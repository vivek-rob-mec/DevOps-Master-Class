import asyncio,os,time,uuid,httpx
from fastapi import FastAPI,HTTPException
from pydantic import BaseModel,Field
from prometheus_client import Counter,Histogram,make_asgi_app
from llmops.policy import build_prompt,embedding,normalize_question,source_allowed
app=FastAPI(title="Governed RAG Gateway",version="1.0.0")
QDRANT=os.getenv("QDRANT_URL","http://localhost:6333");LLM=os.getenv("LLM_BASE_URL","http://localhost:8000/v1");MODEL=os.getenv("LLM_MODEL","Qwen/Qwen3-0.6B");MAX_CONTEXT=int(os.getenv("MAX_CONTEXT_CHARS","6000"))
calls=Counter("rag_requests_total","RAG requests",["result"]);duration=Histogram("rag_request_seconds","RAG request latency")
class Document(BaseModel):id:str=Field(pattern=r"^[a-zA-Z0-9-]{3,64}$");tenant:str=Field(pattern=r"^[a-z0-9-]{2,32}$");source:str;version:str=Field(min_length=1,max_length=32);text:str=Field(min_length=10,max_length=20000)
class Question(BaseModel):tenant:str=Field(pattern=r"^[a-z0-9-]{2,32}$");question:str
async def request(method,path,**kwargs):
 async with httpx.AsyncClient(timeout=10) as client:
  response=await client.request(method,path,**kwargs);response.raise_for_status();return response.json()
@app.on_event("startup")
async def startup():
 for attempt in range(30):
  try:await request("PUT",f"{QDRANT}/collections/documents",json={"vectors":{"size":32,"distance":"Cosine"}});return
  except httpx.HTTPStatusError as error:
   if error.response.status_code==409:return
  except Exception:
   if attempt==29:return
  await asyncio.sleep(1)
@app.get("/health")
async def health():return {"status":"ok"}
@app.get("/ready")
async def ready():
 try:await request("GET",f"{QDRANT}/collections/documents");return {"status":"ready"}
 except Exception as error:raise HTTPException(503,"vector store unavailable") from error
@app.post("/v1/documents",status_code=201)
async def ingest(document:Document):
 if not source_allowed(document.source):raise HTTPException(422,"source host is not allowlisted")
 point_id=str(uuid.uuid5(uuid.NAMESPACE_URL,f"{document.tenant}:{document.id}:{document.version}"))
 payload={"id":document.id,"tenant":document.tenant,"source":document.source,"version":document.version,"text":document.text}
 try:await request("PUT",f"{QDRANT}/collections/documents/points?wait=true",json={"points":[{"id":point_id,"vector":embedding(document.text),"payload":payload}]});return {"pointId":point_id,"documentId":document.id,"version":document.version}
 except Exception as error:raise HTTPException(503,"ingestion unavailable") from error
@app.post("/v1/answer")
async def answer(value:Question):
 started=time.perf_counter()
 try:
  question=normalize_question(value.question)
  result=await request("POST",f"{QDRANT}/collections/documents/points/query",json={"query":embedding(question),"filter":{"must":[{"key":"tenant","match":{"value":value.tenant}}]},"limit":5,"with_payload":True})
  points=result.get("result",{}).get("points",[]);chunks=[point["payload"] for point in points]
  if not chunks:return {"answer":"I do not know based on the available documents.","citations":[],"model":MODEL}
  prompt=build_prompt(question,chunks,MAX_CONTEXT)
  completion=await request("POST",f"{LLM}/chat/completions",json={"model":MODEL,"temperature":0,"max_tokens":400,"messages":[{"role":"system","content":"You are a retrieval-grounded assistant."},{"role":"user","content":prompt}]})
  content=completion["choices"][0]["message"]["content"];calls.labels("success").inc();return {"answer":content,"citations":[{"id":item["id"],"source":item["source"],"version":item["version"]} for item in chunks],"model":MODEL}
 except ValueError as error:calls.labels("rejected").inc();raise HTTPException(422,str(error)) from error
 except Exception as error:calls.labels("failure").inc();raise HTTPException(503,"inference unavailable") from error
 finally:duration.observe(time.perf_counter()-started)
app.mount("/metrics",make_asgi_app())

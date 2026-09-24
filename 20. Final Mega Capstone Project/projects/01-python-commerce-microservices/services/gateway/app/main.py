import os,time,uuid
import httpx
from fastapi import FastAPI,HTTPException,Request,Response
from prometheus_client import CONTENT_TYPE_LATEST,Counter,Histogram,generate_latest

app=FastAPI(title="Commerce Gateway",version="0.1.0");catalog=os.getenv("CATALOG_URL","http://catalog:8001");orders=os.getenv("ORDERS_URL","http://orders:8002")
count=Counter("http_requests_total","HTTP requests",["service","method","route","status"]);latency=Histogram("http_request_duration_seconds","HTTP duration",["service","route"])
@app.middleware("http")
async def observe(request:Request,call_next):
    started=time.perf_counter();request.state.request_id=request.headers.get("x-request-id") or str(uuid.uuid4());response=await call_next(request);response.headers["X-Request-ID"]=request.state.request_id;count.labels("gateway",request.method,request.url.path,str(response.status_code)).inc();latency.labels("gateway",request.url.path).observe(time.perf_counter()-started);return response
async def forward(request,method,url):
    headers={"X-Request-ID":request.state.request_id};key=request.headers.get("idempotency-key")
    if key:headers["Idempotency-Key"]=key
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(3,connect=.5)) as client:upstream=await client.request(method,url,headers=headers,content=await request.body())
    except httpx.RequestError as error:raise HTTPException(503,{"code":"UPSTREAM_UNAVAILABLE","retryable":True}) from error
    return Response(upstream.content,status_code=upstream.status_code,media_type=upstream.headers.get("content-type"))
@app.get("/health")
def health():return {"status":"ok","service":"gateway"}
@app.get("/metrics",include_in_schema=False)
def metrics():return Response(generate_latest(),media_type=CONTENT_TYPE_LATEST)
@app.get("/api/products")
async def products(request:Request):return await forward(request,"GET",f"{catalog}/products")
@app.get("/api/orders")
async def list_orders(request:Request):return await forward(request,"GET",f"{orders}/orders")
@app.post("/api/orders")
async def create_order(request:Request):
    if not request.headers.get("idempotency-key"):raise HTTPException(400,{"code":"IDEMPOTENCY_KEY_REQUIRED","retryable":False})
    return await forward(request,"POST",f"{orders}/orders")

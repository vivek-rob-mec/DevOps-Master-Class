import os,time,uuid
import httpx
from fastapi import FastAPI,Header,HTTPException,Request,Response
from prometheus_client import CONTENT_TYPE_LATEST,Counter,Histogram,generate_latest
from pydantic import BaseModel,Field

app=FastAPI(title="Order Service",version="0.1.0");catalog=os.getenv("CATALOG_URL","http://catalog:8001")
count=Counter("http_requests_total","HTTP requests",["service","method","route","status"]);latency=Histogram("http_request_duration_seconds","HTTP duration",["service","route"])
class Command(BaseModel):product_id:str=Field(min_length=1,max_length=64);quantity:int=Field(ge=1,le=100)
orders={};keys={}
@app.middleware("http")
async def observe(request:Request,call_next):
    started=time.perf_counter();response=await call_next(request);count.labels("orders",request.method,request.url.path,str(response.status_code)).inc();latency.labels("orders",request.url.path).observe(time.perf_counter()-started);return response
@app.get("/health")
def health():return {"status":"ok","service":"orders"}
@app.get("/metrics",include_in_schema=False)
def metrics():return Response(generate_latest(),media_type=CONTENT_TYPE_LATEST)
@app.get("/orders")
def list_orders():return list(orders.values())
@app.post("/orders",status_code=201)
async def create(command:Command,idempotency_key:str=Header(alias="Idempotency-Key")):
    if idempotency_key in keys:return orders[keys[idempotency_key]]
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(2.0,connect=.5)) as client:response=await client.get(f"{catalog}/products/{command.product_id}")
    except httpx.RequestError as error:raise HTTPException(503,{"code":"CATALOG_UNAVAILABLE","retryable":True}) from error
    if response.status_code==404:raise HTTPException(422,{"code":"UNKNOWN_PRODUCT","retryable":False})
    response.raise_for_status();product=response.json()
    if not product["available"]:raise HTTPException(409,{"code":"PRODUCT_UNAVAILABLE","retryable":False})
    order_id=str(uuid.uuid4());order={"id":order_id,"product_id":command.product_id,"quantity":command.quantity,"unit_price_cents":product["price_cents"],"total_cents":product["price_cents"]*command.quantity,"status":"accepted"}
    orders[order_id]=order;keys[idempotency_key]=order_id;return order

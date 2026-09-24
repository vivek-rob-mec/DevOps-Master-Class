import time, uuid
from fastapi import FastAPI, Header, HTTPException, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from pydantic import BaseModel, Field

app=FastAPI(title="Catalog Service",version="0.1.0")
count=Counter("http_requests_total","HTTP requests",["service","method","route","status"])
latency=Histogram("http_request_duration_seconds","HTTP duration",["service","route"])
class Product(BaseModel):
    id:str=Field(min_length=1,max_length=64);name:str=Field(min_length=1,max_length=120);price_cents:int=Field(ge=0);available:bool=True
products={"sku-100":Product(id="sku-100",name="Mechanical Keyboard",price_cents=8900),"sku-200":Product(id="sku-200",name="USB-C Dock",price_cents=12900)}

@app.middleware("http")
async def observe(request:Request,call_next):
    started=time.perf_counter();request_id=request.headers.get("x-request-id") or str(uuid.uuid4());response=await call_next(request)
    response.headers["X-Request-ID"]=request_id;count.labels("catalog",request.method,request.url.path,str(response.status_code)).inc();latency.labels("catalog",request.url.path).observe(time.perf_counter()-started);return response
@app.get("/health")
def health():return {"status":"ok","service":"catalog"}
@app.get("/metrics",include_in_schema=False)
def metrics():return Response(generate_latest(),media_type=CONTENT_TYPE_LATEST)
@app.get("/products",response_model=list[Product])
def list_products():return list(products.values())
@app.get("/products/{product_id}",response_model=Product)
def get_product(product_id:str):
    if product_id not in products:raise HTTPException(404,{"code":"PRODUCT_NOT_FOUND","retryable":False})
    return products[product_id]
@app.put("/products/{product_id}",response_model=Product)
def put_product(product_id:str,product:Product,operator:str|None=Header(default=None,alias="X-Operator")):
    if not operator:raise HTTPException(401,{"code":"OPERATOR_REQUIRED","retryable":False})
    if product_id!=product.id:raise HTTPException(400,{"code":"ID_MISMATCH","retryable":False})
    products[product_id]=product;return product

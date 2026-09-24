param([switch]$WhatIfMode)
. (Join-Path $PSScriptRoot 'Common.ps1')
$project=@{
 Id='01-python-commerce-microservices';Title='Python Commerce Microservices Platform';Type='Microservices';Backend='Python 3.12 / FastAPI';Frontend='React / Vite';Domain='commerce';Namespace='commerce-python';PublicPort=8081;Entry='gateway';Ui='frontend'
 Diagram=@'
flowchart LR
    User --> React["React storefront"] --> Gateway["FastAPI gateway"]
    Gateway --> Catalog["Catalog service"]
    Gateway --> Orders["Order service"]
    Orders --> Catalog
    Catalog --> CatalogState[("Catalog state")]
    Orders --> OrderState[("Order state")]
    Gateway --> Observe["Metrics, logs, traces"]
    Catalog --> Observe
    Orders --> Observe
'@
 Workloads=@(
  @{Name='gateway';Port=8000;Health='/health';Responsibility='Public API, validation, correlation, routing'},
  @{Name='catalog';Port=8001;Health='/health';Responsibility='Product catalog ownership'},
  @{Name='orders';Port=8002;Health='/health';Responsibility='Idempotent order lifecycle'},
  @{Name='frontend';Port=8080;Health='/health';Responsibility='React customer experience'}
 )
}
$root=New-CommonProject $project -WhatIfMode:$WhatIfMode
$requirements=@'
fastapi==0.115.0
httpx==0.27.2
prometheus-client==0.21.0
pydantic==2.9.2
uvicorn[standard]==0.30.6
'@
$docker=@'
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
RUN groupadd -g 10001 app && useradd -u 10001 -g app -m app
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app
RUN python -m compileall -q app && chown -R app:app /app
USER 10001:10001
EXPOSE @@SERVICE_PORT@@
CMD ["sh","-c","uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
'@
foreach($s in @(@{Name='gateway';Port=8000},@{Name='catalog';Port=8001},@{Name='orders';Port=8002})){
 Write-TemplateFile $root "services/$($s.Name)/requirements.txt" $requirements -WhatIfMode:$WhatIfMode
 Write-TemplateFile $root "services/$($s.Name)/Dockerfile" (Expand-ProjectTemplate $docker @{SERVICE_PORT=$s.Port}) -WhatIfMode:$WhatIfMode
 Write-TemplateFile $root "services/$($s.Name)/.dockerignore" "__pycache__/`n*.py[cod]`n.pytest_cache/`n.venv/" -WhatIfMode:$WhatIfMode
 Write-TemplateFile $root "services/$($s.Name)/app/__init__.py" '' -WhatIfMode:$WhatIfMode
}
Write-TemplateFile $root 'services/catalog/app/main.py' @'
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
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'services/orders/app/main.py' @'
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
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'services/gateway/app/main.py' @'
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
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/package.json' @'
{"name":"commerce-react","private":true,"version":"0.1.0","type":"module","scripts":{"dev":"vite --host 0.0.0.0","build":"vite build"},"dependencies":{"@vitejs/plugin-react":"6.0.4","vite":"8.1.0","react":"19.2.7","react-dom":"19.2.7"}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/vite.config.js' 'import{defineConfig}from"vite";import react from"@vitejs/plugin-react";export default defineConfig({plugins:[react()]});' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/.dockerignore' "node_modules/`ndist/" -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/index.html' '<!doctype html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Commerce</title></head><body><div id="root"></div><script type="module" src="/src/main.jsx"></script></body></html>' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/src/main.jsx' @'
import React,{useEffect,useState}from"react";import{createRoot}from"react-dom/client";import"./style.css";
function App(){const[products,setProducts]=useState([]);const[message,setMessage]=useState("Loading...");useEffect(()=>{fetch("/api/products").then(r=>r.json()).then(x=>{setProducts(x);setMessage("Ready")}).catch(e=>setMessage(e.message))},[]);async function order(id){const r=await fetch("/api/orders",{method:"POST",headers:{"Content-Type":"application/json","Idempotency-Key":crypto.randomUUID()},body:JSON.stringify({product_id:id,quantity:1})});setMessage(JSON.stringify(await r.json()))}return <main><h1>Commerce Platform</h1><p>{message}</p><section>{products.map(p=><article key={p.id}><h2>{p.name}</h2><p>${(p.price_cents/100).toFixed(2)}</p><button onClick={()=>order(p.id)}>Order</button></article>)}</section></main>}createRoot(document.getElementById("root")).render(<App/>);
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/src/style.css' 'body{font-family:system-ui;background:#f4f7fb;margin:0}main{max-width:960px;margin:auto;padding:3rem 1rem}section{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:1rem}article{background:white;padding:1rem;border-radius:12px}button{padding:.7rem;background:#3157d5;color:white;border:0;border-radius:8px}' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/nginx.conf' @'
server { listen 8080; root /usr/share/nginx/html; location = /health { default_type application/json; return 200 '{"status":"ok","service":"frontend"}'; } location /api/ { proxy_pass ${GATEWAY_URL}/api/; } location / { try_files $uri /index.html; } }
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/Dockerfile' @'
FROM node:24-alpine AS build
WORKDIR /src
COPY package*.json .
RUN npm ci --no-audit --no-fund
COPY . .
RUN npm run build
FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /src/dist /usr/share/nginx/html
EXPOSE 8080
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'docker-compose.yml' @'
services:
  catalog:
    image: ${REGISTRY:-local}/01-python-commerce-microservices-catalog:${IMAGE_TAG:-dev}
    build: { context: services/catalog }
    environment: { PORT: 8001 }
    healthcheck: { test: ["CMD","python","-c","import urllib.request;urllib.request.urlopen('http://localhost:8001/health')"], interval: 5s, timeout: 2s, retries: 20 }
    networks: [backend]
  orders:
    image: ${REGISTRY:-local}/01-python-commerce-microservices-orders:${IMAGE_TAG:-dev}
    build: { context: services/orders }
    environment: { PORT: 8002, CATALOG_URL: http://catalog:8001 }
    depends_on: { catalog: { condition: service_healthy } }
    healthcheck: { test: ["CMD","python","-c","import urllib.request;urllib.request.urlopen('http://localhost:8002/health')"], interval: 5s, timeout: 2s, retries: 20 }
    networks: [backend]
  gateway:
    image: ${REGISTRY:-local}/01-python-commerce-microservices-gateway:${IMAGE_TAG:-dev}
    build: { context: services/gateway }
    environment: { PORT: 8000, CATALOG_URL: http://catalog:8001, ORDERS_URL: http://orders:8002 }
    depends_on: { catalog: { condition: service_healthy }, orders: { condition: service_healthy } }
    healthcheck: { test: ["CMD","python","-c","import urllib.request;urllib.request.urlopen('http://localhost:8000/health')"], interval: 5s, timeout: 2s, retries: 20 }
    networks: [backend,edge]
  frontend:
    image: ${REGISTRY:-local}/01-python-commerce-microservices-frontend:${IMAGE_TAG:-dev}
    build: { context: frontend }
    environment: { GATEWAY_URL: http://gateway:8000 }
    ports: ["${PUBLIC_PORT:-8081}:8080"]
    depends_on: { gateway: { condition: service_healthy } }
    networks: [edge]
networks: { edge: {}, backend: { internal: true } }
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'scripts/test.sh' @'
#!/usr/bin/env sh
set -eu
python3 -m compileall -q services
docker compose config --quiet
'@ -WhatIfMode:$WhatIfMode
[pscustomobject]@{Project=$project.Id;Root=$root;Files=$script:Generated.Count}

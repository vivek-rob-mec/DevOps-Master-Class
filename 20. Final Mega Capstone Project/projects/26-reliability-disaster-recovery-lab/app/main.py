import asyncio
import os
import time
import uuid
import asyncpg
from fastapi import FastAPI,HTTPException
from pydantic import BaseModel,Field
from prometheus_client import Counter,Histogram,make_asgi_app

app=FastAPI(title="Reliability Lab Order API",version="1.0.0")
pool=None
requests=Counter("order_requests_total","Order requests",["result"])
latency=Histogram("order_request_seconds","Order request latency")

class Order(BaseModel):
 sku:str=Field(pattern=r"^[A-Z0-9-]{3,32}$")
 quantity:int=Field(gt=0,le=100)

@app.on_event("startup")
async def startup():
 global pool
 for attempt in range(30):
  try:
   pool=await asyncpg.create_pool(os.environ["DATABASE_URL"],min_size=1,max_size=10,command_timeout=2)
   async with pool.acquire() as connection:
    await connection.execute("CREATE TABLE IF NOT EXISTS orders(id uuid PRIMARY KEY,sku varchar(32) NOT NULL,quantity integer NOT NULL,created_at timestamptz NOT NULL DEFAULT now())")
   return
  except Exception:
   if attempt==29:raise
   await asyncio.sleep(1)

@app.on_event("shutdown")
async def shutdown():
 if pool:await pool.close()

@app.get("/health")
async def health():return {"status":"ok"}

@app.get("/ready")
async def ready():
 try:
  async with pool.acquire() as connection:await connection.fetchval("SELECT 1")
  return {"status":"ready"}
 except Exception as error:raise HTTPException(503,"database unavailable") from error

@app.post("/api/orders",status_code=201)
async def create(order:Order):
 started=time.perf_counter()
 try:
  identifier=uuid.uuid4()
  async with pool.acquire() as connection:await connection.execute("INSERT INTO orders(id,sku,quantity) VALUES($1,$2,$3)",identifier,order.sku,order.quantity)
  requests.labels("success").inc()
  return {"id":str(identifier),**order.model_dump()}
 except Exception as error:
  requests.labels("failure").inc()
  raise HTTPException(503,"dependency unavailable") from error
 finally:latency.observe(time.perf_counter()-started)

app.mount("/metrics",make_asgi_app())

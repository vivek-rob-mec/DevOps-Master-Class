from dataclasses import dataclass
from datetime import timedelta
from temporalio import activity,workflow
from temporalio.common import RetryPolicy

@dataclass
class Order:
 order_id:str
 sku:str
 quantity:int

@activity.defn
async def authorize_payment(order:Order)->str:
 activity.heartbeat({"order_id":order.order_id,"step":"authorize"})
 return f"auth-{order.order_id}"

@activity.defn
async def reserve_inventory(order:Order)->str:
 activity.heartbeat({"order_id":order.order_id,"step":"reserve"})
 return f"reservation-{order.order_id}"

@activity.defn
async def release_payment(authorization_id:str)->None:
 activity.heartbeat({"authorization_id":authorization_id,"step":"compensate"})

@activity.defn
async def release_inventory(reservation_id:str)->None:
 activity.heartbeat({"reservation_id":reservation_id,"step":"compensate"})

@workflow.defn
class FulfillmentWorkflow:
 def __init__(self)->None:
  self.cancel_requested=False
  self.status="created"

 @workflow.run
 async def run(self,order:Order)->dict:
  retry=RetryPolicy(initial_interval=timedelta(seconds=2),backoff_coefficient=2,maximum_interval=timedelta(minutes=1),maximum_attempts=5)
  authorization=await workflow.execute_activity(authorize_payment,order,start_to_close_timeout=timedelta(seconds=30),heartbeat_timeout=timedelta(seconds=10),retry_policy=retry)
  self.status="payment_authorized"
  try:
   reservation=await workflow.execute_activity(reserve_inventory,order,start_to_close_timeout=timedelta(seconds=30),heartbeat_timeout=timedelta(seconds=10),retry_policy=retry)
   self.status="inventory_reserved"
  except Exception:
   await workflow.execute_activity(release_payment,authorization,start_to_close_timeout=timedelta(seconds=30),retry_policy=retry)
   self.status="payment_released"
   raise
  await workflow.wait_condition(lambda:self.cancel_requested or self.status=="ship_approved")
  if self.cancel_requested:
   await workflow.execute_activity(release_inventory,reservation,start_to_close_timeout=timedelta(seconds=30),retry_policy=retry)
   await workflow.execute_activity(release_payment,authorization,start_to_close_timeout=timedelta(seconds=30),retry_policy=retry)
   self.status="cancelled"
  else:self.status="shipped"
  return {"order_id":order.order_id,"authorization":authorization,"reservation":reservation,"status":self.status}

 @workflow.signal
 def approve_shipping(self)->None:self.status="ship_approved"

 @workflow.signal
 def cancel(self)->None:self.cancel_requested=True

 @workflow.query
 def current_status(self)->str:return self.status

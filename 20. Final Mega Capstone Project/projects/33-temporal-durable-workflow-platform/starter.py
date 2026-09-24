import asyncio,os
from temporalio.client import Client
from workflow.temporal_app import FulfillmentWorkflow,Order

async def main():
 client=await Client.connect(os.getenv("TEMPORAL_ADDRESS","localhost:7233"))
 order=Order("order-1001","SKU-1",1)
 handle=await client.start_workflow(FulfillmentWorkflow.run,order,id=f"fulfillment-{order.order_id}",task_queue=os.getenv("TASK_QUEUE","fulfillment"))
 print(handle.id)

if __name__=="__main__":asyncio.run(main())

import asyncio,os
from temporalio.client import Client
from temporalio.worker import Worker
from workflow.temporal_app import FulfillmentWorkflow,authorize_payment,release_inventory,release_payment,reserve_inventory

async def main():
 client=await Client.connect(os.getenv("TEMPORAL_ADDRESS","localhost:7233"),namespace=os.getenv("TEMPORAL_NAMESPACE","default"))
 worker=Worker(client,task_queue=os.getenv("TASK_QUEUE","fulfillment"),workflows=[FulfillmentWorkflow],activities=[authorize_payment,reserve_inventory,release_inventory,release_payment])
 await worker.run()

if __name__=="__main__":asyncio.run(main())

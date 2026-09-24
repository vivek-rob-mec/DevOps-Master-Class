from celery import shared_task
from .models import Shipment
@shared_task(bind=True,autoretry_for=(Exception,),retry_backoff=True,retry_jitter=True,max_retries=5)
def dispatch_shipment(self,shipment_id):
    updated=Shipment.objects.filter(id=shipment_id,status="queued").update(status="dispatched")
    return {"shipmentId":str(shipment_id),"updated":bool(updated)}

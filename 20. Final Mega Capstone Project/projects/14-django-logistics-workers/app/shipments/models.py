import uuid
from django.db import models
class Shipment(models.Model):
    id=models.UUIDField(primary_key=True,default=uuid.uuid4,editable=False)
    reference=models.CharField(max_length=64)
    destination=models.CharField(max_length=160)
    status=models.CharField(max_length=24,default="queued")
    idempotency_key=models.CharField(max_length=128,unique=True)
    created_at=models.DateTimeField(auto_now_add=True)

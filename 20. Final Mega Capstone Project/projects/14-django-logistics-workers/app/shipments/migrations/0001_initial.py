import uuid
from django.db import migrations,models
class Migration(migrations.Migration):
    initial=True
    dependencies=[]
    operations=[migrations.CreateModel(name="Shipment",fields=[("id",models.UUIDField(default=uuid.uuid4,editable=False,primary_key=True,serialize=False)),("reference",models.CharField(max_length=64)),("destination",models.CharField(max_length=160)),("status",models.CharField(default="queued",max_length=24)),("idempotency_key",models.CharField(max_length=128,unique=True)),("created_at",models.DateTimeField(auto_now_add=True))])]

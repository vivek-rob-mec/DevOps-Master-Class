param([switch]$WhatIfMode)
. (Join-Path $PSScriptRoot 'Common.ps1')
$project=@{
 Id='14-django-logistics-workers';Title='Django Logistics and Background Jobs Platform';Type='Web application with asynchronous workers';Backend='Python 3.12 / Django 5.2 LTS / Celery / Redis / PostgreSQL';Frontend='Django templates / progressive JavaScript';Domain='logistics';Namespace='logistics-django';PublicPort=8093;Entry='web';Ui='web'
 Diagram=@'
flowchart LR
    Operator --> Web["Django logistics portal"]
    Web --> PG[(PostgreSQL)]
    Web --> Redis[(Redis broker)]
    Redis --> Worker["Celery worker"]
    Worker --> Carrier["Carrier adapter"]
    Worker --> PG
    Web --> Metrics["Health and metrics"]
    Worker --> WorkerHealth["Worker health endpoint"]
'@
 Workloads=@(
  @{Name='web';Port=8000;Health='/health';Responsibility='Django portal, shipment API, persistence, and queue producer'},
  @{Name='worker';Port=8001;Health='/health';Responsibility='Celery shipment processor and worker health endpoint'}
 )
}
$root=New-CommonProject $project -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/requirements.txt' @'
Django==5.2.15
celery[redis]==5.5.3
psycopg[binary]==3.2.10
gunicorn==23.0.0
prometheus-client==0.22.1
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/manage.py' 'import os,sys;os.environ.setdefault("DJANGO_SETTINGS_MODULE","config.settings");from django.core.management import execute_from_command_line;execute_from_command_line(sys.argv)' -WhatIfMode:$WhatIfMode
$configInit = @'
from .celery import app as celery_app

__all__ = ("celery_app",)
'@
Write-TemplateFile $root 'app/config/__init__.py' $configInit -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/config/settings.py' @'
import os
BASE_DIR=os.path.dirname(os.path.dirname(__file__))
SECRET_KEY=os.getenv("DJANGO_SECRET_KEY","local-development-only")
DEBUG=False
ALLOWED_HOSTS=["*"]
ROOT_URLCONF="config.urls"
WSGI_APPLICATION="config.wsgi.application"
INSTALLED_APPS=["django.contrib.contenttypes","django.contrib.staticfiles","shipments"]
MIDDLEWARE=["django.middleware.security.SecurityMiddleware","django.middleware.common.CommonMiddleware"]
DATABASES={"default":{"ENGINE":"django.db.backends.postgresql","NAME":os.getenv("POSTGRES_DB","app"),"USER":os.getenv("POSTGRES_USER","app"),"PASSWORD":os.getenv("POSTGRES_PASSWORD","local-development-only"),"HOST":os.getenv("POSTGRES_HOST","postgres"),"PORT":"5432","CONN_MAX_AGE":60}}
STATIC_URL="static/"
STATIC_ROOT=os.path.join(BASE_DIR,"staticfiles")
DEFAULT_AUTO_FIELD="django.db.models.BigAutoField"
CELERY_BROKER_URL=os.getenv("REDIS_URL","redis://redis:6379/0")
CELERY_TASK_ACKS_LATE=True
CELERY_TASK_REJECT_ON_WORKER_LOST=True
CELERY_WORKER_PREFETCH_MULTIPLIER=1
'@ -WhatIfMode:$WhatIfMode
$urls = @'
from django.urls import path
from shipments import views

urlpatterns = [
    path("", views.index),
    path("health", views.health),
    path("metrics", views.metrics),
    path("api/shipments", views.shipments),
]
'@
Write-TemplateFile $root 'app/config/urls.py' $urls -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/config/wsgi.py' 'import os;os.environ.setdefault("DJANGO_SETTINGS_MODULE","config.settings");from django.core.wsgi import get_wsgi_application;application=get_wsgi_application()' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/config/celery.py' 'import os;os.environ.setdefault("DJANGO_SETTINGS_MODULE","config.settings");from celery import Celery;app=Celery("logistics");app.config_from_object("django.conf:settings",namespace="CELERY");app.autodiscover_tasks()' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/shipments/__init__.py' '' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/shipments/models.py' @'
import uuid
from django.db import models
class Shipment(models.Model):
    id=models.UUIDField(primary_key=True,default=uuid.uuid4,editable=False)
    reference=models.CharField(max_length=64)
    destination=models.CharField(max_length=160)
    status=models.CharField(max_length=24,default="queued")
    idempotency_key=models.CharField(max_length=128,unique=True)
    created_at=models.DateTimeField(auto_now_add=True)
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/shipments/domain.py' @'
import re

def parse_shipment(payload):
    reference=str(payload.get("reference","")).strip().upper()
    destination=str(payload.get("destination","")).strip()
    if not re.fullmatch(r"[A-Z0-9-]{4,64}",reference) or not 3<=len(destination)<=160:
        raise ValueError("INVALID_SHIPMENT")
    return {"reference":reference,"destination":destination}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/shipments/tasks.py' @'
from celery import shared_task
from .models import Shipment
@shared_task(bind=True,autoretry_for=(Exception,),retry_backoff=True,retry_jitter=True,max_retries=5)
def dispatch_shipment(self,shipment_id):
    updated=Shipment.objects.filter(id=shipment_id,status="queued").update(status="dispatched")
    return {"shipmentId":str(shipment_id),"updated":bool(updated)}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/shipments/views.py' @'
import json
from django.db import connection,transaction
from django.http import JsonResponse,HttpResponse
from django.views.decorators.csrf import csrf_exempt
from .models import Shipment
from .tasks import dispatch_shipment
from .domain import parse_shipment
def index(request):return HttpResponse(open("shipments/static/index.html",encoding="utf-8").read(),content_type="text/html")
def health(request):
    with connection.cursor() as cursor:cursor.execute("SELECT 1")
    return JsonResponse({"status":"ok","service":"logistics-web"})
def metrics(request):return HttpResponse("# HELP logistics_up Service readiness\n# TYPE logistics_up gauge\nlogistics_up 1\n",content_type="text/plain")
@csrf_exempt
def shipments(request):
    if request.method=="GET":return JsonResponse(list(Shipment.objects.order_by("-created_at").values("id","reference","destination","status","created_at")[:200]),safe=False)
    if request.method!="POST":return JsonResponse({"code":"METHOD_NOT_ALLOWED"},status=405)
    key=request.headers.get("Idempotency-Key","")
    if not key or len(key)>128:return JsonResponse({"code":"IDEMPOTENCY_KEY_REQUIRED"},status=400)
    try:payload=json.loads(request.body or b"{}")
    except json.JSONDecodeError:return JsonResponse({"code":"INVALID_JSON"},status=400)
    try:value=parse_shipment(payload)
    except ValueError as error:return JsonResponse({"code":str(error)},status=422)
    with transaction.atomic():shipment,created=Shipment.objects.get_or_create(idempotency_key=key,defaults=value)
    if created:dispatch_shipment.delay(str(shipment.id))
    return JsonResponse({"id":shipment.id,"reference":shipment.reference,"destination":shipment.destination,"status":shipment.status,"createdAt":shipment.created_at},status=201 if created else 200)
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/shipments/test_domain.py' @'
import unittest
from .domain import parse_shipment

class ShipmentDomainTests(unittest.TestCase):
    def test_normalizes_shipment(self):
        self.assertEqual({"reference":"SHIP-1001","destination":"Bengaluru"},parse_shipment({"reference":" ship-1001 ","destination":" Bengaluru "}))
    def test_rejects_invalid_reference(self):
        with self.assertRaisesRegex(ValueError,"INVALID_SHIPMENT"):
            parse_shipment({"reference":"x","destination":"Bengaluru"})
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/shipments/migrations/__init__.py' '' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/shipments/migrations/0001_initial.py' @'
import uuid
from django.db import migrations,models
class Migration(migrations.Migration):
    initial=True
    dependencies=[]
    operations=[migrations.CreateModel(name="Shipment",fields=[("id",models.UUIDField(default=uuid.uuid4,editable=False,primary_key=True,serialize=False)),("reference",models.CharField(max_length=64)),("destination",models.CharField(max_length=160)),("status",models.CharField(default="queued",max_length=24)),("idempotency_key",models.CharField(max_length=128,unique=True)),("created_at",models.DateTimeField(auto_now_add=True))])]
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/shipments/static/index.html' @'
<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Routeboard</title><style>:root{font-family:system-ui;color:#1f2933;background:#f4efe6}*{box-sizing:border-box}body{margin:0}main{max-width:1050px;margin:auto;padding:4rem 2rem}h1{font-size:clamp(3rem,8vw,6rem);line-height:.9}header p{letter-spacing:.2em;color:#d1495b;font-weight:bold}form{display:flex;gap:.5rem;background:#1f2933;padding:.7rem}input,button{padding:.9rem;border:0;flex:1}button{background:#edae49;font-weight:bold}section{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:1rem;margin-top:2rem}article{background:#fff;padding:1.2rem;border-bottom:5px solid #00798c}span{color:#d1495b;text-transform:uppercase;font-size:.7rem}</style></head><body><main><header><p>ROUTEBOARD</p><h1>Queue work.<br>Track outcomes.</h1><output id="message">Ready</output></header><form id="form"><input name="reference" value="SHIP-1001"><input name="destination" value="Bengaluru"><button>Queue shipment</button></form><section id="list"></section></main><script>const f=document.querySelector("#form"),l=document.querySelector("#list"),m=document.querySelector("#message");async function load(){l.innerHTML=(await(await fetch("/api/shipments")).json()).map(x=>`<article><span>${x.status}</span><h2>${x.reference}</h2><p>${x.destination}</p></article>`).join("")}f.onsubmit=async e=>{e.preventDefault();const d=new FormData(f),r=await fetch("/api/shipments",{method:"POST",headers:{"content-type":"application/json","idempotency-key":crypto.randomUUID()},body:JSON.stringify(Object.fromEntries(d))});m.textContent=r.ok?"Queued":JSON.stringify(await r.json());await load()};load()</script></body></html>
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/worker_health.py' @'
import json,threading
from http.server import BaseHTTPRequestHandler,HTTPServer
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body=json.dumps({"status":"ok","service":"logistics-worker"}).encode() if self.path=="/health" else b"not found";self.send_response(200 if self.path=="/health" else 404);self.send_header("Content-Type","application/json");self.send_header("Content-Length",str(len(body)));self.end_headers();self.wfile.write(body)
    def log_message(self,*args):pass
threading.Thread(target=HTTPServer(("0.0.0.0",8001),Handler).serve_forever,daemon=True).start()
from config.celery import app
app.worker_main(["worker","--loglevel=INFO","--concurrency=2"])
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'Dockerfile.web' @'
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=8000
RUN groupadd -g 10001 app && useradd -u 10001 -g app --no-create-home app
WORKDIR /app
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY --chown=app:app app/ ./
USER 10001:10001
EXPOSE 8000
CMD ["sh","-c","python manage.py migrate --noinput && gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 2 --threads 4 --timeout 30"]
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'Dockerfile.worker' @'
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN groupadd -g 10001 app && useradd -u 10001 -g app --no-create-home app
WORKDIR /app
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY --chown=app:app app/ ./
USER 10001:10001
EXPOSE 8001
CMD ["python","worker_health.py"]
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'docker-compose.yml' @'
services:
  postgres:
    image: postgres:16-alpine
    environment: { POSTGRES_USER: "${POSTGRES_USER:-app}", POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-local-development-only}", POSTGRES_DB: "${POSTGRES_DB:-app}" }
    volumes: [postgres-data:/var/lib/postgresql/data]
    healthcheck: { test: ["CMD-SHELL","pg_isready -U ${POSTGRES_USER:-app} -d ${POSTGRES_DB:-app}"], interval: 5s, timeout: 3s, retries: 30 }
    networks: [data]
  redis:
    image: redis:7.4-alpine
    command: ["redis-server","--appendonly","yes","--requirepass","${REDIS_PASSWORD:-local-development-only}"]
    volumes: [redis-data:/data]
    healthcheck: { test: ["CMD","redis-cli","-a","${REDIS_PASSWORD:-local-development-only}","ping"], interval: 5s, timeout: 3s, retries: 30 }
    networks: [data]
  web:
    image: ${REGISTRY:-local}/14-django-logistics-workers-web:${IMAGE_TAG:-dev}
    build: { context: ., dockerfile: Dockerfile.web }
    environment: &env { POSTGRES_HOST: postgres, POSTGRES_USER: "${POSTGRES_USER:-app}", POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-local-development-only}", POSTGRES_DB: "${POSTGRES_DB:-app}", REDIS_URL: "redis://:${REDIS_PASSWORD:-local-development-only}@redis:6379/0", DJANGO_SECRET_KEY: "${DJANGO_SECRET_KEY:-local-development-only}" }
    ports: ["${PUBLIC_PORT:-8093}:8000"]
    depends_on: { postgres: { condition: service_healthy }, redis: { condition: service_healthy } }
    networks: [edge,data]
  worker:
    image: ${REGISTRY:-local}/14-django-logistics-workers-worker:${IMAGE_TAG:-dev}
    build: { context: ., dockerfile: Dockerfile.worker }
    environment: *env
    depends_on: { postgres: { condition: service_healthy }, redis: { condition: service_healthy } }
    networks: [data]
networks: { edge: {}, data: { internal: true } }
volumes: { postgres-data: {}, redis-data: {} }
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'scripts/test.sh' @'
#!/usr/bin/env sh
set -eu
python -m py_compile app/manage.py app/config/*.py app/shipments/*.py app/shipments/migrations/*.py
cd app
python -m unittest shipments.test_domain -v
cd ..
docker compose config --quiet
'@ -WhatIfMode:$WhatIfMode
[pscustomobject]@{Project=$project.Id;Root=$root;Files=$script:Generated.Count}

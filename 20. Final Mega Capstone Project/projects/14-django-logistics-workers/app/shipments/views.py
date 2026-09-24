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

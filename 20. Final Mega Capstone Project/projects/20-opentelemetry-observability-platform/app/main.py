import logging,os,time
from fastapi import FastAPI,HTTPException,Request
from opentelemetry import metrics,trace
from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor
from opentelemetry.sdk._logs import LoggerProvider,LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.trace.sampling import ParentBased,TraceIdRatioBased
from domain import parse_checkout

endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT","http://otel-collector:4318");resource=Resource.create({"service.name":"checkout-observability","service.version":"0.1.0","deployment.environment":os.getenv("ENVIRONMENT","dev")})
tracer_provider=TracerProvider(resource=resource,sampler=ParentBased(TraceIdRatioBased(float(os.getenv("OTEL_SAMPLE_RATIO","1.0")))));tracer_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=f"{endpoint}/v1/traces")));trace.set_tracer_provider(tracer_provider)
meter_provider=MeterProvider(resource=resource,metric_readers=[PeriodicExportingMetricReader(OTLPMetricExporter(endpoint=f"{endpoint}/v1/metrics"),export_interval_millis=5000)]);metrics.set_meter_provider(meter_provider)
logger_provider=LoggerProvider(resource=resource);logger_provider.add_log_record_processor(BatchLogRecordProcessor(OTLPLogExporter(endpoint=f"{endpoint}/v1/logs")));logging.getLogger().addHandler(LoggingHandler(level=logging.INFO,logger_provider=logger_provider));logging.getLogger().setLevel(logging.INFO);LoggingInstrumentor().instrument(set_logging_format=True)
meter=metrics.get_meter("checkout");requests=meter.create_counter("checkout.requests",unit="1");latency=meter.create_histogram("checkout.duration",unit="ms");logger=logging.getLogger("checkout");app=FastAPI(title="Observable Checkout")
@app.middleware("http")
async def measure(request:Request,call_next):
    started=time.perf_counter();status=500
    try:response=await call_next(request);status=response.status_code;return response
    finally:requests.add(1,{"http.route":request.url.path,"http.status_code":status});latency.record((time.perf_counter()-started)*1000,{"http.route":request.url.path})
@app.get("/health")
def health():return {"status":"ok","service":"checkout-observability"}
@app.post("/api/checkout")
def checkout(payload:dict,simulateFailure:bool=False):
    try:value=parse_checkout(payload)
    except ValueError as error:raise HTTPException(422,detail={"code":str(error)})
    span=trace.get_current_span();span.set_attribute("checkout.cart_id",value.cart_id);span.set_attribute("checkout.items",value.items)
    if simulateFailure:logger.error("checkout dependency failed",extra={"cart_id":value.cart_id});raise HTTPException(503,detail={"code":"PAYMENT_UNAVAILABLE"})
    logger.info("checkout accepted",extra={"cart_id":value.cart_id,"items":value.items});return {"cartId":value.cart_id,"status":"accepted","total":value.total}
FastAPIInstrumentor.instrument_app(app)

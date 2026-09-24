import logging,os,time
from contextlib import asynccontextmanager
import mlflow,pandas as pd
from fastapi import FastAPI,HTTPException
from pydantic import BaseModel
from prometheus_client import Counter,Histogram,make_asgi_app
from platform_lib.domain import validate_features

logging.basicConfig(level=os.getenv("LOG_LEVEL","INFO"),format="%(asctime)s %(levelname)s %(message)s");logger=logging.getLogger("inference");model=None;model_uri=lambda:f"models:/{os.getenv('MODEL_NAME','fraud-risk')}@{os.getenv('MODEL_ALIAS','champion')}";predictions=Counter("model_predictions_total","Predictions by result",["result"]);latency=Histogram("model_prediction_seconds","Inference latency")
def load_model():
 global model
 mlflow.set_tracking_uri(os.getenv("MLFLOW_TRACKING_URI","http://mlflow:5000"));model=mlflow.pyfunc.load_model(model_uri());logger.info("model loaded uri=%s",model_uri())
@asynccontextmanager
async def lifespan(_app):
 try:load_model()
 except Exception:logger.exception("model unavailable during startup")
 yield
app=FastAPI(title="Fraud Risk Inference",lifespan=lifespan);app.mount("/metrics",make_asgi_app())
class PredictionRequest(BaseModel):features:list[float]
@app.get("/health")
def health():
 if model is None:raise HTTPException(503,detail={"status":"not_ready","reason":"model_unavailable"})
 return {"status":"ok","service":"fraud-risk-inference","modelUri":model_uri()}
@app.post("/admin/reload")
def reload():load_model();return {"status":"reloaded","modelUri":model_uri()}
@app.post("/predict")
def predict(request:PredictionRequest):
 if model is None:raise HTTPException(503,detail={"code":"MODEL_UNAVAILABLE"})
 try:features=validate_features(request.features)
 except ValueError as error:raise HTTPException(422,detail={"code":str(error)})
 started=time.perf_counter();frame=pd.DataFrame([features],columns=["velocity","amount_zscore","device_risk","account_age_risk"])
 try:result=int(model.predict(frame)[0])
 except Exception as error:logger.exception("prediction failed");raise HTTPException(500,detail={"code":"PREDICTION_FAILED"}) from error
 finally:latency.observe(time.perf_counter()-started)
 label="review" if result else "approve";predictions.labels(result=label).inc();logger.info("prediction completed result=%s",label);return {"decision":label,"modelUri":model_uri()}

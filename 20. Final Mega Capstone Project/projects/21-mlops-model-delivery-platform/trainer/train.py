import json,os
import mlflow,mlflow.sklearn,pandas as pd
from mlflow import MlflowClient
from sklearn.datasets import make_classification
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score,roc_auc_score
from sklearn.model_selection import train_test_split

tracking=os.getenv("MLFLOW_TRACKING_URI","http://mlflow:5000");name=os.getenv("MODEL_NAME","fraud-risk");alias=os.getenv("MODEL_ALIAS","champion");mlflow.set_tracking_uri(tracking);mlflow.set_experiment("fraud-risk-training")
features,labels=make_classification(n_samples=4000,n_features=4,n_informative=3,n_redundant=1,weights=[.92,.08],random_state=42);features=pd.DataFrame(features,columns=["velocity","amount_zscore","device_risk","account_age_risk"]);x_train,x_test,y_train,y_test=train_test_split(features,labels,test_size=.25,random_state=42,stratify=labels);model=LogisticRegression(max_iter=1000,class_weight="balanced",random_state=42).fit(x_train,y_train);probability=model.predict_proba(x_test)[:,1];prediction=(probability>=.5).astype(int);metrics={"accuracy":accuracy_score(y_test,prediction),"roc_auc":roc_auc_score(y_test,probability)}
if metrics["roc_auc"]<.80:raise RuntimeError(f"quality gate failed: {metrics}")
with mlflow.start_run() as run:
 mlflow.log_params({"algorithm":"logistic-regression","random_state":42,"training_rows":len(x_train),"feature_count":4});mlflow.log_metrics(metrics);mlflow.log_dict({"schema_version":"1","features":["velocity","amount_zscore","device_risk","account_age_risk"]},"feature_contract.json");info=mlflow.sklearn.log_model(sk_model=model,name="model",registered_model_name=name,input_example=x_test[:3])
client=MlflowClient();versions=client.search_model_versions(f"run_id='{run.info.run_id}'");version=max(versions,key=lambda value:int(value.version));client.set_registered_model_alias(name,alias,version.version);client.set_model_version_tag(name,version.version,"validation_status","passed");print(json.dumps({"runId":run.info.run_id,"model":name,"version":version.version,"alias":alias,**metrics},sort_keys=True))

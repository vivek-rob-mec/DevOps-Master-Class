param([switch]$WhatIfMode)
. (Join-Path $PSScriptRoot 'Common.ps1')
$project=@{
 Id='17-rust-payment-risk-service';Title='Rust Payment Risk and Transactional Outbox Service';Type='Event-driven cloud service';Backend='Rust 1.97 / Axum / Tokio / PostgreSQL / NATS JetStream';Frontend='HTTP API';Domain='payment-risk';Namespace='payment-risk-rust';PublicPort=8097;Entry='app';Ui='app'
 Diagram=@'
flowchart LR
    Client --> API["Axum payment API"]
    API --> Rules["Risk rules"]
    Rules --> TX["PostgreSQL transaction"]
    TX --> Payments[(Payments)]
    TX --> Outbox[(Transactional outbox)]
    Publisher["Outbox publisher"] --> Outbox
    Publisher --> NATS["NATS JetStream"]
    NATS --> Consumers["Fraud and settlement consumers"]
'@
 Workloads=@(@{Name='app';Port=8080;Health='/health';Responsibility='Axum API, deterministic risk rules, PostgreSQL ledger, and transactional outbox publisher'})
}
$root=New-CommonProject $project -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/Cargo.toml' @'
[package]
name = "payment-risk"
version = "0.1.0"
edition = "2024"
rust-version = "1.97"

[dependencies]
async-nats = "=0.50.0"
axum = "=0.8.9"
serde = { version = "=1.0.229", features = ["derive"] }
serde_json = "=1.0.151"
thiserror = "=2.0.20"
tokio = { version = "=1.53.1", features = ["macros", "rt-multi-thread", "net", "signal", "sync", "time"] }
tokio-postgres = { version = "=0.7.18", features = ["with-uuid-1"] }
tracing = "=0.1.44"
tracing-subscriber = { version = "=0.3.23", features = ["env-filter", "json"] }
uuid = { version = "=1.24.1", features = ["v4", "serde"] }
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/src/domain.rs' @'
use serde::{Deserialize,Serialize};
use thiserror::Error;

#[derive(Debug,Deserialize)]
pub struct PaymentDraft { pub merchant_id:String,pub amount:f64,pub country:String }
#[derive(Debug,Serialize,PartialEq)]
pub struct AssessedPayment { pub merchant_id:String,pub amount:f64,pub country:String,pub risk_score:i32,pub decision:String }
#[derive(Debug,Error,PartialEq)]
pub enum ValidationError { #[error("INVALID_MERCHANT")] Merchant,#[error("INVALID_AMOUNT")] Amount,#[error("INVALID_COUNTRY")] Country }

pub fn assess(value:PaymentDraft)->Result<AssessedPayment,ValidationError>{
    let merchant=value.merchant_id.trim().to_uppercase();
    let country=value.country.trim().to_uppercase();
    if merchant.len()<4||merchant.len()>64||!merchant.chars().all(|c|c.is_ascii_alphanumeric()||c=='-'){return Err(ValidationError::Merchant)}
    if !value.amount.is_finite()||value.amount<=0.0||value.amount>1_000_000.0{return Err(ValidationError::Amount)}
    if country.len()!=2||!country.chars().all(|c|c.is_ascii_uppercase()){return Err(ValidationError::Country)}
    let mut score=0;if value.amount>=10_000.0{score+=55}if matches!(country.as_str(),"IR"|"KP"|"SY"){score+=45}
    let decision=if score>=80{"review"}else if score>=55{"step_up"}else{"approve"}.to_string();
    Ok(AssessedPayment{merchant_id:merchant,amount:value.amount,country,risk_score:score,decision})
}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/src/main.rs' @'
mod domain;
use std::{env,sync::Arc,time::Duration};
use async_nats::Client as NatsClient;
use axum::{extract::State,http::{header,HeaderMap,StatusCode},response::{IntoResponse,Response},routing::get,Json,Router};
use domain::{assess,PaymentDraft};
use serde_json::{json,Value};
use tokio::sync::Mutex;
use tokio_postgres::{Client,NoTls};
use tracing::{error,info};
use uuid::Uuid;

#[derive(Clone)]struct AppState{db:Arc<Mutex<Client>>,nats:NatsClient}
struct ApiError(StatusCode,&'static str);impl IntoResponse for ApiError{fn into_response(self)->Response{(self.0,Json(json!({"code":self.1}))).into_response()}}

#[tokio::main]
async fn main(){
 tracing_subscriber::fmt().json().with_env_filter(tracing_subscriber::EnvFilter::from_default_env()).init();
 let database_url=env::var("DATABASE_URL").unwrap_or_else(|_|"postgres://app:local-development-only@localhost/app".into());
 let (client,connection)=tokio_postgres::connect(&database_url,NoTls).await.expect("database connection");tokio::spawn(async move{if let Err(error)=connection.await{error!(%error,"database connection ended")}});
 client.batch_execute("CREATE TABLE IF NOT EXISTS payments(id uuid PRIMARY KEY,merchant_id varchar(64) NOT NULL,amount double precision NOT NULL,country char(2) NOT NULL,risk_score integer NOT NULL,decision varchar(16) NOT NULL,idempotency_key varchar(128) UNIQUE NOT NULL,created_at timestamptz NOT NULL DEFAULT now());CREATE TABLE IF NOT EXISTS payment_outbox(id uuid PRIMARY KEY,payload jsonb NOT NULL,published_at timestamptz NULL,created_at timestamptz NOT NULL DEFAULT now());").await.expect("schema");
 let nats_url=env::var("NATS_URL").unwrap_or_else(|_|"nats://localhost:4222".into());let nats=connect_nats(&nats_url).await;
 let state=AppState{db:Arc::new(Mutex::new(client)),nats};tokio::spawn(publish_outbox(state.clone()));
 let app=Router::new().route("/health",get(health)).route("/metrics",get(metrics)).route("/api/payments",get(list).post(create)).with_state(state);
 let address=env::var("LISTEN_ADDRESS").unwrap_or_else(|_|"0.0.0.0:8080".into());let listener=tokio::net::TcpListener::bind(&address).await.expect("listen");info!(%address,"payment risk service started");axum::serve(listener,app).with_graceful_shutdown(shutdown()).await.expect("server");
}
async fn connect_nats(url:&str)->NatsClient{loop{match async_nats::connect(url).await{Ok(client)=>return client,Err(error)=>{error!(%error,"nats unavailable");tokio::time::sleep(Duration::from_secs(2)).await}}}}
async fn health(State(state):State<AppState>)->Result<Json<Value>,ApiError>{state.db.lock().await.simple_query("SELECT 1").await.map_err(|_|ApiError(StatusCode::SERVICE_UNAVAILABLE,"NOT_READY"))?;Ok(Json(json!({"status":"ok","service":"payment-risk"})))}
async fn metrics()->impl IntoResponse{([(header::CONTENT_TYPE,"text/plain; version=0.0.4")],"# HELP payment_risk_up Service readiness\n# TYPE payment_risk_up gauge\npayment_risk_up 1\n")}
async fn list(State(state):State<AppState>)->Result<Json<Value>,ApiError>{let rows=state.db.lock().await.query("SELECT id::text,merchant_id,amount,country,risk_score,decision,created_at::text FROM payments ORDER BY created_at DESC LIMIT 200",&[]).await.map_err(|_|ApiError(StatusCode::INTERNAL_SERVER_ERROR,"DATABASE_ERROR"))?;Ok(Json(Value::Array(rows.iter().map(|r|json!({"id":r.get::<_,String>(0),"merchantId":r.get::<_,String>(1),"amount":r.get::<_,f64>(2),"country":r.get::<_,String>(3),"riskScore":r.get::<_,i32>(4),"decision":r.get::<_,String>(5),"createdAt":r.get::<_,String>(6)})).collect())))}
async fn create(State(state):State<AppState>,headers:HeaderMap,Json(draft):Json<PaymentDraft>)->Result<(StatusCode,Json<Value>),ApiError>{let key=headers.get("idempotency-key").and_then(|v|v.to_str().ok()).unwrap_or("");if key.is_empty()||key.len()>128{return Err(ApiError(StatusCode::BAD_REQUEST,"IDEMPOTENCY_KEY_REQUIRED"))}let value=assess(draft).map_err(|error|match error{domain::ValidationError::Merchant=>ApiError(StatusCode::UNPROCESSABLE_ENTITY,"INVALID_MERCHANT"),domain::ValidationError::Amount=>ApiError(StatusCode::UNPROCESSABLE_ENTITY,"INVALID_AMOUNT"),domain::ValidationError::Country=>ApiError(StatusCode::UNPROCESSABLE_ENTITY,"INVALID_COUNTRY")})?;let id=Uuid::new_v4();let event_id=Uuid::new_v4();let payload=json!({"eventId":event_id,"paymentId":id,"merchantId":value.merchant_id,"amount":value.amount,"country":value.country,"riskScore":value.risk_score,"decision":value.decision});let mut db=state.db.lock().await;let tx=db.transaction().await.map_err(|_|ApiError(StatusCode::INTERNAL_SERVER_ERROR,"DATABASE_ERROR"))?;let row=tx.query_one("WITH inserted AS (INSERT INTO payments(id,merchant_id,amount,country,risk_score,decision,idempotency_key) VALUES($1,$2,$3,$4,$5,$6,$7) ON CONFLICT(idempotency_key) DO NOTHING RETURNING id,merchant_id,amount,country,risk_score,decision,created_at) SELECT true,id::text,merchant_id,amount,country,risk_score,decision,created_at::text FROM inserted UNION ALL SELECT false,id::text,merchant_id,amount,country,risk_score,decision,created_at::text FROM payments WHERE idempotency_key=$7 LIMIT 1",&[&id,&value.merchant_id,&value.amount,&value.country,&value.risk_score,&value.decision,&key]).await.map_err(|_|ApiError(StatusCode::INTERNAL_SERVER_ERROR,"DATABASE_ERROR"))?;let created:bool=row.get(0);if created{tx.execute("INSERT INTO payment_outbox(id,payload) VALUES($1,$2::jsonb)",&[&event_id,&payload.to_string()]).await.map_err(|_|ApiError(StatusCode::INTERNAL_SERVER_ERROR,"DATABASE_ERROR"))?;}tx.commit().await.map_err(|_|ApiError(StatusCode::INTERNAL_SERVER_ERROR,"DATABASE_ERROR"))?;let status=if created{StatusCode::CREATED}else{StatusCode::OK};Ok((status,Json(json!({"id":row.get::<_,String>(1),"merchantId":row.get::<_,String>(2),"amount":row.get::<_,f64>(3),"country":row.get::<_,String>(4),"riskScore":row.get::<_,i32>(5),"decision":row.get::<_,String>(6),"createdAt":row.get::<_,String>(7)}))))}
async fn publish_outbox(state:AppState){loop{tokio::time::sleep(Duration::from_millis(500)).await;let rows=match state.db.lock().await.query("SELECT id,payload::text FROM payment_outbox WHERE published_at IS NULL ORDER BY created_at LIMIT 50",&[]).await{Ok(rows)=>rows,Err(error)=>{error!(%error,"outbox query failed");continue}};for row in rows{let id:Uuid=row.get(0);let payload:String=row.get(1);if state.nats.publish("payment.risk.assessed",payload.into()).await.is_ok(){let _=state.db.lock().await.execute("UPDATE payment_outbox SET published_at=now() WHERE id=$1",&[&id]).await;}}}}
async fn shutdown(){let ctrl_c=async{tokio::signal::ctrl_c().await.expect("signal")};#[cfg(unix)]let terminate=async{tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate()).expect("signal").recv().await;};#[cfg(not(unix))]let terminate=std::future::pending::<()>();tokio::select!{_=ctrl_c=>{},_=terminate=>{}}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/tests/domain.rs' @'
#[path="../src/domain.rs"]mod domain;use domain::{assess,PaymentDraft};#[test]fn scores_large_payment(){let value=assess(PaymentDraft{merchant_id:" merchant-1 ".into(),amount:15000.0,country:"in".into()}).unwrap();assert_eq!(value.merchant_id,"MERCHANT-1");assert_eq!(value.risk_score,55);assert_eq!(value.decision,"step_up")}#[test]fn rejects_negative_amount(){assert!(assess(PaymentDraft{merchant_id:"merchant-1".into(),amount:-1.0,country:"IN".into()}).is_err())}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/Dockerfile' @'
FROM rust:1.97-slim AS build
WORKDIR /src
COPY Cargo.toml ./
COPY src ./src
COPY tests ./tests
RUN cargo test && cargo build --release
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/* && groupadd -g 10001 app && useradd -u 10001 -g app --no-create-home app
ENV RUST_LOG=info LISTEN_ADDRESS=0.0.0.0:8080
COPY --from=build --chown=10001:10001 /src/target/release/payment-risk /usr/local/bin/payment-risk
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["payment-risk"]
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'docker-compose.yml' @'
services:
  postgres:
    image: postgres:16-alpine
    environment: { POSTGRES_USER: "${POSTGRES_USER:-app}", POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-local-development-only}", POSTGRES_DB: "${POSTGRES_DB:-app}" }
    volumes: [postgres-data:/var/lib/postgresql/data]
    healthcheck: { test: ["CMD-SHELL","pg_isready -U ${POSTGRES_USER:-app} -d ${POSTGRES_DB:-app}"], interval: 5s, timeout: 3s, retries: 30 }
    networks: [data]
  nats:
    image: nats:2.11-alpine
    command: ["--jetstream","--store_dir","/data","--http_port","8222"]
    volumes: [nats-data:/data]
    networks: [data]
  app:
    image: ${REGISTRY:-local}/17-rust-payment-risk-service-app:${IMAGE_TAG:-dev}
    build: app
    environment: { DATABASE_URL: "postgres://${POSTGRES_USER:-app}:${POSTGRES_PASSWORD:-local-development-only}@postgres:5432/${POSTGRES_DB:-app}", NATS_URL: "nats://nats:4222", RUST_LOG: "${RUST_LOG:-info}" }
    ports: ["${PUBLIC_PORT:-8097}:8080"]
    depends_on: { postgres: { condition: service_healthy }, nats: { condition: service_started } }
    read_only: true
    tmpfs: [/tmp]
    security_opt: [no-new-privileges:true]
    networks: [edge,data]
networks: { edge: {}, data: { internal: true } }
volumes: { postgres-data: {}, nats-data: {} }
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'scripts/test.sh' @'
#!/usr/bin/env sh
set -eu
docker run --rm -v "$PWD/app:/src" -w /src rust:1.97-slim cargo test
docker compose config --quiet
'@ -WhatIfMode:$WhatIfMode
[pscustomobject]@{Project=$project.Id;Root=$root;Files=$script:Generated.Count}

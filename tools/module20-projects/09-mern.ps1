param([switch]$WhatIfMode)
. (Join-Path $PSScriptRoot 'Common.ps1')

$project=@{
 Id='09-mern-team-collaboration';Title='MERN Team Collaboration Platform';Type='Full-stack two-tier application';Backend='MongoDB / Express 5 / Node.js 24 LTS';Frontend='React 19 / Vite 8';Domain='collaboration';Namespace='collaboration-mern';PublicPort=8089;Entry='api';Ui='frontend';CreatePostgres=$false
 Diagram=@'
flowchart LR
    Team --> React["React delivery board"] --> Nginx["Frontend edge"]
    Nginx --> Express["Express API"]
    Express --> Workspaces["Workspace module"]
    Express --> Tasks["Task workflow module"]
    Express --> Activity["Activity module"]
    Workspaces --> Mongo[(MongoDB replica set)]
    Tasks --> Mongo
    Activity --> Mongo
    Express --> Metrics["Prometheus metrics"]
'@
 Workloads=@(
  @{Name='api';Port=4000;Health='/health';Responsibility='Express API, task workflow rules, MongoDB adapters, and metrics'},
  @{Name='frontend';Port=8080;Health='/health';Responsibility='React collaboration board and same-origin API proxy'}
 )
}

$root=New-CommonProject $project -WhatIfMode:$WhatIfMode

Write-TemplateFile $root '.env.example' @'
PROJECT_NAME=09-mern-team-collaboration
ENVIRONMENT=local
LOG_LEVEL=info
REGISTRY=local
IMAGE_TAG=dev
PUBLIC_PORT=8089
MONGO_USERNAME=app
MONGO_PASSWORD=local-development-only
MONGO_DATABASE=collaboration
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'api/package.json' @'
{"name":"collaboration-api","private":true,"version":"0.1.0","type":"module","scripts":{"start":"node src/server.js","test":"node --test"},"dependencies":{"express":"5.2.1","mongoose":"8.19.1","prom-client":"15.1.3"}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'api/src/domain.js' @'
const statuses=new Set(["backlog","in_progress","review","done"]),priorities=new Set(["low","medium","high"]);export function validateTask(input={}){const title=String(input.title||"").trim(),assignee=String(input.assignee||"Unassigned").trim(),status=String(input.status||"backlog"),priority=String(input.priority||"medium");if(title.length<3||title.length>160)return{ok:false,code:"INVALID_TITLE"};if(assignee.length<2||assignee.length>80)return{ok:false,code:"INVALID_ASSIGNEE"};if(!statuses.has(status))return{ok:false,code:"INVALID_STATUS"};if(!priorities.has(priority))return{ok:false,code:"INVALID_PRIORITY"};return{ok:true,value:{title,assignee,status,priority}}}export function validStatus(value){return statuses.has(value)}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'api/src/server.js' @'
import crypto from"node:crypto";import express from"express";import mongoose from"mongoose";import client from"prom-client";import{validateTask,validStatus}from"./domain.js";
const app=express(),port=Number(process.env.PORT||4000);client.collectDefaultMetrics({prefix:"collaboration_"});const requests=new client.Counter({name:"collaboration_http_requests_total",help:"API HTTP requests",labelNames:["method","route","status"]});
const taskSchema=new mongoose.Schema({title:{type:String,required:true,maxlength:160},assignee:{type:String,required:true,maxlength:80},status:{type:String,enum:["backlog","in_progress","review","done"],required:true},priority:{type:String,enum:["low","medium","high"],required:true},idempotencyKey:{type:String,required:true,unique:true,index:true,maxlength:128}},{timestamps:true,versionKey:false});const Task=mongoose.model("Task",taskSchema);
app.use(express.json({limit:"64kb"}));app.use((req,res,next)=>{req.requestId=req.header("X-Request-ID")||crypto.randomUUID();res.setHeader("X-Request-ID",req.requestId);res.on("finish",()=>requests.inc({method:req.method,route:req.route?.path||req.path,status:String(res.statusCode)}));next()});
app.get("/health",(_q,r)=>mongoose.connection.readyState===1?r.json({status:"ok",service:"collaboration-api"}):r.status(503).json({status:"not_ready"}));app.get("/metrics",async(_q,r)=>r.type(client.register.contentType).send(await client.register.metrics()));
app.get("/api/tasks",async(_q,r,next)=>{try{r.json(await Task.find({}).sort({createdAt:-1}).limit(300).lean())}catch(e){next(e)}});
app.post("/api/tasks",async(q,r,next)=>{const key=q.header("Idempotency-Key");if(!key||key.length>128)return r.status(400).json({code:"IDEMPOTENCY_KEY_REQUIRED"});const parsed=validateTask(q.body);if(!parsed.ok)return r.status(422).json({code:parsed.code});try{const existing=await Task.findOne({idempotencyKey:key}).lean();if(existing)return r.json(existing);return r.status(201).json(await Task.create({...parsed.value,idempotencyKey:key}))}catch(e){if(e?.code===11000){const existing=await Task.findOne({idempotencyKey:key}).lean();return r.json(existing)}next(e)}});
app.patch("/api/tasks/:id/status",async(q,r,next)=>{const status=String(q.body?.status||"");if(!validStatus(status))return r.status(422).json({code:"INVALID_STATUS"});try{const value=await Task.findByIdAndUpdate(q.params.id,{$set:{status}},{new:true,runValidators:true}).lean();return value?r.json(value):r.status(404).json({code:"TASK_NOT_FOUND"})}catch(e){if(e?.name==="CastError")return r.status(404).json({code:"TASK_NOT_FOUND"});next(e)}});
app.use((e,q,r,_n)=>{console.error(JSON.stringify({level:"error",requestId:q.requestId,message:e.message}));r.status(500).json({code:"INTERNAL_ERROR",requestId:q.requestId})});
await mongoose.connect(process.env.MONGO_URI||"mongodb://localhost:27017/collaboration",{serverSelectionTimeoutMS:5000,maxPoolSize:10});app.listen(port,"0.0.0.0",()=>console.log(JSON.stringify({level:"info",service:"collaboration-api",port})));
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'api/test/domain.test.js' @'
import test from"node:test";import assert from"node:assert/strict";import{validateTask,validStatus}from"../src/domain.js";test("normalizes task",()=>assert.deepEqual(validateTask({title:" Deploy release ",assignee:"Asha",priority:"high"}).value,{title:"Deploy release",assignee:"Asha",status:"backlog",priority:"high"}));test("rejects bad status",()=>assert.equal(validStatus("blocked"),false));
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'api/Dockerfile' @'
FROM node:24-alpine
ENV NODE_ENV=production PORT=4000
RUN addgroup -g 10001 app && adduser -D -u 10001 -G app app
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY --chown=app:app src ./src
USER 10001:10001
EXPOSE 4000
HEALTHCHECK --interval=10s --timeout=3s --retries=10 CMD node -e "fetch('http://localhost:4000/health').then(r=>{if(!r.ok)process.exit(1)})"
CMD ["node","src/server.js"]
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'frontend/package.json' @'
{"name":"collaboration-react","private":true,"version":"0.1.0","type":"module","scripts":{"build":"vite build"},"dependencies":{"@vitejs/plugin-react":"6.0.4","vite":"8.1.0","react":"19.2.7","react-dom":"19.2.7"}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/vite.config.js' 'import{defineConfig}from"vite";import react from"@vitejs/plugin-react";export default defineConfig({plugins:[react()]});' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/index.html' '<div id="root"></div><script type="module" src="/src/main.jsx"></script>' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/src/main.jsx' @'
import React,{useEffect,useState}from"react";import{createRoot}from"react-dom/client";import"./style.css";const columns=["backlog","in_progress","review","done"];function App(){const[tasks,setTasks]=useState([]),[message,setMessage]=useState("Ready");async function load(){const r=await fetch("/api/tasks");if(!r.ok)throw Error("Unable to load board");setTasks(await r.json())}useEffect(()=>{load().catch(e=>setMessage(e.message))},[]);async function create(e){e.preventDefault();const f=new FormData(e.currentTarget),r=await fetch("/api/tasks",{method:"POST",headers:{"content-type":"application/json","idempotency-key":crypto.randomUUID()},body:JSON.stringify({title:f.get("title"),assignee:f.get("assignee"),priority:f.get("priority")})});setMessage(r.ok?"Task created":JSON.stringify(await r.json()));if(r.ok){e.currentTarget.reset();await load()}}async function move(task){const next=columns[(columns.indexOf(task.status)+1)%columns.length],r=await fetch(`/api/tasks/${task._id}/status`,{method:"PATCH",headers:{"content-type":"application/json"},body:JSON.stringify({status:next})});if(r.ok)await load()}return <main><header><p>NORTHSTAR DELIVERY</p><h1>Make work visible.<br/>Move it forward.</h1><output>{message}</output></header><form onSubmit={create}><input name="title" placeholder="Task" required/><input name="assignee" placeholder="Assignee" required/><select name="priority"><option>low</option><option>medium</option><option>high</option></select><button>Add task</button></form><div className="board">{columns.map(column=><section key={column}><h2>{column.replace("_"," ")}</h2>{tasks.filter(x=>x.status===column).map(task=><article key={task._id} onClick={()=>move(task)} tabIndex="0"><span>{task.priority}</span><h3>{task.title}</h3><p>{task.assignee}</p></article>)}</section>)}</div></main>}createRoot(document.getElementById("root")).render(<App/>);
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/src/style.css' @'
:root{font-family:Inter,system-ui;color:#e9f1ff;background:#0c1220}*{box-sizing:border-box}body{margin:0}main{padding:3rem;max-width:1500px;margin:auto}header p{color:#75e6da;letter-spacing:.2em;font-weight:800}h1{font-size:clamp(2.5rem,6vw,5.5rem);line-height:.95;margin:.4rem 0 1rem}form{display:flex;gap:.5rem;margin:2rem 0;padding:.7rem;background:#17233b;border:1px solid #2b416a}input,select,button{padding:.8rem;border:0;background:#e9f1ff;color:#0c1220}input:first-child{flex:1}button{background:#75e6da;font-weight:800}.board{display:grid;grid-template-columns:repeat(4,1fr);gap:.8rem}section{background:#111a2d;padding:.8rem;min-height:360px;border-top:4px solid #75e6da}section h2{text-transform:uppercase;font-size:.8rem;letter-spacing:.12em}article{background:#1b2945;padding:1rem;margin:.7rem 0;cursor:pointer;box-shadow:0 6px 15px #0003}article span{color:#ffcb77;text-transform:uppercase;font-size:.7rem}article h3{margin:.5rem 0}@media(max-width:900px){.board{grid-template-columns:1fr 1fr}}@media(max-width:580px){main{padding:1.2rem}.board{grid-template-columns:1fr}form{flex-direction:column}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/nginx.conf' @'
server { listen 8080; root /usr/share/nginx/html; location = /health { default_type application/json; return 200 '{"status":"ok","service":"frontend"}'; } location /api/ { proxy_pass ${API_URL}/api/; proxy_set_header X-Request-ID $request_id; } location / { try_files $uri /index.html; } }
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/Dockerfile' @'
FROM node:24-alpine AS build
WORKDIR /src
COPY package*.json ./
RUN npm ci --no-audit --no-fund
COPY . ./
RUN npm run build
FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /src/dist /usr/share/nginx/html
EXPOSE 8080
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'docker-compose.yml' @'
services:
  mongo:
    image: mongo:8.0
    environment: { MONGO_INITDB_ROOT_USERNAME: "${MONGO_USERNAME:-app}", MONGO_INITDB_ROOT_PASSWORD: "${MONGO_PASSWORD:-local-development-only}", MONGO_INITDB_DATABASE: "${MONGO_DATABASE:-collaboration}" }
    volumes: [mongo-data:/data/db]
    healthcheck: { test: ["CMD","mongosh","--quiet","--username","${MONGO_USERNAME:-app}","--password","${MONGO_PASSWORD:-local-development-only}","--authenticationDatabase","admin","--eval","db.adminCommand('ping').ok"], interval: 5s, timeout: 4s, retries: 30 }
    networks: [data]
  api:
    image: ${REGISTRY:-local}/09-mern-team-collaboration-api:${IMAGE_TAG:-dev}
    build: { context: api }
    environment: { PORT: 4000, MONGO_URI: "mongodb://${MONGO_USERNAME:-app}:${MONGO_PASSWORD:-local-development-only}@mongo:27017/${MONGO_DATABASE:-collaboration}?authSource=admin" }
    depends_on: { mongo: { condition: service_healthy } }
    healthcheck: { test: ["CMD","node","-e","fetch('http://localhost:4000/health').then(r=>{if(!r.ok)process.exit(1)})"], interval: 5s, timeout: 3s, retries: 20 }
    read_only: true
    tmpfs: [/tmp]
    security_opt: [no-new-privileges:true]
    networks: [backend,data]
  frontend:
    image: ${REGISTRY:-local}/09-mern-team-collaboration-frontend:${IMAGE_TAG:-dev}
    build: { context: frontend }
    environment: { API_URL: http://api:4000 }
    ports: ["${PUBLIC_PORT:-8089}:8080"]
    depends_on: { api: { condition: service_healthy } }
    read_only: true
    tmpfs: [/tmp,/var/cache/nginx,/var/run]
    security_opt: [no-new-privileges:true]
    networks: [edge,backend]
networks: { edge: {}, backend: { internal: true }, data: { internal: true } }
volumes: { mongo-data: {} }
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'k8s/base/secret.example.yaml' @'
apiVersion: v1
kind: Secret
metadata: { name: collaboration-runtime, namespace: collaboration-mern, annotations: { template.devops.example/local-placeholders-only: "true" } }
type: Opaque
stringData:
  MONGO_URI: mongodb://replace-with-managed-mongodb-connection/collaboration
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'k8s/overlays/dev/secret.local.yaml' @'
apiVersion: v1
kind: Secret
metadata: { name: collaboration-runtime, namespace: collaboration-mern, annotations: { template.devops.example/local-placeholders-only: "true" } }
type: Opaque
stringData:
  MONGO_URI: mongodb://mongo.mongodb.svc.cluster.local:27017/collaboration
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'docs/MONGODB-OPERATIONS.md' @'
# MongoDB operations contract

Compose runs one MongoDB node only for local learning. Production requires an intentionally operated replica set or managed service, private connectivity, TLS, workload identity/rotated credentials, least-privilege database roles, point-in-time recovery, tested restores, capacity alerts, index review, and a documented upgrade path.

Kubernetes manifests expect `MONGO_URI` from an approved external secret. They intentionally do not install a production database into the application namespace. Set Terraform `create_postgres = false`; integrate an approved MongoDB service through a separately reviewed infrastructure module.
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'terraform/terraform.tfvars.example' @'
project_name = "collaboration"
environment  = "dev"
aws_region   = "us-east-1"
vpc_cidr     = "10.40.0.0/16"
kubernetes_version = "1.36" # verify current regional EKS support
cluster_endpoint_public_access = false
node_instance_types = ["m6i.large"]
create_postgres = false # connect an approved managed MongoDB service separately
tags = { Owner = "replace-with-owner", CostCenter = "replace-with-cost-center", DataClass = "internal" }
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'scripts/test.sh' @'
#!/usr/bin/env sh
set -eu
node --check api/src/domain.js
node --check api/src/server.js
node --test api/test/*.test.js
docker compose config --quiet
'@ -WhatIfMode:$WhatIfMode

[pscustomobject]@{Project=$project.Id;Root=$root;Files=$script:Generated.Count}

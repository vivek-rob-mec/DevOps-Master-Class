param([switch]$WhatIfMode)
. (Join-Path $PSScriptRoot 'Common.ps1')
$project=@{
 Id='03-node-booking-microservices';Title='Node.js Booking Microservices Platform';Type='Microservices';Backend='Node.js 24 LTS / Express 5';Frontend='Next.js 16 / React 19';Domain='booking';Namespace='booking-node';PublicPort=8083;Entry='gateway';Ui='frontend'
 Diagram=@'
flowchart LR
    User --> Next["Next.js frontend"] --> Gateway["Node gateway"]
    Gateway --> Booking["Booking service"]
    Booking --> Notify["Notification service"]
    Booking --> BookingDB[("Booking state")]
    Notify --> Provider["Delivery provider"]
    Gateway --> Observe["Prometheus metrics"]
'@
 Workloads=@(
  @{Name='gateway';Port=3000;Health='/health';Responsibility='Public API and routing'},
  @{Name='booking';Port=3001;Health='/health';Responsibility='Idempotent booking lifecycle'},
  @{Name='notification';Port=3002;Health='/health';Responsibility='Notification delivery abstraction'},
  @{Name='frontend';Port=3000;Health='/health';Responsibility='Next.js traveler experience'}
 )
}
$root=New-CommonProject $project -WhatIfMode:$WhatIfMode
$package=@'
{"name":"@@SERVICE@@","private":true,"version":"0.1.0","type":"module","scripts":{"start":"node src/index.js","test":"node --test"},"dependencies":{"cors":"2.8.6","express":"5.2.1","prom-client":"15.1.3"}}
'@
$docker=@'
FROM node:24-alpine
ENV NODE_ENV=production
RUN addgroup -g 10001 app && adduser -D -u 10001 -G app app
WORKDIR /app
COPY package*.json .
RUN npm ci --omit=dev --no-audit --no-fund
COPY src ./src
RUN chown -R app:app /app
USER 10001:10001
EXPOSE @@SERVICE_PORT@@
CMD ["node","src/index.js"]
'@
foreach($s in @(@{Name='gateway';Port=3000},@{Name='booking';Port=3001},@{Name='notification';Port=3002})){
 $x=@{SERVICE="node-$($s.Name)-service";SERVICE_PORT=$s.Port};Write-TemplateFile $root "services/$($s.Name)/package.json" (Expand-ProjectTemplate $package $x) -WhatIfMode:$WhatIfMode;Write-TemplateFile $root "services/$($s.Name)/Dockerfile" (Expand-ProjectTemplate $docker $x) -WhatIfMode:$WhatIfMode;Write-TemplateFile $root "services/$($s.Name)/.dockerignore" 'node_modules/' -WhatIfMode:$WhatIfMode
}
Write-TemplateFile $root 'services/gateway/src/index.js' @'
import crypto from"node:crypto";import cors from"cors";import express from"express";import client from"prom-client";
const app=express(),port=Number(process.env.PORT||3000),booking=process.env.BOOKING_URL||"http://booking:3001";client.collectDefaultMetrics({prefix:"gateway_"});const requests=new client.Counter({name:"http_requests_total",help:"HTTP requests",labelNames:["service","method","route","status"]});
app.use(cors());app.use(express.json({limit:"64kb"}));app.use((req,res,next)=>{req.requestId=req.header("X-Request-ID")||crypto.randomUUID();res.setHeader("X-Request-ID",req.requestId);res.on("finish",()=>requests.inc({service:"gateway",method:req.method,route:req.path,status:String(res.statusCode)}));next()});
async function proxy(req,res,path){try{const response=await fetch(`${booking}${path}`,{method:req.method,headers:{"content-type":"application/json","x-request-id":req.requestId,"idempotency-key":req.header("Idempotency-Key")||""},body:req.method==="GET"?undefined:JSON.stringify(req.body),signal:AbortSignal.timeout(3000)});res.status(response.status).type(response.headers.get("content-type")||"application/json").send(await response.text())}catch(error){res.status(503).json({code:"BOOKING_UNAVAILABLE",message:error.message,requestId:req.requestId,retryable:true})}}
app.get("/health",(_q,r)=>r.json({status:"ok",service:"gateway"}));app.get("/metrics",async(_q,r)=>r.type(client.register.contentType).send(await client.register.metrics()));app.get("/api/bookings",(q,r)=>proxy(q,r,"/bookings"));app.post("/api/bookings",(q,r)=>q.header("Idempotency-Key")?proxy(q,r,"/bookings"):r.status(400).json({code:"IDEMPOTENCY_KEY_REQUIRED",retryable:false}));app.listen(port,"0.0.0.0",()=>console.log(JSON.stringify({level:"info",service:"gateway",port})));
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'services/booking/src/index.js' @'
import crypto from"node:crypto";import express from"express";import client from"prom-client";
const app=express(),port=Number(process.env.PORT||3001),notify=process.env.NOTIFICATION_URL||"http://notification:3002",data=new Map(),keys=new Map();client.collectDefaultMetrics({prefix:"booking_"});const requests=new client.Counter({name:"http_requests_total",help:"HTTP requests",labelNames:["service","method","route","status"]});app.use(express.json({limit:"64kb"}));app.use((q,r,n)=>{r.on("finish",()=>requests.inc({service:"booking",method:q.method,route:q.path,status:String(r.statusCode)}));n()});
app.get("/health",(_q,r)=>r.json({status:"ok",service:"booking"}));app.get("/metrics",async(_q,r)=>r.type(client.register.contentType).send(await client.register.metrics()));app.get("/bookings",(_q,r)=>r.json([...data.values()]));app.post("/bookings",async(q,r)=>{const key=q.header("Idempotency-Key");if(!key)return r.status(400).json({code:"IDEMPOTENCY_KEY_REQUIRED"});if(keys.has(key))return r.json(data.get(keys.get(key)));const{travelerEmail,destination,seats}=q.body||{};if(!travelerEmail||!destination||!Number.isInteger(seats)||seats<1||seats>9)return r.status(422).json({code:"INVALID_BOOKING"});const value={id:crypto.randomUUID(),travelerEmail,destination,seats,status:"confirmed",createdAt:new Date().toISOString()};data.set(value.id,value);keys.set(key,value.id);try{await fetch(`${notify}/notifications`,{method:"POST",headers:{"content-type":"application/json","x-event-id":value.id},body:JSON.stringify({recipient:travelerEmail,reference:value.id}),signal:AbortSignal.timeout(1500)})}catch(error){console.error(JSON.stringify({level:"warn",code:"NOTIFICATION_DEFERRED",message:error.message}))}return r.status(201).json(value)});app.listen(port,"0.0.0.0");
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'services/notification/src/index.js' @'
import express from"express";import client from"prom-client";const app=express(),port=Number(process.env.PORT||3002),data=new Map();client.collectDefaultMetrics({prefix:"notification_"});app.use(express.json({limit:"64kb"}));app.get("/health",(_q,r)=>r.json({status:"ok",service:"notification"}));app.get("/metrics",async(_q,r)=>r.type(client.register.contentType).send(await client.register.metrics()));app.get("/notifications",(_q,r)=>r.json([...data.values()]));app.post("/notifications",(q,r)=>{const id=q.header("X-Event-ID");if(!id)return r.status(400).json({code:"EVENT_ID_REQUIRED"});if(data.has(id))return r.json(data.get(id));const value={id,...q.body,status:"accepted",acceptedAt:new Date().toISOString()};data.set(id,value);console.log(JSON.stringify({level:"info",service:"notification",eventId:id}));return r.status(202).json(value)});app.listen(port,"0.0.0.0");
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/package.json' '{"name":"booking-next","private":true,"version":"0.1.0","scripts":{"build":"next build","start":"next start"},"dependencies":{"next":"16.2.11","react":"19.2.7","react-dom":"19.2.7"}}' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/.dockerignore' "node_modules/`n.next/" -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/next.config.js' @'
const nextConfig={output:"standalone",async rewrites(){const gateway=process.env.GATEWAY_URL||"http://gateway:3000";return[{source:"/health",destination:`${gateway}/health`},{source:"/api/:path*",destination:`${gateway}/api/:path*`}];}};module.exports=nextConfig;
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/pages/index.js' @'
import{useEffect,useState}from"react";export default function Home(){const[data,setData]=useState([]),[message,setMessage]=useState("Ready");async function load(){setData(await(await fetch("/api/bookings")).json())}useEffect(()=>{load().catch(e=>setMessage(e.message))},[]);async function submit(e){e.preventDefault();const f=new FormData(e.currentTarget),r=await fetch("/api/bookings",{method:"POST",headers:{"Content-Type":"application/json","Idempotency-Key":crypto.randomUUID()},body:JSON.stringify({travelerEmail:f.get("email"),destination:f.get("destination"),seats:Number(f.get("seats"))})});setMessage(JSON.stringify(await r.json()));if(r.ok)await load()}return <main><h1>Booking Platform</h1><p>{message}</p><form onSubmit={submit}><input name="email" type="email" defaultValue="traveler@example.com"/><input name="destination" defaultValue="Bengaluru"/><input name="seats" type="number" defaultValue="1"/><button>Book</button></form><ul>{data.map(x=><li key={x.id}>{x.destination} - {x.status}</li>)}</ul></main>}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/Dockerfile' @'
FROM node:24-alpine AS build
WORKDIR /app
COPY package*.json .
RUN npm ci --no-audit --no-fund
COPY . .
RUN npm run build
FROM node:24-alpine
ENV NODE_ENV=production PORT=3000 HOSTNAME=0.0.0.0
RUN addgroup -g 10001 app && adduser -D -u 10001 -G app app
WORKDIR /app
COPY --from=build --chown=app:app /app/.next/standalone ./
COPY --from=build --chown=app:app /app/.next/static ./.next/static
USER 10001:10001
EXPOSE 3000
CMD ["node","server.js"]
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'docker-compose.yml' @'
services:
  notification:
    image: ${REGISTRY:-local}/03-node-booking-microservices-notification:${IMAGE_TAG:-dev}
    build: { context: services/notification }
    environment: { PORT: 3002 }
    healthcheck: { test: ["CMD","node","-e","fetch('http://localhost:3002/health').then(r=>{if(!r.ok)process.exit(1)})"], interval: 5s, timeout: 2s, retries: 20 }
    networks: [backend]
  booking:
    image: ${REGISTRY:-local}/03-node-booking-microservices-booking:${IMAGE_TAG:-dev}
    build: { context: services/booking }
    environment: { PORT: 3001, NOTIFICATION_URL: http://notification:3002 }
    depends_on: { notification: { condition: service_healthy } }
    healthcheck: { test: ["CMD","node","-e","fetch('http://localhost:3001/health').then(r=>{if(!r.ok)process.exit(1)})"], interval: 5s, timeout: 2s, retries: 20 }
    networks: [backend]
  gateway:
    image: ${REGISTRY:-local}/03-node-booking-microservices-gateway:${IMAGE_TAG:-dev}
    build: { context: services/gateway }
    environment: { PORT: 3000, BOOKING_URL: http://booking:3001 }
    depends_on: { booking: { condition: service_healthy } }
    healthcheck: { test: ["CMD","node","-e","fetch('http://localhost:3000/health').then(r=>{if(!r.ok)process.exit(1)})"], interval: 5s, timeout: 2s, retries: 20 }
    networks: [backend,edge]
  frontend:
    image: ${REGISTRY:-local}/03-node-booking-microservices-frontend:${IMAGE_TAG:-dev}
    build: { context: frontend }
    environment: { GATEWAY_URL: http://gateway:3000 }
    ports: ["${PUBLIC_PORT:-8083}:3000"]
    depends_on: { gateway: { condition: service_healthy } }
    networks: [edge]
networks: { edge: {}, backend: { internal: true } }
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'scripts/test.sh' @'
#!/usr/bin/env sh
set -eu
for file in services/*/src/*.js;do node --check "$file";done
docker compose config --quiet
'@ -WhatIfMode:$WhatIfMode
[pscustomobject]@{Project=$project.Id;Root=$root;Files=$script:Generated.Count}

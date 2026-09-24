param([switch]$WhatIfMode)
. (Join-Path $PSScriptRoot 'Common.ps1')

$project=@{
 Id='06-node-helpdesk-monolith';Title='Node.js Helpdesk Modular Monolith';Type='Modular monolith';Backend='Node.js 24 LTS / Express 5 / PostgreSQL';Frontend='React 19 / Vite 8';Domain='helpdesk';Namespace='helpdesk-node';PublicPort=8086;Entry='app';Ui='app'
 Diagram=@'
flowchart LR
    Agent --> UI["React support console"] --> HTTP["Express HTTP adapters"]
    HTTP --> Tickets["Ticket module"]
    HTTP --> SLA["SLA module"]
    HTTP --> Audit["Audit module"]
    Tickets --> Domain["Domain rules"]
    SLA --> Domain
    Audit --> Domain
    Domain --> PG[(PostgreSQL)]
    HTTP --> Metrics["Prometheus metrics"]
'@
 Workloads=@(
  @{Name='app';Port=3000;Health='/health';Responsibility='React UI, ticket/SLA/audit modules, HTTP API, and persistence adapters in one deployable unit'}
 )
}

$root=New-CommonProject $project -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'app/package.json' @'
{"name":"node-helpdesk-monolith","private":true,"version":"0.1.0","type":"module","scripts":{"start":"node src/server.js","test":"node --test"},"dependencies":{"express":"5.2.1","pg":"8.16.3","prom-client":"15.1.3"}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/src/domain.js' @'
const priorities=new Set(["low","medium","high","critical"]);
export function validateTicket(input={}){const title=String(input.title||"").trim(),customerEmail=String(input.customerEmail||"").trim().toLowerCase(),priority=String(input.priority||"medium");if(title.length<3||title.length>160)return{ok:false,code:"INVALID_TITLE"};if(!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(customerEmail))return{ok:false,code:"INVALID_EMAIL"};if(!priorities.has(priority))return{ok:false,code:"INVALID_PRIORITY"};return{ok:true,value:{title,customerEmail,priority}}}
export function calculateDueAt(priority,now=new Date()){const minutes={critical:30,high:240,medium:1440,low:4320}[priority];return new Date(now.getTime()+minutes*60000).toISOString()}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/src/server.js' @'
import crypto from"node:crypto";import path from"node:path";import{fileURLToPath}from"node:url";import express from"express";import pg from"pg";import client from"prom-client";import{calculateDueAt,validateTicket}from"./domain.js";
const{Pool}=pg,app=express(),port=Number(process.env.PORT||3000),pool=new Pool({connectionString:process.env.DATABASE_URL,connectionTimeoutMillis:3000,max:10}),webRoot=process.env.WEB_ROOT||path.resolve(path.dirname(fileURLToPath(import.meta.url)),"../../public");
client.collectDefaultMetrics({prefix:"helpdesk_"});const requests=new client.Counter({name:"helpdesk_http_requests_total",help:"Helpdesk HTTP requests",labelNames:["method","route","status"]});
app.use(express.json({limit:"64kb"}));app.use((req,res,next)=>{req.requestId=req.header("X-Request-ID")||crypto.randomUUID();res.setHeader("X-Request-ID",req.requestId);res.on("finish",()=>requests.inc({method:req.method,route:req.route?.path||req.path,status:String(res.statusCode)}));next()});
async function migrate(){await pool.query(`CREATE TABLE IF NOT EXISTS tickets(id uuid PRIMARY KEY,title varchar(160) NOT NULL,customer_email varchar(254) NOT NULL,priority varchar(16) NOT NULL,status varchar(24) NOT NULL,due_at timestamptz NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),idempotency_key varchar(128) UNIQUE NOT NULL);CREATE TABLE IF NOT EXISTS ticket_audit(id bigserial PRIMARY KEY,ticket_id uuid NOT NULL REFERENCES tickets(id),action varchar(64) NOT NULL,created_at timestamptz NOT NULL DEFAULT now())`)}
app.get("/health",async(_q,r)=>{try{await pool.query("SELECT 1");r.json({status:"ok",service:"helpdesk-app"})}catch{r.status(503).json({status:"not_ready"})}});app.get("/metrics",async(_q,r)=>r.type(client.register.contentType).send(await client.register.metrics()));
app.get("/api/tickets",async(_q,r,next)=>{try{const result=await pool.query("SELECT id,title,customer_email AS \"customerEmail\",priority,status,due_at AS \"dueAt\",created_at AS \"createdAt\" FROM tickets ORDER BY created_at DESC LIMIT 200");r.json(result.rows)}catch(e){next(e)}});
app.post("/api/tickets",async(q,r,next)=>{const key=q.header("Idempotency-Key");if(!key||key.length>128)return r.status(400).json({code:"IDEMPOTENCY_KEY_REQUIRED"});const validated=validateTicket(q.body);if(!validated.ok)return r.status(422).json({code:validated.code});const db=await pool.connect();try{await db.query("BEGIN");const existing=await db.query("SELECT id,title,customer_email AS \"customerEmail\",priority,status,due_at AS \"dueAt\",created_at AS \"createdAt\" FROM tickets WHERE idempotency_key=$1",[key]);if(existing.rowCount){await db.query("COMMIT");return r.json(existing.rows[0])}const value=validated.value,id=crypto.randomUUID(),created=await db.query("INSERT INTO tickets(id,title,customer_email,priority,status,due_at,idempotency_key) VALUES($1,$2,$3,$4,'open',$5,$6) ON CONFLICT(idempotency_key) DO NOTHING RETURNING id,title,customer_email AS \"customerEmail\",priority,status,due_at AS \"dueAt\",created_at AS \"createdAt\"",[id,value.title,value.customerEmail,value.priority,calculateDueAt(value.priority),key]);if(!created.rowCount){const raced=await db.query("SELECT id,title,customer_email AS \"customerEmail\",priority,status,due_at AS \"dueAt\",created_at AS \"createdAt\" FROM tickets WHERE idempotency_key=$1",[key]);await db.query("COMMIT");return r.json(raced.rows[0])}await db.query("INSERT INTO ticket_audit(ticket_id,action) VALUES($1,'created')",[id]);await db.query("COMMIT");return r.status(201).json(created.rows[0])}catch(e){await db.query("ROLLBACK");next(e)}finally{db.release()}});
app.patch("/api/tickets/:id/status",async(q,r,next)=>{const status=String(q.body?.status||"");if(!["open","in_progress","resolved"].includes(status))return r.status(422).json({code:"INVALID_STATUS"});try{const result=await pool.query("UPDATE tickets SET status=$1 WHERE id=$2 RETURNING id,title,customer_email AS \"customerEmail\",priority,status,due_at AS \"dueAt\",created_at AS \"createdAt\"",[status,q.params.id]);if(!result.rowCount)return r.status(404).json({code:"TICKET_NOT_FOUND"});await pool.query("INSERT INTO ticket_audit(ticket_id,action) VALUES($1,$2)",[q.params.id,`status:${status}`]);r.json(result.rows[0])}catch(e){next(e)}});
app.use(express.static(webRoot,{index:false,maxAge:"1h"}));app.get("/{*path}",(q,r,next)=>q.path.startsWith("/api/")?next():r.sendFile(path.join(webRoot,"index.html")));app.use((e,q,r,_n)=>{console.error(JSON.stringify({level:"error",requestId:q.requestId,message:e.message}));r.status(500).json({code:"INTERNAL_ERROR",requestId:q.requestId})});
await migrate();app.listen(port,"0.0.0.0",()=>console.log(JSON.stringify({level:"info",service:"helpdesk-app",port})));
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/test/domain.test.js' @'
import test from"node:test";import assert from"node:assert/strict";import{calculateDueAt,validateTicket}from"../src/domain.js";
test("normalizes a valid ticket",()=>assert.deepEqual(validateTicket({title:" Login failure ",customerEmail:"USER@EXAMPLE.COM",priority:"high"}).value,{title:"Login failure",customerEmail:"user@example.com",priority:"high"}));
test("rejects unsupported priority",()=>assert.equal(validateTicket({title:"Login failure",customerEmail:"u@example.com",priority:"urgent"}).code,"INVALID_PRIORITY"));
test("critical SLA is thirty minutes",()=>assert.equal(calculateDueAt("critical",new Date("2026-01-01T00:00:00Z")),"2026-01-01T00:30:00.000Z"));
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'frontend/package.json' @'
{"name":"helpdesk-react","private":true,"version":"0.1.0","type":"module","scripts":{"build":"vite build"},"dependencies":{"@vitejs/plugin-react":"6.0.4","vite":"8.1.0","react":"19.2.7","react-dom":"19.2.7"}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/vite.config.js' 'import{defineConfig}from"vite";import react from"@vitejs/plugin-react";export default defineConfig({plugins:[react()]});' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/index.html' '<div id="root"></div><script type="module" src="/src/main.jsx"></script>' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/src/main.jsx' @'
import React,{useEffect,useState}from"react";import{createRoot}from"react-dom/client";import"./style.css";function App(){const[tickets,setTickets]=useState([]),[message,setMessage]=useState("Ready");async function load(){const r=await fetch("/api/tickets");if(!r.ok)throw Error("Unable to load tickets");setTickets(await r.json())}useEffect(()=>{load().catch(e=>setMessage(e.message))},[]);async function submit(e){e.preventDefault();const f=new FormData(e.currentTarget),r=await fetch("/api/tickets",{method:"POST",headers:{"Content-Type":"application/json","Idempotency-Key":crypto.randomUUID()},body:JSON.stringify({title:f.get("title"),customerEmail:f.get("email"),priority:f.get("priority")})});setMessage(r.ok?"Ticket created":JSON.stringify(await r.json()));if(r.ok){e.currentTarget.reset();await load()}}return <main><header><p className="eyebrow">OPERATIONS DESK</p><h1>Customer support, without losing the thread.</h1><p>{message}</p></header><form onSubmit={submit}><input name="title" placeholder="What needs attention?" required/><input name="email" type="email" placeholder="customer@example.com" required/><select name="priority" defaultValue="medium"><option>low</option><option>medium</option><option>high</option><option>critical</option></select><button>Create ticket</button></form><section>{tickets.map(x=><article key={x.id}><span className={`priority ${x.priority}`}>{x.priority}</span><h2>{x.title}</h2><p>{x.customerEmail}</p><small>{x.status} - due {new Date(x.dueAt).toLocaleString()}</small></article>)}</section></main>}createRoot(document.getElementById("root")).render(<App/>);
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/src/style.css' @'
:root{font-family:Inter,ui-sans-serif,system-ui;color:#17223b;background:#f1efe8}*{box-sizing:border-box}body{margin:0}main{max-width:1100px;margin:auto;padding:4rem 2rem}.eyebrow{letter-spacing:.18em;color:#cf5c36;font-weight:800}h1{max-width:720px;font:700 clamp(2.5rem,7vw,5rem)/.96 Georgia,serif}form{display:grid;grid-template-columns:2fr 1fr 1fr auto;gap:.7rem;padding:1rem;background:#17223b;border-radius:16px}input,select,button{padding:.9rem;border:0;border-radius:8px}button{background:#f2c14e;font-weight:800}section{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:1rem;margin-top:2rem}article{background:#fff;padding:1.25rem;border-left:5px solid #528b8b;box-shadow:0 8px 24px #17223b12}.priority{text-transform:uppercase;font-size:.72rem;font-weight:800}.priority.critical{color:#b42318}.priority.high{color:#cf5c36}small{color:#65708a}@media(max-width:760px){form{grid-template-columns:1fr}}
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'Dockerfile' @'
FROM node:24-alpine AS frontend
WORKDIR /src
COPY frontend/package*.json ./
RUN npm ci --no-audit --no-fund
COPY frontend/ ./
RUN npm run build

FROM node:24-alpine AS dependencies
ENV NODE_ENV=production
WORKDIR /app
COPY app/package*.json ./
RUN npm ci --omit=dev --no-audit --no-fund

FROM node:24-alpine
ENV NODE_ENV=production PORT=3000 WEB_ROOT=/app/public
RUN addgroup -g 10001 app && adduser -D -u 10001 -G app app
WORKDIR /app
COPY --from=dependencies --chown=app:app /app/node_modules ./node_modules
COPY --chown=app:app app/package.json ./
COPY --chown=app:app app/src ./src
COPY --from=frontend --chown=app:app /src/dist ./public
USER 10001:10001
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=3s --retries=10 CMD node -e "fetch('http://localhost:3000/health').then(r=>{if(!r.ok)process.exit(1)})"
CMD ["node","src/server.js"]
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'docker-compose.yml' @'
services:
  postgres:
    image: postgres:16-alpine
    environment: { POSTGRES_USER: "${POSTGRES_USER:-app}", POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-local-development-only}", POSTGRES_DB: "${POSTGRES_DB:-app}" }
    volumes: [postgres-data:/var/lib/postgresql/data]
    healthcheck: { test: ["CMD-SHELL","pg_isready -U ${POSTGRES_USER:-app} -d ${POSTGRES_DB:-app}"], interval: 5s, timeout: 3s, retries: 20 }
    networks: [data]
  app:
    image: ${REGISTRY:-local}/06-node-helpdesk-monolith-app:${IMAGE_TAG:-dev}
    build: .
    environment: { PORT: 3000, DATABASE_URL: "postgresql://${POSTGRES_USER:-app}:${POSTGRES_PASSWORD:-local-development-only}@postgres:5432/${POSTGRES_DB:-app}" }
    ports: ["${PUBLIC_PORT:-8086}:3000"]
    depends_on: { postgres: { condition: service_healthy } }
    read_only: true
    tmpfs: [/tmp]
    security_opt: [no-new-privileges:true]
    networks: [edge,data]
networks: { edge: {}, data: { internal: true } }
volumes: { postgres-data: {} }
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'scripts/test.sh' @'
#!/usr/bin/env sh
set -eu
node --check app/src/domain.js
node --check app/src/server.js
node --test app/test/*.test.js
docker compose config --quiet
'@ -WhatIfMode:$WhatIfMode

[pscustomobject]@{Project=$project.Id;Root=$root;Files=$script:Generated.Count}

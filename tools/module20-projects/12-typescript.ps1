param([switch]$WhatIfMode)
. (Join-Path $PSScriptRoot 'Common.ps1')
$project=@{
 Id='12-typescript-nestjs-angular-saas';Title='TypeScript B2B SaaS Platform';Type='Two-tier enterprise web application';Backend='Node.js 24 / NestJS 11 / PostgreSQL';Frontend='Angular 22 / TypeScript 6';Domain='saas';Namespace='saas-typescript';PublicPort=8091;Entry='api';Ui='frontend'
 Diagram=@'
flowchart LR
    User --> Angular["Angular account workspace"] --> Edge["Nginx edge"]
    Edge --> Nest["NestJS API"]
    Nest --> Tenant["Tenant module"]
    Nest --> Subscription["Subscription module"]
    Nest --> Audit["Audit module"]
    Tenant --> PG[(PostgreSQL)]
    Subscription --> PG
    Audit --> PG
    Nest --> Metrics["Prometheus metrics"]
'@
 Workloads=@(
  @{Name='api';Port=3000;Health='/health';Responsibility='NestJS tenant/subscription API, PostgreSQL adapter, and metrics'},
  @{Name='frontend';Port=8080;Health='/health';Responsibility='Angular account workspace and same-origin API proxy'}
 )
}
$root=New-CommonProject $project -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'api/package.json' @'
{"name":"saas-nest-api","private":true,"version":"0.1.0","scripts":{"build":"tsc -p tsconfig.json","start":"node dist/main.js","test":"node --import tsx --test test/*.test.ts"},"dependencies":{"@nestjs/common":"11.1.6","@nestjs/core":"11.1.6","@nestjs/platform-express":"11.1.6","pg":"8.16.3","prom-client":"15.1.3","reflect-metadata":"0.2.2","rxjs":"7.8.2"},"devDependencies":{"@types/node":"24.10.1","@types/pg":"8.15.6","tsx":"4.20.6","typescript":"5.9.3"}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'api/tsconfig.json' @'
{"compilerOptions":{"target":"ES2023","module":"NodeNext","moduleResolution":"NodeNext","outDir":"dist","rootDir":"src","strict":true,"experimentalDecorators":true,"emitDecoratorMetadata":true,"esModuleInterop":true,"skipLibCheck":true},"include":["src/**/*.ts"]}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'api/src/domain.ts' @'
export type Plan="starter"|"growth"|"enterprise";const plans=new Set<Plan>(["starter","growth","enterprise"]);export function parseTenant(input:Record<string,unknown>){const name=String(input.name??"").trim(),ownerEmail=String(input.ownerEmail??"").trim().toLowerCase(),plan=String(input.plan??"starter") as Plan;if(name.length<2||name.length>120)throw Error("INVALID_NAME");if(!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(ownerEmail))throw Error("INVALID_EMAIL");if(!plans.has(plan))throw Error("INVALID_PLAN");return{name,ownerEmail,plan}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'api/src/main.ts' @'
import"reflect-metadata";import{randomUUID}from"node:crypto";import{Controller,Get,Post,Body,Headers,HttpException,HttpStatus,Injectable,Module}from"@nestjs/common";import{NestFactory}from"@nestjs/core";import{Pool}from"pg";import{collectDefaultMetrics,Counter,register}from"prom-client";import{parseTenant}from"./domain.js";
type Tenant={id:string,name:string,ownerEmail:string,plan:string,createdAt:Date};@Injectable()class TenantService{private readonly db=new Pool({connectionString:process.env.DATABASE_URL,connectionTimeoutMillis:3000,max:10});async init(){await this.db.query(`CREATE TABLE IF NOT EXISTS tenants(id uuid PRIMARY KEY,name varchar(120) NOT NULL,owner_email varchar(254) NOT NULL,plan varchar(24) NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),idempotency_key varchar(128) UNIQUE NOT NULL)`)}async health(){await this.db.query("SELECT 1")}async list(){return(await this.db.query(`SELECT id,name,owner_email AS "ownerEmail",plan,created_at AS "createdAt" FROM tenants ORDER BY created_at DESC LIMIT 200`)).rows as Tenant[]}async create(raw:Record<string,unknown>,key:string){if(!key||key.length>128)throw new HttpException({code:"IDEMPOTENCY_KEY_REQUIRED"},400);let value;try{value=parseTenant(raw)}catch(error){throw new HttpException({code:(error as Error).message},422)}const id=randomUUID(),result=await this.db.query(`INSERT INTO tenants(id,name,owner_email,plan,idempotency_key) VALUES($1,$2,$3,$4,$5) ON CONFLICT(idempotency_key) DO UPDATE SET idempotency_key=excluded.idempotency_key RETURNING id,name,owner_email AS "ownerEmail",plan,created_at AS "createdAt"`,[id,value.name,value.ownerEmail,value.plan,key]);return result.rows[0] as Tenant}}
collectDefaultMetrics({prefix:"saas_"});const requests=new Counter({name:"saas_domain_operations_total",help:"Successful domain operations",labelNames:["operation"]});@Controller()class AppController{constructor(private readonly tenants:TenantService){}@Get("health")async health(){try{await this.tenants.health();return{status:"ok",service:"saas-api"}}catch{throw new HttpException({status:"not_ready"},503)}}@Get("metrics")async metrics(){return register.metrics()}@Get("api/tenants")async list(){return this.tenants.list()}@Post("api/tenants")async create(@Body()body:Record<string,unknown>,@Headers("idempotency-key")key:string){const result=await this.tenants.create(body,key);requests.inc({operation:"create_tenant"});return result}}
@Module({controllers:[AppController],providers:[TenantService]})class AppModule{}async function bootstrap(){const app=await NestFactory.create(AppModule,{bodyParser:true});const service=app.get(TenantService);await service.init();app.use((req:any,res:any,next:any)=>{res.setHeader("X-Request-ID",req.header("X-Request-ID")||randomUUID());next()});await app.listen(Number(process.env.PORT||3000),"0.0.0.0")}bootstrap();
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'api/test/domain.test.ts' @'
import test from"node:test";import assert from"node:assert/strict";import{parseTenant}from"../src/domain.js";test("normalizes tenant",()=>assert.deepEqual(parseTenant({name:" Acme ",ownerEmail:"OWNER@EXAMPLE.COM",plan:"growth"}),{name:"Acme",ownerEmail:"owner@example.com",plan:"growth"}));test("rejects plan",()=>assert.throws(()=>parseTenant({name:"Acme",ownerEmail:"o@example.com",plan:"free"}),/INVALID_PLAN/));
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'api/Dockerfile' @'
FROM node:24-alpine AS build
WORKDIR /app
COPY package*.json tsconfig.json ./
RUN npm ci --no-audit --no-fund
COPY src ./src
RUN npm run build
FROM node:24-alpine
ENV NODE_ENV=production PORT=3000
RUN addgroup -g 10001 app && adduser -D -u 10001 -G app app
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY --from=build --chown=app:app /app/dist ./dist
USER 10001:10001
EXPOSE 3000
CMD ["node","dist/main.js"]
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'frontend/package.json' @'
{"name":"saas-angular","private":true,"version":"0.1.0","scripts":{"build":"ng build"},"dependencies":{"@angular/common":"22.0.0","@angular/compiler":"22.0.0","@angular/core":"22.0.0","@angular/platform-browser":"22.0.0","rxjs":"7.8.2","zone.js":"0.15.1"},"devDependencies":{"@angular/build":"22.0.0","@angular/cli":"22.0.0","@angular/compiler-cli":"22.0.0","typescript":"6.0.3"}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/angular.json' @'
{"version":1,"projects":{"app":{"projectType":"application","root":"","sourceRoot":"src","architect":{"build":{"builder":"@angular/build:application","options":{"outputPath":"dist/app","index":"src/index.html","browser":"src/main.ts","tsConfig":"tsconfig.json","styles":["src/styles.css"]}}}}}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/tsconfig.json' @'
{"compilerOptions":{"target":"ES2023","module":"preserve","moduleResolution":"bundler","experimentalDecorators":true,"strict":true,"skipLibCheck":true},"angularCompilerOptions":{"strictTemplates":true},"files":["src/main.ts"]}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/src/index.html' '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Tenant Atlas</title></head><body><app-root></app-root></body></html>' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/src/main.ts' @'
import{Component,signal}from"@angular/core";import{bootstrapApplication}from"@angular/platform-browser";import{HttpClient,provideHttpClient}from"@angular/common/http";import{firstValueFrom}from"rxjs";type Tenant={id:string,name:string,ownerEmail:string,plan:string};@Component({selector:"app-root",standalone:true,template:`<main><header><p>TENANT ATLAS</p><h1>Operate every account<br>with a clear boundary.</h1><output>{{message()}}</output></header><form (submit)="create($event)"><input name="name" placeholder="Company name" required><input name="email" type="email" placeholder="owner@example.com" required><select name="plan"><option>starter</option><option>growth</option><option>enterprise</option></select><button>Create tenant</button></form><section>@for(tenant of tenants();track tenant.id){<article><span>{{tenant.plan}}</span><h2>{{tenant.name}}</h2><p>{{tenant.ownerEmail}}</p></article>}</section></main>`})class App{tenants=signal<Tenant[]>([]);message=signal("Ready");constructor(private http:HttpClient){this.load()}async load(){this.tenants.set(await firstValueFrom(this.http.get<Tenant[]>("/api/tenants")))}async create(event:Event){event.preventDefault();const form=new FormData(event.target as HTMLFormElement);try{await firstValueFrom(this.http.post("/api/tenants",{name:form.get("name"),ownerEmail:form.get("email"),plan:form.get("plan")},{headers:{"Idempotency-Key":crypto.randomUUID()}}));this.message.set("Tenant created");await this.load()}catch{this.message.set("Request failed")}}}bootstrapApplication(App,{providers:[provideHttpClient()]});
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/src/styles.css' @'
:root{font-family:Inter,system-ui;color:#14213d;background:#f7f4ed}*{box-sizing:border-box}body{margin:0}main{max-width:1100px;margin:auto;padding:4rem 2rem}header p{letter-spacing:.2em;color:#e76f51;font-weight:800}h1{font-size:clamp(2.8rem,7vw,6rem);line-height:.9;letter-spacing:-.05em}form{display:grid;grid-template-columns:2fr 2fr 1fr auto;gap:.5rem;background:#14213d;padding:.8rem}input,select,button{padding:.9rem;border:0}button{background:#fca311;font-weight:bold}section{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:1rem;margin-top:2rem}article{background:white;padding:1.2rem;border-top:5px solid #e76f51}article span{text-transform:uppercase;font-size:.7rem;color:#e76f51}@media(max-width:720px){form{grid-template-columns:1fr}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/nginx.conf' 'server { listen 8080; root /usr/share/nginx/html/browser; location = /health { default_type application/json; return 200 ''{"status":"ok","service":"frontend"}''; } location /api/ { proxy_pass ${API_URL}/api/; } location / { try_files $uri /index.html; } }' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/Dockerfile' @'
FROM node:24-alpine AS build
WORKDIR /src
COPY package*.json ./
RUN npm ci --no-audit --no-fund
COPY . ./
RUN npm run build
FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /src/dist/app /usr/share/nginx/html
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'docker-compose.yml' @'
services:
  postgres:
    image: postgres:16-alpine
    environment: { POSTGRES_USER: "${POSTGRES_USER:-app}", POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-local-development-only}", POSTGRES_DB: "${POSTGRES_DB:-app}" }
    volumes: [postgres-data:/var/lib/postgresql/data]
    healthcheck: { test: ["CMD-SHELL","pg_isready -U ${POSTGRES_USER:-app} -d ${POSTGRES_DB:-app}"], interval: 5s, timeout: 3s, retries: 20 }
    networks: [data]
  api:
    image: ${REGISTRY:-local}/12-typescript-nestjs-angular-saas-api:${IMAGE_TAG:-dev}
    build: { context: api }
    environment: { PORT: 3000, DATABASE_URL: "postgresql://${POSTGRES_USER:-app}:${POSTGRES_PASSWORD:-local-development-only}@postgres:5432/${POSTGRES_DB:-app}" }
    depends_on: { postgres: { condition: service_healthy } }
    healthcheck: { test: ["CMD","node","-e","fetch('http://localhost:3000/health').then(r=>{if(!r.ok)process.exit(1)})"], interval: 5s, timeout: 3s, retries: 30 }
    networks: [backend,data]
  frontend:
    image: ${REGISTRY:-local}/12-typescript-nestjs-angular-saas-frontend:${IMAGE_TAG:-dev}
    build: { context: frontend }
    environment: { API_URL: http://api:3000 }
    ports: ["${PUBLIC_PORT:-8091}:8080"]
    depends_on: { api: { condition: service_healthy } }
    networks: [edge,backend]
networks: { edge: {}, backend: { internal: true }, data: { internal: true } }
volumes: { postgres-data: {} }
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'scripts/test.sh' @'
#!/usr/bin/env sh
set -eu
(cd api && npm ci --no-audit --no-fund && npm test && npm run build)
(cd frontend && npm ci --no-audit --no-fund && npm run build)
docker compose config --quiet
'@ -WhatIfMode:$WhatIfMode
[pscustomobject]@{Project=$project.Id;Root=$root;Files=$script:Generated.Count}

param([switch]$WhatIfMode)
. (Join-Path $PSScriptRoot 'Common.ps1')

$project=@{
 Id='07-python-learning-monolith';Title='Python Learning Management Modular Monolith';Type='Modular monolith';Backend='Python 3.12 / FastAPI / PostgreSQL';Frontend='Server-rendered HTML / progressive JavaScript';Domain='learning';Namespace='learning-python';PublicPort=8087;Entry='app';Ui='app'
 Diagram=@'
flowchart LR
    Learner --> UI["Accessible learning portal"] --> HTTP["FastAPI adapters"]
    HTTP --> Catalog["Course catalog module"]
    HTTP --> Enrollment["Enrollment module"]
    HTTP --> Progress["Progress module"]
    Catalog --> Rules["Domain rules"]
    Enrollment --> Rules
    Progress --> Rules
    Rules --> PG[(PostgreSQL)]
    HTTP --> Observe["Metrics and structured logs"]
'@
 Workloads=@(
  @{Name='app';Port=8000;Health='/health';Responsibility='Learning UI, catalog/enrollment/progress modules, API, and persistence adapters in one deployable unit'}
 )
}

$root=New-CommonProject $project -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'app/requirements.txt' @'
fastapi==0.115.0
uvicorn[standard]==0.30.6
psycopg[binary]==3.2.1
prometheus-client==0.21.0
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/domain.py' @'
from dataclasses import dataclass

LEVELS = {"beginner", "intermediate", "advanced"}

@dataclass(frozen=True)
class CourseDraft:
    title: str
    level: str
    capacity: int

def course_draft(payload: dict) -> CourseDraft:
    title = str(payload.get("title", "")).strip()
    level = str(payload.get("level", "beginner")).lower()
    try:
        capacity = int(payload.get("capacity", 0))
    except (TypeError, ValueError) as exc:
        raise ValueError("INVALID_CAPACITY") from exc
    if not 3 <= len(title) <= 160:
        raise ValueError("INVALID_TITLE")
    if level not in LEVELS:
        raise ValueError("INVALID_LEVEL")
    if not 1 <= capacity <= 10_000:
        raise ValueError("INVALID_CAPACITY")
    return CourseDraft(title, level, capacity)

def normalized_email(value: object) -> str:
    email = str(value or "").strip().lower()
    if len(email) > 254 or "@" not in email or "." not in email.rsplit("@", 1)[-1]:
        raise ValueError("INVALID_EMAIL")
    return email
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/main.py' @'
import json,os,time,uuid
from contextlib import contextmanager
from pathlib import Path
import psycopg
from psycopg.rows import dict_row
from fastapi import FastAPI,Header,HTTPException,Request
from fastapi.responses import FileResponse,Response
from fastapi.staticfiles import StaticFiles
from prometheus_client import CONTENT_TYPE_LATEST,Counter,Histogram,generate_latest
from domain import course_draft,normalized_email

app=FastAPI(title="Learning Modular Monolith",version="0.1.0")
root=Path(__file__).parent
requests=Counter("learning_http_requests_total","HTTP requests",["method","route","status"])
duration=Histogram("learning_http_request_duration_seconds","HTTP request latency",["route"])

@contextmanager
def connection():
    with psycopg.connect(os.environ["DATABASE_URL"],connect_timeout=3,row_factory=dict_row) as db:
        yield db

def migrate():
    with connection() as db:
        db.execute("""CREATE TABLE IF NOT EXISTS courses(id uuid PRIMARY KEY,title varchar(160) NOT NULL,level varchar(24) NOT NULL,capacity integer NOT NULL CHECK(capacity > 0),created_at timestamptz NOT NULL DEFAULT now(),idempotency_key varchar(128) UNIQUE NOT NULL);CREATE TABLE IF NOT EXISTS enrollments(id uuid PRIMARY KEY,course_id uuid NOT NULL REFERENCES courses(id),learner_email varchar(254) NOT NULL,status varchar(24) NOT NULL DEFAULT 'active',created_at timestamptz NOT NULL DEFAULT now(),idempotency_key varchar(128) UNIQUE NOT NULL,UNIQUE(course_id,learner_email))""")

@app.middleware("http")
async def telemetry(request:Request,call_next):
    request_id=request.headers.get("X-Request-ID",str(uuid.uuid4()))[:128];started=time.monotonic()
    try: response=await call_next(request)
    except Exception as error:
        print(json.dumps({"level":"error","requestId":request_id,"message":str(error)}),flush=True);raise
    route=getattr(request.scope.get("route"),"path",request.url.path);requests.labels(request.method,route,str(response.status_code)).inc();duration.labels(route).observe(time.monotonic()-started);response.headers["X-Request-ID"]=request_id;return response

@app.on_event("startup")
def startup(): migrate()

@app.get("/health")
def health():
    try:
        with connection() as db: db.execute("SELECT 1").fetchone()
        return {"status":"ok","service":"learning-app"}
    except Exception as error: raise HTTPException(503,"database unavailable") from error

@app.get("/metrics")
def metrics(): return Response(generate_latest(),media_type=CONTENT_TYPE_LATEST)

@app.get("/api/courses")
def list_courses():
    with connection() as db:
        return db.execute("""SELECT c.id,c.title,c.level,c.capacity,c.created_at AS "createdAt",count(e.id)::int AS enrollments FROM courses c LEFT JOIN enrollments e ON e.course_id=c.id GROUP BY c.id ORDER BY c.created_at DESC LIMIT 200""").fetchall()

@app.post("/api/courses",status_code=201)
def create_course(payload:dict,idempotency_key:str|None=Header(None)):
    if not idempotency_key or len(idempotency_key)>128: raise HTTPException(400,{"code":"IDEMPOTENCY_KEY_REQUIRED"})
    try: draft=course_draft(payload)
    except ValueError as error: raise HTTPException(422,{"code":str(error)}) from error
    with connection() as db:
        existing=db.execute("SELECT id,title,level,capacity,created_at AS \"createdAt\" FROM courses WHERE idempotency_key=%s",(idempotency_key,)).fetchone()
        if existing:return existing
        created=db.execute("INSERT INTO courses(id,title,level,capacity,idempotency_key) VALUES(%s,%s,%s,%s,%s) ON CONFLICT(idempotency_key) DO NOTHING RETURNING id,title,level,capacity,created_at AS \"createdAt\"",(uuid.uuid4(),draft.title,draft.level,draft.capacity,idempotency_key)).fetchone()
        return created or db.execute("SELECT id,title,level,capacity,created_at AS \"createdAt\" FROM courses WHERE idempotency_key=%s",(idempotency_key,)).fetchone()

@app.post("/api/enrollments",status_code=201)
def enroll(payload:dict,idempotency_key:str|None=Header(None)):
    if not idempotency_key or len(idempotency_key)>128: raise HTTPException(400,{"code":"IDEMPOTENCY_KEY_REQUIRED"})
    try: course_id=uuid.UUID(str(payload.get("courseId")));email=normalized_email(payload.get("learnerEmail"))
    except (ValueError,TypeError) as error: raise HTTPException(422,{"code":str(error)}) from error
    with connection() as db:
        prior=db.execute("SELECT id,course_id AS \"courseId\",learner_email AS \"learnerEmail\",status,created_at AS \"createdAt\" FROM enrollments WHERE idempotency_key=%s",(idempotency_key,)).fetchone()
        if prior:return prior
        course=db.execute("SELECT capacity,(SELECT count(*) FROM enrollments WHERE course_id=%s AND status='active') AS enrolled FROM courses WHERE id=%s FOR UPDATE",(course_id,course_id)).fetchone()
        if not course:raise HTTPException(404,{"code":"COURSE_NOT_FOUND"})
        if course["enrolled"]>=course["capacity"]:raise HTTPException(409,{"code":"COURSE_FULL"})
        created=db.execute("INSERT INTO enrollments(id,course_id,learner_email,idempotency_key) VALUES(%s,%s,%s,%s) ON CONFLICT DO NOTHING RETURNING id,course_id AS \"courseId\",learner_email AS \"learnerEmail\",status,created_at AS \"createdAt\"",(uuid.uuid4(),course_id,email,idempotency_key)).fetchone()
        if created:return created
        prior=db.execute("SELECT id,course_id AS \"courseId\",learner_email AS \"learnerEmail\",status,created_at AS \"createdAt\" FROM enrollments WHERE idempotency_key=%s",(idempotency_key,)).fetchone()
        if prior:return prior
        raise HTTPException(409,{"code":"ALREADY_ENROLLED"})

app.mount("/assets",StaticFiles(directory=root/"static"),name="assets")
@app.get("/{path:path}",include_in_schema=False)
def ui(path:str):
    if path.startswith("api/"):raise HTTPException(404,{"code":"NOT_FOUND"})
    return FileResponse(root/"static"/"index.html")
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/test_domain.py' @'
import unittest
from domain import course_draft,normalized_email
class DomainTests(unittest.TestCase):
    def test_course_is_normalized(self): self.assertEqual(course_draft({"title":" Platform Engineering ","level":"advanced","capacity":"30"}).title,"Platform Engineering")
    def test_capacity_is_bounded(self):
        with self.assertRaisesRegex(ValueError,"INVALID_CAPACITY"):course_draft({"title":"A valid course","capacity":0})
    def test_email_is_normalized(self):self.assertEqual(normalized_email(" LEARNER@EXAMPLE.COM "),"learner@example.com")
if __name__=="__main__":unittest.main()
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/static/index.html' @'
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Learning Foundry</title><link rel="stylesheet" href="/assets/style.css"></head><body><main><header><p class="label">LEARNING FOUNDRY</p><h1>Grow capability,<br>one deliberate course at a time.</h1><p id="message">Ready</p></header><form id="course"><input name="title" placeholder="Course title" required><select name="level"><option>beginner</option><option>intermediate</option><option>advanced</option></select><input name="capacity" type="number" min="1" value="30"><button>Add course</button></form><section id="courses" aria-live="polite"></section></main><script src="/assets/app.js" defer></script></body></html>
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/static/app.js' @'
const list=document.querySelector("#courses"),message=document.querySelector("#message"),form=document.querySelector("#course");async function load(){const response=await fetch("/api/courses");if(!response.ok)throw Error("Unable to load courses");const courses=await response.json();list.innerHTML=courses.map(course=>`<article><span>${course.level}</span><h2>${course.title}</h2><p>${course.enrollments} / ${course.capacity} learners enrolled</p><button data-id="${course.id}">Enroll demo learner</button></article>`).join("")}form.addEventListener("submit",async event=>{event.preventDefault();const data=new FormData(form),response=await fetch("/api/courses",{method:"POST",headers:{"content-type":"application/json","idempotency-key":crypto.randomUUID()},body:JSON.stringify({title:data.get("title"),level:data.get("level"),capacity:Number(data.get("capacity"))})});message.textContent=response.ok?"Course created":JSON.stringify(await response.json());if(response.ok){form.reset();await load()}});list.addEventListener("click",async event=>{const id=event.target.dataset.id;if(!id)return;const response=await fetch("/api/enrollments",{method:"POST",headers:{"content-type":"application/json","idempotency-key":crypto.randomUUID()},body:JSON.stringify({courseId:id,learnerEmail:`learner-${Date.now()}@example.com`})});message.textContent=response.ok?"Learner enrolled":JSON.stringify(await response.json());if(response.ok)await load()});load().catch(error=>message.textContent=error.message);
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/static/style.css' @'
:root{font-family:system-ui;color:#17324d;background:#f6f2e7}*{box-sizing:border-box}body{margin:0;background:linear-gradient(115deg,#f6f2e7 65%,#d7e9e6 65%)}main{max-width:1080px;margin:auto;padding:5rem 2rem;min-height:100vh}.label{letter-spacing:.2em;color:#b24c3f;font-weight:800}h1{font:700 clamp(2.6rem,7vw,5.4rem)/.95 Georgia,serif;margin:.4rem 0 2rem}form{display:flex;gap:.7rem;flex-wrap:wrap;background:#17324d;padding:1rem;border-radius:12px}input,select,button{padding:.85rem;border:0;border-radius:6px}input:first-child{flex:1;min-width:220px}button{background:#efb366;color:#17324d;font-weight:800}section{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:1rem;margin-top:2rem}article{background:#fff;padding:1.3rem;border-radius:4px;box-shadow:8px 8px 0 #17324d14}article span{font-size:.72rem;text-transform:uppercase;letter-spacing:.14em;color:#b24c3f}article button{background:#d7e9e6}
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'Dockerfile' @'
FROM python:3.12-slim AS dependencies
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY app/requirements.txt .
RUN pip install --prefix=/install -r requirements.txt

FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=8000
RUN groupadd --gid 10001 app && useradd --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app
WORKDIR /app
COPY --from=dependencies /install /usr/local
COPY --chown=app:app app/ ./
USER 10001:10001
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --retries=10 CMD python -c "import urllib.request;urllib.request.urlopen('http://localhost:8000/health',timeout=2)"
CMD ["sh","-c","uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
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
    image: ${REGISTRY:-local}/07-python-learning-monolith-app:${IMAGE_TAG:-dev}
    build: .
    environment: { PORT: 8000, DATABASE_URL: "postgresql://${POSTGRES_USER:-app}:${POSTGRES_PASSWORD:-local-development-only}@postgres:5432/${POSTGRES_DB:-app}" }
    ports: ["${PUBLIC_PORT:-8087}:8000"]
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
PYTHONPATH=app python -m unittest app/test_domain.py
python -m py_compile app/main.py app/domain.py
docker compose config --quiet
'@ -WhatIfMode:$WhatIfMode

[pscustomobject]@{Project=$project.Id;Root=$root;Files=$script:Generated.Count}

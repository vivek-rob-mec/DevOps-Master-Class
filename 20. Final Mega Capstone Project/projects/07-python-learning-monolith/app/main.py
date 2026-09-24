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

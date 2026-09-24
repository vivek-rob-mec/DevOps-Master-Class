"""Small shared helpers for local analyst/operator dashboards and immutable reviews."""
import json
from pathlib import Path
import time

from fastapi import HTTPException, Request
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, ConfigDict, Field

from .runtime import database, digest, encode, make_api


class ReviewBase(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    request_id: str = Field(pattern=r"^[a-zA-Z0-9_-]{8,80}$")
    reviewer: str = Field(min_length=1, max_length=80)
    notes: str = Field(min_length=1, max_length=1000)


def init_reviews(path):
    with database(path) as db:
        db.execute("""CREATE TABLE IF NOT EXISTS operator_reviews(
            request_id TEXT PRIMARY KEY, target TEXT UNIQUE NOT NULL,
            payload_hash TEXT NOT NULL, created REAL NOT NULL, snapshot TEXT NOT NULL)""")


def save_review(path, payload, target, snapshot):
    """Serialize retry/finalization checks with the domain snapshot read."""
    request_hash = digest(payload.model_dump())
    with database(path) as db:
        db.execute("BEGIN IMMEDIATE")
        old = db.execute("SELECT payload_hash,snapshot FROM operator_reviews WHERE request_id=?", (payload.request_id,)).fetchone()
        if old:
            if old['payload_hash'] != request_hash:
                raise HTTPException(409, "Request ID already used for different review data")
            return json.loads(old['snapshot'])
        if db.execute("SELECT 1 FROM operator_reviews WHERE target=?", (target,)).fetchone():
            raise HTTPException(409, "This record already has a finalized review")
        result = {**payload.model_dump(), "snapshot": snapshot(db), "created_at": time.time(), "executed": False}
        db.execute("INSERT INTO operator_reviews VALUES(?,?,?,?,?)", (payload.request_id, target, request_hash, result['created_at'], encode(result)))
        return result


def reviews(db):
    return [json.loads(r[0]) for r in db.execute("SELECT snapshot FROM operator_reviews ORDER BY created DESC LIMIT 30")]


def evidence(runtime, release_id=None):
    try:
        release, _ = runtime.load(release_id)
        metrics = json.loads((runtime.state/'releases'/release['release_id']/'metrics.json').read_text())
        return {"available": True, "release": release, "metrics": metrics}
    except (OSError, ValueError, KeyError):
        return {"available": False, "error": "Model evidence unavailable. Run demo for a new lab, or inspect the retained release files."}


def dashboard_api(runtime, frontend):
    api = make_api(runtime, home_file=frontend/'index.html')
    api.mount('/assets', StaticFiles(directory=frontend), name='assets')
    api.mount('/shared', StaticFiles(directory=Path(__file__).parent/'web'), name='shared')

    @api.middleware('http')
    async def same_origin(request: Request, call_next):
        origin = request.headers.get('origin')
        if request.method in ('POST', 'PUT', 'PATCH', 'DELETE') and origin and origin != str(request.base_url).rstrip('/'):
            from fastapi.responses import JSONResponse
            return JSONResponse({'detail': 'Write requests must originate from this application'}, status_code=403)
        return await call_next(request)

    return api

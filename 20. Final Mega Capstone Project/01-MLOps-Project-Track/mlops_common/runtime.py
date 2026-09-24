from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import tempfile
import time
import uuid

import joblib
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, HTMLResponse, PlainTextResponse


def encode(value):
    return json.dumps(value, sort_keys=True, allow_nan=False, separators=(",", ":"))


def digest(value):
    return hashlib.sha256(encode(value).encode()).hexdigest()


def atomic_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    handle, name = tempfile.mkstemp(dir=path.parent, suffix=".tmp")
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as stream:
            stream.write(encode(value))
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


@contextmanager
def database(path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(path, timeout=15)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA journal_mode=WAL")
    try:
        with connection:
            yield connection
    finally:
        connection.close()


class Runtime:
    def __init__(self, root, service):
        self.root = Path(root)
        self.service = service
        self.state = Path(os.getenv("STATE_DIR", str(self.root / "state")))
        self.state.mkdir(parents=True, exist_ok=True)
        self.db = self.state / "application.db"
        self.telemetry = Path(os.getenv("TELEMETRY_DB", str(self.root.parent / "state" / "telemetry.db")))
        with database(self.telemetry) as db:
            db.execute("CREATE TABLE IF NOT EXISTS events (id INTEGER PRIMARY KEY, ts REAL NOT NULL, service TEXT NOT NULL, kind TEXT NOT NULL, latency REAL NOT NULL, error REAL NOT NULL, queue REAL NOT NULL, context TEXT NOT NULL)")

    def emit(self, kind, latency=0, error=0, queue=0, **context):
        with database(self.telemetry) as db:
            db.execute("INSERT INTO events(ts,service,kind,latency,error,queue,context) VALUES(?,?,?,?,?,?,?)",
                       (time.time(), self.service, kind, latency, error, queue, encode(context)))

    def release(self, model, dataset, splits, metrics, schema, policy):
        release_id = uuid.uuid4().hex
        folder = self.state / "releases" / release_id
        folder.mkdir(parents=True)
        joblib.dump(model, folder / "model.joblib")
        source = {str(p.relative_to(self.root)): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in self.root.glob("*.py")}
        source.update({"common/" + p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                       for p in Path(__file__).parent.glob("*.py")})
        lockfile = Path(__file__).resolve().parents[1] / "requirements.lock"
        metadata = {"release_id": release_id, "service": self.service,
                    "created_at": datetime.now(timezone.utc).isoformat(), "source_sha256": digest(source),
                    "dataset_sha256": digest(dataset), "split_sha256": digest(splits),
                    "model_sha256": hashlib.sha256((folder / "model.joblib").read_bytes()).hexdigest(),
                    "metrics_sha256": digest(metrics), "dependency_lock_sha256": hashlib.sha256(lockfile.read_bytes()).hexdigest(),
                    "feature_schema": schema, "policy": policy,
                    "eligible": bool(metrics.get("validation_pass", False)),
                    "runtime": {"python": os.sys.version.split()[0], "sklearn": __import__("sklearn").__version__}}
        for name, value in [("dataset", dataset), ("splits", splits), ("metrics", metrics), ("release", metadata)]:
            atomic_json(folder / (name + ".json"), value)
        self.emit("trained", release_id=release_id, eligible=metadata["eligible"])
        return metadata

    def load(self, release_id=None):
        if release_id is None:
            pointer = self.state / "active.json"
            if not pointer.exists():
                raise ValueError("No active release. Run demo or train followed by promote.")
            release_id = json.loads(pointer.read_text())["release_id"]
        if not isinstance(release_id, str) or not re.fullmatch(r"[0-9a-f]{32}", release_id):
            raise ValueError("Invalid release ID")
        folder = self.state / "releases" / release_id
        metadata = json.loads((folder / "release.json").read_text())
        if metadata["service"] != self.service or metadata["release_id"] != release_id:
            raise ValueError("Release identity mismatch")
        for filename, key in [("dataset", "dataset_sha256"), ("splits", "split_sha256"), ("metrics", "metrics_sha256")]:
            if digest(json.loads((folder / (filename + ".json")).read_text())) != metadata[key]:
                raise ValueError("Release evidence checksum mismatch")
        if hashlib.sha256((folder / "model.joblib").read_bytes()).hexdigest() != metadata["model_sha256"]:
            raise ValueError("Model checksum mismatch")
        if metadata["runtime"]["sklearn"] != __import__("sklearn").__version__:
            raise ValueError("Incompatible scikit-learn runtime; retrain with this lockfile")
        # Only local trusted training output may be deserialized. Checksums are not signatures.
        return metadata, joblib.load(folder / "model.joblib")

    def activate(self, release_id):
        metadata, _ = self.load(release_id)
        if not metadata["eligible"]:
            raise ValueError("Validation gate rejected this release")
        atomic_json(self.state / "active.json", {"release_id": release_id})
        self.emit("release_activated", release_id=release_id)
        return metadata

    def report(self):
        metadata, _ = self.load()
        metrics = json.loads((self.state / "releases" / metadata["release_id"] / "metrics.json").read_text())
        return {"release": metadata, "metrics": metrics}


def make_api(runtime, home_file=None):
    api = FastAPI(title=runtime.service, version="1.0.0")

    @api.middleware("http")
    async def instrument(request, call_next):
        start = time.perf_counter()
        try:
            response = await call_next(request)
        except Exception:
            runtime.emit("http", latency=(time.perf_counter()-start)*1000, error=1, path=request.url.path, status=500)
            raise
        if request.url.path not in ("/metrics", "/healthz", "/readyz"):
            runtime.emit("http", latency=(time.perf_counter()-start)*1000, error=int(response.status_code >= 500), path=request.url.path, status=response.status_code)
        return response

    @api.get("/", response_class=HTMLResponse)
    def home():
        if home_file is not None:
            return FileResponse(home_file)
        return f"<html><title>{runtime.service}</title><body style='font:18px system-ui;max-width:850px;margin:60px auto'><h1>{runtime.service}</h1><p>Local CPU learning project. Explore the live API and release evidence.</p><ul><li><a href='/docs'>Interactive API console</a></li><li><a href='/report'>Model evaluation and active release</a></li><li><a href='/readyz'>Readiness</a></li><li><a href='/metrics'>Service metrics</a></li></ul></body></html>"

    @api.get("/healthz")
    def health():
        return {"status": "ok", "service": runtime.service}

    @api.get("/readyz")
    def ready():
        try:
            metadata, _ = runtime.load()
            return {"status": "ready", "release_id": metadata["release_id"]}
        except (OSError, ValueError, KeyError) as error:
            raise HTTPException(503, str(error))

    @api.get("/report")
    def report():
        try:
            return runtime.report()
        except (OSError, ValueError) as error:
            raise HTTPException(503, str(error))

    @api.get("/metrics", response_class=PlainTextResponse)
    def metrics():
        with database(runtime.telemetry) as db:
            row = db.execute("SELECT count(*) n, coalesce(sum(error),0) errors, coalesce(sum(latency),0) latency FROM events WHERE service=? AND kind='http'", (runtime.service,)).fetchone()
        return f'lab_requests_total{{service="{runtime.service}"}} {row["n"]}\nlab_errors_total{{service="{runtime.service}"}} {row["errors"]}\nlab_request_duration_milliseconds_sum{{service="{runtime.service}"}} {row["latency"]}\n'

    return api


def cli(project, port):
    import argparse
    parser = argparse.ArgumentParser(description=project.runtime.service)
    parser.add_argument("command", choices=["demo", "train", "serve", "report", "promote", "rollback", "exercise"])
    parser.add_argument("--release")
    parser.add_argument("--port", type=int, default=port)
    parser.add_argument("--host", default="127.0.0.1")
    args = parser.parse_args()
    if args.command == "serve":
        import uvicorn
        uvicorn.run(project.api(), host=args.host, port=args.port, workers=1)
    elif args.command == "train":
        print(json.dumps(project.train(), indent=2))
    elif args.command in ("promote", "rollback"):
        if not args.release:
            parser.error("--release is required")
        print(json.dumps(project.runtime.activate(args.release), indent=2))
    elif args.command == "report":
        print(json.dumps(project.runtime.report(), indent=2))
    elif args.command == "exercise":
        print(json.dumps(project.exercise(), indent=2))
    else:
        print(json.dumps(project.demo(), indent=2))

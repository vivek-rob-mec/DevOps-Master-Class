"""Retail Control Center: local customer-integration and delivery lab."""
import argparse
from contextlib import contextmanager
import csv
from datetime import date, timedelta
import hashlib
import io
import json
import os
from pathlib import Path
import sqlite3
import time
from typing import Literal
import uuid

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, ConfigDict, Field

ROOT = Path(__file__).resolve().parent
METHOD = "seasonal-naive-v1"
LEASE_SECONDS = 30
MAX_ATTEMPTS = 3


def encode(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def digest(value):
    return hashlib.sha256(encode(value).encode()).hexdigest()


class Input(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    request_id: str = Field(pattern=r"^[A-Za-z0-9_-]{8,80}$")


class Import(Input):
    sales_csv: str = Field(min_length=1, max_length=1000000)
    inventory_csv: str = Field(min_length=1, max_length=50000)


class Queue(Input):
    batch_id: str = Field(pattern=r"^[a-f0-9]{64}$")


class Review(Input):
    job_id: str = Field(pattern=r"^[a-f0-9]{64}$")
    sku: str = Field(pattern=r"^[A-Za-z0-9_-]{1,40}$")
    decision: Literal["approved", "deferred"]
    reviewer: str = Field(min_length=1, max_length=80)
    notes: str = Field(min_length=5, max_length=1000)


def integer(value, field, maximum=1000000):
    if not value.isascii() or not value.isdigit() or len(value) > 9 or int(value) > maximum:
        raise ValueError(f"{field} must be an integer between 0 and {maximum}")
    return int(value)


def rows(text, headers, limit):
    try:
        reader = csv.reader(io.StringIO(text.lstrip("\ufeff")), strict=True)
        if next(reader, None) != headers:
            raise ValueError("CSV headers must be exactly: " + ",".join(headers))
        result = []
        for row in reader:
            if len(row) != len(headers):
                raise ValueError("Every CSV row must have exactly the declared fields")
            result.append(dict(zip(headers, (v.strip() for v in row))))
            if len(result) > limit:
                raise ValueError(f"CSV exceeds {limit} rows")
        if not result:
            raise ValueError("CSV must contain data rows")
        return result
    except csv.Error as error:
        raise ValueError(f"Malformed CSV: {error}") from error


def snapshot(sales_csv, inventory_csv):
    import re
    sales = rows(sales_csv, ["date", "sku", "units"], 18300)
    inventory = rows(inventory_csv, ["sku", "on_hand", "safety_stock"], 50)
    series, stock = {}, {}
    for row in sales + inventory:
        if not re.fullmatch(r"[A-Za-z0-9_-]{1,40}", row["sku"]):
            raise ValueError("SKU must use 1-40 ASCII letters, digits, underscores or hyphens")
    for row in sales:
        day = date.fromisoformat(row["date"])
        if day.isoformat() != row["date"] or day > date.today():
            raise ValueError("Sales dates must be canonical YYYY-MM-DD and not in the future")
        values = series.setdefault(row["sku"], {})
        if day.isoformat() in values:
            raise ValueError("Duplicate date/SKU in sales")
        values[day.isoformat()] = integer(row["units"], "units")
    for row in inventory:
        if row["sku"] in stock:
            raise ValueError("Duplicate inventory SKU")
        stock[row["sku"]] = {k: integer(row[k], k) for k in ["on_hand", "safety_stock"]}
    if set(stock) != set(series):
        raise ValueError("Sales and inventory must have the same SKUs")
    days = sorted(next(iter(series.values())))
    if not 28 <= len(days) <= 366:
        raise ValueError("Provide 28-366 complete daily observations for every SKU")
    if (date.fromisoformat(days[-1]) - date.fromisoformat(days[0])).days != len(days) - 1:
        raise ValueError("Missing sales date; explicitly provide zero for a no-sales day")
    if any(sorted(values) != days for values in series.values()):
        raise ValueError("All SKUs must cover exactly the same dates")
    return {"schema": "retail-snapshot-v1", "from_date": days[0], "through_date": days[-1],
            "days": days, "sales": series, "inventory": stock,
            "inventory_as_of": days[-1], "source": "customer-declared CSV; not independently verified"}


def forecast(batch):
    """Immutable same-weekday baseline; final seven observations are a backtest."""
    output = []
    for sku, series in sorted(batch["sales"].items()):
        values = [series[d] for d in batch["days"]]
        predicted = values[-7:]
        stock = batch["inventory"][sku]
        daily = [{"date": (date.fromisoformat(batch["through_date"]) + timedelta(days=i+1)).isoformat(),
                  "units": units} for i, units in enumerate(predicted)]
        output.append({"sku": sku, "daily": daily, "forecast_units": sum(predicted), **stock,
                       "suggested_units": max(0, sum(predicted) + stock["safety_stock"] - stock["on_hand"]),
                       "backtest_mae": sum(abs(a-b) for a,b in zip(values[-14:-7], values[-7:])) / 7})
    return {"method": METHOD, "horizon_days": 7, "items": output,
            "assumptions": "Repeat last week's daily sales; sales may understate demand during stockouts. "
                           "Inventory is declared as of the final sales date. No inbound stock, lead time, "
                           "pack sizes, promotions or stock transfers are modeled. Historical snapshots are lab replays.",
            "evaluation": "One seven-day temporal backtest against the preceding week; no model selection or measured business savings."}


class Project:
    def __init__(self, state=None):
        self.state = Path(state or os.environ.get("STATE_DIR", ROOT / "state"))
        self.state.mkdir(parents=True, exist_ok=True)
        self.db_path = self.state / "retail.db"
        with self.db() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS batches(id TEXT PRIMARY KEY, snapshot TEXT NOT NULL, created REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS current_batch(slot INTEGER PRIMARY KEY CHECK(slot=1), id TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS receipts(id TEXT PRIMARY KEY, hash TEXT NOT NULL, response TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS jobs(id TEXT PRIMARY KEY, batch_id TEXT NOT NULL, method TEXT NOT NULL,
                    state TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, token TEXT, lease_until REAL,
                    created REAL NOT NULL, completed REAL, result TEXT, error TEXT);
                CREATE TABLE IF NOT EXISTS reviews(id TEXT PRIMARY KEY, target TEXT UNIQUE NOT NULL, snapshot TEXT NOT NULL);
            """)

    @contextmanager
    def db(self):
        connection = sqlite3.connect(self.db_path, timeout=10)
        connection.row_factory = sqlite3.Row
        try:
            connection.execute("PRAGMA journal_mode=WAL")
            yield connection
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    def receipt(self, db, payload, kind):
        key = kind + ":" + payload.request_id
        hashed = digest(payload.model_dump())
        found = db.execute("SELECT * FROM receipts WHERE id=?", (key,)).fetchone()
        if found:
            if found["hash"] != hashed:
                raise HTTPException(409, "Request ID already used with different contents")
            return key, hashed, json.loads(found["response"])
        return key, hashed, None

    def save_receipt(self, db, key, hashed, response):
        db.execute("INSERT INTO receipts VALUES(?,?,?)", (key, hashed, encode(response)))
        return response

    def ingest(self, payload: Import):
        with self.db() as db:
            db.execute("BEGIN IMMEDIATE")
            key, hashed, prior = self.receipt(db, payload, "import")
            if prior is not None:
                return prior
            try:
                data = snapshot(payload.sales_csv, payload.inventory_csv)
            except (ValueError, OverflowError) as error:
                raise HTTPException(422, str(error)) from error
            identity = digest(data)
            db.execute("INSERT OR IGNORE INTO batches VALUES(?,?,?)", (identity, encode(data), time.time()))
            db.execute("INSERT OR REPLACE INTO current_batch VALUES(1,?)", (identity,))
            return self.save_receipt(db, key, hashed, {"batch_id": identity, "rows": len(data["days"]) * len(data["sales"]),
                                                        "through_date": data["through_date"]})

    def enqueue(self, payload: Queue):
        with self.db() as db:
            db.execute("BEGIN IMMEDIATE")
            key, hashed, prior = self.receipt(db, payload, "queue")
            if prior is not None:
                return prior
            current = db.execute("SELECT id FROM current_batch WHERE slot=1").fetchone()
            if not current or current["id"] != payload.batch_id:
                raise HTTPException(409, "Snapshot superseded or missing; refresh before forecasting")
            identity = digest([payload.batch_id, METHOD])
            db.execute("""INSERT OR IGNORE INTO jobs(id,batch_id,method,state,created)
                          VALUES(?,?,?,'queued',?)""", (identity, payload.batch_id, METHOD, time.time()))
            return self.save_receipt(db, key, hashed, {"job_id": identity})

    def claim(self, now=None):
        now = time.time() if now is None else now
        with self.db() as db:
            db.execute("BEGIN IMMEDIATE")
            db.execute("""UPDATE jobs SET state='failed',error='Worker lease expired after maximum attempts',token=NULL
                          WHERE state='running' AND lease_until<=? AND attempts>=?""", (now, MAX_ATTEMPTS))
            row = db.execute("""SELECT * FROM jobs WHERE (state='queued' OR (state='running' AND lease_until<=?))
                                AND attempts<? ORDER BY created,id LIMIT 1""", (now, MAX_ATTEMPTS)).fetchone()
            if not row:
                return None
            token = uuid.uuid4().hex
            db.execute("UPDATE jobs SET state='running',attempts=attempts+1,token=?,lease_until=?,error=NULL WHERE id=?",
                       (token, now + LEASE_SECONDS, row["id"]))
            data = db.execute("SELECT snapshot FROM batches WHERE id=?", (row["batch_id"],)).fetchone()
            return {**dict(row), "token": token, "attempts": row["attempts"] + 1, "snapshot": json.loads(data["snapshot"])}

    def finish(self, job, result=None, error=None):
        now = time.time()
        with self.db() as db:
            db.execute("BEGIN IMMEDIATE")
            # A worker that lost its lease cannot publish, even if nobody has reclaimed it yet.
            state = "succeeded" if error is None else ("failed" if job["attempts"] >= MAX_ATTEMPTS else "queued")
            return db.execute("""UPDATE jobs SET state=?,result=?,error=?,completed=?,token=NULL,lease_until=NULL
                               WHERE id=? AND state='running' AND token=? AND lease_until>?""",
                              (state, encode(result) if result is not None else None, error,
                               now if state in ("succeeded", "failed") else None,
                               job["id"], job["token"], now)).rowcount == 1

    def work_once(self):
        job = self.claim()
        if job is None:
            return False
        try:
            result = forecast(job["snapshot"])
        except Exception as error:
            self.finish(job, error=f"Forecast failed: {type(error).__name__}")
        else:
            self.finish(job, result=result)
        return True

    def review(self, payload: Review):
        with self.db() as db:
            db.execute("BEGIN IMMEDIATE")
            key, hashed, prior = self.receipt(db, payload, "review")
            if prior is not None:
                return prior
            job = db.execute("SELECT * FROM jobs WHERE id=?", (payload.job_id,)).fetchone()
            if not job or job["state"] != "succeeded":
                raise HTTPException(409, "A completed forecast is required")
            current = db.execute("SELECT id FROM current_batch WHERE slot=1").fetchone()
            if current["id"] != job["batch_id"]:
                raise HTTPException(409, "Snapshot superseded; refresh and forecast the current import")
            if payload.decision == "approved" and time.time() - job["completed"] > 86400:
                raise HTTPException(409, "Forecast execution is over 24 hours old; defer and import a fresh snapshot")
            result = json.loads(job["result"])
            item = next((i for i in result["items"] if i["sku"] == payload.sku), None)
            if item is None:
                raise HTTPException(404, "SKU is not in this forecast")
            target = digest([payload.job_id, payload.sku])
            if db.execute("SELECT 1 FROM reviews WHERE target=?", (target,)).fetchone():
                raise HTTPException(409, "This forecast/SKU already has a final review")
            saved = {**payload.model_dump(), "batch_id": job["batch_id"], "method": job["method"], "recommendation": item,
                     "assumptions": result["assumptions"], "created_at": time.time(), "executed": False}
            db.execute("INSERT INTO reviews VALUES(?,?,?)", (payload.request_id, target, encode(saved)))
            return self.save_receipt(db, key, hashed, saved)

    def desk(self):
        with self.db() as db:
            db.execute("BEGIN")
            current = db.execute("SELECT b.* FROM batches b JOIN current_batch c ON b.id=c.id").fetchone()
            def public_job(row):
                if row is None:
                    return None
                item = dict(row)
                item.pop("token")
                item["result"] = json.loads(item["result"]) if item["result"] else None
                return item
            jobs = []
            for row in db.execute("SELECT * FROM jobs ORDER BY created DESC,id LIMIT 30"):
                jobs.append(public_job(row))
            reviews = [json.loads(row["snapshot"]) for row in db.execute("SELECT snapshot FROM reviews ORDER BY rowid DESC LIMIT 50")]
            batch = None
            if current:
                data = json.loads(current["snapshot"])
                batch = {"id": current["id"], "created": current["created"], "from_date": data["from_date"],
                         "through_date": data["through_date"], "skus": len(data["sales"]), "days": len(data["days"]),
                         "historical": data["through_date"] < date.today().isoformat()}
            current_job = public_job(db.execute("SELECT * FROM jobs WHERE batch_id=? AND method=?",
                                     (batch["id"], METHOD)).fetchone()) if batch else None
            return {"batch": batch, "current_job": current_job, "jobs": jobs, "reviews": reviews,
                    "limits": "Latest 30 jobs and 50 reviews; full evidence remains in SQLite. Local single-customer lab."}


def sample():
    return {"sales_csv": (ROOT / "data/sales.csv").read_text(),
            "inventory_csv": (ROOT / "data/inventory.csv").read_text(),
            "source": "Simulated ERP export; synthetic fixtures, no external connection"}


def create_app(project=None):
    project = project or Project()
    api = FastAPI(title="Retail Control Center", version="0.1.0")

    @api.middleware("http")
    async def origin_guard(request: Request, call_next):
        origin = request.headers.get("origin")
        if request.method == "POST" and origin and origin != str(request.base_url).rstrip("/"):
            return JSONResponse({"detail": "Cross-origin writes are disabled"}, status_code=403)
        return await call_next(request)

    @api.get("/")
    def home():
        return FileResponse(ROOT / "frontend/index.html")

    @api.get("/healthz")
    def health():
        return {"status": "alive"}

    @api.get("/readyz")
    def ready():
        with project.db() as db:
            db.execute("SELECT 1 FROM jobs LIMIT 1").fetchone()
        return {"status": "database reachable", "worker_health": "not implied; inspect job state and attempts"}

    api.get("/v1/erp/export")(sample)
    api.get("/v1/desk")(project.desk)
    api.post("/v1/imports")(project.ingest)
    api.post("/v1/jobs")(project.enqueue)
    api.post("/v1/reviews")(project.review)
    api.mount("/assets", StaticFiles(directory=ROOT / "frontend"), name="assets")
    return api


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["serve", "worker", "demo"])
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", default=8216, type=int)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    project = Project()
    if args.command == "serve":
        import uvicorn
        uvicorn.run(create_app(project), host=args.host, port=args.port)
    elif args.command == "demo":
        fixture = sample()
        imported = project.ingest(Import(request_id="bundled-demo-v1", sales_csv=fixture["sales_csv"], inventory_csv=fixture["inventory_csv"]))
        queued = project.enqueue(Queue(request_id="bundled-demo-job-v1", batch_id=imported["batch_id"]))
        while project.work_once():
            pass
        print(encode({"import": imported, "job": queued}))
    else:
        while True:
            worked = project.work_once()
            if args.once:
                break
            if not worked:
                time.sleep(1)

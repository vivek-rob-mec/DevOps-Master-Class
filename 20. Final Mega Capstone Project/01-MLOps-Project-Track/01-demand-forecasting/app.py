from datetime import date, timedelta
import json
import math
from pathlib import Path
import time
from typing import Literal

import numpy as np
from fastapi import HTTPException, Request
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, ConfigDict, Field
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error

from mlops_common.runtime import Runtime, database, digest, make_api


class InventoryInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    on_hand: int = Field(strict=True, ge=0, le=1000000)
    revision: int = Field(strict=True, ge=0)


class ReviewInput(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    request_id: str = Field(pattern=r"^[a-zA-Z0-9_-]{8,80}$")
    sku: str = Field(min_length=1, max_length=80)
    batch_id: str = Field(pattern=r"^[a-f0-9]{64}$")
    inventory_revision: int = Field(strict=True, ge=1)
    decision: Literal["approved", "deferred"]
    reviewer: str = Field(min_length=1, max_length=80)
    notes: str = Field(max_length=1000, default="")


def generate(seed=41, products=8, days=224):
    rng = np.random.default_rng(seed)
    return {f"SKU-{p:03d}": [round(max(0, 10 + p*5 + d*0.08 + 6*math.sin(d*2*math.pi/7) + rng.normal(0, 1.2)), 2)
                             for d in range(days)] for p in range(products)}


def features(history, target_day, horizon, product):
    if len(history) < 28:
        raise ValueError("At least 28 observed days are required")
    return [history[-1], history[-7], float(np.mean(history[-7:])), float(np.mean(history[-28:])),
            float(np.mean(history[-7:])-np.mean(history[-14:-7])),
            math.sin(target_day*2*math.pi/7), math.cos(target_day*2*math.pi/7), horizon, product]


def rows(data):
    output = []
    for product, (sku, series) in enumerate(sorted(data.items())):
        for origin in range(28, len(series)-6):
            for horizon in range(1, 8):
                target = origin+horizon-1
                output.append((features(series[:origin], target, horizon, product), series[target],
                               series[origin-7+horizon-1], target, sku, horizon))
    return output


def scores(actual, predicted):
    total = float(np.sum(actual))
    return {"mae": float(mean_absolute_error(actual, predicted)),
            "wape": float(np.abs(np.array(actual)-predicted).sum()/total) if total else None}


class Project:
    def __init__(self, root=None):
        self.runtime = Runtime(root or Path(__file__).parent, "demand-forecasting")
        with database(self.runtime.db) as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS batches(id TEXT PRIMARY KEY, release_id TEXT, origin INTEGER, created REAL);
                CREATE TABLE IF NOT EXISTS forecasts(batch TEXT, sku TEXT, horizon INTEGER, prediction REAL, baseline REAL, PRIMARY KEY(batch,sku,horizon));
                CREATE TABLE IF NOT EXISTS current_batch(slot INTEGER PRIMARY KEY, batch TEXT);
                CREATE TABLE IF NOT EXISTS inventory(sku TEXT PRIMARY KEY, on_hand INTEGER NOT NULL CHECK(on_hand>=0), revision INTEGER NOT NULL, updated_at REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS replenishment_reviews(request_id TEXT PRIMARY KEY, request_hash TEXT NOT NULL, sku TEXT NOT NULL, created_at REAL NOT NULL, snapshot TEXT NOT NULL);
            """)

    def train(self):
        data = generate()
        table = rows(data)
        X = np.array([r[0] for r in table])
        y = np.array([r[1] for r in table])
        baseline = np.array([r[2] for r in table])
        target = np.array([r[3] for r in table])
        train, validation, test = target < 140, (target >= 140) & (target < 175), target >= 175
        model = RandomForestRegressor(n_estimators=40, max_depth=10, min_samples_leaf=3, random_state=41, n_jobs=1)
        model.fit(X[train], y[train])
        candidate = np.maximum(0, model.predict(X))
        validation_pass = mean_absolute_error(y[validation], candidate[validation]) <= mean_absolute_error(y[validation], baseline[validation])
        # Final holdout is an acceptance veto, never used to retune the candidate.
        holdout_pass = mean_absolute_error(y[test], candidate[test]) <= mean_absolute_error(y[test], baseline[test])
        candidate_pass = validation_pass and holdout_pass
        selected = candidate if candidate_pass else baseline
        metrics = {"validation_pass": True, "selected": "random_forest" if candidate_pass else "seasonal_naive",
                   "candidate_eligible": bool(candidate_pass), "candidate_validation_pass": bool(validation_pass),
                   "candidate_holdout_pass": bool(holdout_pass), "test_candidate": scores(y[test], candidate[test]),
                   "validation_candidate": scores(y[validation], candidate[validation]),
                   "validation_baseline": scores(y[validation], baseline[validation]), "test_selected": scores(y[test], selected[test]),
                   "test_baseline": scores(y[test], baseline[test]), "test_slices": {}, "data_type": "synthetic", "seed": 41}
        for horizon in range(1, 8):
            mask = test & (np.array([r[5] for r in table]) == horizon)
            metrics["test_slices"][str(horizon)] = scores(y[mask], selected[mask])
        # Same one-day inventory policy and costs for both methods; a simulation, not measured savings.
        mask = test & (np.array([r[5] for r in table]) == 1)
        def policy(pred):
            stock = np.ceil(pred[mask]+2)
            return {"unfilled_units": float(np.maximum(y[mask]-stock, 0).sum()),
                    "holding_units": float(np.maximum(stock-y[mask], 0).sum()),
                    "assumptions": "daily reset, zero starting stock, immediate delivery, safety buffer=2; synthetic demand"}
        metrics["inventory_simulation"] = {"selected": policy(selected), "baseline": policy(baseline)}
        splits = {"rule": "target_day", "train": [28,139], "validation": [140,174], "test": [175,223],
                  "feature_cutoff": "strictly before each origin", "counts": [int(x.sum()) for x in (train, validation, test)]}
        return self.runtime.release({"estimator": model, "selected": metrics["selected"]}, data, splits, metrics,
                                    "daily-lags-v1", {"horizon": 7, "buffer_units": 2})

    def forecast(self, origin=None, fail_before_publish=False):
        release, model = self.runtime.load()
        data = json.loads((self.runtime.state / "releases" / release["release_id"] / "dataset.json").read_text())
        origin = origin if origin is not None else min(map(len, data.values()))
        if not 28 <= origin <= min(map(len, data.values())):
            raise ValueError("Origin outside observed history")
        batch = digest([release["release_id"], origin])
        results = []
        for product, (sku, series) in enumerate(sorted(data.items())):
            for horizon in range(1, 8):
                baseline = series[origin-7+horizon-1]
                vector = features(series[:origin], origin+horizon-1, horizon, product)
                value = max(0, float(model["estimator"].predict([vector])[0])) if model["selected"] == "random_forest" else baseline
                results.append((batch, sku, horizon, value, baseline))
        with database(self.runtime.db) as db:
            db.execute("INSERT OR IGNORE INTO batches VALUES(?,?,?,?)", (batch, release["release_id"], origin, time.time()))
            db.executemany("INSERT OR IGNORE INTO forecasts VALUES(?,?,?,?,?)", results)
            if fail_before_publish:
                raise RuntimeError("Injected failure before atomic publication")
            db.execute("INSERT OR REPLACE INTO current_batch VALUES(1,?)", (batch,))
        self.runtime.emit("batch_published", release_id=release["release_id"], batch=batch)
        return {"batch_id": batch, "rows": len(results), "origin": origin, "release_id": release["release_id"]}

    def get_forecast(self, sku):
        with database(self.runtime.db) as db:
            records = db.execute("SELECT f.*, b.created, b.origin, b.release_id FROM forecasts f JOIN batches b ON b.id=f.batch JOIN current_batch c ON c.batch=b.id WHERE f.sku=? ORDER BY f.horizon", (sku,)).fetchall()
        if not records:
            raise ValueError("No published forecast for product")
        output = [dict(r) for r in records]
        for row in output:
            row["date"] = (date(2025,1,1)+timedelta(days=row["origin"]+row["horizon"]-1)).isoformat()
        return {"sku": sku, "stale": time.time()-output[0]["created"] > 86400, "forecasts": output}

    def planner(self, sku=None):
        # Read one SQLite snapshot; all chart/evaluation evidence belongs to this batch.
        with database(self.runtime.db) as db:
            db.execute("BEGIN")
            batch = db.execute("SELECT b.* FROM batches b JOIN current_batch c ON c.batch=b.id WHERE c.slot=1").fetchone()
            reviews = [json.loads(r[0]) for r in db.execute("SELECT snapshot FROM replenishment_reviews ORDER BY created_at DESC LIMIT 30")]
            if batch is None:
                if sku is not None:
                    raise HTTPException(404, "No published forecast for product")
                return {"batch": None, "products": [], "reviews": reviews, "batches": []}
            batch = dict(batch)
            batch["stale"] = time.time()-batch["created"] > 86400
            products = [dict(r) for r in db.execute("""SELECT f.sku, SUM(f.prediction) demand,
                i.on_hand, COALESCE(i.revision,0) revision, i.updated_at
                FROM forecasts f LEFT JOIN inventory i ON i.sku=f.sku WHERE f.batch=? GROUP BY f.sku ORDER BY f.sku""", (batch["id"],))]
            batches = [dict(r) for r in db.execute("SELECT * FROM batches ORDER BY created DESC LIMIT 5")]
            forecasts = [dict(r) for r in db.execute("SELECT horizon,prediction,baseline FROM forecasts WHERE batch=? AND sku=? ORDER BY horizon", (batch["id"], sku))] if sku else []
        release, _ = self.runtime.load(batch["release_id"])
        folder = self.runtime.state / "releases" / batch["release_id"]
        metrics = json.loads((folder / "metrics.json").read_text())
        active_path = self.runtime.state / "active.json"
        active = json.loads(active_path.read_text())["release_id"] if active_path.exists() else None
        buffer = release["policy"]["buffer_units"]
        for product in products:
            product["recommended_units"] = None if product["on_hand"] is None else max(0, math.ceil(product["demand"])+buffer-product["on_hand"])
        result = {"batch": batch, "products": products, "batches": batches, "reviews": reviews,
                  "metrics": metrics, "active_release_id": active, "buffer_units": buffer,
                  "release_mismatch": active != batch["release_id"]}
        if sku is not None:
            product = next((p for p in products if p["sku"] == sku), None)
            if product is None:
                raise HTTPException(404, "No published forecast for product")
            data = json.loads((folder / "dataset.json").read_text())[sku]
            anchor = date(2025, 1, 1)
            history = [{"date": (anchor+timedelta(days=d)).isoformat(), "actual": data[d]} for d in range(max(0,batch["origin"]-28),batch["origin"])]
            for row in forecasts:
                row["date"] = (anchor+timedelta(days=batch["origin"]+row["horizon"]-1)).isoformat()
            result.update(product=product, history=history, forecasts=forecasts)
        return result

    def save_inventory(self, sku, payload):
        with database(self.runtime.db) as db:
            db.execute("BEGIN IMMEDIATE")
            if not db.execute("SELECT 1 FROM forecasts f JOIN current_batch c ON c.batch=f.batch WHERE f.sku=?", (sku,)).fetchone():
                raise HTTPException(404, "No published forecast for product")
            old = db.execute("SELECT revision FROM inventory WHERE sku=?", (sku,)).fetchone()
            if payload.revision != (old[0] if old else 0):
                raise HTTPException(409, "Inventory changed. Refresh and review the latest quantity.")
            value = {"sku": sku, "on_hand": payload.on_hand, "revision": payload.revision+1, "updated_at": time.time()}
            db.execute("INSERT OR REPLACE INTO inventory VALUES(?,?,?,?)", tuple(value.values()))
        return value

    def save_review(self, payload):
        values = payload.model_dump()
        request_hash = digest(values)
        with database(self.runtime.db) as db:
            db.execute("BEGIN IMMEDIATE")
            existing = db.execute("SELECT request_hash,snapshot FROM replenishment_reviews WHERE request_id=?", (payload.request_id,)).fetchone()
            if existing:
                if existing["request_hash"] != request_hash:
                    raise HTTPException(409, "Request ID already used for a different review")
                return json.loads(existing["snapshot"])
            batch = db.execute("SELECT b.* FROM batches b JOIN current_batch c ON c.batch=b.id WHERE c.slot=1").fetchone()
            inventory = db.execute("SELECT * FROM inventory WHERE sku=?", (payload.sku,)).fetchone()
            if batch is None or batch["id"] != payload.batch_id:
                raise HTTPException(409, "Published batch changed. Refresh before reviewing.")
            if inventory is None or inventory["revision"] != payload.inventory_revision:
                raise HTTPException(409, "Save inventory and refresh before reviewing.")
            demand = db.execute("SELECT SUM(prediction) FROM forecasts WHERE batch=? AND sku=?", (payload.batch_id, payload.sku)).fetchone()[0]
            if demand is None:
                raise HTTPException(404, "No published forecast for product")
            release, _ = self.runtime.load(batch["release_id"])
            stale = time.time()-batch["created"] > 86400
            if stale and payload.decision == "approved":
                raise HTTPException(409, "Batch is over 24 hours old. Publish a fresh batch or defer this review.")
            result = {**values, "on_hand": inventory["on_hand"], "demand": demand,
                      "recommended_units": max(0, math.ceil(demand)+release["policy"]["buffer_units"]-inventory["on_hand"]),
                      "release_id": batch["release_id"], "stale": stale, "created_at": time.time()}
            db.execute("INSERT INTO replenishment_reviews VALUES(?,?,?,?,?)", (payload.request_id, request_hash, payload.sku, result["created_at"], json.dumps(result)))
        return result

    def api(self):
        frontend = Path(__file__).parent / "frontend"
        api = make_api(self.runtime, home_file=frontend / "index.html")
        api.mount("/assets", StaticFiles(directory=frontend), name="assets")

        def read_planner(sku=None):
            try:
                return self.planner(sku)
            except (OSError, ValueError, KeyError) as error:
                raise HTTPException(503, "Published release evidence unavailable. Check the release artifacts.") from error

        def check_origin(request):
            origin = request.headers.get("origin")
            if origin and origin != str(request.base_url).rstrip("/"):
                raise HTTPException(403, "Write requests must originate from this application")

        @api.get("/v1/planner")
        def planner():
            return read_planner()

        @api.get("/v1/products/{sku}/planning")
        def product_planning(sku: str):
            return read_planner(sku)

        @api.put("/v1/inventory/{sku}")
        def inventory(sku: str, payload: InventoryInput, request: Request):
            check_origin(request)
            return self.save_inventory(sku, payload)

        @api.post("/v1/replenishment-reviews")
        def review(payload: ReviewInput, request: Request):
            check_origin(request)
            try:
                return self.save_review(payload)
            except (OSError, ValueError, KeyError) as error:
                raise HTTPException(503, "Published release evidence unavailable") from error

        @api.get("/v1/forecasts/{sku}")
        def forecast(sku: str):
            try:
                return self.get_forecast(sku)
            except ValueError as error:
                raise HTTPException(404, str(error))
        @api.get("/v1/recommendations/{sku}")
        def recommendation(sku: str, inventory: int = 0):
            if inventory < 0:
                raise HTTPException(422, "Inventory cannot be negative")
            result = forecast(sku)
            result["advisory_order_units"] = max(0, math.ceil(sum(x["prediction"] for x in result["forecasts"])+2-inventory))
            result["assumptions"] = "7-day coverage, buffer=2, inventory supplied by caller; no purchase is made"
            return result
        return api

    def demo(self):
        release = self.train()
        self.runtime.activate(release["release_id"])
        self.forecast()
        return self.runtime.report()

    def exercise(self):
        before = self.get_forecast("SKU-000")
        try:
            self.forecast(origin=200, fail_before_publish=True)
        except RuntimeError:
            self.runtime.emit("batch_failed", error=1, reason="injected_publication_failure")
        after = self.get_forecast("SKU-000")
        assert before == after
        return {"exercise": "atomic_batch_recovery", "passed": True, "preserved_batch": after["forecasts"][0]["batch"]}

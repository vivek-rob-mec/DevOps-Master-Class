import json
from pathlib import Path
import time
from typing import Literal

import numpy as np
from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict, Field
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, brier_score_loss
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

from mlops_common.runtime import Runtime, database, digest, encode, make_api
from mlops_common.operations import ReviewBase, dashboard_api, evidence, init_reviews, reviews, save_review


class Transaction(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)
    event_id: str = Field(min_length=1, max_length=80, pattern=r"^[a-zA-Z0-9_-]+$")
    entity_id: str = Field(min_length=1, max_length=80, pattern=r"^[a-zA-Z0-9_-]+$")
    amount_minor: int = Field(ge=0, le=100000000, strict=True)
    currency: str = Field(default="USD", pattern="^(USD|EUR|INR)$")
    event_time: float = Field(gt=0)


class Label(BaseModel):
    model_config = ConfigDict(extra="forbid")
    event_id: str
    fraud: bool = Field(strict=True)
    available_at: float = Field(gt=0, allow_inf_nan=False)


class RiskReview(ReviewBase):
    event_id: str = Field(min_length=1, max_length=80, pattern=r"^[a-zA-Z0-9_-]+$")
    decision: Literal['escalate', 'clear']


def features(event, history, cutoff):
    prior = [x for x in history if x["entity_id"] == event["entity_id"] and x["currency"] == event["currency"]
             and event["event_time"]-86400 <= x["event_time"] < event["event_time"] and x["received_at"] <= cutoff]
    recent = [x for x in prior if x["event_time"] >= event["event_time"]-3600]
    mean = float(np.mean([x["amount_minor"] for x in prior])) if prior else 0.0
    return [float(np.log1p(event["amount_minor"])), len(recent), len(prior), float(np.log1p(mean)),
            event["amount_minor"] / max(mean, 100)]


def generate(seed=52, size=1800):
    rng = np.random.default_rng(seed)
    events, history, vectors = [], [], []
    for index in range(size):
        fraud = bool(rng.random() < 0.09)
        timestamp = 1700000000 + index*600
        event = {"event_id": f"TX-{index}", "entity_id": f"E-{int(rng.integers(0,40))}",
                 "currency": "USD", "event_time": timestamp, "received_at": timestamp,
                 "amount_minor": int(rng.lognormal(8.1 if fraud else 6.6, 0.65)),
                 "fraud": fraud, "label_available_at": timestamp+int(rng.integers(7200,172800))}
        vectors.append(features(event, history, timestamp))
        events.append(event)
        history.append(event)
    return events, np.array(vectors)


def rules(events):
    return np.array([x["amount_minor"]/(x["amount_minor"]+5000) for x in events])


def evaluate(labels, scores, threshold):
    labels = np.array(labels, dtype=int)
    review = np.array(scores) >= threshold
    return {"average_precision": float(average_precision_score(labels, scores)),
            "brier": float(brier_score_loss(labels, scores)), "review_rate": float(review.mean()),
            "recall_at_threshold": float(labels[review].sum()/max(1,labels.sum())),
            "false_positive_rate": float(((labels==0)&review).sum()/max(1,(labels==0).sum()))}


class Project:
    def __init__(self, root=None):
        self.runtime = Runtime(root or Path(__file__).parent, "payment-risk")
        with database(self.runtime.db) as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS decisions(event_id TEXT PRIMARY KEY, payload_hash TEXT, event TEXT, features TEXT, response TEXT);
                CREATE TABLE IF NOT EXISTS labels(event_id TEXT PRIMARY KEY, fraud INTEGER, available REAL);
            """)
        init_reviews(self.runtime.db)

    def train(self):
        events, X = generate()
        y = np.array([int(x["fraud"]) for x in events])
        cutoff = events[1100]["event_time"]
        train = np.array([i < 1100 and x["label_available_at"] <= cutoff for i,x in enumerate(events)])
        validation = np.arange(1100,1450)
        test = np.arange(1450,len(events))
        model = make_pipeline(StandardScaler(), LogisticRegression(C=0.3, max_iter=300, random_state=52))
        model.fit(X[train], y[train])
        predicted = model.predict_proba(X)[:,1]
        baseline = rules(events)
        candidate_pass = average_precision_score(y[validation], predicted[validation]) >= average_precision_score(y[validation], baseline[validation])
        chosen = predicted if candidate_pass else baseline
        threshold = float(np.quantile(chosen[validation], 0.90))
        metrics = {"validation_pass": True, "selected": "logistic" if candidate_pass else "amount_rule",
                   "candidate_eligible": bool(candidate_pass), "review_threshold": threshold,
                   "validation_candidate_ap": float(average_precision_score(y[validation], predicted[validation])),
                   "validation_baseline_ap": float(average_precision_score(y[validation], baseline[validation])),
                   "test_selected": evaluate(y[test], chosen[test], threshold),
                   "test_baseline": evaluate(y[test], baseline[test], float(np.quantile(baseline[validation], .90))),
                   "labels_excluded_at_training_cutoff": int(1100-train.sum()), "data_type": "synthetic",
                   "label_evaluation": "eventually matured simulator outcomes; not assumed available at decision time"}
        splits = {"train_event_ids": [events[i]["event_id"] for i in np.where(train)[0]],
                  "training_cutoff": cutoff, "validation_ids": [events[i]["event_id"] for i in validation],
                  "test_ids": [events[i]["event_id"] for i in test]}
        return self.runtime.release({"estimator": model, "selected": metrics["selected"]}, events, splits, metrics,
                                    "asof-amount-velocity-v1", {"threshold": threshold, "review_capacity_target": .10})

    def score(self, raw, received_at=None):
        event = Transaction.model_validate(raw).model_dump()
        now = time.time() if received_at is None else received_at
        if event["event_time"] > now+300:
            raise ValueError("Event time too far in the future")
        fingerprint = digest(event)
        # Local inference only: one short write transaction serializes the learning ledger.
        # No external network calls or remote models are allowed inside this transaction.
        with database(self.runtime.db) as db:
            db.execute("BEGIN IMMEDIATE")
            existing = db.execute("SELECT payload_hash,response FROM decisions WHERE event_id=?", (event["event_id"],)).fetchone()
            if existing:
                if existing["payload_hash"] != fingerprint:
                    raise ValueError("Conflicting duplicate event")
                return json.loads(existing["response"])
            release, model = self.runtime.load()
            history = [json.loads(r[0]) for r in db.execute("SELECT event FROM decisions")]
            vector = features(event, history, now)
            score = float(model["estimator"].predict_proba([vector])[0,1]) if model["selected"] == "logistic" else float(rules([event])[0])
            response = {"event_id": event["event_id"], "risk_score": score, "score_type": model["selected"],
                        "advisory": "review" if score >= release["policy"]["threshold"] else "low_risk",
                        "release_id": release["release_id"], "feature_schema": release["feature_schema"], "features": vector}
            event["received_at"] = now
            db.execute("INSERT INTO decisions VALUES(?,?,?,?,?)", (event["event_id"], fingerprint, encode(event), encode(vector), encode(response)))
        return response

    def label(self, raw):
        label = Label.model_validate(raw)
        with database(self.runtime.db) as db:
            db.execute("BEGIN IMMEDIATE")
            if not db.execute("SELECT 1 FROM decisions WHERE event_id=?", (label.event_id,)).fetchone():
                raise ValueError("Unknown scored event")
            existing = db.execute("SELECT fraud,available FROM labels WHERE event_id=?", (label.event_id,)).fetchone()
            desired = (int(label.fraud),label.available_at)
            if existing and tuple(existing) != desired:
                raise ValueError("Conflicting label; corrections require a new audited workflow")
            db.execute("INSERT OR IGNORE INTO labels VALUES(?,?,?)", (label.event_id,*desired))
        return {"recorded": label.event_id}

    def outcomes(self, cutoff):
        with database(self.runtime.db) as db:
            total = db.execute("SELECT count(*) FROM decisions").fetchone()[0]
            records = db.execute("SELECT d.response,l.fraud FROM decisions d JOIN labels l USING(event_id) WHERE l.available<=?", (cutoff,)).fetchall()
        return {"scored": total, "matured_labels": len(records), "coverage": len(records)/max(1,total),
                "matured_fraud": sum(r["fraud"] for r in records), "unknown_are_not_negatives": True}

    def api(self):
        api = dashboard_api(self.runtime, Path(__file__).parent/'frontend')

        @api.get('/v1/desk')
        def desk():
            return self.desk()

        @api.get('/v1/risk-decisions/{event_id}')
        def decision(event_id: str):
            return self.decision(event_id)

        @api.post('/v1/risk-reviews')
        def review(payload: RiskReview):
            def snapshot(db):
                row = db.execute('SELECT event,response FROM decisions WHERE event_id=?', (payload.event_id,)).fetchone()
                if row is None:
                    raise HTTPException(404, 'Unknown scored event')
                return {'event': json.loads(row['event']), 'decision': json.loads(row['response'])}
            return save_review(self.runtime.db, payload, payload.event_id, snapshot)
        @api.post("/v1/risk-decisions")
        def score(event: Transaction):
            try:
                return self.score(event.model_dump())
            except ValueError as error:
                raise HTTPException(409 if "duplicate" in str(error) else 422 if "future" in str(error) else 503, str(error))
            except OSError:
                raise HTTPException(503, "Serving artifact unavailable")
        @api.post("/v1/labels")
        def label(value: Label):
            try:
                return self.label(value.model_dump())
            except ValueError as error:
                raise HTTPException(409, str(error))
        @api.get("/v1/outcomes")
        def outcomes():
            return self.outcomes(time.time())
        return api

    def desk(self):
        with database(self.runtime.db) as db:
            db.execute('BEGIN')
            summary = dict(db.execute("""SELECT COUNT(*) scored,
                COALESCE(SUM(json_extract(response,'$.advisory')='review'),0) flagged,
                (SELECT COUNT(*) FROM operator_reviews) reviewed,
                (SELECT COUNT(*) FROM labels WHERE available<=?) matured_labels
                FROM decisions""", (time.time(),)).fetchone())
            ledger = [self.decision_row(r) for r in db.execute("""SELECT d.event,d.response,l.fraud,l.available,r.snapshot review
                FROM decisions d LEFT JOIN labels l USING(event_id)
                LEFT JOIN operator_reviews r ON r.target=d.event_id
                ORDER BY json_extract(d.event,'$.received_at') DESC,d.event_id LIMIT 200""")]
            saved = reviews(db)
        return {'summary': summary, 'decisions': ledger, 'reviews': saved, 'active_model': evidence(self.runtime), 'limit': 200}

    @staticmethod
    def decision_row(row):
        available = row['available']
        matured = available is not None and available <= time.time()
        return {'event': json.loads(row['event']), 'decision': json.loads(row['response']),
                'label': {'state': 'unknown' if available is None else 'matured' if matured else 'pending',
                          'available_at': available, 'fraud': bool(row['fraud']) if matured else None},
                'review': json.loads(row['review']) if row['review'] else None}

    def decision(self, event_id):
        with database(self.runtime.db) as db:
            row = db.execute("""SELECT d.event,d.response,l.fraud,l.available,r.snapshot review
                FROM decisions d LEFT JOIN labels l USING(event_id)
                LEFT JOIN operator_reviews r ON r.target=d.event_id WHERE d.event_id=?""", (event_id,)).fetchone()
        if row is None:
            raise HTTPException(404, 'Unknown scored event')
        result = self.decision_row(row)
        result['model'] = evidence(self.runtime, result['decision']['release_id'])
        return result

    def demo(self):
        release = self.train()
        self.runtime.activate(release["release_id"])
        sample = {"event_id": "DEMO-"+release["release_id"], "entity_id": "E-demo", "amount_minor": 5000,
                  "currency": "USD", "event_time": 1700000000.0}
        self.score(sample)
        return self.runtime.report()

    def exercise(self):
        event = {"event_id": "EX-"+str(time.time_ns()), "entity_id": "E-demo", "amount_minor": 7000,
                 "currency": "USD", "event_time": 1700000001.0}
        first = self.score(event)
        assert self.score(event) == first
        try:
            self.score(dict(event, amount_minor=1))
            raise AssertionError("Conflict accepted")
        except ValueError:
            pass
        self.label({"event_id": event["event_id"], "fraud": True, "available_at": time.time()+86400})
        assert self.outcomes(time.time()+86401)["matured_labels"] > self.outcomes(time.time())["matured_labels"]
        self.runtime.emit("exercise", delayed_label=True, duplicate_preserved=True)
        return {"exercise": "duplicates_and_delayed_feedback", "passed": True}

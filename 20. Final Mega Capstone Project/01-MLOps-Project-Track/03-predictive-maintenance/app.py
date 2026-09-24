import json
from pathlib import Path
import time
from typing import Literal

import numpy as np
from fastapi import HTTPException, Query
from pydantic import BaseModel, ConfigDict, Field
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error

from mlops_common.runtime import Runtime, database, digest, encode, make_api
from mlops_common.operations import ReviewBase, dashboard_api, evidence, init_reviews, reviews, save_review


class Sensor(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)
    site: str = Field(default="lab", min_length=1, max_length=40)
    equipment: str = Field(min_length=1, max_length=60)
    sequence: int = Field(ge=1, strict=True)
    temperature: float = Field(ge=0, le=300)
    vibration: float = Field(ge=0, le=1000)


class InspectionReview(ReviewBase):
    site: str = Field(min_length=1, max_length=40)
    equipment: str = Field(min_length=1, max_length=60)
    sequence: int = Field(ge=1, strict=True)
    decision: Literal['inspect', 'defer']


def features(window):
    if len(window) < 5 or any(b["sequence"] != a["sequence"]+1 for a,b in zip(window[-5:],window[-4:])):
        raise ValueError("Five consecutive samples required")
    window = window[-5:]
    return [window[-1]["sequence"], window[-1]["temperature"], window[-1]["vibration"],
            float(np.mean([x["temperature"] for x in window])),
            (window[-1]["vibration"]-window[0]["vibration"])/4]


def generate(seed=63, units=50):
    rng = np.random.default_rng(seed)
    data = []
    for unit in range(units):
        lifetime = int(rng.integers(80,141))
        samples = []
        for cycle in range(1,lifetime+1):
            wear = cycle/lifetime
            samples.append({"site": "lab", "equipment": f"M-{unit:03d}", "sequence": cycle,
                            "temperature": round(float(35+45*wear+rng.normal(0,.5)),4),
                            "vibration": round(float(2+12*wear**2+rng.normal(0,.04)),4)})
        data.append({"equipment": f"M-{unit:03d}", "lifetime": lifetime, "samples": samples})
    return data


class Project:
    def __init__(self, root=None):
        self.runtime = Runtime(root or Path(__file__).parent, "predictive-maintenance")
        self.central = self.runtime.state / "central.db"
        with database(self.runtime.db) as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS sensors(site TEXT,equipment TEXT,sequence INTEGER,event TEXT,response TEXT,PRIMARY KEY(site,equipment,sequence));
                CREATE TABLE IF NOT EXISTS spool(id TEXT PRIMARY KEY,payload TEXT);
            """)
        with database(self.central) as db:
            db.execute("CREATE TABLE IF NOT EXISTS ingested(id TEXT PRIMARY KEY,payload TEXT)")
        init_reviews(self.runtime.db)

    def train(self):
        data = generate()
        rows = []
        for unit, record in enumerate(data):
            for end in range(5,len(record["samples"])+1):
                window = record["samples"][end-5:end]
                rows.append((features(window),record["lifetime"]-end,unit))
        X = np.array([r[0] for r in rows])
        y = np.array([r[1] for r in rows])
        units = np.array([r[2] for r in rows])
        train, validation, test = units<30, (units>=30)&(units<40), units>=40
        expected_life = float(np.mean([r["lifetime"] for r in data[:30]]))
        baseline = np.maximum(0,expected_life-X[:,0])
        model = RandomForestRegressor(n_estimators=40,max_depth=10,min_samples_leaf=3,random_state=63,n_jobs=1)
        model.fit(X[train],y[train])
        predicted = np.maximum(0,model.predict(X))
        passed = mean_absolute_error(y[validation],predicted[validation]) <= mean_absolute_error(y[validation],baseline[validation])
        chosen = predicted if passed else baseline
        metrics = {"validation_pass": True,"candidate_eligible": bool(passed),"selected": "random_forest" if passed else "age_baseline",
                   "validation_candidate_mae": float(mean_absolute_error(y[validation],predicted[validation])),
                   "validation_baseline_mae": float(mean_absolute_error(y[validation],baseline[validation])),
                   "test_mae_cycles": float(mean_absolute_error(y[test],chosen[test])),
                   "test_rmse_cycles": float(mean_squared_error(y[test],chosen[test])**.5),
                   "test_baseline_mae_cycles": float(mean_absolute_error(y[test],baseline[test])),
                   "per_equipment_mae": {str(i):float(mean_absolute_error(y[units==i],chosen[units==i])) for i in range(40,50)},
                   "data_type": "synthetic degradation, not NASA or physical equipment"}
        # One first persistent warning per unit; no inflation from overlapping windows.
        leads, false = [], 0
        for unit in range(40,50):
            indices = np.where(units==unit)[0]
            first = next((i for i in range(2,len(indices)) if all(chosen[indices[j]]<=20 for j in range(i-2,i+1))),None)
            if first is not None:
                lead = float(y[indices[first]])
                leads.append(lead)
                false += int(lead>30)
        metrics["warning_policy"] = {"threshold_cycles":20,"consecutive":3,"warned_units":len(leads),
                                     "test_units":10,"early_false_warnings_over_30_cycles":false,"lead_cycles":leads}
        return self.runtime.release({"estimator":model,"selected":metrics["selected"],"expected_life":expected_life},data,
                                    {"train_units":list(range(30)),"validation_units":list(range(30,40)),"test_units":list(range(40,50))},
                                    metrics,"trailing-five-v1",{"inspection_threshold":20,"consecutive":3,"spool_limit":1000})

    def ingest(self, raw):
        event = Sensor.model_validate(raw).model_dump()
        key = (event["site"],event["equipment"],event["sequence"])
        with database(self.runtime.db) as db:
            db.execute("BEGIN IMMEDIATE")
            existing = db.execute("SELECT event,response FROM sensors WHERE site=? AND equipment=? AND sequence=?",key).fetchone()
            if existing:
                if json.loads(existing["event"]) != event:
                    raise ValueError("Conflicting duplicate sequence")
                return json.loads(existing["response"])
            if db.execute("SELECT count(*) FROM spool").fetchone()[0] >= 1000:
                raise OverflowError("Spool full; ingestion backpressure, no acknowledgement")
            previous = db.execute("SELECT event,response FROM sensors WHERE site=? AND equipment=? ORDER BY sequence DESC LIMIT 4",key[:2]).fetchall()
            window = [json.loads(r["event"]) for r in reversed(previous)] + [event]
            if previous and event["sequence"] <= window[-2]["sequence"]:
                raise ValueError("Out-of-order sequence rejected; already issued predictions are immutable")
            try:
                vector = features(window)
            except ValueError:
                response = {"state":"insufficient_history","remaining_cycles":None,"release_id":None,"inspection_advisory":False}
            else:
                release, model = self.runtime.load()
                prediction = max(0,float(model["estimator"].predict([vector])[0])) if model["selected"]=="random_forest" else max(0,model["expected_life"]-event["sequence"])
                earlier = [json.loads(r["response"]) for r in previous[:2]]
                warning = prediction<=20 and len(earlier)==2 and all(r.get("remaining_cycles") is not None and r["remaining_cycles"]<=20 and r.get("release_id")==release["release_id"] for r in earlier)
                response = {"state":"predicted","remaining_cycles":prediction,"release_id":release["release_id"],"inspection_advisory":warning}
            response.update({"site":event["site"],"equipment":event["equipment"],"sequence":event["sequence"]})
            db.execute("INSERT INTO sensors VALUES(?,?,?,?,?)",(*key,encode(event),encode(response)))
            payload = {"event":event,"prediction":response}
            db.execute("INSERT INTO spool VALUES(?,?)",(digest(key),encode(payload)))
        return response

    def accept_batch(self, rows):
        with database(self.central) as db:
            for row in rows:
                previous = db.execute("SELECT payload FROM ingested WHERE id=?",(row["id"],)).fetchone()
                if previous and previous["payload"] != row["payload"]:
                    raise ValueError("Central duplicate conflict")
                db.execute("INSERT OR IGNORE INTO ingested VALUES(?,?)",(row["id"],row["payload"]))
        return [r["id"] for r in rows]

    def flush(self, sink=None):
        with database(self.runtime.db) as db:
            rows = [dict(r) for r in db.execute("SELECT * FROM spool ORDER BY id LIMIT 100")]
        acknowledged = (sink or self.accept_batch)(rows)
        if set(acknowledged) != {r["id"] for r in rows}:
            raise ValueError("Incomplete acknowledgement; retain batch")
        with database(self.runtime.db) as db:
            db.executemany("DELETE FROM spool WHERE id=?",[(key,) for key in acknowledged])
        return {"acknowledged":len(acknowledged)}

    def latest(self,equipment,site='lab'):
        with database(self.runtime.db) as db:
            row=db.execute("SELECT response FROM sensors WHERE site=? AND equipment=? ORDER BY sequence DESC LIMIT 1",(site,equipment)).fetchone()
        if not row:
            raise ValueError("Unknown equipment")
        return json.loads(row[0])

    def api(self):
        api=dashboard_api(self.runtime, Path(__file__).parent/'frontend')

        @api.get('/v1/fleet')
        def fleet():
            return self.fleet()

        @api.get('/v1/equipment-history')
        def history(site: str = Query(min_length=1,max_length=40), equipment: str = Query(min_length=1,max_length=60)):
            return self.history(site,equipment)

        @api.post('/v1/inspection-reviews')
        def review(payload: InspectionReview):
            target = digest([payload.site,payload.equipment,payload.sequence])
            def snapshot(db):
                row = db.execute('SELECT event,response,sequence FROM sensors WHERE site=? AND equipment=? ORDER BY sequence DESC LIMIT 1', (payload.site,payload.equipment)).fetchone()
                if row is None:
                    raise HTTPException(404, 'Unknown equipment')
                if row['sequence'] != payload.sequence:
                    raise HTTPException(409, 'New sensor data arrived. Refresh before reviewing.')
                prediction = json.loads(row['response'])
                if prediction['state'] != 'predicted':
                    raise HTTPException(409, 'Five consecutive samples are required before a model-based inspection review')
                return {'event': json.loads(row['event']), 'prediction': prediction}
            return save_review(self.runtime.db,payload,target,snapshot)
        @api.post("/v1/sensor-events")
        def ingest(event:Sensor):
            try:
                return self.ingest(event.model_dump())
            except OverflowError as error:
                raise HTTPException(507,str(error))
            except (OSError,ValueError) as error:
                raise HTTPException(409 if "sequence" in str(error) else 503,str(error))
        @api.get("/v1/equipment/{equipment}/health-estimate")
        def latest(equipment:str,site:str='lab'):
            try:
                return self.latest(equipment,site)
            except ValueError as error:
                raise HTTPException(404,str(error))
        @api.post("/v1/spool/flush")
        def flush():
            return self.flush()
        return api

    def fleet(self):
        with database(self.runtime.db) as db:
            db.execute('BEGIN')
            units = [dict(event=json.loads(r['event']), prediction=json.loads(r['response'])) for r in db.execute('''
                SELECT s.event,s.response FROM sensors s JOIN
                (SELECT site,equipment,MAX(sequence) seq FROM sensors GROUP BY site,equipment) latest
                ON s.site=latest.site AND s.equipment=latest.equipment AND s.sequence=latest.seq
                ORDER BY s.site,s.equipment''')]
            queued = db.execute('SELECT COUNT(*) FROM spool').fetchone()[0]
            samples = db.execute('SELECT COUNT(*) FROM sensors').fetchone()[0]
            saved = reviews(db)
        with database(self.central) as db:
            central = db.execute('SELECT COUNT(*) FROM ingested').fetchone()[0]
        return {'equipment': units, 'reviews': saved, 'summary': {'units': len(units), 'samples': samples,
                'advisories': sum(u['prediction']['inspection_advisory'] for u in units), 'queued': queued,
                'central_rows': central, 'spool_limit': 1000}, 'active_model': evidence(self.runtime)}

    def history(self,site,equipment):
        with database(self.runtime.db) as db:
            db.execute('BEGIN')
            rows = db.execute('SELECT event,response,sequence FROM sensors WHERE site=? AND equipment=? ORDER BY sequence DESC LIMIT 60',(site,equipment)).fetchall()
            if not rows:
                raise HTTPException(404,'Unknown equipment')
            target = digest([site,equipment,rows[0]['sequence']])
            reviewed = db.execute('SELECT snapshot FROM operator_reviews WHERE target=?',(target,)).fetchone()
        records = [{'event':json.loads(r['event']),'prediction':json.loads(r['response'])} for r in reversed(rows)]
        release_id = records[-1]['prediction']['release_id']
        return {'site':site, 'equipment':equipment, 'samples':records, 'review':json.loads(reviewed[0]) if reviewed else None,
                'model': evidence(self.runtime,release_id) if release_id else {'available':False,'error':'No prediction yet: collect five consecutive samples.'}}

    def demo(self):
        release=self.train()
        self.runtime.activate(release["release_id"])
        for event in generate(units=1)[0]["samples"][:10]:
            self.ingest(event)
        return self.runtime.report()

    def exercise(self):
        equipment="exercise-"+str(time.time_ns())
        for event in generate(units=1)[0]["samples"][:5]:
            self.ingest(dict(event,equipment=equipment))
        def lost_ack(rows):
            self.accept_batch(rows)
            raise ConnectionError("Injected lost acknowledgement after central commit")
        try:
            self.flush(lost_ack)
        except ConnectionError:
            pass
        with database(self.central) as db:
            before=db.execute("SELECT count(*) FROM ingested").fetchone()[0]
        result=self.flush()
        with database(self.central) as db:
            after=db.execute("SELECT count(*) FROM ingested").fetchone()[0]
        assert before==after
        self.runtime.emit("spool_recovered",queue=0,duplicate_rows=after-before)
        return {"exercise":"lost_ack_replay","passed":True,"central_rows":after,**result}

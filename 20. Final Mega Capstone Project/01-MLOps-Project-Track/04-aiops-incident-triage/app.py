import json
from pathlib import Path
import time

import numpy as np
from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict, Field
from typing import Literal
from sklearn.ensemble import IsolationForest
from sklearn.metrics import precision_recall_fscore_support

from mlops_common.runtime import Runtime, database, digest, encode, make_api
from mlops_common.operations import dashboard_api, evidence as model_evidence

SERVICES = ('demand-forecasting', 'payment-risk', 'predictive-maintenance')
SAMPLE_KINDS = ('http', 'fault_fixture', 'healthy_fixture')


def rule(vector):
    latency,error,queue=vector
    return bool(latency>=100 or error>=.1 or queue>=20)


def generate(seed=74):
    rng=np.random.default_rng(seed)
    def normal(n):
        return np.column_stack([np.maximum(1,rng.normal(20,4,n)),np.maximum(0,rng.normal(.002,.001,n)),np.maximum(0,rng.normal(2,1,n))])
    train=normal(300)
    test=normal(100)
    faults=np.vstack([np.column_stack([rng.uniform(140,300,30),rng.uniform(.2,.8,30),rng.uniform(1,4,30)]),
                      np.column_stack([rng.uniform(15,30,30),rng.uniform(0,.005,30),rng.uniform(30,90,30)])])
    return train,np.vstack([test,faults]),np.array([0]*100+[1]*60)


class Review(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    decision: Literal["approved","rejected"]
    reviewer: str=Field(min_length=1,max_length=100)
    reason: str=Field(min_length=5,max_length=500)


class Fixture(BaseModel):
    model_config = ConfigDict(extra='forbid')
    request_id: str = Field(pattern=r'^[a-zA-Z0-9_-]{8,80}$')
    service: Literal['demand-forecasting','payment-risk','predictive-maintenance']
    scenario: Literal['latency_error','backlog','healthy']


class Project:
    def __init__(self,root=None):
        self.runtime=Runtime(root or Path(__file__).parent,"aiops-triage")
        with database(self.runtime.db) as db:
            db.execute("CREATE TABLE IF NOT EXISTS incidents(id TEXT PRIMARY KEY,service TEXT,evidence TEXT,proposal TEXT,state TEXT,review TEXT)")
            db.execute('BEGIN IMMEDIATE')
            columns = {r['name'] for r in db.execute('PRAGMA table_info(incidents)')}
            for name in ('created_at','reviewed_at'):
                if name not in columns:
                    db.execute(f'ALTER TABLE incidents ADD COLUMN {name} REAL')
            db.execute('''CREATE TABLE IF NOT EXISTS analysis_runs(id TEXT PRIMARY KEY,started REAL,
                completed REAL,detector_release TEXT,window_count INTEGER,incident_ids TEXT)''')
        with database(self.runtime.telemetry) as db:
            db.execute('CREATE TABLE IF NOT EXISTS aiops_fixture_runs(id TEXT PRIMARY KEY,payload_hash TEXT,response TEXT)')

    def train(self):
        train,test,labels=generate()
        model=IsolationForest(n_estimators=80,contamination=.03,random_state=74,n_jobs=1)
        model.fit(train)
        predicted=(model.predict(test)==-1).astype(int)
        baseline=np.array([int(rule(x)) for x in test])
        def metrics(values):
            p,r,f,_=precision_recall_fscore_support(labels,values,average="binary",zero_division=0)
            return {"precision":float(p),"recall":float(r),"f1":float(f),
                    "false_alerts":int(((labels==0)&(values==1)).sum())}
        report={"validation_pass":True,"selected":"isolation_forest_with_rule_comparison",
                "heldout_anomaly_detector":metrics(predicted),"heldout_static_rules":metrics(baseline),
                "baseline_source":"synthetic healthy telemetry","automatic_remediation":False,
                "scope":"anomaly screening and evidence correlation; no causal root-cause guarantee"}
        return self.runtime.release(model,{"train":train.tolist(),"test":test.tolist(),"labels":labels.tolist()},
                                    {"training":"300 independent healthy fixture windows","holdout":"100 healthy + 60 fault fixture windows","seed":74},
                                    report,"latency-error-backlog-v1",{"window_seconds":60,"minimum_samples":5})

    def telemetry(self,now=None):
        now=time.time() if now is None else now
        with database(self.runtime.telemetry) as db:
            records=[dict(r) for r in db.execute("SELECT * FROM events WHERE ts>=? AND ts<=? AND service!='aiops-triage' ORDER BY id",(now-60,now))]
        return records

    def windows(self,now=None,records=None):
        now=time.time() if now is None else now
        records=self.telemetry(now) if records is None else records
        services=sorted({r["service"] for r in records})
        output=[]
        for service in services:
            samples=[r for r in records if r["service"]==service and r["kind"] in ("http","fault_fixture","healthy_fixture")]
            if len(samples)<5:
                continue
            vector=[float(np.mean([x["latency"] for x in samples])),float(np.mean([x["error"] for x in samples])),float(max(x["queue"] for x in samples))]
            releases=[r for r in records if r["service"]==service and r["kind"]=="release_activated"]
            output.append({"service":service,"features":vector,"sample_count":len(samples),
                           "first_event_id":samples[0]["id"],"last_event_id":samples[-1]["id"],
                           "release_events":[r["id"] for r in releases],
                           "contains_fixture":any(r["kind"].endswith("fixture") for r in samples),
                           "window_start":now-60,"window_end":now,
                           "source_events":[{**r,'context':json.loads(r['context'])} for r in samples],
                           "release_event_snapshots":[{**r,'context':json.loads(r['context'])} for r in releases]})
        return output

    def analyze(self):
        started=time.time()
        release,model=self.runtime.load()
        findings=[]
        windows=self.windows(started)
        for window in windows:
            anomaly=bool(model.predict([window["features"]])[0]==-1)
            static=rule(window["features"])
            if not (anomaly or static):
                continue
            identifier=digest([window["service"],window["first_event_id"],window["last_event_id"],release["release_id"]])
            latency,error,queue=window["features"]
            hypotheses=[]
            if window["release_events"] and (error>=.1 or latency>=100):
                hypotheses.append({"hypothesis":"release regression","evidence_event_ids":window["release_events"],
                                   "next_check":"Compare changed model/schema with the earlier approved release; check error logs."})
            if queue>=20:
                hypotheses.append({"hypothesis":"consumer slowdown or disconnected edge","next_check":"Inspect worker health, link state, and oldest queued record."})
            if error>=.1:
                hypotheses.append({"hypothesis":"dependency or application failure","next_check":"Check readiness, artifact integrity, and database availability."})
            if not hypotheses:
                hypotheses.append({"hypothesis":"unusual latency distribution or baseline mismatch","next_check":"Inspect payload and resource changes; calibrate a service-specific baseline."})
            proposal={"hypotheses":hypotheses,"action":"Investigate the evidence; prepare a reviewed recovery change.",
                      "executes_commands":False,"causality_proven":False}
            evidence={**window,"anomaly":anomaly,"static_rule":static,"detector_release":release["release_id"]}
            with database(self.runtime.db) as db:
                db.execute("INSERT OR IGNORE INTO incidents(id,service,evidence,proposal,state,review,created_at) VALUES(?,?,?,?,?,?,?)",(identifier,window["service"],encode(evidence),encode(proposal),"pending",None,time.time()))
            findings.append(identifier)
        run_id=digest([release['release_id'],time.time_ns()])
        with database(self.runtime.db) as db:
            db.execute('INSERT INTO analysis_runs VALUES(?,?,?,?,?,?)',(run_id,started,time.time(),release['release_id'],len(windows),encode(findings)))
        return {"incident_ids":findings,"window_seconds":60,"minimum_samples":5,'analyzed_windows':len(windows),'run_id':run_id}

    def incidents(self):
        with database(self.runtime.db) as db:
            records=[dict(r) for r in db.execute("SELECT * FROM incidents ORDER BY rowid DESC LIMIT 100")]
        for row in records:
            for key in ("evidence","proposal","review"):
                row[key]=json.loads(row[key]) if row[key] else None
        return records

    def review(self,identifier,raw):
        review=Review.model_validate(raw).model_dump()
        with database(self.runtime.db) as db:
            db.execute("BEGIN IMMEDIATE")
            current=db.execute("SELECT state,review FROM incidents WHERE id=?",(identifier,)).fetchone()
            if not current:
                raise ValueError("Unknown incident")
            if current["state"]!="pending" and current["review"]!=encode(review):
                raise ValueError("Review already finalized")
            db.execute("UPDATE incidents SET reviewed_at=CASE WHEN state='pending' THEN ? ELSE reviewed_at END,state=?,review=? WHERE id=?",(time.time(),review["decision"],encode(review),identifier))
        return {"incident_id":identifier,"state":review["decision"],"executed":False}

    def api(self):
        api=dashboard_api(self.runtime,Path(__file__).parent/'frontend')
        @api.get('/v1/desk')
        def desk():
            return self.desk()
        @api.get('/v1/incidents/{identifier}')
        def incident(identifier:str):
            return self.incident(identifier)
        @api.post('/v1/fixtures')
        def fixture(payload:Fixture):
            return self.fixture(payload)
        @api.get("/v1/windows")
        def windows():
            return self.windows()
        @api.post("/v1/analyze")
        def analyze():
            try:
                return self.analyze()
            except (OSError,ValueError) as error:
                raise HTTPException(503,str(error))
        @api.get("/v1/incidents")
        def incidents():
            return self.incidents()
        @api.post("/v1/incidents/{identifier}/review")
        def review(identifier:str,value:Review):
            try:
                return self.review(identifier,value.model_dump())
            except ValueError as error:
                raise HTTPException(409,str(error))
        return api

    def desk(self):
        now=time.time()
        records=self.telemetry(now)
        windows={w['service']:w for w in self.windows(now,records)}
        with database(self.runtime.telemetry) as db:
            last_seen={r['service']:r['ts'] for r in db.execute("SELECT service,MAX(ts) ts FROM events WHERE ts<=? AND kind IN ('http','fault_fixture','healthy_fixture') AND service!='aiops-triage' GROUP BY service",(now,))}
        services=[]
        for service in sorted(set(SERVICES)|set(last_seen)):
            samples=[r for r in records if r['service']==service and r['kind'] in SAMPLE_KINDS]
            window=windows.get(service)
            services.append({'service':service,'sample_count':len(samples),'last_seen':last_seen.get(service),
                'status':'eligible' if window else 'insufficient_samples' if samples else 'no_recent_samples',
                'http_samples':sum(r['kind']=='http' for r in samples),
                'fixture_samples':sum(r['kind'].endswith('fixture') for r in samples),
                'features':window['features'] if window else None,
                'static_rule':rule(window['features']) if window else None,
                'queue_signal':'fixture' if any(r['kind'].endswith('fixture') for r in samples) else 'not_measured_by_http'})
        with database(self.runtime.db) as db:
            summary=dict(db.execute("SELECT COUNT(*) total,COALESCE(SUM(state='pending'),0) pending,COALESCE(SUM(state='approved'),0) approved,COALESCE(SUM(state='rejected'),0) rejected FROM incidents").fetchone())
            runs=[dict(r) for r in db.execute('SELECT * FROM analysis_runs ORDER BY completed DESC LIMIT 10')]
        for run in runs:
            run['incident_ids']=json.loads(run['incident_ids'])
        return {'observed_at':now,'window_seconds':60,'minimum_samples':5,'services':services,
            'summary':summary,'incidents':self.incidents(),'runs':runs,'active_model':model_evidence(self.runtime)}

    def incident(self,identifier):
        with database(self.runtime.db) as db:
            row=db.execute('SELECT * FROM incidents WHERE id=?',(identifier,)).fetchone()
        if row is None:
            raise HTTPException(404,'Unknown incident')
        result=dict(row)
        for key in ('evidence','proposal','review'):
            result[key]=json.loads(result[key]) if result[key] else None
        result['model']=model_evidence(self.runtime,result['evidence']['detector_release'])
        # Old incidents keep their original schema; never invent source snapshots.
        result['source_snapshots_available']='source_events' in result['evidence']
        return result

    def fixture(self,payload):
        values=payload.model_dump()
        fingerprint=digest(values)
        now=time.time()
        vector={'healthy':(20,0,2),'latency_error':(250,1,2),'backlog':(20,0,35)}[payload.scenario]
        kind='healthy_fixture' if payload.scenario=='healthy' else 'fault_fixture'
        with database(self.runtime.telemetry) as db:
            db.execute('BEGIN IMMEDIATE')
            previous=db.execute('SELECT payload_hash,response FROM aiops_fixture_runs WHERE id=?',(payload.request_id,)).fetchone()
            if previous:
                if previous['payload_hash']!=fingerprint:
                    raise HTTPException(409,'Fixture request ID already used for different data')
                return json.loads(previous['response'])
            context=encode({'scenario':payload.scenario,'fixture_id':payload.request_id,'simulated':True})
            ids=[]
            if payload.scenario=='latency_error':
                db.execute('INSERT INTO events(ts,service,kind,latency,error,queue,context) VALUES(?,?,?,?,?,?,?)',
                    (now,payload.service,'release_activated',0,0,0,encode({'release_id':'fixture-candidate','scenario':payload.scenario,'fixture_id':payload.request_id,'simulated':True})))
            for _ in range(10):
                cursor=db.execute('INSERT INTO events(ts,service,kind,latency,error,queue,context) VALUES(?,?,?,?,?,?,?)',(now,payload.service,kind,*vector,context))
                ids.append(cursor.lastrowid)
            result={'request_id':payload.request_id,'service':payload.service,'scenario':payload.scenario,'sample_count':10,'event_ids':ids,'created_at':now,'simulated':True}
            db.execute('INSERT INTO aiops_fixture_runs VALUES(?,?,?)',(payload.request_id,fingerprint,encode(result)))
        return result

    def demo(self):
        release=self.train()
        self.runtime.activate(release["release_id"])
        return self.runtime.report()

    def exercise(self):
        # Explicit telemetry fixtures: this does not crash or remotely alter the MLOps services.
        for service in ("demand-forecasting","payment-risk","predictive-maintenance"):
            source=Runtime(self.runtime.root,service)
            for _ in range(10):
                source.emit("healthy_fixture",latency=20,error=0,queue=2,scenario="controlled_replay")
            source.emit("release_activated",release_id="fixture-candidate",scenario="controlled_replay")
            for _ in range(15):
                source.emit("fault_fixture",latency=250,error=1,queue=35,scenario="controlled_replay")
        result=self.analyze()
        assert result["incident_ids"],"Expected incidents from the injected telemetry"
        reviewed=self.review(result["incident_ids"][0],{"decision":"approved","reviewer":"local-learner","reason":"Reviewed fixture evidence; no command execution authorized by the application."})
        return {"exercise":"telemetry_fault_replay","passed":True,**result,"review":reviewed}

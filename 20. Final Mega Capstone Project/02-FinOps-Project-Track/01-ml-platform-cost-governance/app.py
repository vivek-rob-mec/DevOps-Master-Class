"""Local FinOps teaching product. All bundled billing and usage are synthetic."""
import argparse
import calendar
from contextlib import contextmanager
import csv
from datetime import date
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
import hashlib
import io
import json
import os
from pathlib import Path
import re
import sqlite3
import time
from typing import Literal

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, ConfigDict, Field

ROOT=Path(__file__).parent
TEAMS=('retail','risk','operations','platform')
SERVICES={'demand-forecasting':('retail','forecasts'),'payment-risk':('risk','transactions'),
          'predictive-maintenance':('operations','sensor_readings'),'aiops-triage':('platform','reviewed_incidents')}
Currency=Literal['USD','EUR','INR']
Team=Literal['retail','risk','operations','platform']


def encode(value):
    return json.dumps(value,sort_keys=True,separators=(',',':'),allow_nan=False)


def digest(value):
    return hashlib.sha256(encode(value).encode()).hexdigest()


def money(value):
    return format(Decimal(value)/1000000,'.6f')


def round_int(value):
    return int(Decimal(value).quantize(Decimal(1),rounding=ROUND_HALF_UP))


def split_money(amount,weights):
    """Largest-remainder allocation. Includes credits; sum is exact to one micro-unit."""
    magnitude=abs(amount)
    values={team:magnitude*weight//10000 for team,weight in weights.items()}
    remaining=magnitude-sum(values.values())
    order=sorted(weights,key=lambda team:(-(magnitude*weights[team]%10000),team))
    for team in order[:remaining]: values[team]+=1
    return {team:value*(1 if amount>=0 else -1) for team,value in values.items()}


class Input(BaseModel):
    model_config=ConfigDict(extra='forbid',str_strip_whitespace=True)


class Import(Input):
    request_id:str=Field(pattern=r'^[a-zA-Z0-9_-]{8,80}$')
    period:str=Field(pattern=r'^20[0-9]{2}-(0[1-9]|1[0-2])$')
    currency:Currency
    through_day:int=Field(strict=True,ge=1,le=31)
    data_kind:Literal['synthetic']='synthetic'
    cost_csv:str=Field(min_length=1,max_length=500000)
    usage_csv:str=Field(min_length=1,max_length=300000)


class Policy(Input):
    revision:int=Field(strict=True,ge=1)
    retail:int=Field(strict=True,ge=0,le=10000)
    risk:int=Field(strict=True,ge=0,le=10000)
    operations:int=Field(strict=True,ge=0,le=10000)
    platform:int=Field(strict=True,ge=0,le=10000)


class Budget(Input):
    batch_id:str=Field(pattern=r'^[a-f0-9]{64}$')
    team:Team
    amount_micro:int=Field(strict=True,ge=0,le=1000000000000)
    revision:int=Field(strict=True,ge=0)


class Review(Input):
    request_id:str=Field(pattern=r'^[a-zA-Z0-9_-]{8,80}$')
    batch_id:str=Field(pattern=r'^[a-f0-9]{64}$')
    policy_revision:int=Field(strict=True,ge=1)
    team:Team
    reduction_percent:int=Field(strict=True,ge=0,le=50)
    decision:Literal['approved','rejected']
    reviewer:str=Field(min_length=1,max_length=80)
    reason:str=Field(min_length=5,max_length=1000)


def parse_csv(text,fields):
    reader=csv.DictReader(io.StringIO(text.lstrip('\ufeff')))
    if reader.fieldnames!=fields:
        raise ValueError('CSV headers must be exactly: '+','.join(fields))
    rows=[]
    for line,row in enumerate(reader,2):
        if line>1001: raise ValueError('Maximum 1000 rows per CSV')
        if None in row or any(value is None for value in row.values()):
            raise ValueError(f'Invalid CSV field count on line {line}')
        rows.append({k:v.strip() for k,v in row.items()})
    if not rows: raise ValueError('CSV must include at least one data row')
    return rows


def validate_snapshot(payload):
    year,month=map(int,payload.period.split('-'))
    if payload.through_day>calendar.monthrange(year,month)[1]: raise ValueError('Through-day exceeds the calendar month')
    def check_date(value):
        observed=date.fromisoformat(value)
        if observed.isoformat()!=value or value[:7]!=payload.period or observed.day>payload.through_day:
            raise ValueError('Every row must be inside the declared period and through-day')
    costs=parse_csv(payload.cost_csv,['cost_id','date','provider','service','team','category','amount','currency'])
    seen=set()
    for row in costs:
        check_date(row['date'])
        if not row['cost_id'] or len(row['cost_id'])>80 or not all(c.isascii() and (c.isalnum() or c in '-_') for c in row['cost_id']): raise ValueError('Invalid cost ID')
        if row['cost_id'] in seen: raise ValueError('Duplicate cost ID')
        seen.add(row['cost_id'])
        if row['provider'] not in ('aws','azure','gcp','onprem'): raise ValueError('Unsupported provider label')
        if row['service'] not in (*SERVICES,'shared-platform','unattributed'): raise ValueError('Unknown service')
        if row['team'] not in (*TEAMS,'shared','unallocated'): raise ValueError('Unknown allocation team')
        if row['team'] in TEAMS and (row['service'] not in SERVICES or SERVICES[row['service']][0]!=row['team']): raise ValueError('Direct service and team must match the service catalog')
        if row['team']=='shared' and row['service']!='shared-platform': raise ValueError('Shared costs must use shared-platform')
        if row['currency']!=payload.currency: raise ValueError('Mixed currencies are not accepted in a snapshot')
        if row['category'] not in ('compute','storage','network','credit'): raise ValueError('Unknown charge category')
        try:
            raw=row.pop('amount')
            if not re.fullmatch(r'-?[0-9]{1,7}(\.[0-9]{1,6})?',raw): raise ValueError('Use plain decimal amounts with at most six fractional digits')
            value=Decimal(raw)
            if not value.is_finite() or abs(value)>1000000 or value.as_tuple().exponent < -6: raise ValueError('Amount must be finite with at most 6 decimal places, magnitude <= 1000000')
            amount=int(value*1000000)
        except InvalidOperation as error: raise ValueError('Invalid decimal amount') from error
        if (row['category']=='credit' and amount>0) or (row['category']!='credit' and amount<0): raise ValueError('Credits must be nonpositive; other charges nonnegative')
        row['amount_micro']=amount
    if sum(abs(r['amount_micro']) for r in costs)>10000000000000: raise ValueError('Snapshot exceeds the 10-million currency-unit lab limit')
    usage=parse_csv(payload.usage_csv,['date','service','successful_units','unit'])
    seen=set()
    for row in usage:
        check_date(row['date'])
        if row['service'] not in SERVICES or row['unit']!=SERVICES[row['service']][1]: raise ValueError('Usage unit must match the service catalog')
        key=(row['date'],row['service'])
        if key in seen: raise ValueError('Duplicate daily service usage would double-count the denominator')
        seen.add(key)
        if not row['successful_units'].isascii() or not row['successful_units'].isdigit(): raise ValueError('Usage must be a nonnegative integer')
        row['successful_units']=int(row['successful_units'])
        if row['successful_units']>1000000000: raise ValueError('Usage exceeds lab limit')
    # An explicit row, even zero, is required for every day/service. No missing-data-as-zero assumption.
    expected={(f'{payload.period}-{day:02d}',service) for day in range(1,payload.through_day+1) for service in SERVICES}
    if seen!=expected: raise ValueError('Usage requires one row per service per covered day, including explicit zeros')
    return {'period':payload.period,'currency':payload.currency,'through_day':payload.through_day,
            'costs':sorted(costs,key=lambda r:r['cost_id']),'usage':sorted(usage,key=lambda r:(r['date'],r['service']))}


def samples():
    costs=io.StringIO(); usage=io.StringIO()
    cw=csv.writer(costs,lineterminator='\n'); uw=csv.writer(usage,lineterminator='\n')
    cw.writerow(['cost_id','date','provider','service','team','category','amount','currency'])
    uw.writerow(['date','service','successful_units','unit'])
    for day in range(1,15):
        for index,(service,(team,unit)) in enumerate(SERVICES.items()):
            cw.writerow([f'cost-{day}-{index}',f'2026-08-{day:02d}',('aws','azure','gcp','onprem')[index],service,team,'compute',str(Decimal(3+index)+Decimal(day)/10),'USD'])
            uw.writerow([f'2026-08-{day:02d}',service,(index+1)*1000+day*10 if index<3 else day*2,unit])
        cw.writerow([f'shared-{day}',f'2026-08-{day:02d}','onprem','shared-platform','shared','storage','2.000003','USD'])
        cw.writerow([f'untagged-{day}',f'2026-08-{day:02d}','aws','unattributed','unallocated','network','0.50','USD'])
    cw.writerow(['credit-1','2026-08-14','aws','demand-forecasting','retail','credit','-3.25','USD'])
    return {'request_id':'bundled-demo-202608-v1','period':'2026-08','currency':'USD','through_day':14,'cost_csv':costs.getvalue(),'usage_csv':usage.getvalue()}


class Project:
    def __init__(self,root=None):
        self.state=Path(root or os.getenv('STATE_DIR',str(ROOT/'state')))
        self.state.mkdir(parents=True,exist_ok=True); self.path=self.state/'costs.db'
        with self.db() as db:
            db.executescript('''
                CREATE TABLE IF NOT EXISTS batches(id TEXT PRIMARY KEY,snapshot TEXT,created REAL);
                CREATE TABLE IF NOT EXISTS current_batch(slot INTEGER PRIMARY KEY,id TEXT);
                CREATE TABLE IF NOT EXISTS imports(id TEXT PRIMARY KEY,payload_hash TEXT,response TEXT);
                CREATE TABLE IF NOT EXISTS policies(revision INTEGER PRIMARY KEY,weights TEXT,created REAL);
                CREATE TABLE IF NOT EXISTS budgets(period TEXT,currency TEXT,team TEXT,amount INTEGER,revision INTEGER,PRIMARY KEY(period,currency,team));
                CREATE TABLE IF NOT EXISTS reviews(id TEXT PRIMARY KEY,payload_hash TEXT,snapshot TEXT,created REAL);
            ''')
            db.execute('INSERT OR IGNORE INTO policies VALUES(1,?,?)',(encode(dict(zip(TEAMS,[4000,3000,2000,1000]))),time.time()))

    @contextmanager
    def db(self):
        connection=sqlite3.connect(self.path,timeout=15); connection.row_factory=sqlite3.Row
        connection.execute('PRAGMA journal_mode=WAL')
        try:
            with connection: yield connection
        finally: connection.close()

    def ingest(self,payload):
        snapshot=validate_snapshot(payload); fingerprint=digest(snapshot); now=time.time()
        with self.db() as db:
            db.execute('BEGIN IMMEDIATE')
            existing=db.execute('SELECT * FROM imports WHERE id=?',(payload.request_id,)).fetchone()
            if existing:
                if existing['payload_hash']!=fingerprint: raise HTTPException(409,'Import request ID conflicts with another snapshot')
                return json.loads(existing['response'])
            result={'batch_id':fingerprint,'cost_rows':len(snapshot['costs']),'usage_rows':len(snapshot['usage']),'currency':snapshot['currency'],'synthetic':True}
            db.execute('INSERT OR IGNORE INTO batches VALUES(?,?,?)',(fingerprint,encode(snapshot),now))
            db.execute('INSERT OR REPLACE INTO current_batch VALUES(1,?)',(fingerprint,))
            db.execute('INSERT INTO imports VALUES(?,?,?)',(payload.request_id,fingerprint,encode(result)))
        return result

    def calculate(self,db):
        batch=db.execute('SELECT b.* FROM batches b JOIN current_batch c ON c.id=b.id').fetchone()
        policy=db.execute('SELECT * FROM policies ORDER BY revision DESC LIMIT 1').fetchone()
        weights=json.loads(policy['weights'])
        result={'batch':None,'policy':{'revision':policy['revision'],'weights':weights},'teams':[],
                'reviews':[json.loads(r[0]) for r in db.execute('SELECT snapshot FROM reviews ORDER BY created DESC LIMIT 30')]}
        if not batch: return result
        source=json.loads(batch['snapshot']); year,month=map(int,source['period'].split('-')); days=calendar.monthrange(year,month)[1]
        totals={t:0 for t in (*TEAMS,'unallocated')}; compute={t:0 for t in TEAMS}; provider={}; daily={}; gross=0; uncovered=0
        for row in source['costs']:
            amount=row['amount_micro']; gross+=max(0,amount)
            if row['team']=='unallocated': uncovered+=max(0,amount)
            allocated=split_money(amount,weights) if row['team']=='shared' else {row['team']:amount}
            for team,value in allocated.items():
                totals[team]+=value
                if team in compute and row['category']=='compute': compute[team]+=value
            provider[row['provider']]=provider.get(row['provider'],0)+amount
            daily[row['date']]=daily.get(row['date'],0)+amount
        for service,(team,unit) in SERVICES.items():
            quantity=sum(r['successful_units'] for r in source['usage'] if r['service']==service)
            budget=db.execute('SELECT * FROM budgets WHERE period=? AND currency=? AND team=?',(source['period'],source['currency'],team)).fetchone()
            forecast=round_int(Decimal(totals[team])*days/source['through_day'])
            result['teams'].append({'team':team,'service':service,'unit':unit,'successful_units':quantity,'spend_micro':totals[team],
                'compute_micro':compute[team],'projected_micro':forecast,'cost_per_unit':format(Decimal(totals[team])/1000000/quantity,'.8f') if quantity else None,
                'budget_micro':budget['amount'] if budget else None,'budget_revision':budget['revision'] if budget else 0,
                'variance_micro':forecast-budget['amount'] if budget else None})
        total=sum(totals.values())
        result.update(batch={'id':batch['id'],'created':batch['created'],'period':source['period'],'currency':source['currency'],'through_day':source['through_day'],'month_days':days,'cost_rows':len(source['costs']),'usage_rows':len(source['usage'])},
            total_micro=total,unallocated_micro=totals['unallocated'],coverage_percent=float(Decimal(gross-uncovered)*100/gross) if gross else None,
            projected_micro=round_int(Decimal(total)*days/source['through_day']),providers=provider,daily=daily,
            synthetic=True,forecast_assumption='Linear calendar-day run rate; covered billing days declared by importer, not independently verified')
        return result

    def desk(self):
        with self.db() as db:
            db.execute('BEGIN'); return self.calculate(db)

    def policy(self,payload):
        weights={t:getattr(payload,t) for t in TEAMS}
        if sum(weights.values())!=10000: raise HTTPException(422,'Shared weights must sum to 10000 basis points (100%)')
        with self.db() as db:
            db.execute('BEGIN IMMEDIATE')
            current=db.execute('SELECT MAX(revision) FROM policies').fetchone()[0]
            if current!=payload.revision: raise HTTPException(409,'Allocation policy changed. Refresh before saving.')
            db.execute('INSERT INTO policies VALUES(?,?,?)',(current+1,encode(weights),time.time()))
        return {'revision':current+1,'weights':weights}

    def budget(self,payload):
        with self.db() as db:
            db.execute('BEGIN IMMEDIATE'); data=self.calculate(db)
            if not data['batch'] or data['batch']['id']!=payload.batch_id: raise HTTPException(409,'Billing snapshot changed. Refresh before saving.')
            row=next(t for t in data['teams'] if t['team']==payload.team)
            if row['budget_revision']!=payload.revision: raise HTTPException(409,'Budget changed. Refresh before saving.')
            db.execute('INSERT OR REPLACE INTO budgets VALUES(?,?,?,?,?)',(data['batch']['period'],data['batch']['currency'],payload.team,payload.amount_micro,payload.revision+1))
        return {'revision':payload.revision+1}

    def scenario(self,data,team,percent):
        if not data['batch']: raise HTTPException(409,'Import a billing snapshot first')
        row=next(t for t in data['teams'] if t['team']==team)
        saving=round_int(Decimal(row['compute_micro'])*percent*data['batch']['month_days']/(100*data['batch']['through_day']))
        return {'batch_id':data['batch']['id'],'policy_revision':data['policy']['revision'],'currency':data['batch']['currency'],
            'team':team,'reduction_percent':percent,'observed_compute_micro':row['compute_micro'],'estimated_monthly_savings_micro':saving,
            'assumption':'Hypothetical proportional compute-usage reduction at unchanged rates and quality; excludes implementation cost, commitments, and workload change',
            'measured_savings':False,'executed':False}

    def review(self,payload):
        fingerprint=digest(payload.model_dump())
        with self.db() as db:
            db.execute('BEGIN IMMEDIATE')
            old=db.execute('SELECT * FROM reviews WHERE id=?',(payload.request_id,)).fetchone()
            if old:
                if old['payload_hash']!=fingerprint: raise HTTPException(409,'Review request ID conflicts with different data')
                return json.loads(old['snapshot'])
            data=self.calculate(db)
            if not data['batch'] or data['batch']['id']!=payload.batch_id or data['policy']['revision']!=payload.policy_revision:
                raise HTTPException(409,'Cost snapshot or allocation policy changed. Refresh and reassess.')
            result={**payload.model_dump(),'scenario':self.scenario(data,payload.team,payload.reduction_percent),'created_at':time.time()}
            db.execute('INSERT INTO reviews VALUES(?,?,?,?)',(payload.request_id,fingerprint,encode(result),result['created_at']))
        return result

    def api(self):
        api=FastAPI(title='Cost Desk',version='1.0.0')
        api.mount('/assets',StaticFiles(directory=ROOT/'frontend'),name='assets')
        @api.middleware('http')
        async def origin(request:Request,call_next):
            if request.method=='POST' and request.headers.get('origin') not in (None,str(request.base_url).rstrip('/')):
                return JSONResponse({'detail':'Writes must originate from this application'},status_code=403)
            return await call_next(request)
        @api.get('/')
        def home(): return FileResponse(ROOT/'frontend/index.html')
        @api.get('/healthz')
        def health(): return {'status':'ok'}
        @api.get('/readyz')
        def ready():
            with self.db() as db: db.execute('SELECT COUNT(*) FROM policies').fetchone()
            return {'status':'ready'}
        @api.get('/v1/desk')
        def desk(): return self.desk()
        @api.get('/v1/sample')
        def sample(): return samples()
        @api.post('/v1/imports')
        def ingest(payload:Import):
            try: return self.ingest(payload)
            except (ValueError,csv.Error) as error: raise HTTPException(422,str(error)) from error
        @api.post('/v1/policy')
        def policy(payload:Policy): return self.policy(payload)
        @api.post('/v1/budgets')
        def budget(payload:Budget): return self.budget(payload)
        @api.get('/v1/scenario')
        def scenario(team:Team,reduction_percent:int=Query(ge=0,le=50)):
            return self.scenario(self.desk(),team,reduction_percent)
        @api.post('/v1/reviews')
        def review(payload:Review): return self.review(payload)
        return api

    def demo(self):
        return self.ingest(Import(**samples()))


if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('command',choices=['demo','serve'])
    parser.add_argument('--host',default='127.0.0.1'); parser.add_argument('--port',type=int,default=8215)
    args=parser.parse_args(); project=Project()
    if args.command=='demo': print(json.dumps(project.demo(),indent=2))
    else:
        import uvicorn
        uvicorn.run(project.api(),host=args.host,port=args.port)

from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import sys

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from app import Budget,Import,Policy,Project,Review,TEAMS,money,samples,split_money


@pytest.fixture
def project(tmp_path):
    p=Project(tmp_path/'state'); p.demo(); return p


def review(p,**changes):
    d=p.desk()
    return Review(request_id='review-request-001',batch_id=d['batch']['id'],policy_revision=d['policy']['revision'],
                  team='retail',reduction_percent=20,decision='approved',reviewer='FinOps learner',reason='Benchmark quality and usage before action.',**changes)


def test_static_empty_and_readiness(tmp_path):
    client=TestClient(Project(tmp_path/'empty').api())
    assert 'Cost Desk' in client.get('/').text
    assert client.get('/assets/app.js').status_code==200
    assert client.get('/readyz').status_code==200
    assert client.get('/v1/desk').json()['batch'] is None
    assert client.get('/v1/scenario?team=retail&reduction_percent=20').status_code==409


@pytest.mark.parametrize('amount',[0,1,3,1000003,-1,-3,-1000003,99999999999])
def test_shared_allocation_conserves_micro_units(amount):
    weights=dict(zip(TEAMS,[4000,3000,2000,1000]))
    allocated=split_money(amount,weights)
    assert sum(allocated.values())==amount
    assert allocated==split_money(amount,dict(reversed(list(weights.items()))))
    assert all(abs(abs(allocated[t])-abs(amount)*weights[t]/10000)<1 for t in TEAMS)


def test_exact_total_unallocated_and_unit_denominator(project):
    d=project.desk()
    assert d['total_micro']==325750042
    assert d['unallocated_micro']==7000000
    assert sum(t['spend_micro'] for t in d['teams'])+d['unallocated_micro']==d['total_micro']
    assert sum(d['providers'].values())==d['total_micro']
    assert sum(d['daily'].values())==d['total_micro']
    retail=next(t for t in d['teams'] if t['team']=='retail')
    assert retail['successful_units']==15050
    assert retail['compute_micro']==52500000
    assert retail['cost_per_unit']=='0.00401661'


def test_import_retry_concurrent_and_old_retry_does_not_rollback(project):
    first=samples(); first['request_id']='concurrent-import'
    def submit(_): return project.ingest(Import(**first))
    with ThreadPoolExecutor(max_workers=3) as pool: replies=list(pool.map(submit,range(3)))
    assert replies[0]==replies[1]==replies[2]
    next_data={**samples(),'request_id':'next-import-001','currency':'EUR','cost_csv':samples()['cost_csv'].replace('USD','EUR')}
    second=project.ingest(Import(**next_data))
    assert project.ingest(Import(**first))==replies[0]
    assert project.desk()['batch']['id']==second['batch_id']
    client=TestClient(project.api())
    assert client.post('/v1/imports',json={**next_data,'request_id':first['request_id']}).status_code==409


@pytest.mark.parametrize('mutation',[
    lambda d:{**d,'cost_csv':d['cost_csv'].replace('cost_id,','id,',1)},
    lambda d:{**d,'cost_csv':d['cost_csv'].replace('3.1,USD','NaN,USD')},
    lambda d:{**d,'cost_csv':d['cost_csv'].replace('3.1,USD','-3.1,USD')},
    lambda d:{**d,'cost_csv':d['cost_csv'].replace('3.1,USD','3.1234567,USD')},
    lambda d:{**d,'cost_csv':d['cost_csv'].replace('3.1,USD','3.1,EUR')},
    lambda d:{**d,'cost_csv':d['cost_csv']+d['cost_csv'].splitlines()[1]+'\n'},
    lambda d:{**d,'usage_csv':'\n'.join(d['usage_csv'].splitlines()[:-1])},
    lambda d:{**d,'usage_csv':d['usage_csv']+d['usage_csv'].splitlines()[1]+'\n'},
    lambda d:{**d,'through_day':13},
    lambda d:{**d,'cost_csv':d['cost_csv'].replace('demand-forecasting,retail','demand-forecasting,risk')},
])
def test_failed_import_keeps_previous_snapshot(project,mutation):
    before=project.desk()['batch']['id']
    response=TestClient(project.api()).post('/v1/imports',json=mutation({**samples(),'request_id':'invalid-import-001'}))
    assert response.status_code==422,response.text
    assert project.desk()['batch']['id']==before


def test_policy_revision_and_totals(project):
    client=TestClient(project.api())
    payload={'revision':1,**dict.fromkeys(TEAMS,2500)}
    assert client.post('/v1/policy',json={**payload,'retail':1}).status_code==422
    def save(_): return client.post('/v1/policy',json=payload).status_code
    with ThreadPoolExecutor(max_workers=2) as pool: assert sorted(pool.map(save,range(2)))==[200,409]
    d=project.desk()
    assert d['policy']['revision']==2
    assert d['total_micro']==325750042
    assert sum(t['spend_micro'] for t in d['teams'])+d['unallocated_micro']==d['total_micro']


def test_budget_scope_and_stale_revision(project):
    d=project.desk(); client=TestClient(project.api())
    body={'batch_id':d['batch']['id'],'team':'retail','amount_micro':100000000,'revision':0}
    assert client.post('/v1/budgets',json=body).status_code==200
    assert client.post('/v1/budgets',json=body).status_code==409
    assert project.desk()['teams'][0]['variance_micro']>0
    eur={**samples(),'request_id':'currency-import','currency':'EUR','cost_csv':samples()['cost_csv'].replace('USD','EUR')}
    project.ingest(Import(**eur))
    assert project.desk()['teams'][0]['budget_micro'] is None
    assert client.post('/v1/budgets',json={**body,'revision':1}).status_code==409
    september={**samples(),'request_id':'period-import','period':'2026-09','cost_csv':samples()['cost_csv'].replace('2026-08','2026-09'),'usage_csv':samples()['usage_csv'].replace('2026-08','2026-09')}
    project.ingest(Import(**september))
    assert project.desk()['teams'][0]['budget_micro'] is None


def test_zero_usage_is_undefined(project):
    data=samples(); lines=data['usage_csv'].splitlines()
    modified=[lines[0]]
    for line in lines[1:]:
        values=line.split(',')
        if values[1]=='demand-forecasting': values[2]='0'
        modified.append(','.join(values))
    project.ingest(Import(**{**data,'request_id':'zero-usage-import','usage_csv':'\n'.join(modified)}))
    retail=project.desk()['teams'][0]
    assert retail['successful_units']==0 and retail['cost_per_unit'] is None


def test_scenario_review_retry_snapshot_and_restart(project):
    payload=review(project)
    def submit(_): return project.review(payload)
    with ThreadPoolExecutor(max_workers=2) as pool: results=list(pool.map(submit,range(2)))
    assert results[0]==results[1]
    assert results[0]['scenario']['estimated_monthly_savings_micro']==23250000
    assert results[0]['scenario']['executed'] is False and results[0]['scenario']['measured_savings'] is False
    project.policy(Policy(revision=1,**dict.fromkeys(TEAMS,2500)))
    assert project.review(payload)==results[0]
    response=TestClient(project.api()).post('/v1/reviews',json={**payload.model_dump(),'request_id':'stale-review-001'})
    assert response.status_code==409
    restarted=Project(project.state)
    assert restarted.desk()['reviews']==[results[0]]


def test_api_boundaries(project):
    client=TestClient(project.api())
    assert client.post('/v1/imports',json=samples(),headers={'Origin':'https://unrelated.example'}).status_code==403
    payload=review(project).model_dump()
    for changes in [{'decision':'resize'},{'reason':'   '},{'reviewer':' '},{'reduction_percent':51},{'estimated_savings':100}]:
        assert client.post('/v1/reviews',json={**payload,**changes}).status_code==422
    assert client.get('/v1/scenario?team=retail&reduction_percent=-1').status_code==422

from concurrent.futures import ThreadPoolExecutor
from datetime import date, timedelta
import importlib.util
import json
from pathlib import Path
import time

from fastapi.testclient import TestClient
import pytest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('retail', ROOT / 'app.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


@pytest.fixture
def project(tmp_path):
    return m.Project(tmp_path)


def payload(request_id='import-test-0001', change=False):
    fixture = m.sample()
    return m.Import(request_id=request_id, sales_csv=fixture['sales_csv'],
                    inventory_csv=fixture['inventory_csv'].replace('COFFEE,35,10', 'COFFEE,45,10') if change else fixture['inventory_csv'])


def completed(project):
    batch = project.ingest(payload())
    job = project.enqueue(m.Queue(request_id='queue-test-0001', batch_id=batch['batch_id']))
    assert project.work_once()
    return batch, job


def review(job, request_id='review-test-0001', **changes):
    return m.Review(**dict({'request_id': request_id, 'job_id': job['job_id'], 'sku': 'COFFEE',
                    'decision': 'approved', 'reviewer': 'Planner', 'notes': 'Checked stock and upcoming deliveries'}, **changes))


def test_complete_workflow_and_persisted_evidence(project):
    batch, job = completed(project)
    result = project.desk()['jobs'][0]['result']
    coffee = result['items'][0]
    assert coffee['forecast_units'] == 140
    assert coffee['suggested_units'] == 115
    assert coffee['backtest_mae'] == 1
    assert coffee['daily'][0]['date'] == '2026-09-05'
    saved = project.review(review(job))
    assert saved['executed'] is False
    project.ingest(payload('import-test-0002', change=True))
    assert project.review(review(job)) == saved  # Response-loss retry remains safe after a new import.
    assert m.Project(project.state).desk()['reviews'][0] == saved
    with pytest.raises(m.HTTPException) as err:
        project.review(review(job, request_id='review-test-0002', sku='OATS'))
    assert err.value.status_code == 409


def test_duplicate_import_and_queue_are_concurrent_safe(project):
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(lambda _: project.ingest(payload()), range(8)))
    assert all(r == results[0] for r in results)
    batch = results[0]
    with ThreadPoolExecutor(max_workers=4) as pool:
        jobs = list(pool.map(lambda i: project.enqueue(m.Queue(request_id=f'queue-test-{i:04}', batch_id=batch['batch_id'])), range(8)))
    assert len({j['job_id'] for j in jobs}) == 1
    with ThreadPoolExecutor(max_workers=4) as pool:
        claims = list(pool.map(lambda _: project.claim(), range(4)))
    assert sum(j is not None for j in claims) == 1


def test_old_import_retry_does_not_republish(project):
    first = project.ingest(payload())
    second = project.ingest(payload('import-test-0002', True))
    assert project.ingest(payload()) == first
    assert project.desk()['batch']['id'] == second['batch_id']
    with pytest.raises(m.HTTPException) as err:
        project.ingest(payload(change=True))
    assert err.value.status_code == 409


@pytest.mark.parametrize('case', ['headers', 'duplicate', 'missing_day', 'negative', 'fraction', 'mismatch', 'future', 'short', 'extra_field', 'inventory_duplicate'])
def test_invalid_import_is_atomic(project, case):
    original = project.ingest(payload())
    data = payload('invalid-test-0001').model_dump()
    lines = data['sales_csv'].splitlines()
    if case == 'headers': data['sales_csv'] = 'wrong,headers\n1,2'
    if case == 'duplicate': data['sales_csv'] += '\n' + lines[1]
    if case == 'missing_day': data['sales_csv'] = '\n'.join(lines[:10] + lines[13:])
    if case == 'negative': data['sales_csv'] = data['sales_csv'].replace('COFFEE,10', 'COFFEE,-1', 1)
    if case == 'fraction': data['sales_csv'] = data['sales_csv'].replace('COFFEE,10', 'COFFEE,1.5', 1)
    if case == 'mismatch': data['inventory_csv'] = data['inventory_csv'].replace('COFFEE', 'TEA')
    if case == 'future': data['sales_csv'] = data['sales_csv'].replace('2026-08-01', (date.today()+timedelta(days=1)).isoformat())
    if case == 'short': data['sales_csv'] = '\n'.join(lines[:70])
    if case == 'extra_field': data['sales_csv'] += '\n2026-09-10,COFFEE,1,extra'
    if case == 'inventory_duplicate': data['inventory_csv'] += '\nCOFFEE,1,2'
    with pytest.raises(m.HTTPException) as err:
        project.ingest(m.Import(**data))
    assert err.value.status_code == 422
    assert project.desk()['batch']['id'] == original['batch_id']
    with project.db() as db:
        assert db.execute('SELECT count(*) FROM batches').fetchone()[0] == 1


def test_worker_crash_recovery_fences_previous_owner(project):
    batch = project.ingest(payload())
    project.enqueue(m.Queue(request_id='queue-test-0001', batch_id=batch['batch_id']))
    crashed = project.claim(now=time.time()-60)
    replacement = m.Project(project.state).claim()
    assert replacement['attempts'] == 2
    assert not project.finish(crashed, result={'invalid': True})
    assert project.finish(replacement, result=m.forecast(replacement['snapshot']))
    assert project.desk()['jobs'][0]['state'] == 'succeeded'


def test_expired_unclaimed_worker_cannot_publish(project):
    batch = project.ingest(payload())
    project.enqueue(m.Queue(request_id='queue-test-0001', batch_id=batch['batch_id']))
    job = project.claim(now=time.time()-60)
    assert not project.finish(job, result=m.forecast(job['snapshot']))


def test_worker_stops_after_three_failures(project, monkeypatch):
    batch = project.ingest(payload())
    project.enqueue(m.Queue(request_id='queue-test-0001', batch_id=batch['batch_id']))
    def broken(_): raise RuntimeError('Injected failure')
    monkeypatch.setattr(m, 'forecast', broken)
    assert all(project.work_once() for _ in range(3))
    assert not project.work_once()
    assert project.desk()['jobs'][0]['state'] == 'failed'
    assert project.desk()['jobs'][0]['attempts'] == 3


def test_three_crashed_workers_end_in_failure(project):
    batch = project.ingest(payload())
    project.enqueue(m.Queue(request_id='queue-test-0001', batch_id=batch['batch_id']))
    for offset in [120, 80, 40]: assert project.claim(now=time.time()-offset)
    assert project.claim() is None
    assert project.desk()['jobs'][0]['state'] == 'failed'


def test_review_conflicts_and_concurrent_retry(project):
    _, job = completed(project)
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(lambda _: project.review(review(job)), range(4)))
    assert all(r == results[0] for r in results)
    for request in [review(job, notes='A changed rationale'), review(job, request_id='review-test-0002')]:
        with pytest.raises(m.HTTPException) as err: project.review(request)
        assert err.value.status_code == 409
    assert len(project.desk()['reviews']) == 1


def test_expired_forecast_cannot_be_approved_but_can_be_deferred(project):
    _, job = completed(project)
    with project.db() as db: db.execute('UPDATE jobs SET completed=?', (time.time()-86401,))
    with pytest.raises(m.HTTPException) as err: project.review(review(job))
    assert err.value.status_code == 409
    assert project.review(review(job, decision='deferred'))['decision'] == 'deferred'


def test_api_contract_and_origin_guard(project):
    client = TestClient(m.create_app(project))
    assert client.get('/').status_code == 200
    assert client.get('/assets/app.js').status_code == 200
    assert client.get('/readyz').status_code == 200
    assert client.get('/v1/desk').json()['batch'] is None
    data = payload().model_dump()
    assert client.post('/v1/imports', json=data, headers={'Origin':'https://foreign.example'}).status_code == 403
    assert client.post('/v1/imports', json={**data, 'extra':1}).status_code == 422
    batch = client.post('/v1/imports', json=data).json()
    response = client.post('/v1/jobs', json={'request_id':'queue-test-0001', 'batch_id':batch['batch_id']})
    assert response.status_code == 200
    assert client.post('/v1/reviews', json=review(response.json()).model_dump()).status_code == 409
    assert project.work_once()
    assert client.post('/v1/reviews', json=review(response.json(), sku='UNKNOWN').model_dump()).status_code == 404
    assert client.post('/v1/reviews', json=review(response.json()).model_dump()).json()['executed'] is False


def test_backtest_does_not_use_future_targets():
    p = payload()
    data = m.snapshot(p.sales_csv, p.inventory_csv)
    first = m.forecast(data)
    # A single final-day change affects only the matching forecast weekday and the backtest error.
    data['sales']['COFFEE'][data['days'][-1]] += 70
    second = m.forecast(data)
    assert first['items'][0]['daily'][:-1] == second['items'][0]['daily'][:-1]
    assert second['items'][0]['backtest_mae'] == 11


def test_current_job_survives_recent_history_limit(project):
    _, original = completed(project)
    for index in range(32):
        data = payload(f'history-import-{index:04}').model_dump()
        data['inventory_csv'] = data['inventory_csv'].replace('COFFEE,35,10', f'COFFEE,{100+index},10')
        batch = project.ingest(m.Import(**data))
        project.enqueue(m.Queue(request_id=f'history-queue-{index:04}', batch_id=batch['batch_id']))
    project.ingest(payload('republish-original'))
    desk = project.desk()
    assert len(desk['jobs']) == 30
    assert original['job_id'] not in {j['id'] for j in desk['jobs']}
    assert desk['current_job']['id'] == original['job_id']
    assert desk['current_job']['result']['items'][0]['forecast_units'] == 140

from concurrent.futures import ThreadPoolExecutor
import json
import time

from fastapi.testclient import TestClient
import pytest

from conftest import MODULES
from mlops_common.runtime import database


def payment(event_id='desk-event'):
    return {'event_id':event_id,'entity_id':'lab-entity','amount_minor':8000,'currency':'USD','event_time':time.time()-10}


def reading(sequence, site='lab', equipment='desk-machine'):
    return {'site':site,'equipment':equipment,'sequence':sequence,'temperature':75,'vibration':12}


def analyst(event_id='desk-event', **changes):
    return {'request_id':'analyst-review-001','event_id':event_id,'reviewer':'Analyst','notes':'Checked simulated purchase pattern','decision':'escalate',**changes}


def inspection(sequence=5, **changes):
    return {'request_id':'inspection-review-001','site':'lab','equipment':'desk-machine','sequence':sequence,
            'reviewer':'Operator','notes':'Inspect simulated wear trend','decision':'inspect',**changes}


@pytest.mark.parametrize('key,route,title',[('02','/v1/desk','Risk Desk'),('03','/v1/fleet','Fleet Desk')])
def test_operator_static_and_empty_state(tmp_path,key,route,title):
    client = TestClient(MODULES[key].Project(tmp_path/key).api())
    assert title in client.get('/').text
    assert client.get('/assets/app.js').status_code == 200
    assert client.get('/shared/ui.js').status_code == 200
    assert client.get('/shared/styles.css').status_code == 200
    response = client.get(route)
    assert response.status_code == 200
    assert response.json()['active_model']['available'] is False
    assert response.json()['reviews'] == []


def test_risk_ledger_and_delayed_feedback(projects):
    project = projects['02']; client = TestClient(project.api())
    event = payment()
    result = client.post('/v1/risk-decisions',json=event).json()
    detail = client.get('/v1/risk-decisions/desk-event').json()
    assert detail['decision'] == result
    assert detail['label'] == {'state':'unknown','available_at':None,'fraud':None}
    future = time.time()+60
    assert client.post('/v1/labels',json={'event_id':event['event_id'],'fraud':True,'available_at':future}).status_code == 200
    detail = client.get('/v1/risk-decisions/desk-event').json()
    assert detail['label']['state'] == 'pending' and detail['label']['fraud'] is None
    assert project.outcomes(future+1)['matured_labels'] > project.outcomes(time.time())['matured_labels']
    assert client.get('/v1/risk-decisions/missing').status_code == 404
    with database(project.runtime.db) as db:
        db.execute('UPDATE labels SET available=? WHERE event_id=?',(time.time()-1,event['event_id']))
    assert client.get('/v1/risk-decisions/desk-event').json()['label']['fraud'] is True


def test_risk_review_concurrent_retry_finalization_and_restart(projects):
    project = projects['02']; project.score(payment())
    client = TestClient(project.api()); payload = analyst()
    def submit(_):
        response = client.post('/v1/risk-reviews',json=payload)
        assert response.status_code == 200
        return response.json()
    with ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(submit,range(3)))
    assert results[0] == results[1] == results[2]
    assert results[0]['executed'] is False
    assert results[0]['snapshot']['event']['amount_minor'] == 8000
    assert client.post('/v1/risk-reviews',json=analyst(notes='Changed')).status_code == 409
    assert client.post('/v1/risk-reviews',json=analyst(request_id='another-request')).status_code == 409
    restarted = TestClient(MODULES['02'].Project(project.runtime.root).api())
    assert restarted.get('/v1/risk-decisions/desk-event').json()['review'] == results[0]
    assert restarted.get('/v1/desk').json()['summary']['reviewed'] == 1
    assert restarted.get('/v1/desk').json()['summary']['matured_labels'] == 0


def test_risk_label_concurrency_and_validation(projects):
    project = projects['02']; project.score(payment())
    client = TestClient(project.api()); available = time.time()
    def label(fraud):
        return client.post('/v1/labels',json={'event_id':'desk-event','fraud':fraud,'available_at':available}).status_code
    with ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(label,[True,False])) == [200,409]
    assert client.post('/v1/labels',json={'event_id':'desk-event','fraud':'false','available_at':available}).status_code == 422
    assert client.post('/v1/risk-decisions',json={**payment('future'),'event_time':time.time()+1000}).status_code == 422
    assert client.post('/v1/risk-reviews',json=analyst('missing')).status_code == 404


def test_risk_old_decision_retains_original_release(projects):
    project = projects['02']; original = project.score(payment())
    release = project.train(); project.runtime.activate(release['release_id'])
    client = TestClient(project.api()); detail = client.get('/v1/risk-decisions/desk-event').json()
    assert detail['decision'] == original
    assert detail['model']['release']['release_id'] == original['release_id']
    assert client.get('/v1/desk').json()['active_model']['release']['release_id'] == release['release_id']


def test_maintenance_site_isolation_and_history(projects):
    project = projects['03']; client = TestClient(project.api())
    for site in ['north','south']:
        for seq in range(1,6):
            project.ingest(reading(seq,site))
    data = client.get('/v1/fleet').json()
    assert sum(u['event']['equipment']=='desk-machine' for u in data['equipment']) == 2
    history = client.get('/v1/equipment-history',params={'site':'north','equipment':'desk-machine'}).json()
    assert len(history['samples']) == 5
    assert all(s['event']['site']=='north' for s in history['samples'])
    assert history['samples'][3]['prediction']['remaining_cycles'] is None
    assert history['samples'][4]['prediction']['state'] == 'predicted'
    assert client.get('/v1/equipment/desk-machine/health-estimate',params={'site':'south'}).json()['site'] == 'south'
    assert client.get('/v1/equipment-history',params={'site':'missing','equipment':'desk-machine'}).status_code == 404


def test_inspection_warmup_stale_review_and_persistence(projects):
    project = projects['03']; client = TestClient(project.api())
    project.ingest(reading(1))
    assert client.post('/v1/inspection-reviews',json=inspection(1)).status_code == 409
    for seq in range(2,7): project.ingest(reading(seq))
    assert client.post('/v1/inspection-reviews',json=inspection(5)).status_code == 409
    payload = inspection(6)
    response = client.post('/v1/inspection-reviews',json=payload)
    assert response.status_code == 200
    saved = response.json()
    assert saved['snapshot']['prediction']['sequence'] == 6 and saved['executed'] is False
    project.ingest(reading(7))
    assert client.post('/v1/inspection-reviews',json=payload).json() == saved
    restarted = TestClient(MODULES['03'].Project(project.runtime.root).api())
    assert restarted.get('/v1/fleet').json()['reviews'][0] == saved
    assert restarted.get('/v1/equipment-history',params={'site':'lab','equipment':'desk-machine'}).json()['review'] is None


def test_inspection_concurrent_finalization(projects):
    project = projects['03']; client = TestClient(project.api())
    for seq in range(1,6): project.ingest(reading(seq))
    payload = inspection()
    def submit(_):
        response = client.post('/v1/inspection-reviews',json=payload)
        assert response.status_code == 200
        return response.json()
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(submit,range(2)))
    assert results[0] == results[1]
    assert client.post('/v1/inspection-reviews',json=inspection(request_id='different-request')).status_code == 409


def test_fleet_flush_reports_durable_counts(projects):
    client = TestClient(projects['03'].api())
    before = client.get('/v1/fleet').json()['summary']
    result = client.post('/v1/spool/flush').json()
    after = client.get('/v1/fleet').json()['summary']
    assert after['queued'] == before['queued']-result['acknowledged']
    assert after['central_rows'] == before['central_rows']+result['acknowledged']
    assert client.post('/v1/spool/flush').json()['acknowledged'] == 0


@pytest.mark.parametrize('key,route',[('02','/v1/desk'),('03','/v1/fleet')])
def test_ledger_survives_unavailable_model_and_schema_upgrade(projects,key,route):
    project = projects[key]
    before = TestClient(project.api()).get(route).json()['summary']
    with database(project.runtime.db) as db:
        db.execute('DROP TABLE operator_reviews')
    restarted = MODULES[key].Project(project.runtime.root)
    release = restarted.runtime.load()[0]
    (restarted.runtime.state/'releases'/release['release_id']/'metrics.json').write_text('{}')
    response = TestClient(restarted.api()).get(route)
    assert response.status_code == 200 and response.json()['active_model']['available'] is False
    assert response.json()['summary'] == before


@pytest.mark.parametrize('key,route,payload',[
    ('02','/v1/risk-reviews',analyst()),('03','/v1/inspection-reviews',inspection())])
def test_operator_review_boundaries(projects,key,route,payload):
    client = TestClient(projects[key].api())
    assert client.post(route,json=payload,headers={'Origin':'https://unrelated.example'}).status_code == 403
    for fields in ({'notes':' '},{'reviewer':' '},{'notes':'x'*1001},{'decision':'execute'},{'extra':1}):
        assert client.post(route,json={**payload,**fields}).status_code == 422

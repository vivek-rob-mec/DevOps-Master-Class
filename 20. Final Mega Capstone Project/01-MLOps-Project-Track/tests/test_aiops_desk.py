from concurrent.futures import ThreadPoolExecutor
import json
import time

from fastapi.testclient import TestClient

from conftest import MODULES
from mlops_common.runtime import database


def fixture(**changes):
    return {'request_id':'desk-fixture-001','service':'payment-risk','scenario':'latency_error',**changes}


def populate(project, **changes):
    project.fixture(MODULES['04'].Fixture(**fixture(**changes)))
    return project.analyze()['incident_ids'][0]


def test_desk_empty_state_is_not_healthy(tmp_path):
    client=TestClient(MODULES['04'].Project(tmp_path/'empty').api())
    assert 'Incident Desk' in client.get('/').text
    for path in ['/assets/app.js','/assets/styles.css','/shared/ui.js']:
        assert client.get(path).status_code==200
    data=client.get('/v1/desk').json()
    assert data['summary']['total']==0 and data['runs']==[]
    assert len(data['services'])==3
    assert all(s['status']=='no_recent_samples' and s['features'] is None for s in data['services'])
    assert not data['active_model']['available']
    assert client.post('/v1/analyze').status_code==503


def test_minimum_samples_and_unmeasured_queue(projects):
    project=projects['04']; runtime=projects['01'].runtime
    for _ in range(4): runtime.emit('http',latency=25,error=0,path='/test',status=200)
    s=next(s for s in project.desk()['services'] if s['service']=='demand-forecasting')
    assert s['status']=='insufficient_samples' and s['features'] is None
    runtime.emit('http',latency=25,error=0,path='/test',status=200)
    s=next(s for s in project.desk()['services'] if s['service']=='demand-forecasting')
    assert s['status']=='eligible' and s['sample_count']==5
    assert s['queue_signal']=='not_measured_by_http' and s['fixture_samples']==0


def test_fixture_concurrent_retry_and_conflict(projects):
    project=projects['04']; client=TestClient(project.api())
    def submit(_):
        response=client.post('/v1/fixtures',json=fixture())
        assert response.status_code==200
        return response.json()
    with ThreadPoolExecutor(max_workers=3) as pool:
        results=list(pool.map(submit,range(3)))
    assert results[0]==results[1]==results[2]
    assert results[0]['sample_count']==10
    with database(project.runtime.telemetry) as db:
        assert db.execute("SELECT COUNT(*) FROM events WHERE kind='fault_fixture'").fetchone()[0]==10
        assert db.execute("SELECT COUNT(*) FROM events WHERE kind='release_activated' AND service='payment-risk'").fetchone()[0]==1
    assert client.post('/v1/fixtures',json=fixture(scenario='backlog')).status_code==409


def test_snapshot_preserved_after_source_removal(projects):
    project=projects['04']; identifier=populate(project)
    before=project.incident(identifier)
    assert before['source_snapshots_available']
    assert len(before['evidence']['source_events'])==10
    assert len(before['evidence']['release_event_snapshots'])==1
    assert before['created_at'] is not None and before['reviewed_at'] is None
    assert before['proposal']['causality_proven'] is False
    with database(project.runtime.telemetry) as db:
        db.execute("DELETE FROM events WHERE service='payment-risk'")
    after=project.incident(identifier)
    assert after==before
    service=next(s for s in project.desk()['services'] if s['service']=='payment-risk')
    assert service['status']=='no_recent_samples'
    assert project.desk()['summary']['total']==1


def test_analysis_history_and_incident_deduplication(projects):
    project=projects['04']
    empty=project.analyze()
    assert empty['analyzed_windows']==0 and empty['incident_ids']==[]
    project.fixture(MODULES['04'].Fixture(**fixture(scenario='backlog')))
    first=project.analyze(); second=project.analyze()
    assert first['incident_ids']==second['incident_ids']
    assert first['run_id']!=second['run_id']
    data=project.desk()
    assert data['summary']['total']==1 and len(data['runs'])==3
    assert data['runs'][0]['window_count']==1
    incident=project.incident(first['incident_ids'][0])
    assert any('consumer slowdown' in h['hypothesis'] for h in incident['proposal']['hypotheses'])


def test_review_timestamp_retry_and_conflicting_review(projects):
    project=projects['04']; identifier=populate(project); client=TestClient(project.api())
    body={'decision':'approved','reviewer':'Local operator','reason':'Checked all fixture evidence.'}
    def review(_):
        response=client.post(f'/v1/incidents/{identifier}/review',json=body)
        assert response.status_code==200
        return response.json()
    with ThreadPoolExecutor(max_workers=2) as pool:
        results=list(pool.map(review,range(2)))
    assert results[0]==results[1] and results[0]['executed'] is False
    timestamp=project.incident(identifier)['reviewed_at']
    assert timestamp is not None
    client.post(f'/v1/incidents/{identifier}/review',json=body)
    assert project.incident(identifier)['reviewed_at']==timestamp
    assert client.post(f'/v1/incidents/{identifier}/review',json={**body,'decision':'rejected'}).status_code==409
    restarted=MODULES['04'].Project(project.runtime.root)
    assert restarted.incident(identifier)['review']==body
    assert restarted.incident(identifier)['reviewed_at']==timestamp


def test_real_http_evidence_visible_in_desk(projects):
    project=projects['04']; runtime=projects['01'].runtime
    (runtime.state/'active.json').unlink()
    source=TestClient(projects['01'].api())
    for _ in range(6): assert source.get('/report').status_code==503
    identifiers=project.analyze()['incident_ids']
    incident=next(project.incident(i) for i in identifiers if project.incident(i)['service']=='demand-forecasting')
    assert not incident['evidence']['contains_fixture']
    samples=incident['evidence']['source_events']
    assert len(samples)==6 and all(r['kind']=='http' and r['context']['status']==503 for r in samples)


def test_original_detector_evidence_after_promotion(projects):
    project=projects['04']; identifier=populate(project)
    before=project.incident(identifier)
    newer=project.train(); project.runtime.activate(newer['release_id'])
    after=project.incident(identifier)
    assert after==before
    assert project.desk()['active_model']['release']['release_id']==newer['release_id']


def test_legacy_schema_migrates_without_inventing_timestamps(tmp_path):
    root=tmp_path/'legacy'
    stored={'features':[200,.5,0],'detector_release':'a'*32,'sample_count':5,'first_event_id':1,'last_event_id':5,'release_events':[],
            'anomaly':True,'static_rule':True,'contains_fixture':False}
    with database(root/'state/application.db') as db:
        db.execute('CREATE TABLE incidents(id TEXT PRIMARY KEY,service TEXT,evidence TEXT,proposal TEXT,state TEXT,review TEXT)')
        db.execute('INSERT INTO incidents VALUES(?,?,?,?,?,?)',('legacy','payment-risk',json.dumps(stored),json.dumps({'hypotheses':[],'action':'Inspect','executes_commands':False,'causality_proven':False}),'pending',None))
    project=MODULES['04'].Project(root)
    incident=project.incident('legacy')
    assert incident['evidence']==stored
    assert not incident['source_snapshots_available']
    assert incident['created_at'] is None and incident['reviewed_at'] is None


def test_validation_origin_and_missing_incident(projects):
    client=TestClient(projects['04'].api())
    assert client.get('/v1/incidents/missing').status_code==404
    assert client.post('/v1/fixtures',json=fixture(),headers={'Origin':'https://unrelated.example'}).status_code==403
    assert client.post('/v1/analyze',headers={'Origin':'https://unrelated.example'}).status_code==403
    for change in [{'service':'unlisted'},{'scenario':'crash-real-service'},{'sample_count':100000},{'request_id':'bad'}]:
        assert client.post('/v1/fixtures',json={**fixture(),**change}).status_code==422
    for change in [{'reviewer':'   '},{'reason':'     '},{'reason':'x'*501},{'decision':'execute'},{'extra':True}]:
        body={'decision':'approved','reviewer':'Operator','reason':'Inspect sample errors.',**change}
        assert client.post('/v1/incidents/missing/review',json=body).status_code==422


def test_corrupt_detector_preserves_ledger(projects):
    project=projects['04']; identifier=populate(project)
    release=project.runtime.load()[0]['release_id']
    (project.runtime.state/'releases'/release/'metrics.json').write_text('{}')
    client=TestClient(project.api()); data=client.get('/v1/desk').json()
    assert not data['active_model']['available']
    assert data['summary']['total']==1 and data['incidents'][0]['id']==identifier
    assert client.post('/v1/analyze').status_code==503

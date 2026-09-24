from concurrent.futures import ThreadPoolExecutor
import json
import time

from fastapi.testclient import TestClient
import numpy as np
import pytest

from conftest import MODULES
from mlops_common.runtime import atomic_json,database


def test_no_model_means_not_ready(tmp_path):
    client=TestClient(MODULES["01"].Project(tmp_path/"empty").api())
    assert client.get("/healthz").status_code==200
    assert client.get("/readyz").status_code==503


@pytest.mark.parametrize("key",["01","02","03","04"])
def test_live_contract_and_release_evidence(projects,key):
    client=TestClient(projects[key].api())
    assert client.get("/").status_code==200
    assert client.get("/readyz").status_code==200
    response=client.get("/report")
    assert response.status_code==200
    assert response.json()["release"]["eligible"]
    assert response.json()["metrics"]["validation_pass"]
    assert "lab_requests_total" in client.get("/metrics").text


def test_corrupted_candidate_cannot_replace_active(projects):
    project=projects["01"]
    active=project.runtime.load()[0]["release_id"]
    candidate=project.train()["release_id"]
    model=project.runtime.state/"releases"/candidate/"model.joblib"
    model.write_bytes(b"corrupt")
    with pytest.raises(ValueError,match="checksum"):
        project.runtime.activate(candidate)
    assert project.runtime.load()[0]["release_id"]==active


def test_rejected_release_and_path_escape(projects):
    runtime=projects["04"].runtime
    release=runtime.release({"test":True},[],[],{"validation_pass":False},"test",{})
    with pytest.raises(ValueError,match="rejected"):
        runtime.activate(release["release_id"])
    with pytest.raises(ValueError,match="Invalid"):
        runtime.load("../../etc")


def test_evidence_tampering_detected(projects):
    runtime=projects["01"].runtime
    release=runtime.load()[0]["release_id"]
    atomic_json(runtime.state/"releases"/release/"metrics.json",{"validation_pass":True})
    with pytest.raises(ValueError,match="evidence checksum"):
        runtime.load()


def test_forecast_features_cannot_see_future():
    module=MODULES["01"]
    series=module.generate()["SKU-000"]
    before=module.features(series[:50],53,4,0)
    series[50:]=[999999]*len(series[50:])
    assert module.features(series[:50],53,4,0)==before


def test_forecast_atomic_failure_and_duplicate_batch(projects):
    project=projects["01"]
    assert project.exercise()["passed"]
    first=project.forecast()
    second=project.forecast()
    assert first==second
    with database(project.runtime.db) as db:
        count=db.execute("SELECT count(*) FROM forecasts WHERE batch=?",(first["batch_id"],)).fetchone()[0]
    assert count==56


def test_forecast_staleness_and_unknown_product(projects):
    project=projects["01"]
    with database(project.runtime.db) as db:
        db.execute("UPDATE batches SET created=?",(time.time()-90000,))
    assert project.get_forecast("SKU-000")["stale"]
    client=TestClient(project.api())
    assert client.get("/v1/forecasts/missing").status_code==404
    assert client.get("/v1/recommendations/SKU-000?inventory=-1").status_code==422


def transaction(identifier="concurrent"):
    return {"event_id":identifier,"entity_id":"entity","amount_minor":5000,"currency":"USD","event_time":1700000200.0}


def test_risk_concurrent_idempotency(projects):
    project=projects["02"]
    with ThreadPoolExecutor(max_workers=4) as executor:
        results=list(executor.map(lambda _:project.score(transaction()),range(4)))
    assert all(r==results[0] for r in results)
    with database(project.runtime.db) as db:
        assert db.execute("SELECT count(*) FROM decisions WHERE event_id='concurrent'").fetchone()[0]==1
    with pytest.raises(ValueError,match="duplicate"):
        project.score(dict(transaction(),amount_minor=1))


def test_risk_asof_feature_parity_and_late_arrival():
    module=MODULES["02"]
    event=transaction()
    history=[dict(event,event_id="prior",event_time=1700000100,received_at=1700000300)]
    assert module.features(event,history,1700000200)[2]==0
    assert module.features(event,history,1700000400)[2]==1
    future=[dict(event,event_time=1700000300,received_at=1700000100)]
    assert module.features(event,future,1700000400)[2]==0


def test_risk_offline_online_feature_equality(projects):
    module=MODULES["02"]
    events,X=module.generate(size=12)
    project=projects["02"]
    for index,event in enumerate(events):
        raw={k:event[k] for k in ("event_id","entity_id","amount_minor","currency","event_time")}
        response=project.score(raw,received_at=event["received_at"])
        np.testing.assert_allclose(response["features"],X[index])


def test_labels_mature_and_unknown_not_negative(projects):
    project=projects["02"]
    project.score(transaction("labels"))
    project.label({"event_id":"labels","fraud":True,"available_at":time.time()+100})
    assert project.outcomes(time.time())["matured_labels"]==0
    assert project.outcomes(time.time()+200)["matured_labels"]==1


def test_risk_invalid_contract(projects):
    client=TestClient(projects["02"].api())
    assert client.post("/v1/risk-decisions",json=dict(transaction(),amount_minor=-1)).status_code==422
    assert client.post("/v1/risk-decisions",json=dict(transaction(),currency="BAD")).status_code==422


def sensor(sequence=1,equipment="test-unit"):
    return {"site":"lab","equipment":equipment,"sequence":sequence,"temperature":50.0,"vibration":3.0}


def test_edge_warmup_duplicates_and_gaps(projects):
    project=projects["03"]
    first=project.ingest(sensor())
    assert first["state"]=="insufficient_history"
    assert project.ingest(sensor())==first
    with pytest.raises(ValueError,match="duplicate"):
        project.ingest(dict(sensor(),temperature=80))
    for seq in range(2,6):
        response=project.ingest(sensor(seq))
    assert response["state"]=="predicted"
    assert project.ingest(sensor(8))["state"]=="insufficient_history"


def test_edge_acknowledgement_replay(projects):
    assert projects["03"].exercise()["passed"]


def test_edge_disconnection_retains_spool(projects):
    project=projects["03"]
    with database(project.runtime.db) as db:
        before=db.execute("SELECT count(*) FROM spool").fetchone()[0]
    def offline(rows):
        raise ConnectionError("offline")
    with pytest.raises(ConnectionError):
        project.flush(offline)
    with database(project.runtime.db) as db:
        assert db.execute("SELECT count(*) FROM spool").fetchone()[0]==before


def test_edge_backpressure_never_acknowledges_lost_data(projects):
    project=projects["03"]
    with database(project.runtime.db) as db:
        db.executemany("INSERT OR IGNORE INTO spool VALUES(?,?)",[(f"fill-{i}","{}") for i in range(1000)])
    with pytest.raises(OverflowError):
        project.ingest(sensor(1,"full-disk-test"))
    with database(project.runtime.db) as db:
        assert db.execute("SELECT count(*) FROM sensors WHERE equipment='full-disk-test'").fetchone()[0]==0


def test_maintenance_splits_are_entity_disjoint(projects):
    runtime=projects["03"].runtime
    release=runtime.load()[0]["release_id"]
    split=json.loads((runtime.state/"releases"/release/"splits.json").read_text())
    assert not set(split["train_units"])&set(split["test_units"])
    assert not set(split["validation_units"])&set(split["test_units"])


def test_aiops_fixture_review_has_no_execution(projects):
    project=projects["04"]
    result=project.exercise()
    assert result["passed"]
    assert result["review"]["executed"] is False
    before=len(project.incidents())
    project.analyze()
    assert len(project.incidents())==before
    for incident in project.incidents():
        assert incident["proposal"]["causality_proven"] is False
        assert incident["evidence"]["contains_fixture"]


def test_aiops_consumes_actual_http_telemetry(projects):
    runtime=projects["01"].runtime
    pointer=runtime.state/"active.json"
    pointer.unlink()
    client=TestClient(projects["01"].api())
    for _ in range(6):
        assert client.get("/report").status_code==503
    result=projects["04"].analyze()
    assert result["incident_ids"]
    incident=projects["04"].incidents()[0]
    assert incident["service"]=="demand-forecasting"
    assert incident["evidence"]["features"][1]==1.0
    assert incident["evidence"]["contains_fixture"] is False


def test_review_cannot_be_rewritten(projects):
    project=projects["04"]
    identifier=project.exercise()["incident_ids"][0]
    with pytest.raises(ValueError,match="finalized"):
        project.review(identifier,{"decision":"rejected","reviewer":"someone","reason":"Changed decision"})

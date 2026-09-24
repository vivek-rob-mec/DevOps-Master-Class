import json
import time
from concurrent.futures import ThreadPoolExecutor

from fastapi.testclient import TestClient
from conftest import MODULES
from mlops_common.runtime import database


def review_payload(client, **changes):
    data = client.get('/v1/products/SKU-000/planning').json()
    return {"request_id": "review-test-0001", "sku": "SKU-000", "batch_id": data['batch']['id'],
            "inventory_revision": data['product']['revision'], "decision": "approved",
            "reviewer": "Local planner", "notes": "Checked stock", **changes}


def test_dashboard_and_release_evidence(projects):
    client = TestClient(projects['01'].api())
    assert 'Demand Desk' in client.get('/').text
    assert client.get('/assets/app.js').status_code == 200
    assert client.get('/assets/styles.css').status_code == 200
    data = client.get('/v1/products/SKU-000/planning').json()
    assert len(data['history']) == 28 and len(data['forecasts']) == 7
    assert data['history'][-1]['date'] < data['forecasts'][0]['date']
    assert len(data['products']) == 8
    assert data['product']['on_hand'] is None
    assert data['product']['recommended_units'] is None
    assert data['metrics'] == projects['01'].runtime.report()['metrics']
    assert client.get('/v1/products/not-real/planning').status_code == 404


def test_inventory_validation_and_optimistic_concurrency(projects):
    client = TestClient(projects['01'].api())
    for value in (-1, 1.5, True, '10', 1000001):
        assert client.put('/v1/inventory/SKU-000', json={'on_hand': value, 'revision': 0}).status_code == 422
    assert client.put('/v1/inventory/unknown', json={'on_hand': 20, 'revision': 0}).status_code == 404
    def save(_):
        return client.put('/v1/inventory/SKU-000', json={'on_hand': 20, 'revision': 0}).status_code
    with ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(save, range(2))) == [200, 409]
    assert client.put('/v1/inventory/SKU-000', json={'on_hand': 30, 'revision': 1}).json()['revision'] == 2


def test_review_persists_snapshot_and_retries_once(projects):
    project = projects['01']
    client = TestClient(project.api())
    client.put('/v1/inventory/SKU-000', json={'on_hand': 20, 'revision': 0})
    payload = review_payload(client)
    def save(_):
        result = client.post('/v1/replenishment-reviews', json=payload)
        assert result.status_code == 200
        return result.json()
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(save, range(2)))
    assert results[0] == results[1]
    assert results[0]['recommended_units'] == client.get('/v1/products/SKU-000/planning').json()['product']['recommended_units']
    client.put('/v1/inventory/SKU-000', json={'on_hand': 200, 'revision': 1})
    restarted = TestClient(MODULES['01'].Project(project.runtime.root).api())
    assert restarted.post('/v1/replenishment-reviews', json=payload).json() == results[0]
    reviews = restarted.get('/v1/planner').json()['reviews']
    assert len(reviews) == 1 and reviews[0]['on_hand'] == 20
    assert restarted.post('/v1/replenishment-reviews', json={**payload, 'notes': 'changed'}).status_code == 409


def test_stale_inputs_and_batch_cannot_be_approved(projects):
    project = projects['01']
    client = TestClient(project.api())
    client.put('/v1/inventory/SKU-000', json={'on_hand': 20, 'revision': 0})
    payload = review_payload(client)
    client.put('/v1/inventory/SKU-000', json={'on_hand': 21, 'revision': 1})
    assert client.post('/v1/replenishment-reviews', json=payload).status_code == 409
    project.forecast(origin=200)
    assert client.post('/v1/replenishment-reviews', json={**payload, 'inventory_revision': 2}).status_code == 409
    with database(project.runtime.db) as db:
        db.execute('UPDATE batches SET created=?', (time.time()-90000,))
    payload = review_payload(client)
    assert client.get('/v1/planner').json()['batch']['stale']
    assert client.post('/v1/replenishment-reviews', json=payload).status_code == 409
    response = client.post('/v1/replenishment-reviews', json={**payload, 'decision': 'deferred'})
    assert response.status_code == 200 and response.json()['stale']


def test_promotion_does_not_relabel_published_forecast(projects):
    project = projects['01']
    before = project.planner('SKU-000')
    # A new release can be promoted without publishing forecasts from it.
    release, model = project.runtime.load()
    folder = project.runtime.state / 'releases' / release['release_id']
    data = json.loads((folder / 'dataset.json').read_text())
    data['SKU-000'][-1] = 9999
    metrics = {**before['metrics'], 'selected': 'random_forest'}
    newer = project.runtime.release(model, data, json.loads((folder/'splits.json').read_text()), metrics, release['feature_schema'], release['policy'])
    project.runtime.activate(newer['release_id'])
    after = project.planner('SKU-000')
    assert after['release_mismatch']
    assert after['history'] == before['history']
    assert after['metrics'] == before['metrics']
    assert after['batch']['release_id'] == before['batch']['release_id']


def test_empty_state_and_corrupt_evidence(projects, tmp_path):
    empty = TestClient(MODULES['01'].Project(tmp_path/'empty').api())
    assert empty.get('/').status_code == 200
    assert empty.get('/v1/planner').json()['batch'] is None
    assert empty.get('/v1/products/SKU-000/planning').status_code == 404
    project = projects['01']
    release, _ = project.runtime.load()
    (project.runtime.state/'releases'/release['release_id']/'metrics.json').write_text('{}')
    assert TestClient(project.api()).get('/v1/planner').status_code == 503


def test_additive_schema_preserves_forecasts(projects):
    project = projects['01']
    before = project.get_forecast('SKU-000')
    with database(project.runtime.db) as db:
        db.execute('DROP TABLE inventory')
        db.execute('DROP TABLE replenishment_reviews')
    restarted = MODULES['01'].Project(project.runtime.root)
    assert restarted.get_forecast('SKU-000') == before
    assert restarted.planner()['products'][0]['revision'] == 0


def test_write_origin_and_payload_limits(projects):
    client = TestClient(projects['01'].api())
    assert client.put('/v1/inventory/SKU-000', json={'on_hand': 20, 'revision': 0}, headers={'Origin': 'https://unrelated.example'}).status_code == 403
    assert client.put('/v1/inventory/SKU-000', json={'on_hand': 20, 'revision': 0}, headers={'Origin': 'http://testserver'}).status_code == 200
    for changes in ({'reviewer': '   '}, {'notes': 'x'*1001}, {'recommended_units': 0}, {'inventory_revision': 0}):
        assert client.post('/v1/replenishment-reviews', json=review_payload(client, **changes)).status_code == 422

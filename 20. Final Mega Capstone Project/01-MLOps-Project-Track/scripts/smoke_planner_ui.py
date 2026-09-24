r"""Real Edge browser checks against an isolated API + SQLite database.

Install requirements-browser.txt; Edge must be installed. No production state is used.
Run from the track folder: .\.venv\Scripts\python.exe scripts/smoke_planner_ui.py
"""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time

import httpx
from playwright.sync_api import sync_playwright, expect

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / '01-demand-forecasting'))
from app import Project


def main():
    evidence = ROOT / 'evidence'
    evidence.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='planner-ui-') as temp:
        os.environ['STATE_DIR'] = str(Path(temp)/'state')
        os.environ['TELEMETRY_DB'] = str(Path(temp)/'telemetry.db')
        project = Project()
        project.demo()
        with socket.socket() as listener:
            listener.bind(('127.0.0.1', 0))
            port = listener.getsockname()[1]
        url = f'http://127.0.0.1:{port}'
        with (Path(temp)/'server.log').open('w') as log:
            server = subprocess.Popen([sys.executable, str(ROOT/'01-demand-forecasting/run.py'), 'serve', '--port', str(port)],
                                      cwd=ROOT, stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            try:
                for _ in range(100):
                    if server.poll() is not None:
                        raise RuntimeError('API server exited; inspect browser smoke log')
                    try:
                        if httpx.get(url+'/healthz', timeout=1).status_code == 200:
                            break
                    except httpx.HTTPError:
                        pass
                    time.sleep(.1)
                else:
                    raise RuntimeError('API startup timed out')
                with sync_playwright() as p:
                    browser = p.chromium.launch(channel='msedge', headless=True)
                    page = browser.new_page(viewport={'width': 1440, 'height': 1100})
                    errors = []
                    page.on('pageerror', lambda error: errors.append(str(error)))
                    page.goto(url)
                    expect(page.locator('#forecast-title')).to_have_text('SKU-000')
                    expect(page.locator('#chart svg')).to_be_visible()
                    expect(page.locator('#save-review')).to_be_disabled()
                    page.get_by_label('Search products').fill('SKU-003')
                    expect(page.locator('.product')).to_have_count(1)
                    page.locator('.product').click()
                    expect(page.locator('#forecast-title')).to_have_text('SKU-003')
                    page.get_by_label('Inventory on hand').fill('40')
                    page.get_by_role('button', name='Save stock').click()
                    expect(page.locator('#inventory-state')).to_contain_text('revision 1')
                    expect(page.locator('#save-review')).to_be_enabled()
                    page.get_by_label('Inventory on hand').fill('41')
                    expect(page.locator('#save-review')).to_be_disabled()
                    page.get_by_label('Inventory on hand').fill('40')
                    page.get_by_label('Reviewer name').fill('Browser Planner')
                    page.get_by_label('Review notes').fill('<script>alert("unsafe")</script> Checked shelf stock.')
                    page.get_by_role('button', name='Save review').click()
                    expect(page.locator('#reviews')).to_contain_text('Browser Planner')
                    expect(page.locator('#reviews script')).to_have_count(0)
                    page.reload()
                    expect(page.locator('#reviews')).to_contain_text('Browser Planner')
                    page.get_by_role('button', name='SKU-003', exact=False).click()
                    expect(page.get_by_label('Inventory on hand')).to_have_value('40')
                    saved = httpx.get(url+'/v1/planner').json()['reviews']
                    assert len(saved) == 1 and saved[0]['on_hand'] == 40
                    page.screenshot(path=str(evidence/'planner-desktop.png'), full_page=True)
                    page.set_viewport_size({'width': 390, 'height': 844})
                    assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
                    page.screenshot(path=str(evidence/'planner-mobile.png'), full_page=True)
                    page.get_by_label('Search products').fill('unknown')
                    expect(page.locator('#product-list')).to_contain_text('No products match')
                    page.route('**/v1/planner', lambda route: route.fulfill(status=503, json={'detail':'Test unavailable'}))
                    page.get_by_role('button', name='Refresh data').click()
                    expect(page.locator('#notice')).to_contain_text('Test unavailable')
                    expect(page.locator('#dashboard')).to_be_hidden()
                    page.unroute('**/v1/planner')
                    page.get_by_role('button', name='Refresh data').click()
                    expect(page.locator('#dashboard')).to_be_visible()
                    from mlops_common.runtime import database
                    with database(project.runtime.db) as db:
                        db.execute('UPDATE batches SET created=?', (time.time()-90000,))
                    page.get_by_label('Search products').fill('SKU-003')
                    page.get_by_role('button', name='Refresh data').click()
                    expect(page.locator('#notice')).to_contain_text('over 24 hours')
                    expect(page.locator('#save-review')).to_be_disabled()
                    page.get_by_label('Decision', exact=True).select_option('deferred')
                    expect(page.locator('#save-review')).to_be_enabled()
                    page.get_by_label('Reviewer name').fill('Stale batch planner')
                    page.get_by_role('button', name='Save review').click()
                    expect(page.locator('#reviews')).to_contain_text('Stale batch planner')
                    # Empty state uses the real API and DB after removing the pointer in this disposable fixture.
                    with database(project.runtime.db) as db:
                        db.execute('DELETE FROM current_batch')
                    page.get_by_role('button', name='Refresh data').click()
                    expect(page.locator('#empty')).to_be_visible()
                    assert not errors, errors
                    browser.close()
                result = {'passed': True, 'browser': 'Microsoft Edge headless', 'checks': ['product search', 'forecast SVG', 'inventory save', 'dirty inventory guard', 'review save', 'literal user text', 'reload persistence', 'mobile overflow', 'API error/recovery', 'stale approval guard and deferral', 'empty database']}
                (evidence/'planner-browser.json').write_text(json.dumps(result, indent=2))
                print(json.dumps(result, indent=2))
            finally:
                server.terminate()
                server.wait(timeout=15)
                (evidence/'planner-browser-server.log').write_text((Path(temp)/'server.log').read_text())


if __name__ == '__main__':
    main()

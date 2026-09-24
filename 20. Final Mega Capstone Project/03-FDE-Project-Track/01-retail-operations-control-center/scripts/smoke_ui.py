"""Real Edge + HTTP API + separate worker, all using a disposable database."""
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


def main():
    evidence = ROOT / 'evidence'
    evidence.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='retail-ui-') as temp:
        env = {**os.environ, 'STATE_DIR': str(Path(temp) / 'state')}
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            port = sock.getsockname()[1]
        base = f'http://127.0.0.1:{port}'
        with (Path(temp) / 'server.log').open('w') as log:
            stop_file = Path(temp) / 'stop-server'
            server = subprocess.Popen([sys.executable, str(ROOT / 'scripts/ui_server.py'), str(port), str(stop_file)],
                cwd=ROOT, env=env, stdout=log, stderr=log,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            try:
                for _ in range(100):
                    if server.poll() is not None: raise RuntimeError('API exited')
                    try:
                        if httpx.get(base + '/readyz', timeout=1).status_code == 200: break
                    except httpx.HTTPError: pass
                    time.sleep(.1)
                else: raise RuntimeError('API startup timeout')
                with sync_playwright() as p:
                    browser = p.chromium.launch(channel='msedge', headless=True)
                    try:
                        page = browser.new_page(viewport={'width':1440,'height':1080})
                        errors = []
                        page.on('pageerror', lambda error: errors.append(str(error)))
                        page.goto(base)
                        expect(page.locator('#empty')).to_be_visible()
                        expect(page.locator('#queue')).to_be_disabled()
                        page.get_by_role('button', name='Load simulated ERP export').click()
                        expect(page.locator('#sales')).not_to_have_value('')
                        page.get_by_role('button', name='Validate and publish snapshot').click()
                        expect(page.locator('#coverage')).to_have_text('3 / 35')
                        first = httpx.get(base+'/v1/desk').json()['batch']['id']
                        page.get_by_role('button', name='Validate and publish snapshot').click()
                        expect(page.locator('#notice')).to_contain_text('Snapshot validated')
                        assert httpx.get(base+'/v1/desk').json()['batch']['id'] == first
                        page.get_by_role('button', name='Queue forecast').click()
                        expect(page.locator('#job-state')).to_have_text('queued')
                        expect(page.locator('#save-review')).to_be_disabled()
                        subprocess.run([sys.executable, str(ROOT/'app.py'), 'worker', '--once'], cwd=ROOT, env=env, check=True, timeout=20)
                        page.get_by_role('button', name='Refresh data').click()
                        expect(page.locator('#job-state')).to_have_text('succeeded')
                        expect(page.locator('#forecast')).to_contain_text('115')
                        page.get_by_label('Decision', exact=True).select_option('approved')
                        page.get_by_label('Reviewer', exact=True).fill('Customer planner')
                        page.get_by_label('Decision rationale').fill('<script>bad()</script> Checked stock and upcoming delivery.')
                        page.get_by_role('button', name='Save review').click()
                        expect(page.locator('#reviews')).to_contain_text('Customer planner')
                        expect(page.locator('#reviews script')).to_have_count(0)
                        expect(page.locator('#save-review')).to_be_disabled()
                        page.reload()
                        expect(page.locator('#reviews')).to_contain_text('Customer planner')
                        expect(page.locator('#save-review')).to_be_disabled()
                        page.screenshot(path=str(evidence/'retail-desktop.png'), full_page=True)
                        page.set_viewport_size({'width':390,'height':844})
                        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
                        page.screenshot(path=str(evidence/'retail-mobile.png'), full_page=True)
                        page.get_by_role('button', name='Load simulated ERP export').click()
                        expect(page.locator('#inventory')).not_to_have_value('')
                        page.get_by_label('Sales CSV contents').fill('bad,headers\n1,2')
                        page.get_by_role('button', name='Validate and publish snapshot').click()
                        expect(page.locator('#notice')).to_contain_text('CSV headers must be exactly')
                        assert httpx.get(base+'/v1/desk').json()['batch']['id'] == first
                        # A second planner publishes a new import while this browser shows the old forecast.
                        fixture = httpx.get(base+'/v1/erp/export').json()
                        assert httpx.post(base+'/v1/imports', json={'request_id':'second-planner-import',
                            'sales_csv':fixture['sales_csv'], 'inventory_csv':fixture['inventory_csv'].replace('COFFEE,35,10','COFFEE,40,10')}).status_code == 200
                        page.get_by_label('Product', exact=True).select_option('OATS')
                        page.get_by_label('Reviewer', exact=True).fill('Second reviewer')
                        page.get_by_label('Decision rationale').fill('Stale browser should not approve this')
                        page.get_by_role('button', name='Save review').click()
                        expect(page.locator('#notice')).to_contain_text('Snapshot superseded')
                        assert len(httpx.get(base+'/v1/desk').json()['reviews']) == 1
                        page.route('**/v1/desk', lambda route: route.fulfill(status=503, json={'detail':'Simulated database outage'}))
                        page.get_by_role('button', name='Refresh data').click()
                        expect(page.locator('#notice')).to_contain_text('Simulated database outage')
                        page.unroute('**/v1/desk')
                        page.get_by_role('button', name='Refresh data').click()
                        expect(page.locator('#notice')).to_contain_text('Ledger refreshed')
                        expect(page.locator('#job-state')).to_have_text('Not queued')
                        assert not errors, errors
                        (evidence/'browser.json').write_text(json.dumps({'passed':True,'browser':'Microsoft Edge',
                            'checks':['empty state','simulated ERP import','import retry','separate worker',
                                      'forecast evidence','review persistence','literal user text',
                                      'mobile overflow','atomic invalid import','stale review conflict','API error recovery'],
                            'page_errors':errors}, indent=2))
                        print('Retail browser checks passed')
                    finally:
                        browser.close()
            finally:
                stop_file.touch()
                server.wait(timeout=10)


if __name__ == '__main__':
    main()

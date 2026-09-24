"""Run both operator dashboards in real Edge against disposable API/SQLite state.

From the track folder, install requirements-browser.txt, then run this script
with the track virtual environment. Microsoft Edge must already be installed.
"""
from contextlib import contextmanager
import importlib.util
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
from mlops_common.runtime import database


@contextmanager
def application(folder):
    with tempfile.TemporaryDirectory(prefix='operator-desk-') as temp:
        environment = {**os.environ, 'STATE_DIR':str(Path(temp)/'state'), 'TELEMETRY_DB':str(Path(temp)/'telemetry.db')}
        with (Path(temp)/'server.log').open('w') as log:
            subprocess.run([sys.executable,str(ROOT/folder/'run.py'),'demo'],env=environment,cwd=ROOT,stdout=log,stderr=log,check=True)
            with socket.socket() as sock:
                sock.bind(('127.0.0.1',0)); port = sock.getsockname()[1]
            base = f'http://127.0.0.1:{port}'
            server = subprocess.Popen([sys.executable,str(ROOT/folder/'run.py'),'serve','--port',str(port)],
                env=environment,cwd=ROOT,stdout=log,stderr=log,creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
            try:
                for _ in range(100):
                    if server.poll() is not None: raise RuntimeError('API exited before readiness')
                    try:
                        if httpx.get(base+'/readyz',timeout=1).status_code == 200: break
                    except httpx.HTTPError: pass
                    time.sleep(.1)
                else: raise RuntimeError('API readiness timed out')
                yield base, Path(temp)/'state'
            finally:
                server.terminate(); server.wait(timeout=15)
                log.flush()
                (ROOT/'evidence'/f'{folder}-browser-server.log').write_text((Path(temp)/'server.log').read_text())


def responsive_and_recovery(page, route, prefix):
    page.screenshot(path=str(ROOT/'evidence'/f'{prefix}-desktop.png'),full_page=True)
    page.set_viewport_size({'width':390,'height':844})
    assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), 'Page overflows mobile viewport'
    page.screenshot(path=str(ROOT/'evidence'/f'{prefix}-mobile.png'),full_page=True)
    page.route('**'+route,lambda r:r.fulfill(status=503,json={'detail':'Simulated API outage'}))
    page.get_by_role('button',name='Refresh data').click()
    expect(page.locator('#notice')).to_contain_text('Simulated API outage')
    expect(page.locator('#dashboard')).to_be_hidden()
    page.unroute('**'+route)
    page.get_by_role('button',name='Refresh data').click()
    expect(page.locator('#dashboard')).to_be_visible()


def risk(browser):
    with application('02-payment-risk') as (base,state):
        page = browser.new_page(viewport={'width':1440,'height':1080})
        errors = []; page.on('pageerror',lambda e:errors.append(str(e)))
        page.goto(base)
        expect(page.locator('#score-submit')).to_be_enabled()
        page.get_by_label('Event ID',exact=True).fill('browser-risk-001')
        page.get_by_label('Entity ID',exact=True).fill('browser-entity')
        page.get_by_label('Amount in minor units').fill('8000')
        page.get_by_role('button',name='Score payment').click()
        expect(page.locator('#detail-title')).to_have_text('browser-risk-001')
        expect(page.locator('#risk-score')).not_to_have_text('—')
        expect(page.locator('#notice')).to_contain_text('Decision saved')
        count = httpx.get(base+'/v1/desk').json()['summary']['scored']
        page.get_by_role('button',name='Score payment').click()
        expect(page.locator('#notice')).to_contain_text('Decision saved')
        assert httpx.get(base+'/v1/desk').json()['summary']['scored'] == count
        page.get_by_label('Amount in minor units').fill('8001')
        page.get_by_role('button',name='Score payment').click()
        expect(page.locator('#notice')).to_contain_text('Conflicting duplicate')
        page.get_by_label('Amount in minor units').fill('8000')
        page.get_by_label('Reviewer name').fill('Browser Analyst')
        page.get_by_label('Review rationale').fill('<script>bad()</script> Investigate simulated velocity.')
        page.get_by_role('button',name='Save analyst review').click()
        expect(page.locator('#reviews')).to_contain_text('Browser Analyst')
        expect(page.locator('#reviews script')).to_have_count(0)
        expect(page.locator('#review-submit')).to_be_disabled()
        page.get_by_label('Simulated observed outcome').select_option('true')
        page.get_by_label('Available at (your local time)').fill('2099-01-01T12:00')
        page.get_by_role('button',name='Save outcome label').click()
        expect(page.locator('#label-state')).to_contain_text('pending')
        expect(page.locator('#matured')).to_have_text('0')
        page.reload()
        expect(page.locator('#reviews')).to_contain_text('Browser Analyst')
        expect(page.locator('#label-state')).to_contain_text('pending')
        page.get_by_label('Search decisions').fill('browser-entity')
        expect(page.locator('#ledger tr')).to_have_count(1)
        page.get_by_label('Search decisions').fill('absent')
        expect(page.locator('#ledger-empty')).to_contain_text('No events match')
        page.get_by_label('Search decisions').fill('')
        responsive_and_recovery(page,'/v1/desk','risk-desk')
        with database(state/'application.db') as db:
            db.execute('DELETE FROM operator_reviews'); db.execute('DELETE FROM labels'); db.execute('DELETE FROM decisions')
        page.goto(base)
        expect(page.locator('#ledger-empty')).to_contain_text('No decisions yet')
        expect(page.locator('#review-submit')).to_be_disabled()
        assert not errors, errors
        page.close()
    return ['score and original retry','conflicting event','analyst review','literal notes','pending label hidden from coverage',
            'reload persistence','search','mobile layout','API error/recovery','empty ledger']


def maintenance(browser):
    with application('03-predictive-maintenance') as (base,state):
        page = browser.new_page(viewport={'width':1440,'height':1080})
        errors = []; page.on('pageerror',lambda e:errors.append(str(e)))
        page.goto(base)
        expect(page.locator('#sensor-submit')).to_be_enabled()
        page.get_by_label('Equipment ID',exact=True).fill('browser-machine')
        release = json.loads((state/'active.json').read_text())['release_id']
        # Use realistic late-life simulator readings; arbitrary early-age/high-wear
        # combinations are out of distribution and need not trigger this model.
        samples = json.loads((state/'releases'/release/'dataset.json').read_text())[0]['samples'][-7:]
        page.get_by_label('Sequence / simulated cycle').fill(str(samples[0]['sequence']))
        for index, sample in enumerate(samples):
            sequence = sample['sequence']
            if index > 0: page.get_by_role('button',name='Use next sequence for selected unit').click()
            page.get_by_label('Temperature*',exact=True).fill(str(sample['temperature']))
            page.get_by_label('Vibration*',exact=True).fill(str(sample['vibration']))
            page.get_by_role('button',name='Submit sensor reading').click()
            expect(page.locator('#remaining-context')).to_contain_text(f'Sequence {sequence} ·')
            expect(page.locator('#notice')).to_contain_text('Reading persisted')
            if index < 4:
                expect(page.locator('#remaining')).to_have_text('Collecting history')
                expect(page.locator('#review-submit')).to_be_disabled()
        expect(page.locator('#chart svg')).to_be_visible()
        expect(page.locator('#prediction-state')).to_contain_text('Inspection advisory')
        before = httpx.get(base+'/v1/fleet').json()['summary']['samples']
        page.get_by_role('button',name='Submit sensor reading').click()
        expect(page.locator('#notice')).to_contain_text('Reading persisted')
        assert httpx.get(base+'/v1/fleet').json()['summary']['samples'] == before
        page.get_by_label('Reviewer name').fill('Browser Operator')
        page.get_by_label('Review rationale').fill('Inspect after three low estimates; simulator only.')
        page.get_by_role('button',name='Save inspection review').click()
        expect(page.locator('#reviews')).to_contain_text('Browser Operator')
        expect(page.locator('#review-submit')).to_be_disabled()
        page.get_by_role('button',name='Upload up to 100 queued records').click()
        expect(page.locator('#queued')).to_have_text('0')
        expect(page.locator('#flush')).to_be_disabled()
        page.reload()
        expect(page.locator('#reviews')).to_contain_text('Browser Operator')
        page.get_by_role('button',name='browser-machine',exact=False).click()
        expect(page.locator('#detail-title')).to_have_text('lab / browser-machine')
        expect(page.locator('#review-submit')).to_be_disabled()
        page.get_by_label('Search equipment').fill('absent')
        expect(page.locator('#fleet-empty')).to_contain_text('No equipment matches')
        page.get_by_label('Search equipment').fill('')
        responsive_and_recovery(page,'/v1/fleet','fleet-desk')
        # Submit a genuine gap in the disposable fixture; UI must withhold inference.
        response = httpx.post(base+'/v1/sensor-events',json={'site':'lab','equipment':'browser-machine','sequence':samples[-1]['sequence']+3,'temperature':80,'vibration':14})
        assert response.status_code == 200
        page.get_by_role('button',name='Refresh data').click()
        expect(page.locator('#remaining')).to_have_text('Collecting history')
        expect(page.locator('#review-submit')).to_be_disabled()
        with database(state/'application.db') as db:
            db.execute('DELETE FROM operator_reviews'); db.execute('DELETE FROM spool'); db.execute('DELETE FROM sensors')
        page.goto(base)
        expect(page.locator('#fleet-empty')).to_contain_text('No equipment yet')
        expect(page.locator('#review-submit')).to_be_disabled()
        assert not errors, errors
        page.close()
    return ['sensor submission','warmup guard','three-estimate advisory','sensor retry','inspection review',
            'spool upload','reload persistence','search','mobile layout','API error/recovery','gap withholds prediction','empty fleet']


def main():
    (ROOT/'evidence').mkdir(exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(channel='msedge',headless=True)
        try:
            result = {'passed':True,'browser':'Microsoft Edge headless','risk':risk(browser),'maintenance':maintenance(browser)}
        finally:
            browser.close()
    (ROOT/'evidence'/'operator-browser.json').write_text(json.dumps(result,indent=2))
    print(json.dumps(result,indent=2))


if __name__ == '__main__':
    main()

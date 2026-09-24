"""Verify Incident Desk and actual M1 HTTP failures in disposable local state.

Requires requirements-browser.txt and installed Microsoft Edge. No working
application data or running MLOps service is changed by these checks.
"""
from contextlib import contextmanager
import json
import os
import socket
import subprocess
import sys
import time

import httpx
from playwright.sync_api import sync_playwright, expect

from smoke_operator_ui import ROOT, application, responsive_and_recovery
from mlops_common.runtime import database


@contextmanager
def unprepared_forecast(state):
    """A real separate M1 API with no model, sharing only test telemetry."""
    environment={**os.environ,'STATE_DIR':str(state.parent/'unprepared-demand'),
                 'TELEMETRY_DB':str(state.parent/'telemetry.db')}
    with socket.socket() as sock:
        sock.bind(('127.0.0.1',0)); port=sock.getsockname()[1]
    base=f'http://127.0.0.1:{port}'
    with (state.parent/'demand-source.log').open('w') as log:
        server=subprocess.Popen([sys.executable,str(ROOT/'01-demand-forecasting/run.py'),'serve','--port',str(port)],
            env=environment,cwd=ROOT,stdout=log,stderr=log,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
        try:
            for _ in range(100):
                if server.poll() is not None: raise RuntimeError('Source API exited')
                try:
                    if httpx.get(base+'/healthz',timeout=1).status_code==200: break
                except httpx.HTTPError: pass
                time.sleep(.1)
            else: raise RuntimeError('Source API startup timed out')
            yield base
        finally:
            server.terminate(); server.wait(timeout=15)


def main():
    (ROOT/'evidence').mkdir(exist_ok=True)
    with application('04-aiops-incident-triage') as (base,state), sync_playwright() as p:
        browser=p.chromium.launch(channel='msedge',headless=True)
        try:
            page=browser.new_page(viewport={'width':1440,'height':1080})
            errors=[]; page.on('pageerror',lambda error:errors.append(str(error)))
            page.goto(base)
            expect(page.locator('#services .service-card')).to_have_count(3)
            expect(page.locator('#eligible')).to_have_text('0')
            expect(page.locator('#incidents-empty')).to_be_visible()
            expect(page.locator('#review-submit')).to_be_disabled()
            page.get_by_role('button',name='Analyze current windows').click()
            expect(page.locator('#notice')).to_contain_text('Analyzed 0 eligible windows')
            expect(page.locator('#runs tr')).to_have_count(1)
            page.get_by_label('Service to represent').select_option('payment-risk')
            page.get_by_role('button',name='Add labeled fixture').click()
            expect(page.locator('#fixture-count')).to_have_text('10')
            expect(page.locator('#notice')).to_contain_text('Labeled replay ready')
            page.get_by_role('button',name='Add labeled fixture').click()
            expect(page.locator('#notice')).to_contain_text('Labeled replay ready')
            expect(page.locator('#fixture-count')).to_have_text('10')
            page.get_by_role('button',name='Analyze current windows').click()
            expect(page.locator('#incident-count')).to_have_text('1')
            expect(page.locator('#detail-source')).to_contain_text('Includes fixture')
            expect(page.locator('#hypotheses')).to_contain_text('release regression')
            page.get_by_role('button',name='Analyze current windows').click()
            expect(page.locator('#notice')).to_contain_text('Analyzed 1 eligible windows')
            expect(page.locator('#incident-count')).to_have_text('1')
            page.get_by_label('Reviewer name').fill('Browser Operator')
            page.get_by_label('Review decision').select_option('rejected')
            page.get_by_label('Review rationale').fill('<script>bad()</script> A fixture correlation does not establish a real regression.')
            page.get_by_role('button',name='Save human review').click()
            expect(page.locator('#review-state')).to_contain_text('Finalized: rejected')
            expect(page.locator('#review-submit')).to_be_disabled()
            expect(page.locator('#notice')).to_contain_text('No command was executed')
            page.reload()
            expect(page.locator('#review-state')).to_contain_text('Browser Operator')
            expect(page.locator('#reason')).to_have_value('<script>bad()</script> A fixture correlation does not establish a real regression.')
            page.get_by_label('Filter review state').select_option('pending')
            expect(page.locator('#incidents-empty')).to_contain_text('No incidents match')
            page.get_by_label('Filter review state').select_option('all')
            page.get_by_label('Filter evidence source').select_option('http')
            expect(page.locator('#incidents-empty')).to_be_visible()
            page.get_by_label('Filter evidence source').select_option('all')
            page.get_by_label('Search incidents').fill('absent-service')
            expect(page.locator('#incidents-empty')).to_be_visible()
            page.get_by_label('Search incidents').fill('')

            # Emit actual loopback HTTP errors through the real shared middleware.
            with unprepared_forecast(state) as source:
                for _ in range(6): assert httpx.get(source+'/report').status_code==503
            page.get_by_role('button',name='Analyze current windows').click()
            expect(page.locator('#detail-source')).to_contain_text('HTTP sample evidence')
            expect(page.locator('#finding-title')).to_have_text('Demand forecasting')
            expect(page.locator('#hypotheses')).to_contain_text('dependency or application failure')
            data=httpx.get(base+'/v1/desk').json()
            live=next(i for i in data['incidents'] if i['service']=='demand-forecasting')
            assert not live['evidence']['contains_fixture']
            assert len(live['evidence']['source_events'])==6
            assert all(r['context']['status']==503 for r in live['evidence']['source_events'])
            assert not live['proposal']['executes_commands'] and not live['proposal']['causality_proven']
            page.get_by_text('Inspect the source event snapshots',exact=True).click()
            expect(page.locator('#source-events tr')).to_have_count(6)
            expect(page.locator('#source-events')).to_contain_text('503')
            responsive_and_recovery(page,'/v1/desk','incident-desk')

            # Age only this disposable telemetry. Preserve saved incident snapshots.
            with database(state.parent/'telemetry.db') as db:
                db.execute("UPDATE events SET ts=? WHERE service!='aiops-triage'",(time.time()-120,))
            page.get_by_role('button',name='Refresh data').click()
            expect(page.locator('#eligible')).to_have_text('0')
            expect(page.locator('#incident-count')).to_have_text('2')
            expect(page.locator('#source-events tr')).to_have_count(6)
            saved=httpx.get(base+f"/v1/incidents/{live['id']}").json()
            assert saved['evidence']==live['evidence']
            # An unavailable detector must not hide the ledger or pretend to analyze.
            release=json.loads((state/'active.json').read_text())['release_id']
            (state/'releases'/release/'metrics.json').write_text('{}')
            page.get_by_role('button',name='Refresh data').click()
            expect(page.locator('#model-warning')).to_be_visible()
            expect(page.locator('#analyze')).to_be_disabled()
            expect(page.locator('#incident-count')).to_have_text('2')
            assert not errors,errors
        finally:
            browser.close()
    result={'passed':True,'browser':'Microsoft Edge headless','checks':[
        'no telemetry and empty analysis','fixture replay deduplication','incident analysis deduplication',
        'source and hypothesis display','final review and reload','search and filters',
        'actual M1 HTTP 503 evidence','mobile overflow','API error and recovery',
        'retained snapshots after telemetry expiry','unavailable detector with readable ledger']}
    (ROOT/'evidence'/'aiops-browser.json').write_text(json.dumps(result,indent=2))
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    main()

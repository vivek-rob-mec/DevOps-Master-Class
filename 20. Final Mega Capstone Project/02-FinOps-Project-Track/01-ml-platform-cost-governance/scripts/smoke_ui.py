"""Exercise Cost Desk in installed Edge with an isolated real API and database."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time

import httpx
from playwright.sync_api import sync_playwright,expect

ROOT=Path(__file__).resolve().parents[1]


def main():
    evidence=ROOT/'evidence'; evidence.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='finops-ui-') as temp:
        env={**os.environ,'STATE_DIR':str(Path(temp)/'state')}
        with socket.socket() as sock:
            sock.bind(('127.0.0.1',0)); port=sock.getsockname()[1]
        base=f'http://127.0.0.1:{port}'
        with (Path(temp)/'server.log').open('w') as log:
            server=subprocess.Popen([sys.executable,str(ROOT/'app.py'),'serve','--port',str(port)],
                cwd=ROOT,env=env,stdout=log,stderr=log,creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
            try:
                for _ in range(100):
                    if server.poll() is not None: raise RuntimeError('API exited')
                    try:
                        if httpx.get(base+'/readyz',timeout=1).status_code==200: break
                    except httpx.HTTPError: pass
                    time.sleep(.1)
                else: raise RuntimeError('API startup timed out')
                with sync_playwright() as p:
                    browser=p.chromium.launch(channel='msedge',headless=True)
                    try:
                        page=browser.new_page(viewport={'width':1440,'height':1080})
                        errors=[]; page.on('pageerror',lambda error:errors.append(str(error)))
                        page.goto(base)
                        expect(page.locator('#empty')).to_be_visible()
                        expect(page.locator('#budget-submit')).to_be_disabled()
                        page.get_by_role('button',name='Load sample CSVs').click()
                        expect(page.locator('#cost-csv')).not_to_have_value('')
                        page.get_by_role('button',name='Validate and publish snapshot').click()
                        expect(page.locator('#total')).to_contain_text('325.750042')
                        expect(page.locator('#chart svg')).to_be_visible()
                        before=httpx.get(base+'/v1/desk').json()['batch']['id']
                        page.get_by_role('button',name='Validate and publish snapshot').click()
                        expect(page.locator('#notice')).to_contain_text('validated and published')
                        assert httpx.get(base+'/v1/desk').json()['batch']['id']==before
                        page.get_by_label('Retail basis points').fill('1000')
                        page.get_by_role('button',name='Save allocation policy').click()
                        expect(page.locator('#notice')).to_contain_text('must sum to 10000')
                        for name in ['Retail','Risk','Operations','Platform']:
                            page.get_by_label(name+' basis points').fill('2500')
                        page.get_by_role('button',name='Save allocation policy').click()
                        expect(page.locator('#policy-revision')).to_contain_text('revision 2')
                        expect(page.locator('#total')).to_contain_text('325.750042')
                        page.get_by_label('Budget amount (snapshot currency)').fill('100.000001')
                        page.get_by_role('button',name='Save team budget').click()
                        expect(page.locator('#budget-state')).to_contain_text('revision 1')
                        assert httpx.get(base+'/v1/desk').json()['teams'][0]['budget_micro']==100000001
                        page.get_by_role('button',name='Calculate scenario').click()
                        expect(page.locator('#saving')).to_contain_text('23.25')
                        page.get_by_label('Reviewer name').fill('Browser FinOps analyst')
                        page.get_by_label('Rationale and checks needed').fill('<script>bad()</script> Verify latency and throughput before changing usage.')
                        page.get_by_role('button',name='Save scenario review').click()
                        expect(page.locator('#reviews')).to_contain_text('Browser FinOps analyst')
                        expect(page.locator('#reviews script')).to_have_count(0)
                        page.reload()
                        expect(page.locator('#reviews')).to_contain_text('Browser FinOps analyst')
                        expect(page.locator('#budget-amount')).to_have_value('100.000001')
                        expect(page.locator('#policy-revision')).to_contain_text('revision 2')
                        page.screenshot(path=str(evidence/'cost-desk-desktop.png'),full_page=True)
                        page.set_viewport_size({'width':390,'height':844})
                        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
                        page.screenshot(path=str(evidence/'cost-desk-mobile.png'),full_page=True)
                        page.get_by_role('button',name='Load sample CSVs').click()
                        expect(page.locator('#cost-csv')).not_to_have_value('')
                        page.get_by_label('Cost CSV contents').fill('bad,headers\n1,2')
                        page.get_by_role('button',name='Validate and publish snapshot').click()
                        expect(page.locator('#notice')).to_contain_text('CSV headers must be exactly')
                        assert httpx.get(base+'/v1/desk').json()['batch']['id']==before
                        page.route('**/v1/desk',lambda route:route.fulfill(status=503,json={'detail':'Simulated unavailable ledger'}))
                        page.get_by_role('button',name='Refresh data').click()
                        expect(page.locator('#notice')).to_contain_text('Simulated unavailable ledger')
                        page.unroute('**/v1/desk')
                        page.get_by_role('button',name='Refresh data').click()
                        expect(page.locator('#total')).to_contain_text('325.750042')
                        current=httpx.get(base+'/v1/desk').json()
                        change=httpx.post(base+'/v1/policy',json={'revision':current['policy']['revision'],**dict.fromkeys(['retail','risk','operations','platform'],2500)})
                        assert change.status_code==200
                        page.get_by_role('button',name='Calculate scenario').click()
                        expect(page.locator('#notice')).to_contain_text('Refresh before calculating a scenario')
                        expect(page.locator('#review-submit')).to_be_disabled()
                        page.get_by_role('button',name='Refresh data').click()
                        page.get_by_role('button',name='Calculate scenario').click()
                        expect(page.locator('#saving')).to_contain_text('23.25')
                        assert not errors,errors
                    finally: browser.close()
                result={'passed':True,'browser':'Microsoft Edge headless','checks':['empty state','CSV publication and retry','invalid policy','exact budget','scenario review','literal rationale','reload persistence','desktop/mobile','invalid CSV retains active data','API error/recovery','stale scenario preview guard']}
                (evidence/'browser.json').write_text(json.dumps(result,indent=2)); print(json.dumps(result,indent=2))
            finally:
                server.terminate(); server.wait(timeout=15)
                log.flush(); (evidence/'browser-server.log').write_text((Path(temp)/'server.log').read_text())


if __name__=='__main__': main()

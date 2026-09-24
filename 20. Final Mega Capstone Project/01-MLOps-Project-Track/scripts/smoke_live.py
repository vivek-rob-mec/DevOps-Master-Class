"""Start and verify real loopback HTTP servers one at a time; no cloud or Docker."""
import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid

ROOT=Path(__file__).resolve().parents[1]
PROJECTS=("01-demand-forecasting","02-payment-risk","03-predictive-maintenance","04-aiops-incident-triage")


def call(base,path,payload=None):
    request=urllib.request.Request(base+path,data=json.dumps(payload).encode() if payload is not None else None,
                                   headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(request,timeout=10) as response:
        return json.load(response)


def main():
    for folder in PROJECTS:
        with socket.socket() as sock:
            sock.bind(("127.0.0.1",0))
            port=sock.getsockname()[1]
        base=f"http://127.0.0.1:{port}"
        with tempfile.TemporaryFile(mode="w+") as log:
            process=subprocess.Popen([sys.executable,str(ROOT/folder/"run.py"),"serve","--port",str(port)],cwd=ROOT,stdout=log,stderr=log)
            try:
                deadline=time.monotonic()+45
                while True:
                    try:
                        assert call(base,"/readyz")["status"]=="ready"
                        break
                    except (OSError,AssertionError):
                        if process.poll() is not None or time.monotonic()>deadline:
                            raise RuntimeError("Server failed to become ready; run run_suite.py first")
                        time.sleep(.25)
                assert call(base,"/report")["release"]["eligible"]
                if folder.startswith("01"):
                    assert len(call(base,"/v1/forecasts/SKU-000")["forecasts"])==7
                elif folder.startswith("02"):
                    event={"event_id":"live-"+uuid.uuid4().hex,"entity_id":"live-entity","amount_minor":5000,"currency":"USD","event_time":time.time()}
                    first=call(base,"/v1/risk-decisions",event)
                    assert call(base,"/v1/risk-decisions",event)==first
                elif folder.startswith("03"):
                    equipment="live-"+uuid.uuid4().hex
                    for sequence in range(1,6):
                        result=call(base,"/v1/sensor-events",{"equipment":equipment,"sequence":sequence,"temperature":50,"vibration":3})
                    assert result["state"]=="predicted"
                else:
                    assert "incident_ids" in call(base,"/v1/analyze",{})
                    assert isinstance(call(base,"/v1/incidents"),list)
                print(f"PASS live HTTP: {folder}",flush=True)
            except Exception:
                log.seek(0)
                print(log.read(),file=sys.stderr)
                raise
            finally:
                process.terminate()
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


if __name__=="__main__":
    main()

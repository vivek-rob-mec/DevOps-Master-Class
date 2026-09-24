"""Run each project serially and save reproducible execution evidence."""
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[1]
PROJECTS=("01-demand-forecasting","02-payment-risk","03-predictive-maintenance","04-aiops-incident-triage")


def main():
    evidence=ROOT/"evidence"
    evidence.mkdir(exist_ok=True)
    summary={}
    for folder in PROJECTS:
        summary[folder]={}
        for command in ("demo","exercise"):
            start=time.perf_counter()
            result=subprocess.run([sys.executable,str(ROOT/folder/"run.py"),command],cwd=ROOT,capture_output=True,text=True)
            if result.returncode:
                print(result.stdout)
                print(result.stderr,file=sys.stderr)
                raise SystemExit(result.returncode)
            record=json.loads(result.stdout)
            (evidence/f"{folder}-{command}.json").write_text(json.dumps(record,indent=2)+"\n",encoding="utf-8")
            summary[folder][command]={"seconds":round(time.perf_counter()-start,3),"passed":True}
            print(f"PASS {folder}: {command}",flush=True)
    (evidence/"execution-summary.json").write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")


if __name__=="__main__":
    main()

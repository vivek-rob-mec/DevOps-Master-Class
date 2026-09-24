$ErrorActionPreference='Stop'
python -m unittest discover -s tests -v
if($LASTEXITCODE){throw 'Workflow model tests failed.'}
python scripts/replay.py history/fulfillment.json | Out-Null
if($LASTEXITCODE){throw 'History replay failed.'}
python -m py_compile workflow/*.py worker.py starter.py
docker compose config --quiet
kubectl kustomize k8s | Out-Null
Write-Host 'Temporal workflow contracts validated.'

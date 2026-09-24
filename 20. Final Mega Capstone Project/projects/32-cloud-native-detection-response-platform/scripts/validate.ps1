$ErrorActionPreference='Stop'
python -m unittest discover -s tests -v
if($LASTEXITCODE){throw 'Detection tests failed.'}
python scripts/hunt.py evidence/events.jsonl detections/rules.json | Out-Null
if($LASTEXITCODE){throw 'Detection replay failed.'}
docker compose config --quiet
kubectl kustomize k8s | Out-Null
Write-Host 'Detection and response contracts validated.'

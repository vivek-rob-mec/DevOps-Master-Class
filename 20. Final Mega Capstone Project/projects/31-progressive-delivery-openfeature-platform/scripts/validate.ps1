$ErrorActionPreference='Stop'
python -m unittest discover -s tests -v
if($LASTEXITCODE){throw 'Delivery tests failed.'}
python scripts/simulate.py | Out-Null
docker compose config --quiet
if($LASTEXITCODE){throw 'Compose validation failed.'}
kubectl kustomize k8s | Out-Null
Write-Host 'Progressive-delivery contracts validated.'

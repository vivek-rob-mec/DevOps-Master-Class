$ErrorActionPreference='Stop'
python -m unittest discover -s tests -v
if($LASTEXITCODE){throw 'Database guard tests failed.'}
docker compose config --quiet
if($LASTEXITCODE){throw 'Compose validation failed.'}
kubectl kustomize k8s | Out-Null
Write-Host 'Database platform contracts validated.'

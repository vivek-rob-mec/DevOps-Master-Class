$ErrorActionPreference='Stop'
python -m unittest discover -s tests -v
if($LASTEXITCODE){throw 'Mesh policy tests failed.'}
kubectl kustomize k8s | Out-Null
if($LASTEXITCODE){throw 'Kustomize rendering failed.'}
Write-Host 'Mesh contracts validated. Live mTLS and failover still require two disposable clusters.'

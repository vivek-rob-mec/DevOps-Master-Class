$ErrorActionPreference='Stop'
python -m unittest discover -s tests -v
if($LASTEXITCODE){throw 'FinOps tests failed.'}
python scripts/report.py data/opencost-allocations.json policies/budgets.json | Out-Null
if($LASTEXITCODE){throw 'FinOps report failed.'}
kubectl kustomize k8s | Out-Null
Write-Host 'FinOps contracts validated.'

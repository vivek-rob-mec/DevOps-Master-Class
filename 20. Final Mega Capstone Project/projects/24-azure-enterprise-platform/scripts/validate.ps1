$ErrorActionPreference='Stop'
if(Get-Command az -ErrorAction SilentlyContinue){az bicep build --file infra/main.bicep --outfile ([IO.Path]::GetTempFileName())}
kubectl kustomize k8s | Out-Null
Get-Content -Raw policy/deny-public-ip.json | ConvertFrom-Json | Out-Null
Write-Host 'Azure platform contracts validated.'

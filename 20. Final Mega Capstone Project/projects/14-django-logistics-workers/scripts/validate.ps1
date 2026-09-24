$ErrorActionPreference='Stop'
$required=@('README.md','docker-compose.yml','Jenkinsfile','.github/workflows/ci.yml','docs/HLD.md','docs/LLD.md','k8s/base/kustomization.yaml','helm/Chart.yaml','terraform/main.tf','ansible/deploy.yml','argocd/application.yaml')
foreach($file in $required){if(-not(Test-Path -LiteralPath $file)){throw "Missing $file"}}
if(Get-Command docker -ErrorAction SilentlyContinue){docker compose config --quiet;if($LASTEXITCODE){throw 'Compose validation failed'}}
if(Get-Command kubectl -ErrorAction SilentlyContinue){kubectl kustomize k8s/overlays/dev|Out-Null;if($LASTEXITCODE){throw 'Kustomize validation failed'}}
Write-Host 'Static validation passed.'

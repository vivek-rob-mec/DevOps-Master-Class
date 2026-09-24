$ErrorActionPreference='Stop'
$required=@('backstage/app-config.yaml','catalog/location.yaml','templates/service/template.yaml','crossplane/xrd.yaml','crossplane/composition.yaml','argocd/applicationset.yaml','kustomization.yaml','terraform/main.tf')
foreach($file in $required){if(-not(Test-Path -LiteralPath $file)){throw "Missing $file"}}
kubectl kustomize . | Out-Null
if(Get-Command terraform -ErrorAction SilentlyContinue){terraform -chdir=terraform fmt -check -recursive}
Write-Host 'Internal developer platform validation passed.'

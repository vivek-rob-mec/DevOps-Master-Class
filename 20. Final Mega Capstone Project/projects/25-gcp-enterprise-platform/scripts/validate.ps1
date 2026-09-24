$ErrorActionPreference='Stop'
foreach($directory in @('terraform/bootstrap','terraform/workload')){terraform -chdir=$directory fmt -check -recursive;if($LASTEXITCODE){throw "Terraform format failed: $directory"}}
kubectl kustomize k8s | Out-Null
Write-Host 'GCP platform contracts validated.'

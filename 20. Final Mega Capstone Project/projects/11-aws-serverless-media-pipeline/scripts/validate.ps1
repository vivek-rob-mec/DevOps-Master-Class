$ErrorActionPreference='Stop'
$required=@('README.md','template.yaml','functions/intake/app.py','functions/worker/app.py','tests/test_pipeline.py','terraform/main.tf','docs/HLD.md','docs/LLD.md','docs/RUNBOOK.md','docs/THREAT-MODEL.md')
foreach($file in $required){if(-not(Test-Path -LiteralPath $file)){throw "Missing $file"}}
python -m unittest discover -s tests -v
python -m py_compile functions/intake/app.py functions/worker/app.py
if(Get-Command sam -ErrorAction SilentlyContinue){sam validate --lint}
if(Get-Command terraform -ErrorAction SilentlyContinue){terraform -chdir=terraform fmt -check -recursive}
Write-Host 'Serverless project validation passed.'

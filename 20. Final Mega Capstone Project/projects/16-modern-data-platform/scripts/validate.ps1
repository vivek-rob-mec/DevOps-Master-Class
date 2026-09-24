$ErrorActionPreference='Stop'
$required=@('README.md','docker-compose.yml','dags/order_analytics.py','jobs/order_metrics.py','dbt/dbt_project.yml','contracts/order-event.schema.json','terraform/main.tf','k8s/base/kustomization.yaml')
foreach($file in $required){if(-not(Test-Path -LiteralPath $file)){throw "Missing $file"}}
python -m unittest discover -s tests -v
python -m py_compile platform_lib/*.py producers/*.py jobs/*.py dags/*.py
docker compose config --quiet
Write-Host 'Data platform validation passed.'

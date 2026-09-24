param([ValidateRange(0,10000)][int]$LatencyMs=500)
$ErrorActionPreference='Stop'
$body=@{type='latency';attributes=@{latency=$LatencyMs;jitter=50}}|ConvertTo-Json -Compress
Invoke-RestMethod -Method Post -Uri http://localhost:8474/proxies/postgres/toxics -ContentType application/json -Body $body
Write-Host "Injected ${LatencyMs}ms PostgreSQL latency. Remove with: Invoke-RestMethod -Method Delete http://localhost:8474/proxies/postgres/toxics/latency_downstream"

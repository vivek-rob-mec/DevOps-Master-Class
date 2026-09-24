param([switch]$WhatIfMode)
. (Join-Path $PSScriptRoot 'Common.ps1')
$project=@{
 Id='13-dotnet-insurance-monolith';Title='.NET Insurance Claims Modular Monolith';Type='Modular monolith';Backend='.NET 10 LTS / ASP.NET Core / PostgreSQL';Frontend='ASP.NET static web application';Domain='claims';Namespace='claims-dotnet';PublicPort=8092;Entry='app';Ui='app'
 Diagram=@'
flowchart LR
    Adjuster --> UI["Claims operations workspace"] --> API["ASP.NET Core endpoints"]
    API --> Intake["Claim intake module"]
    API --> Review["Review workflow module"]
    API --> Audit["Audit module"]
    Intake --> Rules["Domain rules"]
    Review --> Rules
    Audit --> Rules
    Rules --> PG[(PostgreSQL)]
    API --> Metrics["Health and metrics"]
'@
 Workloads=@(@{Name='app';Port=8080;Health='/health';Responsibility='Claims UI, intake/review/audit modules, HTTP API, and PostgreSQL adapter in one deployable unit'})
}
$root=New-CommonProject $project -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/Claims.csproj' @'
<Project Sdk="Microsoft.NET.Sdk.Web"><PropertyGroup><TargetFramework>net10.0</TargetFramework><Nullable>enable</Nullable><ImplicitUsings>enable</ImplicitUsings><TreatWarningsAsErrors>true</TreatWarningsAsErrors></PropertyGroup><ItemGroup><PackageReference Include="Npgsql" Version="10.0.3" /></ItemGroup></Project>
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/Domain.cs' @'
namespace Claims;public sealed record ClaimDraft(string? PolicyNumber,string? ClaimantEmail,decimal Amount,string? Description);public sealed record ValidClaim(string PolicyNumber,string ClaimantEmail,decimal Amount,string Description);public static class ClaimRules{public static ValidClaim Parse(ClaimDraft value){var policy=(value.PolicyNumber??"").Trim().ToUpperInvariant();var email=(value.ClaimantEmail??"").Trim().ToLowerInvariant();var description=(value.Description??"").Trim();if(!System.Text.RegularExpressions.Regex.IsMatch(policy,"^[A-Z0-9-]{6,32}$"))throw new ArgumentException("INVALID_POLICY");if(!email.Contains('@')||email.Length>254)throw new ArgumentException("INVALID_EMAIL");if(value.Amount<=0||value.Amount>10_000_000)throw new ArgumentException("INVALID_AMOUNT");if(description.Length<5||description.Length>1000)throw new ArgumentException("INVALID_DESCRIPTION");return new(policy,email,value.Amount,description);}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/Program.cs' @'
using Claims;using Npgsql;var builder=WebApplication.CreateBuilder(args);builder.Services.AddSingleton(_=>NpgsqlDataSource.Create(Environment.GetEnvironmentVariable("DATABASE_URL")??"Host=localhost;Database=app;Username=app;Password=local-development-only"));var app=builder.Build();var db=app.Services.GetRequiredService<NpgsqlDataSource>();await using(var command=db.CreateCommand("CREATE TABLE IF NOT EXISTS claims(id uuid PRIMARY KEY,policy_number varchar(32) NOT NULL,claimant_email varchar(254) NOT NULL,amount numeric(14,2) NOT NULL,description varchar(1000) NOT NULL,status varchar(24) NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),idempotency_key varchar(128) UNIQUE NOT NULL)")){await command.ExecuteNonQueryAsync();}app.UseDefaultFiles();app.UseStaticFiles();app.MapGet("/health",async()=>{await using var command=db.CreateCommand("SELECT 1");await command.ExecuteScalarAsync();return Results.Ok(new{status="ok",service="claims-app"});});app.MapGet("/metrics",()=>Results.Text("# HELP claims_up Service readiness\n# TYPE claims_up gauge\nclaims_up 1\n","text/plain; version=0.0.4"));app.MapGet("/api/claims",async()=>{var values=new List<object>();await using var command=db.CreateCommand("SELECT id,policy_number,claimant_email,amount,description,status,created_at FROM claims ORDER BY created_at DESC LIMIT 200");await using var reader=await command.ExecuteReaderAsync();while(await reader.ReadAsync())values.Add(new{id=reader.GetGuid(0),policyNumber=reader.GetString(1),claimantEmail=reader.GetString(2),amount=reader.GetDecimal(3),description=reader.GetString(4),status=reader.GetString(5),createdAt=reader.GetDateTime(6)});return Results.Ok(values);});app.MapPost("/api/claims",async(HttpRequest request,ClaimDraft draft)=>{var key=request.Headers["Idempotency-Key"].ToString();if(string.IsNullOrWhiteSpace(key)||key.Length>128)return Results.BadRequest(new{code="IDEMPOTENCY_KEY_REQUIRED"});ValidClaim value;try{value=ClaimRules.Parse(draft);}catch(ArgumentException error){return Results.UnprocessableEntity(new{code=error.Message});}var id=Guid.NewGuid();await using var command=db.CreateCommand("INSERT INTO claims(id,policy_number,claimant_email,amount,description,status,idempotency_key) VALUES($1,$2,$3,$4,$5,'submitted',$6) ON CONFLICT(idempotency_key) DO UPDATE SET idempotency_key=excluded.idempotency_key RETURNING id,policy_number,claimant_email,amount,description,status,created_at");command.Parameters.AddWithValue(id);command.Parameters.AddWithValue(value.PolicyNumber);command.Parameters.AddWithValue(value.ClaimantEmail);command.Parameters.AddWithValue(value.Amount);command.Parameters.AddWithValue(value.Description);command.Parameters.AddWithValue(key);await using var row=await command.ExecuteReaderAsync();await row.ReadAsync();return Results.Json(new{id=row.GetGuid(0),policyNumber=row.GetString(1),claimantEmail=row.GetString(2),amount=row.GetDecimal(3),description=row.GetString(4),status=row.GetString(5),createdAt=row.GetDateTime(6)},statusCode:201);});app.Run();
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/wwwroot/index.html' @'
<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Claimline</title><link rel="stylesheet" href="/style.css"></head><body><main><header><p>CLAIMLINE / .NET</p><h1>From incident<br>to accountable outcome.</h1><output id="message">Ready</output></header><form id="claim"><input name="policy" placeholder="POL-10001" required><input name="email" type="email" placeholder="claimant@example.com" required><input name="amount" type="number" min="1" value="1000"><input name="description" placeholder="Describe the incident" required><button>Submit claim</button></form><section id="claims"></section></main><script src="/app.js" defer></script></body></html>
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/wwwroot/app.js' @'
const list=document.querySelector("#claims"),form=document.querySelector("#claim"),message=document.querySelector("#message");async function load(){const r=await fetch("/api/claims");list.innerHTML=(await r.json()).map(x=>`<article><span>${x.status}</span><h2>${x.policyNumber}</h2><p>${x.description}</p><strong>${Number(x.amount).toLocaleString()}</strong></article>`).join("")}form.addEventListener("submit",async e=>{e.preventDefault();const f=new FormData(form),r=await fetch("/api/claims",{method:"POST",headers:{"content-type":"application/json","idempotency-key":crypto.randomUUID()},body:JSON.stringify({policyNumber:f.get("policy"),claimantEmail:f.get("email"),amount:Number(f.get("amount")),description:f.get("description")})});message.textContent=r.ok?"Claim submitted":JSON.stringify(await r.json());if(r.ok)await load()});load().catch(e=>message.textContent=e.message);
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/wwwroot/style.css' ':root{font-family:system-ui;color:#102a43;background:#eaf4f4}*{box-sizing:border-box}body{margin:0}main{max-width:1100px;margin:auto;padding:4rem 2rem}header p{letter-spacing:.2em;color:#007f5f;font-weight:bold}h1{font-size:clamp(3rem,8vw,6.5rem);line-height:.9}form{display:grid;grid-template-columns:1fr 1.5fr .7fr 2fr auto;gap:.4rem;padding:.7rem;background:#102a43}input,button{padding:.85rem;border:0}button{background:#80b918;font-weight:bold}section{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:1rem;margin-top:2rem}article{background:white;padding:1.2rem;border-left:5px solid #007f5f}article span{font-size:.7rem;text-transform:uppercase;color:#007f5f}@media(max-width:800px){form{grid-template-columns:1fr}}' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'tests/DomainTests.csproj' '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net10.0</TargetFramework><Nullable>enable</Nullable><ImplicitUsings>enable</ImplicitUsings></PropertyGroup><ItemGroup><ProjectReference Include="../app/Claims.csproj" /></ItemGroup></Project>' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'tests/Program.cs' @'
using Claims;var value=ClaimRules.Parse(new(" pol-10001 ","USER@EXAMPLE.COM",100,"Valid incident"));if(value.PolicyNumber!="POL-10001"||value.ClaimantEmail!="user@example.com")throw new Exception("normalization failed");try{ClaimRules.Parse(new("bad","u@example.com",100,"Valid incident"));throw new Exception("invalid policy accepted");}catch(ArgumentException error)when(error.Message=="INVALID_POLICY"){}Console.WriteLine("Domain tests passed.");
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'Dockerfile' @'
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY app/Claims.csproj app/
COPY tests/DomainTests.csproj tests/
RUN dotnet restore tests/DomainTests.csproj --locked-mode || dotnet restore tests/DomainTests.csproj
COPY app/ app/
COPY tests/ tests/
RUN dotnet run --project tests/DomainTests.csproj && dotnet publish app/Claims.csproj -c Release -o /out --no-restore
FROM mcr.microsoft.com/dotnet/aspnet:10.0
ENV ASPNETCORE_URLS=http://+:8080 DOTNET_EnableDiagnostics=0
WORKDIR /app
COPY --from=build --chown=10001:10001 /out ./
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["dotnet","Claims.dll"]
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'docker-compose.yml' @'
services:
  postgres:
    image: postgres:16-alpine
    environment: { POSTGRES_USER: "${POSTGRES_USER:-app}", POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-local-development-only}", POSTGRES_DB: "${POSTGRES_DB:-app}" }
    volumes: [postgres-data:/var/lib/postgresql/data]
    healthcheck: { test: ["CMD-SHELL","pg_isready -U ${POSTGRES_USER:-app} -d ${POSTGRES_DB:-app}"], interval: 5s, timeout: 3s, retries: 20 }
    networks: [data]
  app:
    image: ${REGISTRY:-local}/13-dotnet-insurance-monolith-app:${IMAGE_TAG:-dev}
    build: .
    environment: { DATABASE_URL: "Host=postgres;Port=5432;Database=${POSTGRES_DB:-app};Username=${POSTGRES_USER:-app};Password=${POSTGRES_PASSWORD:-local-development-only}" }
    ports: ["${PUBLIC_PORT:-8092}:8080"]
    depends_on: { postgres: { condition: service_healthy } }
    read_only: true
    tmpfs: [/tmp]
    security_opt: [no-new-privileges:true]
    networks: [edge,data]
networks: { edge: {}, data: { internal: true } }
volumes: { postgres-data: {} }
'@ -WhatIfMode:$WhatIfMode
$testScript = @'
#!/usr/bin/env sh
set -eu
docker run --rm -v "$PWD:/src" -w /src mcr.microsoft.com/dotnet/sdk:10.0 dotnet run --project tests/DomainTests.csproj
docker compose config --quiet
'@
Write-TemplateFile $root 'scripts/test.sh' $testScript -WhatIfMode:$WhatIfMode
[pscustomobject]@{Project=$project.Id;Root=$root;Files=$script:Generated.Count}

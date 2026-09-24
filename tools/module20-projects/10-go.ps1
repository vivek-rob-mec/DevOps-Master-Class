param([switch]$WhatIfMode)
. (Join-Path $PSScriptRoot 'Common.ps1')

$project=@{
 Id='10-go-url-shortener';Title='Go Cloud-Native URL Shortener';Type='Cloud-native service';Backend='Go 1.25 / net/http / pgx / PostgreSQL';Frontend='Embedded responsive web interface';Domain='shortener';Namespace='shortener-go';PublicPort=8090;Entry='app';Ui='app'
 Diagram=@'
flowchart LR
    User --> UI["Embedded web interface"] --> API["Go HTTP API"]
    API --> Domain["Link and redirect rules"]
    Domain --> PGX["pgx connection pool"] --> PG[(PostgreSQL)]
    Visitor --> Redirect["Bounded redirect handler"] --> PGX
    Redirect --> Target["Validated external URL"]
    API --> Metrics["Low-cardinality Prometheus metrics"]
'@
 Workloads=@(
  @{Name='app';Port=8080;Health='/health';Responsibility='Embedded UI, short-link API, redirect path, persistence, and operational telemetry'}
 )
}

$root=New-CommonProject $project -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'app/go.mod' @'
module example.com/devops-masterclass/shortener

go 1.25

require github.com/jackc/pgx/v5 v5.7.6

require (
	github.com/jackc/pgpassfile v1.0.0 // indirect
	github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761 // indirect
	github.com/jackc/puddle/v2 v2.2.2 // indirect
	golang.org/x/crypto v0.37.0 // indirect
	golang.org/x/sync v0.13.0 // indirect
	golang.org/x/text v0.24.0 // indirect
)
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/domain.go' @'
package main

import("crypto/sha256";"encoding/base64";"errors";"net/url";"strings")

func normalizeURL(raw string)(string,error){value:=strings.TrimSpace(raw);if len(value)<8||len(value)>2048{return"",errors.New("INVALID_URL")};parsed,err:=url.Parse(value);if err!=nil||parsed.Host==""||(parsed.Scheme!="http"&&parsed.Scheme!="https"){return"",errors.New("INVALID_URL")};parsed.Fragment="";return parsed.String(),nil}
func codeFor(key string)string{sum:=sha256.Sum256([]byte(key));return strings.TrimRight(base64.RawURLEncoding.EncodeToString(sum[:6]),"=")}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/main.go' @'
package main

import("context";"embed";"encoding/json";"errors";"fmt";"io/fs";"log/slog";"net/http";"os";"os/signal";"strings";"sync/atomic";"syscall";"time";"github.com/jackc/pgx/v5";"github.com/jackc/pgx/v5/pgxpool")

//go:embed web/*
var assets embed.FS
type application struct{db *pgxpool.Pool;requests atomic.Uint64;redirects atomic.Uint64}
type link struct{Code string `json:"code"`;URL string `json:"url"`;Hits int64 `json:"hits"`;CreatedAt time.Time `json:"createdAt"`}
type createLink struct{URL string `json:"url"`}

func main(){ctx:=context.Background();pool,err:=pgxpool.New(ctx,required("DATABASE_URL"));if err!=nil{panic(err)};defer pool.Close();if err=migrate(ctx,pool);err!=nil{panic(err)};a:=&application{db:pool};mux:=http.NewServeMux();mux.HandleFunc("GET /health",a.health);mux.HandleFunc("GET /metrics",a.metrics);mux.HandleFunc("GET /api/links",a.list);mux.HandleFunc("POST /api/links",a.create);mux.HandleFunc("GET /r/{code}",a.redirect);content,_:=fs.Sub(assets,"web");mux.Handle("/",http.FileServer(http.FS(content)));server:=&http.Server{Addr:":"+env("PORT","8080"),Handler:a.telemetry(mux),ReadHeaderTimeout:5*time.Second,ReadTimeout:10*time.Second,WriteTimeout:10*time.Second,IdleTimeout:60*time.Second,MaxHeaderBytes:1<<20};go func(){slog.Info("shortener started","address",server.Addr);if err:=server.ListenAndServe();err!=nil&&!errors.Is(err,http.ErrServerClosed){panic(err)}}();stop:=make(chan os.Signal,1);signal.Notify(stop,syscall.SIGINT,syscall.SIGTERM);<-stop;shutdown,cancel:=context.WithTimeout(context.Background(),25*time.Second);defer cancel();_ = server.Shutdown(shutdown)}
func migrate(ctx context.Context,db *pgxpool.Pool)error{_,err:=db.Exec(ctx,`CREATE TABLE IF NOT EXISTS links(code varchar(16) PRIMARY KEY,url varchar(2048) NOT NULL,hits bigint NOT NULL DEFAULT 0,created_at timestamptz NOT NULL DEFAULT now(),idempotency_key varchar(128) UNIQUE NOT NULL)`);return err}
func(a *application)telemetry(next http.Handler)http.Handler{return http.HandlerFunc(func(w http.ResponseWriter,r *http.Request){a.requests.Add(1);requestID:=r.Header.Get("X-Request-ID");if requestID==""{requestID=fmt.Sprintf("req-%d",time.Now().UnixNano())};w.Header().Set("X-Request-ID",requestID);started:=time.Now();next.ServeHTTP(w,r);slog.Info("request","requestId",requestID,"method",r.Method,"path",r.URL.Path,"durationMs",time.Since(started).Milliseconds())})}
func(a *application)health(w http.ResponseWriter,r *http.Request){ctx,cancel:=context.WithTimeout(r.Context(),2*time.Second);defer cancel();if err:=a.db.Ping(ctx);err!=nil{write(w,503,map[string]string{"status":"not_ready"});return};write(w,200,map[string]string{"status":"ok","service":"shortener-app"})}
func(a *application)metrics(w http.ResponseWriter,_ *http.Request){w.Header().Set("Content-Type","text/plain; version=0.0.4");fmt.Fprintf(w,"# HELP shortener_http_requests_total HTTP requests\n# TYPE shortener_http_requests_total counter\nshortener_http_requests_total %d\n# HELP shortener_redirects_total Successful redirects\n# TYPE shortener_redirects_total counter\nshortener_redirects_total %d\n",a.requests.Load(),a.redirects.Load())}
func(a *application)list(w http.ResponseWriter,r *http.Request){rows,err:=a.db.Query(r.Context(),`SELECT code,url,hits,created_at FROM links ORDER BY created_at DESC LIMIT 200`);if err!=nil{problem(w,500,"INTERNAL_ERROR");return};defer rows.Close();values:=[]link{};for rows.Next(){var value link;if rows.Scan(&value.Code,&value.URL,&value.Hits,&value.CreatedAt)==nil{values=append(values,value)}};write(w,200,values)}
func(a *application)create(w http.ResponseWriter,r *http.Request){key:=r.Header.Get("Idempotency-Key");if key==""||len(key)>128{problem(w,400,"IDEMPOTENCY_KEY_REQUIRED");return};var input createLink;if json.NewDecoder(http.MaxBytesReader(w,r.Body,64<<10)).Decode(&input)!=nil{problem(w,400,"INVALID_JSON");return};target,err:=normalizeURL(input.URL);if err!=nil{problem(w,422,err.Error());return};var value link;err=a.db.QueryRow(r.Context(),`SELECT code,url,hits,created_at FROM links WHERE idempotency_key=$1`,key).Scan(&value.Code,&value.URL,&value.Hits,&value.CreatedAt);if err==nil{write(w,200,value);return};if !errors.Is(err,pgx.ErrNoRows){problem(w,500,"INTERNAL_ERROR");return};code:=codeFor(key);err=a.db.QueryRow(r.Context(),`INSERT INTO links(code,url,idempotency_key) VALUES($1,$2,$3) ON CONFLICT(idempotency_key) DO UPDATE SET idempotency_key=excluded.idempotency_key RETURNING code,url,hits,created_at`,code,target,key).Scan(&value.Code,&value.URL,&value.Hits,&value.CreatedAt);if err!=nil{problem(w,500,"INTERNAL_ERROR");return};write(w,201,value)}
func(a *application)redirect(w http.ResponseWriter,r *http.Request){code:=strings.TrimSpace(r.PathValue("code"));if len(code)<4||len(code)>16{problem(w,404,"LINK_NOT_FOUND");return};var target string;err:=a.db.QueryRow(r.Context(),`UPDATE links SET hits=hits+1 WHERE code=$1 RETURNING url`,code).Scan(&target);if errors.Is(err,pgx.ErrNoRows){problem(w,404,"LINK_NOT_FOUND");return};if err!=nil{problem(w,500,"INTERNAL_ERROR");return};a.redirects.Add(1);http.Redirect(w,r,target,http.StatusTemporaryRedirect)}
func write(w http.ResponseWriter,status int,value any){w.Header().Set("Content-Type","application/json");w.WriteHeader(status);_ = json.NewEncoder(w).Encode(value)}
func problem(w http.ResponseWriter,status int,code string){write(w,status,map[string]string{"code":code})}
func env(key,fallback string)string{if value:=os.Getenv(key);value!=""{return value};return fallback}
func required(key string)string{value:=os.Getenv(key);if value==""{panic(key+" is required")};return value}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/domain_test.go' @'
package main
import"testing"
func TestNormalizeURL(t *testing.T){value,err:=normalizeURL(" https://example.com/docs#part ");if err!=nil||value!="https://example.com/docs"{t.Fatalf("unexpected result %q %v",value,err)}}
func TestRejectsUnsafeScheme(t *testing.T){if _,err:=normalizeURL("javascript:alert(1)");err==nil{t.Fatal("unsafe scheme accepted")}}
func TestCodeIsStable(t *testing.T){if codeFor("same-key")!=codeFor("same-key"){t.Fatal("code is not stable")}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/web/index.html' @'
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Linksmith</title><link rel="stylesheet" href="/style.css"></head><body><main><header><p>LINKSMITH / GO</p><h1>Short links.<br>Clear signals.</h1><output id="message">Ready</output></header><form id="link"><input name="url" type="url" placeholder="https://example.com/long/path" required><button>Forge link</button></form><section id="links"></section></main><script src="/app.js" defer></script></body></html>
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/web/app.js' @'
const list=document.querySelector("#links"),form=document.querySelector("#link"),message=document.querySelector("#message");async function load(){const response=await fetch("/api/links");if(!response.ok)throw Error("Unable to load links");list.innerHTML=(await response.json()).map(x=>`<article><a href="/r/${x.code}" target="_blank">/r/${x.code}</a><p>${x.url}</p><strong>${x.hits} redirects</strong></article>`).join("")}form.addEventListener("submit",async event=>{event.preventDefault();const data=new FormData(form),response=await fetch("/api/links",{method:"POST",headers:{"content-type":"application/json","idempotency-key":crypto.randomUUID()},body:JSON.stringify({url:data.get("url")})});message.textContent=response.ok?"Link forged":JSON.stringify(await response.json());if(response.ok){form.reset();await load()}});load().catch(error=>message.textContent=error.message);
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'app/web/style.css' @'
:root{font-family:ui-monospace,SFMono-Regular,Consolas;color:#d7f9ed;background:#061a16}*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 80% 10%,#164f41,#061a16 45%)}main{max-width:1000px;margin:auto;padding:5rem 2rem;min-height:100vh}header p{color:#5cf2c2;letter-spacing:.18em}h1{font-size:clamp(3rem,9vw,7rem);line-height:.86;letter-spacing:-.08em;margin:1rem 0}form{display:flex;margin:3rem 0;border:1px solid #5cf2c2;padding:.5rem}input{flex:1;min-width:0}input,button{padding:1rem;border:0;background:#d7f9ed;color:#061a16}button{background:#5cf2c2;font-weight:bold}section{display:grid;gap:.7rem}article{padding:1.1rem;border:1px solid #286c5a;background:#09251f}a{font-size:1.2rem;color:#5cf2c2}article p{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:#91bcb0}article strong{font-size:.75rem}@media(max-width:600px){form{display:grid}}
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'Dockerfile' @'
FROM golang:1.25-alpine AS build
WORKDIR /src
COPY app/go.mod ./
RUN go mod download
COPY app/ ./
RUN CGO_ENABLED=0 go test ./... && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/shortener .

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=build /out/shortener /app/shortener
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/app/shortener"]
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
    image: ${REGISTRY:-local}/10-go-url-shortener-app:${IMAGE_TAG:-dev}
    build: .
    environment: { PORT: 8080, DATABASE_URL: "postgresql://${POSTGRES_USER:-app}:${POSTGRES_PASSWORD:-local-development-only}@postgres:5432/${POSTGRES_DB:-app}" }
    ports: ["${PUBLIC_PORT:-8090}:8080"]
    depends_on: { postgres: { condition: service_healthy } }
    read_only: true
    tmpfs: [/tmp]
    security_opt: [no-new-privileges:true]
    networks: [edge,data]
networks: { edge: {}, data: { internal: true } }
volumes: { postgres-data: {} }
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'scripts/test.sh' @'
#!/usr/bin/env sh
set -eu
docker run --rm -v "$PWD/app:/src" -w /src golang:1.25-alpine sh -c 'go test ./...'
docker compose config --quiet
'@ -WhatIfMode:$WhatIfMode

[pscustomobject]@{Project=$project.Id;Root=$root;Files=$script:Generated.Count}

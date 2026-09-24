# Lesson 6.12 — Docker Performance and Resource Management Masterclass

# CPU, Memory, PIDs, Logs, Disk Usage, Build Cache, Node.js Tuning, Compose Limits, and Capacity Thinking

Today we move from “my container runs” to:

```text id="yqv7e6"
my container runs reliably
does not eat the whole server
does not fill disk
does not get OOMKilled
does not create unlimited processes
does not generate unlimited logs
has predictable resource behavior
```

Docker’s official resource-constraints docs say that, by default, a container has **no resource constraints** and can use as much CPU or memory as the host kernel scheduler allows, so Docker provides runtime flags to control container memory and CPU usage. ([Docker Documentation][1])

---

# 1. Beginner Level — Why Resource Limits Matter

Without limits, one bad container can affect the whole machine.

Example:

```text id="z7ogyn"
backend has memory leak
  ↓
uses more and more RAM
  ↓
host starts swapping or killing processes
  ↓
other containers slow down
  ↓
server becomes unstable
```

Or:

```text id="u8ws24"
container logs too much
  ↓
Docker JSON log file grows
  ↓
disk becomes full
  ↓
MongoDB cannot write
  ↓
deployment fails
```

Resource management protects:

```text id="t3fb6x"
host stability
neighbor containers
database reliability
deployment safety
debuggability
cost
```

Core rule:

```text id="xex3ft"
A production container should have resource expectations, not unlimited access.
```

---

# 2. Beginner Mental Model

A container is a process.

Like any process, it consumes:

```text id="ju7zdk"
CPU
memory
disk
network
file descriptors
process IDs
logs
```

Docker gives controls like:

```bash id="jquywx"
--memory=256m
--cpus=0.5
--pids-limit=100
```

Compose gives equivalent service configuration:

```yaml id="qyo0sv"
mem_limit: 256m
cpus: 0.5
pids_limit: 100
```

Docker Compose’s service reference documents `pids_limit` as a way to tune the container’s PID limit, with `-1` meaning unlimited. ([Docker Documentation][2])

---

# 3. Beginner Commands for Resource Visibility

Check running containers:

```bash id="v0gr6g"
docker ps
```

Check live resource usage:

```bash id="yjth63"
docker stats
```

One-time stats:

```bash id="l7cstq"
docker stats --no-stream
```

Check Docker disk usage:

```bash id="6b7iq1"
docker system df
```

Check host disk:

```bash id="s71ywv"
df -h
```

Check image sizes:

```bash id="v289ce"
docker images
```

Check container state:

```bash id="z4eos5"
docker inspect compose-demo-backend | jq '.[0].State'
```

---

# 4. CPU Limits — Beginner to Intermediate

Run container with half CPU:

```bash id="u0rs4z"
docker run -d \
  --name cpu-demo \
  --cpus=0.5 \
  alpine:3.20 \
  sh -c 'while true; do :; done'
```

Check:

```bash id="vh8j7x"
docker stats cpu-demo
```

Stop:

```bash id="xsmsqr"
docker rm -f cpu-demo
```

Meaning:

```text id="2h3o6f"
--cpus=0.5 means container can use roughly half of one CPU core.
```

Other examples:

```bash id="y52gde"
--cpus=1
--cpus=2
--cpus=0.25
```

Professional guidance:

```text id="qfpez5"
Use CPU limits to prevent noisy-neighbor behavior.
Do not set CPU too low without testing latency.
```

---

# 5. Memory Limits — Beginner to Intermediate

Run backend with memory limit:

```bash id="4j9o8t"
docker rm -f demo-node-api || true

docker run -d \
  --name demo-node-api \
  --memory=256m \
  --cpus=0.5 \
  -p 3000:3000 \
  -e APP_ENV=dev \
  demo-node-api:0.2.0
```

Check:

```bash id="p7lpjj"
docker stats demo-node-api
```

Inspect memory limit:

```bash id="d8xbzq"
docker inspect demo-node-api --format '{{.HostConfig.Memory}}'
```

Clean:

```bash id="kcbcv1"
docker rm -f demo-node-api
```

Important:

```text id="wfrgjj"
If a container exceeds its hard memory limit, it can be killed by the kernel.
```

When killed by memory pressure, you may see:

```text id="kpisv9"
ExitCode 137
OOMKilled true
```

Check:

```bash id="zm0z2s"
docker inspect <container> | jq '.[0].State | {Status, ExitCode, OOMKilled}'
```

---

# 6. Memory Reservation vs Memory Limit

Conceptually:

```text id="gm7z54"
reservation = expected/soft amount
limit       = hard maximum
```

In Compose deploy syntax:

```yaml id="zfmfgm"
deploy:
  resources:
    reservations:
      memory: 128M
    limits:
      memory: 256M
```

Docker’s Compose Deploy Specification defines resource `limits` as platform-enforced maximums and `reservations` as resources the platform should guarantee. This is most meaningful in orchestrated environments, and local Compose support can vary by Docker/Compose implementation. ([Docker Documentation][2])

For local Docker Compose, we have been using:

```yaml id="oh1drm"
mem_limit: 256m
cpus: 0.5
pids_limit: 100
```

Practical rule:

```text id="x4bq3t"
Set limits, then verify with docker inspect on the actual runtime.
```

---

# 7. PIDs Limit

A process can create child processes.

If a bug creates too many processes, it can exhaust host resources.

Run with PID limit:

```bash id="nsa7mt"
docker run --rm \
  --pids-limit=50 \
  alpine:3.20 \
  sh -c 'echo "PID limited container"; sleep 2'
```

Compose:

```yaml id="owovmy"
pids_limit: 100
```

Check:

```bash id="lv1ev5"
docker inspect compose-demo-backend --format '{{.HostConfig.PidsLimit}}'
```

Production rule:

```text id="9jv7sh"
Use pids_limit to reduce fork-bomb or runaway-process blast radius.
```

---

# 8. Update Compose Production Limits

Open:

```bash id="b0sjvk"
cd ~/devops-masterclass/06-docker-containers/compose-demo
nano compose.prod.yaml
```

Use this refined version:

```yaml id="yg1mx5"
services:
  backend:
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /tmp
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    pids_limit: 100
    mem_limit: 256m
    cpus: 0.5
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  nginx:
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /var/cache/nginx
      - /var/run
      - /tmp
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    pids_limit: 100
    mem_limit: 128m
    cpus: 0.25
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  mongo:
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    pids_limit: 300
    mem_limit: 512m
    cpus: 1.0
    logging:
      driver: json-file
      options:
        max-size: "20m"
        max-file: "5"
```

Deploy:

```bash id="ydgm8d"
COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
```

Verify:

```bash id="2dbbq8"
docker inspect compose-demo-backend --format 'Memory={{.HostConfig.Memory}}'
docker inspect compose-demo-backend --format 'NanoCPUs={{.HostConfig.NanoCpus}}'
docker inspect compose-demo-backend --format 'PidsLimit={{.HostConfig.PidsLimit}}'
docker inspect compose-demo-backend --format 'ReadOnly={{.HostConfig.ReadonlyRootfs}}'
```

---

# 9. Node.js Memory Tuning

Your backend is Node.js.

Node uses V8 memory, and V8 has heap settings.

Node’s official CLI docs describe `--max-old-space-size=SIZE` as setting the maximum size, in MiB, of V8’s old memory section; as memory approaches the limit, V8 spends more time on garbage collection. ([Node.js][3])

If container memory limit is:

```text id="9xiv67"
256 MB
```

Do not set Node heap to 256 MB exactly.

Leave memory for:

```text id="rpajaw"
Node runtime
native modules
stack
buffers
OS overhead
other process memory
```

Example:

```yaml id="02ytmt"
environment:
  NODE_OPTIONS: "--max-old-space-size=192"
mem_limit: 256m
```

For backend service in `compose.prod.yaml`, add:

```yaml id="dgv9cl"
    environment:
      NODE_OPTIONS: "--max-old-space-size=192"
```

But be careful: if `compose.yaml` or `backend.env` also sets environment, Compose merges maps but can override depending on structure. Verify rendered config:

```bash id="lsn0zi"
docker compose -f compose.yaml -f compose.prod.yaml config | grep -A30 "backend:"
```

Professional rule:

```text id="8p6gl8"
Container memory limit and Node heap limit should be aligned.
```

---

# 10. Create a Memory Stress Endpoint for Learning

Only for lab.

Go to app:

```bash id="7ceyem"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Open `server.js`:

```bash id="wjvcbl"
nano server.js
```

Add near other simulation endpoints:

```javascript id="z9onpe"
app.get("/simulate-memory", (req, res) => {
  const sizeMb = Math.min(Number(req.query.mb || 10), 100);
  const buffer = Buffer.alloc(sizeMb * 1024 * 1024, "x");

  logger.warn("memory_simulation_allocated", {
    request_id: req.requestId,
    size_mb: sizeMb,
  });

  res.json({
    status: "allocated",
    size_mb: sizeMb,
    note: "Buffer will be eligible for garbage collection after response.",
    sample: buffer.toString("utf8", 0, 10),
  });
});
```

Rebuild:

```bash id="pq1tny"
VERSION=0.2.2 ./scripts/docker-build.sh
```

Deploy:

```bash id="jpv2bj"
cd ~/devops-masterclass/06-docker-containers/compose-demo

APP_IMAGE=demo-node-api \
APP_VERSION=0.2.2 \
COMPOSE_FILES="compose.yaml compose.prod.yaml" \
./scripts/deploy-compose.sh
```

Test:

```bash id="qnuucn"
curl -s "http://127.0.0.1:8080/simulate-memory?mb=20" | jq .
docker stats --no-stream compose-demo-backend
```

This endpoint is for learning only.

Production warning:

```text id="306b38"
Do not expose artificial stress endpoints in real public production apps.
```

---

# 11. Logs and Disk Usage

Containers log to stdout/stderr.

Docker’s default `json-file` logging driver writes logs on disk.

Without rotation, logs can grow.

Compose logging limit:

```yaml id="2mgw1c"
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

Meaning:

```text id="tdgxlp"
each log file max 10 MB
keep 3 files
roughly 30 MB per container
```

Check log file path:

```bash id="j9dfht"
docker inspect compose-demo-backend --format '{{.LogPath}}'
```

Check size:

```bash id="6u4ngd"
sudo ls -lh "$(docker inspect compose-demo-backend --format '{{.LogPath}}')"
```

Professional rule:

```text id="qv1ihc"
Always configure log rotation on single Docker hosts.
```

---

# 12. Disk Usage: Images, Containers, Volumes, Build Cache

Check Docker disk:

```bash id="anzmey"
docker system df
```

Detailed:

```bash id="g75wl0"
docker system df -v
```

Clean stopped containers:

```bash id="r0wwro"
docker container prune
```

Clean dangling images:

```bash id="bjhhjr"
docker image prune
```

Clean build cache:

```bash id="2z34d0"
docker builder prune
```

Docker’s `docker builder prune` command removes build cache and supports filters such as `until=24h` and `--keep-storage` to control cleanup. ([Docker Documentation][4])

More controlled build-cache cleanup:

```bash id="c8x6if"
docker builder prune --filter "until=168h"
```

Dangerous:

```bash id="6mz7du"
docker system prune -a --volumes
```

Docker’s `docker system prune` removes unused containers, networks, images, and optionally volumes; using `--volumes` can remove persistent data if you are careless. ([Docker Documentation][5])

Production rule:

```text id="uut3c8"
Clean images/cache carefully. Treat volumes as data.
```

---

# 13. Build Cache Performance

Your Dockerfile uses BuildKit cache mount:

```Dockerfile id="dlswrq"
RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev && npm cache clean --force
```

This speeds repeated builds by caching npm downloads.

Check build time:

```bash id="mzmv2j"
time DOCKER_BUILDKIT=1 docker build -f Dockerfile.industry --target runtime -t demo-node-api:cache-test .
```

Build again:

```bash id="h5oobm"
time DOCKER_BUILDKIT=1 docker build -f Dockerfile.industry --target runtime -t demo-node-api:cache-test .
```

Second build should be faster if cache is reused.

Professional idea:

```text id="4u2grx"
CI builds benefit from remote cache, but local builds benefit from BuildKit cache mounts.
```

In advanced CI:

```text id="bmrqvh"
cache-to registry
cache-from registry
GitHub Actions cache
BuildKit remote cache
```

We will revisit in advanced CI/CD.

---

# 14. Image Size Performance

Large images cause:

```text id="6w8k3x"
slower pulls
slower deployments
more disk usage
larger attack surface
slower CI
```

Check size:

```bash id="h7to6s"
docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' | grep demo-node-api
```

History:

```bash id="bkrvvk"
docker history demo-node-api:0.2.2
```

Good practices:

```text id="wa528e"
use .dockerignore
copy only runtime files
multi-stage builds
production dependencies only
small base image when compatible
avoid build tools in runtime
```

Professional tradeoff:

```text id="3bvt22"
Smallest image is not always best.
Choose secure, supported, debuggable, compatible base images.
```

---

# 15. Network Performance Basics

For local Compose apps, bridge networking overhead is usually acceptable.

But performance issues can happen from:

```text id="tsklts"
too much logging
slow DNS lookups
wrong upstream timeout
large payloads
Nginx buffering
database latency
container resource limits too low
```

Nginx timeout tuning:

```nginx id="0483qu"
proxy_connect_timeout 5s;
proxy_send_timeout 30s;
proxy_read_timeout 30s;
```

For slow endpoints:

```bash id="rku4q2"
curl -w "\nTotal: %{time_total}s\n" -s "http://127.0.0.1:8080/slow?delay_ms=3000" >/dev/null
```

Test repeated requests:

```bash id="21octn"
for i in {1..10}; do
  curl -s -o /dev/null -w "%{http_code} %{time_total}\n" http://127.0.0.1:8080/health
done
```

Professional rule:

```text id="0k4l8v"
Performance debugging starts with measurement, not guesses.
```

---

# 16. File Descriptor and Process Awareness

Check host limits:

```bash id="f7c21n"
ulimit -n
```

Check processes inside container:

```bash id="yy2738"
docker compose exec backend ps
```

Check PID limit:

```bash id="d1jk7s"
docker inspect compose-demo-backend --format '{{.HostConfig.PidsLimit}}'
```

Advanced Compose can set ulimits:

```yaml id="6al07j"
ulimits:
  nofile:
    soft: 1024
    hard: 4096
```

Use carefully.

Corporate example:

```text id="6o58is"
Nginx handling many connections may need higher file descriptor limits than a small backend API.
```

---

# 17. Capacity Thinking — Professional Level

Resource limits should come from evidence.

Start with estimates:

```text id="rqloer"
backend: 256 MB, 0.5 CPU
nginx: 128 MB, 0.25 CPU
mongo: 512 MB, 1 CPU
```

Then measure:

```bash id="iesifj"
docker stats --no-stream
```

Collect over time:

```bash id="jtn36d"
while true; do
  date
  docker stats --no-stream compose-demo-backend compose-demo-nginx compose-demo-mongo
  sleep 10
done
```

Look for:

```text id="4vrafw"
CPU percent during normal traffic
memory steady state
memory growth over time
restart count
OOMKilled
latency under load
disk growth
log growth
```

Professional rule:

```text id="7r8138"
Do not copy random resource limits from the internet. Benchmark your app.
```

---

# 18. Simple Load Test with ApacheBench or BusyBox

Install ApacheBench on host:

```bash id="8marp7"
sudo apt update
sudo apt install -y apache2-utils
```

Run:

```bash id="85tb8q"
ab -n 1000 -c 20 http://127.0.0.1:8080/health
```

Watch stats:

```bash id="9cr2gr"
docker stats
```

Alternative using `hey` if installed:

```bash id="l8b9xv"
hey -n 1000 -c 20 http://127.0.0.1:8080/health
```

Measure latency with curl loop:

```bash id="uzm0kk"
for i in {1..20}; do
  curl -s -o /dev/null -w "%{time_total}\n" http://127.0.0.1:8080/health
done
```

Interpret carefully:

```text id="qk0v8e"
local laptop benchmarks are not production benchmarks
but they reveal obvious limits and regressions
```

---

# 19. Expert Level — CPU Limit Tradeoffs

CPU limits prevent noisy-neighbor problems.

But too-low CPU can cause:

```text id="byxvu7"
higher latency
slow startup
slow garbage collection
timeouts
healthcheck failures during load
```

Example:

```yaml id="29lrdw"
cpus: 0.1
```

may make a Node app sluggish under concurrent traffic.

Professional approach:

```text id="f72kob"
set conservative limits
load test
watch latency and errors
adjust limits
monitor over time
```

In Kubernetes later, we will distinguish:

```text id="5ed2wb"
requests = scheduling guarantee
limits   = hard cap
```

Compose on one host is simpler but the thinking is similar.

---

# 20. Expert Level — Memory Limit Tradeoffs

Memory too high:

```text id="380yh6"
one container can starve host
higher cost
less density
```

Memory too low:

```text id="m73vo3"
OOMKilled
GC pressure
higher latency
crashes under load
```

Node memory rule of thumb:

```text id="409cyw"
container memory limit > Node heap limit + runtime overhead
```

Example:

```text id="td6u1b"
container limit: 256 MB
Node old space: 192 MB
remaining: runtime/native/buffers/overhead
```

Not universal. Measure.

---

# 21. Expert Level — Database Resource Limits

Be careful limiting databases too aggressively.

MongoDB needs memory for:

```text id="i7gw3n"
working set
indexes
cache
connections
writes
background tasks
```

For learning:

```yaml id="zjfxzl"
mongo:
  mem_limit: 512m
```

For production:

```text id="y39x29"
prefer managed DB
or size VM/container based on actual workload
monitor disk I/O, memory, cache, connections, replication lag
```

Corporate rule:

```text id="m0cvnn"
Application containers are easy to constrain. Databases need capacity planning.
```

---

# 22. Add Resource Report Script

Create:

```bash id="q5qxd9"
cd ~/devops-masterclass/06-docker-containers/compose-demo
nano scripts/resource-report.sh
```

Paste:

```bash id="1vvi88"
#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-resource-reports}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/resource-report-$TIMESTAMP.txt"

mkdir -p "$REPORT_DIR"

{
  echo "===== Docker Resource Report ====="
  echo "Time: $(date -Iseconds)"
  echo

  echo "===== Host Disk ====="
  df -h
  echo

  echo "===== Docker System DF ====="
  docker system df
  echo

  echo "===== Docker Stats ====="
  docker stats --no-stream || true
  echo

  echo "===== Compose Services ====="
  docker compose -f compose.yaml -f compose.prod.yaml ps || true
  echo

  echo "===== Backend Limits ====="
  docker inspect compose-demo-backend \
    --format 'Memory={{.HostConfig.Memory}} NanoCPUs={{.HostConfig.NanoCpus}} PidsLimit={{.HostConfig.PidsLimit}} ReadOnly={{.HostConfig.ReadonlyRootfs}}' \
    2>/dev/null || true
  echo

  echo "===== Nginx Limits ====="
  docker inspect compose-demo-nginx \
    --format 'Memory={{.HostConfig.Memory}} NanoCPUs={{.HostConfig.NanoCpus}} PidsLimit={{.HostConfig.PidsLimit}} ReadOnly={{.HostConfig.ReadonlyRootfs}}' \
    2>/dev/null || true
  echo

  echo "===== Mongo Limits ====="
  docker inspect compose-demo-mongo \
    --format 'Memory={{.HostConfig.Memory}} NanoCPUs={{.HostConfig.NanoCpus}} PidsLimit={{.HostConfig.PidsLimit}}' \
    2>/dev/null || true
  echo

  echo "===== Container Log Paths ====="
  for c in compose-demo-backend compose-demo-nginx compose-demo-mongo; do
    log_path="$(docker inspect "$c" --format '{{.LogPath}}' 2>/dev/null || true)"
    if [ -n "$log_path" ]; then
      echo "$c -> $log_path"
      sudo ls -lh "$log_path" 2>/dev/null || true
    fi
  done
} | tee "$REPORT_FILE"

echo
echo "Report saved: $REPORT_FILE"
```

Make executable:

```bash id="a4divn"
chmod +x scripts/resource-report.sh
```

Run:

```bash id="7ajqtr"
./scripts/resource-report.sh
```

---

# 23. Add Load Test Script

Create:

```bash id="fbfkbg"
nano scripts/simple-load-test.sh
```

Paste:

```bash id="r2w87d"
#!/usr/bin/env bash
set -euo pipefail

URL="${URL:-http://127.0.0.1:8080/health}"
REQUESTS="${REQUESTS:-100}"
CONCURRENCY="${CONCURRENCY:-10}"

echo "===== Simple Load Test ====="
echo "URL: $URL"
echo "Requests: $REQUESTS"
echo "Concurrency: $CONCURRENCY"

if command -v ab >/dev/null 2>&1; then
  ab -n "$REQUESTS" -c "$CONCURRENCY" "$URL"
else
  echo "ab not installed. Running curl loop instead."
  for i in $(seq 1 "$REQUESTS"); do
    curl -s -o /dev/null -w "%{http_code} %{time_total}\n" "$URL"
  done
fi

echo
echo "Container stats after test:"
docker stats --no-stream compose-demo-backend compose-demo-nginx compose-demo-mongo || true
```

Make executable:

```bash id="jcb6tc"
chmod +x scripts/simple-load-test.sh
```

Run:

```bash id="nfl4ib"
REQUESTS=500 CONCURRENCY=20 ./scripts/simple-load-test.sh
```

---

# 24. Add Performance Notes

Create:

```bash id="ayz8zf"
cd ~/devops-masterclass/06-docker-containers
nano docker-performance-resource-management.md
```

Paste:

````markdown id="6rbct7"
# Docker Performance and Resource Management

## Key Resources

- CPU
- memory
- PIDs
- disk
- logs
- build cache
- image size
- network latency

## Docker Run Limits

```bash
docker run --memory=256m --cpus=0.5 --pids-limit=100 image
````

## Compose Limits

```yaml
services:
  backend:
    mem_limit: 256m
    cpus: 0.5
    pids_limit: 100
```

## Node.js Memory

For Node.js containers:

```yaml
environment:
  NODE_OPTIONS: "--max-old-space-size=192"
mem_limit: 256m
```

Container memory must be higher than Node heap because Node also needs runtime/native/buffer overhead.

## Logs

Use log rotation:

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

## Disk Commands

```bash
df -h
docker system df
docker system df -v
docker builder prune
docker image prune
```

## Production Rules

* Set resource limits.
* Verify limits with `docker inspect`.
* Align Node heap with container memory.
* Configure log rotation.
* Monitor disk usage.
* Clean build cache carefully.
* Avoid deleting volumes accidentally.
* Benchmark before finalizing limits.
* Keep images small but debuggable.

````

---

# 25. Update Makefile

Open:

```bash id="i8cx0z"
cd ~/devops-masterclass/06-docker-containers/compose-demo
nano Makefile
````

Add:

```Makefile id="6meey5"
.PHONY: resource-report load-test system-df

resource-report:
	./scripts/resource-report.sh

load-test:
	./scripts/simple-load-test.sh

system-df:
	docker system df
	docker system df -v
```

Run:

```bash id="fj4s84"
make resource-report
make load-test
make system-df
```

---

# 26. Production Capacity Checklist

For each service, document:

```text id="243z32"
normal CPU usage
peak CPU usage
normal memory usage
peak memory usage
startup time
healthcheck timeout
log volume per day
disk usage
expected connections
backup size
restore time
```

For your current stack:

```text id="viwxw7"
backend:
  CPU: 0.5
  memory: 256 MB
  Node heap: 192 MB
  pids: 100

nginx:
  CPU: 0.25
  memory: 128 MB
  pids: 100

mongo:
  CPU: 1.0
  memory: 512 MB
  pids: 300
```

This is fine for lab, not a universal production setting.

Professional rule:

```text id="bggp9w"
Resource values are assumptions until measured under realistic load.
```

---

# 27. Troubleshooting Resource Problems

## Container is OOMKilled

```bash id="0fks8f"
docker inspect container | jq '.[0].State | {ExitCode, OOMKilled}'
docker stats --no-stream
```

Fix:

```text id="baj83w"
increase memory limit
reduce app memory usage
tune Node heap
investigate memory leak
reduce concurrency
```

---

## Container CPU is always high

```bash id="m0kwg1"
docker stats
docker logs container --tail 100
```

Possible causes:

```text id="2edpdn"
busy loop
high traffic
bad healthcheck frequency
expensive endpoint
too-low CPU limit
dependency timeout loop
```

---

## Disk is full

```bash id="zt5qx5"
df -h
docker system df
docker system df -v
```

Fix carefully:

```bash id="qk5bgs"
docker image prune
docker builder prune --filter "until=168h"
docker container prune
```

Avoid:

```bash id="xgx44z"
docker system prune -a --volumes
```

unless you are intentionally deleting data.

---

## Logs are too large

```bash id="wp3mtc"
docker inspect container --format '{{.LogPath}}'
sudo ls -lh "$(docker inspect container --format '{{.LogPath}}')"
```

Fix:

```yaml id="ywv3o4"
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

---

## Build cache is too large

```bash id="74twcb"
docker system df
docker builder prune --filter "until=168h"
```

Professional note:

```text id="gjo44q"
Build cache improves build speed, but needs cleanup policy on CI runners.
```

---

# 28. Final Validation

Deploy stack:

```bash id="w8f9kw"
cd ~/devops-masterclass/06-docker-containers/compose-demo

COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
```

Check limits:

```bash id="u1w94r"
docker inspect compose-demo-backend --format 'Memory={{.HostConfig.Memory}} CPU={{.HostConfig.NanoCpus}} PIDs={{.HostConfig.PidsLimit}}'
docker inspect compose-demo-nginx --format 'Memory={{.HostConfig.Memory}} CPU={{.HostConfig.NanoCpus}} PIDs={{.HostConfig.PidsLimit}}'
docker inspect compose-demo-mongo --format 'Memory={{.HostConfig.Memory}} CPU={{.HostConfig.NanoCpus}} PIDs={{.HostConfig.PidsLimit}}'
```

Run resource report:

```bash id="n66yb5"
./scripts/resource-report.sh
```

Run load test:

```bash id="lm1h3d"
REQUESTS=500 CONCURRENCY=20 ./scripts/simple-load-test.sh
```

Check app:

```bash id="7z4rih"
curl -s http://127.0.0.1:8080/health | jq .
curl -s http://127.0.0.1:8080/ready | jq .
curl -s http://127.0.0.1:8080/version | jq .
```

---

# 29. Commit Work

Run:

```bash id="qn3k2y"
cd ~/devops-masterclass

git status
git add 05-application-runtime/demo-node-api/server.js \
        06-docker-containers

git commit -m "feat: add Docker performance and resource management patterns"
git push
```

---

# 30. Interview Explanation

## Why set resource limits on containers?

Strong answer:

```text id="a3n52f"
Resource limits prevent one container from consuming the entire host and affecting other services. They improve stability, predictability, and capacity planning. I usually set memory, CPU, PID, and log limits, then verify them with docker inspect and tune them using load testing and monitoring data.
```

## What happens when a container exceeds its memory limit?

Strong answer:

```text id="n1muqv"
If a container exceeds its hard memory limit, it can be killed by the kernel. In Docker, I check docker inspect for OOMKilled true and often see exit code 137. Then I investigate whether the limit is too low, the application has a memory leak, or runtime settings like Node.js heap size need adjustment.
```

## How do you tune Node.js memory in Docker?

Strong answer:

```text id="91p1h7"
I align the Node.js V8 heap with the container memory limit using NODE_OPTIONS such as --max-old-space-size. I leave headroom for runtime overhead, buffers, native modules, and OS memory. For example, with a 256 MB container limit, I might set old space around 192 MB and then validate under load.
```

## How do you prevent Docker logs from filling disk?

Strong answer:

```text id="9sl0sb"
I configure the Docker logging driver options, usually json-file with max-size and max-file, such as 10m and 3 files. I also monitor disk usage with df -h and docker system df, and avoid writing large logs inside containers.
```

## How do you clean Docker disk safely?

Strong answer:

```text id="g81xaa"
I first inspect disk usage with docker system df and docker system df -v. Then I clean targeted resources such as stopped containers, dangling images, or build cache. I avoid docker system prune -a --volumes on production because it can remove images needed for rollback and volumes containing persistent data.
```

---

# Today’s Core Rules

```text id="kbq50k"
Containers need resource expectations.
Default containers can use unlimited host resources.
Set memory, CPU, PID, and log limits.
Verify limits with docker inspect.
Use docker stats for live usage.
Use docker system df for disk usage.
Align Node heap with container memory.
Configure log rotation.
Do not prune volumes casually.
Build cache improves speed but needs cleanup.
Image size affects deploy speed and disk usage.
Benchmark before finalizing production limits.
Resource values must be measured, not guessed.
```

Next lesson:

# Lesson 6.13 — Docker Production Capstone: secure image, Compose stack, registry workflow, CI/CD, health validation, rollback, backups, troubleshooting, and final Module 6 portfolio project.

[1]: https://docs.docker.com/engine/containers/resource_constraints/?utm_source=chatgpt.com "Resource constraints"
[2]: https://docs.docker.com/reference/compose-file/services/?utm_source=chatgpt.com "Define services in Docker Compose"
[3]: https://nodejs.org/api/cli.html?utm_source=chatgpt.com "Command-line API | Node.js v26.0.0 Documentation"
[4]: https://docs.docker.com/reference/cli/docker/builder/prune/?utm_source=chatgpt.com "docker builder prune"
[5]: https://docs.docker.com/reference/cli/docker/system/prune/?utm_source=chatgpt.com "docker system prune"

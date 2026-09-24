# Lesson 6.13 — Docker Production Capstone

# Secure Image + Compose Stack + Registry Workflow + CI/CD + Rollback + Backups + Troubleshooting

This is the final capstone for **Module 6 — Docker and Container Fundamentals**.

In this capstone, we will combine everything:

```text id="mgqf4j"
Dockerfile
.dockerignore
image layers
multi-stage builds
non-root user
healthcheck
Docker networking
Docker Compose
volumes
secrets
resource limits
security hardening
image scanning
registry tagging
CI/CD workflow
health validation
rollback
backup/restore
troubleshooting
deployment reports
```

By the end, you will have a production-style Docker project that you can explain in interviews and show as portfolio work.

---

# 1. Capstone Architecture

Final architecture:

```text id="q78jue"
User / Browser / curl
        |
        v
+-------------------+
| Nginx Container   |
| Public: 8080:80   |
+---------+---------+
          |
          | public_net
          v
+-------------------+
| Backend Container |
| demo-node-api     |
| Internal :3000    |
+---------+---------+
          |
          | private_net
          v
+-------------------+
| MongoDB Container |
| Internal :27017   |
| Named Volume      |
+-------------------+
```

Deployment flow:

```text id="z1lss7"
code
  ↓
test
  ↓
build Docker image
  ↓
scan image
  ↓
tag image
  ↓
push/pull registry image
  ↓
deploy with Compose
  ↓
validate /ready
  ↓
rollback if failed
  ↓
write deployment report
```

---

# 2. Capstone Goal

Your final Docker capstone should prove that you can:

```text id="gffdy8"
build a production-ready image
run containers securely
use Compose for multi-container stacks
separate public/private networks
persist database data
use secrets safely
set resource limits
scan images
deploy immutable image tags
validate health/readiness
rollback failed deployments
backup persistent data
troubleshoot incidents
document everything
```

This is no longer beginner Docker.

This is **real DevOps runtime packaging**.

---

# 3. Create Capstone Directory

Run:

```bash id="c2pwma"
cd ~/devops-masterclass/06-docker-containers

mkdir -p docker-production-capstone/{docs,scripts,reports,examples}
```

Expected:

```text id="5r7ayc"
06-docker-containers/
└── docker-production-capstone/
    ├── docs/
    ├── scripts/
    ├── reports/
    └── examples/
```

---

# 4. Capstone Checklist

Create:

```bash id="q2o18e"
cd ~/devops-masterclass/06-docker-containers/docker-production-capstone
nano docs/capstone-checklist.md
```

Paste:

```markdown id="l9xh5y"
# Docker Production Capstone Checklist

## Image

- [ ] Uses production Dockerfile
- [ ] Uses multi-stage build
- [ ] Uses `.dockerignore`
- [ ] Uses `npm ci`
- [ ] Runs as non-root
- [ ] Copies only runtime files
- [ ] Has OCI labels
- [ ] Has healthcheck
- [ ] Does not contain `.env`
- [ ] Does not contain secrets
- [ ] Uses immutable tags

## Compose Stack

- [ ] Nginx is public entrypoint
- [ ] Backend is internal
- [ ] MongoDB is internal
- [ ] Uses public and private networks
- [ ] Uses named volume for MongoDB
- [ ] Uses Compose secrets
- [ ] Uses healthchecks
- [ ] Uses restart policies
- [ ] Uses resource limits
- [ ] Uses log rotation
- [ ] Uses read-only filesystem where possible
- [ ] Drops Linux capabilities where possible

## CI/CD

- [ ] Runs tests
- [ ] Builds image
- [ ] Scans image
- [ ] Tags image with version and commit SHA
- [ ] Pushes/pulls registry image
- [ ] Deploys with Compose
- [ ] Validates `/ready`
- [ ] Rolls back on failed health
- [ ] Writes deployment report

## Operations

- [ ] Backup script exists
- [ ] Restore script exists
- [ ] Diagnostics script exists
- [ ] Resource report script exists
- [ ] Troubleshooting playbook exists
- [ ] Runbook exists
```

---

# 5. Final Production Dockerfile Verification

Your production Dockerfile should already exist here:

```bash id="apkpvr"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
ls -l Dockerfile.industry
```

It should include these patterns:

```text id="cff64u"
multi-stage build
npm ci
BuildKit cache mount
production dependencies
non-root USER node
HEALTHCHECK
OCI labels
safe ENV defaults
copy only runtime files
```

Quick verification:

```bash id="py4p9a"
grep -n 'FROM\|npm ci\|USER node\|HEALTHCHECK\|LABEL\|COPY --from' Dockerfile.industry
```

Build final capstone image:

```bash id="pqiw67"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION=0.3.0 ./scripts/docker-build.sh
```

Check:

```bash id="c9z9ux"
docker images | grep demo-node-api
docker run --rm --entrypoint whoami demo-node-api:0.3.0
```

Expected:

```text id="rjndov"
node
```

---

# 6. Run Local Docker CI

Run your local CI flow:

```bash id="rq07n8"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION=0.3.0 ./scripts/local-docker-ci.sh
```

This validates:

```text id="ekckvw"
npm test
Docker build
non-root user
container smoke test
/health endpoint
/version endpoint
```

---

# 7. Run Image Security Scan

Run:

```bash id="nw7ysv"
VERSION=0.3.0 ./scripts/docker-security-scan.sh
```

If scanner tools are missing, your script will still show alternatives.

Security gate idea:

```text id="mk1xdk"
High/Critical vulnerabilities should be reviewed before deployment.
```

In a real company, the decision is based on:

```text id="j91oua"
severity
exploitability
whether a fix exists
whether vulnerable package is reachable
whether service is internet-facing
business risk
```

---

# 8. Final Compose Stack Verification

Go to Compose project:

```bash id="s3771d"
cd ~/devops-masterclass/06-docker-containers/compose-demo
```

Your final Compose files should be:

```text id="o48k7k"
compose.yaml
compose.override.yaml
compose.prod.yaml
.env.example
backend.env.example
nginx/default.conf
secrets/*.example.txt
scripts/deploy-compose.sh
scripts/rollback-compose.sh
scripts/backup-mongo-volume.sh
scripts/restore-mongo-volume.sh
scripts/compose-security-check.sh
scripts/diagnose-compose.sh
scripts/resource-report.sh
scripts/simple-load-test.sh
```

Check:

```bash id="u1ouok"
ls -la
ls -la scripts
ls -la nginx
ls -la secrets
```

---

# 9. Set Capstone Image Version

Update `.env`:

```bash id="aut0ea"
nano .env
```

Use:

```bash id="6xcmta"
APP_IMAGE=demo-node-api
APP_VERSION=0.3.0
HOST_HTTP_PORT=8080
APP_ENV=prod
LOG_LEVEL=info
```

Update `backend.env`:

```bash id="hwfl7w"
nano backend.env
```

Use:

```bash id="hfnauq"
APP_ENV=prod
PORT=3000
LOG_LEVEL=info
LOAD_DOTENV=false
APP_NAME=demo-node-api
APP_VERSION=0.3.0
COMMIT_SHA=docker-capstone
DATABASE_URL_FILE=/run/secrets/backend_database_url
CORS_ORIGIN=http://localhost:8080
ENABLE_CACHE=false
REQUEST_TIMEOUT_MS=5000
STARTUP_DELAY_MS=0
NODE_OPTIONS=--max-old-space-size=192
```

Do not commit real `.env` or `backend.env`.

---

# 10. Validate Compose Security

Run:

```bash id="ztrf9a"
COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/compose-security-check.sh
```

This checks for:

```text id="f5uac8"
privileged containers
Docker socket mounts
latest tags
published MongoDB ports
```

Good production defaults:

```text id="q4ulru"
no privileged containers
no docker.sock mount
no latest tag
MongoDB not published to host
```

---

# 11. Deploy Capstone Stack

Run:

```bash id="cfqv9s"
COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
```

Validate:

```bash id="f5hisy"
docker compose -f compose.yaml -f compose.prod.yaml ps

curl -s http://127.0.0.1:8080/health | jq .
curl -s http://127.0.0.1:8080/ready | jq .
curl -s http://127.0.0.1:8080/version | jq .
curl -s http://127.0.0.1:8080/config-summary | jq .
```

Expected:

```text id="j8fsdg"
health ok
ready ok
version 0.3.0
config summary does not expose secrets
```

---

# 12. Validate Security Hardening

Run:

```bash id="utebcv"
docker inspect compose-demo-backend --format 'ReadOnly={{.HostConfig.ReadonlyRootfs}}'
docker inspect compose-demo-backend --format 'CapDrop={{json .HostConfig.CapDrop}}'
docker inspect compose-demo-backend --format 'SecurityOpt={{json .HostConfig.SecurityOpt}}'
docker inspect compose-demo-backend --format 'Memory={{.HostConfig.Memory}}'
docker inspect compose-demo-backend --format 'PidsLimit={{.HostConfig.PidsLimit}}'
```

Expected:

```text id="f6yh27"
ReadOnly=true
CapDrop includes ALL
SecurityOpt includes no-new-privileges:true
Memory is non-zero
PidsLimit is non-zero
```

Check backend user:

```bash id="tdqhcv"
docker compose -f compose.yaml -f compose.prod.yaml exec backend whoami
```

Expected:

```text id="igyfci"
node
```

---

# 13. Validate Networks

Run:

```bash id="qxukl2"
docker network inspect compose-demo_public_net | jq '.[0].Containers'
docker network inspect compose-demo_private_net | jq '.[0].Containers'
```

Expected:

```text id="0z9mzr"
public_net:
  nginx
  backend

private_net:
  backend
  mongo
```

MongoDB should not be on the public network.

Check published ports:

```bash id="q10yuq"
docker compose -f compose.yaml -f compose.prod.yaml ps
```

Expected:

```text id="6b8i4j"
nginx has 8080:80
backend has no host port
mongo has no host port
```

---

# 14. Validate Volume Persistence

Insert MongoDB test record:

```bash id="rb3cqq"
docker compose -f compose.yaml -f compose.prod.yaml exec mongo \
  mongosh -u root -p "$(cat secrets/mongodb_root_password.txt)" --authenticationDatabase admin \
  --eval 'use demo; db.capstone.insertOne({lesson:"docker-production-capstone", createdAt:new Date()}); db.capstone.find();'
```

Restart stack:

```bash id="uyxwer"
docker compose -f compose.yaml -f compose.prod.yaml down
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

Check record again:

```bash id="b3gip8"
docker compose -f compose.yaml -f compose.prod.yaml exec mongo \
  mongosh -u root -p "$(cat secrets/mongodb_root_password.txt)" --authenticationDatabase admin \
  --eval 'use demo; db.capstone.find();'
```

If record remains, volume persistence works.

Do not run:

```bash id="b4tww5"
docker compose down -v
```

unless you intentionally want to delete the database volume.

---

# 15. Run Backup

Run:

```bash id="nt7fqv"
./scripts/backup-mongo-volume.sh
```

Check:

```bash id="v29cl0"
ls -lh backups
```

You should see a `.tar.gz` backup file.

Production principle:

```text id="jg5jg9"
Persistence is not backup.
A volume keeps data alive.
A backup gives you recovery.
```

---

# 16. Run Resource Report

Run:

```bash id="eybb28"
./scripts/resource-report.sh
```

Check generated report:

```bash id="vdcr9z"
ls -lh resource-reports
```

This report captures:

```text id="nnhq5w"
host disk
Docker disk usage
container stats
resource limits
log paths
Compose service status
```

This is useful during incidents.

---

# 17. Run Diagnostics

Run:

```bash id="tbx6je"
./scripts/diagnose-compose.sh
```

This checks:

```text id="bl7ag1"
Docker version
Docker disk usage
host disk
rendered Compose config
service status
public endpoints
backend health
logs
networks
volumes
deployment report
```

This is your operational debugging tool.

---

# 18. Run Load Test

Run:

```bash id="yn7atw"
REQUESTS=500 CONCURRENCY=20 ./scripts/simple-load-test.sh
```

Then:

```bash id="xbt3w7"
docker stats --no-stream compose-demo-backend compose-demo-nginx compose-demo-mongo
```

This is not a full production benchmark, but it verifies that your stack handles basic traffic.

---

# 19. Rollback Test

A capstone is incomplete until rollback is tested.

Build a broken image:

```bash id="dibtt3"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

rm -rf /tmp/demo-node-api-capstone-broken
cp -a . /tmp/demo-node-api-capstone-broken
echo 'throw new Error("capstone broken image");' > /tmp/demo-node-api-capstone-broken/server.js

docker build \
  -f /tmp/demo-node-api-capstone-broken/Dockerfile.industry \
  --target runtime \
  --build-arg APP_VERSION=0.3.0-broken \
  --build-arg COMMIT_SHA=capstone-broken \
  -t demo-node-api:0.3.0-broken \
  /tmp/demo-node-api-capstone-broken
```

Deploy known good first:

```bash id="z8er6f"
cd ~/devops-masterclass/06-docker-containers/compose-demo

APP_IMAGE=demo-node-api \
APP_VERSION=0.3.0 \
COMPOSE_FILES="compose.yaml compose.prod.yaml" \
./scripts/deploy-compose.sh
```

Deploy broken image:

```bash id="klhsyi"
APP_IMAGE=demo-node-api \
APP_VERSION=0.3.0-broken \
COMPOSE_FILES="compose.yaml compose.prod.yaml" \
AUTO_ROLLBACK=true \
./scripts/deploy-compose.sh || true
```

Validate rollback:

```bash id="f5shnu"
curl -s http://127.0.0.1:8080/version | jq .
cat "$(ls -t deployment-records/deploy-*.json | head -n 1)" | jq .
```

Expected report status:

```text id="q0hwf3"
failed_rolled_back
```

This proves your deployment can recover from a bad image.

---

# 20. Registry Workflow

For local capstone, we used:

```text id="zw1e85"
demo-node-api:0.3.0
```

For real registry, use:

```text id="dwrhjc"
ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.3.0-<sha>
```

Build and push:

```bash id="aqx6jh"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

export REGISTRY_IMAGE=ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api

VERSION=0.3.0 ./scripts/docker-build.sh
VERSION=0.3.0 ./scripts/docker-tag-push.sh
```

Then update Compose `.env`:

```bash id="oddnj6"
APP_IMAGE=ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api
APP_VERSION=0.3.0-<git-sha>
```

Deploy:

```bash id="w1wxry"
cd ~/devops-masterclass/06-docker-containers/compose-demo

COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
```

Production principle:

```text id="ti32ow"
Production servers should pull images from registry.
They should not build images from source.
```

---

# 21. CI/CD Capstone Validation

You created these workflows:

```text id="vmkpnq"
.github/workflows/docker-ci.yml
.github/workflows/docker-cd-compose.yml
```

CI workflow should do:

```text id="lm70af"
checkout
npm ci
npm test
Buildx setup
GHCR login on push
build image
push image
SBOM/provenance
optional Trivy scan
```

CD workflow should do:

```text id="wg8kuj"
manual dispatch
select image tag
select environment
SSH to server
update .env
run deploy-compose.sh
health validate
rollback if failed
```

Check files:

```bash id="b5cfaw"
cd ~/devops-masterclass

ls -l .github/workflows
cat .github/workflows/docker-ci.yml
cat .github/workflows/docker-cd-compose.yml
```

---

# 22. Create Capstone Architecture Doc

Create:

```bash id="z5yn35"
cd ~/devops-masterclass/06-docker-containers/docker-production-capstone
nano docs/architecture.md
```

Paste:

````markdown id="miq2tn"
# Docker Production Capstone Architecture

## Runtime Architecture

```text
User / Browser / curl
        |
        v
+-------------------+
| Nginx Container   |
| Public: 8080:80   |
+---------+---------+
          |
          | public_net
          v
+-------------------+
| Backend Container |
| demo-node-api     |
| Internal :3000    |
+---------+---------+
          |
          | private_net
          v
+-------------------+
| MongoDB Container |
| Internal :27017   |
| Named Volume      |
+-------------------+
````

## Responsibilities

### Nginx

* public entrypoint
* reverse proxy
* forwards request headers
* exposes only port 8080 locally
* connects to backend by service name

### Backend

* Node.js API
* runs as non-root
* has health/readiness/version/config endpoints
* reads secrets from `/run/secrets`
* runs with read-only root filesystem
* has resource and PID limits

### MongoDB

* private internal database
* no host port published
* stores data in named Docker volume
* uses secret-based root password

### Compose

* defines services
* defines public/private networks
* defines named volumes
* defines secrets
* defines healthchecks
* defines restart policies
* defines security hardening

## Deployment Flow

```text
CI builds image
  -> image scan
  -> push immutable tag
  -> server pulls image
  -> Compose starts stack
  -> /ready validation
  -> rollback if failed
  -> deployment report
```

````

---

# 23. Create Capstone Runbook

Create:

```bash id="j7gxdb"
nano docs/operations-runbook.md
````

Paste:

````markdown id="ic2oae"
# Docker Production Capstone Runbook

## Check Stack

```bash
cd ~/devops-masterclass/06-docker-containers/compose-demo

docker compose -f compose.yaml -f compose.prod.yaml ps
````

## Check Public Endpoints

```bash
curl -i http://127.0.0.1:8080/nginx-health
curl -i http://127.0.0.1:8080/health
curl -i http://127.0.0.1:8080/ready
curl -i http://127.0.0.1:8080/version
```

## Check Logs

```bash
docker compose -f compose.yaml -f compose.prod.yaml logs --tail 100 nginx
docker compose -f compose.yaml -f compose.prod.yaml logs --tail 100 backend
docker compose -f compose.yaml -f compose.prod.yaml logs --tail 100 mongo
```

## Run Diagnostics

```bash
./scripts/diagnose-compose.sh
```

## Run Resource Report

```bash
./scripts/resource-report.sh
```

## Deploy

```bash
COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
```

## Rollback

```bash
./scripts/rollback-compose.sh <previous-version>
```

## Backup Mongo Volume

```bash
./scripts/backup-mongo-volume.sh
```

## Restore Mongo Volume

```bash
docker compose -f compose.yaml -f compose.prod.yaml down
./scripts/restore-mongo-volume.sh backups/<backup-file>.tar.gz
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

## Common Incidents

### Nginx 502

```bash
docker compose logs nginx --tail 100
docker compose logs backend --tail 100
docker compose exec nginx wget -qO- http://backend:3000/health
```

### Backend Unhealthy

```bash
docker inspect compose-demo-backend --format '{{json .State.Health}}' | jq .
docker compose logs backend --tail 100
```

### Mongo Data Missing

```bash
docker volume ls | grep mongo
docker volume inspect compose-demo_mongo_data
```

### Disk Full

```bash
df -h
docker system df
docker system df -v
```

### OOMKilled

```bash
docker inspect compose-demo-backend | jq '.[0].State | {ExitCode, OOMKilled}'
```

````

---

# 24. Create Capstone Security Checklist

Create:

```bash id="f3rwfk"
nano docs/security-checklist.md
````

Paste:

````markdown id="wj7arf"
# Docker Security Checklist

## Image Security

- Uses production Dockerfile
- Uses `.dockerignore`
- Does not copy `.env`
- Does not bake secrets
- Runs as non-root
- Uses `npm ci`
- Uses production dependencies
- Uses healthcheck
- Uses immutable tags
- Image scan performed

## Runtime Security

- Backend runs read-only
- Backend uses tmpfs for `/tmp`
- Backend drops Linux capabilities
- Backend uses no-new-privileges
- Nginx drops capabilities where possible
- MongoDB is not publicly exposed
- Docker socket is not mounted
- No service uses privileged mode
- Secrets are mounted as files
- Resource limits are defined

## Registry Security

- CI has push access
- Server has pull-only access
- No personal tokens on production servers
- Image tags are immutable or versioned
- Digest is recorded where possible

## Dangerous Patterns to Avoid

```yaml
privileged: true
````

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

```yaml
mongo:
  ports:
    - "27017:27017"
```

```Dockerfile
ENV DATABASE_URL=mongodb://user:password@mongo/app
```

````

---

# 25. Create Capstone Validation Script

Create:

```bash id="mk7kpy"
cd ~/devops-masterclass/06-docker-containers/docker-production-capstone
nano scripts/validate-docker-capstone.sh
````

Paste:

```bash id="agn8xk"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
APP_DIR="$ROOT_DIR/05-application-runtime/demo-node-api"
COMPOSE_DIR="$ROOT_DIR/06-docker-containers/compose-demo"
REPORT_DIR="$ROOT_DIR/06-docker-containers/docker-production-capstone/reports"
REPORT_FILE="$REPORT_DIR/docker-capstone-validation-$(date +%Y%m%d_%H%M%S).json"

mkdir -p "$REPORT_DIR"

PASS=0
WARN=0
FAIL=0
RESULTS=()

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))'
}

record() {
  local status="$1"
  local name="$2"
  local message="${3:-}"

  RESULTS+=("{\"status\":\"$status\",\"name\":$(printf "%s" "$name" | json_escape),\"message\":$(printf "%s" "$message" | json_escape)}")

  case "$status" in
    pass) PASS=$((PASS+1)) ;;
    warn) WARN=$((WARN+1)) ;;
    fail) FAIL=$((FAIL+1)) ;;
  esac
}

check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    record pass "command:$1" "found"
  else
    record warn "command:$1" "not found"
  fi
}

check_file() {
  if [ -f "$1" ]; then
    record pass "file:$1" "found"
  else
    record fail "file:$1" "missing"
  fi
}

check_executable() {
  if [ -x "$1" ]; then
    record pass "executable:$1" "executable"
  else
    record fail "executable:$1" "missing or not executable"
  fi
}

check_url() {
  local url="$1"
  if curl -fsS --max-time 5 "$url" >/dev/null 2>&1; then
    record pass "url:$url" "reachable"
  else
    record warn "url:$url" "not reachable"
  fi
}

echo "===== Docker Capstone Validation ====="

check_command docker
check_command "docker"
check_command jq
check_command curl
check_command node
check_command npm

check_file "$APP_DIR/Dockerfile.industry"
check_file "$APP_DIR/.dockerignore"
check_file "$APP_DIR/scripts/docker-build.sh"
check_file "$APP_DIR/scripts/local-docker-ci.sh"
check_file "$APP_DIR/scripts/docker-security-scan.sh"
check_file "$APP_DIR/scripts/docker-tag-push.sh"

check_executable "$APP_DIR/scripts/docker-build.sh"
check_executable "$APP_DIR/scripts/local-docker-ci.sh"
check_executable "$APP_DIR/scripts/docker-security-scan.sh"
check_executable "$APP_DIR/scripts/docker-tag-push.sh"

check_file "$COMPOSE_DIR/compose.yaml"
check_file "$COMPOSE_DIR/compose.prod.yaml"
check_file "$COMPOSE_DIR/nginx/default.conf"
check_file "$COMPOSE_DIR/scripts/deploy-compose.sh"
check_file "$COMPOSE_DIR/scripts/rollback-compose.sh"
check_file "$COMPOSE_DIR/scripts/backup-mongo-volume.sh"
check_file "$COMPOSE_DIR/scripts/restore-mongo-volume.sh"
check_file "$COMPOSE_DIR/scripts/diagnose-compose.sh"
check_file "$COMPOSE_DIR/scripts/resource-report.sh"
check_file "$COMPOSE_DIR/scripts/compose-security-check.sh"

check_executable "$COMPOSE_DIR/scripts/deploy-compose.sh"
check_executable "$COMPOSE_DIR/scripts/rollback-compose.sh"
check_executable "$COMPOSE_DIR/scripts/backup-mongo-volume.sh"
check_executable "$COMPOSE_DIR/scripts/restore-mongo-volume.sh"
check_executable "$COMPOSE_DIR/scripts/diagnose-compose.sh"
check_executable "$COMPOSE_DIR/scripts/resource-report.sh"
check_executable "$COMPOSE_DIR/scripts/compose-security-check.sh"

if docker image inspect demo-node-api:0.3.0 >/dev/null 2>&1; then
  record pass "image:demo-node-api:0.3.0" "found"
else
  record warn "image:demo-node-api:0.3.0" "not found; build it with VERSION=0.3.0 ./scripts/docker-build.sh"
fi

cd "$COMPOSE_DIR"

if docker compose -f compose.yaml -f compose.prod.yaml config >/tmp/docker-capstone-compose.yaml 2>/dev/null; then
  record pass "compose-config" "valid"
else
  record fail "compose-config" "invalid"
fi

if ./scripts/compose-security-check.sh >/tmp/docker-capstone-security.txt 2>&1; then
  record pass "compose-security-check" "passed"
else
  record warn "compose-security-check" "failed; see /tmp/docker-capstone-security.txt"
fi

check_url "http://127.0.0.1:8080/health"
check_url "http://127.0.0.1:8080/ready"
check_url "http://127.0.0.1:8080/version"

RESULTS_JSON="$(IFS=,; echo "${RESULTS[*]}")"

cat > "$REPORT_FILE" <<EOF
{
  "summary": {
    "pass": $PASS,
    "warn": $WARN,
    "fail": $FAIL
  },
  "results": [
    $RESULTS_JSON
  ],
  "generated_at": "$(date -Iseconds)"
}
EOF

cat "$REPORT_FILE" | jq .

echo
echo "Report written to: $REPORT_FILE"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
```

Make executable:

```bash id="z8e672"
chmod +x scripts/validate-docker-capstone.sh
```

Run:

```bash id="kdjxaa"
./scripts/validate-docker-capstone.sh
```

---

# 26. Create Capstone README

Create:

```bash id="w15lou"
cd ~/devops-masterclass/06-docker-containers/docker-production-capstone
nano README.md
```

Paste:

````markdown id="bdwk0t"
# Docker Production Capstone

This capstone demonstrates a production-style Docker workflow for a Node.js API with Nginx and MongoDB.

## Features

- Production Dockerfile
- Multi-stage image build
- Non-root runtime user
- Docker healthcheck
- Docker Compose stack
- Nginx reverse proxy
- Public/private Docker networks
- MongoDB named volume
- Compose secrets
- Resource limits
- Read-only backend container
- Log rotation
- Image scanning
- Registry tagging/push workflow
- Compose deployment script
- Health validation
- Auto rollback
- Backup and restore
- Diagnostics and troubleshooting scripts

## Architecture

```text
User -> Nginx -> Backend -> MongoDB
````

## Build Image

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api
VERSION=0.3.0 ./scripts/docker-build.sh
```

## Run Local CI

```bash
VERSION=0.3.0 ./scripts/local-docker-ci.sh
```

## Deploy Stack

```bash
cd ~/devops-masterclass/06-docker-containers/compose-demo
COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
```

## Validate

```bash
curl -s http://127.0.0.1:8080/health | jq .
curl -s http://127.0.0.1:8080/ready | jq .
curl -s http://127.0.0.1:8080/version | jq .
```

## Backup

```bash
./scripts/backup-mongo-volume.sh
```

## Diagnostics

```bash
./scripts/diagnose-compose.sh
./scripts/resource-report.sh
```

## Capstone Validation

```bash
cd ~/devops-masterclass/06-docker-containers/docker-production-capstone
./scripts/validate-docker-capstone.sh
```

## Production Principles Demonstrated

* Build once, deploy the same image
* Use immutable tags
* Keep secrets out of images
* Keep databases private
* Use health/readiness checks
* Rollback failed deployments
* Persist and backup data
* Harden containers with least privilege
* Monitor resources and logs

````

---

# 27. Add Module 6 Final Summary

Create:

```bash id="ceyhn8"
cd ~/devops-masterclass/06-docker-containers
nano module-6-summary.md
````

Paste:

```markdown id="rl37gy"
# Module 6 Summary — Docker and Container Fundamentals

## Lessons Completed

1. What containers actually are
2. Dockerfile basics
3. Layers, cache, tagging, image optimization
4. Docker networking
5. Docker Compose
6. Volumes and persistent data
7. Compose production patterns
8. Container security
9. Registries and image promotion
10. Docker CI/CD pipeline
11. Docker troubleshooting
12. Docker performance and resource management
13. Docker production capstone

## Core Skills Learned

- Build Docker images
- Write production Dockerfiles
- Use `.dockerignore`
- Run containers with ports/env/volumes
- Debug container failures
- Use Docker Compose
- Create public/private networks
- Persist database data
- Backup/restore volumes
- Use secrets safely
- Harden containers
- Scan images
- Push/pull registry images
- Deploy with Compose
- Validate health
- Rollback failed deployment
- Manage resources and logs

## Portfolio Statement

Built a production-style Docker platform for a Node.js API using multi-stage Dockerfiles, non-root containers, Docker Compose, Nginx reverse proxy, MongoDB persistence, Compose secrets, private networking, healthchecks, security hardening, image scanning, registry tagging, CI/CD workflows, health-based deployment, auto-rollback, backups, diagnostics, and resource management.
```

---

# 28. Final Commit and Tag

Run:

```bash id="eulzz2"
cd ~/devops-masterclass

git status
git add 05-application-runtime/demo-node-api \
        06-docker-containers \
        .github/workflows

git commit -m "feat: complete Docker production capstone"
git push
```

Tag Module 6:

```bash id="auwxj4"
git tag -a v0.6.0 -m "Complete Module 6 Docker and container fundamentals"
git push origin v0.6.0
```

---

# 29. Interview Explanation

## Explain your Docker capstone project.

Strong answer:

```text id="lgd4ob"
I built a production-style Docker deployment for a Node.js API. The app uses a multi-stage Dockerfile, npm ci, non-root runtime user, healthchecks, OCI labels, and safe runtime defaults. I deployed it using Docker Compose with Nginx as the public reverse proxy, backend as an internal service, and MongoDB on a private network with a named volume. The stack uses Compose secrets, healthchecks, restart policies, resource limits, log rotation, read-only filesystem hardening, and deployment scripts with readiness validation and auto-rollback.
```

## How did you make the Docker image production-ready?

Strong answer:

```text id="gqlgey"
I used a production Dockerfile with dependency-first caching, npm ci, multi-stage build structure, production-only dependencies, non-root user, limited runtime file copying, healthcheck, OCI metadata labels, and a .dockerignore file to keep secrets, node_modules, Git history, and logs out of the image.
```

## How did you secure the Compose stack?

Strong answer:

```text id="sa9bsj"
I published only Nginx to the host and kept backend and MongoDB internal. I used public and private networks, mounted secrets as files, avoided privileged containers and Docker socket mounts, ran the backend read-only with tmpfs, dropped Linux capabilities, enabled no-new-privileges, set PID/memory/CPU limits, and configured log rotation.
```

## How does rollback work?

Strong answer:

```text id="kww7ly"
Rollback works by restoring the previous immutable image tag in the Compose environment file, pulling the image if needed, recreating the containers, and validating the readiness endpoint. The deployment script automatically attempts rollback if the new version fails health checks.
```

## How do you handle persistent data?

Strong answer:

```text id="eey8sp"
MongoDB stores data in a named Docker volume so data survives container recreation. I also added backup and restore scripts because persistence is not the same as backup. For production, I would prefer managed databases or storage with snapshots and tested restores.
```

## How do you troubleshoot the stack?

Strong answer:

```text id="f22qgq"
I start with docker compose ps and logs, then inspect healthcheck details, rendered Compose config, networks, volumes, resource usage, and deployment reports. For Nginx 502, I exec into the Nginx container and test the backend service name directly. For resource issues, I check docker stats, OOMKilled state, Docker disk usage, and log file sizes.
```

---

# 30. Module 6 Completion

You completed:

```text id="nm70p0"
Lesson 6.1  What containers actually are
Lesson 6.2  Dockerfile basics
Lesson 6.3  Layers, cache, tagging, production Dockerfiles
Lesson 6.4  Docker networking
Lesson 6.5  Docker Compose
Lesson 6.6  Volumes and persistent data
Lesson 6.7  Compose production patterns
Lesson 6.8  Container security
Lesson 6.9  Registries and image promotion
Lesson 6.10 Docker CI/CD pipeline
Lesson 6.11 Docker troubleshooting
Lesson 6.12 Docker performance and resource management
Lesson 6.13 Docker production capstone
```

You now understand Docker from:

```text id="e9vqle"
beginner container basics
to professional Compose stacks
to expert deployment, security, rollback, and operations
```

---

# 31. What Comes Next

Next module:

# Module 7 — Artifact Management and Registries

In Module 7, we will go deeper into:

```text id="ef33ab"
artifact lifecycle
Docker registries deeper
semantic versioning
build metadata
SBOMs
provenance
image signing
Cosign/Sigstore concepts
ECR/GHCR/Docker Hub patterns
artifact promotion
retention policies
artifact security
release governance
supply-chain security
CI/CD artifact gates
```
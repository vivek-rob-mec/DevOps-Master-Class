# Lesson 6.7 — Docker Compose Production Patterns

# Profiles, Override Files, Secrets, Resource Limits, Health-Based Deployments, and CI/CD Flow

In Lesson 6.5 and 6.6, we built a Compose stack with:

```text id="eq3q91"
nginx
backend
mongo
public/private networks
named volume
healthchecks
restart policies
log rotation
```

Now we make it more production-ready.

Today we will learn:

```text id="d53jhr"
Compose profiles
multiple Compose files
dev vs prod overrides
secrets
resource limits
read-only containers
health-based startup
CI/CD deployment flow
rollback with image tags
corporate Compose structure
```

Compose is designed to manage services, networks, and volumes from one YAML configuration, and Docker documents its use across development, testing, CI, staging, and production-style workflows. ([Docker Documentation][1])

---

# 1. Beginner Level — Why Production Patterns Matter

A beginner Compose file usually looks like this:

```yaml id="mkqy6d"
services:
  backend:
    image: demo-node-api:latest
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: mongodb://mongo:27017/demo

  mongo:
    image: mongo:latest
    ports:
      - "27017:27017"
```

This works, but it has problems:

```text id="pblxdz"
uses latest tag
publishes database port
no healthchecks
no log limits
no resource limits
no secrets handling
no dev/prod separation
no backup thinking
no rollback strategy
```

A production-style Compose setup should think about:

```text id="chgjtu"
security
reliability
repeatability
observability
rollback
least privilege
data safety
environment separation
```

Core rule:

```text id="z05xeb"
A Compose file is not just a run command. It is infrastructure definition.
```

---

# 2. Intermediate Level — Current Compose Demo Structure

Go to your Compose project:

```bash id="horyru"
cd ~/devops-masterclass/06-docker-containers/compose-demo
```

Current structure:

```text id="icmtt6"
compose-demo/
├── compose.yaml
├── .env
├── .env.example
├── backend.env
├── backend.env.example
├── nginx/
│   └── default.conf
├── backups/
├── scripts/
│   ├── backup-mongo-volume.sh
│   └── restore-mongo-volume.sh
└── Makefile
```

Today we will improve it into this:

```text id="gwmchc"
compose-demo/
├── compose.yaml
├── compose.override.yaml
├── compose.prod.yaml
├── .env.example
├── backend.env.example
├── secrets/
│   └── mongodb_root_password.example.txt
├── nginx/
│   └── default.conf
├── scripts/
│   ├── deploy-compose.sh
│   ├── rollback-compose.sh
│   ├── backup-mongo-volume.sh
│   └── restore-mongo-volume.sh
└── Makefile
```

---

# 3. Compose Profiles — Beginner Concept

Profiles let you enable optional services only when needed.

Docker documents Compose profiles as a way to adjust an application for different environments or use cases by selectively activating services. Services without a profile start by default; services assigned to a profile start only when that profile is active. ([Docker Documentation][2])

Example use cases:

```text id="sk5wz9"
debug tools
admin UI
database browser
local-only mail server
load testing tool
backup job
```

Example:

```yaml id="gz3ogj"
services:
  backend:
    image: demo-node-api:0.1.9

  mongo-express:
    image: mongo-express
    profiles:
      - tools
```

Default:

```bash id="b9nqmx"
docker compose up -d
```

Starts only `backend`.

With tools:

```bash id="xeg2a9"
docker compose --profile tools up -d
```

Starts `backend` and `mongo-express`.

Core rule:

```text id="vhi9u4"
Core services should start by default. Optional/debug/admin services should use profiles.
```

---

# 4. Add a Debug Profile Service

In your `compose.yaml`, add a debug container.

Open:

```bash id="x9s5r4"
nano compose.yaml
```

Add this service:

```yaml id="mfvmzm"
  debug:
    image: alpine:3.20
    container_name: compose-demo-debug
    profiles:
      - debug
    command: ["sleep", "infinity"]
    networks:
      - public_net
      - private_net
```

Start normal stack:

```bash id="jz13wk"
docker compose up -d
docker compose ps
```

You should not see `debug`.

Start with debug profile:

```bash id="19yqkk"
docker compose --profile debug up -d
docker compose ps
```

Now enter debug container:

```bash id="ivmz92"
docker compose exec debug sh
```

Inside:

```sh id="2xmzi1"
apk add --no-cache curl bind-tools
nslookup backend
nslookup mongo
curl -i http://backend:3000/health
exit
```

Stop debug profile stack:

```bash id="ml67v1"
docker compose --profile debug down
```

Production idea:

```text id="q4kapu"
Debug tools should not run all the time. Start them only when needed.
```

---

# 5. Multiple Compose Files — Beginner Concept

You can split config into multiple files:

```text id="ygyvm7"
compose.yaml          base
compose.override.yaml local development
compose.prod.yaml     production settings
```

Docker documents using multiple Compose files with the `-f` flag; files are merged in the order specified, and later files can override or add to earlier files. ([Docker Documentation][3])

Example:

```bash id="y1qrb2"
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

Meaning:

```text id="i1aeij"
load compose.yaml first
then apply compose.prod.yaml overrides
```

Core rule:

```text id="q1q8x3"
Use base Compose for common config. Use overrides for environment-specific behavior.
```

---

# 6. Create `compose.override.yaml` for Local Dev

Compose automatically applies `compose.override.yaml` when you run normal `docker compose up`.

Create:

```bash id="czyv7y"
nano compose.override.yaml
```

Paste:

```yaml id="wr2j0t"
services:
  backend:
    environment:
      LOG_LEVEL: debug
    labels:
      com.demo.environment: "local"

  nginx:
    labels:
      com.demo.environment: "local"

  mongo:
    labels:
      com.demo.environment: "local"
```

Validate merged config:

```bash id="2ctmph"
docker compose config
```

You should see:

```text id="e2e7z4"
LOG_LEVEL: debug
com.demo.environment: local
```

Start:

```bash id="ohhfsm"
docker compose up -d
```

Check backend env:

```bash id="bzv8b1"
docker compose exec backend env | grep LOG_LEVEL
```

Stop:

```bash id="gxkr82"
docker compose down
```

Important:

```text id="jk7s29"
compose.override.yaml is convenient for local dev, but be careful not to accidentally apply local settings to production.
```

For production, explicitly specify files:

```bash id="ydlgvn"
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

---

# 7. Create `compose.prod.yaml`

Production override should add stricter settings.

Create:

```bash id="25a0a5"
nano compose.prod.yaml
```

Paste:

```yaml id="m4rk3a"
services:
  backend:
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /tmp
    environment:
      LOG_LEVEL: info
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    deploy:
      resources:
        limits:
          cpus: "0.50"
          memory: 256M
        reservations:
          memory: 128M

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
    deploy:
      resources:
        limits:
          cpus: "0.25"
          memory: 128M

  mongo:
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    deploy:
      resources:
        limits:
          cpus: "1.00"
          memory: 512M
        reservations:
          memory: 256M
```

Validate:

```bash id="moq6uh"
docker compose -f compose.yaml -f compose.prod.yaml config
```

Important about `deploy.resources`:

Docker’s Compose Deploy Specification defines `resources.limits` as maximum resources the platform must prevent the container from exceeding, and `resources.reservations` as resources the platform should guarantee. ([Docker Documentation][4])

Also note: Compose support for `deploy` fields can vary by runtime/platform. Docker’s Compose service reference states that `deploy` support is optional in the Compose Specification; if not implemented, that section is ignored while the file remains valid. ([Docker Documentation][5])

Practical check:

```bash id="4eacvu"
docker compose -f compose.yaml -f compose.prod.yaml up -d
docker inspect compose-demo-backend --format '{{json .HostConfig.Memory}}'
docker inspect compose-demo-backend --format '{{json .HostConfig.NanoCpus}}'
docker compose down
```

If limits do not appear as expected in your local engine, we can also use Compose service-level fields supported by your Docker version later.

---

# 8. Compose Secrets — Beginner Concept

Environment variables are easy, but secrets are safer when mounted as files.

Docker’s Compose secrets docs explain that secrets are defined at the top-level `secrets` element and then granted per service; inside the container, secrets are mounted as files under `/run/secrets/<secret_name>`. ([Docker Documentation][6])

Example:

```yaml id="r8n2pa"
services:
  backend:
    secrets:
      - db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

Inside backend:

```text id="dnom4y"
/run/secrets/db_password
```

Core rule:

```text id="o2jqn5"
Secrets should be passed only to services that need them.
```

---

# 9. Add Compose Secrets for MongoDB Password

Create secrets directory:

```bash id="grxvz8"
mkdir -p secrets
```

Create example file for Git:

```bash id="f8snho"
echo "change-me-example" > secrets/mongodb_root_password.example.txt
```

Create real local secret:

```bash id="z64co9"
openssl rand -base64 32 > secrets/mongodb_root_password.txt
chmod 600 secrets/mongodb_root_password.txt
```

Update `.gitignore`:

```bash id="kh0fvf"
nano .gitignore
```

Make sure it includes:

```gitignore id="2fjgnv"
.env
backend.env
secrets/*.txt
!secrets/*.example.txt
backups/*.tar.gz
```

Now update `compose.yaml`.

For Mongo:

```yaml id="1xcztp"
  mongo:
    image: mongo:7
    container_name: compose-demo-mongo
    restart: unless-stopped
    expose:
      - "27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD_FILE: /run/secrets/mongodb_root_password
    secrets:
      - mongodb_root_password
    volumes:
      - mongo_data:/data/db
    healthcheck:
      test: ["CMD-SHELL", "mongosh --quiet -u root -p \"$$(cat /run/secrets/mongodb_root_password)\" --authenticationDatabase admin --eval 'db.runCommand({ ping: 1 }).ok' || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 15s
    networks:
      - private_net
```

Add top-level secrets at bottom:

```yaml id="fbu6yb"
secrets:
  mongodb_root_password:
    file: ./secrets/mongodb_root_password.txt
```

Important escaping:

```text id="31absz"
Use $$ inside Compose YAML when you want a literal $ inside the container command.
```

---

# 10. Update Backend Mongo URL with Credentials

Open:

```bash id="qjqaw6"
nano backend.env
```

For local learning, use:

```bash id="vk4epn"
APP_ENV=prod
PORT=3000
LOG_LEVEL=info
LOAD_DOTENV=false
APP_NAME=demo-node-api
APP_VERSION=0.1.9
COMMIT_SHA=compose-local
DATABASE_URL=mongodb://root:CHANGE_ME_FROM_SECRET@mongo:27017/demo?authSource=admin
CORS_ORIGIN=http://localhost:8080
ENABLE_CACHE=false
REQUEST_TIMEOUT_MS=5000
STARTUP_DELAY_MS=0
```

But this reveals a limitation: our app currently only reads `DATABASE_URL` as an env var, not a `_FILE` secret path.

Industry standard pattern:

```text id="3dkf6n"
Support both DATABASE_URL and DATABASE_URL_FILE
```

This lets containerized apps read secrets from `/run/secrets`.

We will improve the app.

---

# 11. Add `_FILE` Secret Support to Node Config

Go to app:

```bash id="6zx4z0"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Open:

```bash id="95r39f"
nano src/config.js
```

Add at top:

```javascript id="dk590w"
const fs = require("fs");
```

Add helper:

```javascript id="f1y4jc"
function readSecretFile(filePath, name) {
  try {
    return fs.readFileSync(filePath, "utf8").trim();
  } catch (error) {
    throw new ConfigError(`${name} points to a file that cannot be read: ${filePath}`);
  }
}

function optionalSecretString(name, defaultValue = "") {
  const fileName = `${name}_FILE`;

  if (process.env[fileName]) {
    return readSecretFile(process.env[fileName], fileName);
  }

  return optionalString(name, defaultValue);
}
```

Then change:

```javascript id="dn555x"
const databaseUrl = optionalUrl("DATABASE_URL", "");
```

to a more flexible pattern:

```javascript id="cxw9ye"
const databaseUrlRaw = optionalSecretString("DATABASE_URL", "");
const databaseUrl = databaseUrlRaw ? validateUrl("DATABASE_URL", databaseUrlRaw) : "";
```

If your existing `validateUrl` only accepts HTTP URLs and rejects MongoDB URLs, improve it.

Add helper:

```javascript id="v9gv8w"
function validateConnectionUrl(name, value) {
  try {
    const parsed = new URL(value);
    const allowedProtocols = ["http:", "https:", "mongodb:", "mongodb+srv:", "postgres:", "postgresql:", "redis:"];

    if (!allowedProtocols.includes(parsed.protocol)) {
      throw new Error(`unsupported protocol ${parsed.protocol}`);
    }

    return value;
  } catch {
    throw new ConfigError(`${name} must be a valid connection URL`);
  }
}
```

Then use:

```javascript id="82i3u3"
const databaseUrlRaw = optionalSecretString("DATABASE_URL", "");
const databaseUrl = databaseUrlRaw ? validateConnectionUrl("DATABASE_URL", databaseUrlRaw) : "";
```

Also add safe summary field:

```javascript id="rx9l37"
databaseUrlConfigured: Boolean(config.databaseUrl),
```

Do not print the full database URL.

Production rule:

```text id="n5o2oq"
Never expose credentials in /config-summary or logs.
```

Rebuild image:

```bash id="ve2qkx"
VERSION=0.2.0 ./scripts/docker-build.sh
```

---

# 12. Compose Secret for Backend DATABASE_URL

Return:

```bash id="6i9yku"
cd ~/devops-masterclass/06-docker-containers/compose-demo
```

Create backend database URL secret file.

Use your Mongo password from secret:

```bash id="scgk6g"
MONGO_PASSWORD="$(cat secrets/mongodb_root_password.txt)"

cat > secrets/backend_database_url.txt <<EOF
mongodb://root:${MONGO_PASSWORD}@mongo:27017/demo?authSource=admin
EOF

chmod 600 secrets/backend_database_url.txt
```

Create example:

```bash id="6jtrdt"
cat > secrets/backend_database_url.example.txt <<'EOF'
mongodb://root:change-me@mongo:27017/demo?authSource=admin
EOF
```

Update `backend.env`:

```bash id="2y4eb2"
nano backend.env
```

Use:

```bash id="8p2rmf"
APP_ENV=prod
PORT=3000
LOG_LEVEL=info
LOAD_DOTENV=false
APP_NAME=demo-node-api
APP_VERSION=0.2.0
COMMIT_SHA=compose-secrets
DATABASE_URL_FILE=/run/secrets/backend_database_url
CORS_ORIGIN=http://localhost:8080
ENABLE_CACHE=false
REQUEST_TIMEOUT_MS=5000
STARTUP_DELAY_MS=0
```

Update `.env`:

```bash id="etd3tu"
nano .env
```

Set:

```bash id="3b8c85"
APP_IMAGE=demo-node-api
APP_VERSION=0.2.0
HOST_HTTP_PORT=8080
APP_ENV=dev
LOG_LEVEL=info
```

Update backend service:

```yaml id="4pkyau"
  backend:
    image: ${APP_IMAGE}:${APP_VERSION}
    container_name: compose-demo-backend
    restart: unless-stopped
    expose:
      - "3000"
    env_file:
      - ./backend.env
    secrets:
      - backend_database_url
    depends_on:
      mongo:
        condition: service_started
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:3000/ready || exit 1"]
      interval: 10s
      timeout: 3s
      retries: 5
      start_period: 10s
    networks:
      - public_net
      - private_net
```

Add top-level secret:

```yaml id="gn9myb"
secrets:
  mongodb_root_password:
    file: ./secrets/mongodb_root_password.txt
  backend_database_url:
    file: ./secrets/backend_database_url.txt
```

Start:

```bash id="borpb6"
docker compose up -d
```

Validate:

```bash id="zpggpa"
docker compose ps
curl -s http://127.0.0.1:8080/config-summary | jq .
docker compose exec backend ls -l /run/secrets
docker compose exec backend sh -c 'test -f /run/secrets/backend_database_url && echo secret-mounted'
```

Do **not** run `cat /run/secrets/backend_database_url` in shared screenshots/logs.

---

# 13. Secret Handling: Real-World Notes

Compose secrets are better than plain env vars for local/single-server setups because they are mounted as files and granted per service. Docker’s Compose secrets reference says the top-level `secrets` declaration grants sensitive data to services and can source from a file or, in Docker Compose, an environment variable. ([Docker Documentation][7])

But understand maturity levels:

```text id="z5cj6h"
Beginner: environment variables
Better: Compose secrets from local files
Production cloud: secret manager integration
Enterprise: Vault / AWS Secrets Manager / SOPS / Sealed Secrets / External Secrets
```

Never put secrets in:

```text id="ua826k"
Dockerfile
image layers
Git repo
public logs
/config-summary
README screenshots
```

A 2023 internet-wide study found leaked secrets in container images, including private keys and API secrets, showing why image and repo hygiene matters. ([arXiv][8])

---

# 14. Health-Based Deployment with Compose

A Compose deployment should not just run:

```bash id="b2rsye"
docker compose up -d
```

It should also validate:

```text id="fdcy6o"
containers running
backend healthy
nginx reachable
app ready through public endpoint
deployment image version
logs clean
```

Manual validation:

```bash id="8cuup6"
docker compose ps
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1:8080/ready
curl -fsS http://127.0.0.1:8080/version | jq .
```

Production rule:

```text id="bphd51"
Deployment is not complete until health/readiness checks pass.
```

---

# 15. Create Compose Deployment Script

Create:

```bash id="530w3b"
cd ~/devops-masterclass/06-docker-containers/compose-demo
nano scripts/deploy-compose.sh
```

Paste:

```bash id="r2ntif"
#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILES="${COMPOSE_FILES:-compose.yaml compose.prod.yaml}"
APP_VERSION="${APP_VERSION:-}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:8080/ready}"
VERSION_URL="${VERSION_URL:-http://127.0.0.1:8080/version}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-15}"

if [ -n "$APP_VERSION" ]; then
  echo "Updating .env APP_VERSION=$APP_VERSION"
  if grep -q '^APP_VERSION=' .env; then
    sed -i "s/^APP_VERSION=.*/APP_VERSION=$APP_VERSION/" .env
  else
    echo "APP_VERSION=$APP_VERSION" >> .env
  fi
fi

compose_args=()
for file in $COMPOSE_FILES; do
  compose_args+=("-f" "$file")
done

echo "===== Compose Deploy ====="
echo "Compose files: $COMPOSE_FILES"
echo "Health URL: $HEALTH_URL"

echo
echo "Validating compose config..."
docker compose "${compose_args[@]}" config >/tmp/compose-rendered.yaml

echo
echo "Pulling images if available..."
docker compose "${compose_args[@]}" pull || true

echo
echo "Starting stack..."
docker compose "${compose_args[@]}" up -d

echo
echo "Waiting for health..."
for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  if curl -fsS "$HEALTH_URL" >/dev/null; then
    echo "Health passed on attempt $attempt"
    echo
    curl -fsS "$VERSION_URL" | jq .
    echo
    docker compose "${compose_args[@]}" ps
    exit 0
  fi

  echo "Health failed attempt $attempt/$MAX_ATTEMPTS"
  sleep 2
done

echo "ERROR: deployment health failed" >&2
docker compose "${compose_args[@]}" ps >&2
docker compose "${compose_args[@]}" logs --tail 100 >&2
exit 1
```

Make executable:

```bash id="y74pkr"
chmod +x scripts/deploy-compose.sh
```

Run:

```bash id="jqjjf8"
COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
```

---

# 16. Compose Rollback by Image Tag

Rollback strategy with Compose:

```text id="pz38mb"
previous image tag
update .env APP_VERSION
docker compose up -d
validate health
```

Create:

```bash id="eeznx0"
nano scripts/rollback-compose.sh
```

Paste:

```bash id="2apewx"
#!/usr/bin/env bash
set -euo pipefail

TARGET_VERSION="${1:-}"
COMPOSE_FILES="${COMPOSE_FILES:-compose.yaml compose.prod.yaml}"

if [ -z "$TARGET_VERSION" ]; then
  echo "Usage: $0 <target-app-version>" >&2
  exit 1
fi

echo "===== Compose Rollback ====="
echo "Target APP_VERSION: $TARGET_VERSION"

APP_VERSION="$TARGET_VERSION" \
COMPOSE_FILES="$COMPOSE_FILES" \
./scripts/deploy-compose.sh
```

Make executable:

```bash id="tbnfjr"
chmod +x scripts/rollback-compose.sh
```

Usage:

```bash id="ybzpbq"
./scripts/rollback-compose.sh 0.1.9
```

Then back:

```bash id="8da9ay"
./scripts/rollback-compose.sh 0.2.0
```

Production rule:

```text id="bmfnjr"
Rollback needs immutable image tags. This is why latest is dangerous.
```

---

# 17. CI/CD Flow for Compose Deployment

Corporate flow:

```text id="lkmb73"
Developer pushes code
  ↓
CI runs tests
  ↓
CI builds Docker image
  ↓
CI scans image
  ↓
CI pushes image:gitsha to registry
  ↓
CD SSHs to server
  ↓
server updates .env APP_VERSION=gitsha
  ↓
docker compose pull
  ↓
docker compose up -d
  ↓
health check
  ↓
rollback if failed
```

Example GitHub Actions conceptual deployment:

```yaml id="xmnvsf"
name: Deploy Compose App

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: |
          docker build \
            -f 05-application-runtime/demo-node-api/Dockerfile.industry \
            --target runtime \
            --build-arg APP_VERSION=${GITHUB_SHA::7} \
            --build-arg COMMIT_SHA=${GITHUB_SHA::7} \
            -t registry.example.com/demo-node-api:${GITHUB_SHA::7} \
            05-application-runtime/demo-node-api

      - name: Push image
        run: |
          docker push registry.example.com/demo-node-api:${GITHUB_SHA::7}

      - name: Deploy over SSH
        run: |
          ssh deploy@app-server '
            cd /srv/compose-demo &&
            APP_VERSION=${GITHUB_SHA::7} ./scripts/deploy-compose.sh
          '
```

This is conceptual. Later we will implement a real CI/CD workflow.

---

# 18. Profiles for Jobs: Backup Service

Add a backup job service using profile.

In `compose.yaml`:

```yaml id="sivog9"
  mongo-backup:
    image: alpine:3.20
    container_name: compose-demo-mongo-backup
    profiles:
      - backup
    volumes:
      - mongo_data:/data:ro
      - ./backups:/backup
    command:
      - sh
      - -c
      - |
        tar czf /backup/mongo_data_$$(date +%Y%m%d_%H%M%S).tar.gz -C /data .
        ls -lh /backup
    networks:
      - private_net
```

Run only when needed:

```bash id="sbipf6"
docker compose --profile backup run --rm mongo-backup
```

This demonstrates:

```text id="b2jvkk"
one-off operational jobs in Compose
```

In corporate systems, similar jobs might be:

```text id="oxct8z"
database backup
migration
cache warmup
admin maintenance
data export
```

---

# 19. Profiles for Admin Tools

Add optional Mongo Express only for local tools.

Add to `compose.yaml`:

```yaml id="jtd1sk"
  mongo-express:
    image: mongo-express:1
    container_name: compose-demo-mongo-express
    profiles:
      - tools
    ports:
      - "8082:8081"
    environment:
      ME_CONFIG_MONGODB_ADMINUSERNAME: root
      ME_CONFIG_MONGODB_ADMINPASSWORD_FILE: /run/secrets/mongodb_root_password
      ME_CONFIG_MONGODB_SERVER: mongo
    secrets:
      - mongodb_root_password
    depends_on:
      mongo:
        condition: service_started
    networks:
      - private_net
```

Start:

```bash id="uq6a07"
docker compose --profile tools up -d
```

Open:

```text id="knyqy1"
http://127.0.0.1:8082
```

Stop:

```bash id="x0ar4w"
docker compose --profile tools down
```

Production caution:

```text id="z2orfe"
Admin UIs should not be exposed publicly without strong authentication, network restrictions, and approval.
```

---

# 20. Resource Limits: Practical Options

There are two common ways you will see limits.

## Option A — Compose deploy resources

```yaml id="r2z8pc"
deploy:
  resources:
    limits:
      cpus: "0.50"
      memory: 256M
```

Good for Compose-spec style and some runtimes.

## Option B — Docker runtime-style fields

Depending on Compose version, you may see:

```yaml id="nmy3cs"
mem_limit: 256m
cpus: 0.5
pids_limit: 100
```

For local Docker Compose, this may be more directly reflected in `docker inspect`.

Example:

```yaml id="3od328"
services:
  backend:
    mem_limit: 256m
    cpus: 0.5
    pids_limit: 100
```

Docker Engine’s resource constraint docs explain that Docker can enforce hard and soft memory limits; a hard limit prevents the container from using more than a fixed amount of memory. ([Docker Documentation][9])

Masterclass rule:

```text id="9kr0x7"
Always verify resource limits with docker inspect on the runtime you actually use.
```

Check:

```bash id="0ohlgh"
docker inspect compose-demo-backend --format '{{.HostConfig.Memory}}'
docker inspect compose-demo-backend --format '{{.HostConfig.NanoCpus}}'
docker inspect compose-demo-backend --format '{{.HostConfig.PidsLimit}}'
```

---

# 21. Production Hardening Checklist for Compose Services

For backend:

```yaml id="7nmq2k"
read_only: true
tmpfs:
  - /tmp
security_opt:
  - no-new-privileges:true
cap_drop:
  - ALL
```

For Nginx:

```yaml id="7ol6tw"
read_only: true
tmpfs:
  - /var/cache/nginx
  - /var/run
  - /tmp
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE
```

For databases:

```text id="efui53"
do not always use read_only
needs writable data volume
restrict network exposure
backup regularly
resource limits carefully
```

General:

```text id="p01107"
avoid privileged: true
avoid host network unless justified
avoid mounting docker.sock
avoid latest tag
avoid publishing database ports
```

---

# 22. Create Production Compose Notes

Create:

```bash id="846jhc"
cd ~/devops-masterclass/06-docker-containers
nano compose-production-patterns.md
```

Paste:

````markdown id="r6pz80"
# Docker Compose Production Patterns

## Profiles

Profiles enable optional services:

```bash
docker compose --profile debug up -d
docker compose --profile backup run --rm mongo-backup
````

Use profiles for:

* debug tools
* admin UIs
* backup jobs
* local-only services

## Multiple Compose Files

```bash
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

Use:

* `compose.yaml` for base
* `compose.override.yaml` for local dev
* `compose.prod.yaml` for production

## Secrets

Compose secrets are mounted as files:

```text
/run/secrets/<secret_name>
```

Pattern:

```yaml
services:
  backend:
    secrets:
      - backend_database_url

secrets:
  backend_database_url:
    file: ./secrets/backend_database_url.txt
```

## Production Rules

* use immutable image tags
* publish only reverse proxy ports
* keep DB/cache private
* use secrets, not baked credentials
* add healthchecks
* use restart policies
* limit logs
* define resource limits
* use read-only containers where possible
* backup persistent data
* rollback by previous image tag

## Deployment Flow

```text
CI builds image
CI pushes image tag
server updates APP_VERSION
docker compose pull
docker compose up -d
health check
rollback if failed
```

````id="lm6xnh"

---

# 23. Create Final Production Makefile Targets

Open:

```bash id="3g6web"
cd ~/devops-masterclass/06-docker-containers/compose-demo
nano Makefile
````

Replace or extend with:

```Makefile id="sfb7d3"
.PHONY: up prod-up down ps logs backend-logs nginx-logs mongo-logs config prod-config test restart deploy rollback backup tools debug

up:
	docker compose up -d

prod-up:
	docker compose -f compose.yaml -f compose.prod.yaml up -d

down:
	docker compose down

ps:
	docker compose ps

logs:
	docker compose logs -f

backend-logs:
	docker compose logs -f backend

nginx-logs:
	docker compose logs -f nginx

mongo-logs:
	docker compose logs -f mongo

config:
	docker compose config

prod-config:
	docker compose -f compose.yaml -f compose.prod.yaml config

test:
	curl -fsS http://127.0.0.1:8080/nginx-health
	curl -fsS http://127.0.0.1:8080/health | jq .
	curl -fsS http://127.0.0.1:8080/ready | jq .
	curl -fsS http://127.0.0.1:8080/version | jq .

restart:
	docker compose restart backend

deploy:
	COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh

rollback:
	@test -n "$(VERSION)" || (echo "Usage: make rollback VERSION=<tag>" && exit 1)
	./scripts/rollback-compose.sh $(VERSION)

backup:
	docker compose --profile backup run --rm mongo-backup

tools:
	docker compose --profile tools up -d

debug:
	docker compose --profile debug up -d
```

Use:

```bash id="w55x3f"
make prod-config
make deploy
make test
make backup
make tools
```

---

# 24. Final Validation

Build updated app image:

```bash id="c1sd6j"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
VERSION=0.2.0 ./scripts/docker-build.sh
```

Return:

```bash id="y2zkkp"
cd ~/devops-masterclass/06-docker-containers/compose-demo
```

Check secrets exist:

```bash id="271lx6"
ls -l secrets
```

Validate config:

```bash id="qncyxx"
docker compose -f compose.yaml -f compose.prod.yaml config
```

Deploy:

```bash id="d8n6qv"
COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
```

Test:

```bash id="7oun9p"
curl -s http://127.0.0.1:8080/health | jq .
curl -s http://127.0.0.1:8080/ready | jq .
curl -s http://127.0.0.1:8080/version | jq .
curl -s http://127.0.0.1:8080/config-summary | jq .
```

Check health:

```bash id="utvuig"
docker compose -f compose.yaml -f compose.prod.yaml ps
docker inspect compose-demo-backend --format '{{json .State.Health}}' | jq .
```

Run backup job:

```bash id="8p5sdw"
docker compose --profile backup run --rm mongo-backup
ls -lh backups
```

Run debug profile:

```bash id="6a9qk6"
docker compose --profile debug up -d
docker compose exec debug sh -c "apk add --no-cache curl bind-tools >/dev/null && nslookup backend && nslookup mongo"
```

Stop debug:

```bash id="a7l7zq"
docker compose --profile debug stop debug
docker compose rm -f debug
```

---

# 25. Commit Work

Run:

```bash id="d24drr"
cd ~/devops-masterclass

git status
git add 05-application-runtime/demo-node-api/src/config.js \
        06-docker-containers

git commit -m "feat: add Docker Compose production patterns"
git push
```

---

# 26. Interview Explanation

## What are Docker Compose profiles?

Strong answer:

```text id="uy619d"
Compose profiles allow optional services to be activated only when needed. Core services start by default, while debug tools, admin UIs, backup jobs, and local-only services can be assigned to profiles and started with docker compose --profile.
```

## Why split Compose files?

Strong answer:

```text id="ru3s2o"
Splitting Compose files separates common configuration from environment-specific overrides. A base compose.yaml can define services, networks, and volumes, while compose.override.yaml customizes local development and compose.prod.yaml adds production settings like security hardening, resource limits, and restart policies.
```

## How do Compose secrets work?

Strong answer:

```text id="y03xzu"
Compose secrets are defined at the top level and granted to specific services. They are mounted as files under /run/secrets inside the container. This is safer than baking secrets into images or exposing them in Compose files, and it also supports least privilege because only selected services receive selected secrets.
```

## How do you deploy Compose safely?

Strong answer:

```text id="txusee"
A safe Compose deployment uses immutable image tags. CI builds and pushes an image tagged with the commit SHA. The server updates the image tag, pulls the image, runs docker compose up -d, then validates readiness through the public endpoint. If validation fails, rollback is done by restoring the previous image tag and redeploying.
```

## What production hardening do you apply in Compose?

Strong answer:

```text id="zg2j8z"
I publish only public entrypoint ports, keep databases on private networks, use secrets for sensitive values, add healthchecks and restart policies, limit logs, set resource constraints, run containers as non-root, use read-only filesystems where possible, drop Linux capabilities, avoid privileged mode, and use immutable image tags.
```

---

# Today’s Core Rules

```text id="ygbzm7"
Use profiles for optional services.
Use multiple Compose files for environment separation.
Use secrets for sensitive values.
Mount secrets only into services that need them.
Support *_FILE config pattern in apps.
Use immutable image tags.
Avoid latest in production.
Publish only public entrypoints.
Keep databases private.
Use healthchecks and readiness validation.
Use restart policies.
Limit logs.
Set resource constraints and verify them.
Use read-only containers where practical.
Drop capabilities where possible.
Rollback by previous image tag.
```

Next lesson:

# Lesson 6.8 — Container Security Masterclass: image scanning, non-root users, capabilities, seccomp, read-only filesystems, Docker socket risks, and supply-chain basics.

[1]: https://docs.docker.com/compose/?utm_source=chatgpt.com "Docker Compose"
[2]: https://docs.docker.com/compose/how-tos/profiles/?utm_source=chatgpt.com "Using profiles with Compose"
[3]: https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/?utm_source=chatgpt.com "Merge Compose files"
[4]: https://docs.docker.com/reference/compose-file/deploy/?utm_source=chatgpt.com "Compose Deploy Specification"
[5]: https://docs.docker.com/reference/compose-file/services/?utm_source=chatgpt.com "Define services in Docker Compose"
[6]: https://docs.docker.com/compose/how-tos/use-secrets/?utm_source=chatgpt.com "Manage secrets securely in Docker Compose"
[7]: https://docs.docker.com/reference/compose-file/secrets/?utm_source=chatgpt.com "Secrets"
[8]: https://arxiv.org/abs/2307.03958?utm_source=chatgpt.com "Secrets Revealed in Container Images: An Internet-wide Study on Occurrence and Impact"
[9]: https://docs.docker.com/engine/containers/resource_constraints/?utm_source=chatgpt.com "Resource constraints"

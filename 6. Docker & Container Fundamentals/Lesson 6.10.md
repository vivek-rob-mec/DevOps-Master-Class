# Lesson 6.10 — Docker CI/CD Pipeline Masterclass

# Build, Test, Scan, Tag, Push, Deploy with Compose, Health Validation, Rollback, and Deployment Reports

Now we connect everything into a real DevOps pipeline.

Until now, you learned pieces:

```text id="q982e1"
Dockerfile
image layers
image scanning
Docker Compose
secrets
volumes
registry
image promotion
security hardening
```

Now we create the production flow:

```text id="clhm2d"
code commit
  ↓
test
  ↓
build image
  ↓
scan image
  ↓
tag image
  ↓
push image
  ↓
deploy with Compose
  ↓
health validation
  ↓
rollback if failed
  ↓
deployment report
```

This is the same core pattern used in real companies.

Docker’s GitHub Actions documentation recommends Docker’s official actions for CI workflows, including build and push workflows using Buildx. Docker’s `build-push-action` supports BuildKit features such as multi-platform builds, secrets, and remote cache. ([Docker Documentation][1])

---

# 1. Beginner Level — What Is Docker CI/CD?

CI/CD means:

```text id="5rfxtq"
CI = Continuous Integration
CD = Continuous Delivery / Deployment
```

For Docker projects, CI/CD usually means:

```text id="56zjb3"
CI:
  test code
  build image
  scan image

CD:
  push image
  deploy image
  validate app
  rollback if needed
```

Simple mental model:

```text id="1vrn93"
Git push should create a deployable Docker image.
Approved deployment should run that exact image.
```

The key word is:

```text id="dvdeqb"
exact
```

Not “similar image.”

Not “rebuilt image.”

The same image.

---

# 2. Beginner Pipeline Flow

```text id="9g14r7"
Developer pushes code to GitHub
  ↓
GitHub Actions starts
  ↓
npm test / lint / security checks
  ↓
Docker image is built
  ↓
image is scanned
  ↓
image is pushed to registry
  ↓
server pulls image
  ↓
docker compose up -d
  ↓
curl /ready
  ↓
success or rollback
```

Production idea:

```text id="cfqgu4"
Deployment is not successful just because containers started.
Deployment is successful when health/readiness checks pass.
```

---

# 3. Professional Pipeline Stages

A professional Docker CI/CD pipeline usually has these stages:

```text id="i9ulnb"
1. Checkout source
2. Install dependencies
3. Run tests
4. Run lint/security checks
5. Build Docker image
6. Generate metadata
7. Scan image
8. Generate SBOM/provenance
9. Push immutable tags
10. Deploy to environment
11. Validate health/readiness
12. Record deployment
13. Notify team
14. Rollback if failed
```

Expert pipeline principle:

```text id="0gahyi"
Separate build from deploy.
```

Build job creates the artifact.

Deploy job promotes the artifact.

---

# 4. What We Will Create

We will add:

```text id="01qw2b"
GitHub Actions workflow for Docker build/test/scan/push
Compose deployment script improvements
rollback script
deployment report
Jenkins-style pipeline example
CI/CD documentation
Makefile targets
```

Target files:

```text id="1g2sv5"
.github/workflows/docker-ci.yml
.github/workflows/docker-cd-compose.yml

05-application-runtime/demo-node-api/scripts/docker-build.sh
05-application-runtime/demo-node-api/scripts/docker-security-scan.sh
05-application-runtime/demo-node-api/scripts/docker-tag-push.sh

06-docker-containers/compose-demo/scripts/deploy-compose.sh
06-docker-containers/compose-demo/scripts/rollback-compose.sh
06-docker-containers/compose-demo/scripts/compose-security-check.sh

06-docker-containers/docker-cicd-pipeline-masterclass.md
06-docker-containers/jenkins-docker-compose-pipeline.md
```

---

# 5. Intermediate Level — Prepare App Test Command

Go to app:

```bash id="oo0xpy"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Check `package.json`:

```bash id="xptg7s"
cat package.json | jq .
```

If it does not have a test script, add a simple smoke test script.

Create:

```bash id="q3hxsc"
mkdir -p tests
nano tests/smoke-test.js
```

Paste:

```javascript id="kawtvo"
const { readFileSync } = require("fs");

const requiredFiles = [
  "server.js",
  "src/config.js",
  "src/logger.js",
  "package.json",
  "Dockerfile.industry",
];

for (const file of requiredFiles) {
  readFileSync(file, "utf8");
}

console.log("Smoke test passed: required runtime files exist.");
```

Update `package.json`:

```bash id="nn03pz"
npm pkg set scripts.test="node tests/smoke-test.js"
```

Run:

```bash id="6b79ab"
npm test
```

Expected:

```text id="pyuvjk"
Smoke test passed: required runtime files exist.
```

This is simple. Later projects will use Jest, integration tests, API tests, etc.

---

# 6. Intermediate Level — Local CI Script

Before GitHub Actions, create a local CI script.

Create:

```bash id="2cb3ca"
nano scripts/local-docker-ci.sh
```

Paste:

```bash id="fs0s4j"
#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-0.2.0}"
IMAGE_NAME="${IMAGE_NAME:-demo-node-api}"

echo "===== Local Docker CI ====="
echo "Image: $IMAGE_NAME"
echo "Version: $VERSION"

echo
echo "1. Running tests..."
npm test

echo
echo "2. Building Docker image..."
VERSION="$VERSION" IMAGE_NAME="$IMAGE_NAME" ./scripts/docker-build.sh

echo
echo "3. Checking non-root runtime..."
docker run --rm --entrypoint id "$IMAGE_NAME:$VERSION"

echo
echo "4. Running container smoke test..."
docker rm -f ci-demo-node-api >/dev/null 2>&1 || true

docker run -d \
  --name ci-demo-node-api \
  --read-only \
  --tmpfs /tmp \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  -p 3009:3000 \
  -e APP_ENV=dev \
  -e PORT=3000 \
  "$IMAGE_NAME:$VERSION"

for attempt in {1..10}; do
  if curl -fsS http://127.0.0.1:3009/health >/dev/null; then
    echo "Container smoke test passed."
    curl -s http://127.0.0.1:3009/version | jq .
    docker rm -f ci-demo-node-api >/dev/null
    exit 0
  fi

  echo "Waiting for app health: attempt $attempt/10"
  sleep 2
done

echo "ERROR: container smoke test failed" >&2
docker logs ci-demo-node-api --tail 100 >&2 || true
docker rm -f ci-demo-node-api >/dev/null 2>&1 || true
exit 1
```

Make executable:

```bash id="qgygqf"
chmod +x scripts/local-docker-ci.sh
```

Run:

```bash id="tshjic"
VERSION=0.2.1 ./scripts/local-docker-ci.sh
```

This local script is your pipeline rehearsal.

Professional rule:

```text id="zn9x31"
Anything important in CI should be reproducible locally when possible.
```

---

# 7. GitHub Actions CI Workflow

From repo root:

```bash id="gbgjkv"
cd ~/devops-masterclass
mkdir -p .github/workflows
nano .github/workflows/docker-ci.yml
```

Paste:

```yaml id="gtbt18"
name: Docker CI

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main

permissions:
  contents: read
  packages: write
  security-events: write

env:
  APP_DIR: 05-application-runtime/demo-node-api
  IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/demo-node-api

jobs:
  docker-ci:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Compute metadata
        id: meta
        shell: bash
        run: |
          SHORT_SHA="${GITHUB_SHA::7}"

          if [[ "${GITHUB_REF_TYPE}" == "tag" ]]; then
            VERSION="${GITHUB_REF_NAME}"
          else
            VERSION="0.2.0-${SHORT_SHA}"
          fi

          echo "short_sha=${SHORT_SHA}" >> "$GITHUB_OUTPUT"
          echo "version=${VERSION}" >> "$GITHUB_OUTPUT"
          echo "image_tag=${VERSION}" >> "$GITHUB_OUTPUT"

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: npm
          cache-dependency-path: ${{ env.APP_DIR }}/package-lock.json

      - name: Install dependencies
        working-directory: ${{ env.APP_DIR }}
        run: npm ci

      - name: Run tests
        working-directory: ${{ env.APP_DIR }}
        run: npm test

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        if: github.event_name == 'push'
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build Docker image
        uses: docker/build-push-action@v6
        with:
          context: ${{ env.APP_DIR }}
          file: ${{ env.APP_DIR }}/Dockerfile.industry
          target: runtime
          push: ${{ github.event_name == 'push' }}
          tags: |
            ${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.image_tag }}
            ${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.short_sha }}
          build-args: |
            APP_VERSION=${{ steps.meta.outputs.version }}
            COMMIT_SHA=${{ steps.meta.outputs.short_sha }}
            BUILD_DATE=${{ github.event.head_commit.timestamp }}
          sbom: true
          provenance: true
```

Why this is good:

```text id="7l9faz"
runs on PR and main
tests before image build
uses npm ci
uses Buildx
logs into GHCR only on push
pushes immutable SHA/version tags
generates SBOM/provenance
uses minimal permissions
```

Docker’s `login-action` documentation recommends using a personal access token instead of a Docker Hub password for Docker Hub; for GHCR in GitHub Actions, `GITHUB_TOKEN` is commonly used with `packages: write` permission for repository packages. ([GitHub][2])

---

# 8. Add Trivy Scan to GitHub Actions

You can add Trivy after build.

For PRs, scanning local Buildx images can be tricky because `build-push-action` may not load into Docker local store unless configured. A practical professional pattern is:

```text id="1yfpzw"
PR: build/test
main: build/push, then scan pushed image
```

Add this after build step:

```yaml id="aeu88f"
      - name: Scan pushed image with Trivy
        if: github.event_name == 'push'
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.image_tag }}
          severity: HIGH,CRITICAL
          exit-code: "1"
          ignore-unfixed: true
```

If you want SARIF upload later:

```yaml id="ijyysw"
      - name: Trivy SARIF scan
        if: github.event_name == 'push'
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.image_tag }}
          format: sarif
          output: trivy-results.sarif

      - name: Upload Trivy SARIF
        if: github.event_name == 'push'
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: trivy-results.sarif
```

Professional warning:

```text id="t5ak8c"
Do not blindly fail all vulnerabilities forever without triage policy.
Start with HIGH/CRITICAL, then mature the policy.
```

---

# 9. Expert Level — Workflow Security

Important GitHub Actions security practices:

```text id="p6czeg"
pin permissions explicitly
avoid broad write permissions
avoid running untrusted PR code with secrets
use environments for deployments
use required reviewers for production
avoid long-lived cloud keys; use OIDC when possible
pin third-party actions where required by policy
protect main branch
do not echo secrets
```

GitHub environments support deployment protection rules such as manual approval, wait timers, and branch restrictions before a job can proceed. ([GitHub Docs][3])

For production CD, use:

```yaml id="6ody5c"
environment:
  name: production
```

Then configure GitHub environment protection in repository settings.

Professional rule:

```text id="h02vng"
CI can build automatically. Production deployment should usually require environment controls.
```

---

# 10. Compose CD Workflow Concept

The deployment workflow will:

```text id="v8vuau"
1. receive image tag
2. SSH into server
3. cd to Compose project
4. update .env APP_IMAGE and APP_VERSION
5. docker compose pull
6. docker compose up -d
7. health check
8. rollback if failed
```

Important:

```text id="k2xlgh"
The server should already have compose.yaml, compose.prod.yaml, secrets, and env templates configured.
```

CI/CD should not print secrets.

---

# 11. GitHub Actions CD Workflow with SSH

Create:

```bash id="qf88id"
nano .github/workflows/docker-cd-compose.yml
```

Paste:

```yaml id="9z9d62"
name: Docker Compose CD

on:
  workflow_dispatch:
    inputs:
      image_tag:
        description: "Image tag to deploy, for example 0.2.0-abc1234"
        required: true
        type: string
      environment:
        description: "Target environment"
        required: true
        default: "staging"
        type: choice
        options:
          - staging
          - production

permissions:
  contents: read

env:
  IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/demo-node-api

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: ${{ inputs.environment }}

    steps:
      - name: Deploy over SSH
        uses: appleboy/ssh-action@v1.2.0
        with:
          host: ${{ secrets.DEPLOY_HOST }}
          username: ${{ secrets.DEPLOY_USER }}
          key: ${{ secrets.DEPLOY_SSH_KEY }}
          port: ${{ secrets.DEPLOY_PORT }}
          script: |
            set -euo pipefail

            cd /srv/compose-demo

            echo "Deploying image:"
            echo "${{ env.IMAGE_NAME }}:${{ inputs.image_tag }}"

            if grep -q '^APP_IMAGE=' .env; then
              sed -i 's|^APP_IMAGE=.*|APP_IMAGE=${{ env.IMAGE_NAME }}|' .env
            else
              echo 'APP_IMAGE=${{ env.IMAGE_NAME }}' >> .env
            fi

            if grep -q '^APP_VERSION=' .env; then
              sed -i 's|^APP_VERSION=.*|APP_VERSION=${{ inputs.image_tag }}|' .env
            else
              echo 'APP_VERSION=${{ inputs.image_tag }}' >> .env
            fi

            COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
```

Required GitHub secrets:

```text id="6lofc6"
DEPLOY_HOST
DEPLOY_USER
DEPLOY_SSH_KEY
DEPLOY_PORT
```

Production environment should have manual approval.

---

# 12. Professional CD Concern — Server Registry Login

If GHCR package is private, server must login:

```bash id="xhqc4c"
echo "$GHCR_READ_TOKEN" | docker login ghcr.io -u YOUR_USER --password-stdin
```

On production server, use:

```text id="d16l90"
read-only package token
machine user
GitHub App token
cloud workload identity where possible
```

Do not use:

```text id="5a8x0j"
your personal full-access token
```

Credential location:

```bash id="ry8n4d"
cat ~/.docker/config.json
```

Restrict file permissions:

```bash id="c3ojd8"
chmod 600 ~/.docker/config.json
```

---

# 13. Improve Deploy Script with Rollback

Open:

```bash id="75tr9u"
cd ~/devops-masterclass/06-docker-containers/compose-demo
nano scripts/deploy-compose.sh
```

Replace with this more production-ready version:

```bash id="b8u88g"
#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILES="${COMPOSE_FILES:-compose.yaml compose.prod.yaml}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:8080/ready}"
VERSION_URL="${VERSION_URL:-http://127.0.0.1:8080/version}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-15}"
APP_VERSION="${APP_VERSION:-}"
APP_IMAGE="${APP_IMAGE:-}"
AUTO_ROLLBACK="${AUTO_ROLLBACK:-true}"

REPORT_DIR="${REPORT_DIR:-deployment-records}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/deploy-$TIMESTAMP.json"

mkdir -p "$REPORT_DIR"

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))'
}

write_report() {
  local status="$1"
  local message="$2"
  local backend_image="${3:-}"
  local backend_image_id="${4:-}"

  cat > "$REPORT_FILE" <<EOF
{
  "status": "$status",
  "message": $(printf "%s" "$message" | json_escape),
  "compose_files": $(printf "%s" "$COMPOSE_FILES" | json_escape),
  "health_url": $(printf "%s" "$HEALTH_URL" | json_escape),
  "version_url": $(printf "%s" "$VERSION_URL" | json_escape),
  "backend_image": $(printf "%s" "$backend_image" | json_escape),
  "backend_image_id": $(printf "%s" "$backend_image_id" | json_escape),
  "deployed_at": "$(date -Iseconds)"
}
EOF
}

compose_args=()
for file in $COMPOSE_FILES; do
  compose_args+=("-f" "$file")
done

PREVIOUS_APP_VERSION="$(grep '^APP_VERSION=' .env 2>/dev/null | cut -d= -f2- || true)"
PREVIOUS_APP_IMAGE="$(grep '^APP_IMAGE=' .env 2>/dev/null | cut -d= -f2- || true)"

echo "===== Compose Deploy ====="
echo "Compose files: $COMPOSE_FILES"
echo "Health URL: $HEALTH_URL"
echo "Auto rollback: $AUTO_ROLLBACK"
echo "Previous image: ${PREVIOUS_APP_IMAGE:-unknown}:${PREVIOUS_APP_VERSION:-unknown}"

if [ -n "$APP_IMAGE" ]; then
  echo "Updating APP_IMAGE=$APP_IMAGE"
  if grep -q '^APP_IMAGE=' .env; then
    sed -i "s|^APP_IMAGE=.*|APP_IMAGE=$APP_IMAGE|" .env
  else
    echo "APP_IMAGE=$APP_IMAGE" >> .env
  fi
fi

if [ -n "$APP_VERSION" ]; then
  echo "Updating APP_VERSION=$APP_VERSION"
  if grep -q '^APP_VERSION=' .env; then
    sed -i "s|^APP_VERSION=.*|APP_VERSION=$APP_VERSION|" .env
  else
    echo "APP_VERSION=$APP_VERSION" >> .env
  fi
fi

echo
echo "Validating compose config..."
docker compose "${compose_args[@]}" config >/tmp/compose-rendered.yaml

echo
echo "Pulling images..."
docker compose "${compose_args[@]}" pull || true

echo
echo "Starting stack..."
docker compose "${compose_args[@]}" up -d

echo
echo "Waiting for health..."
for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  if curl -fsS "$HEALTH_URL" >/dev/null; then
    echo "Health passed on attempt $attempt"

    BACKEND_IMAGE="$(docker inspect compose-demo-backend --format '{{.Config.Image}}' 2>/dev/null || true)"
    BACKEND_IMAGE_ID="$(docker inspect compose-demo-backend --format '{{.Image}}' 2>/dev/null || true)"

    curl -fsS "$VERSION_URL" | jq . || true
    docker compose "${compose_args[@]}" ps

    write_report "success" "deployment health check passed" "$BACKEND_IMAGE" "$BACKEND_IMAGE_ID"

    echo
    echo "Deployment report:"
    cat "$REPORT_FILE" | jq .
    exit 0
  fi

  echo "Health failed attempt $attempt/$MAX_ATTEMPTS"
  sleep 2
done

echo "ERROR: deployment health failed" >&2
docker compose "${compose_args[@]}" ps >&2
docker compose "${compose_args[@]}" logs --tail 100 >&2

if [ "$AUTO_ROLLBACK" = "true" ] && [ -n "$PREVIOUS_APP_VERSION" ]; then
  echo
  echo "Attempting rollback to previous version: $PREVIOUS_APP_VERSION"

  if [ -n "$PREVIOUS_APP_IMAGE" ]; then
    sed -i "s|^APP_IMAGE=.*|APP_IMAGE=$PREVIOUS_APP_IMAGE|" .env
  fi

  sed -i "s|^APP_VERSION=.*|APP_VERSION=$PREVIOUS_APP_VERSION|" .env

  docker compose "${compose_args[@]}" pull || true
  docker compose "${compose_args[@]}" up -d

  for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    if curl -fsS "$HEALTH_URL" >/dev/null; then
      echo "Rollback health passed."

      BACKEND_IMAGE="$(docker inspect compose-demo-backend --format '{{.Config.Image}}' 2>/dev/null || true)"
      BACKEND_IMAGE_ID="$(docker inspect compose-demo-backend --format '{{.Image}}' 2>/dev/null || true)"

      write_report "failed_rolled_back" "deployment failed; rollback succeeded" "$BACKEND_IMAGE" "$BACKEND_IMAGE_ID"
      cat "$REPORT_FILE" | jq .
      exit 1
    fi

    echo "Rollback health failed attempt $attempt/$MAX_ATTEMPTS"
    sleep 2
  done

  write_report "failed_rollback_failed" "deployment failed and rollback failed"
  cat "$REPORT_FILE" | jq .
  exit 1
fi

write_report "failed" "deployment health check failed and rollback was not attempted"
cat "$REPORT_FILE" | jq .
exit 1
```

Make executable:

```bash id="ltfwve"
chmod +x scripts/deploy-compose.sh
```

This script now:

```text id="kamury"
records previous image tag
deploys new version
validates health
rolls back automatically if health fails
writes JSON deployment report
```

---

# 14. Create Bad Image Test for Rollback

Build a broken image.

Go to app:

```bash id="50o75j"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Create temp broken copy:

```bash id="4w4sgi"
rm -rf /tmp/demo-node-api-broken-docker
cp -a . /tmp/demo-node-api-broken-docker
echo 'throw new Error("broken docker image for rollback test");' > /tmp/demo-node-api-broken-docker/server.js
```

Build broken image:

```bash id="onqrq1"
docker build \
  -f /tmp/demo-node-api-broken-docker/Dockerfile.industry \
  --target runtime \
  --build-arg APP_VERSION=0.2.0-broken \
  --build-arg COMMIT_SHA=broken \
  -t demo-node-api:0.2.0-broken \
  /tmp/demo-node-api-broken-docker
```

Deploy known good first:

```bash id="xvk8uf"
cd ~/devops-masterclass/06-docker-containers/compose-demo

APP_IMAGE=demo-node-api \
APP_VERSION=0.2.0 \
COMPOSE_FILES="compose.yaml compose.prod.yaml" \
./scripts/deploy-compose.sh
```

Deploy broken:

```bash id="88b1hx"
APP_IMAGE=demo-node-api \
APP_VERSION=0.2.0-broken \
COMPOSE_FILES="compose.yaml compose.prod.yaml" \
AUTO_ROLLBACK=true \
./scripts/deploy-compose.sh || true
```

Validate rollback:

```bash id="jq06er"
curl -s http://127.0.0.1:8080/version | jq .
ls -lh deployment-records
cat deployment-records/deploy-*.json | tail -n 40
```

Expected:

```text id="mjs91n"
deployment failed
rollback succeeded
app running previous good version
```

This is a real-world deployment safety pattern.

---

# 15. Jenkins Pipeline Example

Create note:

```bash id="4hxu59"
cd ~/devops-masterclass/06-docker-containers
nano jenkins-docker-compose-pipeline.md
```

Paste:

````markdown id="6q6l3m"
# Jenkins Docker Compose Pipeline

## Pipeline Flow

```text
checkout
npm ci
npm test
docker build
scan image
docker login
docker push
ssh deploy server
docker compose pull
docker compose up -d
health check
rollback if failed
````

## Jenkinsfile Example

```groovy
pipeline {
  agent any

  environment {
    APP_DIR = '05-application-runtime/demo-node-api'
    IMAGE_NAME = 'ghcr.io/YOUR_USER/demo-node-api'
    VERSION = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Test') {
      steps {
        dir("${APP_DIR}") {
          sh 'npm ci'
          sh 'npm test'
        }
      }
    }

    stage('Build Image') {
      steps {
        dir("${APP_DIR}") {
          sh '''
            docker build \
              -f Dockerfile.industry \
              --target runtime \
              --build-arg APP_VERSION=${VERSION} \
              --build-arg COMMIT_SHA=${GIT_COMMIT} \
              -t ${IMAGE_NAME}:${VERSION} \
              .
          '''
        }
      }
    }

    stage('Scan Image') {
      steps {
        sh '''
          trivy image --severity HIGH,CRITICAL --exit-code 1 ${IMAGE_NAME}:${VERSION}
        '''
      }
    }

    stage('Push Image') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'ghcr-token', usernameVariable: 'REG_USER', passwordVariable: 'REG_TOKEN')]) {
          sh '''
            echo "$REG_TOKEN" | docker login ghcr.io -u "$REG_USER" --password-stdin
            docker push ${IMAGE_NAME}:${VERSION}
          '''
        }
      }
    }

    stage('Deploy') {
      steps {
        sshagent(['compose-server-ssh']) {
          sh '''
            ssh -o StrictHostKeyChecking=no deploy@YOUR_SERVER '
              cd /srv/compose-demo &&
              APP_IMAGE=${IMAGE_NAME} APP_VERSION=${VERSION} COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
            '
          '''
        }
      }
    }
  }

  post {
    always {
      sh 'docker logout ghcr.io || true'
    }
  }
}
```

## Production Notes

* Jenkins agents need Docker access.
* Do not use personal registry tokens.
* Use Jenkins credentials.
* Scan before push or before deployment.
* Deploy immutable tags.
* Health check after deployment.
* Rollback on failed health.

````

This matches your earlier Jenkins deployment experience, but now with container images.

---

# 16. GitHub Actions vs Jenkins

| Topic | GitHub Actions | Jenkins |
|---|---|---|
| Setup | easier for GitHub repos | self-managed |
| Runners | GitHub-hosted or self-hosted | agents/nodes |
| Secrets | GitHub secrets/environments | Jenkins credentials |
| Docker access | easy on hosted Linux | agent must have Docker |
| Approval | GitHub environments | input step/plugins |
| Scaling | managed | you manage |
| Enterprise control | good | very customizable |

Professional view:

```text id="a7afw1"
GitHub Actions is excellent for GitHub-native CI/CD.
Jenkins is excellent when companies need deep customization and existing enterprise integration.
````

---

# 17. Expert Level — Deployment Strategies

With Compose on one server, common strategies are:

```text id="5pac5i"
recreate containers
health validate
rollback by previous image tag
```

Limitations:

```text id="u4hg2v"
brief downtime possible
single server is single point of failure
database migration rollback is hard
no native multi-replica rolling update like Kubernetes
```

Advanced strategies:

```text id="5htnqe"
blue-green Compose projects
Nginx upstream switch
multiple app containers behind proxy
Kubernetes rolling deployments
ECS rolling deployments
ArgoCD GitOps
```

For now, your Compose deployment is good for:

```text id="ab6jqe"
learning
small internal apps
single VM deployments
portfolio project
CI/CD fundamentals
```

---

# 18. Expert Level — Database Migration Safety

Docker deployment is easy.

Database migration is hard.

Bad flow:

```text id="tgq7gu"
deploy new app
run destructive migration
health fails
rollback app
database cannot rollback
```

Safer migration strategy:

```text id="4dxx6s"
backward-compatible schema changes
expand-contract pattern
backup before migration
migration job separated
feature flags
test migration in staging
rollback plan
```

Example expand-contract:

```text id="u1ii5p"
1. Add new column, app still supports old and new
2. Deploy app writing both
3. Backfill data
4. Switch reads
5. Remove old column later
```

Professional rule:

```text id="o1nxz9"
App rollback is easy. Data rollback requires planning.
```

---

# 19. Add Deployment Report Notes

Create:

```bash id="jzz5wb"
cd ~/devops-masterclass/06-docker-containers
nano docker-cicd-pipeline-masterclass.md
```

Paste:

````markdown id="nlvmv8"
# Docker CI/CD Pipeline Masterclass

## Pipeline Flow

```text
commit
  -> test
  -> build image
  -> scan image
  -> push immutable tag
  -> deploy with Compose
  -> health check
  -> rollback if failed
  -> deployment report
````

## CI Rules

* use `npm ci`
* run tests before image build
* build using production Dockerfile
* scan image
* generate SBOM/provenance
* push immutable tags
* do not use latest for production

## CD Rules

* server pulls from registry
* update APP_VERSION
* `docker compose pull`
* `docker compose up -d`
* validate `/ready`
* rollback on failed health
* record deployment metadata

## Deployment Report Should Include

* status
* image tag
* image ID/digest
* environment
* deployed_at
* health URL
* result message

## Rollback Rule

Rollback uses the previous image tag.

This only works if previous image still exists in registry.

## Database Warning

App rollback does not automatically rollback database migrations.
Use backward-compatible migrations and backup strategies.

````

---

# 20. Add Makefile Targets

Open Compose Makefile:

```bash id="m8xdfq"
cd ~/devops-masterclass/06-docker-containers/compose-demo
nano Makefile
````

Add:

```Makefile id="nmaw10"
.PHONY: deploy-prod rollback-prod security-check show-report

deploy-prod:
	COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh

rollback-prod:
	@test -n "$(VERSION)" || (echo "Usage: make rollback-prod VERSION=<tag>" && exit 1)
	COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/rollback-compose.sh $(VERSION)

security-check:
	COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/compose-security-check.sh

show-report:
	ls -lh deployment-records || true
	@if ls deployment-records/deploy-*.json >/dev/null 2>&1; then cat $$(ls -t deployment-records/deploy-*.json | head -n 1) | jq .; fi
```

Use:

```bash id="olbz9m"
make security-check
make deploy-prod
make show-report
make rollback-prod VERSION=0.2.0
```

---

# 21. Production Server Layout

On a real server, use:

```text id="slr8sl"
/srv/compose-demo
├── compose.yaml
├── compose.prod.yaml
├── .env
├── backend.env
├── secrets/
├── nginx/
├── scripts/
└── deployment-records/
```

Permissions:

```bash id="ylgq0q"
sudo mkdir -p /srv/compose-demo
sudo chown -R deploy:deploy /srv/compose-demo
chmod 600 /srv/compose-demo/.env
chmod 600 /srv/compose-demo/backend.env
chmod 700 /srv/compose-demo/secrets
chmod 600 /srv/compose-demo/secrets/*
```

Deploy user:

```text id="a3mic1"
should have only required permissions
should not be your personal user
should use SSH key
should have Docker access only if required
```

Professional caution:

```text id="1iwqgh"
Membership in docker group is powerful and can effectively grant root-level control on the host.
```

Use it carefully.

---

# 22. Final Local Validation

Run app CI:

```bash id="s4ogh1"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION=0.2.1 ./scripts/local-docker-ci.sh
VERSION=0.2.1 ./scripts/docker-security-scan.sh || true
```

Deploy Compose:

```bash id="ys9fzn"
cd ~/devops-masterclass/06-docker-containers/compose-demo

COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/compose-security-check.sh
APP_IMAGE=demo-node-api APP_VERSION=0.2.1 COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
```

Validate:

```bash id="9isx9g"
curl -s http://127.0.0.1:8080/health | jq .
curl -s http://127.0.0.1:8080/ready | jq .
curl -s http://127.0.0.1:8080/version | jq .
make show-report
```

Rollback test with broken image:

```bash id="sr0j96"
APP_IMAGE=demo-node-api APP_VERSION=0.2.0-broken COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh || true

curl -s http://127.0.0.1:8080/version | jq .
make show-report
```

---

# 23. Commit Work

Run:

```bash id="i4e0hz"
cd ~/devops-masterclass

git status
git add .github/workflows/docker-ci.yml \
        .github/workflows/docker-cd-compose.yml \
        05-application-runtime/demo-node-api/package.json \
        05-application-runtime/demo-node-api/tests \
        05-application-runtime/demo-node-api/scripts/local-docker-ci.sh \
        06-docker-containers

git commit -m "feat: add Docker CI/CD pipeline with Compose deployment"
git push
```

---

# 24. Interview Explanation

## Explain a Docker CI/CD pipeline.

Strong answer:

```text id="skckvl"
A Docker CI/CD pipeline checks out code, installs dependencies with a reproducible method like npm ci, runs tests, builds a production Docker image, scans it for vulnerabilities, tags it with immutable identifiers like version and Git SHA, pushes it to a registry, deploys it to the target environment, validates readiness through health checks, records deployment metadata, and rolls back to the previous image tag if validation fails.
```

## Why separate build and deploy?

Strong answer:

```text id="jlrldi"
Build creates the artifact. Deploy promotes that artifact. Separating them ensures the same tested and scanned image moves through environments instead of rebuilding different images for dev, staging, and production.
```

## How do you rollback a Compose deployment?

Strong answer:

```text id="bxk5tt"
For Compose, rollback usually means setting APP_VERSION back to the previous immutable image tag, running docker compose pull and docker compose up -d, then validating readiness. This requires previous images to remain available in the registry.
```

## What makes deployment complete?

Strong answer:

```text id="wy8dty"
Deployment is complete only after the new containers are running and the application passes health or readiness checks through the public path. Starting containers alone is not enough.
```

## What are common CI/CD security practices?

Strong answer:

```text id="hkk870"
Use least-privilege workflow permissions, protect production environments with approvals, avoid secrets in pull requests from untrusted forks, use short-lived cloud credentials or OIDC where possible, scan images before deployment, avoid latest tags, and keep registry credentials scoped to push or pull depending on the system.
```

---

# Today’s Core Rules

```text id="ze48st"
CI tests and builds.
CD deploys and validates.
Build once, promote the same image.
Use immutable tags.
Scan images before deployment.
Generate SBOM/provenance when possible.
Use registry push from CI.
Use read-only pull credentials on servers.
Deploy with docker compose pull + up -d.
Validate /ready after deployment.
Rollback by previous image tag.
Write deployment reports.
Production deployments should use environment protections.
Database migrations need separate rollback planning.
```

Next lesson:

# Lesson 6.11 — Docker Troubleshooting Masterclass: build failures, container exits, networking failures, volume issues, Compose debugging, image pull errors, performance problems, and incident-style playbooks.

[1]: https://docs.docker.com/build/ci/github-actions/?utm_source=chatgpt.com "Docker Build GitHub Actions"
[2]: https://github.com/docker/login-action?utm_source=chatgpt.com "GitHub Action to login against a Docker registry"
[3]: https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments?utm_source=chatgpt.com "Deployments and environments"

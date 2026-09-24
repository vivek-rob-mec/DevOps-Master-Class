# Lesson 8.10 — Deployment and Rollback Pipelines

# Staging Deploy, Production Approval, Health Checks, Version Checks, Smoke Tests, Deployment Reports, Automatic Rollback, Manual Rollback, GitHub Actions, Jenkins, GitLab CI, and SSH/Compose Deployment Pattern

In Lesson 8.9, you built quality gates.

Now we move to the next critical CI/CD layer:

```text
deployment and rollback
```

A production pipeline is incomplete unless it can answer:

```text
What artifact was deployed?
Where was it deployed?
Who approved it?
Did health checks pass?
Did the version match?
What was the previous version?
Can rollback happen quickly?
Was rollback tested?
Where is the deployment report?
```

Professional rule:

```text
Deployment is not complete when the command finishes.
Deployment is complete when the expected version is healthy and verified.
```

---

# 1. Deployment Pipeline Mental Model

A deployment pipeline moves a trusted artifact into an environment.

```text
trusted artifact
  ↓
validate deploy input
  ↓
check environment
  ↓
deploy artifact
  ↓
health check
  ↓
readiness check
  ↓
version check
  ↓
smoke test
  ↓
record deployment
  ↓
rollback if failed
```

For your project:

```text
demo-node-api:0.8.0-dev-a1b2c3d
  ↓
Docker Compose deployment
  ↓
/health check
  ↓
/ready check
  ↓
/version check
  ↓
deployment report
  ↓
rollback to previous known-good image if failed
```

---

# 2. Deployment vs Promotion

Do not confuse these.

## Promotion

Promotion means:

```text
This artifact is approved for an environment.
```

Example:

```text
demo-node-api:0.8.0-a1b2c3d is approved for staging.
```

## Deployment

Deployment means:

```text
This artifact is now running in the environment.
```

Example:

```text
demo-node-api:0.8.0-a1b2c3d is running on staging.
```

Professional rule:

```text
Promotion is a decision.
Deployment is an action.
Verification proves the action worked.
```

---

# 3. Rollback Mental Model

Rollback means returning to a previous known-good artifact.

Bad rollback:

```text
rebuild old code and hope it works
```

Good rollback:

```text
redeploy previous immutable image tag
```

Example:

```text
current failed:
  demo-node-api:0.8.0-a1b2c3d

rollback target:
  demo-node-api:0.7.0-f9e8d7c
```

Professional rule:

```text
Rollback should use a known artifact, not a new build.
```

---

# 4. Deployment Safety Requirements

Before deployment:

```text
artifact tag is immutable
artifact is not latest
artifact passed tests
artifact passed quality gates
artifact has release metadata
rollback version is known
environment is approved
secrets are available only to target environment
```

After deployment:

```text
container is running
health endpoint passes
readiness endpoint passes
version endpoint matches expected version
smoke test passes
deployment report is archived
previous version is stored
rollback command is available
```

---

# 5. Deployment Modes

Common deployment modes:

```text
local Compose:
  Jenkins or local machine runs docker compose directly

SSH Compose:
  CI connects to server and runs controlled deployment script

Kubernetes:
  CI updates deployment image and waits for rollout

ECS:
  CI updates service/task definition

GitOps:
  CI updates environment repo, ArgoCD/Flux deploys

Platform deploy:
  CI calls deployment platform API
```

In this lesson, we focus on:

```text
SSH/Compose and local Compose
```

because your project already has Compose deployment scripts from Module 6.

---

# 6. Create Deployment Lesson Directory

Run:

```bash
cd ~/devops-masterclass/08-cicd-pipelines

mkdir -p deployment-rollback/{scripts,github-actions,jenkins,gitlab,notes,runbooks,reports,examples,policies}
```

Check:

```bash
tree -L 2 deployment-rollback
```

Expected:

```text
deployment-rollback
├── examples
├── github-actions
├── gitlab
├── jenkins
├── notes
├── policies
├── reports
├── runbooks
└── scripts
```

---

# 7. Deployment Policy

Create:

```bash
nano deployment-rollback/policies/demo-node-api-deployment-policy.json
```

Paste:

```json
{
  "service_name": "demo-node-api",
  "policy_version": "1.0",
  "allowed_environments": ["staging", "production"],
  "forbidden_tags": ["latest", "prod", "production", "stable"],
  "required_before_staging": [
    "test_status_passed",
    "quality_gates_passed",
    "release_metadata_exists",
    "rollback_version_known"
  ],
  "required_before_production": [
    "test_status_passed",
    "quality_gates_passed",
    "release_metadata_exists",
    "promotion_record_exists",
    "manual_approval",
    "rollback_version_known",
    "health_check_defined",
    "version_check_defined"
  ],
  "verification": {
    "health_endpoint": "/health",
    "ready_endpoint": "/ready",
    "version_endpoint": "/version",
    "max_attempts": 20,
    "sleep_seconds": 3
  },
  "rollback": {
    "automatic_on_failed_verification": true,
    "manual_rollback_supported": true,
    "rollback_artifact_must_be_immutable": true
  }
}
```

This policy says:

```text
Do not deploy mutable tags.
Always know rollback before production.
Verify runtime after deploy.
Rollback automatically when verification fails.
```

---

# 8. Deployment Input Validator

Create:

```bash
nano deployment-rollback/scripts/validate-deployment-inputs.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_ENV="${TARGET_ENV:-}"
APP_IMAGE="${APP_IMAGE:-}"
APP_VERSION="${APP_VERSION:-}"
ROLLBACK_VERSION="${ROLLBACK_VERSION:-}"
REQUIRE_ROLLBACK="${REQUIRE_ROLLBACK:-true}"

if [ -z "$TARGET_ENV" ]; then
  echo "ERROR: TARGET_ENV is required" >&2
  exit 1
fi

if [ -z "$APP_IMAGE" ]; then
  echo "ERROR: APP_IMAGE is required" >&2
  exit 1
fi

if [ -z "$APP_VERSION" ]; then
  echo "ERROR: APP_VERSION is required" >&2
  exit 1
fi

case "$TARGET_ENV" in
  staging|production)
    ;;
  *)
    echo "ERROR: unsupported TARGET_ENV=$TARGET_ENV" >&2
    exit 1
    ;;
esac

case "$APP_VERSION" in
  latest|prod|production|stable)
    echo "ERROR: refusing mutable or unsafe APP_VERSION=$APP_VERSION" >&2
    exit 1
    ;;
esac

if [[ "$APP_VERSION" != *"-"* ]]; then
  echo "WARNING: APP_VERSION does not look like version-sha format: $APP_VERSION"
fi

if [ "$REQUIRE_ROLLBACK" = "true" ] && [ -z "$ROLLBACK_VERSION" ]; then
  echo "ERROR: ROLLBACK_VERSION is required" >&2
  exit 1
fi

if [ -n "$ROLLBACK_VERSION" ]; then
  case "$ROLLBACK_VERSION" in
    latest|prod|production|stable)
      echo "ERROR: refusing unsafe ROLLBACK_VERSION=$ROLLBACK_VERSION" >&2
      exit 1
      ;;
  esac
fi

echo "Deployment inputs valid."
echo "Target: $TARGET_ENV"
echo "Image: $APP_IMAGE:$APP_VERSION"
echo "Rollback: ${ROLLBACK_VERSION:-not-set}"
```

Make executable:

```bash
chmod +x deployment-rollback/scripts/validate-deployment-inputs.sh
```

Test:

```bash
TARGET_ENV=staging \
APP_IMAGE=demo-node-api \
APP_VERSION=0.8.0-dev-a1b2c3d \
ROLLBACK_VERSION=0.7.0-f9e8d7c \
./deployment-rollback/scripts/validate-deployment-inputs.sh
```

---

# 9. Runtime Verification Script

Create:

```bash
nano deployment-rollback/scripts/verify-runtime.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
EXPECTED_VERSION="${EXPECTED_VERSION:-}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-20}"
SLEEP_SECONDS="${SLEEP_SECONDS:-3}"
REPORT_DIR="${REPORT_DIR:-deployment-rollback/reports}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/runtime-verification-$TIMESTAMP.json"

mkdir -p "$REPORT_DIR"

echo "===== Runtime Verification ====="
echo "Base URL: $BASE_URL"
echo "Expected version: ${EXPECTED_VERSION:-not-set}"

STATUS="failed"
HEALTH_RESPONSE=""
READY_RESPONSE=""
VERSION_RESPONSE=""

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  echo "Attempt $attempt/$MAX_ATTEMPTS"

  if HEALTH_RESPONSE="$(curl -fsS "$BASE_URL/health" 2>/dev/null)" &&
     READY_RESPONSE="$(curl -fsS "$BASE_URL/ready" 2>/dev/null)"; then

    VERSION_RESPONSE="$(curl -fsS "$BASE_URL/version" 2>/dev/null || true)"

    if [ -n "$EXPECTED_VERSION" ]; then
      if echo "$VERSION_RESPONSE" | grep -q "$EXPECTED_VERSION"; then
        STATUS="passed"
        break
      else
        echo "Version endpoint responded, but expected version not found yet."
      fi
    else
      STATUS="passed"
      break
    fi
  fi

  sleep "$SLEEP_SECONDS"
done

cat > "$REPORT_FILE" <<EOF
{
  "base_url": "$BASE_URL",
  "expected_version": "$EXPECTED_VERSION",
  "status": "$STATUS",
  "health_response": $(printf '%s' "$HEALTH_RESPONSE" | jq -Rs .),
  "ready_response": $(printf '%s' "$READY_RESPONSE" | jq -Rs .),
  "version_response": $(printf '%s' "$VERSION_RESPONSE" | jq -Rs .),
  "max_attempts": "$MAX_ATTEMPTS",
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$REPORT_FILE" | jq .
echo "Verification report: $REPORT_FILE"

if [ "$STATUS" != "passed" ]; then
  echo "ERROR: runtime verification failed" >&2
  exit 1
fi

echo "Runtime verification passed."
```

Make executable:

```bash
chmod +x deployment-rollback/scripts/verify-runtime.sh
```

Test after app is running:

```bash
BASE_URL=http://127.0.0.1:8080 \
EXPECTED_VERSION=0.8.0-dev-a1b2c3d \
./deployment-rollback/scripts/verify-runtime.sh
```

---

# 10. Smoke Test Script

Create:

```bash
nano deployment-rollback/scripts/smoke-test.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
REPORT_DIR="${REPORT_DIR:-deployment-rollback/reports}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/smoke-test-$TIMESTAMP.json"

mkdir -p "$REPORT_DIR"

echo "===== Smoke Test ====="
echo "Base URL: $BASE_URL"

ROOT_STATUS="failed"
CONFIG_STATUS="failed"
VERSION_STATUS="failed"

ROOT_RESPONSE="$(curl -fsS "$BASE_URL/" 2>/dev/null || true)"
if [ -n "$ROOT_RESPONSE" ]; then
  ROOT_STATUS="passed"
fi

CONFIG_RESPONSE="$(curl -fsS "$BASE_URL/config-summary" 2>/dev/null || true)"
if [ -n "$CONFIG_RESPONSE" ]; then
  CONFIG_STATUS="passed"
fi

VERSION_RESPONSE="$(curl -fsS "$BASE_URL/version" 2>/dev/null || true)"
if [ -n "$VERSION_RESPONSE" ]; then
  VERSION_STATUS="passed"
fi

OVERALL="failed"
if [ "$ROOT_STATUS" = "passed" ] && [ "$VERSION_STATUS" = "passed" ]; then
  OVERALL="passed"
fi

cat > "$REPORT_FILE" <<EOF
{
  "base_url": "$BASE_URL",
  "overall_status": "$OVERALL",
  "checks": {
    "root": "$ROOT_STATUS",
    "config_summary": "$CONFIG_STATUS",
    "version": "$VERSION_STATUS"
  },
  "version_response": $(printf '%s' "$VERSION_RESPONSE" | jq -Rs .),
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$REPORT_FILE" | jq .
echo "Smoke test report: $REPORT_FILE"

if [ "$OVERALL" != "passed" ]; then
  echo "ERROR: smoke test failed" >&2
  exit 1
fi

echo "Smoke test passed."
```

Make executable:

```bash
chmod +x deployment-rollback/scripts/smoke-test.sh
```

---

# 11. Deployment Record Script

Create:

```bash
nano deployment-rollback/scripts/create-deployment-record.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"
TARGET_ENV="${TARGET_ENV:-}"
APP_IMAGE="${APP_IMAGE:-}"
APP_VERSION="${APP_VERSION:-}"
ROLLBACK_VERSION="${ROLLBACK_VERSION:-}"
DEPLOYMENT_STATUS="${DEPLOYMENT_STATUS:-unknown}"
DEPLOYED_BY="${DEPLOYED_BY:-$(whoami)}"
CI_SYSTEM="${CI_SYSTEM:-local}"
BUILD_URL_VALUE="${BUILD_URL:-}"
REPORT_DIR="${REPORT_DIR:-deployment-rollback/reports}"

if [ -z "$TARGET_ENV" ] || [ -z "$APP_IMAGE" ] || [ -z "$APP_VERSION" ]; then
  echo "ERROR: TARGET_ENV, APP_IMAGE, APP_VERSION are required" >&2
  exit 1
fi

mkdir -p "$REPORT_DIR"

SAFE_ENV="$(echo "$TARGET_ENV" | tr '/:@' '____')"
SAFE_VERSION="$(echo "$APP_VERSION" | tr '/:@' '____')"
OUTPUT_FILE="$REPORT_DIR/deployment-$SAFE_ENV-$SAFE_VERSION.json"

cat > "$OUTPUT_FILE" <<EOF
{
  "service_name": "$SERVICE_NAME",
  "target_environment": "$TARGET_ENV",
  "artifact": "$APP_IMAGE:$APP_VERSION",
  "app_image": "$APP_IMAGE",
  "app_version": "$APP_VERSION",
  "rollback_version": "$ROLLBACK_VERSION",
  "deployment_status": "$DEPLOYMENT_STATUS",
  "deployed_by": "$DEPLOYED_BY",
  "ci_system": "$CI_SYSTEM",
  "build_url": "$BUILD_URL_VALUE",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$OUTPUT_FILE" | jq .
echo "Deployment record: $OUTPUT_FILE"
```

Make executable:

```bash
chmod +x deployment-rollback/scripts/create-deployment-record.sh
```

---

# 12. Local Compose Deployment Orchestrator

This script uses your existing Module 6 Compose deployment scripts.

Create:

```bash
nano deployment-rollback/scripts/deploy-compose-local.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
MODULE8_DIR="$ROOT_DIR/08-cicd-pipelines"
COMPOSE_DIR="${COMPOSE_DIR:-$ROOT_DIR/06-docker-containers/compose-demo}"

TARGET_ENV="${TARGET_ENV:-staging}"
APP_IMAGE="${APP_IMAGE:-}"
APP_VERSION="${APP_VERSION:-}"
ROLLBACK_VERSION="${ROLLBACK_VERSION:-}"
BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
COMPOSE_FILES="${COMPOSE_FILES:-compose.yaml compose.prod.yaml}"
AUTO_ROLLBACK="${AUTO_ROLLBACK:-true}"

cd "$MODULE8_DIR"

TARGET_ENV="$TARGET_ENV" \
APP_IMAGE="$APP_IMAGE" \
APP_VERSION="$APP_VERSION" \
ROLLBACK_VERSION="$ROLLBACK_VERSION" \
REQUIRE_ROLLBACK=true \
./deployment-rollback/scripts/validate-deployment-inputs.sh

echo "===== Local Compose Deployment ====="
echo "Compose dir: $COMPOSE_DIR"
echo "Target: $TARGET_ENV"
echo "Artifact: $APP_IMAGE:$APP_VERSION"

cd "$COMPOSE_DIR"

set +e
APP_IMAGE="$APP_IMAGE" \
APP_VERSION="$APP_VERSION" \
COMPOSE_FILES="$COMPOSE_FILES" \
./scripts/deploy-compose.sh
DEPLOY_EXIT=$?
set -e

cd "$MODULE8_DIR"

if [ "$DEPLOY_EXIT" -ne 0 ]; then
  echo "Deployment command failed."

  if [ "$AUTO_ROLLBACK" = "true" ]; then
    echo "Attempting rollback to $ROLLBACK_VERSION"

    cd "$COMPOSE_DIR"
    APP_IMAGE="$APP_IMAGE" \
    APP_VERSION="$ROLLBACK_VERSION" \
    COMPOSE_FILES="$COMPOSE_FILES" \
    ./scripts/deploy-compose.sh || true
    cd "$MODULE8_DIR"

    TARGET_ENV="$TARGET_ENV" \
    APP_IMAGE="$APP_IMAGE" \
    APP_VERSION="$APP_VERSION" \
    ROLLBACK_VERSION="$ROLLBACK_VERSION" \
    DEPLOYMENT_STATUS="failed_rolled_back" \
    CI_SYSTEM="${CI_SYSTEM:-local}" \
    ./deployment-rollback/scripts/create-deployment-record.sh
  fi

  exit 1
fi

set +e
BASE_URL="$BASE_URL" \
EXPECTED_VERSION="$APP_VERSION" \
./deployment-rollback/scripts/verify-runtime.sh
VERIFY_EXIT=$?
set -e

if [ "$VERIFY_EXIT" -ne 0 ]; then
  echo "Verification failed."

  if [ "$AUTO_ROLLBACK" = "true" ]; then
    echo "Attempting rollback to $ROLLBACK_VERSION"

    cd "$COMPOSE_DIR"
    APP_IMAGE="$APP_IMAGE" \
    APP_VERSION="$ROLLBACK_VERSION" \
    COMPOSE_FILES="$COMPOSE_FILES" \
    ./scripts/deploy-compose.sh || true
    cd "$MODULE8_DIR"

    TARGET_ENV="$TARGET_ENV" \
    APP_IMAGE="$APP_IMAGE" \
    APP_VERSION="$APP_VERSION" \
    ROLLBACK_VERSION="$ROLLBACK_VERSION" \
    DEPLOYMENT_STATUS="verification_failed_rolled_back" \
    CI_SYSTEM="${CI_SYSTEM:-local}" \
    ./deployment-rollback/scripts/create-deployment-record.sh
  fi

  exit 1
fi

BASE_URL="$BASE_URL" ./deployment-rollback/scripts/smoke-test.sh

TARGET_ENV="$TARGET_ENV" \
APP_IMAGE="$APP_IMAGE" \
APP_VERSION="$APP_VERSION" \
ROLLBACK_VERSION="$ROLLBACK_VERSION" \
DEPLOYMENT_STATUS="success" \
CI_SYSTEM="${CI_SYSTEM:-local}" \
./deployment-rollback/scripts/create-deployment-record.sh

echo "Deployment completed successfully."
```

Make executable:

```bash
chmod +x deployment-rollback/scripts/deploy-compose-local.sh
```

Run example:

```bash
cd ~/devops-masterclass/08-cicd-pipelines

TARGET_ENV=staging \
APP_IMAGE=demo-node-api \
APP_VERSION=0.8.0-dev-a1b2c3d \
ROLLBACK_VERSION=0.7.0-f9e8d7c \
BASE_URL=http://127.0.0.1:8080 \
./deployment-rollback/scripts/deploy-compose-local.sh
```

---

# 13. Manual Rollback Script

Create:

```bash
nano deployment-rollback/scripts/rollback-compose-local.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
MODULE8_DIR="$ROOT_DIR/08-cicd-pipelines"
COMPOSE_DIR="${COMPOSE_DIR:-$ROOT_DIR/06-docker-containers/compose-demo}"

TARGET_ENV="${TARGET_ENV:-staging}"
APP_IMAGE="${APP_IMAGE:-}"
ROLLBACK_VERSION="${ROLLBACK_VERSION:-}"
BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
COMPOSE_FILES="${COMPOSE_FILES:-compose.yaml compose.prod.yaml}"

if [ -z "$APP_IMAGE" ] || [ -z "$ROLLBACK_VERSION" ]; then
  echo "ERROR: APP_IMAGE and ROLLBACK_VERSION are required" >&2
  exit 1
fi

case "$ROLLBACK_VERSION" in
  latest|prod|production|stable)
    echo "ERROR: refusing unsafe rollback version: $ROLLBACK_VERSION" >&2
    exit 1
    ;;
esac

echo "===== Manual Rollback ====="
echo "Target: $TARGET_ENV"
echo "Rollback artifact: $APP_IMAGE:$ROLLBACK_VERSION"

cd "$COMPOSE_DIR"

APP_IMAGE="$APP_IMAGE" \
APP_VERSION="$ROLLBACK_VERSION" \
COMPOSE_FILES="$COMPOSE_FILES" \
./scripts/deploy-compose.sh

cd "$MODULE8_DIR"

BASE_URL="$BASE_URL" \
EXPECTED_VERSION="$ROLLBACK_VERSION" \
./deployment-rollback/scripts/verify-runtime.sh

BASE_URL="$BASE_URL" \
./deployment-rollback/scripts/smoke-test.sh

TARGET_ENV="$TARGET_ENV" \
APP_IMAGE="$APP_IMAGE" \
APP_VERSION="$ROLLBACK_VERSION" \
ROLLBACK_VERSION="$ROLLBACK_VERSION" \
DEPLOYMENT_STATUS="manual_rollback_success" \
CI_SYSTEM="${CI_SYSTEM:-local}" \
./deployment-rollback/scripts/create-deployment-record.sh

echo "Manual rollback completed."
```

Make executable:

```bash
chmod +x deployment-rollback/scripts/rollback-compose-local.sh
```

Run:

```bash
TARGET_ENV=production \
APP_IMAGE=demo-node-api \
ROLLBACK_VERSION=0.7.0-f9e8d7c \
BASE_URL=http://127.0.0.1:8080 \
./deployment-rollback/scripts/rollback-compose-local.sh
```

---

# 14. GitHub Actions Deployment Workflow

Create:

```bash
nano deployment-rollback/github-actions/deploy-compose.yml
```

Paste:

```yaml
name: Deploy Compose

on:
  workflow_dispatch:
    inputs:
      target_environment:
        description: "Target environment"
        required: true
        default: "staging"
        type: choice
        options:
          - staging
          - production
      app_image:
        description: "Image repository, for example ghcr.io/user/demo-node-api"
        required: true
        type: string
      app_version:
        description: "Immutable image tag"
        required: true
        type: string
      rollback_version:
        description: "Previous known-good immutable tag"
        required: true
        type: string
      deploy_mode:
        description: "Deployment mode"
        required: true
        default: "dry-run"
        type: choice
        options:
          - dry-run
          - ssh-compose

permissions:
  contents: read

concurrency:
  group: deploy-${{ inputs.target_environment }}
  cancel-in-progress: false

jobs:
  validate:
    runs-on: ubuntu-latest
    outputs:
      target_environment: ${{ inputs.target_environment }}
      app_image: ${{ inputs.app_image }}
      app_version: ${{ inputs.app_version }}
      rollback_version: ${{ inputs.rollback_version }}
      deploy_mode: ${{ inputs.deploy_mode }}

    steps:
      - uses: actions/checkout@v4

      - name: Validate deployment inputs
        run: |
          cd 08-cicd-pipelines
          TARGET_ENV="${{ inputs.target_environment }}" \
          APP_IMAGE="${{ inputs.app_image }}" \
          APP_VERSION="${{ inputs.app_version }}" \
          ROLLBACK_VERSION="${{ inputs.rollback_version }}" \
          ./deployment-rollback/scripts/validate-deployment-inputs.sh

  deploy:
    runs-on: ubuntu-latest
    needs: validate
    environment: ${{ needs.validate.outputs.target_environment }}

    steps:
      - uses: actions/checkout@v4

      - name: Dry-run deployment record
        if: ${{ needs.validate.outputs.deploy_mode == 'dry-run' }}
        run: |
          cd 08-cicd-pipelines
          TARGET_ENV="${{ needs.validate.outputs.target_environment }}" \
          APP_IMAGE="${{ needs.validate.outputs.app_image }}" \
          APP_VERSION="${{ needs.validate.outputs.app_version }}" \
          ROLLBACK_VERSION="${{ needs.validate.outputs.rollback_version }}" \
          DEPLOYMENT_STATUS="dry_run_success" \
          CI_SYSTEM="github-actions" \
          ./deployment-rollback/scripts/create-deployment-record.sh

      - name: Configure SSH key
        if: ${{ needs.validate.outputs.deploy_mode == 'ssh-compose' }}
        run: |
          mkdir -p ~/.ssh
          chmod 700 ~/.ssh
          printf '%s\n' "${{ secrets.DEPLOY_SSH_KEY }}" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519
          ssh-keyscan -H "${{ secrets.DEPLOY_HOST }}" >> ~/.ssh/known_hosts

      - name: Deploy over SSH using remote Compose script
        if: ${{ needs.validate.outputs.deploy_mode == 'ssh-compose' }}
        run: |
          ssh "${{ secrets.DEPLOY_USER }}@${{ secrets.DEPLOY_HOST }}" \
            "cd '${{ secrets.DEPLOY_PATH }}' && \
             TARGET_ENV='${{ needs.validate.outputs.target_environment }}' \
             APP_IMAGE='${{ needs.validate.outputs.app_image }}' \
             APP_VERSION='${{ needs.validate.outputs.app_version }}' \
             ROLLBACK_VERSION='${{ needs.validate.outputs.rollback_version }}' \
             BASE_URL='${{ secrets.DEPLOY_BASE_URL }}' \
             CI_SYSTEM='github-actions' \
             ./08-cicd-pipelines/deployment-rollback/scripts/deploy-compose-local.sh"

      - name: Upload deployment reports
        uses: actions/upload-artifact@v4
        with:
          name: deployment-reports-${{ needs.validate.outputs.target_environment }}-${{ needs.validate.outputs.app_version }}
          path: 08-cicd-pipelines/deployment-rollback/reports/
          if-no-files-found: ignore
```

Copy to workflow path:

```bash
cd ~/devops-masterclass

cp 08-cicd-pipelines/deployment-rollback/github-actions/deploy-compose.yml \
   .github/workflows/deploy-compose.yml
```

GitHub environment setup:

```text
Settings
  -> Environments
  -> staging
  -> production
```

For production, configure required reviewers.

Required secrets for `ssh-compose` mode:

```text
DEPLOY_HOST
DEPLOY_USER
DEPLOY_SSH_KEY
DEPLOY_PATH
DEPLOY_BASE_URL
```

Example:

```text
DEPLOY_PATH=/home/ubuntu/devops-masterclass
DEPLOY_BASE_URL=http://127.0.0.1:8080
```

Professional rule:

```text
GitHub production deploy jobs should use environments and required reviewers.
```

---

# 15. GitHub Actions Manual Rollback Workflow

Create:

```bash
nano deployment-rollback/github-actions/rollback-compose.yml
```

Paste:

```yaml
name: Rollback Compose

on:
  workflow_dispatch:
    inputs:
      target_environment:
        required: true
        default: "production"
        type: choice
        options:
          - staging
          - production
      app_image:
        required: true
        type: string
      rollback_version:
        required: true
        type: string
      rollback_mode:
        required: true
        default: "dry-run"
        type: choice
        options:
          - dry-run
          - ssh-compose

permissions:
  contents: read

concurrency:
  group: rollback-${{ inputs.target_environment }}
  cancel-in-progress: false

jobs:
  rollback:
    runs-on: ubuntu-latest
    environment: ${{ inputs.target_environment }}

    steps:
      - uses: actions/checkout@v4

      - name: Validate rollback input
        run: |
          cd 08-cicd-pipelines

          TARGET_ENV="${{ inputs.target_environment }}" \
          APP_IMAGE="${{ inputs.app_image }}" \
          APP_VERSION="${{ inputs.rollback_version }}" \
          ROLLBACK_VERSION="${{ inputs.rollback_version }}" \
          REQUIRE_ROLLBACK=false \
          ./deployment-rollback/scripts/validate-deployment-inputs.sh

      - name: Dry-run rollback record
        if: ${{ inputs.rollback_mode == 'dry-run' }}
        run: |
          cd 08-cicd-pipelines

          TARGET_ENV="${{ inputs.target_environment }}" \
          APP_IMAGE="${{ inputs.app_image }}" \
          APP_VERSION="${{ inputs.rollback_version }}" \
          ROLLBACK_VERSION="${{ inputs.rollback_version }}" \
          DEPLOYMENT_STATUS="rollback_dry_run_success" \
          CI_SYSTEM="github-actions" \
          ./deployment-rollback/scripts/create-deployment-record.sh

      - name: Configure SSH key
        if: ${{ inputs.rollback_mode == 'ssh-compose' }}
        run: |
          mkdir -p ~/.ssh
          chmod 700 ~/.ssh
          printf '%s\n' "${{ secrets.DEPLOY_SSH_KEY }}" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519
          ssh-keyscan -H "${{ secrets.DEPLOY_HOST }}" >> ~/.ssh/known_hosts

      - name: Rollback over SSH
        if: ${{ inputs.rollback_mode == 'ssh-compose' }}
        run: |
          ssh "${{ secrets.DEPLOY_USER }}@${{ secrets.DEPLOY_HOST }}" \
            "cd '${{ secrets.DEPLOY_PATH }}' && \
             TARGET_ENV='${{ inputs.target_environment }}' \
             APP_IMAGE='${{ inputs.app_image }}' \
             ROLLBACK_VERSION='${{ inputs.rollback_version }}' \
             BASE_URL='${{ secrets.DEPLOY_BASE_URL }}' \
             CI_SYSTEM='github-actions' \
             ./08-cicd-pipelines/deployment-rollback/scripts/rollback-compose-local.sh"
```

Copy:

```bash
cd ~/devops-masterclass

cp 08-cicd-pipelines/deployment-rollback/github-actions/rollback-compose.yml \
   .github/workflows/rollback-compose.yml
```

---

# 16. Jenkins Deployment Pipeline

Create:

```bash
cd ~/devops-masterclass/08-cicd-pipelines

nano deployment-rollback/jenkins/Jenkinsfile.deploy-compose
```

Paste:

```groovy
pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    timeout(time: 45, unit: 'MINUTES')
  }

  parameters {
    choice(name: 'TARGET_ENV', choices: ['staging', 'production'], description: 'Target environment')
    string(name: 'APP_IMAGE', defaultValue: 'demo-node-api', description: 'Image repository')
    string(name: 'APP_VERSION', defaultValue: '', description: 'Immutable image tag to deploy')
    string(name: 'ROLLBACK_VERSION', defaultValue: '', description: 'Previous known-good immutable tag')
    choice(name: 'DEPLOY_MODE', choices: ['dry-run', 'local-compose'], description: 'Deployment mode')
    booleanParam(name: 'AUTO_ROLLBACK', defaultValue: true, description: 'Rollback automatically if verification fails?')
  }

  environment {
    MODULE8_DIR = '08-cicd-pipelines'
    BASE_URL = 'http://127.0.0.1:8080'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Validate Inputs') {
      steps {
        dir("${MODULE8_DIR}") {
          sh '''
            TARGET_ENV="${TARGET_ENV}" \
            APP_IMAGE="${APP_IMAGE}" \
            APP_VERSION="${APP_VERSION}" \
            ROLLBACK_VERSION="${ROLLBACK_VERSION}" \
            ./deployment-rollback/scripts/validate-deployment-inputs.sh
          '''
        }
      }
    }

    stage('Production Approval') {
      when {
        expression { return params.TARGET_ENV == 'production' }
      }

      steps {
        input message: "Deploy ${params.APP_IMAGE}:${params.APP_VERSION} to production? Rollback: ${params.ROLLBACK_VERSION}",
              ok: 'Deploy Production'
      }
    }

    stage('Dry Run') {
      when {
        expression { return params.DEPLOY_MODE == 'dry-run' }
      }

      steps {
        dir("${MODULE8_DIR}") {
          sh '''
            TARGET_ENV="${TARGET_ENV}" \
            APP_IMAGE="${APP_IMAGE}" \
            APP_VERSION="${APP_VERSION}" \
            ROLLBACK_VERSION="${ROLLBACK_VERSION}" \
            DEPLOYMENT_STATUS="jenkins_dry_run_success" \
            CI_SYSTEM="jenkins" \
            ./deployment-rollback/scripts/create-deployment-record.sh
          '''
        }
      }
    }

    stage('Deploy Local Compose') {
      when {
        expression { return params.DEPLOY_MODE == 'local-compose' }
      }

      steps {
        dir("${MODULE8_DIR}") {
          sh '''
            TARGET_ENV="${TARGET_ENV}" \
            APP_IMAGE="${APP_IMAGE}" \
            APP_VERSION="${APP_VERSION}" \
            ROLLBACK_VERSION="${ROLLBACK_VERSION}" \
            BASE_URL="${BASE_URL}" \
            AUTO_ROLLBACK="${AUTO_ROLLBACK}" \
            CI_SYSTEM="jenkins" \
            ./deployment-rollback/scripts/deploy-compose-local.sh
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '08-cicd-pipelines/deployment-rollback/reports/**/*', allowEmptyArchive: true
    }

    success {
      echo "Deployment pipeline succeeded."
    }

    failure {
      echo "Deployment pipeline failed. Check deployment reports."
    }
  }
}
```

Jenkins job setup:

```text
Pipeline from SCM
Script Path:
08-cicd-pipelines/deployment-rollback/jenkins/Jenkinsfile.deploy-compose
```

Safe first run:

```text
TARGET_ENV=staging
APP_IMAGE=demo-node-api
APP_VERSION=0.8.0-dev-a1b2c3d
ROLLBACK_VERSION=0.7.0-f9e8d7c
DEPLOY_MODE=dry-run
AUTO_ROLLBACK=true
```

---

# 17. Jenkins Manual Rollback Pipeline

Create:

```bash
nano deployment-rollback/jenkins/Jenkinsfile.rollback-compose
```

Paste:

```groovy
pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    timeout(time: 30, unit: 'MINUTES')
  }

  parameters {
    choice(name: 'TARGET_ENV', choices: ['staging', 'production'], description: 'Target environment')
    string(name: 'APP_IMAGE', defaultValue: 'demo-node-api', description: 'Image repository')
    string(name: 'ROLLBACK_VERSION', defaultValue: '', description: 'Rollback image tag')
    choice(name: 'ROLLBACK_MODE', choices: ['dry-run', 'local-compose'], description: 'Rollback mode')
  }

  environment {
    MODULE8_DIR = '08-cicd-pipelines'
    BASE_URL = 'http://127.0.0.1:8080'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Validate Rollback') {
      steps {
        dir("${MODULE8_DIR}") {
          sh '''
            TARGET_ENV="${TARGET_ENV}" \
            APP_IMAGE="${APP_IMAGE}" \
            APP_VERSION="${ROLLBACK_VERSION}" \
            ROLLBACK_VERSION="${ROLLBACK_VERSION}" \
            REQUIRE_ROLLBACK=false \
            ./deployment-rollback/scripts/validate-deployment-inputs.sh
          '''
        }
      }
    }

    stage('Production Rollback Approval') {
      when {
        expression { return params.TARGET_ENV == 'production' }
      }

      steps {
        input message: "Rollback production to ${params.APP_IMAGE}:${params.ROLLBACK_VERSION}?",
              ok: 'Rollback Production'
      }
    }

    stage('Dry Run') {
      when {
        expression { return params.ROLLBACK_MODE == 'dry-run' }
      }

      steps {
        dir("${MODULE8_DIR}") {
          sh '''
            TARGET_ENV="${TARGET_ENV}" \
            APP_IMAGE="${APP_IMAGE}" \
            APP_VERSION="${ROLLBACK_VERSION}" \
            ROLLBACK_VERSION="${ROLLBACK_VERSION}" \
            DEPLOYMENT_STATUS="jenkins_rollback_dry_run_success" \
            CI_SYSTEM="jenkins" \
            ./deployment-rollback/scripts/create-deployment-record.sh
          '''
        }
      }
    }

    stage('Rollback Local Compose') {
      when {
        expression { return params.ROLLBACK_MODE == 'local-compose' }
      }

      steps {
        dir("${MODULE8_DIR}") {
          sh '''
            TARGET_ENV="${TARGET_ENV}" \
            APP_IMAGE="${APP_IMAGE}" \
            ROLLBACK_VERSION="${ROLLBACK_VERSION}" \
            BASE_URL="${BASE_URL}" \
            CI_SYSTEM="jenkins" \
            ./deployment-rollback/scripts/rollback-compose-local.sh
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '08-cicd-pipelines/deployment-rollback/reports/**/*', allowEmptyArchive: true
    }
  }
}
```

---

# 18. GitLab CI Deployment Pipeline

Create:

```bash
nano deployment-rollback/gitlab/.gitlab-ci.deploy-compose.yml
```

Paste:

```yaml
stages:
  - validate
  - deploy
  - rollback

variables:
  MODULE8_DIR: "08-cicd-pipelines"

validate_deployment_inputs:
  stage: validate
  image: alpine:3.20
  before_script:
    - apk add --no-cache bash jq
  script:
    - |
      if [ -z "${APP_IMAGE:-}" ] || [ -z "${APP_VERSION:-}" ] || [ -z "${ROLLBACK_VERSION:-}" ]; then
        echo "APP_IMAGE, APP_VERSION, and ROLLBACK_VERSION are required as pipeline variables."
        exit 1
      fi
    - cd "$MODULE8_DIR"
    - |
      TARGET_ENV="${TARGET_ENV:-staging}" \
      APP_IMAGE="$APP_IMAGE" \
      APP_VERSION="$APP_VERSION" \
      ROLLBACK_VERSION="$ROLLBACK_VERSION" \
      ./deployment-rollback/scripts/validate-deployment-inputs.sh

deploy_staging_dry_run:
  stage: deploy
  image: alpine:3.20
  needs:
    - validate_deployment_inputs
  environment:
    name: staging
  rules:
    - if: '$TARGET_ENV == "staging"'
    - when: never
  before_script:
    - apk add --no-cache bash jq
  script:
    - cd "$MODULE8_DIR"
    - |
      TARGET_ENV="staging" \
      APP_IMAGE="$APP_IMAGE" \
      APP_VERSION="$APP_VERSION" \
      ROLLBACK_VERSION="$ROLLBACK_VERSION" \
      DEPLOYMENT_STATUS="gitlab_staging_dry_run_success" \
      CI_SYSTEM="gitlab-ci" \
      ./deployment-rollback/scripts/create-deployment-record.sh
  artifacts:
    when: always
    expire_in: 30 days
    paths:
      - 08-cicd-pipelines/deployment-rollback/reports/

deploy_production_manual:
  stage: deploy
  image: alpine:3.20
  needs:
    - validate_deployment_inputs
  environment:
    name: production
  rules:
    - if: '$TARGET_ENV == "production"'
      when: manual
    - when: never
  allow_failure: false
  before_script:
    - apk add --no-cache bash jq
  script:
    - cd "$MODULE8_DIR"
    - |
      TARGET_ENV="production" \
      APP_IMAGE="$APP_IMAGE" \
      APP_VERSION="$APP_VERSION" \
      ROLLBACK_VERSION="$ROLLBACK_VERSION" \
      DEPLOYMENT_STATUS="gitlab_production_manual_dry_run_success" \
      DEPLOYED_BY="$GITLAB_USER_LOGIN" \
      CI_SYSTEM="gitlab-ci" \
      ./deployment-rollback/scripts/create-deployment-record.sh
  artifacts:
    when: always
    expire_in: 90 days
    paths:
      - 08-cicd-pipelines/deployment-rollback/reports/

manual_rollback:
  stage: rollback
  image: alpine:3.20
  environment:
    name: production
  rules:
    - if: '$ROLLBACK_REQUEST == "true"'
      when: manual
    - when: never
  allow_failure: false
  before_script:
    - apk add --no-cache bash jq
  script:
    - |
      if [ -z "${APP_IMAGE:-}" ] || [ -z "${ROLLBACK_VERSION:-}" ]; then
        echo "APP_IMAGE and ROLLBACK_VERSION are required."
        exit 1
      fi
    - cd "$MODULE8_DIR"
    - |
      TARGET_ENV="${TARGET_ENV:-production}" \
      APP_IMAGE="$APP_IMAGE" \
      APP_VERSION="$ROLLBACK_VERSION" \
      ROLLBACK_VERSION="$ROLLBACK_VERSION" \
      REQUIRE_ROLLBACK=false \
      ./deployment-rollback/scripts/validate-deployment-inputs.sh
    - |
      TARGET_ENV="${TARGET_ENV:-production}" \
      APP_IMAGE="$APP_IMAGE" \
      APP_VERSION="$ROLLBACK_VERSION" \
      ROLLBACK_VERSION="$ROLLBACK_VERSION" \
      DEPLOYMENT_STATUS="gitlab_manual_rollback_dry_run_success" \
      DEPLOYED_BY="$GITLAB_USER_LOGIN" \
      CI_SYSTEM="gitlab-ci" \
      ./deployment-rollback/scripts/create-deployment-record.sh
  artifacts:
    when: always
    expire_in: 90 days
    paths:
      - 08-cicd-pipelines/deployment-rollback/reports/
```

This GitLab example is dry-run by default.

Why?

```text
Real GitLab deployment needs protected runners, SSH keys, or Kubernetes credentials.
Those should be configured carefully before enabling actual deployment.
```

---

# 19. SSH/Compose Production Pattern

For real SSH deployment, the production server should already have:

```text
repo checked out or deployment scripts installed
Docker installed
Docker Compose plugin installed
registry pull credentials
.env and secrets configured
limited deploy user
```

Recommended remote layout:

```text
/opt/demo-node-api/
  repo/
  current/
  shared/
  deployment-logs/
```

Better remote deployment command:

```bash
ssh deploy@server \
  "cd /opt/demo-node-api/repo && \
   git fetch --all && \
   git checkout main && \
   git pull --ff-only && \
   TARGET_ENV=production \
   APP_IMAGE=ghcr.io/user/demo-node-api \
   APP_VERSION=0.8.0-a1b2c3d \
   ROLLBACK_VERSION=0.7.0-f9e8d7c \
   ./08-cicd-pipelines/deployment-rollback/scripts/deploy-compose-local.sh"
```

Professional security rule:

```text
The SSH deploy user should not be a full administrator unless absolutely required.
```

---

# 20. Deployment Reports

After running deployment scripts, reports are stored in:

```text
08-cicd-pipelines/deployment-rollback/reports/
```

You should see:

```text
runtime-verification-*.json
smoke-test-*.json
deployment-staging-*.json
deployment-production-*.json
```

Inspect:

```bash
cd ~/devops-masterclass/08-cicd-pipelines

ls -lt deployment-rollback/reports | head

LATEST_DEPLOYMENT="$(ls -t deployment-rollback/reports/deployment-*.json | head -n 1)"
cat "$LATEST_DEPLOYMENT" | jq .
```

Deployment report should contain:

```json
{
  "service_name": "demo-node-api",
  "target_environment": "staging",
  "artifact": "demo-node-api:0.8.0-dev-a1b2c3d",
  "rollback_version": "0.7.0-f9e8d7c",
  "deployment_status": "success",
  "ci_system": "local"
}
```

---

# 21. Deployment Runbook

Create:

```bash
nano deployment-rollback/runbooks/deployment-runbook.md
```

Paste:

````markdown
# Deployment Runbook

## Goal

Deploy an immutable `demo-node-api` artifact to staging or production and verify that it is healthy.

## Required Inputs

- target environment
- app image
- app version
- rollback version
- base URL
- deployment mode

## Safe Deployment Flow

1. Validate artifact tag.
2. Validate rollback version.
3. Confirm environment approval.
4. Deploy artifact.
5. Check `/health`.
6. Check `/ready`.
7. Check `/version`.
8. Run smoke test.
9. Create deployment record.
10. Archive reports.

## Local Compose Deployment

```bash
cd ~/devops-masterclass/08-cicd-pipelines

TARGET_ENV=staging \
APP_IMAGE=demo-node-api \
APP_VERSION=0.8.0-dev-a1b2c3d \
ROLLBACK_VERSION=0.7.0-f9e8d7c \
BASE_URL=http://127.0.0.1:8080 \
./deployment-rollback/scripts/deploy-compose-local.sh
````

## Manual Rollback

```bash
TARGET_ENV=production \
APP_IMAGE=demo-node-api \
ROLLBACK_VERSION=0.7.0-f9e8d7c \
BASE_URL=http://127.0.0.1:8080 \
./deployment-rollback/scripts/rollback-compose-local.sh
```

## Production Rules

* Do not deploy `latest`.
* Do not deploy without rollback version.
* Do not deploy without verification.
* Archive deployment records.
* Production deployment requires approval.

````

---

# 22. Rollback Runbook

Create:

```bash
nano deployment-rollback/runbooks/rollback-runbook.md
````

Paste:

````markdown
# Rollback Runbook

## When to Roll Back

Rollback when:

- health check fails
- readiness check fails
- version mismatch occurs
- smoke test fails
- error rate spikes
- critical bug is found
- deployment causes customer impact

## Required Inputs

- target environment
- app image
- rollback version
- base URL

## Rollback Command

```bash
cd ~/devops-masterclass/08-cicd-pipelines

TARGET_ENV=production \
APP_IMAGE=demo-node-api \
ROLLBACK_VERSION=0.7.0-f9e8d7c \
BASE_URL=http://127.0.0.1:8080 \
./deployment-rollback/scripts/rollback-compose-local.sh
````

## After Rollback

1. Verify `/health`.
2. Verify `/ready`.
3. Verify `/version`.
4. Run smoke test.
5. Create incident record.
6. Freeze further deployments if needed.
7. Investigate failed release.
8. Fix forward with new artifact.

````

---

# 23. Deployment Troubleshooting

Create:

```bash
nano deployment-rollback/runbooks/deployment-troubleshooting.md
````

Paste:

````markdown
# Deployment Troubleshooting

## Deployment command fails

Check:

```bash
docker compose ps
docker compose logs --tail=100
docker image ls
docker network ls
````

## Health check fails

Check:

```bash
curl -v http://127.0.0.1:8080/health
docker logs <backend-container>
```

Possible causes:

* app crashed
* wrong port
* missing environment variable
* bad secret
* database unavailable
* image pull failed

## Readiness check fails

Check:

```bash
curl -v http://127.0.0.1:8080/ready
```

Possible causes:

* startup delay
* dependency unavailable
* readiness logic failing

## Version mismatch

Check:

```bash
curl -s http://127.0.0.1:8080/version | jq .
docker inspect <container> --format '{{.Config.Image}}'
```

Possible causes:

* old container still running
* image tag not updated
* Compose env file stale
* deployment script used wrong APP_VERSION

## Rollback fails

Check:

* rollback image exists
* rollback tag is correct
* registry credentials work
* Compose files are valid
* previous version is compatible with current data

````

---

# 24. Validation Script

Create:

```bash
nano deployment-rollback/scripts/validate-deployment-lesson.sh
````

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-deployment-rollback}"

echo "===== Validate Deployment/Rollback Lesson Files ====="

test -f "$BASE_DIR/policies/demo-node-api-deployment-policy.json"
test -x "$BASE_DIR/scripts/validate-deployment-inputs.sh"
test -x "$BASE_DIR/scripts/verify-runtime.sh"
test -x "$BASE_DIR/scripts/smoke-test.sh"
test -x "$BASE_DIR/scripts/create-deployment-record.sh"
test -x "$BASE_DIR/scripts/deploy-compose-local.sh"
test -x "$BASE_DIR/scripts/rollback-compose-local.sh"
test -f "$BASE_DIR/github-actions/deploy-compose.yml"
test -f "$BASE_DIR/github-actions/rollback-compose.yml"
test -f "$BASE_DIR/jenkins/Jenkinsfile.deploy-compose"
test -f "$BASE_DIR/jenkins/Jenkinsfile.rollback-compose"
test -f "$BASE_DIR/gitlab/.gitlab-ci.deploy-compose.yml"
test -f "$BASE_DIR/runbooks/deployment-runbook.md"
test -f "$BASE_DIR/runbooks/rollback-runbook.md"
test -f "$BASE_DIR/runbooks/deployment-troubleshooting.md"

echo "Deployment/rollback lesson files validated."
```

Make executable:

```bash
chmod +x deployment-rollback/scripts/validate-deployment-lesson.sh
```

Run:

```bash
./deployment-rollback/scripts/validate-deployment-lesson.sh
```

---

# 25. Update Makefile

Open:

```bash
cd ~/devops-masterclass/08-cicd-pipelines

nano Makefile
```

Add:

```Makefile
.PHONY: validate-deployment deploy-dry-run deploy-local rollback-local deployment-reports

validate-deployment:
	./deployment-rollback/scripts/validate-deployment-lesson.sh

deploy-dry-run:
	TARGET_ENV="$${TARGET_ENV:-staging}" \
	APP_IMAGE="$${APP_IMAGE:-demo-node-api}" \
	APP_VERSION="$${APP_VERSION:-0.8.0-dev-local}" \
	ROLLBACK_VERSION="$${ROLLBACK_VERSION:-0.7.0-local}" \
	DEPLOYMENT_STATUS="make_dry_run_success" \
	CI_SYSTEM="make" \
	./deployment-rollback/scripts/create-deployment-record.sh

deploy-local:
	@test -n "$(APP_VERSION)" || (echo "Usage: make deploy-local APP_VERSION=<tag> ROLLBACK_VERSION=<tag>" && exit 1)
	@test -n "$(ROLLBACK_VERSION)" || (echo "Usage: make deploy-local APP_VERSION=<tag> ROLLBACK_VERSION=<tag>" && exit 1)
	TARGET_ENV="$${TARGET_ENV:-staging}" \
	APP_IMAGE="$${APP_IMAGE:-demo-node-api}" \
	APP_VERSION="$(APP_VERSION)" \
	ROLLBACK_VERSION="$(ROLLBACK_VERSION)" \
	BASE_URL="$${BASE_URL:-http://127.0.0.1:8080}" \
	./deployment-rollback/scripts/deploy-compose-local.sh

rollback-local:
	@test -n "$(ROLLBACK_VERSION)" || (echo "Usage: make rollback-local ROLLBACK_VERSION=<tag>" && exit 1)
	TARGET_ENV="$${TARGET_ENV:-production}" \
	APP_IMAGE="$${APP_IMAGE:-demo-node-api}" \
	ROLLBACK_VERSION="$(ROLLBACK_VERSION)" \
	BASE_URL="$${BASE_URL:-http://127.0.0.1:8080}" \
	./deployment-rollback/scripts/rollback-compose-local.sh

deployment-reports:
	find deployment-rollback/reports -type f | sort | tail -n 20
```

Run:

```bash
make validate-deployment
make deploy-dry-run
make deployment-reports
```

---

# 26. Practical Lab

Run:

```bash
cd ~/devops-masterclass/08-cicd-pipelines

make validate-deployment
make deploy-dry-run
make deployment-reports
```

Copy GitHub workflows:

```bash
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 08-cicd-pipelines/deployment-rollback/github-actions/deploy-compose.yml \
   .github/workflows/deploy-compose.yml

cp 08-cicd-pipelines/deployment-rollback/github-actions/rollback-compose.yml \
   .github/workflows/rollback-compose.yml
```

Commit:

```bash
git status

git add .github/workflows/deploy-compose.yml \
        .github/workflows/rollback-compose.yml \
        08-cicd-pipelines/deployment-rollback

git commit -m "feat: add deployment and rollback pipelines"
git push
```

---

# 27. Production Checklist

Before using real production deployment:

```text
[ ] Image tag is immutable
[ ] Release metadata exists
[ ] Quality gates passed
[ ] SBOM exists
[ ] Provenance exists
[ ] Signature verified where required
[ ] Rollback version exists
[ ] Rollback artifact retained
[ ] Production environment approval configured
[ ] Deployment secrets are environment-scoped
[ ] Deploy user has limited permission
[ ] Health endpoint configured
[ ] Version endpoint configured
[ ] Smoke test configured
[ ] Deployment reports archived
[ ] Manual rollback workflow exists
```

---

# 28. Interview Explanation

## What is a deployment pipeline?

Strong answer:

```text
A deployment pipeline takes a trusted immutable artifact, validates deployment inputs, deploys it to a target environment, verifies health/readiness/version, runs smoke tests, records deployment evidence, and triggers rollback if verification fails.
```

## What is rollback?

Strong answer:

```text
Rollback is restoring a previous known-good immutable artifact. It should not rebuild old code under pressure. The rollback target should be known before deployment starts and retained in the registry.
```

## Why is version check important after deployment?

Strong answer:

```text
Health checks only prove that something is running. A version check proves that the expected artifact is running. Without a version check, a pipeline can report success while the old version is still deployed.
```

## What should a deployment report contain?

Strong answer:

```text
A deployment report should contain service name, environment, artifact image and tag, rollback version, deployment status, CI system, approver or deployer, timestamp, health check result, smoke test result, and links to release metadata.
```

## Why not deploy `latest`?

Strong answer:

```text
`latest` is mutable and does not identify a specific artifact. It makes rollback, audit, debugging, and provenance verification unreliable. Production deployment should use immutable version-SHA tags.
```

## How should production deployment be protected?

Strong answer:

```text
Production deployment should require environment approval, protected secrets, restricted deploy runners or agents, immutable artifact validation, rollback metadata, verification checks, and archived deployment records.
```

---

# 29. Today’s Core Rules

```text
Deployment is not just running docker compose.
Deployment is complete only after verification.
Promotion approves an artifact.
Deployment runs the artifact.
Health check proves app responds.
Version check proves expected artifact is running.
Smoke test proves basic behavior works.
Rollback must use previous known-good artifact.
Do not deploy latest.
Do not deploy without rollback version.
Archive deployment reports.
Production deployment requires approval.
Automatic rollback should run on failed verification.
Manual rollback must be available.
```

---

# Next Lesson

# Lesson 8.11 — Pipeline Observability and Debugging

We will build:

```text
pipeline logs strategy
structured CI/CD reports
failure classification
debug artifacts
timing metrics
stage duration analysis
flaky test tracking
deployment traceability
Slack/email notification patterns
GitHub Actions summaries
Jenkins archived reports
GitLab artifacts
pipeline incident runbook
CI/CD dashboard concepts
```

# Lesson 7.10 — Artifact Promotion: Dev → Staging → Production

# Build Once, Promote Many, Approval Gates, Release Candidates, Promotion Records, GitHub Environments, Jenkins Approvals, ECR/GHCR Promotion Patterns, and Deployment Governance

In the previous lessons, we built the supply-chain foundation:

```text id="g9njvg"
7.1  artifact fundamentals
7.2  versioning and release metadata
7.3  checksums, digests, immutability
7.4  registry fundamentals
7.5  ECR production workflow
7.6  GHCR production workflow
7.7  SBOM
7.8  provenance
7.9  image signing
```

Now we connect everything into the real release lifecycle:

```text id="j5roxy"
dev -> staging -> production
```

This lesson is about **promotion**, not just deployment.

---

# 1. Beginner Level — What Is Artifact Promotion?

Promotion means:

```text id="yt893f"
approving the same artifact for the next environment
```

Deployment means:

```text id="d2m3e9"
running that artifact in an environment
```

Example:

```text id="4mtcaj"
build artifact:
  demo-node-api:0.7.0-a1b2c3d

deploy to dev:
  demo-node-api:0.7.0-a1b2c3d

promote to staging:
  same image approved for staging

deploy to staging:
  demo-node-api:0.7.0-a1b2c3d

promote to production:
  same image approved for production

deploy to production:
  demo-node-api:0.7.0-a1b2c3d
```

Bad:

```text id="a3i84s"
build image for dev
build a new image for staging
build another image for production
```

Good:

```text id="r1kzd0"
build once
test once
scan once
sign once
promote same artifact
deploy same artifact
```

Core rule:

```text id="va1mq8"
Promotion should not rebuild the artifact.
Promotion should approve the same artifact for the next environment.
```

---

# 2. Beginner Mental Model

Think of an artifact like a product batch.

```text id="fo9av8"
factory creates batch:
  image digest sha256:abc...

quality check:
  tests passed
  scan passed
  SBOM generated
  provenance recorded
  signature verified

warehouse:
  registry stores image

approval:
  artifact promoted to production

delivery:
  production deploys same artifact
```

If production rebuilds it, it is not the same batch.

---

# 3. Promotion vs Deployment

| Concept  | Meaning                     | Example                  |
| -------- | --------------------------- | ------------------------ |
| Build    | Create artifact             | Docker image built       |
| Scan     | Validate security           | Trivy/Docker Scout scan  |
| Sign     | Trust artifact              | Cosign signature         |
| Promote  | Approve artifact            | staging → production     |
| Deploy   | Run artifact                | Compose uses image tag   |
| Rollback | Return to previous artifact | previous immutable image |

Professional sentence:

```text id="z08bas"
Promotion is a governance decision; deployment is a runtime action.
```

---

# 4. Artifact Promotion Flow

Professional release flow:

```text id="9k1zoq"
Pull Request merged
  ↓
CI builds image
  ↓
tests pass
  ↓
image scan passes
  ↓
SBOM generated
  ↓
provenance generated
  ↓
image signed
  ↓
image pushed to registry
  ↓
dev deploys automatically
  ↓
staging promotion record created
  ↓
staging deploys same image
  ↓
staging tests pass
  ↓
production approval
  ↓
production promotion record created
  ↓
production deploys same image
  ↓
deployment report stored
```

At no point should production rebuild the image.

---

# 5. Why Rebuilding Per Environment Is Dangerous

Bad pattern:

```text id="5vh9lf"
dev build:
  demo-node-api:dev

staging build:
  demo-node-api:staging

production build:
  demo-node-api:prod
```

Risks:

```text id="n1egys"
different dependencies
different base image version
different timestamp
different build host
different npm package state
different image digest
different untested artifact
```

Even if source code is the same, output may differ.

Professional rule:

```text id="twswuu"
Environment-specific behavior should come from config and secrets, not rebuilding artifacts.
```

---

# 6. Intermediate — Environments

Common environments:

```text id="bvtnh0"
dev:
  fast feedback, automatic deployment

staging:
  production-like validation

production:
  real users, strict approval
```

Environment differences should be:

```text id="rizss7"
environment variables
secrets
replica counts
resource limits
domain names
database endpoints
feature flags
observability config
```

Environment differences should **not** be:

```text id="ck8fkx"
different source code
different Dockerfile
different dependency tree
different image build
```

---

# 7. Intermediate — Promotion Records

A promotion record should answer:

```text id="ogilrb"
which artifact was promoted?
from which environment?
to which environment?
who approved it?
when?
what checks passed?
what image digest?
what SBOM?
what provenance?
what signature verification?
```

Example:

```json id="cfw1uf"
{
  "service_name": "demo-node-api",
  "artifact": "ghcr.io/user/demo-node-api:0.7.0-a1b2c3d",
  "from_environment": "staging",
  "to_environment": "production",
  "approved_by": "release-manager",
  "approved_at": "2026-07-05T10:00:00Z",
  "checks": {
    "tests": "passed",
    "scan": "passed",
    "signature": "verified",
    "provenance": "verified",
    "sbom": "available"
  }
}
```

Professional rule:

```text id="efsurn"
If promotion is not recorded, audit and rollback become weak.
```

---

# 8. Hands-On — Create Promotion Directory

Run:

```bash id="zs7107"
cd ~/devops-masterclass/07-artifact-management-registries

mkdir -p promotion/{records,policies,reports,examples}
```

Check:

```bash id="3uf3vk"
tree -L 2 promotion
```

Expected:

```text id="5kp1bq"
promotion
├── examples
├── policies
├── records
└── reports
```

---

# 9. Create Promotion Policy

Create:

```bash id="n6x63d"
nano promotion/policies/demo-node-api-promotion-policy.json
```

Paste:

```json id="o9j4ge"
{
  "service_name": "demo-node-api",
  "allowed_environments": [
    "dev",
    "staging",
    "production"
  ],
  "promotion_paths": [
    {
      "from": "dev",
      "to": "staging",
      "approval_required": false,
      "required_checks": [
        "tests_passed",
        "scan_passed",
        "sbom_available",
        "provenance_available"
      ]
    },
    {
      "from": "staging",
      "to": "production",
      "approval_required": true,
      "required_checks": [
        "tests_passed",
        "scan_passed",
        "sbom_available",
        "provenance_available",
        "signature_verified",
        "staging_deployment_passed"
      ]
    }
  ],
  "forbidden_tags": [
    "latest",
    "dev",
    "staging",
    "production",
    "prod"
  ],
  "production_rules": {
    "immutable_tag_required": true,
    "digest_required": true,
    "rollback_version_required": true,
    "manual_approval_required": true
  }
}
```

This is the governance definition for your service.

---

# 10. Create Advanced Promotion Record Script

You already created a simple promotion record earlier. Now create a production-grade version.

Create:

```bash id="rlb5v7"
nano scripts/create-promotion-record-v2.sh
```

Paste:

```bash id="0eh1mm"
#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"
ARTIFACT="${ARTIFACT:-}"
IMAGE_TAG="${IMAGE_TAG:-}"
IMAGE_DIGEST="${IMAGE_DIGEST:-}"
FROM_ENV="${FROM_ENV:-dev}"
TO_ENV="${TO_ENV:-staging}"
APPROVED_BY="${APPROVED_BY:-$(whoami)}"
APPROVAL_REQUIRED="${APPROVAL_REQUIRED:-false}"

TEST_STATUS="${TEST_STATUS:-unknown}"
SCAN_STATUS="${SCAN_STATUS:-unknown}"
SBOM_PATH="${SBOM_PATH:-}"
PROVENANCE_PATH="${PROVENANCE_PATH:-}"
SIGNATURE_STATUS="${SIGNATURE_STATUS:-unknown}"
STAGING_DEPLOYMENT_STATUS="${STAGING_DEPLOYMENT_STATUS:-unknown}"
ROLLBACK_VERSION="${ROLLBACK_VERSION:-}"

POLICY_FILE="${POLICY_FILE:-promotion/policies/demo-node-api-promotion-policy.json}"
OUTPUT_DIR="${OUTPUT_DIR:-promotion/records}"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if [ -z "$ARTIFACT" ]; then
  echo "ERROR: ARTIFACT is required" >&2
  echo "Example: ARTIFACT=ghcr.io/user/demo-node-api:0.7.0-a1b2c3d FROM_ENV=staging TO_ENV=production $0" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

if [ -z "$IMAGE_TAG" ]; then
  IMAGE_TAG="${ARTIFACT##*:}"
fi

if [ -f "$POLICY_FILE" ]; then
  if jq -e --arg from "$FROM_ENV" --arg to "$TO_ENV" '
    .promotion_paths[]
    | select(.from == $from and .to == $to)
  ' "$POLICY_FILE" >/dev/null; then
    :
  else
    echo "ERROR: promotion path not allowed: $FROM_ENV -> $TO_ENV" >&2
    exit 1
  fi

  if jq -e --arg tag "$IMAGE_TAG" '.forbidden_tags | index($tag)' "$POLICY_FILE" >/dev/null; then
    echo "ERROR: forbidden image tag for promotion: $IMAGE_TAG" >&2
    exit 1
  fi
fi

SAFE_ARTIFACT="$(echo "$ARTIFACT" | tr '/:@' '____')"
OUTPUT_FILE="$OUTPUT_DIR/${SERVICE_NAME}-${SAFE_ARTIFACT}-${FROM_ENV}-to-${TO_ENV}.json"

cat > "$OUTPUT_FILE" <<EOF
{
  "service_name": "$SERVICE_NAME",
  "artifact": "$ARTIFACT",
  "image_tag": "$IMAGE_TAG",
  "image_digest": "$IMAGE_DIGEST",
  "from_environment": "$FROM_ENV",
  "to_environment": "$TO_ENV",
  "approved_by": "$APPROVED_BY",
  "approval_required": $APPROVAL_REQUIRED,
  "approved_at": "$TIMESTAMP",
  "checks": {
    "tests": "$TEST_STATUS",
    "scan": "$SCAN_STATUS",
    "sbom_path": "$SBOM_PATH",
    "provenance_path": "$PROVENANCE_PATH",
    "signature": "$SIGNATURE_STATUS",
    "staging_deployment": "$STAGING_DEPLOYMENT_STATUS"
  },
  "rollback": {
    "previous_version": "$ROLLBACK_VERSION"
  },
  "status": "promoted"
}
EOF

echo "Promotion record created:"
cat "$OUTPUT_FILE" | jq .
```

Make executable:

```bash id="sbd0az"
chmod +x scripts/create-promotion-record-v2.sh
```

---

# 11. Create Promotion Validation Script

Create:

```bash id="2ked3w"
nano scripts/validate-promotion-record.sh
```

Paste:

```bash id="0890uf"
#!/usr/bin/env bash
set -euo pipefail

PROMOTION_RECORD="${1:-}"
POLICY_FILE="${POLICY_FILE:-promotion/policies/demo-node-api-promotion-policy.json}"

if [ -z "$PROMOTION_RECORD" ]; then
  echo "Usage: $0 <promotion-record-json>" >&2
  exit 1
fi

if [ ! -f "$PROMOTION_RECORD" ]; then
  echo "ERROR: promotion record not found: $PROMOTION_RECORD" >&2
  exit 1
fi

if [ ! -f "$POLICY_FILE" ]; then
  echo "ERROR: policy file not found: $POLICY_FILE" >&2
  exit 1
fi

echo "===== Validate Promotion Record ====="
echo "Record: $PROMOTION_RECORD"
echo "Policy: $POLICY_FILE"

service_name="$(jq -r '.service_name // empty' "$PROMOTION_RECORD")"
artifact="$(jq -r '.artifact // empty' "$PROMOTION_RECORD")"
image_tag="$(jq -r '.image_tag // empty' "$PROMOTION_RECORD")"
from_env="$(jq -r '.from_environment // empty' "$PROMOTION_RECORD")"
to_env="$(jq -r '.to_environment // empty' "$PROMOTION_RECORD")"

if [ -z "$service_name" ] || [ -z "$artifact" ] || [ -z "$image_tag" ] || [ -z "$from_env" ] || [ -z "$to_env" ]; then
  echo "ERROR: missing required promotion fields" >&2
  exit 1
fi

if jq -e --arg tag "$image_tag" '.forbidden_tags | index($tag)' "$POLICY_FILE" >/dev/null; then
  echo "ERROR: forbidden image tag: $image_tag" >&2
  exit 1
fi

if ! jq -e --arg from "$from_env" --arg to "$to_env" '
  .promotion_paths[]
  | select(.from == $from and .to == $to)
' "$POLICY_FILE" >/dev/null; then
  echo "ERROR: promotion path not allowed: $from_env -> $to_env" >&2
  exit 1
fi

if [ "$to_env" = "production" ]; then
  test_status="$(jq -r '.checks.tests // "unknown"' "$PROMOTION_RECORD")"
  scan_status="$(jq -r '.checks.scan // "unknown"' "$PROMOTION_RECORD")"
  signature_status="$(jq -r '.checks.signature // "unknown"' "$PROMOTION_RECORD")"
  staging_status="$(jq -r '.checks.staging_deployment // "unknown"' "$PROMOTION_RECORD")"
  rollback_version="$(jq -r '.rollback.previous_version // empty' "$PROMOTION_RECORD")"

  if [ "$test_status" != "passed" ]; then
    echo "ERROR: production promotion requires tests passed" >&2
    exit 1
  fi

  if [ "$scan_status" != "passed" ]; then
    echo "ERROR: production promotion requires scan passed" >&2
    exit 1
  fi

  if [ "$signature_status" != "verified" ]; then
    echo "ERROR: production promotion requires signature verified" >&2
    exit 1
  fi

  if [ "$staging_status" != "passed" ]; then
    echo "ERROR: production promotion requires staging deployment passed" >&2
    exit 1
  fi

  if [ -z "$rollback_version" ] || [ "$rollback_version" = "null" ]; then
    echo "ERROR: production promotion requires rollback version" >&2
    exit 1
  fi
fi

echo "Promotion record is valid."
cat "$PROMOTION_RECORD" | jq .
```

Make executable:

```bash id="j5w55t"
chmod +x scripts/validate-promotion-record.sh
```

---

# 12. Promotion Record Example — Dev to Staging

Compute tag:

```bash id="93kxhr"
cd ~/devops-masterclass/07-artifact-management-registries

VERSION_JSON="$(BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"
```

Create record:

```bash id="9moiq6"
ARTIFACT="demo-node-api:$DEPLOY_TAG" \
IMAGE_TAG="$DEPLOY_TAG" \
FROM_ENV=dev \
TO_ENV=staging \
APPROVAL_REQUIRED=false \
TEST_STATUS=passed \
SCAN_STATUS=passed \
SBOM_PATH="sbom/cyclonedx/demo-node-api-$DEPLOY_TAG.trivy.cdx.json" \
PROVENANCE_PATH="provenance/manual/demo-node-api-$DEPLOY_TAG.manual-provenance.json" \
SIGNATURE_STATUS=not_required \
./scripts/create-promotion-record-v2.sh
```

Validate:

```bash id="ar7jnp"
LATEST_PROMOTION="$(ls -t promotion/records/*.json | head -n 1)"
./scripts/validate-promotion-record.sh "$LATEST_PROMOTION"
```

---

# 13. Promotion Record Example — Staging to Production

Production promotion should be stricter.

```bash id="qw6vza"
ARTIFACT="demo-node-api:$DEPLOY_TAG" \
IMAGE_TAG="$DEPLOY_TAG" \
FROM_ENV=staging \
TO_ENV=production \
APPROVAL_REQUIRED=true \
APPROVED_BY="$(whoami)" \
TEST_STATUS=passed \
SCAN_STATUS=passed \
SBOM_PATH="sbom/cyclonedx/demo-node-api-$DEPLOY_TAG.trivy.cdx.json" \
PROVENANCE_PATH="provenance/manual/demo-node-api-$DEPLOY_TAG.manual-provenance.json" \
SIGNATURE_STATUS=verified \
STAGING_DEPLOYMENT_STATUS=passed \
ROLLBACK_VERSION=0.6.0-previous \
./scripts/create-promotion-record-v2.sh
```

Validate:

```bash id="gy0e2k"
LATEST_PROMOTION="$(ls -t promotion/records/*.json | head -n 1)"
./scripts/validate-promotion-record.sh "$LATEST_PROMOTION"
```

If you omit rollback version or signature status for production, validation should fail. That is intentional.

---

# 14. Intermediate — Environment Config Files

Your artifact should be the same, but environment files differ.

Example:

```text id="63ci11"
compose-demo/
├── env/
│   ├── dev.env
│   ├── staging.env
│   └── production.env
```

Create:

```bash id="tq2jql"
cd ~/devops-masterclass/06-docker-containers/compose-demo

mkdir -p env
```

Dev:

```bash id="brg3xr"
cat > env/dev.env <<'EOF'
APP_ENV=dev
LOG_LEVEL=debug
HOST_HTTP_PORT=8081
EOF
```

Staging:

```bash id="m10heq"
cat > env/staging.env <<'EOF'
APP_ENV=staging
LOG_LEVEL=info
HOST_HTTP_PORT=8082
EOF
```

Production:

```bash id="s6c1x0"
cat > env/production.env <<'EOF'
APP_ENV=prod
LOG_LEVEL=info
HOST_HTTP_PORT=8080
EOF
```

Professional rule:

```text id="8ds4vk"
Same image, different runtime configuration.
```

Do not commit secrets.

---

# 15. Create Promotion-Aware Deployment Script

Create in Module 7:

```bash id="lvwqbe"
cd ~/devops-masterclass/07-artifact-management-registries

nano scripts/promote-and-deploy-compose.sh
```

Paste:

```bash id="vf6ip7"
#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"
APP_IMAGE="${APP_IMAGE:-demo-node-api}"
APP_VERSION="${APP_VERSION:-}"
FROM_ENV="${FROM_ENV:-dev}"
TO_ENV="${TO_ENV:-staging}"
COMPOSE_DIR="${COMPOSE_DIR:-../06-docker-containers/compose-demo}"
COMPOSE_FILES="${COMPOSE_FILES:-compose.yaml compose.prod.yaml}"
ENV_FILE="${ENV_FILE:-}"

TEST_STATUS="${TEST_STATUS:-passed}"
SCAN_STATUS="${SCAN_STATUS:-passed}"
SIGNATURE_STATUS="${SIGNATURE_STATUS:-unknown}"
STAGING_DEPLOYMENT_STATUS="${STAGING_DEPLOYMENT_STATUS:-unknown}"
ROLLBACK_VERSION="${ROLLBACK_VERSION:-}"
APPROVED_BY="${APPROVED_BY:-$(whoami)}"
APPROVAL_REQUIRED="${APPROVAL_REQUIRED:-false}"

SBOM_PATH="${SBOM_PATH:-}"
PROVENANCE_PATH="${PROVENANCE_PATH:-}"

if [ -z "$APP_VERSION" ]; then
  echo "ERROR: APP_VERSION is required" >&2
  exit 1
fi

ARTIFACT="$APP_IMAGE:$APP_VERSION"

echo "===== Promote and Deploy Compose ====="
echo "Artifact: $ARTIFACT"
echo "From: $FROM_ENV"
echo "To: $TO_ENV"

./scripts/create-promotion-record-v2.sh \
  SERVICE_NAME="$SERVICE_NAME" \
  ARTIFACT="$ARTIFACT" \
  IMAGE_TAG="$APP_VERSION" \
  FROM_ENV="$FROM_ENV" \
  TO_ENV="$TO_ENV" \
  APPROVED_BY="$APPROVED_BY" \
  APPROVAL_REQUIRED="$APPROVAL_REQUIRED" \
  TEST_STATUS="$TEST_STATUS" \
  SCAN_STATUS="$SCAN_STATUS" \
  SBOM_PATH="$SBOM_PATH" \
  PROVENANCE_PATH="$PROVENANCE_PATH" \
  SIGNATURE_STATUS="$SIGNATURE_STATUS" \
  STAGING_DEPLOYMENT_STATUS="$STAGING_DEPLOYMENT_STATUS" \
  ROLLBACK_VERSION="$ROLLBACK_VERSION"

PROMOTION_RECORD="$(ls -t promotion/records/*.json | head -n 1)"
./scripts/validate-promotion-record.sh "$PROMOTION_RECORD"

echo
echo "Promotion validated. Deploying to $TO_ENV..."

cd "$COMPOSE_DIR"

if [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then
  echo "Loading environment file: $ENV_FILE"
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

APP_IMAGE="$APP_IMAGE" \
APP_VERSION="$APP_VERSION" \
COMPOSE_FILES="$COMPOSE_FILES" \
./scripts/deploy-compose.sh
```

There is a shell bug in the above: passing environment variables after command name does not work with individual arguments like that. Replace the call block with this correct version:

```bash id="io5r61"
SERVICE_NAME="$SERVICE_NAME" \
ARTIFACT="$ARTIFACT" \
IMAGE_TAG="$APP_VERSION" \
FROM_ENV="$FROM_ENV" \
TO_ENV="$TO_ENV" \
APPROVED_BY="$APPROVED_BY" \
APPROVAL_REQUIRED="$APPROVAL_REQUIRED" \
TEST_STATUS="$TEST_STATUS" \
SCAN_STATUS="$SCAN_STATUS" \
SBOM_PATH="$SBOM_PATH" \
PROVENANCE_PATH="$PROVENANCE_PATH" \
SIGNATURE_STATUS="$SIGNATURE_STATUS" \
STAGING_DEPLOYMENT_STATUS="$STAGING_DEPLOYMENT_STATUS" \
ROLLBACK_VERSION="$ROLLBACK_VERSION" \
./scripts/create-promotion-record-v2.sh
```

So the corrected script should contain that environment-prefix style.

Make executable:

```bash id="rwxpnd"
chmod +x scripts/promote-and-deploy-compose.sh
```

Usage dev → staging:

```bash id="9jh7k6"
APP_IMAGE=demo-node-api \
APP_VERSION="$DEPLOY_TAG" \
FROM_ENV=dev \
TO_ENV=staging \
ENV_FILE="../06-docker-containers/compose-demo/env/staging.env" \
./scripts/promote-and-deploy-compose.sh
```

Usage staging → production:

```bash id="lx66z6"
APP_IMAGE=demo-node-api \
APP_VERSION="$DEPLOY_TAG" \
FROM_ENV=staging \
TO_ENV=production \
APPROVAL_REQUIRED=true \
SIGNATURE_STATUS=verified \
STAGING_DEPLOYMENT_STATUS=passed \
ROLLBACK_VERSION=0.6.0-previous \
ENV_FILE="../06-docker-containers/compose-demo/env/production.env" \
./scripts/promote-and-deploy-compose.sh
```

---

# 16. GitHub Environments

GitHub Actions environments are useful for promotion gates.

GitHub environments can have deployment protection rules and environment secrets; GitHub’s docs describe configuring environments for deployment workflows and applying protection rules such as required reviewers. ([GitHub Docs][1])

Example workflow concept:

```yaml id="0wc7wn"
jobs:
  deploy-staging:
    environment: staging

  deploy-production:
    environment: production
```

With production environment protection:

```text id="742l45"
required reviewer
deployment branch restrictions
environment-specific secrets
approval before job continues
```

GitHub also supports custom deployment protection rules using GitHub Apps for third-party checks, but private/internal repository support depends on plan level. ([GitHub Docs][2])

Professional rule:

```text id="7b2rte"
Use environment protection for production deployment, not only a shell prompt.
```

---

# 17. GitHub Actions Promotion Workflow Example

Create:

```bash id="5yw71z"
cd ~/devops-masterclass/07-artifact-management-registries

nano examples/github-actions-artifact-promotion.yml
```

Paste:

```yaml id="349ohx"
name: Artifact Promotion Example

on:
  workflow_dispatch:
    inputs:
      image_tag:
        description: "Immutable image tag to promote"
        required: true
        type: string
      target_environment:
        description: "Target environment"
        required: true
        type: choice
        options:
          - staging
          - production

permissions:
  contents: read
  packages: read

env:
  IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/demo-node-api

jobs:
  promote-staging:
    if: ${{ inputs.target_environment == 'staging' }}
    runs-on: ubuntu-latest
    environment: staging

    steps:
      - uses: actions/checkout@v4

      - name: Validate image tag
        run: |
          TAG="${{ inputs.image_tag }}"

          if [[ "$TAG" == "latest" || "$TAG" == "dev" || "$TAG" == "staging" || "$TAG" == "prod" ]]; then
            echo "Forbidden mutable tag: $TAG"
            exit 1
          fi

      - name: Create staging promotion summary
        run: |
          mkdir -p promotion-records
          cat > promotion-records/staging-${{ inputs.image_tag }}.json <<EOF
          {
            "artifact": "${IMAGE_NAME}:${{ inputs.image_tag }}",
            "to_environment": "staging",
            "status": "promoted",
            "approved_by": "${{ github.actor }}",
            "approved_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
          }
          EOF

      - name: Upload promotion record
        uses: actions/upload-artifact@v4
        with:
          name: promotion-staging-${{ inputs.image_tag }}
          path: promotion-records/

  promote-production:
    if: ${{ inputs.target_environment == 'production' }}
    runs-on: ubuntu-latest
    environment: production

    steps:
      - uses: actions/checkout@v4

      - name: Validate image tag
        run: |
          TAG="${{ inputs.image_tag }}"

          if [[ "$TAG" == "latest" || "$TAG" == "dev" || "$TAG" == "staging" || "$TAG" == "prod" ]]; then
            echo "Forbidden mutable tag: $TAG"
            exit 1
          fi

      - name: Create production promotion summary
        run: |
          mkdir -p promotion-records
          cat > promotion-records/production-${{ inputs.image_tag }}.json <<EOF
          {
            "artifact": "${IMAGE_NAME}:${{ inputs.image_tag }}",
            "to_environment": "production",
            "status": "promoted",
            "approved_by": "${{ github.actor }}",
            "approved_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
            "approval_gate": "GitHub Environment production"
          }
          EOF

      - name: Upload promotion record
        uses: actions/upload-artifact@v4
        with:
          name: promotion-production-${{ inputs.image_tag }}
          path: promotion-records/
```

This workflow does not build. It promotes an existing immutable image tag.

That is the point.

---

# 18. Jenkins Approval Gate

In Jenkins, human approval commonly uses the Pipeline `input` step. Jenkins documents that the input step pauses Pipeline execution and lets a user proceed or abort the build. ([Jenkins][3])

Example:

```groovy id="9ak5yl"
stage('Approve Production Promotion') {
  steps {
    input message: 'Promote this artifact to production?', ok: 'Promote'
  }
}
```

Production promotion Jenkins example:

```groovy id="bl2dqw"
pipeline {
  agent any

  parameters {
    string(name: 'IMAGE_TAG', description: 'Immutable image tag to promote')
  }

  environment {
    APP_IMAGE = 'ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api'
  }

  stages {
    stage('Validate Tag') {
      steps {
        sh '''
          case "$IMAGE_TAG" in
            latest|dev|staging|prod|production)
              echo "Forbidden mutable tag: $IMAGE_TAG"
              exit 1
              ;;
          esac
        '''
      }
    }

    stage('Staging Deploy') {
      steps {
        sh '''
          APP_IMAGE="$APP_IMAGE" \
          APP_VERSION="$IMAGE_TAG" \
          COMPOSE_FILES="compose.yaml compose.prod.yaml" \
          ./scripts/deploy-compose.sh
        '''
      }
    }

    stage('Approve Production Promotion') {
      steps {
        input message: "Promote $APP_IMAGE:$IMAGE_TAG to production?", ok: 'Promote'
      }
    }

    stage('Production Deploy') {
      steps {
        sh '''
          APP_IMAGE="$APP_IMAGE" \
          APP_VERSION="$IMAGE_TAG" \
          COMPOSE_FILES="compose.yaml compose.prod.yaml" \
          ./scripts/deploy-compose.sh
        '''
      }
    }
  }
}
```

Professional rule:

```text id="vm3xi1"
Manual approval should approve a specific artifact tag or digest, not “whatever is latest.”
```

---

# 19. ECR Promotion Patterns

There are two common ECR promotion approaches.

## Pattern A — Same tag across environments

```text id="7wr2u3"
dev deploys:
  demo-node-api:0.7.0-a1b2c3d

staging deploys:
  demo-node-api:0.7.0-a1b2c3d

production deploys:
  demo-node-api:0.7.0-a1b2c3d
```

This is the cleanest.

## Pattern B — Retag existing image as environment-approved tag

Example:

```text id="qgxiz7"
0.7.0-a1b2c3d
production-approved
```

AWS ECR supports retagging an existing image without pulling and pushing it again by using `put-image --image-tag` with the image manifest. ([AWS Documentation][4])

Example:

```bash id="8laske"
AWS_REGION=ap-south-1
ECR_REPOSITORY=demo-node-api
SOURCE_TAG="$DEPLOY_TAG"
TARGET_TAG="production-approved-$DEPLOY_TAG"

MANIFEST="$(aws ecr batch-get-image \
  --repository-name "$ECR_REPOSITORY" \
  --image-ids imageTag="$SOURCE_TAG" \
  --query 'images[0].imageManifest' \
  --output text \
  --region "$AWS_REGION")"

aws ecr put-image \
  --repository-name "$ECR_REPOSITORY" \
  --image-tag "$TARGET_TAG" \
  --image-manifest "$MANIFEST" \
  --region "$AWS_REGION"
```

Important warning:

```text id="k6z65f"
If ECR tag immutability is enabled, retagging to an existing tag will fail.
```

Professional preference:

```text id="x3ppeg"
Use immutable version-sha tags as the deployment source of truth.
Use environment tags only as convenience pointers, never as the only audit record.
```

---

# 20. GHCR Promotion Patterns

GHCR promotion usually means:

```text id="97ddbg"
same image tag gets approved for next environment
deployment workflow receives image_tag input
GitHub Environment approval controls production
promotion record is stored
```

Do not do:

```text id="wq42c2"
push prod tag over and over
```

Better:

```text id="hltpj2"
deploy exact immutable tag:
  ghcr.io/user/demo-node-api:0.7.0-a1b2c3d
```

GHCR has granular permissions and package access can be configured independently or inherited from a repository, which matters when separate repos build and deploy images. ([GitHub Docs][5])

Professional rule:

```text id="7cqja7"
For GHCR, promotion is usually workflow governance plus deployment records, not image rebuilding.
```

---

# 21. Release Candidate Promotion

Release candidates are useful.

Example:

```text id="nplflb"
0.8.0-rc.1-a1b2c3d
```

Flow:

```text id="qmqf9h"
build rc image
deploy to staging
run tests
if approved:
  either promote rc as production artifact
  or create stable release from same commit depending on policy
```

Two production strategies:

## Strategy A — Deploy RC artifact to production

```text id="rh8g42"
staging tested:
  0.8.0-rc.1-a1b2c3d

production deploys:
  0.8.0-rc.1-a1b2c3d
```

Most artifact-pure.

## Strategy B — Rebuild stable from same commit

```text id="ianvmc"
staging tested:
  0.8.0-rc.1-a1b2c3d

production release:
  0.8.0-a1b2c3d
```

More human-friendly, but rebuild risk exists unless build is reproducible and controlled.

Professional compromise:

```text id="ewbmki"
If rebuilding stable from the same commit, record both RC and stable artifact digests and ensure the pipeline is deterministic enough for your risk level.
```

---

# 22. Rollback Metadata

Promotion to production must know rollback target.

Record:

```text id="ny1imu"
current production version
new production version
previous production version
rollback command
rollback health check
rollback report location
```

Example:

```json id="lbh6dq"
{
  "environment": "production",
  "previous_version": "0.6.0-f8e9d10",
  "new_version": "0.7.0-a1b2c3d",
  "rollback_available": true,
  "rollback_method": "APP_VERSION=0.6.0-f8e9d10 ./scripts/deploy-compose.sh"
}
```

Professional rule:

```text id="f11ulu"
Never promote to production without knowing the rollback target.
```

---

# 23. Create Current Environment State File

Create:

```bash id="ytuxgy"
cd ~/devops-masterclass/07-artifact-management-registries

mkdir -p promotion/state
nano promotion/state/environments.json
```

Paste:

```json id="wgbhqy"
{
  "dev": {
    "current_version": "",
    "previous_version": ""
  },
  "staging": {
    "current_version": "",
    "previous_version": ""
  },
  "production": {
    "current_version": "",
    "previous_version": ""
  }
}
```

Create state update script:

```bash id="5v85rk"
nano scripts/update-environment-state.sh
```

Paste:

```bash id="jopj2s"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-}"
NEW_VERSION="${NEW_VERSION:-}"
STATE_FILE="${STATE_FILE:-promotion/state/environments.json}"

if [ -z "$ENVIRONMENT" ] || [ -z "$NEW_VERSION" ]; then
  echo "ERROR: ENVIRONMENT and NEW_VERSION are required" >&2
  exit 1
fi

if [ ! -f "$STATE_FILE" ]; then
  echo "ERROR: state file not found: $STATE_FILE" >&2
  exit 1
fi

CURRENT_VERSION="$(jq -r --arg env "$ENVIRONMENT" '.[$env].current_version // ""' "$STATE_FILE")"

TMP_FILE="$(mktemp)"

jq \
  --arg env "$ENVIRONMENT" \
  --arg current "$CURRENT_VERSION" \
  --arg new "$NEW_VERSION" \
  --arg updated "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '.[$env].previous_version = $current
   | .[$env].current_version = $new
   | .[$env].updated_at = $updated' \
  "$STATE_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$STATE_FILE"

echo "Environment state updated:"
cat "$STATE_FILE" | jq .
```

Make executable:

```bash id="gqodyd"
chmod +x scripts/update-environment-state.sh
```

Update staging:

```bash id="21hy0u"
ENVIRONMENT=staging NEW_VERSION="$DEPLOY_TAG" ./scripts/update-environment-state.sh
```

Update production:

```bash id="z3gzga"
ENVIRONMENT=production NEW_VERSION="$DEPLOY_TAG" ./scripts/update-environment-state.sh
```

---

# 24. Create Production Promotion Gate Script

Create:

```bash id="p6rm76"
nano scripts/production-promotion-gate.sh
```

Paste:

```bash id="swav3x"
#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${IMAGE_TAG:-}"
STATE_FILE="${STATE_FILE:-promotion/state/environments.json}"
REQUIRE_STAGING="${REQUIRE_STAGING:-true}"

if [ -z "$IMAGE_TAG" ]; then
  echo "ERROR: IMAGE_TAG is required" >&2
  exit 1
fi

if [ ! -f "$STATE_FILE" ]; then
  echo "ERROR: state file not found: $STATE_FILE" >&2
  exit 1
fi

echo "===== Production Promotion Gate ====="
echo "Image tag: $IMAGE_TAG"

case "$IMAGE_TAG" in
  latest|dev|staging|prod|production)
    echo "ERROR: forbidden production tag: $IMAGE_TAG" >&2
    exit 1
    ;;
esac

if [ "$REQUIRE_STAGING" = "true" ]; then
  STAGING_VERSION="$(jq -r '.staging.current_version // ""' "$STATE_FILE")"

  if [ "$STAGING_VERSION" != "$IMAGE_TAG" ]; then
    echo "ERROR: image tag has not passed staging according to state file" >&2
    echo "Staging current: $STAGING_VERSION" >&2
    echo "Requested prod:   $IMAGE_TAG" >&2
    exit 1
  fi
fi

PROD_PREVIOUS="$(jq -r '.production.current_version // ""' "$STATE_FILE")"

if [ -z "$PROD_PREVIOUS" ]; then
  echo "WARNING: no previous production version recorded."
else
  echo "Previous production version: $PROD_PREVIOUS"
fi

echo "Production promotion gate passed."
```

Make executable:

```bash id="h489no"
chmod +x scripts/production-promotion-gate.sh
```

Run:

```bash id="3wg6r0"
IMAGE_TAG="$DEPLOY_TAG" ./scripts/production-promotion-gate.sh
```

---

# 25. Promotion Runbook

Create:

```bash id="eofou5"
nano notes/artifact-promotion-runbook.md
```

Paste:

````markdown id="jt1z0m"
# Artifact Promotion Runbook

## Goal

Promote the same immutable artifact from dev to staging to production.

## Core Rule

Do not rebuild per environment.

## Artifact Identity

Use:

```text
APP_IMAGE:APP_VERSION
````

Example:

```text id="vlgm6r"
ghcr.io/user/demo-node-api:0.7.0-a1b2c3d
```

## Dev to Staging

Required:

* tests passed
* scan passed
* SBOM exists
* provenance exists

Command:

```bash id="fl5oqf"
ARTIFACT=demo-node-api:TAG \
IMAGE_TAG=TAG \
FROM_ENV=dev \
TO_ENV=staging \
TEST_STATUS=passed \
SCAN_STATUS=passed \
./scripts/create-promotion-record-v2.sh
```

## Staging to Production

Required:

* tests passed
* scan passed
* SBOM exists
* provenance exists
* signature verified
* staging deployment passed
* rollback version recorded
* human approval

Command:

```bash id="1e4g5p"
ARTIFACT=demo-node-api:TAG \
IMAGE_TAG=TAG \
FROM_ENV=staging \
TO_ENV=production \
APPROVAL_REQUIRED=true \
TEST_STATUS=passed \
SCAN_STATUS=passed \
SIGNATURE_STATUS=verified \
STAGING_DEPLOYMENT_STATUS=passed \
ROLLBACK_VERSION=PREVIOUS \
./scripts/create-promotion-record-v2.sh
```

## Production Gate

```bash id="h8dk3v"
IMAGE_TAG=TAG ./scripts/production-promotion-gate.sh
```

## Update State

```bash id="1xg0i3"
ENVIRONMENT=production NEW_VERSION=TAG ./scripts/update-environment-state.sh
```

## Rollback

Rollback to previous production version from:

```text id="jfkoj8"
promotion/state/environments.json
deployment reports
promotion records
```

````

---

# 26. Promotion Policy Notes

Create:

```bash id="4epp5o"
nano notes/artifact-promotion-policy.md
````

Paste:

```markdown id="3mbf4h"
# Artifact Promotion Policy

## Build Policy

- Build artifact once in CI.
- Do not rebuild for staging or production.
- Use immutable version-sha tags.
- Record digest where possible.

## Dev Policy

Dev deployment may be automatic after CI passes.

## Staging Policy

Staging promotion requires:

- tests passed
- vulnerability scan passed or accepted
- SBOM available
- provenance available
- image exists in registry

## Production Policy

Production promotion requires:

- staging deployment passed
- tests passed
- vulnerability scan passed or approved
- SBOM available
- provenance available
- signature verified
- rollback version known
- human approval

## Forbidden

- deploying `latest`
- rebuilding for production
- promoting unsigned/unverified images to production
- promoting without rollback target
- deleting previous production image before rollback window expires
```

---

# 27. Enterprise Promotion Governance

In real companies, promotion may include:

```text id="pk30lh"
QA approval
security approval
change advisory board
release manager approval
business approval
automated policy checks
manual break-glass process
audit trail
```

But good DevOps avoids unnecessary bureaucracy.

Balanced model:

```text id="f76uuc"
dev:
  automated

staging:
  automated with quality gates

production:
  automated checks + lightweight approval

emergency hotfix:
  fast approval + strong audit trail
```

Professional rule:

```text id="4wr054"
Governance should reduce risk without destroying delivery speed.
```

---

# 28. Promotion Anti-Patterns

Avoid these:

```text id="6wcddn"
using latest in production
rebuilding image in production pipeline
manual docker build on server
approving branch instead of artifact
no rollback target
no promotion record
no scan/SBOM/signature evidence
environment-specific Dockerfiles for same app
deleting previous image immediately after deploy
using mutable prod tag as only source of truth
```

Strong DevOps habit:

```text id="yaqz1h"
Always ask: what exact artifact is being promoted?
```

---

# 29. Update Makefile

Open:

```bash id="q4hfzg"
cd ~/devops-masterclass/07-artifact-management-registries

nano Makefile
```

Add:

```Makefile id="lin3sg"
.PHONY: promote validate-promotion update-env-state prod-gate

promote:
	@test -n "$(ARTIFACT)" || (echo "Usage: make promote ARTIFACT=<image:tag> FROM_ENV=dev TO_ENV=staging" && exit 1)
	ARTIFACT="$(ARTIFACT)" FROM_ENV="$(FROM_ENV)" TO_ENV="$(TO_ENV)" ./scripts/create-promotion-record-v2.sh

validate-promotion:
	@LATEST=$$(ls -t promotion/records/*.json | head -n 1); \
	./scripts/validate-promotion-record.sh "$$LATEST"

update-env-state:
	@test -n "$(ENVIRONMENT)" || (echo "Usage: make update-env-state ENVIRONMENT=staging NEW_VERSION=<tag>" && exit 1)
	@test -n "$(NEW_VERSION)" || (echo "Usage: make update-env-state ENVIRONMENT=staging NEW_VERSION=<tag>" && exit 1)
	ENVIRONMENT="$(ENVIRONMENT)" NEW_VERSION="$(NEW_VERSION)" ./scripts/update-environment-state.sh

prod-gate:
	@test -n "$(IMAGE_TAG)" || (echo "Usage: make prod-gate IMAGE_TAG=<tag>" && exit 1)
	IMAGE_TAG="$(IMAGE_TAG)" ./scripts/production-promotion-gate.sh
```

Use:

```bash id="tbp55u"
make promote ARTIFACT="demo-node-api:$DEPLOY_TAG" FROM_ENV=dev TO_ENV=staging
make validate-promotion
make update-env-state ENVIRONMENT=staging NEW_VERSION="$DEPLOY_TAG"
make prod-gate IMAGE_TAG="$DEPLOY_TAG"
```

---

# 30. Final Validation Flow

Compute version:

```bash id="xksttq"
cd ~/devops-masterclass/07-artifact-management-registries

VERSION_JSON="$(BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"

echo "$DEPLOY_TAG"
```

Build once:

```bash id="v85bq7"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
```

Create dev → staging promotion:

```bash id="t64ldq"
cd ~/devops-masterclass/07-artifact-management-registries

ARTIFACT="demo-node-api:$DEPLOY_TAG" \
IMAGE_TAG="$DEPLOY_TAG" \
FROM_ENV=dev \
TO_ENV=staging \
TEST_STATUS=passed \
SCAN_STATUS=passed \
SBOM_PATH="sbom/cyclonedx/demo-node-api-$DEPLOY_TAG.trivy.cdx.json" \
PROVENANCE_PATH="provenance/manual/demo-node-api-$DEPLOY_TAG.manual-provenance.json" \
./scripts/create-promotion-record-v2.sh

LATEST_PROMOTION="$(ls -t promotion/records/*.json | head -n 1)"
./scripts/validate-promotion-record.sh "$LATEST_PROMOTION"
```

Deploy to staging:

```bash id="l7h7nm"
cd ~/devops-masterclass/06-docker-containers/compose-demo

APP_IMAGE=demo-node-api \
APP_VERSION="$DEPLOY_TAG" \
COMPOSE_FILES="compose.yaml compose.prod.yaml" \
./scripts/deploy-compose.sh
```

Update staging state:

```bash id="lg0nzm"
cd ~/devops-masterclass/07-artifact-management-registries

ENVIRONMENT=staging NEW_VERSION="$DEPLOY_TAG" ./scripts/update-environment-state.sh
```

Run production gate:

```bash id="hcmv7r"
IMAGE_TAG="$DEPLOY_TAG" ./scripts/production-promotion-gate.sh
```

Create staging → production promotion:

```bash id="ne0jca"
PREVIOUS_PROD="$(jq -r '.production.current_version // "none"' promotion/state/environments.json)"

ARTIFACT="demo-node-api:$DEPLOY_TAG" \
IMAGE_TAG="$DEPLOY_TAG" \
FROM_ENV=staging \
TO_ENV=production \
APPROVAL_REQUIRED=true \
TEST_STATUS=passed \
SCAN_STATUS=passed \
SIGNATURE_STATUS=verified \
STAGING_DEPLOYMENT_STATUS=passed \
ROLLBACK_VERSION="$PREVIOUS_PROD" \
./scripts/create-promotion-record-v2.sh

LATEST_PROMOTION="$(ls -t promotion/records/*.json | head -n 1)"
./scripts/validate-promotion-record.sh "$LATEST_PROMOTION"
```

Deploy to production:

```bash id="l2ey39"
cd ~/devops-masterclass/06-docker-containers/compose-demo

APP_IMAGE=demo-node-api \
APP_VERSION="$DEPLOY_TAG" \
COMPOSE_FILES="compose.yaml compose.prod.yaml" \
./scripts/deploy-compose.sh
```

Update production state:

```bash id="nrk83x"
cd ~/devops-masterclass/07-artifact-management-registries

ENVIRONMENT=production NEW_VERSION="$DEPLOY_TAG" ./scripts/update-environment-state.sh
```

---

# 31. Commit Work

Run:

```bash id="vwpxb8"
cd ~/devops-masterclass

git status
git add 06-docker-containers/compose-demo/env \
        07-artifact-management-registries

git commit -m "feat: add artifact promotion workflow and governance"
git push
```

---

# 32. Interview Explanation

## What is artifact promotion?

Strong answer:

```text id="g9eijp"
Artifact promotion is the process of approving the same built artifact for the next environment, such as dev to staging or staging to production. It should not rebuild the artifact. The same image tag or digest should move through environments with different runtime configuration.
```

## Promotion vs deployment?

Strong answer:

```text id="7ugxlu"
Promotion is a governance decision that says an artifact is approved for an environment. Deployment is the runtime action of running that artifact in that environment.
```

## What does “build once, promote many” mean?

Strong answer:

```text id="fjugp7"
It means CI builds one artifact, such as a Docker image, and the same artifact is tested, scanned, signed, and promoted through dev, staging, and production. Environment-specific behavior comes from config and secrets, not rebuilding.
```

## What checks are required before production promotion?

Strong answer:

```text id="n3pbvr"
Before production promotion, I want tests passed, vulnerability scan passed or approved, SBOM available, provenance available, signature verified, staging deployment passed, rollback version known, and human approval where required.
```

## How do GitHub Environments help production promotion?

Strong answer:

```text id="lss7vo"
GitHub Environments can apply deployment protection rules such as required reviewers and environment-specific secrets. A workflow job targeting the production environment can pause until approval is granted.
```

## How does Jenkins handle production approval?

Strong answer:

```text id="4lwdvq"
In Jenkins Pipeline, the input step can pause the pipeline and require a user to proceed or abort. I use it to approve a specific immutable image tag or digest before production deployment.
```

## Why is rollback metadata part of promotion?

Strong answer:

```text id="l71n4w"
Production promotion should know the previous production artifact before deploying the new one. If the new deployment fails, rollback should target a known immutable previous version, not guess from latest or rebuild.
```

---

# Today’s Core Rules

```text id="xsn1y3"
Promotion approves an artifact.
Deployment runs an artifact.
Do not rebuild per environment.
Use the same image tag/digest through dev, staging, and production.
Environment-specific behavior belongs in config and secrets.
Production promotion requires stronger gates.
Promotion records are audit evidence.
GitHub Environments can enforce approval gates.
Jenkins input step can pause for approval.
ECR can retag an existing image, but immutable version-sha tags remain the source of truth.
Do not use latest for production.
Never promote without rollback target.
Governance should reduce risk without killing delivery speed.
```

---

# Next Lesson

# Lesson 7.11 — Registry Security and Access Control Deep Dive

We will go deeper into:

```text id="0mik4x"
registry IAM
push vs pull identities
least privilege
repository policies
GitHub package permissions
ECR repository policies
cross-account access
token scopes
secret rotation
audit logs
break-glass access
registry incident response
supply-chain attack scenarios
```

[1]: https://docs.github.com/actions/deployment/targeting-different-environments/using-environments-for-deployment?utm_source=chatgpt.com "Managing environments for deployment"
[2]: https://docs.github.com/actions/deployment/protecting-deployments/creating-custom-deployment-protection-rules?utm_source=chatgpt.com "Creating custom deployment protection rules"
[3]: https://www.jenkins.io/doc/pipeline/steps/pipeline-input-step/?utm_source=chatgpt.com "Pipeline: Input Step"
[4]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-retag.html?utm_source=chatgpt.com "Retagging an image in Amazon ECR"
[5]: https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry?utm_source=chatgpt.com "Working with the Container registry"

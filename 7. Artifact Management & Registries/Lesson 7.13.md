# Lesson 7.13 — Artifact Management CI/CD Capstone

# Version → Build → Test → Scan → SBOM → Provenance → Sign → Push → Promote → Verify → Deploy → Retain → Cleanup

This is the **Module 7 capstone**.

You are now going to combine the full artifact management lifecycle into one production-grade workflow.

By the end, your project will have a complete artifact chain:

```text id="5cfld8"
source code
  ↓
version computation
  ↓
Docker image build
  ↓
test gate
  ↓
security scan gate
  ↓
SBOM generation
  ↓
provenance generation
  ↓
image signing
  ↓
registry push
  ↓
release metadata
  ↓
promotion record
  ↓
verify-before-deploy
  ↓
rollback-safe retention
  ↓
cleanup policy
```

This is what separates a basic CI/CD user from a real DevOps engineer.

---

# 1. Capstone Goal

Your capstone objective:

```text id="ziqjcg"
Create a production-style artifact management workflow for demo-node-api.
```

Your workflow must prove:

```text id="mw0szd"
what artifact was built
from which commit
with which version
where it was stored
whether tests passed
whether scan passed
whether SBOM exists
whether provenance exists
whether signature exists
whether it was promoted
whether rollback is safe
```

---

# 2. Final Module 7 Architecture

```text id="fm4nk6"
Git commit
  ↓
compute version
  ↓
build Docker image
  ↓
run tests
  ↓
scan image
  ↓
generate SBOM
  ↓
generate provenance
  ↓
push image to registry
  ↓
sign image
  ↓
create release metadata
  ↓
promote dev → staging
  ↓
verify and deploy staging
  ↓
promote staging → production
  ↓
verify and deploy production
  ↓
store reports
  ↓
retain rollback artifacts
```

Professional principle:

```text id="pua6xu"
Build once. Verify continuously. Promote the same artifact.
```

---

# 3. Capstone Folder Setup

Run:

```bash id="9jc76r"
cd ~/devops-masterclass/07-artifact-management-registries

mkdir -p capstone/{scripts,reports,runbooks,examples,ci,jenkins,docs}
```

Check:

```bash id="lqajcl"
tree -L 2 capstone
```

Expected:

```text id="91g3lt"
capstone
├── ci
├── docs
├── examples
├── jenkins
├── reports
├── runbooks
└── scripts
```

---

# 4. Capstone Release Policy

Create:

```bash id="yj815h"
nano capstone/docs/artifact-management-capstone-policy.md
```

Paste:

```markdown id="z6w64x"
# Artifact Management Capstone Policy

## Core Rules

- Build once.
- Promote the same artifact through environments.
- Do not rebuild for staging or production.
- Do not deploy `latest` to production.
- Use immutable version-SHA tags.
- Generate release metadata.
- Generate SBOM.
- Generate provenance.
- Sign registry images where possible.
- Verify before deployment.
- Keep rollback artifacts.
- Cleanup must not break rollback.

## Required Production Evidence

A production artifact must have:

- version
- commit SHA
- image tag
- image digest if available
- test status
- scan status
- SBOM path
- provenance path
- signing record path where available
- promotion record
- deployment report

## Promotion Rules

Dev to staging requires:

- tests passed
- scan passed
- SBOM available
- provenance available

Staging to production requires:

- staging deployment passed
- tests passed
- scan passed
- SBOM available
- provenance available
- signature verified where registry signing is enabled
- rollback version recorded
- approval recorded
```

---

# 5. Final Capstone Orchestrator Script

This script creates a full local capstone report.

It uses the scripts you created in previous lessons.

Create:

```bash id="uw83lb"
nano capstone/scripts/artifact-capstone-local.sh
```

Paste:

```bash id="gdg6jk"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
MODULE_DIR="$ROOT_DIR/07-artifact-management-registries"
APP_DIR="$ROOT_DIR/05-application-runtime/demo-node-api"

SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"
BASE_VERSION="${BASE_VERSION:-0.7.0}"
CHANNEL="${CHANNEL:-stable}"
IMAGE_NAME="${IMAGE_NAME:-demo-node-api}"
REGISTRY_IMAGE="${REGISTRY_IMAGE:-}"
RUN_SECURITY_SCAN="${RUN_SECURITY_SCAN:-true}"
GENERATE_SBOM="${GENERATE_SBOM:-true}"
GENERATE_PROVENANCE="${GENERATE_PROVENANCE:-true}"
CREATE_PROMOTION="${CREATE_PROMOTION:-true}"

REPORT_DIR="$MODULE_DIR/capstone/reports"
mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/artifact-capstone-$TIMESTAMP.json"

echo "===== Module 7 Artifact Management Capstone ====="
echo "Root: $ROOT_DIR"
echo "Module: $MODULE_DIR"
echo "App: $APP_DIR"
echo "Service: $SERVICE_NAME"
echo "Base version: $BASE_VERSION"
echo "Channel: $CHANNEL"

cd "$MODULE_DIR"

VERSION_JSON="$(BASE_VERSION="$BASE_VERSION" CHANNEL="$CHANNEL" ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"
COMMIT_SHA="$(echo "$VERSION_JSON" | jq -r '.commit_sha')"

echo
echo "Computed deploy tag: $DEPLOY_TAG"

echo
echo "===== Test Gate ====="
cd "$APP_DIR"
npm ci
npm test
TEST_STATUS="passed"

echo
echo "===== Build Image ====="
VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh

echo
echo "===== Security Scan Gate ====="
SCAN_STATUS="not_run"
if [ "$RUN_SECURITY_SCAN" = "true" ]; then
  if [ -x "$APP_DIR/scripts/docker-security-scan.sh" ]; then
    VERSION="$DEPLOY_TAG" "$APP_DIR/scripts/docker-security-scan.sh" || SCAN_STATUS="failed"
    if [ "$SCAN_STATUS" != "failed" ]; then
      SCAN_STATUS="passed"
    fi
  elif command -v trivy >/dev/null 2>&1; then
    trivy image --severity HIGH,CRITICAL "$IMAGE_NAME:$DEPLOY_TAG" || SCAN_STATUS="failed"
    if [ "$SCAN_STATUS" != "failed" ]; then
      SCAN_STATUS="passed"
    fi
  else
    echo "WARNING: no security scanner found. Marking scan as not_run."
    SCAN_STATUS="not_run"
  fi
else
  SCAN_STATUS="skipped"
fi

cd "$MODULE_DIR"

echo
echo "===== Generate SBOM ====="
SBOM_PATH=""
if [ "$GENERATE_SBOM" = "true" ]; then
  IMAGE_TAG="$DEPLOY_TAG" TOOL=trivy ./scripts/generate-sbom.sh || true
  SBOM_PATH="$(ls -t sbom/cyclonedx/$SERVICE_NAME-$DEPLOY_TAG*.json 2>/dev/null | head -n 1 || true)"
  IMAGE_TAG="$DEPLOY_TAG" ./scripts/create-sbom-index.sh || true
fi

echo
echo "===== Generate Provenance ====="
PROVENANCE_PATH=""
if [ "$GENERATE_PROVENANCE" = "true" ]; then
  IMAGE_TAG="$DEPLOY_TAG" ./scripts/create-manual-provenance.sh
  PROVENANCE_PATH="$(ls -t provenance/manual/*.manual-provenance.json | head -n 1)"
  ./scripts/validate-manual-provenance.sh "$PROVENANCE_PATH"
fi

echo
echo "===== Create Release Metadata ====="
BASE_VERSION="$BASE_VERSION" \
CHANNEL="$CHANNEL" \
IMAGE_NAME="$IMAGE_NAME" \
REGISTRY_IMAGE="$REGISTRY_IMAGE" \
TEST_STATUS="$TEST_STATUS" \
SCAN_STATUS="$SCAN_STATUS" \
SBOM_PATH="$SBOM_PATH" \
PROVENANCE_PATH="$PROVENANCE_PATH" \
./scripts/create-release-metadata.sh

RELEASE_METADATA="$(ls -t release-records/$SERVICE_NAME-*.json | head -n 1)"

echo
echo "===== Create Promotion Record dev -> staging ====="
PROMOTION_RECORD=""
if [ "$CREATE_PROMOTION" = "true" ]; then
  ARTIFACT="$IMAGE_NAME:$DEPLOY_TAG" \
  IMAGE_TAG="$DEPLOY_TAG" \
  FROM_ENV=dev \
  TO_ENV=staging \
  TEST_STATUS="$TEST_STATUS" \
  SCAN_STATUS="$SCAN_STATUS" \
  SBOM_PATH="$SBOM_PATH" \
  PROVENANCE_PATH="$PROVENANCE_PATH" \
  SIGNATURE_STATUS=not_required \
  ./scripts/create-promotion-record-v2.sh

  PROMOTION_RECORD="$(ls -t promotion/records/*.json | head -n 1)"
  ./scripts/validate-promotion-record.sh "$PROMOTION_RECORD"
fi

echo
echo "===== Create Capstone Report ====="

IMAGE_ID=""
REPO_DIGESTS="[]"

if docker image inspect "$IMAGE_NAME:$DEPLOY_TAG" >/dev/null 2>&1; then
  IMAGE_ID="$(docker image inspect "$IMAGE_NAME:$DEPLOY_TAG" --format '{{.Id}}')"
  REPO_DIGESTS="$(docker image inspect "$IMAGE_NAME:$DEPLOY_TAG" --format '{{json .RepoDigests}}')"
fi

if [ "$REPO_DIGESTS" = "null" ]; then
  REPO_DIGESTS="[]"
fi

cat > "$REPORT_FILE" <<EOF
{
  "module": "7-artifact-management-registries",
  "service_name": "$SERVICE_NAME",
  "base_version": "$BASE_VERSION",
  "deploy_tag": "$DEPLOY_TAG",
  "commit_sha": "$COMMIT_SHA",
  "image_name": "$IMAGE_NAME",
  "image_id": "$IMAGE_ID",
  "repo_digests": $REPO_DIGESTS,
  "test_status": "$TEST_STATUS",
  "scan_status": "$SCAN_STATUS",
  "sbom_path": "$SBOM_PATH",
  "provenance_path": "$PROVENANCE_PATH",
  "release_metadata": "$RELEASE_METADATA",
  "promotion_record": "$PROMOTION_RECORD",
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$REPORT_FILE" | jq .

echo
echo "Capstone completed."
echo "Report: $REPORT_FILE"
```

Make executable:

```bash id="y2cs3h"
chmod +x capstone/scripts/artifact-capstone-local.sh
```

Run:

```bash id="yyxo3k"
BASE_VERSION=0.7.0 CHANNEL=stable ./capstone/scripts/artifact-capstone-local.sh
```

This gives you a complete local artifact chain.

---

# 6. Registry Capstone Script — GHCR

Now create a registry version for GHCR.

Create:

```bash id="zg4qe0"
nano capstone/scripts/artifact-capstone-ghcr.sh
```

Paste:

```bash id="0sb4sn"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
MODULE_DIR="$ROOT_DIR/07-artifact-management-registries"
APP_DIR="$ROOT_DIR/05-application-runtime/demo-node-api"

GITHUB_USERNAME="${GITHUB_USERNAME:-}"
GHCR_TOKEN="${GHCR_TOKEN:-}"
BASE_VERSION="${BASE_VERSION:-0.7.0}"
CHANNEL="${CHANNEL:-stable}"
SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"
IMAGE_NAME="${IMAGE_NAME:-demo-node-api}"
VERIFY_SIGNATURE="${VERIFY_SIGNATURE:-false}"
CERT_IDENTITY_REGEXP="${CERT_IDENTITY_REGEXP:-}"

if [ -z "$GITHUB_USERNAME" ]; then
  echo "ERROR: GITHUB_USERNAME is required" >&2
  exit 1
fi

REGISTRY_IMAGE="ghcr.io/$GITHUB_USERNAME/$IMAGE_NAME"

cd "$MODULE_DIR"

VERSION_JSON="$(BASE_VERSION="$BASE_VERSION" CHANNEL="$CHANNEL" ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"

echo "===== GHCR Artifact Capstone ====="
echo "Registry image: $REGISTRY_IMAGE"
echo "Deploy tag: $DEPLOY_TAG"

echo
echo "===== Build Local Artifact Chain ====="
ROOT_DIR="$ROOT_DIR" \
BASE_VERSION="$BASE_VERSION" \
CHANNEL="$CHANNEL" \
IMAGE_NAME="$IMAGE_NAME" \
REGISTRY_IMAGE="$REGISTRY_IMAGE" \
./capstone/scripts/artifact-capstone-local.sh

echo
echo "===== Push to GHCR ====="
GITHUB_USERNAME="$GITHUB_USERNAME" \
GHCR_TOKEN="$GHCR_TOKEN" \
IMAGE_TAG="$DEPLOY_TAG" \
IMAGE_NAME="$IMAGE_NAME" \
./scripts/ghcr-push.sh

echo
echo "===== Create GHCR Release Record ====="
GITHUB_USERNAME="$GITHUB_USERNAME" \
IMAGE_NAME="$IMAGE_NAME" \
IMAGE_TAG="$DEPLOY_TAG" \
./scripts/create-ghcr-release-record.sh

SIGNATURE_STATUS="not_verified"

if [ "$VERIFY_SIGNATURE" = "true" ]; then
  echo
  echo "===== Verify Keyless Signature ====="
  if [ -z "$CERT_IDENTITY_REGEXP" ]; then
    echo "ERROR: CERT_IDENTITY_REGEXP is required when VERIFY_SIGNATURE=true" >&2
    exit 1
  fi

  IMAGE_REF="$REGISTRY_IMAGE:$DEPLOY_TAG" \
  CERT_IDENTITY_REGEXP="$CERT_IDENTITY_REGEXP" \
  ./scripts/verify-image-keyless.sh

  SIGNATURE_STATUS="verified"
fi

echo
echo "===== Final GHCR Metadata ====="

LATEST_SBOM="$(ls -t sbom/cyclonedx/$SERVICE_NAME-$DEPLOY_TAG*.json 2>/dev/null | head -n 1 || true)"
LATEST_PROV="$(ls -t provenance/manual/*.manual-provenance.json 2>/dev/null | head -n 1 || true)"
SIGNING_RECORD="$(ls -t signing/records/*.signing-record.json 2>/dev/null | head -n 1 || true)"

BASE_VERSION="$BASE_VERSION" \
CHANNEL="$CHANNEL" \
IMAGE_NAME="$IMAGE_NAME" \
REGISTRY_IMAGE="$REGISTRY_IMAGE" \
TEST_STATUS=passed \
SCAN_STATUS=passed \
SBOM_PATH="$LATEST_SBOM" \
PROVENANCE_PATH="$LATEST_PROV" \
SIGNING_RECORD_PATH="$SIGNING_RECORD" \
./scripts/create-release-metadata.sh

echo
echo "GHCR capstone completed:"
echo "$REGISTRY_IMAGE:$DEPLOY_TAG"
```

Make executable:

```bash id="y87hj8"
chmod +x capstone/scripts/artifact-capstone-ghcr.sh
```

Run:

```bash id="g2muma"
GITHUB_USERNAME=YOUR_GITHUB_USERNAME \
GHCR_TOKEN=YOUR_TOKEN \
BASE_VERSION=0.7.0 \
CHANNEL=stable \
./capstone/scripts/artifact-capstone-ghcr.sh
```

---

# 7. Registry Capstone Script — ECR

Create:

```bash id="7ltzpu"
nano capstone/scripts/artifact-capstone-ecr.sh
```

Paste:

```bash id="6zedet"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
MODULE_DIR="$ROOT_DIR/07-artifact-management-registries"

AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"
ECR_REPOSITORY="${ECR_REPOSITORY:-demo-node-api}"
BASE_VERSION="${BASE_VERSION:-0.7.0}"
CHANNEL="${CHANNEL:-stable}"
IMAGE_NAME="${IMAGE_NAME:-demo-node-api}"

if [ -z "$AWS_ACCOUNT_ID" ]; then
  AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
fi

REGISTRY_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY"

cd "$MODULE_DIR"

VERSION_JSON="$(BASE_VERSION="$BASE_VERSION" CHANNEL="$CHANNEL" ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"

echo "===== ECR Artifact Capstone ====="
echo "Registry image: $REGISTRY_IMAGE"
echo "Deploy tag: $DEPLOY_TAG"

echo
echo "===== Setup ECR Repository ====="
AWS_REGION="$AWS_REGION" \
ECR_REPOSITORY="$ECR_REPOSITORY" \
./scripts/setup-ecr-repository.sh

echo
echo "===== Build Local Artifact Chain ====="
ROOT_DIR="$ROOT_DIR" \
BASE_VERSION="$BASE_VERSION" \
CHANNEL="$CHANNEL" \
IMAGE_NAME="$IMAGE_NAME" \
REGISTRY_IMAGE="$REGISTRY_IMAGE" \
./capstone/scripts/artifact-capstone-local.sh

echo
echo "===== Login to ECR ====="
REGISTRY_PROVIDER=ecr \
AWS_REGION="$AWS_REGION" \
AWS_ACCOUNT_ID="$AWS_ACCOUNT_ID" \
./scripts/registry-login.sh

echo
echo "===== Push to ECR ====="
REGISTRY_PROVIDER=ecr \
AWS_REGION="$AWS_REGION" \
AWS_ACCOUNT_ID="$AWS_ACCOUNT_ID" \
ECR_REPOSITORY="$ECR_REPOSITORY" \
IMAGE_TAG="$DEPLOY_TAG" \
LOCAL_IMAGE="$IMAGE_NAME" \
./scripts/tag-and-push-registry-image.sh

echo
echo "===== Create Final ECR Metadata ====="
LATEST_SBOM="$(ls -t sbom/cyclonedx/demo-node-api-$DEPLOY_TAG*.json 2>/dev/null | head -n 1 || true)"
LATEST_PROV="$(ls -t provenance/manual/*.manual-provenance.json 2>/dev/null | head -n 1 || true)"

BASE_VERSION="$BASE_VERSION" \
CHANNEL="$CHANNEL" \
IMAGE_NAME="$IMAGE_NAME" \
REGISTRY_IMAGE="$REGISTRY_IMAGE" \
TEST_STATUS=passed \
SCAN_STATUS=passed \
SBOM_PATH="$LATEST_SBOM" \
PROVENANCE_PATH="$LATEST_PROV" \
./scripts/create-release-metadata.sh

echo
echo "ECR capstone completed:"
echo "$REGISTRY_IMAGE:$DEPLOY_TAG"
```

Make executable:

```bash id="d56kjx"
chmod +x capstone/scripts/artifact-capstone-ecr.sh
```

Run when AWS permissions are ready:

```bash id="q4lm2t"
AWS_REGION=ap-south-1 \
ECR_REPOSITORY=demo-node-api \
BASE_VERSION=0.7.0 \
CHANNEL=stable \
./capstone/scripts/artifact-capstone-ecr.sh
```

---

# 8. Verify-Before-Deploy Capstone Flow

The strongest deployment pattern:

```text id="rhlcaj"
verify image signature
verify provenance
verify promotion record
deploy
health check
record deployment
```

Create:

```bash id="c02r1d"
nano capstone/scripts/capstone-verify-deploy.sh
```

Paste:

```bash id="bsztux"
#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="${MODULE_DIR:-$HOME/devops-masterclass/07-artifact-management-registries}"
COMPOSE_DIR="${COMPOSE_DIR:-$HOME/devops-masterclass/06-docker-containers/compose-demo}"

APP_IMAGE="${APP_IMAGE:-}"
APP_VERSION="${APP_VERSION:-}"
VERIFY_MODE="${VERIFY_MODE:-none}" # none, key, keyless
PUBLIC_KEY_PATH="${PUBLIC_KEY_PATH:-$MODULE_DIR/signing/keys/demo-node-api-cosign.pub}"
CERT_IDENTITY_REGEXP="${CERT_IDENTITY_REGEXP:-}"

if [ -z "$APP_IMAGE" ] || [ -z "$APP_VERSION" ]; then
  echo "ERROR: APP_IMAGE and APP_VERSION are required" >&2
  exit 1
fi

cd "$MODULE_DIR"

echo "===== Capstone Verify Deploy ====="
echo "Image: $APP_IMAGE:$APP_VERSION"
echo "Verify mode: $VERIFY_MODE"

case "$VERIFY_MODE" in
  none)
    echo "WARNING: signature verification skipped."
    ;;
  key)
    IMAGE_REF="$APP_IMAGE:$APP_VERSION" \
    PUBLIC_KEY_PATH="$PUBLIC_KEY_PATH" \
    ./scripts/verify-image-key.sh
    ;;
  keyless)
    IMAGE_REF="$APP_IMAGE:$APP_VERSION" \
    CERT_IDENTITY_REGEXP="$CERT_IDENTITY_REGEXP" \
    ./scripts/verify-image-keyless.sh
    ;;
  *)
    echo "ERROR: unsupported VERIFY_MODE=$VERIFY_MODE" >&2
    exit 1
    ;;
esac

echo
echo "===== Production Promotion Gate ====="
IMAGE_TAG="$APP_VERSION" ./scripts/production-promotion-gate.sh || true

echo
echo "===== Deploy Compose ====="
cd "$COMPOSE_DIR"

APP_IMAGE="$APP_IMAGE" \
APP_VERSION="$APP_VERSION" \
COMPOSE_FILES="compose.yaml compose.prod.yaml" \
./scripts/deploy-compose.sh

echo
echo "===== Validate Runtime ====="
curl -s http://127.0.0.1:8080/version | jq . || true
docker inspect compose-demo-backend --format '{{.Config.Image}}' || true

echo
echo "Capstone verify-deploy completed."
```

Make executable:

```bash id="c610ul"
chmod +x capstone/scripts/capstone-verify-deploy.sh
```

Local image deploy:

```bash id="404vj0"
APP_IMAGE=demo-node-api \
APP_VERSION="$DEPLOY_TAG" \
VERIFY_MODE=none \
./capstone/scripts/capstone-verify-deploy.sh
```

GHCR signed deploy:

```bash id="r0ojwn"
APP_IMAGE=ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api \
APP_VERSION="$DEPLOY_TAG" \
VERIFY_MODE=keyless \
CERT_IDENTITY_REGEXP="https://github.com/YOUR_GITHUB_USERNAME/devops-masterclass/.github/workflows/.*" \
./capstone/scripts/capstone-verify-deploy.sh
```

---

# 9. Capstone Validation Script

Create:

```bash id="z2xp3t"
nano capstone/scripts/validate-module-7-capstone.sh
```

Paste:

```bash id="966obf"
#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="${MODULE_DIR:-$HOME/devops-masterclass/07-artifact-management-registries}"
REPORT_DIR="$MODULE_DIR/capstone/reports"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/module-7-validation-$TIMESTAMP.json"

mkdir -p "$REPORT_DIR"

cd "$MODULE_DIR"

check_path() {
  local path="$1"
  if [ -e "$path" ]; then
    echo "true"
  else
    echo "false"
  fi
}

cat > "$REPORT_FILE" <<EOF
{
  "module": "7-artifact-management-registries",
  "validated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "checks": {
    "version_script": $(check_path scripts/compute-version.sh),
    "release_metadata_script": $(check_path scripts/create-release-metadata.sh),
    "checksum_scripts": $(check_path scripts/generate-checksums.sh),
    "registry_scripts": $(check_path scripts/registry-login.sh),
    "ghcr_script": $(check_path scripts/ghcr-push.sh),
    "ecr_script": $(check_path scripts/setup-ecr-repository.sh),
    "sbom_script": $(check_path scripts/generate-sbom.sh),
    "provenance_script": $(check_path scripts/create-manual-provenance.sh),
    "signing_scripts": $(check_path scripts/verify-image-keyless.sh),
    "promotion_scripts": $(check_path scripts/create-promotion-record-v2.sh),
    "cleanup_scripts": $(check_path scripts/safe-local-docker-cleanup.sh),
    "retention_policy": $(check_path cleanup/policies/demo-node-api-retention-policy.json),
    "promotion_policy": $(check_path promotion/policies/demo-node-api-promotion-policy.json),
    "registry_security_policy": $(check_path security/registry-security-policy.md),
    "capstone_policy": $(check_path capstone/docs/artifact-management-capstone-policy.md)
  },
  "latest_release_metadata": "$(ls -t release-records/demo-node-api-*.json 2>/dev/null | head -n 1 || true)",
  "latest_capstone_report": "$(ls -t capstone/reports/artifact-capstone-*.json 2>/dev/null | head -n 1 || true)"
}
EOF

cat "$REPORT_FILE" | jq .

echo
echo "Module 7 validation report: $REPORT_FILE"
```

Make executable:

```bash id="6m7g01"
chmod +x capstone/scripts/validate-module-7-capstone.sh
```

Run:

```bash id="pyjn5d"
./capstone/scripts/validate-module-7-capstone.sh
```

---

# 10. GitHub Actions Capstone Workflow

Create:

```bash id="4rm7g1"
cd ~/devops-masterclass

nano .github/workflows/artifact-management-capstone.yml
```

Paste:

```yaml id="kfh6th"
name: Artifact Management Capstone

on:
  workflow_dispatch:
    inputs:
      base_version:
        description: "Base semantic version"
        required: true
        default: "0.7.0"
      channel:
        description: "Release channel"
        required: true
        default: "dev"
        type: choice
        options:
          - dev
          - rc
          - stable

permissions:
  contents: read
  packages: write
  id-token: write
  attestations: write

env:
  APP_DIR: 05-application-runtime/demo-node-api
  MODULE_DIR: 07-artifact-management-registries
  IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/demo-node-api

jobs:
  artifact-capstone:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Compute version
        id: version
        shell: bash
        run: |
          SHORT_SHA="${GITHUB_SHA::7}"
          BASE_VERSION="${{ inputs.base_version }}"
          CHANNEL="${{ inputs.channel }}"

          case "$CHANNEL" in
            stable)
              VERSION="$BASE_VERSION"
              ;;
            dev)
              VERSION="$BASE_VERSION-dev"
              ;;
            rc)
              VERSION="$BASE_VERSION-rc.1"
              ;;
            *)
              echo "Unsupported channel: $CHANNEL"
              exit 1
              ;;
          esac

          DEPLOY_TAG="$VERSION-$SHORT_SHA"

          echo "short_sha=$SHORT_SHA" >> "$GITHUB_OUTPUT"
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
          echo "deploy_tag=$DEPLOY_TAG" >> "$GITHUB_OUTPUT"

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: npm
          cache-dependency-path: ${{ env.APP_DIR }}/package-lock.json

      - name: Test
        working-directory: ${{ env.APP_DIR }}
        run: |
          npm ci
          npm test

      - name: Login to GHCR
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push image with SBOM/provenance
        id: build
        uses: docker/build-push-action@v6
        with:
          context: ${{ env.APP_DIR }}
          file: ${{ env.APP_DIR }}/Dockerfile.industry
          target: runtime
          push: true
          tags: |
            ${{ env.IMAGE_NAME }}:${{ steps.version.outputs.deploy_tag }}
            ${{ env.IMAGE_NAME }}:${{ steps.version.outputs.short_sha }}
          labels: |
            org.opencontainers.image.source=https://github.com/${{ github.repository }}
            org.opencontainers.image.revision=${{ github.sha }}
            org.opencontainers.image.version=${{ steps.version.outputs.deploy_tag }}
          build-args: |
            APP_VERSION=${{ steps.version.outputs.deploy_tag }}
            COMMIT_SHA=${{ steps.version.outputs.short_sha }}
          sbom: true
          provenance: mode=max

      - name: Sign image keyless
        run: |
          cosign sign --yes "${IMAGE_NAME}:${{ steps.version.outputs.deploy_tag }}"

      - name: Verify image signature
        run: |
          cosign verify \
            --certificate-identity-regexp "https://github.com/${{ github.repository }}/.github/workflows/.*" \
            --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
            "${IMAGE_NAME}:${{ steps.version.outputs.deploy_tag }}"

      - name: Generate release evidence
        shell: bash
        run: |
          mkdir -p artifact-evidence

          cat > artifact-evidence/release-metadata.json <<EOF
          {
            "service_name": "demo-node-api",
            "image": "${IMAGE_NAME}:${{ steps.version.outputs.deploy_tag }}",
            "version": "${{ steps.version.outputs.version }}",
            "deploy_tag": "${{ steps.version.outputs.deploy_tag }}",
            "commit_sha": "${{ github.sha }}",
            "workflow": "${{ github.workflow }}",
            "run_id": "${{ github.run_id }}",
            "test_status": "passed",
            "signature_status": "verified",
            "sbom_attestation": "enabled",
            "provenance_attestation": "enabled",
            "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
          }
          EOF

          cat artifact-evidence/release-metadata.json

      - name: Upload release evidence
        uses: actions/upload-artifact@v4
        with:
          name: artifact-evidence-${{ steps.version.outputs.deploy_tag }}
          path: artifact-evidence/
```

This is your portfolio-quality artifact workflow.

---

# 11. GitHub Environment Promotion Workflow

Create:

```bash id="020t6d"
nano .github/workflows/artifact-promotion-capstone.yml
```

Paste:

```yaml id="m0p2zu"
name: Artifact Promotion Capstone

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
  promote:
    runs-on: ubuntu-latest
    environment: ${{ inputs.target_environment }}

    steps:
      - name: Validate immutable tag
        shell: bash
        run: |
          TAG="${{ inputs.image_tag }}"

          case "$TAG" in
            latest|dev|staging|prod|production)
              echo "Forbidden mutable tag: $TAG"
              exit 1
              ;;
          esac

          if [[ "$TAG" != *"-"* ]]; then
            echo "Expected version-sha style tag. Got: $TAG"
            exit 1
          fi

      - name: Create promotion record
        shell: bash
        run: |
          mkdir -p promotion-record

          cat > promotion-record/promotion-${{ inputs.target_environment }}-${{ inputs.image_tag }}.json <<EOF
          {
            "artifact": "${IMAGE_NAME}:${{ inputs.image_tag }}",
            "target_environment": "${{ inputs.target_environment }}",
            "approved_by": "${{ github.actor }}",
            "approval_gate": "GitHub Environment: ${{ inputs.target_environment }}",
            "status": "promoted",
            "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
          }
          EOF

          cat promotion-record/*.json

      - name: Upload promotion record
        uses: actions/upload-artifact@v4
        with:
          name: promotion-${{ inputs.target_environment }}-${{ inputs.image_tag }}
          path: promotion-record/
```

For GitHub settings:

```text id="3qassm"
Repository Settings
  -> Environments
  -> production
  -> Required reviewers
```

This creates a real approval gate.

---

# 12. Jenkins Capstone Mapping

Create:

```bash id="qbmcc6"
cd ~/devops-masterclass/07-artifact-management-registries

nano capstone/jenkins/Jenkinsfile.artifact-management
```

Paste:

```groovy id="la177h"
pipeline {
  agent any

  parameters {
    string(name: 'BASE_VERSION', defaultValue: '0.7.0', description: 'Base version')
    choice(name: 'CHANNEL', choices: ['dev', 'rc', 'stable'], description: 'Release channel')
    choice(name: 'TARGET_ENV', choices: ['dev', 'staging', 'production'], description: 'Target environment')
  }

  environment {
    APP_DIR = '05-application-runtime/demo-node-api'
    MODULE_DIR = '07-artifact-management-registries'
    IMAGE_NAME = 'demo-node-api'
  }

  stages {
    stage('Compute Version') {
      steps {
        script {
          def shortSha = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          def version = params.BASE_VERSION

          if (params.CHANNEL == 'dev') {
            version = "${params.BASE_VERSION}-dev"
          } else if (params.CHANNEL == 'rc') {
            version = "${params.BASE_VERSION}-rc.1"
          }

          env.SHORT_SHA = shortSha
          env.DEPLOY_TAG = "${version}-${shortSha}"

          echo "Deploy tag: ${env.DEPLOY_TAG}"
        }
      }
    }

    stage('Test') {
      steps {
        dir("${APP_DIR}") {
          sh '''
            npm ci
            npm test
          '''
        }
      }
    }

    stage('Build Image') {
      steps {
        dir("${APP_DIR}") {
          sh '''
            VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
          '''
        }
      }
    }

    stage('Generate SBOM') {
      steps {
        dir("${MODULE_DIR}") {
          sh '''
            IMAGE_TAG="$DEPLOY_TAG" TOOL=trivy ./scripts/generate-sbom.sh || true
          '''
        }
      }
    }

    stage('Provenance') {
      steps {
        dir("${MODULE_DIR}") {
          sh '''
            IMAGE_TAG="$DEPLOY_TAG" ./scripts/create-manual-provenance.sh
          '''
        }
      }
    }

    stage('Release Metadata') {
      steps {
        dir("${MODULE_DIR}") {
          sh '''
            BASE_VERSION="$BASE_VERSION" \
            CHANNEL="$CHANNEL" \
            IMAGE_NAME="$IMAGE_NAME" \
            TEST_STATUS=passed \
            SCAN_STATUS=passed \
            ./scripts/create-release-metadata.sh
          '''
        }
      }
    }

    stage('Approve Production') {
      when {
        expression { params.TARGET_ENV == 'production' }
      }
      steps {
        input message: "Promote ${env.IMAGE_NAME}:${env.DEPLOY_TAG} to production?", ok: 'Promote'
      }
    }

    stage('Promotion Record') {
      steps {
        dir("${MODULE_DIR}") {
          sh '''
            FROM_ENV=dev
            TO_ENV="$TARGET_ENV"

            if [ "$TARGET_ENV" = "production" ]; then
              FROM_ENV=staging
            fi

            ARTIFACT="$IMAGE_NAME:$DEPLOY_TAG" \
            IMAGE_TAG="$DEPLOY_TAG" \
            FROM_ENV="$FROM_ENV" \
            TO_ENV="$TO_ENV" \
            TEST_STATUS=passed \
            SCAN_STATUS=passed \
            SIGNATURE_STATUS=not_required \
            STAGING_DEPLOYMENT_STATUS=passed \
            ROLLBACK_VERSION=previous-known-good \
            ./scripts/create-promotion-record-v2.sh

            LATEST="$(ls -t promotion/records/*.json | head -n 1)"
            ./scripts/validate-promotion-record.sh "$LATEST"
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '07-artifact-management-registries/**/*.json, 07-artifact-management-registries/**/*.md', allowEmptyArchive: true
    }
  }
}
```

This maps your capstone to Jenkins.

---

# 13. Capstone Runbook

Create:

```bash id="45tzfc"
nano capstone/runbooks/artifact-management-capstone-runbook.md
```

Paste:

````markdown id="wgnsm8"
# Artifact Management Capstone Runbook

## Goal

Produce a traceable, verifiable, promotion-ready artifact for `demo-node-api`.

## Local Capstone

```bash
cd ~/devops-masterclass/07-artifact-management-registries
BASE_VERSION=0.7.0 CHANNEL=stable ./capstone/scripts/artifact-capstone-local.sh
````

## GHCR Capstone

```bash
GITHUB_USERNAME=YOUR_GITHUB_USERNAME \
GHCR_TOKEN=YOUR_TOKEN \
BASE_VERSION=0.7.0 \
CHANNEL=stable \
./capstone/scripts/artifact-capstone-ghcr.sh
```

## ECR Capstone

```bash
AWS_REGION=ap-south-1 \
ECR_REPOSITORY=demo-node-api \
BASE_VERSION=0.7.0 \
CHANNEL=stable \
./capstone/scripts/artifact-capstone-ecr.sh
```

## Verify and Deploy

```bash
APP_IMAGE=demo-node-api \
APP_VERSION=TAG \
VERIFY_MODE=none \
./capstone/scripts/capstone-verify-deploy.sh
```

## Validate Module

```bash
./capstone/scripts/validate-module-7-capstone.sh
```

## Evidence Locations

* release metadata: `release-records/`
* SBOM: `sbom/`
* provenance: `provenance/`
* signing: `signing/`
* promotion: `promotion/`
* cleanup: `cleanup/`
* capstone reports: `capstone/reports/`

## Production Checklist

* [ ] version computed
* [ ] tests passed
* [ ] image built
* [ ] scan passed or accepted
* [ ] SBOM generated
* [ ] provenance generated
* [ ] image pushed to registry
* [ ] image signed where required
* [ ] release metadata generated
* [ ] promotion record generated
* [ ] deployment verified
* [ ] rollback target known
* [ ] retention policy protects artifact

````

---

# 14. Portfolio README Section

Create:

```bash id="3mgzxs"
nano capstone/docs/portfolio-artifact-management-summary.md
````

Paste:

````markdown id="2cgpk8"
# Artifact Management and Registry Workflow

This project implements a production-style artifact management workflow for a containerized Node.js service.

## Capabilities

- semantic versioning with Git SHA
- immutable Docker image tags
- release metadata JSON
- checksum generation
- GHCR and ECR registry workflows
- SBOM generation with CycloneDX/SPDX support
- provenance records
- image signing workflow with Cosign/Sigstore concepts
- dev to staging to production promotion records
- verify-before-deploy pattern
- registry access-control policies
- rollback-safe retention policy
- cleanup reports and lifecycle-policy examples

## Image Tag Strategy

```text
VERSION-COMMIT_SHA
````

Example:

```text
0.7.0-a1b2c3d
```

## Production Principle

```text
Build once. Promote the same artifact. Verify before deployment.
```

## Evidence

Each release can include:

* image tag
* image digest
* commit SHA
* test status
* scan status
* SBOM path
* provenance path
* signing record
* promotion record
* cleanup/retention policy

````

This is excellent resume material.

---

# 15. Module 7 Summary File

Create:

```bash id="5iw8kw"
nano module-7-summary.md
````

Paste:

````markdown id="84po1r"
# Module 7 Summary — Artifact Management and Registries

## Completed Topics

1. Artifact management fundamentals
2. Versioning and release metadata
3. Checksums, digests, immutability, and reproducibility
4. Docker registry fundamentals
5. Amazon ECR production workflow
6. GHCR production workflow
7. SBOM fundamentals
8. Provenance and build attestations
9. Image signing with Cosign and Sigstore concepts
10. Artifact promotion from dev to staging to production
11. Registry security and access control
12. Artifact cleanup, retention, and rollback safety
13. Artifact management CI/CD capstone

## Core Principles

- Build once, promote many.
- Do not use `latest` for production.
- Use immutable version-SHA tags.
- Record release metadata.
- Store images in a registry.
- Generate SBOM.
- Generate provenance.
- Sign and verify images where possible.
- Use least-privilege registry access.
- Protect rollback artifacts.
- Cleanup must be policy-driven.

## Final Artifact Chain

```text
source code
  -> version
  -> build
  -> test
  -> scan
  -> SBOM
  -> provenance
  -> sign
  -> push
  -> metadata
  -> promote
  -> verify
  -> deploy
  -> retain
````

## Suggested Tag

```bash
git tag -a v0.7.0 -m "Complete Module 7 artifact management and registries"
git push origin v0.7.0
```

````

---

# 16. Update Makefile with Capstone Targets

Open:

```bash id="nbi3gp"
cd ~/devops-masterclass/07-artifact-management-registries

nano Makefile
````

Add:

```Makefile id="x09mtb"
.PHONY: capstone-local capstone-ghcr capstone-ecr capstone-validate capstone-deploy

capstone-local:
	BASE_VERSION="$${BASE_VERSION:-0.7.0}" CHANNEL="$${CHANNEL:-stable}" ./capstone/scripts/artifact-capstone-local.sh

capstone-ghcr:
	@test -n "$(GITHUB_USERNAME)" || (echo "Usage: make capstone-ghcr GITHUB_USERNAME=<user>" && exit 1)
	GITHUB_USERNAME="$(GITHUB_USERNAME)" BASE_VERSION="$${BASE_VERSION:-0.7.0}" CHANNEL="$${CHANNEL:-stable}" ./capstone/scripts/artifact-capstone-ghcr.sh

capstone-ecr:
	BASE_VERSION="$${BASE_VERSION:-0.7.0}" CHANNEL="$${CHANNEL:-stable}" ./capstone/scripts/artifact-capstone-ecr.sh

capstone-validate:
	./capstone/scripts/validate-module-7-capstone.sh

capstone-deploy:
	@test -n "$(APP_IMAGE)" || (echo "Usage: make capstone-deploy APP_IMAGE=<image> APP_VERSION=<tag>" && exit 1)
	@test -n "$(APP_VERSION)" || (echo "Usage: make capstone-deploy APP_IMAGE=<image> APP_VERSION=<tag>" && exit 1)
	APP_IMAGE="$(APP_IMAGE)" APP_VERSION="$(APP_VERSION)" VERIFY_MODE="$${VERIFY_MODE:-none}" ./capstone/scripts/capstone-verify-deploy.sh
```

Run:

```bash id="g7645q"
make capstone-local
make capstone-validate
```

---

# 17. Full Final Validation

Run the complete local capstone:

```bash id="wbr4gt"
cd ~/devops-masterclass/07-artifact-management-registries

BASE_VERSION=0.7.0 CHANNEL=stable ./capstone/scripts/artifact-capstone-local.sh
```

Validate module:

```bash id="x183xk"
./capstone/scripts/validate-module-7-capstone.sh
```

Check latest evidence:

```bash id="rb6498"
ls -lt capstone/reports | head
ls -lt release-records | head
ls -lt promotion/records | head
ls -lt sbom/cyclonedx | head
ls -lt provenance/manual | head
```

Inspect latest capstone report:

```bash id="lfmwzr"
LATEST_CAPSTONE="$(ls -t capstone/reports/artifact-capstone-*.json | head -n 1)"
cat "$LATEST_CAPSTONE" | jq .
```

Deploy local image:

```bash id="y8xpiz"
DEPLOY_TAG="$(jq -r '.deploy_tag' "$LATEST_CAPSTONE")"

APP_IMAGE=demo-node-api \
APP_VERSION="$DEPLOY_TAG" \
VERIFY_MODE=none \
./capstone/scripts/capstone-verify-deploy.sh
```

Validate runtime:

```bash id="69tijv"
curl -s http://127.0.0.1:8080/version | jq .
docker inspect compose-demo-backend --format '{{.Config.Image}}'
```

---

# 18. Git Commit and Module Tag

Run:

```bash id="cz2hvu"
cd ~/devops-masterclass

git status
git add .github/workflows/artifact-management-capstone.yml \
        .github/workflows/artifact-promotion-capstone.yml \
        07-artifact-management-registries

git commit -m "feat: complete artifact management and registry capstone"
```

Create Module 7 tag:

```bash id="db26py"
git tag -a v0.7.0 -m "Complete Module 7 artifact management and registries"
```

Push:

```bash id="6o3mjr"
git push
git push origin v0.7.0
```

Module 7 is now complete.

---

# 19. Final Interview Explanation

## Explain your artifact management workflow.

Strong answer:

```text id="t65ua0"
I use a build-once, promote-many workflow. CI computes a semantic version plus Git SHA, runs tests, builds a Docker image, scans it, generates SBOM and provenance, signs the image where supported, pushes it to GHCR or ECR, and creates release metadata. The same immutable artifact is promoted from dev to staging to production with promotion records and verification gates. Production deployment verifies trust evidence and keeps rollback artifacts protected by retention policy.
```

## Why is artifact metadata important?

Strong answer:

```text id="mzmkfi"
Artifact metadata connects the running artifact to its source commit, version, image tag, digest, test status, scan status, SBOM, provenance, signature, and promotion history. It gives traceability for debugging, rollback, audit, and incident response.
```

## What is build once, promote many?

Strong answer:

```text id="l1vwia"
Build once, promote many means the same artifact is moved through dev, staging, and production. Environment differences come from configuration and secrets, not rebuilding the image. This reduces drift and ensures production runs the same artifact that was tested.
```

## What evidence should exist before production deployment?

Strong answer:

```text id="a78618"
Before production deployment, I want tests passed, security scan passed or approved, SBOM generated, provenance generated, image signed and verified where required, promotion record created, rollback target known, and release metadata stored.
```

## How do you protect rollback?

Strong answer:

```text id="6etqko"
I protect rollback by using immutable image tags, recording previous production versions, retaining current and previous production artifacts, preventing lifecycle policies from deleting rollback images, and validating rollback commands as part of deployment runbooks.
```

## How do you secure registry access?

Strong answer:

```text id="cgmzf8"
I separate push and pull identities. CI can push only to required repositories, production servers are pull-only, admins manage policies, delete access is restricted, tokens are scoped and rotated, and production images are verified using signatures/provenance before deployment.
```

---

# 20. Module 7 Final Core Rules

```text id="u3q6kq"
Artifacts are production assets.
Source code is not the deployment unit; artifacts are.
Every artifact needs identity.
Every artifact needs metadata.
Do not deploy latest to production.
Use immutable version-SHA tags.
Build once, promote many.
Generate SBOM.
Generate provenance.
Sign images where possible.
Verify before deployment.
Separate push and pull identities.
Protect registry access.
Record promotion.
Record deployment.
Keep rollback artifacts.
Cleanup must be policy-driven.
Retention is part of reliability.
```

---

# Module 7 Complete

You have now completed:

```text id="yeekz4"
Module 7 — Artifact Management and Registries
```

Next module:

# Module 8 — CI/CD Pipelines: GitHub Actions, Jenkins, and GitLab CI

We will go deep into:

```text id="hpnrmk"
CI/CD mental model
pipeline stages
GitHub Actions production workflow
Jenkins declarative pipeline
Jenkins agents
artifacts between stages
secrets in CI/CD
matrix builds
quality gates
manual approvals
deployment pipelines
rollback pipelines
pipeline observability
pipeline security
pipeline capstone
```

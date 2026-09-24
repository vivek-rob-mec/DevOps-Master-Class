# Lesson 8.12 — CI/CD Capstone Project

# GitHub Actions + Jenkins + GitLab CI + Secrets/OIDC + Quality Gates + Artifact Build + Registry Push + Deployment + Rollback + Observability

This is the final lesson of **Module 8 — CI/CD Pipelines**.

You have learned:

```text
8.1  CI/CD mental model
8.2  GitHub Actions fundamentals
8.3  GitHub Actions production pipeline
8.4  Jenkins fundamentals
8.5  Jenkins production pipeline
8.6  GitLab CI fundamentals
8.7  GitLab CI production pipeline
8.8  Secrets and OIDC
8.9  Quality gates and DevSecOps checks
8.10 Deployment and rollback pipelines
8.11 Pipeline observability and debugging
```

Now we combine everything into one production-style capstone.

---

# 1. Capstone Goal

By the end, your repo will contain a complete CI/CD reference architecture:

```text
source code
  ↓
quality gates
  ↓
test
  ↓
Docker build
  ↓
scan
  ↓
SBOM
  ↓
provenance
  ↓
signing-ready workflow
  ↓
release metadata
  ↓
promotion record
  ↓
deployment dry-run / real deploy path
  ↓
rollback workflow
  ↓
observability reports
  ↓
debug bundle
```

This capstone is designed to be useful for:

```text
portfolio
resume discussion
interview answers
real project extension
future Kubernetes/GitOps module
```

---

# 2. Create Capstone Directory

Run:

```bash
cd ~/devops-masterclass/08-cicd-pipelines

mkdir -p capstone/{scripts,github-actions,jenkins,gitlab,docs,runbooks,reports,examples}
```

Check:

```bash
tree -L 2 capstone
```

Expected:

```text
capstone
├── docs
├── examples
├── github-actions
├── gitlab
├── jenkins
├── reports
├── runbooks
└── scripts
```

---

# 3. Capstone Architecture Document

Create:

```bash
nano capstone/docs/module-8-capstone-architecture.md
```

Paste:

````markdown
# Module 8 CI/CD Capstone Architecture

## Service

`demo-node-api`

## Pipeline Flow

```text
Git push / manual trigger
  -> pipeline context
  -> quality gates
  -> dependency install
  -> tests
  -> version computation
  -> Docker image build
  -> optional scan
  -> optional SBOM
  -> provenance record
  -> release metadata
  -> deployment dry-run or deployment workflow
  -> rollback workflow
  -> observability summary
````

## CI/CD Platforms

This capstone includes examples for:

* GitHub Actions
* Jenkins
* GitLab CI

## Production Principles

* Build once, promote many.
* Do not deploy `latest`.
* Use immutable version-SHA tags.
* Store release metadata.
* Generate SBOM and provenance.
* Protect secrets.
* Prefer OIDC for cloud credentials.
* Require rollback version before production.
* Verify runtime after deployment.
* Archive reports and evidence.

````

---

# 4. Local CI/CD Capstone Orchestrator

This script runs the full capstone locally.

Create:

```bash
nano capstone/scripts/cicd-capstone-local.sh
````

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
APP_DIR="${APP_DIR:-$ROOT_DIR/05-application-runtime/demo-node-api}"
MODULE7_DIR="${MODULE7_DIR:-$ROOT_DIR/07-artifact-management-registries}"
MODULE8_DIR="${MODULE8_DIR:-$ROOT_DIR/08-cicd-pipelines}"

BASE_VERSION="${BASE_VERSION:-0.8.0}"
CHANNEL="${CHANNEL:-dev}"
RUN_QUALITY_GATES="${RUN_QUALITY_GATES:-true}"
STRICT_GATES="${STRICT_GATES:-false}"
RUN_DOCKER_BUILD="${RUN_DOCKER_BUILD:-true}"
RUN_DEPLOYMENT_DRY_RUN="${RUN_DEPLOYMENT_DRY_RUN:-true}"

SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"
APP_IMAGE="${APP_IMAGE:-demo-node-api}"
TARGET_ENV="${TARGET_ENV:-staging}"
ROLLBACK_VERSION="${ROLLBACK_VERSION:-0.7.0-local-rollback}"

REPORT_DIR="$MODULE8_DIR/capstone/reports"
mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
CAPSTONE_REPORT="$REPORT_DIR/module-8-capstone-$TIMESTAMP.json"

echo "===== Module 8 CI/CD Capstone ====="
echo "Root: $ROOT_DIR"
echo "Base version: $BASE_VERSION"
echo "Channel: $CHANNEL"
echo "Target env: $TARGET_ENV"

cd "$ROOT_DIR"

echo
echo "===== Pipeline Context ====="
cd "$MODULE8_DIR"
CI_SYSTEM="local-capstone" \
PIPELINE_NAME="module-8-cicd-capstone" \
PIPELINE_RUN_ID="$TIMESTAMP" \
JOB_NAME="local-capstone" \
./pipeline-observability/scripts/create-pipeline-context.sh

echo
echo "===== Compute Version ====="
cd "$MODULE7_DIR"
VERSION_JSON="$(BASE_VERSION="$BASE_VERSION" CHANNEL="$CHANNEL" ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"
SHORT_SHA="$(echo "$VERSION_JSON" | jq -r '.short_sha // empty')"

echo "$VERSION_JSON" | jq .
echo "Deploy tag: $DEPLOY_TAG"

echo
echo "===== Quality Gates ====="
QUALITY_STATUS="skipped"
if [ "$RUN_QUALITY_GATES" = "true" ]; then
  cd "$MODULE8_DIR"
  STRICT="$STRICT_GATES" ./quality-gates/scripts/run-quality-gates.sh
  QUALITY_STATUS="passed"
fi

echo
echo "===== Docker Build ====="
BUILD_STATUS="skipped"
if [ "$RUN_DOCKER_BUILD" = "true" ]; then
  cd "$APP_DIR"
  VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
  BUILD_STATUS="passed"
fi

echo
echo "===== Release Metadata ====="
cd "$MODULE7_DIR"
BASE_VERSION="$BASE_VERSION" \
CHANNEL="$CHANNEL" \
IMAGE_NAME="$APP_IMAGE" \
TEST_STATUS="passed" \
SCAN_STATUS="not_run_local_capstone" \
./scripts/create-release-metadata.sh

LATEST_METADATA="$(ls -t release-records/demo-node-api-*.json | head -n 1)"
echo "Latest metadata: $LATEST_METADATA"

echo
echo "===== Promotion Record ====="
ARTIFACT="$APP_IMAGE:$DEPLOY_TAG" \
IMAGE_TAG="$DEPLOY_TAG" \
FROM_ENV="dev" \
TO_ENV="$TARGET_ENV" \
TEST_STATUS="passed" \
SCAN_STATUS="not_run_local_capstone" \
SIGNATURE_STATUS="not_signed_local_capstone" \
"$MODULE7_DIR/scripts/create-promotion-record-v2.sh"

LATEST_PROMOTION="$(ls -t promotion/records/*.json | head -n 1)"
echo "Latest promotion: $LATEST_PROMOTION"

echo
echo "===== Deployment Dry Run ====="
DEPLOYMENT_STATUS="skipped"
if [ "$RUN_DEPLOYMENT_DRY_RUN" = "true" ]; then
  cd "$MODULE8_DIR"
  TARGET_ENV="$TARGET_ENV" \
  APP_IMAGE="$APP_IMAGE" \
  APP_VERSION="$DEPLOY_TAG" \
  ROLLBACK_VERSION="$ROLLBACK_VERSION" \
  DEPLOYMENT_STATUS="capstone_dry_run_success" \
  CI_SYSTEM="local-capstone" \
  ./deployment-rollback/scripts/create-deployment-record.sh

  DEPLOYMENT_STATUS="dry_run_success"
fi

echo
echo "===== Observability Summary ====="
cd "$MODULE8_DIR"
PIPELINE_STATUS="passed" \
CI_SYSTEM="local-capstone" \
ARTIFACT="$APP_IMAGE:$DEPLOY_TAG" \
TARGET_ENV="$TARGET_ENV" \
ROLLBACK_VERSION="$ROLLBACK_VERSION" \
./pipeline-observability/scripts/create-pipeline-summary.sh

cat > "$CAPSTONE_REPORT" <<EOF
{
  "module": "8",
  "module_name": "CI/CD Pipelines",
  "service_name": "$SERVICE_NAME",
  "base_version": "$BASE_VERSION",
  "channel": "$CHANNEL",
  "deploy_tag": "$DEPLOY_TAG",
  "artifact": "$APP_IMAGE:$DEPLOY_TAG",
  "target_environment": "$TARGET_ENV",
  "rollback_version": "$ROLLBACK_VERSION",
  "quality_status": "$QUALITY_STATUS",
  "build_status": "$BUILD_STATUS",
  "deployment_status": "$DEPLOYMENT_STATUS",
  "release_metadata": "$LATEST_METADATA",
  "promotion_record": "$LATEST_PROMOTION",
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$CAPSTONE_REPORT" | jq .

echo
echo "Module 8 capstone completed."
echo "Report: $CAPSTONE_REPORT"
```

Make executable:

```bash
chmod +x capstone/scripts/cicd-capstone-local.sh
```

Run:

```bash
BASE_VERSION=0.8.0 \
CHANNEL=dev \
RUN_QUALITY_GATES=true \
STRICT_GATES=false \
RUN_DOCKER_BUILD=true \
RUN_DEPLOYMENT_DRY_RUN=true \
./capstone/scripts/cicd-capstone-local.sh
```

---

# 5. Capstone GitHub Actions Workflow

Create:

```bash
nano capstone/github-actions/module-8-cicd-capstone.yml
```

Paste:

```yaml
name: Module 8 CI/CD Capstone

on:
  workflow_dispatch:
    inputs:
      base_version:
        description: "Base version"
        required: true
        default: "0.8.0"
        type: string
      channel:
        description: "Release channel"
        required: true
        default: "dev"
        type: choice
        options:
          - dev
          - rc
          - stable
      run_quality_gates:
        required: true
        default: true
        type: boolean
      push_image:
        required: true
        default: false
        type: boolean

permissions:
  contents: read
  packages: write
  id-token: write
  attestations: write

env:
  APP_DIR: 05-application-runtime/demo-node-api
  MODULE7_DIR: 07-artifact-management-registries
  MODULE8_DIR: 08-cicd-pipelines
  IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/demo-node-api
  NODE_VERSION: "22"

jobs:
  capstone:
    name: Module 8 capstone
    runs-on: ubuntu-latest

    outputs:
      deploy_tag: ${{ steps.version.outputs.deploy_tag }}
      image_ref: ${{ steps.image.outputs.image_ref }}

    steps:
      - uses: actions/checkout@v4

      - name: Create pipeline context
        run: |
          cd "$MODULE8_DIR"
          CI_SYSTEM="github-actions" \
          PIPELINE_NAME="${{ github.workflow }}" \
          PIPELINE_RUN_ID="${{ github.run_id }}" \
          JOB_NAME="module-8-capstone" \
          BUILD_URL="https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}" \
          REPOSITORY="${{ github.repository }}" \
          BRANCH="${{ github.ref_name }}" \
          COMMIT_SHA="${{ github.sha }}" \
          SHORT_SHA="${GITHUB_SHA::7}" \
          TRIGGERED_BY="${{ github.actor }}" \
          ./pipeline-observability/scripts/create-pipeline-context.sh

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm
          cache-dependency-path: ${{ env.APP_DIR }}/package-lock.json

      - name: Install dependencies
        working-directory: ${{ env.APP_DIR }}
        run: npm ci

      - name: Compute version
        id: version
        run: |
          cd "$MODULE7_DIR"
          VERSION_JSON="$(BASE_VERSION='${{ inputs.base_version }}' CHANNEL='${{ inputs.channel }}' ./scripts/compute-version.sh)"
          echo "$VERSION_JSON" | jq .

          DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"
          SHORT_SHA="$(echo "$VERSION_JSON" | jq -r '.short_sha // empty')"

          echo "deploy_tag=$DEPLOY_TAG" >> "$GITHUB_OUTPUT"
          echo "short_sha=$SHORT_SHA" >> "$GITHUB_OUTPUT"

      - name: Run quality gates
        if: ${{ inputs.run_quality_gates }}
        run: |
          cd "$MODULE8_DIR"
          STRICT=false ./quality-gates/scripts/run-quality-gates.sh

      - name: Define image ref
        id: image
        run: |
          IMAGE_REF="${IMAGE_NAME}:${{ steps.version.outputs.deploy_tag }}"
          echo "image_ref=$IMAGE_REF" >> "$GITHUB_OUTPUT"
          echo "Image: $IMAGE_REF"

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        if: ${{ inputs.push_image }}
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build image
        uses: docker/build-push-action@v6
        with:
          context: ${{ env.APP_DIR }}
          file: ${{ env.APP_DIR }}/Dockerfile.industry
          target: runtime
          push: ${{ inputs.push_image }}
          tags: ${{ steps.image.outputs.image_ref }}
          build-args: |
            APP_VERSION=${{ steps.version.outputs.deploy_tag }}
            COMMIT_SHA=${{ steps.version.outputs.short_sha }}
          sbom: true
          provenance: mode=max

      - name: Create release metadata
        run: |
          cd "$MODULE7_DIR"
          BASE_VERSION="${{ inputs.base_version }}" \
          CHANNEL="${{ inputs.channel }}" \
          IMAGE_NAME="${{ steps.image.outputs.image_ref }}" \
          TEST_STATUS="passed" \
          SCAN_STATUS="github_actions_capstone" \
          ./scripts/create-release-metadata.sh

      - name: Create deployment dry-run record
        run: |
          cd "$MODULE8_DIR"
          TARGET_ENV="staging" \
          APP_IMAGE="${{ env.IMAGE_NAME }}" \
          APP_VERSION="${{ steps.version.outputs.deploy_tag }}" \
          ROLLBACK_VERSION="previous-known-good" \
          DEPLOYMENT_STATUS="github_actions_capstone_dry_run_success" \
          CI_SYSTEM="github-actions" \
          ./deployment-rollback/scripts/create-deployment-record.sh

      - name: Create pipeline summary
        if: always()
        run: |
          cd "$MODULE8_DIR"
          PIPELINE_STATUS="${{ job.status }}" \
          CI_SYSTEM="github-actions" \
          ARTIFACT="${{ steps.image.outputs.image_ref }}" \
          TARGET_ENV="staging" \
          ROLLBACK_VERSION="previous-known-good" \
          ./pipeline-observability/scripts/create-pipeline-summary.sh

      - name: Write job summary
        if: always()
        run: |
          {
            echo "## Module 8 CI/CD Capstone"
            echo ""
            echo "- Status: \`${{ job.status }}\`"
            echo "- Deploy tag: \`${{ steps.version.outputs.deploy_tag }}\`"
            echo "- Image: \`${{ steps.image.outputs.image_ref }}\`"
            echo "- Push image: \`${{ inputs.push_image }}\`"
          } >> "$GITHUB_STEP_SUMMARY"

      - name: Upload capstone evidence
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: module-8-capstone-evidence
          path: |
            08-cicd-pipelines/capstone/reports/
            08-cicd-pipelines/quality-gates/reports/
            08-cicd-pipelines/deployment-rollback/reports/
            08-cicd-pipelines/pipeline-observability/reports/
            07-artifact-management-registries/release-records/
            07-artifact-management-registries/promotion/records/
```

Copy into real workflow path:

```bash
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 08-cicd-pipelines/capstone/github-actions/module-8-cicd-capstone.yml \
   .github/workflows/module-8-cicd-capstone.yml
```

---

# 6. Capstone Jenkinsfile

Create:

```bash
cd ~/devops-masterclass/08-cicd-pipelines

nano capstone/jenkins/Jenkinsfile.module-8-capstone
```

Paste:

```groovy
pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    timeout(time: 60, unit: 'MINUTES')
  }

  parameters {
    string(name: 'BASE_VERSION', defaultValue: '0.8.0', description: 'Base semantic version')
    choice(name: 'CHANNEL', choices: ['dev', 'rc', 'stable'], description: 'Release channel')
    booleanParam(name: 'RUN_QUALITY_GATES', defaultValue: true, description: 'Run quality gates?')
    booleanParam(name: 'STRICT_GATES', defaultValue: false, description: 'Strict quality gates?')
    booleanParam(name: 'RUN_DOCKER_BUILD', defaultValue: true, description: 'Build Docker image?')
    booleanParam(name: 'RUN_DEPLOYMENT_DRY_RUN', defaultValue: true, description: 'Create deployment dry-run?')
    string(name: 'ROLLBACK_VERSION', defaultValue: '0.7.0-local-rollback', description: 'Rollback version')
  }

  environment {
    MODULE8_DIR = '08-cicd-pipelines'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Run Capstone') {
      steps {
        dir("${MODULE8_DIR}") {
          sh '''
            BASE_VERSION="${BASE_VERSION}" \
            CHANNEL="${CHANNEL}" \
            RUN_QUALITY_GATES="${RUN_QUALITY_GATES}" \
            STRICT_GATES="${STRICT_GATES}" \
            RUN_DOCKER_BUILD="${RUN_DOCKER_BUILD}" \
            RUN_DEPLOYMENT_DRY_RUN="${RUN_DEPLOYMENT_DRY_RUN}" \
            ROLLBACK_VERSION="${ROLLBACK_VERSION}" \
            ./capstone/scripts/cicd-capstone-local.sh
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '''
        08-cicd-pipelines/capstone/reports/**/*,
        08-cicd-pipelines/quality-gates/reports/**/*,
        08-cicd-pipelines/deployment-rollback/reports/**/*,
        08-cicd-pipelines/pipeline-observability/reports/**/*,
        07-artifact-management-registries/release-records/**/*,
        07-artifact-management-registries/promotion/records/**/*
      ''', allowEmptyArchive: true
    }

    success {
      echo 'Module 8 CI/CD capstone succeeded.'
    }

    failure {
      echo 'Module 8 CI/CD capstone failed. Review archived evidence.'
    }
  }
}
```

Jenkins job script path:

```text
08-cicd-pipelines/capstone/jenkins/Jenkinsfile.module-8-capstone
```

---

# 7. Capstone GitLab CI Pipeline

Create:

```bash
nano capstone/gitlab/.gitlab-ci.module-8-capstone.yml
```

Paste:

```yaml
stages:
  - capstone

variables:
  MODULE8_DIR: "08-cicd-pipelines"
  BASE_VERSION: "0.8.0"
  CHANNEL: "dev"
  RUN_QUALITY_GATES: "true"
  STRICT_GATES: "false"
  RUN_DOCKER_BUILD: "false"
  RUN_DEPLOYMENT_DRY_RUN: "true"
  ROLLBACK_VERSION: "0.7.0-local-rollback"

module_8_cicd_capstone:
  stage: capstone
  image: node:22-alpine
  before_script:
    - apk add --no-cache bash git jq docker-cli curl grep findutils
  script:
    - cd "$MODULE8_DIR"
    - |
      BASE_VERSION="$BASE_VERSION" \
      CHANNEL="$CHANNEL" \
      RUN_QUALITY_GATES="$RUN_QUALITY_GATES" \
      STRICT_GATES="$STRICT_GATES" \
      RUN_DOCKER_BUILD="$RUN_DOCKER_BUILD" \
      RUN_DEPLOYMENT_DRY_RUN="$RUN_DEPLOYMENT_DRY_RUN" \
      ROLLBACK_VERSION="$ROLLBACK_VERSION" \
      ./capstone/scripts/cicd-capstone-local.sh
  artifacts:
    when: always
    expire_in: 30 days
    paths:
      - 08-cicd-pipelines/capstone/reports/
      - 08-cicd-pipelines/quality-gates/reports/
      - 08-cicd-pipelines/deployment-rollback/reports/
      - 08-cicd-pipelines/pipeline-observability/reports/
      - 07-artifact-management-registries/release-records/
      - 07-artifact-management-registries/promotion/records/
```

Note:

```text
RUN_DOCKER_BUILD=false is safer for generic GitLab runners.
Enable Docker build only on Docker-capable trusted runners.
```

---

# 8. Capstone Validation Script

Create:

```bash
nano capstone/scripts/validate-module-8-capstone.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-capstone}"

echo "===== Validate Module 8 Capstone ====="

test -x "$BASE_DIR/scripts/cicd-capstone-local.sh"
test -f "$BASE_DIR/github-actions/module-8-cicd-capstone.yml"
test -f "$BASE_DIR/jenkins/Jenkinsfile.module-8-capstone"
test -f "$BASE_DIR/gitlab/.gitlab-ci.module-8-capstone.yml"
test -f "$BASE_DIR/docs/module-8-capstone-architecture.md"

test -d quality-gates
test -d deployment-rollback
test -d pipeline-observability
test -d secrets-oidc

test -x quality-gates/scripts/run-quality-gates.sh
test -x deployment-rollback/scripts/create-deployment-record.sh
test -x pipeline-observability/scripts/create-pipeline-summary.sh

echo "Module 8 capstone files validated."
```

Make executable:

```bash
chmod +x capstone/scripts/validate-module-8-capstone.sh
```

Run:

```bash
./capstone/scripts/validate-module-8-capstone.sh
```

---

# 9. Module 8 Final Summary

Create:

```bash
nano module-8-summary.md
```

Paste:

```markdown
# Module 8 Summary — CI/CD Pipelines

## Completed Topics

- CI/CD mental model
- GitHub Actions fundamentals
- GitHub Actions production pipeline
- Jenkins fundamentals
- Jenkins production pipeline
- GitLab CI fundamentals
- GitLab CI production pipeline
- Secrets and OIDC
- Quality gates and DevSecOps checks
- Deployment and rollback pipelines
- Pipeline observability and debugging
- CI/CD capstone project

## Platforms Covered

- GitHub Actions
- Jenkins
- GitLab CI

## Production Concepts Practiced

- stages, jobs, steps, runners, agents
- workflow triggers
- parameters and manual inputs
- environment approvals
- Jenkins input approvals
- GitLab manual jobs
- artifact reports
- quality gates
- secret handling
- OIDC patterns
- Docker image build
- registry push patterns
- SBOM/provenance patterns
- deployment records
- rollback workflows
- observability summaries
- debug bundles

## Core Production Rules

- Build once, promote many.
- Do not deploy `latest`.
- Use immutable version-SHA tags.
- Store release metadata.
- Generate SBOM and provenance.
- Protect secrets.
- Prefer OIDC for cloud access.
- Require rollback version for production.
- Verify runtime after deployment.
- Archive reports and evidence.
```

---

# 10. Portfolio Summary

Create:

```bash
nano capstone/docs/portfolio-cicd-summary.md
```

Paste:

```markdown
# Portfolio Summary — Production CI/CD Pipeline

I built a production-style CI/CD system for a Node.js Dockerized application using GitHub Actions, Jenkins, and GitLab CI.

The pipeline includes source validation, dependency installation, automated testing, quality gates, Docker image build, registry push patterns, SBOM/provenance generation, release metadata, promotion records, deployment and rollback workflows, secrets/OIDC security patterns, and pipeline observability.

## Key Skills Demonstrated

- CI/CD architecture
- GitHub Actions workflows
- Jenkins declarative pipelines
- GitLab CI pipelines
- Docker-based build pipelines
- artifact traceability
- quality gates
- DevSecOps checks
- secret management
- OIDC cloud authentication patterns
- deployment verification
- rollback automation
- pipeline observability
- structured release evidence

## Production Practices

- immutable version-SHA image tags
- build once, promote many
- explicit quality gates
- environment approvals
- rollback metadata
- archived reports
- structured deployment records
- secure secret handling
```

---

# 11. Add Makefile Targets

Open:

```bash
cd ~/devops-masterclass/08-cicd-pipelines

nano Makefile
```

Add:

```Makefile
.PHONY: capstone capstone-validate capstone-reports

capstone:
	./capstone/scripts/cicd-capstone-local.sh

capstone-validate:
	./capstone/scripts/validate-module-8-capstone.sh

capstone-reports:
	find capstone/reports -type f | sort | tail -n 20
```

Run:

```bash
make capstone-validate
make capstone
make capstone-reports
```

---

# 12. Full Final Validation

Run:

```bash
cd ~/devops-masterclass/08-cicd-pipelines

make validate-notes || true
make validate-gha || true
make validate-gha-production || true
make validate-jenkins || true
make validate-jenkins-production || true
make validate-gitlab || true
make validate-gitlab-production || true
make validate-deployment || true
make validate-observability || true
make capstone-validate
```

Then run the capstone:

```bash
BASE_VERSION=0.8.0 \
CHANNEL=dev \
RUN_QUALITY_GATES=true \
STRICT_GATES=false \
RUN_DOCKER_BUILD=true \
RUN_DEPLOYMENT_DRY_RUN=true \
make capstone
```

Check report:

```bash
ls -lt capstone/reports | head

LATEST_CAPSTONE="$(ls -t capstone/reports/module-8-capstone-*.json | head -n 1)"
cat "$LATEST_CAPSTONE" | jq .
```

Expected fields:

```json
{
  "module": "8",
  "module_name": "CI/CD Pipelines",
  "service_name": "demo-node-api",
  "base_version": "0.8.0",
  "channel": "dev",
  "deploy_tag": "...",
  "artifact": "demo-node-api:...",
  "target_environment": "staging",
  "rollback_version": "0.7.0-local-rollback",
  "quality_status": "passed",
  "build_status": "passed",
  "deployment_status": "dry_run_success"
}
```

---

# 13. Copy Final GitHub Workflow

Run:

```bash
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 08-cicd-pipelines/capstone/github-actions/module-8-cicd-capstone.yml \
   .github/workflows/module-8-cicd-capstone.yml
```

---

# 14. Commit Module 8

Run:

```bash
cd ~/devops-masterclass

git status

git add .github/workflows/module-8-cicd-capstone.yml \
        08-cicd-pipelines

git commit -m "feat: complete CI/CD pipelines capstone"
```

---

# 15. Tag Module 8

Run:

```bash
git tag -a v0.8.0 -m "Complete Module 8 CI/CD pipelines"
```

Push:

```bash
git push
git push origin v0.8.0
```

---

# 16. Final Interview Answer for Module 8

Use this when explaining the module:

```text
I built a production-style CI/CD system across GitHub Actions, Jenkins, and GitLab CI. The system validates source code, runs tests and quality gates, builds Docker images, supports registry push workflows, generates SBOM/provenance/release metadata, handles secrets and OIDC patterns, supports staging and production deployment workflows, includes rollback automation, and archives structured observability reports for debugging and audit.
```

Stronger version:

```text
The key design principle was build once, promote many. Every deployable artifact uses an immutable version-SHA tag, and production deployment requires rollback metadata, environment approval, runtime verification, and archived deployment evidence. I also added pipeline observability with context reports, stage timing, failure classification, debug bundles, and notification payloads.
```

---

# 17. Module 8 Completion Checklist

```text
[ ] GitHub Actions fundamentals workflow created
[ ] GitHub Actions production pipeline created
[ ] Jenkins fundamentals pipelines created
[ ] Jenkins production pipeline created
[ ] GitLab CI fundamentals examples created
[ ] GitLab CI production pipeline created
[ ] secrets and OIDC patterns added
[ ] quality gates added
[ ] deployment pipeline added
[ ] rollback pipeline added
[ ] pipeline observability added
[ ] capstone local orchestrator added
[ ] capstone GitHub Actions workflow added
[ ] capstone Jenkinsfile added
[ ] capstone GitLab CI example added
[ ] module summary added
[ ] portfolio summary added
[ ] capstone validation passed
[ ] commit created
[ ] tag v0.8.0 created
```

---

# 18. What You Have Now

You now have a CI/CD module that covers:

```text
GitHub Actions
Jenkins
GitLab CI
quality gates
DevSecOps checks
secrets and OIDC
artifact metadata
deployment pipelines
rollback pipelines
pipeline observability
capstone automation
```

This is already a strong DevOps portfolio module.

---

# Module 8 Complete

```text
Module 8 — CI/CD Pipelines
Status: Complete
Tag: v0.8.0
```

---

# Next Module

# Module 9 — DevSecOps Security Gates

We will go much deeper into:

```text
SAST
DAST
SCA
secret scanning
container scanning
IaC scanning
Dockerfile scanning
Kubernetes manifest scanning
SBOM risk analysis
license policy
OPA / Conftest
Checkov
Trivy config scanning
Hadolint
Gitleaks
Semgrep
OWASP Dependency-Check
security exceptions
risk acceptance
security dashboards
DevSecOps capstone
```

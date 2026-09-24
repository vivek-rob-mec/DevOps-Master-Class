# Lesson 9.5 — Container Image Scanning

# Trivy Image Scanning, Docker Scout Overview, Image Vulnerability Policy, Base Image Updates, JSON/SARIF Reports, GitHub Actions, Jenkins, GitLab CI, and Production Image Scan Gates

In Lesson 9.4, we scanned application dependencies.

Now we scan the final runtime artifact:

```text
container image
```

This is important because the final image can contain risk from:

```text
base OS packages
Node.js runtime packages
npm production dependencies
system libraries
misconfigured image metadata
old base image layers
```

Trivy supports container image scanning with severity filtering, JSON output, and exit-code behavior for CI/CD enforcement, and it also supports SARIF reporting for integration with code scanning systems. ([Trivy][1])

---

# 1. Container Scanning Mental Model

SCA scans your dependency manifests:

```text
package.json
package-lock.json
```

Container scanning scans the built image:

```text
demo-node-api:0.9.0-dev-a1b2c3d
```

That image may include:

```text
Node.js runtime
Alpine/Debian/Ubuntu packages
OpenSSL
libc/musl
npm runtime packages
application files
Dockerfile decisions
```

Professional rule:

```text
Dependency scanning tells you what your app depends on.
Container scanning tells you what you are actually shipping.
```

---

# 2. Why Container Scanning Is Different from SCA

Example:

```text
npm audit:
  finds vulnerable npm packages

trivy image:
  finds vulnerable OS packages and language packages inside image
```

You need both.

```text
SCA:
  before image build

container scanning:
  after image build
```

Production rule:

```text
No production deployment should happen before the final image has been scanned.
```

---

# 3. Tools in This Lesson

We will use:

```text
Trivy:
  primary open-source image scanner

Docker Scout:
  overview and optional CI integration

GitHub Actions:
  image scan workflow

Jenkins:
  image scan pipeline

GitLab CI:
  image scan job
```

Docker Scout is integrated with Docker Desktop and Docker CLI and provides vulnerability insights, CVE summaries, and remediation guidance; Docker also documents GitHub Actions integration for Docker Scout. ([Docker Documentation][2])

---

# 4. Create Lesson Directory

```bash
cd ~/devops-masterclass/09-devsecops-security-gates

mkdir -p container-image-scanning/{trivy,docker-scout,scripts,reports,github-actions,jenkins,gitlab,runbooks,examples,notes,policies}
```

Check:

```bash
tree -L 2 container-image-scanning
```

---

# 5. Container Image Scan Policy

Create:

```bash
nano container-image-scanning/policies/container-image-scan-policy.json
```

Paste:

```json
{
  "service_name": "demo-node-api",
  "policy_version": "1.0",
  "tools": ["trivy image", "docker scout"],
  "environments": {
    "pull_request": {
      "critical": "warn",
      "high": "warn",
      "medium": "report",
      "low": "report"
    },
    "main": {
      "critical": "fail",
      "high": "warn",
      "medium": "report",
      "low": "report"
    },
    "production": {
      "critical": "fail",
      "high": "fail",
      "medium": "warn",
      "low": "report",
      "exception_required_for_unfixed_high_or_critical": true
    }
  },
  "required_reports": [
    "trivy_json",
    "trivy_sarif",
    "container_scan_summary"
  ],
  "forbidden": {
    "image_tags": ["latest", "prod", "production", "stable"],
    "unscanned_production_image": true
  },
  "exception_policy": {
    "allowed": true,
    "requires_owner": true,
    "requires_reason": true,
    "requires_expiry": true,
    "requires_fix_plan": true,
    "requires_compensating_control": true,
    "max_days": 30
  }
}
```

---

# 6. Container Scanning Notes

Create:

```bash
nano container-image-scanning/notes/container-image-scanning-mental-model.md
```

Paste:

```markdown
# Container Image Scanning Mental Model

## Goal

Scan the final runtime container image before deployment.

## Why It Matters

An image can contain vulnerabilities from:

- base OS packages
- language runtime
- npm production dependencies
- system libraries
- outdated packages
- image build decisions

## SCA vs Image Scan

SCA checks dependency manifests.

Container scanning checks the built artifact.

## Production Rule

Production images should be scanned after build and before deployment.

## Recommended Policy

Pull request:

- report or warn

Main:

- fail critical
- warn high

Production:

- fail high and critical unless approved exception exists

## Golden Rule

Do not deploy an unscanned image to production.
```

---

# 7. Build Local Image First

Use your Module 5 app image.

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api

docker build \
  -f Dockerfile.industry \
  --target runtime \
  --build-arg APP_VERSION=0.9.0-dev-local \
  --build-arg COMMIT_SHA="$(git rev-parse --short HEAD)" \
  -t demo-node-api:0.9.0-dev-local \
  .
```

Check:

```bash
docker image ls demo-node-api
```

---

# 8. Basic Trivy Image Scan

Run:

```bash
cd ~/devops-masterclass

trivy image demo-node-api:0.9.0-dev-local
```

JSON report:

```bash
trivy image \
  --format json \
  --output 09-devsecops-security-gates/container-image-scanning/reports/trivy-image-local.json \
  demo-node-api:0.9.0-dev-local
```

Fail on high/critical:

```bash
trivy image \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  demo-node-api:0.9.0-dev-local
```

SARIF report:

```bash
trivy image \
  --format sarif \
  --output 09-devsecops-security-gates/container-image-scanning/reports/trivy-image-local.sarif \
  demo-node-api:0.9.0-dev-local
```

Trivy’s image command supports severity filtering and JSON output, and its reporting docs list SARIF as a supported output format. ([Trivy][1])

---

# 9. Trivy Image Scan Gate Script

Create:

```bash
cd ~/devops-masterclass/09-devsecops-security-gates

nano container-image-scanning/scripts/trivy-image-gate.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF="${IMAGE_REF:-}"
MODULE_DIR="${MODULE_DIR:-$HOME/devops-masterclass/09-devsecops-security-gates}"
REPORT_DIR="${REPORT_DIR:-$MODULE_DIR/container-image-scanning/reports}"

ENVIRONMENT="${ENVIRONMENT:-pull_request}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
FAIL_ON_SCAN="${FAIL_ON_SCAN:-false}"

if [ -z "$IMAGE_REF" ]; then
  echo "ERROR: IMAGE_REF is required" >&2
  exit 1
fi

case "$IMAGE_REF" in
  *:latest|*:prod|*:production|*:stable)
    echo "ERROR: refusing mutable or unsafe image tag: $IMAGE_REF" >&2
    exit 1
    ;;
esac

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
SAFE_IMAGE="$(echo "$IMAGE_REF" | tr '/:@' '____')"

JSON_REPORT="$REPORT_DIR/trivy-image-$ENVIRONMENT-$SAFE_IMAGE-$TIMESTAMP.json"
SARIF_REPORT="$REPORT_DIR/trivy-image-$ENVIRONMENT-$SAFE_IMAGE-$TIMESTAMP.sarif"
SUMMARY_REPORT="$REPORT_DIR/trivy-image-summary-$ENVIRONMENT-$SAFE_IMAGE-$TIMESTAMP.json"

echo "===== Trivy Image Gate ====="
echo "Image: $IMAGE_REF"
echo "Environment: $ENVIRONMENT"
echo "Severity: $SEVERITY"
echo "Fail on scan: $FAIL_ON_SCAN"

if ! command -v trivy >/dev/null 2>&1; then
  echo "ERROR: trivy is required" >&2
  exit 1
fi

if [ "$FAIL_ON_SCAN" = "true" ]; then
  EXIT_CODE=1
else
  EXIT_CODE=0
fi

set +e
trivy image \
  --severity "$SEVERITY" \
  --exit-code "$EXIT_CODE" \
  --format json \
  --output "$JSON_REPORT" \
  "$IMAGE_REF"
TRIVY_EXIT_CODE=$?
set -e

trivy image \
  --severity "$SEVERITY" \
  --format sarif \
  --output "$SARIF_REPORT" \
  "$IMAGE_REF" >/dev/null || true

CRITICAL="$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length' "$JSON_REPORT")"
HIGH="$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length' "$JSON_REPORT")"
MEDIUM="$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "MEDIUM")] | length' "$JSON_REPORT")"
LOW="$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "LOW")] | length' "$JSON_REPORT")"
UNKNOWN="$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "UNKNOWN")] | length' "$JSON_REPORT")"
TOTAL="$(jq '[.Results[]?.Vulnerabilities[]?] | length' "$JSON_REPORT")"

DECISION="passed"

case "$ENVIRONMENT" in
  production)
    if [ "$HIGH" -gt 0 ] || [ "$CRITICAL" -gt 0 ]; then
      DECISION="failed"
    fi
    ;;
  main)
    if [ "$CRITICAL" -gt 0 ]; then
      DECISION="failed"
    fi
    ;;
  pull_request|dev)
    if [ "$CRITICAL" -gt 0 ] && [ "$FAIL_ON_SCAN" = "true" ]; then
      DECISION="failed"
    fi
    ;;
esac

if [ "$FAIL_ON_SCAN" = "true" ] && [ "$TRIVY_EXIT_CODE" -ne 0 ]; then
  DECISION="failed"
fi

cat > "$SUMMARY_REPORT" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "container_image_scan",
  "tool": "trivy image",
  "environment": "$ENVIRONMENT",
  "image_ref": "$IMAGE_REF",
  "severity_filter": "$SEVERITY",
  "trivy_exit_code": $TRIVY_EXIT_CODE,
  "vulnerabilities": {
    "total": $TOTAL,
    "critical": $CRITICAL,
    "high": $HIGH,
    "medium": $MEDIUM,
    "low": $LOW,
    "unknown": $UNKNOWN
  },
  "decision": "$DECISION",
  "json_report": "$JSON_REPORT",
  "sarif_report": "$SARIF_REPORT",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_REPORT" | jq .

echo
echo "JSON report: $JSON_REPORT"
echo "SARIF report: $SARIF_REPORT"
echo "Summary report: $SUMMARY_REPORT"

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: container image scan gate failed" >&2
  exit 1
fi

echo "Container image scan gate passed or reported only."
```

Make executable:

```bash
chmod +x container-image-scanning/scripts/trivy-image-gate.sh
```

Run report mode:

```bash
IMAGE_REF=demo-node-api:0.9.0-dev-local \
ENVIRONMENT=pull_request \
FAIL_ON_SCAN=false \
./container-image-scanning/scripts/trivy-image-gate.sh
```

Run stricter production simulation:

```bash
IMAGE_REF=demo-node-api:0.9.0-dev-local \
ENVIRONMENT=production \
FAIL_ON_SCAN=true \
SEVERITY=HIGH,CRITICAL \
./container-image-scanning/scripts/trivy-image-gate.sh
```

---

# 10. Container Scan Summary Script

Create:

```bash
nano container-image-scanning/scripts/container-scan-summary.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-container-image-scanning/reports}"

echo "===== Container Image Scan Summary ====="
echo "Report dir: $REPORT_DIR"

find "$REPORT_DIR" -type f -name '*summary*.json' | sort | tail -n 10 | while read -r file; do
  echo
  echo "## $file"
  jq . "$file"
done

echo
echo "Recent raw reports:"
find "$REPORT_DIR" -type f \( -name 'trivy-image-*.json' -o -name 'trivy-image-*.sarif' \) | sort | tail -n 10
```

Make executable:

```bash
chmod +x container-image-scanning/scripts/container-scan-summary.sh
```

Run:

```bash
./container-image-scanning/scripts/container-scan-summary.sh
```

---

# 11. Base Image Update Workflow

Most container vulnerabilities are fixed by updating the base image.

Create:

```bash
nano container-image-scanning/runbooks/base-image-update-runbook.md
```

Paste:

````markdown
# Base Image Update Runbook

## Goal

Reduce container vulnerabilities by updating the base image safely.

## Step 1 — Identify Base Image

```bash
grep -n '^FROM' 05-application-runtime/demo-node-api/Dockerfile.industry
````

## Step 2 — Check Current Image Findings

```bash
trivy image demo-node-api:TAG
```

## Step 3 — Update Base Image

Examples:

```Dockerfile
FROM node:22-alpine
```

or pin more tightly:

```Dockerfile
FROM node:22-alpine3.20
```

For very strict production:

```Dockerfile
FROM node@sha256:<digest>
```

## Step 4 — Rebuild

```bash
docker build \
  -f Dockerfile.industry \
  --target runtime \
  --build-arg APP_VERSION=0.9.0-dev-local \
  --build-arg COMMIT_SHA="$(git rev-parse --short HEAD)" \
  -t demo-node-api:0.9.0-dev-local \
  .
```

## Step 5 — Rescan

```bash
trivy image --severity HIGH,CRITICAL demo-node-api:0.9.0-dev-local
```

## Step 6 — Validate Runtime

```bash
docker run --rm -p 8080:3002 demo-node-api:0.9.0-dev-local
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/version
```

## Production Rule

Update base images intentionally.
Do not blindly change base image major versions before testing.

````

---

# 12. OS Package Vulnerability Triage

Create:

```bash
nano container-image-scanning/runbooks/os-package-vulnerability-triage.md
````

Paste:

```markdown
# OS Package Vulnerability Triage

## Goal

Triage vulnerabilities found in container OS packages.

## Collect

- CVE ID
- package name
- installed version
- fixed version
- severity
- base image
- exploitability
- runtime exposure

## Questions

- Is the vulnerable package used at runtime?
- Is a fixed package available?
- Is this inherited from the base image?
- Does updating the base image fix it?
- Is the affected functionality reachable?
- Is the container exposed to untrusted input?
- Is there a compensating control?

## Fix Options

1. Update base image.
2. Update OS package during build.
3. Remove unnecessary package.
4. Change to a smaller base image.
5. Use a distroless/minimal runtime image.
6. Add temporary exception with expiry.

## Do Not

- ignore high/critical production findings silently
- install random packages without pinning
- use `latest` as a fix
- accept permanent exceptions
```

---

# 13. Application Package Vulnerability Triage

Create:

```bash
nano container-image-scanning/runbooks/application-package-vulnerability-triage.md
```

Paste:

```markdown
# Application Package Vulnerability Triage

## Goal

Triage application dependency vulnerabilities found inside container images.

## Why Image Scan May Differ from npm Audit

Container image scan sees what is actually copied into the image.

It may include:

- production dependencies
- copied lockfiles
- bundled packages
- OS packages
- language packages

## Triage Questions

- Is the package a runtime dependency?
- Is it dev-only but accidentally copied into image?
- Is the vulnerable path reachable?
- Is a patched version available?
- Can package-lock be updated safely?
- Does npm audit also report it?

## Fix Options

- update package.json/package-lock.json
- run npm ci with production-only install where appropriate
- improve Dockerfile multi-stage build
- avoid copying node_modules from local machine
- remove dev dependencies from runtime image
```

---

# 14. Image Scan Exception Template

Create:

```bash
nano container-image-scanning/examples/container-scan-exception-template.json
```

Paste:

```json
{
  "exception_id": "IMG-EX-YYYY-NNN",
  "image_ref": "",
  "image_digest": "",
  "vulnerability_id": "",
  "package_name": "",
  "installed_version": "",
  "fixed_version": "",
  "severity": "",
  "affected_environment": "",
  "reason": "",
  "reachability_assessment": "",
  "fix_available": true,
  "fix_plan": "",
  "risk_owner": "",
  "approved_by": "",
  "created_at": "",
  "expires_on": "",
  "compensating_controls": [],
  "status": "requested"
}
```

Professional rule:

```text
Image scan exceptions must be attached to an image digest or immutable tag.
```

---

# 15. Docker Scout Overview

Docker Scout can analyze container images and provide CVE and remediation information. Docker documents GitHub Actions integration using Docker Scout workflows, and the `docker/scout-action` supports SARIF upload when GitHub code scanning is enabled. ([Docker Documentation][3])

Create overview notes:

```bash
nano container-image-scanning/docker-scout/docker-scout-overview.md
```

Paste:

```markdown
# Docker Scout Overview

## What It Does

Docker Scout analyzes container images and provides:

- vulnerability insights
- CVE summaries
- remediation guidance
- image comparison
- GitHub Actions integration

## When to Use

Use Docker Scout when your team uses:

- Docker Desktop
- Docker Hub
- Docker Scout-enabled workflows
- Docker organization policy features

## How It Fits With Trivy

Trivy is a strong open-source default scanner.

Docker Scout can be used as an additional image intelligence and remediation layer.

## Production Rule

Use at least one image scanner before production deployment.
More than one scanner can be useful for defense-in-depth.
```

Optional Docker Scout command:

```bash
docker scout cves demo-node-api:0.9.0-dev-local
```

Optional comparison:

```bash
docker scout compare demo-node-api:0.9.0-dev-local --to demo-node-api:previous
```

---

# 16. GitHub Actions Image Scanning Workflow

Create:

```bash
nano container-image-scanning/github-actions/container-image-scanning.yml
```

Paste:

```yaml
name: Container Image Scanning

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main
  workflow_dispatch:
    inputs:
      image_tag:
        description: "Image tag to build and scan"
        required: true
        default: "0.9.0-dev-manual"
        type: string

permissions:
  contents: read
  security-events: write

env:
  APP_DIR: 05-application-runtime/demo-node-api
  MODULE9_DIR: 09-devsecops-security-gates
  IMAGE_NAME: demo-node-api

jobs:
  trivy-image-scan:
    name: Build and scan image with Trivy
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Resolve image tag
        id: version
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            TAG="${{ inputs.image_tag }}"
          else
            TAG="0.9.0-${GITHUB_SHA::7}"
          fi

          case "$TAG" in
            latest|prod|production|stable)
              echo "Refusing unsafe tag: $TAG"
              exit 1
              ;;
          esac

          echo "tag=$TAG" >> "$GITHUB_OUTPUT"
          echo "image_ref=${IMAGE_NAME}:$TAG" >> "$GITHUB_OUTPUT"

      - name: Build image
        run: |
          docker build \
            -f "$APP_DIR/Dockerfile.industry" \
            --target runtime \
            --build-arg APP_VERSION="${{ steps.version.outputs.tag }}" \
            --build-arg COMMIT_SHA="${GITHUB_SHA::7}" \
            -t "${{ steps.version.outputs.image_ref }}" \
            "$APP_DIR"

      - name: Install Trivy
        run: |
          sudo apt-get update
          sudo apt-get install -y wget apt-transport-https gnupg lsb-release
          wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
            | gpg --dearmor \
            | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
          echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
            | sudo tee /etc/apt/sources.list.d/trivy.list
          sudo apt-get update
          sudo apt-get install -y trivy
          trivy --version

      - name: Run image scan gate
        run: |
          cd "$MODULE9_DIR"

          if [ "${{ github.event_name }}" = "pull_request" ]; then
            ENVIRONMENT="pull_request"
            FAIL_SCAN="false"
          else
            ENVIRONMENT="main"
            FAIL_SCAN="true"
          fi

          IMAGE_REF="${{ steps.version.outputs.image_ref }}" \
          ENVIRONMENT="$ENVIRONMENT" \
          FAIL_ON_SCAN="$FAIL_SCAN" \
          SEVERITY="HIGH,CRITICAL" \
          ./container-image-scanning/scripts/trivy-image-gate.sh

      - name: Upload container scan reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: container-image-scan-reports
          path: 09-devsecops-security-gates/container-image-scanning/reports/

      - name: Upload SARIF to GitHub code scanning
        if: always()
        uses: github/codeql-action/upload-sarif@v4
        with:
          sarif_file: 09-devsecops-security-gates/container-image-scanning/reports/
```

Copy:

```bash
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/container-image-scanning/github-actions/container-image-scanning.yml \
   .github/workflows/container-image-scanning.yml
```

GitHub documents uploading third-party SARIF files to code scanning using GitHub Actions, and the `upload-sarif` action can take a SARIF file or directory. ([GitHub Docs][4])

---

# 17. Jenkins Image Scanning Pipeline

Create:

```bash
nano container-image-scanning/jenkins/Jenkinsfile.container-image-scanning
```

Paste:

```groovy
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 45, unit: 'MINUTES')
  }

  parameters {
    string(name: 'IMAGE_TAG', defaultValue: '0.9.0-dev-jenkins', description: 'Immutable image tag')
    choice(name: 'ENVIRONMENT', choices: ['pull_request', 'main', 'production'], description: 'Gate environment')
    booleanParam(name: 'FAIL_ON_SCAN', defaultValue: false, description: 'Fail on image scan findings?')
  }

  environment {
    APP_DIR = '05-application-runtime/demo-node-api'
    MODULE9_DIR = '09-devsecops-security-gates'
    IMAGE_NAME = 'demo-node-api'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Validate Tag') {
      steps {
        sh '''
          case "${IMAGE_TAG}" in
            latest|prod|production|stable)
              echo "Refusing unsafe tag: ${IMAGE_TAG}"
              exit 1
              ;;
          esac
        '''
      }
    }

    stage('Build Image') {
      steps {
        sh '''
          docker build \
            -f "${APP_DIR}/Dockerfile.industry" \
            --target runtime \
            --build-arg APP_VERSION="${IMAGE_TAG}" \
            --build-arg COMMIT_SHA="$(git rev-parse --short HEAD)" \
            -t "${IMAGE_NAME}:${IMAGE_TAG}" \
            "${APP_DIR}"
        '''
      }
    }

    stage('Tool Check') {
      steps {
        sh '''
          if ! command -v trivy >/dev/null 2>&1; then
            echo "ERROR: trivy is required on Jenkins agent"
            exit 1
          fi

          trivy --version
        '''
      }
    }

    stage('Trivy Image Scan') {
      steps {
        dir("${MODULE9_DIR}") {
          sh '''
            IMAGE_REF="${IMAGE_NAME}:${IMAGE_TAG}" \
            ENVIRONMENT="${ENVIRONMENT}" \
            FAIL_ON_SCAN="${FAIL_ON_SCAN}" \
            SEVERITY="HIGH,CRITICAL" \
            ./container-image-scanning/scripts/trivy-image-gate.sh
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '09-devsecops-security-gates/container-image-scanning/reports/**/*', allowEmptyArchive: true
    }

    success {
      echo 'Container image scan passed.'
    }

    failure {
      echo 'Container image scan failed. Review archived reports.'
    }
  }
}
```

Jenkins job script path:

```text
09-devsecops-security-gates/container-image-scanning/jenkins/Jenkinsfile.container-image-scanning
```

---

# 18. GitLab CI Image Scanning Pipeline

Create:

```bash
nano container-image-scanning/gitlab/.gitlab-ci.container-image-scanning.yml
```

Paste:

```yaml
stages:
  - build
  - scan

variables:
  APP_DIR: "05-application-runtime/demo-node-api"
  MODULE9_DIR: "09-devsecops-security-gates"
  IMAGE_NAME: "demo-node-api"
  IMAGE_TAG: "0.9.0-dev-gitlab"
  DOCKER_TLS_CERTDIR: "/certs"

build_image:
  stage: build
  image: docker:27
  services:
    - name: docker:27-dind
      alias: docker
  script:
    - docker version
    - |
      case "$IMAGE_TAG" in
        latest|prod|production|stable)
          echo "Refusing unsafe tag: $IMAGE_TAG"
          exit 1
          ;;
      esac
    - |
      docker build \
        -f "$APP_DIR/Dockerfile.industry" \
        --target runtime \
        --build-arg APP_VERSION="$IMAGE_TAG" \
        --build-arg COMMIT_SHA="$CI_COMMIT_SHORT_SHA" \
        -t "$IMAGE_NAME:$IMAGE_TAG" \
        "$APP_DIR"
    - docker save "$IMAGE_NAME:$IMAGE_TAG" -o image.tar
  artifacts:
    when: always
    expire_in: 1 day
    paths:
      - image.tar

trivy_image_scan:
  stage: scan
  image:
    name: aquasec/trivy:latest
    entrypoint: [""]
  needs:
    - job: build_image
      artifacts: true
  variables:
    TRIVY_NO_PROGRESS: "true"
  script:
    - trivy image --input image.tar --severity HIGH,CRITICAL --format json --output "$MODULE9_DIR/container-image-scanning/reports/gitlab-trivy-image.json"
    - trivy image --input image.tar --severity HIGH,CRITICAL --format sarif --output "$MODULE9_DIR/container-image-scanning/reports/gitlab-trivy-image.sarif"
  artifacts:
    when: always
    expire_in: 30 days
    paths:
      - 09-devsecops-security-gates/container-image-scanning/reports/
```

For production, pin the scanner image version instead of using `aquasec/trivy:latest`.

GitLab’s container scanning documentation states that GitLab integrates with Trivy for container vulnerability static analysis. GitLab also provides container scanning features that can be used instead of or alongside custom Trivy jobs. ([GitLab Docs][5])

Optional GitLab built-in container scanning pattern:

```yaml
include:
  - template: Jobs/Container-Scanning.gitlab-ci.yml
```

Professional pattern:

```text
Use built-in GitLab container scanning where available.
Use custom Trivy jobs when you need portability or full control.
```

---

# 19. Trivy Ignore File Pattern

Sometimes you need to temporarily ignore a vulnerability.

Create:

```bash
nano container-image-scanning/trivy/.trivyignore.example
```

Paste:

```text
# Example only.
# Do not ignore vulnerabilities without approval and expiry.
# CVE-YYYY-NNNN
```

Professional rule:

```text
A .trivyignore entry should map to a documented exception with owner, reason, expiry, and fix plan.
```

---

# 20. Image Scan Runbook

Create:

```bash
nano container-image-scanning/runbooks/container-image-scan-runbook.md
```

Paste:

````markdown
# Container Image Scan Runbook

## Goal

Scan a built container image before deployment.

## Local Scan

```bash
trivy image demo-node-api:TAG
````

JSON:

```bash
trivy image --format json --output reports/image.json demo-node-api:TAG
```

Fail on high/critical:

```bash
trivy image --severity HIGH,CRITICAL --exit-code 1 demo-node-api:TAG
```

## Gate Script

```bash
IMAGE_REF=demo-node-api:TAG \
ENVIRONMENT=main \
FAIL_ON_SCAN=true \
./container-image-scanning/scripts/trivy-image-gate.sh
```

## Triage

Check:

* CVE ID
* package name
* installed version
* fixed version
* severity
* image layer/source
* runtime exposure
* fix availability

## Fix

Preferred:

1. update base image
2. update application dependency
3. remove unnecessary package
4. rebuild image
5. rescan image
6. redeploy only after pass

## Exception

Allowed only with:

* owner
* reason
* expiry
* fix plan
* compensating controls
* affected image tag/digest

````

---

# 21. Validation Script

Create:

```bash
nano container-image-scanning/scripts/validate-container-image-scanning-lesson.sh
````

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-container-image-scanning}"

echo "===== Validate Container Image Scanning Lesson ====="

test -f "$BASE_DIR/policies/container-image-scan-policy.json"
test -f "$BASE_DIR/notes/container-image-scanning-mental-model.md"
test -x "$BASE_DIR/scripts/trivy-image-gate.sh"
test -x "$BASE_DIR/scripts/container-scan-summary.sh"
test -f "$BASE_DIR/runbooks/base-image-update-runbook.md"
test -f "$BASE_DIR/runbooks/os-package-vulnerability-triage.md"
test -f "$BASE_DIR/runbooks/application-package-vulnerability-triage.md"
test -f "$BASE_DIR/runbooks/container-image-scan-runbook.md"
test -f "$BASE_DIR/examples/container-scan-exception-template.json"
test -f "$BASE_DIR/docker-scout/docker-scout-overview.md"
test -f "$BASE_DIR/github-actions/container-image-scanning.yml"
test -f "$BASE_DIR/jenkins/Jenkinsfile.container-image-scanning"
test -f "$BASE_DIR/gitlab/.gitlab-ci.container-image-scanning.yml"

echo "Container image scanning lesson validated."
```

Make executable:

```bash
chmod +x container-image-scanning/scripts/validate-container-image-scanning-lesson.sh
```

Run:

```bash
./container-image-scanning/scripts/validate-container-image-scanning-lesson.sh
```

---

# 22. Update Makefile

Open:

```bash
cd ~/devops-masterclass/09-devsecops-security-gates

nano Makefile
```

Add:

```Makefile
.PHONY: image-scan-validate image-build image-scan image-scan-prod image-scan-summary

image-scan-validate:
	./container-image-scanning/scripts/validate-container-image-scanning-lesson.sh

image-build:
	cd ../05-application-runtime/demo-node-api && \
	docker build \
		-f Dockerfile.industry \
		--target runtime \
		--build-arg APP_VERSION="$${IMAGE_TAG:-0.9.0-dev-local}" \
		--build-arg COMMIT_SHA="$$(git rev-parse --short HEAD)" \
		-t demo-node-api:"$${IMAGE_TAG:-0.9.0-dev-local}" \
		.

image-scan:
	IMAGE_REF="$${IMAGE_REF:-demo-node-api:0.9.0-dev-local}" \
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_SCAN="$${FAIL_ON_SCAN:-false}" \
	./container-image-scanning/scripts/trivy-image-gate.sh

image-scan-prod:
	IMAGE_REF="$${IMAGE_REF:-demo-node-api:0.9.0-dev-local}" \
	ENVIRONMENT=production \
	FAIL_ON_SCAN=true \
	SEVERITY=HIGH,CRITICAL \
	./container-image-scanning/scripts/trivy-image-gate.sh

image-scan-summary:
	./container-image-scanning/scripts/container-scan-summary.sh
```

Run:

```bash
make image-scan-validate
make image-build IMAGE_TAG=0.9.0-dev-local
make image-scan IMAGE_REF=demo-node-api:0.9.0-dev-local
make image-scan-summary
```

---

# 23. Practical Lab

Run:

```bash
cd ~/devops-masterclass/09-devsecops-security-gates

make image-scan-validate

make image-build IMAGE_TAG=0.9.0-dev-local

IMAGE_REF=demo-node-api:0.9.0-dev-local \
ENVIRONMENT=pull_request \
FAIL_ON_SCAN=false \
make image-scan

make image-scan-summary
```

Run production simulation:

```bash
IMAGE_REF=demo-node-api:0.9.0-dev-local \
make image-scan-prod
```

Copy GitHub workflow:

```bash
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/container-image-scanning/github-actions/container-image-scanning.yml \
   .github/workflows/container-image-scanning.yml
```

Commit:

```bash
git status

git add .github/workflows/container-image-scanning.yml \
        09-devsecops-security-gates

git commit -m "feat: add container image scanning gates"
git push
```

---

# 24. Common Container Scan Problems

## Too many vulnerabilities

Do not panic first.

Classify:

```text
base image issue
OS package issue
npm package issue
dev dependency copied into image
no fixed version
false positive
runtime reachable
not runtime reachable
```

## Scan fails but image runs fine

That is normal.

Security scanning and runtime health check answer different questions.

```text
health check:
  does it run?

image scan:
  is it safe enough to ship?
```

## Vulnerability has no fix

Options:

```text
document exception
change base image
remove package
add compensating control
monitor advisory
set expiry date
```

## Vulnerability is in dev dependency

Check whether dev dependencies are copied into runtime image.

Improve Dockerfile:

```text
multi-stage build
npm ci --omit=dev
copy only runtime files
avoid copying local node_modules
```

## SARIF upload fails

Still archive:

```text
JSON report
SARIF report
summary JSON
```

GitHub code scanning upload depends on repository settings and SARIF requirements. ([GitHub Docs][4])

---

# 25. Interview Explanation

## What is container image scanning?

```text
Container image scanning analyzes the final built image for vulnerabilities in OS packages, runtime libraries, language dependencies, and image contents before the artifact is deployed.
```

## Why scan images if you already run npm audit?

```text
npm audit checks Node dependency manifests. Image scanning checks the final runtime image, including base OS packages and the actual dependencies shipped inside the image. Both are required because production risk comes from the complete artifact.
```

## What is the best way to fix image vulnerabilities?

```text
Usually I first update the base image, rebuild, and rescan. If the vulnerability is from an application dependency, I update package.json and package-lock.json. If no fix exists, I create a time-bound exception with owner, reason, compensating controls, and a fix plan.
```

## Why avoid latest image tags?

```text
latest is mutable and makes scanning, deployment, rollback, and audit unreliable. A scan report should refer to an immutable tag or digest so we know exactly what artifact was evaluated.
```

## How do you enforce image scanning in CI/CD?

```text
I build the image, run Trivy against the image with a severity threshold, produce JSON and SARIF reports, fail the pipeline based on environment policy, archive the reports, and block production if high or critical findings are unresolved.
```

## What is Docker Scout?

```text
Docker Scout is Docker’s image analysis and vulnerability insight tool. It can provide CVE summaries, remediation guidance, image comparison, and GitHub Actions integration. I can use it alongside Trivy as a second layer of image intelligence.
```

---

# 26. Today’s Core Rules

```text
Scan the final container image before deployment.
SCA does not replace image scanning.
Image scanning does not replace SAST.
Do not deploy unscanned production images.
Do not use latest for production deployment.
Archive JSON and SARIF scan reports.
Fail high/critical findings in production unless exception exists.
Update base images intentionally.
Remove unnecessary runtime packages.
Do not copy dev dependencies into runtime images.
Attach exceptions to immutable image tags or digests.
```

---

# Next Lesson

# Lesson 9.6 — Dockerfile and Container Build Security

We will build:

```text
Hadolint Dockerfile scanning
custom Dockerfile policy checks
non-root user enforcement
no latest base images
no secrets in ARG/ENV
multi-stage build hardening
.dockerignore security
minimal runtime images
GitHub Actions Dockerfile scanning
Jenkins Dockerfile scanning
GitLab CI Dockerfile scanning
Dockerfile security runbook
production-ready Dockerfile gate
```

[1]: https://trivy.dev/docs/latest/references/configuration/cli/trivy_image/?utm_source=chatgpt.com "Image"
[2]: https://docs.docker.com/dhi/how-to/scan/?utm_source=chatgpt.com "Scan Docker Hardened Images"
[3]: https://docs.docker.com/scout/integrations/ci/gha/?utm_source=chatgpt.com "Integrate Docker Scout with GitHub Actions"
[4]: https://docs.github.com/en/code-security/how-tos/find-and-fix-code-vulnerabilities/integrate-with-existing-tools/upload-sarif-file?utm_source=chatgpt.com "Uploading a SARIF file to GitHub"
[5]: https://docs.gitlab.com/user/application_security/container_scanning/?utm_source=chatgpt.com "Container scanning"

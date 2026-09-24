# Lesson 9.12 — DevSecOps Capstone Project

# Full Module 9 Security Pipeline, Evidence Collection, Release Approval, Dashboard, Final Commit, and Tag `v0.9.0`

This capstone combines everything from Module 9 into one production-style DevSecOps security pipeline.

You already built individual gates for:

```text id="f2k0qh"
SAST
secret scanning
SCA dependency scanning
container image scanning
Dockerfile security
IaC security scanning
SBOM and license policy
OPA policy as code
DAST runtime security
security evidence collection
risk exception validation
release approval
```

Now we will connect them into one repeatable release workflow.

Semgrep supports local CLI code scanning, Gitleaks scans repositories/files for secrets, Trivy covers multiple targets such as container images and filesystems and can generate SBOMs, and ZAP Baseline provides a short passive Docker-based scan for running web apps. ([Semgrep][1])

---

## 1. Capstone Goal

By the end, you will have:

```text id="az70go"
one Module 9 capstone folder
one master DevSecOps pipeline script
one final security dashboard
one evidence bundle
one production-style release gate
GitHub Actions workflow
Jenkins pipeline
GitLab CI pipeline
runbook
portfolio summary
final Module 9 commit
Git tag v0.9.0
```

The production mental model:

```text id="k185nm"
code change
  ↓
security gates
  ↓
artifact/image/SBOM
  ↓
policy checks
  ↓
runtime checks
  ↓
evidence collection
  ↓
release decision
  ↓
approval
  ↓
deploy or block
```

---

## 2. Create Capstone Folder

```bash id="y1z9ms"
cd ~/devops-masterclass/09-devsecops-security-gates

mkdir -p capstone/{scripts,reports,github-actions,jenkins,gitlab,runbooks,docs,dashboard,evidence}
```

Check:

```bash id="99v5lb"
tree -L 2 capstone
```

---

## 3. Capstone Architecture Doc

Create:

```bash id="0di9ok"
nano capstone/docs/module-9-capstone-architecture.md
```

Paste:

```markdown id="m0axsl"
# Module 9 DevSecOps Capstone Architecture

## Goal

Create a production-style security pipeline for `demo-node-api`.

## Pipeline Stages

1. SAST with Semgrep
2. Secret scanning with Gitleaks and Trivy
3. SCA dependency scanning with npm audit and Trivy
4. Dockerfile/build security with Hadolint and custom policy
5. Container image scanning with Trivy
6. IaC scanning with Checkov and Trivy config
7. SBOM generation and license policy
8. OPA policy-as-code checks
9. DAST/runtime security checks
10. Security evidence collection
11. Release approval decision

## Release Evidence

The capstone produces:

- security report summaries
- raw scanner reports
- SBOM files
- dashboard JSON
- release decision JSON
- approval evidence
- final portfolio summary

## Production Rule

Production release is blocked if required evidence is missing, artifact tag is mutable, rollback version is missing, SBOM is missing, or high/critical risk lacks valid approval.
```

---

## 4. Capstone Policy

Create:

```bash id="8v4q99"
nano capstone/docs/module-9-capstone-policy.md
```

Paste:

```markdown id="6gq71s"
# Module 9 Capstone Security Policy

## Pull Request

Required:

- SAST
- secret scanning
- SCA
- Dockerfile security
- policy-as-code checks

Mode:

- report/warn for noisy scanners
- fail for secrets, unsafe Dockerfile patterns, and critical custom policies

## Main Branch

Required:

- SAST
- secret scanning
- SCA
- Dockerfile security
- IaC scanning
- SBOM/license
- OPA policy checks
- optional image scan if image is built

Mode:

- fail high-confidence critical issues
- archive all reports

## Production

Required:

- all security gates
- image scan
- DAST/runtime checks
- SBOM
- evidence bundle
- rollback version
- manual approval

Mode:

- fail missing evidence
- fail mutable tags
- fail missing rollback
- fail expired exceptions
- fail missing approval
```

---

## 5. Master Capstone Pipeline Script

Create:

```bash id="d4ooow"
nano capstone/scripts/module9-devsecops-capstone.sh
```

Paste:

```bash id="50p581"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
MODULE_DIR="${MODULE_DIR:-$ROOT_DIR/09-devsecops-security-gates}"
APP_DIR="${APP_DIR:-$ROOT_DIR/05-application-runtime/demo-node-api}"

ENVIRONMENT="${ENVIRONMENT:-pull_request}"
CAPSTONE_MODE="${CAPSTONE_MODE:-report}"

ARTIFACT_VERSION="${ARTIFACT_VERSION:-0.9.0-dev-local}"
ARTIFACT_IMAGE="${ARTIFACT_IMAGE:-demo-node-api:0.9.0-dev-local}"
ROLLBACK_VERSION="${ROLLBACK_VERSION:-0.8.0-dev-local}"
CHANGE_ID="${CHANGE_ID:-CHG-MODULE9-CAPSTONE}"
APPROVED_BY="${APPROVED_BY:-}"

TARGET_URL="${TARGET_URL:-http://127.0.0.1:3002}"
IAC_TARGET_DIR="${IAC_TARGET_DIR:-$MODULE_DIR/iac-security-scanning/examples/terraform-secure}"

RUN_SAST="${RUN_SAST:-true}"
RUN_SECRET="${RUN_SECRET:-true}"
RUN_SCA="${RUN_SCA:-true}"
RUN_DOCKERFILE="${RUN_DOCKERFILE:-true}"
RUN_IMAGE="${RUN_IMAGE:-false}"
RUN_IAC="${RUN_IAC:-true}"
RUN_SBOM="${RUN_SBOM:-true}"
RUN_OPA="${RUN_OPA:-true}"
RUN_DAST="${RUN_DAST:-false}"
RUN_EVIDENCE="${RUN_EVIDENCE:-true}"
RUN_RELEASE_DECISION="${RUN_RELEASE_DECISION:-true}"

REPORT_DIR="$MODULE_DIR/capstone/reports"
mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
CAPSTONE_REPORT="$REPORT_DIR/module9-capstone-run-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== Module 9 DevSecOps Capstone ====="
echo "Environment: $ENVIRONMENT"
echo "Mode: $CAPSTONE_MODE"
echo "Artifact version: $ARTIFACT_VERSION"
echo "Artifact image: $ARTIFACT_IMAGE"
echo "Rollback version: $ROLLBACK_VERSION"
echo "Target URL: $TARGET_URL"
echo

FAILED=0
GATES_JSON="[]"

record_gate() {
  local name="$1"
  local status="$2"
  local notes="$3"

  GATES_JSON="$(echo "$GATES_JSON" | jq \
    --arg name "$name" \
    --arg status "$status" \
    --arg notes "$notes" \
    '. + [{gate: $name, status: $status, notes: $notes}]')"
}

run_gate() {
  local name="$1"
  shift

  echo
  echo "===== Running gate: $name ====="

  set +e
  "$@"
  local exit_code=$?
  set -e

  if [ "$exit_code" -eq 0 ]; then
    record_gate "$name" "passed" "exit_code=0"
    echo "Gate passed: $name"
  else
    record_gate "$name" "failed" "exit_code=$exit_code"
    echo "Gate failed: $name"
    FAILED=1
  fi
}

cd "$MODULE_DIR"

# Fail behavior by mode
if [ "$CAPSTONE_MODE" = "strict" ]; then
  FAIL_SAST=true
  FAIL_SECRET=true
  FAIL_SCA=true
  FAIL_DOCKERFILE=true
  FAIL_IMAGE=true
  FAIL_IAC=true
  FAIL_SBOM=true
  FAIL_OPA=true
  FAIL_DAST=true
  FAIL_RELEASE=true
else
  FAIL_SAST=false
  FAIL_SECRET=false
  FAIL_SCA=false
  FAIL_DOCKERFILE=false
  FAIL_IMAGE=false
  FAIL_IAC=false
  FAIL_SBOM=false
  FAIL_OPA=false
  FAIL_DAST=false
  FAIL_RELEASE=false
fi

if [ "$RUN_SAST" = "true" ]; then
  run_gate "sast_semgrep" \
    env ENVIRONMENT="$ENVIRONMENT" FAIL_ON_FINDINGS="$FAIL_SAST" \
    ./sast-semgrep/scripts/semgrep-sast-gate.sh
else
  record_gate "sast_semgrep" "skipped" "RUN_SAST=false"
fi

if [ "$RUN_SECRET" = "true" ]; then
  run_gate "secret_scanning" \
    env ENVIRONMENT="$ENVIRONMENT" FAIL_ON_FINDINGS="$FAIL_SECRET" \
    RUN_TRIVY=false \
    ./secret-scanning/scripts/secret-scan-gate.sh
else
  record_gate "secret_scanning" "skipped" "RUN_SECRET=false"
fi

if [ "$RUN_SCA" = "true" ]; then
  run_gate "sca_dependency_scanning" \
    env ENVIRONMENT="$ENVIRONMENT" FAIL_ON_AUDIT="$FAIL_SCA" FAIL_ON_TRIVY=false \
    ./sca-dependency-scanning/scripts/sca-gate.sh
else
  record_gate "sca_dependency_scanning" "skipped" "RUN_SCA=false"
fi

if [ "$RUN_DOCKERFILE" = "true" ]; then
  run_gate "dockerfile_security" \
    env ENVIRONMENT="$ENVIRONMENT" FAIL_ON_HADOLINT="$FAIL_DOCKERFILE" FAIL_ON_POLICY=true \
    DOCKERFILE="$APP_DIR/Dockerfile.industry" BUILD_CONTEXT="$APP_DIR" \
    ./dockerfile-build-security/scripts/dockerfile-security-gate.sh
else
  record_gate "dockerfile_security" "skipped" "RUN_DOCKERFILE=false"
fi

if [ "$RUN_IMAGE" = "true" ]; then
  run_gate "container_image_scan" \
    env IMAGE_REF="$ARTIFACT_IMAGE" ENVIRONMENT="$ENVIRONMENT" FAIL_ON_SCAN="$FAIL_IMAGE" \
    ./container-image-scanning/scripts/trivy-image-gate.sh
else
  record_gate "container_image_scan" "skipped" "RUN_IMAGE=false"
fi

if [ "$RUN_IAC" = "true" ]; then
  run_gate "iac_security" \
    env TARGET_DIR="$IAC_TARGET_DIR" ENVIRONMENT="$ENVIRONMENT" \
    FAIL_ON_CHECKOV="$FAIL_IAC" FAIL_ON_TRIVY=false FAIL_ON_CUSTOM="$FAIL_IAC" \
    ./iac-security-scanning/scripts/iac-security-gate.sh
else
  record_gate "iac_security" "skipped" "RUN_IAC=false"
fi

if [ "$RUN_SBOM" = "true" ]; then
  run_gate "sbom_license_policy" \
    env ENVIRONMENT="$ENVIRONMENT" ARTIFACT_VERSION="$ARTIFACT_VERSION" \
    IMAGE_REF="" FAIL_ON_SBOM_SCAN="$FAIL_SBOM" FAIL_ON_LICENSE_REVIEW=false \
    ./sbom-license-policy/scripts/sbom-license-gate.sh
else
  record_gate "sbom_license_policy" "skipped" "RUN_SBOM=false"
fi

if [ "$RUN_OPA" = "true" ]; then
  run_gate "policy_as_code_opa" \
    env INPUT_PATH="$MODULE_DIR/policy-as-code-opa/examples-secure" \
    ENVIRONMENT="$ENVIRONMENT" FAIL_ON_POLICY="$FAIL_OPA" \
    ./policy-as-code-opa/scripts/policy-as-code-gate.sh
else
  record_gate "policy_as_code_opa" "skipped" "RUN_OPA=false"
fi

if [ "$RUN_DAST" = "true" ]; then
  run_gate "dast_runtime_security" \
    env TARGET_URL="$TARGET_URL" ENVIRONMENT="$ENVIRONMENT" RUN_ZAP=false \
    FAIL_ON_HEADERS=false FAIL_ON_METHODS=true FAIL_ON_HEALTH_LEAK=true \
    FAIL_ON_SENSITIVE_PATHS=true FAIL_ON_API_ERROR=false \
    ./dast-runtime-security/scripts/dast-runtime-gate.sh
else
  record_gate "dast_runtime_security" "skipped" "RUN_DAST=false"
fi

if [ "$RUN_EVIDENCE" = "true" ]; then
  run_gate "security_evidence_collection" \
    env ENVIRONMENT="$ENVIRONMENT" ARTIFACT_VERSION="$ARTIFACT_VERSION" \
    ARTIFACT_IMAGE="$ARTIFACT_IMAGE" ROLLBACK_VERSION="$ROLLBACK_VERSION" \
    ./security-evidence-release-approval/scripts/collect-security-evidence.sh

  run_gate "security_dashboard" \
    ./security-evidence-release-approval/scripts/create-security-dashboard.py
else
  record_gate "security_evidence_collection" "skipped" "RUN_EVIDENCE=false"
  record_gate "security_dashboard" "skipped" "RUN_EVIDENCE=false"
fi

if [ "$RUN_RELEASE_DECISION" = "true" ]; then
  run_gate "release_decision" \
    env ENVIRONMENT="$ENVIRONMENT" FAIL_ON_BLOCK="$FAIL_RELEASE" \
    ./security-evidence-release-approval/scripts/production-release-decision.py
else
  record_gate "release_decision" "skipped" "RUN_RELEASE_DECISION=false"
fi

DECISION="passed"
if [ "$FAILED" -ne 0 ]; then
  if [ "$CAPSTONE_MODE" = "strict" ]; then
    DECISION="failed"
  else
    DECISION="warning"
  fi
fi

cat > "$CAPSTONE_REPORT" <<EOF
{
  "service_name": "demo-node-api",
  "module": "module_9_devsecops_capstone",
  "environment": "$ENVIRONMENT",
  "mode": "$CAPSTONE_MODE",
  "artifact_version": "$ARTIFACT_VERSION",
  "artifact_image": "$ARTIFACT_IMAGE",
  "rollback_version": "$ROLLBACK_VERSION",
  "target_url": "$TARGET_URL",
  "gates": $GATES_JSON,
  "decision": "$DECISION",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$CAPSTONE_REPORT" | jq .

echo
echo "Capstone report: $CAPSTONE_REPORT"

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: Module 9 capstone failed" >&2
  exit 1
fi

echo "Module 9 capstone completed with decision: $DECISION"
```

Make executable:

```bash id="efhyru"
chmod +x capstone/scripts/module9-devsecops-capstone.sh
```

---

## 6. Capstone Dashboard Generator

Create:

```bash id="l8sknd"
nano capstone/scripts/module9-capstone-dashboard.py
```

Paste:

```python id="5g6j78"
#!/usr/bin/env python3

import json
from pathlib import Path
from datetime import datetime, timezone
import os

module_dir = Path(os.environ.get("MODULE_DIR", Path.home() / "devops-masterclass/09-devsecops-security-gates"))
capstone_dir = module_dir / "capstone"
dashboard_dir = capstone_dir / "dashboard"
dashboard_dir.mkdir(parents=True, exist_ok=True)

report_dirs = {
    "sast": module_dir / "sast-semgrep/reports",
    "secret_scan": module_dir / "secret-scanning/reports",
    "sca": module_dir / "sca-dependency-scanning/reports",
    "container_image_scan": module_dir / "container-image-scanning/reports",
    "dockerfile_security": module_dir / "dockerfile-build-security/reports",
    "iac_security": module_dir / "iac-security-scanning/reports",
    "sbom_license": module_dir / "sbom-license-policy/reports",
    "policy_as_code": module_dir / "policy-as-code-opa/reports",
    "dast_runtime": module_dir / "dast-runtime-security/reports",
    "release_approval": module_dir / "security-evidence-release-approval/reports",
    "capstone": module_dir / "capstone/reports"
}

def load_latest_json(path: Path, patterns):
    if not path.exists():
        return None

    files = []
    for pattern in patterns:
        files.extend(path.glob(pattern))

    files = sorted(set(files))

    if not files:
        return None

    latest = files[-1]

    try:
        data = json.loads(latest.read_text(encoding="utf-8"))
    except Exception as exc:
        data = {"parse_error": str(exc)}

    return {
        "file": str(latest),
        "data": data
    }

gates = {}

for gate, path in report_dirs.items():
    latest = load_latest_json(path, ["*summary*.json", "*decision*.json", "module9-capstone-run-*.json"])
    if latest:
        data = latest["data"]
        decision = data.get("decision", "unknown")
        gates[gate] = {
            "status": "present",
            "decision": decision,
            "file": latest["file"]
        }
    else:
        gates[gate] = {
            "status": "missing",
            "decision": "unknown",
            "file": ""
        }

present = sum(1 for item in gates.values() if item["status"] == "present")
missing = sum(1 for item in gates.values() if item["status"] == "missing")
failed = sum(1 for item in gates.values() if item["decision"] in ["failed", "blocked"])

overall = "passed"
if failed:
    overall = "failed"
elif missing:
    overall = "warning"

dashboard = {
    "service_name": "demo-node-api",
    "module": "module_9_devsecops_capstone",
    "overall_decision": overall,
    "present_gates": present,
    "missing_gates": missing,
    "failed_or_blocked_gates": failed,
    "gates": gates,
    "created_at": datetime.now(timezone.utc).isoformat()
}

timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
dashboard_file = dashboard_dir / f"module9-capstone-dashboard-{timestamp}.json"
latest_file = dashboard_dir / "module9-capstone-dashboard-latest.json"

dashboard_file.write_text(json.dumps(dashboard, indent=2), encoding="utf-8")
latest_file.write_text(json.dumps(dashboard, indent=2), encoding="utf-8")

print(json.dumps(dashboard, indent=2))
print(f"Dashboard: {dashboard_file}")
print(f"Latest: {latest_file}")
```

Make executable:

```bash id="rb1n2b"
chmod +x capstone/scripts/module9-capstone-dashboard.py
```

---

## 7. Capstone Validation Script

Create:

```bash id="4z4uwe"
nano capstone/scripts/validate-module9-capstone.sh
```

Paste:

```bash id="977hdf"
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-capstone}"

echo "===== Validate Module 9 Capstone ====="

test -f "$BASE_DIR/docs/module-9-capstone-architecture.md"
test -f "$BASE_DIR/docs/module-9-capstone-policy.md"
test -x "$BASE_DIR/scripts/module9-devsecops-capstone.sh"
test -x "$BASE_DIR/scripts/module9-capstone-dashboard.py"
test -f "$BASE_DIR/github-actions/module9-devsecops-capstone.yml"
test -f "$BASE_DIR/jenkins/Jenkinsfile.module9-devsecops-capstone"
test -f "$BASE_DIR/gitlab/.gitlab-ci.module9-devsecops-capstone.yml"
test -f "$BASE_DIR/runbooks/module9-capstone-runbook.md"
test -f "$BASE_DIR/docs/module-9-portfolio-summary.md"

echo "Module 9 capstone files validated."
```

Make executable:

```bash id="77bq2a"
chmod +x capstone/scripts/validate-module9-capstone.sh
```

---

## 8. Capstone Runbook

Create:

```bash id="mp0odq"
nano capstone/runbooks/module9-capstone-runbook.md
```

Paste:

````markdown id="xixptl"
# Module 9 DevSecOps Capstone Runbook

## Goal

Run a full production-style DevSecOps pipeline for `demo-node-api`.

## Report Mode

Use report mode during learning and early adoption:

```bash
ENVIRONMENT=pull_request \
CAPSTONE_MODE=report \
./capstone/scripts/module9-devsecops-capstone.sh
````

## Strict Mode

Use strict mode when the team trusts the gates:

```bash
ENVIRONMENT=main \
CAPSTONE_MODE=strict \
./capstone/scripts/module9-devsecops-capstone.sh
```

## With Image Scan

Build image first:

```bash
cd ../05-application-runtime/demo-node-api

docker build \
  -f Dockerfile.industry \
  --target runtime \
  --build-arg APP_VERSION=0.9.0-dev-local \
  --build-arg COMMIT_SHA="$(git rev-parse --short HEAD)" \
  -t demo-node-api:0.9.0-dev-local \
  .
```

Run capstone:

```bash
cd ../../09-devsecops-security-gates

RUN_IMAGE=true \
ARTIFACT_IMAGE=demo-node-api:0.9.0-dev-local \
./capstone/scripts/module9-devsecops-capstone.sh
```

## With DAST

Start app first:

```bash
cd ../05-application-runtime/demo-node-api

PORT=3002 NODE_ENV=production npm start
```

Run capstone from another terminal:

```bash
cd ../../09-devsecops-security-gates

RUN_DAST=true \
TARGET_URL=http://127.0.0.1:3002 \
./capstone/scripts/module9-devsecops-capstone.sh
```

## Production Simulation

```bash
ENVIRONMENT=production \
CAPSTONE_MODE=report \
ARTIFACT_VERSION=0.9.0-prod-a1b2c3d \
ARTIFACT_IMAGE=demo-node-api:0.9.0-prod-a1b2c3d \
ROLLBACK_VERSION=0.8.0-prod-f9e8d7c \
RUN_IMAGE=false \
RUN_DAST=false \
./capstone/scripts/module9-devsecops-capstone.sh
```

## Troubleshooting

If the capstone warns or fails:

1. Read `capstone/reports`.
2. Generate dashboard.
3. Check each gate summary.
4. Run the failing gate individually.
5. Fix the finding or create a valid exception.
6. Rerun the capstone.

````

---

## 9. Portfolio Summary

Create:

```bash id="r92htc"
nano capstone/docs/module-9-portfolio-summary.md
````

Paste:

```markdown id="iuzfjm"
# Module 9 Portfolio Summary — DevSecOps Security Gates

Built a production-style DevSecOps security pipeline for a Node.js API using layered security gates across source code, dependencies, secrets, containers, infrastructure, runtime behavior, SBOMs, and release approval.

## Implemented Controls

- SAST with Semgrep
- secret scanning with Gitleaks and Trivy
- SCA dependency scanning with npm audit and Trivy
- container image scanning with Trivy
- Dockerfile security with Hadolint and custom policy checks
- IaC security scanning with Checkov and Trivy config
- SBOM generation and vulnerability scanning with Trivy
- license policy checks for npm dependencies
- OPA/Conftest policy-as-code gates
- DAST/runtime security checks with OWASP ZAP baseline and custom HTTP checks
- central security evidence collection
- risk exception validation
- production release approval decision
- final security dashboard

## Production Skills Demonstrated

- CI/CD security gate design
- scanner report automation
- fail/warn/report policy modeling
- exception governance
- SBOM and supply-chain visibility
- immutable artifact release thinking
- rollback-aware production approval
- audit-ready evidence collection

## Resume-Ready Takeaway

Designed and implemented an end-to-end DevSecOps security pipeline integrating SAST, secrets, SCA, container, IaC, SBOM/license, OPA policy-as-code, DAST, evidence collection, and release approval gates for production-style CI/CD.
```

---

## 10. GitHub Actions Capstone Workflow

Create:

```bash id="8aa1lm"
nano capstone/github-actions/module9-devsecops-capstone.yml
```

Paste:

```yaml id="n6mygv"
name: Module 9 DevSecOps Capstone

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main
  workflow_dispatch:
    inputs:
      capstone_mode:
        description: "report or strict"
        required: true
        default: "report"
        type: choice
        options:
          - report
          - strict

permissions:
  contents: read
  security-events: write

env:
  MODULE9_DIR: 09-devsecops-security-gates
  APP_DIR: 05-application-runtime/demo-node-api
  NODE_VERSION: "22"

jobs:
  module9-capstone:
    name: Full DevSecOps capstone
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm
          cache-dependency-path: ${{ env.APP_DIR }}/package-lock.json

      - name: Install app dependencies
        working-directory: ${{ env.APP_DIR }}
        run: npm ci

      - name: Install Python CLIs
        run: |
          python3 -m pip install --user pipx
          python3 -m pipx ensurepath
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"
          ~/.local/bin/pipx install semgrep
          ~/.local/bin/pipx install checkov

      - name: Install Gitleaks
        run: |
          curl -sSfL https://raw.githubusercontent.com/gitleaks/gitleaks/master/install.sh \
            | sh -s -- -b "$HOME/.local/bin"
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"

      - name: Install Trivy
        run: |
          sudo apt-get update
          sudo apt-get install -y wget apt-transport-https gnupg lsb-release jq
          wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
            | gpg --dearmor \
            | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
          echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
            | sudo tee /etc/apt/sources.list.d/trivy.list
          sudo apt-get update
          sudo apt-get install -y trivy

      - name: Install OPA and Conftest
        run: |
          mkdir -p "$HOME/.local/bin"

          curl -L -o "$HOME/.local/bin/opa" \
            https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static
          chmod +x "$HOME/.local/bin/opa"

          curl -L -o conftest.tar.gz \
            https://github.com/open-policy-agent/conftest/releases/latest/download/conftest_Linux_x86_64.tar.gz
          tar -xzf conftest.tar.gz
          mv conftest "$HOME/.local/bin/conftest"

          echo "$HOME/.local/bin" >> "$GITHUB_PATH"

      - name: Run Module 9 capstone
        run: |
          cd "$MODULE9_DIR"

          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            MODE="${{ inputs.capstone_mode }}"
          elif [ "${{ github.event_name }}" = "pull_request" ]; then
            MODE="report"
          else
            MODE="report"
          fi

          ENVIRONMENT="${{ github.event_name == 'pull_request' && 'pull_request' || 'main' }}" \
          CAPSTONE_MODE="$MODE" \
          RUN_IMAGE=false \
          RUN_DAST=false \
          ./capstone/scripts/module9-devsecops-capstone.sh

          ./capstone/scripts/module9-capstone-dashboard.py

      - name: Upload Module 9 capstone reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: module9-devsecops-capstone-reports
          path: |
            09-devsecops-security-gates/capstone/
            09-devsecops-security-gates/security-evidence-release-approval/evidence/
            09-devsecops-security-gates/security-evidence-release-approval/dashboard/
            09-devsecops-security-gates/security-evidence-release-approval/reports/
```

Copy to root workflows:

```bash id="kf845a"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/capstone/github-actions/module9-devsecops-capstone.yml \
   .github/workflows/module9-devsecops-capstone.yml
```

---

## 11. Jenkins Capstone Pipeline

Create:

```bash id="hl4iyl"
nano capstone/jenkins/Jenkinsfile.module9-devsecops-capstone
```

Paste:

```groovy id="7bm475"
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 90, unit: 'MINUTES')
  }

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['pull_request', 'main', 'production'], description: 'Gate environment')
    choice(name: 'CAPSTONE_MODE', choices: ['report', 'strict'], description: 'Gate mode')
    booleanParam(name: 'RUN_IMAGE', defaultValue: false, description: 'Run container image scan?')
    booleanParam(name: 'RUN_DAST', defaultValue: false, description: 'Run DAST runtime checks?')
    string(name: 'ARTIFACT_VERSION', defaultValue: '0.9.0-dev-jenkins', description: 'Artifact version')
    string(name: 'ARTIFACT_IMAGE', defaultValue: 'demo-node-api:0.9.0-dev-jenkins', description: 'Artifact image')
    string(name: 'ROLLBACK_VERSION', defaultValue: '0.8.0-dev-jenkins', description: 'Rollback version')
  }

  environment {
    MODULE9_DIR = '09-devsecops-security-gates'
    APP_DIR = '05-application-runtime/demo-node-api'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Install App Dependencies') {
      steps {
        dir("${APP_DIR}") {
          sh 'npm ci'
        }
      }
    }

    stage('Tool Check') {
      steps {
        sh '''
          export PATH="$HOME/.local/bin:$PATH"

          node --version
          npm --version

          command -v semgrep || true
          command -v gitleaks || true
          command -v trivy || true
          command -v checkov || true
          command -v opa || true
          command -v conftest || true
        '''
      }
    }

    stage('Run Module 9 Capstone') {
      steps {
        dir("${MODULE9_DIR}") {
          sh '''
            export PATH="$HOME/.local/bin:$PATH"

            ENVIRONMENT="${ENVIRONMENT}" \
            CAPSTONE_MODE="${CAPSTONE_MODE}" \
            ARTIFACT_VERSION="${ARTIFACT_VERSION}" \
            ARTIFACT_IMAGE="${ARTIFACT_IMAGE}" \
            ROLLBACK_VERSION="${ROLLBACK_VERSION}" \
            RUN_IMAGE="${RUN_IMAGE}" \
            RUN_DAST="${RUN_DAST}" \
            ./capstone/scripts/module9-devsecops-capstone.sh

            ./capstone/scripts/module9-capstone-dashboard.py
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '''
        09-devops-security-gates/capstone/**/*,
        09-devsecops-security-gates/capstone/**/*,
        09-devsecops-security-gates/security-evidence-release-approval/evidence/**/*,
        09-devsecops-security-gates/security-evidence-release-approval/dashboard/**/*,
        09-devsecops-security-gates/security-evidence-release-approval/reports/**/*
      ''', allowEmptyArchive: true
    }

    success {
      echo 'Module 9 DevSecOps capstone completed.'
    }

    failure {
      echo 'Module 9 DevSecOps capstone failed. Review archived reports.'
    }
  }
}
```

Jenkins path:

```text id="zkda6s"
09-devsecops-security-gates/capstone/jenkins/Jenkinsfile.module9-devsecops-capstone
```

---

## 12. GitLab CI Capstone Pipeline

Create:

```bash id="s83z2d"
nano capstone/gitlab/.gitlab-ci.module9-devsecops-capstone.yml
```

Paste:

```yaml id="2bx0mp"
stages:
  - module9_capstone

variables:
  MODULE9_DIR: "09-devsecops-security-gates"
  APP_DIR: "05-application-runtime/demo-node-api"
  ENVIRONMENT: "pull_request"
  CAPSTONE_MODE: "report"
  ARTIFACT_VERSION: "0.9.0-dev-gitlab"
  ARTIFACT_IMAGE: "demo-node-api:0.9.0-dev-gitlab"
  ROLLBACK_VERSION: "0.8.0-dev-gitlab"

module9_devsecops_capstone:
  stage: module9_capstone
  image: node:22-bookworm
  before_script:
    - apt-get update
    - apt-get install -y bash curl wget gnupg jq python3 python3-pip python3-venv git
    - cd "$APP_DIR"
    - npm ci
    - cd "$CI_PROJECT_DIR"

    - python3 -m venv /tmp/security-venv
    - . /tmp/security-venv/bin/activate
    - pip install --upgrade pip semgrep checkov

    - curl -sSfL https://raw.githubusercontent.com/gitleaks/gitleaks/master/install.sh | sh -s -- -b /usr/local/bin

    - wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor > /usr/share/keyrings/trivy.gpg
    - echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" > /etc/apt/sources.list.d/trivy.list
    - apt-get update
    - apt-get install -y trivy

    - curl -L -o /usr/local/bin/opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static
    - chmod +x /usr/local/bin/opa
    - curl -L -o conftest.tar.gz https://github.com/open-policy-agent/conftest/releases/latest/download/conftest_Linux_x86_64.tar.gz
    - tar -xzf conftest.tar.gz
    - mv conftest /usr/local/bin/conftest

  script:
    - . /tmp/security-venv/bin/activate
    - cd "$MODULE9_DIR"
    - |
      if [ "${CI_COMMIT_BRANCH:-}" = "main" ]; then
        ENVIRONMENT="main"
      else
        ENVIRONMENT="pull_request"
      fi

      ENVIRONMENT="$ENVIRONMENT" \
      CAPSTONE_MODE="$CAPSTONE_MODE" \
      ARTIFACT_VERSION="$ARTIFACT_VERSION" \
      ARTIFACT_IMAGE="$ARTIFACT_IMAGE" \
      ROLLBACK_VERSION="$ROLLBACK_VERSION" \
      RUN_IMAGE=false \
      RUN_DAST=false \
      ./capstone/scripts/module9-devsecops-capstone.sh

      ./capstone/scripts/module9-capstone-dashboard.py

  artifacts:
    when: always
    expire_in: 30 days
    paths:
      - 09-devsecops-security-gates/capstone/
      - 09-devsecops-security-gates/security-evidence-release-approval/evidence/
      - 09-devsecops-security-gates/security-evidence-release-approval/dashboard/
      - 09-devsecops-security-gates/security-evidence-release-approval/reports/
```

---

## 13. Update Module 9 Makefile

Open:

```bash id="jlq3ap"
cd ~/devops-masterclass/09-devsecops-security-gates

nano Makefile
```

Add:

```Makefile id="nhl7nt"
.PHONY: capstone-validate capstone-run capstone-run-strict capstone-dashboard capstone-full capstone-prod-sim capstone-summary

capstone-validate:
	./capstone/scripts/validate-module9-capstone.sh

capstone-run:
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	CAPSTONE_MODE="$${CAPSTONE_MODE:-report}" \
	RUN_IMAGE="$${RUN_IMAGE:-false}" \
	RUN_DAST="$${RUN_DAST:-false}" \
	./capstone/scripts/module9-devsecops-capstone.sh

capstone-run-strict:
	ENVIRONMENT="$${ENVIRONMENT:-main}" \
	CAPSTONE_MODE=strict \
	RUN_IMAGE="$${RUN_IMAGE:-false}" \
	RUN_DAST="$${RUN_DAST:-false}" \
	./capstone/scripts/module9-devsecops-capstone.sh

capstone-dashboard:
	./capstone/scripts/module9-capstone-dashboard.py

capstone-prod-sim:
	ENVIRONMENT=production \
	CAPSTONE_MODE=report \
	ARTIFACT_VERSION="$${ARTIFACT_VERSION:-0.9.0-prod-a1b2c3d}" \
	ARTIFACT_IMAGE="$${ARTIFACT_IMAGE:-demo-node-api:0.9.0-prod-a1b2c3d}" \
	ROLLBACK_VERSION="$${ROLLBACK_VERSION:-0.8.0-prod-f9e8d7c}" \
	RUN_IMAGE="$${RUN_IMAGE:-false}" \
	RUN_DAST="$${RUN_DAST:-false}" \
	./capstone/scripts/module9-devsecops-capstone.sh

capstone-full:
	$(MAKE) capstone-validate
	$(MAKE) capstone-run
	$(MAKE) capstone-dashboard

capstone-summary:
	cat capstone/dashboard/module9-capstone-dashboard-latest.json | jq .
```

---

## 14. Run the Capstone Locally

Start with validation:

```bash id="x0fyu9"
cd ~/devops-masterclass/09-devsecops-security-gates

make capstone-validate
```

Run in report mode:

```bash id="nug18t"
make capstone-run
make capstone-dashboard
make capstone-summary
```

Run production simulation:

```bash id="wdefaf"
make capstone-prod-sim
make capstone-dashboard
```

Run strict mode only after you are ready to fix every failure:

```bash id="9u0qg1"
make capstone-run-strict
```

If strict mode fails, that is normal. The point is to expose what still needs fixing.

---

## 15. Optional Full Run with Image Scan

Build the image:

```bash id="5uzgi7"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

docker build \
  -f Dockerfile.industry \
  --target runtime \
  --build-arg APP_VERSION=0.9.0-dev-local \
  --build-arg COMMIT_SHA="$(git rev-parse --short HEAD)" \
  -t demo-node-api:0.9.0-dev-local \
  .
```

Run capstone with image scan:

```bash id="75j08p"
cd ~/devops-masterclass/09-devsecops-security-gates

RUN_IMAGE=true \
ARTIFACT_IMAGE=demo-node-api:0.9.0-dev-local \
make capstone-run
```

---

## 16. Optional Full Run with DAST

Terminal 1:

```bash id="tf282m"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

PORT=3002 \
NODE_ENV=production \
APP_VERSION=0.9.0-dev-local \
npm start
```

Terminal 2:

```bash id="8fxe84"
cd ~/devops-masterclass/09-devsecops-security-gates

RUN_DAST=true \
TARGET_URL=http://127.0.0.1:3002 \
make capstone-run
```

---

## 17. Copy Workflow to Root

```bash id="c17ioz"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/capstone/github-actions/module9-devsecops-capstone.yml \
   .github/workflows/module9-devsecops-capstone.yml
```

---

## 18. Final Module 9 Validation

Run the main checks:

```bash id="d5rydy"
cd ~/devops-masterclass/09-devsecops-security-gates

make validate || true
make sast-validate
make secret-validate
make sca-validate
make image-scan-validate
make dockerfile-validate
make iac-validate
make sbom-validate
make opa-validate
make dast-validate
make evidence-validate
make capstone-validate
```

Then:

```bash id="gmi0eq"
make capstone-full
```

---

## 19. Final Commit and Tag

From repo root:

```bash id="6p1yvu"
cd ~/devops-masterclass

git status

git add .github/workflows/module9-devsecops-capstone.yml \
        09-devsecops-security-gates

git commit -m "feat: complete DevSecOps security gates capstone"

git tag -a v0.9.0 -m "Complete Module 9 DevSecOps Security Gates"

git push

git push origin v0.9.0
```

Verify:

```bash id="b5d2fq"
git log --oneline --decorate -5
git tag --list "v0.*"
```

---

## 20. Common Capstone Problems

### `semgrep`, `checkov`, `trivy`, `gitleaks`, `opa`, or `conftest` not found

Install tools from previous lessons, then rerun:

```bash id="zf4e0u"
semgrep --version
checkov --version
trivy --version
gitleaks version
opa version
conftest --version
```

### Capstone fails in strict mode

Use report mode first:

```bash id="xxpw1c"
CAPSTONE_MODE=report make capstone-run
```

Then fix one gate at a time.

### Image scan skipped

This is controlled by:

```bash id="qhyfca"
RUN_IMAGE=false
```

Enable only after building the image:

```bash id="hjdoxe"
RUN_IMAGE=true ARTIFACT_IMAGE=demo-node-api:0.9.0-dev-local make capstone-run
```

### DAST skipped

This is controlled by:

```bash id="75qp3z"
RUN_DAST=false
```

Enable only after the app is running:

```bash id="8z56fb"
RUN_DAST=true TARGET_URL=http://127.0.0.1:3002 make capstone-run
```

### Production decision blocked

Check:

```bash id="3vz6tn"
make release-summary
```

Common blockers:

```text id="0cxzf4"
missing evidence
missing SBOM
missing approval
missing rollback version
mutable artifact tag
expired exception
unapproved high/critical exception
```

---

## 21. Interview Explanation

```text id="jx82p2"
In Module 9, I built an end-to-end DevSecOps security pipeline that integrates SAST, secret scanning, dependency scanning, container image scanning, Dockerfile security, IaC scanning, SBOM and license policy, OPA policy-as-code, DAST runtime checks, evidence collection, risk exception validation, and release approval.

The pipeline supports report and strict modes, generates machine-readable JSON reports, archives evidence, validates release metadata, and blocks production-style releases when required evidence, rollback, SBOM, approval, or valid exceptions are missing.
```

Resume version:

```text id="ngglol"
Implemented a production-style DevSecOps pipeline integrating Semgrep, Gitleaks, Trivy, Checkov, Hadolint, OPA/Conftest, OWASP ZAP, SBOM/license checks, evidence collection, and release approval gates across GitHub Actions, Jenkins, and GitLab CI.
```

---

## 22. Module 9 Completion Checklist

```text id="x74tz2"
[ ] SAST gate completed
[ ] Secret scanning gate completed
[ ] SCA dependency scanning gate completed
[ ] Container image scanning gate completed
[ ] Dockerfile security gate completed
[ ] IaC security gate completed
[ ] SBOM/license gate completed
[ ] OPA policy-as-code gate completed
[ ] DAST/runtime gate completed
[ ] Security evidence gate completed
[ ] Module 9 capstone completed
[ ] GitHub Actions workflow copied
[ ] Final commit created
[ ] Tag v0.9.0 pushed
```

---

# Module 9 Complete

You have now completed:

```text id="ptbyxa"
Module 9 — DevSecOps Security Gates
```

Next module:

```text id="kwcnh7"
Module 10 — Kubernetes Production Operations
```

We will start with:

```text id="vxl17f"
Lesson 10.1 — Kubernetes Production Mental Model, Cluster Architecture, Workloads, Services, Ingress, Namespaces, RBAC, and Deployment Flow
```

[1]: https://docs.semgrep.dev/getting-started/cli?utm_source=chatgpt.com "Local scans with Semgrep"

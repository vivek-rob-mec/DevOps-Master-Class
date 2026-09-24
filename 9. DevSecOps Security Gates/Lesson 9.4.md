# Lesson 9.4 — SCA Dependency Scanning

# npm audit, Trivy Filesystem Scan, GitHub Dependency Review, Jenkins, GitLab CI, Vulnerability Policy, Exceptions, and Dependency Update Runbook

In Lesson 9.3, we added secret scanning.

Now we add the next major DevSecOps gate:

```text id="7k4dpq"
SCA = Software Composition Analysis
```

SCA checks your third-party packages and dependency lockfiles for known vulnerabilities and license/security risk.

For your Node.js app, this means scanning:

```text id="fy6jo9"
package.json
package-lock.json
node_modules metadata
transitive dependencies
container/application dependency evidence
```

`npm audit` checks configured project dependencies against the npm registry’s vulnerability data and returns a non-zero exit code when vulnerabilities violate the configured threshold. Trivy filesystem scanning also detects vulnerabilities from lockfiles such as `package-lock.json`, and GitHub Dependency Review can fail pull requests that introduce vulnerabilities at or above a selected severity. ([npm Docs][1])

---

# 1. SCA Mental Model

Your app is not only your code.

It also includes:

```text id="i79yhi"
Express
Mongoose
Jest
React
Next.js
Webpack
Babel
npm transitive packages
base image packages
runtime OS packages
```

A small app can include hundreds or thousands of transitive dependencies.

SCA asks:

```text id="e6fgim"
Are any dependencies known to be vulnerable?
Are vulnerable versions used directly or transitively?
Is there a safe upgrade?
Should the pipeline fail, warn, or report?
Is the vulnerability relevant to production runtime?
```

Professional rule:

```text id="eyc4vm"
Dependency risk is supply-chain risk.
```

---

# 2. SCA vs SAST vs Secret Scanning

```text id="nweifp"
SAST:
  scans your source code patterns

Secret scanning:
  scans for leaked credentials

SCA:
  scans third-party dependencies

Container scanning:
  scans the final image, including OS and language packages
```

Example:

```text id="3msie2"
Your code has eval():
  SAST finding

Your repo has AWS key:
  secret finding

Your package-lock has vulnerable library:
  SCA finding

Your image has vulnerable openssl:
  container finding
```

---

# 3. Dependency Gate Strategy

Use different strictness by environment.

```text id="dp4jbf"
pull_request:
  warn on medium/high
  fail on critical if policy says so

main:
  fail on high/critical

production:
  fail on high/critical
  require exception for unresolved risk
```

Good production policy:

```text id="fmmc39"
No production deployment with unreviewed high/critical dependency vulnerabilities.
```

But avoid blind panic.

A vulnerability may be:

```text id="hrrtni"
not reachable
dev-only
not loaded at runtime
fixed by patch upgrade
blocked by compensating control
false positive
```

Professional rule:

```text id="1lvbhj"
SCA findings require severity plus context.
```

---

# 4. Create Lesson Directory

Run:

```bash id="trte4f"
cd ~/devops-masterclass/09-devsecops-security-gates

mkdir -p sca-dependency-scanning/{npm,trivy,scripts,reports,github-actions,jenkins,gitlab,runbooks,examples,notes,policies}
```

Check:

```bash id="6f53yk"
tree -L 2 sca-dependency-scanning
```

---

# 5. Create SCA Notes

Create:

```bash id="9hj9zn"
nano sca-dependency-scanning/notes/sca-mental-model.md
```

Paste:

```markdown id="5kyu6t"
# SCA Dependency Scanning Mental Model

## Definition

SCA means Software Composition Analysis.

It scans third-party dependencies for known vulnerabilities, license risk, and supply-chain issues.

## What SCA Scans

- package.json
- package-lock.json
- npm dependencies
- transitive dependencies
- language dependency manifests
- lockfiles

## Why It Matters

Most modern applications depend heavily on open-source packages.
A vulnerability in a transitive dependency can still affect production.

## Gate Strategy

Pull request:

- report low/medium
- warn high
- fail critical if policy requires

Main:

- fail high/critical

Production:

- fail high/critical unless approved exception exists

## Golden Rule

Do not blindly ignore SCA findings.
Classify by severity, reachability, runtime exposure, fix availability, and environment.
```

---

# 6. SCA Policy

Create:

```bash id="xpjy7j"
nano sca-dependency-scanning/policies/sca-policy.json
```

Paste:

```json id="eblbip"
{
  "service_name": "demo-node-api",
  "policy_version": "1.0",
  "tools": ["npm audit", "trivy fs", "github dependency review", "gitlab dependency scanning"],
  "environments": {
    "pull_request": {
      "critical": "fail",
      "high": "warn",
      "moderate": "warn",
      "medium": "warn",
      "low": "report",
      "dev_dependency": "warn"
    },
    "main": {
      "critical": "fail",
      "high": "fail",
      "moderate": "warn",
      "medium": "warn",
      "low": "report",
      "dev_dependency": "warn"
    },
    "production": {
      "critical": "fail",
      "high": "fail",
      "moderate": "warn",
      "medium": "warn",
      "low": "report",
      "exception_required_for_unfixed_high_or_critical": true
    }
  },
  "exception_policy": {
    "allowed": true,
    "requires_owner": true,
    "requires_reason": true,
    "requires_expiry": true,
    "requires_fix_plan": true,
    "max_days": 30
  },
  "required_artifacts": [
    "npm_audit_json",
    "trivy_fs_json",
    "sca_summary_json"
  ]
}
```

---

# 7. npm audit Basics

Go to your app:

```bash id="s6wg6j"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Run:

```bash id="uud48n"
npm audit
```

JSON report:

```bash id="w6fg8l"
npm audit --json
```

Severity threshold:

```bash id="feljny"
npm audit --audit-level=high
```

`npm audit` submits dependency information to the registry, calculates vulnerabilities/remediations, and `npm audit fix` can apply compatible remediations to the package tree. The npm docs also state that audit checks direct, dev, bundled, and optional dependencies, but not peer dependencies. ([npm Docs][1])

---

# 8. npm Audit Gate Script

Create:

```bash id="i8jfsj"
cd ~/devops-masterclass/09-devsecops-security-gates

nano sca-dependency-scanning/scripts/npm-audit-gate.sh
```

Paste:

```bash id="39dy5a"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
APP_DIR="${APP_DIR:-$ROOT_DIR/05-application-runtime/demo-node-api}"
MODULE_DIR="${MODULE_DIR:-$ROOT_DIR/09-devsecops-security-gates}"
REPORT_DIR="${REPORT_DIR:-$MODULE_DIR/sca-dependency-scanning/reports}"

ENVIRONMENT="${ENVIRONMENT:-pull_request}"
AUDIT_LEVEL="${AUDIT_LEVEL:-high}"
FAIL_ON_AUDIT="${FAIL_ON_AUDIT:-false}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/npm-audit-$ENVIRONMENT-$TIMESTAMP.json"
SUMMARY_FILE="$REPORT_DIR/npm-audit-summary-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== npm Audit Gate ====="
echo "App dir: $APP_DIR"
echo "Environment: $ENVIRONMENT"
echo "Audit level: $AUDIT_LEVEL"
echo "Fail on audit: $FAIL_ON_AUDIT"

if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm is required" >&2
  exit 1
fi

cd "$APP_DIR"

set +e
npm audit --audit-level="$AUDIT_LEVEL" --json > "$REPORT_FILE"
NPM_AUDIT_EXIT=$?
set -e

TOTAL="$(jq '.metadata.vulnerabilities.total // 0' "$REPORT_FILE")"
LOW="$(jq '.metadata.vulnerabilities.low // 0' "$REPORT_FILE")"
MODERATE="$(jq '.metadata.vulnerabilities.moderate // 0' "$REPORT_FILE")"
HIGH="$(jq '.metadata.vulnerabilities.high // 0' "$REPORT_FILE")"
CRITICAL="$(jq '.metadata.vulnerabilities.critical // 0' "$REPORT_FILE")"

DECISION="passed"

case "$ENVIRONMENT" in
  production|main)
    if [ "$HIGH" -gt 0 ] || [ "$CRITICAL" -gt 0 ]; then
      DECISION="failed"
    fi
    ;;
  pull_request|dev)
    if [ "$CRITICAL" -gt 0 ] && [ "$FAIL_ON_AUDIT" = "true" ]; then
      DECISION="failed"
    fi
    ;;
esac

if [ "$FAIL_ON_AUDIT" = "true" ] && [ "$NPM_AUDIT_EXIT" -ne 0 ]; then
  DECISION="failed"
fi

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "sca",
  "tool": "npm audit",
  "environment": "$ENVIRONMENT",
  "audit_level": "$AUDIT_LEVEL",
  "npm_audit_exit_code": $NPM_AUDIT_EXIT,
  "vulnerabilities": {
    "total": $TOTAL,
    "low": $LOW,
    "moderate": $MODERATE,
    "high": $HIGH,
    "critical": $CRITICAL
  },
  "decision": "$DECISION",
  "report_file": "$REPORT_FILE",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .

echo
echo "npm audit report: $REPORT_FILE"
echo "npm audit summary: $SUMMARY_FILE"

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: npm audit gate failed" >&2
  exit 1
fi

echo "npm audit gate passed or reported only."
```

Make executable:

```bash id="7oxu2a"
chmod +x sca-dependency-scanning/scripts/npm-audit-gate.sh
```

Run report mode:

```bash id="b4npzu"
ENVIRONMENT=pull_request \
AUDIT_LEVEL=high \
FAIL_ON_AUDIT=false \
./sca-dependency-scanning/scripts/npm-audit-gate.sh
```

Run strict main mode:

```bash id="52swat"
ENVIRONMENT=main \
AUDIT_LEVEL=high \
FAIL_ON_AUDIT=true \
./sca-dependency-scanning/scripts/npm-audit-gate.sh
```

---

# 9. Trivy Filesystem Dependency Scan

Run from repo root:

```bash id="xenz20"
cd ~/devops-masterclass

trivy fs \
  --scanners vuln \
  --format json \
  --output 09-devsecops-security-gates/sca-dependency-scanning/reports/trivy-fs-vuln.json \
  .
```

Trivy filesystem scanning looks for vulnerabilities using lockfiles such as `package-lock.json`, and its filesystem target supports vulnerability scanning as a default scanner. ([Trivy][2])

---

# 10. Trivy SCA Gate Script

Create:

```bash id="scv5xx"
cd ~/devops-masterclass/09-devsecops-security-gates

nano sca-dependency-scanning/scripts/trivy-sca-gate.sh
```

Paste:

```bash id="jl2xj4"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
MODULE_DIR="${MODULE_DIR:-$ROOT_DIR/09-devsecops-security-gates}"
TARGET_DIR="${TARGET_DIR:-$ROOT_DIR/05-application-runtime/demo-node-api}"
REPORT_DIR="${REPORT_DIR:-$MODULE_DIR/sca-dependency-scanning/reports}"

ENVIRONMENT="${ENVIRONMENT:-pull_request}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
FAIL_ON_SCAN="${FAIL_ON_SCAN:-false}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/trivy-sca-$ENVIRONMENT-$TIMESTAMP.json"
SUMMARY_FILE="$REPORT_DIR/trivy-sca-summary-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== Trivy SCA Gate ====="
echo "Target dir: $TARGET_DIR"
echo "Environment: $ENVIRONMENT"
echo "Severity: $SEVERITY"
echo "Fail on scan: $FAIL_ON_SCAN"

if ! command -v trivy >/dev/null 2>&1; then
  echo "ERROR: trivy is required" >&2
  exit 1
fi

TRIVY_EXIT_CODE=0

if [ "$FAIL_ON_SCAN" = "true" ]; then
  EXIT_CODE=1
else
  EXIT_CODE=0
fi

set +e
trivy fs \
  --scanners vuln \
  --severity "$SEVERITY" \
  --exit-code "$EXIT_CODE" \
  --format json \
  --output "$REPORT_FILE" \
  "$TARGET_DIR"
TRIVY_EXIT_CODE=$?
set -e

CRITICAL="$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length' "$REPORT_FILE")"
HIGH="$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length' "$REPORT_FILE")"
MEDIUM="$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "MEDIUM")] | length' "$REPORT_FILE")"
LOW="$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "LOW")] | length' "$REPORT_FILE")"
UNKNOWN="$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "UNKNOWN")] | length' "$REPORT_FILE")"
TOTAL="$(jq '[.Results[]?.Vulnerabilities[]?] | length' "$REPORT_FILE")"

DECISION="passed"

case "$ENVIRONMENT" in
  production|main)
    if [ "$HIGH" -gt 0 ] || [ "$CRITICAL" -gt 0 ]; then
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

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "sca",
  "tool": "trivy fs",
  "environment": "$ENVIRONMENT",
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
  "report_file": "$REPORT_FILE",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .

echo
echo "Trivy SCA report: $REPORT_FILE"
echo "Trivy SCA summary: $SUMMARY_FILE"

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: Trivy SCA gate failed" >&2
  exit 1
fi

echo "Trivy SCA gate passed or reported only."
```

Make executable:

```bash id="xd6rma"
chmod +x sca-dependency-scanning/scripts/trivy-sca-gate.sh
```

Run:

```bash id="m2ge10"
ENVIRONMENT=pull_request \
FAIL_ON_SCAN=false \
./sca-dependency-scanning/scripts/trivy-sca-gate.sh
```

Strict:

```bash id="te0k1u"
ENVIRONMENT=main \
FAIL_ON_SCAN=true \
SEVERITY=HIGH,CRITICAL \
./sca-dependency-scanning/scripts/trivy-sca-gate.sh
```

---

# 11. Combined SCA Gate

Create:

```bash id="v9tpq0"
nano sca-dependency-scanning/scripts/sca-gate.sh
```

Paste:

```bash id="wm4w8j"
#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="${MODULE_DIR:-$HOME/devops-masterclass/09-devsecops-security-gates}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"

RUN_NPM_AUDIT="${RUN_NPM_AUDIT:-true}"
RUN_TRIVY="${RUN_TRIVY:-true}"

FAIL_ON_AUDIT="${FAIL_ON_AUDIT:-false}"
FAIL_ON_TRIVY="${FAIL_ON_TRIVY:-false}"

AUDIT_LEVEL="${AUDIT_LEVEL:-high}"
TRIVY_SEVERITY="${TRIVY_SEVERITY:-HIGH,CRITICAL}"

echo "===== Combined SCA Gate ====="
echo "Environment: $ENVIRONMENT"

FAILED=0

cd "$MODULE_DIR"

if [ "$RUN_NPM_AUDIT" = "true" ]; then
  echo
  echo "===== npm audit ====="
  ENVIRONMENT="$ENVIRONMENT" \
  AUDIT_LEVEL="$AUDIT_LEVEL" \
  FAIL_ON_AUDIT="$FAIL_ON_AUDIT" \
  ./sca-dependency-scanning/scripts/npm-audit-gate.sh || FAILED=1
fi

if [ "$RUN_TRIVY" = "true" ]; then
  echo
  echo "===== Trivy fs dependency scan ====="
  ENVIRONMENT="$ENVIRONMENT" \
  SEVERITY="$TRIVY_SEVERITY" \
  FAIL_ON_SCAN="$FAIL_ON_TRIVY" \
  ./sca-dependency-scanning/scripts/trivy-sca-gate.sh || FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
  echo "ERROR: SCA gate failed" >&2
  exit 1
fi

echo "SCA gate passed or reported only."
```

Make executable:

```bash id="txt14g"
chmod +x sca-dependency-scanning/scripts/sca-gate.sh
```

Run PR/report mode:

```bash id="5yfbey"
ENVIRONMENT=pull_request \
FAIL_ON_AUDIT=false \
FAIL_ON_TRIVY=false \
./sca-dependency-scanning/scripts/sca-gate.sh
```

Run main strict mode:

```bash id="ok0q7p"
ENVIRONMENT=main \
FAIL_ON_AUDIT=true \
FAIL_ON_TRIVY=true \
./sca-dependency-scanning/scripts/sca-gate.sh
```

---

# 12. SCA Summary Script

Create:

```bash id="vd0aow"
nano sca-dependency-scanning/scripts/sca-summary.sh
```

Paste:

```bash id="9eb8zy"
#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-sca-dependency-scanning/reports}"

echo "===== SCA Summary ====="
echo "Report dir: $REPORT_DIR"

find "$REPORT_DIR" -type f -name '*summary*.json' | sort | tail -n 10 | while read -r file; do
  echo
  echo "## $file"
  jq . "$file"
done

echo
echo "Recent raw reports:"
find "$REPORT_DIR" -type f \( -name 'npm-audit-*.json' -o -name 'trivy-sca-*.json' \) | sort | tail -n 10
```

Make executable:

```bash id="4238qx"
chmod +x sca-dependency-scanning/scripts/sca-summary.sh
```

Run:

```bash id="sm4zqh"
./sca-dependency-scanning/scripts/sca-summary.sh
```

---

# 13. Dependency Exception Template

Create:

```bash id="r4xir6"
nano sca-dependency-scanning/examples/dependency-exception-template.json
```

Paste:

```json id="6vuyxv"
{
  "exception_id": "DEP-EX-YYYY-NNN",
  "package_name": "",
  "installed_version": "",
  "vulnerability_id": "",
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

```text id="z04ngz"
Dependency exceptions must expire and must have a fix plan.
```

---

# 14. GitHub Actions SCA Workflow

Create:

```bash id="f0fxgg"
nano sca-dependency-scanning/github-actions/sca-dependency-scanning.yml
```

Paste:

```yaml id="z3x5fv"
name: SCA Dependency Scanning

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read
  pull-requests: read

env:
  MODULE9_DIR: 09-devsecops-security-gates
  APP_DIR: 05-application-runtime/demo-node-api
  NODE_VERSION: "22"

jobs:
  npm-and-trivy-sca:
    name: npm audit and Trivy SCA
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm
          cache-dependency-path: ${{ env.APP_DIR }}/package-lock.json

      - name: Install dependencies
        working-directory: ${{ env.APP_DIR }}
        run: npm ci

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

      - name: Run SCA gate
        run: |
          cd "$MODULE9_DIR"

          if [ "${{ github.event_name }}" = "pull_request" ]; then
            ENVIRONMENT="pull_request"
            FAIL_NPM="false"
            FAIL_TRIVY="false"
          else
            ENVIRONMENT="main"
            FAIL_NPM="true"
            FAIL_TRIVY="true"
          fi

          ENVIRONMENT="$ENVIRONMENT" \
          FAIL_ON_AUDIT="$FAIL_NPM" \
          FAIL_ON_TRIVY="$FAIL_TRIVY" \
          ./sca-dependency-scanning/scripts/sca-gate.sh

      - name: Upload SCA reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: sca-dependency-reports
          path: 09-devsecops-security-gates/sca-dependency-scanning/reports/

  dependency-review:
    name: GitHub Dependency Review
    runs-on: ubuntu-latest
    if: ${{ github.event_name == 'pull_request' }}

    steps:
      - uses: actions/checkout@v4

      - name: Dependency Review
        uses: actions/dependency-review-action@v4
        with:
          fail-on-severity: high
```

Copy:

```bash id="77f02c"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/sca-dependency-scanning/github-actions/sca-dependency-scanning.yml \
   .github/workflows/sca-dependency-scanning.yml
```

GitHub’s Dependency Review Action compares dependency changes in pull requests and can fail PRs that introduce vulnerabilities at the configured `fail-on-severity` threshold. ([GitHub][3])

---

# 15. Jenkins SCA Pipeline

Create:

```bash id="cyq63d"
nano sca-dependency-scanning/jenkins/Jenkinsfile.sca-dependency-scanning
```

Paste:

```groovy id="gb8813"
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
  }

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['pull_request', 'main', 'production'], description: 'Gate environment')
    booleanParam(name: 'FAIL_ON_AUDIT', defaultValue: false, description: 'Fail npm audit?')
    booleanParam(name: 'FAIL_ON_TRIVY', defaultValue: false, description: 'Fail Trivy SCA?')
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

    stage('Install Dependencies') {
      steps {
        dir("${APP_DIR}") {
          sh 'npm ci'
        }
      }
    }

    stage('Tool Check') {
      steps {
        sh '''
          npm --version
          if ! command -v trivy >/dev/null 2>&1; then
            echo "ERROR: trivy is required on Jenkins agent"
            exit 1
          fi
          trivy --version
        '''
      }
    }

    stage('SCA Gate') {
      steps {
        dir("${MODULE9_DIR}") {
          sh '''
            ENVIRONMENT="${ENVIRONMENT}" \
            FAIL_ON_AUDIT="${FAIL_ON_AUDIT}" \
            FAIL_ON_TRIVY="${FAIL_ON_TRIVY}" \
            ./sca-dependency-scanning/scripts/sca-gate.sh
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '09-devsecops-security-gates/sca-dependency-scanning/reports/**/*', allowEmptyArchive: true
    }

    success {
      echo 'SCA dependency gate passed.'
    }

    failure {
      echo 'SCA dependency gate failed. Review archived reports.'
    }
  }
}
```

Jenkins job script path:

```text id="b1m34j"
09-devsecops-security-gates/sca-dependency-scanning/jenkins/Jenkinsfile.sca-dependency-scanning
```

---

# 16. GitLab CI SCA Pipeline

Create:

```bash id="l5ar7m"
nano sca-dependency-scanning/gitlab/.gitlab-ci.sca-dependency-scanning.yml
```

Paste:

```yaml id="shyyk2"
stages:
  - sca

variables:
  MODULE9_DIR: "09-devsecops-security-gates"
  APP_DIR: "05-application-runtime/demo-node-api"

sca_custom:
  stage: sca
  image: node:22-alpine
  before_script:
    - apk add --no-cache bash jq curl wget grep
    - cd "$APP_DIR"
    - npm ci
    - cd "$CI_PROJECT_DIR"
  script:
    - cd "$MODULE9_DIR"
    - |
      if [ "${CI_COMMIT_BRANCH:-}" = "main" ]; then
        ENVIRONMENT="main"
        FAIL_NPM="true"
        FAIL_TRIVY="false"
      else
        ENVIRONMENT="pull_request"
        FAIL_NPM="false"
        FAIL_TRIVY="false"
      fi

      ENVIRONMENT="$ENVIRONMENT" \
      FAIL_ON_AUDIT="$FAIL_NPM" \
      RUN_TRIVY=false \
      ./sca-dependency-scanning/scripts/sca-gate.sh
  artifacts:
    when: always
    expire_in: 30 days
    paths:
      - 09-devsecops-security-gates/sca-dependency-scanning/reports/
```

GitLab also provides dependency scanning that detects dependencies and matches them against the GitLab Advisory Database, and GitLab’s docs describe continuous dependency scanning from SBOM components on the default branch’s latest successful pipeline. ([GitLab Docs][4])

Optional GitLab built-in template:

```yaml id="a155xp"
include:
  - template: Jobs/Dependency-Scanning.gitlab-ci.yml
```

Professional pattern:

```text id="0rlj7f"
Use GitLab built-in dependency scanning where available.
Use custom npm audit/Trivy jobs for portability and learning.
```

---

# 17. Dependency Update Runbook

Create:

```bash id="eyoviu"
nano sca-dependency-scanning/runbooks/dependency-update-runbook.md
```

Paste:

````markdown id="gcs8lu"
# Dependency Update Runbook

## Goal

Safely remediate vulnerable dependencies.

## Step 1 — Identify Finding

Collect:

- package name
- installed version
- vulnerable version range
- fixed version
- severity
- direct or transitive dependency
- dev or production dependency
- exploitability/reachability

## Step 2 — Check Fix

Run:

```bash
cd 05-application-runtime/demo-node-api
npm audit
````

Check suggested fix:

```bash
npm audit fix --dry-run
```

## Step 3 — Patch Safely

Preferred:

```bash
npm update <package>
```

or:

```bash
npm install <package>@<safe-version>
```

For transitive dependencies, consider:

```bash
npm overrides
```

## Step 4 — Validate

Run:

```bash
npm ci
npm test
npm audit --audit-level=high
```

Then run Module 9 SCA gate:

```bash
cd ../../09-devsecops-security-gates
ENVIRONMENT=main FAIL_ON_AUDIT=true FAIL_ON_TRIVY=true ./sca-dependency-scanning/scripts/sca-gate.sh
```

## Step 5 — Commit

Commit package files together:

```bash
git add package.json package-lock.json
git commit -m "fix: update vulnerable dependencies"
```

## Step 6 — Exception

If no safe fix exists:

* create exception
* assign owner
* document reason
* add expiry date
* add compensating controls
* plan upgrade

````

---

# 18. Package Lock Security Workflow

Create:

```bash id="ccogvz"
nano sca-dependency-scanning/runbooks/package-lock-security-workflow.md
````

Paste:

````markdown id="itkauv"
# package-lock Security Workflow

## Rules

- Commit `package-lock.json`.
- Use `npm ci` in CI.
- Do not manually edit lockfiles unless absolutely necessary.
- Review lockfile changes in pull requests.
- Run dependency review for PRs.
- Run npm audit and Trivy fs.
- Keep production and dev dependency risk separate.

## Why package-lock matters

`package-lock.json` records exact dependency versions.

Without it, CI and production builds may resolve different package versions.

## Safe Commands

Install exact lockfile dependencies:

```bash
npm ci
````

Update dependency intentionally:

```bash
npm install package@version
```

Audit:

```bash
npm audit
npm audit --audit-level=high
```

Dry-run fix:

```bash
npm audit fix --dry-run
```

## Do Not

* delete lockfile to fix audit randomly
* run `npm audit fix --force` blindly
* merge lockfile changes without tests
* ignore high/critical production vulnerabilities

````

---

# 19. SCA Triage Runbook

Create:

```bash id="2189b8"
nano sca-dependency-scanning/runbooks/sca-triage-runbook.md
````

Paste:

```markdown id="1lfqt6"
# SCA Triage Runbook

## Goal

Triage dependency vulnerability findings from npm audit, Trivy, GitHub Dependency Review, or GitLab Dependency Scanning.

## Step 1 — Identify

- package
- installed version
- fixed version
- vulnerability ID
- severity
- direct/transitive
- dev/runtime dependency
- affected environment

## Step 2 — Assess

Ask:

- Is this dependency used at runtime?
- Is the vulnerable function reachable?
- Is the package exposed to untrusted input?
- Is a patch available?
- Is this only a dev/test dependency?
- Is there a compensating control?

## Step 3 — Decide

| Severity | PR | Main | Production |
|---|---|---|---|
| Critical | fail | fail | fail |
| High | warn/fail | fail | fail |
| Medium | warn | warn | warn/fail if reachable |
| Low | report | report | report |

## Step 4 — Fix

Preferred:

- upgrade direct dependency
- upgrade transitive dependency through parent
- use npm overrides carefully
- replace abandoned package
- patch base image if container-level

## Step 5 — Exception

Exception requires:

- owner
- reason
- expiry
- fix plan
- compensating controls
- approval
```

---

# 20. Validation Script

Create:

```bash id="l6wvt5"
nano sca-dependency-scanning/scripts/validate-sca-lesson.sh
```

Paste:

```bash id="ic8fz2"
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-sca-dependency-scanning}"

echo "===== Validate SCA Dependency Scanning Lesson ====="

test -f "$BASE_DIR/notes/sca-mental-model.md"
test -f "$BASE_DIR/policies/sca-policy.json"
test -x "$BASE_DIR/scripts/npm-audit-gate.sh"
test -x "$BASE_DIR/scripts/trivy-sca-gate.sh"
test -x "$BASE_DIR/scripts/sca-gate.sh"
test -x "$BASE_DIR/scripts/sca-summary.sh"
test -f "$BASE_DIR/github-actions/sca-dependency-scanning.yml"
test -f "$BASE_DIR/jenkins/Jenkinsfile.sca-dependency-scanning"
test -f "$BASE_DIR/gitlab/.gitlab-ci.sca-dependency-scanning.yml"
test -f "$BASE_DIR/examples/dependency-exception-template.json"
test -f "$BASE_DIR/runbooks/dependency-update-runbook.md"
test -f "$BASE_DIR/runbooks/package-lock-security-workflow.md"
test -f "$BASE_DIR/runbooks/sca-triage-runbook.md"

echo "SCA dependency scanning lesson validated."
```

Make executable:

```bash id="gdwhhy"
chmod +x sca-dependency-scanning/scripts/validate-sca-lesson.sh
```

Run:

```bash id="ta7x42"
./sca-dependency-scanning/scripts/validate-sca-lesson.sh
```

---

# 21. Update Makefile

Open:

```bash id="lpcd43"
cd ~/devops-masterclass/09-devsecops-security-gates

nano Makefile
```

Add:

```Makefile id="9h28iu"
.PHONY: sca-validate sca-scan sca-summary npm-audit-gate trivy-sca-gate

sca-validate:
	./sca-dependency-scanning/scripts/validate-sca-lesson.sh

sca-scan:
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_AUDIT="$${FAIL_ON_AUDIT:-false}" \
	FAIL_ON_TRIVY="$${FAIL_ON_TRIVY:-false}" \
	./sca-dependency-scanning/scripts/sca-gate.sh

npm-audit-gate:
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_AUDIT="$${FAIL_ON_AUDIT:-false}" \
	./sca-dependency-scanning/scripts/npm-audit-gate.sh

trivy-sca-gate:
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_SCAN="$${FAIL_ON_SCAN:-false}" \
	./sca-dependency-scanning/scripts/trivy-sca-gate.sh

sca-summary:
	./sca-dependency-scanning/scripts/sca-summary.sh
```

Run:

```bash id="7lc8zg"
make sca-validate
make sca-scan
make sca-summary
```

---

# 22. Practical Lab

Run:

```bash id="11v3vg"
cd ~/devops-masterclass/09-devsecops-security-gates

make sca-validate

ENVIRONMENT=pull_request \
FAIL_ON_AUDIT=false \
FAIL_ON_TRIVY=false \
make sca-scan

make sca-summary
```

Run stricter main simulation:

```bash id="gxk8sb"
ENVIRONMENT=main \
FAIL_ON_AUDIT=true \
FAIL_ON_TRIVY=true \
make sca-scan
```

Copy GitHub workflow:

```bash id="y6t6sh"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/sca-dependency-scanning/github-actions/sca-dependency-scanning.yml \
   .github/workflows/sca-dependency-scanning.yml
```

Commit:

```bash id="60frxg"
git status

git add .github/workflows/sca-dependency-scanning.yml \
        09-devsecops-security-gates

git commit -m "feat: add SCA dependency scanning gates"
git push
```

---

# 23. Common SCA Problems

## `npm audit` fails but no production risk

Check whether it is:

```text id="wvcrvr"
dev dependency
test-only dependency
not reachable
false positive
already fixed in parent upgrade
```

Do not ignore it silently. Document the decision.

## `npm audit fix --force` wants breaking changes

Do not run blindly.

Use:

```bash id="sqaiid"
npm audit fix --dry-run
```

Then upgrade intentionally.

## Trivy finds more than npm audit

Expected.

Different tools use different databases and dependency detection methods.

## Lockfile drift

Fix with:

```bash id="rhe810"
rm -rf node_modules
npm ci
npm test
```

If `npm ci` fails, your `package.json` and `package-lock.json` are inconsistent.

## Transitive dependency vulnerable

Options:

```text id="yqsfhl"
upgrade direct parent package
use npm overrides carefully
replace package
wait for upstream patch with exception
```

---

# 24. Interview Explanation

## What is SCA?

```text id="az78r7"
SCA, or Software Composition Analysis, scans third-party dependencies and lockfiles for known vulnerabilities, license risk, and supply-chain issues. It helps identify risk from direct and transitive open-source packages.
```

## Why use both npm audit and Trivy?

```text id="32n99h"
npm audit is npm-native and checks the Node dependency tree against npm advisory data. Trivy provides broader filesystem scanning and can detect vulnerabilities from lockfiles across ecosystems, making it useful as a second layer and for standardized CI/CD reports.
```

## What is a transitive dependency?

```text id="09lfd5"
A transitive dependency is a package pulled in by another dependency. Even if I did not directly install it, it can still become part of the application dependency tree and may introduce vulnerabilities.
```

## Should all dependency vulnerabilities fail CI?

```text id="fjia35"
No. A mature policy considers severity, environment, whether the dependency is runtime or dev-only, reachability, exploitability, and fix availability. However, high and critical vulnerabilities should usually block production unless there is an approved time-bound exception.
```

## How do you safely fix vulnerable dependencies?

```text id="qrn7s6"
I review the vulnerable package, affected version, fixed version, and dependency path. Then I update the direct dependency or parent package, run tests, rerun SCA scans, review lockfile changes, and commit both package.json and package-lock.json together.
```

## What is GitHub Dependency Review?

```text id="n865a8"
GitHub Dependency Review analyzes dependency changes in pull requests and can fail the PR when new vulnerabilities are introduced at or above a configured severity threshold.
```

---

# 25. Today’s Core Rules

```text id="sxou9d"
SCA scans third-party dependency risk.
Use package-lock.json for reproducible dependency trees.
Use npm ci in CI.
Use npm audit for npm-native dependency scanning.
Use Trivy fs for broader filesystem dependency scanning.
Use Dependency Review on pull requests.
Fail high/critical vulnerabilities on main and production.
Do not run npm audit fix --force blindly.
Triage dev-only and transitive vulnerabilities carefully.
Exceptions must have owner, reason, expiry, and fix plan.
Commit package.json and package-lock.json together.
```

---

# Next Lesson

# Lesson 9.5 — Container Image Scanning

We will build:

```text id="p0esbu"
Trivy image scanning
Docker Scout overview
image vulnerability policy
base image update workflow
OS package vulnerability triage
application package vulnerability triage
image scan JSON/SARIF reports
GitHub Actions image scanning
Jenkins image scanning
GitLab CI image scanning
fail/warn policy
container scan runbook
production-ready image scan gate
```

[1]: https://docs.npmjs.com/cli/v8/commands/npm-audit/?utm_source=chatgpt.com "npm-audit"
[2]: https://trivy.dev/docs/latest/target/filesystem/?utm_source=chatgpt.com "Filesystem"
[3]: https://github.com/actions/dependency-review-action?utm_source=chatgpt.com "Dependency Review Action"
[4]: https://docs.gitlab.com/user/application_security/dependency_scanning/?utm_source=chatgpt.com "Dependency scanning"

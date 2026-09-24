# Lesson 9.2 — SAST with Semgrep

# Local Scanning, Custom Rules, Express.js Security Checks, JSON/SARIF Reports, GitHub Actions, Jenkins, GitLab CI, and SAST Triage

In Lesson 9.1, we built the DevSecOps security-gate foundation.

Now we add the first real security gate:

```text
SAST = Static Application Security Testing
```

SAST scans your source code before deployment and tries to catch insecure patterns early. Semgrep is a fast static-analysis tool that can run locally, in CI, or through its platform; for open-source standalone CI usage, Semgrep’s docs recommend `semgrep scan`, and it supports JSON and SARIF outputs for machine-readable reports. ([Semgrep][1])

---

# 1. SAST Mental Model

SAST asks:

```text
Does the source code contain risky patterns before it becomes a running artifact?
```

Examples:

```text
unsafe eval usage
command injection risk
XSS risk
SQL/NoSQL injection risk
hardcoded secrets pattern
unsafe Express response rendering
insecure crypto usage
dangerous child_process usage
disabled TLS verification
```

SAST is different from container scanning:

```text
SAST:
  scans source code

SCA:
  scans dependencies

Container scan:
  scans built image

DAST:
  tests running application
```

Professional rule:

```text
SAST should run before artifact build, because it catches risky code before packaging.
```

---

# 2. Why Semgrep?

Semgrep works well for DevSecOps learning because:

```text
it is CLI-friendly
it supports JavaScript/Node.js
it supports custom rules
it can output JSON and SARIF
it works in GitHub Actions, Jenkins, and GitLab CI
it can run in open-source standalone mode
```

Semgrep’s local CLI docs show `semgrep scan` for local or no-account usage, while `semgrep ci` is intended for organization/platform-backed CI scanning; the CLI also supports exported text, SARIF, and JSON output. ([Semgrep][2])

Important note:

```text
Do not use the old semgrep-action wrapper.
Use native Semgrep CLI or Semgrep’s current CI integration pattern.
```

The GitHub Marketplace page for `semgrep-action` marks that wrapper as deprecated and recommends native Semgrep support instead. ([GitHub][3])

---

# 3. Create Lesson Folder

Run:

```bash
cd ~/devops-masterclass/09-devsecops-security-gates

mkdir -p sast-semgrep/{rules,scripts,reports,github-actions,jenkins,gitlab,runbooks,examples,notes}
```

Check:

```bash
tree -L 2 sast-semgrep
```

Expected:

```text
sast-semgrep
├── examples
├── github-actions
├── gitlab
├── jenkins
├── notes
├── reports
├── rules
├── runbooks
└── scripts
```

---

# 4. Install Semgrep Locally

Recommended local install:

```bash
python3 -m pip install --user pipx
python3 -m pipx ensurepath
pipx install semgrep
semgrep --version
```

Alternative with `uv`:

```bash
uv tool install semgrep
semgrep --version
```

Semgrep’s CLI docs show `pipx install semgrep` and `uv tool install semgrep` as setup options. ([Semgrep][2])

Docker option:

```bash
cd ~/devops-masterclass

docker run --rm \
  -v "$PWD:/src" \
  semgrep/semgrep \
  semgrep scan --config auto /src
```

Semgrep’s standalone CI docs also describe direct use of the `semgrep/semgrep` Docker image or installing Semgrep inside the CI job. ([Semgrep][1])

---

# 5. First Local Scan

Run from repo root:

```bash
cd ~/devops-masterclass

semgrep scan --config auto \
  --json-output 09-devsecops-security-gates/sast-semgrep/reports/semgrep-auto.json \
  .
```

Also generate SARIF:

```bash
semgrep scan --config auto \
  --sarif-output 09-devsecops-security-gates/sast-semgrep/reports/semgrep-auto.sarif \
  .
```

For CI blocking mode:

```bash
semgrep scan --config auto --error .
```

`--error` makes `semgrep scan` exit with code 1 when findings exist, which is useful for CI gate enforcement; without `--error`, `semgrep scan` can report findings without failing. ([Semgrep][4])

---

# 6. Create SAST Notes

Create:

```bash
nano sast-semgrep/notes/sast-with-semgrep.md
```

Paste:

```markdown
# SAST with Semgrep

## Goal

Use Semgrep to scan source code for insecure patterns before build and deployment.

## What SAST Finds

- dangerous function calls
- injection-prone code
- unsafe Express patterns
- risky child process usage
- insecure crypto usage
- disabled TLS checks
- hardcoded dangerous configuration

## Semgrep Modes

- `semgrep scan`: local and standalone scanning
- `semgrep ci`: CI mode connected to Semgrep AppSec Platform

## Outputs

- JSON for automation
- SARIF for code scanning systems
- text for humans

## Production Rule

SAST should run on pull requests and main branch.
Production releases should not proceed with untriaged high or critical findings.
```

---

# 7. Basic Semgrep Rule Structure

A Semgrep rule is YAML.

Semgrep rule syntax requires fields such as `id`, `message`, `severity`, `languages`, and a pattern expression under the top-level `rules` key; Semgrep supports `pattern`, `patterns`, `pattern-either`, `pattern-regex`, `pattern-not`, `pattern-inside`, and other rule constructs. ([Semgrep][5])

Basic rule:

```yaml
rules:
  - id: javascript-dangerous-eval
    message: Avoid eval(); it can execute attacker-controlled input.
    severity: ERROR
    languages:
      - javascript
      - typescript
    pattern: eval(...)
```

Semgrep pattern syntax also supports the `...` ellipsis operator, which can match zero or more arguments, statements, parameters, or other syntactic elements depending on context. ([Semgrep][6])

---

# 8. Create Custom Rules for Node/Express

Create:

```bash
nano sast-semgrep/rules/node-express-security.yml
```

Paste:

```yaml
rules:
  - id: node-dangerous-eval
    message: Avoid eval(); it can execute attacker-controlled input.
    severity: ERROR
    languages:
      - javascript
      - typescript
    metadata:
      category: security
      technology:
        - node
      cwe:
        - "CWE-95"
      remediation: Replace eval with safe parsing or explicit logic.
    pattern: eval(...)

  - id: node-child-process-exec
    message: Avoid child_process.exec with dynamic input. Prefer execFile/spawn with fixed arguments.
    severity: ERROR
    languages:
      - javascript
      - typescript
    metadata:
      category: security
      technology:
        - node
      cwe:
        - "CWE-78"
      remediation: Use safe argument arrays and avoid shell interpolation.
    pattern-either:
      - pattern: |
          require("child_process").exec(...)
      - pattern: |
          child_process.exec(...)

  - id: express-response-send-user-input
    message: Review res.send() with request-derived input. This can create XSS risk if HTML is returned.
    severity: WARNING
    languages:
      - javascript
      - typescript
    metadata:
      category: security
      technology:
        - express
      cwe:
        - "CWE-79"
      remediation: Return JSON, sanitize output, or use safe templating/escaping.
    patterns:
      - pattern-either:
          - pattern: |
              $APP.$METHOD(..., ($REQ, $RES) => {
                ...
                $RES.send($REQ.$ANY)
                ...
              })
          - pattern: |
              $APP.$METHOD(..., function ($REQ, $RES) {
                ...
                $RES.send($REQ.$ANY)
                ...
              })

  - id: node-disable-tls-verification
    message: Do not disable TLS certificate verification with NODE_TLS_REJECT_UNAUTHORIZED=0.
    severity: ERROR
    languages:
      - javascript
      - typescript
    metadata:
      category: security
      technology:
        - node
      cwe:
        - "CWE-295"
      remediation: Fix certificate trust instead of disabling verification.
    pattern-either:
      - pattern: process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"
      - pattern: process.env["NODE_TLS_REJECT_UNAUTHORIZED"] = "0"

  - id: express-debug-error-leak
    message: Avoid returning raw error messages to clients in production.
    severity: WARNING
    languages:
      - javascript
      - typescript
    metadata:
      category: security
      technology:
        - express
      cwe:
        - "CWE-209"
      remediation: Log detailed errors internally and return generic client errors.
    pattern-either:
      - pattern: |
          $RES.status(500).json({ error: $ERR.message })
      - pattern: |
          $RES.status(500).send($ERR.message)
```

These are learning rules. In production, tune them after observing false positives.

---

# 9. Create Test Fixture with Bad Code

Create a deliberately vulnerable example outside your app, so it does not pollute production code.

```bash
nano sast-semgrep/examples/insecure-express-example.js
```

Paste:

```javascript
const express = require("express");
const child_process = require("child_process");

const app = express();

app.get("/search", (req, res) => {
  res.send(req.query.q);
});

app.get("/run", (req, res) => {
  child_process.exec("ls " + req.query.path, (err, stdout) => {
    res.send(stdout);
  });
});

app.get("/eval", (req, res) => {
  const result = eval(req.query.expression);
  res.json({ result });
});

process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

app.listen(3000);
```

Run custom rule scan:

```bash
semgrep scan \
  --config sast-semgrep/rules/node-express-security.yml \
  --json-output sast-semgrep/reports/custom-node-express-results.json \
  sast-semgrep/examples
```

View findings:

```bash
cat sast-semgrep/reports/custom-node-express-results.json | jq '.results[] | {check_id, path, start, extra: .extra.message}'
```

---

# 10. Semgrep SAST Gate Script

Create:

```bash
nano sast-semgrep/scripts/semgrep-sast-gate.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
MODULE_DIR="${MODULE_DIR:-$ROOT_DIR/09-devsecops-security-gates}"
TARGET_DIR="${TARGET_DIR:-$ROOT_DIR/05-application-runtime/demo-node-api}"
RULES_FILE="${RULES_FILE:-$MODULE_DIR/sast-semgrep/rules/node-express-security.yml}"
REPORT_DIR="${REPORT_DIR:-$MODULE_DIR/sast-semgrep/reports}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"
FAIL_ON_FINDINGS="${FAIL_ON_FINDINGS:-false}"
SEVERITY_FAIL_LEVEL="${SEVERITY_FAIL_LEVEL:-ERROR}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
JSON_REPORT="$REPORT_DIR/semgrep-sast-$ENVIRONMENT-$TIMESTAMP.json"
SARIF_REPORT="$REPORT_DIR/semgrep-sast-$ENVIRONMENT-$TIMESTAMP.sarif"
SUMMARY_REPORT="$REPORT_DIR/semgrep-sast-summary-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== Semgrep SAST Gate ====="
echo "Target: $TARGET_DIR"
echo "Rules: $RULES_FILE"
echo "Environment: $ENVIRONMENT"
echo "Fail on findings: $FAIL_ON_FINDINGS"

if ! command -v semgrep >/dev/null 2>&1; then
  echo "ERROR: semgrep is not installed" >&2
  exit 1
fi

cd "$ROOT_DIR"

set +e
semgrep scan \
  --config "$RULES_FILE" \
  --json-output "$JSON_REPORT" \
  "$TARGET_DIR"
SCAN_EXIT=$?
set -e

semgrep scan \
  --config "$RULES_FILE" \
  --sarif-output "$SARIF_REPORT" \
  "$TARGET_DIR" >/dev/null || true

TOTAL_FINDINGS="$(jq '.results | length' "$JSON_REPORT")"
ERROR_FINDINGS="$(jq '[.results[] | select(.extra.severity == "ERROR")] | length' "$JSON_REPORT")"
WARNING_FINDINGS="$(jq '[.results[] | select(.extra.severity == "WARNING")] | length' "$JSON_REPORT")"
INFO_FINDINGS="$(jq '[.results[] | select(.extra.severity == "INFO")] | length' "$JSON_REPORT")"

DECISION="passed"

if [ "$FAIL_ON_FINDINGS" = "true" ] && [ "$TOTAL_FINDINGS" -gt 0 ]; then
  DECISION="failed"
fi

if [ "$SEVERITY_FAIL_LEVEL" = "ERROR" ] && [ "$ERROR_FINDINGS" -gt 0 ]; then
  DECISION="failed"
fi

cat > "$SUMMARY_REPORT" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "sast",
  "tool": "semgrep",
  "environment": "$ENVIRONMENT",
  "target_dir": "$TARGET_DIR",
  "rules_file": "$RULES_FILE",
  "total_findings": $TOTAL_FINDINGS,
  "error_findings": $ERROR_FINDINGS,
  "warning_findings": $WARNING_FINDINGS,
  "info_findings": $INFO_FINDINGS,
  "json_report": "$JSON_REPORT",
  "sarif_report": "$SARIF_REPORT",
  "scan_exit_code": $SCAN_EXIT,
  "decision": "$DECISION",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_REPORT" | jq .

echo
echo "JSON report: $JSON_REPORT"
echo "SARIF report: $SARIF_REPORT"
echo "Summary: $SUMMARY_REPORT"

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: Semgrep SAST gate failed" >&2
  exit 1
fi

echo "Semgrep SAST gate passed."
```

Make executable:

```bash
chmod +x sast-semgrep/scripts/semgrep-sast-gate.sh
```

Run report mode:

```bash
ENVIRONMENT=pull_request \
FAIL_ON_FINDINGS=false \
./sast-semgrep/scripts/semgrep-sast-gate.sh
```

Run strict mode:

```bash
ENVIRONMENT=main \
FAIL_ON_FINDINGS=true \
./sast-semgrep/scripts/semgrep-sast-gate.sh
```

---

# 11. SAST Report Summary Script

Create:

```bash
nano sast-semgrep/scripts/semgrep-report-summary.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-sast-semgrep/reports}"

echo "===== Semgrep Report Summary ====="
echo "Report dir: $REPORT_DIR"

LATEST="$(find "$REPORT_DIR" -type f -name 'semgrep-sast-summary-*.json' | sort | tail -n 1 || true)"

if [ -z "$LATEST" ]; then
  echo "No summary report found."
  exit 0
fi

echo "Latest summary: $LATEST"
cat "$LATEST" | jq .

JSON_REPORT="$(jq -r '.json_report // empty' "$LATEST")"

if [ -n "$JSON_REPORT" ] && [ -f "$JSON_REPORT" ]; then
  echo
  echo "Findings:"
  jq -r '.results[]? | "- \(.extra.severity) \(.check_id) \(.path):\(.start.line) - \(.extra.message)"' "$JSON_REPORT"
fi
```

Make executable:

```bash
chmod +x sast-semgrep/scripts/semgrep-report-summary.sh
```

Run:

```bash
./sast-semgrep/scripts/semgrep-report-summary.sh
```

---

# 12. GitHub Actions SAST Workflow

Create:

```bash
nano sast-semgrep/github-actions/semgrep-sast.yml
```

Paste:

```yaml
name: Semgrep SAST

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
  security-events: write

env:
  MODULE9_DIR: 09-devsecops-security-gates
  APP_DIR: 05-application-runtime/demo-node-api

jobs:
  semgrep-sast:
    name: Semgrep SAST
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Install Semgrep
        run: |
          python3 -m pip install --user pipx
          python3 -m pipx ensurepath
          ~/.local/bin/pipx install semgrep
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"

      - name: Run Semgrep SAST gate
        run: |
          cd "$MODULE9_DIR"
          ENVIRONMENT="${{ github.event_name == 'pull_request' && 'pull_request' || 'main' }}" \
          TARGET_DIR="$GITHUB_WORKSPACE/$APP_DIR" \
          FAIL_ON_FINDINGS=false \
          ./sast-semgrep/scripts/semgrep-sast-gate.sh

      - name: Upload Semgrep reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: semgrep-sast-reports
          path: 09-devsecops-security-gates/sast-semgrep/reports/

      - name: Upload SARIF to code scanning
        if: always()
        uses: github/codeql-action/upload-sarif@v4
        with:
          sarif_file: 09-devsecops-security-gates/sast-semgrep/reports/
```

Copy:

```bash
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/sast-semgrep/github-actions/semgrep-sast.yml \
   .github/workflows/semgrep-sast.yml
```

Note:

```text
For a public learning repo, SARIF upload may require GitHub code scanning permissions/features.
If SARIF upload fails, the artifact upload still preserves the reports.
```

---

# 13. Jenkins SAST Pipeline

Create:

```bash
nano sast-semgrep/jenkins/Jenkinsfile.semgrep-sast
```

Paste:

```groovy
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
  }

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['pull_request', 'main', 'production'], description: 'Security gate environment')
    booleanParam(name: 'FAIL_ON_FINDINGS', defaultValue: false, description: 'Fail on any Semgrep finding?')
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

    stage('Install Semgrep') {
      steps {
        sh '''
          if ! command -v semgrep >/dev/null 2>&1; then
            python3 -m pip install --user pipx
            python3 -m pipx ensurepath || true
            ~/.local/bin/pipx install semgrep || true
          fi

          semgrep --version || ~/.local/bin/semgrep --version
        '''
      }
    }

    stage('SAST Scan') {
      steps {
        dir("${MODULE9_DIR}") {
          sh '''
            export PATH="$HOME/.local/bin:$PATH"

            ENVIRONMENT="${ENVIRONMENT}" \
            TARGET_DIR="$WORKSPACE/${APP_DIR}" \
            FAIL_ON_FINDINGS="${FAIL_ON_FINDINGS}" \
            ./sast-semgrep/scripts/semgrep-sast-gate.sh
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '09-devsecops-security-gates/sast-semgrep/reports/**/*', allowEmptyArchive: true
    }

    success {
      echo 'Semgrep SAST gate passed.'
    }

    failure {
      echo 'Semgrep SAST gate failed. Review archived Semgrep reports.'
    }
  }
}
```

Jenkins job script path:

```text
09-devsecops-security-gates/sast-semgrep/jenkins/Jenkinsfile.semgrep-sast
```

---

# 14. GitLab CI SAST Pipeline

Create:

```bash
nano sast-semgrep/gitlab/.gitlab-ci.semgrep-sast.yml
```

Paste:

```yaml
stages:
  - sast

variables:
  MODULE9_DIR: "09-devsecops-security-gates"
  APP_DIR: "05-application-runtime/demo-node-api"

semgrep_sast:
  stage: sast
  image: semgrep/semgrep
  script:
    - cd "$MODULE9_DIR"
    - |
      ENVIRONMENT="${CI_COMMIT_BRANCH:-pull_request}" \
      TARGET_DIR="$CI_PROJECT_DIR/$APP_DIR" \
      FAIL_ON_FINDINGS=false \
      ./sast-semgrep/scripts/semgrep-sast-gate.sh
  artifacts:
    when: always
    expire_in: 30 days
    paths:
      - 09-devsecops-security-gates/sast-semgrep/reports/
```

For stricter main branch behavior:

```yaml
rules:
  - if: '$CI_COMMIT_BRANCH == "main"'
    variables:
      FAIL_ON_FINDINGS: "true"
  - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    variables:
      FAIL_ON_FINDINGS: "false"
```

---

# 15. SAST Triage Runbook

Create:

```bash
nano sast-semgrep/runbooks/sast-triage-runbook.md
```

Paste:

```markdown
# SAST Triage Runbook

## Goal

Review and respond to Semgrep SAST findings.

## Step 1 — Identify Finding

Check:

- rule ID
- severity
- file path
- line number
- message
- code snippet
- commit
- branch

## Step 2 — Classify

Categories:

- true positive
- false positive
- acceptable risk
- duplicate
- needs more context

## Step 3 — Decide Action

| Severity | Pull Request | Main | Production |
|---|---|---|---|
| ERROR / HIGH | warn or fail | fail | fail |
| WARNING / MEDIUM | warn | warn/fail | fail if exploitable |
| INFO / LOW | report | report | warn/report |

## Step 4 — Fix

Common fixes:

- remove dangerous function
- validate input
- sanitize output
- use safe APIs
- avoid shell execution
- return generic errors
- use secure configuration

## Step 5 — Exception

Only allow exception when:

- owner is assigned
- reason is documented
- expiry date exists
- compensating control exists
- security approval exists

## Step 6 — Close

Close when:

- code is fixed
- finding no longer appears
- exception is approved and tracked
```

---

# 16. Semgrep Rule Writing Notes

Create:

```bash
nano sast-semgrep/notes/semgrep-rule-writing.md
```

Paste:

````markdown
# Semgrep Rule Writing Notes

## Rule Shape

```yaml
rules:
  - id: unique-rule-id
    message: explain finding and remediation
    severity: ERROR
    languages:
      - javascript
    pattern: dangerous(...)
````

## Useful Constructs

* `pattern`: match one code pattern
* `patterns`: logical AND
* `pattern-either`: logical OR
* `pattern-not`: exclude pattern
* `pattern-inside`: match inside another structure
* `metavariable-regex`: filter metavariable text

## Ellipsis

`...` means "match flexible code here".

Example:

```yaml
pattern: eval(...)
```

matches:

```javascript
eval(userInput)
eval("1 + 1")
```

## Production Rule

Custom rules must include:

* clear message
* severity
* remediation metadata
* tests or examples
* false-positive review

````

---

# 17. SAST Validation Script

Create:

```bash
nano sast-semgrep/scripts/validate-sast-semgrep-lesson.sh
````

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-sast-semgrep}"

echo "===== Validate Semgrep SAST Lesson ====="

test -f "$BASE_DIR/rules/node-express-security.yml"
test -x "$BASE_DIR/scripts/semgrep-sast-gate.sh"
test -x "$BASE_DIR/scripts/semgrep-report-summary.sh"
test -f "$BASE_DIR/examples/insecure-express-example.js"
test -f "$BASE_DIR/github-actions/semgrep-sast.yml"
test -f "$BASE_DIR/jenkins/Jenkinsfile.semgrep-sast"
test -f "$BASE_DIR/gitlab/.gitlab-ci.semgrep-sast.yml"
test -f "$BASE_DIR/runbooks/sast-triage-runbook.md"
test -f "$BASE_DIR/notes/sast-with-semgrep.md"
test -f "$BASE_DIR/notes/semgrep-rule-writing.md"

if command -v semgrep >/dev/null 2>&1; then
  semgrep scan --config "$BASE_DIR/rules/node-express-security.yml" "$BASE_DIR/examples" >/dev/null || true
else
  echo "WARN: semgrep not installed; file validation only."
fi

echo "Semgrep SAST lesson validated."
```

Make executable:

```bash
chmod +x sast-semgrep/scripts/validate-sast-semgrep-lesson.sh
```

Run:

```bash
./sast-semgrep/scripts/validate-sast-semgrep-lesson.sh
```

---

# 18. Update Makefile

Open:

```bash
cd ~/devops-masterclass/09-devsecops-security-gates

nano Makefile
```

Add:

```Makefile
.PHONY: sast-validate sast-scan sast-summary sast-example

sast-validate:
	./sast-semgrep/scripts/validate-sast-semgrep-lesson.sh

sast-scan:
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_FINDINGS="$${FAIL_ON_FINDINGS:-false}" \
	./sast-semgrep/scripts/semgrep-sast-gate.sh

sast-summary:
	./sast-semgrep/scripts/semgrep-report-summary.sh

sast-example:
	semgrep scan --config sast-semgrep/rules/node-express-security.yml sast-semgrep/examples
```

Run:

```bash
make sast-validate
make sast-example
make sast-scan
make sast-summary
```

---

# 19. Practical Lab

Run everything:

```bash
cd ~/devops-masterclass/09-devsecops-security-gates

make validate
make sast-validate
make sast-example

ENVIRONMENT=pull_request \
FAIL_ON_FINDINGS=false \
make sast-scan

make sast-summary
```

Copy GitHub workflow:

```bash
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/sast-semgrep/github-actions/semgrep-sast.yml \
   .github/workflows/semgrep-sast.yml
```

Commit:

```bash
git status

git add .github/workflows/semgrep-sast.yml \
        09-devsecops-security-gates

git commit -m "feat: add Semgrep SAST security gate"
git push
```

---

# 20. Common Semgrep Problems

## `semgrep: command not found`

Fix:

```bash
pipx install semgrep
pipx ensurepath
exec "$SHELL"
semgrep --version
```

## Too many findings

Start in report mode:

```bash
FAIL_ON_FINDINGS=false ./sast-semgrep/scripts/semgrep-sast-gate.sh
```

Then tune rules before failing CI.

## False positives

Options:

```text
improve rule pattern
add pattern-not
limit paths
lower severity
document exception
use nosem only with review
```

## CI fails because Semgrep finds warnings

Set policy:

```bash
FAIL_ON_FINDINGS=false
SEVERITY_FAIL_LEVEL=ERROR
```

## SARIF upload fails in GitHub

Still keep artifacts:

```text
semgrep JSON report
semgrep SARIF report
summary JSON
```

SARIF upload depends on repository/security settings.

---

# 21. Interview Explanation

## What is SAST?

```text
SAST is Static Application Security Testing. It analyzes source code before runtime to identify insecure coding patterns such as injection risks, unsafe APIs, XSS-prone output, insecure crypto, and dangerous configuration.
```

## Why use Semgrep?

```text
Semgrep is useful because it is fast, CI-friendly, supports custom rules, works well with JavaScript/Node.js, and can produce JSON or SARIF reports for automation and security dashboards.
```

## What is a Semgrep rule?

```text
A Semgrep rule is a YAML definition that describes a code pattern to find, the target language, severity, message, and metadata such as category, CWE, and remediation guidance.
```

## How do you avoid false positives?

```text
I start in report mode, review findings, tune custom rules with pattern-not or narrower patterns, add tests/examples for rules, and only enforce blocking behavior after the team trusts the signal.
```

## Where should SAST run?

```text
SAST should run on pull requests to give early feedback and on main/release pipelines with stricter enforcement. Production releases should not proceed with untriaged high or critical SAST findings.
```

---

# 22. Today’s Core Rules

```text
SAST scans source code before build.
Semgrep can run locally and in CI.
Use report mode first.
Fail only after tuning.
Custom rules should include remediation messages.
JSON is for automation.
SARIF is for code scanning systems.
False positives must be triaged, not ignored silently.
Production gates should be stricter than PR gates.
SAST is one layer, not the whole security program.
```

---

# Next Lesson

# Lesson 9.3 — Secret Scanning with Gitleaks and Trivy

We will build:

```text
Gitleaks local scanning
Trivy secret scanning
custom allowlists
baseline handling
GitHub Actions secret scan workflow
Jenkins secret scan pipeline
GitLab CI secret scan pipeline
secret leak incident response
rotation workflow
fail/warn policy
portfolio-ready secret scanning gate
```

[1]: https://semgrep.dev/docs/deployment/oss-deployment "Semgrep Community Edition in CI - Semgrep"
[2]: https://semgrep.dev/docs/getting-started/cli "Local scans with Semgrep - Semgrep"
[3]: https://github.com/marketplace/actions/semgrep-action "semgrep-action · Actions · GitHub Marketplace · GitHub"
[4]: https://semgrep.dev/docs/cli-reference "CLI reference - Semgrep"
[5]: https://semgrep.dev/docs/writing-rules/rule-syntax "Rule structure syntax - Semgrep"
[6]: https://semgrep.dev/docs/writing-rules/pattern-syntax "Rule pattern syntax - Semgrep"

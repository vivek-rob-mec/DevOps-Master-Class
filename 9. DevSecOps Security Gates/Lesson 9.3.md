# Lesson 9.3 — Secret Scanning with Gitleaks and Trivy

# Gitleaks Local Scanning, Trivy Secret Scanning, Allowlists, Baselines, GitHub Actions, Jenkins, GitLab CI, Incident Response, and Rotation Workflow

In Lesson 9.2, we added SAST with Semgrep.

Now we add one of the most important DevSecOps gates:

```text
secret scanning
```

Secret scanning detects accidentally committed credentials such as:

```text
AWS keys
GitHub tokens
Docker registry tokens
SSH private keys
database passwords
API keys
JWT signing secrets
.env files
private certificates
```

Gitleaks is an open-source scanner for secrets in Git repositories, files, and directories. Trivy can also scan local filesystems for vulnerabilities, misconfigurations, secrets, and licenses using `trivy fs`. ([Gitleaks][1])

---

# 1. Secret Scanning Mental Model

Secret scanning asks:

```text
Did we accidentally commit credentials into source code, config, logs, examples, or documentation?
```

Secret scanning should run in multiple places:

```text
developer machine
  ↓
pre-commit hook
  ↓
pull request
  ↓
main branch
  ↓
release pipeline
  ↓
scheduled repository scan
```

Professional rule:

```text
A leaked secret is not “fixed” by deleting the line. The secret must be revoked and rotated.
```

Why?

```text
Git history may still contain it.
CI logs may contain it.
Artifacts may contain it.
Attackers may already have copied it.
```

---

# 2. Gitleaks vs Trivy Secret Scanning

Use both patterns.

| Tool                 | Best Use                                                                           |
| -------------------- | ---------------------------------------------------------------------------------- |
| Gitleaks             | Git history, staged files, directory secret scanning, baselines, allowlists        |
| Trivy secret scanner | Filesystem/repo scanning alongside vulnerability, IaC, license, and SBOM workflows |

Gitleaks supports baselines so old known findings can be ignored while new leaks are blocked. Trivy filesystem scanning is useful in CI/CD because `trivy fs` can scan local project files for multiple scanner types, including secrets. ([GitHub][2])

---

# 3. Create Lesson Folder

Run:

```bash
cd ~/devops-masterclass/09-devsecops-security-gates

mkdir -p secret-scanning/{gitleaks,trivy,scripts,reports,github-actions,jenkins,gitlab,runbooks,examples,notes,policies}
```

Check:

```bash
tree -L 2 secret-scanning
```

---

# 4. Install Gitleaks

## Linux install with script

```bash
curl -sSfL https://raw.githubusercontent.com/gitleaks/gitleaks/master/install.sh | sh -s -- -b "$HOME/.local/bin"
gitleaks version
```

## Homebrew

```bash
brew install gitleaks
gitleaks version
```

## Docker

```bash
docker run --rm -v "$PWD:/repo" zricethezav/gitleaks:latest detect --source=/repo
```

For production, pin the Docker image version instead of using `latest`.

---

# 5. Install Trivy

If not already installed:

```bash
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
```

---

# 6. Create Secret Scanning Notes

Create:

```bash
nano secret-scanning/notes/secret-scanning-mental-model.md
```

Paste:

```markdown
# Secret Scanning Mental Model

## Goal

Detect committed or staged secrets before they reach production systems.

## Examples of Secrets

- AWS access keys
- GitHub tokens
- Docker registry tokens
- SSH private keys
- database passwords
- JWT secrets
- API keys
- private certificates
- `.env` files

## Tools

| Tool | Purpose |
|---|---|
| Gitleaks | Git and directory secret scanning |
| Trivy secret scanner | Filesystem/repository secret scanning as part of broader security scanning |

## Golden Rule

If a real secret is committed, deleting it from the repository is not enough.

You must:

1. revoke it
2. rotate it
3. inspect logs/artifacts
4. investigate misuse
5. prevent recurrence

## Pipeline Policy

Pull request:

- fail on real secret
- allow documented false positives

Main:

- fail on real secret
- archive reports

Production:

- block release if secrets are found
```

---

# 7. Create Safe Fake Secret Examples

We need test data, but we must not create real secrets.

Create:

```bash
nano secret-scanning/examples/fake-secrets-example.txt
```

Paste:

```text
# Fake examples for scanner testing only.
# These are not real credentials.

example_api_key = "sk_test_fake_example_value_not_real_1234567890"

fake_private_key_marker = "-----BEGIN PRIVATE KEY-----FAKE-NOT-REAL-----END PRIVATE KEY-----"

fake_password = "not-a-real-password-example-123456"
```

Important:

```text
Never use real keys for testing scanners.
Use fake values only.
```

---

# 8. Basic Gitleaks Scan

From repo root:

```bash
cd ~/devops-masterclass

gitleaks detect \
  --source . \
  --report-format json \
  --report-path 09-devsecops-security-gates/secret-scanning/reports/gitleaks-report.json \
  --redact
```

Show results:

```bash
cat 09-devsecops-security-gates/secret-scanning/reports/gitleaks-report.json | jq .
```

`--redact` helps avoid printing the full secret value in reports.

---

# 9. Basic Trivy Secret Scan

Run:

```bash
cd ~/devops-masterclass

trivy fs \
  --scanners secret \
  --format json \
  --output 09-devsecops-security-gates/secret-scanning/reports/trivy-secret-report.json \
  .
```

Show summary:

```bash
cat 09-devsecops-security-gates/secret-scanning/reports/trivy-secret-report.json \
  | jq '.Results[]? | select(.Secrets != null) | {Target, Secrets}'
```

Trivy’s filesystem scanner can scan local project files and supports scanner selection through `--scanners`; the filesystem docs state that vulnerability and secret scanning are enabled by default and can be configured. ([Trivy][3])

---

# 10. Gitleaks Configuration

Create:

```bash
nano secret-scanning/gitleaks/gitleaks.toml
```

Paste:

```toml
title = "demo-node-api gitleaks config"

[extend]
useDefault = true

[allowlist]
description = "Global allowlist for safe test fixtures and documentation"
paths = [
  '''09-devsecops-security-gates/secret-scanning/examples/fake-secrets-example.txt''',
  '''09-devsecops-security-gates/secret-scanning/reports/.*''',
  '''.*node_modules/.*''',
  '''.*coverage/.*'''
]

regexes = [
  '''sk_test_fake_example_value_not_real_[0-9]+'''
]
```

Gitleaks uses rules to identify secrets and allowlists to define values or paths that should not be treated as leaks; its default config documents that rules define secrets and allowlists define what is allowed. ([GitHub][4])

Run with config:

```bash
gitleaks detect \
  --source . \
  --config 09-devsecops-security-gates/secret-scanning/gitleaks/gitleaks.toml \
  --report-format json \
  --report-path 09-devsecops-security-gates/secret-scanning/reports/gitleaks-configured-report.json \
  --redact
```

---

# 11. Baseline Handling

Baselines are useful when a large repo already has known old findings.

Create baseline:

```bash
cd ~/devops-masterclass

gitleaks detect \
  --source . \
  --config 09-devsecops-security-gates/secret-scanning/gitleaks/gitleaks.toml \
  --report-format json \
  --report-path 09-devsecops-security-gates/secret-scanning/gitleaks/baseline.json \
  --redact || true
```

Future scans can use:

```bash
gitleaks detect \
  --source . \
  --config 09-devsecops-security-gates/secret-scanning/gitleaks/gitleaks.toml \
  --baseline-path 09-devsecops-security-gates/secret-scanning/gitleaks/baseline.json \
  --report-format json \
  --report-path 09-devsecops-security-gates/secret-scanning/reports/gitleaks-new-findings.json \
  --redact
```

Gitleaks baselines let you ignore old findings already present in a baseline report, which is useful when introducing secret scanning to an existing repository. ([GitHub][2])

Professional warning:

```text
A baseline is not a security fix.
A baseline is a migration tool.
```

You should still triage old findings and rotate any real leaked secrets.

---

# 12. Gitleaks Gate Script

Create:

```bash
nano secret-scanning/scripts/gitleaks-gate.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
MODULE_DIR="${MODULE_DIR:-$ROOT_DIR/09-devsecops-security-gates}"
CONFIG_FILE="${CONFIG_FILE:-$MODULE_DIR/secret-scanning/gitleaks/gitleaks.toml}"
BASELINE_FILE="${BASELINE_FILE:-}"
REPORT_DIR="${REPORT_DIR:-$MODULE_DIR/secret-scanning/reports}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"
FAIL_ON_FINDINGS="${FAIL_ON_FINDINGS:-true}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/gitleaks-$ENVIRONMENT-$TIMESTAMP.json"
SUMMARY_FILE="$REPORT_DIR/gitleaks-summary-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== Gitleaks Secret Gate ====="
echo "Root: $ROOT_DIR"
echo "Config: $CONFIG_FILE"
echo "Baseline: ${BASELINE_FILE:-none}"
echo "Environment: $ENVIRONMENT"
echo "Fail on findings: $FAIL_ON_FINDINGS"

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "ERROR: gitleaks is not installed" >&2
  exit 1
fi

cd "$ROOT_DIR"

CMD=(
  gitleaks detect
  --source "$ROOT_DIR"
  --config "$CONFIG_FILE"
  --report-format json
  --report-path "$REPORT_FILE"
  --redact
)

if [ -n "$BASELINE_FILE" ] && [ -f "$BASELINE_FILE" ]; then
  CMD+=(--baseline-path "$BASELINE_FILE")
fi

set +e
"${CMD[@]}"
GITLEAKS_EXIT=$?
set -e

if [ -f "$REPORT_FILE" ]; then
  FINDINGS="$(jq 'length' "$REPORT_FILE")"
else
  FINDINGS=0
  echo "[]" > "$REPORT_FILE"
fi

DECISION="passed"

if [ "$FINDINGS" -gt 0 ] && [ "$FAIL_ON_FINDINGS" = "true" ]; then
  DECISION="failed"
fi

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "secret_scan",
  "tool": "gitleaks",
  "environment": "$ENVIRONMENT",
  "findings": $FINDINGS,
  "report_file": "$REPORT_FILE",
  "baseline_file": "$BASELINE_FILE",
  "gitleaks_exit_code": $GITLEAKS_EXIT,
  "decision": "$DECISION",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: Gitleaks gate failed. Review $REPORT_FILE" >&2
  exit 1
fi

echo "Gitleaks gate passed."
```

Make executable:

```bash
chmod +x secret-scanning/scripts/gitleaks-gate.sh
```

Run report mode:

```bash
ENVIRONMENT=pull_request \
FAIL_ON_FINDINGS=false \
./secret-scanning/scripts/gitleaks-gate.sh
```

Run strict mode:

```bash
ENVIRONMENT=main \
FAIL_ON_FINDINGS=true \
./secret-scanning/scripts/gitleaks-gate.sh
```

---

# 13. Trivy Secret Gate Script

Create:

```bash
nano secret-scanning/scripts/trivy-secret-gate.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
MODULE_DIR="${MODULE_DIR:-$ROOT_DIR/09-devsecops-security-gates}"
TARGET_DIR="${TARGET_DIR:-$ROOT_DIR}"
REPORT_DIR="${REPORT_DIR:-$MODULE_DIR/secret-scanning/reports}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"
FAIL_ON_FINDINGS="${FAIL_ON_FINDINGS:-true}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/trivy-secret-$ENVIRONMENT-$TIMESTAMP.json"
SUMMARY_FILE="$REPORT_DIR/trivy-secret-summary-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== Trivy Secret Gate ====="
echo "Target: $TARGET_DIR"
echo "Environment: $ENVIRONMENT"
echo "Fail on findings: $FAIL_ON_FINDINGS"

if ! command -v trivy >/dev/null 2>&1; then
  echo "ERROR: trivy is not installed" >&2
  exit 1
fi

set +e
trivy fs \
  --scanners secret \
  --format json \
  --output "$REPORT_FILE" \
  "$TARGET_DIR"
TRIVY_EXIT=$?
set -e

SECRET_COUNT="$(jq '[.Results[]? | .Secrets[]?] | length' "$REPORT_FILE")"

DECISION="passed"

if [ "$SECRET_COUNT" -gt 0 ] && [ "$FAIL_ON_FINDINGS" = "true" ]; then
  DECISION="failed"
fi

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "secret_scan",
  "tool": "trivy",
  "environment": "$ENVIRONMENT",
  "secret_findings": $SECRET_COUNT,
  "report_file": "$REPORT_FILE",
  "trivy_exit_code": $TRIVY_EXIT,
  "decision": "$DECISION",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: Trivy secret gate failed. Review $REPORT_FILE" >&2
  exit 1
fi

echo "Trivy secret gate passed."
```

Make executable:

```bash
chmod +x secret-scanning/scripts/trivy-secret-gate.sh
```

Run:

```bash
ENVIRONMENT=pull_request \
FAIL_ON_FINDINGS=false \
./secret-scanning/scripts/trivy-secret-gate.sh
```

---

# 14. Combined Secret Scanning Gate

Create:

```bash
nano secret-scanning/scripts/secret-scan-gate.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="${MODULE_DIR:-$HOME/devops-masterclass/09-devsecops-security-gates}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"
FAIL_ON_FINDINGS="${FAIL_ON_FINDINGS:-true}"
RUN_GITLEAKS="${RUN_GITLEAKS:-true}"
RUN_TRIVY="${RUN_TRIVY:-true}"

echo "===== Combined Secret Scanning Gate ====="
echo "Environment: $ENVIRONMENT"
echo "Fail on findings: $FAIL_ON_FINDINGS"

FAILED=0

cd "$MODULE_DIR"

if [ "$RUN_GITLEAKS" = "true" ]; then
  echo
  echo "===== Running Gitleaks ====="
  ENVIRONMENT="$ENVIRONMENT" \
  FAIL_ON_FINDINGS="$FAIL_ON_FINDINGS" \
  ./secret-scanning/scripts/gitleaks-gate.sh || FAILED=1
fi

if [ "$RUN_TRIVY" = "true" ]; then
  echo
  echo "===== Running Trivy Secret Scanner ====="
  ENVIRONMENT="$ENVIRONMENT" \
  FAIL_ON_FINDINGS="$FAIL_ON_FINDINGS" \
  ./secret-scanning/scripts/trivy-secret-gate.sh || FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
  echo "ERROR: combined secret scanning gate failed" >&2
  exit 1
fi

echo "Combined secret scanning gate passed."
```

Make executable:

```bash
chmod +x secret-scanning/scripts/secret-scan-gate.sh
```

Run:

```bash
ENVIRONMENT=pull_request \
FAIL_ON_FINDINGS=false \
./secret-scanning/scripts/secret-scan-gate.sh
```

Strict:

```bash
ENVIRONMENT=main \
FAIL_ON_FINDINGS=true \
./secret-scanning/scripts/secret-scan-gate.sh
```

---

# 15. Secret Scan Summary Script

Create:

```bash
nano secret-scanning/scripts/secret-scan-summary.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-secret-scanning/reports}"

echo "===== Secret Scan Summary ====="
echo "Report dir: $REPORT_DIR"

find "$REPORT_DIR" -type f -name '*summary*.json' | sort | tail -n 10 | while read -r file; do
  echo
  echo "## $file"
  jq . "$file"
done

echo
echo "Recent raw reports:"
find "$REPORT_DIR" -type f \( -name 'gitleaks-*.json' -o -name 'trivy-secret-*.json' \) | sort | tail -n 10
```

Make executable:

```bash
chmod +x secret-scanning/scripts/secret-scan-summary.sh
```

Run:

```bash
./secret-scanning/scripts/secret-scan-summary.sh
```

---

# 16. GitHub Actions Secret Scan Workflow

Create:

```bash
nano secret-scanning/github-actions/secret-scanning.yml
```

Paste:

```yaml
name: Secret Scanning

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

env:
  MODULE9_DIR: 09-devsecops-security-gates

jobs:
  secret-scan:
    name: Gitleaks and Trivy Secret Scan
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Install Gitleaks
        run: |
          curl -sSfL https://raw.githubusercontent.com/gitleaks/gitleaks/master/install.sh \
            | sh -s -- -b "$HOME/.local/bin"
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"
          gitleaks version

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

      - name: Run secret scanning gate
        run: |
          cd "$MODULE9_DIR"

          if [ "${{ github.event_name }}" = "pull_request" ]; then
            MODE="pull_request"
            FAIL="true"
          else
            MODE="main"
            FAIL="true"
          fi

          ENVIRONMENT="$MODE" \
          FAIL_ON_FINDINGS="$FAIL" \
          ./secret-scanning/scripts/secret-scan-gate.sh

      - name: Upload secret scanning reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: secret-scanning-reports
          path: 09-devsecops-security-gates/secret-scanning/reports/
```

Copy:

```bash
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/secret-scanning/github-actions/secret-scanning.yml \
   .github/workflows/secret-scanning.yml
```

Gitleaks also provides an official GitHub Action, but using CLI installation keeps this lesson consistent across GitHub Actions, Jenkins, and GitLab CI. The Gitleaks Action describes Gitleaks as a scanner for hardcoded secrets such as passwords, API keys, and tokens in Git repositories. ([GitHub][5])

---

# 17. Jenkins Secret Scan Pipeline

Create:

```bash
nano secret-scanning/jenkins/Jenkinsfile.secret-scanning
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
    choice(name: 'ENVIRONMENT', choices: ['pull_request', 'main', 'production'], description: 'Gate environment')
    booleanParam(name: 'FAIL_ON_FINDINGS', defaultValue: true, description: 'Fail if secrets are found?')
  }

  environment {
    MODULE9_DIR = '09-devsecops-security-gates'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Install Tools') {
      steps {
        sh '''
          set -e

          if ! command -v gitleaks >/dev/null 2>&1; then
            curl -sSfL https://raw.githubusercontent.com/gitleaks/gitleaks/master/install.sh \
              | sh -s -- -b "$HOME/.local/bin"
          fi

          if ! command -v trivy >/dev/null 2>&1; then
            echo "Trivy not found. Install Trivy on this Jenkins agent or use a Dockerized scanner."
            exit 1
          fi

          export PATH="$HOME/.local/bin:$PATH"
          gitleaks version
          trivy --version
        '''
      }
    }

    stage('Secret Scan') {
      steps {
        dir("${MODULE9_DIR}") {
          sh '''
            export PATH="$HOME/.local/bin:$PATH"

            ENVIRONMENT="${ENVIRONMENT}" \
            FAIL_ON_FINDINGS="${FAIL_ON_FINDINGS}" \
            ./secret-scanning/scripts/secret-scan-gate.sh
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '09-devsecops-security-gates/secret-scanning/reports/**/*', allowEmptyArchive: true
    }

    success {
      echo 'Secret scanning gate passed.'
    }

    failure {
      echo 'Secret scanning gate failed. Review archived reports and rotate any real leaked secrets.'
    }
  }
}
```

Jenkins job script path:

```text
09-devsecops-security-gates/secret-scanning/jenkins/Jenkinsfile.secret-scanning
```

---

# 18. GitLab CI Secret Scan Pipeline

Create:

```bash
nano secret-scanning/gitlab/.gitlab-ci.secret-scanning.yml
```

Paste:

```yaml
stages:
  - secret_scan

variables:
  MODULE9_DIR: "09-devsecops-security-gates"

secret_scanning_custom:
  stage: secret_scan
  image: alpine:3.20
  before_script:
    - apk add --no-cache bash curl git jq
    - curl -sSfL https://raw.githubusercontent.com/gitleaks/gitleaks/master/install.sh | sh -s -- -b /usr/local/bin
    - gitleaks version
  script:
    - cd "$MODULE9_DIR"
    - |
      ENVIRONMENT="${CI_COMMIT_BRANCH:-pull_request}" \
      FAIL_ON_FINDINGS=true \
      RUN_GITLEAKS=true \
      RUN_TRIVY=false \
      ./secret-scanning/scripts/secret-scan-gate.sh
  artifacts:
    when: always
    expire_in: 30 days
    paths:
      - 09-devsecops-security-gates/secret-scanning/reports/
```

GitLab also has built-in pipeline secret detection. Its docs state that pipeline secret detection scans files after they are committed and pushed, creating a `secret_detection` job and JSON report artifacts. ([GitLab Docs][6])

Optional GitLab built-in template:

```yaml
include:
  - template: Jobs/Secret-Detection.gitlab-ci.yml
```

Professional pattern:

```text
Use GitLab built-in secret detection when available.
Use custom Gitleaks/Trivy jobs when you need portability or custom behavior.
```

---

# 19. Pre-Commit Hook Pattern

Create:

```bash
nano secret-scanning/scripts/install-gitleaks-precommit-hook.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
MODULE_DIR="$ROOT_DIR/09-devsecops-security-gates"
HOOK_FILE="$ROOT_DIR/.git/hooks/pre-commit"

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "ERROR: gitleaks is required" >&2
  exit 1
fi

cat > "$HOOK_FILE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "Running Gitleaks pre-commit secret scan..."

gitleaks detect \
  --source . \
  --config 09-devsecops-security-gates/secret-scanning/gitleaks/gitleaks.toml \
  --redact

echo "Gitleaks pre-commit scan passed."
EOF

chmod +x "$HOOK_FILE"

echo "Installed pre-commit hook: $HOOK_FILE"
```

Make executable:

```bash
chmod +x secret-scanning/scripts/install-gitleaks-precommit-hook.sh
```

Install:

```bash
./secret-scanning/scripts/install-gitleaks-precommit-hook.sh
```

Professional warning:

```text
Pre-commit hooks help developers, but CI must still enforce secret scanning.
Hooks can be bypassed.
```

---

# 20. Secret Leak Incident Runbook

Create:

```bash
nano secret-scanning/runbooks/secret-leak-incident-runbook.md
```

Paste:

```markdown
# Secret Leak Incident Runbook

## Goal

Respond safely when a real secret is found in source code, logs, artifacts, or CI/CD output.

## Immediate Actions

1. Stop the affected pipeline.
2. Revoke the leaked secret.
3. Rotate the credential.
4. Check whether the secret was used.
5. Search CI logs and artifacts.
6. Search Git history.
7. Remove the secret from active code.
8. Update detection rules if needed.
9. Create incident record.
10. Add prevention controls.

## AWS Key Leak

1. Disable the access key immediately.
2. Review CloudTrail for usage.
3. Rotate dependent credentials.
4. Replace static key with OIDC where possible.
5. Check IAM permissions for over-broad access.

## GitHub Token Leak

1. Revoke token.
2. Check repository/package activity.
3. Rotate automation secret.
4. Review workflows for unsafe echo/env dumps.
5. Prefer `GITHUB_TOKEN` with scoped permissions where possible.

## SSH Private Key Leak

1. Remove public key from all servers.
2. Rotate key pair.
3. Review SSH auth logs.
4. Check deployed files.
5. Restrict future deploy keys.

## Database Password Leak

1. Rotate database password.
2. Kill active sessions if needed.
3. Review access logs.
4. Update secret manager/CI variables.
5. Redeploy affected services.

## Important Rule

Deleting the secret from Git is not enough.
The credential must be revoked and rotated.
```

---

# 21. Secret Rotation Checklist

Create:

```bash
nano secret-scanning/runbooks/secret-rotation-checklist.md
```

Paste:

```markdown
# Secret Rotation Checklist

## Rotation Steps

- [ ] Identify leaked secret type.
- [ ] Identify owner.
- [ ] Identify all consumers.
- [ ] Create replacement secret.
- [ ] Update CI/CD secret store.
- [ ] Update runtime secret store.
- [ ] Test staging pipeline.
- [ ] Deploy production update.
- [ ] Revoke old secret.
- [ ] Confirm old secret no longer works.
- [ ] Review logs for misuse.
- [ ] Document incident.
- [ ] Add scanner rule or allowlist correction.

## Do Not

- paste new secret into chat
- print new secret in logs
- store new secret in Git
- leave old secret active
- rotate without knowing consumers
```

---

# 22. Secret Scanning Policy

Create:

```bash
nano secret-scanning/policies/secret-scanning-policy.json
```

Paste:

```json
{
  "service_name": "demo-node-api",
  "policy_version": "1.0",
  "tools": ["gitleaks", "trivy"],
  "environments": {
    "pull_request": {
      "real_secret": "fail",
      "false_positive": "allow_with_documented_allowlist",
      "baseline_allowed": true
    },
    "main": {
      "real_secret": "fail",
      "false_positive": "allow_with_documented_allowlist",
      "baseline_allowed": true
    },
    "production": {
      "real_secret": "fail",
      "false_positive": "must_be_reviewed",
      "baseline_allowed": false
    }
  },
  "required_response_for_real_secret": [
    "revoke",
    "rotate",
    "investigate_usage",
    "remove_from_active_code",
    "review_logs_and_artifacts",
    "document_incident"
  ],
  "forbidden_files": [
    ".env",
    ".env.production",
    "id_rsa",
    "id_ed25519",
    "*.pem",
    "*.p12"
  ]
}
```

---

# 23. Validation Script

Create:

```bash
nano secret-scanning/scripts/validate-secret-scanning-lesson.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-secret-scanning}"

echo "===== Validate Secret Scanning Lesson ====="

test -f "$BASE_DIR/gitleaks/gitleaks.toml"
test -x "$BASE_DIR/scripts/gitleaks-gate.sh"
test -x "$BASE_DIR/scripts/trivy-secret-gate.sh"
test -x "$BASE_DIR/scripts/secret-scan-gate.sh"
test -x "$BASE_DIR/scripts/secret-scan-summary.sh"
test -x "$BASE_DIR/scripts/install-gitleaks-precommit-hook.sh"
test -f "$BASE_DIR/github-actions/secret-scanning.yml"
test -f "$BASE_DIR/jenkins/Jenkinsfile.secret-scanning"
test -f "$BASE_DIR/gitlab/.gitlab-ci.secret-scanning.yml"
test -f "$BASE_DIR/runbooks/secret-leak-incident-runbook.md"
test -f "$BASE_DIR/runbooks/secret-rotation-checklist.md"
test -f "$BASE_DIR/policies/secret-scanning-policy.json"
test -f "$BASE_DIR/examples/fake-secrets-example.txt"
test -f "$BASE_DIR/notes/secret-scanning-mental-model.md"

echo "Secret scanning lesson validated."
```

Make executable:

```bash
chmod +x secret-scanning/scripts/validate-secret-scanning-lesson.sh
```

Run:

```bash
./secret-scanning/scripts/validate-secret-scanning-lesson.sh
```

---

# 24. Update Makefile

Open:

```bash
cd ~/devops-masterclass/09-devsecops-security-gates

nano Makefile
```

Add:

```Makefile
.PHONY: secret-validate secret-scan secret-summary gitleaks-scan trivy-secret-scan install-secret-hook

secret-validate:
	./secret-scanning/scripts/validate-secret-scanning-lesson.sh

secret-scan:
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_FINDINGS="$${FAIL_ON_FINDINGS:-false}" \
	./secret-scanning/scripts/secret-scan-gate.sh

gitleaks-scan:
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_FINDINGS="$${FAIL_ON_FINDINGS:-false}" \
	./secret-scanning/scripts/gitleaks-gate.sh

trivy-secret-scan:
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_FINDINGS="$${FAIL_ON_FINDINGS:-false}" \
	./secret-scanning/scripts/trivy-secret-gate.sh

secret-summary:
	./secret-scanning/scripts/secret-scan-summary.sh

install-secret-hook:
	./secret-scanning/scripts/install-gitleaks-precommit-hook.sh
```

Run:

```bash
make secret-validate
make secret-scan
make secret-summary
```

---

# 25. Practical Lab

Run:

```bash
cd ~/devops-masterclass/09-devsecops-security-gates

make secret-validate

ENVIRONMENT=pull_request \
FAIL_ON_FINDINGS=false \
make secret-scan

make secret-summary
```

Copy GitHub workflow:

```bash
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/secret-scanning/github-actions/secret-scanning.yml \
   .github/workflows/secret-scanning.yml
```

Commit:

```bash
git status

git add .github/workflows/secret-scanning.yml \
        09-devsecops-security-gates

git commit -m "feat: add secret scanning gates with Gitleaks and Trivy"
git push
```

---

# 26. Common Secret Scanning Problems

## False positives

Fix options:

```text
add targeted allowlist
improve scanner config
move fake examples into approved fixtures
document why allowed
avoid broad allowlists
```

Bad allowlist:

```toml
regexes = ['''.*''']
```

Good allowlist:

```toml
paths = ['''09-devsecops-security-gates/secret-scanning/examples/fake-secrets-example.txt''']
```

## Old repository findings

Use baseline temporarily:

```bash
gitleaks detect --source . --report-path baseline.json --redact || true
```

Then:

```bash
gitleaks detect --source . --baseline-path baseline.json --redact
```

But still rotate real exposed secrets.

## CI fails on fake examples

Put fake examples under allowlisted path.

## Secret found in logs

Treat it like a real incident:

```text
revoke
rotate
delete log if possible
review access
document incident
```

## Secret found in Git history

Use this response:

```text
revoke and rotate first
then clean Git history if required
force-push only after coordination
invalidate old clones if possible
```

---

# 27. Interview Explanation

## What is secret scanning?

```text
Secret scanning is an automated security check that detects credentials such as API keys, tokens, SSH keys, database passwords, and cloud keys in source code, Git history, files, logs, or artifacts.
```

## Why use Gitleaks?

```text
Gitleaks is useful because it scans Git repositories, files, and directories for hardcoded secrets, supports custom configuration, allowlists, JSON reports, and baselines for gradually adopting secret scanning in existing repositories.
```

## Why also use Trivy?

```text
Trivy can scan a filesystem or repository for secrets as part of a broader security workflow that also includes vulnerabilities, misconfigurations, and licenses. This makes it useful as a unified DevSecOps scanner.
```

## What do you do if a real secret is committed?

```text
I revoke and rotate the credential immediately, check logs and artifacts, investigate usage, remove the secret from active code, clean Git history if necessary, update CI/CD secrets, and document the incident. Deleting the line alone is not enough.
```

## What is a baseline?

```text
A baseline is a previous scanner report used to ignore known historical findings while blocking new findings. It helps introduce scanning to existing repositories, but it does not remove the need to triage and rotate real leaked secrets.
```

## How do you handle false positives?

```text
I use narrow allowlists for known safe test fixtures or false positives, document the reason, and avoid broad allowlists that hide real secrets.
```

---

# 28. Today’s Core Rules

```text
Fail real secrets immediately.
Deleting a leaked secret is not enough.
Revoke and rotate exposed credentials.
Use Gitleaks for Git-aware secret scanning.
Use Trivy for filesystem/repository secret scanning.
Use redacted reports.
Use narrow allowlists.
Use baselines only as migration tools.
Do not upload secrets in artifacts.
Do not print env dumps in CI.
Run secret scanning in PR and main pipelines.
CI enforcement is required because hooks can be bypassed.
```

---

# Next Lesson

# Lesson 9.4 — SCA Dependency Scanning

We will build:

```text
npm audit gate
Trivy filesystem dependency scan
dependency vulnerability policy
high/critical fail strategy
dependency exception handling
GitHub dependency review workflow
Jenkins dependency scan pipeline
GitLab dependency scan pipeline
dependency update runbook
package lock security workflow
portfolio-ready SCA gate
```

[1]: https://gitleaks.io/?utm_source=chatgpt.com "Gitleaks"
[2]: https://github.com/gitleaks/gitleaks?utm_source=chatgpt.com "Find secrets with Gitleaks"
[3]: https://trivy.dev/docs/latest/target/filesystem/?utm_source=chatgpt.com "Filesystem"
[4]: https://github.com/gitleaks/gitleaks/blob/master/config/gitleaks.toml?utm_source=chatgpt.com "gitleaks/config/gitleaks.toml at master"
[5]: https://github.com/gitleaks/gitleaks-action?utm_source=chatgpt.com "Protect your secrets using Gitleaks-Action"
[6]: https://docs.gitlab.com/user/application_security/secret_detection/pipeline/?utm_source=chatgpt.com "Pipeline secret detection"

# Lesson 8.11 — Pipeline Observability and Debugging

# CI/CD Logs, Structured Reports, Failure Classification, Debug Artifacts, Stage Timing, Flaky Test Tracking, Deployment Traceability, Notifications, GitHub Summaries, Jenkins Artifacts, GitLab Artifacts, and Pipeline Incident Runbooks

In Lesson 8.10, you built deployment and rollback pipelines.

Now we learn how to **observe and debug CI/CD pipelines like production systems**.

A mature DevOps engineer does not only ask:

```text
Did the pipeline pass or fail?
```

A mature DevOps engineer asks:

```text
Which stage failed?
Why did it fail?
Was it source, dependency, test, build, scan, registry, deploy, or environment?
How long did each stage take?
Was this failure new or recurring?
Was this test flaky?
What artifact was being deployed?
What commit triggered it?
What reports were archived?
Who approved it?
What rollback version was available?
```

GitHub Actions supports workflow commands for annotations, grouped logs, masking, outputs, and job summaries; Jenkins supports archiving generated files as pipeline artifacts; GitLab job artifacts preserve files produced by jobs, and GitLab artifact reports can feed test/security/code-quality data into merge requests and pipeline views. ([GitHub Docs][1])

---

# 1. Why Pipeline Observability Matters

A weak pipeline gives you this:

```text
Build failed.
```

A strong pipeline gives you this:

```json
{
  "pipeline": "github-actions-production",
  "service": "demo-node-api",
  "commit": "a1b2c3d",
  "stage": "container_scan",
  "failure_type": "security_gate",
  "severity": "critical",
  "artifact": "ghcr.io/user/demo-node-api:0.8.0-dev-a1b2c3d",
  "rollback_version": "0.7.0-f9e8d7c",
  "recommended_action": "Review Trivy report and dependency patch"
}
```

Professional rule:

```text
CI/CD pipelines should be observable because they are part of the production delivery system.
```

---

# 2. What to Observe in CI/CD

You should observe:

```text
pipeline identity:
  CI system, workflow/job name, run ID, build number

source identity:
  repository, branch, tag, commit SHA, author

artifact identity:
  image name, image tag, digest, SBOM, provenance

stage status:
  passed, failed, skipped, warning

stage duration:
  how long each stage took

failure classification:
  dependency, test, build, scan, deploy, environment, permission

deployment traceability:
  environment, approver, deployed version, rollback version

evidence:
  test reports, scan reports, quality gate reports, deployment reports

notifications:
  who needs to know, what happened, what to do next
```

---

# 3. Pipeline Failure Taxonomy

Create a consistent failure classification.

```text
source_failure:
  checkout failed, merge conflict, missing files

dependency_failure:
  npm ci failed, package registry unavailable, lockfile mismatch

test_failure:
  unit/integration/smoke tests failed

quality_gate_failure:
  lint, format, coverage, secret scan, dependency scan failed

build_failure:
  Docker build failed, artifact packaging failed

scan_failure:
  vulnerability scan, SBOM generation, provenance, signing failed

registry_failure:
  login, push, pull, tag immutability, permission denied

deployment_failure:
  deploy command failed, container did not start

verification_failure:
  health, readiness, version, smoke test failed

environment_failure:
  server, network, DNS, disk, memory, secret, database issue

pipeline_infra_failure:
  runner offline, Jenkins agent down, GitLab runner stuck, GitHub hosted runner issue
```

Professional rule:

```text
Classify failures first. Fix second.
```

---

# 4. Create Pipeline Observability Directory

Run:

```bash
cd ~/devops-masterclass/08-cicd-pipelines

mkdir -p pipeline-observability/{scripts,github-actions,jenkins,gitlab,notes,runbooks,reports,examples,policies,dashboards}
```

Check:

```bash
tree -L 2 pipeline-observability
```

---

# 5. Observability Policy

Create:

```bash
nano pipeline-observability/policies/pipeline-observability-policy.json
```

Paste:

```json
{
  "service_name": "demo-node-api",
  "policy_version": "1.0",
  "required_reports": [
    "pipeline_context",
    "stage_timing",
    "failure_classification",
    "quality_gate_summary",
    "artifact_identity",
    "deployment_record"
  ],
  "failure_types": [
    "source_failure",
    "dependency_failure",
    "test_failure",
    "quality_gate_failure",
    "build_failure",
    "scan_failure",
    "registry_failure",
    "deployment_failure",
    "verification_failure",
    "environment_failure",
    "pipeline_infra_failure",
    "unknown_failure"
  ],
  "retention": {
    "pull_request_reports_days": 14,
    "main_reports_days": 30,
    "production_reports_days": 90
  },
  "notification_rules": {
    "pull_request_failure": "notify_author",
    "main_failure": "notify_devops_channel",
    "production_deployment_failure": "notify_incident_channel",
    "rollback_triggered": "notify_incident_channel"
  }
}
```

---

# 6. Pipeline Context Script

This script records pipeline metadata in a portable format.

Create:

```bash
nano pipeline-observability/scripts/create-pipeline-context.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-pipeline-observability/reports}"
SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"
CI_SYSTEM="${CI_SYSTEM:-local}"
PIPELINE_NAME="${PIPELINE_NAME:-unknown}"
PIPELINE_RUN_ID="${PIPELINE_RUN_ID:-unknown}"
JOB_NAME_VALUE="${JOB_NAME:-unknown}"
BUILD_URL_VALUE="${BUILD_URL:-}"
REPOSITORY="${REPOSITORY:-$(git config --get remote.origin.url 2>/dev/null || echo unknown)}"
BRANCH="${BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)}"
COMMIT_SHA="${COMMIT_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
SHORT_SHA="${SHORT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"
TRIGGERED_BY="${TRIGGERED_BY:-$(whoami)}"

mkdir -p "$REPORT_DIR"

OUTPUT_FILE="$REPORT_DIR/pipeline-context-$(date +%Y%m%d_%H%M%S).json"

cat > "$OUTPUT_FILE" <<EOF
{
  "service_name": "$SERVICE_NAME",
  "ci_system": "$CI_SYSTEM",
  "pipeline_name": "$PIPELINE_NAME",
  "pipeline_run_id": "$PIPELINE_RUN_ID",
  "job_name": "$JOB_NAME_VALUE",
  "build_url": "$BUILD_URL_VALUE",
  "repository": "$REPOSITORY",
  "branch": "$BRANCH",
  "commit_sha": "$COMMIT_SHA",
  "short_sha": "$SHORT_SHA",
  "triggered_by": "$TRIGGERED_BY",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$OUTPUT_FILE" | jq .
echo "Pipeline context: $OUTPUT_FILE"
```

Make executable:

```bash
chmod +x pipeline-observability/scripts/create-pipeline-context.sh
```

Run:

```bash
./pipeline-observability/scripts/create-pipeline-context.sh
```

---

# 7. Stage Timing Script

Stage timing helps answer:

```text
Which stage is slow?
Did the pipeline become slower over time?
Where should we optimize?
```

Create:

```bash
nano pipeline-observability/scripts/stage-timer.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
STAGE_NAME="${2:-}"
REPORT_DIR="${REPORT_DIR:-pipeline-observability/reports}"
STATE_DIR="${STATE_DIR:-$REPORT_DIR/.stage-timer-state}"

mkdir -p "$REPORT_DIR" "$STATE_DIR"

if [ -z "$ACTION" ] || [ -z "$STAGE_NAME" ]; then
  echo "Usage:"
  echo "  $0 start <stage-name>"
  echo "  $0 end <stage-name>"
  exit 1
fi

SAFE_STAGE="$(echo "$STAGE_NAME" | tr '/ :' '___')"
START_FILE="$STATE_DIR/$SAFE_STAGE.start"
OUTPUT_FILE="$REPORT_DIR/stage-timing-$SAFE_STAGE.json"

case "$ACTION" in
  start)
    date +%s > "$START_FILE"
    echo "Started stage timer: $STAGE_NAME"
    ;;

  end)
    if [ ! -f "$START_FILE" ]; then
      echo "ERROR: start time not found for stage: $STAGE_NAME" >&2
      exit 1
    fi

    START_TS="$(cat "$START_FILE")"
    END_TS="$(date +%s)"
    DURATION="$((END_TS - START_TS))"

    cat > "$OUTPUT_FILE" <<EOF
{
  "stage": "$STAGE_NAME",
  "start_epoch": "$START_TS",
  "end_epoch": "$END_TS",
  "duration_seconds": "$DURATION",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

    cat "$OUTPUT_FILE" | jq .
    echo "Stage timing report: $OUTPUT_FILE"
    ;;

  *)
    echo "ERROR: unsupported action: $ACTION" >&2
    exit 1
    ;;
esac
```

Make executable:

```bash
chmod +x pipeline-observability/scripts/stage-timer.sh
```

Test:

```bash
./pipeline-observability/scripts/stage-timer.sh start test
sleep 2
./pipeline-observability/scripts/stage-timer.sh end test
```

---

# 8. Failure Classifier Script

Create:

```bash
nano pipeline-observability/scripts/classify-failure.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

STAGE="${STAGE:-unknown}"
EXIT_CODE="${EXIT_CODE:-1}"
LOG_FILE="${LOG_FILE:-}"
REPORT_DIR="${REPORT_DIR:-pipeline-observability/reports}"
FAILURE_TYPE="unknown_failure"
RECOMMENDED_ACTION="Review pipeline logs and archived reports."

mkdir -p "$REPORT_DIR"

TEXT=""

if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
  TEXT="$(cat "$LOG_FILE")"
fi

case "$STAGE" in
  checkout|source)
    FAILURE_TYPE="source_failure"
    RECOMMENDED_ACTION="Check Git checkout, branch, tag, credentials, and repository availability."
    ;;

  install|dependencies|npm-ci)
    FAILURE_TYPE="dependency_failure"
    RECOMMENDED_ACTION="Check lockfile, package registry, Node version, and dependency credentials."
    ;;

  test|unit-test|integration-test|smoke-test)
    FAILURE_TYPE="test_failure"
    RECOMMENDED_ACTION="Run tests locally and inspect test report."
    ;;

  lint|format|quality|quality-gates)
    FAILURE_TYPE="quality_gate_failure"
    RECOMMENDED_ACTION="Review quality gate reports and fix policy violations."
    ;;

  build|docker-build|package)
    FAILURE_TYPE="build_failure"
    RECOMMENDED_ACTION="Check Dockerfile, build context, .dockerignore, and build args."
    ;;

  scan|sbom|provenance|sign|verify-signature)
    FAILURE_TYPE="scan_failure"
    RECOMMENDED_ACTION="Check scan, SBOM, provenance, or signing tool output."
    ;;

  registry|push|pull|login)
    FAILURE_TYPE="registry_failure"
    RECOMMENDED_ACTION="Check registry credentials, image name, tag immutability, and permissions."
    ;;

  deploy)
    FAILURE_TYPE="deployment_failure"
    RECOMMENDED_ACTION="Check deployment command output, target host, compose/kubernetes state."
    ;;

  verify|health|ready|version)
    FAILURE_TYPE="verification_failure"
    RECOMMENDED_ACTION="Check runtime logs, health/readiness/version endpoints, and rollback status."
    ;;
esac

if echo "$TEXT" | grep -Eiq "permission denied|access denied|unauthorized|forbidden"; then
  FAILURE_TYPE="registry_failure"
  RECOMMENDED_ACTION="Check credentials, token scope, IAM policy, and registry/project permissions."
fi

if echo "$TEXT" | grep -Eiq "runner|agent|executor|offline|no runner"; then
  FAILURE_TYPE="pipeline_infra_failure"
  RECOMMENDED_ACTION="Check runner/agent availability, labels, executor capacity, and queue."
fi

OUTPUT_FILE="$REPORT_DIR/failure-classification-$(date +%Y%m%d_%H%M%S).json"

cat > "$OUTPUT_FILE" <<EOF
{
  "stage": "$STAGE",
  "exit_code": "$EXIT_CODE",
  "failure_type": "$FAILURE_TYPE",
  "recommended_action": "$RECOMMENDED_ACTION",
  "log_file": "$LOG_FILE",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$OUTPUT_FILE" | jq .
echo "Failure classification: $OUTPUT_FILE"
```

Make executable:

```bash
chmod +x pipeline-observability/scripts/classify-failure.sh
```

Test:

```bash
STAGE=docker-build EXIT_CODE=1 ./pipeline-observability/scripts/classify-failure.sh
```

---

# 9. Pipeline Summary Script

This combines reports into one final summary.

Create:

```bash
nano pipeline-observability/scripts/create-pipeline-summary.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-pipeline-observability/reports}"
SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"
CI_SYSTEM="${CI_SYSTEM:-local}"
PIPELINE_STATUS="${PIPELINE_STATUS:-unknown}"
ARTIFACT="${ARTIFACT:-}"
TARGET_ENV="${TARGET_ENV:-}"
ROLLBACK_VERSION="${ROLLBACK_VERSION:-}"

mkdir -p "$REPORT_DIR"

OUTPUT_FILE="$REPORT_DIR/pipeline-summary-$(date +%Y%m%d_%H%M%S).json"

LATEST_CONTEXT="$(find "$REPORT_DIR" -type f -name 'pipeline-context-*.json' | sort | tail -n 1 || true)"
LATEST_FAILURE="$(find "$REPORT_DIR" -type f -name 'failure-classification-*.json' | sort | tail -n 1 || true)"
LATEST_DEPLOYMENT="$(find "$REPORT_DIR" -type f -name 'deployment-*.json' | sort | tail -n 1 || true)"
LATEST_QUALITY="$(find "$REPORT_DIR" -type f -name 'quality-gate-summary-*.json' | sort | tail -n 1 || true)"

STAGE_TIMINGS="$(find "$REPORT_DIR" -type f -name 'stage-timing-*.json' | sort || true)"

{
  echo "{"
  echo "  \"service_name\": \"$SERVICE_NAME\","
  echo "  \"ci_system\": \"$CI_SYSTEM\","
  echo "  \"pipeline_status\": \"$PIPELINE_STATUS\","
  echo "  \"artifact\": \"$ARTIFACT\","
  echo "  \"target_environment\": \"$TARGET_ENV\","
  echo "  \"rollback_version\": \"$ROLLBACK_VERSION\","
  echo "  \"pipeline_context_file\": \"$LATEST_CONTEXT\","
  echo "  \"failure_classification_file\": \"$LATEST_FAILURE\","
  echo "  \"deployment_file\": \"$LATEST_DEPLOYMENT\","
  echo "  \"quality_gate_file\": \"$LATEST_QUALITY\","
  echo "  \"stage_timing_files\": ["

  first=1
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    if [ "$first" -eq 0 ]; then
      echo ","
    fi
    printf '    "%s"' "$file"
    first=0
  done <<< "$STAGE_TIMINGS"

  echo
  echo "  ],"
  echo "  \"generated_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\""
  echo "}"
} > "$OUTPUT_FILE"

cat "$OUTPUT_FILE" | jq .
echo "Pipeline summary: $OUTPUT_FILE"
```

Make executable:

```bash
chmod +x pipeline-observability/scripts/create-pipeline-summary.sh
```

Run:

```bash
PIPELINE_STATUS=passed ./pipeline-observability/scripts/create-pipeline-summary.sh
```

---

# 10. Debug Bundle Script

When a pipeline fails, collect safe debug files.

Create:

```bash
nano pipeline-observability/scripts/create-debug-bundle.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
MODULE8_DIR="$ROOT_DIR/08-cicd-pipelines"
REPORT_DIR="${REPORT_DIR:-$MODULE8_DIR/pipeline-observability/reports}"
OUTPUT_DIR="${OUTPUT_DIR:-$MODULE8_DIR/pipeline-observability/reports/debug-bundles}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BUNDLE_DIR="$OUTPUT_DIR/debug-bundle-$TIMESTAMP"
ARCHIVE="$OUTPUT_DIR/debug-bundle-$TIMESTAMP.tar.gz"

mkdir -p "$BUNDLE_DIR"

echo "===== Create Debug Bundle ====="

copy_if_exists() {
  local src="$1"
  local dest="$2"

  if [ -e "$src" ]; then
    mkdir -p "$(dirname "$BUNDLE_DIR/$dest")"
    cp -R "$src" "$BUNDLE_DIR/$dest"
  fi
}

copy_if_exists "$MODULE8_DIR/pipeline-observability/reports" "pipeline-observability-reports"
copy_if_exists "$MODULE8_DIR/quality-gates/reports" "quality-gates-reports"
copy_if_exists "$MODULE8_DIR/deployment-rollback/reports" "deployment-reports"
copy_if_exists "$MODULE8_DIR/../07-artifact-management-registries/release-records" "release-records"
copy_if_exists "$MODULE8_DIR/../07-artifact-management-registries/promotion/records" "promotion-records"

cat > "$BUNDLE_DIR/debug-context.txt" <<EOF
created_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
host=$(hostname)
user=$(whoami)
pwd=$(pwd)
git_commit=$(cd "$ROOT_DIR" && git rev-parse HEAD 2>/dev/null || echo unknown)
git_branch=$(cd "$ROOT_DIR" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
EOF

find "$BUNDLE_DIR" -type f -name "*.env" -delete || true
find "$BUNDLE_DIR" -type f -name ".env" -delete || true
find "$BUNDLE_DIR" -type f -name "*key*" -delete || true
find "$BUNDLE_DIR" -type f -name "*secret*" -delete || true

tar -czf "$ARCHIVE" -C "$OUTPUT_DIR" "$(basename "$BUNDLE_DIR")"

echo "Debug bundle directory: $BUNDLE_DIR"
echo "Debug bundle archive: $ARCHIVE"
```

Make executable:

```bash
chmod +x pipeline-observability/scripts/create-debug-bundle.sh
```

Run:

```bash
./pipeline-observability/scripts/create-debug-bundle.sh
```

Professional rule:

```text
Debug bundles must not include secrets.
```

---

# 11. Flaky Test Tracker

A flaky test passes sometimes and fails sometimes.

Create:

```bash
nano pipeline-observability/scripts/record-test-result.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="${TEST_NAME:-unknown}"
TEST_STATUS="${TEST_STATUS:-unknown}"
REPORT_DIR="${REPORT_DIR:-pipeline-observability/reports/flaky-tests}"
OUTPUT_FILE="$REPORT_DIR/test-history.jsonl"

mkdir -p "$REPORT_DIR"

cat >> "$OUTPUT_FILE" <<EOF
{"test_name":"$TEST_NAME","status":"$TEST_STATUS","commit":"$(git rev-parse --short HEAD 2>/dev/null || echo unknown)","created_at":"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"}
EOF

tail -n 5 "$OUTPUT_FILE"
```

Make executable:

```bash
chmod +x pipeline-observability/scripts/record-test-result.sh
```

Create analyzer:

```bash
nano pipeline-observability/scripts/flaky-test-summary.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

HISTORY_FILE="${HISTORY_FILE:-pipeline-observability/reports/flaky-tests/test-history.jsonl}"

if [ ! -f "$HISTORY_FILE" ]; then
  echo "No test history found."
  exit 0
fi

echo "===== Flaky Test Summary ====="

jq -r '.test_name' "$HISTORY_FILE" | sort -u | while read -r test; do
  total="$(jq --arg t "$test" 'select(.test_name == $t) | .status' "$HISTORY_FILE" | wc -l | tr -d ' ')"
  failed="$(jq --arg t "$test" 'select(.test_name == $t and .status == "failed")' "$HISTORY_FILE" | wc -l | tr -d ' ')"
  passed="$(jq --arg t "$test" 'select(.test_name == $t and .status == "passed")' "$HISTORY_FILE" | wc -l | tr -d ' ')"

  echo "$test total=$total passed=$passed failed=$failed"

  if [ "$passed" -gt 0 ] && [ "$failed" -gt 0 ]; then
    echo "  POSSIBLE FLAKY TEST: $test"
  fi
done
```

Make executable:

```bash
chmod +x pipeline-observability/scripts/flaky-test-summary.sh
```

Test:

```bash
TEST_NAME="TodoList renders" TEST_STATUS=passed ./pipeline-observability/scripts/record-test-result.sh
TEST_NAME="TodoList renders" TEST_STATUS=failed ./pipeline-observability/scripts/record-test-result.sh
./pipeline-observability/scripts/flaky-test-summary.sh
```

---

# 12. GitHub Actions Observability Workflow

GitHub workflow commands can create notices, warnings, errors, grouped logs, masks, outputs, and job summaries; writing Markdown to `$GITHUB_STEP_SUMMARY` adds content to the job summary. ([GitHub Docs][1])

Create:

```bash
nano pipeline-observability/github-actions/pipeline-observability.yml
```

Paste:

```yaml
name: Pipeline Observability

on:
  workflow_dispatch:
  push:
    branches:
      - main
  pull_request:

permissions:
  contents: read

env:
  MODULE8_DIR: 08-cicd-pipelines
  APP_DIR: 05-application-runtime/demo-node-api
  NODE_VERSION: "22"

jobs:
  observed-ci:
    runs-on: ubuntu-latest

    steps:
      - name: Start checkout group
        run: echo "::group::Checkout and context"

      - uses: actions/checkout@v4

      - name: Create pipeline context
        run: |
          cd "$MODULE8_DIR"
          CI_SYSTEM="github-actions" \
          PIPELINE_NAME="${{ github.workflow }}" \
          PIPELINE_RUN_ID="${{ github.run_id }}" \
          JOB_NAME="observed-ci" \
          BUILD_URL="https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}" \
          REPOSITORY="${{ github.repository }}" \
          BRANCH="${{ github.ref_name }}" \
          COMMIT_SHA="${{ github.sha }}" \
          SHORT_SHA="${GITHUB_SHA::7}" \
          TRIGGERED_BY="${{ github.actor }}" \
          ./pipeline-observability/scripts/create-pipeline-context.sh

      - name: End checkout group
        run: echo "::endgroup::"

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm
          cache-dependency-path: ${{ env.APP_DIR }}/package-lock.json

      - name: Install dependencies with timing
        run: |
          cd "$MODULE8_DIR"
          ./pipeline-observability/scripts/stage-timer.sh start install

          cd "$GITHUB_WORKSPACE/$APP_DIR"
          npm ci

          cd "$GITHUB_WORKSPACE/$MODULE8_DIR"
          ./pipeline-observability/scripts/stage-timer.sh end install

      - name: Run tests with timing
        run: |
          cd "$MODULE8_DIR"
          ./pipeline-observability/scripts/stage-timer.sh start test

          cd "$GITHUB_WORKSPACE/$APP_DIR"
          npm test

          cd "$GITHUB_WORKSPACE/$MODULE8_DIR"
          ./pipeline-observability/scripts/stage-timer.sh end test

      - name: Create pipeline summary file
        if: always()
        run: |
          cd "$MODULE8_DIR"
          PIPELINE_STATUS="${{ job.status }}" \
          CI_SYSTEM="github-actions" \
          ./pipeline-observability/scripts/create-pipeline-summary.sh

      - name: Write GitHub job summary
        if: always()
        run: |
          {
            echo "## Pipeline Observability Summary"
            echo ""
            echo "- CI system: GitHub Actions"
            echo "- Workflow: ${{ github.workflow }}"
            echo "- Run ID: ${{ github.run_id }}"
            echo "- Actor: ${{ github.actor }}"
            echo "- Ref: ${{ github.ref_name }}"
            echo "- Commit: \`${{ github.sha }}\`"
            echo "- Status: \`${{ job.status }}\`"
            echo ""
            echo "### Report files"
            echo ""
            find "$MODULE8_DIR/pipeline-observability/reports" -type f | sort | sed 's#^#- #'
          } >> "$GITHUB_STEP_SUMMARY"

      - name: Upload observability reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: pipeline-observability-reports
          path: 08-cicd-pipelines/pipeline-observability/reports/
```

Copy:

```bash
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 08-cicd-pipelines/pipeline-observability/github-actions/pipeline-observability.yml \
   .github/workflows/pipeline-observability.yml
```

---

# 13. Jenkins Observability Pipeline

Jenkins supports archiving generated files with `archiveArtifacts`; Jenkins also supports publishing test results through the JUnit plugin when test reports are generated in JUnit XML format. ([Jenkins][2])

Create:

```bash
cd ~/devops-masterclass/08-cicd-pipelines

nano pipeline-observability/jenkins/Jenkinsfile.pipeline-observability
```

Paste:

```groovy
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
  }

  environment {
    MODULE8_DIR = '08-cicd-pipelines'
    APP_DIR = '05-application-runtime/demo-node-api'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm

        dir("${MODULE8_DIR}") {
          sh '''
            CI_SYSTEM="jenkins" \
            PIPELINE_NAME="${JOB_NAME}" \
            PIPELINE_RUN_ID="${BUILD_NUMBER}" \
            JOB_NAME="${JOB_NAME}" \
            BUILD_URL="${BUILD_URL}" \
            BRANCH="${BRANCH_NAME:-unknown}" \
            COMMIT_SHA="$(git rev-parse HEAD)" \
            SHORT_SHA="$(git rev-parse --short HEAD)" \
            TRIGGERED_BY="${BUILD_USER_ID:-jenkins}" \
            ./pipeline-observability/scripts/create-pipeline-context.sh
          '''
        }
      }
    }

    stage('Install Dependencies') {
      steps {
        dir("${MODULE8_DIR}") {
          sh './pipeline-observability/scripts/stage-timer.sh start install'
        }

        dir("${APP_DIR}") {
          sh 'npm ci'
        }

        dir("${MODULE8_DIR}") {
          sh './pipeline-observability/scripts/stage-timer.sh end install'
        }
      }
    }

    stage('Test') {
      steps {
        dir("${MODULE8_DIR}") {
          sh './pipeline-observability/scripts/stage-timer.sh start test'
        }

        dir("${APP_DIR}") {
          sh 'npm test'
        }

        dir("${MODULE8_DIR}") {
          sh './pipeline-observability/scripts/stage-timer.sh end test'
        }
      }
    }

    stage('Summary') {
      steps {
        dir("${MODULE8_DIR}") {
          sh '''
            PIPELINE_STATUS="running_or_passed" \
            CI_SYSTEM="jenkins" \
            ./pipeline-observability/scripts/create-pipeline-summary.sh
          '''
        }
      }
    }
  }

  post {
    failure {
      dir("${MODULE8_DIR}") {
        sh '''
          STAGE="unknown" \
          EXIT_CODE="1" \
          ./pipeline-observability/scripts/classify-failure.sh || true

          ./pipeline-observability/scripts/create-debug-bundle.sh || true
        '''
      }
    }

    always {
      archiveArtifacts artifacts: '''
        08-cicd-pipelines/pipeline-observability/reports/**/*,
        08-cicd-pipelines/quality-gates/reports/**/*,
        08-cicd-pipelines/deployment-rollback/reports/**/*
      ''', allowEmptyArchive: true
    }

    success {
      echo 'Observed Jenkins pipeline succeeded.'
    }

    failure {
      echo 'Observed Jenkins pipeline failed. Check archived observability reports.'
    }
  }
}
```

---

# 14. GitLab CI Observability Pipeline

GitLab job artifacts can preserve generated files, and by default later jobs fetch artifacts from earlier stages unless dependencies/needs are used to control artifact download behavior. GitLab artifact reports can also be used for test, code quality, security, and other structured outputs in pipeline/MR views. ([GitLab Docs][3])

Create:

```bash
nano pipeline-observability/gitlab/.gitlab-ci.pipeline-observability.yml
```

Paste:

```yaml
stages:
  - context
  - test
  - summarize

variables:
  MODULE8_DIR: "08-cicd-pipelines"
  APP_DIR: "05-application-runtime/demo-node-api"

pipeline_context:
  stage: context
  image: alpine:3.20
  before_script:
    - apk add --no-cache bash git jq
  script:
    - cd "$MODULE8_DIR"
    - |
      CI_SYSTEM="gitlab-ci" \
      PIPELINE_NAME="$CI_PROJECT_PATH" \
      PIPELINE_RUN_ID="$CI_PIPELINE_ID" \
      JOB_NAME="$CI_JOB_NAME" \
      BUILD_URL="$CI_PIPELINE_URL" \
      REPOSITORY="$CI_PROJECT_PATH" \
      BRANCH="${CI_COMMIT_REF_NAME:-unknown}" \
      COMMIT_SHA="$CI_COMMIT_SHA" \
      SHORT_SHA="$CI_COMMIT_SHORT_SHA" \
      TRIGGERED_BY="$GITLAB_USER_LOGIN" \
      ./pipeline-observability/scripts/create-pipeline-context.sh
  artifacts:
    when: always
    expire_in: 14 days
    paths:
      - 08-cicd-pipelines/pipeline-observability/reports/

observed_tests:
  stage: test
  image: node:22-alpine
  needs:
    - job: pipeline_context
      artifacts: true
  script:
    - cd "$MODULE8_DIR"
    - ./pipeline-observability/scripts/stage-timer.sh start install
    - cd "$CI_PROJECT_DIR/$APP_DIR"
    - npm ci
    - cd "$CI_PROJECT_DIR/$MODULE8_DIR"
    - ./pipeline-observability/scripts/stage-timer.sh end install
    - ./pipeline-observability/scripts/stage-timer.sh start test
    - cd "$CI_PROJECT_DIR/$APP_DIR"
    - npm test
    - cd "$CI_PROJECT_DIR/$MODULE8_DIR"
    - ./pipeline-observability/scripts/stage-timer.sh end test
  artifacts:
    when: always
    expire_in: 14 days
    paths:
      - 08-cicd-pipelines/pipeline-observability/reports/

pipeline_summary:
  stage: summarize
  image: alpine:3.20
  needs:
    - job: observed_tests
      artifacts: true
  before_script:
    - apk add --no-cache bash jq git
  script:
    - cd "$MODULE8_DIR"
    - |
      PIPELINE_STATUS="passed_or_running" \
      CI_SYSTEM="gitlab-ci" \
      ./pipeline-observability/scripts/create-pipeline-summary.sh
    - find pipeline-observability/reports -type f | sort
  artifacts:
    when: always
    expire_in: 30 days
    paths:
      - 08-cicd-pipelines/pipeline-observability/reports/
```

---

# 15. Notification Message Builder

We will create a generic notification payload. You can send it later to Slack, email, Teams, or PagerDuty.

Create:

```bash
nano pipeline-observability/scripts/create-notification-message.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"
CI_SYSTEM="${CI_SYSTEM:-local}"
PIPELINE_STATUS="${PIPELINE_STATUS:-unknown}"
FAILURE_TYPE="${FAILURE_TYPE:-}"
ARTIFACT="${ARTIFACT:-}"
TARGET_ENV="${TARGET_ENV:-}"
BUILD_URL_VALUE="${BUILD_URL:-}"
REPORT_DIR="${REPORT_DIR:-pipeline-observability/reports}"

mkdir -p "$REPORT_DIR"

OUTPUT_FILE="$REPORT_DIR/notification-message-$(date +%Y%m%d_%H%M%S).json"

SEVERITY="info"

case "$PIPELINE_STATUS" in
  failed)
    SEVERITY="warning"
    ;;
  production_failed|rollback_triggered)
    SEVERITY="critical"
    ;;
  passed|success)
    SEVERITY="info"
    ;;
esac

cat > "$OUTPUT_FILE" <<EOF
{
  "service_name": "$SERVICE_NAME",
  "ci_system": "$CI_SYSTEM",
  "pipeline_status": "$PIPELINE_STATUS",
  "severity": "$SEVERITY",
  "failure_type": "$FAILURE_TYPE",
  "artifact": "$ARTIFACT",
  "target_environment": "$TARGET_ENV",
  "build_url": "$BUILD_URL_VALUE",
  "message": "Pipeline status for $SERVICE_NAME is $PIPELINE_STATUS",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$OUTPUT_FILE" | jq .
echo "Notification message: $OUTPUT_FILE"
```

Make executable:

```bash
chmod +x pipeline-observability/scripts/create-notification-message.sh
```

Run:

```bash
PIPELINE_STATUS=failed FAILURE_TYPE=test_failure ./pipeline-observability/scripts/create-notification-message.sh
```

---

# 16. Slack Notification Pattern

Do not hardcode webhook URLs.

GitHub Actions example:

```yaml
- name: Send Slack notification
  if: failure()
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
  run: |
    payload="$(cat 08-cicd-pipelines/pipeline-observability/reports/notification-message-*.json | tail -n 1)"
    curl -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"Pipeline failed. Check run: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}\"}" \
      "$SLACK_WEBHOOK_URL"
```

Jenkins example:

```groovy
withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK_URL')]) {
  sh '''
    curl -X POST -H 'Content-type: application/json' \
      --data '{"text":"Jenkins pipeline failed. Check archived reports."}' \
      "$SLACK_WEBHOOK_URL"
  '''
}
```

GitLab example:

```yaml
notify_failure:
  image: alpine:3.20
  when: on_failure
  script:
    - apk add --no-cache curl
    - |
      curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"GitLab pipeline failed: $CI_PIPELINE_URL\"}" \
        "$SLACK_WEBHOOK_URL"
```

Professional rule:

```text
Notifications should tell the responder what failed, where to look, and whether rollback happened.
```

---

# 17. CI/CD Dashboard Data Model

Create:

```bash
nano pipeline-observability/examples/pipeline-dashboard-record.json
```

Paste:

```json
{
  "service_name": "demo-node-api",
  "ci_system": "github-actions",
  "pipeline_name": "production-pipeline",
  "run_id": "123456789",
  "status": "passed",
  "branch": "main",
  "commit_sha": "a1b2c3d",
  "artifact": "ghcr.io/user/demo-node-api:0.8.0-dev-a1b2c3d",
  "target_environment": "staging",
  "rollback_version": "0.7.0-f9e8d7c",
  "stage_durations": {
    "install": 12,
    "test": 8,
    "build": 42,
    "scan": 55,
    "deploy": 20,
    "verify": 9
  },
  "failure_type": null,
  "quality_gate_status": "passed",
  "deployment_status": "success",
  "created_at": "2026-07-12T00:00:00Z"
}
```

Dashboard ideas:

```text
success rate
failure rate by type
average duration by stage
slowest pipelines
flaky tests
deployment frequency
rollback frequency
mean time to recover
top failure causes
```

---

# 18. Pipeline Incident Runbook

Create:

```bash
nano pipeline-observability/runbooks/pipeline-incident-runbook.md
```

Paste:

```markdown
# Pipeline Incident Runbook

## Goal

Quickly classify, debug, and recover from CI/CD pipeline failures.

## Step 1 — Identify Failure Type

Check:

- failed stage
- exit code
- logs
- archived reports
- failure classification file

Failure categories:

- source failure
- dependency failure
- test failure
- quality gate failure
- build failure
- scan failure
- registry failure
- deployment failure
- verification failure
- environment failure
- pipeline infrastructure failure

## Step 2 — Check Blast Radius

Ask:

- Is this only a pull request?
- Is main blocked?
- Is production deployment blocked?
- Did a bad artifact reach staging?
- Did a bad artifact reach production?
- Was rollback triggered?

## Step 3 — Recover

For test/build/scan failures:

- fix code or dependency
- rerun pipeline

For registry failures:

- check credentials
- check tag immutability
- check registry status

For deployment failures:

- check deployment report
- check runtime logs
- rollback if production impacted

For verification failures:

- check `/health`
- check `/ready`
- check `/version`
- compare expected artifact vs running artifact

## Step 4 — Preserve Evidence

Archive:

- pipeline context
- stage timings
- failure classification
- quality gate reports
- scan reports
- deployment reports
- rollback records

## Step 5 — Post-Incident

Create follow-up:

- root cause
- detection gap
- prevention action
- runbook update
- test coverage update
- alerting update
```

---

# 19. Pipeline Debugging Checklist

Create:

```bash
nano pipeline-observability/runbooks/pipeline-debugging-checklist.md
```

Paste:

```markdown
# Pipeline Debugging Checklist

## Basic Context

- [ ] Which CI system failed?
- [ ] Which workflow/job failed?
- [ ] Which stage failed?
- [ ] Which commit?
- [ ] Which branch/tag?
- [ ] Which artifact?
- [ ] Which environment?

## Failure Class

- [ ] source failure
- [ ] dependency failure
- [ ] test failure
- [ ] quality gate failure
- [ ] build failure
- [ ] scan failure
- [ ] registry failure
- [ ] deployment failure
- [ ] verification failure
- [ ] environment failure
- [ ] pipeline infrastructure failure

## Evidence

- [ ] logs reviewed
- [ ] reports archived
- [ ] stage timing reviewed
- [ ] deployment record reviewed
- [ ] rollback record reviewed
- [ ] debug bundle created

## Recovery

- [ ] rerun safe?
- [ ] rollback needed?
- [ ] credentials valid?
- [ ] runner/agent healthy?
- [ ] production impacted?
- [ ] incident needed?
```

---

# 20. Observability Notes

Create:

```bash
nano pipeline-observability/notes/pipeline-observability.md
```

Paste:

```markdown
# Pipeline Observability

## Definition

Pipeline observability is the ability to understand the state, progress, failure reason, artifact identity, and deployment impact of CI/CD workflows.

## Key Signals

- logs
- stage duration
- exit codes
- reports
- artifacts
- summaries
- notifications
- deployment records
- rollback records

## Golden Rule

A pipeline should produce structured evidence that explains what happened.

## What Good Looks Like

For every important pipeline run, you should know:

- source commit
- actor
- artifact built
- quality gates
- scan results
- deployment environment
- runtime verification result
- rollback version
- failure type if failed
```

---

# 21. Validation Script

Create:

```bash
nano pipeline-observability/scripts/validate-pipeline-observability-lesson.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-pipeline-observability}"

echo "===== Validate Pipeline Observability Lesson ====="

test -f "$BASE_DIR/policies/pipeline-observability-policy.json"
test -x "$BASE_DIR/scripts/create-pipeline-context.sh"
test -x "$BASE_DIR/scripts/stage-timer.sh"
test -x "$BASE_DIR/scripts/classify-failure.sh"
test -x "$BASE_DIR/scripts/create-pipeline-summary.sh"
test -x "$BASE_DIR/scripts/create-debug-bundle.sh"
test -x "$BASE_DIR/scripts/record-test-result.sh"
test -x "$BASE_DIR/scripts/flaky-test-summary.sh"
test -x "$BASE_DIR/scripts/create-notification-message.sh"
test -f "$BASE_DIR/github-actions/pipeline-observability.yml"
test -f "$BASE_DIR/jenkins/Jenkinsfile.pipeline-observability"
test -f "$BASE_DIR/gitlab/.gitlab-ci.pipeline-observability.yml"
test -f "$BASE_DIR/runbooks/pipeline-incident-runbook.md"
test -f "$BASE_DIR/runbooks/pipeline-debugging-checklist.md"
test -f "$BASE_DIR/notes/pipeline-observability.md"

echo "Pipeline observability lesson files validated."
```

Make executable:

```bash
chmod +x pipeline-observability/scripts/validate-pipeline-observability-lesson.sh
```

Run:

```bash
./pipeline-observability/scripts/validate-pipeline-observability-lesson.sh
```

---

# 22. Update Makefile

Open:

```bash
cd ~/devops-masterclass/08-cicd-pipelines

nano Makefile
```

Add:

```Makefile
.PHONY: validate-observability pipeline-context pipeline-summary debug-bundle flaky-summary notification-message

validate-observability:
	./pipeline-observability/scripts/validate-pipeline-observability-lesson.sh

pipeline-context:
	./pipeline-observability/scripts/create-pipeline-context.sh

pipeline-summary:
	PIPELINE_STATUS="$${PIPELINE_STATUS:-passed}" ./pipeline-observability/scripts/create-pipeline-summary.sh

debug-bundle:
	./pipeline-observability/scripts/create-debug-bundle.sh

flaky-summary:
	./pipeline-observability/scripts/flaky-test-summary.sh

notification-message:
	PIPELINE_STATUS="$${PIPELINE_STATUS:-failed}" ./pipeline-observability/scripts/create-notification-message.sh
```

Run:

```bash
make validate-observability
make pipeline-context
make pipeline-summary
make notification-message
```

---

# 23. Practical Lab

Run:

```bash
cd ~/devops-masterclass/08-cicd-pipelines

make validate-observability
make pipeline-context

./pipeline-observability/scripts/stage-timer.sh start demo-stage
sleep 1
./pipeline-observability/scripts/stage-timer.sh end demo-stage

STAGE=test EXIT_CODE=1 ./pipeline-observability/scripts/classify-failure.sh

PIPELINE_STATUS=failed ./pipeline-observability/scripts/create-pipeline-summary.sh

make debug-bundle
```

Copy GitHub workflow:

```bash
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 08-cicd-pipelines/pipeline-observability/github-actions/pipeline-observability.yml \
   .github/workflows/pipeline-observability.yml
```

Commit:

```bash
git status

git add .github/workflows/pipeline-observability.yml \
        08-cicd-pipelines/pipeline-observability

git commit -m "feat: add pipeline observability and debugging workflows"
git push
```

---

# 24. What Good Pipeline Logs Look Like

Good logs:

```text
clear stage names
safe context
grouped logs
tool versions
artifact names
report paths
failure reason
next action
```

Bad logs:

```text
huge env dump
secret values
no stage boundaries
no artifact identity
no report location
no failure classification
```

Professional rule:

```text
Logs should help you debug without leaking secrets.
```

---

# 25. Debugging Production Deployment Failure

When production deployment fails:

```text
1. Identify expected artifact.
2. Check deployment record.
3. Check runtime verification report.
4. Check smoke test report.
5. Check container logs.
6. Compare /version with expected version.
7. Check if rollback triggered.
8. Confirm rollback version is healthy.
9. Notify incident channel.
10. Open post-incident follow-up.
```

Do not start with random commands.

Start with:

```bash
cat deployment-rollback/reports/deployment-*.json | jq .
cat deployment-rollback/reports/runtime-verification-*.json | jq .
cat deployment-rollback/reports/smoke-test-*.json | jq .
```

---

# 26. Interview Explanation

## What is pipeline observability?

Strong answer:

```text
Pipeline observability is the ability to understand what happened in a CI/CD run, including source commit, stage results, durations, artifacts, failures, deployment status, rollback information, and archived evidence.
```

## What reports should a production pipeline generate?

Strong answer:

```text
A production pipeline should generate pipeline context, stage timing, quality gate summary, test reports, scan reports, SBOM, provenance, release metadata, deployment records, runtime verification reports, smoke test reports, and failure classification when something fails.
```

## How do you debug a failed pipeline?

Strong answer:

```text
I first classify the failure by stage and type: dependency, test, build, scan, registry, deployment, verification, environment, or runner issue. Then I inspect archived reports and logs, reproduce locally if applicable, and decide whether to rerun, fix forward, or rollback.
```

## Why archive artifacts?

Strong answer:

```text
Archived artifacts preserve structured evidence after the job finishes. Logs alone are not enough because reports, scan output, SBOMs, deployment records, and debug bundles are needed for audit, debugging, incident response, and rollback analysis.
```

## What is a flaky test?

Strong answer:

```text
A flaky test sometimes passes and sometimes fails without a relevant code change. Flaky tests reduce trust in CI/CD, so they should be tracked, isolated, fixed, or quarantined with clear ownership.
```

## What should a pipeline notification contain?

Strong answer:

```text
A useful pipeline notification should include service name, status, failure type, failed stage, branch, commit, artifact, target environment, rollback status, build URL, and the recommended next action.
```

---

# 27. Today’s Core Rules

```text
CI/CD pipelines need observability.
A failed pipeline must explain why it failed.
Classify failures before fixing.
Archive structured reports.
Measure stage durations.
Track flaky tests.
Create debug bundles without secrets.
Use job summaries for human-readable output.
Use artifacts for machine-readable evidence.
Deployment reports must include artifact and rollback version.
Notifications must include next action.
Logs should help debug without leaking secrets.
```

---

# Next Lesson

# Lesson 8.12 — CI/CD Capstone Project

We will combine the full Module 8 pipeline:

```text
GitHub Actions
Jenkins
GitLab CI
secrets and OIDC
quality gates
artifact build
registry push
SBOM/provenance/signing
deployment pipeline
rollback pipeline
observability reports
debug bundles
production runbook
final portfolio summary
module tag v0.8.0
```

[1]: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands?utm_source=chatgpt.com "Workflow commands for GitHub Actions"
[2]: https://www.jenkins.io/doc/pipeline/tour/tests-and-artifacts/?utm_source=chatgpt.com "Recording tests and artifacts"
[3]: https://docs.gitlab.com/ci/jobs/job_artifacts/?utm_source=chatgpt.com "Job artifacts"

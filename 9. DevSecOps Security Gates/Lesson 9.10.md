# Lesson 9.10 — DAST and Runtime Security Smoke Tests

# OWASP ZAP Baseline Scan, Runtime Security Headers, HTTP Method Checks, Health Endpoint Exposure, API Security Smoke Tests, GitHub Actions, Jenkins, GitLab CI, and Production-Safe DAST Gates

In Lesson 9.9, we added **Policy as Code** with OPA and Conftest.

Now we test the application while it is running.

```text id="6vc2xa"
DAST = Dynamic Application Security Testing
```

SAST scans source code.

SCA scans dependencies.

Container scanning scans images.

IaC scanning scans infrastructure definitions.

DAST scans a **running application**.

```text id="0qyvr3"
running app
  ↓
HTTP requests
  ↓
security behavior checked from outside
```

OWASP ZAP provides Docker-based scan scripts for automation. The ZAP Baseline Scan runs a spider against a target for a short time, waits for passive scanning to complete, and reports findings without performing active attacks. ZAP’s Docker docs also distinguish baseline, full, and API scans. ([zaproxy.org](https://www.zaproxy.org/docs/docker/baseline-scan/?utm_source=chatgpt.com))

---

# 1. DAST Mental Model

DAST asks:

```text id="4ufrwm"
When the app is actually running, does it behave securely over HTTP?
```

Examples:

```text id="ljmhtg"
Are security headers present?
Does HTTP redirect to HTTPS?
Are unsafe HTTP methods blocked?
Are error responses leaking internals?
Are sensitive endpoints exposed?
Is the API returning unsafe headers?
Are cookies configured securely?
Does passive scan detect weak behavior?
```

Professional rule:

```text id="n4c3cn"
DAST validates runtime behavior, not source intent.
```

---

# 2. DAST vs SAST

```text id="b6qz2u"
SAST:
  sees code
  runs before app starts
  catches risky patterns

DAST:
  sees running app
  sends HTTP requests
  catches runtime behavior
```

Example:

```text id="i0dhrq"
SAST might flag:
  res.send(req.query.q)

DAST might detect:
  missing X-Content-Type-Options
  missing Content-Security-Policy
  reflected input behavior
  server banner exposure
```

You need both.

---

# 3. ZAP Baseline vs Full Scan vs API Scan

Use scans safely.

```text id="r82tb4"
ZAP Baseline Scan:
  passive scan
  safe for CI/staging
  no active attacks by default

ZAP Full Scan:
  active scan
  can attack endpoints
  use only in approved test environments

ZAP API Scan:
  scans APIs from OpenAPI/SOAP/GraphQL definitions
  can run active API-oriented scanning
```

ZAP’s Docker documentation states that the full scan performs active attacks and can run for a long time, while the baseline scan is short and passive. The API scan is tuned for APIs defined by OpenAPI, SOAP, or GraphQL. ([zaproxy.org](https://www.zaproxy.org/docs/docker/full-scan/?utm_source=chatgpt.com))

Production rule:

```text id="bsx1r9"
Do not run aggressive active DAST scans against production unless explicitly approved.
```

---

# 4. What We Will Build

In this lesson, you will create:

```text id="g19zvb"
DAST notes
runtime security policy
OWASP ZAP baseline scan wrapper
runtime header check script
HTTP method check script
health/version exposure check
API smoke security checks
combined DAST gate
GitHub Actions workflow
Jenkins pipeline
GitLab CI pipeline
DAST runbooks
Makefile targets
```

---

# 5. Create Lesson Directory

Run:

```bash id="8w39k0"
cd ~/devops-masterclass/09-devsecops-security-gates

mkdir -p dast-runtime-security/{zap,scripts,reports,github-actions,jenkins,gitlab,runbooks,examples,notes,policies}
```

Check:

```bash id="sqgo8j"
tree -L 2 dast-runtime-security
```

Expected:

```text id="116jyp"
dast-runtime-security
├── examples
├── github-actions
├── gitlab
├── jenkins
├── notes
├── policies
├── reports
├── runbooks
├── scripts
└── zap
```

---

# 6. Runtime Security Policy

Create:

```bash id="01lrlc"
nano dast-runtime-security/policies/runtime-security-policy.json
```

Paste:

```json id="ei1m1i"
{
  "service_name": "demo-node-api",
  "policy_version": "1.0",
  "tools": ["owasp zap baseline", "custom runtime checks"],
  "environments": {
    "pull_request": {
      "zap_baseline": "warn",
      "security_headers": "warn",
      "unsafe_methods": "fail",
      "health_exposure": "report"
    },
    "main": {
      "zap_baseline": "warn",
      "security_headers": "warn",
      "unsafe_methods": "fail",
      "health_exposure": "warn"
    },
    "production": {
      "zap_baseline": "report_only_unless_approved",
      "security_headers": "fail",
      "unsafe_methods": "fail",
      "health_exposure": "warn",
      "active_scan": "disabled_by_default"
    }
  },
  "required_headers": [
    "x-content-type-options",
    "x-frame-options",
    "referrer-policy"
  ],
  "recommended_headers": [
    "content-security-policy",
    "strict-transport-security",
    "permissions-policy"
  ],
  "forbidden_methods": [
    "TRACE"
  ],
  "sensitive_paths": [
    "/debug",
    "/metrics",
    "/admin",
    "/.env",
    "/server-status"
  ],
  "exception_policy": {
    "allowed": true,
    "requires_owner": true,
    "requires_reason": true,
    "requires_expiry": true,
    "requires_security_review": true,
    "max_days": 30
  }
}
```

---

# 7. DAST Notes

Create:

```bash id="2ca9z0"
nano dast-runtime-security/notes/dast-runtime-security-mental-model.md
```

Paste:

```markdown id="3i3mdc"
# DAST and Runtime Security Mental Model

## Definition

DAST means Dynamic Application Security Testing.

It tests a running application from the outside using HTTP requests.

## What It Finds

- missing security headers
- insecure HTTP methods
- weak cookie attributes
- information leakage
- exposed sensitive paths
- server banner exposure
- runtime-only misconfiguration

## Tools

| Tool | Purpose |
|---|---|
| OWASP ZAP Baseline | passive DAST scan |
| curl/custom scripts | deterministic runtime smoke checks |
| OWASP ZAP API Scan | API-focused scan using OpenAPI/SOAP/GraphQL definitions |

## Safe Rule

Use passive baseline scans in CI/staging.
Use active scans only against approved test environments.

## Production Rule

Production DAST should usually be passive/report-only unless approved.
Do not run destructive or aggressive scans against production.
```

---

# 8. Prepare Local App Target

For local testing, run your Module 5 app.

```bash id="z0ni3u"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

npm ci

PORT=3002 \
NODE_ENV=production \
APP_VERSION=0.9.0-dev-local \
node server.js
```

In a second terminal:

```bash id="n5n6o4"
curl -i http://127.0.0.1:3002/health
curl -i http://127.0.0.1:3002/version
```

If your app uses a different entry file, use your existing app start command:

```bash id="pfx29d"
npm start
```

Target URL for this lesson:

```text id="iu77xs"
http://127.0.0.1:3002
```

---

# 9. OWASP ZAP Baseline Local Scan

ZAP Docker images include packaged scan scripts, including the baseline scan. The baseline scan runs a spider against the target for a short default period and performs passive scanning. ([zaproxy.org](https://www.zaproxy.org/docs/docker/about/?utm_source=chatgpt.com))

Run:

```bash id="87gj2y"
cd ~/devops-masterclass/09-devsecops-security-gates

docker run --rm \
  --network host \
  -v "$PWD/dast-runtime-security/reports:/zap/wrk/:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py \
  -t http://127.0.0.1:3002 \
  -J zap-baseline-local.json \
  -r zap-baseline-local.html \
  -w zap-baseline-local.md || true
```

Notes:

```text id="yz0kr7"
--network host works on Linux.
On Docker Desktop, use host.docker.internal instead of 127.0.0.1.
```

Docker Desktop style:

```bash id="5v6r0n"
docker run --rm \
  -v "$PWD/dast-runtime-security/reports:/zap/wrk/:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py \
  -t http://host.docker.internal:3002 \
  -J zap-baseline-local.json \
  -r zap-baseline-local.html \
  -w zap-baseline-local.md || true
```

---

# 10. ZAP Rules File

Create:

```bash id="siijoh"
nano dast-runtime-security/zap/zap-baseline-rules.tsv
```

Paste:

```text id="4c6z06"
# ZAP baseline rule configuration
# Format: rule_id<TAB>action
# Actions: WARN, IGNORE, FAIL
# Keep this file reviewed. Do not ignore findings without reason.

10020	WARN
10021	WARN
10035	WARN
10036	WARN
10038	WARN
10049	WARN
10054	WARN
10096	WARN
```

Professional rule:

```text id="l7uro2"
Do not set findings to IGNORE unless you have a documented exception.
```

---

# 11. ZAP Baseline Gate Script

Create:

```bash id="m1ycxw"
nano dast-runtime-security/scripts/zap-baseline-gate.sh
```

Paste:

```bash id="s6yt4k"
#!/usr/bin/env bash
set -euo pipefail

TARGET_URL="${TARGET_URL:-http://127.0.0.1:3002}"
MODULE_DIR="${MODULE_DIR:-$HOME/devops-masterclass/09-devsecops-security-gates}"
REPORT_DIR="${REPORT_DIR:-$MODULE_DIR/dast-runtime-security/reports}"
RULES_FILE="${RULES_FILE:-$MODULE_DIR/dast-runtime-security/zap/zap-baseline-rules.tsv}"

ENVIRONMENT="${ENVIRONMENT:-pull_request}"
FAIL_ON_ZAP="${FAIL_ON_ZAP:-false}"
ZAP_IMAGE="${ZAP_IMAGE:-ghcr.io/zaproxy/zaproxy:stable}"
USE_HOST_NETWORK="${USE_HOST_NETWORK:-true}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
JSON_REPORT="zap-baseline-$ENVIRONMENT-$TIMESTAMP.json"
HTML_REPORT="zap-baseline-$ENVIRONMENT-$TIMESTAMP.html"
MD_REPORT="zap-baseline-$ENVIRONMENT-$TIMESTAMP.md"
SUMMARY_FILE="$REPORT_DIR/zap-baseline-summary-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== OWASP ZAP Baseline Gate ====="
echo "Target URL: $TARGET_URL"
echo "Environment: $ENVIRONMENT"
echo "Fail on ZAP: $FAIL_ON_ZAP"
echo "ZAP image: $ZAP_IMAGE"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is required for ZAP baseline scan" >&2
  exit 1
fi

DOCKER_ARGS=(docker run --rm)

if [ "$USE_HOST_NETWORK" = "true" ]; then
  DOCKER_ARGS+=(--network host)
fi

DOCKER_ARGS+=(
  -v "$REPORT_DIR:/zap/wrk/:rw"
  "$ZAP_IMAGE"
  zap-baseline.py
  -t "$TARGET_URL"
  -J "$JSON_REPORT"
  -r "$HTML_REPORT"
  -w "$MD_REPORT"
)

if [ -f "$RULES_FILE" ]; then
  cp "$RULES_FILE" "$REPORT_DIR/zap-baseline-rules-$TIMESTAMP.tsv"
  DOCKER_ARGS+=(-c "zap-baseline-rules-$TIMESTAMP.tsv")
fi

set +e
"${DOCKER_ARGS[@]}"
ZAP_EXIT=$?
set -e

FULL_JSON="$REPORT_DIR/$JSON_REPORT"
FULL_HTML="$REPORT_DIR/$HTML_REPORT"
FULL_MD="$REPORT_DIR/$MD_REPORT"

ALERT_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0
INFO_COUNT=0

if [ -f "$FULL_JSON" ]; then
  ALERT_COUNT="$(jq '[.site[]?.alerts[]?] | length' "$FULL_JSON" 2>/dev/null || echo 0)"
  HIGH_COUNT="$(jq '[.site[]?.alerts[]? | select((.riskdesc // "") | test("High"))] | length' "$FULL_JSON" 2>/dev/null || echo 0)"
  MEDIUM_COUNT="$(jq '[.site[]?.alerts[]? | select((.riskdesc // "") | test("Medium"))] | length' "$FULL_JSON" 2>/dev/null || echo 0)"
  LOW_COUNT="$(jq '[.site[]?.alerts[]? | select((.riskdesc // "") | test("Low"))] | length' "$FULL_JSON" 2>/dev/null || echo 0)"
  INFO_COUNT="$(jq '[.site[]?.alerts[]? | select((.riskdesc // "") | test("Informational"))] | length' "$FULL_JSON" 2>/dev/null || echo 0)"
fi

DECISION="passed"

case "$ENVIRONMENT" in
  production)
    if [ "$FAIL_ON_ZAP" = "true" ] && { [ "$HIGH_COUNT" -gt 0 ] || [ "$MEDIUM_COUNT" -gt 0 ]; }; then
      DECISION="failed"
    fi
    ;;
  main)
    if [ "$FAIL_ON_ZAP" = "true" ] && [ "$HIGH_COUNT" -gt 0 ]; then
      DECISION="failed"
    fi
    ;;
  pull_request|dev)
    if [ "$FAIL_ON_ZAP" = "true" ] && [ "$HIGH_COUNT" -gt 0 ]; then
      DECISION="failed"
    fi
    ;;
esac

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "dast_zap_baseline",
  "tool": "owasp_zap_baseline",
  "environment": "$ENVIRONMENT",
  "target_url": "$TARGET_URL",
  "zap_exit_code": $ZAP_EXIT,
  "alerts": {
    "total": $ALERT_COUNT,
    "high": $HIGH_COUNT,
    "medium": $MEDIUM_COUNT,
    "low": $LOW_COUNT,
    "informational": $INFO_COUNT
  },
  "decision": "$DECISION",
  "json_report": "$FULL_JSON",
  "html_report": "$FULL_HTML",
  "markdown_report": "$FULL_MD",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: ZAP baseline gate failed" >&2
  exit 1
fi

echo "ZAP baseline gate completed with decision: $DECISION"
```

Make executable:

```bash id="xcsnzr"
chmod +x dast-runtime-security/scripts/zap-baseline-gate.sh
```

Run:

```bash id="u5a9y0"
TARGET_URL=http://127.0.0.1:3002 \
ENVIRONMENT=pull_request \
FAIL_ON_ZAP=false \
./dast-runtime-security/scripts/zap-baseline-gate.sh
```

---

# 12. Runtime Security Headers Check

Create:

```bash id="fet418"
nano dast-runtime-security/scripts/security-headers-check.sh
```

Paste:

```bash id="z0ixpc"
#!/usr/bin/env bash
set -euo pipefail

TARGET_URL="${TARGET_URL:-http://127.0.0.1:3002}"
REPORT_DIR="${REPORT_DIR:-dast-runtime-security/reports}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"
FAIL_ON_MISSING_REQUIRED="${FAIL_ON_MISSING_REQUIRED:-false}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
HEADERS_FILE="$REPORT_DIR/security-headers-$ENVIRONMENT-$TIMESTAMP.txt"
SUMMARY_FILE="$REPORT_DIR/security-headers-summary-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== Security Headers Check ====="
echo "Target URL: $TARGET_URL"
echo "Environment: $ENVIRONMENT"

curl -skI "$TARGET_URL" > "$HEADERS_FILE"

normalize_headers="$(mktemp)"
tr '[:upper:]' '[:lower:]' < "$HEADERS_FILE" > "$normalize_headers"

REQUIRED_HEADERS=(
  "x-content-type-options"
  "x-frame-options"
  "referrer-policy"
)

RECOMMENDED_HEADERS=(
  "content-security-policy"
  "strict-transport-security"
  "permissions-policy"
)

MISSING_REQUIRED=()
MISSING_RECOMMENDED=()

for header in "${REQUIRED_HEADERS[@]}"; do
  if ! grep -qi "^$header:" "$normalize_headers"; then
    MISSING_REQUIRED+=("$header")
  fi
done

for header in "${RECOMMENDED_HEADERS[@]}"; do
  if ! grep -qi "^$header:" "$normalize_headers"; then
    MISSING_RECOMMENDED+=("$header")
  fi
done

rm -f "$normalize_headers"

REQUIRED_JSON="$(printf '%s\n' "${MISSING_REQUIRED[@]:-}" | jq -R . | jq -s 'map(select(. != ""))')"
RECOMMENDED_JSON="$(printf '%s\n' "${MISSING_RECOMMENDED[@]:-}" | jq -R . | jq -s 'map(select(. != ""))')"

DECISION="passed"

if [ "${#MISSING_REQUIRED[@]}" -gt 0 ]; then
  case "$ENVIRONMENT" in
    production|main)
      if [ "$FAIL_ON_MISSING_REQUIRED" = "true" ]; then
        DECISION="failed"
      else
        DECISION="warning"
      fi
      ;;
    *)
      DECISION="warning"
      ;;
  esac
fi

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "runtime_security_headers",
  "environment": "$ENVIRONMENT",
  "target_url": "$TARGET_URL",
  "missing_required": $REQUIRED_JSON,
  "missing_recommended": $RECOMMENDED_JSON,
  "decision": "$DECISION",
  "headers_file": "$HEADERS_FILE",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: required security headers missing" >&2
  exit 1
fi

echo "Security headers check completed with decision: $DECISION"
```

Make executable:

```bash id="b5cj97"
chmod +x dast-runtime-security/scripts/security-headers-check.sh
```

Run:

```bash id="6wggt9"
TARGET_URL=http://127.0.0.1:3002 \
ENVIRONMENT=pull_request \
FAIL_ON_MISSING_REQUIRED=false \
./dast-runtime-security/scripts/security-headers-check.sh
```

---

# 13. HTTP Method Check

Create:

```bash id="1q3l7j"
nano dast-runtime-security/scripts/http-method-check.sh
```

Paste:

```bash id="mcgtux"
#!/usr/bin/env bash
set -euo pipefail

TARGET_URL="${TARGET_URL:-http://127.0.0.1:3002}"
REPORT_DIR="${REPORT_DIR:-dast-runtime-security/reports}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"
FAIL_ON_UNSAFE="${FAIL_ON_UNSAFE:-true}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
SUMMARY_FILE="$REPORT_DIR/http-method-summary-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== HTTP Method Check ====="
echo "Target URL: $TARGET_URL"

TRACE_STATUS="$(curl -sk -o /dev/null -w "%{http_code}" -X TRACE "$TARGET_URL" || echo "000")"
OPTIONS_STATUS="$(curl -sk -o /dev/null -w "%{http_code}" -X OPTIONS "$TARGET_URL" || echo "000")"
DELETE_STATUS="$(curl -sk -o /dev/null -w "%{http_code}" -X DELETE "$TARGET_URL" || echo "000")"

UNSAFE_FOUND=false
FINDINGS=()

if [ "$TRACE_STATUS" != "405" ] && [ "$TRACE_STATUS" != "403" ] && [ "$TRACE_STATUS" != "404" ]; then
  UNSAFE_FOUND=true
  FINDINGS+=("TRACE returned $TRACE_STATUS")
fi

FINDINGS_JSON="$(printf '%s\n' "${FINDINGS[@]:-}" | jq -R . | jq -s 'map(select(. != ""))')"

DECISION="passed"

if [ "$UNSAFE_FOUND" = "true" ]; then
  if [ "$FAIL_ON_UNSAFE" = "true" ]; then
    DECISION="failed"
  else
    DECISION="warning"
  fi
fi

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "http_method_check",
  "environment": "$ENVIRONMENT",
  "target_url": "$TARGET_URL",
  "method_status": {
    "TRACE": "$TRACE_STATUS",
    "OPTIONS": "$OPTIONS_STATUS",
    "DELETE": "$DELETE_STATUS"
  },
  "findings": $FINDINGS_JSON,
  "decision": "$DECISION",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: unsafe HTTP method behavior found" >&2
  exit 1
fi

echo "HTTP method check completed with decision: $DECISION"
```

Make executable:

```bash id="mj9w1d"
chmod +x dast-runtime-security/scripts/http-method-check.sh
```

Run:

```bash id="cyj1zp"
TARGET_URL=http://127.0.0.1:3002 \
ENVIRONMENT=pull_request \
./dast-runtime-security/scripts/http-method-check.sh
```

---

# 14. Health and Version Exposure Check

Health endpoints are useful, but they should not leak secrets, stack traces, hostnames, database URLs, or internal config.

Create:

```bash id="bf1lbc"
nano dast-runtime-security/scripts/health-exposure-check.sh
```

Paste:

```bash id="erlpta"
#!/usr/bin/env bash
set -euo pipefail

TARGET_URL="${TARGET_URL:-http://127.0.0.1:3002}"
REPORT_DIR="${REPORT_DIR:-dast-runtime-security/reports}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"
FAIL_ON_LEAK="${FAIL_ON_LEAK:-true}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
HEALTH_FILE="$REPORT_DIR/health-response-$ENVIRONMENT-$TIMESTAMP.txt"
VERSION_FILE="$REPORT_DIR/version-response-$ENVIRONMENT-$TIMESTAMP.txt"
SUMMARY_FILE="$REPORT_DIR/health-exposure-summary-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== Health Exposure Check ====="
echo "Target URL: $TARGET_URL"

curl -sk "$TARGET_URL/health" > "$HEALTH_FILE" || true
curl -sk "$TARGET_URL/version" > "$VERSION_FILE" || true

FINDINGS=()

LEAK_PATTERNS=(
  "password"
  "secret"
  "token"
  "mongodb://"
  "postgres://"
  "mysql://"
  "private_key"
  "stack"
  "trace"
  "aws_access_key"
  "aws_secret"
)

for pattern in "${LEAK_PATTERNS[@]}"; do
  if grep -qi "$pattern" "$HEALTH_FILE" "$VERSION_FILE"; then
    FINDINGS+=("possible sensitive pattern found: $pattern")
  fi
done

FINDINGS_JSON="$(printf '%s\n' "${FINDINGS[@]:-}" | jq -R . | jq -s 'map(select(. != ""))')"

DECISION="passed"

if [ "${#FINDINGS[@]}" -gt 0 ]; then
  if [ "$FAIL_ON_LEAK" = "true" ]; then
    DECISION="failed"
  else
    DECISION="warning"
  fi
fi

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "health_endpoint_exposure",
  "environment": "$ENVIRONMENT",
  "target_url": "$TARGET_URL",
  "findings": $FINDINGS_JSON,
  "decision": "$DECISION",
  "health_response_file": "$HEALTH_FILE",
  "version_response_file": "$VERSION_FILE",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: possible sensitive health/version exposure found" >&2
  exit 1
fi

echo "Health exposure check completed with decision: $DECISION"
```

Make executable:

```bash id="sjfg5x"
chmod +x dast-runtime-security/scripts/health-exposure-check.sh
```

Run:

```bash id="b4rp9b"
TARGET_URL=http://127.0.0.1:3002 \
ENVIRONMENT=pull_request \
./dast-runtime-security/scripts/health-exposure-check.sh
```

---

# 15. Sensitive Path Check

Create:

```bash id="1tlzs6"
nano dast-runtime-security/scripts/sensitive-path-check.sh
```

Paste:

```bash id="95pthf"
#!/usr/bin/env bash
set -euo pipefail

TARGET_URL="${TARGET_URL:-http://127.0.0.1:3002}"
REPORT_DIR="${REPORT_DIR:-dast-runtime-security/reports}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"
FAIL_ON_EXPOSED="${FAIL_ON_EXPOSED:-true}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
SUMMARY_FILE="$REPORT_DIR/sensitive-path-summary-$ENVIRONMENT-$TIMESTAMP.json"

PATHS=(
  "/.env"
  "/debug"
  "/admin"
  "/server-status"
  "/actuator/env"
  "/config"
  "/metrics"
)

FINDINGS=()

for path in "${PATHS[@]}"; do
  status="$(curl -sk -o /dev/null -w "%{http_code}" "$TARGET_URL$path" || echo "000")"

  case "$status" in
    200|201|202|204|301|302)
      FINDINGS+=("$path returned $status")
      ;;
  esac
done

FINDINGS_JSON="$(printf '%s\n' "${FINDINGS[@]:-}" | jq -R . | jq -s 'map(select(. != ""))')"

DECISION="passed"

if [ "${#FINDINGS[@]}" -gt 0 ]; then
  if [ "$FAIL_ON_EXPOSED" = "true" ]; then
    DECISION="failed"
  else
    DECISION="warning"
  fi
fi

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "sensitive_path_check",
  "environment": "$ENVIRONMENT",
  "target_url": "$TARGET_URL",
  "findings": $FINDINGS_JSON,
  "decision": "$DECISION",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: sensitive path exposure found" >&2
  exit 1
fi

echo "Sensitive path check completed with decision: $DECISION"
```

Make executable:

```bash id="hrmbt8"
chmod +x dast-runtime-security/scripts/sensitive-path-check.sh
```

Run:

```bash id="bk5hux"
TARGET_URL=http://127.0.0.1:3002 \
ENVIRONMENT=pull_request \
./dast-runtime-security/scripts/sensitive-path-check.sh
```

---

# 16. API Security Smoke Test

Create:

```bash id="uilzeu"
nano dast-runtime-security/scripts/api-security-smoke-test.sh
```

Paste:

```bash id="7b03j7"
#!/usr/bin/env bash
set -euo pipefail

TARGET_URL="${TARGET_URL:-http://127.0.0.1:3002}"
REPORT_DIR="${REPORT_DIR:-dast-runtime-security/reports}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"
FAIL_ON_ERROR="${FAIL_ON_ERROR:-true}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
SUMMARY_FILE="$REPORT_DIR/api-security-smoke-summary-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== API Security Smoke Test ====="
echo "Target URL: $TARGET_URL"

FINDINGS=()

ROOT_STATUS="$(curl -sk -o /dev/null -w "%{http_code}" "$TARGET_URL/" || echo "000")"
HEALTH_STATUS="$(curl -sk -o /dev/null -w "%{http_code}" "$TARGET_URL/health" || echo "000")"
VERSION_STATUS="$(curl -sk -o /dev/null -w "%{http_code}" "$TARGET_URL/version" || echo "000")"

if [ "$HEALTH_STATUS" != "200" ]; then
  FINDINGS+=("/health expected 200, got $HEALTH_STATUS")
fi

if [ "$VERSION_STATUS" != "200" ] && [ "$VERSION_STATUS" != "404" ]; then
  FINDINGS+=("/version expected 200 or 404, got $VERSION_STATUS")
fi

ERROR_BODY="$(curl -sk "$TARGET_URL/simulate-error" || true)"

if echo "$ERROR_BODY" | grep -qiE 'stack|trace|error:.*at |node_modules|mongodb://|password|secret'; then
  FINDINGS+=("error endpoint may expose internal details")
fi

FINDINGS_JSON="$(printf '%s\n' "${FINDINGS[@]:-}" | jq -R . | jq -s 'map(select(. != ""))')"

DECISION="passed"

if [ "${#FINDINGS[@]}" -gt 0 ]; then
  if [ "$FAIL_ON_ERROR" = "true" ]; then
    DECISION="failed"
  else
    DECISION="warning"
  fi
fi

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "api_security_smoke",
  "environment": "$ENVIRONMENT",
  "target_url": "$TARGET_URL",
  "status_codes": {
    "root": "$ROOT_STATUS",
    "health": "$HEALTH_STATUS",
    "version": "$VERSION_STATUS"
  },
  "findings": $FINDINGS_JSON,
  "decision": "$DECISION",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: API security smoke test failed" >&2
  exit 1
fi

echo "API security smoke test completed with decision: $DECISION"
```

Make executable:

```bash id="s40e6c"
chmod +x dast-runtime-security/scripts/api-security-smoke-test.sh
```

Run:

```bash id="q5c6tq"
TARGET_URL=http://127.0.0.1:3002 \
ENVIRONMENT=pull_request \
FAIL_ON_ERROR=false \
./dast-runtime-security/scripts/api-security-smoke-test.sh
```

---

# 17. Combined DAST Runtime Gate

Create:

```bash id="8n35nf"
nano dast-runtime-security/scripts/dast-runtime-gate.sh
```

Paste:

```bash id="m0wl3r"
#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="${MODULE_DIR:-$HOME/devops-masterclass/09-devsecops-security-gates}"
TARGET_URL="${TARGET_URL:-http://127.0.0.1:3002}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"

RUN_ZAP="${RUN_ZAP:-false}"
RUN_HEADERS="${RUN_HEADERS:-true}"
RUN_METHODS="${RUN_METHODS:-true}"
RUN_HEALTH="${RUN_HEALTH:-true}"
RUN_SENSITIVE_PATHS="${RUN_SENSITIVE_PATHS:-true}"
RUN_API_SMOKE="${RUN_API_SMOKE:-true}"

FAIL_ON_ZAP="${FAIL_ON_ZAP:-false}"
FAIL_ON_HEADERS="${FAIL_ON_HEADERS:-false}"
FAIL_ON_METHODS="${FAIL_ON_METHODS:-true}"
FAIL_ON_HEALTH_LEAK="${FAIL_ON_HEALTH_LEAK:-true}"
FAIL_ON_SENSITIVE_PATHS="${FAIL_ON_SENSITIVE_PATHS:-true}"
FAIL_ON_API_ERROR="${FAIL_ON_API_ERROR:-false}"

echo "===== Combined DAST Runtime Gate ====="
echo "Target URL: $TARGET_URL"
echo "Environment: $ENVIRONMENT"

FAILED=0

cd "$MODULE_DIR"

if [ "$RUN_HEADERS" = "true" ]; then
  echo
  echo "===== Security Headers ====="
  TARGET_URL="$TARGET_URL" \
  ENVIRONMENT="$ENVIRONMENT" \
  FAIL_ON_MISSING_REQUIRED="$FAIL_ON_HEADERS" \
  ./dast-runtime-security/scripts/security-headers-check.sh || FAILED=1
fi

if [ "$RUN_METHODS" = "true" ]; then
  echo
  echo "===== HTTP Methods ====="
  TARGET_URL="$TARGET_URL" \
  ENVIRONMENT="$ENVIRONMENT" \
  FAIL_ON_UNSAFE="$FAIL_ON_METHODS" \
  ./dast-runtime-security/scripts/http-method-check.sh || FAILED=1
fi

if [ "$RUN_HEALTH" = "true" ]; then
  echo
  echo "===== Health Exposure ====="
  TARGET_URL="$TARGET_URL" \
  ENVIRONMENT="$ENVIRONMENT" \
  FAIL_ON_LEAK="$FAIL_ON_HEALTH_LEAK" \
  ./dast-runtime-security/scripts/health-exposure-check.sh || FAILED=1
fi

if [ "$RUN_SENSITIVE_PATHS" = "true" ]; then
  echo
  echo "===== Sensitive Paths ====="
  TARGET_URL="$TARGET_URL" \
  ENVIRONMENT="$ENVIRONMENT" \
  FAIL_ON_EXPOSED="$FAIL_ON_SENSITIVE_PATHS" \
  ./dast-runtime-security/scripts/sensitive-path-check.sh || FAILED=1
fi

if [ "$RUN_API_SMOKE" = "true" ]; then
  echo
  echo "===== API Security Smoke ====="
  TARGET_URL="$TARGET_URL" \
  ENVIRONMENT="$ENVIRONMENT" \
  FAIL_ON_ERROR="$FAIL_ON_API_ERROR" \
  ./dast-runtime-security/scripts/api-security-smoke-test.sh || FAILED=1
fi

if [ "$RUN_ZAP" = "true" ]; then
  echo
  echo "===== OWASP ZAP Baseline ====="
  TARGET_URL="$TARGET_URL" \
  ENVIRONMENT="$ENVIRONMENT" \
  FAIL_ON_ZAP="$FAIL_ON_ZAP" \
  ./dast-runtime-security/scripts/zap-baseline-gate.sh || FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
  echo "ERROR: DAST runtime gate failed" >&2
  exit 1
fi

echo "DAST runtime gate passed or reported only."
```

Make executable:

```bash id="2k66hz"
chmod +x dast-runtime-security/scripts/dast-runtime-gate.sh
```

Run without ZAP:

```bash id="3jc57n"
TARGET_URL=http://127.0.0.1:3002 \
ENVIRONMENT=pull_request \
RUN_ZAP=false \
./dast-runtime-security/scripts/dast-runtime-gate.sh
```

Run with ZAP:

```bash id="p2xww2"
TARGET_URL=http://127.0.0.1:3002 \
ENVIRONMENT=pull_request \
RUN_ZAP=true \
FAIL_ON_ZAP=false \
./dast-runtime-security/scripts/dast-runtime-gate.sh
```

---

# 18. DAST Summary Script

Create:

```bash id="n1pwzx"
nano dast-runtime-security/scripts/dast-runtime-summary.sh
```

Paste:

```bash id="6dll6c"
#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-dast-runtime-security/reports}"

echo "===== DAST Runtime Security Summary ====="
echo "Report dir: $REPORT_DIR"

find "$REPORT_DIR" -type f -name '*summary*.json' | sort | tail -n 20 | while read -r file; do
  echo
  echo "## $file"
  jq . "$file"
done

echo
echo "Recent ZAP reports:"
find "$REPORT_DIR" -type f \( -name 'zap-baseline-*.json' -o -name 'zap-baseline-*.html' -o -name 'zap-baseline-*.md' \) \
  | sort \
  | tail -n 10
```

Make executable:

```bash id="6y6twg"
chmod +x dast-runtime-security/scripts/dast-runtime-summary.sh
```

Run:

```bash id="zqn75f"
./dast-runtime-security/scripts/dast-runtime-summary.sh
```

---

# 19. Optional: Add Helmet to Express

Your custom header check may warn because the app does not set security headers.

For Express apps, a common fix is to use Helmet.

```bash id="owf8io"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

npm install helmet
```

In your server entry file:

```javascript id="jdpxdo"
const helmet = require("helmet");

app.use(helmet());
```

Then restart app and rerun:

```bash id="lrk1zb"
cd ~/devops-masterclass/09-devsecops-security-gates

TARGET_URL=http://127.0.0.1:3002 \
ENVIRONMENT=main \
FAIL_ON_MISSING_REQUIRED=true \
./dast-runtime-security/scripts/security-headers-check.sh
```

Commit app change only after tests pass:

```bash id="2rsxca"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

npm test
```

---

# 20. GitHub Actions DAST Workflow

Create:

```bash id="6vid4w"
nano dast-runtime-security/github-actions/dast-runtime-security.yml
```

Paste:

```yaml id="nrksvf"
name: DAST Runtime Security

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main
  workflow_dispatch:
    inputs:
      run_zap:
        description: "Run OWASP ZAP baseline"
        required: true
        default: false
        type: boolean

permissions:
  contents: read

env:
  MODULE9_DIR: 09-devsecops-security-gates
  APP_DIR: 05-application-runtime/demo-node-api
  NODE_VERSION: "22"
  TARGET_URL: http://127.0.0.1:3002

jobs:
  dast-runtime:
    name: Runtime security smoke tests and optional ZAP
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

      - name: Start app
        working-directory: ${{ env.APP_DIR }}
        run: |
          PORT=3002 \
          NODE_ENV=production \
          APP_VERSION="0.9.0-${GITHUB_SHA::7}" \
          nohup npm start > app.log 2>&1 &

          for i in $(seq 1 30); do
            if curl -fsS "$TARGET_URL/health"; then
              echo "App is ready."
              exit 0
            fi
            sleep 2
          done

          echo "App failed to become ready."
          cat app.log || true
          exit 1

      - name: Run DAST runtime gate
        run: |
          cd "$MODULE9_DIR"

          if [ "${{ github.event_name }}" = "pull_request" ]; then
            ENVIRONMENT="pull_request"
            FAIL_HEADERS="false"
          else
            ENVIRONMENT="main"
            FAIL_HEADERS="false"
          fi

          RUN_ZAP="${{ github.event_name == 'workflow_dispatch' && inputs.run_zap || false }}"

          TARGET_URL="$TARGET_URL" \
          ENVIRONMENT="$ENVIRONMENT" \
          RUN_ZAP="$RUN_ZAP" \
          FAIL_ON_ZAP=false \
          FAIL_ON_HEADERS="$FAIL_HEADERS" \
          FAIL_ON_METHODS=true \
          FAIL_ON_HEALTH_LEAK=true \
          FAIL_ON_SENSITIVE_PATHS=true \
          FAIL_ON_API_ERROR=false \
          ./dast-runtime-security/scripts/dast-runtime-gate.sh

      - name: Upload DAST reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: dast-runtime-reports
          path: 09-devsecops-security-gates/dast-runtime-security/reports/

      - name: Upload app log
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: dast-app-log
          path: 05-application-runtime/demo-node-api/app.log
```

Copy:

```bash id="2ueww2"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/dast-runtime-security/github-actions/dast-runtime-security.yml \
   .github/workflows/dast-runtime-security.yml
```

ZAP provides a GitHub Marketplace baseline scan action, but using the Docker/script approach here keeps the same pattern portable across GitHub Actions, Jenkins, and GitLab CI. ([github.com](https://github.com/marketplace/actions/zap-baseline-scan?utm_source=chatgpt.com))

---

# 21. Jenkins DAST Pipeline

Create:

```bash id="bew5z6"
nano dast-runtime-security/jenkins/Jenkinsfile.dast-runtime-security
```

Paste:

```groovy id="wxq3vz"
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 45, unit: 'MINUTES')
  }

  parameters {
    string(name: 'TARGET_URL', defaultValue: 'http://127.0.0.1:3002', description: 'Target URL')
    choice(name: 'ENVIRONMENT', choices: ['pull_request', 'main', 'production'], description: 'Gate environment')
    booleanParam(name: 'RUN_ZAP', defaultValue: false, description: 'Run OWASP ZAP baseline?')
    booleanParam(name: 'START_LOCAL_APP', defaultValue: true, description: 'Start local app in Jenkins?')
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

    stage('Start Local App') {
      when {
        expression { return params.START_LOCAL_APP }
      }
      steps {
        dir("${APP_DIR}") {
          sh '''
            npm ci

            PORT=3002 \
            NODE_ENV=production \
            APP_VERSION="0.9.0-${BUILD_NUMBER}" \
            nohup npm start > app.log 2>&1 &

            for i in $(seq 1 30); do
              if curl -fsS "${TARGET_URL}/health"; then
                echo "App is ready."
                exit 0
              fi
              sleep 2
            done

            echo "App failed to become ready."
            cat app.log || true
            exit 1
          '''
        }
      }
    }

    stage('DAST Runtime Gate') {
      steps {
        dir("${MODULE9_DIR}") {
          sh '''
            TARGET_URL="${TARGET_URL}" \
            ENVIRONMENT="${ENVIRONMENT}" \
            RUN_ZAP="${RUN_ZAP}" \
            FAIL_ON_ZAP=false \
            FAIL_ON_HEADERS=false \
            FAIL_ON_METHODS=true \
            FAIL_ON_HEALTH_LEAK=true \
            FAIL_ON_SENSITIVE_PATHS=true \
            FAIL_ON_API_ERROR=false \
            ./dast-runtime-security/scripts/dast-runtime-gate.sh
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '''
        09-devsecops-security-gates/dast-runtime-security/reports/**/*,
        05-application-runtime/demo-node-api/app.log
      ''', allowEmptyArchive: true
    }

    success {
      echo 'DAST runtime gate passed.'
    }

    failure {
      echo 'DAST runtime gate failed. Review archived reports.'
    }
  }
}
```

Jenkins script path:

```text id="7k2hc3"
09-devsecops-security-gates/dast-runtime-security/jenkins/Jenkinsfile.dast-runtime-security
```

---

# 22. GitLab CI DAST Pipeline

Create:

```bash id="84x12q"
nano dast-runtime-security/gitlab/.gitlab-ci.dast-runtime-security.yml
```

Paste:

```yaml id="s24jmx"
stages:
  - dast

variables:
  MODULE9_DIR: "09-devsecops-security-gates"
  APP_DIR: "05-application-runtime/demo-node-api"
  TARGET_URL: "http://127.0.0.1:3002"
  RUN_ZAP: "false"

dast_runtime_security:
  stage: dast
  image: node:22-bookworm
  before_script:
    - apt-get update
    - apt-get install -y curl jq docker.io
    - cd "$APP_DIR"
    - npm ci
    - PORT=3002 NODE_ENV=production APP_VERSION="0.9.0-${CI_COMMIT_SHORT_SHA}" nohup npm start > app.log 2>&1 &
    - |
      for i in $(seq 1 30); do
        if curl -fsS "$TARGET_URL/health"; then
          echo "App is ready."
          break
        fi
        sleep 2
      done
    - cd "$CI_PROJECT_DIR"
  script:
    - cd "$MODULE9_DIR"
    - |
      if [ "${CI_COMMIT_BRANCH:-}" = "main" ]; then
        ENVIRONMENT="main"
      else
        ENVIRONMENT="pull_request"
      fi

      TARGET_URL="$TARGET_URL" \
      ENVIRONMENT="$ENVIRONMENT" \
      RUN_ZAP="$RUN_ZAP" \
      FAIL_ON_ZAP=false \
      FAIL_ON_HEADERS=false \
      FAIL_ON_METHODS=true \
      FAIL_ON_HEALTH_LEAK=true \
      FAIL_ON_SENSITIVE_PATHS=true \
      FAIL_ON_API_ERROR=false \
      ./dast-runtime-security/scripts/dast-runtime-gate.sh
  artifacts:
    when: always
    expire_in: 30 days
    paths:
      - 09-devsecops-security-gates/dast-runtime-security/reports/
      - 05-application-runtime/demo-node-api/app.log
```

Note:

```text id="v3st71"
RUN_ZAP=false by default because ZAP via Docker requires Docker availability in the runner.
Use a Docker-enabled GitLab runner or a dedicated ZAP image job for ZAP scans.
```

---

# 23. DAST Triage Runbook

Create:

```bash id="l75b04"
nano dast-runtime-security/runbooks/dast-triage-runbook.md
```

Paste:

````markdown id="undm30"
# DAST Triage Runbook

## Goal

Triage runtime security findings from OWASP ZAP and custom security smoke tests.

## Step 1 — Identify Finding

Collect:

- target URL
- endpoint
- HTTP method
- response code
- security header
- ZAP alert name
- ZAP risk level
- evidence
- environment

## Step 2 — Classify

Categories:

- missing security header
- unsafe method
- information leakage
- sensitive endpoint exposure
- cookie/session issue
- TLS/HTTPS issue
- false positive

## Step 3 — Decide Severity

High:

- exposed secrets
- exposed admin/debug endpoint
- TRACE enabled with risky behavior
- stack trace or internal config leak

Medium:

- missing important security headers
- weak cookie attributes
- server version leakage

Low:

- informational headers
- minor passive scan warnings

## Step 4 — Fix

Common fixes:

- add Helmet or equivalent middleware
- disable unsafe methods at Nginx/app layer
- hide stack traces in production
- protect debug/admin endpoints
- remove sensitive output from health endpoints
- enforce HTTPS at load balancer/CloudFront/Nginx

## Step 5 — Rerun

Run:

```bash
TARGET_URL=http://127.0.0.1:3002 ./dast-runtime-security/scripts/dast-runtime-gate.sh
````

## Step 6 — Exception

Exception requires:

* owner
* reason
* expiry
* affected endpoint
* compensating control
* security approval

```id="yn22ce"
```

---

# 24. Production-Safe DAST Runbook

Create:

```bash id="lftzj3"
nano dast-runtime-security/runbooks/production-safe-dast.md
```

Paste:

```markdown id="rle4l6"
# Production-Safe DAST

## Rule

Do not run aggressive active scans against production unless explicitly approved.

## Safer Production Checks

Allowed by default:

- HTTP security headers
- health endpoint response validation
- sensitive path existence checks
- passive ZAP baseline if approved
- TLS/HTTPS checks
- known endpoint smoke tests

Avoid by default:

- active attack scans
- fuzzing
- destructive payloads
- authenticated mutation endpoints
- high-volume scans

## Recommended Pattern

Pull request:

- start app locally or preview environment
- run runtime smoke checks
- optional passive baseline

Staging:

- run ZAP baseline
- run API scan against test data
- run deeper checks

Production:

- passive/report-only
- strict rate limit
- no destructive tests
- approved scan window
```

---

# 25. Security Headers Fix Runbook

Create:

```bash id="g925bz"
nano dast-runtime-security/runbooks/security-headers-fix.md
```

Paste:

````markdown id="2p7f89"
# Security Headers Fix Runbook

## Express.js

Install Helmet:

```bash
npm install helmet
````

Use it:

```javascript
const helmet = require("helmet");
app.use(helmet());
```

## Nginx

Example:

```nginx
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "DENY" always;
add_header Referrer-Policy "no-referrer" always;
add_header Permissions-Policy "geolocation=()" always;
```

## CloudFront

Security headers can be added with:

* response headers policy
* origin configuration
* Lambda@Edge / CloudFront Functions where appropriate

## Validate

```bash
curl -I https://example.com
```

```id="le2ttd"
```

---

# 26. Validation Script

Create:

```bash id="652z7x"
nano dast-runtime-security/scripts/validate-dast-runtime-lesson.sh
```

Paste:

```bash id="m1h5qy"
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-dast-runtime-security}"

echo "===== Validate DAST Runtime Security Lesson ====="

test -f "$BASE_DIR/policies/runtime-security-policy.json"
test -f "$BASE_DIR/notes/dast-runtime-security-mental-model.md"
test -f "$BASE_DIR/zap/zap-baseline-rules.tsv"

test -x "$BASE_DIR/scripts/zap-baseline-gate.sh"
test -x "$BASE_DIR/scripts/security-headers-check.sh"
test -x "$BASE_DIR/scripts/http-method-check.sh"
test -x "$BASE_DIR/scripts/health-exposure-check.sh"
test -x "$BASE_DIR/scripts/sensitive-path-check.sh"
test -x "$BASE_DIR/scripts/api-security-smoke-test.sh"
test -x "$BASE_DIR/scripts/dast-runtime-gate.sh"
test -x "$BASE_DIR/scripts/dast-runtime-summary.sh"

test -f "$BASE_DIR/github-actions/dast-runtime-security.yml"
test -f "$BASE_DIR/jenkins/Jenkinsfile.dast-runtime-security"
test -f "$BASE_DIR/gitlab/.gitlab-ci.dast-runtime-security.yml"

test -f "$BASE_DIR/runbooks/dast-triage-runbook.md"
test -f "$BASE_DIR/runbooks/production-safe-dast.md"
test -f "$BASE_DIR/runbooks/security-headers-fix.md"

echo "DAST runtime security lesson validated."
```

Make executable:

```bash id="s526rb"
chmod +x dast-runtime-security/scripts/validate-dast-runtime-lesson.sh
```

Run:

```bash id="p30b2c"
./dast-runtime-security/scripts/validate-dast-runtime-lesson.sh
```

---

# 27. Update Makefile

Open:

```bash id="k9cy9g"
cd ~/devops-masterclass/09-devsecops-security-gates

nano Makefile
```

Add:

```Makefile id="me1l73"
.PHONY: dast-validate dast-gate dast-gate-zap dast-summary headers-check methods-check health-check sensitive-path-check api-security-smoke zap-baseline

dast-validate:
	./dast-runtime-security/scripts/validate-dast-runtime-lesson.sh

headers-check:
	TARGET_URL="$${TARGET_URL:-http://127.0.0.1:3002}" \
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_MISSING_REQUIRED="$${FAIL_ON_MISSING_REQUIRED:-false}" \
	./dast-runtime-security/scripts/security-headers-check.sh

methods-check:
	TARGET_URL="$${TARGET_URL:-http://127.0.0.1:3002}" \
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	./dast-runtime-security/scripts/http-method-check.sh

health-check:
	TARGET_URL="$${TARGET_URL:-http://127.0.0.1:3002}" \
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	./dast-runtime-security/scripts/health-exposure-check.sh

sensitive-path-check:
	TARGET_URL="$${TARGET_URL:-http://127.0.0.1:3002}" \
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	./dast-runtime-security/scripts/sensitive-path-check.sh

api-security-smoke:
	TARGET_URL="$${TARGET_URL:-http://127.0.0.1:3002}" \
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_ERROR="$${FAIL_ON_ERROR:-false}" \
	./dast-runtime-security/scripts/api-security-smoke-test.sh

zap-baseline:
	TARGET_URL="$${TARGET_URL:-http://127.0.0.1:3002}" \
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_ZAP="$${FAIL_ON_ZAP:-false}" \
	./dast-runtime-security/scripts/zap-baseline-gate.sh

dast-gate:
	TARGET_URL="$${TARGET_URL:-http://127.0.0.1:3002}" \
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	RUN_ZAP="$${RUN_ZAP:-false}" \
	./dast-runtime-security/scripts/dast-runtime-gate.sh

dast-gate-zap:
	TARGET_URL="$${TARGET_URL:-http://127.0.0.1:3002}" \
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	RUN_ZAP=true \
	FAIL_ON_ZAP=false \
	./dast-runtime-security/scripts/dast-runtime-gate.sh

dast-summary:
	./dast-runtime-security/scripts/dast-runtime-summary.sh
```

Run:

```bash id="1nxciz"
make dast-validate
make dast-gate
make dast-summary
```

---

# 28. Practical Lab

Terminal 1 — start app:

```bash id="5qh89p"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

npm ci

PORT=3002 \
NODE_ENV=production \
APP_VERSION=0.9.0-dev-local \
npm start
```

Terminal 2 — run DAST:

```bash id="2cy6ve"
cd ~/devops-masterclass/09-devsecops-security-gates

make dast-validate

TARGET_URL=http://127.0.0.1:3002 \
ENVIRONMENT=pull_request \
RUN_ZAP=false \
make dast-gate

make dast-summary
```

Optional ZAP baseline:

```bash id="3gf360"
TARGET_URL=http://127.0.0.1:3002 \
RUN_ZAP=true \
make dast-gate-zap
```

Copy GitHub workflow:

```bash id="js5oxs"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/dast-runtime-security/github-actions/dast-runtime-security.yml \
   .github/workflows/dast-runtime-security.yml
```

Commit:

```bash id="2karlc"
git status

git add .github/workflows/dast-runtime-security.yml \
        09-devsecops-security-gates

git commit -m "feat: add DAST runtime security gates"
git push
```

---

# 29. Common DAST Problems

## App is not reachable from ZAP container

Linux:

```bash id="fgd5ib"
USE_HOST_NETWORK=true TARGET_URL=http://127.0.0.1:3002 make zap-baseline
```

Docker Desktop:

```bash id="d0o1pk"
USE_HOST_NETWORK=false TARGET_URL=http://host.docker.internal:3002 make zap-baseline
```

## ZAP returns warnings for missing headers

Fix in app or Nginx.

For Express:

```bash id="jww5c7"
npm install helmet
```

Then:

```javascript id="aflplm"
const helmet = require("helmet");
app.use(helmet());
```

## DAST fails but SAST passes

Expected.

```text id="6nw8ze"
SAST checks code patterns.
DAST checks runtime behavior.
```

## ZAP baseline finds too many passive alerts

Start as report/warn mode:

```bash id="renvyc"
FAIL_ON_ZAP=false
```

Then tune rules with documented exceptions.

## Do not run full scan against production

ZAP full scan performs active attacks and can run longer, so use it only in approved test environments. ([zaproxy.org](https://www.zaproxy.org/docs/docker/full-scan/?utm_source=chatgpt.com))

---

# 30. Interview Explanation

## What is DAST?

```text id="ajb27a"
DAST, or Dynamic Application Security Testing, tests a running application from the outside by sending HTTP requests and analyzing runtime behavior. It can detect issues like missing security headers, insecure HTTP methods, exposed debug endpoints, information leakage, and passive web security findings.
```

## Why do we need DAST if we already use SAST?

```text id="q2759u"
SAST analyzes source code before runtime, while DAST checks the deployed application's actual behavior over HTTP. Some issues, such as missing security headers, server banner exposure, misconfigured routes, or runtime error leakage, may only appear when the app is running.
```

## What is OWASP ZAP baseline scan?

```text id="5gd9wq"
OWASP ZAP baseline scan is a passive security scan that spiders a target for a short time and reports passive findings. It is safer for CI and staging than active scans because it does not perform active attacks by default.
```

## Why avoid active scans in production?

```text id="0mip29"
Active scans can send attack-like payloads, create load, mutate data, or trigger defensive systems. They should only run in approved environments or controlled production windows with explicit authorization.
```

## What runtime checks should every API have?

```text id="1j38na"
At minimum, I check security headers, unsafe HTTP methods, health/version endpoint exposure, sensitive paths like /.env or /debug, and error responses for stack traces or secrets.
```

## How do you handle DAST findings?

```text id="2xk0tx"
I classify the finding by endpoint, severity, evidence, environment, and exploitability. Then I fix the app, proxy, or infrastructure configuration, rerun the scan, and only use exceptions when there is an owner, reason, expiry date, and compensating control.
```

---

# 31. Today’s Core Rules

```text id="uf6hit"
DAST scans a running app.
Use passive baseline scans in CI/staging.
Do not run active scans against production by default.
Custom runtime checks are fast and deterministic.
ZAP baseline is useful but should not be your only runtime gate.
Check security headers.
Block unsafe HTTP methods.
Do not leak secrets from health/version endpoints.
Do not expose debug/admin paths.
Archive DAST reports.
DAST complements SAST, SCA, image scanning, IaC scanning, and SBOM.
```

---

# Next Lesson

# Lesson 9.11 — Security Evidence, Risk Exceptions, and Release Approval

We will build:

```text id="4q85it"
central security evidence collector
security report index
risk exception schema
exception validation
release approval checklist
production security gate
GitHub Actions approval evidence
Jenkins approval evidence
GitLab CI approval evidence
security dashboard JSON
DevSecOps release runbook
```

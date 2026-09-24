# Lesson 9.6 — Dockerfile and Container Build Security

# Hadolint, Custom Dockerfile Policy Checks, Non-Root Runtime, No `latest`, No Secrets in `ARG`/`ENV`, Multi-Stage Build Hardening, `.dockerignore`, GitHub Actions, Jenkins, GitLab CI, and Production Dockerfile Gates

In Lesson 9.5, we scanned the **built container image**.

Now we scan and harden the **Dockerfile and build process** before the image is even built.

A container security pipeline should ask:

```text id="1qvl66"
Is the Dockerfile safe?
Is the base image pinned?
Does the runtime run as non-root?
Are secrets kept out of ARG/ENV?
Is the final image minimal?
Are dev dependencies excluded?
Is .dockerignore protecting the build context?
Are unsafe build instructions blocked?
```

Docker recommends multi-stage builds to separate build steps from the final runtime output and reduce what ends up in the final image. Docker also supports `.dockerignore` files to exclude unnecessary or sensitive files from the build context before it is sent to the builder. ([Docker Documentation][1])

---

# 1. Dockerfile Security Mental Model

A Dockerfile is not just a build recipe.

It controls:

```text id="gev0ah"
base image
runtime user
filesystem contents
dependency installation
secret exposure risk
image layers
build cache behavior
attack surface
runtime command
health checks
```

Bad Dockerfile:

```Dockerfile id="4g9ejd"
FROM node:latest
WORKDIR /app
COPY . .
ENV API_KEY=super-secret
RUN npm install
CMD ["npm", "start"]
```

Problems:

```text id="0q4uqj"
uses latest
copies everything
stores secret in image metadata
installs dev dependencies
runs as root by default
no healthcheck
large attack surface
less reproducible build
```

Better Dockerfile:

```Dockerfile id="yyabhb"
FROM node:22-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY --from=deps /app/node_modules ./node_modules
COPY . .
USER node
EXPOSE 3002
CMD ["node", "server.js"]
```

Professional rule:

```text id="w8vnbx"
A secure Dockerfile produces a small, reproducible, least-privilege runtime image.
```

---

# 2. What Hadolint Does

Hadolint is a Dockerfile linter. It detects common Dockerfile issues and ShellCheck-style shell issues in `RUN` commands. The Hadolint project documents rules such as avoiding untagged images, not using `apt-get upgrade`, and ensuring the last user should not be root. ([GitHub][2])

Examples of issues Hadolint can catch:

```text id="5g9dlh"
using latest or untagged base images
missing version pinning
bad apt/apk patterns
unsafe shell commands
root runtime user
inefficient layers
```

Hadolint is not enough by itself, so we will combine it with **custom policy scripts**.

---

# 3. Create Lesson Directory

Run:

```bash id="ji4luk"
cd ~/devops-masterclass/09-devsecops-security-gates

mkdir -p dockerfile-build-security/{hadolint,scripts,reports,github-actions,jenkins,gitlab,runbooks,examples,notes,policies}
```

Check:

```bash id="l53naf"
tree -L 2 dockerfile-build-security
```

Expected:

```text id="ut4ujs"
dockerfile-build-security
├── examples
├── github-actions
├── gitlab
├── hadolint
├── jenkins
├── notes
├── policies
├── reports
├── runbooks
└── scripts
```

---

# 4. Dockerfile Security Policy

Create:

```bash id="8fpdkl"
nano dockerfile-build-security/policies/dockerfile-security-policy.json
```

Paste:

```json id="6a68cm"
{
  "service_name": "demo-node-api",
  "policy_version": "1.0",
  "tools": ["hadolint", "custom dockerfile policy"],
  "environments": {
    "pull_request": {
      "hadolint": "warn",
      "custom_policy": "fail_on_critical",
      "non_root_user": "warn",
      "latest_base_image": "fail",
      "secret_like_arg_env": "fail"
    },
    "main": {
      "hadolint": "fail",
      "custom_policy": "fail",
      "non_root_user": "fail",
      "latest_base_image": "fail",
      "secret_like_arg_env": "fail"
    },
    "production": {
      "hadolint": "fail",
      "custom_policy": "fail",
      "non_root_user": "fail",
      "latest_base_image": "fail",
      "secret_like_arg_env": "fail",
      "dockerignore_required": true,
      "multi_stage_required": true,
      "healthcheck_recommended": true
    }
  },
  "forbidden": {
    "base_image_tags": ["latest"],
    "runtime_user": ["root", "0"],
    "secret_like_names": [
      "SECRET",
      "TOKEN",
      "PASSWORD",
      "PASSWD",
      "API_KEY",
      "ACCESS_KEY",
      "PRIVATE_KEY"
    ],
    "forbidden_files_in_context": [
      ".env",
      ".env.production",
      "id_rsa",
      "id_ed25519",
      "*.pem",
      "*.p12"
    ]
  },
  "required_runtime_practices": [
    "explicit_base_tag",
    "non_root_user",
    "minimal_runtime_stage",
    "no_secret_like_arg_or_env",
    "dockerignore_present",
    "no_local_node_modules_copy"
  ]
}
```

---

# 5. Dockerfile Security Notes

Create:

```bash id="05hq6m"
nano dockerfile-build-security/notes/dockerfile-security-mental-model.md
```

Paste:

```markdown id="x2fk8z"
# Dockerfile and Build Security Mental Model

## Goal

Prevent insecure build patterns before the image is built.

## Security Risks

- mutable base image tags
- root runtime user
- secrets in ARG or ENV
- copying too much build context
- dev dependencies in runtime image
- no `.dockerignore`
- unnecessary OS packages
- unsafe shell commands
- unpinned package installation
- missing healthcheck/version metadata

## Secure Dockerfile Principles

- use explicit base image tags
- prefer multi-stage builds
- copy only required files
- run as non-root
- do not bake secrets into image
- use BuildKit secrets for build-time secrets
- use `.dockerignore`
- keep runtime image minimal
- scan Dockerfile and final image

## Golden Rule

A Dockerfile should produce a reproducible, minimal, non-root, secret-free runtime image.
```

---

# 6. Install Hadolint

## Option A — Docker

```bash id="osjlkq"
docker run --rm -i hadolint/hadolint < Dockerfile
```

## Option B — Download binary

```bash id="qbvde1"
mkdir -p "$HOME/.local/bin"

curl -L https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64 \
  -o "$HOME/.local/bin/hadolint"

chmod +x "$HOME/.local/bin/hadolint"

hadolint --version
```

## Option C — GitHub Action

Hadolint provides a GitHub Action that runs the Dockerfile linting tool, commonly used with `hadolint/hadolint-action@v3.1.0`. ([GitHub][3])

---

# 7. Basic Hadolint Scan

Run:

```bash id="aj9q7s"
cd ~/devops-masterclass

hadolint 05-application-runtime/demo-node-api/Dockerfile.industry
```

Docker option:

```bash id="hy5frz"
docker run --rm -i hadolint/hadolint \
  < 05-application-runtime/demo-node-api/Dockerfile.industry
```

JSON format:

```bash id="k0ua6u"
hadolint \
  --format json \
  05-application-runtime/demo-node-api/Dockerfile.industry \
  > 09-devsecops-security-gates/dockerfile-build-security/reports/hadolint-report.json
```

---

# 8. Hadolint Config

Create:

```bash id="fvh5uw"
nano dockerfile-build-security/hadolint/.hadolint.yaml
```

Paste:

```yaml id="2zb9gr"
failure-threshold: error

ignored:
  # Example only:
  # - DL3018

trustedRegistries:
  - docker.io
  - ghcr.io
  - public.ecr.aws

override:
  warning:
    - DL3008
    - DL3018
```

Notes:

```text id="341my9"
Do not ignore rules casually.
Every ignored rule should have a documented reason.
```

---

# 9. Bad Dockerfile Example

Create:

```bash id="u4fwgd"
nano dockerfile-build-security/examples/Dockerfile.insecure
```

Paste:

```Dockerfile id="014g5a"
FROM node:latest

WORKDIR /app

ARG API_KEY
ENV DB_PASSWORD=example-password
ENV NODE_ENV=production

COPY . .

RUN npm install

EXPOSE 3002

CMD ["npm", "start"]
```

This should be flagged because:

```text id="k0cpj2"
uses latest
has secret-like ARG
has secret-like ENV
copies entire context
uses npm install instead of npm ci
does not set non-root user
does not use multi-stage build
```

---

# 10. Secure Dockerfile Example

Create:

```bash id="fmuq74"
nano dockerfile-build-security/examples/Dockerfile.secure-node
```

Paste:

```Dockerfile id="mjxolo"
FROM node:22-alpine AS deps

WORKDIR /app

COPY package*.json ./

RUN npm ci --omit=dev && npm cache clean --force


FROM node:22-alpine AS runtime

WORKDIR /app

ENV NODE_ENV=production

COPY --from=deps /app/node_modules ./node_modules
COPY . .

USER node

EXPOSE 3002

HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3002/health || exit 1

CMD ["node", "server.js"]
```

This demonstrates:

```text id="unl7ax"
multi-stage build
explicit base image tag
production dependency install
non-root user
healthcheck
no secret-like ARG/ENV
```

Docker’s multi-stage build documentation explains that multiple `FROM` statements let you selectively copy artifacts from one stage to another and leave behind anything not needed in the final image. ([Docker Documentation][4])

---

# 11. `.dockerignore` Security

Docker says `.dockerignore` removes matching files from the build context before it is sent to the builder, which helps avoid sending unwanted files and directories. Dockerfile-specific ignore files can also be used when multiple Dockerfiles exist. ([Docker Documentation][5])

Create a recommended `.dockerignore` for your app:

```bash id="fd17z7"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

cat > .dockerignore <<'EOF'
node_modules
npm-debug.log
coverage
.git
.gitignore
.env
.env.*
*.pem
*.key
id_rsa
id_ed25519
Dockerfile*
docker-compose*
README.md
reports
logs
*.log
EOF
```

Important:

```text id="jx7yim"
.dockerignore reduces accidental context leakage.
It does not replace secret scanning.
```

Docker also documents that files excluded by `.dockerignore` are not present in the build context, so trying to `COPY` ignored files can cause build errors. ([Docker Documentation][6])

---

# 12. BuildKit Secrets Instead of ARG/ENV

Bad:

```Dockerfile id="eh9gii"
ARG NPM_TOKEN
RUN npm config set //registry.npmjs.org/:_authToken=$NPM_TOKEN
```

Bad:

```Dockerfile id="yady3i"
ENV NPM_TOKEN=secret-value
```

Better with BuildKit secret mount:

```Dockerfile id="j8urfd"
# syntax=docker/dockerfile:1.7

RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm ci --omit=dev
```

Build command:

```bash id="gzugz0"
DOCKER_BUILDKIT=1 docker build \
  --secret id=npmrc,src="$HOME/.npmrc" \
  -t demo-node-api:secure-build \
  .
```

Docker’s build secrets documentation says build secrets are passed with `docker build --secret` and consumed inside the Dockerfile, instead of being stored in normal build arguments or image layers. ([Docker Documentation][7])

Professional rule:

```text id="3a4gys"
Do not pass real secrets through ARG or ENV during image build.
```

---

# 13. Hadolint Gate Script

Create:

```bash id="w479uq"
cd ~/devops-masterclass/09-devsecops-security-gates

nano dockerfile-build-security/scripts/hadolint-gate.sh
```

Paste:

```bash id="oz799o"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
MODULE_DIR="${MODULE_DIR:-$ROOT_DIR/09-devsecops-security-gates}"
DOCKERFILE="${DOCKERFILE:-$ROOT_DIR/05-application-runtime/demo-node-api/Dockerfile.industry}"
CONFIG_FILE="${CONFIG_FILE:-$MODULE_DIR/dockerfile-build-security/hadolint/.hadolint.yaml}"
REPORT_DIR="${REPORT_DIR:-$MODULE_DIR/dockerfile-build-security/reports}"

ENVIRONMENT="${ENVIRONMENT:-pull_request}"
FAIL_ON_HADOLINT="${FAIL_ON_HADOLINT:-false}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
SAFE_FILE="$(echo "$DOCKERFILE" | tr '/:@' '____')"
REPORT_FILE="$REPORT_DIR/hadolint-$ENVIRONMENT-$SAFE_FILE-$TIMESTAMP.json"
SUMMARY_FILE="$REPORT_DIR/hadolint-summary-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== Hadolint Gate ====="
echo "Dockerfile: $DOCKERFILE"
echo "Config: $CONFIG_FILE"
echo "Environment: $ENVIRONMENT"
echo "Fail on Hadolint: $FAIL_ON_HADOLINT"

if [ ! -f "$DOCKERFILE" ]; then
  echo "ERROR: Dockerfile not found: $DOCKERFILE" >&2
  exit 1
fi

if command -v hadolint >/dev/null 2>&1; then
  HADOLINT_CMD=(hadolint --format json)
  if [ -f "$CONFIG_FILE" ]; then
    HADOLINT_CMD+=(--config "$CONFIG_FILE")
  fi
  HADOLINT_CMD+=("$DOCKERFILE")
else
  echo "WARN: hadolint binary not found; trying Docker image."
  HADOLINT_CMD=(docker run --rm -i hadolint/hadolint hadolint --format json -)
fi

set +e
if command -v hadolint >/dev/null 2>&1; then
  "${HADOLINT_CMD[@]}" > "$REPORT_FILE"
  HADOLINT_EXIT=$?
else
  docker run --rm -i hadolint/hadolint hadolint --format json - < "$DOCKERFILE" > "$REPORT_FILE"
  HADOLINT_EXIT=$?
fi
set -e

if [ ! -s "$REPORT_FILE" ]; then
  echo "[]" > "$REPORT_FILE"
fi

ERRORS="$(jq '[.[] | select(.level == "error")] | length' "$REPORT_FILE")"
WARNINGS="$(jq '[.[] | select(.level == "warning")] | length' "$REPORT_FILE")"
INFO="$(jq '[.[] | select(.level == "info")] | length' "$REPORT_FILE")"
TOTAL="$(jq 'length' "$REPORT_FILE")"

DECISION="passed"

case "$ENVIRONMENT" in
  production|main)
    if [ "$ERRORS" -gt 0 ] || [ "$FAIL_ON_HADOLINT" = "true" ] && [ "$TOTAL" -gt 0 ]; then
      DECISION="failed"
    fi
    ;;
  pull_request|dev)
    if [ "$FAIL_ON_HADOLINT" = "true" ] && [ "$ERRORS" -gt 0 ]; then
      DECISION="failed"
    fi
    ;;
esac

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "dockerfile_lint",
  "tool": "hadolint",
  "environment": "$ENVIRONMENT",
  "dockerfile": "$DOCKERFILE",
  "hadolint_exit_code": $HADOLINT_EXIT,
  "findings": {
    "total": $TOTAL,
    "error": $ERRORS,
    "warning": $WARNINGS,
    "info": $INFO
  },
  "decision": "$DECISION",
  "report_file": "$REPORT_FILE",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: Hadolint gate failed" >&2
  exit 1
fi

echo "Hadolint gate passed or reported only."
```

Make executable:

```bash id="zn8u50"
chmod +x dockerfile-build-security/scripts/hadolint-gate.sh
```

Run on insecure example:

```bash id="g871rl"
DOCKERFILE=./dockerfile-build-security/examples/Dockerfile.insecure \
ENVIRONMENT=pull_request \
FAIL_ON_HADOLINT=false \
./dockerfile-build-security/scripts/hadolint-gate.sh
```

Run on real Dockerfile:

```bash id="y8tar9"
DOCKERFILE=../05-application-runtime/demo-node-api/Dockerfile.industry \
ENVIRONMENT=main \
FAIL_ON_HADOLINT=false \
./dockerfile-build-security/scripts/hadolint-gate.sh
```

---

# 14. Custom Dockerfile Policy Gate

Hadolint is useful, but we want project-specific security rules.

Create:

```bash id="luakx9"
nano dockerfile-build-security/scripts/dockerfile-policy-gate.sh
```

Paste:

```bash id="35o1dg"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
MODULE_DIR="${MODULE_DIR:-$ROOT_DIR/09-devsecops-security-gates}"
DOCKERFILE="${DOCKERFILE:-$ROOT_DIR/05-application-runtime/demo-node-api/Dockerfile.industry}"
BUILD_CONTEXT="${BUILD_CONTEXT:-$(dirname "$DOCKERFILE")}"
REPORT_DIR="${REPORT_DIR:-$MODULE_DIR/dockerfile-build-security/reports}"

ENVIRONMENT="${ENVIRONMENT:-pull_request}"
FAIL_ON_POLICY="${FAIL_ON_POLICY:-true}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
SUMMARY_FILE="$REPORT_DIR/dockerfile-policy-summary-$ENVIRONMENT-$TIMESTAMP.json"
TEXT_REPORT="$REPORT_DIR/dockerfile-policy-$ENVIRONMENT-$TIMESTAMP.txt"

echo "===== Custom Dockerfile Policy Gate ====="
echo "Dockerfile: $DOCKERFILE"
echo "Build context: $BUILD_CONTEXT"
echo "Environment: $ENVIRONMENT"
echo "Fail on policy: $FAIL_ON_POLICY"

if [ ! -f "$DOCKERFILE" ]; then
  echo "ERROR: Dockerfile not found: $DOCKERFILE" >&2
  exit 1
fi

FAILED=0
WARNED=0

record_fail() {
  echo "FAIL: $*" | tee -a "$TEXT_REPORT"
  FAILED=1
}

record_warn() {
  echo "WARN: $*" | tee -a "$TEXT_REPORT"
  WARNED=1
}

record_pass() {
  echo "PASS: $*" | tee -a "$TEXT_REPORT"
}

: > "$TEXT_REPORT"

echo "Dockerfile policy report generated at $(date -u +"%Y-%m-%dT%H:%M:%SZ")" | tee -a "$TEXT_REPORT"
echo | tee -a "$TEXT_REPORT"

# Rule 1: no latest or untagged base image
if grep -En '^FROM[[:space:]]+[^[:space:]]+(:latest)?([[:space:]]|$)' "$DOCKERFILE" | grep -Ev '@sha256:' >/tmp/dockerfile-from-check.$$ 2>/dev/null; then
  while read -r line; do
    from_image="$(echo "$line" | sed -E 's/^[0-9]+:FROM[[:space:]]+([^[:space:]]+).*/\1/')"
    if [[ "$from_image" != *":"* ]] || [[ "$from_image" == *":latest" ]]; then
      record_fail "base image must use explicit non-latest tag or digest: $line"
    fi
  done < /tmp/dockerfile-from-check.$$
else
  record_pass "base image tags look explicit"
fi
rm -f /tmp/dockerfile-from-check.$$ || true

# Rule 2: no secret-like ARG or ENV
if grep -En '^(ARG|ENV)[[:space:]].*(SECRET|TOKEN|PASSWORD|PASSWD|API_KEY|ACCESS_KEY|PRIVATE_KEY|NPM_TOKEN|GITHUB_TOKEN)' "$DOCKERFILE" >/tmp/dockerfile-secret-check.$$ 2>/dev/null; then
  while read -r line; do
    record_fail "secret-like ARG/ENV found: $line"
  done < /tmp/dockerfile-secret-check.$$
else
  record_pass "no secret-like ARG/ENV found"
fi
rm -f /tmp/dockerfile-secret-check.$$ || true

# Rule 3: runtime USER should exist and not be root
LAST_USER="$(grep -En '^USER[[:space:]]+' "$DOCKERFILE" | tail -n 1 | sed -E 's/^[0-9]+:USER[[:space:]]+//' || true)"

if [ -z "$LAST_USER" ]; then
  record_fail "no USER instruction found; runtime may run as root"
else
  case "$LAST_USER" in
    root|0)
      record_fail "runtime USER is root: $LAST_USER"
      ;;
    *)
      record_pass "runtime USER is non-root: $LAST_USER"
      ;;
  esac
fi

# Rule 4: multi-stage build recommended/required for main/prod
FROM_COUNT="$(grep -Ec '^FROM[[:space:]]+' "$DOCKERFILE" || true)"
if [ "$FROM_COUNT" -lt 2 ]; then
  if [ "$ENVIRONMENT" = "production" ] || [ "$ENVIRONMENT" = "main" ]; then
    record_fail "multi-stage build required for $ENVIRONMENT"
  else
    record_warn "multi-stage build recommended"
  fi
else
  record_pass "multi-stage build detected: $FROM_COUNT stages"
fi

# Rule 5: .dockerignore required
if [ -f "$BUILD_CONTEXT/.dockerignore" ]; then
  record_pass ".dockerignore found"
else
  if [ "$ENVIRONMENT" = "production" ] || [ "$ENVIRONMENT" = "main" ]; then
    record_fail ".dockerignore required for $ENVIRONMENT"
  else
    record_warn ".dockerignore recommended"
  fi
fi

# Rule 6: do not copy local node_modules
if grep -En '^(COPY|ADD)[[:space:]].*node_modules' "$DOCKERFILE" >/tmp/dockerfile-node-modules-check.$$ 2>/dev/null; then
  while read -r line; do
    record_fail "Dockerfile should not COPY local node_modules: $line"
  done < /tmp/dockerfile-node-modules-check.$$
else
  record_pass "Dockerfile does not copy local node_modules directly"
fi
rm -f /tmp/dockerfile-node-modules-check.$$ || true

# Rule 7: prefer npm ci over npm install
if grep -En 'RUN[[:space:]].*npm install' "$DOCKERFILE" >/tmp/dockerfile-npm-install-check.$$ 2>/dev/null; then
  while read -r line; do
    record_warn "prefer npm ci over npm install in CI images: $line"
  done < /tmp/dockerfile-npm-install-check.$$
else
  record_pass "npm install pattern not found"
fi
rm -f /tmp/dockerfile-npm-install-check.$$ || true

# Rule 8: healthcheck recommended
if grep -Eq '^HEALTHCHECK[[:space:]]+' "$DOCKERFILE"; then
  record_pass "HEALTHCHECK found"
else
  record_warn "HEALTHCHECK recommended"
fi

DECISION="passed"

if [ "$FAILED" -ne 0 ] && [ "$FAIL_ON_POLICY" = "true" ]; then
  DECISION="failed"
elif [ "$WARNED" -ne 0 ]; then
  DECISION="warning"
fi

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "dockerfile_custom_policy",
  "tool": "custom",
  "environment": "$ENVIRONMENT",
  "dockerfile": "$DOCKERFILE",
  "build_context": "$BUILD_CONTEXT",
  "failed": $FAILED,
  "warned": $WARNED,
  "decision": "$DECISION",
  "text_report": "$TEXT_REPORT",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: Dockerfile policy gate failed" >&2
  exit 1
fi

echo "Dockerfile policy gate completed with decision: $DECISION"
```

Make executable:

```bash id="m8fm7u"
chmod +x dockerfile-build-security/scripts/dockerfile-policy-gate.sh
```

Run on insecure example:

```bash id="m9agew"
DOCKERFILE=./dockerfile-build-security/examples/Dockerfile.insecure \
BUILD_CONTEXT=./dockerfile-build-security/examples \
ENVIRONMENT=main \
FAIL_ON_POLICY=true \
./dockerfile-build-security/scripts/dockerfile-policy-gate.sh || true
```

Run on real Dockerfile:

```bash id="3o49nn"
DOCKERFILE=../05-application-runtime/demo-node-api/Dockerfile.industry \
BUILD_CONTEXT=../05-application-runtime/demo-node-api \
ENVIRONMENT=main \
FAIL_ON_POLICY=true \
./dockerfile-build-security/scripts/dockerfile-policy-gate.sh
```

---

# 15. Combined Dockerfile Security Gate

Create:

```bash id="3474bx"
nano dockerfile-build-security/scripts/dockerfile-security-gate.sh
```

Paste:

```bash id="li08jp"
#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="${MODULE_DIR:-$HOME/devops-masterclass/09-devsecops-security-gates}"
DOCKERFILE="${DOCKERFILE:-$HOME/devops-masterclass/05-application-runtime/demo-node-api/Dockerfile.industry}"
BUILD_CONTEXT="${BUILD_CONTEXT:-$(dirname "$DOCKERFILE")}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"

RUN_HADOLINT="${RUN_HADOLINT:-true}"
RUN_CUSTOM_POLICY="${RUN_CUSTOM_POLICY:-true}"
FAIL_ON_HADOLINT="${FAIL_ON_HADOLINT:-false}"
FAIL_ON_POLICY="${FAIL_ON_POLICY:-true}"

echo "===== Combined Dockerfile Security Gate ====="
echo "Dockerfile: $DOCKERFILE"
echo "Build context: $BUILD_CONTEXT"
echo "Environment: $ENVIRONMENT"

FAILED=0

cd "$MODULE_DIR"

if [ "$RUN_HADOLINT" = "true" ]; then
  echo
  echo "===== Running Hadolint ====="
  DOCKERFILE="$DOCKERFILE" \
  ENVIRONMENT="$ENVIRONMENT" \
  FAIL_ON_HADOLINT="$FAIL_ON_HADOLINT" \
  ./dockerfile-build-security/scripts/hadolint-gate.sh || FAILED=1
fi

if [ "$RUN_CUSTOM_POLICY" = "true" ]; then
  echo
  echo "===== Running Custom Dockerfile Policy ====="
  DOCKERFILE="$DOCKERFILE" \
  BUILD_CONTEXT="$BUILD_CONTEXT" \
  ENVIRONMENT="$ENVIRONMENT" \
  FAIL_ON_POLICY="$FAIL_ON_POLICY" \
  ./dockerfile-build-security/scripts/dockerfile-policy-gate.sh || FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
  echo "ERROR: Dockerfile security gate failed" >&2
  exit 1
fi

echo "Dockerfile security gate passed."
```

Make executable:

```bash id="et5dbn"
chmod +x dockerfile-build-security/scripts/dockerfile-security-gate.sh
```

Run:

```bash id="5ftusw"
DOCKERFILE=../05-application-runtime/demo-node-api/Dockerfile.industry \
BUILD_CONTEXT=../05-application-runtime/demo-node-api \
ENVIRONMENT=pull_request \
FAIL_ON_HADOLINT=false \
FAIL_ON_POLICY=true \
./dockerfile-build-security/scripts/dockerfile-security-gate.sh
```

---

# 16. Dockerfile Report Summary

Create:

```bash id="s8g3bo"
nano dockerfile-build-security/scripts/dockerfile-security-summary.sh
```

Paste:

```bash id="1w7dbz"
#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-dockerfile-build-security/reports}"

echo "===== Dockerfile Security Summary ====="
echo "Report dir: $REPORT_DIR"

find "$REPORT_DIR" -type f -name '*summary*.json' | sort | tail -n 10 | while read -r file; do
  echo
  echo "## $file"
  jq . "$file"
done

echo
echo "Recent text reports:"
find "$REPORT_DIR" -type f -name 'dockerfile-policy-*.txt' | sort | tail -n 10
```

Make executable:

```bash id="5qazy7"
chmod +x dockerfile-build-security/scripts/dockerfile-security-summary.sh
```

Run:

```bash id="femf56"
./dockerfile-build-security/scripts/dockerfile-security-summary.sh
```

---

# 17. `.dockerignore` Policy Check Script

Create:

```bash id="eu6oaf"
nano dockerfile-build-security/scripts/dockerignore-policy-gate.sh
```

Paste:

```bash id="44hnsq"
#!/usr/bin/env bash
set -euo pipefail

BUILD_CONTEXT="${BUILD_CONTEXT:-$HOME/devops-masterclass/05-application-runtime/demo-node-api}"
REPORT_DIR="${REPORT_DIR:-dockerfile-build-security/reports}"
FAIL_ON_MISSING="${FAIL_ON_MISSING:-true}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/dockerignore-policy-$TIMESTAMP.json"

DOCKERIGNORE="$BUILD_CONTEXT/.dockerignore"

REQUIRED_PATTERNS=(
  "node_modules"
  ".env"
  ".env.*"
  "*.pem"
  "*.key"
  "id_rsa"
  "id_ed25519"
  ".git"
)

MISSING=()

if [ ! -f "$DOCKERIGNORE" ]; then
  echo "ERROR: .dockerignore not found: $DOCKERIGNORE" >&2

  cat > "$REPORT_FILE" <<EOF
{
  "build_context": "$BUILD_CONTEXT",
  "dockerignore": "$DOCKERIGNORE",
  "exists": false,
  "missing_patterns": [],
  "decision": "failed",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

  cat "$REPORT_FILE" | jq .

  if [ "$FAIL_ON_MISSING" = "true" ]; then
    exit 1
  else
    exit 0
  fi
fi

for pattern in "${REQUIRED_PATTERNS[@]}"; do
  if ! grep -Fxq "$pattern" "$DOCKERIGNORE"; then
    MISSING+=("$pattern")
  fi
done

DECISION="passed"
if [ "${#MISSING[@]}" -gt 0 ]; then
  DECISION="failed"
fi

MISSING_JSON="$(printf '%s\n' "${MISSING[@]:-}" | jq -R . | jq -s .)"

cat > "$REPORT_FILE" <<EOF
{
  "build_context": "$BUILD_CONTEXT",
  "dockerignore": "$DOCKERIGNORE",
  "exists": true,
  "missing_patterns": $MISSING_JSON,
  "decision": "$DECISION",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$REPORT_FILE" | jq .

if [ "$DECISION" = "failed" ] && [ "$FAIL_ON_MISSING" = "true" ]; then
  echo "ERROR: .dockerignore policy failed" >&2
  exit 1
fi

echo ".dockerignore policy passed or reported only."
```

Make executable:

```bash id="z0vegg"
chmod +x dockerfile-build-security/scripts/dockerignore-policy-gate.sh
```

Run:

```bash id="gxyj8j"
BUILD_CONTEXT=../05-application-runtime/demo-node-api \
./dockerfile-build-security/scripts/dockerignore-policy-gate.sh
```

---

# 18. GitHub Actions Dockerfile Security Workflow

Create:

```bash id="052cyw"
nano dockerfile-build-security/github-actions/dockerfile-build-security.yml
```

Paste:

```yaml id="uw0klj"
name: Dockerfile Build Security

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
  APP_DIR: 05-application-runtime/demo-node-api
  DOCKERFILE_PATH: 05-application-runtime/demo-node-api/Dockerfile.industry

jobs:
  dockerfile-security:
    name: Hadolint and Dockerfile policy
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Run Hadolint Action
        uses: hadolint/hadolint-action@v3.1.0
        with:
          dockerfile: ${{ env.DOCKERFILE_PATH }}
          config: ${{ env.MODULE9_DIR }}/dockerfile-build-security/hadolint/.hadolint.yaml
          no-fail: true

      - name: Run custom Dockerfile security gate
        run: |
          cd "$MODULE9_DIR"

          if [ "${{ github.event_name }}" = "pull_request" ]; then
            ENVIRONMENT="pull_request"
            FAIL_HADOLINT="false"
          else
            ENVIRONMENT="main"
            FAIL_HADOLINT="true"
          fi

          DOCKERFILE="$GITHUB_WORKSPACE/$DOCKERFILE_PATH" \
          BUILD_CONTEXT="$GITHUB_WORKSPACE/$APP_DIR" \
          ENVIRONMENT="$ENVIRONMENT" \
          FAIL_ON_HADOLINT="$FAIL_HADOLINT" \
          FAIL_ON_POLICY=true \
          ./dockerfile-build-security/scripts/dockerfile-security-gate.sh

      - name: Validate dockerignore
        run: |
          cd "$MODULE9_DIR"
          BUILD_CONTEXT="$GITHUB_WORKSPACE/$APP_DIR" \
          ./dockerfile-build-security/scripts/dockerignore-policy-gate.sh

      - name: Upload Dockerfile security reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: dockerfile-security-reports
          path: 09-devsecops-security-gates/dockerfile-build-security/reports/
```

Copy:

```bash id="rxpdhh"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/dockerfile-build-security/github-actions/dockerfile-build-security.yml \
   .github/workflows/dockerfile-build-security.yml
```

---

# 19. Jenkins Dockerfile Security Pipeline

Create:

```bash id="w89oqd"
nano dockerfile-build-security/jenkins/Jenkinsfile.dockerfile-build-security
```

Paste:

```groovy id="uw5c5k"
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
  }

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['pull_request', 'main', 'production'], description: 'Gate environment')
    booleanParam(name: 'FAIL_ON_HADOLINT', defaultValue: false, description: 'Fail on Hadolint findings?')
  }

  environment {
    MODULE9_DIR = '09-devsecops-security-gates'
    APP_DIR = '05-application-runtime/demo-node-api'
    DOCKERFILE_PATH = '05-application-runtime/demo-node-api/Dockerfile.industry'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Dockerfile Security Gate') {
      steps {
        dir("${MODULE9_DIR}") {
          sh '''
            DOCKERFILE="$WORKSPACE/${DOCKERFILE_PATH}" \
            BUILD_CONTEXT="$WORKSPACE/${APP_DIR}" \
            ENVIRONMENT="${ENVIRONMENT}" \
            FAIL_ON_HADOLINT="${FAIL_ON_HADOLINT}" \
            FAIL_ON_POLICY=true \
            ./dockerfile-build-security/scripts/dockerfile-security-gate.sh
          '''
        }
      }
    }

    stage('Dockerignore Policy') {
      steps {
        dir("${MODULE9_DIR}") {
          sh '''
            BUILD_CONTEXT="$WORKSPACE/${APP_DIR}" \
            ./dockerfile-build-security/scripts/dockerignore-policy-gate.sh
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '09-devsecops-security-gates/dockerfile-build-security/reports/**/*', allowEmptyArchive: true
    }

    success {
      echo 'Dockerfile security gate passed.'
    }

    failure {
      echo 'Dockerfile security gate failed. Review archived reports.'
    }
  }
}
```

Jenkins job script path:

```text id="sipcqk"
09-devsecops-security-gates/dockerfile-build-security/jenkins/Jenkinsfile.dockerfile-build-security
```

---

# 20. GitLab CI Dockerfile Security Pipeline

Create:

```bash id="0112zf"
nano dockerfile-build-security/gitlab/.gitlab-ci.dockerfile-build-security.yml
```

Paste:

```yaml id="z3mn1q"
stages:
  - dockerfile_security

variables:
  MODULE9_DIR: "09-devsecops-security-gates"
  APP_DIR: "05-application-runtime/demo-node-api"
  DOCKERFILE_PATH: "05-application-runtime/demo-node-api/Dockerfile.industry"

dockerfile_security:
  stage: dockerfile_security
  image: alpine:3.20
  before_script:
    - apk add --no-cache bash jq curl docker-cli
    - curl -L https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64 -o /usr/local/bin/hadolint
    - chmod +x /usr/local/bin/hadolint
    - hadolint --version
  script:
    - cd "$MODULE9_DIR"
    - |
      if [ "${CI_COMMIT_BRANCH:-}" = "main" ]; then
        ENVIRONMENT="main"
        FAIL_HADOLINT="true"
      else
        ENVIRONMENT="pull_request"
        FAIL_HADOLINT="false"
      fi

      DOCKERFILE="$CI_PROJECT_DIR/$DOCKERFILE_PATH" \
      BUILD_CONTEXT="$CI_PROJECT_DIR/$APP_DIR" \
      ENVIRONMENT="$ENVIRONMENT" \
      FAIL_ON_HADOLINT="$FAIL_HADOLINT" \
      FAIL_ON_POLICY=true \
      ./dockerfile-build-security/scripts/dockerfile-security-gate.sh

    - |
      BUILD_CONTEXT="$CI_PROJECT_DIR/$APP_DIR" \
      ./dockerfile-build-security/scripts/dockerignore-policy-gate.sh
  artifacts:
    when: always
    expire_in: 30 days
    paths:
      - 09-devsecops-security-gates/dockerfile-build-security/reports/
```

---

# 21. Dockerfile Security Runbook

Create:

```bash id="w2udbh"
nano dockerfile-build-security/runbooks/dockerfile-security-runbook.md
```

Paste:

````markdown id="gtxqpm"
# Dockerfile Security Runbook

## Goal

Review and fix Dockerfile security issues before building production images.

## Local Checks

Run Hadolint:

```bash
hadolint 05-application-runtime/demo-node-api/Dockerfile.industry
````

Run custom policy:

```bash id="ojlizr"
cd 09-devsecops-security-gates

DOCKERFILE=../05-application-runtime/demo-node-api/Dockerfile.industry \
BUILD_CONTEXT=../05-application-runtime/demo-node-api \
ENVIRONMENT=main \
./dockerfile-build-security/scripts/dockerfile-security-gate.sh
```

## Common Findings

### latest base image

Bad:

```Dockerfile
FROM node:latest
```

Better:

```Dockerfile id="ejcg8y"
FROM node:22-alpine
```

Best for strict production:

```Dockerfile id="dnw8oz"
FROM node@sha256:<digest>
```

### root runtime user

Bad:

```Dockerfile id="jyclur"
CMD ["node", "server.js"]
```

Better:

```Dockerfile id="em9lhc"
USER node
CMD ["node", "server.js"]
```

### secrets in ARG/ENV

Bad:

```Dockerfile id="is0tg0"
ARG NPM_TOKEN
ENV API_KEY=value
```

Better:

```Dockerfile id="y7hlsm"
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci
```

### missing .dockerignore

Add:

```text id="hshfjw"
node_modules
.env
.env.*
*.pem
*.key
.git
```

## Production Rules

* no `latest`
* no root runtime user
* no secret-like ARG/ENV
* `.dockerignore` required
* multi-stage build required
* image scan required after build

````

---

# 22. Multi-Stage Build Hardening Runbook

Create:

```bash id="sx3i3p"
nano dockerfile-build-security/runbooks/multi-stage-build-hardening.md
````

Paste:

````markdown id="sfi00a"
# Multi-Stage Build Hardening

## Goal

Keep build tools, dev dependencies, and temporary files out of the runtime image.

## Pattern

```Dockerfile
FROM node:22-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY --from=deps /app/node_modules ./node_modules
COPY . .
USER node
CMD ["node", "server.js"]
````

## Why

Build stages can contain:

* compilers
* package managers
* cache files
* dev dependencies
* temporary artifacts

The runtime stage should contain only what is needed to run.

## Validate

```bash
docker build -f Dockerfile.industry --target runtime -t app:secure .
docker run --rm app:secure id
docker image inspect app:secure
```

````

---

# 23. Build Context Security Runbook

Create:

```bash id="2y9452"
nano dockerfile-build-security/runbooks/build-context-security.md
````

Paste:

````markdown id="e7md3l"
# Build Context Security

## Goal

Prevent sensitive or unnecessary files from being sent to the Docker builder.

## Use .dockerignore

Recommended:

```text
node_modules
.env
.env.*
*.pem
*.key
id_rsa
id_ed25519
.git
coverage
logs
*.log
````

## Why It Matters

Docker sends the build context to the builder.
If sensitive files are in the context, they can accidentally be copied into the image or exposed to a remote builder.

## Check Context

```bash
docker build --no-cache --progress=plain .
```

Watch what files are copied and what the context size is.

## Production Rules

* keep context small
* exclude secrets
* exclude local dependencies
* exclude Git metadata unless explicitly needed
* do not COPY everything unless `.dockerignore` is strong

````

---

# 24. Validation Script

Create:

```bash id="p75roc"
nano dockerfile-build-security/scripts/validate-dockerfile-build-security-lesson.sh
````

Paste:

```bash id="tl9s9k"
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-dockerfile-build-security}"

echo "===== Validate Dockerfile Build Security Lesson ====="

test -f "$BASE_DIR/policies/dockerfile-security-policy.json"
test -f "$BASE_DIR/notes/dockerfile-security-mental-model.md"
test -f "$BASE_DIR/hadolint/.hadolint.yaml"
test -f "$BASE_DIR/examples/Dockerfile.insecure"
test -f "$BASE_DIR/examples/Dockerfile.secure-node"
test -x "$BASE_DIR/scripts/hadolint-gate.sh"
test -x "$BASE_DIR/scripts/dockerfile-policy-gate.sh"
test -x "$BASE_DIR/scripts/dockerfile-security-gate.sh"
test -x "$BASE_DIR/scripts/dockerfile-security-summary.sh"
test -x "$BASE_DIR/scripts/dockerignore-policy-gate.sh"
test -f "$BASE_DIR/github-actions/dockerfile-build-security.yml"
test -f "$BASE_DIR/jenkins/Jenkinsfile.dockerfile-build-security"
test -f "$BASE_DIR/gitlab/.gitlab-ci.dockerfile-build-security.yml"
test -f "$BASE_DIR/runbooks/dockerfile-security-runbook.md"
test -f "$BASE_DIR/runbooks/multi-stage-build-hardening.md"
test -f "$BASE_DIR/runbooks/build-context-security.md"

echo "Dockerfile build security lesson validated."
```

Make executable:

```bash id="xsd2dh"
chmod +x dockerfile-build-security/scripts/validate-dockerfile-build-security-lesson.sh
```

Run:

```bash id="6bhdd4"
./dockerfile-build-security/scripts/validate-dockerfile-build-security-lesson.sh
```

---

# 25. Update Makefile

Open:

```bash id="5gmuqk"
cd ~/devops-masterclass/09-devsecops-security-gates

nano Makefile
```

Add:

```Makefile id="wluxmb"
.PHONY: dockerfile-validate dockerfile-gate dockerfile-summary dockerignore-gate dockerfile-insecure-test

dockerfile-validate:
	./dockerfile-build-security/scripts/validate-dockerfile-build-security-lesson.sh

dockerfile-gate:
	DOCKERFILE="$${DOCKERFILE:-../05-application-runtime/demo-node-api/Dockerfile.industry}" \
	BUILD_CONTEXT="$${BUILD_CONTEXT:-../05-application-runtime/demo-node-api}" \
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_HADOLINT="$${FAIL_ON_HADOLINT:-false}" \
	FAIL_ON_POLICY="$${FAIL_ON_POLICY:-true}" \
	./dockerfile-build-security/scripts/dockerfile-security-gate.sh

dockerignore-gate:
	BUILD_CONTEXT="$${BUILD_CONTEXT:-../05-application-runtime/demo-node-api}" \
	./dockerfile-build-security/scripts/dockerignore-policy-gate.sh

dockerfile-summary:
	./dockerfile-build-security/scripts/dockerfile-security-summary.sh

dockerfile-insecure-test:
	DOCKERFILE="./dockerfile-build-security/examples/Dockerfile.insecure" \
	BUILD_CONTEXT="./dockerfile-build-security/examples" \
	ENVIRONMENT=main \
	FAIL_ON_POLICY=true \
	./dockerfile-build-security/scripts/dockerfile-security-gate.sh || true
```

Run:

```bash id="l9odzh"
make dockerfile-validate
make dockerfile-insecure-test
make dockerfile-gate
make dockerignore-gate
make dockerfile-summary
```

---

# 26. Practical Lab

Run:

```bash id="ncmxf7"
cd ~/devops-masterclass/09-devsecops-security-gates

make dockerfile-validate

make dockerfile-insecure-test

DOCKERFILE=../05-application-runtime/demo-node-api/Dockerfile.industry \
BUILD_CONTEXT=../05-application-runtime/demo-node-api \
ENVIRONMENT=pull_request \
FAIL_ON_HADOLINT=false \
FAIL_ON_POLICY=true \
make dockerfile-gate

make dockerignore-gate
make dockerfile-summary
```

Copy GitHub workflow:

```bash id="f4kuoz"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/dockerfile-build-security/github-actions/dockerfile-build-security.yml \
   .github/workflows/dockerfile-build-security.yml
```

Commit:

```bash id="0egx5e"
git status

git add .github/workflows/dockerfile-build-security.yml \
        09-devsecops-security-gates \
        05-application-runtime/demo-node-api/.dockerignore

git commit -m "feat: add Dockerfile and build security gates"
git push
```

---

# 27. Common Dockerfile Security Problems

## Hadolint complains about package pinning

For learning, warn first. For production, decide whether your team pins OS packages or relies on base image updates.

## Dockerfile has no `USER`

Add:

```Dockerfile id="tyyxll"
USER node
```

Then ensure files are readable by that user.

## App fails after switching to non-root

Fix ownership:

```Dockerfile id="v58gks"
COPY --chown=node:node . .
USER node
```

## `.dockerignore` breaks build

You may be excluding files the Dockerfile tries to copy. Docker documents that files ignored by `.dockerignore` are not in the build context and cannot be copied into the image. ([Docker Documentation][6])

## Need private npm token during build

Do not use `ARG NPM_TOKEN`.

Use BuildKit secret mount:

```bash id="pj3i8h"
DOCKER_BUILDKIT=1 docker build \
  --secret id=npmrc,src="$HOME/.npmrc" \
  .
```

## Multi-stage build is confusing

Use names:

```Dockerfile id="x8rz58"
FROM node:22-alpine AS deps
FROM node:22-alpine AS runtime
COPY --from=deps /app/node_modules ./node_modules
```

Docker’s multi-stage docs specifically recommend naming build stages to make Dockerfiles easier to maintain. ([Docker Documentation][4])

---

# 28. Interview Explanation

## What is Dockerfile security?

```text id="4fljpv"
Dockerfile security means writing build instructions that produce a reproducible, minimal, least-privilege container image without leaking secrets or unnecessary files into the final runtime artifact.
```

## Why use Hadolint?

```text id="v1uall"
Hadolint automatically checks Dockerfiles for common best-practice and security issues, such as untagged images, unsafe package manager usage, shell mistakes, and root runtime user patterns.
```

## Why avoid `latest`?

```text id="r7thj2"
`latest` is mutable and makes builds less reproducible. If the base image changes unexpectedly, the same Dockerfile can produce different images, which makes scanning, debugging, rollback, and compliance harder.
```

## Why run containers as non-root?

```text id="3dg8se"
Running as non-root reduces the impact if the application or container process is compromised. It limits what the process can modify inside the container and supports least-privilege runtime design.
```

## Why avoid secrets in `ARG` and `ENV`?

```text id="sozv92"
ARG and ENV values can appear in image metadata, build history, logs, or layers. Build-time secrets should use BuildKit secret mounts, and runtime secrets should come from the deployment platform or secret manager.
```

## Why use `.dockerignore`?

```text id="n9h5es"
`.dockerignore` prevents unnecessary or sensitive files from being sent to the Docker build context. This reduces build time and lowers the chance of accidentally copying secrets, local dependencies, logs, or Git metadata into the image.
```

---

# 29. Today’s Core Rules

```text id="iluxn2"
Scan Dockerfiles before building images.
Use Hadolint plus custom policy.
Do not use latest for production images.
Run runtime containers as non-root.
Do not put secrets in ARG or ENV.
Use BuildKit secrets for build-time secrets.
Use .dockerignore to protect build context.
Use multi-stage builds for clean runtime images.
Do not copy local node_modules into images.
Prefer npm ci over npm install in CI images.
Archive Dockerfile security reports.
Image scanning still runs after Dockerfile checks.
```

---

# Next Lesson

# Lesson 9.7 — IaC Security Scanning with Checkov and Trivy Config

We will build:

```text id="1gt7px"
Terraform security scanning
Checkov basics
Trivy config scanning
AWS S3 public access checks
security group rule checks
IAM wildcard policy checks
CloudFront/S3 policy checks
GitHub Actions IaC scanning
Jenkins IaC scanning
GitLab CI IaC scanning
IaC exception handling
production-ready IaC security gate
```

[1]: https://docs.docker.com/build/building/best-practices/?utm_source=chatgpt.com "Building best practices"
[2]: https://github.com/hadolint/hadolint?utm_source=chatgpt.com "Dockerfile linter, validate inline bash, written in Haskell"
[3]: https://github.com/hadolint/hadolint-action?utm_source=chatgpt.com "Hadolint Action"
[4]: https://docs.docker.com/build/building/multi-stage/?utm_source=chatgpt.com "Multi-stage builds"
[5]: https://docs.docker.com/build/concepts/context/?utm_source=chatgpt.com "Build context"
[6]: https://docs.docker.com/reference/build-checks/copy-ignored-file/?utm_source=chatgpt.com "CopyIgnoredFile"
[7]: https://docs.docker.com/build/building/secrets/?utm_source=chatgpt.com "Build secrets"

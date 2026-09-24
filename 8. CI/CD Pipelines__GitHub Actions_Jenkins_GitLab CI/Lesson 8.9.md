# Lesson 8.9 — Quality Gates and DevSecOps Checks in CI/CD

# Lint, Format, Tests, Coverage, Secret Scanning, Dependency Review, Container Scanning, SBOM Validation, License Policy, IaC Scanning, and Fail-vs-Warn Strategy

This lesson is where CI/CD becomes serious.

A beginner pipeline says:

```text id="2syb0m"
npm test passed, so deploy.
```

A production pipeline says:

```text id="iwldo3"
Before deployment, prove the code, dependencies, container image, secrets, infrastructure, licenses, and artifact evidence meet policy.
```

That is the purpose of **quality gates**.

GitHub’s dependency review action can scan pull requests for dependency changes and fail when vulnerabilities or invalid licenses are introduced. Trivy can scan container images, filesystems, Git repositories, Kubernetes, SBOMs, and IaC for security issues. GitLab provides built-in application security testing features, including SAST, dependency, container, and secret detection capabilities depending on configuration/tier. Jenkins can enforce quality gates through plugins such as Warnings Next Generation, where failed gates can mark builds unstable or failed. ([GitHub][1])

---

# 1. What Is a Quality Gate?

A quality gate is a rule that decides whether the pipeline can continue.

Examples:

```text id="30jijj"
tests must pass
coverage must be above 80%
no critical vulnerabilities
no committed secrets
Dockerfile must follow security policy
SBOM must exist
production image must not use latest
release metadata must exist
license policy must pass
Terraform must be formatted and valid
```

Pipeline without gates:

```text id="sl4t81"
run commands
hope everything is fine
```

Pipeline with gates:

```text id="0kzxtb"
validate
measure
enforce
block unsafe releases
```

Professional definition:

```text id="tco92z"
A quality gate is an automated release control that converts engineering policy into a pass, fail, or warning decision.
```

---

# 2. Gate Severity Model

Not every issue should fail the pipeline immediately.

Use three levels:

```text id="8fhugs"
FAIL:
  stop pipeline

WARN:
  mark warning/unstable, but continue

REPORT:
  collect evidence only
```

Example policy:

```text id="wvhud0"
unit tests failed:
  FAIL

critical vulnerability in production image:
  FAIL

medium vulnerability in dev branch:
  WARN

license unknown in new dependency:
  WARN or FAIL depending policy

coverage slightly below target:
  WARN initially, FAIL later

SBOM missing for production artifact:
  FAIL

secret detected:
  FAIL
```

Professional rule:

```text id="asb5ut"
Fail on risks that make deployment unsafe. Warn on risks that need visibility but should not block early development.
```

---

# 3. CI/CD Gate Categories

Production pipelines usually include these gates:

```text id="a17wh0"
source gates:
  branch rules, PR rules, signed commits if required

code quality gates:
  lint, format, complexity, type checks

test gates:
  unit, integration, smoke, coverage

secret gates:
  committed secrets, unsafe env dumps, .env files

dependency gates:
  vulnerable dependencies, outdated dependencies, license policy

container gates:
  image scan, Dockerfile policy, root user, capabilities

artifact gates:
  immutable tag, SBOM, provenance, signature, release metadata

IaC gates:
  terraform fmt/validate/plan scan, misconfiguration checks

deployment gates:
  environment approval, health checks, version checks

rollback gates:
  previous artifact known and retained
```

---

# 4. Quality Gate Maturity Levels

## Level 1 — Basic CI

```text id="b8d06n"
npm test
```

## Level 2 — Code Quality

```text id="8gi3zh"
lint
format
unit tests
```

## Level 3 — Security Checks

```text id="xsjwb7"
secret scan
dependency scan
container scan
```

## Level 4 — Artifact Trust

```text id="u1djzo"
SBOM
provenance
signing
release metadata
```

## Level 5 — Policy-as-Code

```text id="9c39bn"
OPA/Conftest
Checkov
tfsec
Hadolint
custom gates
```

## Level 6 — Risk-Based Release

```text id="kdrne1"
fail/warn/report by environment
exceptions with expiry
approvals
audit records
SLO-aware deployment
```

Your target in this module:

```text id="3av76q"
Level 4 now.
Level 5+ in DevSecOps and Kubernetes modules.
```

---

# 5. Quality Gate Policy for Your Project

Create a policy first.

Run:

```bash id="s6tk48"
cd ~/devops-masterclass/08-cicd-pipelines

mkdir -p quality-gates/{policies,scripts,github-actions,jenkins,gitlab,notes,runbooks,reports,examples}
```

Create:

```bash id="02sn2z"
nano quality-gates/policies/demo-node-api-quality-gates.json
```

Paste:

```json id="9l5o8v"
{
  "service_name": "demo-node-api",
  "policy_version": "1.0",
  "environments": {
    "pull_request": {
      "tests": "fail",
      "lint": "warn",
      "format": "warn",
      "secret_scan": "fail",
      "dependency_scan": "warn",
      "container_scan": "report",
      "sbom_required": false
    },
    "main": {
      "tests": "fail",
      "lint": "fail",
      "format": "fail",
      "secret_scan": "fail",
      "dependency_scan": "fail_on_high_or_critical",
      "container_scan": "fail_on_critical",
      "sbom_required": true
    },
    "production": {
      "tests": "fail",
      "lint": "fail",
      "format": "fail",
      "secret_scan": "fail",
      "dependency_scan": "fail_on_high_or_critical",
      "container_scan": "fail_on_high_or_critical",
      "sbom_required": true,
      "provenance_required": true,
      "signature_required": true,
      "release_metadata_required": true,
      "rollback_version_required": true
    }
  },
  "forbidden": {
    "image_tags": ["latest", "prod", "production", "stable"],
    "files": [".env", ".env.production", "id_rsa", "id_ed25519"],
    "docker": {
      "root_user": true,
      "secret_in_build_args": true
    }
  }
}
```

This becomes your quality gate contract.

---

# 6. Add Node.js Quality Scripts

Go to your app:

```bash id="l0oxwg"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Check current scripts:

```bash id="9xrv7s"
cat package.json | jq '.scripts'
```

Add safe baseline scripts if missing:

```bash id="wm681k"
npm pkg set scripts.ci="npm ci && npm test"
npm pkg set scripts.lint="node scripts/lint-placeholder.js"
npm pkg set scripts.format:check="node scripts/format-placeholder.js"
npm pkg set scripts.coverage="npm test -- --coverage=false"
```

Create placeholder lint script:

```bash id="gnmjjf"
mkdir -p scripts

cat > scripts/lint-placeholder.js <<'EOF'
console.log("Lint placeholder passed.");
console.log("Later: replace with ESLint.");
process.exit(0);
EOF
```

Create placeholder format script:

```bash id="wpzfu3"
cat > scripts/format-placeholder.js <<'EOF'
console.log("Format placeholder passed.");
console.log("Later: replace with Prettier --check.");
process.exit(0);
EOF
```

Why placeholders?

```text id="b81tuz"
Your production pipeline structure becomes ready now.
Actual ESLint/Prettier configuration can be added without redesigning CI/CD.
```

Run:

```bash id="206lfd"
npm run lint
npm run format:check
npm test
```

---

# 7. Secret Scanning Gate

You already created a basic scanner in Lesson 8.8.

Now create a quality-gate wrapper.

Run:

```bash id="xjqais"
cd ~/devops-masterclass/08-cicd-pipelines
```

Create:

```bash id="lvveo2"
nano quality-gates/scripts/secret-gate.sh
```

Paste:

```bash id="bhbmxq"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
REPORT_DIR="${REPORT_DIR:-$ROOT_DIR/08-cicd-pipelines/quality-gates/reports}"
FAIL_ON_FINDINGS="${FAIL_ON_FINDINGS:-true}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/secret-gate-$TIMESTAMP.txt"

mkdir -p "$REPORT_DIR"

echo "===== Secret Gate ====="
echo "Root: $ROOT_DIR"
echo "Fail on findings: $FAIL_ON_FINDINGS"

cd "$ROOT_DIR"

PATTERNS_FOUND=0

{
  echo "Secret gate generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo

  echo "## AWS access key-like patterns"
  if grep -RInE 'AKIA[0-9A-Z]{16}' . \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude-dir=coverage \
    --exclude-dir=reports; then
    PATTERNS_FOUND=1
  fi

  echo
  echo "## Private key patterns"
  if grep -RInE 'BEGIN (RSA |OPENSSH |EC |DSA |)PRIVATE KEY' . \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude-dir=coverage \
    --exclude-dir=reports; then
    PATTERNS_FOUND=1
  fi

  echo
  echo "## Forbidden env files"
  if find . \
    -path './.git' -prune -o \
    -path './**/node_modules' -prune -o \
    -type f \( -name '.env' -o -name '.env.production' -o -name 'id_rsa' -o -name 'id_ed25519' \) \
    -print | grep .; then
    PATTERNS_FOUND=1
  fi
} | tee "$REPORT_FILE"

echo
echo "Report: $REPORT_FILE"

if [ "$PATTERNS_FOUND" -ne 0 ] && [ "$FAIL_ON_FINDINGS" = "true" ]; then
  echo "ERROR: secret gate failed. Review $REPORT_FILE" >&2
  exit 1
fi

echo "Secret gate passed or reported only."
```

Make executable:

```bash id="4u7xkn"
chmod +x quality-gates/scripts/secret-gate.sh
```

Run:

```bash id="pm53fb"
FAIL_ON_FINDINGS=false ./quality-gates/scripts/secret-gate.sh
```

For real blocking mode:

```bash id="9q5yxm"
FAIL_ON_FINDINGS=true ./quality-gates/scripts/secret-gate.sh
```

---

# 8. Dependency Gate

For Node.js, use:

```bash id="hh3st7"
npm audit
```

Create:

```bash id="bz54gj"
nano quality-gates/scripts/npm-audit-gate.sh
```

Paste:

```bash id="e0d7lz"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
APP_DIR="${APP_DIR:-$ROOT_DIR/05-application-runtime/demo-node-api}"
REPORT_DIR="${REPORT_DIR:-$ROOT_DIR/08-cicd-pipelines/quality-gates/reports}"
AUDIT_LEVEL="${AUDIT_LEVEL:-high}"
FAIL_ON_AUDIT="${FAIL_ON_AUDIT:-true}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/npm-audit-$TIMESTAMP.json"

mkdir -p "$REPORT_DIR"

echo "===== NPM Audit Gate ====="
echo "App: $APP_DIR"
echo "Audit level: $AUDIT_LEVEL"
echo "Fail on audit: $FAIL_ON_AUDIT"

cd "$APP_DIR"

if [ "$FAIL_ON_AUDIT" = "true" ]; then
  npm audit --audit-level="$AUDIT_LEVEL" --json | tee "$REPORT_FILE"
else
  npm audit --audit-level="$AUDIT_LEVEL" --json | tee "$REPORT_FILE" || true
fi

echo
echo "Report: $REPORT_FILE"
```

Make executable:

```bash id="y88nkx"
chmod +x quality-gates/scripts/npm-audit-gate.sh
```

Run report mode:

```bash id="3qjccw"
FAIL_ON_AUDIT=false ./quality-gates/scripts/npm-audit-gate.sh
```

Run strict mode:

```bash id="acfl42"
AUDIT_LEVEL=high FAIL_ON_AUDIT=true ./quality-gates/scripts/npm-audit-gate.sh
```

Professional note:

```text id="ej6l8l"
Dependency gates should include an exception process, because not every vulnerability is exploitable in your runtime context.
```

---

# 9. Container Scan Gate

Create:

```bash id="cpo78s"
nano quality-gates/scripts/container-scan-gate.sh
```

Paste:

```bash id="55t9wd"
#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF="${IMAGE_REF:-}"
REPORT_DIR="${REPORT_DIR:-$HOME/devops-masterclass/08-cicd-pipelines/quality-gates/reports}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
FAIL_ON_SCAN="${FAIL_ON_SCAN:-true}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/container-scan-$TIMESTAMP.json"

if [ -z "$IMAGE_REF" ]; then
  echo "ERROR: IMAGE_REF is required" >&2
  exit 1
fi

mkdir -p "$REPORT_DIR"

echo "===== Container Scan Gate ====="
echo "Image: $IMAGE_REF"
echo "Severity: $SEVERITY"
echo "Fail on scan: $FAIL_ON_SCAN"

if ! command -v trivy >/dev/null 2>&1; then
  echo "ERROR: trivy is required" >&2
  exit 1
fi

if [ "$FAIL_ON_SCAN" = "true" ]; then
  trivy image \
    --severity "$SEVERITY" \
    --exit-code 1 \
    --format json \
    --output "$REPORT_FILE" \
    "$IMAGE_REF"
else
  trivy image \
    --severity "$SEVERITY" \
    --exit-code 0 \
    --format json \
    --output "$REPORT_FILE" \
    "$IMAGE_REF" || true
fi

cat "$REPORT_FILE" | jq '.Results | length' || true

echo
echo "Report: $REPORT_FILE"
```

Make executable:

```bash id="guw938"
chmod +x quality-gates/scripts/container-scan-gate.sh
```

Run after building image:

```bash id="y9gtcm"
IMAGE_REF=demo-node-api:0.8.0-dev-local \
FAIL_ON_SCAN=false \
./quality-gates/scripts/container-scan-gate.sh
```

Trivy supports scanning container images and other targets for vulnerabilities and misconfigurations. ([GitHub][2])

---

# 10. Dockerfile Gate

Create a simple Dockerfile policy gate.

Create:

```bash id="n7bcj8"
nano quality-gates/scripts/dockerfile-gate.sh
```

Paste:

```bash id="9xl8sf"
#!/usr/bin/env bash
set -euo pipefail

DOCKERFILE="${DOCKERFILE:-$HOME/devops-masterclass/05-application-runtime/demo-node-api/Dockerfile.industry}"
REPORT_DIR="${REPORT_DIR:-$HOME/devops-masterclass/08-cicd-pipelines/quality-gates/reports}"
FAIL_ON_FINDINGS="${FAIL_ON_FINDINGS:-true}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/dockerfile-gate-$TIMESTAMP.txt"

mkdir -p "$REPORT_DIR"

echo "===== Dockerfile Gate ====="
echo "Dockerfile: $DOCKERFILE"

if [ ! -f "$DOCKERFILE" ]; then
  echo "ERROR: Dockerfile not found: $DOCKERFILE" >&2
  exit 1
fi

FAILED=0

{
  echo "Dockerfile gate generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo

  echo "## Check USER instruction"
  if grep -Eq '^USER[[:space:]]+node|^USER[[:space:]]+[0-9]+' "$DOCKERFILE"; then
    echo "PASS: USER instruction found"
  else
    echo "FAIL: no non-root USER instruction found"
    FAILED=1
  fi

  echo
  echo "## Check latest tag"
  if grep -Eq '^FROM[[:space:]].*:latest' "$DOCKERFILE"; then
    echo "FAIL: base image uses latest"
    FAILED=1
  else
    echo "PASS: no FROM latest found"
  fi

  echo
  echo "## Check secret-like build args"
  if grep -Ei 'ARG .*secret|ARG .*token|ARG .*password|ENV .*secret|ENV .*token|ENV .*password' "$DOCKERFILE"; then
    echo "FAIL: possible secret-like ARG/ENV found"
    FAILED=1
  else
    echo "PASS: no obvious secret-like ARG/ENV found"
  fi

  echo
  echo "## Check healthcheck"
  if grep -Eq '^HEALTHCHECK' "$DOCKERFILE"; then
    echo "PASS: HEALTHCHECK found"
  else
    echo "WARN: no HEALTHCHECK found"
  fi
} | tee "$REPORT_FILE"

echo
echo "Report: $REPORT_FILE"

if [ "$FAILED" -ne 0 ] && [ "$FAIL_ON_FINDINGS" = "true" ]; then
  echo "ERROR: Dockerfile gate failed" >&2
  exit 1
fi

echo "Dockerfile gate passed or reported only."
```

Make executable:

```bash id="wbnyom"
chmod +x quality-gates/scripts/dockerfile-gate.sh
```

Run:

```bash id="4y3u8q"
./quality-gates/scripts/dockerfile-gate.sh
```

---

# 11. SBOM Gate

Create:

```bash id="zjtyld"
nano quality-gates/scripts/sbom-gate.sh
```

Paste:

```bash id="eud42k"
#!/usr/bin/env bash
set -euo pipefail

SBOM_FILE="${SBOM_FILE:-}"
MIN_COMPONENTS="${MIN_COMPONENTS:-1}"

if [ -z "$SBOM_FILE" ]; then
  echo "ERROR: SBOM_FILE is required" >&2
  exit 1
fi

if [ ! -f "$SBOM_FILE" ]; then
  echo "ERROR: SBOM file not found: $SBOM_FILE" >&2
  exit 1
fi

echo "===== SBOM Gate ====="
echo "SBOM: $SBOM_FILE"

if ! jq empty "$SBOM_FILE" >/dev/null 2>&1; then
  echo "ERROR: SBOM is not valid JSON" >&2
  exit 1
fi

BOM_FORMAT="$(jq -r '.bomFormat // empty' "$SBOM_FILE")"
SPDX_ID="$(jq -r '.spdxVersion // empty' "$SBOM_FILE")"

if [ -n "$BOM_FORMAT" ]; then
  echo "Detected CycloneDX-like SBOM: $BOM_FORMAT"
  COMPONENT_COUNT="$(jq '.components // [] | length' "$SBOM_FILE")"
elif [ -n "$SPDX_ID" ]; then
  echo "Detected SPDX-like SBOM: $SPDX_ID"
  COMPONENT_COUNT="$(jq '.packages // [] | length' "$SBOM_FILE")"
else
  echo "ERROR: unknown SBOM format" >&2
  exit 1
fi

echo "Component/package count: $COMPONENT_COUNT"

if [ "$COMPONENT_COUNT" -lt "$MIN_COMPONENTS" ]; then
  echo "ERROR: SBOM component count below minimum $MIN_COMPONENTS" >&2
  exit 1
fi

echo "SBOM gate passed."
```

Make executable:

```bash id="k9jex6"
chmod +x quality-gates/scripts/sbom-gate.sh
```

Example:

```bash id="bz03x5"
SBOM_FILE=../07-artifact-management-registries/sbom/cyclonedx/some-file.json \
./quality-gates/scripts/sbom-gate.sh
```

---

# 12. Release Metadata Gate

Create:

```bash id="q95gs2"
nano quality-gates/scripts/release-metadata-gate.sh
```

Paste:

```bash id="15qpfz"
#!/usr/bin/env bash
set -euo pipefail

METADATA_FILE="${METADATA_FILE:-}"
REQUIRE_SIGNATURE="${REQUIRE_SIGNATURE:-false}"
REQUIRE_ROLLBACK="${REQUIRE_ROLLBACK:-false}"

if [ -z "$METADATA_FILE" ]; then
  echo "ERROR: METADATA_FILE is required" >&2
  exit 1
fi

if [ ! -f "$METADATA_FILE" ]; then
  echo "ERROR: metadata file not found: $METADATA_FILE" >&2
  exit 1
fi

echo "===== Release Metadata Gate ====="
echo "Metadata: $METADATA_FILE"

jq empty "$METADATA_FILE"

required_fields=(
  "service_name"
  "deploy_tag"
  "commit_sha"
)

for field in "${required_fields[@]}"; do
  value="$(jq -r --arg field "$field" '.[$field] // empty' "$METADATA_FILE")"
  if [ -z "$value" ]; then
    echo "ERROR: required field missing: $field" >&2
    exit 1
  fi
done

DEPLOY_TAG="$(jq -r '.deploy_tag // empty' "$METADATA_FILE")"

case "$DEPLOY_TAG" in
  latest|prod|production|stable)
    echo "ERROR: forbidden mutable deploy tag: $DEPLOY_TAG" >&2
    exit 1
    ;;
esac

if [ "$REQUIRE_SIGNATURE" = "true" ]; then
  sig="$(jq -r '.signature_status // .signing_status // empty' "$METADATA_FILE")"
  if [ "$sig" != "verified" ] && [ "$sig" != "signed" ] && [ "$sig" != "verified_when_pushed" ]; then
    echo "ERROR: signature required but not present/verified" >&2
    exit 1
  fi
fi

if [ "$REQUIRE_ROLLBACK" = "true" ]; then
  rollback="$(jq -r '.rollback_version // .rollback_strategy // empty' "$METADATA_FILE")"
  if [ -z "$rollback" ]; then
    echo "ERROR: rollback metadata required" >&2
    exit 1
  fi
fi

echo "Release metadata gate passed."
```

Make executable:

```bash id="4mnty3"
chmod +x quality-gates/scripts/release-metadata-gate.sh
```

Run against latest release metadata:

```bash id="1oz1wj"
METADATA_FILE="$(ls -t ../07-artifact-management-registries/release-records/demo-node-api-*.json | head -n 1)"
METADATA_FILE="$METADATA_FILE" ./quality-gates/scripts/release-metadata-gate.sh
```

---

# 13. IaC Gate

For now, create a Terraform format/validate gate.

Create:

```bash id="qdqmhy"
nano quality-gates/scripts/iac-gate.sh
```

Paste:

```bash id="wlsqau"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
REPORT_DIR="${REPORT_DIR:-$ROOT_DIR/08-cicd-pipelines/quality-gates/reports}"
FAIL_ON_FINDINGS="${FAIL_ON_FINDINGS:-true}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/iac-gate-$TIMESTAMP.txt"

mkdir -p "$REPORT_DIR"

echo "===== IaC Gate ====="

FAILED=0

{
  echo "IaC gate generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo

  echo "## Terraform directories"
  find "$ROOT_DIR" -type f -name "*.tf" \
    -not -path "*/.terraform/*" \
    -print | sed 's#/[^/]*$##' | sort -u
  echo

  while IFS= read -r tfdir; do
    [ -n "$tfdir" ] || continue
    echo "Checking Terraform dir: $tfdir"

    if command -v terraform >/dev/null 2>&1; then
      (
        cd "$tfdir"
        terraform fmt -check -recursive || exit 10
        terraform validate || exit 11
      ) || FAILED=1
    else
      echo "WARN: terraform not installed; skipping real validate"
    fi
  done < <(find "$ROOT_DIR" -type f -name "*.tf" -not -path "*/.terraform/*" -print | sed 's#/[^/]*$##' | sort -u)
} | tee "$REPORT_FILE"

echo
echo "Report: $REPORT_FILE"

if [ "$FAILED" -ne 0 ] && [ "$FAIL_ON_FINDINGS" = "true" ]; then
  echo "ERROR: IaC gate failed" >&2
  exit 1
fi

echo "IaC gate passed or reported only."
```

Make executable:

```bash id="2tcluj"
chmod +x quality-gates/scripts/iac-gate.sh
```

Run:

```bash id="tx67zg"
FAIL_ON_FINDINGS=false ./quality-gates/scripts/iac-gate.sh
```

Later DevSecOps module will add:

```text id="uwlok0"
Checkov
tfsec / Trivy config scan
Conftest
OPA policies
```

---

# 14. Unified Quality Gate Runner

Create one master script.

Create:

```bash id="9gzxky"
nano quality-gates/scripts/run-quality-gates.sh
```

Paste:

```bash id="zkv65k"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
APP_DIR="${APP_DIR:-$ROOT_DIR/05-application-runtime/demo-node-api}"
MODULE_DIR="${MODULE_DIR:-$ROOT_DIR/08-cicd-pipelines}"
REPORT_DIR="${REPORT_DIR:-$MODULE_DIR/quality-gates/reports}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"
IMAGE_REF="${IMAGE_REF:-}"
STRICT="${STRICT:-false}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
SUMMARY_FILE="$REPORT_DIR/quality-gate-summary-$TIMESTAMP.json"

echo "===== Run Quality Gates ====="
echo "Environment: $ENVIRONMENT"
echo "Strict: $STRICT"

TEST_STATUS="not_run"
LINT_STATUS="not_run"
FORMAT_STATUS="not_run"
SECRET_STATUS="not_run"
NPM_AUDIT_STATUS="not_run"
DOCKERFILE_STATUS="not_run"
CONTAINER_SCAN_STATUS="not_run"
IAC_STATUS="not_run"

run_gate() {
  local name="$1"
  shift

  echo
  echo "===== Gate: $name ====="

  if "$@"; then
    echo "Gate passed: $name"
    return 0
  else
    echo "Gate failed: $name"
    return 1
  fi
}

cd "$APP_DIR"

if run_gate "lint" npm run lint; then
  LINT_STATUS="passed"
else
  LINT_STATUS="failed"
  [ "$STRICT" = "true" ] && exit 1
fi

if run_gate "format" npm run format:check; then
  FORMAT_STATUS="passed"
else
  FORMAT_STATUS="failed"
  [ "$STRICT" = "true" ] && exit 1
fi

if run_gate "tests" npm test; then
  TEST_STATUS="passed"
else
  TEST_STATUS="failed"
  exit 1
fi

cd "$MODULE_DIR"

if run_gate "secret_scan" env FAIL_ON_FINDINGS="$STRICT" ./quality-gates/scripts/secret-gate.sh; then
  SECRET_STATUS="passed"
else
  SECRET_STATUS="failed"
  exit 1
fi

if run_gate "npm_audit" env FAIL_ON_AUDIT="$STRICT" ./quality-gates/scripts/npm-audit-gate.sh; then
  NPM_AUDIT_STATUS="passed"
else
  NPM_AUDIT_STATUS="failed"
  [ "$STRICT" = "true" ] && exit 1
fi

if run_gate "dockerfile" env FAIL_ON_FINDINGS="$STRICT" ./quality-gates/scripts/dockerfile-gate.sh; then
  DOCKERFILE_STATUS="passed"
else
  DOCKERFILE_STATUS="failed"
  [ "$STRICT" = "true" ] && exit 1
fi

if [ -n "$IMAGE_REF" ]; then
  if run_gate "container_scan" env IMAGE_REF="$IMAGE_REF" FAIL_ON_SCAN="$STRICT" ./quality-gates/scripts/container-scan-gate.sh; then
    CONTAINER_SCAN_STATUS="passed"
  else
    CONTAINER_SCAN_STATUS="failed"
    [ "$STRICT" = "true" ] && exit 1
  fi
else
  echo "Skipping container scan: IMAGE_REF not provided"
  CONTAINER_SCAN_STATUS="skipped"
fi

if run_gate "iac" env FAIL_ON_FINDINGS=false ./quality-gates/scripts/iac-gate.sh; then
  IAC_STATUS="passed"
else
  IAC_STATUS="failed"
  [ "$STRICT" = "true" ] && exit 1
fi

cat > "$SUMMARY_FILE" <<EOF
{
  "environment": "$ENVIRONMENT",
  "strict": "$STRICT",
  "image_ref": "$IMAGE_REF",
  "results": {
    "lint": "$LINT_STATUS",
    "format": "$FORMAT_STATUS",
    "tests": "$TEST_STATUS",
    "secret_scan": "$SECRET_STATUS",
    "npm_audit": "$NPM_AUDIT_STATUS",
    "dockerfile": "$DOCKERFILE_STATUS",
    "container_scan": "$CONTAINER_SCAN_STATUS",
    "iac": "$IAC_STATUS"
  },
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .
echo
echo "Quality gate summary: $SUMMARY_FILE"
```

Make executable:

```bash id="ncxzxk"
chmod +x quality-gates/scripts/run-quality-gates.sh
```

Run report mode:

```bash id="0hsble"
STRICT=false ./quality-gates/scripts/run-quality-gates.sh
```

Run strict mode:

```bash id="61n2mj"
STRICT=true ./quality-gates/scripts/run-quality-gates.sh
```

---

# 15. GitHub Actions Quality Gates Workflow

Create:

```bash id="246rpr"
nano quality-gates/github-actions/quality-gates.yml
```

Paste:

```yaml id="p0kpbz"
name: Quality Gates

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
  APP_DIR: 05-application-runtime/demo-node-api
  MODULE8_DIR: 08-cicd-pipelines
  NODE_VERSION: "22"

jobs:
  code-quality:
    name: Code quality and tests
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm
          cache-dependency-path: ${{ env.APP_DIR }}/package-lock.json

      - name: Install dependencies
        working-directory: ${{ env.APP_DIR }}
        run: npm ci

      - name: Lint
        working-directory: ${{ env.APP_DIR }}
        run: npm run lint

      - name: Format check
        working-directory: ${{ env.APP_DIR }}
        run: npm run format:check

      - name: Test
        working-directory: ${{ env.APP_DIR }}
        run: npm test

  dependency-review:
    name: Dependency review
    runs-on: ubuntu-latest
    if: ${{ github.event_name == 'pull_request' }}

    steps:
      - uses: actions/checkout@v4

      - name: Dependency Review
        uses: actions/dependency-review-action@v4
        with:
          fail-on-severity: high

  custom-gates:
    name: Custom quality gates
    runs-on: ubuntu-latest
    needs: code-quality

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

      - name: Run custom gates
        run: |
          cd "$MODULE8_DIR"
          STRICT=false ./quality-gates/scripts/run-quality-gates.sh

      - name: Upload quality gate reports
        uses: actions/upload-artifact@v4
        with:
          name: quality-gate-reports
          path: 08-cicd-pipelines/quality-gates/reports/
```

Copy:

```bash id="d2jgql"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 08-cicd-pipelines/quality-gates/github-actions/quality-gates.yml \
   .github/workflows/quality-gates.yml
```

GitHub’s dependency review action is designed to scan pull requests for dependency changes and can fail when vulnerabilities or invalid licenses are introduced. ([GitHub][1])

---

# 16. Jenkins Quality Gates Pipeline

Create:

```bash id="sob0py"
cd ~/devops-masterclass/08-cicd-pipelines

nano quality-gates/jenkins/Jenkinsfile.quality-gates
```

Paste:

```groovy id="94i0qp"
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
  }

  parameters {
    booleanParam(name: 'STRICT', defaultValue: false, description: 'Fail on warning-level gates?')
    string(name: 'IMAGE_REF', defaultValue: '', description: 'Optional image ref to scan')
  }

  environment {
    APP_DIR = '05-application-runtime/demo-node-api'
    MODULE8_DIR = '08-cicd-pipelines'
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

    stage('Code Quality') {
      steps {
        dir("${APP_DIR}") {
          sh '''
            npm run lint
            npm run format:check
            npm test
          '''
        }
      }
    }

    stage('Custom Quality Gates') {
      steps {
        dir("${MODULE8_DIR}") {
          sh '''
            STRICT="${STRICT}" IMAGE_REF="${IMAGE_REF}" ./quality-gates/scripts/run-quality-gates.sh
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '08-cicd-pipelines/quality-gates/reports/**/*', allowEmptyArchive: true
    }

    success {
      echo 'Quality gates passed.'
    }

    unstable {
      echo 'Quality gates unstable.'
    }

    failure {
      echo 'Quality gates failed.'
    }
  }
}
```

Jenkins Warnings Next Generation supports quality gates that can set build status to unstable or failed, which is useful for separating warning-level issues from hard failures. ([Jenkins][3])

---

# 17. GitLab CI Quality Gates Pipeline

Create:

```bash id="pw5q3e"
nano quality-gates/gitlab/.gitlab-ci.quality-gates.yml
```

Paste:

```yaml id="9vy3fu"
stages:
  - quality
  - security
  - reports

variables:
  APP_DIR: "05-application-runtime/demo-node-api"
  MODULE8_DIR: "08-cicd-pipelines"
  NODE_ENV: "test"

cache:
  key:
    files:
      - 05-application-runtime/demo-node-api/package-lock.json
  paths:
    - 05-application-runtime/demo-node-api/.npm/

code_quality_tests:
  stage: quality
  image: node:22-alpine
  script:
    - cd "$APP_DIR"
    - npm ci --cache .npm --prefer-offline
    - npm run lint
    - npm run format:check
    - npm test

custom_security_gates:
  stage: security
  image: node:22-alpine
  needs:
    - code_quality_tests
  before_script:
    - apk add --no-cache bash jq grep findutils
  script:
    - cd "$APP_DIR"
    - npm ci --cache .npm --prefer-offline
    - cd "$CI_PROJECT_DIR/$MODULE8_DIR"
    - STRICT=false ./quality-gates/scripts/run-quality-gates.sh
  artifacts:
    when: always
    expire_in: 14 days
    paths:
      - 08-cicd-pipelines/quality-gates/reports/

show_quality_reports:
  stage: reports
  image: alpine:3.20
  needs:
    - job: custom_security_gates
      artifacts: true
  script:
    - ls -la 08-cicd-pipelines/quality-gates/reports || true
    - find 08-cicd-pipelines/quality-gates/reports -type f | sort | tail -n 20
```

GitLab application security testing provides continuous detection of vulnerabilities during development and after deployment changes, with SAST and other scanning features available through GitLab’s security tooling. ([GitLab Docs][4])

---

# 18. Gate Exceptions Policy

In real companies, sometimes a gate cannot be fixed immediately.

Use exceptions, but control them.

Create:

```bash id="go6sm4"
nano quality-gates/policies/gate-exceptions.example.json
```

Paste:

```json id="sqb456"
{
  "exceptions": [
    {
      "id": "EX-2026-001",
      "gate": "container_scan",
      "artifact": "demo-node-api:0.8.0-dev-a1b2c3d",
      "issue": "CVE-EXAMPLE-1234",
      "severity": "HIGH",
      "reason": "Not exploitable because affected package is not reachable at runtime",
      "approved_by": "security-lead",
      "expires_on": "2026-08-01",
      "compensating_controls": [
        "runtime endpoint not exposed",
        "WAF rule enabled",
        "upgrade scheduled"
      ]
    }
  ]
}
```

Professional rules:

```text id="k8c2qb"
exceptions must have owner
exceptions must expire
exceptions must include reason
exceptions must include compensating control
exceptions must not be permanent silence
```

---

# 19. Quality Gate Report Summary Script

Create:

```bash id="sxo9ak"
nano quality-gates/scripts/quality-report-summary.sh
```

Paste:

```bash id="aaslbm"
#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-quality-gates/reports}"

echo "===== Quality Gate Report Summary ====="
echo "Report dir: $REPORT_DIR"

if [ ! -d "$REPORT_DIR" ]; then
  echo "No report directory found."
  exit 0
fi

echo
echo "Latest summary files:"
find "$REPORT_DIR" -type f -name "quality-gate-summary-*.json" -print | sort | tail -n 5

LATEST="$(find "$REPORT_DIR" -type f -name "quality-gate-summary-*.json" -print | sort | tail -n 1 || true)"

if [ -n "$LATEST" ]; then
  echo
  echo "Latest summary:"
  jq . "$LATEST"
fi

echo
echo "All report files:"
find "$REPORT_DIR" -type f | sort | tail -n 30
```

Make executable:

```bash id="qs4j6h"
chmod +x quality-gates/scripts/quality-report-summary.sh
```

Run:

```bash id="obc6z1"
./quality-gates/scripts/quality-report-summary.sh
```

---

# 20. Quality Gates Runbook

Create:

```bash id="6hz9u5"
nano quality-gates/runbooks/quality-gates-runbook.md
```

Paste:

````markdown id="x5h9bb"
# Quality Gates Runbook

## Goal

Prevent unsafe code, dependencies, containers, or artifacts from reaching production.

## Gate Types

- lint
- format
- unit tests
- dependency audit
- secret scan
- Dockerfile policy
- container scan
- SBOM validation
- release metadata validation
- IaC validation

## Local Run

```bash
cd ~/devops-masterclass/08-cicd-pipelines
STRICT=false ./quality-gates/scripts/run-quality-gates.sh
````

Strict mode:

```bash id="mpuyvo"
STRICT=true ./quality-gates/scripts/run-quality-gates.sh
```

With image scan:

```bash id="ybdm2q"
IMAGE_REF=demo-node-api:TAG STRICT=false ./quality-gates/scripts/run-quality-gates.sh
```

## Recommended Policy

Pull request:

* fail tests
* fail secret scan
* warn dependency scan
* report container scan

Main:

* fail tests
* fail lint/format
* fail secret scan
* fail high/critical dependency scan
* fail critical container scan

Production:

* fail high/critical dependency scan
* fail high/critical container scan
* require SBOM
* require provenance
* require signature
* require release metadata
* require rollback version

## Exception Rules

Exceptions must include:

* issue ID
* owner
* reason
* expiry date
* compensating controls
* approval

````

---

# 21. Quality Gates Troubleshooting

Create:

```bash id="q1csdd"
nano quality-gates/runbooks/quality-gates-troubleshooting.md
````

Paste:

````markdown id="0rd8gq"
# Quality Gates Troubleshooting

## Lint fails

Run locally:

```bash
cd 05-application-runtime/demo-node-api
npm run lint
````

Fix code or update lint config.

## Format fails

Run:

```bash id="yql0lt"
npm run format:check
```

Fix formatting or update formatter.

## Tests fail

Run:

```bash id="jb13n6"
npm test
```

Check recent code changes, env vars, mocks, ports, and flaky tests.

## NPM audit fails

Run:

```bash id="mftmhb"
npm audit
npm audit fix
```

Review whether vulnerability is reachable.

## Secret gate fails

Check report:

```bash id="6crrng"
ls -lt 08-cicd-pipelines/quality-gates/reports
```

If real secret:

1. revoke it
2. rotate it
3. remove it from Git history if committed
4. check logs/artifacts
5. create incident record

## Container scan fails

Check:

```bash id="iyj5mt"
trivy image IMAGE_REF
```

Fix by:

* updating base image
* updating app dependencies
* changing package version
* accepting documented exception with expiry

## Dockerfile gate fails

Check:

* non-root USER
* no latest base image
* no secret-like ARG/ENV
* healthcheck present if policy requires it

## SBOM gate fails

Check:

* SBOM file exists
* JSON is valid
* CycloneDX or SPDX format recognized
* component count is not zero

## IaC gate fails

Run:

```bash id="kpp719"
terraform fmt -recursive
terraform validate
```

````id="8kztgp"

---

# 22. Update Makefile

Open:

```bash id="zgx0e3"
cd ~/devops-masterclass/08-cicd-pipelines

nano Makefile
````

Add:

```Makefile id="mxxr16"
.PHONY: quality-gates quality-gates-strict quality-summary quality-secret quality-dockerfile quality-iac

quality-gates:
	./quality-gates/scripts/run-quality-gates.sh

quality-gates-strict:
	STRICT=true ./quality-gates/scripts/run-quality-gates.sh

quality-summary:
	./quality-gates/scripts/quality-report-summary.sh

quality-secret:
	./quality-gates/scripts/secret-gate.sh

quality-dockerfile:
	./quality-gates/scripts/dockerfile-gate.sh

quality-iac:
	./quality-gates/scripts/iac-gate.sh
```

Run:

```bash id="igzvpa"
make quality-gates
make quality-summary
```

---

# 23. Validation

Run:

```bash id="p21gez"
cd ~/devops-masterclass/08-cicd-pipelines

test -f quality-gates/policies/demo-node-api-quality-gates.json
test -x quality-gates/scripts/secret-gate.sh
test -x quality-gates/scripts/npm-audit-gate.sh
test -x quality-gates/scripts/container-scan-gate.sh
test -x quality-gates/scripts/dockerfile-gate.sh
test -x quality-gates/scripts/sbom-gate.sh
test -x quality-gates/scripts/release-metadata-gate.sh
test -x quality-gates/scripts/iac-gate.sh
test -x quality-gates/scripts/run-quality-gates.sh
test -f quality-gates/github-actions/quality-gates.yml
test -f quality-gates/jenkins/Jenkinsfile.quality-gates
test -f quality-gates/gitlab/.gitlab-ci.quality-gates.yml

echo "Quality gates lesson files validated."
```

---

# 24. Practical Lab

Run:

```bash id="xtxuvs"
cd ~/devops-masterclass/08-cicd-pipelines

make quality-gates
make quality-summary
```

Copy GitHub workflow:

```bash id="tjm42z"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 08-cicd-pipelines/quality-gates/github-actions/quality-gates.yml \
   .github/workflows/quality-gates.yml
```

Commit:

```bash id="o8xdlt"
git status

git add .github/workflows/quality-gates.yml \
        08-cicd-pipelines/quality-gates \
        05-application-runtime/demo-node-api/package.json \
        05-application-runtime/demo-node-api/scripts

git commit -m "feat: add CI/CD quality gates and DevSecOps checks"
git push
```

---

# 25. Interview Explanation

## What is a quality gate?

Strong answer:

```text id="enumb3"
A quality gate is an automated policy check in CI/CD that decides whether the pipeline can continue. Examples include tests passing, no critical vulnerabilities, no committed secrets, required SBOM, signed image, and valid release metadata.
```

## What gates would you add before production?

Strong answer:

```text id="3406i8"
Before production, I would require tests, lint/format checks, secret scanning, dependency scanning, container image scanning, SBOM generation, provenance, image signature verification, release metadata, environment approval, deployment health checks, and rollback metadata.
```

## Fail vs warn strategy?

Strong answer:

```text id="o40c9r"
I fail the pipeline for issues that make deployment unsafe, such as failed tests, committed secrets, missing production SBOM, missing signature, or critical exploitable vulnerabilities. I use warnings for lower-risk findings during early development, but production gates are stricter.
```

## What is the difference between dependency scanning and container scanning?

Strong answer:

```text id="1fjend"
Dependency scanning checks application dependencies such as npm packages. Container scanning checks the final container image, including OS packages, language packages, and sometimes image configuration. Both are needed because the runtime image can include vulnerabilities not visible in application dependency files.
```

## Why validate SBOM?

Strong answer:

```text id="5aiyy5"
Generating an SBOM is not enough. The pipeline should validate that the SBOM exists, is valid JSON, uses a recognized format such as CycloneDX or SPDX, and contains components. Otherwise the release evidence may be incomplete or useless.
```

## How do you handle exceptions?

Strong answer:

```text id="8bjb2b"
I allow exceptions only with an owner, reason, expiry date, approval, affected artifact, and compensating controls. Exceptions should be tracked as policy records and reviewed regularly, not used as permanent ignores.
```

---

# 26. Today’s Core Rules

```text id="7ihzsf"
Quality gates convert engineering policy into automation.
Tests are necessary but not enough.
Fail secrets immediately.
Fail production if SBOM/provenance/signature is missing.
Use warn/report mode while introducing new gates.
Make production gates stricter than PR gates.
Scan dependencies and final images.
Validate release metadata.
Validate Dockerfile security basics.
Validate IaC before apply.
Archive gate reports.
Exceptions need owner, reason, expiry, and approval.
A pipeline without gates is just a remote shell script.
```

---

# Next Lesson

# Lesson 8.10 — Deployment and Rollback Pipelines

We will build:

```text id="gqtem6"
deployment pipeline design
environment promotion
staging deploy
production approval
health checks
version checks
smoke tests
deployment reports
automatic rollback
manual rollback
rollback metadata
GitHub Actions deploy workflow
Jenkins deploy workflow
GitLab CI deploy workflow
SSH/Compose deployment pattern
safe deployment runbook
```

[1]: https://github.com/actions/dependency-review-action?utm_source=chatgpt.com "Dependency Review Action"
[2]: https://github.com/aquasecurity/trivy?utm_source=chatgpt.com "aquasecurity/trivy: Find vulnerabilities, misconfigurations, ..."
[3]: https://www.jenkins.io/doc/pipeline/steps/warnings-ng/?utm_source=chatgpt.com "Warnings Plugin"
[4]: https://docs.gitlab.com/user/application_security/?utm_source=chatgpt.com "Application security testing"

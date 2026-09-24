# Lesson 9.11 — Security Evidence, Risk Exceptions, and Release Approval

# Central Evidence Collector, Exception Validation, Production Security Gate, Release Approval Checklist, Security Dashboard JSON, GitHub Actions, Jenkins, GitLab CI, and DevSecOps Release Runbook

In Lesson 9.10, we added DAST and runtime security smoke tests.

Now we build the **release-control layer**.

A mature DevSecOps system does not only run tools.

It answers:

```text id="7brfgb"
What was scanned?
Which artifact was scanned?
Which reports were generated?
Which findings failed?
Which exceptions were approved?
Who approved production?
What rollback version exists?
Can we prove this release was safe enough to ship?
```

This is called **security evidence**.

GitHub Actions environments can require reviewers before a job referencing that environment proceeds, Jenkins has an `input` step that pauses pipeline execution for human interaction, and GitLab supports blocking manual jobs using `when: manual` with `allow_failure: false`. These are the approval mechanisms we will connect to our evidence system. ([GitHub Docs][1])

---

# 1. Security Evidence Mental Model

Security evidence is proof that your release went through required controls.

Evidence includes:

```text id="8hj7ok"
SAST report
secret scan report
SCA report
container image scan report
Dockerfile security report
IaC scan report
SBOM
license report
OPA policy report
DAST report
exception records
release approval record
deployment record
rollback record
```

A weak pipeline says:

```text id="h4rsni"
Build passed.
Deploy approved.
```

A strong pipeline says:

```text id="x75j3o"
Artifact demo-node-api:0.9.0-prod-a1b2c3d passed SAST, secret scanning, SCA,
image scanning, Dockerfile policy, IaC scanning, SBOM validation, license policy,
OPA policy checks, and DAST smoke tests. Exceptions were reviewed. Production
approval was recorded. Rollback version exists.
```

Professional rule:

```text id="bnws7j"
Security gates without evidence are hard to audit.
```

---

# 2. Why Release Approval Matters

Production approval should not be a blind button click.

It should answer:

```text id="uoowma"
Are all required gates complete?
Are high/critical risks resolved?
Are exceptions valid?
Is SBOM present?
Is artifact immutable?
Is rollback version known?
Has runtime verification been planned?
Has the approver reviewed evidence?
```

Approval should depend on evidence.

```text id="b62w5k"
security evidence
  ↓
release decision
  ↓
production approval
  ↓
deployment
```

Not:

```text id="pyhwug"
approval
  ↓
hope scans were okay
```

---

# 3. What We Will Build

In this lesson, you will create:

```text id="k4ielw"
security evidence policy
risk exception schema
exception validator
evidence collector
security dashboard generator
release approval checklist
production release decision script
GitHub Actions approval workflow
Jenkins approval pipeline
GitLab approval pipeline
release runbooks
Makefile targets
```

This lesson connects everything from Module 9.

---

# 4. Create Lesson Directory

Run:

```bash id="ciprny"
cd ~/devops-masterclass/09-devsecops-security-gates

mkdir -p security-evidence-release-approval/{scripts,reports,evidence,github-actions,jenkins,gitlab,runbooks,examples,notes,policies,exceptions,approvals,dashboard}
```

Check:

```bash id="npa8lh"
tree -L 2 security-evidence-release-approval
```

Expected:

```text id="sbihy2"
security-evidence-release-approval
├── approvals
├── dashboard
├── evidence
├── exceptions
├── examples
├── github-actions
├── gitlab
├── jenkins
├── notes
├── policies
├── reports
├── runbooks
└── scripts
```

---

# 5. Security Evidence Policy

Create:

```bash id="ecdpqh"
nano security-evidence-release-approval/policies/security-evidence-policy.json
```

Paste:

```json id="zubfkp"
{
  "service_name": "demo-node-api",
  "policy_version": "1.0",
  "required_evidence": {
    "pull_request": [
      "sast",
      "secret_scan",
      "sca",
      "dockerfile_security"
    ],
    "main": [
      "sast",
      "secret_scan",
      "sca",
      "container_image_scan",
      "dockerfile_security",
      "iac_security",
      "sbom_license",
      "policy_as_code"
    ],
    "production": [
      "sast",
      "secret_scan",
      "sca",
      "container_image_scan",
      "dockerfile_security",
      "iac_security",
      "sbom_license",
      "policy_as_code",
      "dast_runtime",
      "release_approval",
      "rollback_plan"
    ]
  },
  "blocking_conditions": {
    "production": [
      "missing_required_evidence",
      "unapproved_high_or_critical_exception",
      "missing_sbom",
      "missing_rollback_version",
      "mutable_artifact_tag",
      "missing_approval",
      "expired_exception"
    ]
  },
  "artifact_rules": {
    "forbidden_tags": ["latest", "prod", "production", "stable"],
    "digest_required_for_production": true,
    "sbom_required_for_production": true,
    "rollback_required_for_production": true
  },
  "exception_policy": {
    "allowed": true,
    "requires_owner": true,
    "requires_reason": true,
    "requires_approver": true,
    "requires_expiry": true,
    "requires_compensating_controls": true,
    "max_days": 30
  },
  "approval_policy": {
    "production_requires_manual_approval": true,
    "approval_requires_evidence_summary": true,
    "approval_requires_rollback_version": true
  }
}
```

---

# 6. Notes

Create:

```bash id="ikhcbs"
nano security-evidence-release-approval/notes/security-evidence-mental-model.md
```

Paste:

```markdown id="jjp9mz"
# Security Evidence and Release Approval Mental Model

## Definition

Security evidence is proof that required security gates ran and produced reviewable results.

## Examples

- SAST report
- secret scan report
- SCA report
- container image scan report
- Dockerfile policy report
- IaC security report
- SBOM
- license report
- policy-as-code report
- DAST report
- exception records
- approval record
- rollback record

## Why It Matters

Security gates are useful during CI/CD.
Security evidence is useful during audit, release review, and incident response.

## Production Rule

A production release should not proceed unless:

- required evidence exists
- critical findings are resolved or approved
- exceptions are valid and unexpired
- artifact is immutable
- rollback version exists
- approval is recorded
```

---

# 7. Risk Exception Schema

Create:

```bash id="h5l7bq"
nano security-evidence-release-approval/policies/risk-exception-schema.json
```

Paste:

```json id="melazl"
{
  "required_fields": [
    "exception_id",
    "category",
    "severity",
    "affected_artifact",
    "affected_environment",
    "finding_id",
    "reason",
    "risk_owner",
    "approved_by",
    "created_at",
    "expires_on",
    "compensating_controls",
    "fix_plan",
    "status"
  ],
  "allowed_categories": [
    "sast",
    "secret_scan",
    "sca",
    "container_image_scan",
    "dockerfile_security",
    "iac_security",
    "sbom_license",
    "policy_as_code",
    "dast_runtime"
  ],
  "allowed_severities": [
    "low",
    "medium",
    "high",
    "critical"
  ],
  "allowed_statuses": [
    "requested",
    "approved",
    "rejected",
    "expired",
    "closed"
  ],
  "max_days": 30
}
```

Create example valid exception:

```bash id="9hn47p"
nano security-evidence-release-approval/examples/risk-exception-valid.json
```

Paste:

```json id="ya9zzh"
{
  "exception_id": "RISK-EX-2026-001",
  "category": "container_image_scan",
  "severity": "high",
  "affected_artifact": "demo-node-api:0.9.0-prod-a1b2c3d",
  "affected_environment": "production",
  "finding_id": "CVE-EXAMPLE-1234",
  "reason": "No fixed version is available in the current base image. Runtime exposure is limited.",
  "risk_owner": "platform-team",
  "approved_by": "security-team",
  "created_at": "2026-07-12",
  "expires_on": "2026-08-10",
  "compensating_controls": [
    "restricted ingress",
    "runtime monitoring",
    "WAF rule"
  ],
  "fix_plan": "Upgrade base image when patched package is available.",
  "status": "approved"
}
```

Create invalid exception:

```bash id="1bgy26"
nano security-evidence-release-approval/examples/risk-exception-invalid.json
```

Paste:

```json id="hg73e5"
{
  "exception_id": "RISK-EX-2026-002",
  "category": "container_image_scan",
  "severity": "critical",
  "affected_artifact": "demo-node-api:latest",
  "affected_environment": "production",
  "finding_id": "CVE-EXAMPLE-9999",
  "reason": "",
  "risk_owner": "",
  "approved_by": "",
  "created_at": "2026-07-12",
  "expires_on": "",
  "compensating_controls": [],
  "fix_plan": "",
  "status": "approved"
}
```

---

# 8. Exception Validator

Create:

```bash id="2usyu8"
nano security-evidence-release-approval/scripts/validate-risk-exception.py
```

Paste:

```python id="9y7x75"
#!/usr/bin/env python3

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

exception_file = os.environ.get("EXCEPTION_FILE", "")
schema_file = Path(os.environ.get(
    "SCHEMA_FILE",
    "security-evidence-release-approval/policies/risk-exception-schema.json"
))
report_dir = Path(os.environ.get("REPORT_DIR", "security-evidence-release-approval/reports"))
fail_on_invalid = os.environ.get("FAIL_ON_INVALID", "true").lower() == "true"

if not exception_file:
    print("ERROR: EXCEPTION_FILE is required", file=sys.stderr)
    sys.exit(1)

exception_path = Path(exception_file)

if not exception_path.exists():
    print(f"ERROR: exception file not found: {exception_path}", file=sys.stderr)
    sys.exit(1)

if not schema_file.exists():
    print(f"ERROR: schema file not found: {schema_file}", file=sys.stderr)
    sys.exit(1)

report_dir.mkdir(parents=True, exist_ok=True)

exception = json.loads(exception_path.read_text(encoding="utf-8"))
schema = json.loads(schema_file.read_text(encoding="utf-8"))

findings = []

for field in schema["required_fields"]:
    value = exception.get(field)
    if value is None or value == "" or value == []:
        findings.append(f"missing required field: {field}")

if exception.get("category") not in schema["allowed_categories"]:
    findings.append(f"invalid category: {exception.get('category')}")

if exception.get("severity") not in schema["allowed_severities"]:
    findings.append(f"invalid severity: {exception.get('severity')}")

if exception.get("status") not in schema["allowed_statuses"]:
    findings.append(f"invalid status: {exception.get('status')}")

if exception.get("affected_environment") == "production":
    if exception.get("status") != "approved":
        findings.append("production exception must be approved")

    if not exception.get("approved_by"):
        findings.append("production exception must include approved_by")

    if not exception.get("compensating_controls"):
        findings.append("production exception must include compensating controls")

    artifact = exception.get("affected_artifact", "")
    if artifact.endswith(":latest") or artifact.endswith(":prod") or artifact.endswith(":production") or artifact.endswith(":stable"):
        findings.append("production exception must not reference mutable artifact tag")

expires_on = exception.get("expires_on", "")
created_at = exception.get("created_at", "")

try:
    if expires_on:
        expiry = datetime.strptime(expires_on, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        now = datetime.now(timezone.utc)
        if expiry < now:
            findings.append("exception is expired")
except ValueError:
    findings.append("expires_on must use YYYY-MM-DD format")

try:
    if expires_on and created_at:
        created = datetime.strptime(created_at, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        expiry = datetime.strptime(expires_on, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        age_days = (expiry - created).days
        if age_days > int(schema.get("max_days", 30)):
            findings.append(f"exception duration exceeds max_days: {age_days}")
except ValueError:
    findings.append("created_at must use YYYY-MM-DD format")

decision = "passed" if not findings else "failed"

timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
summary_file = report_dir / f"risk-exception-validation-{timestamp}.json"

summary = {
    "gate": "risk_exception_validation",
    "exception_file": str(exception_path),
    "exception_id": exception.get("exception_id"),
    "status": exception.get("status"),
    "severity": exception.get("severity"),
    "affected_environment": exception.get("affected_environment"),
    "findings": findings,
    "decision": decision,
    "created_at": datetime.now(timezone.utc).isoformat()
}

summary_file.write_text(json.dumps(summary, indent=2), encoding="utf-8")
print(json.dumps(summary, indent=2))
print(f"Exception validation summary: {summary_file}")

if decision == "failed" and fail_on_invalid:
    sys.exit(1)
```

Make executable:

```bash id="6zgnt0"
chmod +x security-evidence-release-approval/scripts/validate-risk-exception.py
```

Run valid:

```bash id="n4dzll"
EXCEPTION_FILE=security-evidence-release-approval/examples/risk-exception-valid.json \
./security-evidence-release-approval/scripts/validate-risk-exception.py
```

Run invalid:

```bash id="9cznhk"
EXCEPTION_FILE=security-evidence-release-approval/examples/risk-exception-invalid.json \
./security-evidence-release-approval/scripts/validate-risk-exception.py || true
```

---

# 9. Release Metadata Example

Create:

```bash id="hec6c2"
nano security-evidence-release-approval/examples/release-metadata-example.json
```

Paste:

```json id="7dltfw"
{
  "service_name": "demo-node-api",
  "environment": "production",
  "artifact": {
    "image": "demo-node-api:0.9.0-prod-a1b2c3d",
    "version": "0.9.0-prod-a1b2c3d",
    "digest": "sha256:exampledigest",
    "sbom": "sbom/demo-node-api-image.cdx.json",
    "provenance": "provenance/demo-node-api.intoto.jsonl",
    "signature": "cosign-signature-present"
  },
  "rollback": {
    "version": "0.8.0-prod-f9e8d7c",
    "image": "demo-node-api:0.8.0-prod-f9e8d7c"
  },
  "release": {
    "change_id": "CHG-2026-001",
    "requested_by": "platform-team",
    "approved_by": "",
    "approval_status": "pending"
  }
}
```

---

# 10. Evidence Collector

This script searches for reports from all Module 9 gates and creates a central evidence bundle.

Create:

```bash id="7ytww5"
nano security-evidence-release-approval/scripts/collect-security-evidence.sh
```

Paste:

```bash id="wo7ie6"
#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="${MODULE_DIR:-$HOME/devops-masterclass/09-devsecops-security-gates}"
EVIDENCE_DIR="${EVIDENCE_DIR:-$MODULE_DIR/security-evidence-release-approval/evidence}"
REPORT_DIR="${REPORT_DIR:-$MODULE_DIR/security-evidence-release-approval/reports}"

SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"
ARTIFACT_VERSION="${ARTIFACT_VERSION:-local}"
ARTIFACT_IMAGE="${ARTIFACT_IMAGE:-demo-node-api:local}"
ROLLBACK_VERSION="${ROLLBACK_VERSION:-}"

mkdir -p "$EVIDENCE_DIR" "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BUNDLE_DIR="$EVIDENCE_DIR/$SERVICE_NAME-$ENVIRONMENT-$ARTIFACT_VERSION-$TIMESTAMP"
mkdir -p "$BUNDLE_DIR"

MANIFEST="$BUNDLE_DIR/evidence-manifest.json"
SUMMARY="$REPORT_DIR/security-evidence-summary-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== Collect Security Evidence ====="
echo "Service: $SERVICE_NAME"
echo "Environment: $ENVIRONMENT"
echo "Artifact: $ARTIFACT_IMAGE"
echo "Bundle: $BUNDLE_DIR"

declare -A SOURCES
SOURCES["sast"]="sast-semgrep/reports"
SOURCES["secret_scan"]="secret-scanning/reports"
SOURCES["sca"]="sca-dependency-scanning/reports"
SOURCES["container_image_scan"]="container-image-scanning/reports"
SOURCES["dockerfile_security"]="dockerfile-build-security/reports"
SOURCES["iac_security"]="iac-security-scanning/reports"
SOURCES["sbom_license"]="sbom-license-policy/reports"
SOURCES["policy_as_code"]="policy-as-code-opa/reports"
SOURCES["dast_runtime"]="dast-runtime-security/reports"

EVIDENCE_ITEMS="[]"

for gate in "${!SOURCES[@]}"; do
  source_dir="$MODULE_DIR/${SOURCES[$gate]}"
  dest_dir="$BUNDLE_DIR/$gate"
  mkdir -p "$dest_dir"

  files_found=0

  if [ -d "$source_dir" ]; then
    while IFS= read -r file; do
      cp "$file" "$dest_dir/" || true
      files_found=$((files_found + 1))
    done < <(find "$source_dir" -type f | sort | tail -n 20)
  fi

  status="missing"
  if [ "$files_found" -gt 0 ]; then
    status="present"
  fi

  EVIDENCE_ITEMS="$(echo "$EVIDENCE_ITEMS" | jq \
    --arg gate "$gate" \
    --arg status "$status" \
    --arg source "$source_dir" \
    --arg dest "$dest_dir" \
    --argjson count "$files_found" \
    '. + [{
      gate: $gate,
      status: $status,
      source_dir: $source,
      bundle_dir: $dest,
      file_count: $count
    }]')"
done

SBOM_COUNT=0
if [ -d "$MODULE_DIR/sbom-license-policy/sbom" ]; then
  mkdir -p "$BUNDLE_DIR/sbom"
  while IFS= read -r sbom_file; do
    cp "$sbom_file" "$BUNDLE_DIR/sbom/" || true
    SBOM_COUNT=$((SBOM_COUNT + 1))
  done < <(find "$MODULE_DIR/sbom-license-policy/sbom" -type f | sort | tail -n 20)
fi

cat > "$MANIFEST" <<EOF
{
  "service_name": "$SERVICE_NAME",
  "environment": "$ENVIRONMENT",
  "artifact_version": "$ARTIFACT_VERSION",
  "artifact_image": "$ARTIFACT_IMAGE",
  "rollback_version": "$ROLLBACK_VERSION",
  "bundle_dir": "$BUNDLE_DIR",
  "sbom_count": $SBOM_COUNT,
  "evidence": $EVIDENCE_ITEMS,
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

PRESENT_COUNT="$(jq '[.evidence[] | select(.status == "present")] | length' "$MANIFEST")"
MISSING_COUNT="$(jq '[.evidence[] | select(.status == "missing")] | length' "$MANIFEST")"

cat > "$SUMMARY" <<EOF
{
  "service_name": "$SERVICE_NAME",
  "gate": "security_evidence_collection",
  "environment": "$ENVIRONMENT",
  "artifact_version": "$ARTIFACT_VERSION",
  "artifact_image": "$ARTIFACT_IMAGE",
  "rollback_version": "$ROLLBACK_VERSION",
  "bundle_dir": "$BUNDLE_DIR",
  "manifest": "$MANIFEST",
  "evidence_present_count": $PRESENT_COUNT,
  "evidence_missing_count": $MISSING_COUNT,
  "sbom_count": $SBOM_COUNT,
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY" | jq .

echo
echo "Evidence bundle created: $BUNDLE_DIR"
echo "Manifest: $MANIFEST"
```

Make executable:

```bash id="j1mq5t"
chmod +x security-evidence-release-approval/scripts/collect-security-evidence.sh
```

Run:

```bash id="jig5o8"
ENVIRONMENT=main \
ARTIFACT_VERSION=0.9.0-dev-local \
ARTIFACT_IMAGE=demo-node-api:0.9.0-dev-local \
ROLLBACK_VERSION=0.8.0-dev-local \
./security-evidence-release-approval/scripts/collect-security-evidence.sh
```

---

# 11. Production Release Decision Script

This script validates whether production can proceed.

Create:

```bash id="cx3htl"
nano security-evidence-release-approval/scripts/production-release-decision.py
```

Paste:

```python id="o1tcnb"
#!/usr/bin/env python3

import json
import os
import sys
from pathlib import Path
from datetime import datetime, timezone

policy_file = Path(os.environ.get(
    "POLICY_FILE",
    "security-evidence-release-approval/policies/security-evidence-policy.json"
))
release_file = Path(os.environ.get(
    "RELEASE_FILE",
    "security-evidence-release-approval/examples/release-metadata-example.json"
))
manifest_file = os.environ.get("EVIDENCE_MANIFEST", "")
exceptions_dir = Path(os.environ.get("EXCEPTIONS_DIR", "security-evidence-release-approval/exceptions"))
report_dir = Path(os.environ.get("REPORT_DIR", "security-evidence-release-approval/reports"))
environment = os.environ.get("ENVIRONMENT", "production")
fail_on_block = os.environ.get("FAIL_ON_BLOCK", "true").lower() == "true"

if not policy_file.exists():
    print(f"ERROR: policy file not found: {policy_file}", file=sys.stderr)
    sys.exit(1)

if not release_file.exists():
    print(f"ERROR: release file not found: {release_file}", file=sys.stderr)
    sys.exit(1)

report_dir.mkdir(parents=True, exist_ok=True)

policy = json.loads(policy_file.read_text(encoding="utf-8"))
release = json.loads(release_file.read_text(encoding="utf-8"))

manifest = None
if manifest_file:
    manifest_path = Path(manifest_file)
else:
    manifests = sorted(Path("security-evidence-release-approval/evidence").glob("*/evidence-manifest.json"))
    manifest_path = manifests[-1] if manifests else None

if manifest_path and manifest_path.exists():
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

blocking = []
warnings = []

required = policy["required_evidence"].get(environment, [])

if manifest:
    evidence_status = {item["gate"]: item["status"] for item in manifest.get("evidence", [])}
    for gate in required:
        if gate in ["release_approval", "rollback_plan"]:
            continue
        if evidence_status.get(gate) != "present":
            blocking.append(f"missing required evidence: {gate}")
else:
    blocking.append("missing evidence manifest")

artifact = release.get("artifact", {})
rollback = release.get("rollback", {})
approval = release.get("release", {})

image = artifact.get("image", "")
version = artifact.get("version", "")
digest = artifact.get("digest", "")
sbom = artifact.get("sbom", "")

for forbidden_tag in policy["artifact_rules"]["forbidden_tags"]:
    if image.endswith(f":{forbidden_tag}") or version == forbidden_tag:
        blocking.append(f"mutable or forbidden artifact tag used: {forbidden_tag}")

if environment == "production":
    if policy["artifact_rules"].get("digest_required_for_production") and not digest:
        blocking.append("production artifact digest is missing")

    if policy["artifact_rules"].get("sbom_required_for_production") and not sbom:
        blocking.append("production SBOM reference is missing")

    if policy["artifact_rules"].get("rollback_required_for_production") and not rollback.get("version"):
        blocking.append("production rollback version is missing")

    if policy["approval_policy"].get("production_requires_manual_approval"):
        if approval.get("approval_status") != "approved" or not approval.get("approved_by"):
            blocking.append("production manual approval is missing")

exception_files = sorted(exceptions_dir.glob("*.json")) if exceptions_dir.exists() else []
expired_exceptions = []
unapproved_high_critical = []

now = datetime.now(timezone.utc)

for path in exception_files:
    try:
        exc = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        warnings.append(f"could not parse exception file: {path}")
        continue

    severity = exc.get("severity", "")
    status = exc.get("status", "")
    expires_on = exc.get("expires_on", "")

    if severity in ["high", "critical"] and status != "approved":
        unapproved_high_critical.append(exc.get("exception_id", str(path)))

    if expires_on:
        try:
            expiry = datetime.strptime(expires_on, "%Y-%m-%d").replace(tzinfo=timezone.utc)
            if expiry < now:
                expired_exceptions.append(exc.get("exception_id", str(path)))
        except ValueError:
            expired_exceptions.append(exc.get("exception_id", str(path)))

if unapproved_high_critical:
    blocking.append(f"unapproved high/critical exceptions: {', '.join(unapproved_high_critical)}")

if expired_exceptions:
    blocking.append(f"expired exceptions: {', '.join(expired_exceptions)}")

decision = "approved_to_release" if not blocking else "blocked"

timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
decision_file = report_dir / f"production-release-decision-{timestamp}.json"

result = {
    "service_name": release.get("service_name", "demo-node-api"),
    "gate": "production_release_decision",
    "environment": environment,
    "release_file": str(release_file),
    "evidence_manifest": str(manifest_path) if manifest_path else "",
    "artifact": artifact,
    "rollback": rollback,
    "approval": approval,
    "required_evidence": required,
    "blocking": blocking,
    "warnings": warnings,
    "exception_files_checked": [str(p) for p in exception_files],
    "decision": decision,
    "created_at": datetime.now(timezone.utc).isoformat()
}

decision_file.write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps(result, indent=2))
print(f"Production release decision: {decision_file}")

if decision == "blocked" and fail_on_block:
    sys.exit(1)
```

Make executable:

```bash id="t1zzyd"
chmod +x security-evidence-release-approval/scripts/production-release-decision.py
```

Run:

```bash id="95xjs9"
ENVIRONMENT=production \
FAIL_ON_BLOCK=false \
./security-evidence-release-approval/scripts/production-release-decision.py
```

Expected first result may be blocked because approval is still pending.

That is correct.

---

# 12. Create Approval Record

Create:

```bash id="mokcz0"
nano security-evidence-release-approval/scripts/create-release-approval.sh
```

Paste:

```bash id="ql0m1a"
#!/usr/bin/env bash
set -euo pipefail

APPROVAL_DIR="${APPROVAL_DIR:-security-evidence-release-approval/approvals}"
REPORT_DIR="${REPORT_DIR:-security-evidence-release-approval/reports}"

SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"
ENVIRONMENT="${ENVIRONMENT:-production}"
ARTIFACT_IMAGE="${ARTIFACT_IMAGE:-}"
ARTIFACT_VERSION="${ARTIFACT_VERSION:-}"
ROLLBACK_VERSION="${ROLLBACK_VERSION:-}"
APPROVED_BY="${APPROVED_BY:-}"
APPROVAL_STATUS="${APPROVAL_STATUS:-approved}"
CHANGE_ID="${CHANGE_ID:-manual-change}"
EVIDENCE_MANIFEST="${EVIDENCE_MANIFEST:-}"

mkdir -p "$APPROVAL_DIR" "$REPORT_DIR"

if [ "$ENVIRONMENT" = "production" ]; then
  test -n "$ARTIFACT_IMAGE" || { echo "ERROR: ARTIFACT_IMAGE required"; exit 1; }
  test -n "$ARTIFACT_VERSION" || { echo "ERROR: ARTIFACT_VERSION required"; exit 1; }
  test -n "$ROLLBACK_VERSION" || { echo "ERROR: ROLLBACK_VERSION required"; exit 1; }
  test -n "$APPROVED_BY" || { echo "ERROR: APPROVED_BY required"; exit 1; }
fi

case "$ARTIFACT_IMAGE" in
  *:latest|*:prod|*:production|*:stable)
    echo "ERROR: refusing mutable production artifact tag: $ARTIFACT_IMAGE" >&2
    exit 1
    ;;
esac

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
APPROVAL_FILE="$APPROVAL_DIR/release-approval-$ENVIRONMENT-$TIMESTAMP.json"

cat > "$APPROVAL_FILE" <<EOF
{
  "service_name": "$SERVICE_NAME",
  "environment": "$ENVIRONMENT",
  "change_id": "$CHANGE_ID",
  "artifact": {
    "image": "$ARTIFACT_IMAGE",
    "version": "$ARTIFACT_VERSION"
  },
  "rollback": {
    "version": "$ROLLBACK_VERSION"
  },
  "approval": {
    "status": "$APPROVAL_STATUS",
    "approved_by": "$APPROVED_BY",
    "approved_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "evidence_manifest": "$EVIDENCE_MANIFEST"
}
EOF

cp "$APPROVAL_FILE" "$REPORT_DIR/$(basename "$APPROVAL_FILE")"

cat "$APPROVAL_FILE" | jq .

echo "Approval record: $APPROVAL_FILE"
```

Make executable:

```bash id="ni8g07"
chmod +x security-evidence-release-approval/scripts/create-release-approval.sh
```

Run example:

```bash id="js4jgl"
ARTIFACT_IMAGE=demo-node-api:0.9.0-prod-a1b2c3d \
ARTIFACT_VERSION=0.9.0-prod-a1b2c3d \
ROLLBACK_VERSION=0.8.0-prod-f9e8d7c \
APPROVED_BY=security-team \
CHANGE_ID=CHG-2026-001 \
./security-evidence-release-approval/scripts/create-release-approval.sh
```

---

# 13. Security Dashboard Generator

Create:

```bash id="6nm197"
nano security-evidence-release-approval/scripts/create-security-dashboard.py
```

Paste:

```python id="rp0lpl"
#!/usr/bin/env python3

import json
import os
from pathlib import Path
from datetime import datetime, timezone

module_dir = Path(os.environ.get("MODULE_DIR", Path.home() / "devops-masterclass/09-devsecops-security-gates"))
output_dir = module_dir / "security-evidence-release-approval/dashboard"
report_dir = module_dir / "security-evidence-release-approval/reports"

output_dir.mkdir(parents=True, exist_ok=True)

gate_dirs = {
    "sast": "sast-semgrep/reports",
    "secret_scan": "secret-scanning/reports",
    "sca": "sca-dependency-scanning/reports",
    "container_image_scan": "container-image-scanning/reports",
    "dockerfile_security": "dockerfile-build-security/reports",
    "iac_security": "iac-security-scanning/reports",
    "sbom_license": "sbom-license-policy/reports",
    "policy_as_code": "policy-as-code-opa/reports",
    "dast_runtime": "dast-runtime-security/reports",
    "release_approval": "security-evidence-release-approval/reports"
}

def latest_summary(path: Path):
    if not path.exists():
        return None

    files = sorted(path.glob("*summary*.json"))
    if not files:
        files = sorted(path.glob("*decision*.json"))

    if not files:
        return None

    latest = files[-1]

    try:
        data = json.loads(latest.read_text(encoding="utf-8"))
    except Exception:
        data = {"parse_error": True}

    return {
        "file": str(latest),
        "data": data
    }

gates = {}

for gate, rel_dir in gate_dirs.items():
    summary = latest_summary(module_dir / rel_dir)
    if summary:
        data = summary["data"]
        decision = data.get("decision") or data.get("approval", {}).get("status") or "unknown"
        gates[gate] = {
            "status": "present",
            "decision": decision,
            "summary_file": summary["file"]
        }
    else:
        gates[gate] = {
            "status": "missing",
            "decision": "unknown",
            "summary_file": ""
        }

present_count = sum(1 for value in gates.values() if value["status"] == "present")
missing_count = sum(1 for value in gates.values() if value["status"] == "missing")
failed_count = sum(1 for value in gates.values() if value["decision"] in ["failed", "blocked"])

dashboard = {
    "service_name": "demo-node-api",
    "dashboard": "module_9_security_evidence",
    "present_count": present_count,
    "missing_count": missing_count,
    "failed_or_blocked_count": failed_count,
    "gates": gates,
    "created_at": datetime.now(timezone.utc).isoformat()
}

timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
dashboard_file = output_dir / f"security-dashboard-{timestamp}.json"
latest_file = output_dir / "security-dashboard-latest.json"

dashboard_file.write_text(json.dumps(dashboard, indent=2), encoding="utf-8")
latest_file.write_text(json.dumps(dashboard, indent=2), encoding="utf-8")

print(json.dumps(dashboard, indent=2))
print(f"Dashboard: {dashboard_file}")
print(f"Latest: {latest_file}")
```

Make executable:

```bash id="vyl3jw"
chmod +x security-evidence-release-approval/scripts/create-security-dashboard.py
```

Run:

```bash id="2alx5i"
./security-evidence-release-approval/scripts/create-security-dashboard.py
```

---

# 14. Release Approval Checklist

Create:

```bash id="olbt1d"
nano security-evidence-release-approval/runbooks/production-release-approval-checklist.md
```

Paste:

```markdown id="ecoe9l"
# Production Release Approval Checklist

## Release Metadata

- [ ] Service name is correct.
- [ ] Artifact image tag is immutable.
- [ ] Artifact digest is recorded.
- [ ] Version is recorded.
- [ ] SBOM reference exists.
- [ ] Provenance reference exists.
- [ ] Signature evidence exists where required.
- [ ] Rollback version is recorded.

## Required Security Evidence

- [ ] SAST report exists.
- [ ] Secret scan report exists.
- [ ] SCA dependency scan report exists.
- [ ] Container image scan report exists.
- [ ] Dockerfile security report exists.
- [ ] IaC security report exists.
- [ ] SBOM/license report exists.
- [ ] Policy-as-code report exists.
- [ ] DAST/runtime report exists.

## Risk Review

- [ ] No unresolved critical findings.
- [ ] No unresolved high findings without approved exception.
- [ ] Exceptions are approved.
- [ ] Exceptions are not expired.
- [ ] Exceptions include compensating controls.
- [ ] Exceptions include fix plan.

## Deployment Readiness

- [ ] Deployment plan exists.
- [ ] Rollback plan exists.
- [ ] Runtime verification plan exists.
- [ ] Monitoring is available.
- [ ] On-call owner is known.

## Approval

- [ ] Security evidence reviewed.
- [ ] Release owner approved.
- [ ] Security/platform approver recorded.
- [ ] Change ID recorded.
```

---

# 15. DevSecOps Release Runbook

Create:

```bash id="8iqank"
nano security-evidence-release-approval/runbooks/devsecops-release-runbook.md
```

Paste:

````markdown id="4f8fky"
# DevSecOps Release Runbook

## Goal

Approve a production release only after required security evidence is available.

## Step 1 — Build Artifact

Use immutable tag:

```bash
demo-node-api:0.9.0-prod-a1b2c3d
````

Do not use:

```bash id="bzj9ri"
latest
prod
production
stable
```

## Step 2 — Run Security Gates

Required gates:

* SAST
* secret scanning
* SCA
* container image scanning
* Dockerfile security
* IaC security
* SBOM/license policy
* policy as code
* DAST/runtime smoke

## Step 3 — Collect Evidence

```bash id="z35n9i"
ENVIRONMENT=production \
ARTIFACT_VERSION=0.9.0-prod-a1b2c3d \
ARTIFACT_IMAGE=demo-node-api:0.9.0-prod-a1b2c3d \
ROLLBACK_VERSION=0.8.0-prod-f9e8d7c \
./security-evidence-release-approval/scripts/collect-security-evidence.sh
```

## Step 4 — Validate Exceptions

```bash id="em1xeo"
EXCEPTION_FILE=security-evidence-release-approval/exceptions/example.json \
./security-evidence-release-approval/scripts/validate-risk-exception.py
```

## Step 5 — Create Approval

```bash id="p4pfoz"
ARTIFACT_IMAGE=demo-node-api:0.9.0-prod-a1b2c3d \
ARTIFACT_VERSION=0.9.0-prod-a1b2c3d \
ROLLBACK_VERSION=0.8.0-prod-f9e8d7c \
APPROVED_BY=security-team \
CHANGE_ID=CHG-2026-001 \
./security-evidence-release-approval/scripts/create-release-approval.sh
```

## Step 6 — Make Release Decision

```bash id="7ea1f8"
ENVIRONMENT=production \
FAIL_ON_BLOCK=true \
./security-evidence-release-approval/scripts/production-release-decision.py
```

## Step 7 — Deploy

Deploy only after decision is approved.

## Step 8 — Verify

Run:

* health check
* version check
* smoke tests
* monitoring check

## Step 9 — Rollback if Needed

Use recorded rollback version.

````

---

# 16. Risk Exception Runbook

Create:

```bash id="yx5vl0"
nano security-evidence-release-approval/runbooks/risk-exception-runbook.md
````

Paste:

````markdown id="fe5o3v"
# Risk Exception Runbook

## Goal

Handle temporary accepted security risk safely.

## Exception Requirements

Every exception must include:

- exception ID
- category
- severity
- affected artifact
- affected environment
- finding ID
- reason
- risk owner
- approver
- created date
- expiry date
- compensating controls
- fix plan
- status

## Rules

- Critical production exceptions require explicit approval.
- Exceptions must expire.
- Exceptions must not reference mutable artifact tags.
- Exceptions must include compensating controls.
- Exceptions must include a fix plan.
- Expired exceptions block production.

## Bad Exception

```json
{
  "reason": "",
  "expires_on": "",
  "approved_by": ""
}
````

## Good Exception

```json
{
  "reason": "No fixed version available",
  "expires_on": "2026-08-10",
  "approved_by": "security-team",
  "compensating_controls": ["WAF rule", "restricted ingress"],
  "fix_plan": "Upgrade base image when patch is available"
}
```

````

---

# 17. Combined Release Approval Gate

Create:

```bash id="0nzv6d"
nano security-evidence-release-approval/scripts/release-approval-gate.sh
````

Paste:

```bash id="fn4b8e"
#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="${MODULE_DIR:-$HOME/devops-masterclass/09-devsecops-security-gates}"
ENVIRONMENT="${ENVIRONMENT:-production}"
ARTIFACT_VERSION="${ARTIFACT_VERSION:-}"
ARTIFACT_IMAGE="${ARTIFACT_IMAGE:-}"
ROLLBACK_VERSION="${ROLLBACK_VERSION:-}"
APPROVED_BY="${APPROVED_BY:-}"
CHANGE_ID="${CHANGE_ID:-manual-change}"
FAIL_ON_BLOCK="${FAIL_ON_BLOCK:-true}"

echo "===== Release Approval Gate ====="
echo "Environment: $ENVIRONMENT"
echo "Artifact version: $ARTIFACT_VERSION"
echo "Artifact image: $ARTIFACT_IMAGE"
echo "Rollback version: $ROLLBACK_VERSION"

cd "$MODULE_DIR"

ENVIRONMENT="$ENVIRONMENT" \
ARTIFACT_VERSION="$ARTIFACT_VERSION" \
ARTIFACT_IMAGE="$ARTIFACT_IMAGE" \
ROLLBACK_VERSION="$ROLLBACK_VERSION" \
./security-evidence-release-approval/scripts/collect-security-evidence.sh

LATEST_MANIFEST="$(ls -t security-evidence-release-approval/evidence/*/evidence-manifest.json | head -n 1)"

if [ -n "$APPROVED_BY" ]; then
  ARTIFACT_IMAGE="$ARTIFACT_IMAGE" \
  ARTIFACT_VERSION="$ARTIFACT_VERSION" \
  ROLLBACK_VERSION="$ROLLBACK_VERSION" \
  APPROVED_BY="$APPROVED_BY" \
  CHANGE_ID="$CHANGE_ID" \
  EVIDENCE_MANIFEST="$LATEST_MANIFEST" \
  ./security-evidence-release-approval/scripts/create-release-approval.sh
else
  echo "WARN: APPROVED_BY not set. Approval record will not be created."
fi

./security-evidence-release-approval/scripts/create-security-dashboard.py

ENVIRONMENT="$ENVIRONMENT" \
EVIDENCE_MANIFEST="$LATEST_MANIFEST" \
FAIL_ON_BLOCK="$FAIL_ON_BLOCK" \
./security-evidence-release-approval/scripts/production-release-decision.py
```

Make executable:

```bash id="y70701"
chmod +x security-evidence-release-approval/scripts/release-approval-gate.sh
```

Run report mode:

```bash id="c4uxjb"
ENVIRONMENT=production \
ARTIFACT_VERSION=0.9.0-prod-a1b2c3d \
ARTIFACT_IMAGE=demo-node-api:0.9.0-prod-a1b2c3d \
ROLLBACK_VERSION=0.8.0-prod-f9e8d7c \
APPROVED_BY=security-team \
CHANGE_ID=CHG-2026-001 \
FAIL_ON_BLOCK=false \
./security-evidence-release-approval/scripts/release-approval-gate.sh
```

---

# 18. GitHub Actions Release Approval Workflow

Create:

```bash id="4du58v"
nano security-evidence-release-approval/github-actions/security-release-approval.yml
```

Paste:

```yaml id="mn2u87"
name: Security Release Approval

on:
  workflow_dispatch:
    inputs:
      artifact_image:
        description: "Immutable artifact image"
        required: true
        default: "demo-node-api:0.9.0-prod-a1b2c3d"
        type: string
      artifact_version:
        description: "Artifact version"
        required: true
        default: "0.9.0-prod-a1b2c3d"
        type: string
      rollback_version:
        description: "Rollback version"
        required: true
        default: "0.8.0-prod-f9e8d7c"
        type: string
      change_id:
        description: "Change/release ID"
        required: true
        default: "CHG-2026-001"
        type: string

permissions:
  contents: read
  actions: read

env:
  MODULE9_DIR: 09-devsecops-security-gates

jobs:
  security-evidence:
    name: Collect security evidence
    runs-on: ubuntu-latest

    outputs:
      artifact_image: ${{ inputs.artifact_image }}
      artifact_version: ${{ inputs.artifact_version }}
      rollback_version: ${{ inputs.rollback_version }}
      change_id: ${{ inputs.change_id }}

    steps:
      - uses: actions/checkout@v4

      - name: Validate artifact tag
        run: |
          case "${{ inputs.artifact_image }}" in
            *:latest|*:prod|*:production|*:stable)
              echo "Refusing mutable artifact tag: ${{ inputs.artifact_image }}"
              exit 1
              ;;
          esac

      - name: Collect evidence and create dashboard
        run: |
          cd "$MODULE9_DIR"

          ENVIRONMENT=production \
          ARTIFACT_VERSION="${{ inputs.artifact_version }}" \
          ARTIFACT_IMAGE="${{ inputs.artifact_image }}" \
          ROLLBACK_VERSION="${{ inputs.rollback_version }}" \
          ./security-evidence-release-approval/scripts/collect-security-evidence.sh

          ./security-evidence-release-approval/scripts/create-security-dashboard.py

      - name: Upload security evidence
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: security-release-evidence
          path: |
            09-devsecops-security-gates/security-evidence-release-approval/evidence/
            09-devsecops-security-gates/security-evidence-release-approval/reports/
            09-devsecops-security-gates/security-evidence-release-approval/dashboard/

  production-approval:
    name: Production security approval
    runs-on: ubuntu-latest
    needs: security-evidence
    environment: production

    steps:
      - uses: actions/checkout@v4

      - name: Create approval record
        run: |
          cd "$MODULE9_DIR"

          ARTIFACT_IMAGE="${{ needs.security-evidence.outputs.artifact_image }}" \
          ARTIFACT_VERSION="${{ needs.security-evidence.outputs.artifact_version }}" \
          ROLLBACK_VERSION="${{ needs.security-evidence.outputs.rollback_version }}" \
          CHANGE_ID="${{ needs.security-evidence.outputs.change_id }}" \
          APPROVED_BY="${{ github.actor }}" \
          ./security-evidence-release-approval/scripts/create-release-approval.sh

      - name: Final release decision
        run: |
          cd "$MODULE9_DIR"

          ENVIRONMENT=production \
          FAIL_ON_BLOCK=false \
          ./security-evidence-release-approval/scripts/production-release-decision.py

      - name: Upload approval evidence
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: security-release-approval
          path: |
            09-devsecops-security-gates/security-evidence-release-approval/approvals/
            09-devsecops-security-gates/security-evidence-release-approval/reports/
```

Copy:

```bash id="3g389u"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/security-evidence-release-approval/github-actions/security-release-approval.yml \
   .github/workflows/security-release-approval.yml
```

In GitHub, configure an environment named `production` and add required reviewers. GitHub’s environment protection rules can require reviewers before jobs using that environment continue. GitHub workflow artifacts can be used to upload generated evidence files and reports from jobs. ([GitHub Docs][2])

---

# 19. Jenkins Release Approval Pipeline

Create:

```bash id="k1namv"
nano security-evidence-release-approval/jenkins/Jenkinsfile.security-release-approval
```

Paste:

```groovy id="e7x5ee"
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 60, unit: 'MINUTES')
  }

  parameters {
    string(name: 'ARTIFACT_IMAGE', defaultValue: 'demo-node-api:0.9.0-prod-a1b2c3d', description: 'Immutable artifact image')
    string(name: 'ARTIFACT_VERSION', defaultValue: '0.9.0-prod-a1b2c3d', description: 'Artifact version')
    string(name: 'ROLLBACK_VERSION', defaultValue: '0.8.0-prod-f9e8d7c', description: 'Rollback version')
    string(name: 'CHANGE_ID', defaultValue: 'CHG-2026-001', description: 'Change ID')
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

    stage('Validate Inputs') {
      steps {
        sh '''
          case "${ARTIFACT_IMAGE}" in
            *:latest|*:prod|*:production|*:stable)
              echo "Refusing mutable artifact tag: ${ARTIFACT_IMAGE}"
              exit 1
              ;;
          esac

          test -n "${ROLLBACK_VERSION}"
        '''
      }
    }

    stage('Collect Evidence') {
      steps {
        dir("${MODULE9_DIR}") {
          sh '''
            ENVIRONMENT=production \
            ARTIFACT_VERSION="${ARTIFACT_VERSION}" \
            ARTIFACT_IMAGE="${ARTIFACT_IMAGE}" \
            ROLLBACK_VERSION="${ROLLBACK_VERSION}" \
            ./security-evidence-release-approval/scripts/collect-security-evidence.sh

            ./security-evidence-release-approval/scripts/create-security-dashboard.py
          '''
        }
      }
    }

    stage('Manual Security Approval') {
      steps {
        script {
          def approval = input(
            message: "Approve production release after reviewing security evidence?",
            ok: "Approve Release",
            parameters: [
              string(name: 'APPROVED_BY', defaultValue: 'security-team', description: 'Approver name/team'),
              booleanParam(name: 'EVIDENCE_REVIEWED', defaultValue: false, description: 'I reviewed security evidence')
            ]
          )

          if (!approval['EVIDENCE_REVIEWED']) {
            error("Security evidence must be reviewed before approval.")
          }

          env.APPROVED_BY = approval['APPROVED_BY']
        }
      }
    }

    stage('Create Approval and Decision') {
      steps {
        dir("${MODULE9_DIR}") {
          sh '''
            ARTIFACT_IMAGE="${ARTIFACT_IMAGE}" \
            ARTIFACT_VERSION="${ARTIFACT_VERSION}" \
            ROLLBACK_VERSION="${ROLLBACK_VERSION}" \
            CHANGE_ID="${CHANGE_ID}" \
            APPROVED_BY="${APPROVED_BY}" \
            ./security-evidence-release-approval/scripts/create-release-approval.sh

            ENVIRONMENT=production \
            FAIL_ON_BLOCK=false \
            ./security-evidence-release-approval/scripts/production-release-decision.py
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '''
        09-devsecops-security-gates/security-evidence-release-approval/evidence/**/*,
        09-devsecops-security-gates/security-evidence-release-approval/reports/**/*,
        09-devsecops-security-gates/security-evidence-release-approval/approvals/**/*,
        09-devsecops-security-gates/security-evidence-release-approval/dashboard/**/*
      ''', allowEmptyArchive: true
    }

    success {
      echo 'Security release approval pipeline completed.'
    }

    failure {
      echo 'Security release approval failed or was blocked.'
    }
  }
}
```

The Jenkins `input` step pauses the pipeline and allows a user to proceed or abort, optionally collecting parameters from the approver. ([Jenkins][3])

Jenkins script path:

```text id="ptcnqa"
09-devsecops-security-gates/security-evidence-release-approval/jenkins/Jenkinsfile.security-release-approval
```

---

# 20. GitLab CI Release Approval Pipeline

Create:

```bash id="tj5pnw"
nano security-evidence-release-approval/gitlab/.gitlab-ci.security-release-approval.yml
```

Paste:

```yaml id="2rkxoa"
stages:
  - evidence
  - approval
  - decision

variables:
  MODULE9_DIR: "09-devsecops-security-gates"
  ARTIFACT_IMAGE: "demo-node-api:0.9.0-prod-a1b2c3d"
  ARTIFACT_VERSION: "0.9.0-prod-a1b2c3d"
  ROLLBACK_VERSION: "0.8.0-prod-f9e8d7c"
  CHANGE_ID: "CHG-2026-001"

security_evidence:
  stage: evidence
  image: python:3.12-slim
  before_script:
    - apt-get update
    - apt-get install -y bash jq
  script:
    - cd "$MODULE9_DIR"
    - |
      case "$ARTIFACT_IMAGE" in
        *:latest|*:prod|*:production|*:stable)
          echo "Refusing mutable artifact tag: $ARTIFACT_IMAGE"
          exit 1
          ;;
      esac
    - |
      ENVIRONMENT=production \
      ARTIFACT_VERSION="$ARTIFACT_VERSION" \
      ARTIFACT_IMAGE="$ARTIFACT_IMAGE" \
      ROLLBACK_VERSION="$ROLLBACK_VERSION" \
      ./security-evidence-release-approval/scripts/collect-security-evidence.sh
    - ./security-evidence-release-approval/scripts/create-security-dashboard.py
  artifacts:
    when: always
    expire_in: 30 days
    paths:
      - 09-devsecops-security-gates/security-evidence-release-approval/evidence/
      - 09-devsecops-security-gates/security-evidence-release-approval/reports/
      - 09-devsecops-security-gates/security-evidence-release-approval/dashboard/

security_manual_approval:
  stage: approval
  image: alpine:3.20
  when: manual
  allow_failure: false
  script:
    - echo "Manual approval completed by GitLab user."
    - echo "Review security evidence artifacts from previous job before approving."

security_release_decision:
  stage: decision
  image: python:3.12-slim
  needs:
    - job: security_evidence
      artifacts: true
    - job: security_manual_approval
  before_script:
    - apt-get update
    - apt-get install -y bash jq
  script:
    - cd "$MODULE9_DIR"
    - |
      ARTIFACT_IMAGE="$ARTIFACT_IMAGE" \
      ARTIFACT_VERSION="$ARTIFACT_VERSION" \
      ROLLBACK_VERSION="$ROLLBACK_VERSION" \
      CHANGE_ID="$CHANGE_ID" \
      APPROVED_BY="${GITLAB_USER_LOGIN:-gitlab-approver}" \
      ./security-evidence-release-approval/scripts/create-release-approval.sh
    - |
      ENVIRONMENT=production \
      FAIL_ON_BLOCK=false \
      ./security-evidence-release-approval/scripts/production-release-decision.py
  artifacts:
    when: always
    expire_in: 30 days
    paths:
      - 09-devsecops-security-gates/security-evidence-release-approval/approvals/
      - 09-devsecops-security-gates/security-evidence-release-approval/reports/
```

GitLab manual jobs can be optional or blocking; setting `allow_failure: false` with a manual job creates a blocking approval point before later stages continue. ([GitLab Docs][4])

---

# 21. Release Evidence Summary Script

Create:

```bash id="66mk2r"
nano security-evidence-release-approval/scripts/release-evidence-summary.sh
```

Paste:

```bash id="a7un2d"
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-security-evidence-release-approval}"

echo "===== Release Evidence Summary ====="

echo
echo "Latest evidence manifest:"
LATEST_MANIFEST="$(find "$BASE_DIR/evidence" -type f -name 'evidence-manifest.json' | sort | tail -n 1 || true)"
if [ -n "$LATEST_MANIFEST" ]; then
  echo "$LATEST_MANIFEST"
  jq . "$LATEST_MANIFEST"
else
  echo "No evidence manifest found."
fi

echo
echo "Latest approval:"
LATEST_APPROVAL="$(find "$BASE_DIR/approvals" -type f -name 'release-approval-*.json' | sort | tail -n 1 || true)"
if [ -n "$LATEST_APPROVAL" ]; then
  echo "$LATEST_APPROVAL"
  jq . "$LATEST_APPROVAL"
else
  echo "No approval record found."
fi

echo
echo "Latest release decision:"
LATEST_DECISION="$(find "$BASE_DIR/reports" -type f -name 'production-release-decision-*.json' | sort | tail -n 1 || true)"
if [ -n "$LATEST_DECISION" ]; then
  echo "$LATEST_DECISION"
  jq . "$LATEST_DECISION"
else
  echo "No release decision found."
fi

echo
echo "Latest dashboard:"
LATEST_DASHBOARD="$BASE_DIR/dashboard/security-dashboard-latest.json"
if [ -f "$LATEST_DASHBOARD" ]; then
  jq . "$LATEST_DASHBOARD"
else
  echo "No dashboard found."
fi
```

Make executable:

```bash id="sjeaas"
chmod +x security-evidence-release-approval/scripts/release-evidence-summary.sh
```

Run:

```bash id="vvne5s"
./security-evidence-release-approval/scripts/release-evidence-summary.sh
```

---

# 22. Validation Script

Create:

```bash id="ua7ope"
nano security-evidence-release-approval/scripts/validate-security-evidence-lesson.sh
```

Paste:

```bash id="dy0esk"
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-security-evidence-release-approval}"

echo "===== Validate Security Evidence Release Approval Lesson ====="

test -f "$BASE_DIR/policies/security-evidence-policy.json"
test -f "$BASE_DIR/policies/risk-exception-schema.json"
test -f "$BASE_DIR/notes/security-evidence-mental-model.md"

test -f "$BASE_DIR/examples/risk-exception-valid.json"
test -f "$BASE_DIR/examples/risk-exception-invalid.json"
test -f "$BASE_DIR/examples/release-metadata-example.json"

test -x "$BASE_DIR/scripts/validate-risk-exception.py"
test -x "$BASE_DIR/scripts/collect-security-evidence.sh"
test -x "$BASE_DIR/scripts/production-release-decision.py"
test -x "$BASE_DIR/scripts/create-release-approval.sh"
test -x "$BASE_DIR/scripts/create-security-dashboard.py"
test -x "$BASE_DIR/scripts/release-approval-gate.sh"
test -x "$BASE_DIR/scripts/release-evidence-summary.sh"

test -f "$BASE_DIR/github-actions/security-release-approval.yml"
test -f "$BASE_DIR/jenkins/Jenkinsfile.security-release-approval"
test -f "$BASE_DIR/gitlab/.gitlab-ci.security-release-approval.yml"

test -f "$BASE_DIR/runbooks/production-release-approval-checklist.md"
test -f "$BASE_DIR/runbooks/devsecops-release-runbook.md"
test -f "$BASE_DIR/runbooks/risk-exception-runbook.md"

echo "Security evidence release approval lesson validated."
```

Make executable:

```bash id="c594eg"
chmod +x security-evidence-release-approval/scripts/validate-security-evidence-lesson.sh
```

Run:

```bash id="ahoc3c"
./security-evidence-release-approval/scripts/validate-security-evidence-lesson.sh
```

---

# 23. Update Makefile

Open:

```bash id="svw4x6"
cd ~/devops-masterclass/09-devsecops-security-gates

nano Makefile
```

Add:

```Makefile id="8cnhdo"
.PHONY: evidence-validate evidence-collect exception-valid exception-invalid release-approval release-decision release-gate security-dashboard release-summary

evidence-validate:
	./security-evidence-release-approval/scripts/validate-security-evidence-lesson.sh

evidence-collect:
	ENVIRONMENT="$${ENVIRONMENT:-main}" \
	ARTIFACT_VERSION="$${ARTIFACT_VERSION:-0.9.0-dev-local}" \
	ARTIFACT_IMAGE="$${ARTIFACT_IMAGE:-demo-node-api:0.9.0-dev-local}" \
	ROLLBACK_VERSION="$${ROLLBACK_VERSION:-0.8.0-dev-local}" \
	./security-evidence-release-approval/scripts/collect-security-evidence.sh

exception-valid:
	EXCEPTION_FILE=security-evidence-release-approval/examples/risk-exception-valid.json \
	./security-evidence-release-approval/scripts/validate-risk-exception.py

exception-invalid:
	EXCEPTION_FILE=security-evidence-release-approval/examples/risk-exception-invalid.json \
	./security-evidence-release-approval/scripts/validate-risk-exception.py || true

release-approval:
	ARTIFACT_IMAGE="$${ARTIFACT_IMAGE:-demo-node-api:0.9.0-prod-a1b2c3d}" \
	ARTIFACT_VERSION="$${ARTIFACT_VERSION:-0.9.0-prod-a1b2c3d}" \
	ROLLBACK_VERSION="$${ROLLBACK_VERSION:-0.8.0-prod-f9e8d7c}" \
	APPROVED_BY="$${APPROVED_BY:-security-team}" \
	CHANGE_ID="$${CHANGE_ID:-CHG-2026-001}" \
	./security-evidence-release-approval/scripts/create-release-approval.sh

release-decision:
	ENVIRONMENT="$${ENVIRONMENT:-production}" \
	FAIL_ON_BLOCK="$${FAIL_ON_BLOCK:-false}" \
	./security-evidence-release-approval/scripts/production-release-decision.py

release-gate:
	ENVIRONMENT="$${ENVIRONMENT:-production}" \
	ARTIFACT_VERSION="$${ARTIFACT_VERSION:-0.9.0-prod-a1b2c3d}" \
	ARTIFACT_IMAGE="$${ARTIFACT_IMAGE:-demo-node-api:0.9.0-prod-a1b2c3d}" \
	ROLLBACK_VERSION="$${ROLLBACK_VERSION:-0.8.0-prod-f9e8d7c}" \
	APPROVED_BY="$${APPROVED_BY:-security-team}" \
	CHANGE_ID="$${CHANGE_ID:-CHG-2026-001}" \
	FAIL_ON_BLOCK="$${FAIL_ON_BLOCK:-false}" \
	./security-evidence-release-approval/scripts/release-approval-gate.sh

security-dashboard:
	./security-evidence-release-approval/scripts/create-security-dashboard.py

release-summary:
	./security-evidence-release-approval/scripts/release-evidence-summary.sh
```

Run:

```bash id="mpwcp7"
make evidence-validate
make exception-valid
make exception-invalid
make evidence-collect
make security-dashboard
make release-approval
make release-decision
make release-summary
```

---

# 24. Practical Lab

Run:

```bash id="hj3kl0"
cd ~/devops-masterclass/09-devsecops-security-gates

make evidence-validate

make exception-valid
make exception-invalid

ENVIRONMENT=main \
ARTIFACT_VERSION=0.9.0-dev-local \
ARTIFACT_IMAGE=demo-node-api:0.9.0-dev-local \
ROLLBACK_VERSION=0.8.0-dev-local \
make evidence-collect

make security-dashboard
make release-summary
```

Production-style simulation:

```bash id="i7bcok"
ENVIRONMENT=production \
ARTIFACT_VERSION=0.9.0-prod-a1b2c3d \
ARTIFACT_IMAGE=demo-node-api:0.9.0-prod-a1b2c3d \
ROLLBACK_VERSION=0.8.0-prod-f9e8d7c \
APPROVED_BY=security-team \
CHANGE_ID=CHG-2026-001 \
FAIL_ON_BLOCK=false \
make release-gate
```

Copy GitHub workflow:

```bash id="gx2ok2"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/security-evidence-release-approval/github-actions/security-release-approval.yml \
   .github/workflows/security-release-approval.yml
```

Commit:

```bash id="a0merj"
git status

git add .github/workflows/security-release-approval.yml \
        09-devsecops-security-gates

git commit -m "feat: add security evidence and release approval gates"
git push
```

---

# 25. Common Problems

## Evidence missing

Run individual gates first:

```bash id="n7c938"
make sast-scan
make secret-scan
make sca-scan
make image-scan
make dockerfile-gate
make iac-scan
make sbom-gate
make policy-gate
make dast-gate
```

Then collect evidence again:

```bash id="er5sm2"
make evidence-collect
```

## Production decision is blocked

Check:

```bash id="qwj9ka"
make release-summary
```

Common causes:

```text id="tl75zu"
missing evidence manifest
missing SBOM
missing rollback version
pending approval
mutable artifact tag
expired exception
unapproved high/critical exception
```

## Exception validation fails

Fix required fields:

```text id="3z95lu"
reason
risk_owner
approved_by
expires_on
compensating_controls
fix_plan
status
```

## GitHub approval does not pause

Make sure the workflow job uses:

```yaml id="hso7x2"
environment: production
```

Then configure the `production` environment in GitHub settings with required reviewers. GitHub supports required reviewers on environments, and only one of the listed reviewers needs to approve the job for it to proceed. ([GitHub Docs][2])

## GitLab manual approval is not blocking

Use:

```yaml id="mj93lo"
when: manual
allow_failure: false
```

GitLab documents that manual jobs can be blocking when configured with `allow_failure: false`. ([GitLab Docs][5])

---

# 26. Interview Explanation

## What is security evidence?

```text id="1bitbi"
Security evidence is the collection of reports, metadata, approvals, exceptions, SBOMs, and release records that prove a software artifact passed required security controls before deployment.
```

## Why is evidence important?

```text id="0pjopl"
Evidence makes security controls auditable. It helps teams prove what was scanned, which artifact was reviewed, what risks existed, which exceptions were approved, and whether production release requirements were met.
```

## What should be required before production approval?

```text id="z31z41"
A production release should require immutable artifact metadata, SBOM, scan reports, policy results, DAST/runtime evidence, valid exceptions, rollback version, and a recorded manual approval.
```

## What is a risk exception?

```text id="8sqts5"
A risk exception is a temporary approved acceptance of a security finding. It should include the finding, severity, affected artifact, owner, reason, approver, expiry date, compensating controls, and fix plan.
```

## Why must exceptions expire?

```text id="bay43k"
If exceptions do not expire, they become permanent hidden risk. Expiry forces re-review and ensures the team either fixes the issue or explicitly re-accepts the risk.
```

## How do you implement release approval in CI/CD?

```text id="uxp7ic"
In GitHub Actions I use environments with required reviewers. In Jenkins I use the input step. In GitLab CI I use blocking manual jobs. In all cases, approval should happen after security evidence is collected and before production deployment.
```

---

# 27. Today’s Core Rules

```text id="s2xs4h"
Security evidence proves what happened.
Production approval must depend on evidence.
Do not approve production blindly.
Use immutable artifact tags.
Require rollback version.
Require SBOM for production.
Validate exceptions before release.
Exceptions must have owner, reason, approver, expiry, compensating controls, and fix plan.
Expired exceptions block production.
Archive evidence as CI/CD artifacts.
Approval records should include approver, time, artifact, rollback, and evidence reference.
```

---

# Next Lesson

# Lesson 9.12 — DevSecOps Capstone Project

We will combine the entire Module 9 into one production-style security pipeline:

```text id="r0mbyb"
SAST
secret scanning
SCA
container image scanning
Dockerfile security
IaC scanning
SBOM and license policy
OPA policy as code
DAST runtime security
security evidence collection
risk exception validation
release approval
final DevSecOps dashboard
Module 9 final commit and tag v0.9.0
```

[1]: https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments?utm_source=chatgpt.com "Deployments and environments"
[2]: https://docs.github.com/actions/deployment/targeting-different-environments/using-environments-for-deployment?utm_source=chatgpt.com "Managing environments for deployment"
[3]: https://www.jenkins.io/doc/pipeline/steps/pipeline-input-step/?utm_source=chatgpt.com "Pipeline: Input Step"
[4]: https://docs.gitlab.com/ci/jobs/job_control/?utm_source=chatgpt.com "Control how jobs run"
[5]: https://docs.gitlab.com/ci/yaml/?utm_source=chatgpt.com "CI/CD YAML syntax reference"

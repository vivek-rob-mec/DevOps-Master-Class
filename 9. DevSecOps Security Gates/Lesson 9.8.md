# Lesson 9.8 — SBOM Security and License Policy

# CycloneDX SBOMs, SPDX License IDs, Trivy SBOM Generation/Scanning, License Inventory, License Allow/Deny Policy, GitHub Actions, Jenkins, GitLab CI, and Production SBOM Gates

In Lesson 9.7, we scanned IaC.

Now we add **SBOM and license policy**.

```text id="bdu6a1"
SBOM = Software Bill of Materials
```

An SBOM answers:

```text id="56vuwg"
What components are inside this software artifact?
Which versions?
Which package ecosystem?
Which licenses?
Which vulnerabilities?
Which artifact does this SBOM belong to?
Can production prove what it shipped?
```

Trivy can generate SBOMs in CycloneDX format, and CycloneDX conventionally uses names like `bom.json`, `bom.xml`, `*.cdx.json`, and `*.cdx.xml` for BOM files. SPDX is another SBOM/license standard and provides standardized license identifiers through the SPDX License List. ([Trivy][1])

---

# 1. SBOM Mental Model

Your application artifact is not just your code.

It contains:

```text id="nb74kh"
your source code
npm dependencies
transitive npm dependencies
Node.js runtime
OS packages in the container image
base image layers
licenses
metadata
```

An SBOM is an inventory of those components.

Without an SBOM:

```text id="m9kbmh"
critical vulnerability announced
  ↓
team asks: are we affected?
  ↓
nobody knows quickly
```

With an SBOM:

```text id="ddsq65"
critical vulnerability announced
  ↓
search SBOM
  ↓
identify package/version/artifact
  ↓
patch or prove not affected
```

Professional rule:

```text id="v93zn0"
You cannot protect or patch what you cannot inventory.
```

---

# 2. SBOM vs SCA vs Image Scan

```text id="n3sg57"
SCA:
  finds vulnerable dependencies

Image scan:
  finds vulnerabilities in final container image

SBOM:
  records what components exist in the artifact

License policy:
  decides whether dependency licenses are allowed
```

Example:

```text id="iwwq55"
Trivy image scan:
  openssl has CVE

SBOM:
  openssl version 3.x exists in image

License inventory:
  dependency uses MIT license

License policy:
  MIT allowed
```

---

# 3. Why License Policy Matters

Open-source packages come with licenses.

Common permissive licenses:

```text id="4qbnpz"
MIT
Apache-2.0
BSD-2-Clause
BSD-3-Clause
ISC
```

Common high-review licenses:

```text id="5tc66p"
GPL-2.0
GPL-3.0
AGPL-3.0
LGPL
unknown
custom
```

This does not mean every GPL package is “bad.” It means your organization may require review before using it.

Professional rule:

```text id="0j8bpc"
License risk should be reviewed before production release, not after shipment.
```

The SPDX License List provides standardized short identifiers, full names, license text, and canonical URLs for commonly found software, data, hardware, and documentation licenses. ([SPDX][2])

---

# 4. Create Lesson Directory

Run:

```bash id="hec6jf"
cd ~/devops-masterclass/09-devsecops-security-gates

mkdir -p sbom-license-policy/{sbom,licenses,scripts,reports,github-actions,jenkins,gitlab,runbooks,examples,notes,policies}
```

Check:

```bash id="9oai8i"
tree -L 2 sbom-license-policy
```

---

# 5. SBOM and License Policy

Create:

```bash id="arxmjj"
nano sbom-license-policy/policies/sbom-license-policy.json
```

Paste:

```json id="1mnxdc"
{
  "service_name": "demo-node-api",
  "policy_version": "1.0",
  "sbom": {
    "required_for_main": true,
    "required_for_production": true,
    "accepted_formats": ["cyclonedx-json", "spdx-json"],
    "minimum_fields": [
      "bomFormat",
      "specVersion",
      "metadata",
      "components"
    ]
  },
  "licenses": {
    "allowed": [
      "MIT",
      "Apache-2.0",
      "BSD-2-Clause",
      "BSD-3-Clause",
      "ISC",
      "0BSD",
      "CC0-1.0"
    ],
    "review_required": [
      "GPL-2.0",
      "GPL-3.0",
      "AGPL-3.0",
      "LGPL-2.1",
      "LGPL-3.0",
      "MPL-2.0",
      "EPL-2.0",
      "CDDL-1.0",
      "UNKNOWN",
      "UNLICENSED"
    ],
    "denied": [
      "WTFPL"
    ]
  },
  "environments": {
    "pull_request": {
      "sbom_required": false,
      "license_unknown": "warn",
      "license_review_required": "warn"
    },
    "main": {
      "sbom_required": true,
      "license_unknown": "warn",
      "license_review_required": "warn"
    },
    "production": {
      "sbom_required": true,
      "license_unknown": "fail",
      "license_review_required": "fail_without_exception",
      "denied_license": "fail"
    }
  },
  "exception_policy": {
    "allowed": true,
    "requires_owner": true,
    "requires_reason": true,
    "requires_expiry": true,
    "requires_legal_or_security_review": true,
    "max_days": 90
  }
}
```

---

# 6. Notes

Create:

```bash id="v955wd"
nano sbom-license-policy/notes/sbom-license-mental-model.md
```

Paste:

```markdown id="fz2tpj"
# SBOM and License Policy Mental Model

## SBOM

A Software Bill of Materials is an inventory of software components inside an application or artifact.

## Why SBOM Matters

SBOMs help answer:

- what package is included?
- which version?
- where did it come from?
- which artifact contains it?
- which license applies?
- are we affected by a new CVE?

## Common SBOM Formats

- CycloneDX
- SPDX

## License Policy

License policy defines which open-source licenses are allowed, require review, or are denied.

## Production Rule

Production artifacts should have:

- SBOM
- vulnerability scan report
- license inventory
- release metadata
- artifact tag or digest
```

---

# 7. Generate CycloneDX SBOM with Trivy

For filesystem/app source:

```bash id="lnpqpr"
cd ~/devops-masterclass

trivy fs \
  --format cyclonedx \
  --output 09-devsecops-security-gates/sbom-license-policy/sbom/demo-node-api-fs.cdx.json \
  05-application-runtime/demo-node-api
```

For container image:

```bash id="zu6r96"
trivy image \
  --format cyclonedx \
  --output 09-devsecops-security-gates/sbom-license-policy/sbom/demo-node-api-image.cdx.json \
  demo-node-api:0.9.0-dev-local
```

Trivy’s SBOM documentation shows SBOM generation through regular scan subcommands such as image and filesystem scans, with CycloneDX output support. ([Trivy][1])

---

# 8. Scan an SBOM with Trivy

Once you have an SBOM, scan it:

```bash id="tgkopl"
trivy sbom \
  --format json \
  --output 09-devsecops-security-gates/sbom-license-policy/reports/trivy-sbom-scan.json \
  09-devsecops-security-gates/sbom-license-policy/sbom/demo-node-api-fs.cdx.json
```

This pattern is useful because your pipeline can generate an SBOM once and later rescan the SBOM when vulnerability databases change.

```text id="q83sh4"
build artifact once
  ↓
generate SBOM
  ↓
store SBOM
  ↓
rescan SBOM later for newly disclosed CVEs
```

---

# 9. SBOM Generation Script

Create:

```bash id="6nr3av"
cd ~/devops-masterclass/09-devsecops-security-gates

nano sbom-license-policy/scripts/generate-sbom.sh
```

Paste:

```bash id="vl29gq"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
MODULE_DIR="${MODULE_DIR:-$ROOT_DIR/09-devsecops-security-gates}"
APP_DIR="${APP_DIR:-$ROOT_DIR/05-application-runtime/demo-node-api}"
IMAGE_REF="${IMAGE_REF:-}"
SBOM_DIR="${SBOM_DIR:-$MODULE_DIR/sbom-license-policy/sbom}"
REPORT_DIR="${REPORT_DIR:-$MODULE_DIR/sbom-license-policy/reports}"
ARTIFACT_NAME="${ARTIFACT_NAME:-demo-node-api}"
ARTIFACT_VERSION="${ARTIFACT_VERSION:-local}"

mkdir -p "$SBOM_DIR" "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
SAFE_VERSION="$(echo "$ARTIFACT_VERSION" | tr '/:@' '____')"

FS_SBOM="$SBOM_DIR/$ARTIFACT_NAME-fs-$SAFE_VERSION-$TIMESTAMP.cdx.json"
IMAGE_SBOM=""

echo "===== Generate SBOM ====="
echo "App dir: $APP_DIR"
echo "Image ref: ${IMAGE_REF:-not-set}"
echo "Artifact version: $ARTIFACT_VERSION"

if ! command -v trivy >/dev/null 2>&1; then
  echo "ERROR: trivy is required" >&2
  exit 1
fi

trivy fs \
  --format cyclonedx \
  --output "$FS_SBOM" \
  "$APP_DIR"

if [ -n "$IMAGE_REF" ]; then
  case "$IMAGE_REF" in
    *:latest|*:prod|*:production|*:stable)
      echo "ERROR: refusing unsafe image tag for SBOM: $IMAGE_REF" >&2
      exit 1
      ;;
  esac

  SAFE_IMAGE="$(echo "$IMAGE_REF" | tr '/:@' '____')"
  IMAGE_SBOM="$SBOM_DIR/$ARTIFACT_NAME-image-$SAFE_IMAGE-$TIMESTAMP.cdx.json"

  trivy image \
    --format cyclonedx \
    --output "$IMAGE_SBOM" \
    "$IMAGE_REF"
fi

SUMMARY="$REPORT_DIR/sbom-generation-summary-$SAFE_VERSION-$TIMESTAMP.json"

cat > "$SUMMARY" <<EOF
{
  "service_name": "$ARTIFACT_NAME",
  "artifact_version": "$ARTIFACT_VERSION",
  "image_ref": "$IMAGE_REF",
  "fs_sbom": "$FS_SBOM",
  "image_sbom": "$IMAGE_SBOM",
  "format": "cyclonedx-json",
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY" | jq .

echo "Filesystem SBOM: $FS_SBOM"
if [ -n "$IMAGE_SBOM" ]; then
  echo "Image SBOM: $IMAGE_SBOM"
fi
```

Make executable:

```bash id="c0y7ib"
chmod +x sbom-license-policy/scripts/generate-sbom.sh
```

Run:

```bash id="s4qmbk"
ARTIFACT_VERSION=0.9.0-dev-local \
./sbom-license-policy/scripts/generate-sbom.sh
```

With image:

```bash id="d8pbdd"
IMAGE_REF=demo-node-api:0.9.0-dev-local \
ARTIFACT_VERSION=0.9.0-dev-local \
./sbom-license-policy/scripts/generate-sbom.sh
```

---

# 10. SBOM Validation Script

Create:

```bash id="rex28w"
nano sbom-license-policy/scripts/validate-sbom.sh
```

Paste:

```bash id="qkqpot"
#!/usr/bin/env bash
set -euo pipefail

SBOM_FILE="${SBOM_FILE:-}"
REPORT_DIR="${REPORT_DIR:-sbom-license-policy/reports}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"
FAIL_ON_INVALID="${FAIL_ON_INVALID:-true}"

if [ -z "$SBOM_FILE" ]; then
  echo "ERROR: SBOM_FILE is required" >&2
  exit 1
fi

if [ ! -f "$SBOM_FILE" ]; then
  echo "ERROR: SBOM file not found: $SBOM_FILE" >&2
  exit 1
fi

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
SUMMARY_FILE="$REPORT_DIR/sbom-validation-summary-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== Validate SBOM ====="
echo "SBOM file: $SBOM_FILE"
echo "Environment: $ENVIRONMENT"

BOM_FORMAT="$(jq -r '.bomFormat // empty' "$SBOM_FILE")"
SPEC_VERSION="$(jq -r '.specVersion // empty' "$SBOM_FILE")"
COMPONENT_COUNT="$(jq '.components // [] | length' "$SBOM_FILE")"
METADATA_PRESENT="$(jq 'has("metadata")' "$SBOM_FILE")"

DECISION="passed"
REASON="SBOM has required minimum fields"

if [ -z "$BOM_FORMAT" ] || [ -z "$SPEC_VERSION" ]; then
  DECISION="failed"
  REASON="SBOM missing bomFormat or specVersion"
fi

if [ "$COMPONENT_COUNT" -eq 0 ]; then
  DECISION="failed"
  REASON="SBOM has zero components"
fi

if [ "$METADATA_PRESENT" != "true" ]; then
  DECISION="failed"
  REASON="SBOM missing metadata"
fi

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "sbom_validation",
  "environment": "$ENVIRONMENT",
  "sbom_file": "$SBOM_FILE",
  "bom_format": "$BOM_FORMAT",
  "spec_version": "$SPEC_VERSION",
  "component_count": $COMPONENT_COUNT,
  "metadata_present": $METADATA_PRESENT,
  "decision": "$DECISION",
  "reason": "$REASON",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .

if [ "$DECISION" = "failed" ] && [ "$FAIL_ON_INVALID" = "true" ]; then
  echo "ERROR: SBOM validation failed" >&2
  exit 1
fi

echo "SBOM validation completed with decision: $DECISION"
```

Make executable:

```bash id="ykhlxk"
chmod +x sbom-license-policy/scripts/validate-sbom.sh
```

Run:

```bash id="yn4cb9"
LATEST_SBOM="$(ls -t sbom-license-policy/sbom/*fs*.cdx.json | head -n 1)"

SBOM_FILE="$LATEST_SBOM" \
ENVIRONMENT=main \
./sbom-license-policy/scripts/validate-sbom.sh
```

---

# 11. SBOM Vulnerability Scan Script

Create:

```bash id="2zsu4b"
nano sbom-license-policy/scripts/scan-sbom-vulnerabilities.sh
```

Paste:

```bash id="qks4aq"
#!/usr/bin/env bash
set -euo pipefail

SBOM_FILE="${SBOM_FILE:-}"
REPORT_DIR="${REPORT_DIR:-sbom-license-policy/reports}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
FAIL_ON_SCAN="${FAIL_ON_SCAN:-false}"

if [ -z "$SBOM_FILE" ]; then
  echo "ERROR: SBOM_FILE is required" >&2
  exit 1
fi

if [ ! -f "$SBOM_FILE" ]; then
  echo "ERROR: SBOM file not found: $SBOM_FILE" >&2
  exit 1
fi

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
SAFE_SBOM="$(basename "$SBOM_FILE" | tr '/:@' '____')"
REPORT_FILE="$REPORT_DIR/trivy-sbom-vuln-$ENVIRONMENT-$SAFE_SBOM-$TIMESTAMP.json"
SUMMARY_FILE="$REPORT_DIR/trivy-sbom-vuln-summary-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== Scan SBOM Vulnerabilities ====="
echo "SBOM file: $SBOM_FILE"
echo "Environment: $ENVIRONMENT"
echo "Severity: $SEVERITY"

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
trivy sbom \
  --severity "$SEVERITY" \
  --exit-code "$EXIT_CODE" \
  --format json \
  --output "$REPORT_FILE" \
  "$SBOM_FILE"
TRIVY_EXIT=$?
set -e

CRITICAL="$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length' "$REPORT_FILE")"
HIGH="$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length' "$REPORT_FILE")"
MEDIUM="$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "MEDIUM")] | length' "$REPORT_FILE")"
LOW="$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "LOW")] | length' "$REPORT_FILE")"
TOTAL="$(jq '[.Results[]?.Vulnerabilities[]?] | length' "$REPORT_FILE")"

DECISION="passed"

case "$ENVIRONMENT" in
  production|main)
    if [ "$HIGH" -gt 0 ] || [ "$CRITICAL" -gt 0 ]; then
      DECISION="failed"
    fi
    ;;
  pull_request|dev)
    if [ "$FAIL_ON_SCAN" = "true" ] && [ "$CRITICAL" -gt 0 ]; then
      DECISION="failed"
    fi
    ;;
esac

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "sbom_vulnerability_scan",
  "tool": "trivy sbom",
  "environment": "$ENVIRONMENT",
  "sbom_file": "$SBOM_FILE",
  "severity_filter": "$SEVERITY",
  "trivy_exit_code": $TRIVY_EXIT,
  "vulnerabilities": {
    "total": $TOTAL,
    "critical": $CRITICAL,
    "high": $HIGH,
    "medium": $MEDIUM,
    "low": $LOW
  },
  "decision": "$DECISION",
  "report_file": "$REPORT_FILE",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: SBOM vulnerability scan failed" >&2
  exit 1
fi

echo "SBOM vulnerability scan completed with decision: $DECISION"
```

Make executable:

```bash id="4ihj7d"
chmod +x sbom-license-policy/scripts/scan-sbom-vulnerabilities.sh
```

Run:

```bash id="6q5scv"
LATEST_SBOM="$(ls -t sbom-license-policy/sbom/*fs*.cdx.json | head -n 1)"

SBOM_FILE="$LATEST_SBOM" \
ENVIRONMENT=pull_request \
FAIL_ON_SCAN=false \
./sbom-license-policy/scripts/scan-sbom-vulnerabilities.sh
```

---

# 12. License Inventory Script

This script reads installed npm packages from `node_modules`.

First install dependencies:

```bash id="5qj2ae"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
npm ci
```

Create:

```bash id="9tojj3"
cd ~/devops-masterclass/09-devsecops-security-gates

nano sbom-license-policy/scripts/create-npm-license-inventory.py
```

Paste:

```python id="crqguz"
#!/usr/bin/env python3

import json
import os
from pathlib import Path
from datetime import datetime, timezone

app_dir = Path(os.environ.get("APP_DIR", str(Path.home() / "devops-masterclass/05-application-runtime/demo-node-api")))
report_dir = Path(os.environ.get("REPORT_DIR", "sbom-license-policy/reports"))
service_name = os.environ.get("SERVICE_NAME", "demo-node-api")

node_modules = app_dir / "node_modules"
report_dir.mkdir(parents=True, exist_ok=True)

packages = []

if not node_modules.exists():
    raise SystemExit(f"node_modules not found: {node_modules}. Run npm ci first.")

def read_package_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None

for item in sorted(node_modules.iterdir()):
    if item.name.startswith("."):
        continue

    if item.name.startswith("@") and item.is_dir():
        for scoped_pkg in sorted(item.iterdir()):
            pkg_json = scoped_pkg / "package.json"
            data = read_package_json(pkg_json)
            if data:
                packages.append({
                    "name": data.get("name", scoped_pkg.name),
                    "version": data.get("version", ""),
                    "license": data.get("license", "UNKNOWN"),
                    "path": str(pkg_json)
                })
    else:
        pkg_json = item / "package.json"
        data = read_package_json(pkg_json)
        if data:
            packages.append({
                "name": data.get("name", item.name),
                "version": data.get("version", ""),
                "license": data.get("license", "UNKNOWN"),
                "path": str(pkg_json)
            })

timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
output_file = report_dir / f"npm-license-inventory-{timestamp}.json"

result = {
    "service_name": service_name,
    "app_dir": str(app_dir),
    "package_count": len(packages),
    "packages": packages,
    "created_at": datetime.now(timezone.utc).isoformat()
}

output_file.write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps(result, indent=2))
print(f"License inventory: {output_file}")
```

Make executable:

```bash id="r4l9cb"
chmod +x sbom-license-policy/scripts/create-npm-license-inventory.py
```

Run:

```bash id="d34fvx"
./sbom-license-policy/scripts/create-npm-license-inventory.py
```

---

# 13. License Policy Gate

Create:

```bash id="t947hp"
nano sbom-license-policy/scripts/license-policy-gate.py
```

Paste:

```python id="bfk5ox"
#!/usr/bin/env python3

import json
import os
import sys
from pathlib import Path
from datetime import datetime, timezone

inventory_file = os.environ.get("INVENTORY_FILE", "")
policy_file = Path(os.environ.get("POLICY_FILE", "sbom-license-policy/policies/sbom-license-policy.json"))
report_dir = Path(os.environ.get("REPORT_DIR", "sbom-license-policy/reports"))
environment = os.environ.get("ENVIRONMENT", "pull_request")
fail_on_review_required = os.environ.get("FAIL_ON_REVIEW_REQUIRED", "false").lower() == "true"

if not inventory_file:
    matches = sorted(report_dir.glob("npm-license-inventory-*.json"))
    if not matches:
        print("ERROR: no license inventory found", file=sys.stderr)
        sys.exit(1)
    inventory_path = matches[-1]
else:
    inventory_path = Path(inventory_file)

if not inventory_path.exists():
    print(f"ERROR: inventory file not found: {inventory_path}", file=sys.stderr)
    sys.exit(1)

if not policy_file.exists():
    print(f"ERROR: policy file not found: {policy_file}", file=sys.stderr)
    sys.exit(1)

report_dir.mkdir(parents=True, exist_ok=True)

inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
policy = json.loads(policy_file.read_text(encoding="utf-8"))

allowed = set(policy["licenses"]["allowed"])
review_required = set(policy["licenses"]["review_required"])
denied = set(policy["licenses"]["denied"])

packages = inventory.get("packages", [])

allowed_findings = []
review_findings = []
denied_findings = []
unknown_findings = []

def normalize_license(value):
    if not value:
        return "UNKNOWN"

    if isinstance(value, dict):
        value = value.get("type") or value.get("name") or "UNKNOWN"

    value = str(value).strip()

    if value.startswith("(") and value.endswith(")"):
        value = value[1:-1]

    return value

for pkg in packages:
    lic = normalize_license(pkg.get("license", "UNKNOWN"))
    pkg_record = {
        "name": pkg.get("name"),
        "version": pkg.get("version"),
        "license": lic,
        "path": pkg.get("path")
    }

    if lic in denied:
        denied_findings.append(pkg_record)
    elif lic in review_required:
        review_findings.append(pkg_record)
    elif lic in allowed:
        allowed_findings.append(pkg_record)
    else:
        unknown_findings.append(pkg_record)

decision = "passed"
reason = "license policy passed"

if denied_findings:
    decision = "failed"
    reason = "denied licenses found"
elif environment == "production" and unknown_findings:
    decision = "failed"
    reason = "unknown licenses found in production"
elif environment == "production" and review_findings and fail_on_review_required:
    decision = "failed"
    reason = "review-required licenses found in production"
elif review_findings or unknown_findings:
    decision = "warning"
    reason = "licenses require review or are unknown"

timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
summary_file = report_dir / f"license-policy-summary-{environment}-{timestamp}.json"

summary = {
    "service_name": inventory.get("service_name", "demo-node-api"),
    "gate": "license_policy",
    "environment": environment,
    "inventory_file": str(inventory_path),
    "package_count": len(packages),
    "allowed_count": len(allowed_findings),
    "review_required_count": len(review_findings),
    "denied_count": len(denied_findings),
    "unknown_count": len(unknown_findings),
    "decision": decision,
    "reason": reason,
    "review_required": review_findings,
    "denied": denied_findings,
    "unknown": unknown_findings,
    "created_at": datetime.now(timezone.utc).isoformat()
}

summary_file.write_text(json.dumps(summary, indent=2), encoding="utf-8")
print(json.dumps(summary, indent=2))
print(f"License policy summary: {summary_file}")

if decision == "failed":
    sys.exit(1)
```

Make executable:

```bash id="jw9d6w"
chmod +x sbom-license-policy/scripts/license-policy-gate.py
```

Run:

```bash id="q9i6xu"
ENVIRONMENT=pull_request \
./sbom-license-policy/scripts/license-policy-gate.py
```

Production simulation:

```bash id="gon9kw"
ENVIRONMENT=production \
FAIL_ON_REVIEW_REQUIRED=true \
./sbom-license-policy/scripts/license-policy-gate.py || true
```

---

# 14. Combined SBOM and License Gate

Create:

```bash id="m1ahnp"
nano sbom-license-policy/scripts/sbom-license-gate.sh
```

Paste:

```bash id="jg0qmw"
#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="${MODULE_DIR:-$HOME/devops-masterclass/09-devsecops-security-gates}"
APP_DIR="${APP_DIR:-$HOME/devops-masterclass/05-application-runtime/demo-node-api}"
IMAGE_REF="${IMAGE_REF:-}"
ARTIFACT_VERSION="${ARTIFACT_VERSION:-local}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"

RUN_SBOM_GENERATION="${RUN_SBOM_GENERATION:-true}"
RUN_SBOM_VALIDATION="${RUN_SBOM_VALIDATION:-true}"
RUN_SBOM_SCAN="${RUN_SBOM_SCAN:-true}"
RUN_LICENSE_POLICY="${RUN_LICENSE_POLICY:-true}"

FAIL_ON_SBOM_SCAN="${FAIL_ON_SBOM_SCAN:-false}"
FAIL_ON_LICENSE_REVIEW="${FAIL_ON_LICENSE_REVIEW:-false}"

echo "===== SBOM and License Gate ====="
echo "Environment: $ENVIRONMENT"
echo "Artifact version: $ARTIFACT_VERSION"
echo "Image ref: ${IMAGE_REF:-not-set}"

FAILED=0

cd "$MODULE_DIR"

if [ "$RUN_SBOM_GENERATION" = "true" ]; then
  APP_DIR="$APP_DIR" \
  IMAGE_REF="$IMAGE_REF" \
  ARTIFACT_VERSION="$ARTIFACT_VERSION" \
  ./sbom-license-policy/scripts/generate-sbom.sh
fi

LATEST_SBOM="$(ls -t sbom-license-policy/sbom/*fs*.cdx.json | head -n 1)"

if [ "$RUN_SBOM_VALIDATION" = "true" ]; then
  SBOM_FILE="$LATEST_SBOM" \
  ENVIRONMENT="$ENVIRONMENT" \
  ./sbom-license-policy/scripts/validate-sbom.sh || FAILED=1
fi

if [ "$RUN_SBOM_SCAN" = "true" ]; then
  SBOM_FILE="$LATEST_SBOM" \
  ENVIRONMENT="$ENVIRONMENT" \
  FAIL_ON_SCAN="$FAIL_ON_SBOM_SCAN" \
  ./sbom-license-policy/scripts/scan-sbom-vulnerabilities.sh || FAILED=1
fi

if [ "$RUN_LICENSE_POLICY" = "true" ]; then
  cd "$APP_DIR"
  npm ci

  cd "$MODULE_DIR"

  APP_DIR="$APP_DIR" \
  ./sbom-license-policy/scripts/create-npm-license-inventory.py

  ENVIRONMENT="$ENVIRONMENT" \
  FAIL_ON_REVIEW_REQUIRED="$FAIL_ON_LICENSE_REVIEW" \
  ./sbom-license-policy/scripts/license-policy-gate.py || FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
  echo "ERROR: SBOM/license gate failed" >&2
  exit 1
fi

echo "SBOM/license gate passed or reported only."
```

Make executable:

```bash id="bc41qp"
chmod +x sbom-license-policy/scripts/sbom-license-gate.sh
```

Run:

```bash id="nmso5q"
ENVIRONMENT=pull_request \
ARTIFACT_VERSION=0.9.0-dev-local \
FAIL_ON_SBOM_SCAN=false \
FAIL_ON_LICENSE_REVIEW=false \
./sbom-license-policy/scripts/sbom-license-gate.sh
```

Production simulation:

```bash id="i2cmbf"
ENVIRONMENT=production \
ARTIFACT_VERSION=0.9.0-dev-local \
FAIL_ON_SBOM_SCAN=true \
FAIL_ON_LICENSE_REVIEW=true \
./sbom-license-policy/scripts/sbom-license-gate.sh || true
```

---

# 15. Summary Script

Create:

```bash id="dik9q4"
nano sbom-license-policy/scripts/sbom-license-summary.sh
```

Paste:

```bash id="z1br50"
#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-sbom-license-policy/reports}"
SBOM_DIR="${SBOM_DIR:-sbom-license-policy/sbom}"

echo "===== SBOM and License Summary ====="

echo
echo "SBOM files:"
find "$SBOM_DIR" -type f | sort | tail -n 10 || true

echo
echo "Summary reports:"
find "$REPORT_DIR" -type f -name '*summary*.json' | sort | tail -n 15 | while read -r file; do
  echo
  echo "## $file"
  jq . "$file"
done
```

Make executable:

```bash id="zrbfgi"
chmod +x sbom-license-policy/scripts/sbom-license-summary.sh
```

Run:

```bash id="fbthgq"
./sbom-license-policy/scripts/sbom-license-summary.sh
```

---

# 16. License Exception Template

Create:

```bash id="llgxze"
nano sbom-license-policy/examples/license-exception-template.json
```

Paste:

```json id="c3ocg0"
{
  "exception_id": "LIC-EX-YYYY-NNN",
  "package_name": "",
  "package_version": "",
  "license": "",
  "affected_artifact": "",
  "affected_environment": "",
  "reason": "",
  "business_justification": "",
  "risk_owner": "",
  "reviewed_by": "",
  "created_at": "",
  "expires_on": "",
  "replacement_plan": "",
  "status": "requested"
}
```

---

# 17. SBOM Exception Template

Create:

```bash id="diorix"
nano sbom-license-policy/examples/sbom-exception-template.json
```

Paste:

```json id="8mkghi"
{
  "exception_id": "SBOM-EX-YYYY-NNN",
  "artifact": "",
  "artifact_version": "",
  "artifact_digest": "",
  "reason": "",
  "missing_evidence": "",
  "risk_owner": "",
  "approved_by": "",
  "created_at": "",
  "expires_on": "",
  "compensating_controls": [],
  "status": "requested"
}
```

Professional rule:

```text id="ftdg6h"
A production SBOM exception should be rare and time-bound.
```

---

# 18. GitHub Actions Workflow

Create:

```bash id="pvk3ua"
nano sbom-license-policy/github-actions/sbom-license-policy.yml
```

Paste:

```yaml id="zozoy3"
name: SBOM and License Policy

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main
  workflow_dispatch:
    inputs:
      artifact_version:
        description: "Artifact version"
        required: true
        default: "0.9.0-dev-manual"
        type: string

permissions:
  contents: read

env:
  MODULE9_DIR: 09-devsecops-security-gates
  APP_DIR: 05-application-runtime/demo-node-api
  NODE_VERSION: "22"

jobs:
  sbom-license:
    name: Generate SBOM and check license policy
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm
          cache-dependency-path: ${{ env.APP_DIR }}/package-lock.json

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

      - name: Resolve version and mode
        id: vars
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            VERSION="${{ inputs.artifact_version }}"
          else
            VERSION="0.9.0-${GITHUB_SHA::7}"
          fi

          if [ "${{ github.event_name }}" = "pull_request" ]; then
            ENVIRONMENT="pull_request"
            FAIL_SBOM_SCAN="false"
            FAIL_LICENSE="false"
          else
            ENVIRONMENT="main"
            FAIL_SBOM_SCAN="true"
            FAIL_LICENSE="false"
          fi

          echo "artifact_version=$VERSION" >> "$GITHUB_OUTPUT"
          echo "environment=$ENVIRONMENT" >> "$GITHUB_OUTPUT"
          echo "fail_sbom_scan=$FAIL_SBOM_SCAN" >> "$GITHUB_OUTPUT"
          echo "fail_license=$FAIL_LICENSE" >> "$GITHUB_OUTPUT"

      - name: Run SBOM and license gate
        run: |
          cd "$MODULE9_DIR"

          ENVIRONMENT="${{ steps.vars.outputs.environment }}" \
          ARTIFACT_VERSION="${{ steps.vars.outputs.artifact_version }}" \
          FAIL_ON_SBOM_SCAN="${{ steps.vars.outputs.fail_sbom_scan }}" \
          FAIL_ON_LICENSE_REVIEW="${{ steps.vars.outputs.fail_license }}" \
          ./sbom-license-policy/scripts/sbom-license-gate.sh

      - name: Upload SBOM/license reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: sbom-license-reports
          path: |
            09-devsecops-security-gates/sbom-license-policy/sbom/
            09-devsecops-security-gates/sbom-license-policy/reports/
```

Copy:

```bash id="sdfay5"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/sbom-license-policy/github-actions/sbom-license-policy.yml \
   .github/workflows/sbom-license-policy.yml
```

GitHub workflow artifacts persist files generated during a workflow run, and GitHub provides upload/download artifact actions for sharing and retaining generated outputs like reports. ([GitHub Docs][3])

---

# 19. Jenkins Pipeline

Create:

```bash id="7swzo3"
nano sbom-license-policy/jenkins/Jenkinsfile.sbom-license-policy
```

Paste:

```groovy id="tkz247"
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 45, unit: 'MINUTES')
  }

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['pull_request', 'main', 'production'], description: 'Gate environment')
    string(name: 'ARTIFACT_VERSION', defaultValue: '0.9.0-dev-jenkins', description: 'Artifact version')
    booleanParam(name: 'FAIL_ON_SBOM_SCAN', defaultValue: false, description: 'Fail on SBOM vulnerability findings?')
    booleanParam(name: 'FAIL_ON_LICENSE_REVIEW', defaultValue: false, description: 'Fail on review-required licenses?')
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

    stage('Tool Check') {
      steps {
        sh '''
          node --version || true
          npm --version || true

          if ! command -v trivy >/dev/null 2>&1; then
            echo "ERROR: trivy is required on Jenkins agent"
            exit 1
          fi

          trivy --version
        '''
      }
    }

    stage('SBOM and License Gate') {
      steps {
        dir("${MODULE9_DIR}") {
          sh '''
            ENVIRONMENT="${ENVIRONMENT}" \
            ARTIFACT_VERSION="${ARTIFACT_VERSION}" \
            APP_DIR="$WORKSPACE/${APP_DIR}" \
            FAIL_ON_SBOM_SCAN="${FAIL_ON_SBOM_SCAN}" \
            FAIL_ON_LICENSE_REVIEW="${FAIL_ON_LICENSE_REVIEW}" \
            ./sbom-license-policy/scripts/sbom-license-gate.sh
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '''
        09-devsecops-security-gates/sbom-license-policy/sbom/**/*,
        09-devsecops-security-gates/sbom-license-policy/reports/**/*
      ''', allowEmptyArchive: true
    }

    success {
      echo 'SBOM/license gate passed.'
    }

    failure {
      echo 'SBOM/license gate failed. Review archived reports.'
    }
  }
}
```

Jenkins script path:

```text id="c7z9q0"
09-devsecops-security-gates/sbom-license-policy/jenkins/Jenkinsfile.sbom-license-policy
```

---

# 20. GitLab CI Pipeline

Create:

```bash id="xyzwu8"
nano sbom-license-policy/gitlab/.gitlab-ci.sbom-license-policy.yml
```

Paste:

```yaml id="uce7db"
stages:
  - sbom_license

variables:
  MODULE9_DIR: "09-devsecops-security-gates"
  APP_DIR: "05-application-runtime/demo-node-api"
  ARTIFACT_VERSION: "0.9.0-dev-gitlab"

sbom_license_policy:
  stage: sbom_license
  image: node:22-bookworm
  before_script:
    - apt-get update
    - apt-get install -y wget gnupg jq
    - wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor > /usr/share/keyrings/trivy.gpg
    - echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" > /etc/apt/sources.list.d/trivy.list
    - apt-get update
    - apt-get install -y trivy
    - trivy --version
  script:
    - cd "$MODULE9_DIR"
    - |
      if [ "${CI_COMMIT_BRANCH:-}" = "main" ]; then
        ENVIRONMENT="main"
        FAIL_SBOM_SCAN="true"
        FAIL_LICENSE="false"
      else
        ENVIRONMENT="pull_request"
        FAIL_SBOM_SCAN="false"
        FAIL_LICENSE="false"
      fi

      ENVIRONMENT="$ENVIRONMENT" \
      ARTIFACT_VERSION="$ARTIFACT_VERSION" \
      APP_DIR="$CI_PROJECT_DIR/$APP_DIR" \
      FAIL_ON_SBOM_SCAN="$FAIL_SBOM_SCAN" \
      FAIL_ON_LICENSE_REVIEW="$FAIL_LICENSE" \
      ./sbom-license-policy/scripts/sbom-license-gate.sh
  artifacts:
    when: always
    expire_in: 30 days
    paths:
      - 09-devsecops-security-gates/sbom-license-policy/sbom/
      - 09-devsecops-security-gates/sbom-license-policy/reports/
```

---

# 21. SBOM Triage Runbook

Create:

```bash id="de0r99"
nano sbom-license-policy/runbooks/sbom-triage-runbook.md
```

Paste:

````markdown id="ylkxlf"
# SBOM Triage Runbook

## Goal

Use SBOMs to identify affected components and artifacts.

## When to Use

Use this runbook when:

- a new CVE is announced
- a package is suspected vulnerable
- production artifact needs component proof
- customer asks for dependency evidence
- compliance requires software inventory

## Steps

1. Identify artifact version or image digest.
2. Locate matching SBOM.
3. Search for package name.
4. Check package version.
5. Compare with vulnerability advisory.
6. Determine whether affected package is runtime or dev-only.
7. Patch, replace, or document exception.
8. Regenerate SBOM after fix.
9. Archive updated SBOM.

## Useful Commands

```bash
jq '.components[] | select(.name == "PACKAGE_NAME")' bom.cdx.json
````

Count components:

```bash id="1s33ct"
jq '.components | length' bom.cdx.json
```

Show package names and versions:

```bash id="y96nhp"
jq -r '.components[] | "\(.name)@\(.version // "unknown")"' bom.cdx.json
```

````id="b7uzng"

---

# 22. License Triage Runbook

Create:

```bash
nano sbom-license-policy/runbooks/license-triage-runbook.md
````

Paste:

```markdown id="kuhp33"
# License Triage Runbook

## Goal

Review dependency licenses before release.

## License Categories

Allowed:

- MIT
- Apache-2.0
- BSD-2-Clause
- BSD-3-Clause
- ISC

Review required:

- GPL
- AGPL
- LGPL
- MPL
- EPL
- UNKNOWN
- UNLICENSED

Denied:

- organization-specific deny list

## Triage Questions

- Is this dependency runtime or dev-only?
- Is it distributed externally?
- Is there a replacement package?
- Does legal/security need to review?
- Is license metadata missing or incorrect?
- Is an exception required?

## Exception Requirements

- package name
- version
- license
- affected artifact
- owner
- reason
- expiry date
- reviewer
- replacement plan
```

---

# 23. Production SBOM Checklist

Create:

```bash id="obsey6"
nano sbom-license-policy/runbooks/production-sbom-checklist.md
```

Paste:

```markdown id="wwognd"
# Production SBOM Checklist

Before production deployment:

- [ ] SBOM generated
- [ ] SBOM validates
- [ ] SBOM attached to immutable artifact tag/digest
- [ ] SBOM vulnerability scan completed
- [ ] license inventory generated
- [ ] license policy checked
- [ ] denied licenses absent
- [ ] unknown licenses reviewed
- [ ] release metadata references SBOM
- [ ] SBOM archived as CI/CD artifact
- [ ] exceptions have owner, reason, expiry, and approval
```

---

# 24. Validation Script

Create:

```bash id="vvrw6k"
nano sbom-license-policy/scripts/validate-sbom-license-lesson.sh
```

Paste:

```bash id="m5d7fl"
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-sbom-license-policy}"

echo "===== Validate SBOM License Lesson ====="

test -f "$BASE_DIR/policies/sbom-license-policy.json"
test -f "$BASE_DIR/notes/sbom-license-mental-model.md"
test -x "$BASE_DIR/scripts/generate-sbom.sh"
test -x "$BASE_DIR/scripts/validate-sbom.sh"
test -x "$BASE_DIR/scripts/scan-sbom-vulnerabilities.sh"
test -x "$BASE_DIR/scripts/create-npm-license-inventory.py"
test -x "$BASE_DIR/scripts/license-policy-gate.py"
test -x "$BASE_DIR/scripts/sbom-license-gate.sh"
test -x "$BASE_DIR/scripts/sbom-license-summary.sh"
test -f "$BASE_DIR/examples/license-exception-template.json"
test -f "$BASE_DIR/examples/sbom-exception-template.json"
test -f "$BASE_DIR/github-actions/sbom-license-policy.yml"
test -f "$BASE_DIR/jenkins/Jenkinsfile.sbom-license-policy"
test -f "$BASE_DIR/gitlab/.gitlab-ci.sbom-license-policy.yml"
test -f "$BASE_DIR/runbooks/sbom-triage-runbook.md"
test -f "$BASE_DIR/runbooks/license-triage-runbook.md"
test -f "$BASE_DIR/runbooks/production-sbom-checklist.md"

echo "SBOM license policy lesson validated."
```

Make executable:

```bash id="vuchav"
chmod +x sbom-license-policy/scripts/validate-sbom-license-lesson.sh
```

Run:

```bash id="8c14zd"
./sbom-license-policy/scripts/validate-sbom-license-lesson.sh
```

---

# 25. Update Makefile

Open:

```bash id="6qpe4j"
cd ~/devops-masterclass/09-devsecops-security-gates

nano Makefile
```

Add:

```Makefile id="rv3nn7"
.PHONY: sbom-validate sbom-generate sbom-gate sbom-summary license-inventory license-policy

sbom-validate:
	./sbom-license-policy/scripts/validate-sbom-license-lesson.sh

sbom-generate:
	ARTIFACT_VERSION="$${ARTIFACT_VERSION:-0.9.0-dev-local}" \
	IMAGE_REF="$${IMAGE_REF:-}" \
	./sbom-license-policy/scripts/generate-sbom.sh

license-inventory:
	cd ../05-application-runtime/demo-node-api && npm ci
	APP_DIR="../05-application-runtime/demo-node-api" \
	./sbom-license-policy/scripts/create-npm-license-inventory.py

license-policy:
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_REVIEW_REQUIRED="$${FAIL_ON_REVIEW_REQUIRED:-false}" \
	./sbom-license-policy/scripts/license-policy-gate.py

sbom-gate:
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	ARTIFACT_VERSION="$${ARTIFACT_VERSION:-0.9.0-dev-local}" \
	IMAGE_REF="$${IMAGE_REF:-}" \
	FAIL_ON_SBOM_SCAN="$${FAIL_ON_SBOM_SCAN:-false}" \
	FAIL_ON_LICENSE_REVIEW="$${FAIL_ON_LICENSE_REVIEW:-false}" \
	./sbom-license-policy/scripts/sbom-license-gate.sh

sbom-summary:
	./sbom-license-policy/scripts/sbom-license-summary.sh
```

Run:

```bash id="jjq774"
make sbom-validate
make sbom-gate
make sbom-summary
```

---

# 26. Practical Lab

Run:

```bash id="9wrv3f"
cd ~/devops-masterclass/09-devsecops-security-gates

make sbom-validate

ARTIFACT_VERSION=0.9.0-dev-local \
ENVIRONMENT=pull_request \
FAIL_ON_SBOM_SCAN=false \
FAIL_ON_LICENSE_REVIEW=false \
make sbom-gate

make sbom-summary
```

With image SBOM:

```bash id="s77cjs"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

docker build \
  -f Dockerfile.industry \
  --target runtime \
  --build-arg APP_VERSION=0.9.0-dev-local \
  --build-arg COMMIT_SHA="$(git rev-parse --short HEAD)" \
  -t demo-node-api:0.9.0-dev-local \
  .

cd ~/devops-masterclass/09-devsecops-security-gates

IMAGE_REF=demo-node-api:0.9.0-dev-local \
ARTIFACT_VERSION=0.9.0-dev-local \
make sbom-gate
```

Copy GitHub workflow:

```bash id="ypi2nq"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/sbom-license-policy/github-actions/sbom-license-policy.yml \
   .github/workflows/sbom-license-policy.yml
```

Commit:

```bash id="44nrzb"
git status

git add .github/workflows/sbom-license-policy.yml \
        09-devsecops-security-gates

git commit -m "feat: add SBOM and license policy gates"
git push
```

---

# 27. Common SBOM and License Problems

## SBOM has zero components

Check:

```bash id="d4f1tg"
jq '.components | length' sbom-file.cdx.json
```

Possible causes:

```text id="n2mg8r"
wrong target directory
dependencies not installed
unsupported ecosystem metadata
scanner config issue
```

## License is UNKNOWN

Possible causes:

```text id="aqf904"
package metadata missing license field
custom license
old package
scanner could not resolve metadata
```

Triage:

```bash id="xjewk7"
cat node_modules/PACKAGE/package.json | jq '.license'
```

## Production fails on review-required licenses

Create an exception only with:

```text id="xhl7xr"
owner
reason
reviewer
expiry
replacement plan
affected artifact
```

## SBOM vulnerability scan differs from image scan

Expected.

```text id="rvftlx"
SBOM scan:
  scans component inventory

Image scan:
  scans actual image and OS packages

SCA scan:
  scans manifests/lockfiles
```

Use all three for production confidence.

## SBOM generated but not linked to artifact

Fix your release metadata.

A useful release record should include:

```text id="b8e1j2"
artifact tag
artifact digest
SBOM path
SBOM hash
scan report path
license report path
```

---

# 28. Interview Explanation

## What is an SBOM?

```text id="k4yt4i"
An SBOM, or Software Bill of Materials, is an inventory of software components included in an application or artifact. It records packages, versions, metadata, and sometimes licenses and relationships, allowing teams to assess exposure when vulnerabilities are disclosed.
```

## Why is SBOM important in DevSecOps?

```text id="z4zaxd"
SBOMs improve supply-chain visibility. They help teams quickly answer whether a production artifact contains a vulnerable package, which version is affected, and which artifact needs to be patched or replaced.
```

## What is CycloneDX?

```text id="rwmls9"
CycloneDX is a bill-of-materials standard commonly used for SBOMs and related supply-chain use cases. In this module, we generate CycloneDX JSON SBOMs with Trivy.
```

## What is SPDX?

```text id="35blgv"
SPDX is an open standard for representing software component, license, security, and related metadata. SPDX license identifiers are commonly used to standardize license policy decisions.
```

## What should block production?

```text id="7i8qtj"
Production should be blocked if the SBOM is missing or invalid, if high or critical SBOM vulnerability findings violate policy, if denied licenses are present, or if review-required/unknown licenses lack an approved exception.
```

## How do you handle unknown licenses?

```text id="ak242j"
I review the package metadata and upstream repository, determine whether the license is actually missing or just not detected, document the finding, and require approval or replacement before production if policy requires it.
```

---

# 29. Today’s Core Rules

```text id="d0scbq"
Generate SBOMs for release artifacts.
Validate SBOMs before production.
Archive SBOMs as pipeline evidence.
Scan SBOMs for vulnerabilities.
Track licenses for dependencies.
Use SPDX identifiers for license policy.
Allowed licenses can pass automatically.
Review-required licenses need approval.
Denied licenses should fail.
Unknown licenses should not silently pass production.
Link SBOMs to immutable artifact tags or digests.
SBOM does not replace SAST, SCA, or image scanning.
```

---

# Next Lesson

# Lesson 9.9 — Policy as Code with OPA and Conftest

We will build:

```text id="lu354y"
OPA mental model
Conftest basics
Rego policy fundamentals
Dockerfile policy
Terraform policy
Kubernetes policy
CI/CD policy checks
security exception validation
GitHub Actions OPA workflow
Jenkins OPA pipeline
GitLab CI OPA pipeline
production policy-as-code gate
```

[1]: https://trivy.dev/docs/latest/supply-chain/sbom/?utm_source=chatgpt.com "SBOM"
[2]: https://spdx.org/licenses/?utm_source=chatgpt.com "SPDX License List | Software Package Data Exchange ..."
[3]: https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts?utm_source=chatgpt.com "Workflow artifacts"

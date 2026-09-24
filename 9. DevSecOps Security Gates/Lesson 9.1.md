# Module 9 — DevSecOps Security Gates

# Lesson 9.1 — DevSecOps Mental Model and Security Gate Architecture

Module 8 gave you CI/CD pipelines.

Module 9 makes those pipelines **security-aware**.

A normal CI/CD pipeline asks:

```text
Can we build and deploy this?
```

A DevSecOps pipeline asks:

```text
Can we build, trust, scan, approve, deploy, monitor, and safely roll back this artifact?
```

Tools we will use or prepare for in this module include Trivy for vulnerabilities, misconfigurations, secrets, SBOM, containers, repositories, and Kubernetes targets; Semgrep for code/SAST-style analysis; Gitleaks for secret detection; and Checkov for infrastructure-as-code misconfiguration scanning. ([GitHub][1])

---

# 1. What DevSecOps Means

DevSecOps means security is not a final manual checkpoint after development.

It means security is built into:

```text
developer workflow
Git commits
pull requests
CI pipelines
artifact build
registry promotion
deployment approval
runtime verification
incident response
```

Old model:

```text
developer writes code
  ↓
CI builds
  ↓
deploy
  ↓
security team reviews later
```

DevSecOps model:

```text
developer writes code
  ↓
automated security checks
  ↓
CI/CD quality gates
  ↓
trusted artifact
  ↓
approved deployment
  ↓
runtime monitoring
  ↓
feedback to developers
```

Professional rule:

```text
Security should be early, automated, repeatable, and evidence-based.
```

---

# 2. The DevSecOps Gate Categories

In Module 9, we will build gates for:

```text
SAST:
  source code vulnerability scanning

SCA:
  dependency vulnerability scanning

secret scanning:
  API keys, tokens, private keys, credentials

container scanning:
  OS packages, language packages, image vulnerabilities

Dockerfile scanning:
  insecure Dockerfile patterns

IaC scanning:
  Terraform, Kubernetes, CloudFormation, Helm, etc.

SBOM validation:
  prove software component inventory exists

license policy:
  check dependency licenses

artifact trust:
  provenance, signing, digest, release metadata

deployment security:
  environment approval, protected secrets, rollback readiness
```

Static Application Security Testing, or SAST, analyzes source code to identify vulnerabilities before production; GitLab’s SAST documentation describes it as a CI/CD-integrated way to detect issues during development. ([GitLab Docs][2])

---

# 3. Security Gate Placement

Security gates should exist at multiple points.

```text
developer machine:
  format, lint, unit tests, secret scan

pre-commit:
  secret scanning, basic policy checks

pull request:
  SAST, dependency review, secret scan, tests

main branch:
  stricter SAST, SCA, image scan, IaC scan

artifact build:
  SBOM, provenance, signing, scan reports

staging:
  deployment verification, smoke tests

production:
  manual approval, signed artifact, rollback version, release evidence
```

Professional rule:

```text
Use fast gates early and deeper gates later.
```

Do not make every developer wait 30 minutes for every scan on every commit. Use staged enforcement.

---

# 4. Fail, Warn, Report Strategy

Every finding should not automatically block the pipeline.

Use this model:

```text
FAIL:
  stop the pipeline

WARN:
  continue but mark risk

REPORT:
  collect evidence only
```

Example policy:

```text
hardcoded AWS key:
  FAIL

critical dependency vulnerability on production path:
  FAIL

medium vulnerability in dev branch:
  WARN

unknown license:
  WARN first, FAIL later after policy maturity

SBOM missing for production artifact:
  FAIL

IaC public S3 bucket:
  FAIL for production, WARN for sandbox
```

Professional rule:

```text
Security gates should be risk-based, not panic-based.
```

---

# 5. DevSecOps Maturity Levels

## Level 1 — Basic CI

```text
tests
lint
format
```

## Level 2 — Basic Security

```text
secret scan
dependency scan
container scan
```

## Level 3 — Artifact Evidence

```text
SBOM
provenance
release metadata
scan reports
```

## Level 4 — Policy Enforcement

```text
fail on critical vulnerabilities
fail on committed secrets
fail on insecure IaC
fail on unsigned production artifacts
```

## Level 5 — Governance

```text
exceptions
expiry dates
security approval
risk acceptance
audit trail
```

## Level 6 — Runtime Feedback

```text
incident data
runtime vulnerabilities
attack signals
SLO impact
rollback and patch workflow
```

Your target in Module 9:

```text
Level 4 now.
Level 5 by the capstone.
```

---

# 6. Module 9 Folder Structure

Create the module folder:

```bash
cd ~/devops-masterclass

mkdir -p 09-devsecops-security-gates/{notes,scripts,policies,reports,runbooks,examples,github-actions,jenkins,gitlab,tools,capstone}
```

Check:

```bash
tree -L 2 09-devsecops-security-gates
```

Expected:

```text
09-devsecops-security-gates
├── capstone
├── examples
├── github-actions
├── gitlab
├── jenkins
├── notes
├── policies
├── reports
├── runbooks
├── scripts
└── tools
```

---

# 7. Create DevSecOps Mental Model Notes

Create:

```bash
cd ~/devops-masterclass/09-devsecops-security-gates

nano notes/devsecops-mental-model.md
```

Paste:

```markdown
# DevSecOps Mental Model

## Definition

DevSecOps means integrating security checks, policies, evidence, and feedback into the software delivery lifecycle.

## Core Idea

Security should not be a final manual approval after development.

Security should be:

- early
- automated
- repeatable
- evidence-based
- risk-based
- developer-friendly

## Security Gate Categories

| Gate | Purpose |
|---|---|
| SAST | Find insecure code patterns |
| SCA | Find vulnerable dependencies |
| Secret scanning | Find leaked credentials |
| Container scanning | Find image vulnerabilities |
| Dockerfile scanning | Find insecure image build patterns |
| IaC scanning | Find cloud/Kubernetes/Terraform misconfigurations |
| SBOM validation | Prove component inventory exists |
| License policy | Check open-source license risk |
| Artifact trust | Verify provenance, signature, digest, metadata |
| Deployment security | Verify approvals, rollback, and runtime health |

## Fail/Warn/Report

- FAIL: stop unsafe release
- WARN: continue with visible risk
- REPORT: collect evidence only

## Production Rule

Production deployments should require:

- tests passed
- quality gates passed
- secret scan passed
- dependency policy passed
- container scan passed
- SBOM exists
- provenance exists
- release metadata exists
- rollback version exists
- deployment approval exists
```

---

# 8. Security Gate Policy

Create:

```bash
nano policies/demo-node-api-security-gates-policy.json
```

Paste:

```json
{
  "service_name": "demo-node-api",
  "policy_version": "1.0",
  "default_mode": "warn",
  "environments": {
    "pull_request": {
      "sast": "warn",
      "sca": "warn",
      "secret_scan": "fail",
      "container_scan": "report",
      "iac_scan": "warn",
      "sbom_required": false,
      "signature_required": false
    },
    "main": {
      "sast": "fail_on_high",
      "sca": "fail_on_high_or_critical",
      "secret_scan": "fail",
      "container_scan": "fail_on_critical",
      "iac_scan": "fail_on_high",
      "sbom_required": true,
      "signature_required": false
    },
    "production": {
      "sast": "fail_on_high_or_critical",
      "sca": "fail_on_high_or_critical",
      "secret_scan": "fail",
      "container_scan": "fail_on_high_or_critical",
      "iac_scan": "fail_on_high_or_critical",
      "sbom_required": true,
      "provenance_required": true,
      "signature_required": true,
      "release_metadata_required": true,
      "rollback_version_required": true,
      "manual_approval_required": true
    }
  },
  "severity_order": ["unknown", "low", "medium", "high", "critical"],
  "exception_policy": {
    "allowed": true,
    "requires_owner": true,
    "requires_reason": true,
    "requires_expiry": true,
    "requires_compensating_control": true,
    "max_days": 30
  },
  "forbidden": {
    "secret_patterns": [
      "AWS access keys",
      "private keys",
      "GitHub tokens",
      "database passwords"
    ],
    "image_tags": ["latest", "prod", "production", "stable"],
    "dockerfile_patterns": [
      "root runtime user",
      "secret-like ARG or ENV",
      "FROM latest"
    ]
  }
}
```

This file becomes your security contract.

---

# 9. Security Gate Matrix

Create:

```bash
nano examples/security-gate-matrix.json
```

Paste:

```json
{
  "gates": [
    {
      "name": "secret_scan",
      "tool_examples": ["gitleaks", "trivy secret"],
      "runs_on": ["developer", "pull_request", "main"],
      "production_behavior": "fail",
      "reason": "leaked credentials create immediate compromise risk"
    },
    {
      "name": "sast",
      "tool_examples": ["semgrep", "gitlab_sast"],
      "runs_on": ["pull_request", "main"],
      "production_behavior": "fail_on_high_or_critical",
      "reason": "code vulnerabilities should be blocked before release"
    },
    {
      "name": "sca",
      "tool_examples": ["npm audit", "trivy fs"],
      "runs_on": ["pull_request", "main", "release"],
      "production_behavior": "fail_on_high_or_critical",
      "reason": "vulnerable dependencies increase application risk"
    },
    {
      "name": "container_scan",
      "tool_examples": ["trivy image"],
      "runs_on": ["main", "release"],
      "production_behavior": "fail_on_high_or_critical",
      "reason": "runtime image risk matters before deployment"
    },
    {
      "name": "iac_scan",
      "tool_examples": ["checkov", "trivy config"],
      "runs_on": ["pull_request", "main"],
      "production_behavior": "fail_on_high_or_critical",
      "reason": "cloud misconfigurations can expose production infrastructure"
    },
    {
      "name": "sbom_validation",
      "tool_examples": ["trivy sbom", "custom jq validation"],
      "runs_on": ["release"],
      "production_behavior": "fail_if_missing",
      "reason": "production artifacts need component inventory"
    }
  ]
}
```

Trivy can scan multiple target types, including container images, repositories, Kubernetes, code repositories, misconfigurations, secrets, and SBOM-related targets. ([GitHub][1])

---

# 10. Tool Selection Notes

Create:

```bash
nano notes/devsecops-tool-selection.md
```

Paste:

```markdown
# DevSecOps Tool Selection

## Tools Used in This Module

| Category | Primary Tool | Purpose |
|---|---|---|
| SAST | Semgrep | Static source code analysis |
| Secret scanning | Gitleaks | Detect secrets in Git/files |
| Container scanning | Trivy | Scan container images |
| SCA | npm audit / Trivy | Dependency vulnerability scanning |
| IaC scanning | Checkov / Trivy config | Terraform/Kubernetes/cloud config scanning |
| SBOM | Trivy | Generate CycloneDX/SPDX SBOMs |
| Policy | Custom scripts first, OPA later | Gate enforcement |

## Why These Tools

- CLI-friendly
- CI/CD-friendly
- widely used
- good for learning
- work across GitHub Actions, Jenkins, and GitLab CI
- can generate machine-readable reports

## Rule

Start with tools that create reports.
Then enforce policies gradually.
```

Semgrep positions its platform around SAST, SCA, and secrets scanning; Gitleaks is an open-source scanner for secrets in Git repositories, files, directories, and stdin; Checkov scans cloud infrastructure configurations across IaC platforms such as Terraform, CloudFormation, Kubernetes, Helm, ARM templates, and serverless frameworks. ([GitHub][3])

---

# 11. Security Finding Data Model

Create a standard finding format.

```bash
nano examples/security-finding-example.json
```

Paste:

```json
{
  "service_name": "demo-node-api",
  "finding_id": "SEC-EXAMPLE-001",
  "category": "container_scan",
  "tool": "trivy",
  "severity": "high",
  "title": "Example vulnerable package",
  "affected_component": "openssl",
  "affected_artifact": "demo-node-api:0.9.0-dev-a1b2c3d",
  "environment": "main",
  "status": "open",
  "gate_decision": "fail",
  "owner": "platform-team",
  "recommended_action": "Upgrade base image or package",
  "exception": {
    "requested": false,
    "approved": false,
    "expires_on": null
  },
  "created_at": "2026-07-12T00:00:00Z"
}
```

Why standardize this?

```text
Different tools output different JSON structures.
Your pipeline needs one common model for decisions.
```

---

# 12. Risk Classifier Script

Create:

```bash
nano scripts/classify-security-finding.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

CATEGORY="${CATEGORY:-unknown}"
SEVERITY="${SEVERITY:-unknown}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"
REPORT_DIR="${REPORT_DIR:-reports}"
SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"

mkdir -p "$REPORT_DIR"

SEVERITY_LC="$(echo "$SEVERITY" | tr '[:upper:]' '[:lower:]')"
CATEGORY_LC="$(echo "$CATEGORY" | tr '[:upper:]' '[:lower:]')"
ENV_LC="$(echo "$ENVIRONMENT" | tr '[:upper:]' '[:lower:]')"

DECISION="report"
REASON="default report mode"

case "$CATEGORY_LC" in
  secret_scan)
    DECISION="fail"
    REASON="secret findings must be blocked"
    ;;

  sast|sca|container_scan|iac_scan)
    case "$ENV_LC" in
      production|main)
        case "$SEVERITY_LC" in
          critical|high)
            DECISION="fail"
            REASON="$CATEGORY_LC $SEVERITY_LC finding is not allowed in $ENV_LC"
            ;;
          medium)
            DECISION="warn"
            REASON="medium finding should be triaged"
            ;;
          *)
            DECISION="report"
            REASON="low/unknown finding recorded"
            ;;
        esac
        ;;
      pull_request|dev)
        case "$SEVERITY_LC" in
          critical)
            DECISION="fail"
            REASON="critical finding blocks even early pipeline"
            ;;
          high|medium)
            DECISION="warn"
            REASON="finding visible but not blocking in early environment"
            ;;
          *)
            DECISION="report"
            REASON="low/unknown finding recorded"
            ;;
        esac
        ;;
    esac
    ;;

  sbom_validation)
    if [ "$ENV_LC" = "production" ] || [ "$ENV_LC" = "main" ]; then
      DECISION="fail"
      REASON="missing or invalid SBOM blocks release"
    else
      DECISION="warn"
      REASON="SBOM issue should be fixed before release"
    fi
    ;;
esac

OUTPUT_FILE="$REPORT_DIR/security-finding-classification-$(date +%Y%m%d_%H%M%S).json"

cat > "$OUTPUT_FILE" <<EOF
{
  "service_name": "$SERVICE_NAME",
  "category": "$CATEGORY_LC",
  "severity": "$SEVERITY_LC",
  "environment": "$ENV_LC",
  "decision": "$DECISION",
  "reason": "$REASON",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$OUTPUT_FILE" | jq .
echo "Classification report: $OUTPUT_FILE"

if [ "$DECISION" = "fail" ]; then
  exit 2
fi
```

Make executable:

```bash
chmod +x scripts/classify-security-finding.sh
```

Test:

```bash
CATEGORY=secret_scan SEVERITY=critical ENVIRONMENT=pull_request ./scripts/classify-security-finding.sh || true

CATEGORY=container_scan SEVERITY=medium ENVIRONMENT=pull_request ./scripts/classify-security-finding.sh || true

CATEGORY=container_scan SEVERITY=critical ENVIRONMENT=production ./scripts/classify-security-finding.sh || true
```

---

# 13. Security Gate Inventory Script

Create:

```bash
nano scripts/security-gate-inventory.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-reports}"
OUTPUT_FILE="$REPORT_DIR/security-gate-inventory.json"

mkdir -p "$REPORT_DIR"

cat > "$OUTPUT_FILE" <<'EOF'
{
  "module": "9",
  "module_name": "DevSecOps Security Gates",
  "security_gates": [
    {
      "name": "sast",
      "status": "planned",
      "primary_tool": "semgrep",
      "blocking_in_production": true
    },
    {
      "name": "secret_scan",
      "status": "planned",
      "primary_tool": "gitleaks",
      "blocking_in_production": true
    },
    {
      "name": "sca",
      "status": "planned",
      "primary_tool": "npm audit and trivy fs",
      "blocking_in_production": true
    },
    {
      "name": "container_scan",
      "status": "planned",
      "primary_tool": "trivy image",
      "blocking_in_production": true
    },
    {
      "name": "iac_scan",
      "status": "planned",
      "primary_tool": "checkov and trivy config",
      "blocking_in_production": true
    },
    {
      "name": "sbom_validation",
      "status": "planned",
      "primary_tool": "trivy and jq",
      "blocking_in_production": true
    },
    {
      "name": "license_policy",
      "status": "planned",
      "primary_tool": "npm license tooling or custom policy",
      "blocking_in_production": "depends_on_policy"
    }
  ]
}
EOF

cat "$OUTPUT_FILE" | jq .
echo "Security gate inventory: $OUTPUT_FILE"
```

Make executable:

```bash
chmod +x scripts/security-gate-inventory.sh
```

Run:

```bash
./scripts/security-gate-inventory.sh
```

---

# 14. Security Triage Runbook

Create:

```bash
nano runbooks/security-findings-triage.md
```

Paste:

```markdown
# Security Findings Triage Runbook

## Goal

Classify and respond to security findings from CI/CD gates.

## Step 1 — Identify Category

Common categories:

- SAST
- SCA
- secret scan
- container scan
- IaC scan
- SBOM validation
- license policy
- artifact trust

## Step 2 — Identify Severity

Use:

- critical
- high
- medium
- low
- unknown

## Step 3 — Determine Environment

The same finding may have different decisions in different environments.

| Environment | Typical Behavior |
|---|---|
| pull_request | fail secrets, warn most others |
| main | fail high/critical |
| production | fail high/critical and missing evidence |

## Step 4 — Decide Action

Possible actions:

- fail pipeline
- warn and create ticket
- report only
- request exception
- rotate secret
- rollback
- block production

## Step 5 — Exception Rules

Exceptions require:

- owner
- reason
- affected artifact
- expiry date
- compensating control
- approval

## Step 6 — Close Finding

A finding can be closed when:

- vulnerability is fixed
- secret is revoked and rotated
- IaC misconfiguration is corrected
- exception expires and risk is resolved
- false positive is documented
```

---

# 15. Security Exception Template

Create:

```bash
nano examples/security-exception-template.json
```

Paste:

```json
{
  "exception_id": "SEC-EX-YYYY-NNN",
  "finding_id": "",
  "category": "",
  "severity": "",
  "affected_artifact": "",
  "affected_environment": "",
  "reason": "",
  "risk_owner": "",
  "approved_by": "",
  "created_at": "",
  "expires_on": "",
  "compensating_controls": [],
  "review_required": true,
  "status": "requested"
}
```

Professional rule:

```text
Security exceptions must expire.
```

Permanent exceptions become hidden vulnerabilities.

---

# 16. DevSecOps README

Create:

```bash
nano README.md
```

Paste:

```markdown
# Module 9 — DevSecOps Security Gates

This module adds security gates to the CI/CD system.

## Topics

- DevSecOps mental model
- SAST
- SCA
- secret scanning
- container scanning
- Dockerfile scanning
- IaC scanning
- SBOM validation
- license policy
- artifact trust
- security exceptions
- risk acceptance
- DevSecOps capstone

## Core Principle

Security gates should be automated, risk-based, and evidence-driven.

## First Lesson

Lesson 9.1 created:

- DevSecOps mental model
- security gate policy
- security gate matrix
- finding data model
- risk classifier
- triage runbook
- exception template
```

---

# 17. Makefile

Create:

```bash
nano Makefile
```

Paste:

```Makefile
.PHONY: inventory classify-secret classify-container classify-prod validate

inventory:
	./scripts/security-gate-inventory.sh

classify-secret:
	CATEGORY=secret_scan SEVERITY=critical ENVIRONMENT=pull_request ./scripts/classify-security-finding.sh || true

classify-container:
	CATEGORY=container_scan SEVERITY=medium ENVIRONMENT=pull_request ./scripts/classify-security-finding.sh || true

classify-prod:
	CATEGORY=container_scan SEVERITY=critical ENVIRONMENT=production ./scripts/classify-security-finding.sh || true

validate:
	test -f notes/devsecops-mental-model.md
	test -f notes/devsecops-tool-selection.md
	test -f policies/demo-node-api-security-gates-policy.json
	test -f examples/security-gate-matrix.json
	test -f examples/security-finding-example.json
	test -f examples/security-exception-template.json
	test -x scripts/classify-security-finding.sh
	test -x scripts/security-gate-inventory.sh
	test -f runbooks/security-findings-triage.md
	@echo "Module 9 Lesson 9.1 validated."
```

Run:

```bash
make validate
make inventory
make classify-secret
make classify-container
make classify-prod
```

---

# 18. What We Built in Lesson 9.1

You now have the foundation for Module 9:

```text
DevSecOps mental model
security gate categories
security policy
gate matrix
finding data model
risk classifier
gate inventory
triage runbook
exception template
Makefile validation
```

This foundation is important because tools alone do not create DevSecOps.

```text
Tools produce findings.
Policies decide what findings mean.
Pipelines enforce the decisions.
Runbooks explain how humans respond.
```

---

# 19. Commit Work

Run:

```bash
cd ~/devops-masterclass

git status

git add 09-devsecops-security-gates

git commit -m "feat: start DevSecOps security gates module"
git push
```

---

# 20. Interview Explanation

## What is DevSecOps?

Strong answer:

```text
DevSecOps means integrating security into the software delivery lifecycle through automated checks, security gates, policies, evidence, and feedback loops. Instead of doing security only at the end, DevSecOps shifts security earlier into development and CI/CD while still preserving production controls.
```

## What are security gates?

Strong answer:

```text
Security gates are automated policy checks that decide whether a pipeline can continue. Examples include SAST, dependency scanning, secret scanning, container scanning, IaC scanning, SBOM validation, artifact signing, and release metadata validation.
```

## Why not fail every security finding?

Strong answer:

```text
Not every finding has the same risk. A critical leaked secret should fail immediately, but a medium dependency issue in a development branch may start as a warning. Mature DevSecOps uses fail, warn, and report modes based on severity, environment, exploitability, and business risk.
```

## What is the difference between SAST and SCA?

Strong answer:

```text
SAST analyzes source code for insecure patterns and vulnerabilities in the application logic. SCA analyzes third-party dependencies and packages for known vulnerabilities and license risk.
```

## What is the purpose of a security exception?

Strong answer:

```text
A security exception documents a temporary accepted risk. It should include the finding, owner, reason, approval, expiry date, affected artifact, and compensating controls. Exceptions should not be permanent ignores.
```

---

# 21. Today’s Core Rules

```text
DevSecOps is security built into delivery.
Security gates must be automated and evidence-based.
Tools produce findings; policies make decisions.
Use fail, warn, and report modes.
Fail committed secrets immediately.
Production security gates must be stricter than PR gates.
Use exceptions only with owner, reason, approval, and expiry.
Do not deploy artifacts with missing SBOM/provenance/signature when policy requires them.
Security should help developers fix issues, not just block them.
```

---

# Next Lesson

# Lesson 9.2 — SAST with Semgrep

We will build:

```text
Semgrep local scanning
Semgrep rules
Node.js Express security checks
custom rule examples
SARIF/JSON reports
GitHub Actions SAST workflow
Jenkins SAST pipeline
GitLab CI SAST pipeline
fail/warn policy
security findings triage
SAST runbook
```

[1]: https://github.com/aquasecurity/trivy?utm_source=chatgpt.com "aquasecurity/trivy: Find vulnerabilities, misconfigurations ..."
[2]: https://docs.gitlab.com/user/application_security/sast/?utm_source=chatgpt.com "Static application security testing (SAST)"
[3]: https://github.com/semgrep/semgrep?utm_source=chatgpt.com "semgrep/semgrep: Lightweight static analysis for many ..."

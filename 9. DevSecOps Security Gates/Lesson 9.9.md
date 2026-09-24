# Lesson 9.9 — Policy as Code with OPA and Conftest

# Rego Fundamentals, Conftest, Dockerfile Policy, Terraform Policy, Kubernetes Policy, Exception Validation, GitHub Actions, Jenkins, GitLab CI, and Production Policy Gates

In Lesson 9.8, we added SBOM and license policy.

Now we add the layer that connects all DevSecOps gates together:

```text id="xwu6c3"
Policy as Code
```

Policy as Code means your organization’s rules are written as version-controlled, testable, executable code.

Instead of saying:

```text id="x8bt5k"
Do not deploy latest.
Do not allow public SSH.
Do not allow missing SBOM.
Do not allow root containers.
Do not allow permanent exceptions.
```

You write executable policy:

```text id="yi0dbl"
deny if image tag is latest
deny if security group opens SSH to 0.0.0.0/0
deny if production artifact has no SBOM
deny if Kubernetes container runs as root
deny if exception has no expiry
```

OPA is a general-purpose policy engine that lets you write policy as code in Rego and use it across CI/CD, Kubernetes, APIs, microservices, and other systems. Conftest is a utility for testing structured configuration data with Rego policies. ([Open Policy Agent][1])

---

# 1. Policy as Code Mental Model

Policy as Code answers:

```text id="ldxd3r"
Is this configuration allowed?
```

Examples:

```text id="idgg3m"
Is this Docker image tag allowed?
Is this Terraform security group allowed?
Is this IAM policy too broad?
Is this Kubernetes deployment secure?
Is this security exception valid?
Is this production release missing required evidence?
```

Old model:

```text id="xa5e4s"
security checklist in document
manual review
inconsistent enforcement
late feedback
```

Policy as Code model:

```text id="5lz5ba"
security rules in Git
automated tests
CI/CD enforcement
consistent decisions
auditable policy history
```

Professional rule:

```text id="54c0hs"
If a security rule matters repeatedly, encode it as policy.
```

---

# 2. OPA, Rego, and Conftest

## OPA

OPA is the policy engine.

```text id="yjiwfu"
input data + Rego policy = decision
```

## Rego

Rego is the policy language used by OPA.

Rego queries are assertions on structured data and are used to define decisions about whether input data violates the expected state of a system. Rego supports structured document models such as JSON. ([Open Policy Agent][2])

## Conftest

Conftest is the CLI tool that makes OPA/Rego easy to use in CI/CD.

```text id="h030v6"
YAML / JSON / Terraform / Kubernetes / Dockerfile-like data
  ↓
Conftest
  ↓
Rego policy
  ↓
pass/fail
```

Conftest is designed to test structured configuration data such as Kubernetes configs, Terraform code, Serverless configs, and similar files. ([Conftest][3])

---

# 3. What We Will Build

In this lesson, you will build:

```text id="sxifdu"
OPA/Rego notes
Conftest local setup
Rego policy basics
Docker artifact policy
Terraform security policy
Kubernetes security policy
security exception policy
policy tests
combined policy gate
GitHub Actions workflow
Jenkins pipeline
GitLab CI pipeline
policy runbooks
Makefile targets
```

This lesson will sit above the previous gates.

```text id="49evqm"
SAST
secret scanning
SCA
image scanning
Dockerfile scanning
IaC scanning
SBOM/license
  ↓
Policy as Code
```

---

# 4. Create Lesson Directory

Run:

```bash id="9omiba"
cd ~/devops-masterclass/09-devsecops-security-gates

mkdir -p policy-as-code-opa/{policies,data,scripts,reports,github-actions,jenkins,gitlab,runbooks,examples,notes,tests}
```

Check:

```bash id="c764g2"
tree -L 2 policy-as-code-opa
```

Expected:

```text id="4oar6s"
policy-as-code-opa
├── data
├── examples
├── github-actions
├── gitlab
├── jenkins
├── notes
├── policies
├── reports
├── runbooks
├── scripts
└── tests
```

---

# 5. Install OPA and Conftest

## Install OPA

```bash id="lfd2fz"
mkdir -p "$HOME/.local/bin"

curl -L -o "$HOME/.local/bin/opa" \
  https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static

chmod +x "$HOME/.local/bin/opa"

opa version
```

## Install Conftest

```bash id="xygz6e"
curl -L -o conftest.tar.gz \
  https://github.com/open-policy-agent/conftest/releases/latest/download/conftest_Linux_x86_64.tar.gz

tar -xzf conftest.tar.gz
mv conftest "$HOME/.local/bin/conftest"
rm -f conftest.tar.gz

conftest --version
```

---

# 6. Policy as Code Notes

Create:

```bash id="fjfi8e"
nano policy-as-code-opa/notes/policy-as-code-mental-model.md
```

Paste:

```markdown id="p6zne7"
# Policy as Code with OPA and Conftest

## Definition

Policy as Code means writing security, compliance, and operational rules as version-controlled executable code.

## Tools

| Tool | Purpose |
|---|---|
| OPA | Policy engine |
| Rego | OPA policy language |
| Conftest | CLI for testing structured config with Rego |

## Why It Matters

Policy as Code makes rules:

- repeatable
- testable
- automated
- auditable
- version-controlled
- CI/CD-friendly

## Examples

- deny latest image tags
- deny public SSH
- deny wildcard IAM
- deny root Kubernetes containers
- deny production release without SBOM
- deny exceptions without expiry

## Golden Rule

If the same rule is manually checked more than once, consider encoding it as policy.
```

---

# 7. Rego Basics

Create:

```bash id="knsxkd"
nano policy-as-code-opa/notes/rego-basics.md
```

Paste:

````markdown id="652h0x"
# Rego Basics

## Input

OPA evaluates policy against input data.

Example input:

```json
{
  "image": "demo-node-api:latest",
  "environment": "production"
}
````

## Policy

```rego
package devsecops.image

import rego.v1

deny contains msg if {
  endswith(input.image, ":latest")
  msg := "latest image tag is not allowed"
}
```

## Decision

If `deny` contains messages, the input violates policy.

## Common Functions

* `endswith(value, suffix)`
* `startswith(value, prefix)`
* `contains(value, substring)`
* `lower(value)`
* `sprintf(format, values)`
* array/object iteration

## Conftest Convention

Conftest commonly evaluates policies that produce:

```rego
deny contains msg if {
  ...
}
```

If `deny` has one or more messages, the test fails.

```
```

---

# 8. Create Artifact Policy Input

Create:

```bash id="0eegcl"
nano policy-as-code-opa/examples/artifact-policy-input.json
```

Paste:

```json id="4qkrc4"
{
  "service_name": "demo-node-api",
  "environment": "production",
  "artifact": {
    "image": "demo-node-api:latest",
    "version": "latest",
    "digest": "",
    "sbom": "",
    "provenance": "",
    "signature": "",
    "rollback_version": ""
  },
  "deployment": {
    "manual_approval": false,
    "runtime_verification": false
  }
}
```

This intentionally violates production policy.

Create a passing example:

```bash id="6tjqhm"
nano policy-as-code-opa/examples/artifact-policy-input-secure.json
```

Paste:

```json id="iaszu4"
{
  "service_name": "demo-node-api",
  "environment": "production",
  "artifact": {
    "image": "demo-node-api:0.9.0-prod-a1b2c3d",
    "version": "0.9.0-prod-a1b2c3d",
    "digest": "sha256:exampledigest",
    "sbom": "sbom/demo-node-api-image.cdx.json",
    "provenance": "provenance/demo-node-api.intoto.jsonl",
    "signature": "cosign-signature-present",
    "rollback_version": "0.8.0-prod-f9e8d7c"
  },
  "deployment": {
    "manual_approval": true,
    "runtime_verification": true
  }
}
```

---

# 9. Artifact Release Policy

Create:

```bash id="8q4klv"
nano policy-as-code-opa/policies/artifact_release.rego
```

Paste:

```rego id="66d5o9"
package devsecops.artifact

import rego.v1

deny contains msg if {
  input.environment == "production"
  endswith(input.artifact.image, ":latest")
  msg := "production artifact must not use latest tag"
}

deny contains msg if {
  input.environment == "production"
  input.artifact.digest == ""
  msg := "production artifact must include image digest"
}

deny contains msg if {
  input.environment == "production"
  input.artifact.sbom == ""
  msg := "production artifact must include SBOM reference"
}

deny contains msg if {
  input.environment == "production"
  input.artifact.provenance == ""
  msg := "production artifact must include provenance reference"
}

deny contains msg if {
  input.environment == "production"
  input.artifact.signature == ""
  msg := "production artifact must include signature evidence"
}

deny contains msg if {
  input.environment == "production"
  input.artifact.rollback_version == ""
  msg := "production deployment must include rollback version"
}

deny contains msg if {
  input.environment == "production"
  input.deployment.manual_approval != true
  msg := "production deployment must have manual approval"
}

deny contains msg if {
  input.environment == "production"
  input.deployment.runtime_verification != true
  msg := "production deployment must include runtime verification"
}
```

Run:

```bash id="x7dz8y"
conftest test \
  --policy policy-as-code-opa/policies \
  policy-as-code-opa/examples/artifact-policy-input.json || true
```

Expected:

```text id="eplcl4"
FAIL - artifact-policy-input.json - production artifact must not use latest tag
...
```

Run secure input:

```bash id="dobzg8"
conftest test \
  --policy policy-as-code-opa/policies \
  policy-as-code-opa/examples/artifact-policy-input-secure.json
```

Expected:

```text id="v1eaal"
PASS
```

---

# 10. Terraform Policy Input

Instead of depending on a parser for this first policy lesson, we will normalize important Terraform risks into JSON.

Create:

```bash id="hu9xdo"
nano policy-as-code-opa/examples/terraform-risk-input.json
```

Paste:

```json id="njuebg"
{
  "environment": "production",
  "security_groups": [
    {
      "name": "bad-open-ssh",
      "ingress": [
        {
          "from_port": 22,
          "to_port": 22,
          "cidr_blocks": ["0.0.0.0/0"]
        }
      ]
    },
    {
      "name": "bad-open-mongodb",
      "ingress": [
        {
          "from_port": 27017,
          "to_port": 27017,
          "cidr_blocks": ["0.0.0.0/0"]
        }
      ]
    }
  ],
  "iam_policies": [
    {
      "name": "bad-admin",
      "statements": [
        {
          "effect": "Allow",
          "actions": ["*"],
          "resources": ["*"]
        }
      ]
    }
  ],
  "s3_buckets": [
    {
      "name": "public-bucket",
      "block_public_acls": false,
      "block_public_policy": false,
      "ignore_public_acls": false,
      "restrict_public_buckets": false,
      "encryption_enabled": false
    }
  ],
  "cloudfront": [
    {
      "name": "bad-cdn",
      "viewer_protocol_policy": "allow-all"
    }
  ]
}
```

Create secure version:

```bash id="q8ktr7"
nano policy-as-code-opa/examples/terraform-risk-input-secure.json
```

Paste:

```json id="4mbht6"
{
  "environment": "production",
  "security_groups": [
    {
      "name": "web-only",
      "ingress": [
        {
          "from_port": 443,
          "to_port": 443,
          "cidr_blocks": ["0.0.0.0/0"]
        }
      ]
    }
  ],
  "iam_policies": [
    {
      "name": "limited-ecr",
      "statements": [
        {
          "effect": "Allow",
          "actions": ["ecr:BatchGetImage", "ecr:DescribeImages"],
          "resources": ["arn:aws:ecr:ap-south-1:123456789012:repository/demo-node-api"]
        }
      ]
    }
  ],
  "s3_buckets": [
    {
      "name": "private-bucket",
      "block_public_acls": true,
      "block_public_policy": true,
      "ignore_public_acls": true,
      "restrict_public_buckets": true,
      "encryption_enabled": true
    }
  ],
  "cloudfront": [
    {
      "name": "secure-cdn",
      "viewer_protocol_policy": "redirect-to-https"
    }
  ]
}
```

---

# 11. Terraform Security Rego Policy

Create:

```bash id="21b7ow"
nano policy-as-code-opa/policies/terraform_security.rego
```

Paste:

```rego id="6yy1tv"
package devsecops.terraform

import rego.v1

database_ports := {3306, 5432, 27017, 6379, 9200}

deny contains msg if {
  input.environment == "production"
  sg := input.security_groups[_]
  rule := sg.ingress[_]
  rule.from_port <= 22
  rule.to_port >= 22
  rule.cidr_blocks[_] == "0.0.0.0/0"
  msg := sprintf("security group %s allows SSH from the internet", [sg.name])
}

deny contains msg if {
  input.environment == "production"
  sg := input.security_groups[_]
  rule := sg.ingress[_]
  port := database_ports[_]
  rule.from_port <= port
  rule.to_port >= port
  rule.cidr_blocks[_] == "0.0.0.0/0"
  msg := sprintf("security group %s exposes database-like port %v to the internet", [sg.name, port])
}

deny contains msg if {
  input.environment == "production"
  policy := input.iam_policies[_]
  statement := policy.statements[_]
  statement.actions[_] == "*"
  msg := sprintf("IAM policy %s allows wildcard Action", [policy.name])
}

deny contains msg if {
  input.environment == "production"
  policy := input.iam_policies[_]
  statement := policy.statements[_]
  statement.resources[_] == "*"
  msg := sprintf("IAM policy %s allows wildcard Resource", [policy.name])
}

deny contains msg if {
  input.environment == "production"
  bucket := input.s3_buckets[_]
  bucket.block_public_acls != true
  msg := sprintf("S3 bucket %s does not block public ACLs", [bucket.name])
}

deny contains msg if {
  input.environment == "production"
  bucket := input.s3_buckets[_]
  bucket.block_public_policy != true
  msg := sprintf("S3 bucket %s does not block public bucket policies", [bucket.name])
}

deny contains msg if {
  input.environment == "production"
  bucket := input.s3_buckets[_]
  bucket.encryption_enabled != true
  msg := sprintf("S3 bucket %s does not have encryption enabled", [bucket.name])
}

deny contains msg if {
  input.environment == "production"
  dist := input.cloudfront[_]
  dist.viewer_protocol_policy == "allow-all"
  msg := sprintf("CloudFront distribution %s allows HTTP instead of redirecting to HTTPS", [dist.name])
}
```

Run:

```bash id="ur56qv"
conftest test \
  --policy policy-as-code-opa/policies \
  policy-as-code-opa/examples/terraform-risk-input.json || true
```

Run secure:

```bash id="t493rv"
conftest test \
  --policy policy-as-code-opa/policies \
  policy-as-code-opa/examples/terraform-risk-input-secure.json
```

---

# 12. Kubernetes Policy Input

Create a risky deployment:

```bash id="4wdznn"
nano policy-as-code-opa/examples/k8s-deployment-insecure.yaml
```

Paste:

```yaml id="xy7b7b"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-node-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-node-api
  template:
    metadata:
      labels:
        app: demo-node-api
    spec:
      containers:
        - name: demo-node-api
          image: demo-node-api:latest
          securityContext:
            privileged: true
            runAsUser: 0
          resources: {}
```

Create secure deployment:

```bash id="54e1kd"
nano policy-as-code-opa/examples/k8s-deployment-secure.yaml
```

Paste:

```yaml id="m8gm1x"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-node-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo-node-api
  template:
    metadata:
      labels:
        app: demo-node-api
    spec:
      securityContext:
        runAsNonRoot: true
      containers:
        - name: demo-node-api
          image: demo-node-api:0.9.0-prod-a1b2c3d
          securityContext:
            allowPrivilegeEscalation: false
            privileged: false
            runAsUser: 10001
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
```

---

# 13. Kubernetes Rego Policy

Create:

```bash id="fb7euw"
nano policy-as-code-opa/policies/kubernetes_security.rego
```

Paste:

```rego id="np1uxr"
package devsecops.kubernetes

import rego.v1

is_workload if {
  input.kind == "Deployment"
}

containers := input.spec.template.spec.containers if {
  is_workload
}

deny contains msg if {
  is_workload
  container := containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("container %s must not use latest image tag", [container.name])
}

deny contains msg if {
  is_workload
  container := containers[_]
  container.securityContext.privileged == true
  msg := sprintf("container %s must not run privileged", [container.name])
}

deny contains msg if {
  is_workload
  container := containers[_]
  container.securityContext.runAsUser == 0
  msg := sprintf("container %s must not run as root user", [container.name])
}

deny contains msg if {
  is_workload
  not input.spec.template.spec.securityContext.runAsNonRoot
  msg := "pod securityContext.runAsNonRoot must be true"
}

deny contains msg if {
  is_workload
  container := containers[_]
  not container.securityContext.allowPrivilegeEscalation == false
  msg := sprintf("container %s must set allowPrivilegeEscalation=false", [container.name])
}

deny contains msg if {
  is_workload
  container := containers[_]
  not container.resources.requests.cpu
  msg := sprintf("container %s must set CPU request", [container.name])
}

deny contains msg if {
  is_workload
  container := containers[_]
  not container.resources.limits.memory
  msg := sprintf("container %s must set memory limit", [container.name])
}
```

Run:

```bash id="9nddel"
conftest test \
  --policy policy-as-code-opa/policies \
  policy-as-code-opa/examples/k8s-deployment-insecure.yaml || true
```

Run secure:

```bash id="51km56"
conftest test \
  --policy policy-as-code-opa/policies \
  policy-as-code-opa/examples/k8s-deployment-secure.yaml
```

OPA is commonly used for Kubernetes policy enforcement, and OPA’s general-purpose engine can enforce policy across Kubernetes, CI/CD, microservices, and more. ([Open Policy Agent][1])

---

# 14. Security Exception Policy Input

Create invalid exception:

```bash id="p5b4qp"
nano policy-as-code-opa/examples/security-exception-invalid.json
```

Paste:

```json id="2a41dk"
{
  "exception_id": "SEC-EX-001",
  "finding_id": "CVE-EXAMPLE",
  "severity": "critical",
  "affected_environment": "production",
  "reason": "",
  "risk_owner": "",
  "approved_by": "",
  "expires_on": "",
  "compensating_controls": [],
  "status": "approved"
}
```

Create valid exception:

```bash id="8heekh"
nano policy-as-code-opa/examples/security-exception-valid.json
```

Paste:

```json id="n52ryc"
{
  "exception_id": "SEC-EX-002",
  "finding_id": "CVE-EXAMPLE",
  "severity": "high",
  "affected_environment": "production",
  "reason": "No fixed version available; compensating WAF rule deployed",
  "risk_owner": "platform-team",
  "approved_by": "security-team",
  "expires_on": "2026-08-10",
  "compensating_controls": ["WAF rule", "runtime monitoring", "restricted exposure"],
  "status": "approved"
}
```

---

# 15. Exception Validation Policy

Create:

```bash id="4gzjqr"
nano policy-as-code-opa/policies/security_exception.rego
```

Paste:

```rego id="vk6q7u"
package devsecops.exception

import rego.v1

is_exception if {
  input.exception_id
}

deny contains msg if {
  is_exception
  input.affected_environment == "production"
  input.reason == ""
  msg := "production exception must include reason"
}

deny contains msg if {
  is_exception
  input.affected_environment == "production"
  input.risk_owner == ""
  msg := "production exception must include risk owner"
}

deny contains msg if {
  is_exception
  input.affected_environment == "production"
  input.approved_by == ""
  msg := "production exception must include approver"
}

deny contains msg if {
  is_exception
  input.affected_environment == "production"
  input.expires_on == ""
  msg := "production exception must include expiry date"
}

deny contains msg if {
  is_exception
  input.affected_environment == "production"
  count(input.compensating_controls) == 0
  msg := "production exception must include compensating controls"
}

deny contains msg if {
  is_exception
  input.status == "approved"
  input.approved_by == ""
  msg := "approved exception must include approver"
}
```

Run:

```bash id="1u3llc"
conftest test \
  --policy policy-as-code-opa/policies \
  policy-as-code-opa/examples/security-exception-invalid.json || true
```

Run valid:

```bash id="3rvael"
conftest test \
  --policy policy-as-code-opa/policies \
  policy-as-code-opa/examples/security-exception-valid.json
```

---

# 16. Policy Tests with OPA

OPA also lets you write tests for policies, which helps prevent accidental policy breakage. OPA’s policy testing documentation explains that tests speed up policy development and reduce the risk of breaking policies as requirements evolve. ([Open Policy Agent][4])

Create:

```bash id="xz2ehk"
nano policy-as-code-opa/tests/artifact_release_test.rego
```

Paste:

```rego id="6xw2f8"
package devsecops.artifact

import rego.v1

test_latest_denied if {
  violations := deny with input as {
    "environment": "production",
    "artifact": {
      "image": "demo-node-api:latest",
      "digest": "sha256:abc",
      "sbom": "bom.cdx.json",
      "provenance": "prov.json",
      "signature": "sig",
      "rollback_version": "0.8.0"
    },
    "deployment": {
      "manual_approval": true,
      "runtime_verification": true
    }
  }

  count(violations) == 1
}

test_secure_artifact_allowed if {
  violations := deny with input as {
    "environment": "production",
    "artifact": {
      "image": "demo-node-api:0.9.0-prod-a1b2c3d",
      "digest": "sha256:abc",
      "sbom": "bom.cdx.json",
      "provenance": "prov.json",
      "signature": "sig",
      "rollback_version": "0.8.0"
    },
    "deployment": {
      "manual_approval": true,
      "runtime_verification": true
    }
  }

  count(violations) == 0
}
```

Run OPA tests:

```bash id="dl3u91"
opa test policy-as-code-opa/policies policy-as-code-opa/tests
```

---

# 17. Combined Policy Gate Script

Create:

```bash id="du3l9i"
nano policy-as-code-opa/scripts/policy-as-code-gate.sh
```

Paste:

```bash id="jo5k51"
#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="${MODULE_DIR:-$HOME/devops-masterclass/09-devsecops-security-gates}"
POLICY_DIR="${POLICY_DIR:-$MODULE_DIR/policy-as-code-opa/policies}"
TEST_DIR="${TEST_DIR:-$MODULE_DIR/policy-as-code-opa/tests}"
INPUT_PATH="${INPUT_PATH:-$MODULE_DIR/policy-as-code-opa/examples}"
REPORT_DIR="${REPORT_DIR:-$MODULE_DIR/policy-as-code-opa/reports}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"

FAIL_ON_POLICY="${FAIL_ON_POLICY:-true}"
RUN_OPA_TESTS="${RUN_OPA_TESTS:-true}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/conftest-policy-$ENVIRONMENT-$TIMESTAMP.json"
SUMMARY_FILE="$REPORT_DIR/policy-as-code-summary-$ENVIRONMENT-$TIMESTAMP.json"
OPA_TEST_REPORT="$REPORT_DIR/opa-tests-$ENVIRONMENT-$TIMESTAMP.txt"

echo "===== Policy as Code Gate ====="
echo "Policy dir: $POLICY_DIR"
echo "Test dir: $TEST_DIR"
echo "Input path: $INPUT_PATH"
echo "Environment: $ENVIRONMENT"

if ! command -v conftest >/dev/null 2>&1; then
  echo "ERROR: conftest is required" >&2
  exit 1
fi

if ! command -v opa >/dev/null 2>&1; then
  echo "ERROR: opa is required" >&2
  exit 1
fi

FAILED=0
OPA_TEST_STATUS="skipped"

if [ "$RUN_OPA_TESTS" = "true" ]; then
  set +e
  opa test "$POLICY_DIR" "$TEST_DIR" > "$OPA_TEST_REPORT" 2>&1
  OPA_EXIT=$?
  set -e

  cat "$OPA_TEST_REPORT"

  if [ "$OPA_EXIT" -ne 0 ]; then
    OPA_TEST_STATUS="failed"
    FAILED=1
  else
    OPA_TEST_STATUS="passed"
  fi
fi

set +e
conftest test \
  --policy "$POLICY_DIR" \
  --output json \
  "$INPUT_PATH" > "$REPORT_FILE"
CONFTEST_EXIT=$?
set -e

if [ ! -s "$REPORT_FILE" ]; then
  echo "[]" > "$REPORT_FILE"
fi

FAILURES="$(jq '[.[]?.failures[]?] | length' "$REPORT_FILE")"
WARNINGS="$(jq '[.[]?.warnings[]?] | length' "$REPORT_FILE")"
SUCCESSES="$(jq '[.[]? | select((.failures | length) == 0)] | length' "$REPORT_FILE")"

DECISION="passed"

if [ "$CONFTEST_EXIT" -ne 0 ] || [ "$FAILURES" -gt 0 ]; then
  if [ "$FAIL_ON_POLICY" = "true" ]; then
    DECISION="failed"
    FAILED=1
  else
    DECISION="warning"
  fi
fi

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "policy_as_code",
  "tool": "opa_conftest",
  "environment": "$ENVIRONMENT",
  "input_path": "$INPUT_PATH",
  "policy_dir": "$POLICY_DIR",
  "opa_test_status": "$OPA_TEST_STATUS",
  "conftest_exit_code": $CONFTEST_EXIT,
  "results": {
    "failures": $FAILURES,
    "warnings": $WARNINGS,
    "successes": $SUCCESSES
  },
  "decision": "$DECISION",
  "conftest_report": "$REPORT_FILE",
  "opa_test_report": "$OPA_TEST_REPORT",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .

if [ "$FAILED" -ne 0 ]; then
  echo "ERROR: policy as code gate failed" >&2
  exit 1
fi

echo "Policy as Code gate completed with decision: $DECISION"
```

Make executable:

```bash id="faefun"
chmod +x policy-as-code-opa/scripts/policy-as-code-gate.sh
```

Run against all examples:

```bash id="3x95kr"
INPUT_PATH=policy-as-code-opa/examples \
ENVIRONMENT=pull_request \
FAIL_ON_POLICY=false \
./policy-as-code-opa/scripts/policy-as-code-gate.sh
```

Strict mode:

```bash id="wg7ozl"
INPUT_PATH=policy-as-code-opa/examples \
ENVIRONMENT=main \
FAIL_ON_POLICY=true \
./policy-as-code-opa/scripts/policy-as-code-gate.sh || true
```

Run only secure examples:

```bash id="zjhb1s"
mkdir -p policy-as-code-opa/examples-secure

cp policy-as-code-opa/examples/artifact-policy-input-secure.json policy-as-code-opa/examples-secure/
cp policy-as-code-opa/examples/terraform-risk-input-secure.json policy-as-code-opa/examples-secure/
cp policy-as-code-opa/examples/k8s-deployment-secure.yaml policy-as-code-opa/examples-secure/
cp policy-as-code-opa/examples/security-exception-valid.json policy-as-code-opa/examples-secure/

INPUT_PATH=policy-as-code-opa/examples-secure \
ENVIRONMENT=main \
FAIL_ON_POLICY=true \
./policy-as-code-opa/scripts/policy-as-code-gate.sh
```

---

# 18. Policy Summary Script

Create:

```bash id="fdxx49"
nano policy-as-code-opa/scripts/policy-as-code-summary.sh
```

Paste:

```bash id="1adwll"
#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-policy-as-code-opa/reports}"

echo "===== Policy as Code Summary ====="
echo "Report dir: $REPORT_DIR"

find "$REPORT_DIR" -type f -name '*summary*.json' | sort | tail -n 10 | while read -r file; do
  echo
  echo "## $file"
  jq . "$file"
done

echo
echo "Recent Conftest reports:"
find "$REPORT_DIR" -type f -name 'conftest-policy-*.json' | sort | tail -n 10

echo
echo "Recent OPA test reports:"
find "$REPORT_DIR" -type f -name 'opa-tests-*.txt' | sort | tail -n 10
```

Make executable:

```bash id="0nihya"
chmod +x policy-as-code-opa/scripts/policy-as-code-summary.sh
```

Run:

```bash id="cnld9o"
./policy-as-code-opa/scripts/policy-as-code-summary.sh
```

---

# 19. GitHub Actions Workflow

Create:

```bash id="upozqj"
nano policy-as-code-opa/github-actions/policy-as-code-opa.yml
```

Paste:

```yaml id="yk4yhm"
name: Policy as Code OPA

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main
  workflow_dispatch:
    inputs:
      input_path:
        description: "Input path to evaluate"
        required: true
        default: "09-devsecops-security-gates/policy-as-code-opa/examples-secure"
        type: string

permissions:
  contents: read

env:
  MODULE9_DIR: 09-devsecops-security-gates

jobs:
  opa-conftest:
    name: OPA and Conftest policy gate
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Install OPA
        run: |
          mkdir -p "$HOME/.local/bin"
          curl -L -o "$HOME/.local/bin/opa" \
            https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static
          chmod +x "$HOME/.local/bin/opa"
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"
          opa version

      - name: Install Conftest
        run: |
          curl -L -o conftest.tar.gz \
            https://github.com/open-policy-agent/conftest/releases/latest/download/conftest_Linux_x86_64.tar.gz
          tar -xzf conftest.tar.gz
          mkdir -p "$HOME/.local/bin"
          mv conftest "$HOME/.local/bin/conftest"
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"
          conftest --version

      - name: Resolve input path
        id: vars
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            INPUT_PATH="${{ inputs.input_path }}"
          else
            INPUT_PATH="09-devsecops-security-gates/policy-as-code-opa/examples-secure"
          fi

          if [ "${{ github.event_name }}" = "pull_request" ]; then
            ENVIRONMENT="pull_request"
            FAIL_POLICY="true"
          else
            ENVIRONMENT="main"
            FAIL_POLICY="true"
          fi

          echo "input_path=$INPUT_PATH" >> "$GITHUB_OUTPUT"
          echo "environment=$ENVIRONMENT" >> "$GITHUB_OUTPUT"
          echo "fail_policy=$FAIL_POLICY" >> "$GITHUB_OUTPUT"

      - name: Run policy gate
        run: |
          cd "$MODULE9_DIR"

          INPUT_PATH="$GITHUB_WORKSPACE/${{ steps.vars.outputs.input_path }}" \
          ENVIRONMENT="${{ steps.vars.outputs.environment }}" \
          FAIL_ON_POLICY="${{ steps.vars.outputs.fail_policy }}" \
          ./policy-as-code-opa/scripts/policy-as-code-gate.sh

      - name: Upload policy reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: policy-as-code-reports
          path: 09-devsecops-security-gates/policy-as-code-opa/reports/
```

Copy:

```bash id="j2t2eh"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/policy-as-code-opa/github-actions/policy-as-code-opa.yml \
   .github/workflows/policy-as-code-opa.yml
```

---

# 20. Jenkins Pipeline

Create:

```bash id="nmv91x"
nano policy-as-code-opa/jenkins/Jenkinsfile.policy-as-code-opa
```

Paste:

```groovy id="h0aik2"
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
  }

  parameters {
    string(name: 'INPUT_PATH', defaultValue: '09-devsecops-security-gates/policy-as-code-opa/examples-secure', description: 'Input path to evaluate')
    choice(name: 'ENVIRONMENT', choices: ['pull_request', 'main', 'production'], description: 'Gate environment')
    booleanParam(name: 'FAIL_ON_POLICY', defaultValue: true, description: 'Fail on policy violations?')
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

    stage('Tool Check') {
      steps {
        sh '''
          export PATH="$HOME/.local/bin:$PATH"

          if ! command -v opa >/dev/null 2>&1; then
            mkdir -p "$HOME/.local/bin"
            curl -L -o "$HOME/.local/bin/opa" https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static
            chmod +x "$HOME/.local/bin/opa"
          fi

          if ! command -v conftest >/dev/null 2>&1; then
            curl -L -o conftest.tar.gz https://github.com/open-policy-agent/conftest/releases/latest/download/conftest_Linux_x86_64.tar.gz
            tar -xzf conftest.tar.gz
            mv conftest "$HOME/.local/bin/conftest"
            rm -f conftest.tar.gz
          fi

          opa version
          conftest --version
        '''
      }
    }

    stage('Policy Gate') {
      steps {
        dir("${MODULE9_DIR}") {
          sh '''
            export PATH="$HOME/.local/bin:$PATH"

            INPUT_PATH="$WORKSPACE/${INPUT_PATH}" \
            ENVIRONMENT="${ENVIRONMENT}" \
            FAIL_ON_POLICY="${FAIL_ON_POLICY}" \
            ./policy-as-code-opa/scripts/policy-as-code-gate.sh
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '09-devsecops-security-gates/policy-as-code-opa/reports/**/*', allowEmptyArchive: true
    }

    success {
      echo 'Policy as Code gate passed.'
    }

    failure {
      echo 'Policy as Code gate failed. Review archived reports.'
    }
  }
}
```

Jenkins script path:

```text id="m9lnii"
09-devsecops-security-gates/policy-as-code-opa/jenkins/Jenkinsfile.policy-as-code-opa
```

---

# 21. GitLab CI Pipeline

Create:

```bash id="1b46ic"
nano policy-as-code-opa/gitlab/.gitlab-ci.policy-as-code-opa.yml
```

Paste:

```yaml id="kk27gp"
stages:
  - policy

variables:
  MODULE9_DIR: "09-devsecops-security-gates"
  INPUT_PATH: "09-devsecops-security-gates/policy-as-code-opa/examples-secure"

policy_as_code_opa:
  stage: policy
  image: alpine:3.20
  before_script:
    - apk add --no-cache bash curl jq tar gzip
    - mkdir -p /usr/local/bin
    - curl -L -o /usr/local/bin/opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static
    - chmod +x /usr/local/bin/opa
    - curl -L -o conftest.tar.gz https://github.com/open-policy-agent/conftest/releases/latest/download/conftest_Linux_x86_64.tar.gz
    - tar -xzf conftest.tar.gz
    - mv conftest /usr/local/bin/conftest
    - opa version
    - conftest --version
  script:
    - cd "$MODULE9_DIR"
    - |
      if [ "${CI_COMMIT_BRANCH:-}" = "main" ]; then
        ENVIRONMENT="main"
      else
        ENVIRONMENT="pull_request"
      fi

      INPUT_PATH="$CI_PROJECT_DIR/$INPUT_PATH" \
      ENVIRONMENT="$ENVIRONMENT" \
      FAIL_ON_POLICY=true \
      ./policy-as-code-opa/scripts/policy-as-code-gate.sh
  artifacts:
    when: always
    expire_in: 30 days
    paths:
      - 09-devsecops-security-gates/policy-as-code-opa/reports/
```

---

# 22. Policy Authoring Runbook

Create:

```bash id="dc8j9n"
nano policy-as-code-opa/runbooks/policy-authoring-runbook.md
```

Paste:

````markdown id="l949yn"
# Policy Authoring Runbook

## Goal

Write safe, testable, maintainable Rego policies.

## Steps

1. Define the rule in plain English.
2. Define the expected input schema.
3. Create failing input example.
4. Create passing input example.
5. Write Rego deny rule.
6. Run Conftest manually.
7. Add OPA unit tests.
8. Add to CI/CD gate.
9. Document exception process.

## Example Rule

Plain English:

> Production artifacts must not use latest image tags.

Rego:

```rego
deny contains msg if {
  input.environment == "production"
  endswith(input.artifact.image, ":latest")
  msg := "production artifact must not use latest tag"
}
````

## Policy Quality Checklist

* [ ] clear rule message
* [ ] passing example exists
* [ ] failing example exists
* [ ] unit test exists
* [ ] exception process documented
* [ ] CI/CD gate archives reports

```
```

---

# 23. Policy Debugging Runbook

Create:

```bash id="3l8vbn"
nano policy-as-code-opa/runbooks/policy-debugging-runbook.md
```

Paste:

````markdown id="fjt6lw"
# Policy Debugging Runbook

## Common Problems

### Policy does not match input

Check input shape:

```bash
cat input.json | jq .
````

Run Conftest with JSON output:

```bash
conftest test --policy policies --output json input.json | jq .
```

### Rego syntax error

Run:

```bash
opa check policies
```

### Policy logic wrong

Add an OPA test:

```bash
opa test policies tests
```

### Too many false positives

Fix by:

* narrowing conditions
* adding input schema assumptions
* using exception rules
* adding allowlist data only when justified

### Policy misses bad config

Add:

* failing fixture
* unit test
* stricter rule

````

---

# 24. Production Policy Checklist

Create:

```bash id="95vfkc"
nano policy-as-code-opa/runbooks/production-policy-checklist.md
````

Paste:

```markdown id="x28620"
# Production Policy Checklist

Before enforcing policy in production:

- [ ] policy has clear owner
- [ ] policy has clear message
- [ ] passing fixture exists
- [ ] failing fixture exists
- [ ] OPA unit test exists
- [ ] exception process exists
- [ ] CI/CD reports are archived
- [ ] rollout starts in warn/report mode
- [ ] team reviewed false positives
- [ ] policy is enforced in main/production
- [ ] policy changes require code review
```

---

# 25. Validation Script

Create:

```bash id="ulxl1b"
nano policy-as-code-opa/scripts/validate-policy-as-code-lesson.sh
```

Paste:

```bash id="612gqs"
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-policy-as-code-opa}"

echo "===== Validate Policy as Code Lesson ====="

test -f "$BASE_DIR/notes/policy-as-code-mental-model.md"
test -f "$BASE_DIR/notes/rego-basics.md"

test -f "$BASE_DIR/policies/artifact_release.rego"
test -f "$BASE_DIR/policies/terraform_security.rego"
test -f "$BASE_DIR/policies/kubernetes_security.rego"
test -f "$BASE_DIR/policies/security_exception.rego"

test -f "$BASE_DIR/examples/artifact-policy-input.json"
test -f "$BASE_DIR/examples/artifact-policy-input-secure.json"
test -f "$BASE_DIR/examples/terraform-risk-input.json"
test -f "$BASE_DIR/examples/terraform-risk-input-secure.json"
test -f "$BASE_DIR/examples/k8s-deployment-insecure.yaml"
test -f "$BASE_DIR/examples/k8s-deployment-secure.yaml"
test -f "$BASE_DIR/examples/security-exception-invalid.json"
test -f "$BASE_DIR/examples/security-exception-valid.json"

test -f "$BASE_DIR/tests/artifact_release_test.rego"

test -x "$BASE_DIR/scripts/policy-as-code-gate.sh"
test -x "$BASE_DIR/scripts/policy-as-code-summary.sh"

test -f "$BASE_DIR/github-actions/policy-as-code-opa.yml"
test -f "$BASE_DIR/jenkins/Jenkinsfile.policy-as-code-opa"
test -f "$BASE_DIR/gitlab/.gitlab-ci.policy-as-code-opa.yml"

test -f "$BASE_DIR/runbooks/policy-authoring-runbook.md"
test -f "$BASE_DIR/runbooks/policy-debugging-runbook.md"
test -f "$BASE_DIR/runbooks/production-policy-checklist.md"

if command -v opa >/dev/null 2>&1; then
  opa check "$BASE_DIR/policies"
  opa test "$BASE_DIR/policies" "$BASE_DIR/tests"
else
  echo "WARN: opa not installed; skipping opa check/test."
fi

if command -v conftest >/dev/null 2>&1; then
  conftest test --policy "$BASE_DIR/policies" "$BASE_DIR/examples-secure"
else
  echo "WARN: conftest not installed; skipping conftest test."
fi

echo "Policy as Code lesson validated."
```

Make executable:

```bash id="4qzp7o"
chmod +x policy-as-code-opa/scripts/validate-policy-as-code-lesson.sh
```

Create secure examples directory:

```bash id="dqp4b0"
mkdir -p policy-as-code-opa/examples-secure

cp policy-as-code-opa/examples/artifact-policy-input-secure.json policy-as-code-opa/examples-secure/
cp policy-as-code-opa/examples/terraform-risk-input-secure.json policy-as-code-opa/examples-secure/
cp policy-as-code-opa/examples/k8s-deployment-secure.yaml policy-as-code-opa/examples-secure/
cp policy-as-code-opa/examples/security-exception-valid.json policy-as-code-opa/examples-secure/
```

Run:

```bash id="b9qhkk"
./policy-as-code-opa/scripts/validate-policy-as-code-lesson.sh
```

---

# 26. Update Makefile

Open:

```bash id="1tdlbi"
cd ~/devops-masterclass/09-devsecops-security-gates

nano Makefile
```

Add:

```Makefile id="mqxiav"
.PHONY: opa-validate opa-test conftest-secure conftest-insecure policy-gate policy-gate-strict policy-summary

opa-validate:
	./policy-as-code-opa/scripts/validate-policy-as-code-lesson.sh

opa-test:
	opa test policy-as-code-opa/policies policy-as-code-opa/tests

conftest-secure:
	conftest test --policy policy-as-code-opa/policies policy-as-code-opa/examples-secure

conftest-insecure:
	conftest test --policy policy-as-code-opa/policies policy-as-code-opa/examples || true

policy-gate:
	INPUT_PATH="$${INPUT_PATH:-policy-as-code-opa/examples-secure}" \
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_POLICY="$${FAIL_ON_POLICY:-true}" \
	./policy-as-code-opa/scripts/policy-as-code-gate.sh

policy-gate-strict:
	INPUT_PATH="$${INPUT_PATH:-policy-as-code-opa/examples}" \
	ENVIRONMENT=main \
	FAIL_ON_POLICY=true \
	./policy-as-code-opa/scripts/policy-as-code-gate.sh || true

policy-summary:
	./policy-as-code-opa/scripts/policy-as-code-summary.sh
```

Run:

```bash id="yrqn5x"
make opa-validate
make opa-test
make conftest-secure
make conftest-insecure
make policy-gate
make policy-summary
```

---

# 27. Practical Lab

Run full lesson:

```bash id="of4g2l"
cd ~/devops-masterclass/09-devsecops-security-gates

make opa-validate
make opa-test

make conftest-insecure
make conftest-secure

INPUT_PATH=policy-as-code-opa/examples-secure \
ENVIRONMENT=main \
FAIL_ON_POLICY=true \
make policy-gate

make policy-summary
```

Copy GitHub workflow:

```bash id="rclckr"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/policy-as-code-opa/github-actions/policy-as-code-opa.yml \
   .github/workflows/policy-as-code-opa.yml
```

Commit:

```bash id="ymtqmp"
git status

git add .github/workflows/policy-as-code-opa.yml \
        09-devsecops-security-gates

git commit -m "feat: add OPA policy as code gates"
git push
```

---

# 28. Common OPA/Rego Problems

## Syntax error

Run:

```bash id="rlj2vc"
opa check policy-as-code-opa/policies
```

## Policy does not trigger

Inspect input:

```bash id="unr1l1"
cat policy-as-code-opa/examples/artifact-policy-input.json | jq .
```

Then run:

```bash id="i22fmu"
conftest test --policy policy-as-code-opa/policies --output json policy-as-code-opa/examples/artifact-policy-input.json | jq .
```

## Too many false positives

Add better conditions.

Bad:

```rego id="zf1wz2"
deny contains msg if {
  input.image
}
```

Better:

```rego id="orqu3q"
deny contains msg if {
  input.environment == "production"
  endswith(input.artifact.image, ":latest")
  msg := "production artifact must not use latest tag"
}
```

## Policy changed and broke CI

Add OPA tests.

```bash id="nqcq6t"
opa test policy-as-code-opa/policies policy-as-code-opa/tests
```

## Conftest input shape is confusing

Use normalized JSON first.

```text id="d2afto"
scanner/raw config
  ↓
normalizer script
  ↓
policy input JSON
  ↓
Conftest
```

This is often easier than writing policies directly against every possible raw tool format.

---

# 29. Interview Explanation

## What is Policy as Code?

```text id="lfep0e"
Policy as Code means writing security, compliance, and operational rules as executable, version-controlled code. It allows CI/CD systems to automatically enforce rules such as no latest tags, no public SSH, required SBOMs, non-root containers, and valid security exceptions.
```

## What is OPA?

```text id="5vwqgr"
OPA, or Open Policy Agent, is a general-purpose policy engine. It evaluates structured input data against policies written in Rego and returns decisions that can be used by CI/CD, Kubernetes, APIs, or other systems.
```

## What is Rego?

```text id="6skh0q"
Rego is OPA’s declarative policy language. It lets you write rules that evaluate structured data such as JSON or YAML and produce decisions such as allow, deny, or a list of violations.
```

## What is Conftest?

```text id="vbvgkl"
Conftest is a CLI tool that uses Rego policies to test structured configuration data. It is useful for CI/CD checks against Kubernetes manifests, Terraform-like inputs, deployment metadata, exceptions, and other configuration files.
```

## Why add policy tests?

```text id="ox0gyp"
Policy tests prevent accidental policy regressions. When rules change, tests verify that known-bad inputs still fail and known-good inputs still pass.
```

## What should be encoded as policy?

```text id="d6ysh0"
Rules that are repeated, important, and objective should become policy. Examples include blocking latest tags, requiring SBOMs for production, denying public SSH, requiring non-root containers, and requiring expiry dates for exceptions.
```

---

# 30. Today’s Core Rules

```text id="h9wznu"
Policy as Code makes rules executable.
OPA is the policy engine.
Rego is the policy language.
Conftest tests structured config with Rego.
Use deny messages for CI/CD gate failures.
Normalize complex tool output when needed.
Write passing and failing fixtures.
Write OPA tests for policies.
Start in report/warn mode before strict enforcement.
Production policies should be strict and auditable.
Security exceptions must be validated by policy too.
```

---

# Next Lesson

# Lesson 9.10 — DAST and Runtime Security Smoke Tests

We will build:

```text id="74ximc"
DAST mental model
OWASP ZAP baseline scan
runtime security headers check
HTTP method checks
health endpoint exposure checks
basic auth/session checks
API security smoke tests
GitHub Actions DAST workflow
Jenkins DAST pipeline
GitLab CI DAST pipeline
DAST triage runbook
production-safe DAST gate
```

[1]: https://openpolicyagent.org/docs?utm_source=chatgpt.com "Open Policy Agent (OPA)"
[2]: https://openpolicyagent.org/docs/policy-language?utm_source=chatgpt.com "Policy Language"
[3]: https://www.conftest.dev/?utm_source=chatgpt.com "Conftest"
[4]: https://openpolicyagent.org/docs/policy-testing?utm_source=chatgpt.com "Policy Testing"

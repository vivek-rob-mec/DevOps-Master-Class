# Module 12 — Terraform, Ansible, and IaC

# Lesson 12.15 — Policy Checks for IaC

In Lesson 12.14, you built CI/CD pipelines for Terraform and Ansible:

```text id="recap-12-14"
Terraform fmt
Terraform validate
Terraform plan
saved plan artifacts
manual approval before apply
GitHub Actions OIDC
Ansible validation
drift detection
safe destroy plan workflow
```

Now we add **Policy-as-Code guardrails** before infrastructure can be applied.

Terraform can export a saved plan as JSON using `terraform show -json <planfile>`, which lets scripts and policy engines inspect exactly what Terraform intends to create, update, or delete. OPA is a common policy-as-code engine for evaluating Terraform plans as JSON input. ([HashiCorp Developer][1])

---

# 1. Goal

Build a practical policy gate that blocks risky infrastructure before apply.

You will create checks for:

```text id="goal"
deny public SSH
deny public database ports
require approved AWS region
require required tags
require S3 public access block
require S3 encryption
require EC2 IMDSv2
require CloudFront HTTPS viewer redirect
require CloudFront S3 OAC
detect unsafe security group CIDRs
generate policy reports
integrate policy checks into CI/CD
```

Architecture:

```text id="policy-flow"
terraform plan -out=tfplan
  ↓
terraform show -json tfplan > tfplan.json
  ↓
custom policy checker
  ↓
policy report
  ↓
pass:
  apply allowed

fail:
  apply blocked
```

---

# 2. What You Will Learn

```text id="lesson-map"
12.15.1   Policy-as-Code mental model
12.15.2   Terraform plan JSON
12.15.3   resource_changes inspection
12.15.4   planned_values inspection
12.15.5   deny vs warn rules
12.15.6   security group guardrails
12.15.7   S3 guardrails
12.15.8   EC2 IMDSv2 guardrails
12.15.9   CloudFront guardrails
12.15.10  tag guardrails
12.15.11  approved region guardrails
12.15.12  OPA/Rego concept
12.15.13  Checkov concept
12.15.14  tfsec/Trivy concept
12.15.15  IAM Access Analyzer validation
12.15.16  CI/CD policy gates
12.15.17  reports and runbooks
```

Checkov scans IaC such as Terraform, CloudFormation, Kubernetes, Helm, ARM templates, and other formats. tfsec has been folded into Aqua Security’s Trivy ecosystem, so for new pipelines, Trivy or Checkov are often better long-term choices than starting with standalone tfsec. ([Checkov][2])

---

# 3. Never Confuse These

## Static Code Scan vs Plan Scan

```text id="static-vs-plan"
Static code scan:
  scans .tf files before Terraform evaluates variables/modules

Plan scan:
  scans actual resolved Terraform plan after variables, modules, count, for_each, and provider defaults
```

Both are useful.

For this lesson:

```text id="lesson-choice"
Primary:
  Terraform plan JSON scan

Optional:
  OPA/Rego, Checkov, Trivy concepts
```

---

## Warning vs Deny

```text id="warn-vs-deny"
warning:
  visible risk, but pipeline can continue

deny:
  pipeline must fail
```

Example:

```text id="deny-example"
public SSH from 0.0.0.0/0:
  deny

ALB deletion protection disabled in dev:
  warn
```

---

## Security Group Rule vs NACL Rule

```text id="sg-vs-nacl"
Security group rule:
  attached to SG/ENI level

NACL rule:
  subnet-level stateless filter
```

This policy gate checks security groups first.

---

## OPA vs Custom Script

```text id="opa-vs-script"
OPA:
  general policy engine using Rego

custom script:
  direct Python checks for your repo and team standards
```

In real companies, you may use both:

```text id="both"
custom fast checks:
  team-specific guardrails

OPA/Checkov/Trivy:
  broader platform/security policy checks
```

OPA receives structured data such as JSON as input and evaluates policies written in Rego. Terraform plan JSON is one of the common OPA use cases. ([Open Policy Agent][3])

---

# 4. Create Lesson Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 12-terraform-ansible-iac/12.15-policy-checks/{notes,scripts,runbooks,reports,policies,examples}
mkdir -p 12-terraform-ansible-iac/policy
```

Check:

```bash id="tree-folder"
tree -L 3 12-terraform-ansible-iac/12.15-policy-checks
tree -L 3 12-terraform-ansible-iac/policy
```

---

# 5. Create Policy Mental Model Notes

```bash id="mental-note"
cat > 12-terraform-ansible-iac/12.15-policy-checks/notes/policy-as-code-mental-model.md <<'EOF'
# Policy-as-Code Mental Model

## Policy-as-Code

Policy-as-Code means writing operational, security, compliance, and cost rules as version-controlled code.

## Main question

Should this infrastructure change be allowed?

## Inputs

Possible policy inputs:

- Terraform HCL
- Terraform plan JSON
- Terraform state JSON
- Kubernetes manifests
- Dockerfiles
- IAM policies
- CI/CD metadata

## Outputs

Policy engines should produce:

- pass/fail decision
- violation list
- severity
- resource address
- explanation
- remediation hint

## Good policy rule

A good policy rule is:

- specific
- explainable
- testable
- version-controlled
- not overly noisy
- mapped to a real risk

## Golden rule

Policy checks should catch dangerous changes before apply, not after an incident.
EOF
```

---

# 6. Create Never-Forget Policy Notes

````bash id="never-note"
cat > 12-terraform-ansible-iac/12.15-policy-checks/notes/never-confuse-policy-points.md <<'EOF'
# Never Forget — IaC Policy Checks

## 1. Plan JSON is resolved intent

Terraform plan JSON shows what Terraform intends to do after variables and modules are evaluated.

## 2. Policy check should run before apply

Never wait until after apply to discover public SSH or public S3 mistakes.

## 3. Explicit denies should be rare but firm

Deny only things your team truly wants to block.

## 4. Warnings are useful for coaching

Warnings help teams improve without blocking every small issue.

## 5. Policy should explain the fix

Bad:

```text
Policy failed.
````

Good:

```text id="ky44aq"
aws_instance.app must require IMDSv2.
Set metadata_options.http_tokens = "required".
```

## 6. Do not rely only on one scanner

Use layered checks:

* custom policy script
* OPA/Rego
* Checkov or Trivy
* IAM Access Analyzer
* cloud-native config checks

## 7. Policy reports are audit evidence

Keep reports as CI artifacts.

## 8. Suppressions need governance

Allow exceptions only with owner, reason, expiry, and ticket.

## 9. Dev can be relaxed, prod should be strict

But dev should still block dangerous mistakes such as public SSH.

## 10. Policy-as-Code is production engineering

It is not just security paperwork.
EOF

````

---

# 7. Define Your Policy Rules

Create a simple YAML file describing policy intent.

```bash id="rules-yml"
cat > 12-terraform-ansible-iac/policy/iac-policy-rules.yml <<'EOF'
---
approved_regions:
  - ap-south-1

required_tags:
  - Project
  - Environment
  - ManagedBy

deny_public_ingress_ports:
  - 22
  - 3389
  - 3306
  - 5432
  - 6379
  - 27017
  - 9200
  - 9300

public_cidrs:
  - 0.0.0.0/0
  - ::/0

s3:
  require_public_access_block: true
  require_encryption: true

ec2:
  require_imdsv2: true

cloudfront:
  require_https_redirect: true
  require_oac_for_s3_origin: true

severity:
  public_ssh: deny
  public_database_port: deny
  missing_required_tags: warn
  s3_missing_public_access_block: deny
  s3_missing_encryption: deny
  ec2_imdsv2_not_required: deny
  cloudfront_no_https_redirect: deny
  cloudfront_s3_without_oac: deny
  unapproved_region: deny
EOF
````

---

# 8. Create Terraform Plan Policy Checker

This is your custom policy gate.

```bash id="policy-script"
cat > 12-terraform-ansible-iac/policy/terraform_plan_policy_check.py <<'EOF'
#!/usr/bin/env python3
import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

try:
    import yaml
except ImportError:
    print("Missing PyYAML. Install with: python3 -m pip install pyyaml", file=sys.stderr)
    sys.exit(1)


def load_json(path: Path) -> Dict[str, Any]:
    with path.open() as f:
        return json.load(f)


def load_yaml(path: Path) -> Dict[str, Any]:
    with path.open() as f:
        return yaml.safe_load(f)


def walk_modules(module: Dict[str, Any]) -> Iterable[Dict[str, Any]]:
    yield module
    for child in module.get("child_modules", []) or []:
        yield from walk_modules(child)


def planned_resources(plan: Dict[str, Any]) -> List[Dict[str, Any]]:
    root = plan.get("planned_values", {}).get("root_module", {})
    resources = []
    for module in walk_modules(root):
        resources.extend(module.get("resources", []) or [])
    return resources


def resource_changes(plan: Dict[str, Any]) -> List[Dict[str, Any]]:
    return plan.get("resource_changes", []) or []


def after(change: Dict[str, Any]) -> Dict[str, Any]:
    return change.get("change", {}).get("after") or {}


def actions(change: Dict[str, Any]) -> List[str]:
    return change.get("change", {}).get("actions") or []


def is_deleted(change: Dict[str, Any]) -> bool:
    acts = actions(change)
    return acts == ["delete"]


def get_tags(values: Dict[str, Any]) -> Dict[str, Any]:
    tags = values.get("tags_all") or values.get("tags") or {}
    return tags if isinstance(tags, dict) else {}


def add_violation(violations: List[Dict[str, str]], severity: str, rule: str, address: str, message: str, fix: str) -> None:
    violations.append(
        {
            "severity": severity,
            "rule": rule,
            "address": address,
            "message": message,
            "fix": fix,
        }
    )


def cidr_is_public(cidr: Optional[str], public_cidrs: List[str]) -> bool:
    return cidr in public_cidrs


def port_range_contains(from_port: Any, to_port: Any, target_port: int) -> bool:
    try:
        f = int(from_port)
        t = int(to_port)
    except (TypeError, ValueError):
        return False
    return f <= target_port <= t


def check_region(violations: List[Dict[str, str]], rules: Dict[str, Any], environment_region: str) -> None:
    approved = rules.get("approved_regions", [])
    if environment_region not in approved:
        add_violation(
            violations,
            "deny",
            "unapproved_region",
            "provider.aws",
            f"AWS region {environment_region} is not approved.",
            f"Use one of: {', '.join(approved)}",
        )


def check_security_groups(violations: List[Dict[str, str]], changes: List[Dict[str, Any]], rules: Dict[str, Any]) -> None:
    public_cidrs = rules.get("public_cidrs", ["0.0.0.0/0", "::/0"])
    denied_ports = [int(p) for p in rules.get("deny_public_ingress_ports", [])]

    for change in changes:
        if is_deleted(change):
            continue

        rtype = change.get("type")
        address = change.get("address", "unknown")
        values = after(change)

        if rtype == "aws_vpc_security_group_ingress_rule":
            cidrs = []
            if values.get("cidr_ipv4"):
                cidrs.append(values.get("cidr_ipv4"))
            if values.get("cidr_ipv6"):
                cidrs.append(values.get("cidr_ipv6"))

            from_port = values.get("from_port")
            to_port = values.get("to_port")
            ip_protocol = values.get("ip_protocol")

            if ip_protocol in ("tcp", "-1", None):
                for cidr in cidrs:
                    if not cidr_is_public(cidr, public_cidrs):
                        continue

                    for port in denied_ports:
                        if port_range_contains(from_port, to_port, port):
                            rule_name = "public_ssh" if port == 22 else "public_database_or_admin_port"
                            add_violation(
                                violations,
                                "deny",
                                rule_name,
                                address,
                                f"Public ingress to sensitive port {port} from {cidr} is not allowed.",
                                "Restrict source CIDR, remove the rule, or use ALB/SSM/VPN/bastion access.",
                            )

        if rtype == "aws_security_group":
            for block_name in ["ingress", "egress"]:
                for rule_block in values.get(block_name, []) or []:
                    cidrs = list(rule_block.get("cidr_blocks") or []) + list(rule_block.get("ipv6_cidr_blocks") or [])
                    from_port = rule_block.get("from_port")
                    to_port = rule_block.get("to_port")
                    protocol = rule_block.get("protocol")

                    if protocol in ("tcp", "-1", None):
                        for cidr in cidrs:
                            if not cidr_is_public(cidr, public_cidrs):
                                continue

                            for port in denied_ports:
                                if port_range_contains(from_port, to_port, port):
                                    add_violation(
                                        violations,
                                        "deny",
                                        "public_sensitive_inline_sg_rule",
                                        address,
                                        f"Inline security group rule exposes sensitive port {port} to {cidr}.",
                                        "Use restricted CIDR or source security group reference.",
                                    )


def check_required_tags(violations: List[Dict[str, str]], changes: List[Dict[str, Any]], rules: Dict[str, Any]) -> None:
    required = rules.get("required_tags", [])
    aws_prefixes = ("aws_",)

    ignored_types = {
        "aws_s3_bucket_policy",
        "aws_s3_object",
        "aws_vpc_security_group_ingress_rule",
        "aws_vpc_security_group_egress_rule",
        "aws_route",
        "aws_route_table_association",
        "aws_iam_role_policy_attachment",
    }

    for change in changes:
        if is_deleted(change):
            continue

        rtype = change.get("type", "")
        address = change.get("address", "unknown")

        if not rtype.startswith(aws_prefixes) or rtype in ignored_types:
            continue

        values = after(change)
        tags = get_tags(values)
        missing = [tag for tag in required if tag not in tags or tags.get(tag) in ("", None)]

        if missing:
            add_violation(
                violations,
                "warn",
                "missing_required_tags",
                address,
                f"Resource is missing required tags: {', '.join(missing)}.",
                "Add tags through provider default_tags or resource tags.",
            )


def check_ec2_imdsv2(violations: List[Dict[str, str]], changes: List[Dict[str, Any]], rules: Dict[str, Any]) -> None:
    if not rules.get("ec2", {}).get("require_imdsv2", True):
        return

    for change in changes:
        if is_deleted(change):
            continue

        if change.get("type") != "aws_instance":
            continue

        address = change.get("address", "unknown")
        values = after(change)
        metadata_options = values.get("metadata_options") or []
        http_tokens = None

        if isinstance(metadata_options, list) and metadata_options:
            http_tokens = metadata_options[0].get("http_tokens")
        elif isinstance(metadata_options, dict):
            http_tokens = metadata_options.get("http_tokens")

        if http_tokens != "required":
            add_violation(
                violations,
                "deny",
                "ec2_imdsv2_not_required",
                address,
                "EC2 instance does not require IMDSv2.",
                'Set metadata_options { http_tokens = "required" } on aws_instance or launch template.',
            )


def check_s3_controls(violations: List[Dict[str, str]], resources: List[Dict[str, Any]], changes: List[Dict[str, Any]], rules: Dict[str, Any]) -> None:
    s3_rules = rules.get("s3", {})
    if not s3_rules:
        return

    resource_types = {r.get("type") for r in resources}
    changed_types = {c.get("type") for c in changes if not is_deleted(c)}
    all_types = resource_types | changed_types

    if s3_rules.get("require_public_access_block", True) and "aws_s3_bucket" in all_types:
        if "aws_s3_bucket_public_access_block" not in all_types:
            add_violation(
                violations,
                "deny",
                "s3_missing_public_access_block",
                "aws_s3_bucket",
                "S3 bucket exists but no aws_s3_bucket_public_access_block was found in the plan.",
                "Add aws_s3_bucket_public_access_block with all public access block settings true.",
            )

    for change in changes:
        if is_deleted(change):
            continue

        if change.get("type") == "aws_s3_bucket_public_access_block":
            address = change.get("address", "unknown")
            values = after(change)
            required_true = [
                "block_public_acls",
                "block_public_policy",
                "ignore_public_acls",
                "restrict_public_buckets",
            ]
            bad = [k for k in required_true if values.get(k) is not True]
            if bad:
                add_violation(
                    violations,
                    "deny",
                    "s3_public_access_block_not_strict",
                    address,
                    f"S3 public access block settings are not all true: {', '.join(bad)}.",
                    "Set block_public_acls, block_public_policy, ignore_public_acls, and restrict_public_buckets to true.",
                )

    if s3_rules.get("require_encryption", True) and "aws_s3_bucket" in all_types:
        if "aws_s3_bucket_server_side_encryption_configuration" not in all_types:
            add_violation(
                violations,
                "deny",
                "s3_missing_encryption",
                "aws_s3_bucket",
                "S3 bucket exists but no server-side encryption configuration was found.",
                "Add aws_s3_bucket_server_side_encryption_configuration.",
            )


def check_cloudfront(violations: List[Dict[str, str]], changes: List[Dict[str, Any]], rules: Dict[str, Any]) -> None:
    cf_rules = rules.get("cloudfront", {})

    for change in changes:
        if is_deleted(change):
            continue

        if change.get("type") != "aws_cloudfront_distribution":
            continue

        address = change.get("address", "unknown")
        values = after(change)

        if cf_rules.get("require_https_redirect", True):
            behaviors = []
            default_behavior = values.get("default_cache_behavior")
            if isinstance(default_behavior, list):
                behaviors.extend(default_behavior)
            elif isinstance(default_behavior, dict):
                behaviors.append(default_behavior)

            for b in values.get("ordered_cache_behavior", []) or []:
                if isinstance(b, dict):
                    behaviors.append(b)

            for idx, behavior in enumerate(behaviors):
                policy = behavior.get("viewer_protocol_policy")
                if policy not in ("redirect-to-https", "https-only"):
                    add_violation(
                        violations,
                        "deny",
                        "cloudfront_no_https_redirect",
                        address,
                        f"CloudFront cache behavior #{idx} does not enforce HTTPS. viewer_protocol_policy={policy}",
                        'Set viewer_protocol_policy = "redirect-to-https" or "https-only".',
                    )

        if cf_rules.get("require_oac_for_s3_origin", True):
            for origin in values.get("origin", []) or []:
                domain = origin.get("domain_name", "")
                origin_id = origin.get("origin_id", "unknown-origin")
                looks_like_s3 = ".s3." in domain or domain.endswith(".amazonaws.com") and "s3" in domain

                if looks_like_s3 and not origin.get("origin_access_control_id"):
                    add_violation(
                        violations,
                        "deny",
                        "cloudfront_s3_without_oac",
                        f"{address}.origin[{origin_id}]",
                        f"S3 origin {origin_id} does not have origin_access_control_id.",
                        "Attach aws_cloudfront_origin_access_control to private S3 origins.",
                    )


def write_markdown_report(path: Path, violations: List[Dict[str, str]]) -> None:
    denies = [v for v in violations if v["severity"] == "deny"]
    warnings = [v for v in violations if v["severity"] == "warn"]

    lines = [
        "# Terraform Plan Policy Report",
        "",
        f"Status: {'FAIL' if denies else 'PASS'}",
        f"Denies: {len(denies)}",
        f"Warnings: {len(warnings)}",
        "",
    ]

    if violations:
        lines.append("## Findings")
        lines.append("")
        for i, v in enumerate(violations, start=1):
            lines.extend(
                [
                    f"### {i}. {v['severity'].upper()} — {v['rule']}",
                    "",
                    f"- Resource: `{v['address']}`",
                    f"- Message: {v['message']}",
                    f"- Fix: {v['fix']}",
                    "",
                ]
            )
    else:
        lines.append("No policy violations found.")
        lines.append("")

    path.write_text("\n".join(lines))


def main() -> int:
    parser = argparse.ArgumentParser(description="Terraform plan JSON policy checker")
    parser.add_argument("--plan-json", required=True, help="Path to terraform show -json output")
    parser.add_argument("--rules", required=True, help="Path to iac-policy-rules.yml")
    parser.add_argument("--report-json", required=True, help="Output JSON report path")
    parser.add_argument("--report-md", required=True, help="Output Markdown report path")
    parser.add_argument("--region", default=os.environ.get("AWS_REGION", os.environ.get("AWS_DEFAULT_REGION", "ap-south-1")))
    args = parser.parse_args()

    plan = load_json(Path(args.plan_json))
    rules = load_yaml(Path(args.rules))

    violations: List[Dict[str, str]] = []
    changes = resource_changes(plan)
    resources = planned_resources(plan)

    check_region(violations, rules, args.region)
    check_security_groups(violations, changes, rules)
    check_required_tags(violations, changes, rules)
    check_ec2_imdsv2(violations, changes, rules)
    check_s3_controls(violations, resources, changes, rules)
    check_cloudfront(violations, changes, rules)

    report = {
        "status": "fail" if any(v["severity"] == "deny" for v in violations) else "pass",
        "denies": [v for v in violations if v["severity"] == "deny"],
        "warnings": [v for v in violations if v["severity"] == "warn"],
        "all_findings": violations,
    }

    Path(args.report_json).write_text(json.dumps(report, indent=2))
    write_markdown_report(Path(args.report_md), violations)

    print(json.dumps(report, indent=2))

    return 1 if report["denies"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
EOF

chmod +x 12-terraform-ansible-iac/policy/terraform_plan_policy_check.py
```

EC2 IMDS can be configured so that `HttpTokens=required`, which enforces IMDSv2-only access. That is why this policy blocks EC2 instances without required IMDSv2. ([AWS Documentation][4])

---

# 9. Create Policy Runner Script

This script creates a plan, exports JSON, and runs the policy checker.

```bash id="runner-script"
cat > 12-terraform-ansible-iac/12.15-policy-checks/scripts/run-terraform-policy-check.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
PLAN_NAME="${PLAN_NAME:-tfplan-policy}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

BASE="12-terraform-ansible-iac"
TF_DIR="$BASE/environments/$ENVIRONMENT"
BACKEND_CONFIG="../../12.3-terraform-state-backend/backend-configs/$ENVIRONMENT.s3.hcl"
REPORT_DIR="$BASE/12.15-policy-checks/reports"
RULES="$BASE/policy/iac-policy-rules.yml"
CHECKER="$BASE/policy/terraform_plan_policy_check.py"

mkdir -p "$REPORT_DIR"

echo "===== Terraform Policy Check ====="
echo "Environment: $ENVIRONMENT"
echo "AWS region: $AWS_REGION"

aws sts get-caller-identity >/dev/null

cd "$TF_DIR"

terraform init -reconfigure -backend-config="$BACKEND_CONFIG"
terraform fmt -check -recursive
terraform validate

terraform plan \
  -var-file=terraform.tfvars.example \
  -out="$PLAN_NAME"

terraform show -json "$PLAN_NAME" > "../../12.15-policy-checks/reports/$ENVIRONMENT-tfplan.json"
terraform show -no-color "$PLAN_NAME" > "../../12.15-policy-checks/reports/$ENVIRONMENT-tfplan.txt"

cd - >/dev/null

python3 "$CHECKER" \
  --plan-json "$REPORT_DIR/$ENVIRONMENT-tfplan.json" \
  --rules "$RULES" \
  --region "$AWS_REGION" \
  --report-json "$REPORT_DIR/$ENVIRONMENT-policy-report.json" \
  --report-md "$REPORT_DIR/$ENVIRONMENT-policy-report.md"

echo
echo "Policy report:"
echo "$REPORT_DIR/$ENVIRONMENT-policy-report.md"
EOF

chmod +x 12-terraform-ansible-iac/12.15-policy-checks/scripts/run-terraform-policy-check.sh
```

Run:

```bash id="run-policy"
cd ~/devops-masterclass

ENVIRONMENT=dev AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/12.15-policy-checks/scripts/run-terraform-policy-check.sh
```

Expected:

```text id="expected"
Policy check should pass or show actionable deny/warn findings.
```

If your dev SG still allows app port `3002` publicly, this policy does **not** block it because the deny list focuses on admin/database ports. If you want to block all public non-HTTP ports later, we can tighten it.

---

# 10. Create Example Bad Terraform Plan Notes

Create examples to train your eye.

````bash id="bad-examples"
cat > 12-terraform-ansible-iac/12.15-policy-checks/examples/bad-policy-scenarios.md <<'EOF'
# Bad IaC Policy Scenarios

## Scenario 1 — Public SSH

Bad:

```hcl
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}
````

Why blocked:

```text
SSH from the internet is high risk.
Use SSM, VPN, bastion, or restricted CIDR.
```

## Scenario 2 — Public database port

Bad:

```hcl
from_port = 5432
to_port   = 5432
cidr_ipv4 = "0.0.0.0/0"
```

Why blocked:

```text
PostgreSQL should not be exposed directly to the internet.
```

## Scenario 3 — EC2 without IMDSv2

Bad:

```hcl
metadata_options {
  http_tokens = "optional"
}
```

Good:

```hcl
metadata_options {
  http_endpoint = "enabled"
  http_tokens   = "required"
}
```

## Scenario 4 — S3 bucket without public access block

Bad:

```hcl
resource "aws_s3_bucket" "assets" {
  bucket = "example"
}
```

Good:

```hcl
resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

## Scenario 5 — CloudFront S3 origin without OAC

Bad:

```hcl
origin {
  domain_name = aws_s3_bucket.assets.bucket_regional_domain_name
  origin_id   = "s3-origin"
}
```

Good:

```hcl
origin {
  domain_name              = aws_s3_bucket.assets.bucket_regional_domain_name
  origin_id                = "s3-origin"
  origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
}
```

EOF

````

---

# 11. Add IAM Access Analyzer Policy Validation

IAM Access Analyzer can validate IAM policies against policy grammar and AWS best-practice checks. This is useful for your Terraform caller policy examples and future IAM changes. :contentReference[oaicite:4]{index=4}

Create script:

```bash id="access-analyzer-script"
cat > 12-terraform-ansible-iac/12.15-policy-checks/scripts/validate-iam-policies-access-analyzer.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== IAM Access Analyzer Policy Validation ====="

POLICY_DIR="${POLICY_DIR:-12-terraform-ansible-iac/12.14-cicd-for-iac/policies}"
REPORT_DIR="${REPORT_DIR:-12-terraform-ansible-iac/12.15-policy-checks/reports}"

mkdir -p "$REPORT_DIR"

for policy in "$POLICY_DIR"/*.json 12-terraform-ansible-iac/12.11-iam-troubleshooting/policies/*.json; do
  [ -f "$policy" ] || continue

  name="$(basename "$policy" .json)"
  echo
  echo "Validating: $policy"

  aws accessanalyzer validate-policy \
    --policy-document "file://$policy" \
    --policy-type IDENTITY_POLICY \
    --output json | tee "$REPORT_DIR/$name-access-analyzer.json"
done

echo
echo "IAM policy validation completed."
EOF

chmod +x 12-terraform-ansible-iac/12.15-policy-checks/scripts/validate-iam-policies-access-analyzer.sh
````

Run:

```bash id="run-access-analyzer"
./12-terraform-ansible-iac/12.15-policy-checks/scripts/validate-iam-policies-access-analyzer.sh
```

Note:

```text id="access-analyzer-note"
Access Analyzer validates IAM policy documents.
It does not replace Terraform plan checks.
```

---

# 12. Optional OPA/Rego Example

Create an OPA policy example.

```bash id="opa-example"
mkdir -p 12-terraform-ansible-iac/12.15-policy-checks/examples/opa

cat > 12-terraform-ansible-iac/12.15-policy-checks/examples/opa/terraform.rego <<'EOF'
package terraform.security

deny[msg] {
  rc := input.resource_changes[_]
  rc.type == "aws_vpc_security_group_ingress_rule"
  not rc.change.actions == ["delete"]

  after := rc.change.after
  after.cidr_ipv4 == "0.0.0.0/0"
  after.from_port <= 22
  after.to_port >= 22

  msg := sprintf("%s allows public SSH from 0.0.0.0/0", [rc.address])
}

deny[msg] {
  rc := input.resource_changes[_]
  rc.type == "aws_instance"
  not rc.change.actions == ["delete"]

  after := rc.change.after
  metadata := after.metadata_options[0]
  metadata.http_tokens != "required"

  msg := sprintf("%s does not require IMDSv2", [rc.address])
}
EOF

cat > 12-terraform-ansible-iac/12.15-policy-checks/examples/opa/run-opa-example.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PLAN_JSON="${PLAN_JSON:-../../reports/dev-tfplan.json}"

opa eval \
  --data terraform.rego \
  --input "$PLAN_JSON" \
  "data.terraform.security.deny"
EOF

chmod +x 12-terraform-ansible-iac/12.15-policy-checks/examples/opa/run-opa-example.sh
```

Usage if you install OPA:

```bash id="opa-run"
cd 12-terraform-ansible-iac/12.15-policy-checks/examples/opa

PLAN_JSON=../../reports/dev-tfplan.json \
./run-opa-example.sh
```

---

# 13. Optional Checkov and Trivy Commands

Install/use only when you want scanner coverage.

```bash id="checkov"
python3 -m pip install --user checkov

checkov \
  -d 12-terraform-ansible-iac \
  --framework terraform \
  --output cli \
  --output json \
  --output-file-path console,12-terraform-ansible-iac/12.15-policy-checks/reports/checkov-report.json
```

Optional Trivy config scan:

```bash id="trivy"
trivy config \
  --format table \
  12-terraform-ansible-iac
```

Use these as **additional scanners**, not replacements for your custom plan policy.

---

# 14. Create Policy Report Summary Script

```bash id="summary-script"
cat > 12-terraform-ansible-iac/12.15-policy-checks/scripts/policy-report-summary.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
REPORT="12-terraform-ansible-iac/12.15-policy-checks/reports/$ENVIRONMENT-policy-report.json"

echo "===== Policy Report Summary ====="
echo "Environment: $ENVIRONMENT"

test -f "$REPORT" || {
  echo "Missing report: $REPORT"
  exit 1
}

jq '{status, deny_count: (.denies | length), warning_count: (.warnings | length)}' "$REPORT"

echo
echo "Deny findings:"
jq -r '.denies[]? | "- \(.rule) | \(.address) | \(.message)"' "$REPORT"

echo
echo "Warning findings:"
jq -r '.warnings[]? | "- \(.rule) | \(.address) | \(.message)"' "$REPORT"
EOF

chmod +x 12-terraform-ansible-iac/12.15-policy-checks/scripts/policy-report-summary.sh
```

Run:

```bash id="run-summary"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.15-policy-checks/scripts/policy-report-summary.sh
```

---

# 15. Integrate Policy Gate into CI Scripts

Update `terraform-ci-plan.sh` so CI runs policy after plan JSON.

```bash id="update-ci-plan"
cat > 12-terraform-ansible-iac/ci/scripts/terraform-ci-plan.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
PLAN_NAME="${PLAN_NAME:-tfplan}"
AWS_REGION="${AWS_REGION:-ap-south-1}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

BASE="12-terraform-ansible-iac"
TF_DIR="$BASE/environments/$ENVIRONMENT"
BACKEND_CONFIG="../../12.3-terraform-state-backend/backend-configs/$ENVIRONMENT.s3.hcl"
REPORT_DIR="$BASE/12.14-cicd-for-iac/reports"
POLICY_REPORT_DIR="$BASE/12.15-policy-checks/reports"
RULES="$BASE/policy/iac-policy-rules.yml"
CHECKER="$BASE/policy/terraform_plan_policy_check.py"

mkdir -p "$REPORT_DIR" "$POLICY_REPORT_DIR"

echo "===== Terraform CI Plan ====="
echo "Environment: $ENVIRONMENT"
echo "AWS region: $AWS_REGION"

aws sts get-caller-identity

cd "$TF_DIR"

terraform init -reconfigure -backend-config="$BACKEND_CONFIG"
terraform fmt -check -recursive
terraform validate

terraform plan \
  -var-file=terraform.tfvars.example \
  -out="$PLAN_NAME"

terraform show -no-color "$PLAN_NAME" > "../../12.14-cicd-for-iac/reports/$ENVIRONMENT-plan.txt"
terraform show -json "$PLAN_NAME" > "../../12.14-cicd-for-iac/reports/$ENVIRONMENT-plan.json"

cd - >/dev/null

echo
echo "Running policy checks..."
python3 "$CHECKER" \
  --plan-json "$REPORT_DIR/$ENVIRONMENT-plan.json" \
  --rules "$RULES" \
  --region "$AWS_REGION" \
  --report-json "$POLICY_REPORT_DIR/$ENVIRONMENT-policy-report.json" \
  --report-md "$POLICY_REPORT_DIR/$ENVIRONMENT-policy-report.md"

echo "Plan file: $TF_DIR/$PLAN_NAME"
echo "Plan text: $REPORT_DIR/$ENVIRONMENT-plan.txt"
echo "Plan JSON: $REPORT_DIR/$ENVIRONMENT-plan.json"
echo "Policy report: $POLICY_REPORT_DIR/$ENVIRONMENT-policy-report.md"
EOF

chmod +x 12-terraform-ansible-iac/ci/scripts/terraform-ci-plan.sh
```

Now PR checks and apply workflow plans will fail before apply if the policy gate returns deny findings.

---

# 16. Update GitHub Artifact Uploads for Policy Reports

Patch the workflow artifact paths.

```bash id="patch-workflows"
python3 - <<'PY'
from pathlib import Path

for wf in [
    ".github/workflows/iac-pr-check.yml",
    ".github/workflows/iac-apply-dev.yml",
    ".github/workflows/iac-drift-detect.yml",
]:
    p = Path(wf)
    if not p.exists():
        continue
    s = p.read_text()
    if "12-terraform-ansible-iac/12.15-policy-checks/reports/**" not in s:
        s = s.replace(
            "12-terraform-ansible-iac/12.14-cicd-for-iac/reports/**",
            "12-terraform-ansible-iac/12.14-cicd-for-iac/reports/**\n            12-terraform-ansible-iac/12.15-policy-checks/reports/**",
        )
        s = s.replace(
            "12-terraform-ansible-iac/12.14-cicd-for-iac/reports/dev-plan.json",
            "12-terraform-ansible-iac/12.14-cicd-for-iac/reports/dev-plan.json\n            12-terraform-ansible-iac/12.15-policy-checks/reports/dev-policy-report.json\n            12-terraform-ansible-iac/12.15-policy-checks/reports/dev-policy-report.md",
        )
    p.write_text(s)
PY
```

---

# 17. Create Policy Gate Runbook

````bash id="policy-runbook"
cat > 12-terraform-ansible-iac/12.15-policy-checks/runbooks/policy-gate-runbook.md <<'EOF'
# IaC Policy Gate Runbook

## 1. Generate Terraform plan

```bash
cd 12-terraform-ansible-iac/environments/dev

terraform plan \
  -var-file=terraform.tfvars.example \
  -out=tfplan
````

## 2. Export JSON

```bash id="json-export"
terraform show -json tfplan > ../../12.15-policy-checks/reports/dev-tfplan.json
```

## 3. Run policy checker

```bash id="policy-run"
python3 ../../policy/terraform_plan_policy_check.py \
  --plan-json ../../12.15-policy-checks/reports/dev-tfplan.json \
  --rules ../../policy/iac-policy-rules.yml \
  --region ap-south-1 \
  --report-json ../../12.15-policy-checks/reports/dev-policy-report.json \
  --report-md ../../12.15-policy-checks/reports/dev-policy-report.md
```

## 4. Interpret result

```text
PASS:
  no deny findings

FAIL:
  one or more deny findings
```

Warnings should be reviewed but do not block by default.

## 5. Fix violation

Each finding includes:

* severity
* rule
* resource address
* message
* fix

## 6. Re-run

```bash id="rerun"
ENVIRONMENT=dev AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/12.15-policy-checks/scripts/run-terraform-policy-check.sh
```

## Golden rule

Do not bypass policy checks just to make the pipeline green. Fix or formally approve an exception.
EOF

````

---

# 18. Create Policy Exception Runbook

```bash id="exception-runbook"
cat > 12-terraform-ansible-iac/12.15-policy-checks/runbooks/policy-exception-runbook.md <<'EOF'
# Policy Exception Runbook

## When to allow exceptions

Only when:

- the risk is understood
- there is a business reason
- there is an owner
- there is an expiry date
- compensating control exists
- approval is recorded

## Exception record should include

```text
Rule:
Resource:
Environment:
Owner:
Reason:
Risk:
Compensating control:
Expiry:
Approval ticket:
````

## Bad exception

```text
Need to deploy fast.
```

## Good exception

```text id="ctqjqv"
Rule:
  missing_required_tags

Resource:
  module.example.aws_resource.demo

Reason:
  Provider does not support tags for this resource type.

Expiry:
  none, documented provider limitation.

Approval:
  SEC-1234
```

## Never approve casually

* public SSH
* public database ports
* public S3 bucket for private assets
* EC2 without IMDSv2 in production
* unapproved region
* wildcard iam:PassRole

## Golden rule

Exceptions are temporary risk decisions, not hidden bypasses.
EOF

````

---

# 19. Create Policy Troubleshooting Runbook

```bash id="troubleshoot-runbook"
cat > 12-terraform-ansible-iac/12.15-policy-checks/runbooks/policy-troubleshooting-runbook.md <<'EOF'
# IaC Policy Troubleshooting Runbook

## Error: PyYAML missing

Fix:

```bash
python3 -m pip install --user pyyaml
````

## Error: plan JSON missing

Fix:

```bash id="plan-json-fix"
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
```

## Error: policy fails on tags even though provider default_tags exists

Check:

```bash id="tag-debug"
jq '.resource_changes[] | {address, type, after: .change.after.tags_all}' tfplan.json
```

Some resources do not support tags or expose them differently.

## Error: S3 encryption policy false positive

Check:

```bash id="s3-debug"
jq '.planned_values.root_module.child_modules[]?.resources[]? | select(.type|startswith("aws_s3")) | {address,type}' tfplan.json
```

Confirm encryption resource exists in planned values.

## Error: CloudFront OAC false positive

Check:

```bash id="cf-debug"
jq '.resource_changes[] | select(.type=="aws_cloudfront_distribution") | .change.after.origin' tfplan.json
```

Confirm S3 origin has origin_access_control_id.

## Error: policy blocks dev experiment

Options:

1. Fix the risky config.
2. Change the rule only if team standard changed.
3. Create a documented exception process.

## Golden rule

A false positive should improve the policy, not train the team to ignore policy reports.
EOF

````

---

# 20. Create Production Policy Checklist

```bash id="prod-runbook"
cat > 12-terraform-ansible-iac/12.15-policy-checks/runbooks/production-policy-checklist.md <<'EOF'
# Production IaC Policy Checklist

## Network

- deny public SSH
- deny public RDP
- deny public database ports
- require ALB-to-EC2 security group references
- restrict admin access to SSM/VPN/bastion

## EC2

- require IMDSv2
- require encrypted root volume
- require tags
- restrict instance types if needed
- deny public IP in private workloads

## S3

- require public access block
- require encryption
- require versioning for critical buckets
- deny public bucket policies
- deny public ACLs
- require OAC for CloudFront private origins

## CloudFront

- require HTTPS viewer policy
- require OAC for S3 origins
- require approved price class if cost-sensitive
- require WAF for production internet apps where required
- require logging where required

## IAM

- deny wildcard iam:PassRole
- deny AdministratorAccess for pipeline roles
- validate policies with IAM Access Analyzer
- require service-specific trust policies

## CI/CD

- run policy before apply
- upload policy reports
- block deny findings
- review warning findings
- require environment approval

## Golden rule

Production policy should prevent the most expensive, exposed, and irreversible mistakes.
EOF
````

---

# 21. Create Lesson Validation Script

```bash id="validation-script"
cat > 12-terraform-ansible-iac/12.15-policy-checks/scripts/validate-lesson-12-15.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 12.15 ====="

BASE="12-terraform-ansible-iac"
LESSON="$BASE/12.15-policy-checks"

test -d "$LESSON/notes"
test -d "$LESSON/scripts"
test -d "$LESSON/runbooks"
test -d "$LESSON/reports"
test -d "$LESSON/policies"
test -d "$LESSON/examples"
test -d "$BASE/policy"

test -f "$LESSON/notes/policy-as-code-mental-model.md"
test -f "$LESSON/notes/never-confuse-policy-points.md"
test -f "$BASE/policy/iac-policy-rules.yml"
test -x "$BASE/policy/terraform_plan_policy_check.py"

test -x "$LESSON/scripts/run-terraform-policy-check.sh"
test -x "$LESSON/scripts/validate-iam-policies-access-analyzer.sh"
test -x "$LESSON/scripts/policy-report-summary.sh"

test -f "$LESSON/examples/bad-policy-scenarios.md"
test -f "$LESSON/examples/opa/terraform.rego"
test -f "$LESSON/examples/opa/run-opa-example.sh"

test -f "$LESSON/runbooks/policy-gate-runbook.md"
test -f "$LESSON/runbooks/policy-exception-runbook.md"
test -f "$LESSON/runbooks/policy-troubleshooting-runbook.md"
test -f "$LESSON/runbooks/production-policy-checklist.md"

python3 --version >/dev/null
python3 -m py_compile "$BASE/policy/terraform_plan_policy_check.py"

python3 - <<'PY'
import yaml
from pathlib import Path
yaml.safe_load(Path("12-terraform-ansible-iac/policy/iac-policy-rules.yml").read_text())
PY

terraform version >/dev/null

echo
echo "Checking shell script syntax..."
bash -n "$LESSON/scripts/run-terraform-policy-check.sh"
bash -n "$LESSON/scripts/validate-iam-policies-access-analyzer.sh"
bash -n "$LESSON/scripts/policy-report-summary.sh"

echo
echo "Lesson 12.15 validation passed."
echo
echo "Optional live check:"
echo "ENVIRONMENT=dev AWS_REGION=ap-south-1 $LESSON/scripts/run-terraform-policy-check.sh"
EOF

chmod +x 12-terraform-ansible-iac/12.15-policy-checks/scripts/validate-lesson-12-15.sh
```

Run:

```bash id="run-validation"
./12-terraform-ansible-iac/12.15-policy-checks/scripts/validate-lesson-12-15.sh
```

---

# 22. Create Cleanup Script

```bash id="cleanup-script"
cat > 12-terraform-ansible-iac/12.15-policy-checks/scripts/cleanup-lesson-12-15-local.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 12.15 Local Artifacts ====="

BASE="12-terraform-ansible-iac"

find "$BASE" -name "tfplan" -delete
find "$BASE" -name "tfplan-*" -delete
find "$BASE" -name "*.tfplan" -delete

rm -f "$BASE/12.15-policy-checks/reports/"*.json
rm -f "$BASE/12.15-policy-checks/reports/"*.md
rm -f "$BASE/12.15-policy-checks/reports/"*.txt

echo "Local policy artifacts cleaned."
echo "AWS resources were not destroyed."
EOF

chmod +x 12-terraform-ansible-iac/12.15-policy-checks/scripts/cleanup-lesson-12-15-local.sh
```

Run:

```bash id="run-cleanup"
./12-terraform-ansible-iac/12.15-policy-checks/scripts/cleanup-lesson-12-15-local.sh
```

---

# 23. Local Simulation

Run this before committing:

```bash id="local-sim"
cd ~/devops-masterclass

python3 -m pip install --user pyyaml

./12-terraform-ansible-iac/12.15-policy-checks/scripts/validate-lesson-12-15.sh

ENVIRONMENT=dev AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/12.15-policy-checks/scripts/run-terraform-policy-check.sh

ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.15-policy-checks/scripts/policy-report-summary.sh
```

If it fails, open the Markdown report:

```bash id="open-report"
cat 12-terraform-ansible-iac/12.15-policy-checks/reports/dev-policy-report.md
```

---

# 24. Common Policy Failures and Fixes

## Failure 1 — Public SSH

Example finding:

```text id="public-ssh"
Public ingress to sensitive port 22 from 0.0.0.0/0 is not allowed.
```

Fix:

```text id="public-ssh-fix"
Remove SSH rule.
Use SSM.
Or restrict to your VPN/office CIDR.
```

---

## Failure 2 — EC2 without IMDSv2

Fix in `aws_instance` or launch template:

```hcl id="imdsv2-fix"
metadata_options {
  http_endpoint = "enabled"
  http_tokens   = "required"
}
```

---

## Failure 3 — S3 public access block missing

Fix:

```hcl id="s3-pab-fix"
resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

S3 Block Public Access provides account- and bucket-level controls to block public ACLs and public bucket policies. AWS also notes that new S3 buckets automatically have Block Public Access enabled and ACLs disabled by default, but Terraform modules should still express the desired controls explicitly for auditability. ([Amazon Web Services, Inc.][5])

---

## Failure 4 — CloudFront S3 origin without OAC

Fix:

```hcl id="oac-fix"
resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${var.name_prefix}-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

origin {
  domain_name              = var.s3_origin_domain_name
  origin_id                = local.s3_origin_id
  origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
}
```

For private S3 origins, CloudFront OAC plus a bucket policy scoped to the CloudFront distribution ARN is the current recommended pattern. ([AWS Documentation][6])

---

## Failure 5 — Missing Required Tags

Fix:

```hcl id="tag-fix"
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
```

Or add tags directly to resources that do not inherit provider default tags.

---

# 25. Cost Safety

This lesson itself creates local files and policy reports.

The live policy runner runs Terraform plan and does **not** create resources unless you separately apply.

Clean local artifacts:

```bash id="cost-clean"
./12-terraform-ansible-iac/12.15-policy-checks/scripts/cleanup-lesson-12-15-local.sh
```

Destroy previous dev AWS stack if stopping:

```bash id="destroy"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/cleanup-lesson-12-10-dev.sh
```

---

# 26. Revision Checkpoint

You should now be able to answer:

```text id="revision"
What is Policy-as-Code?
Why should policy checks run before apply?
What is Terraform plan JSON?
How do you generate Terraform plan JSON?
Why scan plan JSON instead of only .tf files?
What is a deny finding?
What is a warning finding?
Why block public SSH?
Why block public database ports?
Why require IMDSv2?
Why require S3 public access block?
Why require S3 encryption?
Why require CloudFront HTTPS viewer redirect?
Why require OAC for private S3 origins?
What does OPA do?
How do Checkov and Trivy fit into IaC scanning?
What does IAM Access Analyzer validate?
How do you integrate policy gates into CI/CD?
How should policy exceptions be handled?
```

Strong interview answer:

```text id="interview-answer"
I built policy-as-code guardrails for Terraform by converting saved Terraform plans into JSON with `terraform show -json` and scanning the resolved plan before apply. This lets me evaluate actual planned infrastructure after variables, modules, count, and for_each are resolved, rather than only scanning static HCL.

My policy gate blocks high-risk changes such as public SSH, public database ports, EC2 instances without IMDSv2, S3 buckets without public access block or encryption, CloudFront S3 origins without OAC, CloudFront behaviors that do not redirect to HTTPS, and unapproved AWS regions. It also warns on missing required tags and produces JSON and Markdown reports for CI artifacts.

I integrate this into CI/CD so pull requests and apply workflows fail before apply if deny-level findings exist. I also use IAM Access Analyzer for IAM policy validation and understand how OPA/Rego, Checkov, and Trivy can provide additional policy coverage. For exceptions, I require owner, reason, risk, compensating control, expiry, and approval rather than silent bypasses.
```

Resume bullet:

```text id="resume-bullet"
Built a Terraform policy-as-code gate using plan JSON analysis, custom Python policy checks, deny/warn severity handling, public SSH and database-port blocking, approved-region enforcement, required tag checks, S3 encryption and public-access-block validation, EC2 IMDSv2 enforcement, CloudFront HTTPS and OAC checks, IAM Access Analyzer validation, OPA/Rego examples, Checkov/Trivy integration notes, CI/CD policy-gate wiring, JSON/Markdown reports, exception governance, and production policy runbooks.
```

---

# 27. Commit Lesson 12.15

Clean:

```bash id="clean-before-commit"
cd ~/devops-masterclass

./12-terraform-ansible-iac/12.15-policy-checks/scripts/cleanup-lesson-12-15-local.sh
```

Validate:

```bash id="validate-before-commit"
./12-terraform-ansible-iac/12.15-policy-checks/scripts/validate-lesson-12-15.sh
```

Optional live policy check:

```bash id="live-policy"
ENVIRONMENT=dev AWS_REGION=ap-south-1 \
./12-terraform-ansible-iac/12.15-policy-checks/scripts/run-terraform-policy-check.sh
```

Review:

```bash id="review"
git status

find 12-terraform-ansible-iac/12.15-policy-checks -maxdepth 4 -type f | sort
find 12-terraform-ansible-iac/policy -maxdepth 3 -type f | sort
find 12-terraform-ansible-iac/ci/scripts -maxdepth 1 -type f | sort
```

Commit:

```bash id="commit"
git add .github 12-terraform-ansible-iac

git commit -m "feat: add policy checks for Terraform IaC"

git push
```

---

# 28. Next Lesson

```text id="next-lesson"
12.16 — Final IaC Capstone
```

We will combine everything:

```text id="next-topics"
production-style repo review
Terraform modules review
remote state review
VPC/EC2/ALB/S3/CloudFront/IAM stack
Ansible inventory and roles
Terraform + Ansible orchestration
CI/CD pipeline
policy checks
drift detection
cost cleanup
documentation
architecture diagram
runbook set
resume project summary
final interview explanation
```

[1]: https://developer.hashicorp.com/terraform/cli/commands/show?utm_source=chatgpt.com "terraform show command reference | Terraform | HashiCorp Developer"
[2]: https://www.checkov.io/?utm_source=chatgpt.com "checkov"
[3]: https://www.openpolicyagent.org/docs?utm_source=chatgpt.com "Open Policy Agent (OPA) | Open Policy Agent"
[4]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-options.html?utm_source=chatgpt.com "Configure the Instance Metadata Service options - Amazon Elastic Compute Cloud"
[5]: https://aws.amazon.com/s3/features/block-public-access//?utm_source=chatgpt.com "Amazon S3 Block Public Access - AWS"
[6]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-policy-validation.html?utm_source=chatgpt.com "Validate policies with IAM Access Analyzer - AWS Identity and Access Management"

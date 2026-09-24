# Lesson 9.7 — IaC Security Scanning with Checkov and Trivy Config

# Terraform Security Scanning, AWS S3 Public Access, Security Groups, IAM Wildcards, CloudFront/S3 Patterns, GitHub Actions, Jenkins, GitLab CI, and Production IaC Gates

In Lesson 9.6, we secured Dockerfiles and container builds.

Now we secure **Infrastructure as Code**.

IaC security scanning asks:

```text id="nfhl42"
Will this Terraform, Kubernetes, CloudFormation, or Helm config create insecure infrastructure?
```

Examples:

```text id="u1z2kq"
public S3 bucket
0.0.0.0/0 SSH security group
wildcard IAM policy
unencrypted storage
open database port
missing CloudFront HTTPS redirect
missing access logging
over-permissive bucket policy
```

Checkov scans infrastructure-as-code for misconfigurations across Terraform, CloudFormation, Kubernetes, Helm, ARM templates, and other formats. Trivy config scanning can scan IaC files such as Terraform, Kubernetes manifests, CloudFormation, Dockerfiles, and Helm charts for misconfigurations. ([Checkov][1])

---

# 1. IaC Security Mental Model

Terraform makes infrastructure repeatable.

That is powerful.

But it also means mistakes are repeatable.

Bad Terraform can repeatedly create:

```text id="3uqtrl"
public storage
open network access
weak IAM
unencrypted data stores
missing logs
unsafe load balancer rules
insecure Kubernetes workloads
```

Professional rule:

```text id="7h3i6j"
IaC scanning prevents insecure infrastructure before terraform apply.
```

Old workflow:

```text id="lyen7w"
write Terraform
terraform apply
security review later
```

DevSecOps workflow:

```text id="xq4xws"
write Terraform
terraform fmt
terraform validate
Checkov scan
Trivy config scan
review findings
fix or document exception
then terraform plan/apply
```

---

# 2. What IaC Scanning Catches

Common AWS examples:

```text id="3rp53a"
S3:
  public bucket ACL
  public bucket policy
  missing encryption
  missing versioning
  missing block public access

Security Groups:
  SSH open to 0.0.0.0/0
  database ports open to internet
  overly broad ingress/egress

IAM:
  Action = "*"
  Resource = "*"
  admin policies
  missing least privilege

CloudFront:
  HTTP allowed instead of HTTPS redirect
  weak TLS policy
  missing logging
  origin access misconfiguration

EC2/EBS/RDS:
  unencrypted volumes
  public instances
  public database
  missing backups

Kubernetes:
  privileged containers
  hostPath mounts
  root containers
  missing resource limits
```

Checkov supports scanning Terraform files and Terraform plan JSON; its plan scanning docs note that plan evaluation can provide more context, but plan files can contain dynamically injected sensitive values, so plan scanning should run in a secure CI/CD setting. ([Checkov][2])

---

# 3. Checkov vs Trivy Config

Use both for learning.

| Tool         | Best Use                                                                                          |
| ------------ | ------------------------------------------------------------------------------------------------- |
| Checkov      | Deep IaC policy scanning, Terraform-focused checks, broad cloud policy coverage                   |
| Trivy config | Unified scanner for IaC misconfigurations alongside image, filesystem, secret, and SBOM workflows |

Checkov’s Terraform scanning supports scanning Terraform directories and downloading external modules if needed. Trivy’s Terraform scanning is available through `trivy config <path>`. ([Checkov][3])

Professional rule:

```text id="o049hr"
Use one primary IaC scanner and one secondary scanner for defense-in-depth.
```

---

# 4. Create Lesson Directory

Run:

```bash id="5sx4al"
cd ~/devops-masterclass/09-devsecops-security-gates

mkdir -p iac-security-scanning/{checkov,trivy,scripts,reports,github-actions,jenkins,gitlab,runbooks,examples,notes,policies}
```

Check:

```bash id="frcp9i"
tree -L 2 iac-security-scanning
```

---

# 5. IaC Security Policy

Create:

```bash id="al9qkt"
nano iac-security-scanning/policies/iac-security-policy.json
```

Paste:

```json id="vafo1a"
{
  "service_name": "demo-node-api",
  "policy_version": "1.0",
  "tools": ["checkov", "trivy config"],
  "environments": {
    "pull_request": {
      "checkov": "warn",
      "trivy_config": "warn",
      "public_s3": "fail",
      "open_ssh": "fail",
      "iam_wildcard": "warn"
    },
    "main": {
      "checkov": "fail",
      "trivy_config": "fail_on_high_or_critical",
      "public_s3": "fail",
      "open_ssh": "fail",
      "iam_wildcard": "fail"
    },
    "production": {
      "checkov": "fail",
      "trivy_config": "fail_on_high_or_critical",
      "public_s3": "fail",
      "open_ssh": "fail",
      "iam_wildcard": "fail",
      "unencrypted_storage": "fail",
      "public_database": "fail",
      "exception_required": true
    }
  },
  "forbidden_patterns": {
    "security_group_cidr": ["0.0.0.0/0 for port 22", "0.0.0.0/0 for database ports"],
    "iam": ["Action:*", "Resource:*"],
    "s3": ["public ACL", "public bucket policy", "missing block public access"],
    "cloudfront": ["viewer_protocol_policy allow-all"]
  },
  "exception_policy": {
    "allowed": true,
    "requires_owner": true,
    "requires_reason": true,
    "requires_expiry": true,
    "requires_compensating_control": true,
    "max_days": 30
  },
  "required_reports": [
    "checkov_json",
    "trivy_config_json",
    "iac_summary_json"
  ]
}
```

---

# 6. IaC Security Notes

Create:

```bash id="zijh2f"
nano iac-security-scanning/notes/iac-security-mental-model.md
```

Paste:

```markdown id="7oxj4r"
# IaC Security Scanning Mental Model

## Goal

Detect insecure infrastructure definitions before deployment.

## Why It Matters

Infrastructure as Code can create risky cloud infrastructure repeatedly and quickly.

Common issues:

- public storage
- open security groups
- wildcard IAM policies
- missing encryption
- missing logging
- public databases
- weak TLS settings
- insecure Kubernetes workloads

## Tools

| Tool | Purpose |
|---|---|
| Checkov | IaC policy scanning |
| Trivy config | IaC misconfiguration scanning |

## Production Rule

Never run `terraform apply` for production infrastructure unless IaC security checks have passed or documented exceptions exist.

## Gate Strategy

Pull request:

- fail critical custom patterns
- warn scanner findings

Main:

- fail scanner findings

Production:

- fail high/critical findings
- require exception for accepted risk
```

---

# 7. Install Checkov

Recommended local install:

```bash id="uivnlm"
python3 -m pip install --user pipx
python3 -m pipx ensurepath
pipx install checkov
checkov --version
```

Alternative:

```bash id="pkh6by"
python3 -m pip install --user checkov
checkov --version
```

Checkov’s CLI docs show directory scanning with `checkov -d .`, and its command reference documents output formats and file output options. ([Checkov][4])

---

# 8. Install Trivy

If already installed from previous lessons, skip.

```bash id="vznh6b"
trivy --version
```

If not installed:

```bash id="z1f1sz"
sudo apt-get update
sudo apt-get install -y wget apt-transport-https gnupg lsb-release

wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list

sudo apt-get update
sudo apt-get install -y trivy
```

---

# 9. Create Insecure Terraform Example

Create a safe test fixture that intentionally contains bad infrastructure patterns.

```bash id="ssr046"
mkdir -p iac-security-scanning/examples/terraform-insecure

nano iac-security-scanning/examples/terraform-insecure/main.tf
```

Paste:

```hcl id="g607dn"
terraform {
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_s3_bucket" "public_bucket" {
  bucket = "example-public-bucket-devsecops-learning"
}

resource "aws_s3_bucket_public_access_block" "bad_public_access" {
  bucket = aws_s3_bucket.public_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_security_group" "bad_sg" {
  name        = "bad-open-sg"
  description = "Bad SG for scanner testing"

  ingress {
    description = "SSH from anywhere - intentionally insecure"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MongoDB from anywhere - intentionally insecure"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_policy" "bad_admin_policy" {
  name = "bad-admin-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudfront_distribution" "bad_distribution" {
  enabled = true

  origin {
    domain_name = "example-public-bucket-devsecops-learning.s3.amazonaws.com"
    origin_id   = "s3-origin"
  }

  default_cache_behavior {
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "allow-all"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
```

This fixture should trigger findings such as:

```text id="y7eq0e"
public S3 access block disabled
SSH open to internet
MongoDB open to internet
IAM wildcard admin pattern
CloudFront allows HTTP
```

---

# 10. Create Secure Terraform Example

Create:

```bash id="rf7hok"
mkdir -p iac-security-scanning/examples/terraform-secure

nano iac-security-scanning/examples/terraform-secure/main.tf
```

Paste:

```hcl id="7ux2aj"
terraform {
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_s3_bucket" "private_bucket" {
  bucket = "example-private-bucket-devsecops-learning"
}

resource "aws_s3_bucket_public_access_block" "secure_public_access" {
  bucket = aws_s3_bucket.private_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.private_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_security_group" "web_sg" {
  name        = "secure-web-sg"
  description = "Example web SG"

  ingress {
    description = "HTTP only for learning example"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.0/24"]
  }

  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_policy" "limited_ecr_policy" {
  name = "limited-ecr-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:DescribeImages"
        ]
        Resource = "arn:aws:ecr:ap-south-1:123456789012:repository/demo-node-api"
      }
    ]
  })
}
```

---

# 11. Basic Checkov Scan

Run:

```bash id="ebacok"
cd ~/devops-masterclass/09-devsecops-security-gates

checkov -d iac-security-scanning/examples/terraform-insecure --framework terraform
```

JSON output:

```bash id="fgdq83"
checkov \
  -d iac-security-scanning/examples/terraform-insecure \
  --framework terraform \
  -o json \
  --soft-fail \
  > iac-security-scanning/reports/checkov-insecure.json
```

View failed checks:

```bash id="0g6zzn"
cat iac-security-scanning/reports/checkov-insecure.json \
  | jq '[.. | objects | select(has("check_result")) | select(.check_result.result == "FAILED")] | length'
```

Checkov’s GitHub Actions docs describe integrating Checkov to apply policies to Terraform code during pull request review and build processes. ([Checkov][5])

---

# 12. Basic Trivy Config Scan

Run:

```bash id="3ri5dv"
trivy config iac-security-scanning/examples/terraform-insecure
```

JSON:

```bash id="k90odj"
trivy config \
  --format json \
  --output iac-security-scanning/reports/trivy-config-insecure.json \
  iac-security-scanning/examples/terraform-insecure
```

Fail on high/critical:

```bash id="3ig3p2"
trivy config \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  iac-security-scanning/examples/terraform-insecure
```

Trivy’s misconfiguration scanner has built-in checks for IaC files including Terraform, Docker, Kubernetes, and CloudFormation. ([Trivy][6])

---

# 13. Checkov Gate Script

Create:

```bash id="vayg59"
nano iac-security-scanning/scripts/checkov-iac-gate.sh
```

Paste:

```bash id="agfouq"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
MODULE_DIR="${MODULE_DIR:-$ROOT_DIR/09-devsecops-security-gates}"
TARGET_DIR="${TARGET_DIR:-$ROOT_DIR}"
REPORT_DIR="${REPORT_DIR:-$MODULE_DIR/iac-security-scanning/reports}"

ENVIRONMENT="${ENVIRONMENT:-pull_request}"
FRAMEWORK="${FRAMEWORK:-terraform}"
FAIL_ON_CHECKOV="${FAIL_ON_CHECKOV:-false}"
DOWNLOAD_EXTERNAL_MODULES="${DOWNLOAD_EXTERNAL_MODULES:-false}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
SAFE_TARGET="$(echo "$TARGET_DIR" | tr '/:@' '____')"
REPORT_FILE="$REPORT_DIR/checkov-$ENVIRONMENT-$SAFE_TARGET-$TIMESTAMP.json"
SUMMARY_FILE="$REPORT_DIR/checkov-summary-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== Checkov IaC Gate ====="
echo "Target: $TARGET_DIR"
echo "Framework: $FRAMEWORK"
echo "Environment: $ENVIRONMENT"
echo "Fail on Checkov: $FAIL_ON_CHECKOV"

if ! command -v checkov >/dev/null 2>&1; then
  echo "ERROR: checkov is required" >&2
  exit 1
fi

CMD=(
  checkov
  -d "$TARGET_DIR"
  --framework "$FRAMEWORK"
  -o json
  --soft-fail
)

if [ "$DOWNLOAD_EXTERNAL_MODULES" = "true" ]; then
  CMD+=(--download-external-modules true)
fi

set +e
"${CMD[@]}" > "$REPORT_FILE"
CHECKOV_EXIT=$?
set -e

FAILED_CHECKS="$(jq '[.. | objects | select(has("check_result")) | select(.check_result.result == "FAILED")] | length' "$REPORT_FILE")"
PASSED_CHECKS="$(jq '[.. | objects | select(has("check_result")) | select(.check_result.result == "PASSED")] | length' "$REPORT_FILE")"
SKIPPED_CHECKS="$(jq '[.. | objects | select(has("check_result")) | select(.check_result.result == "SKIPPED")] | length' "$REPORT_FILE")"

DECISION="passed"

case "$ENVIRONMENT" in
  production|main)
    if [ "$FAILED_CHECKS" -gt 0 ]; then
      DECISION="failed"
    fi
    ;;
  pull_request|dev)
    if [ "$FAIL_ON_CHECKOV" = "true" ] && [ "$FAILED_CHECKS" -gt 0 ]; then
      DECISION="failed"
    fi
    ;;
esac

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "iac_security",
  "tool": "checkov",
  "environment": "$ENVIRONMENT",
  "framework": "$FRAMEWORK",
  "target_dir": "$TARGET_DIR",
  "checkov_exit_code": $CHECKOV_EXIT,
  "checks": {
    "failed": $FAILED_CHECKS,
    "passed": $PASSED_CHECKS,
    "skipped": $SKIPPED_CHECKS
  },
  "decision": "$DECISION",
  "report_file": "$REPORT_FILE",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .

echo
echo "Checkov report: $REPORT_FILE"
echo "Checkov summary: $SUMMARY_FILE"

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: Checkov IaC gate failed" >&2
  exit 1
fi

echo "Checkov IaC gate passed or reported only."
```

Make executable:

```bash id="u9bhjy"
chmod +x iac-security-scanning/scripts/checkov-iac-gate.sh
```

Run against insecure fixture:

```bash id="1s8cvq"
TARGET_DIR=iac-security-scanning/examples/terraform-insecure \
ENVIRONMENT=pull_request \
FAIL_ON_CHECKOV=false \
./iac-security-scanning/scripts/checkov-iac-gate.sh
```

Run strict main mode:

```bash id="aftsqz"
TARGET_DIR=iac-security-scanning/examples/terraform-insecure \
ENVIRONMENT=main \
FAIL_ON_CHECKOV=true \
./iac-security-scanning/scripts/checkov-iac-gate.sh || true
```

---

# 14. Trivy Config Gate Script

Create:

```bash id="82egyu"
nano iac-security-scanning/scripts/trivy-config-gate.sh
```

Paste:

```bash id="is1zex"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
MODULE_DIR="${MODULE_DIR:-$ROOT_DIR/09-devsecops-security-gates}"
TARGET_DIR="${TARGET_DIR:-$ROOT_DIR}"
REPORT_DIR="${REPORT_DIR:-$MODULE_DIR/iac-security-scanning/reports}"

ENVIRONMENT="${ENVIRONMENT:-pull_request}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
FAIL_ON_TRIVY="${FAIL_ON_TRIVY:-false}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
SAFE_TARGET="$(echo "$TARGET_DIR" | tr '/:@' '____')"
REPORT_FILE="$REPORT_DIR/trivy-config-$ENVIRONMENT-$SAFE_TARGET-$TIMESTAMP.json"
SUMMARY_FILE="$REPORT_DIR/trivy-config-summary-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== Trivy Config Gate ====="
echo "Target: $TARGET_DIR"
echo "Severity: $SEVERITY"
echo "Environment: $ENVIRONMENT"
echo "Fail on Trivy: $FAIL_ON_TRIVY"

if ! command -v trivy >/dev/null 2>&1; then
  echo "ERROR: trivy is required" >&2
  exit 1
fi

if [ "$FAIL_ON_TRIVY" = "true" ]; then
  EXIT_CODE=1
else
  EXIT_CODE=0
fi

set +e
trivy config \
  --severity "$SEVERITY" \
  --exit-code "$EXIT_CODE" \
  --format json \
  --output "$REPORT_FILE" \
  "$TARGET_DIR"
TRIVY_EXIT=$?
set -e

CRITICAL="$(jq '[.Results[]?.Misconfigurations[]? | select(.Severity == "CRITICAL")] | length' "$REPORT_FILE")"
HIGH="$(jq '[.Results[]?.Misconfigurations[]? | select(.Severity == "HIGH")] | length' "$REPORT_FILE")"
MEDIUM="$(jq '[.Results[]?.Misconfigurations[]? | select(.Severity == "MEDIUM")] | length' "$REPORT_FILE")"
LOW="$(jq '[.Results[]?.Misconfigurations[]? | select(.Severity == "LOW")] | length' "$REPORT_FILE")"
TOTAL="$(jq '[.Results[]?.Misconfigurations[]?] | length' "$REPORT_FILE")"

DECISION="passed"

case "$ENVIRONMENT" in
  production|main)
    if [ "$HIGH" -gt 0 ] || [ "$CRITICAL" -gt 0 ]; then
      DECISION="failed"
    fi
    ;;
  pull_request|dev)
    if [ "$FAIL_ON_TRIVY" = "true" ] && [ "$CRITICAL" -gt 0 ]; then
      DECISION="failed"
    fi
    ;;
esac

if [ "$FAIL_ON_TRIVY" = "true" ] && [ "$TRIVY_EXIT" -ne 0 ]; then
  DECISION="failed"
fi

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "iac_security",
  "tool": "trivy config",
  "environment": "$ENVIRONMENT",
  "severity_filter": "$SEVERITY",
  "target_dir": "$TARGET_DIR",
  "trivy_exit_code": $TRIVY_EXIT,
  "misconfigurations": {
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

echo
echo "Trivy config report: $REPORT_FILE"
echo "Trivy config summary: $SUMMARY_FILE"

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: Trivy config gate failed" >&2
  exit 1
fi

echo "Trivy config gate passed or reported only."
```

Make executable:

```bash id="8lie1z"
chmod +x iac-security-scanning/scripts/trivy-config-gate.sh
```

Run:

```bash id="9ccwct"
TARGET_DIR=iac-security-scanning/examples/terraform-insecure \
ENVIRONMENT=pull_request \
FAIL_ON_TRIVY=false \
./iac-security-scanning/scripts/trivy-config-gate.sh
```

---

# 15. Custom Terraform Critical Pattern Gate

Scanner output can vary. For your project, we will add hard custom checks for critical patterns.

Create:

```bash id="s25ofq"
nano iac-security-scanning/scripts/custom-terraform-critical-gate.sh
```

Paste:

```bash id="o4z38q"
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${TARGET_DIR:-.}"
REPORT_DIR="${REPORT_DIR:-iac-security-scanning/reports}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"
FAIL_ON_FINDINGS="${FAIL_ON_FINDINGS:-true}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/custom-terraform-critical-$ENVIRONMENT-$TIMESTAMP.txt"
SUMMARY_FILE="$REPORT_DIR/custom-terraform-critical-summary-$ENVIRONMENT-$TIMESTAMP.json"

echo "===== Custom Terraform Critical Gate ====="
echo "Target: $TARGET_DIR"
echo "Environment: $ENVIRONMENT"

FAILED=0
FINDINGS=0

: > "$REPORT_FILE"

record_fail() {
  echo "FAIL: $*" | tee -a "$REPORT_FILE"
  FAILED=1
  FINDINGS=$((FINDINGS + 1))
}

record_pass() {
  echo "PASS: $*" | tee -a "$REPORT_FILE"
}

# Check 1: SSH open to the world
if grep -RInE 'from_port[[:space:]]*=[[:space:]]*22|to_port[[:space:]]*=[[:space:]]*22|cidr_blocks[[:space:]]*=[[:space:]]*\["0\.0\.0\.0/0"\]' "$TARGET_DIR" \
  --include='*.tf' >/tmp/tf-open-ssh.$$ 2>/dev/null; then

  if grep -RInE 'from_port[[:space:]]*=[[:space:]]*22|to_port[[:space:]]*=[[:space:]]*22' "$TARGET_DIR" --include='*.tf' >/dev/null 2>&1 &&
     grep -RInE 'cidr_blocks[[:space:]]*=[[:space:]]*\["0\.0\.0\.0/0"\]' "$TARGET_DIR" --include='*.tf' >/dev/null 2>&1; then
    record_fail "possible SSH open to 0.0.0.0/0 found"
  fi
else
  record_pass "no obvious SSH open-to-world pattern found"
fi
rm -f /tmp/tf-open-ssh.$$ || true

# Check 2: Database ports open to the world
if grep -RInE 'from_port[[:space:]]*=[[:space:]]*(3306|5432|27017|6379)|to_port[[:space:]]*=[[:space:]]*(3306|5432|27017|6379)' "$TARGET_DIR" \
  --include='*.tf' >/dev/null 2>&1 &&
   grep -RInE 'cidr_blocks[[:space:]]*=[[:space:]]*\["0\.0\.0\.0/0"\]' "$TARGET_DIR" --include='*.tf' >/dev/null 2>&1; then
  record_fail "possible database port open to 0.0.0.0/0 found"
else
  record_pass "no obvious database open-to-world pattern found"
fi

# Check 3: IAM wildcard action/resource
if grep -RInE 'Action[[:space:]]*=[[:space:]]*"\*"|Resource[[:space:]]*=[[:space:]]*"\*"' "$TARGET_DIR" \
  --include='*.tf' >/dev/null 2>&1; then
  record_fail "IAM wildcard Action or Resource found"
else
  record_pass "no obvious IAM wildcard Action/Resource found"
fi

# Check 4: S3 public access block disabled
if grep -RInE 'block_public_acls[[:space:]]*=[[:space:]]*false|block_public_policy[[:space:]]*=[[:space:]]*false|ignore_public_acls[[:space:]]*=[[:space:]]*false|restrict_public_buckets[[:space:]]*=[[:space:]]*false' "$TARGET_DIR" \
  --include='*.tf' >/dev/null 2>&1; then
  record_fail "S3 public access block disabled found"
else
  record_pass "no S3 public access block disabled pattern found"
fi

# Check 5: CloudFront allow-all HTTP
if grep -RInE 'viewer_protocol_policy[[:space:]]*=[[:space:]]*"allow-all"' "$TARGET_DIR" \
  --include='*.tf' >/dev/null 2>&1; then
  record_fail "CloudFront viewer_protocol_policy allow-all found"
else
  record_pass "no CloudFront allow-all viewer protocol policy found"
fi

DECISION="passed"
if [ "$FAILED" -ne 0 ] && [ "$FAIL_ON_FINDINGS" = "true" ]; then
  DECISION="failed"
elif [ "$FINDINGS" -gt 0 ]; then
  DECISION="warning"
fi

cat > "$SUMMARY_FILE" <<EOF
{
  "service_name": "demo-node-api",
  "gate": "iac_custom_critical_patterns",
  "tool": "custom",
  "environment": "$ENVIRONMENT",
  "target_dir": "$TARGET_DIR",
  "findings": $FINDINGS,
  "decision": "$DECISION",
  "text_report": "$REPORT_FILE",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$SUMMARY_FILE" | jq .

if [ "$DECISION" = "failed" ]; then
  echo "ERROR: custom Terraform critical gate failed" >&2
  exit 1
fi

echo "Custom Terraform critical gate completed with decision: $DECISION"
```

Make executable:

```bash id="55v0vj"
chmod +x iac-security-scanning/scripts/custom-terraform-critical-gate.sh
```

Run:

```bash id="izl6za"
TARGET_DIR=iac-security-scanning/examples/terraform-insecure \
ENVIRONMENT=pull_request \
FAIL_ON_FINDINGS=true \
./iac-security-scanning/scripts/custom-terraform-critical-gate.sh || true
```

---

# 16. Combined IaC Security Gate

Create:

```bash id="x2xwjg"
nano iac-security-scanning/scripts/iac-security-gate.sh
```

Paste:

```bash id="8cy96o"
#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="${MODULE_DIR:-$HOME/devops-masterclass/09-devsecops-security-gates}"
TARGET_DIR="${TARGET_DIR:-$HOME/devops-masterclass}"
ENVIRONMENT="${ENVIRONMENT:-pull_request}"

RUN_CHECKOV="${RUN_CHECKOV:-true}"
RUN_TRIVY="${RUN_TRIVY:-true}"
RUN_CUSTOM="${RUN_CUSTOM:-true}"

FAIL_ON_CHECKOV="${FAIL_ON_CHECKOV:-false}"
FAIL_ON_TRIVY="${FAIL_ON_TRIVY:-false}"
FAIL_ON_CUSTOM="${FAIL_ON_CUSTOM:-true}"

echo "===== Combined IaC Security Gate ====="
echo "Target: $TARGET_DIR"
echo "Environment: $ENVIRONMENT"

FAILED=0

cd "$MODULE_DIR"

if [ "$RUN_CUSTOM" = "true" ]; then
  echo
  echo "===== Custom Critical Terraform Checks ====="
  TARGET_DIR="$TARGET_DIR" \
  ENVIRONMENT="$ENVIRONMENT" \
  FAIL_ON_FINDINGS="$FAIL_ON_CUSTOM" \
  REPORT_DIR="$MODULE_DIR/iac-security-scanning/reports" \
  ./iac-security-scanning/scripts/custom-terraform-critical-gate.sh || FAILED=1
fi

if [ "$RUN_CHECKOV" = "true" ]; then
  echo
  echo "===== Checkov ====="
  TARGET_DIR="$TARGET_DIR" \
  ENVIRONMENT="$ENVIRONMENT" \
  FAIL_ON_CHECKOV="$FAIL_ON_CHECKOV" \
  ./iac-security-scanning/scripts/checkov-iac-gate.sh || FAILED=1
fi

if [ "$RUN_TRIVY" = "true" ]; then
  echo
  echo "===== Trivy Config ====="
  TARGET_DIR="$TARGET_DIR" \
  ENVIRONMENT="$ENVIRONMENT" \
  FAIL_ON_TRIVY="$FAIL_ON_TRIVY" \
  SEVERITY="HIGH,CRITICAL" \
  ./iac-security-scanning/scripts/trivy-config-gate.sh || FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
  echo "ERROR: IaC security gate failed" >&2
  exit 1
fi

echo "IaC security gate passed or reported only."
```

Make executable:

```bash id="nogsqd"
chmod +x iac-security-scanning/scripts/iac-security-gate.sh
```

Run report mode:

```bash id="9p55xu"
TARGET_DIR=iac-security-scanning/examples/terraform-insecure \
ENVIRONMENT=pull_request \
FAIL_ON_CHECKOV=false \
FAIL_ON_TRIVY=false \
FAIL_ON_CUSTOM=false \
./iac-security-scanning/scripts/iac-security-gate.sh
```

Run strict mode:

```bash id="35spro"
TARGET_DIR=iac-security-scanning/examples/terraform-insecure \
ENVIRONMENT=main \
FAIL_ON_CHECKOV=true \
FAIL_ON_TRIVY=true \
FAIL_ON_CUSTOM=true \
./iac-security-scanning/scripts/iac-security-gate.sh || true
```

---

# 17. IaC Scan Summary Script

Create:

```bash id="9o0ba5"
nano iac-security-scanning/scripts/iac-security-summary.sh
```

Paste:

```bash id="u9f6ad"
#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-iac-security-scanning/reports}"

echo "===== IaC Security Scan Summary ====="
echo "Report dir: $REPORT_DIR"

find "$REPORT_DIR" -type f -name '*summary*.json' | sort | tail -n 15 | while read -r file; do
  echo
  echo "## $file"
  jq . "$file"
done

echo
echo "Recent raw reports:"
find "$REPORT_DIR" -type f \( -name 'checkov-*.json' -o -name 'trivy-config-*.json' -o -name 'custom-terraform-critical-*.txt' \) \
  | sort \
  | tail -n 15
```

Make executable:

```bash id="i1sq9q"
chmod +x iac-security-scanning/scripts/iac-security-summary.sh
```

Run:

```bash id="zevf2w"
./iac-security-scanning/scripts/iac-security-summary.sh
```

---

# 18. IaC Exception Template

Create:

```bash id="0vy0lp"
nano iac-security-scanning/examples/iac-security-exception-template.json
```

Paste:

```json id="5ehb7j"
{
  "exception_id": "IAC-EX-YYYY-NNN",
  "finding_id": "",
  "tool": "",
  "resource": "",
  "file": "",
  "line": "",
  "severity": "",
  "affected_environment": "",
  "reason": "",
  "risk_owner": "",
  "approved_by": "",
  "created_at": "",
  "expires_on": "",
  "compensating_controls": [],
  "fix_plan": "",
  "status": "requested"
}
```

Professional rule:

```text id="i6h7gy"
IaC exceptions must expire because cloud exposure risk changes over time.
```

---

# 19. Terraform Security Fix Examples

Create:

```bash id="30vwyy"
nano iac-security-scanning/notes/terraform-security-fix-examples.md
```

Paste:

````markdown id="hm2cfj"
# Terraform Security Fix Examples

## S3 Public Access

Bad:

```hcl
block_public_acls       = false
block_public_policy     = false
ignore_public_acls      = false
restrict_public_buckets = false
````

Good:

```hcl
block_public_acls       = true
block_public_policy     = true
ignore_public_acls      = true
restrict_public_buckets = true
```

## Security Group SSH

Bad:

```hcl
from_port   = 22
to_port     = 22
cidr_blocks = ["0.0.0.0/0"]
```

Better:

```hcl
from_port   = 22
to_port     = 22
cidr_blocks = ["203.0.113.10/32"]
```

Best:

* use SSM Session Manager
* avoid SSH exposure entirely

## IAM Wildcard

Bad:

```hcl
Action   = "*"
Resource = "*"
```

Better:

```hcl
Action = [
  "ecr:BatchGetImage",
  "ecr:DescribeImages"
]
Resource = "arn:aws:ecr:ap-south-1:123456789012:repository/demo-node-api"
```

## CloudFront HTTP

Bad:

```hcl
viewer_protocol_policy = "allow-all"
```

Better:

```hcl
viewer_protocol_policy = "redirect-to-https"
```

````

---

# 20. GitHub Actions IaC Security Workflow

Create:

```bash id="txsaqd"
nano iac-security-scanning/github-actions/iac-security-scanning.yml
````

Paste:

```yaml id="8o7c9c"
name: IaC Security Scanning

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main
  workflow_dispatch:
    inputs:
      target_dir:
        description: "IaC directory to scan"
        required: true
        default: "09-devsecops-security-gates/iac-security-scanning/examples/terraform-insecure"
        type: string

permissions:
  contents: read
  security-events: write

env:
  MODULE9_DIR: 09-devsecops-security-gates

jobs:
  iac-security:
    name: Checkov and Trivy Config
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Resolve target
        id: target
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            TARGET="${{ inputs.target_dir }}"
          else
            TARGET="."
          fi

          echo "target_dir=$TARGET" >> "$GITHUB_OUTPUT"

      - name: Install Checkov
        run: |
          python3 -m pip install --user pipx
          python3 -m pipx ensurepath
          ~/.local/bin/pipx install checkov
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"
          checkov --version

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

      - name: Run IaC security gate
        run: |
          cd "$MODULE9_DIR"

          if [ "${{ github.event_name }}" = "pull_request" ]; then
            ENVIRONMENT="pull_request"
            FAIL_CHECKOV="false"
            FAIL_TRIVY="false"
            FAIL_CUSTOM="true"
          else
            ENVIRONMENT="main"
            FAIL_CHECKOV="true"
            FAIL_TRIVY="true"
            FAIL_CUSTOM="true"
          fi

          TARGET_DIR="$GITHUB_WORKSPACE/${{ steps.target.outputs.target_dir }}" \
          ENVIRONMENT="$ENVIRONMENT" \
          FAIL_ON_CHECKOV="$FAIL_CHECKOV" \
          FAIL_ON_TRIVY="$FAIL_TRIVY" \
          FAIL_ON_CUSTOM="$FAIL_CUSTOM" \
          ./iac-security-scanning/scripts/iac-security-gate.sh

      - name: Upload IaC security reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: iac-security-reports
          path: 09-devsecops-security-gates/iac-security-scanning/reports/
```

Copy:

```bash id="10dd5u"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/iac-security-scanning/github-actions/iac-security-scanning.yml \
   .github/workflows/iac-security-scanning.yml
```

The Checkov GitHub Action also exists and runs Checkov against IaC, open-source packages, container images, and CI/CD configurations; using the CLI here keeps the workflow portable across GitHub Actions, Jenkins, and GitLab CI. ([GitHub][7])

---

# 21. Jenkins IaC Security Pipeline

Create:

```bash id="r1m0ch"
nano iac-security-scanning/jenkins/Jenkinsfile.iac-security-scanning
```

Paste:

```groovy id="q1m1kn"
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
  }

  parameters {
    string(name: 'TARGET_DIR', defaultValue: '09-devsecops-security-gates/iac-security-scanning/examples/terraform-insecure', description: 'IaC target directory')
    choice(name: 'ENVIRONMENT', choices: ['pull_request', 'main', 'production'], description: 'Gate environment')
    booleanParam(name: 'FAIL_ON_CHECKOV', defaultValue: false, description: 'Fail on Checkov findings?')
    booleanParam(name: 'FAIL_ON_TRIVY', defaultValue: false, description: 'Fail on Trivy findings?')
    booleanParam(name: 'FAIL_ON_CUSTOM', defaultValue: true, description: 'Fail on custom critical patterns?')
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

          if ! command -v checkov >/dev/null 2>&1; then
            python3 -m pip install --user pipx
            python3 -m pipx ensurepath || true
            ~/.local/bin/pipx install checkov || true
          fi

          if ! command -v trivy >/dev/null 2>&1; then
            echo "ERROR: trivy is required on Jenkins agent"
            exit 1
          fi

          checkov --version
          trivy --version
        '''
      }
    }

    stage('IaC Security Gate') {
      steps {
        dir("${MODULE9_DIR}") {
          sh '''
            export PATH="$HOME/.local/bin:$PATH"

            TARGET_DIR="$WORKSPACE/${TARGET_DIR}" \
            ENVIRONMENT="${ENVIRONMENT}" \
            FAIL_ON_CHECKOV="${FAIL_ON_CHECKOV}" \
            FAIL_ON_TRIVY="${FAIL_ON_TRIVY}" \
            FAIL_ON_CUSTOM="${FAIL_ON_CUSTOM}" \
            ./iac-security-scanning/scripts/iac-security-gate.sh
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '09-devsecops-security-gates/iac-security-scanning/reports/**/*', allowEmptyArchive: true
    }

    success {
      echo 'IaC security gate passed.'
    }

    failure {
      echo 'IaC security gate failed. Review archived reports.'
    }
  }
}
```

Jenkins job script path:

```text id="yvpwz6"
09-devsecops-security-gates/iac-security-scanning/jenkins/Jenkinsfile.iac-security-scanning
```

---

# 22. GitLab CI IaC Security Pipeline

Create:

```bash id="vt6vz2"
nano iac-security-scanning/gitlab/.gitlab-ci.iac-security-scanning.yml
```

Paste:

```yaml id="ytq0jk"
stages:
  - iac_security

variables:
  MODULE9_DIR: "09-devsecops-security-gates"
  TARGET_DIR: "09-devsecops-security-gates/iac-security-scanning/examples/terraform-insecure"

iac_security_custom:
  stage: iac_security
  image: python:3.12-slim
  before_script:
    - apt-get update
    - apt-get install -y curl wget gnupg jq
    - pip install --no-cache-dir checkov
    - wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor > /usr/share/keyrings/trivy.gpg
    - echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" > /etc/apt/sources.list.d/trivy.list
    - apt-get update
    - apt-get install -y trivy
    - checkov --version
    - trivy --version
  script:
    - cd "$MODULE9_DIR"
    - |
      if [ "${CI_COMMIT_BRANCH:-}" = "main" ]; then
        ENVIRONMENT="main"
        FAIL_CHECKOV="true"
        FAIL_TRIVY="true"
      else
        ENVIRONMENT="pull_request"
        FAIL_CHECKOV="false"
        FAIL_TRIVY="false"
      fi

      TARGET_DIR="$CI_PROJECT_DIR/$TARGET_DIR" \
      ENVIRONMENT="$ENVIRONMENT" \
      FAIL_ON_CHECKOV="$FAIL_CHECKOV" \
      FAIL_ON_TRIVY="$FAIL_TRIVY" \
      FAIL_ON_CUSTOM=true \
      ./iac-security-scanning/scripts/iac-security-gate.sh
  artifacts:
    when: always
    expire_in: 30 days
    paths:
      - 09-devsecops-security-gates/iac-security-scanning/reports/
```

Checkov’s GitLab CI integration docs describe using Checkov in GitLab CI to apply policies to Terraform code during merge request review and build processes. ([Checkov][8])

---

# 23. IaC Security Runbook

Create:

```bash id="c7o9f5"
nano iac-security-scanning/runbooks/iac-security-runbook.md
```

Paste:

````markdown id="f0017k"
# IaC Security Runbook

## Goal

Scan Terraform and IaC before deployment.

## Local Scan

Checkov:

```bash
checkov -d terraform-dir --framework terraform
````

Trivy config:

```bash id="zehsrd"
trivy config terraform-dir
```

Combined gate:

```bash id="k27wqn"
cd 09-devsecops-security-gates

TARGET_DIR=iac-security-scanning/examples/terraform-insecure \
ENVIRONMENT=main \
FAIL_ON_CHECKOV=true \
FAIL_ON_TRIVY=true \
FAIL_ON_CUSTOM=true \
./iac-security-scanning/scripts/iac-security-gate.sh
```

## Triage Steps

1. Identify resource.
2. Identify file and line.
3. Confirm environment.
4. Decide if finding is true positive.
5. Fix Terraform.
6. Rerun scanners.
7. Document exception only if required.

## Production Rules

* no public S3 unless explicitly approved
* no SSH from 0.0.0.0/0
* no database from 0.0.0.0/0
* no wildcard IAM admin policy
* encryption should be enabled
* logging should be enabled where required
* CloudFront should redirect HTTP to HTTPS

````

---

# 24. AWS Security Group Runbook

Create:

```bash id="efd01w"
nano iac-security-scanning/runbooks/security-group-triage.md
````

Paste:

````markdown id="hc4r6k"
# Security Group Triage

## High-Risk Patterns

- SSH 22 open to 0.0.0.0/0
- RDP 3389 open to 0.0.0.0/0
- database ports open to 0.0.0.0/0
- Redis 6379 open to public
- MongoDB 27017 open to public
- Elasticsearch 9200 open to public

## Better Patterns

- restrict to specific CIDR
- use VPN/bastion/SSM
- use private subnets
- use load balancer security groups
- use security group references instead of public CIDRs

## Example Fix

Bad:

```hcl
cidr_blocks = ["0.0.0.0/0"]
from_port   = 22
````

Better:

```hcl
cidr_blocks = ["203.0.113.10/32"]
from_port   = 22
```

Best:

```text
Use AWS SSM Session Manager and remove public SSH.
```

````

---

# 25. IAM Policy Triage Runbook

Create:

```bash id="diqqkc"
nano iac-security-scanning/runbooks/iam-policy-triage.md
````

Paste:

````markdown id="uit8ur"
# IAM Policy Triage

## High-Risk Patterns

```hcl
Action   = "*"
Resource = "*"
````

## Questions

* Which service actions are actually required?
* Can Resource be narrowed?
* Can conditions be added?
* Is this build, deploy, or runtime access?
* Is this temporary break-glass access?

## Better Example

```hcl
Action = [
  "ecr:BatchGetImage",
  "ecr:DescribeImages"
]

Resource = "arn:aws:ecr:ap-south-1:123456789012:repository/demo-node-api"
```

## Production Rule

Avoid wildcard admin policies in CI/CD and runtime roles.

````

---

# 26. S3 and CloudFront Triage Runbook

Create:

```bash id="dkz0eq"
nano iac-security-scanning/runbooks/s3-cloudfront-triage.md
````

Paste:

````markdown id="d17fyf"
# S3 and CloudFront Triage

## S3 Public Access

Bad:

```hcl
block_public_policy = false
restrict_public_buckets = false
````

Better:

```hcl
block_public_acls       = true
block_public_policy     = true
ignore_public_acls      = true
restrict_public_buckets = true
```

## S3 Encryption

Use server-side encryption unless there is a documented reason not to.

## CloudFront Viewer Protocol

Bad:

```hcl
viewer_protocol_policy = "allow-all"
```

Better:

```hcl
viewer_protocol_policy = "redirect-to-https"
```

## Production Pattern

* private S3 origin
* CloudFront origin access control/origin access identity
* redirect HTTP to HTTPS
* TLS policy configured
* access logs where required
* least-privilege bucket policy

````

---

# 27. Validation Script

Create:

```bash id="2g36wb"
nano iac-security-scanning/scripts/validate-iac-security-lesson.sh
````

Paste:

```bash id="fw7yse"
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-iac-security-scanning}"

echo "===== Validate IaC Security Lesson ====="

test -f "$BASE_DIR/policies/iac-security-policy.json"
test -f "$BASE_DIR/notes/iac-security-mental-model.md"
test -f "$BASE_DIR/notes/terraform-security-fix-examples.md"
test -f "$BASE_DIR/examples/terraform-insecure/main.tf"
test -f "$BASE_DIR/examples/terraform-secure/main.tf"
test -x "$BASE_DIR/scripts/checkov-iac-gate.sh"
test -x "$BASE_DIR/scripts/trivy-config-gate.sh"
test -x "$BASE_DIR/scripts/custom-terraform-critical-gate.sh"
test -x "$BASE_DIR/scripts/iac-security-gate.sh"
test -x "$BASE_DIR/scripts/iac-security-summary.sh"
test -f "$BASE_DIR/examples/iac-security-exception-template.json"
test -f "$BASE_DIR/github-actions/iac-security-scanning.yml"
test -f "$BASE_DIR/jenkins/Jenkinsfile.iac-security-scanning"
test -f "$BASE_DIR/gitlab/.gitlab-ci.iac-security-scanning.yml"
test -f "$BASE_DIR/runbooks/iac-security-runbook.md"
test -f "$BASE_DIR/runbooks/security-group-triage.md"
test -f "$BASE_DIR/runbooks/iam-policy-triage.md"
test -f "$BASE_DIR/runbooks/s3-cloudfront-triage.md"

echo "IaC security scanning lesson validated."
```

Make executable:

```bash id="iq5pqa"
chmod +x iac-security-scanning/scripts/validate-iac-security-lesson.sh
```

Run:

```bash id="xy85jx"
./iac-security-scanning/scripts/validate-iac-security-lesson.sh
```

---

# 28. Update Makefile

Open:

```bash id="2zpebl"
cd ~/devops-masterclass/09-devsecops-security-gates

nano Makefile
```

Add:

```Makefile id="plra5b"
.PHONY: iac-validate iac-scan iac-scan-strict iac-summary checkov-scan trivy-config-scan iac-custom-scan

iac-validate:
	./iac-security-scanning/scripts/validate-iac-security-lesson.sh

iac-scan:
	TARGET_DIR="$${TARGET_DIR:-iac-security-scanning/examples/terraform-insecure}" \
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_CHECKOV="$${FAIL_ON_CHECKOV:-false}" \
	FAIL_ON_TRIVY="$${FAIL_ON_TRIVY:-false}" \
	FAIL_ON_CUSTOM="$${FAIL_ON_CUSTOM:-false}" \
	./iac-security-scanning/scripts/iac-security-gate.sh

iac-scan-strict:
	TARGET_DIR="$${TARGET_DIR:-iac-security-scanning/examples/terraform-insecure}" \
	ENVIRONMENT=main \
	FAIL_ON_CHECKOV=true \
	FAIL_ON_TRIVY=true \
	FAIL_ON_CUSTOM=true \
	./iac-security-scanning/scripts/iac-security-gate.sh

checkov-scan:
	TARGET_DIR="$${TARGET_DIR:-iac-security-scanning/examples/terraform-insecure}" \
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_CHECKOV="$${FAIL_ON_CHECKOV:-false}" \
	./iac-security-scanning/scripts/checkov-iac-gate.sh

trivy-config-scan:
	TARGET_DIR="$${TARGET_DIR:-iac-security-scanning/examples/terraform-insecure}" \
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_TRIVY="$${FAIL_ON_TRIVY:-false}" \
	./iac-security-scanning/scripts/trivy-config-gate.sh

iac-custom-scan:
	TARGET_DIR="$${TARGET_DIR:-iac-security-scanning/examples/terraform-insecure}" \
	ENVIRONMENT="$${ENVIRONMENT:-pull_request}" \
	FAIL_ON_FINDINGS="$${FAIL_ON_FINDINGS:-true}" \
	./iac-security-scanning/scripts/custom-terraform-critical-gate.sh

iac-summary:
	./iac-security-scanning/scripts/iac-security-summary.sh
```

Run:

```bash id="vydk3h"
make iac-validate
make iac-scan
make iac-summary
```

Strict test:

```bash id="elgfbf"
make iac-scan-strict || true
```

---

# 29. Practical Lab

Run:

```bash id="e064cr"
cd ~/devops-masterclass/09-devsecops-security-gates

make iac-validate

TARGET_DIR=iac-security-scanning/examples/terraform-insecure \
ENVIRONMENT=pull_request \
FAIL_ON_CHECKOV=false \
FAIL_ON_TRIVY=false \
FAIL_ON_CUSTOM=false \
make iac-scan

make iac-summary
```

Now scan the secure example:

```bash id="47ya6b"
TARGET_DIR=iac-security-scanning/examples/terraform-secure \
ENVIRONMENT=main \
FAIL_ON_CHECKOV=false \
FAIL_ON_TRIVY=false \
FAIL_ON_CUSTOM=true \
make iac-scan
```

Copy GitHub workflow:

```bash id="twgq9t"
cd ~/devops-masterclass

mkdir -p .github/workflows

cp 09-devsecops-security-gates/iac-security-scanning/github-actions/iac-security-scanning.yml \
   .github/workflows/iac-security-scanning.yml
```

Commit:

```bash id="xnafu2"
git status

git add .github/workflows/iac-security-scanning.yml \
        09-devsecops-security-gates

git commit -m "feat: add IaC security scanning gates"
git push
```

---

# 30. Common IaC Scanning Problems

## Too many findings

Start in report mode:

```bash id="cz2vfk"
FAIL_ON_CHECKOV=false
FAIL_ON_TRIVY=false
```

Then fix critical patterns first:

```text id="errvzr"
public storage
open SSH
open database
wildcard IAM
unencrypted storage
```

## Scanner false positive

Do not immediately skip.

Triage:

```text id="0dtcoo"
is resource really created?
is module value known only at plan time?
does scanner lack context?
would plan scanning help?
is compensating control present?
```

## Terraform modules not scanned correctly

Checkov supports downloading external modules when scanning Terraform, but external module scanning should be done carefully in CI because it can add time and external dependency behavior. ([Checkov][3])

Example:

```bash id="8u0ekl"
checkov -d . --download-external-modules true
```

## Terraform plan scan contains secrets

Plan files can contain dynamically injected sensitive values, so run plan scanning in a secure CI/CD environment and avoid archiving sensitive plan JSON carelessly. ([Checkov][2])

## Custom grep gate is imperfect

Correct.

The custom gate is for critical project-specific patterns.

```text id="8r7xk4"
Checkov/Trivy:
  broad scanner coverage

custom gate:
  hard-block obvious project-specific dangerous patterns
```

Use both.

---

# 31. Interview Explanation

## What is IaC security scanning?

```text id="skl5yi"
IaC security scanning analyzes infrastructure code such as Terraform, Kubernetes, CloudFormation, or Helm before deployment to detect misconfigurations like public storage, open security groups, wildcard IAM, missing encryption, and insecure network exposure.
```

## Why scan Terraform before apply?

```text id="x5qegu"
Terraform can create real cloud resources quickly and repeatedly. Scanning before apply helps catch insecure infrastructure before it reaches the cloud environment.
```

## Why use both Checkov and Trivy config?

```text id="05uxz5"
Checkov provides deep IaC policy scanning, especially for Terraform and cloud misconfiguration checks. Trivy config provides a unified scanner that can scan IaC alongside images, filesystems, secrets, and other security targets. Using both improves coverage and consistency.
```

## What IaC issues would block production?

```text id="au2xzp"
I would block production for public S3 buckets without approval, SSH or database ports open to the internet, wildcard admin IAM policies, public databases, unencrypted storage, weak CloudFront HTTPS behavior, and high or critical scanner findings without an approved exception.
```

## How do you handle false positives?

```text id="4b1n7l"
I triage the finding, confirm whether the resource is actually created, check whether values are resolved only at plan time, document the reason, and use a time-bound exception only when there is an owner, expiry date, and compensating control.
```

## Why is Terraform plan scanning sensitive?

```text id="628q1c"
Terraform plan JSON can include dynamically injected values and potentially sensitive data. Plan scanning can provide better context, but the plan file should be handled securely and not archived publicly.
```

---

# 32. Today’s Core Rules

```text id="hgcqhd"
Scan Terraform before apply.
Use Checkov for IaC policy scanning.
Use Trivy config for unified misconfiguration scanning.
Fail public S3, open SSH, open database ports, and wildcard IAM.
Use custom gates for critical organization-specific patterns.
Run plan scanning only in secure CI/CD contexts.
Do not archive sensitive Terraform plan files carelessly.
Production IaC exceptions need owner, reason, expiry, and compensating control.
Scanner reports must be archived.
Fix infrastructure risk before it becomes cloud risk.
```

---

# Next Lesson

# Lesson 9.8 — SBOM Security and License Policy

We will build:

```text id="qvwzml"
SBOM validation
CycloneDX and SPDX checks
Trivy SBOM scanning
license inventory
license allow/deny policy
npm license reports
production SBOM gate
GitHub Actions SBOM/license workflow
Jenkins SBOM/license pipeline
GitLab CI SBOM/license pipeline
SBOM risk triage
license exception handling
```

[1]: https://www.checkov.io/?utm_source=chatgpt.com "checkov"
[2]: https://www.checkov.io/7.Scan%20Examples/Terraform%20Plan%20Scanning.html?utm_source=chatgpt.com "Terraform Plan Scanning"
[3]: https://www.checkov.io/7.Scan%20Examples/Terraform.html?utm_source=chatgpt.com "Terraform Scanning"
[4]: https://www.checkov.io/2.Basics/CLI%20Command%20Reference.html?utm_source=chatgpt.com "CLI Command Reference"
[5]: https://www.checkov.io/4.Integrations/GitHub%20Actions.html?utm_source=chatgpt.com "GitHub Actions"
[6]: https://trivy.dev/docs/latest/scanner/misconfiguration/?utm_source=chatgpt.com "Misconfiguration Scanning"
[7]: https://github.com/bridgecrewio/checkov-action?utm_source=chatgpt.com "bridgecrewio/checkov-action: This ..."
[8]: https://www.checkov.io/4.Integrations/GitLab%20CI.html?utm_source=chatgpt.com "GitLab CI"

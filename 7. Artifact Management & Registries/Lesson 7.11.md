# Lesson 7.11 — Registry Security and Access Control Deep Dive

# IAM, Push vs Pull Identities, Least Privilege, Repository Policies, Token Scopes, Audit Logs, Break-Glass Access, and Registry Incident Response

In previous lessons, we learned how to use:

```text id="x1k5sa"
GHCR
ECR
Docker Hub
SBOM
provenance
signing
artifact promotion
```

Now we secure the registry itself.

A registry is not just storage.

It is a production control point.

If an attacker can push to your registry, they may be able to replace your application artifact.

If an attacker can pull private images, they may learn your app structure, dependencies, internal package names, or accidentally baked secrets.

So registry access control is a serious DevOps and supply-chain security topic.

---

# 1. Beginner Level — Registry Security Mental Model

A registry stores deployable artifacts.

That means you must control:

```text id="ji2lr8"
who can push images
who can pull images
who can delete images
who can change repository settings
who can change visibility
who can change lifecycle policies
who can create tokens
who can approve production artifacts
```

Bad registry security:

```text id="xibgj8"
everyone can push
servers can push
developers share one token
production uses latest
old images deleted randomly
no audit trail
no scan/signature requirement
```

Good registry security:

```text id="mxf2pw"
CI pushes
servers pull
admins manage settings
tokens are scoped
production uses immutable tags/digests
push access is limited
delete access is rare
audit logs are monitored
rollback images are retained
```

Core rule:

```text id="9gbfql"
Registry access should follow least privilege.
```

---

# 2. Push vs Pull Identities

This is one of the most important production rules.

```text id="8lxq6r"
CI identity:
  push images

runtime identity:
  pull images

admin identity:
  manage repository settings

security identity:
  read scan/audit data
```

Never use one powerful credential everywhere.

Bad:

```text id="3dcxjq"
same token used by:
  developer laptop
  GitHub Actions
  EC2 production server
  Jenkins
  admin scripts
```

Good:

```text id="m61id5"
GitHub Actions role:
  push image

EC2 role:
  pull image

developer token:
  pull or dev push only

admin role:
  repository settings

break-glass role:
  emergency only, audited
```

Professional rule:

```text id="jznt3d"
The identity that deploys should not usually have permission to publish new artifacts.
```

---

# 3. Registry Threat Model

Ask: what can go wrong?

## Threat 1 — Unauthorized push

Attacker pushes:

```text id="qs5s9c"
demo-node-api:0.7.0-a1b2c3d
```

or:

```text id="tq3vyx"
demo-node-api:latest
```

Risk:

```text id="25r2g4"
production pulls malicious image
```

Controls:

```text id="tgephx"
tag immutability
least-privilege push role
signature verification
provenance verification
no latest in production
protected CI workflows
```

---

## Threat 2 — Unauthorized pull

Attacker pulls private image.

Risk:

```text id="1d67tm"
source structure leakage
dependency leakage
internal URLs
possible baked secrets
vulnerability intelligence
```

Controls:

```text id="se88yg"
private registry
pull-only scoped tokens
no secrets in images
image scanning
audit logs
token rotation
```

---

## Threat 3 — Token leakage

A token appears in:

```text id="slxsmy"
GitHub repo
CI logs
server shell history
developer laptop
.env file
Slack message
```

Controls:

```text id="c6b85a"
short-lived credentials
OIDC where possible
least privilege
secret scanning
rotation
revocation
audit review
```

---

## Threat 4 — Deletion of rollback images

Someone deletes previous production image.

Risk:

```text id="7bhbir"
rollback fails during incident
```

Controls:

```text id="kfbun3"
retention policy
delete permission restricted
stable release protection
promotion/deployment records
break-glass process
```

---

# 4. Least Privilege Registry Roles

Create role categories.

```text id="rc2ph1"
registry-admin:
  create/delete repositories
  set policies
  set lifecycle rules
  set visibility
  manage scanning

ci-publisher:
  push images
  read repository metadata
  cannot delete repository

deploy-puller:
  pull images only
  no push
  no delete

security-auditor:
  read images
  read scan findings
  read audit logs

break-glass-admin:
  emergency admin
  temporary
  heavily audited
```

Golden rule:

```text id="8nng9e"
Give each identity only the action it needs, for only the repositories it needs.
```

---

# 5. Amazon ECR Access Control

Amazon ECR uses AWS IAM identity policies and ECR repository policies. AWS notes that users need IAM permissions to push to private repositories, and recommends granting least privilege to a specific repository where possible. ([AWS Documentation][1])

ECR also requires `ecr:GetAuthorizationToken` through an IAM policy before users can authenticate to a registry and push or pull images. ([AWS Documentation][2])

That means ECR access usually has two layers:

```text id="u3atyo"
IAM identity policy:
  what this role/user can do

ECR repository policy:
  resource-based control for specific repository access
```

AWS documents that ECR private repositories can be controlled with both user access policies and repository policies. ([AWS Documentation][3])

---

# 6. ECR Push Policy — CI Publisher

Create a policy for CI push only.

```bash id="zjmw33"
cd ~/devops-masterclass/07-artifact-management-registries

mkdir -p security/policies/ecr security/reports security/runbooks
```

Create:

```bash id="j0xwft"
nano security/policies/ecr/demo-node-api-ecr-ci-push-policy.json
```

Paste:

```json id="or5y2e"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EcrAuthToken",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Sid": "PushOnlyToDemoNodeApiRepository",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
        "ecr:BatchGetImage",
        "ecr:DescribeImages",
        "ecr:DescribeRepositories"
      ],
      "Resource": "arn:aws:ecr:ap-south-1:123456789012:repository/demo-node-api"
    }
  ]
}
```

Replace:

```text id="wqf5y0"
123456789012
```

with your AWS account ID.

Why `GetAuthorizationToken` uses `Resource: "*"`?

```text id="z83fss"
ECR authorization token is registry-level, not repository-specific.
```

Professional rule:

```text id="83g3s2"
CI push policy should not include repository deletion or policy modification.
```

Do not include:

```text id="r6d9gt"
ecr:DeleteRepository
ecr:DeleteRepositoryPolicy
ecr:PutLifecyclePolicy
ecr:SetRepositoryPolicy
ecr:PutImageTagMutability
```

in normal CI push roles.

---

# 7. ECR Pull Policy — Deployment Server

Create:

```bash id="wud3ua"
nano security/policies/ecr/demo-node-api-ecr-deploy-pull-policy.json
```

Paste:

```json id="gc9p25"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EcrAuthToken",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Sid": "PullOnlyFromDemoNodeApiRepository",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:DescribeImages",
        "ecr:DescribeRepositories"
      ],
      "Resource": "arn:aws:ecr:ap-south-1:123456789012:repository/demo-node-api"
    }
  ]
}
```

This is for:

```text id="7ja6nt"
EC2 instance role
deployment server role
ECS task execution role pattern
EKS node/pod pull identity pattern
```

Professional rule:

```text id="tl5dgk"
Production runtime should pull, not push.
```

---

# 8. ECR Admin Policy — Restricted Admin

Admin policy should be rare.

Create:

```bash id="dlhgt7"
nano security/policies/ecr/demo-node-api-ecr-admin-policy.json
```

Paste:

```json id="zxbc0q"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EcrAuthToken",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ManageDemoNodeApiRepository",
      "Effect": "Allow",
      "Action": [
        "ecr:CreateRepository",
        "ecr:DescribeRepositories",
        "ecr:DeleteRepository",
        "ecr:SetRepositoryPolicy",
        "ecr:DeleteRepositoryPolicy",
        "ecr:GetRepositoryPolicy",
        "ecr:PutLifecyclePolicy",
        "ecr:GetLifecyclePolicy",
        "ecr:DeleteLifecyclePolicy",
        "ecr:PutImageScanningConfiguration",
        "ecr:PutImageTagMutability",
        "ecr:DescribeImages",
        "ecr:ListImages",
        "ecr:BatchDeleteImage"
      ],
      "Resource": "arn:aws:ecr:ap-south-1:123456789012:repository/demo-node-api"
    }
  ]
}
```

Use carefully.

For normal engineers, this is too much.

---

# 9. ECR Cross-Account Repository Policy

ECR repository policies are resource-based policies scoped to individual repositories, and AWS provides repository policy examples for controlling access to private repositories. ([AWS Documentation][4])

Example: allow another AWS account to pull.

Create:

```bash id="mh9t4l"
nano security/policies/ecr/demo-node-api-cross-account-pull-repository-policy.json
```

Paste:

```json id="js4msp"
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "AllowCrossAccountPull",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::222222222222:root"
      },
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ]
    }
  ]
}
```

Apply:

```bash id="b2saa8"
aws ecr set-repository-policy \
  --repository-name demo-node-api \
  --policy-text file://security/policies/ecr/demo-node-api-cross-account-pull-repository-policy.json \
  --region ap-south-1
```

Important:

```text id="62ieit"
The consuming account still needs IAM permissions and ECR authentication.
```

Cross-account access should be explicit, reviewed, and logged.

---

# 10. ECR Authentication Token Lifetime

AWS ECR push documentation says authentication tokens must be obtained for each registry used and are valid for 12 hours. ([AWS Documentation][5])

That means:

```text id="q72zd8"
CI should login during each job.
Servers should refresh login before pulling if needed.
Do not assume old docker login lasts forever.
```

Command:

```bash id="w35zpw"
aws ecr get-login-password --region ap-south-1 \
  | docker login \
      --username AWS \
      --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com"
```

Common failure:

```text id="sjqw4s"
no basic auth credentials
```

Fix:

```text id="cqbmut"
login again to the correct AWS account and region
```

---

# 11. GHCR Access Control

GitHub Container Registry supports granular permissions and can inherit permissions from a linked repository or be managed independently. Public container packages can be pulled anonymously, while private packages require authentication. ([GitHub Docs][6])

GHCR access identities:

```text id="gxarqc"
GITHUB_TOKEN:
  best for GitHub Actions in the same repo/package context

PAT classic:
  local CLI or external server pull/push

repository/package access:
  controls which repos/actions can access package
```

GitHub docs state that `GITHUB_TOKEN` can publish packages associated with the workflow repository, and a PAT with at least `read:packages` is needed to install packages associated with other private repositories unless the repository is granted access. ([GitHub Docs][7])

---

# 12. GHCR Permission Patterns

## Same repo builds and publishes

```text id="0cdx5w"
repo:
  devops-masterclass

workflow:
  ghcr-build-push.yml

image:
  ghcr.io/owner/demo-node-api
```

Use:

```yaml id="ilxruv"
permissions:
  contents: read
  packages: write
```

Login:

```yaml id="bzyip8"
- uses: docker/login-action@v4
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

---

## Different repo deploys private package

Example:

```text id="0kfl6o"
repo A:
  builds image

repo B:
  deploys image
```

Options:

```text id="9vn6jd"
grant repo B package access
use PAT with read:packages
make package public if safe
```

Professional rule:

```text id="v9fnhz"
Do not solve GHCR permission problems by using a broad personal admin token everywhere.
```

---

# 13. GHCR Token Scopes

For local or server tokens:

```text id="wz1ic7"
read:packages:
  pull private packages

write:packages:
  push packages

delete:packages:
  delete packages, dangerous
```

Production server:

```text id="tx38k7"
read:packages only
```

CI publisher:

```text id="6ntmjr"
GITHUB_TOKEN packages: write
or PAT write:packages only if needed
```

Admin cleanup workflow:

```text id="1mseiw"
delete:packages only in tightly controlled workflow
```

---

# 14. Docker Hub Access Control

Docker Hub personal access tokens are a secure alternative to passwords for Docker CLI authentication and automation. ([Docker Documentation][8])

For organizations, Docker’s Organization Access Tokens provide programmatic access for CI/CD and automation, and Docker’s documentation recommends least privilege, rotation, monitoring token usage, and secure storage. ([Docker Documentation][9])

Docker login can authenticate to a registry using a username with an access token or password. ([Docker Documentation][10])

Production rule:

```text id="bekdhx"
Use tokens, not passwords.
Use org tokens for organization automation where available.
Use minimum repository access.
Rotate tokens.
```

Bad:

```bash id="czh4te"
docker login -u user -p password
```

Better:

```bash id="l4yx6l"
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
```

---

# 15. Create Registry Access Matrix

Create:

```bash id="fadqw3"
cd ~/devops-masterclass/07-artifact-management-registries

nano security/registry-access-matrix.md
```

Paste:

```markdown id="lcx9k5"
# Registry Access Matrix

## Service

`demo-node-api`

## Repositories

| Registry | Repository |
|---|---|
| GHCR | `ghcr.io/OWNER/demo-node-api` |
| ECR | `ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api` |
| Docker Hub | `OWNER/demo-node-api` |

## Access Roles

| Identity | Push | Pull | Delete | Manage Policy | Notes |
|---|---:|---:|---:|---:|---|
| CI publisher | yes | yes | no | no | Builds and publishes images |
| Deployment server | no | yes | no | no | Pull-only runtime |
| Developer | limited | yes | no | no | Dev tags only if allowed |
| Security auditor | no | yes | no | no | Reads image metadata/scans |
| Registry admin | yes | yes | yes | yes | Restricted admin group |
| Break-glass admin | yes | yes | yes | yes | Emergency only, audited |

## Rules

- Production servers must not push.
- CI must not manage repository policies.
- Delete access must be rare.
- Production deploys immutable version-sha tags.
- Production deployment requires signature verification.
- Rollback images must not be deleted.
```

---

# 16. Create Registry Security Policy

Create:

```bash id="gqn21k"
nano security/registry-security-policy.md
```

Paste:

```markdown id="qa9c7h"
# Registry Security Policy

## Authentication

- Use tokens or IAM roles, not passwords.
- Prefer OIDC for CI to cloud registries.
- Use short-lived credentials where possible.
- Store secrets only in approved secret stores.

## Authorization

- CI can push only to approved repositories.
- Runtime servers are pull-only.
- Delete access is restricted.
- Repository policy changes require admin approval.
- Cross-account access requires explicit approval.

## Artifact Controls

- Production uses immutable version-sha tags.
- `latest` is forbidden for production.
- Tag immutability should be enabled where supported.
- Image signing is required for production.
- SBOM and provenance are required for production.

## Retention

- Keep current production image.
- Keep previous production image.
- Keep stable release artifacts.
- Do not delete artifacts referenced by deployment records.

## Auditing

- Review push/delete/policy-change events.
- Review failed authentication events.
- Rotate suspicious credentials.
- Investigate unexpected image tags.

## Break-Glass

- Break-glass access is temporary.
- Break-glass use must be logged.
- Post-incident review is required.
```

---

# 17. Create ECR Policy Validator Script

This validator checks for dangerous ECR policy patterns in local JSON files.

Create:

```bash id="3ri4um"
nano scripts/validate-ecr-policy.sh
```

Paste:

```bash id="o9d76a"
#!/usr/bin/env bash
set -euo pipefail

POLICY_FILE="${1:-}"

if [ -z "$POLICY_FILE" ]; then
  echo "Usage: $0 <policy-json>" >&2
  exit 1
fi

if [ ! -f "$POLICY_FILE" ]; then
  echo "ERROR: policy file not found: $POLICY_FILE" >&2
  exit 1
fi

echo "===== Validate ECR Policy ====="
echo "Policy: $POLICY_FILE"

FAIL=0

if jq -e '.. | objects | select(.Effect? == "Allow" and .Action? == "*")' "$POLICY_FILE" >/dev/null; then
  echo "ERROR: wildcard Action '*' found"
  FAIL=1
fi

if jq -e '.. | objects | select(.Effect? == "Allow" and .Resource? == "*")' "$POLICY_FILE" >/dev/null; then
  if jq -e '.. | objects | select(.Action? == ["ecr:GetAuthorizationToken"] or .Action? == "ecr:GetAuthorizationToken")' "$POLICY_FILE" >/dev/null; then
    echo "INFO: Resource '*' found for GetAuthorizationToken, usually expected."
  else
    echo "WARNING: Resource '*' found outside expected auth-token use."
  fi
fi

if jq -e '.. | strings | select(. == "ecr:DeleteRepository" or . == "ecr:BatchDeleteImage" or . == "ecr:SetRepositoryPolicy" or . == "ecr:DeleteRepositoryPolicy")' "$POLICY_FILE" >/dev/null; then
  echo "WARNING: destructive/admin ECR permissions found."
fi

if jq -e '.. | strings | select(. == "ecr:PutImage")' "$POLICY_FILE" >/dev/null; then
  echo "INFO: push permission ecr:PutImage found."
fi

if jq -e '.. | strings | select(. == "ecr:GetDownloadUrlForLayer")' "$POLICY_FILE" >/dev/null; then
  echo "INFO: pull permission ecr:GetDownloadUrlForLayer found."
fi

if [ "$FAIL" -eq 1 ]; then
  echo "Policy validation failed."
  exit 1
fi

echo "Policy validation completed."
```

Make executable:

```bash id="rxku7f"
chmod +x scripts/validate-ecr-policy.sh
```

Run:

```bash id="v5ng5q"
./scripts/validate-ecr-policy.sh security/policies/ecr/demo-node-api-ecr-ci-push-policy.json
./scripts/validate-ecr-policy.sh security/policies/ecr/demo-node-api-ecr-deploy-pull-policy.json
./scripts/validate-ecr-policy.sh security/policies/ecr/demo-node-api-ecr-admin-policy.json
```

Expected:

```text id="zps20i"
push policy:
  PutImage found

pull policy:
  GetDownloadUrlForLayer found

admin policy:
  warnings for destructive/admin permissions
```

---

# 18. Create Registry Access Audit Script

This script generates a local registry security report.

Create:

```bash id="itby7y"
nano scripts/registry-security-audit.sh
```

Paste:

```bash id="dmqsge"
#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-security/reports}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/registry-security-audit-$TIMESTAMP.json"

mkdir -p "$REPORT_DIR"

echo "===== Registry Security Audit ====="

DOCKER_LOGGED_IN="unknown"
if [ -f "$HOME/.docker/config.json" ]; then
  DOCKER_LOGGED_IN="config_exists"
else
  DOCKER_LOGGED_IN="no_config"
fi

ECR_IDENTITY="not_checked"
if command -v aws >/dev/null 2>&1; then
  if aws sts get-caller-identity >/tmp/aws-identity.json 2>/dev/null; then
    ECR_IDENTITY="$(cat /tmp/aws-identity.json | jq -c .)"
  else
    ECR_IDENTITY="aws_not_authenticated"
  fi
fi

POLICY_FILES_JSON="$(find security/policies -type f -name "*.json" 2>/dev/null | sort | jq -R . | jq -s .)"

cat > "$REPORT_FILE" <<EOF
{
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "docker_auth_config": "$DOCKER_LOGGED_IN",
  "aws_identity": $(
    if echo "$ECR_IDENTITY" | jq . >/dev/null 2>&1; then
      echo "$ECR_IDENTITY"
    else
      jq -n --arg value "$ECR_IDENTITY" '$value'
    fi
  ),
  "policy_files": $POLICY_FILES_JSON,
  "checks": {
    "least_privilege_review_required": true,
    "production_pull_only_required": true,
    "delete_access_restricted_required": true,
    "token_rotation_required": true,
    "signature_verification_required": true
  }
}
EOF

cat "$REPORT_FILE" | jq .
echo
echo "Report written: $REPORT_FILE"
```

Make executable:

```bash id="ss76id"
chmod +x scripts/registry-security-audit.sh
```

Run:

```bash id="xncs6q"
./scripts/registry-security-audit.sh
```

---

# 19. ECR Audit Commands

Useful commands:

```bash id="k0xd8b"
AWS_REGION=ap-south-1
ECR_REPOSITORY=demo-node-api
```

Describe repo:

```bash id="ctod86"
aws ecr describe-repositories \
  --repository-names "$ECR_REPOSITORY" \
  --region "$AWS_REGION" \
  | jq .
```

List images:

```bash id="ecmq0k"
aws ecr list-images \
  --repository-name "$ECR_REPOSITORY" \
  --region "$AWS_REGION" \
  | jq .
```

Describe images:

```bash id="pc34bp"
aws ecr describe-images \
  --repository-name "$ECR_REPOSITORY" \
  --region "$AWS_REGION" \
  | jq '.imageDetails[] | {imageTags, imageDigest, imagePushedAt, imageSizeInBytes}'
```

Get repository policy:

```bash id="qohb4b"
aws ecr get-repository-policy \
  --repository-name "$ECR_REPOSITORY" \
  --region "$AWS_REGION" \
  | jq .
```

Get lifecycle policy:

```bash id="sgw6m4"
aws ecr get-lifecycle-policy \
  --repository-name "$ECR_REPOSITORY" \
  --region "$AWS_REGION" \
  | jq .
```

Scan findings:

```bash id="jbaxfp"
aws ecr describe-image-scan-findings \
  --repository-name "$ECR_REPOSITORY" \
  --image-id imageTag="$DEPLOY_TAG" \
  --region "$AWS_REGION" \
  | jq .
```

---

# 20. CloudTrail and Audit Logs

For AWS, ECR API actions can be reviewed through AWS audit trails. In practice, you should investigate events such as:

```text id="e9w645"
CreateRepository
DeleteRepository
PutImage
BatchDeleteImage
SetRepositoryPolicy
DeleteRepositoryPolicy
PutLifecyclePolicy
PutImageTagMutability
PutImageScanningConfiguration
GetAuthorizationToken
```

AWS ECR repositories can be created, monitored, deleted, and managed through API operations, and permissions control who can access them. ([AWS Documentation][11])

Example CloudTrail lookup:

```bash id="bwl0ls"
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=PutImage \
  --region ap-south-1 \
  | jq .
```

Look for suspicious events:

```bash id="edydhd"
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=BatchDeleteImage \
  --region ap-south-1 \
  | jq .
```

Professional rule:

```text id="m217fs"
Push, delete, and policy-change events should be auditable.
```

---

# 21. GHCR Audit Checklist

For GHCR, manually check:

```text id="tudbb8"
package visibility
package linked repository
Manage Actions access
who can write package
who can read package
who can delete package
workflow permissions
repository secrets
organization package settings
```

GitHub package permissions can be inherited from a repository or configured granularly, which is why package access and repository access must both be reviewed. ([GitHub Docs][6])

Important workflow permissions:

```yaml id="hsnoz4"
permissions:
  contents: read
  packages: write
```

For deploy-only workflow:

```yaml id="rp1fib"
permissions:
  contents: read
  packages: read
```

If private image pull fails, check:

```text id="657a24"
package visibility
token read:packages
repo has package access
server docker login
correct owner/image name
```

---

# 22. Token Storage and Rotation

Token rules:

```text id="57zqgg"
never commit tokens
never print tokens in logs
never store tokens in shell scripts
avoid putting tokens directly in .env
use CI secrets
use AWS IAM roles
use GitHub Actions OIDC
rotate tokens regularly
delete unused tokens
use expiration dates when available
```

Docker’s organization token documentation recommends regular token rotation, least privilege, monitoring token usage, and secure storage. ([Docker Documentation][9])

For local terminal:

```bash id="tcxav7"
read -s GHCR_TOKEN
echo "$GHCR_TOKEN" | docker login ghcr.io -u YOUR_USER --password-stdin
unset GHCR_TOKEN
```

Avoid:

```bash id="opx69r"
GHCR_TOKEN=actual_token ./script.sh
```

because it can appear in shell history.

---

# 23. Break-Glass Access

Break-glass access means emergency access used only during incidents.

Examples:

```text id="hypwtw"
production registry admin role
manual image delete permission
manual policy override
emergency push permission
```

Break-glass must have:

```text id="cbzx3r"
approval
time limit
audit logs
reason
post-incident review
credential rotation if needed
```

Create break-glass template:

```bash id="1su30h"
nano security/runbooks/break-glass-registry-access.md
```

Paste:

```markdown id="d92fn9"
# Break-Glass Registry Access

## Purpose

Emergency access for registry operations during production incidents.

## Allowed Use

- restore deleted rollback image
- fix broken repository policy
- emergency revoke leaked credential
- recover from compromised CI token
- unblock critical production deployment

## Not Allowed

- normal deployments
- convenience pushes
- bypassing approval without incident
- deleting audit evidence

## Procedure

1. Declare incident.
2. Record reason.
3. Get approval from responsible lead.
4. Assume break-glass role or retrieve emergency token.
5. Perform minimum required action.
6. Capture command output.
7. Revoke/disable temporary access.
8. Rotate credentials if exposed.
9. Document timeline.
10. Run post-incident review.

## Required Record

- who used access
- when
- why
- commands run
- artifacts affected
- follow-up actions
```

---

# 24. Registry Incident Response

Common incident scenarios:

```text id="4aprw8"
CI token leaked
GHCR token leaked
ECR push role compromised
unknown image pushed
production pulled unexpected image
rollback image deleted
repository made public accidentally
malicious tag discovered
signature verification failed
```

Incident response flow:

```text id="oykog2"
1. Stop ongoing deployments.
2. Identify affected registry/repository.
3. Revoke leaked credentials.
4. Rotate tokens/keys.
5. Review recent push/delete/policy events.
6. Identify suspicious images/tags/digests.
7. Block or delete malicious images if safe.
8. Restore trusted previous artifact.
9. Verify signatures/provenance.
10. Deploy known-good image.
11. Document incident.
12. Add preventive controls.
```

Create runbook:

```bash id="coq37d"
nano security/runbooks/registry-incident-response.md
```

Paste:

````markdown id="v77yx7"
# Registry Incident Response Runbook

## First Actions

```bash
# Stop automatic deployment jobs if needed
# Disable compromised token or role
# Preserve logs and deployment records
````

## Identify Running Image

```bash id="sqo5u8"
docker inspect compose-demo-backend --format '{{.Config.Image}}'
curl -s http://127.0.0.1:8080/version | jq .
```

## ECR Recent Push Events

```bash id="j0umh8"
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=PutImage \
  --region ap-south-1 \
  | jq .
```

## ECR Recent Delete Events

```bash id="7y001g"
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=BatchDeleteImage \
  --region ap-south-1 \
  | jq .
```

## Verify Trusted Image

```bash id="dymbn6"
cosign verify \
  --certificate-identity-regexp "https://github.com/OWNER/REPO/.github/workflows/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  IMAGE
```

## Rollback

```bash id="bvvhp7"
APP_IMAGE=trusted-image \
APP_VERSION=previous-known-good \
COMPOSE_FILES="compose.yaml compose.prod.yaml" \
./scripts/deploy-compose.sh
```

## Post-Incident

* rotate credentials
* review token scopes
* review IAM policies
* enable immutability
* enforce signature verification
* update lifecycle policy
* document root cause

````

---

# 25. Supply-Chain Attack Scenarios

## Scenario A — CI push token leaked

Risk:

```text id="rum08d"
attacker pushes malicious image
````

Mitigation:

```text id="xqozm6"
OIDC instead of static key
least-privilege role
tag immutability
signature verification
audit PutImage events
```

---

## Scenario B — Production server token leaked

Risk:

```text id="2jj8ll"
attacker pulls private images
```

Mitigation:

```text id="d11lys"
pull-only token
no secrets in images
rotate token
audit pull/logins where available
move to IAM role or short-lived credential
```

---

## Scenario C — Registry admin compromised

Risk:

```text id="wv9s41"
delete repository
change policy
disable immutability
delete rollback images
```

Mitigation:

```text id="x4hr4d"
MFA
restricted admin group
CloudTrail/audit alerts
break-glass separation
backups/replication
policy-as-code review
```

---

## Scenario D — Public package accidentally exposed

Risk:

```text id="oju57o"
private image becomes public
```

Mitigation:

```text id="n6kmh0"
visibility review
no secrets in image
package policy audit
automated checks
incident response
```

---

# 26. Create Registry Security Checklist Script

Create:

```bash id="wg8s61"
nano scripts/registry-security-checklist.sh
```

Paste:

```bash id="hhj9fa"
#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-security/reports}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/registry-security-checklist-$TIMESTAMP.md"

mkdir -p "$REPORT_DIR"

cat > "$REPORT_FILE" <<'EOF'
# Registry Security Checklist

## Access Control

- [ ] CI identity can push only required repositories.
- [ ] Production server identity is pull-only.
- [ ] Delete access is restricted.
- [ ] Admin access is restricted and audited.
- [ ] Break-glass access exists and is documented.

## Authentication

- [ ] No passwords used in CI.
- [ ] Tokens have minimum scopes.
- [ ] Tokens have expiration where possible.
- [ ] Tokens are rotated regularly.
- [ ] OIDC is used for cloud CI where possible.

## Artifact Protection

- [ ] Production does not use latest.
- [ ] Immutable version-sha tags are used.
- [ ] Tag immutability enabled where supported.
- [ ] Image signing required for production.
- [ ] SBOM required for production.
- [ ] Provenance required for production.

## Retention and Rollback

- [ ] Current production image retained.
- [ ] Previous production image retained.
- [ ] Stable release images retained.
- [ ] Lifecycle policy does not delete rollback images.

## Auditing

- [ ] Push events reviewed.
- [ ] Delete events reviewed.
- [ ] Policy-change events reviewed.
- [ ] Failed auth events investigated.
- [ ] Unexpected tags investigated.

## Incident Response

- [ ] Token leak runbook exists.
- [ ] Malicious image runbook exists.
- [ ] Rollback process tested.
- [ ] Credential rotation process tested.
EOF

cat "$REPORT_FILE"
echo
echo "Checklist written: $REPORT_FILE"
```

Make executable:

```bash id="xx3uxm"
chmod +x scripts/registry-security-checklist.sh
```

Run:

```bash id="unr5uc"
./scripts/registry-security-checklist.sh
```

---

# 27. Update Makefile

Open:

```bash id="4radxf"
cd ~/devops-masterclass/07-artifact-management-registries

nano Makefile
```

Add:

```Makefile id="fgfin3"
.PHONY: validate-ecr-policy registry-audit registry-checklist

validate-ecr-policy:
	@test -n "$(POLICY)" || (echo "Usage: make validate-ecr-policy POLICY=<file>" && exit 1)
	./scripts/validate-ecr-policy.sh "$(POLICY)"

registry-audit:
	./scripts/registry-security-audit.sh

registry-checklist:
	./scripts/registry-security-checklist.sh
```

Use:

```bash id="c9pr90"
make validate-ecr-policy POLICY=security/policies/ecr/demo-node-api-ecr-ci-push-policy.json
make validate-ecr-policy POLICY=security/policies/ecr/demo-node-api-ecr-deploy-pull-policy.json
make registry-audit
make registry-checklist
```

---

# 28. Final Validation

Run:

```bash id="m6gefl"
cd ~/devops-masterclass/07-artifact-management-registries

./scripts/validate-ecr-policy.sh security/policies/ecr/demo-node-api-ecr-ci-push-policy.json
./scripts/validate-ecr-policy.sh security/policies/ecr/demo-node-api-ecr-deploy-pull-policy.json
./scripts/registry-security-audit.sh
./scripts/registry-security-checklist.sh
```

Optional AWS validation if permissions are available:

```bash id="ru7wmm"
AWS_REGION=ap-south-1
ECR_REPOSITORY=demo-node-api

aws sts get-caller-identity
aws ecr describe-repositories --repository-names "$ECR_REPOSITORY" --region "$AWS_REGION" | jq .
aws ecr get-repository-policy --repository-name "$ECR_REPOSITORY" --region "$AWS_REGION" | jq . || true
aws ecr get-lifecycle-policy --repository-name "$ECR_REPOSITORY" --region "$AWS_REGION" | jq . || true
```

---

# 29. Commit Work

Run:

```bash id="es04gc"
cd ~/devops-masterclass

git status
git add 07-artifact-management-registries

git commit -m "feat: add registry security and access control patterns"
git push
```

---

# 30. Interview Explanation

## How do you secure a container registry?

Strong answer:

```text id="9yjpj7"
I separate registry identities by responsibility. CI has push access, production servers have pull-only access, admins manage repository settings, and delete access is restricted. I use immutable tags, signature verification, SBOM/provenance requirements, lifecycle policies that protect rollback images, and audit logs for push/delete/policy-change events.
```

## What permissions should CI have?

Strong answer:

```text id="3pzti2"
CI should have push access only to the repositories it builds. In ECR, that means GetAuthorizationToken plus upload and PutImage permissions scoped to the repository. CI should not have delete repository or repository policy management permissions.
```

## What permissions should production servers have?

Strong answer:

```text id="fgsmeo"
Production servers should usually have pull-only access. For ECR, that means GetAuthorizationToken, BatchGetImage, GetDownloadUrlForLayer, BatchCheckLayerAvailability, and describe permissions scoped to the repository. They should not be able to push or delete images.
```

## How do GHCR permissions work?

Strong answer:

```text id="eg9xpu"
GHCR supports package-level permissions and repository-linked access. GitHub Actions can publish with GITHUB_TOKEN when workflow permissions include packages write and the package is associated with the repository. External servers pulling private images need read:packages or package access.
```

## Why should delete access be restricted?

Strong answer:

```text id="r7lo6w"
Deleting images can break rollback and destroy release evidence. Delete access should be restricted to admins or controlled cleanup workflows, and lifecycle policies must protect production and previous production artifacts.
```

## What is break-glass access?

Strong answer:

```text id="y6njp5"
Break-glass access is emergency elevated access used only during incidents. It should be temporary, approved, audited, and followed by a post-incident review and credential rotation if needed.
```

## What would you do if a registry token leaks?

Strong answer:

```text id="lo43ku"
I would stop risky deployments, revoke the token, rotate credentials, review recent push/delete/policy events, identify suspicious image tags and digests, verify trusted images with signatures/provenance, deploy a known-good image if needed, and document the incident with follow-up controls.
```

---

# Today’s Core Rules

```text id="k2vewu"
Registry security is supply-chain security.
CI should push.
Servers should pull.
Admins manage repository settings.
Delete access must be rare.
Use least privilege.
Use tokens or IAM roles, not passwords.
Prefer OIDC for CI to cloud registries.
Use pull-only production credentials.
Use immutable version-sha tags.
Do not use latest in production.
Protect rollback images.
Review push/delete/policy-change events.
Use signature verification before production deployment.
Rotate tokens and remove unused credentials.
Break-glass access must be audited.
```

---

# Next Lesson

# Lesson 7.12 — Artifact Cleanup, Retention, and Rollback Safety Deep Dive

We will go deeper into:

```text id="x17x3e"
artifact retention policies
safe cleanup rules
registry lifecycle policies
GHCR cleanup strategy
ECR lifecycle policy design
rollback windows
stable release protection
untagged image cleanup
storage cost vs safety
cleanup automation
cleanup incident scenarios
```

[1]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-push-iam.html?utm_source=chatgpt.com "IAM permissions for pushing an image to an Amazon ECR ..."
[2]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-policies.html?utm_source=chatgpt.com "Private repository policies in Amazon ECR"
[3]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/Registries.html?utm_source=chatgpt.com "Amazon ECR private registry"
[4]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-policy-examples.html?utm_source=chatgpt.com "Private repository policy examples in Amazon ECR"
[5]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html?utm_source=chatgpt.com "push a Docker image to an Amazon ECR repository"
[6]: https://docs.github.com/en/packages/learn-github-packages/about-permissions-for-github-packages?utm_source=chatgpt.com "About permissions for GitHub Packages"
[7]: https://docs.github.com/en/packages/learn-github-packages/introduction-to-github-packages?utm_source=chatgpt.com "Introduction to GitHub Packages"
[8]: https://docs.docker.com/security/access-tokens/?utm_source=chatgpt.com "Personal access tokens"
[9]: https://docs.docker.com/enterprise/security/access-tokens/?utm_source=chatgpt.com "Organization access tokens"
[10]: https://docs.docker.com/reference/cli/docker/login/?utm_source=chatgpt.com "docker login"
[11]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/Repositories.html?utm_source=chatgpt.com "Amazon ECR private repositories"

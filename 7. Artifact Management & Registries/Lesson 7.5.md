# Lesson 7.5 — Amazon ECR Production Workflow Deep Dive

# IAM Push/Pull, GitHub OIDC, Terraform ECR, Tag Immutability, Scan-on-Push, Lifecycle Policies, Repository Policies, and Troubleshooting

Amazon ECR is AWS’s managed container registry. For AWS-native production systems, ECR is usually the best registry because it integrates with IAM, ECS, EKS, EC2, Lambda container images, CloudTrail, Security Hub, and AWS-native private networking patterns. Amazon ECR supports private repositories with IAM-based access control. ([AWS Documentation][1])

In this lesson, we will go much deeper than “docker push to ECR.”

We will design a production ECR workflow.

---

# 1. Beginner Level — What Is ECR?

ECR means:

```text id="cwn1rl"
Elastic Container Registry
```

It stores container images.

Your image name in ECR looks like this:

```text id="ec95ea"
AWS_ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/REPOSITORY:TAG
```

For your AWS region:

```text id="2cb45a"
123456789012.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api:0.7.0-a1b2c3d
```

Breakdown:

```text id="xmq4mo"
123456789012          AWS account ID
ap-south-1            AWS region
demo-node-api         ECR repository
0.7.0-a1b2c3d         image tag
```

Basic flow:

```text id="ex7zf5"
build image locally or in CI
  ↓
login to ECR
  ↓
tag image with ECR URL
  ↓
push image
  ↓
server/ECS/EKS pulls image
  ↓
deploy
```

AWS documents the push workflow as: authenticate Docker to the ECR registry, tag the local image with the ECR registry/repository/tag format, then push it. ([AWS Documentation][2])

---

# 2. Production ECR Mental Model

Do not think of ECR as only image storage.

Think of it as:

```text id="z3r7co"
artifact storage
release control point
security scan location
rollback artifact source
IAM access boundary
promotion system component
audit trail component
```

A professional ECR workflow answers:

```text id="g7fqp5"
Who can push images?
Who can pull images?
Can tags be overwritten?
Are images scanned?
Which images can be deleted?
Which images must be retained?
Can production rollback?
Can another AWS account pull this image?
Can CI push without long-lived AWS keys?
```

Core rule:

```text id="0in3vg"
ECR is part of your release governance, not just Docker storage.
```

---

# 3. ECR Production Architecture

A common architecture:

```text id="viugz7"
GitHub Repo
   |
   | GitHub Actions with OIDC
   v
AWS IAM Role: github-actions-ecr-push-role
   |
   | docker build / scan / push
   v
Amazon ECR Repository
   |
   | pull-only IAM role
   v
EC2 / ECS / EKS / deployment server
   |
   v
Production container runtime
```

Permissions should be separated:

```text id="4w8nk0"
CI role:
  push image

server role:
  pull image

admin role:
  manage ECR repository settings

developer:
  maybe pull, maybe push dev images only
```

Professional rule:

```text id="n76yl6"
The identity that builds should not be the same as the identity that deploys or runs.
```

---

# 4. ECR Repository Creation — CLI

Use your region:

```bash id="fn9imb"
AWS_REGION=ap-south-1
ECR_REPOSITORY=demo-node-api
```

Create repository:

```bash id="uupuxn"
aws ecr create-repository \
  --repository-name "$ECR_REPOSITORY" \
  --region "$AWS_REGION"
```

But production should not create a default mutable, ungoverned repository. Use production options:

```bash id="ygjasv"
aws ecr create-repository \
  --repository-name "$ECR_REPOSITORY" \
  --region "$AWS_REGION" \
  --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true
```

ECR tag immutability prevents tags from being overwritten. When immutability is enabled, pushing an image with a tag that already exists returns `ImageTagAlreadyExistsException`. ([AWS Documentation][3])

ECR supports scan-on-push at repository creation through the image scanning configuration. AWS Security Hub also treats ECR image scanning as an important control for private repositories. ([AWS Documentation][4])

---

# 5. ECR Login

ECR uses AWS authentication, then Docker login.

Command:

```bash id="somxwf"
AWS_REGION=ap-south-1
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login \
      --username AWS \
      --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
```

AWS documents this pattern using `aws ecr get-login-password`, `docker login`, username `AWS`, and the registry URL format. ([AWS Documentation][2])

Validate:

```bash id="5rmcjb"
docker info | grep -i username || true
```

Important:

```text id="dxsuvd"
ECR login is region-specific.
If your repository is in ap-south-1, login to ap-south-1 registry.
```

---

# 6. Build, Tag, and Push to ECR

Compute deploy tag:

```bash id="yp5uxu"
cd ~/devops-masterclass/07-artifact-management-registries

VERSION_JSON="$(BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"

echo "$DEPLOY_TAG"
```

Build image:

```bash id="0cqbsy"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
```

Resolve ECR image:

```bash id="snzwu4"
AWS_REGION=ap-south-1
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_REPOSITORY=demo-node-api

ECR_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY"
```

Tag:

```bash id="3msbfm"
docker tag "demo-node-api:$DEPLOY_TAG" "$ECR_IMAGE:$DEPLOY_TAG"
```

Push:

```bash id="sayap9"
docker push "$ECR_IMAGE:$DEPLOY_TAG"
```

Inspect local repo digest after push:

```bash id="8pf3qf"
docker image inspect "$ECR_IMAGE:$DEPLOY_TAG" \
  --format '{{json .RepoDigests}}' | jq .
```

Professional rule:

```text id="8igx8o"
Push immutable version-sha tags to ECR, not latest.
```

---

# 7. IAM Permissions — Push Policy

For pushing to ECR, the identity needs authorization token access plus repository upload actions. AWS documents that users need IAM permissions to push to private repositories and recommends least privilege scoped to a repository where possible. ([AWS Documentation][5])

Create a push policy file:

```bash id="9owcdv"
cd ~/devops-masterclass/07-artifact-management-registries

cat > examples/ecr-push-policy.json <<'EOF'
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
      "Sid": "PushToSpecificRepository",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
        "ecr:DescribeRepositories",
        "ecr:DescribeImages",
        "ecr:BatchGetImage"
      ],
      "Resource": "arn:aws:ecr:ap-south-1:123456789012:repository/demo-node-api"
    }
  ]
}
EOF
```

Replace:

```text id="6xahjq"
123456789012
```

with your real AWS account ID.

Attach to CI role or IAM user:

```bash id="c5w7g6"
aws iam create-policy \
  --policy-name demo-node-api-ecr-push-policy \
  --policy-document file://examples/ecr-push-policy.json
```

Then attach to role:

```bash id="onx945"
aws iam attach-role-policy \
  --role-name github-actions-ecr-push-role \
  --policy-arn arn:aws:iam::<account-id>:policy/demo-node-api-ecr-push-policy
```

Professional rule:

```text id="d8a4k1"
CI should have push access only to the repositories it builds.
```

---

# 8. IAM Permissions — Pull Policy

Servers should usually have pull-only access.

Create:

```bash id="tbz57d"
cat > examples/ecr-pull-policy.json <<'EOF'
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
      "Sid": "PullFromSpecificRepository",
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
EOF
```

Attach to your EC2 instance role or deployment server role.

Professional rule:

```text id="bf4y83"
Production servers should pull images, not push images.
```

---

# 9. GitHub Actions OIDC to AWS — Why It Matters

Old method:

```text id="737fsq"
store AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in GitHub secrets
```

Better method:

```text id="ayvcjb"
GitHub Actions uses OIDC
AWS IAM role trusts GitHub repo
workflow receives temporary AWS credentials
no long-lived AWS keys in GitHub
```

GitHub documents configuring OpenID Connect in AWS so workflows can authenticate to AWS without storing long-lived cloud credentials. ([GitHub Docs][6])

The official `aws-actions/configure-aws-credentials` action supports assuming an IAM role using a `role-to-assume` value. ([GitHub][7])

Professional rule:

```text id="kvum8l"
Use OIDC for GitHub Actions to AWS wherever possible.
```

---

# 10. Create GitHub OIDC IAM Trust Policy

Example for one GitHub repo:

```bash id="ecim3v"
cat > examples/github-oidc-trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/devops-masterclass:*"
        }
      }
    }
  ]
}
EOF
```

More restrictive for `main` only:

```json id="6k524d"
"token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/devops-masterclass:ref:refs/heads/main"
```

For GitHub environment-based deployment, you can use environment-specific subject patterns, but exact claims depend on your workflow design. GitHub’s OIDC docs explain that AWS trust policies should restrict which repository/branch/environment can assume the role. ([GitHub Docs][6])

Create role:

```bash id="54w0n5"
aws iam create-role \
  --role-name github-actions-ecr-push-role \
  --assume-role-policy-document file://examples/github-oidc-trust-policy.json
```

Attach push policy:

```bash id="q8mcor"
aws iam attach-role-policy \
  --role-name github-actions-ecr-push-role \
  --policy-arn arn:aws:iam::<account-id>:policy/demo-node-api-ecr-push-policy
```

---

# 11. GitHub Actions Workflow — Build and Push to ECR

Create:

```bash id="gsi72c"
cd ~/devops-masterclass

nano .github/workflows/ecr-build-push.yml
```

Paste:

```yaml id="3bvlsd"
name: Build and Push to Amazon ECR

on:
  push:
    branches:
      - main
    tags:
      - "v*"
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

env:
  AWS_REGION: ap-south-1
  ECR_REPOSITORY: demo-node-api
  APP_DIR: 05-application-runtime/demo-node-api
  BASE_VERSION: "0.7.0"

jobs:
  build-push-ecr:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Compute version
        id: version
        shell: bash
        run: |
          SHORT_SHA="${GITHUB_SHA::7}"

          if [[ "${GITHUB_REF_TYPE}" == "tag" ]]; then
            BASE_VERSION="${GITHUB_REF_NAME#v}"
            CHANNEL="stable"
          else
            BASE_VERSION="${BASE_VERSION}"
            CHANNEL="dev"
          fi

          if [[ "$CHANNEL" == "stable" ]]; then
            VERSION="$BASE_VERSION"
          else
            VERSION="$BASE_VERSION-$CHANNEL"
          fi

          DEPLOY_TAG="$VERSION-$SHORT_SHA"

          echo "short_sha=$SHORT_SHA" >> "$GITHUB_OUTPUT"
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
          echo "deploy_tag=$DEPLOY_TAG" >> "$GITHUB_OUTPUT"

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: npm
          cache-dependency-path: ${{ env.APP_DIR }}/package-lock.json

      - name: Test
        working-directory: ${{ env.APP_DIR }}
        run: |
          npm ci
          npm test

      - name: Configure AWS credentials with OIDC
        uses: aws-actions/configure-aws-credentials@v5
        with:
          role-to-assume: arn:aws:iam::<account-id>:role/github-actions-ecr-push-role
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to ECR
        id: ecr-login
        shell: bash
        run: |
          AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
          echo "aws_account_id=$AWS_ACCOUNT_ID" >> "$GITHUB_OUTPUT"

          aws ecr get-login-password --region "$AWS_REGION" \
            | docker login \
                --username AWS \
                --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

      - name: Build image
        shell: bash
        run: |
          AWS_ACCOUNT_ID="${{ steps.ecr-login.outputs.aws_account_id }}"
          IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY"
          DEPLOY_TAG="${{ steps.version.outputs.deploy_tag }}"
          SHORT_SHA="${{ steps.version.outputs.short_sha }}"

          docker build \
            -f "$APP_DIR/Dockerfile.industry" \
            --target runtime \
            --build-arg APP_VERSION="$DEPLOY_TAG" \
            --build-arg COMMIT_SHA="$SHORT_SHA" \
            -t "$IMAGE:$DEPLOY_TAG" \
            -t "$IMAGE:$SHORT_SHA" \
            "$APP_DIR"

      - name: Push image
        shell: bash
        run: |
          AWS_ACCOUNT_ID="${{ steps.ecr-login.outputs.aws_account_id }}"
          IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY"
          DEPLOY_TAG="${{ steps.version.outputs.deploy_tag }}"
          SHORT_SHA="${{ steps.version.outputs.short_sha }}"

          docker push "$IMAGE:$DEPLOY_TAG"
          docker push "$IMAGE:$SHORT_SHA"

      - name: Record image digest
        shell: bash
        run: |
          AWS_ACCOUNT_ID="${{ steps.ecr-login.outputs.aws_account_id }}"
          IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY"
          DEPLOY_TAG="${{ steps.version.outputs.deploy_tag }}"

          docker pull "$IMAGE:$DEPLOY_TAG"
          docker image inspect "$IMAGE:$DEPLOY_TAG" --format '{{json .RepoDigests}}'
```

Replace:

```text id="8zb6hx"
<account-id>
```

with your real AWS account ID.

This workflow uses OIDC by granting `id-token: write`, then the AWS credentials action assumes an IAM role instead of using static AWS keys. GitHub documents OIDC as the recommended keyless pattern for cloud authentication. ([GitHub Docs][6])

---

# 12. ECR with Terraform — Production IaC

Now we make ECR infrastructure repeatable.

Create:

```bash id="p9b5ak"
cd ~/devops-masterclass/07-artifact-management-registries

mkdir -p terraform/ecr
cd terraform/ecr
```

Create provider:

```bash id="ddn13h"
nano providers.tf
```

Paste:

```hcl id="q50s84"
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

Create variables:

```bash id="lfxna4"
nano variables.tf
```

Paste:

```hcl id="uvxa62"
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "repository_name" {
  description = "ECR repository name"
  type        = string
  default     = "demo-node-api"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "dev"
}

variable "scan_on_push" {
  description = "Enable scan on push"
  type        = bool
  default     = true
}

variable "image_tag_mutability" {
  description = "ECR image tag mutability"
  type        = string
  default     = "IMMUTABLE"
}
```

Create ECR:

```bash id="qknczj"
nano main.tf
```

Paste:

```hcl id="v4uz28"
resource "aws_ecr_repository" "app" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = var.repository_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "devops-masterclass"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire old dev images beyond last 30"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
```

The Terraform AWS provider supports `aws_ecr_repository`, including `image_scanning_configuration` with `scan_on_push`, and exposes repository attributes such as `repository_url`. ([Terraform Registry][8])

Create outputs:

```bash id="i2ch0m"
nano outputs.tf
```

Paste:

```hcl id="qslca3"
output "repository_name" {
  value = aws_ecr_repository.app.name
}

output "repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "repository_arn" {
  value = aws_ecr_repository.app.arn
}
```

Run:

```bash id="7eib11"
terraform init
terraform fmt
terraform validate
terraform plan
```

Apply if permissions allow:

```bash id="f6nh06"
terraform apply
```

If you hit `AccessDeniedException`, that matches your earlier AWS IAM pattern. You need permissions like:

```text id="r0priq"
ecr:CreateRepository
ecr:PutLifecyclePolicy
ecr:PutImageTagMutability
ecr:PutImageScanningConfiguration
ecr:DescribeRepositories
```

---

# 13. Repository Policy for Cross-Account Pull

ECR can use repository policies for repository-scoped access. AWS explains that ECR repository policies are resource-based policies scoped to individual repositories; IAM policies and repository policies are both evaluated when determining access. ([AWS Documentation][9])

Example: allow another AWS account to pull.

Create:

```bash id="yveyom"
cat > examples/ecr-cross-account-pull-policy.json <<'EOF'
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
EOF
```

Apply:

```bash id="xu8s6d"
aws ecr set-repository-policy \
  --repository-name demo-node-api \
  --policy-text file://examples/ecr-cross-account-pull-policy.json \
  --region ap-south-1
```

AWS provides ECR repository policy examples for controlling access to private repositories, including permission statements for repository access. ([AWS Documentation][10])

Professional caution:

```text id="bj9pjj"
Cross-account ECR access should be explicit, reviewed, and logged.
```

---

# 14. EC2 / Compose Server Pull from ECR

On an EC2 deployment server, prefer an instance profile/role with pull-only ECR permissions.

Login:

```bash id="qvxwnv"
AWS_REGION=ap-south-1
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login \
      --username AWS \
      --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
```

Set Compose `.env`:

```bash id="ufrtxp"
cd ~/devops-masterclass/06-docker-containers/compose-demo

cat > .env <<EOF
APP_IMAGE=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/demo-node-api
APP_VERSION=$DEPLOY_TAG
HOST_HTTP_PORT=8080
APP_ENV=prod
LOG_LEVEL=info
EOF
```

Deploy:

```bash id="4mahws"
COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
```

Validate:

```bash id="b47f2p"
docker inspect compose-demo-backend --format '{{.Config.Image}}'
curl -s http://127.0.0.1:8080/version | jq .
```

Professional rule:

```text id="fja6jz"
EC2 deployment servers should pull from ECR using an IAM role, not hardcoded AWS access keys.
```

---

# 15. ECR Enhanced Scanning

Basic scan-on-push is useful, but AWS also supports enhanced scanning configuration at the private registry level. AWS documents enhanced scanning configuration from ECR private registry settings. ([AWS Documentation][11])

Conceptual maturity:

```text id="gvse9l"
basic scan:
  repository-level scan on push

enhanced scan:
  registry-level deeper scanning integration
  more continuous security posture
```

For this course:

```text id="xx8dln"
Start with scanOnPush=true.
Later, learn enhanced scanning with Amazon Inspector/Security Hub integration.
```

Production rule:

```text id="wf5wod"
Image scanning should be part of CI and registry governance.
```

---

# 16. Create ECR Production Notes

Create:

```bash id="nah6fh"
cd ~/devops-masterclass/07-artifact-management-registries

nano notes/ecr-production-workflow.md
```

Paste:

````markdown id="pmxovx"
# Amazon ECR Production Workflow

## ECR Image Format

```text
AWS_ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/REPOSITORY:TAG
````

Example:

```text id="2srihc"
123456789012.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api:0.7.0-a1b2c3d
```

## Production Settings

* private repository
* tag immutability enabled
* scan on push enabled
* lifecycle policy configured
* CI push role
* server pull role
* release tags retained
* previous production image retained

## Login

```bash
aws ecr get-login-password --region ap-south-1 \
  | docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com
```

## Push

```bash id="id6d1g"
docker tag demo-node-api:TAG ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api:TAG
docker push ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api:TAG
```

## Pull

```bash id="9qfe9b"
docker pull ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api:TAG
```

## IAM Separation

CI role:

* push image
* describe repository
* get auth token

Server role:

* pull image
* get auth token

Admin role:

* create repository
* manage lifecycle policy
* manage scanning
* manage repository policy

## Production Rules

* Do not push `latest` to production.
* Use version-sha tags.
* Do not overwrite tags.
* Enable tag immutability.
* Enable scanning.
* Use OIDC for GitHub Actions.
* Use EC2 instance roles for server pulls.
* Protect rollback artifacts from lifecycle deletion.

````

---

# 17. Create ECR Troubleshooting Notes

Create:

```bash id="3iy6z4"
nano notes/ecr-troubleshooting-playbook.md
````

Paste:

````markdown id="dszt88"
# ECR Troubleshooting Playbook

## AccessDeniedException on create-repository

Likely missing:

```text
ecr:CreateRepository
````

## Cannot login to ECR

Check:

```bash
aws sts get-caller-identity
aws ecr get-login-password --region ap-south-1
```

Common causes:

* AWS CLI not configured
* wrong region
* expired credentials
* role lacks ECR auth permission

## Push denied

Likely missing:

```text
ecr:BatchCheckLayerAvailability
ecr:InitiateLayerUpload
ecr:UploadLayerPart
ecr:CompleteLayerUpload
ecr:PutImage
```

## Pull denied

Likely missing:

```text
ecr:BatchGetImage
ecr:GetDownloadUrlForLayer
ecr:BatchCheckLayerAvailability
```

## ImageTagAlreadyExistsException

Tag immutability is enabled and the tag already exists.

Correct fix:

* create a new tag
* do not overwrite release tags

## RepositoryNotFoundException

Causes:

* repository not created
* wrong region
* wrong AWS account
* typo in repository name

## Cannot rollback

Causes:

* previous image deleted by lifecycle policy
* previous tag overwritten
* image never pushed
* server cannot pull from ECR

Fix:

* retain production release tags
* keep previous production image
* use immutable tags
* record deployment metadata

````

---

# 18. Add Makefile Targets for ECR

Open:

```bash id="m1f1iz"
cd ~/devops-masterclass/07-artifact-management-registries

nano Makefile
````

Add:

```Makefile id="tlh413"
.PHONY: ecr-login ecr-setup ecr-push ecr-pull ecr-lifecycle ecr-describe ecr-scan-findings

ecr-login:
	REGISTRY_PROVIDER=ecr ./scripts/registry-login.sh

ecr-setup:
	./scripts/setup-ecr-repository.sh

ecr-push:
	@test -n "$(IMAGE_TAG)" || (echo "Usage: make ecr-push IMAGE_TAG=<tag> AWS_ACCOUNT_ID=<id>" && exit 1)
	REGISTRY_PROVIDER=ecr IMAGE_TAG="$(IMAGE_TAG)" ./scripts/tag-and-push-registry-image.sh

ecr-pull:
	@test -n "$(IMAGE_TAG)" || (echo "Usage: make ecr-pull IMAGE_TAG=<tag> AWS_ACCOUNT_ID=<id>" && exit 1)
	REGISTRY_PROVIDER=ecr IMAGE_TAG="$(IMAGE_TAG)" ./scripts/verify-registry-pull.sh

ecr-lifecycle:
	./scripts/apply-ecr-lifecycle-policy.sh

ecr-describe:
	aws ecr describe-repositories --repository-names "$${ECR_REPOSITORY:-demo-node-api}" --region "$${AWS_REGION:-ap-south-1}" | jq .

ecr-scan-findings:
	@test -n "$(IMAGE_TAG)" || (echo "Usage: make ecr-scan-findings IMAGE_TAG=<tag>" && exit 1)
	aws ecr describe-image-scan-findings \
		--repository-name "$${ECR_REPOSITORY:-demo-node-api}" \
		--image-id imageTag="$(IMAGE_TAG)" \
		--region "$${AWS_REGION:-ap-south-1}" | jq .
```

Usage:

```bash id="9nqtm9"
AWS_REGION=ap-south-1 ECR_REPOSITORY=demo-node-api make ecr-setup
AWS_REGION=ap-south-1 AWS_ACCOUNT_ID=123456789012 IMAGE_TAG="$DEPLOY_TAG" make ecr-push
IMAGE_TAG="$DEPLOY_TAG" make ecr-scan-findings
```

---

# 19. Production ECR Checklist

```text id="p2x21q"
Repository exists in correct region.
Repository is private.
Tag immutability enabled.
Scan on push enabled.
Lifecycle policy configured.
CI role has push access only.
Deployment server role has pull access only.
GitHub Actions uses OIDC.
No long-lived AWS keys in GitHub secrets.
Image tags include version and Git SHA.
Release metadata records ECR image ref.
Deployment report records running image.
Previous production image is retained.
Rollback has been tested.
```

---

# 20. Corporate Example

A production company may use this flow:

```text id="3u7tbz"
GitHub Actions
  assumes AWS IAM role via OIDC
  runs tests
  builds Docker image
  scans image
  pushes 1.8.2-a1b2c3d to ECR
  records digest
  stores release metadata

Staging EC2/ECS/EKS
  pulls same ECR image
  runs smoke tests

Production approval
  promotes same image tag/digest

Production runtime
  pulls image using IAM role
  validates readiness
  records deployment
```

A mature multi-account setup may look like:

```text id="2e1bnl"
dev AWS account:
  fast-moving dev images

shared services/security account:
  central ECR or replicated images

prod AWS account:
  production pulls approved images
```

Cross-account access can be handled with ECR repository policies or registry-level patterns depending on scope. AWS documents repository policies for individual repositories and cross-account access examples. ([AWS Documentation][9])

---

# 21. Final Hands-On Flow

Compute version:

```bash id="zt0kld"
cd ~/devops-masterclass/07-artifact-management-registries

VERSION_JSON="$(BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"
echo "$DEPLOY_TAG"
```

Build:

```bash id="4i8xuv"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
```

Setup ECR:

```bash id="45cykd"
cd ~/devops-masterclass/07-artifact-management-registries

AWS_REGION=ap-south-1 \
ECR_REPOSITORY=demo-node-api \
./scripts/setup-ecr-repository.sh
```

Login:

```bash id="4o6g2g"
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

REGISTRY_PROVIDER=ecr \
AWS_REGION=ap-south-1 \
AWS_ACCOUNT_ID="$AWS_ACCOUNT_ID" \
./scripts/registry-login.sh
```

Push:

```bash id="xyv6jo"
REGISTRY_PROVIDER=ecr \
AWS_REGION=ap-south-1 \
AWS_ACCOUNT_ID="$AWS_ACCOUNT_ID" \
IMAGE_TAG="$DEPLOY_TAG" \
./scripts/tag-and-push-registry-image.sh
```

Verify pull:

```bash id="5oczd5"
REGISTRY_PROVIDER=ecr \
AWS_REGION=ap-south-1 \
AWS_ACCOUNT_ID="$AWS_ACCOUNT_ID" \
IMAGE_TAG="$DEPLOY_TAG" \
./scripts/verify-registry-pull.sh
```

Create release metadata:

```bash id="40bzzp"
BASE_VERSION=0.7.0 \
CHANNEL=stable \
IMAGE_NAME=demo-node-api \
REGISTRY_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api" \
TEST_STATUS=passed \
SCAN_STATUS=passed \
./scripts/create-release-metadata.sh
```

Deploy with Compose:

```bash id="lgmhz1"
cd ~/devops-masterclass/06-docker-containers/compose-demo

APP_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api" \
APP_VERSION="$DEPLOY_TAG" \
COMPOSE_FILES="compose.yaml compose.prod.yaml" \
./scripts/deploy-compose.sh
```

Validate:

```bash id="7d13wc"
curl -s http://127.0.0.1:8080/version | jq .
docker inspect compose-demo-backend --format '{{.Config.Image}}'
```

---

# 22. Interview Explanation

## Why use ECR instead of Docker Hub?

Strong answer:

```text id="jo9hx1"
For AWS workloads, ECR is usually preferred because it integrates directly with IAM, ECS, EKS, EC2 instance roles, AWS scanning, repository policies, lifecycle policies, CloudTrail, and AWS-native security controls. Docker Hub is useful for public/general images, but ECR is better for AWS production systems.
```

## How does ECR authentication work?

Strong answer:

```text id="krje8z"
ECR authentication uses AWS credentials to request a temporary registry password with `aws ecr get-login-password`. That password is piped to `docker login` with username `AWS` and the account/region-specific registry URL.
```

## What permissions does CI need to push to ECR?

Strong answer:

```text id="8y5ipt"
CI needs `ecr:GetAuthorizationToken` and repository-scoped upload actions such as `BatchCheckLayerAvailability`, `InitiateLayerUpload`, `UploadLayerPart`, `CompleteLayerUpload`, and `PutImage`. It should be scoped to the specific repository wherever possible.
```

## What permissions does a server need to pull from ECR?

Strong answer:

```text id="iqufi6"
A server needs `ecr:GetAuthorizationToken` plus pull actions such as `BatchGetImage`, `GetDownloadUrlForLayer`, and usually `BatchCheckLayerAvailability`, scoped to the specific ECR repository.
```

## Why use GitHub OIDC with AWS?

Strong answer:

```text id="q4plnn"
OIDC lets GitHub Actions assume an AWS IAM role and receive temporary credentials without storing long-lived AWS access keys in GitHub secrets. This improves security and makes role trust policies more explicit.
```

## Why enable tag immutability?

Strong answer:

```text id="09xvlj"
Tag immutability prevents existing image tags from being overwritten. This protects release integrity, improves auditability, and makes rollback safer because a tag continues to represent the same image content.
```

## How do lifecycle policies affect production safety?

Strong answer:

```text id="fbi7ha"
Lifecycle policies reduce storage cost by deleting old images, but they must be designed carefully. They should not delete current production images, previous production rollback images, stable releases, or artifacts needed for audit.
```

---

# Today’s Core Rules

```text id="bxum5b"
Use ECR for AWS-native container workloads.
Use ap-south-1 for your current AWS region.
Use immutable version-sha image tags.
Enable ECR tag immutability.
Enable scan-on-push.
Use lifecycle policies carefully.
CI should push images.
Servers should pull images.
Use GitHub OIDC instead of long-lived AWS keys.
Use IAM least privilege.
Use EC2 instance roles for server pulls.
Use Terraform to manage ECR repositories.
Use repository policies for cross-account access.
Record ECR image refs and digests in metadata.
Never delete rollback artifacts blindly.
```

---

# Commit Work

Run:

```bash id="a6fqlv"
cd ~/devops-masterclass

git status
git add .github/workflows/ecr-build-push.yml \
        07-artifact-management-registries

git commit -m "feat: add Amazon ECR production workflow"
git push
```

---

# Next Lesson

# Lesson 7.6 — GHCR Production Workflow Deep Dive

We will go deeper into:

```text id="z4ou19"
GitHub Container Registry
package permissions
GITHUB_TOKEN vs PAT
private/public packages
linking packages to repositories
GitHub Actions publishing
read-only deploy tokens
GHCR image visibility
GHCR troubleshooting
GHCR release workflow
portfolio-friendly registry setup
```

[1]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html?utm_source=chatgpt.com "What is Amazon Elastic Container Registry? - Amazon ECR"
[2]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html?utm_source=chatgpt.com "push a Docker image to an Amazon ECR repository"
[3]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-tag-mutability.html?utm_source=chatgpt.com "Preventing image tags from being overwritten in Amazon ECR"
[4]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-create.html?utm_source=chatgpt.com "Creating an Amazon ECR private repository to store images"
[5]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-push-iam.html?utm_source=chatgpt.com "IAM permissions for pushing an image to an Amazon ECR ..."
[6]: https://docs.github.com/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services?utm_source=chatgpt.com "Configuring OpenID Connect in Amazon Web Services"
[7]: https://github.com/aws-actions/configure-aws-credentials?utm_source=chatgpt.com "Configure AWS credential environment variables for use ..."
[8]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository?utm_source=chatgpt.com "aws_ecr_repository | Resources | hashicorp/aws | Terraform"
[9]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-policies.html?utm_source=chatgpt.com "Private repository policies in Amazon ECR"
[10]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-policy-examples.html?utm_source=chatgpt.com "Private repository policy examples in Amazon ECR"
[11]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning-enhanced-enabling.html?utm_source=chatgpt.com "Configuring enhanced scanning for images in Amazon ECR"

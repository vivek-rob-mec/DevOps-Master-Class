# Lesson 7.4 — Docker Registry Deep Dive Masterclass

# Docker Hub, GHCR, ECR, Repository Structure, Auth, Push/Pull Permissions, Immutability, Scanning, Lifecycle Policies, and Registry Operations

In previous lessons, we learned:

```text id="xjgzfi"
artifact versioning
release metadata
checksums
Docker image digests
immutability
reproducibility
```

Now we go deeper into **where container artifacts live**:

```text id="4vbumd"
container registries
```

A container registry is not just image storage. In professional DevOps, it becomes part of your release, security, audit, rollback, and supply-chain system.

Docker Hub repositories store and organize container images by tags, where tags represent different versions of the same application. ([Docker Documentation][1])

---

# 1. Beginner Level — What Is a Docker Registry?

A Docker registry stores container images.

Examples:

```text id="ri5mrw"
Docker Hub
GitHub Container Registry / GHCR
Amazon ECR
GitLab Container Registry
Harbor
JFrog Artifactory
Nexus Repository
Google Artifact Registry
Azure Container Registry
```

Basic flow:

```text id="92sdal"
docker build
  ↓
local image
  ↓
docker tag
  ↓
docker push
  ↓
registry
  ↓
docker pull
  ↓
server / Compose / Kubernetes
```

Example:

```bash id="o3lsvy"
docker build -t demo-node-api:0.7.0-a1b2c3d .
docker tag demo-node-api:0.7.0-a1b2c3d ghcr.io/YOUR_USER/demo-node-api:0.7.0-a1b2c3d
docker push ghcr.io/YOUR_USER/demo-node-api:0.7.0-a1b2c3d
docker pull ghcr.io/YOUR_USER/demo-node-api:0.7.0-a1b2c3d
```

Core rule:

```text id="m6tjzj"
A registry is the source of truth for deployable container artifacts.
```

---

# 2. Beginner Mental Model

Local image:

```text id="w1w7qh"
demo-node-api:0.7.0-a1b2c3d
```

Registry image:

```text id="kq1mtf"
registry/namespace/repository:tag
```

Example GHCR:

```text id="w4dmha"
ghcr.io/vivek-saroj/demo-node-api:0.7.0-a1b2c3d
```

Example Docker Hub:

```text id="sw39yr"
viveksaroj/demo-node-api:0.7.0-a1b2c3d
```

Example ECR:

```text id="elcv2i"
123456789012.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api:0.7.0-a1b2c3d
```

---

# 3. Image Name Anatomy

Example:

```text id="kn42ei"
ghcr.io/vivek-saroj/demo-node-api:0.7.0-a1b2c3d
```

Breakdown:

```text id="ffr9f0"
ghcr.io               registry host
vivek-saroj           owner / namespace / organization
demo-node-api         repository
0.7.0-a1b2c3d         tag
```

ECR example:

```text id="j3tpkl"
123456789012.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api:0.7.0-a1b2c3d
```

Breakdown:

```text id="v0jxsy"
123456789012          AWS account ID
ap-south-1            AWS region
demo-node-api         ECR repository
0.7.0-a1b2c3d         tag
```

---

# 4. Registry vs Repository vs Tag vs Digest

These four words are very important.

```text id="15c708"
registry   = server/platform storing images
repository = collection of related images
tag        = named pointer to image version
digest     = exact content identity
```

Example:

```text id="kjq8l7"
registry:
  ghcr.io

repository:
  ghcr.io/vivek-saroj/demo-node-api

tag:
  0.7.0-a1b2c3d

digest:
  sha256:abc...
```

Professional answer:

```text id="17sj97"
A registry stores repositories. A repository stores image versions. Tags are human-friendly references. Digests identify exact image content.
```

---

# 5. Registry Option 1 — Docker Hub

Docker Hub is the default Docker registry.

Docker Hub repositories can be public or private, and repository content is organized by tags representing different versions of an application. ([Docker Documentation][1])

Image format:

```text id="rdar3c"
DOCKERHUB_USERNAME/repository:tag
```

Example:

```text id="xr22rl"
viveksaroj/demo-node-api:0.7.0-a1b2c3d
```

Login:

```bash id="b6erxf"
docker login
```

Tag:

```bash id="nflxa9"
docker tag demo-node-api:0.7.0-a1b2c3d viveksaroj/demo-node-api:0.7.0-a1b2c3d
```

Push:

```bash id="7354gj"
docker push viveksaroj/demo-node-api:0.7.0-a1b2c3d
```

Pull:

```bash id="hu9vcn"
docker pull viveksaroj/demo-node-api:0.7.0-a1b2c3d
```

For automation, Docker recommends personal access tokens as a more secure alternative to passwords for CLI authentication, CI/CD pipelines, and development tools. ([Docker Documentation][2])

Good CI/CD login pattern:

```bash id="g73jj8"
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
```

Bad CI/CD pattern:

```bash id="ytyxf2"
docker login -u username -p password
```

Core rule:

```text id="n40fz0"
Use tokens for automation. Do not use personal account passwords in pipelines.
```

---

# 6. Registry Option 2 — GitHub Container Registry / GHCR

GHCR image format:

```text id="gt73n2"
ghcr.io/OWNER/IMAGE_NAME:TAG
```

Example:

```text id="njocxz"
ghcr.io/vivek-saroj/demo-node-api:0.7.0-a1b2c3d
```

GitHub Container Registry supports granular permissions and can inherit permissions from a linked repository or use package-level permissions independently. ([GitHub Docs][3])

Login from local machine:

```bash id="zl4oy2"
echo "$GHCR_TOKEN" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

Tag:

```bash id="tknne4"
docker tag demo-node-api:0.7.0-a1b2c3d ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.7.0-a1b2c3d
```

Push:

```bash id="erympi"
docker push ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.7.0-a1b2c3d
```

Pull:

```bash id="n9cofh"
docker pull ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.7.0-a1b2c3d
```

For GitHub Actions, `GITHUB_TOKEN` is a GitHub App installation token scoped to the repository that contains the workflow, and its permissions can be configured for the workflow. ([GitHub Docs][4])

GitHub Actions GHCR login:

```yaml id="rg1oo6"
- name: Login to GHCR
  uses: docker/login-action@v4
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

Workflow permissions:

```yaml id="rllxfr"
permissions:
  contents: read
  packages: write
```

Professional rule:

```text id="qe78w4"
Use GITHUB_TOKEN for GitHub-native package publishing when possible. Use PATs only when required.
```

---

# 7. Registry Option 3 — Amazon ECR

Amazon ECR image format:

```text id="nhejiu"
AWS_ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/REPOSITORY:TAG
```

Example for your region:

```text id="k58h2b"
123456789012.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api:0.7.0-a1b2c3d
```

AWS ECR authentication uses `aws ecr get-login-password`, piped into `docker login` with username `AWS`. ([AWS Documentation][5])

Login:

```bash id="p2cowu"
AWS_REGION=ap-south-1
AWS_ACCOUNT_ID=123456789012

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login \
      --username AWS \
      --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
```

Create repository:

```bash id="ityydg"
aws ecr create-repository \
  --repository-name demo-node-api \
  --region ap-south-1
```

Tag:

```bash id="jn1zxg"
docker tag demo-node-api:0.7.0-a1b2c3d \
  "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/demo-node-api:0.7.0-a1b2c3d"
```

Push:

```bash id="q3h3px"
docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/demo-node-api:0.7.0-a1b2c3d"
```

Pull:

```bash id="2lq39n"
docker pull "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/demo-node-api:0.7.0-a1b2c3d"
```

For your earlier AWS issue, if repository creation fails, it is usually IAM permission related. Repository creation needs permissions such as `ecr:CreateRepository`; pushing images requires upload and put-image permissions.

---

# 8. Professional Registry Comparison

```text id="pjvyi7"
Docker Hub:
  good public ecosystem
  simple for demos and public images
  token-based automation

GHCR:
  excellent for GitHub projects
  good repo/package integration
  GitHub Actions friendly

ECR:
  best for AWS workloads
  IAM-native
  private by default
  integrates with ECS/EKS/Lambda container workflows
```

Decision guide:

```text id="u7tlql"
Portfolio GitHub project:
  GHCR

AWS production deployment:
  ECR

Public reusable image:
  Docker Hub or GHCR public package

Enterprise self-hosted:
  Harbor / Artifactory / Nexus / GitLab
```

For your course project:

```text id="iwydst"
Use GHCR first.
Then learn ECR deeply because your AWS region and Terraform/IAM work already use ap-south-1.
```

---

# 9. Professional Permission Model

A registry should not use one credential for everything.

Bad:

```text id="pfv39c"
same token for developer laptop, CI push, and production pull
```

Better:

```text id="bm422k"
developer token:
  local push/pull to dev repos

CI token:
  push release images

server token:
  pull-only

admin token:
  repository management only
```

Professional access separation:

```text id="1xajik"
build identity != deploy identity != runtime identity
```

Example permission model:

```text id="kwztvj"
CI:
  push demo-node-api

staging server:
  pull demo-node-api

production server:
  pull demo-node-api stable tags only where possible

developer:
  pull, maybe push dev tags

admin:
  manage repository policy
```

Expert rule:

```text id="14goac"
Registry credentials should be scoped by role, repository, and action.
```

---

# 10. Tag Immutability

Tag immutability prevents overwriting existing image tags.

ECR supports tag immutability; when enabled, pushing an image with an existing tag returns `ImageTagAlreadyExistsException`. ([AWS Documentation][6])

Why this matters:

```text id="oqlqlz"
same tag always points to same image
rollback is safer
audit is stronger
supply-chain attack surface is reduced
```

Good:

```text id="2jay3j"
0.7.0-a1b2c3d
0.7.1-d4e5f6g
0.8.0-rc.1-h7i8j9k
```

Bad:

```text id="02m7su"
latest overwritten repeatedly
0.7.0 overwritten after bug fix
prod tag overwritten without record
```

ECR repository creation with image tag immutability:

```bash id="n12e9h"
aws ecr create-repository \
  --repository-name demo-node-api \
  --region ap-south-1 \
  --image-tag-mutability IMMUTABLE
```

If repo already exists:

```bash id="dv95jv"
aws ecr put-image-tag-mutability \
  --repository-name demo-node-api \
  --image-tag-mutability IMMUTABLE \
  --region ap-south-1
```

Professional rule:

```text id="o03x5d"
Make release tags immutable wherever your registry supports it.
```

---

# 11. Registry Scanning

Registry scanning detects known vulnerabilities in stored images.

AWS Security Hub controls treat ECR image scanning as a security control and check whether private repositories have scan-on-push or continuous scanning configured. ([AWS Documentation][7])

ECR basic scan-on-push at repository creation:

```bash id="ndp43o"
aws ecr create-repository \
  --repository-name demo-node-api \
  --region ap-south-1 \
  --image-scanning-configuration scanOnPush=true
```

Update existing repository:

```bash id="wp1p4t"
aws ecr put-image-scanning-configuration \
  --repository-name demo-node-api \
  --image-scanning-configuration scanOnPush=true \
  --region ap-south-1
```

Describe scan findings:

```bash id="1cznkj"
aws ecr describe-image-scan-findings \
  --repository-name demo-node-api \
  --image-id imageTag=0.7.0-a1b2c3d \
  --region ap-south-1
```

Professional rule:

```text id="pkm1nq"
Scan in CI before push and scan in registry after push.
```

Why both?

```text id="6hzxov"
CI scan blocks bad builds early.
Registry scan catches stored-image risk and newer vulnerability data.
```

---

# 12. Lifecycle Policies

Registries can fill with old images.

ECR lifecycle policies use rules with priorities, tag patterns, count types, and expiration actions to manage image retention. ([AWS Documentation][8])

Bad lifecycle policy:

```text id="w8etp2"
delete all images older than 7 days
```

Risk:

```text id="mp1fya"
previous production image deleted
rollback fails
```

Better:

```text id="ilrrbc"
keep stable release tags
keep current production
keep previous production
delete old PR/dev images
delete old untagged images
```

Example ECR lifecycle policy file:

```bash id="h1w04e"
cat > ecr-lifecycle-policy.json <<'EOF'
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 30 dev images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["dev"],
        "countType": "imageCountMoreThan",
        "countNumber": 30
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Expire untagged images older than 7 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
```

Apply:

```bash id="7ao2lj"
aws ecr put-lifecycle-policy \
  --repository-name demo-node-api \
  --lifecycle-policy-text file://ecr-lifecycle-policy.json \
  --region ap-south-1
```

Professional warning:

```text id="hbb8g7"
Do not let lifecycle policies delete artifacts required for rollback or audit.
```

---

# 13. Hands-On — Create Module 7 Registry Notes

Run:

```bash id="qej02g"
cd ~/devops-masterclass/07-artifact-management-registries

nano notes/docker-registry-deep-dive.md
```

Paste:

````markdown id="thlgnp"
# Docker Registry Deep Dive

## Registry Concepts

- Registry: platform/server storing images
- Repository: collection of related images
- Tag: human-friendly image reference
- Digest: exact content identity

## Image Format

```text
registry/namespace/repository:tag
````

Examples:

```text
ghcr.io/example/demo-node-api:0.7.0-a1b2c3d
example/demo-node-api:0.7.0-a1b2c3d
123456789012.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api:0.7.0-a1b2c3d
```

## Docker Hub

```bash
docker login
docker tag demo-node-api:tag USER/demo-node-api:tag
docker push USER/demo-node-api:tag
```

## GHCR

```bash
echo "$GHCR_TOKEN" | docker login ghcr.io -u USER --password-stdin
docker tag demo-node-api:tag ghcr.io/USER/demo-node-api:tag
docker push ghcr.io/USER/demo-node-api:tag
```

## ECR

```bash
aws ecr get-login-password --region ap-south-1 \
  | docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com
```

## Production Rules

* Use immutable version-sha tags.
* Avoid latest in production.
* Use pull-only credentials on servers.
* Use push credentials only in CI.
* Enable scan on push where supported.
* Enable tag immutability where supported.
* Use lifecycle policies carefully.
* Retain rollback artifacts.
* Record image digest in release/deployment metadata.

````

---

# 14. Create Registry Environment File Example

Create:

```bash id="fdfusx"
nano examples/registry.env.example
````

Paste:

```bash id="7wkdq8"
# Registry provider: dockerhub, ghcr, ecr
REGISTRY_PROVIDER=ghcr

# Common
IMAGE_NAME=demo-node-api
IMAGE_TAG=0.7.0-a1b2c3d

# Docker Hub
DOCKERHUB_USERNAME=your-dockerhub-username
DOCKERHUB_REPOSITORY=demo-node-api

# GHCR
GITHUB_USERNAME=your-github-username
GHCR_IMAGE=ghcr.io/your-github-username/demo-node-api

# ECR
AWS_REGION=ap-south-1
AWS_ACCOUNT_ID=123456789012
ECR_REPOSITORY=demo-node-api
```

Copy for local use:

```bash id="f4god5"
cp examples/registry.env.example .registry.env
```

Do not commit real secrets or tokens.

---

# 15. Create Registry Image Name Script

Create:

```bash id="i721q5"
nano scripts/resolve-registry-image.sh
```

Paste:

```bash id="a0cw5e"
#!/usr/bin/env bash
set -euo pipefail

REGISTRY_PROVIDER="${REGISTRY_PROVIDER:-ghcr}"
IMAGE_NAME="${IMAGE_NAME:-demo-node-api}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-}"
DOCKERHUB_REPOSITORY="${DOCKERHUB_REPOSITORY:-$IMAGE_NAME}"

GITHUB_USERNAME="${GITHUB_USERNAME:-}"
GHCR_IMAGE="${GHCR_IMAGE:-}"

AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"
ECR_REPOSITORY="${ECR_REPOSITORY:-$IMAGE_NAME}"

case "$REGISTRY_PROVIDER" in
  dockerhub)
    if [ -z "$DOCKERHUB_USERNAME" ]; then
      echo "ERROR: DOCKERHUB_USERNAME is required" >&2
      exit 1
    fi
    REGISTRY_IMAGE="$DOCKERHUB_USERNAME/$DOCKERHUB_REPOSITORY"
    ;;
  ghcr)
    if [ -n "$GHCR_IMAGE" ]; then
      REGISTRY_IMAGE="$GHCR_IMAGE"
    else
      if [ -z "$GITHUB_USERNAME" ]; then
        echo "ERROR: GITHUB_USERNAME or GHCR_IMAGE is required" >&2
        exit 1
      fi
      REGISTRY_IMAGE="ghcr.io/$GITHUB_USERNAME/$IMAGE_NAME"
    fi
    ;;
  ecr)
    if [ -z "$AWS_ACCOUNT_ID" ]; then
      echo "ERROR: AWS_ACCOUNT_ID is required" >&2
      exit 1
    fi
    REGISTRY_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY"
    ;;
  *)
    echo "ERROR: unsupported REGISTRY_PROVIDER=$REGISTRY_PROVIDER" >&2
    echo "Allowed: dockerhub, ghcr, ecr" >&2
    exit 1
    ;;
esac

cat <<EOF
{
  "registry_provider": "$REGISTRY_PROVIDER",
  "registry_image": "$REGISTRY_IMAGE",
  "image_tag": "$IMAGE_TAG",
  "full_image_ref": "$REGISTRY_IMAGE:$IMAGE_TAG"
}
EOF
```

Make executable:

```bash id="u2f1zp"
chmod +x scripts/resolve-registry-image.sh
```

Test GHCR:

```bash id="4tptbw"
REGISTRY_PROVIDER=ghcr \
GITHUB_USERNAME=YOUR_GITHUB_USERNAME \
IMAGE_TAG=0.7.0-a1b2c3d \
./scripts/resolve-registry-image.sh | jq .
```

Test ECR:

```bash id="ei6x3q"
REGISTRY_PROVIDER=ecr \
AWS_ACCOUNT_ID=123456789012 \
AWS_REGION=ap-south-1 \
IMAGE_TAG=0.7.0-a1b2c3d \
./scripts/resolve-registry-image.sh | jq .
```

---

# 16. Create Registry Login Script

Create:

```bash id="oedz1a"
nano scripts/registry-login.sh
```

Paste:

```bash id="7701oc"
#!/usr/bin/env bash
set -euo pipefail

REGISTRY_PROVIDER="${REGISTRY_PROVIDER:-ghcr}"

DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-}"
DOCKERHUB_TOKEN="${DOCKERHUB_TOKEN:-}"

GITHUB_USERNAME="${GITHUB_USERNAME:-}"
GHCR_TOKEN="${GHCR_TOKEN:-}"

AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"

case "$REGISTRY_PROVIDER" in
  dockerhub)
    if [ -z "$DOCKERHUB_USERNAME" ] || [ -z "$DOCKERHUB_TOKEN" ]; then
      echo "ERROR: DOCKERHUB_USERNAME and DOCKERHUB_TOKEN are required" >&2
      exit 1
    fi

    echo "$DOCKERHUB_TOKEN" | docker login \
      -u "$DOCKERHUB_USERNAME" \
      --password-stdin
    ;;

  ghcr)
    if [ -z "$GITHUB_USERNAME" ] || [ -z "$GHCR_TOKEN" ]; then
      echo "ERROR: GITHUB_USERNAME and GHCR_TOKEN are required" >&2
      exit 1
    fi

    echo "$GHCR_TOKEN" | docker login ghcr.io \
      -u "$GITHUB_USERNAME" \
      --password-stdin
    ;;

  ecr)
    if [ -z "$AWS_ACCOUNT_ID" ]; then
      echo "ERROR: AWS_ACCOUNT_ID is required" >&2
      exit 1
    fi

    aws ecr get-login-password --region "$AWS_REGION" \
      | docker login \
          --username AWS \
          --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
    ;;

  *)
    echo "ERROR: unsupported REGISTRY_PROVIDER=$REGISTRY_PROVIDER" >&2
    exit 1
    ;;
esac

echo "Registry login completed for provider: $REGISTRY_PROVIDER"
```

Make executable:

```bash id="bb2ypp"
chmod +x scripts/registry-login.sh
```

Usage GHCR:

```bash id="fdul66"
REGISTRY_PROVIDER=ghcr \
GITHUB_USERNAME=YOUR_GITHUB_USERNAME \
GHCR_TOKEN=YOUR_TOKEN \
./scripts/registry-login.sh
```

Usage ECR:

```bash id="9tv8l0"
REGISTRY_PROVIDER=ecr \
AWS_ACCOUNT_ID=123456789012 \
AWS_REGION=ap-south-1 \
./scripts/registry-login.sh
```

Do not paste real tokens into shell history on shared machines.

---

# 17. Create Generic Registry Push Script

Create:

```bash id="h1zbvi"
nano scripts/tag-and-push-registry-image.sh
```

Paste:

```bash id="ow7sse"
#!/usr/bin/env bash
set -euo pipefail

LOCAL_IMAGE="${LOCAL_IMAGE:-demo-node-api}"
IMAGE_TAG="${IMAGE_TAG:-}"
REGISTRY_PROVIDER="${REGISTRY_PROVIDER:-ghcr}"

if [ -z "$IMAGE_TAG" ]; then
  echo "ERROR: IMAGE_TAG is required" >&2
  exit 1
fi

RESOLVE_JSON="$(REGISTRY_PROVIDER="$REGISTRY_PROVIDER" IMAGE_TAG="$IMAGE_TAG" ./scripts/resolve-registry-image.sh)"
REGISTRY_IMAGE="$(echo "$RESOLVE_JSON" | jq -r '.registry_image')"
FULL_IMAGE_REF="$(echo "$RESOLVE_JSON" | jq -r '.full_image_ref')"

echo "===== Tag and Push Registry Image ====="
echo "$RESOLVE_JSON" | jq .

echo
echo "Checking local image..."
docker image inspect "$LOCAL_IMAGE:$IMAGE_TAG" >/dev/null

echo
echo "Tagging:"
echo "$LOCAL_IMAGE:$IMAGE_TAG -> $FULL_IMAGE_REF"
docker tag "$LOCAL_IMAGE:$IMAGE_TAG" "$FULL_IMAGE_REF"

echo
echo "Pushing:"
docker push "$FULL_IMAGE_REF"

echo
echo "Inspecting local registry ref:"
docker image inspect "$FULL_IMAGE_REF" --format '{{json .RepoDigests}}' | jq . || true

echo
echo "Push completed: $FULL_IMAGE_REF"
```

Make executable:

```bash id="x100ns"
chmod +x scripts/tag-and-push-registry-image.sh
```

Usage GHCR:

```bash id="j1y6eo"
REGISTRY_PROVIDER=ghcr \
GITHUB_USERNAME=YOUR_GITHUB_USERNAME \
IMAGE_TAG=0.7.0-a1b2c3d \
./scripts/tag-and-push-registry-image.sh
```

Usage ECR:

```bash id="iee1zy"
REGISTRY_PROVIDER=ecr \
AWS_ACCOUNT_ID=123456789012 \
AWS_REGION=ap-south-1 \
IMAGE_TAG=0.7.0-a1b2c3d \
./scripts/tag-and-push-registry-image.sh
```

---

# 18. Create Registry Pull Verification Script

Create:

```bash id="tp7ryv"
nano scripts/verify-registry-pull.sh
```

Paste:

```bash id="dc8epq"
#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${IMAGE_TAG:-}"
REGISTRY_PROVIDER="${REGISTRY_PROVIDER:-ghcr}"

if [ -z "$IMAGE_TAG" ]; then
  echo "ERROR: IMAGE_TAG is required" >&2
  exit 1
fi

RESOLVE_JSON="$(REGISTRY_PROVIDER="$REGISTRY_PROVIDER" IMAGE_TAG="$IMAGE_TAG" ./scripts/resolve-registry-image.sh)"
FULL_IMAGE_REF="$(echo "$RESOLVE_JSON" | jq -r '.full_image_ref')"

echo "===== Verify Registry Pull ====="
echo "$RESOLVE_JSON" | jq .

echo
echo "Pulling image:"
docker pull "$FULL_IMAGE_REF"

echo
echo "Image details:"
docker image inspect "$FULL_IMAGE_REF" \
  --format 'ID={{.Id}} Created={{.Created}} RepoDigests={{json .RepoDigests}}'

echo
echo "Running quick non-root check:"
docker run --rm --entrypoint id "$FULL_IMAGE_REF"

echo
echo "Registry pull verification completed."
```

Make executable:

```bash id="is92eq"
chmod +x scripts/verify-registry-pull.sh
```

Usage:

```bash id="xmzcde"
REGISTRY_PROVIDER=ghcr \
GITHUB_USERNAME=YOUR_GITHUB_USERNAME \
IMAGE_TAG=0.7.0-a1b2c3d \
./scripts/verify-registry-pull.sh
```

---

# 19. ECR Repository Setup Script

Create:

```bash id="zq36i5"
nano scripts/setup-ecr-repository.sh
```

Paste:

```bash id="9x590z"
#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
ECR_REPOSITORY="${ECR_REPOSITORY:-demo-node-api}"
TAG_MUTABILITY="${TAG_MUTABILITY:-IMMUTABLE}"
SCAN_ON_PUSH="${SCAN_ON_PUSH:-true}"

echo "===== Setup ECR Repository ====="
echo "Repository: $ECR_REPOSITORY"
echo "Region: $AWS_REGION"
echo "Tag mutability: $TAG_MUTABILITY"
echo "Scan on push: $SCAN_ON_PUSH"

if aws ecr describe-repositories \
  --repository-names "$ECR_REPOSITORY" \
  --region "$AWS_REGION" >/dev/null 2>&1; then

  echo "Repository already exists. Updating settings..."

  aws ecr put-image-tag-mutability \
    --repository-name "$ECR_REPOSITORY" \
    --image-tag-mutability "$TAG_MUTABILITY" \
    --region "$AWS_REGION"

  aws ecr put-image-scanning-configuration \
    --repository-name "$ECR_REPOSITORY" \
    --image-scanning-configuration scanOnPush="$SCAN_ON_PUSH" \
    --region "$AWS_REGION"

else
  echo "Creating repository..."

  aws ecr create-repository \
    --repository-name "$ECR_REPOSITORY" \
    --image-tag-mutability "$TAG_MUTABILITY" \
    --image-scanning-configuration scanOnPush="$SCAN_ON_PUSH" \
    --region "$AWS_REGION"
fi

echo
echo "Repository details:"
aws ecr describe-repositories \
  --repository-names "$ECR_REPOSITORY" \
  --region "$AWS_REGION" \
  | jq .
```

Make executable:

```bash id="x810fw"
chmod +x scripts/setup-ecr-repository.sh
```

Run when AWS permissions are available:

```bash id="p8i0b4"
AWS_REGION=ap-south-1 \
ECR_REPOSITORY=demo-node-api \
./scripts/setup-ecr-repository.sh
```

If you get `AccessDeniedException`, your IAM user/role needs ECR permissions.

---

# 20. ECR Lifecycle Policy Script

Create:

```bash id="iezvif"
nano scripts/apply-ecr-lifecycle-policy.sh
```

Paste:

```bash id="gdhz3z"
#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
ECR_REPOSITORY="${ECR_REPOSITORY:-demo-node-api}"
POLICY_FILE="${POLICY_FILE:-examples/ecr-lifecycle-policy.json}"

if [ ! -f "$POLICY_FILE" ]; then
  echo "ERROR: policy file not found: $POLICY_FILE" >&2
  exit 1
fi

echo "===== Apply ECR Lifecycle Policy ====="
echo "Repository: $ECR_REPOSITORY"
echo "Region: $AWS_REGION"
echo "Policy: $POLICY_FILE"

aws ecr put-lifecycle-policy \
  --repository-name "$ECR_REPOSITORY" \
  --lifecycle-policy-text "file://$POLICY_FILE" \
  --region "$AWS_REGION"

echo
echo "Lifecycle policy applied."
aws ecr get-lifecycle-policy \
  --repository-name "$ECR_REPOSITORY" \
  --region "$AWS_REGION" \
  | jq .
```

Create policy file:

```bash id="5f08cw"
nano examples/ecr-lifecycle-policy.json
```

Paste:

```json id="oay4mr"
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire old dev images beyond last 30",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["dev"],
        "countType": "imageCountMoreThan",
        "countNumber": 30
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Expire untagged images older than 7 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

Make executable:

```bash id="mb61gn"
chmod +x scripts/apply-ecr-lifecycle-policy.sh
```

Run:

```bash id="20dbiv"
AWS_REGION=ap-south-1 \
ECR_REPOSITORY=demo-node-api \
./scripts/apply-ecr-lifecycle-policy.sh
```

---

# 21. Registry Troubleshooting Playbook

Create:

```bash id="bm1u1z"
nano notes/registry-troubleshooting-playbook.md
```

Paste:

````markdown id="3un3m0"
# Registry Troubleshooting Playbook

## Problem: docker push denied

Check:

```bash
docker login
docker image ls
docker tag SOURCE TARGET
docker push TARGET
````

Common causes:

* not logged in
* wrong registry URL
* wrong namespace
* repository does not exist
* token lacks push permission
* tag immutability blocks overwrite

## Problem: docker pull denied

Common causes:

* private image
* server not logged in
* token expired
* token lacks read permission
* wrong image name
* wrong tag

## Problem: ECR login fails

Check:

```bash
aws sts get-caller-identity
aws ecr get-login-password --region ap-south-1
```

## Problem: ECR repository creation denied

Likely missing:

```text
ecr:CreateRepository
```

## Problem: ECR push denied

Likely missing:

```text
ecr:BatchCheckLayerAvailability
ecr:InitiateLayerUpload
ecr:UploadLayerPart
ecr:CompleteLayerUpload
ecr:PutImage
```

## Problem: Image tag already exists

If tag immutability is enabled, pushing the same tag again fails.

Fix:

* use a new immutable tag
* do not overwrite release tags
* only disable immutability with approval

## Problem: Rollback image missing

Causes:

* lifecycle policy deleted old image
* tag was overwritten
* image was never pushed
* wrong registry

Fix:

* keep stable releases
* keep previous production artifact
* record digest
* test rollback

````

---

# 22. Corporate Registry Architecture

A mature company may have:

```text id="855q72"
developer laptops
  ↓ push dev images maybe
CI runners
  ↓ push signed/scanned images
central registry
  ↓ pull
dev/staging/prod clusters
````

Production registry controls:

```text id="50y1u8"
private repositories
least-privilege credentials
tag immutability
scan on push
lifecycle policies
audit logs
image signing
SBOM/provenance storage
promotion approvals
network restrictions
```

Common corporate separation:

```text id="2icbfl"
dev registry/repository:
  fast-moving, short retention

staging registry/repository:
  release candidates

production registry/repository:
  approved immutable releases
```

Or same repository with controlled tags:

```text id="z1fz3x"
demo-node-api:dev-a1b2c3d
demo-node-api:0.7.0-rc.1-a1b2c3d
demo-node-api:0.7.0-a1b2c3d
```

Professional preference:

```text id="sfp53o"
Use immutable tags and promotion records, not mutable environment tags as the only source of truth.
```

---

# 23. GitHub Actions Registry Workflow Example

Create:

```bash id="2i3k7m"
nano examples/github-actions-registry-push.yml
```

Paste:

```yaml id="5940l6"
name: Registry Push Example

on:
  push:
    branches: [main]
    tags:
      - "v*"

permissions:
  contents: read
  packages: write

env:
  APP_DIR: 05-application-runtime/demo-node-api
  IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/demo-node-api

jobs:
  build-and-push:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Compute tag
        id: version
        shell: bash
        run: |
          SHORT_SHA="${GITHUB_SHA::7}"

          if [[ "${GITHUB_REF_TYPE}" == "tag" ]]; then
            BASE_VERSION="${GITHUB_REF_NAME#v}"
          else
            BASE_VERSION="0.7.0-dev"
          fi

          DEPLOY_TAG="${BASE_VERSION}-${SHORT_SHA}"

          echo "short_sha=$SHORT_SHA" >> "$GITHUB_OUTPUT"
          echo "deploy_tag=$DEPLOY_TAG" >> "$GITHUB_OUTPUT"

      - name: Login to GHCR
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push image
        uses: docker/build-push-action@v6
        with:
          context: ${{ env.APP_DIR }}
          file: ${{ env.APP_DIR }}/Dockerfile.industry
          target: runtime
          push: true
          tags: |
            ${{ env.IMAGE_NAME }}:${{ steps.version.outputs.deploy_tag }}
            ${{ env.IMAGE_NAME }}:${{ steps.version.outputs.short_sha }}
          build-args: |
            APP_VERSION=${{ steps.version.outputs.deploy_tag }}
            COMMIT_SHA=${{ steps.version.outputs.short_sha }}
          sbom: true
          provenance: true
```

This workflow:

```text id="y7lm3i"
computes immutable tag
logs into GHCR
builds image
pushes image
adds SBOM/provenance metadata
```

---

# 24. Registry Operations Runbook

Create:

```bash id="9zy45s"
nano notes/registry-operations-runbook.md
```

Paste:

````markdown id="2xw5wy"
# Registry Operations Runbook

## Resolve Image Name

```bash
REGISTRY_PROVIDER=ghcr GITHUB_USERNAME=USER IMAGE_TAG=0.7.0-a1b2c3d ./scripts/resolve-registry-image.sh
````

## Login

```bash
REGISTRY_PROVIDER=ghcr GITHUB_USERNAME=USER GHCR_TOKEN=TOKEN ./scripts/registry-login.sh
```

## Push

```bash
REGISTRY_PROVIDER=ghcr GITHUB_USERNAME=USER IMAGE_TAG=0.7.0-a1b2c3d ./scripts/tag-and-push-registry-image.sh
```

## Verify Pull

```bash
REGISTRY_PROVIDER=ghcr GITHUB_USERNAME=USER IMAGE_TAG=0.7.0-a1b2c3d ./scripts/verify-registry-pull.sh
```

## ECR Setup

```bash
AWS_REGION=ap-south-1 ECR_REPOSITORY=demo-node-api ./scripts/setup-ecr-repository.sh
```

## ECR Lifecycle Policy

```bash
AWS_REGION=ap-south-1 ECR_REPOSITORY=demo-node-api ./scripts/apply-ecr-lifecycle-policy.sh
```

## Production Rules

* CI pushes images.
* Servers pull images.
* Use read-only server credentials.
* Do not overwrite release tags.
* Enable immutability where supported.
* Enable scanning where supported.
* Keep rollback artifacts.

````

---

# 25. Update Makefile

Open:

```bash id="4lhy9f"
cd ~/devops-masterclass/07-artifact-management-registries

nano Makefile
````

Add these targets:

```Makefile id="nqlbtr"
.PHONY: resolve-image registry-login registry-push registry-pull ecr-setup ecr-lifecycle

resolve-image:
	./scripts/resolve-registry-image.sh | jq .

registry-login:
	./scripts/registry-login.sh

registry-push:
	@test -n "$(IMAGE_TAG)" || (echo "Usage: make registry-push IMAGE_TAG=<tag> REGISTRY_PROVIDER=ghcr" && exit 1)
	IMAGE_TAG="$(IMAGE_TAG)" ./scripts/tag-and-push-registry-image.sh

registry-pull:
	@test -n "$(IMAGE_TAG)" || (echo "Usage: make registry-pull IMAGE_TAG=<tag> REGISTRY_PROVIDER=ghcr" && exit 1)
	IMAGE_TAG="$(IMAGE_TAG)" ./scripts/verify-registry-pull.sh

ecr-setup:
	./scripts/setup-ecr-repository.sh

ecr-lifecycle:
	./scripts/apply-ecr-lifecycle-policy.sh
```

Example use:

```bash id="i8ap48"
make resolve-image REGISTRY_PROVIDER=ghcr GITHUB_USERNAME=YOUR_GITHUB_USERNAME IMAGE_TAG=0.7.0-a1b2c3d
make registry-push REGISTRY_PROVIDER=ghcr GITHUB_USERNAME=YOUR_GITHUB_USERNAME IMAGE_TAG=0.7.0-a1b2c3d
```

Note: Make variables need to be exported to subprocesses in some shells. If they do not pass, use direct command style:

```bash id="ow2iqy"
REGISTRY_PROVIDER=ghcr GITHUB_USERNAME=YOUR_GITHUB_USERNAME IMAGE_TAG=0.7.0-a1b2c3d make resolve-image
```

---

# 26. End-to-End Local Registry Flow

Compute version:

```bash id="u2kvao"
cd ~/devops-masterclass/07-artifact-management-registries

VERSION_JSON="$(BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"

echo "$DEPLOY_TAG"
```

Build image:

```bash id="4xkslm"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
```

Login to GHCR:

```bash id="9kofix"
cd ~/devops-masterclass/07-artifact-management-registries

REGISTRY_PROVIDER=ghcr \
GITHUB_USERNAME=YOUR_GITHUB_USERNAME \
GHCR_TOKEN=YOUR_TOKEN \
./scripts/registry-login.sh
```

Push:

```bash id="f9mj8j"
REGISTRY_PROVIDER=ghcr \
GITHUB_USERNAME=YOUR_GITHUB_USERNAME \
IMAGE_TAG="$DEPLOY_TAG" \
./scripts/tag-and-push-registry-image.sh
```

Verify pull:

```bash id="grhqyg"
REGISTRY_PROVIDER=ghcr \
GITHUB_USERNAME=YOUR_GITHUB_USERNAME \
IMAGE_TAG="$DEPLOY_TAG" \
./scripts/verify-registry-pull.sh
```

Deploy registry image with Compose:

```bash id="yvvrdi"
cd ~/devops-masterclass/06-docker-containers/compose-demo

APP_IMAGE=ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api \
APP_VERSION="$DEPLOY_TAG" \
COMPOSE_FILES="compose.yaml compose.prod.yaml" \
./scripts/deploy-compose.sh
```

Validate:

```bash id="nu43r7"
curl -s http://127.0.0.1:8080/version | jq .
docker inspect compose-demo-backend --format '{{.Config.Image}}'
```

---

# 27. ECR Flow for Your AWS Practice

Use this when IAM permissions are ready.

```bash id="9ml835"
cd ~/devops-masterclass/07-artifact-management-registries

AWS_REGION=ap-south-1 \
ECR_REPOSITORY=demo-node-api \
./scripts/setup-ecr-repository.sh
```

Login:

```bash id="k9saa8"
REGISTRY_PROVIDER=ecr \
AWS_REGION=ap-south-1 \
AWS_ACCOUNT_ID=YOUR_ACCOUNT_ID \
./scripts/registry-login.sh
```

Push:

```bash id="dz33mw"
REGISTRY_PROVIDER=ecr \
AWS_REGION=ap-south-1 \
AWS_ACCOUNT_ID=YOUR_ACCOUNT_ID \
IMAGE_TAG="$DEPLOY_TAG" \
./scripts/tag-and-push-registry-image.sh
```

Deploy:

```bash id="f9qw9z"
cd ~/devops-masterclass/06-docker-containers/compose-demo

APP_IMAGE=YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api \
APP_VERSION="$DEPLOY_TAG" \
COMPOSE_FILES="compose.yaml compose.prod.yaml" \
./scripts/deploy-compose.sh
```

---

# 28. Professional Registry Security Checklist

```text id="0bxa15"
Repository is private for private apps.
CI has push access.
Servers have pull-only access.
Personal passwords are not used in CI.
Release tags are immutable.
latest is not used for production.
Scan-on-push is enabled where available.
Lifecycle policy protects rollback artifacts.
Registry access is audited.
Secrets are not baked into images.
Deployment metadata records image tag and digest.
```

---

# 29. Troubleshooting Examples

## `denied: requested access to the resource is denied`

Possible causes:

```text id="iho3am"
not logged in
wrong namespace
token lacks permission
repository does not exist
trying to push to someone else's namespace
```

Check:

```bash id="nyz35r"
docker login ghcr.io
docker image ls | grep demo-node-api
docker tag demo-node-api:$DEPLOY_TAG ghcr.io/YOUR_USER/demo-node-api:$DEPLOY_TAG
docker push ghcr.io/YOUR_USER/demo-node-api:$DEPLOY_TAG
```

---

## `ImageTagAlreadyExistsException` in ECR

Meaning:

```text id="drb77j"
tag immutability is enabled and you tried to overwrite an existing tag
```

Correct fix:

```text id="5e1v8g"
create a new tag
```

Wrong fix:

```text id="or03as"
disable immutability just to overwrite a release tag
```

---

## Server cannot pull image

Check on server:

```bash id="ghj0u4"
docker pull ghcr.io/YOUR_USER/demo-node-api:$DEPLOY_TAG
```

If private GHCR package:

```bash id="n1tgny"
echo "$GHCR_READ_TOKEN" | docker login ghcr.io -u YOUR_USER --password-stdin
```

Check Compose `.env`:

```bash id="mspv7k"
cat .env
```

Check running image:

```bash id="j6lcy9"
docker inspect compose-demo-backend --format '{{.Config.Image}}'
```

---

## ECR repository creation fails

Check identity:

```bash id="bjuxk0"
aws sts get-caller-identity
```

Likely missing:

```text id="xasjgw"
ecr:CreateRepository
```

If this happens in your AWS account, create repo through Terraform/Admin-approved IAM or ask for permissions.

---

# 30. Interview Explanation

## What is a Docker registry?

Strong answer:

```text id="b41v1x"
A Docker registry stores container images. It contains repositories, and each repository contains image versions identified by tags and digests. CI pushes images to the registry, and servers or orchestrators pull images from it during deployment.
```

## Difference between Docker Hub, GHCR, and ECR?

Strong answer:

```text id="3w9qzg"
Docker Hub is Docker’s general-purpose public/private registry. GHCR is GitHub’s container registry and integrates well with GitHub repositories and GitHub Actions. ECR is AWS’s managed container registry and integrates with IAM, ECS, EKS, and other AWS services.
```

## How do you authenticate to ECR?

Strong answer:

```text id="jc7i3b"
For ECR, I use AWS CLI to generate a temporary registry password with `aws ecr get-login-password --region REGION` and pipe it to `docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.REGION.amazonaws.com`.
```

## What is tag immutability?

Strong answer:

```text id="m6hwju"
Tag immutability prevents an existing tag from being overwritten. This improves auditability and rollback safety because a tag always points to the same image content once pushed.
```

## What registry permissions should production servers have?

Strong answer:

```text id="a2i0sv"
Production servers should usually have pull-only access to the specific repositories they need. They should not have push or admin permissions. CI should have push permission, and repository administration should be limited to platform or DevOps admins.
```

## How do lifecycle policies affect rollback?

Strong answer:

```text id="rzfhgz"
Lifecycle policies clean old images, but if they are too aggressive, they can delete images needed for rollback. I design policies to keep current production, previous production, stable releases, and required audit artifacts while deleting old dev, PR, and untagged images.
```

---

# Today’s Core Rules

```text id="9r7jam"
A registry stores container artifacts.
A repository stores related image versions.
A tag is a pointer.
A digest is exact content identity.
Use GHCR for GitHub-native workflows.
Use ECR for AWS-native workloads.
Use Docker Hub for public/general images.
Use tokens, not passwords, for automation.
CI should push.
Servers should pull.
Production servers should use pull-only credentials.
Use immutable version-sha tags.
Enable tag immutability where possible.
Enable scanning where possible.
Use lifecycle policies carefully.
Protect rollback artifacts.
Record image tag and digest in metadata.
```

---

# Commit Work

Run:

```bash id="k8or8p"
cd ~/devops-masterclass

git status
git add 07-artifact-management-registries

git commit -m "feat: add Docker registry deep dive workflows"
git push
```

---

# Next Lesson

# Lesson 7.5 — Amazon ECR Production Workflow Deep Dive

We will go deeper into:

```text id="dmq9ad"
ECR repository creation
IAM policies for push/pull
GitHub Actions OIDC to AWS
scan-on-push
tag immutability
lifecycle policies
Terraform-managed ECR
repository policies
cross-account pull patterns
ECR troubleshooting
AWS production best practices
```

[1]: https://docs.docker.com/docker-hub/repos/?utm_source=chatgpt.com "Repositories"
[2]: https://docs.docker.com/security/access-tokens/?utm_source=chatgpt.com "Personal access tokens"
[3]: https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry?utm_source=chatgpt.com "Working with the Container registry"
[4]: https://docs.github.com/en/actions/concepts/security/github_token?utm_source=chatgpt.com "GITHUB_TOKEN"
[5]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-create.html?utm_source=chatgpt.com "Creating an Amazon ECR private repository to store images"
[6]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-tag-mutability.html?utm_source=chatgpt.com "Preventing image tags from being overwritten in Amazon ECR"
[7]: https://docs.aws.amazon.com/securityhub/latest/userguide/ecr-controls.html?utm_source=chatgpt.com "Security Hub CSPM controls for Amazon ECR"
[8]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/lifecycle_policy_examples.html?utm_source=chatgpt.com "Examples of lifecycle policies in Amazon ECR"

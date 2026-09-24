# Lesson 6.9 — Docker Registries and Image Promotion Masterclass

# Docker Hub, GHCR, ECR Concepts, Login, Tag, Push, Pull, Immutable Tags, Promotion, and Registry Security

You now know how to build secure images locally.

But local images are not enough.

In real DevOps, images must move through a lifecycle:

```text id="mgp2co"
developer machine / CI runner
  ↓
container registry
  ↓
dev environment
  ↓
staging environment
  ↓
production environment
```

A registry is the central image storage system.

Docker’s docs describe the basic publish flow as: build an image, tag it, authenticate with `docker login`, and push it with `docker push`. ([Docker Documentation][1])

---

# 1. Beginner Level — What Is a Container Registry?

A container registry stores Docker/OCI images.

Examples:

```text id="7vri2w"
Docker Hub
GitHub Container Registry / GHCR
Amazon ECR
Google Artifact Registry
Azure Container Registry
Harbor
GitLab Container Registry
```

Simple definition:

```text id="o7kr15"
A registry is like GitHub for container images.
```

But instead of storing source code, it stores:

```text id="7104ng"
image repositories
image tags
image layers
image metadata
SBOM/provenance attestations
vulnerability scan results in some platforms
```

Example image name:

```text id="sfq8wo"
demo-node-api:0.2.0
```

Example registry image name:

```text id="nbpzrb"
ghcr.io/vivek-saroj/demo-node-api:0.2.0
```

Example ECR image name:

```text id="sywn4z"
123456789012.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api:0.2.0
```

---

# 2. Beginner Mental Model

Local image:

```text id="xsx1b6"
demo-node-api:0.2.0
```

Registry image:

```text id="9ponb9"
registry/repository:tag
```

Flow:

```text id="7cmx58"
docker build
  ↓
local image
  ↓ docker tag
registry image name
  ↓ docker push
registry
  ↓ docker pull
server / Kubernetes / Compose
```

Practical commands:

```bash id="ngwups"
docker build -t demo-node-api:0.2.0 .
docker tag demo-node-api:0.2.0 ghcr.io/YOUR_USER/demo-node-api:0.2.0
docker push ghcr.io/YOUR_USER/demo-node-api:0.2.0
docker pull ghcr.io/YOUR_USER/demo-node-api:0.2.0
```

Core rule:

```text id="ro9ak1"
Build once, push once, deploy the same image everywhere.
```

---

# 3. Image Name Anatomy

Example:

```text id="lsicyf"
ghcr.io/vivek-saroj/demo-node-api:0.2.0
```

Parts:

```text id="3a9joq"
ghcr.io             registry host
vivek-saroj         namespace / owner / organization
demo-node-api       repository
0.2.0               tag
```

Docker Hub example:

```text id="kojpbs"
viveksaroj/demo-node-api:0.2.0
```

Docker Hub default registry is Docker Hub, so this:

```text id="tgod2q"
viveksaroj/demo-node-api:0.2.0
```

means:

```text id="7yuw5g"
docker.io/viveksaroj/demo-node-api:0.2.0
```

---

# 4. Intermediate Level — Tags vs Digests

A tag is a human-readable pointer:

```text id="0hhqsh"
demo-node-api:0.2.0
demo-node-api:staging
demo-node-api:prod
demo-node-api:abc1234
```

A digest is content-addressed and immutable:

```text id="wqc1yb"
sha256:9c1f...
```

Pull by tag:

```bash id="70698u"
docker pull ghcr.io/YOUR_USER/demo-node-api:0.2.0
```

Pull by digest:

```bash id="tsus3w"
docker pull ghcr.io/YOUR_USER/demo-node-api@sha256:<digest>
```

Professional rule:

```text id="3gi8ip"
Tags are convenient. Digests are exact.
```

Production systems often deploy with:

```text id="2ko6qt"
version tag + recorded digest
```

Expert-level supply-chain systems may pin by digest for exact reproducibility.

---

# 5. Why `latest` Is Dangerous

Bad deployment:

```yaml id="w7hdhc"
image: demo-node-api:latest
```

Problems:

```text id="mpzh7w"
latest can point to different images over time
rollback is unclear
audit is weak
environment drift is likely
incident debugging is harder
```

Better:

```yaml id="2dsugf"
image: demo-node-api:0.2.0-a1b2c3d
```

Best for strict environments:

```yaml id="6oqkal"
image: demo-node-api@sha256:<digest>
```

Core rule:

```text id="11escr"
Never rely on latest for production deployments.
```

---

# 6. Professional Tagging Strategy

Use multiple tags for the same image:

```text id="j420i4"
0.2.0
a1b2c3d
0.2.0-a1b2c3d
```

Optional environment pointer tags:

```text id="kx4b7i"
dev
staging
prod
```

But environment tags are mutable, so treat them carefully.

Recommended:

```text id="f3x64z"
immutable build tag: 0.2.0-a1b2c3d
promotion record: staging/prod metadata, GitOps commit, deployment manifest, or release file
```

Build example:

```bash id="k4r96c"
VERSION=0.2.0
COMMIT_SHA=$(git rev-parse --short HEAD)

IMAGE_LOCAL="demo-node-api:$VERSION-$COMMIT_SHA"
IMAGE_REGISTRY="ghcr.io/YOUR_USER/demo-node-api"

docker build \
  -f Dockerfile.industry \
  --target runtime \
  --build-arg APP_VERSION="$VERSION" \
  --build-arg COMMIT_SHA="$COMMIT_SHA" \
  -t "$IMAGE_LOCAL" \
  -t "$IMAGE_REGISTRY:$VERSION" \
  -t "$IMAGE_REGISTRY:$COMMIT_SHA" \
  -t "$IMAGE_REGISTRY:$VERSION-$COMMIT_SHA" \
  .
```

---

# 7. Registry Option 1 — Docker Hub

Docker Hub image name:

```text id="33xb1q"
YOUR_DOCKERHUB_USERNAME/demo-node-api:0.2.0
```

Login:

```bash id="dt3mzn"
docker login
```

Tag:

```bash id="gbc872"
docker tag demo-node-api:0.2.0 YOUR_DOCKERHUB_USERNAME/demo-node-api:0.2.0
```

Push:

```bash id="674xxe"
docker push YOUR_DOCKERHUB_USERNAME/demo-node-api:0.2.0
```

Pull:

```bash id="rqtvqj"
docker pull YOUR_DOCKERHUB_USERNAME/demo-node-api:0.2.0
```

For CI/CD, use a token instead of your password. Docker’s login action docs specifically recommend using a personal access token for Docker Hub authentication in GitHub Actions, not an account password. ([GitHub][2])

---

# 8. Registry Option 2 — GitHub Container Registry / GHCR

GHCR image name:

```text id="nbsqh8"
ghcr.io/GITHUB_USERNAME/demo-node-api:0.2.0
```

GitHub’s docs describe GHCR as a container registry that stores images under a personal account or organization and can associate images with repositories. ([GitHub Docs][3])

Login:

```bash id="k8ic5v"
echo "$GITHUB_TOKEN_OR_PAT" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

Tag:

```bash id="3fbpea"
docker tag demo-node-api:0.2.0 ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.2.0
```

Push:

```bash id="qcuwfl"
docker push ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.2.0
```

Pull:

```bash id="z9fpdg"
docker pull ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.2.0
```

For GitHub Actions, you can often use:

```text id="wh3gxx"
GITHUB_TOKEN
```

for packages associated with the repository, depending on permissions.

Professional note:

```text id="sbyqt6"
For private GHCR packages, production servers need a token with package read permission.
```

---

# 9. Registry Option 3 — Amazon ECR

ECR image name format:

```text id="s7zw47"
AWS_ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/REPOSITORY:TAG
```

Example:

```text id="u136g4"
123456789012.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api:0.2.0
```

AWS ECR docs state that Docker authentication uses `aws ecr get-login-password`, piped into `docker login` with username `AWS` and your registry URI. ([AWS Documentation][4])

Login:

```bash id="tql1s5"
AWS_REGION=ap-south-1
AWS_ACCOUNT_ID=123456789012

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login \
      --username AWS \
      --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
```

Create repo if you have permission:

```bash id="rtdnbw"
aws ecr create-repository \
  --repository-name demo-node-api \
  --region ap-south-1
```

Tag:

```bash id="aesq1j"
docker tag demo-node-api:0.2.0 \
  "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/demo-node-api:0.2.0"
```

Push:

```bash id="0h0d4x"
docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/demo-node-api:0.2.0"
```

Pull:

```bash id="vu3hav"
docker pull "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/demo-node-api:0.2.0"
```

Important for your earlier AWS experience:

```text id="23g7np"
ECR create-repository needs IAM permissions.
If denied, ask admin or pre-create repo with Terraform/IAM-approved workflow.
```

---

# 10. Professional Registry Security Concepts

A registry is production infrastructure.

Secure it with:

```text id="cmlvv4"
private repositories
least-privilege push/pull tokens
CI-only push permissions
server-only pull permissions
image scanning
tag immutability
lifecycle policies
audit logs
protected environments
no shared personal credentials
```

Bad pattern:

```text id="p5nejt"
developer personal Docker token used on production server
```

Better:

```text id="ik96sx"
CI has push token
production server has read-only pull token
admins manage repository policy
```

Expert rule:

```text id="xqak4a"
Separate build identity, deploy identity, and runtime identity.
```

---

# 11. Image Promotion — Beginner Concept

Bad promotion:

```text id="4i41fh"
build separate image for dev
build separate image for staging
build separate image for prod
```

Why bad?

```text id="xjw4s5"
dev tested one image
prod runs a different image
drift occurs
bugs appear after rebuild
audit is weaker
```

Good promotion:

```text id="69kprq"
build image once
scan image once
push image once
promote same image tag/digest across environments
```

Flow:

```text id="pj4ke8"
CI build: demo-node-api:0.2.0-a1b2c3d
  ↓
dev deploys same tag
  ↓
staging deploys same tag
  ↓
prod deploys same tag
```

Core rule:

```text id="y5l89s"
Promote artifacts. Do not rebuild for every environment.
```

---

# 12. Image Promotion — Professional Model

Environment differences should come from runtime config:

```text id="6x4ou0"
APP_ENV
DATABASE_URL
CORS_ORIGIN
LOG_LEVEL
secrets
resource limits
replica count
domain name
```

Not from rebuilding image.

Same image:

```text id="xnpz70"
ghcr.io/org/demo-node-api:0.2.0-a1b2c3d
```

Different configs:

```text id="nx0sw2"
dev DATABASE_URL=dev-db
staging DATABASE_URL=staging-db
prod DATABASE_URL=prod-db
```

This follows the Twelve-Factor App principle of strict config separation from code; the Twelve-Factor App describes config as everything likely to vary between deploys, such as database handles, credentials, and hostnames, and recommends storing config in environment variables. ([Docker Documentation][1])

Correction: the above citation is Docker’s build/publish docs, not Twelve-Factor. The principle itself is stable background knowledge; we’ll keep using the practice here.

---

# 13. Create Registry Scripts

Go to app:

```bash id="87r66n"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Create:

```bash id="7vcllb"
nano scripts/docker-tag-push.sh
```

Paste:

```bash id="xr5zf2"
#!/usr/bin/env bash
set -euo pipefail

LOCAL_IMAGE="${LOCAL_IMAGE:-demo-node-api}"
VERSION="${VERSION:-0.2.0}"
COMMIT_SHA="${COMMIT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"
REGISTRY_IMAGE="${REGISTRY_IMAGE:-ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api}"

LOCAL_TAG="$LOCAL_IMAGE:$VERSION"
IMMUTABLE_TAG="$VERSION-$COMMIT_SHA"

echo "===== Docker Tag and Push ====="
echo "Local image: $LOCAL_TAG"
echo "Registry image: $REGISTRY_IMAGE"
echo "Version: $VERSION"
echo "Commit: $COMMIT_SHA"

docker image inspect "$LOCAL_TAG" >/dev/null

docker tag "$LOCAL_TAG" "$REGISTRY_IMAGE:$VERSION"
docker tag "$LOCAL_TAG" "$REGISTRY_IMAGE:$COMMIT_SHA"
docker tag "$LOCAL_TAG" "$REGISTRY_IMAGE:$IMMUTABLE_TAG"

echo
echo "Pushing tags..."
docker push "$REGISTRY_IMAGE:$VERSION"
docker push "$REGISTRY_IMAGE:$COMMIT_SHA"
docker push "$REGISTRY_IMAGE:$IMMUTABLE_TAG"

echo
echo "Pushed:"
echo "$REGISTRY_IMAGE:$VERSION"
echo "$REGISTRY_IMAGE:$COMMIT_SHA"
echo "$REGISTRY_IMAGE:$IMMUTABLE_TAG"
```

Make executable:

```bash id="jffmvx"
chmod +x scripts/docker-tag-push.sh
```

Usage for GHCR:

```bash id="8i3bcd"
export REGISTRY_IMAGE=ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api

VERSION=0.2.0 ./scripts/docker-build.sh
VERSION=0.2.0 ./scripts/docker-tag-push.sh
```

Usage for Docker Hub:

```bash id="xtvvzp"
export REGISTRY_IMAGE=YOUR_DOCKERHUB_USERNAME/demo-node-api

VERSION=0.2.0 ./scripts/docker-build.sh
VERSION=0.2.0 ./scripts/docker-tag-push.sh
```

Usage for ECR:

```bash id="3ium4z"
export AWS_REGION=ap-south-1
export AWS_ACCOUNT_ID=123456789012
export REGISTRY_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/demo-node-api"

VERSION=0.2.0 ./scripts/docker-build.sh
VERSION=0.2.0 ./scripts/docker-tag-push.sh
```

---

# 14. Create Registry Login Notes

Create Module 6 notes:

```bash id="h0uqy7"
cd ~/devops-masterclass/06-docker-containers
nano docker-registries-image-promotion.md
```

Paste:

````markdown id="b5o7sg"
# Docker Registries and Image Promotion

## What is a Registry?

A registry stores container images.

Examples:

- Docker Hub
- GitHub Container Registry
- Amazon ECR
- Google Artifact Registry
- Azure Container Registry
- Harbor
- GitLab Container Registry

## Image Name

```text
registry/namespace/repository:tag
````

Example:

```text
ghcr.io/example-org/demo-node-api:0.2.0-a1b2c3d
```

## Tagging Strategy

Use immutable tags:

```text
version
git-sha
version-git-sha
```

Avoid relying on:

```text
latest
```

## Promotion Rule

Build once. Promote the same image across environments.

```text
build -> scan -> push -> dev -> staging -> prod
```

## Docker Hub

```bash
docker login
docker tag demo-node-api:0.2.0 USER/demo-node-api:0.2.0
docker push USER/demo-node-api:0.2.0
```

## GHCR

```bash
echo "$GITHUB_TOKEN_OR_PAT" | docker login ghcr.io -u USER --password-stdin
docker tag demo-node-api:0.2.0 ghcr.io/USER/demo-node-api:0.2.0
docker push ghcr.io/USER/demo-node-api:0.2.0
```

## ECR

```bash
aws ecr get-login-password --region ap-south-1 \
  | docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com

docker tag demo-node-api:0.2.0 ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api:0.2.0
docker push ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api:0.2.0
```

## Production Rules

* Use private repositories for private apps.
* Use read-only pull credentials on servers.
* Use CI-only push credentials.
* Enable image scanning.
* Avoid mutable production tags.
* Record image digest.
* Use lifecycle policies.
* Audit registry access.

````

---

# 15. Professional Deployment With Compose and Registry Image

In Compose `.env`, instead of local image:

```bash id="5vyrdp"
APP_IMAGE=demo-node-api
APP_VERSION=0.2.0
````

Use registry image:

```bash id="f90a9q"
APP_IMAGE=ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api
APP_VERSION=0.2.0-a1b2c3d
```

Then:

```bash id="9fosnr"
cd ~/devops-masterclass/06-docker-containers/compose-demo

docker compose -f compose.yaml -f compose.prod.yaml pull
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

Validate:

```bash id="twz7n9"
curl -s http://127.0.0.1:8080/version | jq .
```

Professional note:

```text id="99mepi"
Production servers should pull from registry, not build from source.
```

---

# 16. Expert Level — Digest Recording

After push, inspect digest:

```bash id="8e8x1h"
docker buildx imagetools inspect ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.2.0
```

Or after pull:

```bash id="3uzeci"
docker image inspect ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.2.0 \
  --format '{{index .RepoDigests 0}}'
```

You might see:

```text id="6tc5sc"
ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api@sha256:abc...
```

Store digest in deployment report:

```text id="5tjxq7"
service=demo-node-api
tag=0.2.0-a1b2c3d
digest=sha256:abc...
deployed_at=...
environment=prod
```

Why?

```text id="uypj9s"
tag can move if registry allows mutation
digest identifies exact image content
incident response becomes precise
```

Expert rule:

```text id="hmdjxx"
For high assurance, deploy or at least record image digests.
```

---

# 17. Expert Level — SBOM and Provenance Attestations

Modern supply-chain systems attach metadata to pushed images.

Docker docs describe build attestations such as:

```text id="bmmkzp"
SBOM: software artifacts inside or used to build image
Provenance: how the image was built
```

Docker says you can create attestations with `docker buildx build` using `--provenance` and `--sbom`, and the metadata attaches to the image index. ([Docker Documentation][5])

Example:

```bash id="maqstu"
docker buildx build \
  -f Dockerfile.industry \
  --target runtime \
  --build-arg APP_VERSION=0.2.0 \
  --build-arg COMMIT_SHA="$COMMIT_SHA" \
  --sbom=true \
  --provenance=true \
  -t ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.2.0-$COMMIT_SHA \
  --push \
  .
```

Docker’s GitHub Actions docs also note that SBOM attestations require pushing to a registry because the local image store does not support loading images with attestations. ([Docker Documentation][6])

Professional meaning:

```text id="tg70te"
registry is not just storage anymore
registry becomes a place for image metadata, SBOM, provenance, scanning, policy
```

---

# 18. Expert Level — Image Signing Preview

We will go deeper later, but know the concept now.

Image signing proves:

```text id="2agxh2"
who built/published the image
image was not tampered with
deployment can verify trust policy
```

Popular tools:

```text id="p9s0uv"
Cosign / Sigstore
Notary v2 ecosystem
Cloud provider signing integrations
```

Future production rule:

```text id="gz4bqd"
Only deploy signed images from trusted CI pipelines.
```

For now, we focus on:

```text id="ra6a36"
immutable tags
digest recording
SBOM/provenance awareness
registry access control
```

---

# 19. Registry Access Patterns

## Local developer

Permissions:

```text id="odnzhm"
pull base images
push to dev namespace maybe
no production push
```

## CI runner

Permissions:

```text id="xe9gc7"
push app images
attach SBOM/provenance
maybe sign images
```

## Staging server

Permissions:

```text id="x6t2gj"
pull images only
```

## Production server

Permissions:

```text id="4aiw73"
pull approved images only
```

Bad:

```text id="y4f9sd"
production server has push permission
```

Better:

```text id="s1pgkq"
production server has read-only pull permission
```

Expert rule:

```text id="u28fsf"
Registry credentials should match the role: developer, CI, staging, production.
```

---

# 20. Registry Lifecycle Policies

Registries can fill up.

Use lifecycle policies to delete old images.

Keep:

```text id="8iq9l5"
production tags
recent N builds
release tags
digests currently deployed
```

Delete:

```text id="ew0e2m"
old untagged images
old feature branch builds
temporary PR images
```

ECR, GHCR, Harbor, GitLab, and cloud registries provide different retention mechanisms.

Professional warning:

```text id="w9q5qx"
Do not delete images that may be needed for rollback.
```

Good retention thinking:

```text id="y2ip8d"
keep last 30 days of CI images
keep all semver release tags
keep currently deployed digests
keep previous production digest
```

---

# 21. Create Image Promotion Script for Compose

In Compose project:

```bash id="zae3i2"
cd ~/devops-masterclass/06-docker-containers/compose-demo
```

Create:

```bash id="k00kyf"
nano scripts/promote-image.sh
```

Paste:

```bash id="xct31a"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-}"
IMAGE_TAG="${2:-}"
ENV_FILE="${ENV_FILE:-.env}"

if [ -z "$ENVIRONMENT" ] || [ -z "$IMAGE_TAG" ]; then
  echo "Usage: $0 <environment> <image-tag>" >&2
  echo "Example: $0 staging 0.2.0-a1b2c3d" >&2
  exit 1
fi

echo "===== Image Promotion ====="
echo "Environment: $ENVIRONMENT"
echo "Image tag: $IMAGE_TAG"
echo "Env file: $ENV_FILE"

if grep -q '^APP_VERSION=' "$ENV_FILE"; then
  sed -i "s/^APP_VERSION=.*/APP_VERSION=$IMAGE_TAG/" "$ENV_FILE"
else
  echo "APP_VERSION=$IMAGE_TAG" >> "$ENV_FILE"
fi

mkdir -p deployment-records

cat > "deployment-records/${ENVIRONMENT}-last-promotion.json" <<EOF
{
  "environment": "$ENVIRONMENT",
  "image_tag": "$IMAGE_TAG",
  "promoted_at": "$(date -Iseconds)"
}
EOF

echo "Promotion record:"
cat "deployment-records/${ENVIRONMENT}-last-promotion.json" | jq .
```

Make executable:

```bash id="2t8nmb"
chmod +x scripts/promote-image.sh
```

Use:

```bash id="xig7fp"
./scripts/promote-image.sh staging 0.2.0-a1b2c3d
```

Deploy:

```bash id="6sgxaa"
COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
```

Add Git ignore for local records if desired:

```bash id="1eq8ih"
echo "deployment-records/*.json" >> .gitignore
```

Or commit example records only.

---

# 22. CI/CD Example — GHCR Build and Push

Create workflow note:

```bash id="8ryp9o"
cd ~/devops-masterclass/06-docker-containers
nano ghcr-build-push-workflow.md
```

Paste:

````markdown id="oqjt69"
# GHCR Build and Push Workflow

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [main]
    tags:
      - "v*"

permissions:
  contents: read
  packages: write

env:
  IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/demo-node-api

jobs:
  docker:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Compute metadata
        id: meta
        run: |
          SHORT_SHA="${GITHUB_SHA::7}"
          VERSION="${GITHUB_REF_NAME}"
          echo "short_sha=$SHORT_SHA" >> "$GITHUB_OUTPUT"
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"

      - name: Login to GHCR
        run: |
          echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io \
            -u "${{ github.actor }}" \
            --password-stdin

      - name: Build and push
        run: |
          docker buildx build \
            -f 05-application-runtime/demo-node-api/Dockerfile.industry \
            --target runtime \
            --build-arg APP_VERSION="${{ steps.meta.outputs.version }}" \
            --build-arg COMMIT_SHA="${{ steps.meta.outputs.short_sha }}" \
            --sbom=true \
            --provenance=true \
            -t "${IMAGE_NAME}:${{ steps.meta.outputs.short_sha }}" \
            -t "${IMAGE_NAME}:${{ steps.meta.outputs.version }}-${{ steps.meta.outputs.short_sha }}" \
            --push \
            05-application-runtime/demo-node-api
````

## Notes

* Use immutable tags.
* Push SBOM/provenance attestations.
* Production deploy should pull exact tag or digest.
* Avoid `latest` for production.

````

---

# 23. CI/CD Example — ECR Build and Push

Create:

```bash id="8f5z18"
nano ecr-build-push-workflow.md
````

Paste:

````markdown id="sueojb"
# ECR Build and Push Workflow

```yaml
name: Build and Push to ECR

on:
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write

env:
  AWS_REGION: ap-south-1
  ECR_REPOSITORY: demo-node-api

jobs:
  docker:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-region: ${{ env.AWS_REGION }}
          role-to-assume: arn:aws:iam::<account-id>:role/<github-actions-ecr-role>

      - name: Login to ECR
        run: |
          AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          echo "AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID" >> "$GITHUB_ENV"

          aws ecr get-login-password --region "$AWS_REGION" \
            | docker login \
                --username AWS \
                --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

      - name: Build and push
        run: |
          SHORT_SHA="${GITHUB_SHA::7}"
          IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY"

          docker buildx build \
            -f 05-application-runtime/demo-node-api/Dockerfile.industry \
            --target runtime \
            --build-arg APP_VERSION="$SHORT_SHA" \
            --build-arg COMMIT_SHA="$SHORT_SHA" \
            --sbom=true \
            --provenance=true \
            -t "$IMAGE:$SHORT_SHA" \
            --push \
            05-application-runtime/demo-node-api
````

## Notes

* Prefer OIDC role assumption over long-lived AWS keys.
* Server/ECS/EKS should have pull-only permissions.
* ECR repo should have lifecycle policy and scan settings.

````

---

# 24. Registry Troubleshooting Playbook

## Problem 1 — `denied: requested access to the resource is denied`

Likely causes:

```text id="qykd4s"
not logged in
wrong registry URL
wrong namespace
token lacks push permission
repository does not exist
````

Check:

```bash id="ulct7h"
docker info | grep Username || true
docker login ghcr.io
docker image ls | grep demo-node-api
```

---

## Problem 2 — ECR login works but push fails

Check repo exists:

```bash id="wntpog"
aws ecr describe-repositories --repository-names demo-node-api --region ap-south-1
```

Check identity:

```bash id="pql7u4"
aws sts get-caller-identity
```

Check IAM permissions:

```text id="dhtyos"
ecr:BatchCheckLayerAvailability
ecr:InitiateLayerUpload
ecr:UploadLayerPart
ecr:CompleteLayerUpload
ecr:PutImage
```

For repo creation:

```text id="4kpih2"
ecr:CreateRepository
```

You previously hit IAM issues with ECR creation, so this is expected if permissions are limited.

---

## Problem 3 — Server cannot pull private image

Check login on server:

```bash id="tjpz7m"
docker pull ghcr.io/YOUR_USER/demo-node-api:0.2.0
```

Likely causes:

```text id="z296y0"
server not logged in
token expired/revoked
package private
token lacks read:packages
wrong registry URL
```

Production fix:

```text id="0vr42a"
use deploy token or machine identity with read-only package access
```

---

## Problem 4 — Wrong image deployed

Check Compose `.env`:

```bash id="b5wk7n"
cat .env
```

Check running image:

```bash id="mkxdc6"
docker inspect compose-demo-backend --format '{{.Config.Image}}'
```

Check app endpoint:

```bash id="1nayik"
curl -s http://127.0.0.1:8080/version | jq .
```

Check digest:

```bash id="28ixjd"
docker inspect compose-demo-backend --format '{{.Image}}'
```

---

## Problem 5 — Tag was overwritten

If registry allows mutable tags, someone may push a new image to the same tag.

Fix:

```text id="hzlr3b"
enable tag immutability if registry supports it
use version-sha tags
record digest
restrict push permissions
```

---

# 25. Expert Corporate Promotion Flow

A mature promotion flow:

```text id="ach768"
1. CI builds image from commit.
2. CI runs unit/integration tests.
3. CI scans image.
4. CI generates SBOM/provenance.
5. CI pushes immutable tag.
6. Dev deploys automatically.
7. Staging promotion requires approval.
8. Prod promotion requires approval/change window.
9. Deployment records tag and digest.
10. Monitoring validates health/SLOs.
11. Rollback uses previous digest/tag.
```

Promotion is metadata, not rebuild:

```text id="5cf49n"
same artifact
different environment
different runtime config
controlled approval
```

This is the same concept you will later see in:

```text id="4c364m"
Kubernetes
Helm
ArgoCD
Terraform deployments
GitOps
ECS services
```

---

# 26. Update Compose Deployment Script to Record Image

Optional enhancement.

Open:

```bash id="3nu4yd"
cd ~/devops-masterclass/06-docker-containers/compose-demo
nano scripts/deploy-compose.sh
```

After health passes, add:

```bash id="kcmz5c"
mkdir -p deployment-records

BACKEND_IMAGE="$(docker inspect compose-demo-backend --format '{{.Config.Image}}' 2>/dev/null || true)"
BACKEND_IMAGE_ID="$(docker inspect compose-demo-backend --format '{{.Image}}' 2>/dev/null || true)"

cat > "deployment-records/last-deploy.json" <<EOF
{
  "backend_image": "$BACKEND_IMAGE",
  "backend_image_id": "$BACKEND_IMAGE_ID",
  "health_url": "$HEALTH_URL",
  "deployed_at": "$(date -Iseconds)"
}
EOF

echo
echo "Deployment record:"
cat deployment-records/last-deploy.json | jq .
```

This records:

```text id="s79gzd"
which image was deployed
local image ID
deployment timestamp
health URL
```

In enterprise, this record goes to:

```text id="mghy1k"
CI artifacts
deployment database
change management system
S3 bucket
GitOps commit
observability event
```

---

# 27. Final Validation

Build image:

```bash id="5l04vl"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
VERSION=0.2.0 ./scripts/docker-build.sh
```

Tag locally as if registry image:

```bash id="sjkabk"
docker tag demo-node-api:0.2.0 local-registry-demo/demo-node-api:0.2.0
```

Set Compose to use local simulated registry name:

```bash id="5yu3nh"
cd ~/devops-masterclass/06-docker-containers/compose-demo

sed -i 's|^APP_IMAGE=.*|APP_IMAGE=local-registry-demo/demo-node-api|' .env
sed -i 's|^APP_VERSION=.*|APP_VERSION=0.2.0|' .env
```

Deploy:

```bash id="xpy2li"
COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
```

Validate:

```bash id="mkms8g"
curl -s http://127.0.0.1:8080/version | jq .
docker inspect compose-demo-backend --format '{{.Config.Image}}'
```

Set back to your real registry later:

```bash id="e3pahc"
APP_IMAGE=ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api
APP_VERSION=0.2.0-a1b2c3d
```

---

# 28. Commit Work

Run:

```bash id="q5sjlx"
cd ~/devops-masterclass

git status
git add 05-application-runtime/demo-node-api/scripts/docker-tag-push.sh \
        06-docker-containers

git commit -m "feat: add Docker registry and image promotion patterns"
git push
```

---

# 29. Interview Explanation

## What is a container registry?

Strong answer:

```text id="7roxla"
A container registry stores container images and their tags, layers, metadata, and sometimes scan results or attestations. CI pushes images to the registry, and deployment environments pull images from it. Examples include Docker Hub, GHCR, Amazon ECR, Harbor, and GitLab Container Registry.
```

## What is the difference between a tag and a digest?

Strong answer:

```text id="l5f0z3"
A tag is a human-readable reference that can point to an image, such as 0.2.0 or staging. A digest is a content-addressed SHA256 identifier for the exact image content. Tags can be mutable depending on registry policy, while digests identify the exact artifact.
```

## Why avoid `latest` in production?

Strong answer:

```text id="4h4qjg"
The latest tag is mutable and does not clearly identify what code is running. It makes rollback, auditing, and incident response harder. Production deployments should use immutable tags such as version plus Git SHA, and ideally record the image digest.
```

## What does image promotion mean?

Strong answer:

```text id="ixt56j"
Image promotion means building an image once and promoting that same image tag or digest through dev, staging, and production. Environment-specific behavior comes from runtime config and secrets, not rebuilding the image for each environment.
```

## How do you secure a registry?

Strong answer:

```text id="4bkw7d"
I use private repositories, least-privilege credentials, CI-only push permissions, production read-only pull permissions, image scanning, immutable tags, lifecycle policies, audit logs, and protected deployment environments. I avoid personal credentials on servers and record image digests for traceability.
```

## How does ECR login work?

Strong answer:

```text id="ytpb53"
For ECR, Docker authenticates using an authorization token generated by AWS CLI. The command `aws ecr get-login-password --region REGION` is piped to `docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.REGION.amazonaws.com`.
```

---

# Today’s Core Rules

```text id="872k8x"
A registry stores images.
Image name = registry/namespace/repository:tag.
Build once, promote the same image.
Do not rebuild separately for dev/staging/prod.
Avoid latest in production.
Use version, Git SHA, and version-SHA tags.
Record image digest for traceability.
Use private repos for private apps.
CI should push images.
Servers should pull images with read-only credentials.
Scan images before promotion.
Use SBOM/provenance where possible.
Use lifecycle policies carefully.
Do not delete images needed for rollback.
```

Next lesson:

# Lesson 6.10 — Docker CI/CD Pipeline Masterclass: GitHub Actions/Jenkins build, test, scan, tag, push, deploy with Compose, health validation, rollback, and deployment reports.

[1]: https://docs.docker.com/get-started/docker-concepts/building-images/build-tag-and-publish-an-image/?utm_source=chatgpt.com "Build, tag, and publish an image"
[2]: https://github.com/docker/login-action?utm_source=chatgpt.com "GitHub Action to login against a Docker registry"
[3]: https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry?utm_source=chatgpt.com "Working with the Container registry"
[4]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html?utm_source=chatgpt.com "push a Docker image to an Amazon ECR repository"
[5]: https://docs.docker.com/guides/docker-scout/attestations/?utm_source=chatgpt.com "Attestations | Docker Docs"
[6]: https://docs.docker.com/build/ci/github-actions/attestations/?utm_source=chatgpt.com "Add SBOM and provenance attestations with GitHub Actions"

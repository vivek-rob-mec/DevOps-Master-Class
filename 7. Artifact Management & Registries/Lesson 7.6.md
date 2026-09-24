# Lesson 7.6 — GHCR Production Workflow Deep Dive

# GitHub Container Registry, Package Permissions, GITHUB_TOKEN vs PAT, Private/Public Images, GitHub Actions Publishing, Deploy Pull Tokens, Visibility, and Troubleshooting

GHCR means:

```text id="lxxmb1"
GitHub Container Registry
```

GHCR is very useful for your portfolio and GitHub-native DevOps projects because your source code, CI/CD workflows, container images, release metadata, and deployment automation can all live around the same GitHub project.

GitHub Container Registry stores container images under a personal account or organization and supports granular permissions and repository-linked packages. ([GitHub Docs][1])

---

# 1. Beginner Level — What Is GHCR?

GHCR image format:

```text id="wtflbl"
ghcr.io/OWNER/IMAGE_NAME:TAG
```

Example:

```text id="z2w1sh"
ghcr.io/vivek-saroj/demo-node-api:0.7.0-a1b2c3d
```

Breakdown:

```text id="ed2pl8"
ghcr.io                 registry host
vivek-saroj             GitHub username or organization
demo-node-api           package/image name
0.7.0-a1b2c3d           image tag
```

Basic commands:

```bash id="k8g73n"
docker login ghcr.io
docker tag demo-node-api:0.7.0-a1b2c3d ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.7.0-a1b2c3d
docker push ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.7.0-a1b2c3d
docker pull ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.7.0-a1b2c3d
```

Core rule:

```text id="dtdfqk"
GHCR is a good default registry for GitHub-based portfolio and CI/CD projects.
```

---

# 2. GHCR vs ECR vs Docker Hub

```text id="ulbbgs"
GHCR:
  best for GitHub-native projects and portfolio repositories

ECR:
  best for AWS-native production systems

Docker Hub:
  best for public ecosystem images and simple public sharing
```

For your learning journey:

```text id="gvcz4x"
GHCR = best for GitHub portfolio
ECR  = best for AWS deployment practice
```

A very professional setup may use both:

```text id="9zfqn7"
GHCR:
  public portfolio image

ECR:
  private AWS production image
```

---

# 3. Beginner — GHCR Login

For local login, use a GitHub personal access token.

GitHub docs say GitHub Packages supports authentication with a personal access token classic for package workflows, and the container registry can also use `GITHUB_TOKEN` inside GitHub Actions for packages associated with the workflow repository. ([GitHub Docs][1])

Local login:

```bash id="b2gw1i"
echo "$GHCR_TOKEN" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

Token scopes for local CLI:

```text id="fqkq0l"
read:packages   -> pull private images
write:packages  -> push images
delete:packages -> delete packages, use carefully
```

For production servers:

```text id="da4bm3"
read:packages only
```

For CI push:

```text id="66wx15"
GITHUB_TOKEN with packages: write
or PAT with write:packages if needed
```

Bad:

```text id="zw1004"
using your personal full-access token on a production server
```

Good:

```text id="z51ec4"
using a read-only token or repository-linked access pattern for deploy pulls
```

---

# 4. Intermediate — GHCR Package Visibility

GHCR packages can be:

```text id="09w3h5"
public
private
internal for organizations where available
```

GitHub docs explain that container registry public packages can be pulled anonymously, while many other package registries require authentication even for public packages. ([GitHub Docs][2])

Meaning:

```text id="wrm2sd"
public GHCR image:
  docker pull ghcr.io/user/image:tag may work without login

private GHCR image:
  docker login ghcr.io is required
```

Portfolio recommendation:

```text id="31l3zk"
Make portfolio demo images public only if they contain no secrets and are safe to share.
```

Production recommendation:

```text id="xp2m4p"
Keep production images private.
```

---

# 5. Intermediate — Package Permissions

GHCR supports granular package permissions and repository-linked package permissions. Packages can inherit permissions from a linked repository or use specific package access settings. ([GitHub Docs][3])

This matters because your GitHub Actions workflow may fail with:

```text id="olotsh"
permission_denied: write_package
```

Common causes:

```text id="8kvm09"
workflow permissions missing packages: write
package not linked to repository
Actions access not granted to repository
using wrong owner namespace
token lacks write:packages
organization policy blocks package publishing
```

Workflow permission must include:

```yaml id="bxvfux"
permissions:
  contents: read
  packages: write
```

If package already exists and is not linked properly, go to:

```text id="mv2n2b"
GitHub package page
  -> Package settings
  -> Manage Actions access
  -> add repository
  -> grant write access
```

Professional rule:

```text id="ndncli"
When GHCR push fails, check both token permissions and package access settings.
```

---

# 6. Beginner — First GHCR Push Manually

Compute your current deploy tag:

```bash id="zpo4gi"
cd ~/devops-masterclass/07-artifact-management-registries

VERSION_JSON="$(BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"

echo "$DEPLOY_TAG"
```

Build image:

```bash id="35ta0c"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
```

Login:

```bash id="6zmpkb"
echo "$GHCR_TOKEN" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

Tag:

```bash id="4iubcj"
docker tag "demo-node-api:$DEPLOY_TAG" "ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:$DEPLOY_TAG"
```

Push:

```bash id="o2pqyx"
docker push "ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:$DEPLOY_TAG"
```

Pull test:

```bash id="6szucr"
docker pull "ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:$DEPLOY_TAG"
```

Inspect digest:

```bash id="d0e0je"
docker image inspect "ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:$DEPLOY_TAG" \
  --format '{{json .RepoDigests}}' | jq .
```

---

# 7. Professional — GHCR Image Labels

GitHub can associate a container package with a source repository using OCI labels.

Your Dockerfile should include labels like:

```Dockerfile id="4qqkg8"
LABEL org.opencontainers.image.source="https://github.com/YOUR_GITHUB_USERNAME/devops-masterclass"
LABEL org.opencontainers.image.description="Production runtime demo Node.js API"
LABEL org.opencontainers.image.licenses="MIT"
```

For GitHub Actions, you can pass labels during build:

```yaml id="962xx5"
labels: |
  org.opencontainers.image.source=https://github.com/${{ github.repository }}
  org.opencontainers.image.revision=${{ github.sha }}
  org.opencontainers.image.version=${{ steps.version.outputs.deploy_tag }}
```

Why labels matter:

```text id="i5g87r"
better package discoverability
source traceability
metadata visible in registry
audit support
```

Professional rule:

```text id="3q4nzp"
Every production image should include source, revision, version, and creation metadata.
```

---

# 8. Professional — GitHub Actions GHCR Workflow

Create:

```bash id="5102gw"
cd ~/devops-masterclass

nano .github/workflows/ghcr-build-push.yml
```

Paste:

```yaml id="k3tg9h"
name: Build and Push to GHCR

on:
  push:
    branches:
      - main
    tags:
      - "v*"
  workflow_dispatch:

permissions:
  contents: read
  packages: write

env:
  APP_DIR: 05-application-runtime/demo-node-api
  IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/demo-node-api
  BASE_VERSION: "0.7.0"

jobs:
  build-push-ghcr:
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

      - name: Login to GHCR
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: ${{ env.APP_DIR }}
          file: ${{ env.APP_DIR }}/Dockerfile.industry
          target: runtime
          push: true
          tags: |
            ${{ env.IMAGE_NAME }}:${{ steps.version.outputs.deploy_tag }}
            ${{ env.IMAGE_NAME }}:${{ steps.version.outputs.short_sha }}
          labels: |
            org.opencontainers.image.source=https://github.com/${{ github.repository }}
            org.opencontainers.image.revision=${{ github.sha }}
            org.opencontainers.image.version=${{ steps.version.outputs.deploy_tag }}
          build-args: |
            APP_VERSION=${{ steps.version.outputs.deploy_tag }}
            COMMIT_SHA=${{ steps.version.outputs.short_sha }}
          sbom: true
          provenance: true

      - name: Show image reference
        run: |
          echo "Image pushed:"
          echo "${IMAGE_NAME}:${{ steps.version.outputs.deploy_tag }}"
```

This uses GitHub’s recommended package workflow pattern: `GITHUB_TOKEN` can publish packages associated with the workflow repository when workflow permissions grant `packages: write`. ([GitHub Docs][3])

---

# 9. Professional — Docker Metadata Action Alternative

Many production workflows use `docker/metadata-action` to create tags and labels.

Example:

```yaml id="nysbdh"
      - name: Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository_owner }}/demo-node-api
          tags: |
            type=sha,prefix=
            type=ref,event=tag
            type=raw,value=0.7.0-${{ github.sha }}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: ${{ env.APP_DIR }}
          file: ${{ env.APP_DIR }}/Dockerfile.industry
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

For learning, our manual version computation is better because you understand it.

For professional projects, metadata-action reduces custom scripting.

---

# 10. Professional — Private GHCR Deployment Server Pull

If your GHCR image is private, your deployment server must login.

On server:

```bash id="l49gjh"
echo "$GHCR_READ_TOKEN" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

Use a token with:

```text id="h9i001"
read:packages
```

Then:

```bash id="zdbxz1"
docker pull ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.7.0-a1b2c3d
```

Compose `.env`:

```bash id="4s5neo"
APP_IMAGE=ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api
APP_VERSION=0.7.0-a1b2c3d
HOST_HTTP_PORT=8080
APP_ENV=prod
LOG_LEVEL=info
```

Deploy:

```bash id="fjgwxq"
cd ~/devops-masterclass/06-docker-containers/compose-demo

COMPOSE_FILES="compose.yaml compose.prod.yaml" ./scripts/deploy-compose.sh
```

Professional rule:

```text id="ktgzz2"
Production servers should use read-only package credentials.
```

---

# 11. Expert — Public Portfolio Image vs Private Production Image

For portfolio:

```text id="eztxri"
public GitHub repo
public GHCR image
clear README
no secrets
safe demo app
```

Benefits:

```text id="2g1v5w"
recruiters/interviewers can pull your image
shows real CI/CD practice
source and artifact are linked
```

For production:

```text id="bcmdsm"
private repo or private package
restricted package access
read-only deploy credentials
no public vulnerability exposure
```

Recommended split:

```text id="rh6v8b"
Portfolio:
  ghcr.io/vivek-saroj/demo-node-api:0.7.0-a1b2c3d public

AWS production practice:
  AWS ECR private repository
```

---

# 12. Expert — GHCR Access Patterns

## Pattern A — Same repository publishes image

```text id="63cah4"
repo: devops-masterclass
workflow publishes: ghcr.io/owner/demo-node-api
GITHUB_TOKEN works with packages: write
```

Best for your current project.

## Pattern B — Different repository deploys image

```text id="0xtzfn"
repo A builds image
repo B deploys image
```

Then package access must allow repo B to read the package.

Possible fixes:

```text id="mz57oj"
make package public
grant repo B package access
use PAT with read:packages
use organization-level package permissions
```

## Pattern C — Organization package

```text id="cchxyl"
ghcr.io/org/demo-node-api
```

Need organization package permissions and Actions settings.

Professional rule:

```text id="x0a1cd"
GHCR permissions are package-level and repository-aware. Always check package access if Actions fails.
```

---

# 13. Expert — GHCR Deletion and Cleanup

GHCR image tags consume storage and clutter package history.

But cleanup can break rollback.

GitHub Packages supports deleting and restoring packages with permissions; GitHub docs note that GitHub Actions can delete or restore packages via REST API using `GITHUB_TOKEN` if it has admin permission to the package, with delete/restore behavior historically noted as preview in some docs. ([GitHub Docs][4])

Production policy:

```text id="o1ln1a"
Keep stable release tags.
Keep current production.
Keep previous production.
Delete old dev/PR tags.
Do not delete images referenced by deployment records.
```

For this course, do not automate deletion yet.

We will cover artifact retention deeper later.

---

# 14. Hands-On — Create GHCR Notes

Run:

```bash id="3fy3e2"
cd ~/devops-masterclass/07-artifact-management-registries

nano notes/ghcr-production-workflow.md
```

Paste:

````markdown id="pm0ach"
# GHCR Production Workflow

## Image Format

```text
ghcr.io/OWNER/IMAGE_NAME:TAG
````

Example:

```text
ghcr.io/vivek-saroj/demo-node-api:0.7.0-a1b2c3d
```

## Authentication

Local CLI:

```bash
echo "$GHCR_TOKEN" | docker login ghcr.io -u USER --password-stdin
```

GitHub Actions:

```yaml
permissions:
  contents: read
  packages: write
```

```yaml
- uses: docker/login-action@v4
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

## Token Scopes

* `read:packages` for pulling private packages
* `write:packages` for pushing packages
* `delete:packages` only for cleanup/admin workflows

## Production Rules

* Use immutable version-sha tags.
* Avoid `latest` for production.
* Use public packages only for safe portfolio/demo images.
* Use private packages for production.
* Server tokens should be read-only.
* CI should push with `GITHUB_TOKEN` where possible.
* Link packages to repositories for better permissions.
* Record image tag and digest in release metadata.

````

---

# 15. Create GHCR Setup Runbook

Create:

```bash id="ki98n0"
nano notes/ghcr-setup-runbook.md
````

Paste:

````markdown id="ghd4vf"
# GHCR Setup Runbook

## 1. Create Token for Local Push

Create a GitHub personal access token classic with:

- `write:packages`
- `read:packages`

For pull-only deployment server token:

- `read:packages`

## 2. Login Locally

```bash
echo "$GHCR_TOKEN" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
````

## 3. Build Image

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION=0.7.0-a1b2c3d ./scripts/docker-build.sh
```

## 4. Tag Image

```bash
docker tag demo-node-api:0.7.0-a1b2c3d ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.7.0-a1b2c3d
```

## 5. Push Image

```bash
docker push ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.7.0-a1b2c3d
```

## 6. Configure Package Visibility

Go to:

```text
GitHub profile or organization
  -> Packages
  -> demo-node-api
  -> Package settings
```

Choose public/private visibility as appropriate.

## 7. Manage Actions Access

If GitHub Actions cannot push:

```text
Package settings
  -> Manage Actions access
  -> Add repository
  -> Grant write access
```

## 8. Deploy Server Pull

```bash
echo "$GHCR_READ_TOKEN" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
docker pull ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.7.0-a1b2c3d
```

````

---

# 16. Create GHCR Troubleshooting Playbook

Create:

```bash id="p516ld"
nano notes/ghcr-troubleshooting-playbook.md
````

Paste:

````markdown id="cyslyr"
# GHCR Troubleshooting Playbook

## denied: permission_denied: write_package

Check:

- workflow has `packages: write`
- package is linked to repository
- package Actions access grants write to repo
- token has `write:packages`
- image namespace is correct
- organization policy allows publishing

## denied: permission_denied: read_package

Check:

- image is private
- server is logged in
- token has `read:packages`
- package grants access to repository or user
- image owner namespace is correct

## package not visible

Possible causes:

- package is private
- pushed to wrong owner
- repository/package not linked
- package name differs from expected

## GITHUB_TOKEN push fails

Fix:

```yaml
permissions:
  contents: read
  packages: write
````

Then check package settings:

```text
Package settings -> Manage Actions access
```

## Pull works locally but not on server

Check server login:

```bash
docker login ghcr.io
docker pull ghcr.io/OWNER/IMAGE:TAG
```

Check Compose image:

```bash
cat .env
docker inspect compose-demo-backend --format '{{.Config.Image}}'
```

## Avoid

* using personal full-access token on server
* using `latest` in production
* deleting previous production tags

````

---

# 17. Create GHCR Release Metadata Script

We already have generic metadata, but let’s add a GHCR-focused helper.

Create:

```bash id="cih6m8"
nano scripts/create-ghcr-release-record.sh
````

Paste:

```bash id="lzg4x6"
#!/usr/bin/env bash
set -euo pipefail

GITHUB_USERNAME="${GITHUB_USERNAME:-}"
IMAGE_NAME="${IMAGE_NAME:-demo-node-api}"
IMAGE_TAG="${IMAGE_TAG:-}"
OUTPUT_DIR="${OUTPUT_DIR:-release-records/ghcr}"

if [ -z "$GITHUB_USERNAME" ]; then
  echo "ERROR: GITHUB_USERNAME is required" >&2
  exit 1
fi

if [ -z "$IMAGE_TAG" ]; then
  echo "ERROR: IMAGE_TAG is required" >&2
  exit 1
fi

IMAGE_REF="ghcr.io/$GITHUB_USERNAME/$IMAGE_NAME:$IMAGE_TAG"

mkdir -p "$OUTPUT_DIR"

IMAGE_ID=""
REPO_DIGESTS="[]"

if docker image inspect "$IMAGE_REF" >/dev/null 2>&1; then
  IMAGE_ID="$(docker image inspect "$IMAGE_REF" --format '{{.Id}}')"
  REPO_DIGESTS="$(docker image inspect "$IMAGE_REF" --format '{{json .RepoDigests}}')"
fi

if [ "$REPO_DIGESTS" = "null" ]; then
  REPO_DIGESTS="[]"
fi

OUTPUT_FILE="$OUTPUT_DIR/$IMAGE_NAME-$IMAGE_TAG-ghcr.json"

cat > "$OUTPUT_FILE" <<EOF
{
  "registry": "ghcr",
  "owner": "$GITHUB_USERNAME",
  "image_name": "$IMAGE_NAME",
  "image_tag": "$IMAGE_TAG",
  "image_ref": "$IMAGE_REF",
  "image_id": "$IMAGE_ID",
  "repo_digests": $REPO_DIGESTS,
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

echo "GHCR release record created:"
cat "$OUTPUT_FILE" | jq .
```

Make executable:

```bash id="ngf1b5"
chmod +x scripts/create-ghcr-release-record.sh
```

Run after push/pull:

```bash id="9e3yay"
GITHUB_USERNAME=YOUR_GITHUB_USERNAME \
IMAGE_TAG="$DEPLOY_TAG" \
./scripts/create-ghcr-release-record.sh
```

---

# 18. Create GHCR Push Script Wrapper

We already created generic registry scripts. Now create a GHCR-friendly wrapper.

```bash id="j4wcsq"
nano scripts/ghcr-push.sh
```

Paste:

```bash id="jhhod5"
#!/usr/bin/env bash
set -euo pipefail

GITHUB_USERNAME="${GITHUB_USERNAME:-}"
GHCR_TOKEN="${GHCR_TOKEN:-}"
IMAGE_TAG="${IMAGE_TAG:-}"
LOCAL_IMAGE="${LOCAL_IMAGE:-demo-node-api}"
IMAGE_NAME="${IMAGE_NAME:-demo-node-api}"

if [ -z "$GITHUB_USERNAME" ]; then
  echo "ERROR: GITHUB_USERNAME is required" >&2
  exit 1
fi

if [ -z "$IMAGE_TAG" ]; then
  echo "ERROR: IMAGE_TAG is required" >&2
  exit 1
fi

if [ -n "$GHCR_TOKEN" ]; then
  echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
else
  echo "GHCR_TOKEN not provided. Assuming docker is already logged in."
fi

GHCR_IMAGE="ghcr.io/$GITHUB_USERNAME/$IMAGE_NAME"

docker image inspect "$LOCAL_IMAGE:$IMAGE_TAG" >/dev/null

docker tag "$LOCAL_IMAGE:$IMAGE_TAG" "$GHCR_IMAGE:$IMAGE_TAG"

docker push "$GHCR_IMAGE:$IMAGE_TAG"

docker pull "$GHCR_IMAGE:$IMAGE_TAG"

docker image inspect "$GHCR_IMAGE:$IMAGE_TAG" \
  --format 'ID={{.Id}} RepoDigests={{json .RepoDigests}}'

GITHUB_USERNAME="$GITHUB_USERNAME" \
IMAGE_NAME="$IMAGE_NAME" \
IMAGE_TAG="$IMAGE_TAG" \
./scripts/create-ghcr-release-record.sh
```

Make executable:

```bash id="xvn079"
chmod +x scripts/ghcr-push.sh
```

Usage:

```bash id="3jv7i0"
GITHUB_USERNAME=YOUR_GITHUB_USERNAME \
GHCR_TOKEN=YOUR_TOKEN \
IMAGE_TAG="$DEPLOY_TAG" \
./scripts/ghcr-push.sh
```

---

# 19. Update Makefile

Open:

```bash id="wde3l6"
cd ~/devops-masterclass/07-artifact-management-registries

nano Makefile
```

Add:

```Makefile id="rz9kms"
.PHONY: ghcr-push ghcr-record

ghcr-push:
	@test -n "$(GITHUB_USERNAME)" || (echo "Usage: make ghcr-push GITHUB_USERNAME=<user> IMAGE_TAG=<tag>" && exit 1)
	@test -n "$(IMAGE_TAG)" || (echo "Usage: make ghcr-push GITHUB_USERNAME=<user> IMAGE_TAG=<tag>" && exit 1)
	GITHUB_USERNAME="$(GITHUB_USERNAME)" IMAGE_TAG="$(IMAGE_TAG)" ./scripts/ghcr-push.sh

ghcr-record:
	@test -n "$(GITHUB_USERNAME)" || (echo "Usage: make ghcr-record GITHUB_USERNAME=<user> IMAGE_TAG=<tag>" && exit 1)
	@test -n "$(IMAGE_TAG)" || (echo "Usage: make ghcr-record GITHUB_USERNAME=<user> IMAGE_TAG=<tag>" && exit 1)
	GITHUB_USERNAME="$(GITHUB_USERNAME)" IMAGE_TAG="$(IMAGE_TAG)" ./scripts/create-ghcr-release-record.sh
```

Use:

```bash id="yqqu9z"
make ghcr-push GITHUB_USERNAME=YOUR_GITHUB_USERNAME IMAGE_TAG="$DEPLOY_TAG"
make ghcr-record GITHUB_USERNAME=YOUR_GITHUB_USERNAME IMAGE_TAG="$DEPLOY_TAG"
```

---

# 20. End-to-End GHCR Flow

Compute version:

```bash id="rgu3c7"
cd ~/devops-masterclass/07-artifact-management-registries

VERSION_JSON="$(BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"

echo "$DEPLOY_TAG"
```

Build image:

```bash id="rh7w75"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
```

Push to GHCR:

```bash id="kf6ecg"
cd ~/devops-masterclass/07-artifact-management-registries

GITHUB_USERNAME=YOUR_GITHUB_USERNAME \
GHCR_TOKEN=YOUR_TOKEN \
IMAGE_TAG="$DEPLOY_TAG" \
./scripts/ghcr-push.sh
```

Deploy from GHCR:

```bash id="4cml09"
cd ~/devops-masterclass/06-docker-containers/compose-demo

APP_IMAGE=ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api \
APP_VERSION="$DEPLOY_TAG" \
COMPOSE_FILES="compose.yaml compose.prod.yaml" \
./scripts/deploy-compose.sh
```

Validate:

```bash id="ou232e"
curl -s http://127.0.0.1:8080/version | jq .
docker inspect compose-demo-backend --format '{{.Config.Image}}'
```

---

# 21. Expert — GHCR for Portfolio README

In your portfolio README, show:

````markdown id="c7mkl1"
## Container Image

This project publishes a Docker image to GitHub Container Registry:

```text
ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:<version-sha>
````

Pull:

```bash
docker pull ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:<version-sha>
```

Run:

```bash
docker run -p 3000:3000 \
  -e APP_ENV=dev \
  ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:<version-sha>
```

````

This makes your project easier to demonstrate.

---

# 22. Expert — GHCR Production Risks

GHCR is excellent, but production teams must consider:

```text id="0jr8go"
GitHub package permissions must be understood
private image pull requires token management
organization policies can block workflows
package access can be different from repo access
cleanup can delete rollback images
personal PATs are risky on servers
````

Mitigations:

```text id="y2rmdf"
use GITHUB_TOKEN for CI push when possible
use read-only deploy token for server pull
link packages to repositories
use immutable version-sha tags
record digests
do not rely on latest
avoid deleting release tags
document package access
```

---

# 23. GHCR Security Checklist

```text id="is7bos"
Workflow has minimal permissions.
CI uses GITHUB_TOKEN where possible.
Local push uses PAT only when needed.
Server pull token has read:packages only.
Package is linked to repository.
Package visibility is intentional.
No secrets are inside the image.
Tags are immutable by convention.
No latest in production deployment.
Release records store image ref and digest.
Previous production image is retained.
```

---

# 24. Troubleshooting Examples

## `denied: permission_denied: write_package`

Fix checklist:

```text id="doegoz"
permissions: packages: write
correct image owner
package access grants workflow repo write
token has write:packages
package/repo link is correct
```

Workflow:

```yaml id="aipxqa"
permissions:
  contents: read
  packages: write
```

## `denied: permission_denied: read_package`

Fix checklist:

```text id="gshob0"
image is private
docker login ghcr.io completed
token has read:packages
server uses correct owner username
package access grants repository/user access
```

## `manifest unknown`

Meaning:

```text id="uaxd4y"
tag does not exist
wrong image name
wrong owner
push failed
tag was deleted
```

Check:

```bash id="v3ge6e"
docker pull ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:$DEPLOY_TAG
```

## Package pushed to wrong owner

If workflow uses:

```yaml id="f6d5ig"
ghcr.io/${{ github.repository_owner }}/demo-node-api
```

Owner is the repository owner.

If local CLI uses:

```bash id="gz4n2v"
ghcr.io/YOUR_USERNAME/demo-node-api
```

Make sure they match.

---

# 25. Interview Explanation

## What is GHCR?

Strong answer:

```text id="50gkzf"
GHCR is GitHub Container Registry. It stores container images under GitHub users or organizations and integrates well with GitHub Actions and GitHub Packages permissions. It is useful for GitHub-native CI/CD and portfolio projects.
```

## How do you push to GHCR from GitHub Actions?

Strong answer:

```text id="4kosqo"
I configure workflow permissions with `contents: read` and `packages: write`, login to `ghcr.io` using `docker/login-action` with `${{ github.actor }}` and `${{ secrets.GITHUB_TOKEN }}`, then build and push with Docker Buildx using immutable tags such as version plus Git SHA.
```

## GITHUB_TOKEN vs PAT for GHCR?

Strong answer:

```text id="ygr0v5"
In GitHub Actions, I prefer `GITHUB_TOKEN` for publishing packages associated with the workflow repository because it is automatically created and scoped by workflow permissions. For local CLI or external servers, I use a personal access token with the minimum required scope, such as `read:packages` for pulling private images.
```

## Why does GHCR push sometimes fail with write_package denied?

Strong answer:

```text id="8l03h2"
It usually means the workflow token or package access is not configured correctly. I check workflow permissions for `packages: write`, the image namespace, package repository linkage, and Package settings under Manage Actions access.
```

## Should portfolio images be public?

Strong answer:

```text id="t9flq4"
Public images are useful for portfolio demos if they contain no secrets and are safe to share. For production or proprietary apps, images should be private and pulled using read-only deploy credentials.
```

---

# Today’s Core Rules

```text id="0ztbv6"
GHCR is ideal for GitHub-native projects.
Use ghcr.io/OWNER/IMAGE:TAG.
Use GITHUB_TOKEN in GitHub Actions where possible.
Set workflow permissions: contents read, packages write.
Use PATs only when needed.
Use read:packages only for deploy servers.
Public images are good for safe portfolio demos.
Private images are better for production.
Link packages to repositories.
Check Manage Actions access when push fails.
Use immutable version-sha tags.
Do not rely on latest.
Record image refs and digests.
Do not delete rollback images.
```

---

# Commit Work

Run:

```bash id="xiyjgx"
cd ~/devops-masterclass

git status
git add .github/workflows/ghcr-build-push.yml \
        07-artifact-management-registries

git commit -m "feat: add GHCR production workflow"
git push
```

---

# Next Lesson

# Lesson 7.7 — SBOM Fundamentals Deep Dive

We will go deeper into:

```text id="uihd9h"
what SBOM is
CycloneDX vs SPDX
why SBOM matters
how to generate SBOMs with Trivy/Docker Scout
SBOM storage
SBOM in CI/CD
SBOM and vulnerability response
SBOM for Docker images
enterprise supply-chain requirements
```

[1]: https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry?utm_source=chatgpt.com "Working with the Container registry"
[2]: https://docs.github.com/en/packages/learn-github-packages/about-permissions-for-github-packages?utm_source=chatgpt.com "About permissions for GitHub Packages"
[3]: https://docs.github.com/en/packages/learn-github-packages/introduction-to-github-packages?utm_source=chatgpt.com "Introduction to GitHub Packages"
[4]: https://docs.github.com/en/enterprise-server%403.20/packages/managing-github-packages-using-github-actions-workflows/publishing-and-installing-a-package-with-github-actions?utm_source=chatgpt.com "Publishing and installing a package with GitHub Actions"

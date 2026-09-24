# Lesson 7.8 — Provenance and Build Attestations Deep Dive

# Who Built It, Where It Was Built, From Which Source, SLSA Concepts, BuildKit Attestations, GitHub Attestations, and Supply-Chain Verification

In Lesson 7.7, we learned:

```text id="769su6"
SBOM = what is inside the artifact
```

Now we learn:

```text id="yz6tg8"
provenance = how the artifact was produced
```

This is one of the most important supply-chain security concepts.

A Docker image may have a tag:

```text id="f9l2vi"
demo-node-api:0.7.0-a1b2c3d
```

An SBOM tells:

```text id="z53igq"
this image contains express, node, alpine packages, npm dependencies
```

Provenance tells:

```text id="79kk0s"
this image was built from repository X
from commit Y
by workflow Z
on builder W
at time T
using build inputs A/B/C
```

SLSA describes provenance as verifiable information about software artifacts that explains where, when, and how something was produced. ([SLSA][1])

---

# 1. Beginner Level — What Is Provenance?

Simple definition:

```text id="5zce5q"
Provenance is the history of how an artifact was built.
```

It answers:

```text id="cl26ii"
Who built it?
What built it?
Where was it built?
When was it built?
From which source repo?
From which commit?
With which workflow?
With which build command?
What artifact was produced?
```

For example:

```json id="5nw0bd"
{
  "artifact": "ghcr.io/user/demo-node-api:0.7.0-a1b2c3d",
  "source": "github.com/user/devops-masterclass",
  "commit": "a1b2c3d",
  "builder": "GitHub Actions",
  "workflow": "ghcr-build-push.yml",
  "built_at": "2026-07-05T10:00:00Z"
}
```

Beginner mental model:

```text id="29paez"
SBOM = ingredients
Provenance = recipe + kitchen + chef
Signature = trusted stamp
```

---

# 2. Why Provenance Matters

Without provenance, you may know:

```text id="vzsrij"
this image exists
```

But you may not know:

```text id="x8e8jf"
was it built by CI?
was it built from the correct GitHub repo?
was it built from a reviewed commit?
was it built from main branch?
was it built by a compromised laptop?
was the tag manually pushed?
```

With provenance, you can verify:

```text id="b59u97"
artifact came from expected source
artifact came from expected workflow
artifact was built by expected builder
artifact matches expected commit
artifact was not manually produced outside CI
```

GitHub artifact attestations are designed to create provenance and integrity guarantees so consumers can verify where and how software was built. ([GitHub Docs][2])

Professional rule:

```text id="xcj40g"
Production should prefer artifacts with verifiable provenance.
```

---

# 3. Provenance vs SBOM vs Signature

These three are different.

| Concept    | Answers                 | Example                           |
| ---------- | ----------------------- | --------------------------------- |
| SBOM       | What is inside?         | npm packages, OS packages         |
| Provenance | How was it built?       | repo, commit, workflow, builder   |
| Signature  | Who signed/approved it? | cryptographic signature by CI/org |

Simple:

```text id="s4bguq"
SBOM:
  this artifact contains express 4.x

Provenance:
  this artifact was built from commit a1b2c3d by GitHub Actions

Signature:
  this claim/artifact was signed by trusted identity
```

Expert rule:

```text id="1hg5uz"
Strong supply-chain security uses all three: SBOM, provenance, and signatures.
```

---

# 4. What Is an Attestation?

An attestation is a signed or attached statement about an artifact.

Examples:

```text id="ulwf36"
This image has this SBOM.
This image was built by this workflow.
This binary passed this test.
This artifact was scanned.
This artifact was approved.
```

Generic structure:

```json id="5rt7t6"
{
  "subject": "artifact digest",
  "predicateType": "provenance",
  "predicate": {
    "builder": "GitHub Actions",
    "source": "repo",
    "commit": "sha"
  }
}
```

Docker BuildKit supports build attestations, including SBOM and provenance attestations. Docker’s build docs say attestations make it possible to inspect an image and see where it was built, who created it, and what software packages it contains. ([Docker Documentation][3])

---

# 5. SLSA Basics

SLSA means:

```text id="cck8bi"
Supply-chain Levels for Software Artifacts
```

SLSA is a security framework and checklist of standards and controls to prevent tampering, improve integrity, and secure packages and infrastructure. ([SLSA][4])

In simple language:

```text id="g01kvd"
SLSA helps prove software artifacts were built securely and traceably.
```

SLSA focuses on questions like:

```text id="k46qjf"
Was the source controlled?
Was the build scripted?
Was provenance generated?
Was the build isolated?
Can the artifact be verified?
Can someone tamper with the build?
```

For this course, remember:

```text id="xp88fw"
SLSA Level 1 thinking:
  produce provenance

Higher maturity:
  stronger build isolation
  stronger tamper resistance
  stronger verification
```

We are not trying to become SLSA experts today. We are learning the practical DevOps workflow.

---

# 6. Provenance Fields You Should Care About

A useful provenance record should include:

```text id="g69pmu"
artifact name
artifact digest
source repository
commit SHA
branch or tag
builder identity
workflow file
workflow run ID
build timestamp
build command or build type
materials/inputs
parameters
environment
```

For your project:

```text id="263q76"
service: demo-node-api
source: devops-masterclass
commit: current Git SHA
workflow: ghcr-build-push.yml or ecr-build-push.yml
image: ghcr.io/user/demo-node-api:0.7.0-a1b2c3d
digest: sha256:...
builder: GitHub Actions or local Docker BuildKit
```

Professional rule:

```text id="1i74o5"
Provenance must point to the exact artifact digest, not only a mutable tag.
```

---

# 7. BuildKit Provenance Attestations

Docker Buildx can create provenance attestations.

Docker docs show:

```bash id="ag9ljf"
docker buildx build \
  --tag <namespace>/<image>:<version> \
  --attest type=provenance,mode=[min,max],version=[v0.2,v1] .
```

Docker also documents shorthand flags such as `--provenance=mode=max`, and `--sbom=true` for SBOM attestations. ([Docker Documentation][5])

Modes:

```text id="fgz791"
min:
  smaller provenance, less detail

max:
  more detailed provenance, more build metadata
```

For learning:

```text id="98c6gb"
use mode=max in CI examples
```

For production:

```text id="94hrpo"
choose mode based on security needs and information disclosure risk
```

Because detailed provenance may reveal build arguments or internal paths depending on setup.

---

# 8. Important BuildKit Caveat

Attestations usually make most sense when pushing to a registry.

Example:

```bash id="z1yj55"
docker buildx build \
  -f Dockerfile.industry \
  --target runtime \
  --tag ghcr.io/YOUR_USER/demo-node-api:$DEPLOY_TAG \
  --provenance=mode=max \
  --sbom=true \
  --push \
  .
```

Why push?

```text id="qed3s7"
registry can store image plus attached attestations
local docker image store may not show them the same way
```

Professional rule:

```text id="zfgjjf"
Generate and store provenance during CI registry push, not only during local builds.
```

---

# 9. Hands-On — Create Directory

Run:

```bash id="2vxj30"
cd ~/devops-masterclass/07-artifact-management-registries

mkdir -p provenance/{buildkit,github,manual,reports,policies}
```

Check:

```bash id="7z3b7k"
tree -L 2 provenance
```

Expected:

```text id="0xjig7"
provenance
├── buildkit
├── github
├── manual
├── policies
└── reports
```

---

# 10. Manual Provenance Record

Before advanced tooling, create a manual provenance record. This helps you understand what provenance contains.

Create:

```bash id="680k5h"
nano scripts/create-manual-provenance.sh
```

Paste:

```bash id="97meda"
#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"
IMAGE_NAME="${IMAGE_NAME:-demo-node-api}"
IMAGE_TAG="${IMAGE_TAG:-}"
SOURCE_REPO="${SOURCE_REPO:-devops-masterclass}"
COMMIT_SHA="${COMMIT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"
GIT_BRANCH="${GIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)}"
BUILDER="${BUILDER:-local-docker}"
BUILD_TYPE="${BUILD_TYPE:-docker-build}"
WORKFLOW="${WORKFLOW:-manual-local-build}"
OUTPUT_DIR="${OUTPUT_DIR:-provenance/manual}"

if [ -z "$IMAGE_TAG" ]; then
  echo "ERROR: IMAGE_TAG is required" >&2
  echo "Example: IMAGE_TAG=0.7.0-a1b2c3d $0" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

IMAGE_ID=""
REPO_DIGESTS="[]"

if docker image inspect "$IMAGE_NAME:$IMAGE_TAG" >/dev/null 2>&1; then
  IMAGE_ID="$(docker image inspect "$IMAGE_NAME:$IMAGE_TAG" --format '{{.Id}}')"
  REPO_DIGESTS="$(docker image inspect "$IMAGE_NAME:$IMAGE_TAG" --format '{{json .RepoDigests}}')"
fi

if [ "$REPO_DIGESTS" = "null" ]; then
  REPO_DIGESTS="[]"
fi

OUTPUT_FILE="$OUTPUT_DIR/$SERVICE_NAME-$IMAGE_TAG.manual-provenance.json"

cat > "$OUTPUT_FILE" <<EOF
{
  "predicate_type": "manual_provenance",
  "service_name": "$SERVICE_NAME",
  "artifact": {
    "image_name": "$IMAGE_NAME",
    "image_tag": "$IMAGE_TAG",
    "image_id": "$IMAGE_ID",
    "repo_digests": $REPO_DIGESTS
  },
  "source": {
    "repository": "$SOURCE_REPO",
    "commit_sha": "$COMMIT_SHA",
    "branch": "$GIT_BRANCH"
  },
  "build": {
    "builder": "$BUILDER",
    "build_type": "$BUILD_TYPE",
    "workflow": "$WORKFLOW",
    "built_by": "$(whoami)",
    "built_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  }
}
EOF

echo "Manual provenance created:"
cat "$OUTPUT_FILE" | jq .
```

Make executable:

```bash id="ns7sbo"
chmod +x scripts/create-manual-provenance.sh
```

Run:

```bash id="2audzg"
VERSION_JSON="$(BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"

IMAGE_TAG="$DEPLOY_TAG" ./scripts/create-manual-provenance.sh
```

This is not cryptographically strong, but it teaches the shape of provenance.

---

# 11. Build with Buildx Provenance Locally

First create a builder:

```bash id="1tav93"
docker buildx ls
docker buildx create --name devops-builder --use || docker buildx use devops-builder
docker buildx inspect --bootstrap
```

Compute version:

```bash id="netf8a"
cd ~/devops-masterclass/07-artifact-management-registries

VERSION_JSON="$(BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"
```

Build and push with GHCR example:

```bash id="kgol10"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

docker buildx build \
  -f Dockerfile.industry \
  --target runtime \
  --build-arg APP_VERSION="$DEPLOY_TAG" \
  --build-arg COMMIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo local)" \
  --tag "ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:$DEPLOY_TAG" \
  --provenance=mode=max \
  --sbom=true \
  --push \
  .
```

For ECR:

```bash id="f4st3u"
docker buildx build \
  -f Dockerfile.industry \
  --target runtime \
  --build-arg APP_VERSION="$DEPLOY_TAG" \
  --build-arg COMMIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo local)" \
  --tag "$AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api:$DEPLOY_TAG" \
  --provenance=mode=max \
  --sbom=true \
  --push \
  .
```

Docker’s docs for GitHub Actions attestations explain that SBOM and provenance attestations add metadata about image contents and how the image was built, and Docker Buildx/build-push-action can create those attestations. ([Docker Documentation][6])

---

# 12. GitHub Actions Provenance with Docker Build Push Action

You already used this pattern:

```yaml id="u38e6w"
sbom: true
provenance: true
```

For richer provenance:

```yaml id="za2gt7"
provenance: mode=max
sbom: true
```

Docker docs say `docker/build-push-action` supports attestations, and the docs specifically mention SBOM and provenance attestations in GitHub Actions. ([Docker Documentation][6])

Add to your GHCR workflow:

```yaml id="140gha"
      - name: Build and push with attestations
        uses: docker/build-push-action@v6
        with:
          context: ${{ env.APP_DIR }}
          file: ${{ env.APP_DIR }}/Dockerfile.industry
          target: runtime
          push: true
          tags: |
            ${{ env.IMAGE_NAME }}:${{ steps.version.outputs.deploy_tag }}
          build-args: |
            APP_VERSION=${{ steps.version.outputs.deploy_tag }}
            COMMIT_SHA=${{ steps.version.outputs.short_sha }}
          sbom: true
          provenance: mode=max
```

Professional note:

```text id="kz1bnt"
Use provenance: mode=max for learning and high visibility, but review what metadata you expose before using it in sensitive production systems.
```

---

# 13. GitHub Artifact Attestations

GitHub has a separate artifact attestations feature.

GitHub docs say artifact attestations create cryptographically signed claims that establish build provenance and let consumers verify where and how software was built. ([GitHub Docs][2])

GitHub also documents using artifact attestations to establish provenance for builds, including binaries and container images. ([GitHub Docs][7])

For container image provenance, GitHub provides an action:

```yaml id="aowg4v"
- name: Attest image provenance
  uses: actions/attest-build-provenance@v2
  with:
    subject-name: ghcr.io/${{ github.repository_owner }}/demo-node-api
    subject-digest: ${{ steps.push.outputs.digest }}
    push-to-registry: true
```

The idea:

```text id="51urlq"
build image
push image
capture digest
create attestation for that digest
push attestation to registry
```

This is different from just writing a JSON file. It is a signed provenance claim.

---

# 14. GHCR Workflow with GitHub Attestation

Create example:

```bash id="swp7a2"
cd ~/devops-masterclass/07-artifact-management-registries

nano examples/github-actions-provenance-attestation.yml
```

Paste:

```yaml id="3c69a6"
name: Provenance Attestation Example

on:
  workflow_dispatch:

permissions:
  contents: read
  packages: write
  id-token: write
  attestations: write

env:
  APP_DIR: 05-application-runtime/demo-node-api
  IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/demo-node-api
  BASE_VERSION: "0.7.0"

jobs:
  build-provenance:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Compute version
        id: version
        shell: bash
        run: |
          SHORT_SHA="${GITHUB_SHA::7}"
          DEPLOY_TAG="${BASE_VERSION}-dev-${SHORT_SHA}"
          echo "short_sha=$SHORT_SHA" >> "$GITHUB_OUTPUT"
          echo "deploy_tag=$DEPLOY_TAG" >> "$GITHUB_OUTPUT"

      - name: Login to GHCR
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push image
        id: push
        uses: docker/build-push-action@v6
        with:
          context: ${{ env.APP_DIR }}
          file: ${{ env.APP_DIR }}/Dockerfile.industry
          target: runtime
          push: true
          tags: |
            ${{ env.IMAGE_NAME }}:${{ steps.version.outputs.deploy_tag }}
          build-args: |
            APP_VERSION=${{ steps.version.outputs.deploy_tag }}
            COMMIT_SHA=${{ steps.version.outputs.short_sha }}
          sbom: true
          provenance: mode=max

      - name: Attest image provenance
        uses: actions/attest-build-provenance@v2
        with:
          subject-name: ${{ env.IMAGE_NAME }}
          subject-digest: ${{ steps.push.outputs.digest }}
          push-to-registry: true
```

Permissions matter:

```yaml id="xg2c9c"
permissions:
  contents: read
  packages: write
  id-token: write
  attestations: write
```

GitHub’s artifact attestation examples require permissions such as `attestations: write` and `id-token: write` to generate attestations. ([GitHub Docs][7])

---

# 15. Provenance Verification Concept

A verification system should check:

```text id="0zkmkk"
artifact digest matches expected digest
provenance exists
provenance is signed by trusted builder
source repository is expected
commit SHA is expected
workflow is expected
branch/tag is allowed
builder identity is trusted
```

Example policy:

```text id="hiufml"
Allow production deployment only if:
  source repo = github.com/vivek-saroj/devops-masterclass
  branch/tag = main or v*
  builder = GitHub Actions
  workflow = ghcr-build-push.yml
  artifact digest matches release metadata
  SBOM exists
  vulnerability scan passed
```

Expert rule:

```text id="76qd8w"
Provenance is useful only if consumers verify it against policy.
```

---

# 16. Create Provenance Policy

Create:

```bash id="q8zepx"
nano provenance/policies/demo-node-api-provenance-policy.json
```

Paste:

```json id="62u3ar"
{
  "service_name": "demo-node-api",
  "allowed_sources": [
    "devops-masterclass"
  ],
  "allowed_builders": [
    "GitHub Actions",
    "local-docker"
  ],
  "allowed_workflows": [
    "ghcr-build-push.yml",
    "ecr-build-push.yml",
    "manual-local-build"
  ],
  "required_fields": [
    "artifact",
    "source",
    "build"
  ],
  "production_requirements": {
    "require_commit_sha": true,
    "require_image_identity": true,
    "require_builder": true,
    "require_workflow": true
  }
}
```

This is learning policy, not a full enterprise verification engine.

---

# 17. Validate Manual Provenance Script

Create:

```bash id="5de9dy"
nano scripts/validate-manual-provenance.sh
```

Paste:

```bash id="q5eldm"
#!/usr/bin/env bash
set -euo pipefail

PROVENANCE_FILE="${1:-}"
POLICY_FILE="${POLICY_FILE:-provenance/policies/demo-node-api-provenance-policy.json}"

if [ -z "$PROVENANCE_FILE" ]; then
  echo "Usage: $0 <provenance-json>" >&2
  exit 1
fi

if [ ! -f "$PROVENANCE_FILE" ]; then
  echo "ERROR: provenance file not found: $PROVENANCE_FILE" >&2
  exit 1
fi

if [ ! -f "$POLICY_FILE" ]; then
  echo "ERROR: policy file not found: $POLICY_FILE" >&2
  exit 1
fi

echo "===== Validate Manual Provenance ====="
echo "Provenance: $PROVENANCE_FILE"
echo "Policy: $POLICY_FILE"

service_name="$(jq -r '.service_name // empty' "$PROVENANCE_FILE")"
image_tag="$(jq -r '.artifact.image_tag // empty' "$PROVENANCE_FILE")"
commit_sha="$(jq -r '.source.commit_sha // empty' "$PROVENANCE_FILE")"
repository="$(jq -r '.source.repository // empty' "$PROVENANCE_FILE")"
builder="$(jq -r '.build.builder // empty' "$PROVENANCE_FILE")"
workflow="$(jq -r '.build.workflow // empty' "$PROVENANCE_FILE")"

if [ -z "$service_name" ] || [ -z "$image_tag" ] || [ -z "$commit_sha" ]; then
  echo "ERROR: required provenance identity fields missing" >&2
  exit 1
fi

if ! jq -e --arg repo "$repository" '.allowed_sources | index($repo)' "$POLICY_FILE" >/dev/null; then
  echo "ERROR: repository not allowed by policy: $repository" >&2
  exit 1
fi

if ! jq -e --arg workflow "$workflow" '.allowed_workflows | index($workflow)' "$POLICY_FILE" >/dev/null; then
  echo "ERROR: workflow not allowed by policy: $workflow" >&2
  exit 1
fi

echo "Manual provenance passed policy checks."
cat "$PROVENANCE_FILE" | jq .
```

Make executable:

```bash id="g85r0w"
chmod +x scripts/validate-manual-provenance.sh
```

Run:

```bash id="4mf6o8"
LATEST_PROV="$(ls -t provenance/manual/*.manual-provenance.json | head -n 1)"
./scripts/validate-manual-provenance.sh "$LATEST_PROV"
```

---

# 18. Provenance Summary Script

Create:

```bash id="m0ucq3"
nano scripts/provenance-summary.sh
```

Paste:

```bash id="f8qi50"
#!/usr/bin/env bash
set -euo pipefail

PROVENANCE_FILE="${1:-}"

if [ -z "$PROVENANCE_FILE" ]; then
  echo "Usage: $0 <provenance-json>" >&2
  exit 1
fi

if [ ! -f "$PROVENANCE_FILE" ]; then
  echo "ERROR: file not found: $PROVENANCE_FILE" >&2
  exit 1
fi

echo "===== Provenance Summary ====="
echo "File: $PROVENANCE_FILE"
echo

jq -r '
{
  service_name: (.service_name // "unknown"),
  image_name: (.artifact.image_name // "unknown"),
  image_tag: (.artifact.image_tag // "unknown"),
  image_id: (.artifact.image_id // "unknown"),
  source_repository: (.source.repository // "unknown"),
  commit_sha: (.source.commit_sha // "unknown"),
  branch: (.source.branch // "unknown"),
  builder: (.build.builder // "unknown"),
  workflow: (.build.workflow // "unknown"),
  built_at: (.build.built_at // "unknown")
}
' "$PROVENANCE_FILE" | jq .
```

Make executable:

```bash id="p09y1i"
chmod +x scripts/provenance-summary.sh
```

Run:

```bash id="yyp87c"
./scripts/provenance-summary.sh "$LATEST_PROV"
```

---

# 19. Add Provenance to Release Metadata

Your release metadata should reference provenance.

Create metadata with provenance path:

```bash id="eal1lx"
cd ~/devops-masterclass/07-artifact-management-registries

LATEST_PROV="$(ls -t provenance/manual/*.manual-provenance.json | head -n 1)"
LATEST_SBOM="$(ls -t sbom/cyclonedx/demo-node-api-*.trivy.cdx.json 2>/dev/null | head -n 1 || true)"

BASE_VERSION=0.7.0 \
CHANNEL=stable \
IMAGE_NAME=demo-node-api \
TEST_STATUS=passed \
SCAN_STATUS=passed \
SBOM_PATH="$LATEST_SBOM" \
PROVENANCE_PATH="$LATEST_PROV" \
./scripts/create-release-metadata.sh
```

Your current `create-release-metadata.sh` may not yet include `PROVENANCE_PATH`. Add it.

Open:

```bash id="4szblb"
nano scripts/create-release-metadata.sh
```

Add variable near other variables:

```bash id="x5km4w"
PROVENANCE_PATH="${PROVENANCE_PATH:-}"
```

Add JSON field:

```json id="2lmegb"
  "provenance_path": "$PROVENANCE_PATH",
```

Now rerun metadata creation.

Professional rule:

```text id="0sjjgs"
Release metadata should link artifact version, SBOM, scan result, and provenance.
```

---

# 20. Provenance in CI/CD Release Records

Your final release evidence should connect:

```text id="7u53y0"
image tag
image digest
SBOM path
provenance path or attestation reference
test result
scan result
promotion record
deployment report
```

Example final release record:

```json id="3cm3wh"
{
  "service_name": "demo-node-api",
  "deploy_tag": "0.7.0-a1b2c3d",
  "image_ref": "ghcr.io/user/demo-node-api:0.7.0-a1b2c3d",
  "repo_digests": [
    "ghcr.io/user/demo-node-api@sha256:abc..."
  ],
  "sbom_path": "sbom/cyclonedx/demo-node-api-0.7.0-a1b2c3d.trivy.cdx.json",
  "provenance_path": "provenance/manual/demo-node-api-0.7.0-a1b2c3d.manual-provenance.json",
  "test_status": "passed",
  "scan_status": "passed"
}
```

This is the beginning of professional release evidence.

---

# 21. Provenance and Secrets

Provenance can leak information if configured carelessly.

Possible sensitive metadata:

```text id="oqd3bk"
internal repository paths
private build arguments
dependency URLs
builder environment details
internal usernames
private branch names
```

Docker’s provenance docs expose modes like `min` and `max`; `max` gives more complete provenance, but teams should consider what metadata they publish externally. ([Docker Documentation][5])

Professional rule:

```text id="aehk68"
Use detailed provenance internally; review before publishing provenance publicly.
```

For public portfolio:

```text id="r959cf"
safe:
  repo URL
  commit SHA
  workflow name
  image tag

avoid:
  secrets
  internal private URLs
  sensitive build args
```

---

# 22. Provenance and Build Arguments

Your Docker build uses:

```bash id="t9b5kt"
--build-arg APP_VERSION=...
--build-arg COMMIT_SHA=...
```

These are safe.

Dangerous build args:

```bash id="hm6kma"
--build-arg NPM_TOKEN=...
--build-arg DATABASE_PASSWORD=...
--build-arg API_KEY=...
```

Never use build args for secrets.

Use BuildKit secrets for build-time secrets:

```Dockerfile id="w14o9t"
RUN --mount=type=secret,id=npm_token ...
```

We will cover secret-safe builds deeper in supply-chain security.

Core rule:

```text id="u459iu"
Do not put secrets in build args, image layers, provenance, or logs.
```

---

# 23. Provenance Notes

Create:

```bash id="ks0972"
nano notes/provenance-build-attestations.md
```

Paste:

````markdown id="xtlrhd"
# Provenance and Build Attestations

## What Is Provenance?

Provenance describes how an artifact was produced.

It answers:

- who built it
- where it was built
- when it was built
- from which source repository
- from which commit
- using which workflow
- using which builder

## SBOM vs Provenance vs Signature

- SBOM: what is inside
- Provenance: how it was built
- Signature: who signed/approved it

## Attestation

An attestation is a statement about an artifact.

Examples:

- this artifact has this SBOM
- this artifact was built by this workflow
- this artifact passed this scan

## BuildKit Provenance

```bash
docker buildx build \
  --provenance=mode=max \
  --sbom=true \
  --push \
  -t registry/image:tag .
````

## GitHub Actions

```yaml
permissions:
  contents: read
  packages: write
  id-token: write
  attestations: write
```

```yaml id="x00e63"
- uses: docker/build-push-action@v6
  with:
    push: true
    provenance: mode=max
    sbom: true
```

## Production Rules

* Generate provenance in CI.
* Link provenance to exact image digest.
* Store provenance with release evidence.
* Verify provenance before production deployment where possible.
* Do not expose sensitive build metadata publicly.
* Do not put secrets in build args.

````

---

# 24. Provenance Verification Policy Notes

Create:

```bash id="kv2it5"
nano notes/provenance-verification-policy.md
````

Paste:

````markdown id="35m88e"
# Provenance Verification Policy

## Goal

Only deploy artifacts that were built by trusted systems from trusted source.

## Required Checks

For production deployment, verify:

- source repository is expected
- commit SHA is recorded
- image tag is immutable
- image digest is recorded
- builder is trusted
- workflow is expected
- SBOM exists
- scan passed
- provenance exists

## Example Policy

Allow deployment only if:

```text
source repository = devops-masterclass
builder = GitHub Actions
workflow = ghcr-build-push.yml or ecr-build-push.yml
branch/tag = main or v*
scan_status = passed
````

## Red Flags

* image manually pushed without provenance
* image built from unknown repo
* image built from unreviewed branch
* provenance missing
* image digest missing
* release metadata missing
* tag is latest
* secrets appear in build metadata

````

---

# 25. GitHub Verification Concept

GitHub provides commands and features for verifying artifact attestations. The exact verification command depends on artifact type, repository visibility, and whether attestations were pushed to a registry. Use GitHub’s current artifact attestation docs when implementing verification in a real repo because this feature evolves quickly. GitHub’s documentation explains artifact attestations can be used to verify where and how software was built. :contentReference[oaicite:11]{index=11}

Conceptual verification flow:

```text id="d8f0p9"
consumer has image digest
  ↓
fetch attestation
  ↓
verify signature/trusted identity
  ↓
check source repo/workflow/commit policy
  ↓
allow deployment
````

For now, your learning implementation uses:

```text id="foe27x"
manual provenance JSON
policy JSON
validation script
```

Later we will use actual signing and verification with Cosign/Sigstore.

---

# 26. Add Makefile Targets

Open:

```bash id="v8ix9t"
cd ~/devops-masterclass/07-artifact-management-registries

nano Makefile
```

Add:

```Makefile id="6ihikb"
.PHONY: provenance provenance-summary validate-provenance

provenance:
	@test -n "$(IMAGE_TAG)" || (echo "Usage: make provenance IMAGE_TAG=<tag>" && exit 1)
	IMAGE_TAG="$(IMAGE_TAG)" ./scripts/create-manual-provenance.sh

provenance-summary:
	@LATEST=$$(ls -t provenance/manual/*.manual-provenance.json | head -n 1); \
	./scripts/provenance-summary.sh "$$LATEST"

validate-provenance:
	@LATEST=$$(ls -t provenance/manual/*.manual-provenance.json | head -n 1); \
	./scripts/validate-manual-provenance.sh "$$LATEST"
```

Use:

```bash id="90hwz8"
make provenance IMAGE_TAG="$DEPLOY_TAG"
make provenance-summary
make validate-provenance
```

---

# 27. Final Validation

Run:

```bash id="ssbn69"
cd ~/devops-masterclass/07-artifact-management-registries

VERSION_JSON="$(BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"

echo "$DEPLOY_TAG"
```

Build if needed:

```bash id="2jo1qg"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
```

Create provenance:

```bash id="oi4jhl"
cd ~/devops-masterclass/07-artifact-management-registries

IMAGE_TAG="$DEPLOY_TAG" ./scripts/create-manual-provenance.sh
LATEST_PROV="$(ls -t provenance/manual/*.manual-provenance.json | head -n 1)"

./scripts/provenance-summary.sh "$LATEST_PROV"
./scripts/validate-manual-provenance.sh "$LATEST_PROV"
```

Generate SBOM if not done:

```bash id="i6qfqm"
IMAGE_TAG="$DEPLOY_TAG" TOOL=trivy ./scripts/generate-sbom.sh
```

Create release metadata with SBOM and provenance:

```bash id="5j9vvc"
LATEST_SBOM="$(ls -t sbom/cyclonedx/demo-node-api-$DEPLOY_TAG*.json | head -n 1)"

BASE_VERSION=0.7.0 \
CHANNEL=stable \
IMAGE_NAME=demo-node-api \
TEST_STATUS=passed \
SCAN_STATUS=passed \
SBOM_PATH="$LATEST_SBOM" \
PROVENANCE_PATH="$LATEST_PROV" \
./scripts/create-release-metadata.sh
```

Validate metadata:

```bash id="wyfxms"
LATEST_METADATA="$(ls -t release-records/demo-node-api-*.json | head -n 1)"
./scripts/validate-release-metadata.sh "$LATEST_METADATA"
cat "$LATEST_METADATA" | jq .
```

---

# 28. Commit Work

Run:

```bash id="8u04j8"
cd ~/devops-masterclass

git status
git add 07-artifact-management-registries

git commit -m "feat: add provenance and build attestation workflows"
git push
```

---

# 29. Interview Explanation

## What is provenance?

Strong answer:

```text id="6qphcj"
Provenance is metadata that describes how an artifact was produced. It records source repository, commit SHA, builder identity, workflow, build time, build inputs, and the resulting artifact identity. It helps verify that an artifact came from the expected source and build system.
```

## SBOM vs provenance?

Strong answer:

```text id="yfh791"
An SBOM tells what components are inside the artifact. Provenance tells how the artifact was built, from which source, by which builder, and through which workflow.
```

## What is an attestation?

Strong answer:

```text id="1ec7la"
An attestation is a statement or claim about an artifact, often tied to the artifact digest and signed by a trusted identity. Examples include SBOM attestations and build provenance attestations.
```

## Why is provenance important in CI/CD?

Strong answer:

```text id="8go42v"
Provenance helps prevent untrusted or manually built artifacts from reaching production. A deployment system can verify that an image was built by the approved CI workflow from the expected repository and commit before allowing deployment.
```

## What is SLSA?

Strong answer:

```text id="k14e6q"
SLSA stands for Supply-chain Levels for Software Artifacts. It is a supply-chain security framework that defines controls to improve artifact integrity, reduce tampering risk, and strengthen trust in how software is built and distributed.
```

## What should a production provenance policy check?

Strong answer:

```text id="4d6903"
It should check that the artifact digest matches release metadata, the source repository is trusted, the commit SHA is recorded, the workflow is approved, the builder identity is trusted, SBOM exists, vulnerability scan passed, and the artifact was not built manually outside the approved pipeline.
```

---

# Today’s Core Rules

```text id="119vyu"
Provenance explains how an artifact was built.
SBOM explains what is inside.
Signature proves trusted signing identity.
Attestation is a claim about an artifact.
BuildKit can generate SBOM and provenance attestations.
GitHub Actions can generate artifact attestations.
Provenance should reference exact artifact digest.
Generate provenance in CI.
Verify provenance before production where possible.
Do not expose sensitive build metadata publicly.
Do not use build args for secrets.
Release metadata should link image, SBOM, scan result, and provenance.
SLSA is a framework for supply-chain integrity.
```

---

# Next Lesson

# Lesson 7.9 — Image Signing with Cosign and Sigstore Concepts

We will go deeper into:

```text id="d2q6fn"
why signing matters
key-based signing
keyless signing
Sigstore
Cosign
Fulcio
Rekor transparency log
signing Docker images
verifying signatures
policy-based deployment
signature vs provenance vs SBOM
production trust workflow
```

[1]: https://slsa.dev/spec/v0.1/provenance?utm_source=chatgpt.com "Provenance"
[2]: https://docs.github.com/en/actions/concepts/security/artifact-attestations?utm_source=chatgpt.com "Artifact attestations"
[3]: https://docs.docker.com/build/metadata/attestations/?utm_source=chatgpt.com "Build attestations"
[4]: https://slsa.dev/?utm_source=chatgpt.com "SLSA • Supply-chain Levels for Software Artifacts"
[5]: https://docs.docker.com/build/metadata/attestations/slsa-provenance/?utm_source=chatgpt.com "Provenance attestations"
[6]: https://docs.docker.com/build/ci/github-actions/attestations/?utm_source=chatgpt.com "Add SBOM and provenance attestations with GitHub Actions"
[7]: https://docs.github.com/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds?utm_source=chatgpt.com "Using artifact attestations to establish provenance for builds"
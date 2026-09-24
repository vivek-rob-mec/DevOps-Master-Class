# Module 7 — Artifact Management and Registries

# Lesson 7.1 — Artifact Management Fundamentals Masterclass

Welcome to **Module 7**.

In Module 6, we learned how to build, run, secure, deploy, troubleshoot, and operate Docker containers.

Now we move one level higher.

Docker images are not just “containers.”

They are **artifacts**.

In real DevOps, CI/CD is mostly about producing, securing, storing, promoting, and deploying artifacts.

---

# Module 7 Learning Path

We will cover:

```text id="tquekr"
7.1  Artifact management fundamentals
7.2  Versioning and release metadata
7.3  Checksums, digests, immutability, and reproducibility
7.4  Docker registries deep dive: Docker Hub, GHCR, ECR
7.5  ECR production workflow with IAM and lifecycle policies
7.6  GHCR production workflow
7.7  SBOM fundamentals
7.8  Provenance and build attestations
7.9  Image signing with Cosign/Sigstore concepts
7.10 Artifact promotion: dev -> staging -> prod
7.11 Registry security and access control
7.12 Artifact cleanup, retention, and rollback safety
7.13 Artifact management CI/CD capstone
```

By the end of this module, you should be able to explain and implement:

```text id="330kwk"
build once, promote many
immutable artifacts
release metadata
artifact checksums
image digests
SBOMs
provenance
registry security
artifact retention
image promotion
rollback-safe artifact lifecycle
```

---

# 1. Beginner Level — What Is an Artifact?

An artifact is any output produced by a build process that can be stored, versioned, tested, scanned, promoted, or deployed.

Examples:

```text id="mn8yi4"
Docker image
.tar.gz release package
Node.js package
Python wheel
Java .jar file
Helm chart
Terraform plan file
SBOM file
test report
coverage report
deployment report
checksum file
```

Simple definition:

```text id="kl74p0"
An artifact is a build output that represents something we may deploy, verify, store, or audit.
```

In your project, these are artifacts:

```text id="m4yk05"
demo-node-api:0.3.0 Docker image
deployment-records/deploy-*.json
mongo backup tar.gz
SBOM JSON file
release metadata JSON
Docker image digest
```

---

# 2. Beginner Mental Model

Source code is not the same as artifact.

```text id="h10p37"
Source code:
  what developers write

Artifact:
  what CI builds from source code

Deployment:
  running the artifact in an environment
```

Flow:

```text id="26nlao"
Git commit
  ↓
CI pipeline
  ↓
Build artifact
  ↓
Store artifact
  ↓
Scan artifact
  ↓
Promote artifact
  ↓
Deploy artifact
```

Core rule:

```text id="dz7wk5"
Production should deploy artifacts, not raw source code.
```

---

# 3. Beginner Example

You write code:

```text id="j42x0m"
server.js
src/config.js
src/logger.js
```

CI builds Docker image:

```text id="hhl07m"
demo-node-api:0.3.0-a1b2c3d
```

That Docker image is the artifact.

Then staging and production should deploy the same artifact:

```text id="czba3e"
staging -> demo-node-api:0.3.0-a1b2c3d
production -> demo-node-api:0.3.0-a1b2c3d
```

Not this:

```text id="6yo5l9"
staging builds its own image
production builds another image
```

That creates drift.

---

# 4. Intermediate Level — Artifact Types in DevOps

## Application artifacts

```text id="1clnpi"
Docker image
.jar
.war
.zip
.tar.gz
Python wheel
npm package
```

## Infrastructure artifacts

```text id="qnbvjv"
Terraform plan
Ansible inventory package
Helm chart
Kubernetes manifest bundle
CloudFormation template package
```

## Security artifacts

```text id="ls5hzh"
SBOM
vulnerability scan report
provenance attestation
image signature
policy report
```

## Quality artifacts

```text id="gihn58"
test report
coverage report
lint report
performance report
load test report
```

## Operations artifacts

```text id="4b03ei"
deployment report
rollback report
backup file
incident report
diagnostics report
resource report
```

Professional understanding:

```text id="hglaux"
A mature CI/CD system manages many artifact types, not only the deployable application.
```

---

# 5. Professional Level — Why Artifact Management Matters

Artifact management solves these problems:

```text id="mlasva"
What exactly did we deploy?
Who built it?
From which commit?
When was it built?
Was it tested?
Was it scanned?
Was it approved?
What dependencies are inside?
Can we rollback?
Can we reproduce it?
Can we prove it was not tampered with?
```

Without artifact management, production becomes guesswork.

Bad deployment conversation:

```text id="7ztg85"
Which version is running?
Maybe latest.
Which commit?
Not sure.
Can we rollback?
Maybe.
Was this image scanned?
I don't know.
```

Good deployment conversation:

```text id="349x7l"
Production runs demo-node-api:0.3.0-a1b2c3d.
It was built from commit a1b2c3d.
It passed tests.
It passed image scan.
Its digest is sha256:...
Its SBOM is stored.
Previous version is 0.2.2-f8e9d10.
Rollback is available.
```

That is professional DevOps.

---

# 6. Expert Level — Artifact Lifecycle

A production artifact usually goes through this lifecycle:

```text id="6alky1"
1. Source commit created
2. CI builds artifact
3. Artifact is tagged
4. Artifact metadata is generated
5. Artifact is scanned
6. Artifact is stored in registry/repository
7. Artifact is promoted to environment
8. Artifact is deployed
9. Artifact is monitored
10. Artifact is retained for rollback/audit
11. Artifact is eventually expired by policy
```

Important:

```text id="35mp37"
Promotion should not mean rebuild.
Promotion should mean approving the same artifact for the next environment.
```

---

# 7. Industry Standard Principle — Build Once, Promote Many

This is one of the most important DevOps principles.

Bad:

```text id="o0uwzm"
Build image for dev
Build image again for staging
Build image again for prod
```

Why bad?

```text id="0sgj3w"
different timestamps
different dependency versions
different base image state
different build environment
different result
```

Good:

```text id="lusgb8"
Build once in CI
Store artifact in registry
Promote same artifact to dev
Promote same artifact to staging
Promote same artifact to production
```

Best mental model:

```text id="ia309w"
Environment changes config.
Environment should not change artifact.
```

---

# 8. Artifact Metadata

Every artifact should have metadata.

Metadata answers:

```text id="p0iyl4"
artifact name
version
commit SHA
build date
builder
source repository
image tag
image digest
tests passed
scan result
SBOM location
environment promoted to
```

Example metadata:

```json id="l1ed7s"
{
  "artifact_name": "demo-node-api",
  "artifact_type": "docker_image",
  "version": "0.3.0",
  "commit_sha": "a1b2c3d",
  "image": "ghcr.io/example/demo-node-api:0.3.0-a1b2c3d",
  "digest": "sha256:example",
  "built_at": "2026-07-04T10:00:00Z",
  "tests": "passed",
  "scan": "passed"
}
```

Professional rule:

```text id="rm750h"
If you cannot identify an artifact, you cannot safely deploy or rollback it.
```

---

# 9. Hands-On — Create Module 7 Directory

Run:

```bash id="7xo4wx"
cd ~/devops-masterclass

mkdir -p 07-artifact-management-registries/{notes,scripts,examples,release-records,checksums,sbom,reports}
```

Check:

```bash id="96157l"
tree -L 2 07-artifact-management-registries
```

Expected:

```text id="uvctv1"
07-artifact-management-registries
├── checksums
├── examples
├── notes
├── release-records
├── reports
├── sbom
└── scripts
```

---

# 10. Create Artifact Fundamentals Notes

Create:

```bash id="2hff28"
cd ~/devops-masterclass/07-artifact-management-registries

nano notes/artifact-management-fundamentals.md
```

Paste:

````markdown id="5x2ge1"
# Artifact Management Fundamentals

## What Is an Artifact?

An artifact is a build output that can be stored, versioned, tested, scanned, promoted, deployed, audited, or rolled back.

## Examples

- Docker image
- `.tar.gz` release package
- `.jar`
- Python wheel
- npm package
- Helm chart
- Terraform plan
- SBOM
- vulnerability scan report
- deployment report
- backup file

## Source Code vs Artifact

Source code is what developers write.

Artifact is what CI builds.

Production should deploy artifacts, not raw source code.

## Artifact Lifecycle

```text
source commit
  -> build
  -> tag
  -> test
  -> scan
  -> store
  -> promote
  -> deploy
  -> monitor
  -> retain
  -> expire
````

## Core Principle

Build once, promote many.

Do not rebuild separately for dev, staging, and production.

## Artifact Metadata

Good artifact metadata should include:

* artifact name
* artifact type
* version
* commit SHA
* source repository
* build date
* image tag
* image digest
* test result
* scan result
* SBOM location
* promotion status

## Professional Rules

* Use immutable artifact versions.
* Store artifacts in a registry or repository.
* Keep metadata with artifacts.
* Scan artifacts before promotion.
* Retain artifacts needed for rollback.
* Do not deploy unknown artifacts.

````

---

# 11. Hands-On — Build a Release Artifact Package

Even though Docker image is your main artifact, let’s also create a `.tar.gz` release artifact.

Go to app:

```bash id="a1etmr"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
````

Create release package manually:

```bash id="u54fz5"
VERSION=0.3.0
COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo local)
ARTIFACT_NAME="demo-node-api-${VERSION}-${COMMIT_SHA}.tar.gz"

mkdir -p /tmp/demo-node-api-release

tar \
  --exclude=node_modules \
  --exclude=.env \
  --exclude=".env.*" \
  --exclude=coverage \
  --exclude=reports \
  --exclude="*.log" \
  -czf "/tmp/$ARTIFACT_NAME" \
  server.js src package.json package-lock.json Dockerfile.industry .dockerignore

ls -lh "/tmp/$ARTIFACT_NAME"
```

Copy into Module 7 examples:

```bash id="t71qxg"
cp "/tmp/$ARTIFACT_NAME" ~/devops-masterclass/07-artifact-management-registries/examples/
```

Check:

```bash id="fn5pom"
ls -lh ~/devops-masterclass/07-artifact-management-registries/examples/
```

This `.tar.gz` is a traditional release artifact.

---

# 12. Intermediate — Checksums

A checksum verifies file integrity.

If artifact changes, checksum changes.

Common checksum:

```text id="toocxg"
sha256
```

Generate checksum:

```bash id="jdw4fx"
cd ~/devops-masterclass/07-artifact-management-registries

sha256sum examples/demo-node-api-*.tar.gz | tee checksums/demo-node-api.sha256
```

Verify later:

```bash id="3k6djk"
sha256sum -c checksums/demo-node-api.sha256
```

Expected:

```text id="qfflz9"
OK
```

Why this matters:

```text id="30gvbw"
detects corruption
detects accidental changes
helps verify artifact integrity
supports audit and release processes
```

Professional rule:

```text id="beqebr"
Every release artifact should have a checksum or digest.
```

---

# 13. Docker Image Digest vs File Checksum

For files:

```bash id="ia4862"
sha256sum artifact.tar.gz
```

For Docker images:

```bash id="vt5v0y"
docker image inspect demo-node-api:0.3.0 --format '{{json .RepoDigests}}'
```

If image was pushed/pulled from registry, you may see:

```text id="7o0zvi"
registry/repo@sha256:...
```

A Docker digest identifies image content.

Beginner difference:

```text id="m8f5v8"
tag = name pointer
digest = exact content identity
```

Professional rule:

```text id="b53ypr"
Deploy using immutable tags, and record digests when possible.
```

---

# 14. Hands-On — Create Artifact Metadata Script

Create script:

```bash id="dqr53t"
cd ~/devops-masterclass/07-artifact-management-registries

nano scripts/create-artifact-metadata.sh
```

Paste:

```bash id="ipyahk"
#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_NAME="${ARTIFACT_NAME:-demo-node-api}"
ARTIFACT_TYPE="${ARTIFACT_TYPE:-docker_image}"
VERSION="${VERSION:-0.3.0}"
COMMIT_SHA="${COMMIT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"
IMAGE_NAME="${IMAGE_NAME:-demo-node-api}"
IMAGE_TAG="${IMAGE_TAG:-$VERSION}"
REGISTRY_IMAGE="${REGISTRY_IMAGE:-}"
SOURCE_REPO="${SOURCE_REPO:-devops-masterclass}"
OUTPUT_DIR="${OUTPUT_DIR:-release-records}"
BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
OUTPUT_FILE="$OUTPUT_DIR/${ARTIFACT_NAME}-${VERSION}-${COMMIT_SHA}.json"

mkdir -p "$OUTPUT_DIR"

LOCAL_IMAGE_ID=""
if docker image inspect "$IMAGE_NAME:$IMAGE_TAG" >/dev/null 2>&1; then
  LOCAL_IMAGE_ID="$(docker image inspect "$IMAGE_NAME:$IMAGE_TAG" --format '{{.Id}}')"
fi

REGISTRY_REF=""
if [ -n "$REGISTRY_IMAGE" ]; then
  REGISTRY_REF="$REGISTRY_IMAGE:$IMAGE_TAG"
fi

cat > "$OUTPUT_FILE" <<EOF
{
  "artifact_name": "$ARTIFACT_NAME",
  "artifact_type": "$ARTIFACT_TYPE",
  "version": "$VERSION",
  "commit_sha": "$COMMIT_SHA",
  "source_repository": "$SOURCE_REPO",
  "image_name": "$IMAGE_NAME",
  "image_tag": "$IMAGE_TAG",
  "registry_ref": "$REGISTRY_REF",
  "local_image_id": "$LOCAL_IMAGE_ID",
  "build_date": "$BUILD_DATE",
  "created_by": "$(whoami)",
  "status": "created"
}
EOF

echo "Artifact metadata created:"
cat "$OUTPUT_FILE" | jq .
```

Make executable:

```bash id="ey1xoe"
chmod +x scripts/create-artifact-metadata.sh
```

Run:

```bash id="z7f9ni"
VERSION=0.3.0 IMAGE_NAME=demo-node-api IMAGE_TAG=0.3.0 ./scripts/create-artifact-metadata.sh
```

Check:

```bash id="99dnrd"
ls -lh release-records
cat release-records/*.json | jq .
```

---

# 15. Professional — Artifact Repository vs Container Registry

Artifact repository is a general storage system for build artifacts.

Examples:

```text id="chmzio"
Nexus Repository
JFrog Artifactory
GitHub Releases
GitLab Package Registry
AWS CodeArtifact
S3 artifact bucket
```

Container registry is specifically for container images.

Examples:

```text id="n4p3be"
Docker Hub
GHCR
ECR
GCR / Artifact Registry
ACR
Harbor
GitLab Container Registry
```

Difference:

```text id="t0wiv2"
Artifact repository stores many package types.
Container registry stores container images.
```

In real companies, both may exist:

```text id="mwkdzh"
Docker images -> ECR/GHCR/Harbor
JAR files -> Nexus/Artifactory
Helm charts -> OCI registry or chart repo
SBOMs -> artifact repository
deployment reports -> S3/GitHub artifacts
```

---

# 16. Professional — Artifact Immutability

An immutable artifact does not change after creation.

Bad:

```text id="wmdv29"
demo-node-api:latest keeps changing
release.tar.gz overwritten every deploy
same version tag points to different content
```

Good:

```text id="eyayip"
demo-node-api:0.3.0-a1b2c3d
demo-node-api-0.3.0-a1b2c3d.tar.gz
metadata-0.3.0-a1b2c3d.json
```

Core rule:

```text id="hkvfgn"
Never overwrite release artifacts.
Create a new version instead.
```

Why?

```text id="5appmd"
rollback safety
auditability
reproducibility
incident investigation
change control
compliance
```

---

# 17. Expert — Reproducibility

A reproducible build means:

```text id="dj6096"
same source
same dependencies
same build environment
same output
```

This is difficult in real systems.

Problems:

```text id="gfrdrv"
floating dependency versions
latest base images
timestamps inside artifacts
different build machines
network downloads changing
missing lockfiles
non-deterministic build steps
```

Controls:

```text id="8m6z16"
package-lock.json
npm ci
pinned base image versions
immutable image tags
recorded digests
SBOM
provenance
CI-controlled builds
no manual production builds
```

Professional truth:

```text id="af54il"
Most teams do not achieve perfect reproducibility, but mature teams reduce uncertainty with metadata, lockfiles, digests, and controlled CI builds.
```

---

# 18. Expert — Artifact Promotion vs Deployment

Promotion means:

```text id="wp0grx"
this artifact is approved for the next environment
```

Deployment means:

```text id="wv8pyk"
this artifact is now running in an environment
```

Example:

```text id="p55ix7"
artifact built: demo-node-api:0.3.0-a1b2c3d
promoted to staging
deployed to staging
tested in staging
promoted to production
deployed to production
```

Promotion metadata:

```json id="nufj7o"
{
  "artifact": "demo-node-api:0.3.0-a1b2c3d",
  "from": "staging",
  "to": "production",
  "approved_by": "release-manager",
  "approved_at": "2026-07-04T12:00:00Z"
}
```

Professional rule:

```text id="86v17j"
Promotion should be explicit, auditable, and based on the same artifact.
```

---

# 19. Hands-On — Create Promotion Record Script

Create:

```bash id="cg1v71"
cd ~/devops-masterclass/07-artifact-management-registries

nano scripts/create-promotion-record.sh
```

Paste:

```bash id="5r38t9"
#!/usr/bin/env bash
set -euo pipefail

ARTIFACT="${ARTIFACT:-}"
FROM_ENV="${FROM_ENV:-dev}"
TO_ENV="${TO_ENV:-staging}"
APPROVED_BY="${APPROVED_BY:-$(whoami)}"
OUTPUT_DIR="${OUTPUT_DIR:-release-records/promotions}"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if [ -z "$ARTIFACT" ]; then
  echo "ERROR: ARTIFACT is required" >&2
  echo "Example: ARTIFACT=demo-node-api:0.3.0-a1b2c3d FROM_ENV=staging TO_ENV=prod $0" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

SAFE_ARTIFACT="$(echo "$ARTIFACT" | tr '/:@' '____')"
OUTPUT_FILE="$OUTPUT_DIR/${SAFE_ARTIFACT}-${FROM_ENV}-to-${TO_ENV}.json"

cat > "$OUTPUT_FILE" <<EOF
{
  "artifact": "$ARTIFACT",
  "from_environment": "$FROM_ENV",
  "to_environment": "$TO_ENV",
  "approved_by": "$APPROVED_BY",
  "approved_at": "$TIMESTAMP",
  "status": "promoted"
}
EOF

echo "Promotion record created:"
cat "$OUTPUT_FILE" | jq .
```

Make executable:

```bash id="esusks"
chmod +x scripts/create-promotion-record.sh
```

Run:

```bash id="42uy36"
ARTIFACT=demo-node-api:0.3.0 FROM_ENV=dev TO_ENV=staging ./scripts/create-promotion-record.sh
ARTIFACT=demo-node-api:0.3.0 FROM_ENV=staging TO_ENV=production ./scripts/create-promotion-record.sh
```

Check:

```bash id="ohvfi0"
find release-records/promotions -type f -maxdepth 1 -print -exec cat {} \; | jq .
```

---

# 20. Corporate Example — Artifact Flow

A corporate backend service might follow this:

```text id="qmkaw8"
Developer merges PR
  ↓
CI runs tests
  ↓
CI builds Docker image
  ↓
CI tags image with Git SHA
  ↓
CI generates SBOM
  ↓
CI scans image
  ↓
CI pushes image to registry
  ↓
Dev auto-deploys
  ↓
QA approves staging promotion
  ↓
Staging deploys same image
  ↓
Security gates pass
  ↓
Release manager approves prod
  ↓
Prod deploys same image digest
  ↓
Deployment report stored
```

Artifact trail:

```text id="gm8vsk"
commit SHA
image tag
image digest
SBOM
scan result
promotion record
deployment report
rollback record
```

This is the difference between hobby deployment and enterprise deployment.

---

# 21. Expert — Artifact Governance

Artifact governance means rules around artifact creation and usage.

Examples:

```text id="casza4"
Only CI can publish production artifacts.
Artifacts must be scanned.
Critical vulnerabilities block promotion.
Production images must have SBOM.
Production deployment must use immutable tag or digest.
Artifacts must be retained for rollback.
Old artifacts expire by lifecycle policy.
Secrets must not exist inside artifacts.
```

Bad governance:

```text id="4envqk"
developers manually build on server
latest tag used everywhere
old images deleted randomly
no scan reports
no release metadata
no rollback artifact
```

Good governance:

```text id="3por1r"
CI builds
registry stores
security scans
metadata records
promotion approvals
retention policy
rollback tested
```

---

# 22. Create Artifact Inventory

Create:

```bash id="g7dp7y"
cd ~/devops-masterclass/07-artifact-management-registries

nano examples/artifact-inventory.json
```

Paste:

```json id="zo90si"
{
  "project": "devops-masterclass",
  "service": "demo-node-api",
  "artifacts": [
    {
      "name": "demo-node-api",
      "type": "docker_image",
      "example": "demo-node-api:0.3.0",
      "storage": "local Docker / GHCR / ECR",
      "deployable": true
    },
    {
      "name": "demo-node-api-release-package",
      "type": "tar.gz",
      "example": "demo-node-api-0.3.0-a1b2c3d.tar.gz",
      "storage": "artifact repository / GitHub release / S3",
      "deployable": false
    },
    {
      "name": "docker-image-sbom",
      "type": "sbom",
      "example": "sbom-demo-node-api.json",
      "storage": "artifact repository / registry attestation",
      "deployable": false
    },
    {
      "name": "deployment-report",
      "type": "json_report",
      "example": "deploy-20260704.json",
      "storage": "deployment-records / CI artifacts / S3",
      "deployable": false
    },
    {
      "name": "mongo-backup",
      "type": "backup",
      "example": "mongo_data_20260704.tar.gz",
      "storage": "backup storage",
      "deployable": false
    }
  ]
}
```

View:

```bash id="i4vdo8"
cat examples/artifact-inventory.json | jq .
```

---

# 23. Create Artifact Policy

Create:

```bash id="lj3cte"
nano notes/artifact-policy.md
```

Paste:

```markdown id="1n0kme"
# Artifact Policy

## Build Policy

- Production artifacts must be built by CI.
- Manual builds are allowed only for local testing.
- Build must use lockfiles where available.
- Build must produce metadata.

## Version Policy

- Production artifacts must use immutable versions.
- Do not rely on `latest`.
- Use version + commit SHA where possible.

## Security Policy

- Artifacts must be scanned before promotion.
- Secrets must not be included inside artifacts.
- SBOM should be generated for production artifacts.
- Critical vulnerabilities require fix or documented exception.

## Promotion Policy

- Dev promotion can be automatic.
- Staging promotion requires successful CI.
- Production promotion requires approval.
- Same artifact must be promoted; do not rebuild.

## Retention Policy

- Keep production artifacts.
- Keep previous production artifact for rollback.
- Keep recent CI artifacts for debugging.
- Delete old temporary artifacts by lifecycle policy.
- Never delete artifacts currently deployed.

## Rollback Policy

- Rollback uses previous immutable artifact.
- Rollback must be validated by health checks.
- Rollback reports must be stored.
```

---

# 24. Add Makefile for Module 7

Create:

```bash id="pq81h0"
cd ~/devops-masterclass/07-artifact-management-registries

nano Makefile
```

Paste:

```Makefile id="syd2el"
.PHONY: metadata promotion checksum inventory

metadata:
	VERSION?=0.3.0 IMAGE_NAME?=demo-node-api IMAGE_TAG?=0.3.0 ./scripts/create-artifact-metadata.sh

promotion:
	@test -n "$(ARTIFACT)" || (echo "Usage: make promotion ARTIFACT=<artifact> FROM_ENV=dev TO_ENV=staging" && exit 1)
	ARTIFACT="$(ARTIFACT)" FROM_ENV="$(FROM_ENV)" TO_ENV="$(TO_ENV)" ./scripts/create-promotion-record.sh

checksum:
	sha256sum examples/*.tar.gz | tee checksums/artifacts.sha256

inventory:
	cat examples/artifact-inventory.json | jq .
```

Use:

```bash id="aqe2mp"
make metadata
make promotion ARTIFACT=demo-node-api:0.3.0 FROM_ENV=dev TO_ENV=staging
make inventory
```

---

# 25. Troubleshooting Artifact Problems

## Problem 1 — “Which artifact is deployed?”

Check deployment report:

```bash id="c5a3jo"
cd ~/devops-masterclass/06-docker-containers/compose-demo

cat "$(ls -t deployment-records/deploy-*.json | head -n 1)" | jq .
```

Check running image:

```bash id="5xcz6a"
docker inspect compose-demo-backend --format '{{.Config.Image}}'
```

Check app version endpoint:

```bash id="3qmng7"
curl -s http://127.0.0.1:8080/version | jq .
```

---

## Problem 2 — Artifact checksum fails

Run:

```bash id="57q5ve"
cd ~/devops-masterclass/07-artifact-management-registries

sha256sum -c checksums/demo-node-api.sha256
```

If failed:

```text id="7rxtu9"
artifact changed
wrong file
corruption occurred
checksum file outdated
```

Correct behavior:

```text id="ltrk5y"
Do not silently ignore checksum mismatch.
Investigate and regenerate only if intentionally creating a new artifact.
```

---

## Problem 3 — Cannot rollback

Possible reasons:

```text id="fcutol"
previous artifact deleted
previous image tag overwritten
registry credentials expired
deployment report missing previous version
artifact was rebuilt instead of promoted
```

Fix:

```text id="j9517l"
use immutable tags
retain previous production artifacts
record deployment metadata
test rollback
```

---

## Problem 4 — Artifact contains secret

Search tar artifact:

```bash id="s7ricd"
tar tzf examples/demo-node-api-*.tar.gz
```

Extract to temp and search:

```bash id="xryzj8"
mkdir -p /tmp/artifact-check
tar xzf examples/demo-node-api-*.tar.gz -C /tmp/artifact-check

grep -R "DATABASE_URL\|PASSWORD\|SECRET\|TOKEN" /tmp/artifact-check || true
```

If secrets found:

```text id="vewfdd"
remove artifact
rotate leaked secret
fix build packaging
add .dockerignore/.gitignore rules
add CI secret scan
```

---

# 26. Interview Explanation

## What is an artifact?

Strong answer:

```text id="3mog2l"
An artifact is a build output that can be stored, versioned, scanned, promoted, deployed, or audited. Examples include Docker images, release archives, JAR files, Helm charts, SBOMs, test reports, and deployment reports.
```

## Why is artifact management important?

Strong answer:

```text id="5q7nmr"
Artifact management gives traceability and control over what is deployed. It helps answer which version is running, which commit produced it, whether it was tested and scanned, whether it can be rolled back, and whether it matches the approved release.
```

## What does “build once, promote many” mean?

Strong answer:

```text id="q0k3e7"
It means CI builds one artifact and that same artifact is promoted through dev, staging, and production. Environment-specific behavior should come from configuration and secrets, not rebuilding different artifacts for each environment.
```

## Why should artifacts be immutable?

Strong answer:

```text id="36mkp4"
Immutable artifacts improve rollback, auditing, reproducibility, and incident investigation. If a version tag changes over time, we cannot reliably know what was tested or deployed.
```

## What metadata should be stored with artifacts?

Strong answer:

```text id="46r4i1"
I store artifact name, version, commit SHA, source repository, build date, image tag or digest, test result, scan result, SBOM location, builder identity, and promotion/deployment status.
```

---

# 27. Today’s Core Rules

```text id="wmfu8x"
Artifacts are build outputs.
Production should deploy artifacts, not raw source code.
Docker images are artifacts.
SBOMs and reports are also artifacts.
Build once, promote many.
Do not rebuild separately for each environment.
Use immutable artifact versions.
Use checksums or digests.
Store metadata with artifacts.
Scan artifacts before promotion.
Do not include secrets in artifacts.
Retain rollback artifacts.
Promotion and deployment are different.
Artifact governance is part of professional DevOps.
```

---

# 28. Commit Work

Run:

```bash id="1rs2b8"
cd ~/devops-masterclass

git status
git add 07-artifact-management-registries

git commit -m "feat: start artifact management module"
git push
```

---

# Next Lesson

# Lesson 7.2 — Versioning and Release Metadata Masterclass

We will go deeper into:

```text id="8r8r2a"
semantic versioning
Git SHA tags
build numbers
release metadata JSON
CHANGELOGs
release notes
environment promotion records
artifact traceability
professional release naming strategies
```

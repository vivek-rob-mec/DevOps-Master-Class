# Lesson 7.2 — Versioning and Release Metadata Masterclass

# Semantic Versioning, Git SHA Tags, Build Numbers, Release Metadata, Changelogs, Promotion Records, and Traceability

In Lesson 7.1, we learned:

```text id="v0b5a1"
source code -> build artifact -> artifact metadata -> promotion -> deployment
```

Now we go deeper into **versioning**.

Versioning answers:

```text id="n6m3x9"
Which build is this?
Which commit created it?
Is this a stable release or pre-release?
Can we rollback to it?
Was it deployed to staging?
Was it promoted to production?
What changed in this version?
```

A professional DevOps pipeline does not just build:

```text id="fis8br"
demo-node-api:latest
```

It builds identifiable, traceable artifacts like:

```text id="e9sm1d"
demo-node-api:1.4.2-a1b2c3d
```

---

# 1. Beginner Level — What Is Versioning?

Versioning is the practice of assigning a unique identifier to a release or artifact.

Examples:

```text id="r0zv0f"
1.0.0
1.2.3
1.2.3-rc.1
2026.07.04
0.3.0-a1b2c3d
build-152
```

Simple definition:

```text id="yaq2fh"
A version tells humans and systems which artifact they are talking about.
```

Without versioning:

```text id="nd3yam"
Which image is running?
latest.

Which commit?
Not sure.

Can we rollback?
Maybe.
```

With versioning:

```text id="jjo4v8"
Production runs demo-node-api:0.3.0-a1b2c3d.
It was built from commit a1b2c3d.
It passed tests and scan.
Previous version is 0.2.2-f8e9d10.
Rollback is available.
```

---

# 2. Beginner Mental Model

Think of versioning like a product label.

```text id="obw5pg"
Artifact:
  demo-node-api Docker image

Version label:
  0.3.0-a1b2c3d

Metadata:
  built from commit a1b2c3d
  built at 2026-07-04T10:00:00Z
  tests passed
  scan passed
  deployed to staging
```

Version is the short name.

Metadata is the full identity card.

---

# 3. Why `latest` Is Not a Version

Bad:

```yaml id="f8t1z9"
image: demo-node-api:latest
```

Problems:

```text id="p4n6fh"
latest can change
rollback is unclear
audit is weak
incident debugging is hard
environment drift happens
```

Better:

```yaml id="aqm8m7"
image: demo-node-api:0.3.0-a1b2c3d
```

Even better for high assurance:

```text id="r3gp8d"
image tag: 0.3.0-a1b2c3d
image digest: sha256:...
```

Core rule:

```text id="rbgdqz"
latest is a moving pointer, not a reliable production version.
```

---

# 4. Intermediate Level — Semantic Versioning

Semantic versioning usually follows:

```text id="yp101g"
MAJOR.MINOR.PATCH
```

Example:

```text id="w9kcbp"
2.5.1
```

Meaning:

```text id="g75zub"
2 = major
5 = minor
1 = patch
```

Common interpretation:

```text id="j9bwyh"
MAJOR: breaking changes
MINOR: backward-compatible features
PATCH: backward-compatible fixes
```

Examples:

```text id="fyg893"
1.0.0 -> first stable release
1.1.0 -> new feature
1.1.1 -> bug fix
2.0.0 -> breaking change
```

For your DevOps course project:

```text id="b2ac9g"
v0.1.0 = Module 1 completed
v0.2.0 = Git/GitHub module completed
v0.3.0 = Linux module completed
v0.4.0 = Python module completed
v0.5.0 = Runtime module completed
v0.6.0 = Docker module completed
```

Module 7 can become:

```text id="ezs5t8"
v0.7.0
```

---

# 5. Pre-Release Versions

Pre-release versions identify unstable or candidate releases.

Examples:

```text id="k6nfuh"
1.0.0-alpha.1
1.0.0-beta.1
1.0.0-rc.1
```

Meaning:

```text id="t4vhzl"
alpha = early internal testing
beta  = wider testing
rc    = release candidate
```

Professional flow:

```text id="oar6c8"
1.4.0-alpha.1  -> internal dev test
1.4.0-beta.1   -> QA/staging
1.4.0-rc.1     -> release candidate
1.4.0          -> production release
```

For Docker tags:

```text id="zsb5wo"
demo-node-api:1.4.0-rc.1-a1b2c3d
```

Good.

Avoid special characters like `+` in Docker tags.

Semantic versioning allows build metadata like:

```text id="s1fam7"
1.4.0+build.52
```

But Docker tags do not support every SemVer character. In practice, use Docker-safe tags:

```text id="l3g14y"
1.4.0-build.52
1.4.0-a1b2c3d
1.4.0-rc.1-a1b2c3d
```

---

# 6. Intermediate — Git SHA as Version Metadata

A Git commit SHA identifies exact source code.

Full SHA:

```text id="qqyl1f"
a1b2c3d4e5f678901234567890abcdef12345678
```

Short SHA:

```text id="h6dfpa"
a1b2c3d
```

Get short SHA:

```bash id="ya1dka"
git rev-parse --short HEAD
```

Use in image tags:

```bash id="e98q93"
VERSION=0.3.0
COMMIT_SHA=$(git rev-parse --short HEAD)

docker build \
  -t demo-node-api:$VERSION \
  -t demo-node-api:$COMMIT_SHA \
  -t demo-node-api:$VERSION-$COMMIT_SHA \
  .
```

Recommended production deploy tag:

```text id="znqkss"
0.3.0-a1b2c3d
```

Why?

```text id="w9xwqz"
human sees release version
machine/team can trace exact commit
rollback target is clear
```

---

# 7. Professional Versioning Strategy

For your project, use this strategy:

```text id="tic9of"
Human release version:
  0.7.0

Git source identity:
  a1b2c3d

Docker deployment tag:
  0.7.0-a1b2c3d

Git tag:
  v0.7.0

Release metadata:
  release-records/demo-node-api-0.7.0-a1b2c3d.json
```

For CI builds before release:

```text id="a62nl2"
0.7.0-dev-a1b2c3d
```

For release candidates:

```text id="alffx0"
0.7.0-rc.1-a1b2c3d
```

For production:

```text id="ba3bia"
0.7.0-a1b2c3d
```

Core rule:

```text id="yqa4wb"
Use human-readable version plus machine-traceable commit.
```

---

# 8. Professional Versioning Patterns

## Pattern 1 — SemVer + Git SHA

Best for apps.

```text id="xei4p7"
1.8.3-a1b2c3d
```

## Pattern 2 — Calendar Versioning

Useful for frequent releases.

```text id="rhicxy"
2026.07.04
2026.07.04.1
```

## Pattern 3 — Build Number

Common in Jenkins.

```text id="ytsyxg"
build-152
1.8.3-build.152
```

## Pattern 4 — Environment Channel Tags

Useful but mutable.

```text id="v1302c"
dev
staging
prod
```

Use carefully.

Bad as the only production tag:

```text id="c7yw11"
prod
```

Better:

```text id="fixlxi"
prod -> points to 1.8.3-a1b2c3d
deployment record stores exact version and digest
```

---

# 9. Expert Level — Version vs Tag vs Digest

These are related but different.

```text id="z9mk2p"
version = release identity chosen by humans
tag     = registry reference pointing to image
digest  = content identity generated from image content
```

Example:

```text id="dxwrxb"
version:
  0.3.0

tag:
  ghcr.io/org/demo-node-api:0.3.0-a1b2c3d

digest:
  ghcr.io/org/demo-node-api@sha256:abc...
```

Professional answer:

```text id="i9ovtw"
A version tells us what release it is. A tag helps us pull it. A digest proves exactly what content it is.
```

Best production record contains all three.

---

# 10. Expert Level — Versioning and Rollback

Rollback depends on versioning.

Bad rollback:

```text id="21k61c"
deploy latest again
hope it is the previous version
```

Good rollback:

```text id="potz27"
current: 0.3.1-e9f8a7b
previous: 0.3.0-a1b2c3d
rollback to previous tag
validate /ready
write rollback report
```

Rollback-safe retention:

```text id="wvocdk"
keep current production artifact
keep previous production artifact
keep recent staging artifacts
keep release metadata
keep deployment reports
```

Expert rule:

```text id="bmb4xy"
A versioning strategy is incomplete if it cannot support rollback.
```

---

# 11. Hands-On — Create Versioning Notes

Run:

```bash id="dzeg5x"
cd ~/devops-masterclass/07-artifact-management-registries

nano notes/versioning-release-metadata.md
```

Paste:

````markdown id="p8ctwd"
# Versioning and Release Metadata

## Versioning

Versioning assigns a unique identity to an artifact or release.

## Recommended App Version Format

```text
MAJOR.MINOR.PATCH-COMMIT_SHA
````

Example:

```text id="lkwlti"
0.7.0-a1b2c3d
```

## Semantic Versioning

```text id="dq0g79"
MAJOR.MINOR.PATCH
```

* MAJOR: breaking changes
* MINOR: backward-compatible features
* PATCH: backward-compatible fixes

## Pre-Releases

```text id="2l79z8"
1.0.0-alpha.1
1.0.0-beta.1
1.0.0-rc.1
```

Docker-safe examples:

```text id="p12c2c"
1.0.0-rc.1-a1b2c3d
1.0.0-build.45-a1b2c3d
```

## Version vs Tag vs Digest

* version: human release identity
* tag: registry reference
* digest: exact content identity

## Production Rules

* Do not use latest for production.
* Use immutable tags.
* Include Git SHA in deployment tag.
* Store release metadata.
* Record image digest when possible.
* Keep previous versions for rollback.

````

---

# 12. Hands-On — Create a Version Computation Script

Create:

```bash id="d40xe7"
cd ~/devops-masterclass/07-artifact-management-registries

nano scripts/compute-version.sh
````

Paste:

```bash id="q2kp14"
#!/usr/bin/env bash
set -euo pipefail

BASE_VERSION="${BASE_VERSION:-0.7.0}"
CHANNEL="${CHANNEL:-stable}"   # dev, alpha, beta, rc, stable
RC_NUMBER="${RC_NUMBER:-1}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
COMMIT_SHA="${COMMIT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"

sanitize() {
  echo "$1" | tr '+' '-' | tr '/' '-' | tr ':' '-' | tr '[:upper:]' '[:lower:]'
}

case "$CHANNEL" in
  stable)
    VERSION="$BASE_VERSION"
    ;;
  dev)
    VERSION="$BASE_VERSION-dev"
    ;;
  alpha)
    VERSION="$BASE_VERSION-alpha.$RC_NUMBER"
    ;;
  beta)
    VERSION="$BASE_VERSION-beta.$RC_NUMBER"
    ;;
  rc)
    VERSION="$BASE_VERSION-rc.$RC_NUMBER"
    ;;
  *)
    echo "ERROR: unsupported CHANNEL=$CHANNEL" >&2
    echo "Allowed: dev, alpha, beta, rc, stable" >&2
    exit 1
    ;;
esac

if [ -n "$BUILD_NUMBER" ]; then
  VERSION="$VERSION-build.$BUILD_NUMBER"
fi

DEPLOY_TAG="$(sanitize "$VERSION-$COMMIT_SHA")"

cat <<EOF
{
  "base_version": "$BASE_VERSION",
  "channel": "$CHANNEL",
  "build_number": "$BUILD_NUMBER",
  "commit_sha": "$COMMIT_SHA",
  "version": "$VERSION",
  "deploy_tag": "$DEPLOY_TAG"
}
EOF
```

Make executable:

```bash id="xarocb"
chmod +x scripts/compute-version.sh
```

Test stable:

```bash id="gbw5wj"
BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh | jq .
```

Test release candidate:

```bash id="vvho7x"
BASE_VERSION=0.7.0 CHANNEL=rc RC_NUMBER=1 ./scripts/compute-version.sh | jq .
```

Test Jenkins-style build:

```bash id="q4dmub"
BASE_VERSION=0.7.0 CHANNEL=dev BUILD_NUMBER=152 ./scripts/compute-version.sh | jq .
```

Expected deploy tags:

```text id="zcdt8d"
0.7.0-a1b2c3d
0.7.0-rc.1-a1b2c3d
0.7.0-dev-build.152-a1b2c3d
```

---

# 13. Hands-On — Create a Release Metadata Script

Now we create serious release metadata.

Create:

```bash id="yc9zfb"
nano scripts/create-release-metadata.sh
```

Paste:

```bash id="gix7zm"
#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"
BASE_VERSION="${BASE_VERSION:-0.7.0}"
CHANNEL="${CHANNEL:-stable}"
RC_NUMBER="${RC_NUMBER:-1}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
COMMIT_SHA="${COMMIT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"
GIT_BRANCH="${GIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)}"
SOURCE_REPO="${SOURCE_REPO:-devops-masterclass}"
REGISTRY_IMAGE="${REGISTRY_IMAGE:-}"
IMAGE_NAME="${IMAGE_NAME:-demo-node-api}"
OUTPUT_DIR="${OUTPUT_DIR:-release-records}"
TEST_STATUS="${TEST_STATUS:-unknown}"
SCAN_STATUS="${SCAN_STATUS:-unknown}"
SBOM_PATH="${SBOM_PATH:-}"
CHANGELOG_PATH="${CHANGELOG_PATH:-}"
BUILT_BY="${BUILT_BY:-$(whoami)}"

mkdir -p "$OUTPUT_DIR"

VERSION_JSON="$(BASE_VERSION="$BASE_VERSION" CHANNEL="$CHANNEL" RC_NUMBER="$RC_NUMBER" BUILD_NUMBER="$BUILD_NUMBER" COMMIT_SHA="$COMMIT_SHA" "$(dirname "$0")/compute-version.sh")"

VERSION="$(echo "$VERSION_JSON" | jq -r '.version')"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"

IMAGE_REF="$IMAGE_NAME:$DEPLOY_TAG"
if [ -n "$REGISTRY_IMAGE" ]; then
  IMAGE_REF="$REGISTRY_IMAGE:$DEPLOY_TAG"
fi

LOCAL_IMAGE_ID=""
LOCAL_IMAGE_CREATED=""
if docker image inspect "$IMAGE_NAME:$DEPLOY_TAG" >/dev/null 2>&1; then
  LOCAL_IMAGE_ID="$(docker image inspect "$IMAGE_NAME:$DEPLOY_TAG" --format '{{.Id}}')"
  LOCAL_IMAGE_CREATED="$(docker image inspect "$IMAGE_NAME:$DEPLOY_TAG" --format '{{.Created}}')"
elif docker image inspect "$IMAGE_NAME:$BASE_VERSION" >/dev/null 2>&1; then
  LOCAL_IMAGE_ID="$(docker image inspect "$IMAGE_NAME:$BASE_VERSION" --format '{{.Id}}')"
  LOCAL_IMAGE_CREATED="$(docker image inspect "$IMAGE_NAME:$BASE_VERSION" --format '{{.Created}}')"
fi

OUTPUT_FILE="$OUTPUT_DIR/${SERVICE_NAME}-${DEPLOY_TAG}.json"

cat > "$OUTPUT_FILE" <<EOF
{
  "service_name": "$SERVICE_NAME",
  "artifact_type": "docker_image",
  "base_version": "$BASE_VERSION",
  "version": "$VERSION",
  "deploy_tag": "$DEPLOY_TAG",
  "channel": "$CHANNEL",
  "build_number": "$BUILD_NUMBER",
  "commit_sha": "$COMMIT_SHA",
  "git_branch": "$GIT_BRANCH",
  "source_repository": "$SOURCE_REPO",
  "image_ref": "$IMAGE_REF",
  "local_image_id": "$LOCAL_IMAGE_ID",
  "local_image_created": "$LOCAL_IMAGE_CREATED",
  "test_status": "$TEST_STATUS",
  "scan_status": "$SCAN_STATUS",
  "sbom_path": "$SBOM_PATH",
  "changelog_path": "$CHANGELOG_PATH",
  "built_by": "$BUILT_BY",
  "metadata_created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

echo "Release metadata created:"
cat "$OUTPUT_FILE" | jq .
```

Make executable:

```bash id="z76n2r"
chmod +x scripts/create-release-metadata.sh
```

Run:

```bash id="hhvcjr"
BASE_VERSION=0.7.0 \
CHANNEL=stable \
TEST_STATUS=passed \
SCAN_STATUS=passed \
./scripts/create-release-metadata.sh
```

Check:

```bash id="z6wtm9"
ls -lh release-records
cat release-records/demo-node-api-*.json | jq .
```

---

# 14. Build Image Using Computed Version

Go to app:

```bash id="i1y1vc"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Compute version:

```bash id="vibq7t"
VERSION_JSON="$(cd ~/devops-masterclass/07-artifact-management-registries && BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"

echo "$VERSION_JSON" | jq .
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"
```

Build image:

```bash id="eppis2"
VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
```

Check:

```bash id="z2xsdn"
docker images | grep demo-node-api
```

Create metadata:

```bash id="xjlvp7"
cd ~/devops-masterclass/07-artifact-management-registries

BASE_VERSION=0.7.0 \
CHANNEL=stable \
IMAGE_NAME=demo-node-api \
TEST_STATUS=passed \
SCAN_STATUS=passed \
./scripts/create-release-metadata.sh
```

Now your metadata points to the deployable Docker tag.

---

# 15. Professional — Release Notes vs Changelog

These are related but different.

## Changelog

Technical list of changes.

Example:

```text id="yzbqjc"
- add release metadata script
- add version computation script
- fix Docker deploy report
```

## Release notes

Human-friendly summary.

Example:

```text id="yuoy3l"
This release adds artifact versioning and release metadata automation. It improves traceability by recording commit SHA, image tag, test status, scan status, and SBOM path.
```

Professional rule:

```text id="u5x64q"
Changelog is for engineers. Release notes are for stakeholders and operators.
```

---

# 16. Hands-On — Generate Changelog from Git

Create script:

```bash id="p35g9k"
cd ~/devops-masterclass/07-artifact-management-registries

nano scripts/generate-changelog.sh
```

Paste:

```bash id="cim98c"
#!/usr/bin/env bash
set -euo pipefail

FROM_REF="${FROM_REF:-}"
TO_REF="${TO_REF:-HEAD}"
OUTPUT_DIR="${OUTPUT_DIR:-release-records/changelogs}"
SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"

mkdir -p "$OUTPUT_DIR"

if [ -z "$FROM_REF" ]; then
  FROM_REF="$(git describe --tags --abbrev=0 2>/dev/null || true)"
fi

if [ -z "$FROM_REF" ]; then
  RANGE="$TO_REF"
  TITLE="Changes up to $TO_REF"
else
  RANGE="$FROM_REF..$TO_REF"
  TITLE="Changes from $FROM_REF to $TO_REF"
fi

OUTPUT_FILE="$OUTPUT_DIR/${SERVICE_NAME}-changelog-$(date +%Y%m%d_%H%M%S).md"

{
  echo "# $TITLE"
  echo
  echo "Generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo
  echo "## Commits"
  echo
  git log --pretty=format:'- %h %s (%an)' "$RANGE" || true
  echo
} > "$OUTPUT_FILE"

echo "Changelog created: $OUTPUT_FILE"
cat "$OUTPUT_FILE"
```

Make executable:

```bash id="cvzd9x"
chmod +x scripts/generate-changelog.sh
```

Run:

```bash id="gxk9i9"
./scripts/generate-changelog.sh
```

Or between tags:

```bash id="lhxqrs"
FROM_REF=v0.6.0 TO_REF=HEAD ./scripts/generate-changelog.sh
```

---

# 17. Hands-On — Generate Release Notes

Create:

```bash id="yd5fw6"
nano scripts/generate-release-notes.sh
```

Paste:

```bash id="vu2vww"
#!/usr/bin/env bash
set -euo pipefail

METADATA_FILE="${1:-}"
OUTPUT_DIR="${OUTPUT_DIR:-release-records/release-notes}"

if [ -z "$METADATA_FILE" ]; then
  echo "Usage: $0 <release-metadata-json>" >&2
  exit 1
fi

if [ ! -f "$METADATA_FILE" ]; then
  echo "ERROR: metadata file not found: $METADATA_FILE" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

SERVICE_NAME="$(jq -r '.service_name' "$METADATA_FILE")"
DEPLOY_TAG="$(jq -r '.deploy_tag' "$METADATA_FILE")"
VERSION="$(jq -r '.version' "$METADATA_FILE")"
COMMIT_SHA="$(jq -r '.commit_sha' "$METADATA_FILE")"
IMAGE_REF="$(jq -r '.image_ref' "$METADATA_FILE")"
TEST_STATUS="$(jq -r '.test_status' "$METADATA_FILE")"
SCAN_STATUS="$(jq -r '.scan_status' "$METADATA_FILE")"

OUTPUT_FILE="$OUTPUT_DIR/${SERVICE_NAME}-${DEPLOY_TAG}-release-notes.md"

cat > "$OUTPUT_FILE" <<EOF
# Release Notes — $SERVICE_NAME $VERSION

## Summary

This release packages $SERVICE_NAME as artifact version \`$DEPLOY_TAG\`.

## Artifact

- Service: \`$SERVICE_NAME\`
- Version: \`$VERSION\`
- Deploy tag: \`$DEPLOY_TAG\`
- Commit SHA: \`$COMMIT_SHA\`
- Image: \`$IMAGE_REF\`

## Validation

- Tests: \`$TEST_STATUS\`
- Security scan: \`$SCAN_STATUS\`

## Deployment Guidance

Deploy this release using the immutable deploy tag:

\`\`\`bash
APP_VERSION=$DEPLOY_TAG ./scripts/deploy-compose.sh
\`\`\`

## Rollback

Rollback should use the previous known-good immutable tag from deployment records.
EOF

echo "Release notes created: $OUTPUT_FILE"
cat "$OUTPUT_FILE"
```

Make executable:

```bash id="x4ht5y"
chmod +x scripts/generate-release-notes.sh
```

Run:

```bash id="vphluo"
LATEST_METADATA="$(ls -t release-records/demo-node-api-*.json | head -n 1)"
./scripts/generate-release-notes.sh "$LATEST_METADATA"
```

---

# 18. Expert — Versioning in Branching Strategy

Common professional branch/version relationship:

```text id="tw190i"
feature branches:
  0.7.0-dev-<sha>

main branch:
  0.7.0-dev-<sha> or 0.7.0-<sha>

release branch:
  0.7.0-rc.1-<sha>

Git tag v0.7.0:
  0.7.0-<sha>

hotfix branch:
  0.7.1-<sha>
```

Example flow:

```text id="omaw8w"
feature/artifact-versioning
  -> merge to main
  -> build 0.7.0-dev-a1b2c3d
  -> create release candidate 0.7.0-rc.1-d4e5f6g
  -> test staging
  -> tag v0.7.0
  -> build/promote 0.7.0-d4e5f6g
```

Professional rule:

```text id="cgfz9y"
Branches control development flow. Versions control artifact identity.
```

---

# 19. Expert — Versioning for Microservices

In monolith:

```text id="gqev2c"
one app
one version
one release
```

In microservices:

```text id="w37ezz"
order-api:1.8.0-a1b2c3d
payment-api:2.4.1-d4e5f6g
user-api:3.1.2-h7i8j9k
```

You need:

```text id="catgf2"
service-specific versions
compatibility tracking
API contract management
deployment matrix
release train or independent deploys
```

Example deployment record:

```json id="t8mxta"
{
  "environment": "production",
  "services": {
    "order-api": "1.8.0-a1b2c3d",
    "payment-api": "2.4.1-d4e5f6g",
    "user-api": "3.1.2-h7i8j9k"
  }
}
```

Expert rule:

```text id="ks1wvq"
In distributed systems, release metadata becomes system state documentation.
```

---

# 20. Expert — Versioning and Database Migrations

App versioning is easy.

Database versioning is harder.

Bad:

```text id="mz4jif"
deploy app 2.0.0
migration changes schema destructively
app fails
rollback app to 1.9.0
database no longer compatible
```

Better:

```text id="fzf1vd"
version app artifact
version migration scripts
record migration status
use backward-compatible migrations
backup before risky migrations
```

Release metadata should include:

```json id="bl9bnn"
{
  "app_version": "2.0.0-a1b2c3d",
  "migration_version": "20260704_add_customer_status",
  "migration_required": true,
  "rollback_safe": false
}
```

Professional rule:

```text id="tf4l5z"
A rollback-safe app version is not enough if the database migration is not rollback-safe.
```

We will go deeper later in CI/CD and production deployment modules.

---

# 21. Expert — Release Metadata Schema

A strong release metadata schema includes:

```json id="lhkscw"
{
  "release": {
    "service_name": "demo-node-api",
    "version": "0.7.0",
    "deploy_tag": "0.7.0-a1b2c3d",
    "channel": "stable"
  },
  "source": {
    "repository": "devops-masterclass",
    "branch": "main",
    "commit_sha": "a1b2c3d"
  },
  "artifact": {
    "type": "docker_image",
    "image_ref": "ghcr.io/org/demo-node-api:0.7.0-a1b2c3d",
    "digest": "sha256:..."
  },
  "validation": {
    "tests": "passed",
    "scan": "passed",
    "sbom": "sbom/demo-node-api-0.7.0.json"
  },
  "promotion": {
    "dev": "promoted",
    "staging": "promoted",
    "production": "pending"
  }
}
```

We will evolve our scripts toward this structure throughout Module 7.

---

# 22. Upgrade Metadata Script to Include Promotion Status

Optional enhancement.

Create a promotion status file:

```bash id="zs1cbm"
cd ~/devops-masterclass/07-artifact-management-registries

mkdir -p release-records/status
nano release-records/status/demo-node-api-0.7.0-status.json
```

Paste:

```json id="f1ge1x"
{
  "dev": "pending",
  "staging": "pending",
  "production": "pending"
}
```

Later scripts can update it.

For now, record promotion separately with:

```bash id="n8klbk"
ARTIFACT=demo-node-api:0.7.0-a1b2c3d FROM_ENV=dev TO_ENV=staging ./scripts/create-promotion-record.sh
```

---

# 23. Professional — Release Naming Policy

Create:

```bash id="lrb1re"
nano notes/release-naming-policy.md
```

Paste:

````markdown id="eirm0c"
# Release Naming Policy

## Application Version

Use semantic versioning:

```text
MAJOR.MINOR.PATCH
````

Example:

```text id="7eju85"
0.7.0
```

## Docker Deploy Tag

Use:

```text id="11vgm1"
VERSION-COMMIT_SHA
```

Example:

```text id="hm9b5h"
0.7.0-a1b2c3d
```

## Pre-Release Tags

Use:

```text id="bmjywk"
VERSION-rc.N-COMMIT_SHA
VERSION-beta.N-COMMIT_SHA
VERSION-alpha.N-COMMIT_SHA
```

Examples:

```text id="13dqjm"
0.7.0-rc.1-a1b2c3d
0.7.0-beta.1-a1b2c3d
```

## Forbidden for Production

Do not use these as final production identifiers:

```text id="gsw5wl"
latest
dev
staging
prod
test
```

They may exist as convenience channel tags, but deployment records must store exact immutable tags and preferably digests.

## Git Tags

Use annotated Git tags for module or production releases:

```bash id="xgbcin"
git tag -a v0.7.0 -m "Release v0.7.0"
git push origin v0.7.0
```

## Release Metadata

Every release must have a JSON metadata file with:

* service name
* version
* deploy tag
* commit SHA
* image reference
* test status
* scan status
* build timestamp
* SBOM path if available

````

---

# 24. Create GitHub Actions Versioning Example

Create:

```bash id="ofmx6i"
nano examples/github-actions-versioning.yml
````

Paste:

```yaml id="bqo0pg"
name: Versioning Example

on:
  push:
    branches: [main]
    tags:
      - "v*"

jobs:
  compute-version:
    runs-on: ubuntu-latest

    outputs:
      version: ${{ steps.version.outputs.version }}
      deploy_tag: ${{ steps.version.outputs.deploy_tag }}
      short_sha: ${{ steps.version.outputs.short_sha }}

    steps:
      - uses: actions/checkout@v4

      - name: Compute version
        id: version
        shell: bash
        run: |
          SHORT_SHA="${GITHUB_SHA::7}"

          if [[ "${GITHUB_REF_TYPE}" == "tag" ]]; then
            BASE_VERSION="${GITHUB_REF_NAME#v}"
            CHANNEL="stable"
          else
            BASE_VERSION="0.7.0"
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

      - name: Show version
        run: |
          echo "Version: ${{ steps.version.outputs.version }}"
          echo "Deploy tag: ${{ steps.version.outputs.deploy_tag }}"
```

This example shows:

```text id="m03hyh"
push to main -> dev tag
push Git tag v0.7.0 -> stable release tag
```

---

# 25. Create Jenkins Versioning Example

Create:

```bash id="1b98vx"
nano examples/jenkins-versioning.groovy
```

Paste:

```groovy id="l37o0v"
pipeline {
  agent any

  environment {
    BASE_VERSION = "0.7.0"
    SERVICE_NAME = "demo-node-api"
  }

  stages {
    stage('Compute Version') {
      steps {
        script {
          def shortSha = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
          def branch = env.BRANCH_NAME ?: "unknown"
          def channel = branch == "main" ? "stable" : "dev"
          def version = channel == "stable" ? env.BASE_VERSION : "${env.BASE_VERSION}-${channel}"
          def deployTag = "${version}-${shortSha}"

          env.SHORT_SHA = shortSha
          env.VERSION = version
          env.DEPLOY_TAG = deployTag

          echo "Version: ${env.VERSION}"
          echo "Deploy tag: ${env.DEPLOY_TAG}"
        }
      }
    }

    stage('Build Image') {
      steps {
        sh """
          docker build \
            --build-arg APP_VERSION=${DEPLOY_TAG} \
            --build-arg COMMIT_SHA=${SHORT_SHA} \
            -t ${SERVICE_NAME}:${DEPLOY_TAG} \
            .
        """
      }
    }
  }
}
```

---

# 26. Hands-On — Validate Release Metadata

Create:

```bash id="hixz6m"
nano scripts/validate-release-metadata.sh
```

Paste:

```bash id="gm98xt"
#!/usr/bin/env bash
set -euo pipefail

METADATA_FILE="${1:-}"

if [ -z "$METADATA_FILE" ]; then
  echo "Usage: $0 <metadata-json>" >&2
  exit 1
fi

if [ ! -f "$METADATA_FILE" ]; then
  echo "ERROR: file not found: $METADATA_FILE" >&2
  exit 1
fi

required_fields=(
  service_name
  artifact_type
  base_version
  version
  deploy_tag
  commit_sha
  image_ref
  test_status
  scan_status
  metadata_created_at
)

for field in "${required_fields[@]}"; do
  value="$(jq -r ".$field // empty" "$METADATA_FILE")"
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    echo "ERROR: missing required field: $field" >&2
    exit 1
  fi
done

deploy_tag="$(jq -r '.deploy_tag' "$METADATA_FILE")"

if echo "$deploy_tag" | grep -Eq 'latest|:|/|\+'; then
  echo "ERROR: deploy_tag contains forbidden Docker tag characters or forbidden value: $deploy_tag" >&2
  exit 1
fi

echo "Release metadata is valid:"
cat "$METADATA_FILE" | jq .
```

Make executable:

```bash id="pw3xmj"
chmod +x scripts/validate-release-metadata.sh
```

Run:

```bash id="f2blf5"
LATEST_METADATA="$(ls -t release-records/demo-node-api-*.json | head -n 1)"
./scripts/validate-release-metadata.sh "$LATEST_METADATA"
```

---

# 27. Add Makefile Targets

Open:

```bash id="jbsjmm"
cd ~/devops-masterclass/07-artifact-management-registries

nano Makefile
```

Replace or extend:

```Makefile id="vbx2ri"
.PHONY: version metadata validate-metadata changelog release-notes promotion checksum inventory

version:
	BASE_VERSION?=0.7.0 CHANNEL?=stable ./scripts/compute-version.sh | jq .

metadata:
	BASE_VERSION?=0.7.0 CHANNEL?=stable TEST_STATUS?=passed SCAN_STATUS?=passed ./scripts/create-release-metadata.sh

validate-metadata:
	@LATEST=$$(ls -t release-records/demo-node-api-*.json | head -n 1); \
	./scripts/validate-release-metadata.sh "$$LATEST"

changelog:
	./scripts/generate-changelog.sh

release-notes:
	@LATEST=$$(ls -t release-records/demo-node-api-*.json | head -n 1); \
	./scripts/generate-release-notes.sh "$$LATEST"

promotion:
	@test -n "$(ARTIFACT)" || (echo "Usage: make promotion ARTIFACT=<artifact> FROM_ENV=dev TO_ENV=staging" && exit 1)
	ARTIFACT="$(ARTIFACT)" FROM_ENV="$(FROM_ENV)" TO_ENV="$(TO_ENV)" ./scripts/create-promotion-record.sh

checksum:
	sha256sum examples/*.tar.gz | tee checksums/artifacts.sha256

inventory:
	cat examples/artifact-inventory.json | jq .
```

Test:

```bash id="sm10aa"
make version
make metadata
make validate-metadata
make changelog
make release-notes
```

---

# 28. Troubleshooting Versioning Problems

## Problem 1 — Same version points to different content

Cause:

```text id="mm4hvk"
tag was overwritten
artifact was rebuilt with same version
registry allows mutable tags
```

Fix:

```text id="vdafp1"
use version-sha tags
enable tag immutability where possible
record digest
restrict push permissions
```

---

## Problem 2 — Cannot trace production to commit

Check:

```bash id="t7c2rp"
curl -s http://127.0.0.1:8080/version | jq .
cat deployment-records/latest.json 2>/dev/null || true
```

Fix:

```text id="egjg7y"
include COMMIT_SHA in app env
include commit in image label
include commit in release metadata
include commit in deployment report
```

---

## Problem 3 — Docker tag invalid

Bad characters:

```text id="se9s7x"
+
/
:
space
```

Fix:

```text id="nudndb"
sanitize tags
use hyphen instead of plus
avoid branch names directly as tags unless sanitized
```

Example:

```bash id="ij5uvg"
echo "feature/my-branch+build" | tr '+/:' '---'
```

---

## Problem 4 — Release notes do not match deployed artifact

Cause:

```text id="r4uqsb"
release notes generated from wrong metadata file
artifact rebuilt after notes
tag overwritten
manual deployment bypassed metadata
```

Fix:

```text id="smsw2l"
generate release notes from exact metadata file
do not overwrite tags
store metadata in CI artifacts
deployment script should record image tag and digest
```

---

# 29. Final Validation

Run full local versioning flow:

```bash id="uhp0vi"
cd ~/devops-masterclass/07-artifact-management-registries

make version BASE_VERSION=0.7.0 CHANNEL=stable
make metadata BASE_VERSION=0.7.0 CHANNEL=stable TEST_STATUS=passed SCAN_STATUS=passed
make validate-metadata
make changelog
make release-notes
```

Build image with computed version:

```bash id="xm31l5"
VERSION_JSON="$(BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"

cd ~/devops-masterclass/05-application-runtime/demo-node-api
VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
```

Deploy with Compose:

```bash id="osx09y"
cd ~/devops-masterclass/06-docker-containers/compose-demo

APP_IMAGE=demo-node-api \
APP_VERSION="$DEPLOY_TAG" \
COMPOSE_FILES="compose.yaml compose.prod.yaml" \
./scripts/deploy-compose.sh
```

Validate:

```bash id="u52ak3"
curl -s http://127.0.0.1:8080/version | jq .
```

Create promotion record:

```bash id="9n3g3x"
cd ~/devops-masterclass/07-artifact-management-registries

ARTIFACT="demo-node-api:$DEPLOY_TAG" FROM_ENV=dev TO_ENV=staging ./scripts/create-promotion-record.sh
```

---

# 30. Commit Work

Run:

```bash id="cc1nvq"
cd ~/devops-masterclass

git status
git add 07-artifact-management-registries

git commit -m "feat: add release versioning and metadata automation"
git push
```

---

# 31. Interview Explanation

## What versioning strategy would you use for Docker images?

Strong answer:

```text id="dzankr"
I use semantic versioning for human release identity and add the Git commit SHA for traceability. For example, a Docker image tag might be 1.4.2-a1b2c3d. This makes the release readable while still linking it to exact source code. I avoid latest for production and record image digests in deployment metadata where possible.
```

## What is release metadata?

Strong answer:

```text id="m5oyr9"
Release metadata is structured information that describes an artifact or release. It includes the service name, version, commit SHA, image reference, digest, build timestamp, test status, scan status, SBOM path, changelog path, builder identity, and promotion/deployment status.
```

## Difference between version, tag, and digest?

Strong answer:

```text id="qdwnzq"
A version is the human release identity, such as 1.4.2. A tag is a registry reference used to pull an image, such as app:1.4.2-a1b2c3d. A digest is a content-addressed identifier like sha256 that identifies the exact image content.
```

## Why include Git SHA in image tags?

Strong answer:

```text id="c26imu"
Including the Git SHA makes the image traceable to exact source code. It helps debugging, audit, rollback, and incident response because we can identify the commit that produced the running artifact.
```

## How do you handle release candidates?

Strong answer:

```text id="6rg1qt"
I use pre-release tags such as 1.4.0-rc.1-a1b2c3d. The same artifact can be tested in staging, and if approved, the release can be promoted or rebuilt from the same commit with the stable version depending on the organization’s release policy. The important part is preserving traceability to commit and artifact digest.
```

---

# Today’s Core Rules

```text id="hlxu4b"
Version every artifact.
Do not use latest for production.
Use SemVer for human release identity.
Use Git SHA for source traceability.
Use version-sha tags for deployable Docker images.
Record digests where possible.
Generate release metadata.
Generate changelog and release notes.
Promotion and deployment should reference immutable versions.
Rollback requires previous artifact availability.
Release metadata is essential for audit and incident response.
Docker tags must be sanitized.
Database migrations need separate version/rollback planning.
```

---

# Next Lesson

# Lesson 7.3 — Checksums, Digests, Immutability, and Reproducibility Deep Dive

We will go deeper into:

```text id="cpmvg2"
sha256 checksums
Docker image digests
tag mutability risks
content-addressable storage
artifact integrity verification
reproducible builds
lockfiles
base image pinning
digest-pinned Dockerfiles
registry immutability
rollback-safe retention
```

# Lesson 7.3 — Checksums, Digests, Immutability, and Reproducibility Deep Dive

# Artifact Integrity, Docker Digests, Tag Mutability Risks, Lockfiles, Base Image Pinning, and Rollback-Safe Retention

In Lesson 7.2, we learned how to create strong artifact versions like:

```text id="f2qspo"
0.7.0-a1b2c3d
```

Now we go deeper.

Versioning tells us **what we intended to release**.

Checksums and digests prove **what the artifact actually is**.

That difference is very important.

---

# 1. Beginner Level — Why Checksums and Digests Matter

Imagine you have this artifact:

```text id="tb90nl"
demo-node-api-0.7.0-a1b2c3d.tar.gz
```

How do you know it was not changed?

How do you know it was not corrupted?

How do you know production pulled the exact image that staging tested?

That is where checksums and digests come in.

Simple definition:

```text id="hd7ycw"
A checksum is a fingerprint of a file.
A digest is a fingerprint of image content.
```

If the file or image changes, the fingerprint changes.

---

# 2. Beginner Mental Model

Think of a checksum like a fingerprint.

```text id="dze9je"
artifact file
  ↓
sha256sum
  ↓
unique fingerprint
```

Example:

```text id="pbcy7s"
demo-node-api.tar.gz
sha256: 85e4c3...
```

If even one byte changes:

```text id="rqc4ur"
old checksum != new checksum
```

That means:

```text id="uwwsvg"
artifact changed
artifact corrupted
wrong file downloaded
someone modified it
```

Core rule:

```text id="lcnk3n"
Names can lie. Checksums reveal content changes.
```

---

# 3. Beginner — File Checksum Lab

Go to Module 7:

```bash id="l32rgg"
cd ~/devops-masterclass/07-artifact-management-registries
```

Create a simple file:

```bash id="5zul4b"
echo "hello artifact" > examples/sample-artifact.txt
```

Generate checksum:

```bash id="3tdtnq"
sha256sum examples/sample-artifact.txt
```

Example output:

```text id="mzo2o0"
abc123...  examples/sample-artifact.txt
```

Save checksum:

```bash id="bt1t2s"
sha256sum examples/sample-artifact.txt > checksums/sample-artifact.sha256
```

Verify:

```bash id="lwg7xs"
sha256sum -c checksums/sample-artifact.sha256
```

Expected:

```text id="uye452"
examples/sample-artifact.txt: OK
```

Now change file:

```bash id="0tyugp"
echo "changed" >> examples/sample-artifact.txt
```

Verify again:

```bash id="yigsp2"
sha256sum -c checksums/sample-artifact.sha256
```

Expected:

```text id="4455ms"
FAILED
```

This is checksum integrity verification.

---

# 4. Beginner — Why SHA256?

You will often see:

```text id="31u5ok"
sha256
```

SHA256 is a cryptographic hash algorithm.

In DevOps, it is commonly used for:

```text id="mkh5ts"
artifact checksums
Docker image digests
release verification
download verification
integrity checks
SBOM references
supply-chain metadata
```

Common command:

```bash id="0gb1mb"
sha256sum file.tar.gz
```

Professional rule:

```text id="h388a2"
Use SHA256 or stronger for release artifact integrity.
```

Avoid older weak hashes like:

```text id="rcmmyz"
md5
sha1
```

for serious integrity/security workflows.

---

# 5. Intermediate — Checksums for Release Packages

In Lesson 7.1, you created a `.tar.gz` artifact.

Check:

```bash id="ozw3tr"
cd ~/devops-masterclass/07-artifact-management-registries

ls -lh examples
```

Generate checksums for all release packages:

```bash id="jmu0le"
sha256sum examples/*.tar.gz | tee checksums/release-artifacts.sha256
```

Verify:

```bash id="ej0sol"
sha256sum -c checksums/release-artifacts.sha256
```

Expected:

```text id="gx38c5"
examples/demo-node-api-...tar.gz: OK
```

Professional practice:

```text id="2kqgrc"
Store checksum files with release artifacts.
```

Example release storage:

```text id="uolxtv"
release/
├── demo-node-api-0.7.0-a1b2c3d.tar.gz
├── demo-node-api-0.7.0-a1b2c3d.sha256
├── demo-node-api-0.7.0-a1b2c3d.metadata.json
└── demo-node-api-0.7.0-a1b2c3d.sbom.json
```

---

# 6. Intermediate — Create a Checksum Script

Create:

```bash id="lx5bay"
cd ~/devops-masterclass/07-artifact-management-registries

nano scripts/generate-checksums.sh
```

Paste:

```bash id="67o020"
#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_DIR="${ARTIFACT_DIR:-examples}"
CHECKSUM_DIR="${CHECKSUM_DIR:-checksums}"
OUTPUT_FILE="${OUTPUT_FILE:-$CHECKSUM_DIR/artifacts.sha256}"

mkdir -p "$CHECKSUM_DIR"

if ! find "$ARTIFACT_DIR" -type f | grep -q .; then
  echo "ERROR: no files found in $ARTIFACT_DIR" >&2
  exit 1
fi

echo "===== Generate Checksums ====="
echo "Artifact directory: $ARTIFACT_DIR"
echo "Output: $OUTPUT_FILE"

find "$ARTIFACT_DIR" -type f \
  ! -name "*.sha256" \
  -print0 \
  | sort -z \
  | xargs -0 sha256sum \
  | tee "$OUTPUT_FILE"

echo
echo "Checksums generated."
```

Make executable:

```bash id="vntqf6"
chmod +x scripts/generate-checksums.sh
```

Run:

```bash id="8lmn9f"
./scripts/generate-checksums.sh
```

Verify:

```bash id="z49d31"
sha256sum -c checksums/artifacts.sha256
```

---

# 7. Intermediate — Create Checksum Verification Script

Create:

```bash id="ph8cjc"
nano scripts/verify-checksums.sh
```

Paste:

```bash id="cqzscy"
#!/usr/bin/env bash
set -euo pipefail

CHECKSUM_FILE="${CHECKSUM_FILE:-checksums/artifacts.sha256}"

if [ ! -f "$CHECKSUM_FILE" ]; then
  echo "ERROR: checksum file not found: $CHECKSUM_FILE" >&2
  exit 1
fi

echo "===== Verify Checksums ====="
echo "Checksum file: $CHECKSUM_FILE"

sha256sum -c "$CHECKSUM_FILE"

echo
echo "Checksum verification passed."
```

Make executable:

```bash id="v9argl"
chmod +x scripts/verify-checksums.sh
```

Run:

```bash id="zcyv0h"
./scripts/verify-checksums.sh
```

---

# 8. Intermediate — Docker Image Digests

A Docker image tag looks like this:

```text id="qkvv9e"
demo-node-api:0.7.0-a1b2c3d
```

But a digest looks like this:

```text id="ll9pnp"
demo-node-api@sha256:abcd...
```

Tag:

```text id="j4c48o"
human-friendly pointer
```

Digest:

```text id="qwgcct"
content identity
```

A tag can move.

A digest identifies exact content.

This is the key difference.

---

# 9. Hands-On — Inspect Local Image ID

Build an image:

```bash id="2h6cxd"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION_JSON="$(cd ~/devops-masterclass/07-artifact-management-registries && BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"

VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
```

Inspect image ID:

```bash id="ycq28u"
docker image inspect demo-node-api:$DEPLOY_TAG --format '{{.Id}}'
```

Example:

```text id="655ut0"
sha256:abc123...
```

This is the local image ID.

Check RepoDigests:

```bash id="bb06uo"
docker image inspect demo-node-api:$DEPLOY_TAG --format '{{json .RepoDigests}}' | jq .
```

For a local-only image, this may be:

```json id="x7n1w2"
null
```

or:

```json id="kue6xl"
[]
```

Why?

```text id="l7l7ud"
RepoDigests usually appear after pulling/pushing from a registry.
```

---

# 10. Professional — Tag Mutability Risk

A tag is a pointer.

This means:

```text id="fd2aw5"
demo-node-api:0.7.0
```

can point to one image today and another image tomorrow if someone overwrites it.

Example:

```bash id="xa46lz"
docker tag demo-node-api:old demo-node-api:0.7.0
docker tag demo-node-api:new demo-node-api:0.7.0
```

Same tag, different content.

This is dangerous for production.

Bad:

```text id="h3f5lu"
production deploys demo-node-api:latest
```

Still risky:

```text id="92qb4k"
production deploys demo-node-api:0.7.0
if tag is mutable
```

Better:

```text id="e7w5so"
production deploys demo-node-api:0.7.0-a1b2c3d
deployment report records image digest
registry prevents tag overwrite where possible
```

Expert:

```text id="2w2ly6"
production deploys digest-pinned image
```

Example:

```text id="9szd1d"
ghcr.io/org/demo-node-api@sha256:abc...
```

---

# 11. Professional — Immutable Tags

An immutable tag means:

```text id="e21gv4"
once pushed, it cannot be overwritten
```

Some registries support tag immutability policies.

Common registry strategies:

```text id="s34iov"
ECR tag immutability
Harbor immutable tag rules
GitLab protected container tags
Artifactory/Nexus permissions
GHCR controlled permissions and release discipline
```

Even if your registry does not enforce immutability strictly, your process should.

Policy:

```text id="j2yxq3"
Never overwrite release tags.
Never overwrite version-sha tags.
Create a new tag for a new build.
```

Good tags:

```text id="579rxe"
0.7.0-a1b2c3d
0.7.1-d4e5f6g
0.8.0-rc.1-h7i8j9k
```

Bad release process:

```text id="4azpbp"
docker push app:0.7.0
oops bug
fix code
docker push app:0.7.0 again
```

Better:

```text id="ptnapi"
docker push app:0.7.1
```

---

# 12. Expert — Digest-Pinned Deployment

A digest-pinned image reference:

```text id="1326g4"
ghcr.io/org/demo-node-api@sha256:abc123...
```

Benefits:

```text id="wrs7hr"
exact image content
immune to tag overwrite
best auditability
strong rollback identity
```

Tradeoffs:

```text id="kuzdsd"
less human-readable
harder manual operations
requires metadata tooling
promotion records become more important
```

Professional compromise:

```text id="d0q8q2"
Use version-sha tags for humans.
Record digest for machines/audit.
Pin by digest in high-security environments.
```

---

# 13. Intermediate — Add Digest to Metadata

Update your release metadata script to capture local image ID and optional repo digest.

Open:

```bash id="uqnyv4"
cd ~/devops-masterclass/07-artifact-management-registries

nano scripts/create-release-metadata.sh
```

Find the image inspection section and improve it conceptually like this:

```bash id="g2szx2"
LOCAL_IMAGE_ID=""
LOCAL_IMAGE_CREATED=""
REPO_DIGESTS="[]"

if docker image inspect "$IMAGE_NAME:$DEPLOY_TAG" >/dev/null 2>&1; then
  LOCAL_IMAGE_ID="$(docker image inspect "$IMAGE_NAME:$DEPLOY_TAG" --format '{{.Id}}')"
  LOCAL_IMAGE_CREATED="$(docker image inspect "$IMAGE_NAME:$DEPLOY_TAG" --format '{{.Created}}')"
  REPO_DIGESTS="$(docker image inspect "$IMAGE_NAME:$DEPLOY_TAG" --format '{{json .RepoDigests}}')"
elif docker image inspect "$IMAGE_NAME:$BASE_VERSION" >/dev/null 2>&1; then
  LOCAL_IMAGE_ID="$(docker image inspect "$IMAGE_NAME:$BASE_VERSION" --format '{{.Id}}')"
  LOCAL_IMAGE_CREATED="$(docker image inspect "$IMAGE_NAME:$BASE_VERSION" --format '{{.Created}}')"
  REPO_DIGESTS="$(docker image inspect "$IMAGE_NAME:$BASE_VERSION" --format '{{json .RepoDigests}}')"
fi

if [ "$REPO_DIGESTS" = "null" ]; then
  REPO_DIGESTS="[]"
fi
```

Then in JSON, add:

```json id="ey6gry"
  "repo_digests": $REPO_DIGESTS,
```

Final relevant JSON area should look like:

```json id="ng668s"
  "image_ref": "$IMAGE_REF",
  "local_image_id": "$LOCAL_IMAGE_ID",
  "local_image_created": "$LOCAL_IMAGE_CREATED",
  "repo_digests": $REPO_DIGESTS,
```

Run:

```bash id="x7arxk"
BASE_VERSION=0.7.0 CHANNEL=stable TEST_STATUS=passed SCAN_STATUS=passed ./scripts/create-release-metadata.sh
```

Validate:

```bash id="jm3g7h"
LATEST_METADATA="$(ls -t release-records/demo-node-api-*.json | head -n 1)"
cat "$LATEST_METADATA" | jq .
```

---

# 14. Expert — Content-Addressable Storage

Docker images are built from layers.

Each layer has content identity.

Simplified:

```text id="fh74jt"
Dockerfile instruction
  ↓
layer
  ↓
layer digest
```

Image digest depends on image manifest content.

This is why Docker can reuse layers:

```text id="3a7n8s"
same content -> same layer identity
different content -> different layer identity
```

Mental model:

```text id="7t9dpc"
Docker tags are names.
Docker layers are content-addressed objects.
Docker digests identify content.
```

This is also why small Dockerfile changes can affect image identity.

---

# 15. Beginner to Expert — Reproducibility

A reproducible build means:

```text id="zojcwr"
same input produces same output
```

In DevOps, perfect reproducibility is hard.

But we can improve it.

Bad build:

```Dockerfile id="73g1z8"
FROM node:latest
RUN npm install
COPY . .
```

Problems:

```text id="u5p7nl"
latest changes
npm install can change dependency tree
build context may include extra files
timestamps may differ
base image may change
```

Better:

```Dockerfile id="40o2zl"
FROM node:22-alpine
COPY package*.json ./
RUN npm ci --omit=dev
COPY server.js ./
COPY src ./src
```

Even better:

```Dockerfile id="wyxc1o"
FROM node:22-alpine@sha256:<digest>
```

This pins the base image content.

Expert tradeoff:

```text id="q4d14j"
Pinning base image digest improves reproducibility.
But you must actively update base digests to receive security fixes.
```

---

# 16. Professional — Lockfiles

For Node.js, `package-lock.json` is critical.

Good:

```bash id="wcd0qs"
npm ci
```

Why?

```text id="ke53fc"
uses package-lock.json
fails if package.json and lockfile mismatch
more reproducible than npm install
good for CI
```

Bad for CI:

```bash id="cu04p4"
npm install
```

Why?

```text id="w8iesk"
can update lockfile
can produce different dependency tree
less strict
```

Check:

```bash id="06r4bv"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

ls package-lock.json
npm ci
```

Professional rule:

```text id="7k2ywi"
CI builds should use lockfiles and deterministic install commands.
```

---

# 17. Expert — Base Image Pinning

Current Dockerfile likely uses:

```Dockerfile id="v04bbi"
FROM node:22-alpine
```

This is okay for learning and common in many teams.

But expert-level reproducibility may use digest pinning:

```Dockerfile id="rwd5uy"
FROM node:22-alpine@sha256:<digest>
```

How to get digest after pulling:

```bash id="m0s2gg"
docker pull node:22-alpine
docker image inspect node:22-alpine --format '{{json .RepoDigests}}' | jq .
```

You may see something like:

```text id="fsmlx0"
node@sha256:...
```

Then Dockerfile can pin:

```Dockerfile id="z17a19"
FROM node:22-alpine@sha256:...
```

Tradeoff:

```text id="134tj8"
tag pinning gets updates when image changes
digest pinning freezes exact base image
```

Production recommendation:

```text id="c7e2l8"
Use pinned major/minor tags at minimum.
Use digest pinning in high-security or high-reproducibility environments.
Automate base image update PRs.
```

---

# 18. Expert — Reproducibility Checklist

A more reproducible artifact build uses:

```text id="xl55er"
lockfiles
npm ci
pinned runtime versions
controlled CI build environment
.dockerignore
multi-stage Dockerfile
no latest tags
base image digest pinning where needed
immutable artifact tags
checksums for files
digests for images
release metadata
SBOM/provenance
```

Still not always perfectly reproducible because:

```text id="9rq0vp"
timestamps
package registries
system dependencies
architecture differences
build tool nondeterminism
```

Professional truth:

```text id="x13z3r"
Reproducibility is a maturity journey, not a single switch.
```

---

# 19. Intermediate — Create Reproducibility Notes

Create:

```bash id="4yd90l"
cd ~/devops-masterclass/07-artifact-management-registries

nano notes/checksums-digests-immutability-reproducibility.md
```

Paste:

````markdown id="nqs90l"
# Checksums, Digests, Immutability, and Reproducibility

## Checksums

A checksum is a fingerprint of a file.

```bash
sha256sum artifact.tar.gz
sha256sum -c artifact.sha256
````

## Docker Digests

A Docker digest identifies exact image content.

```text
image@sha256:...
```

## Tag vs Digest

* tag: human-friendly pointer
* digest: exact content identity

## Tag Mutability Risk

Tags can be overwritten unless registry policy prevents it.

Avoid relying on mutable tags for production.

## Immutable Artifact Rule

Never overwrite release artifacts.

Create a new version instead.

## Reproducibility Controls

* use lockfiles
* use `npm ci`
* avoid `latest`
* use `.dockerignore`
* pin base image versions
* consider digest-pinned base images
* generate checksums
* record image digests
* store release metadata

## Production Rules

* Use immutable version-sha tags.
* Record digest where possible.
* Verify checksums before using release files.
* Retain rollback artifacts.
* Do not delete currently deployed artifacts.

````

---

# 20. Expert — Registry Retention and Rollback Safety

Artifact cleanup is dangerous.

Bad cleanup:

```text id="a064w9"
delete all images older than 7 days
````

Problem:

```text id="71h6zt"
production previous version may be older than 7 days
rollback fails
```

Better retention:

```text id="kvjfx0"
keep all production release tags
keep current prod digest
keep previous prod digest
keep staging candidate
delete old PR/dev builds
delete untagged images after safe period
```

Retention policy should consider:

```text id="ezx12y"
rollback window
audit requirements
storage cost
security risk
release frequency
compliance
```

Expert rule:

```text id="oqw6y4"
Do not let cleanup policies destroy rollback capability.
```

---

# 21. Hands-On — Create Retention Policy Note

Create:

```bash id="86lj8p"
nano notes/artifact-retention-policy.md
```

Paste:

```markdown id="syw5bg"
# Artifact Retention Policy

## Goals

- keep rollback artifacts available
- reduce storage waste
- preserve audit trail
- remove temporary artifacts safely

## Keep

- current production artifact
- previous production artifact
- all tagged stable releases
- latest staging candidate
- release metadata
- SBOM and scan reports for production releases
- deployment reports

## Delete Candidates

- old PR images
- old dev branch images
- untagged images
- failed experimental builds
- old build cache

## Safe Cleanup Rule

Never delete an artifact if:

- it is currently deployed
- it is the previous production version
- it is required for audit
- it is referenced by deployment records
- it is needed for a planned rollback

## Example Policy

- Stable releases: keep indefinitely or per compliance requirement
- Production previous releases: keep at least 90 days
- Staging candidates: keep 30 days
- PR/dev images: keep 7-14 days
- Untagged images: delete after 7 days
```

---

# 22. Hands-On — Artifact Integrity Report Script

Create:

```bash id="ex8z45"
cd ~/devops-masterclass/07-artifact-management-registries

nano scripts/artifact-integrity-report.sh
```

Paste:

```bash id="nxx8o7"
#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_DIR="${ARTIFACT_DIR:-examples}"
CHECKSUM_FILE="${CHECKSUM_FILE:-checksums/artifacts.sha256}"
IMAGE_NAME="${IMAGE_NAME:-demo-node-api}"
IMAGE_TAG="${IMAGE_TAG:-}"
REPORT_DIR="${REPORT_DIR:-reports}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/artifact-integrity-$TIMESTAMP.json"

mkdir -p "$REPORT_DIR"

CHECKSUM_STATUS="not_checked"
if [ -f "$CHECKSUM_FILE" ]; then
  if sha256sum -c "$CHECKSUM_FILE" >/tmp/checksum-report.txt 2>&1; then
    CHECKSUM_STATUS="passed"
  else
    CHECKSUM_STATUS="failed"
  fi
else
  echo "checksum file missing: $CHECKSUM_FILE" >/tmp/checksum-report.txt
  CHECKSUM_STATUS="missing"
fi

IMAGE_EXISTS=false
IMAGE_ID=""
REPO_DIGESTS="[]"

if [ -n "$IMAGE_TAG" ] && docker image inspect "$IMAGE_NAME:$IMAGE_TAG" >/dev/null 2>&1; then
  IMAGE_EXISTS=true
  IMAGE_ID="$(docker image inspect "$IMAGE_NAME:$IMAGE_TAG" --format '{{.Id}}')"
  REPO_DIGESTS="$(docker image inspect "$IMAGE_NAME:$IMAGE_TAG" --format '{{json .RepoDigests}}')"
fi

if [ "$REPO_DIGESTS" = "null" ]; then
  REPO_DIGESTS="[]"
fi

cat > "$REPORT_FILE" <<EOF
{
  "artifact_dir": "$ARTIFACT_DIR",
  "checksum_file": "$CHECKSUM_FILE",
  "checksum_status": "$CHECKSUM_STATUS",
  "image_name": "$IMAGE_NAME",
  "image_tag": "$IMAGE_TAG",
  "image_exists": $IMAGE_EXISTS,
  "image_id": "$IMAGE_ID",
  "repo_digests": $REPO_DIGESTS,
  "generated_at": "$(date -Iseconds)"
}
EOF

echo "Artifact integrity report:"
cat "$REPORT_FILE" | jq .

echo
echo "Checksum details:"
cat /tmp/checksum-report.txt || true
```

Make executable:

```bash id="jtb2r4"
chmod +x scripts/artifact-integrity-report.sh
```

Run:

```bash id="ei54br"
./scripts/generate-checksums.sh

VERSION_JSON="$(BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"

IMAGE_NAME=demo-node-api IMAGE_TAG="$DEPLOY_TAG" ./scripts/artifact-integrity-report.sh
```

---

# 23. Update Makefile

Open:

```bash id="epfd8c"
cd ~/devops-masterclass/07-artifact-management-registries

nano Makefile
```

Add or ensure these targets exist:

```Makefile id="dckxe2"
.PHONY: checksums verify-checksums integrity-report

checksums:
	./scripts/generate-checksums.sh

verify-checksums:
	./scripts/verify-checksums.sh

integrity-report:
	IMAGE_NAME?=demo-node-api IMAGE_TAG?= ./scripts/artifact-integrity-report.sh
```

Use:

```bash id="zsat94"
make checksums
make verify-checksums
make integrity-report IMAGE_TAG="$DEPLOY_TAG"
```

---

# 24. Expert — Supply Chain Meaning

Checksums and digests are part of supply-chain security.

They help answer:

```text id="9l5x8c"
Is this the exact artifact CI produced?
Did the artifact change after scan?
Is production running what staging tested?
Can we prove the artifact identity?
Can we rollback to exact previous content?
```

But checksums alone do not prove trust.

They prove integrity, not identity.

Meaning:

```text id="tswyuo"
checksum tells artifact did not change
signature tells trusted party signed it
provenance tells how it was built
SBOM tells what is inside
```

We will cover signatures and provenance soon.

Expert mental model:

```text id="4h0u8h"
checksum/digest = what content?
signature = who approved/signed?
provenance = how was it built?
SBOM = what is inside?
```

---

# 25. Troubleshooting Integrity Issues

## Problem 1 — Checksum verification fails

Possible causes:

```text id="u59962"
file changed
file corrupted
wrong checksum file
artifact regenerated with same name
line endings changed
wrong path in checksum file
```

Response:

```text id="m13jhx"
do not deploy
compare artifact source
regenerate only for a new intentional artifact
create new version if content changed
```

---

## Problem 2 — Docker tag points to unexpected image

Check:

```bash id="76qyba"
docker image inspect demo-node-api:$DEPLOY_TAG --format '{{.Id}}'
docker history demo-node-api:$DEPLOY_TAG
```

Compare with metadata:

```bash id="ax3tar"
cat release-records/demo-node-api-$DEPLOY_TAG.json | jq .
```

Possible causes:

```text id="b40ng8"
tag overwritten locally
tag overwritten in registry
wrong image pulled
wrong .env APP_VERSION
```

Fix:

```text id="u19r38"
use version-sha tag
record digest
avoid mutable tags
pull exact tag or digest
```

---

## Problem 3 — Build is not reproducible

Possible causes:

```text id="f3orrw"
base image changed
dependency registry changed
lockfile missing
npm install used instead of npm ci
timestamps included
build context includes extra files
different platform architecture
```

Fix:

```text id="cyvqbv"
use lockfiles
pin base image
use .dockerignore
build in CI
record metadata
consider digest pinning
```

---

## Problem 4 — Rollback image deleted

Possible causes:

```text id="vk303e"
aggressive lifecycle policy
manual cleanup
untagged previous image
no release retention policy
```

Fix:

```text id="9m1zq9"
retain current and previous production artifacts
tag stable releases
record deployed digests
exclude release tags from cleanup
```

---

# 26. Final Validation

Run:

```bash id="8xq645"
cd ~/devops-masterclass/07-artifact-management-registries

make checksums
make verify-checksums
```

Build image with deploy tag:

```bash id="kl9lqk"
VERSION_JSON="$(BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"

cd ~/devops-masterclass/05-application-runtime/demo-node-api
VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
```

Create metadata:

```bash id="b5hwvr"
cd ~/devops-masterclass/07-artifact-management-registries

BASE_VERSION=0.7.0 \
CHANNEL=stable \
IMAGE_NAME=demo-node-api \
TEST_STATUS=passed \
SCAN_STATUS=passed \
./scripts/create-release-metadata.sh
```

Run integrity report:

```bash id="ol28s3"
IMAGE_NAME=demo-node-api IMAGE_TAG="$DEPLOY_TAG" ./scripts/artifact-integrity-report.sh
```

Deploy:

```bash id="6xy50q"
cd ~/devops-masterclass/06-docker-containers/compose-demo

APP_IMAGE=demo-node-api \
APP_VERSION="$DEPLOY_TAG" \
COMPOSE_FILES="compose.yaml compose.prod.yaml" \
./scripts/deploy-compose.sh
```

Validate running version:

```bash id="k64gph"
curl -s http://127.0.0.1:8080/version | jq .
```

---

# 27. Commit Work

Run:

```bash id="5dz2q6"
cd ~/devops-masterclass

git status
git add 07-artifact-management-registries

git commit -m "feat: add artifact integrity and reproducibility patterns"
git push
```

---

# 28. Interview Explanation

## What is a checksum?

Strong answer:

```text id="k5hzcv"
A checksum is a cryptographic fingerprint of a file. I use SHA256 checksums to verify that release artifacts have not changed or become corrupted. If the file changes, the checksum verification fails.
```

## What is a Docker image digest?

Strong answer:

```text id="jj9hg2"
A Docker image digest is a content-addressed identifier for image content, usually represented as sha256. Unlike a tag, which can be overwritten, a digest identifies the exact image content.
```

## Difference between tag and digest?

Strong answer:

```text id="fciivj"
A tag is a human-friendly reference that can point to an image, such as app:1.0.0. A digest is a content identity like sha256 that points to exact image content. Tags are convenient, but digests are stronger for audit and reproducibility.
```

## Why is tag mutability dangerous?

Strong answer:

```text id="8shefr"
If a tag can be overwritten, the same tag may refer to different image content over time. That breaks auditability, rollback safety, and confidence that production is running the same artifact that was tested.
```

## How do you improve build reproducibility?

Strong answer:

```text id="fb26sl"
I use lockfiles, deterministic install commands like npm ci, pinned runtime versions, .dockerignore, controlled CI builds, immutable image tags, checksums for release files, image digests, and release metadata. In higher-security environments, I also pin base images by digest and generate SBOM/provenance.
```

## Should you pin base images by digest?

Strong answer:

```text id="1wl5zh"
Digest pinning improves reproducibility because it freezes the exact base image. The tradeoff is that security updates will not be picked up automatically, so teams need automation to update pinned digests regularly.
```

---

# Today’s Core Rules

```text id="w71etn"
Checksums verify file integrity.
Docker digests identify exact image content.
Tags are pointers and may be mutable.
Do not rely on latest for production.
Use immutable version-sha tags.
Record digests where possible.
Never overwrite release artifacts.
Use lockfiles and npm ci.
Use .dockerignore.
Avoid latest base images.
Consider digest-pinned base images for high assurance.
Retention policy must protect rollback artifacts.
Checksum proves integrity, not trust.
Signature proves trusted signer.
Provenance explains how artifact was built.
SBOM explains what is inside.
```

---

# Next Lesson

# Lesson 7.4 — Docker Registry Deep Dive: Docker Hub, GHCR, ECR, Repository Structure, Auth, Pull/Push Permissions, Tag Immutability, and Registry Operations

We will go deeper into:

```text id="tme2lq"
Docker Hub
GitHub Container Registry
Amazon ECR
repository naming
private vs public images
login methods
push/pull permission models
tag immutability
lifecycle policies
registry scanning
registry troubleshooting
corporate registry architecture
```

# Lesson 7.7 — SBOM Fundamentals Deep Dive

# CycloneDX, SPDX, Docker Scout, Trivy, CI/CD Storage, Vulnerability Response, and Supply-Chain Visibility

SBOM means:

```text id="kirp7p"
Software Bill of Materials
```

A simple definition:

```text id="v94fd9"
An SBOM is an inventory of the software components inside an application or artifact.
```

For Docker images, an SBOM answers:

```text id="ojuj8b"
Which OS packages are inside this image?
Which npm packages are inside?
Which versions?
Which licenses?
Which dependencies?
Which component may be affected by a CVE?
```

Docker Scout uses SBOMs to understand which packages and versions an image contains, and if an SBOM attestation is not available, Docker Scout can create one by indexing the image contents. ([Docker Documentation][1])

---

# 1. Beginner Level — Why SBOM Matters

Imagine a serious vulnerability appears in a package:

```text id="g5r8ul"
openssl
lodash
express
zlib
glibc
busybox
```

Without SBOM, you ask:

```text id="biug4l"
Do we use this package?
Which service has it?
Which image version has it?
Is production affected?
Which version fixed it?
```

With SBOM, you can answer faster:

```text id="o6xw2w"
demo-node-api:0.7.0-a1b2c3d contains package X version Y.
Production is affected.
Patch image 0.7.1-d4e5f6g removes/upgrades it.
```

Core rule:

```text id="auf8wy"
SBOM gives visibility into what is inside your artifact.
```

---

# 2. Beginner Mental Model

Think of a Docker image like a food product.

The Docker image is the product:

```text id="n2g35k"
demo-node-api:0.7.0-a1b2c3d
```

The SBOM is the ingredient label:

```text id="a5034h"
node
express
mongoose
winston
alpine packages
npm dependencies
transitive dependencies
```

It does not automatically make the image secure.

It tells you what is inside.

Professional statement:

```text id="te5ur9"
SBOM is visibility, not security by itself.
```

Security comes from using SBOM with:

```text id="9c0n3v"
vulnerability scanning
policy gates
patching
risk triage
signing
provenance
retention
incident response
```

---

# 3. SBOM vs Vulnerability Scan

These are related but different.

```text id="qewfbj"
SBOM:
  inventory of components

Vulnerability scan:
  compares components against vulnerability databases
```

Example:

```text id="ogpxzz"
SBOM says:
  express 4.18.2 exists

Scanner says:
  express 4.18.2 has/does not have known CVEs
```

Docker Scout cross-references SBOM information with advisory data to determine whether image components have known vulnerabilities. ([Docker Documentation][2])

Core rule:

```text id="p6yl1c"
SBOM tells what exists. Scanner tells what may be risky.
```

---

# 4. SBOM Formats — CycloneDX and SPDX

The two most common SBOM formats are:

```text id="b9udl5"
CycloneDX
SPDX
```

CycloneDX is an OWASP full-stack Bill of Materials standard focused on supply-chain risk reduction. ([CycloneDX][3])

SPDX is an open standard for representing systems with software components as SBOMs, and SPDX is also an ISO/IEC 5962:2021 international open standard. ([SPDX][4])

Simple comparison:

| Topic       | CycloneDX                                 | SPDX                                                       |
| ----------- | ----------------------------------------- | ---------------------------------------------------------- |
| Origin      | OWASP ecosystem                           | Linux Foundation ecosystem                                 |
| Common use  | Security and supply-chain risk            | Licensing, compliance, supply-chain                        |
| Formats     | JSON/XML/protobuf depending on spec/tool  | Tag-value, JSON, YAML, RDF, etc. depending on version/tool |
| Good for    | Security workflows, vulnerability context | License/compliance and standardized interchange            |
| In practice | Very popular in AppSec tooling            | Very popular in legal/compliance/open-source governance    |

Professional rule:

```text id="e76x34"
Support at least one major SBOM format. CycloneDX and SPDX are both important.
```

For your project, generate both:

```text id="w62o90"
CycloneDX JSON
SPDX JSON
```

---

# 5. Beginner — What Does an SBOM Contain?

A useful SBOM may contain:

```text id="m3e3yr"
component name
component version
component type
package URL / PURL
supplier
license
hashes
dependency relationships
metadata about tool that generated SBOM
timestamp
main artifact identity
```

For Docker images, you may see:

```text id="6auy1s"
OS packages:
  apk packages from Alpine

Language packages:
  npm packages from package-lock.json / node_modules

Container metadata:
  image name
  image ID
  repo digest
```

---

# 6. Hands-On — Prepare Directory

Run:

```bash id="saw5ve"
cd ~/devops-masterclass/07-artifact-management-registries

mkdir -p sbom/{cyclonedx,spdx,docker-scout,trivy,reports}
```

Check:

```bash id="v72g4l"
tree -L 2 sbom
```

Expected:

```text id="yae4e6"
sbom
├── cyclonedx
├── docker-scout
├── reports
├── spdx
└── trivy
```

---

# 7. Build Image for SBOM Lab

Compute version:

```bash id="9hvcpx"
cd ~/devops-masterclass/07-artifact-management-registries

VERSION_JSON="$(BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"

echo "$DEPLOY_TAG"
```

Build image:

```bash id="ts0ge0"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
```

Check image:

```bash id="8ncbmd"
docker images | grep demo-node-api
```

---

# 8. Generate SBOM with Docker Scout

Docker Scout has a `docker scout sbom` command that analyzes an image or other artifact and generates an SBOM; supported output formats include `json`, `spdx`, and `cyclonedx`, and the `--output` flag writes the report to a file. ([Docker Documentation][5])

Generate human-readable list:

```bash id="jgo2pk"
docker scout sbom --format list demo-node-api:$DEPLOY_TAG
```

Generate Docker Scout default JSON:

```bash id="12fx6w"
cd ~/devops-masterclass/07-artifact-management-registries

docker scout sbom \
  --format json \
  --output "sbom/docker-scout/demo-node-api-$DEPLOY_TAG.scout.json" \
  "demo-node-api:$DEPLOY_TAG"
```

Generate SPDX:

```bash id="9j2knx"
docker scout sbom \
  --format spdx \
  --output "sbom/spdx/demo-node-api-$DEPLOY_TAG.docker-scout.spdx.json" \
  "demo-node-api:$DEPLOY_TAG"
```

Generate CycloneDX:

```bash id="i4o2ce"
docker scout sbom \
  --format cyclonedx \
  --output "sbom/cyclonedx/demo-node-api-$DEPLOY_TAG.docker-scout.cdx.json" \
  "demo-node-api:$DEPLOY_TAG"
```

Inspect:

```bash id="4lenbl"
ls -lh sbom/docker-scout sbom/spdx sbom/cyclonedx
jq '. | keys' "sbom/cyclonedx/demo-node-api-$DEPLOY_TAG.docker-scout.cdx.json" || true
```

If `docker scout` is not available, use Trivy in the next section.

---

# 9. Generate SBOM with Trivy

Trivy can generate SBOMs in CycloneDX and SPDX formats; its docs show `trivy image --format spdx-json --output result.json alpine:3.15` and `trivy image --format cyclonedx --output result.json alpine:3.15`. ([Trivy][6])

Install Trivy if needed:

```bash id="g0m1qv"
trivy --version
```

If not installed, you can use the Trivy container image:

```bash id="5re0hv"
docker run --rm aquasec/trivy:latest --version
```

Generate CycloneDX with local Trivy:

```bash id="v6fcl4"
cd ~/devops-masterclass/07-artifact-management-registries

trivy image \
  --format cyclonedx \
  --output "sbom/cyclonedx/demo-node-api-$DEPLOY_TAG.trivy.cdx.json" \
  "demo-node-api:$DEPLOY_TAG"
```

Generate SPDX JSON:

```bash id="7k75vz"
trivy image \
  --format spdx-json \
  --output "sbom/spdx/demo-node-api-$DEPLOY_TAG.trivy.spdx.json" \
  "demo-node-api:$DEPLOY_TAG"
```

Using Trivy container:

```bash id="5i0f7m"
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD/sbom:/sbom" \
  aquasec/trivy:latest image \
  --format cyclonedx \
  --output "/sbom/cyclonedx/demo-node-api-$DEPLOY_TAG.trivy.cdx.json" \
  "demo-node-api:$DEPLOY_TAG"
```

Security caution:

```text id="tpt2q2"
Mounting /var/run/docker.sock gives powerful Docker access. Use it carefully and avoid giving it to untrusted containers.
```

---

# 10. Include Vulnerabilities in CycloneDX with Trivy

By default, Trivy’s `--format cyclonedx` represents an SBOM and does not include vulnerabilities; Trivy docs say to enable vulnerability scanning with `--scanners vuln` if you want vulnerabilities included in the CycloneDX report. ([Trivy][6])

Generate CycloneDX with vulnerability information:

```bash id="n1ufn2"
trivy image \
  --scanners vuln \
  --format cyclonedx \
  --output "sbom/cyclonedx/demo-node-api-$DEPLOY_TAG.trivy.vuln.cdx.json" \
  "demo-node-api:$DEPLOY_TAG"
```

Professional rule:

```text id="c59ry6"
Keep pure SBOM and vulnerability report separate unless your security workflow explicitly requires combined output.
```

Why?

```text id="ldogbj"
SBOM changes when artifact contents change.
Vulnerability report can change when vulnerability databases update.
```

---

# 11. Scan an SBOM as Input

Trivy can also take an SBOM document as input for scanning, using commands such as `trivy sbom ./sbom.spdx`. ([Trivy][6])

Example:

```bash id="29rcy7"
trivy sbom \
  "sbom/spdx/demo-node-api-$DEPLOY_TAG.trivy.spdx.json"
```

Output to JSON:

```bash id="o7p8qq"
trivy sbom \
  --format json \
  --output "sbom/reports/demo-node-api-$DEPLOY_TAG.sbom-scan.json" \
  "sbom/spdx/demo-node-api-$DEPLOY_TAG.trivy.spdx.json"
```

This is powerful because you can scan stored SBOMs later without needing to rebuild or re-pull the image.

---

# 12. Professional — SBOM Naming Convention

Use names that include:

```text id="fgoi1r"
service name
version/deploy tag
tool
format
optional scan type
```

Examples:

```text id="7wtfy4"
demo-node-api-0.7.0-a1b2c3d.trivy.cdx.json
demo-node-api-0.7.0-a1b2c3d.trivy.spdx.json
demo-node-api-0.7.0-a1b2c3d.docker-scout.spdx.json
demo-node-api-0.7.0-a1b2c3d.sbom-scan.json
```

Good directory layout:

```text id="cmn9oc"
sbom/
├── cyclonedx/
├── spdx/
├── docker-scout/
├── trivy/
└── reports/
```

Professional rule:

```text id="86c8js"
SBOM filename should identify the artifact, version, tool, and format.
```

---

# 13. Create SBOM Generation Script

Create:

```bash id="dzxmbo"
cd ~/devops-masterclass/07-artifact-management-registries

nano scripts/generate-sbom.sh
```

Paste:

```bash id="q0tgzx"
#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-demo-node-api}"
IMAGE_TAG="${IMAGE_TAG:-}"
TOOL="${TOOL:-trivy}"   # trivy, docker-scout, both
OUTPUT_ROOT="${OUTPUT_ROOT:-sbom}"

if [ -z "$IMAGE_TAG" ]; then
  echo "ERROR: IMAGE_TAG is required" >&2
  echo "Example: IMAGE_TAG=0.7.0-a1b2c3d $0" >&2
  exit 1
fi

IMAGE_REF="$IMAGE_NAME:$IMAGE_TAG"

docker image inspect "$IMAGE_REF" >/dev/null

mkdir -p "$OUTPUT_ROOT/cyclonedx" "$OUTPUT_ROOT/spdx" "$OUTPUT_ROOT/docker-scout" "$OUTPUT_ROOT/trivy" "$OUTPUT_ROOT/reports"

echo "===== Generate SBOM ====="
echo "Image: $IMAGE_REF"
echo "Tool: $TOOL"

generate_trivy() {
  if command -v trivy >/dev/null 2>&1; then
    echo
    echo "Generating Trivy CycloneDX..."
    trivy image \
      --format cyclonedx \
      --output "$OUTPUT_ROOT/cyclonedx/$IMAGE_NAME-$IMAGE_TAG.trivy.cdx.json" \
      "$IMAGE_REF"

    echo
    echo "Generating Trivy SPDX JSON..."
    trivy image \
      --format spdx-json \
      --output "$OUTPUT_ROOT/spdx/$IMAGE_NAME-$IMAGE_TAG.trivy.spdx.json" \
      "$IMAGE_REF"

    echo
    echo "Generating Trivy SBOM vulnerability scan report..."
    trivy sbom \
      --format json \
      --output "$OUTPUT_ROOT/reports/$IMAGE_NAME-$IMAGE_TAG.trivy.sbom-scan.json" \
      "$OUTPUT_ROOT/spdx/$IMAGE_NAME-$IMAGE_TAG.trivy.spdx.json" || true
  else
    echo "WARNING: trivy not installed. Skipping Trivy SBOM generation." >&2
  fi
}

generate_docker_scout() {
  if docker scout version >/dev/null 2>&1; then
    echo
    echo "Generating Docker Scout JSON..."
    docker scout sbom \
      --format json \
      --output "$OUTPUT_ROOT/docker-scout/$IMAGE_NAME-$IMAGE_TAG.scout.json" \
      "$IMAGE_REF"

    echo
    echo "Generating Docker Scout SPDX..."
    docker scout sbom \
      --format spdx \
      --output "$OUTPUT_ROOT/spdx/$IMAGE_NAME-$IMAGE_TAG.docker-scout.spdx.json" \
      "$IMAGE_REF"

    echo
    echo "Generating Docker Scout CycloneDX..."
    docker scout sbom \
      --format cyclonedx \
      --output "$OUTPUT_ROOT/cyclonedx/$IMAGE_NAME-$IMAGE_TAG.docker-scout.cdx.json" \
      "$IMAGE_REF"
  else
    echo "WARNING: Docker Scout not available. Skipping Docker Scout SBOM generation." >&2
  fi
}

case "$TOOL" in
  trivy)
    generate_trivy
    ;;
  docker-scout)
    generate_docker_scout
    ;;
  both)
    generate_trivy
    generate_docker_scout
    ;;
  *)
    echo "ERROR: unsupported TOOL=$TOOL" >&2
    echo "Allowed: trivy, docker-scout, both" >&2
    exit 1
    ;;
esac

echo
echo "SBOM files:"
find "$OUTPUT_ROOT" -type f -name "*$IMAGE_TAG*" -print | sort
```

Make executable:

```bash id="jcqonw"
chmod +x scripts/generate-sbom.sh
```

Run:

```bash id="tp8h5m"
IMAGE_TAG="$DEPLOY_TAG" TOOL=both ./scripts/generate-sbom.sh
```

If one tool is unavailable, use:

```bash id="m21vcw"
IMAGE_TAG="$DEPLOY_TAG" TOOL=trivy ./scripts/generate-sbom.sh
```

---

# 14. Create SBOM Summary Script

Create:

```bash id="ezwol0"
nano scripts/sbom-summary.sh
```

Paste:

```bash id="4q3rji"
#!/usr/bin/env bash
set -euo pipefail

SBOM_FILE="${1:-}"

if [ -z "$SBOM_FILE" ]; then
  echo "Usage: $0 <sbom-file.json>" >&2
  exit 1
fi

if [ ! -f "$SBOM_FILE" ]; then
  echo "ERROR: file not found: $SBOM_FILE" >&2
  exit 1
fi

echo "===== SBOM Summary ====="
echo "File: $SBOM_FILE"

if jq -e '.bomFormat == "CycloneDX"' "$SBOM_FILE" >/dev/null 2>&1; then
  echo "Format: CycloneDX"
  echo "Spec: $(jq -r '.specVersion // "unknown"' "$SBOM_FILE")"
  echo "Components: $(jq '.components // [] | length' "$SBOM_FILE")"

  echo
  echo "Top components:"
  jq -r '
    (.components // [])[]
    | [
        (.type // "unknown"),
        (.name // "unknown"),
        (.version // "unknown")
      ]
    | @tsv
  ' "$SBOM_FILE" | head -n 20

elif jq -e '.spdxVersion or .SPDXID' "$SBOM_FILE" >/dev/null 2>&1; then
  echo "Format: SPDX JSON"
  echo "SPDX version: $(jq -r '.spdxVersion // "unknown"' "$SBOM_FILE")"
  echo "Packages: $(jq '.packages // [] | length' "$SBOM_FILE")"

  echo
  echo "Top packages:"
  jq -r '
    (.packages // [])[]
    | [
        (.name // "unknown"),
        (.versionInfo // "unknown"),
        (.downloadLocation // "unknown")
      ]
    | @tsv
  ' "$SBOM_FILE" | head -n 20

else
  echo "Format: unknown or tool-specific JSON"
  jq 'keys' "$SBOM_FILE"
fi
```

Make executable:

```bash id="dsaylk"
chmod +x scripts/sbom-summary.sh
```

Run:

```bash id="ycjdr2"
./scripts/sbom-summary.sh "sbom/cyclonedx/demo-node-api-$DEPLOY_TAG.trivy.cdx.json"
./scripts/sbom-summary.sh "sbom/spdx/demo-node-api-$DEPLOY_TAG.trivy.spdx.json"
```

---

# 15. Create SBOM Index Script

An SBOM index helps track which SBOM belongs to which artifact.

Create:

```bash id="r3l32d"
nano scripts/create-sbom-index.sh
```

Paste:

```bash id="df8x2f"
#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"
IMAGE_NAME="${IMAGE_NAME:-demo-node-api}"
IMAGE_TAG="${IMAGE_TAG:-}"
SBOM_ROOT="${SBOM_ROOT:-sbom}"
OUTPUT_DIR="${OUTPUT_DIR:-release-records/sbom-index}"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if [ -z "$IMAGE_TAG" ]; then
  echo "ERROR: IMAGE_TAG is required" >&2
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

OUTPUT_FILE="$OUTPUT_DIR/$SERVICE_NAME-$IMAGE_TAG-sbom-index.json"

FILES_JSON="$(find "$SBOM_ROOT" -type f -name "*$IMAGE_TAG*" -print | sort | jq -R . | jq -s .)"

cat > "$OUTPUT_FILE" <<EOF
{
  "service_name": "$SERVICE_NAME",
  "image_name": "$IMAGE_NAME",
  "image_tag": "$IMAGE_TAG",
  "image_id": "$IMAGE_ID",
  "repo_digests": $REPO_DIGESTS,
  "sbom_files": $FILES_JSON,
  "created_at": "$TIMESTAMP"
}
EOF

echo "SBOM index created:"
cat "$OUTPUT_FILE" | jq .
```

Make executable:

```bash id="fp7me9"
chmod +x scripts/create-sbom-index.sh
```

Run:

```bash id="l5z4v2"
IMAGE_TAG="$DEPLOY_TAG" ./scripts/create-sbom-index.sh
```

---

# 16. Add SBOM Path to Release Metadata

Your release metadata should reference SBOM files.

Create metadata with SBOM path:

```bash id="e5pocy"
LATEST_CDX="sbom/cyclonedx/demo-node-api-$DEPLOY_TAG.trivy.cdx.json"

BASE_VERSION=0.7.0 \
CHANNEL=stable \
IMAGE_NAME=demo-node-api \
TEST_STATUS=passed \
SCAN_STATUS=passed \
SBOM_PATH="$LATEST_CDX" \
./scripts/create-release-metadata.sh
```

Validate:

```bash id="ot7n5h"
LATEST_METADATA="$(ls -t release-records/demo-node-api-*.json | head -n 1)"
cat "$LATEST_METADATA" | jq .
```

Expected field:

```json id="lusr0g"
"sbom_path": "sbom/cyclonedx/demo-node-api-..."
```

Professional rule:

```text id="dnvsys"
Release metadata should point to the SBOM generated for that exact artifact.
```

---

# 17. SBOM in CI/CD

A professional CI pipeline should do:

```text id="d49wb2"
build image
generate SBOM
scan image or SBOM
store SBOM artifact
push image
record image tag/digest/SBOM path
```

With Docker Buildx, build workflows can also attach SBOM/provenance attestations using build options. Docker Scout docs describe generating an SBOM and attaching it as a build-time attestation with `--attest type=sbom`, and Docker’s build-push-action supports `sbom: true` and `provenance: true` options in workflows. ([Docker Documentation][1])

GitHub Actions example:

```yaml id="u7i2mg"
      - name: Build and push image with SBOM/provenance
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
          provenance: true
```

Also save explicit SBOM files as workflow artifacts:

```yaml id="tr7xf9"
      - name: Generate Trivy SBOM
        run: |
          trivy image \
            --format cyclonedx \
            --output "demo-node-api-${{ steps.version.outputs.deploy_tag }}.cdx.json" \
            "${{ env.IMAGE_NAME }}:${{ steps.version.outputs.deploy_tag }}"

      - name: Upload SBOM artifact
        uses: actions/upload-artifact@v4
        with:
          name: sbom-${{ steps.version.outputs.deploy_tag }}
          path: demo-node-api-${{ steps.version.outputs.deploy_tag }}.cdx.json
```

Professional rule:

```text id="k9644k"
Attach SBOM to image where possible, and store SBOM files as release evidence.
```

---

# 18. Create GitHub Actions SBOM Example

Create:

```bash id="9fiinc"
cd ~/devops-masterclass/07-artifact-management-registries

nano examples/github-actions-sbom.yml
```

Paste:

```yaml id="3utlgr"
name: SBOM Example

on:
  workflow_dispatch:

permissions:
  contents: read
  packages: write

env:
  APP_DIR: 05-application-runtime/demo-node-api
  IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/demo-node-api
  BASE_VERSION: "0.7.0"

jobs:
  sbom:
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

      - name: Build and push with SBOM/provenance attestations
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
          provenance: true

      - name: Generate explicit Trivy SBOM files
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.IMAGE_NAME }}:${{ steps.version.outputs.deploy_tag }}
          format: cyclonedx
          output: demo-node-api-${{ steps.version.outputs.deploy_tag }}.cdx.json

      - name: Upload SBOM file
        uses: actions/upload-artifact@v4
        with:
          name: sbom-${{ steps.version.outputs.deploy_tag }}
          path: demo-node-api-${{ steps.version.outputs.deploy_tag }}.cdx.json
```

This is an example file, not necessarily your final production workflow.

---

# 19. SBOM Storage Strategy

Where should SBOMs live?

Options:

```text id="dft1qi"
CI workflow artifacts
GitHub Releases
S3 artifact bucket
artifact repository
registry attestation
security platform
release-records folder for learning
```

Recommended for your learning project:

```text id="ntst4z"
local repo:
  release-records/sbom-index/*.json

CI:
  upload-artifact

registry:
  build-push-action sbom attestation

future AWS:
  store SBOM in S3 with release metadata
```

Professional rule:

```text id="ot4e7j"
SBOM must be stored where security, DevOps, and incident responders can find it.
```

---

# 20. SBOM and Vulnerability Response

When a new CVE appears, use this flow:

```text id="xu09zi"
1. Identify affected package name/version.
2. Search SBOMs for package.
3. Identify affected images and environments.
4. Check exploitability and runtime exposure.
5. Build patched image.
6. Generate new SBOM.
7. Scan again.
8. Promote patched artifact.
9. Deploy.
10. Record response.
```

Example search:

```bash id="lmr1lf"
grep -R "\"express\"" sbom/ release-records/ || true
grep -R "\"openssl\"" sbom/ release-records/ || true
```

For CycloneDX:

```bash id="2vi2qj"
jq -r '
  (.components // [])[]
  | select((.name // "") | test("express|openssl"; "i"))
  | [.type, .name, .version]
  | @tsv
' "sbom/cyclonedx/demo-node-api-$DEPLOY_TAG.trivy.cdx.json"
```

For SPDX:

```bash id="wzow1f"
jq -r '
  (.packages // [])[]
  | select((.name // "") | test("express|openssl"; "i"))
  | [.name, .versionInfo]
  | @tsv
' "sbom/spdx/demo-node-api-$DEPLOY_TAG.trivy.spdx.json"
```

---

# 21. Create SBOM Search Script

Create:

```bash id="rxj02b"
nano scripts/search-sbom-package.sh
```

Paste:

```bash id="sk2107"
#!/usr/bin/env bash
set -euo pipefail

PACKAGE="${1:-}"
SBOM_ROOT="${SBOM_ROOT:-sbom}"

if [ -z "$PACKAGE" ]; then
  echo "Usage: $0 <package-name>" >&2
  exit 1
fi

if [ ! -d "$SBOM_ROOT" ]; then
  echo "ERROR: SBOM directory not found: $SBOM_ROOT" >&2
  exit 1
fi

echo "===== Search SBOM Package ====="
echo "Package: $PACKAGE"
echo "SBOM root: $SBOM_ROOT"

find "$SBOM_ROOT" -type f -name "*.json" | sort | while read -r file; do
  matches=""

  if jq -e '.bomFormat == "CycloneDX"' "$file" >/dev/null 2>&1; then
    matches="$(jq -r --arg pkg "$PACKAGE" '
      (.components // [])[]
      | select((.name // "") | test($pkg; "i"))
      | "CycloneDX\t" + .name + "\t" + (.version // "unknown")
    ' "$file")"
  elif jq -e '.spdxVersion or .SPDXID' "$file" >/dev/null 2>&1; then
    matches="$(jq -r --arg pkg "$PACKAGE" '
      (.packages // [])[]
      | select((.name // "") | test($pkg; "i"))
      | "SPDX\t" + .name + "\t" + (.versionInfo // "unknown")
    ' "$file")"
  fi

  if [ -n "$matches" ]; then
    echo
    echo "File: $file"
    echo "$matches"
  fi
done
```

Make executable:

```bash id="dtz852"
chmod +x scripts/search-sbom-package.sh
```

Run:

```bash id="j2cl3a"
./scripts/search-sbom-package.sh express
./scripts/search-sbom-package.sh openssl
./scripts/search-sbom-package.sh node
```

---

# 22. Create SBOM Vulnerability Response Note

Create:

```bash id="t46zfb"
nano notes/sbom-vulnerability-response.md
```

Paste:

````markdown id="1ha81m"
# SBOM Vulnerability Response

## Goal

Use SBOMs to quickly identify whether our artifacts contain a vulnerable component.

## Response Flow

1. Identify vulnerable package and affected versions.
2. Search stored SBOMs.
3. Identify affected images.
4. Identify affected environments.
5. Check exploitability.
6. Patch dependency or base image.
7. Rebuild image.
8. Generate new SBOM.
9. Scan new image/SBOM.
10. Deploy patched artifact.
11. Store response record.

## Search Examples

```bash
./scripts/search-sbom-package.sh express
./scripts/search-sbom-package.sh openssl
````

## Important Distinction

SBOM tells what is inside.

Vulnerability scan tells whether known vulnerabilities affect those components.

Exploitability analysis tells whether the vulnerability is reachable or relevant in our runtime.

## Production Rule

Do not panic-deploy blindly. Triage severity, exposure, exploitability, and availability of fixes.

````

---

# 23. SBOM Quality Problems

SBOMs are not perfect.

Common issues:

```text id="pcwq4u"
tool misses packages
tool reports duplicate packages
tool cannot identify custom binaries
transitive dependencies unclear
version metadata missing
container image has files without package metadata
different tools generate different results
SBOM gets detached from artifact
````

Professional approach:

```text id="wmdwe3"
generate SBOM during CI
record image digest
store SBOM with release metadata
use more than one tool for critical apps if needed
validate SBOM format
treat SBOM as evidence, not magic
```

Expert statement:

```text id="pphfi1"
SBOM completeness depends on ecosystem metadata, package managers, image contents, and generator quality.
```

---

# 24. SBOM Policy

Create:

```bash id="my9vg1"
nano notes/sbom-policy.md
```

Paste:

```markdown id="d20i2o"
# SBOM Policy

## Scope

Production container images should have an SBOM.

## Required Formats

At least one of:

- CycloneDX JSON
- SPDX JSON

For learning and high confidence, generate both.

## Required Metadata

SBOM record should link to:

- service name
- image tag
- image digest if available
- build commit SHA
- SBOM tool
- SBOM format
- generated timestamp

## CI/CD Requirements

- Generate SBOM after image build.
- Store SBOM as CI artifact.
- Reference SBOM in release metadata.
- Scan image or SBOM before promotion.
- Keep SBOMs for production releases.

## Retention

Keep SBOMs for:

- current production image
- previous production image
- stable releases
- audit period required by policy

## Security Response

Use SBOMs to identify affected artifacts when new vulnerabilities are disclosed.
```

---

# 25. Update Makefile

Open:

```bash id="arrju0"
cd ~/devops-masterclass/07-artifact-management-registries

nano Makefile
```

Add:

```Makefile id="iozptg"
.PHONY: sbom sbom-trivy sbom-scout sbom-summary sbom-index sbom-search

sbom:
	@test -n "$(IMAGE_TAG)" || (echo "Usage: make sbom IMAGE_TAG=<tag> TOOL=trivy" && exit 1)
	IMAGE_TAG="$(IMAGE_TAG)" TOOL="$${TOOL:-trivy}" ./scripts/generate-sbom.sh

sbom-trivy:
	@test -n "$(IMAGE_TAG)" || (echo "Usage: make sbom-trivy IMAGE_TAG=<tag>" && exit 1)
	IMAGE_TAG="$(IMAGE_TAG)" TOOL=trivy ./scripts/generate-sbom.sh

sbom-scout:
	@test -n "$(IMAGE_TAG)" || (echo "Usage: make sbom-scout IMAGE_TAG=<tag>" && exit 1)
	IMAGE_TAG="$(IMAGE_TAG)" TOOL=docker-scout ./scripts/generate-sbom.sh

sbom-index:
	@test -n "$(IMAGE_TAG)" || (echo "Usage: make sbom-index IMAGE_TAG=<tag>" && exit 1)
	IMAGE_TAG="$(IMAGE_TAG)" ./scripts/create-sbom-index.sh

sbom-summary:
	@test -n "$(FILE)" || (echo "Usage: make sbom-summary FILE=<sbom-json>" && exit 1)
	./scripts/sbom-summary.sh "$(FILE)"

sbom-search:
	@test -n "$(PACKAGE)" || (echo "Usage: make sbom-search PACKAGE=<name>" && exit 1)
	./scripts/search-sbom-package.sh "$(PACKAGE)"
```

Use:

```bash id="ek2mx8"
make sbom-trivy IMAGE_TAG="$DEPLOY_TAG"
make sbom-index IMAGE_TAG="$DEPLOY_TAG"
make sbom-search PACKAGE=express
```

---

# 26. Final Validation

Run:

```bash id="mm07qa"
cd ~/devops-masterclass/07-artifact-management-registries

VERSION_JSON="$(BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"

echo "$DEPLOY_TAG"
```

Build image if needed:

```bash id="jz7f0x"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
```

Generate SBOM:

```bash id="atsb4m"
cd ~/devops-masterclass/07-artifact-management-registries

IMAGE_TAG="$DEPLOY_TAG" TOOL=trivy ./scripts/generate-sbom.sh
IMAGE_TAG="$DEPLOY_TAG" ./scripts/create-sbom-index.sh
```

Summarize:

```bash id="xfkvcj"
./scripts/sbom-summary.sh "sbom/cyclonedx/demo-node-api-$DEPLOY_TAG.trivy.cdx.json"
./scripts/sbom-summary.sh "sbom/spdx/demo-node-api-$DEPLOY_TAG.trivy.spdx.json"
```

Search:

```bash id="grrbkz"
./scripts/search-sbom-package.sh express
```

Create release metadata with SBOM:

```bash id="zzmjzb"
BASE_VERSION=0.7.0 \
CHANNEL=stable \
IMAGE_NAME=demo-node-api \
TEST_STATUS=passed \
SCAN_STATUS=passed \
SBOM_PATH="sbom/cyclonedx/demo-node-api-$DEPLOY_TAG.trivy.cdx.json" \
./scripts/create-release-metadata.sh
```

---

# 27. Commit Work

Run:

```bash id="i6t5az"
cd ~/devops-masterclass

git status
git add 07-artifact-management-registries

git commit -m "feat: add SBOM generation and vulnerability response workflow"
git push
```

---

# 28. Interview Explanation

## What is an SBOM?

Strong answer:

```text id="6k1vab"
An SBOM, or Software Bill of Materials, is an inventory of software components inside an artifact. For a Docker image, it can list OS packages, language dependencies, versions, licenses, package URLs, and dependency relationships.
```

## Why is SBOM important?

Strong answer:

```text id="x5c89b"
SBOMs improve supply-chain visibility. When a vulnerability is disclosed, we can search SBOMs to identify which artifacts and environments contain the affected component, then patch, rebuild, scan, and redeploy more quickly.
```

## SBOM vs vulnerability scan?

Strong answer:

```text id="vsa6hd"
An SBOM lists what is inside the artifact. A vulnerability scan compares that inventory against vulnerability databases to identify known risks. SBOM is inventory; scanning is risk detection.
```

## CycloneDX vs SPDX?

Strong answer:

```text id="3xizjm"
CycloneDX is an OWASP Bill of Materials standard widely used in security and supply-chain workflows. SPDX is a Linux Foundation standard and ISO-recognized format often used for license compliance and software component interchange. Both are common and useful.
```

## Where should SBOMs be stored?

Strong answer:

```text id="en7mq5"
I store SBOMs with release evidence: as CI artifacts, linked in release metadata, optionally attached as registry attestations, and retained for production releases. The SBOM should be traceable to the exact image tag and digest.
```

## Should SBOM include vulnerabilities?

Strong answer:

```text id="hxo7ak"
Usually I keep the SBOM and vulnerability report separate because the SBOM represents artifact contents, while vulnerability results can change as databases update. Some formats and tools can include vulnerability data, but the workflow should be explicit.
```

---

# Today’s Core Rules

```text id="bbgmpn"
SBOM means Software Bill of Materials.
SBOM is an inventory of artifact components.
SBOM is not the same as a vulnerability scan.
CycloneDX and SPDX are the major SBOM formats.
Generate SBOM for production images.
Store SBOM with release metadata.
Record image tag and digest with SBOM.
Generate SBOM in CI/CD.
Attach SBOM as registry attestation where possible.
Keep SBOMs for current and previous production releases.
Use SBOMs during vulnerability response.
SBOM quality depends on tool and ecosystem metadata.
```

---

# Next Lesson

# Lesson 7.8 — Provenance and Build Attestations Deep Dive

We will go deeper into:

```text id="x32wsm"
what provenance means
who built the artifact
where it was built
from which source
SLSA concepts
BuildKit attestations
GitHub Actions provenance
Docker build-push-action provenance
attestation storage
provenance vs SBOM vs signature
supply-chain verification workflow
```

[1]: https://docs.docker.com/scout/how-tos/view-create-sboms/ "Docker Scout SBOMs | Docker Docs"
[2]: https://docs.docker.com/guides/docker-scout/sbom/?utm_source=chatgpt.com "Software Bill of Materials"
[3]: https://cyclonedx.org/?utm_source=chatgpt.com "CycloneDX Bill of Materials Standard | CycloneDX"
[4]: https://spdx.dev/?utm_source=chatgpt.com "SPDX – Linux Foundation Projects Site"
[5]: https://docs.docker.com/reference/cli/docker/scout/sbom/ "docker scout sbom | Docker Docs"
[6]: https://trivy.dev/docs/latest/supply-chain/sbom/ "SBOM - Trivy"

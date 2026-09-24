# Lesson 8.3 — GitHub Actions Production Pipeline

# Test → Build → Scan → Push → SBOM → Provenance → Sign → Release Metadata → Promotion → Deployment Placeholder → Rollback Metadata

In Lesson 8.2, you learned GitHub Actions fundamentals.

Now we build a **production-grade GitHub Actions pipeline** for your `demo-node-api`.

This pipeline will use the artifact management standards from Module 7:

```text id="b0nccf"
version computation
Node.js tests
Docker build
GHCR push
SBOM/provenance attestations
Cosign signing
signature verification
release metadata
promotion record
deployment placeholder
rollback metadata
```

GitHub Actions workflows are YAML automation files made of jobs and steps, and GitHub recommends setting workflow token permissions to the minimum required for the job. Docker’s Build Push Action supports SBOM/provenance attestations, and Cosign is used to sign and verify software artifacts. ([GitHub Docs][1])

---

# 1. Production Pipeline Goal

A basic CI workflow asks:

```text id="ddhn0w"
Do tests pass?
```

A production pipeline asks:

```text id="pjmarl"
Can this exact artifact safely move toward production?
```

Our production pipeline should produce this final evidence:

```json id="vb4dyz"
{
  "service_name": "demo-node-api",
  "image": "ghcr.io/OWNER/demo-node-api:0.8.0-dev-a1b2c3d",
  "commit_sha": "a1b2c3d...",
  "test_status": "passed",
  "image_push_status": "passed",
  "signature_status": "verified",
  "sbom_attestation": "enabled",
  "provenance_attestation": "enabled",
  "promotion_target": "staging",
  "rollback_strategy": "previous known-good artifact"
}
```

Professional rule:

```text id="2qkd58"
A production pipeline should create a deployable artifact plus enough evidence to trust, promote, deploy, and rollback it.
```

---

# 2. Pipeline Architecture

```text id="p5j16o"
Git push / manual dispatch
  ↓
validate source
  ↓
install dependencies
  ↓
run tests
  ↓
compute immutable version tag
  ↓
build Docker image
  ↓
push to GHCR
  ↓
attach SBOM/provenance
  ↓
sign image with Cosign keyless
  ↓
verify signature
  ↓
create release metadata
  ↓
upload release evidence
  ↓
optional staging promotion job
  ↓
optional production approval job later
```

For now, we will keep deployment as a **placeholder** because real deployment depends on whether you deploy to:

```text id="n38tdw"
EC2 Docker Compose
Kubernetes
ECS
self-hosted runner
SSH server
GitOps repository
```

We will build real deployment and rollback pipelines in later Module 8 lessons.

---

# 3. Required GitHub Workflow Permissions

This pipeline needs:

```yaml id="zq82ys"
permissions:
  contents: read
  packages: write
  id-token: write
  attestations: write
```

Meaning:

```text id="hysrf2"
contents: read
  checkout source code

packages: write
  push image to GHCR

id-token: write
  use OIDC for keyless signing

attestations: write
  create artifact attestations when using GitHub attestation features
```

GitHub’s authentication docs recommend using the minimum required `GITHUB_TOKEN` permissions, and GitHub artifact/cosign-style identity workflows require OIDC permissions when using keyless identity-based signing. ([GitHub Docs][1])

---

# 4. Required Pipeline Tools

This workflow will use:

```text id="i8jxiz"
actions/checkout
actions/setup-node
docker/login-action
docker/setup-buildx-action
docker/build-push-action
sigstore/cosign-installer
actions/upload-artifact
```

Notes:

```text id="z44amo"
actions/upload-artifact@v4 should be used instead of older v1/v2/v3 versions.
docker/build-push-action can produce SBOM and provenance attestations.
cosign signs and verifies images.
```

The `actions/upload-artifact` repository warns that older artifact actions have deprecation timelines and points users toward v4, while Docker’s docs describe SBOM/provenance attestations with `docker/build-push-action`. ([GitHub][2])

---

# 5. Create Workflow Directory

Run:

```bash id="j7hxom"
cd ~/devops-masterclass

mkdir -p .github/workflows
mkdir -p 08-cicd-pipelines/github-actions/production
```

---

# 6. Create Production Workflow Example in Module 8

Create:

```bash id="g6bvlv"
cd ~/devops-masterclass/08-cicd-pipelines

nano github-actions/production/github-actions-production-pipeline.yml
```

Paste:

```yaml id="w0spwo"
name: GitHub Actions Production Pipeline

on:
  push:
    branches:
      - main
    tags:
      - "v*"

  pull_request:
    branches:
      - main

  workflow_dispatch:
    inputs:
      base_version:
        description: "Base semantic version"
        required: true
        default: "0.8.0"
        type: string
      channel:
        description: "Release channel"
        required: true
        default: "dev"
        type: choice
        options:
          - dev
          - rc
          - stable
      push_image:
        description: "Push image to GHCR"
        required: true
        default: true
        type: boolean

permissions:
  contents: read
  packages: write
  id-token: write
  attestations: write

env:
  APP_DIR: 05-application-runtime/demo-node-api
  IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/demo-node-api
  NODE_VERSION: "22"
  DEFAULT_BASE_VERSION: "0.8.0"

jobs:
  test:
    name: Test application
    runs-on: ubuntu-latest

    outputs:
      short_sha: ${{ steps.version.outputs.short_sha }}
      version: ${{ steps.version.outputs.version }}
      channel: ${{ steps.version.outputs.channel }}
      deploy_tag: ${{ steps.version.outputs.deploy_tag }}

    steps:
      - name: Checkout source
        uses: actions/checkout@v4

      - name: Compute version
        id: version
        shell: bash
        run: |
          SHORT_SHA="${GITHUB_SHA::7}"

          if [[ "${{ github.event_name }}" == "workflow_dispatch" ]]; then
            BASE_VERSION="${{ inputs.base_version }}"
            CHANNEL="${{ inputs.channel }}"
          elif [[ "${GITHUB_REF_TYPE}" == "tag" ]]; then
            BASE_VERSION="${GITHUB_REF_NAME#v}"
            CHANNEL="stable"
          elif [[ "${GITHUB_REF_NAME}" == "main" ]]; then
            BASE_VERSION="${DEFAULT_BASE_VERSION}"
            CHANNEL="dev"
          else
            BASE_VERSION="${DEFAULT_BASE_VERSION}"
            CHANNEL="branch"
          fi

          case "$CHANNEL" in
            stable)
              VERSION="$BASE_VERSION"
              ;;
            rc)
              VERSION="$BASE_VERSION-rc.1"
              ;;
            dev)
              VERSION="$BASE_VERSION-dev"
              ;;
            branch)
              SAFE_REF="$(echo "${GITHUB_REF_NAME}" | tr '/' '-' | tr -cd 'a-zA-Z0-9._-')"
              VERSION="$BASE_VERSION-$SAFE_REF"
              ;;
            *)
              echo "Unsupported channel: $CHANNEL" >&2
              exit 1
              ;;
          esac

          DEPLOY_TAG="$VERSION-$SHORT_SHA"

          echo "short_sha=$SHORT_SHA" >> "$GITHUB_OUTPUT"
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
          echo "channel=$CHANNEL" >> "$GITHUB_OUTPUT"
          echo "deploy_tag=$DEPLOY_TAG" >> "$GITHUB_OUTPUT"

          echo "Computed deploy tag: $DEPLOY_TAG"

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm
          cache-dependency-path: ${{ env.APP_DIR }}/package-lock.json

      - name: Install dependencies
        working-directory: ${{ env.APP_DIR }}
        run: npm ci

      - name: Run tests
        working-directory: ${{ env.APP_DIR }}
        run: npm test

      - name: Create test evidence
        run: |
          mkdir -p pipeline-evidence

          cat > pipeline-evidence/test-evidence.json <<EOF
          {
            "service_name": "demo-node-api",
            "repository": "${{ github.repository }}",
            "commit_sha": "${{ github.sha }}",
            "short_sha": "${{ steps.version.outputs.short_sha }}",
            "version": "${{ steps.version.outputs.version }}",
            "deploy_tag": "${{ steps.version.outputs.deploy_tag }}",
            "test_status": "passed",
            "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
          }
          EOF

          cat pipeline-evidence/test-evidence.json

      - name: Upload test evidence
        uses: actions/upload-artifact@v4
        with:
          name: test-evidence-${{ steps.version.outputs.deploy_tag }}
          path: pipeline-evidence/test-evidence.json

  build_publish:
    name: Build, publish, sign
    runs-on: ubuntu-latest
    needs: test

    if: ${{ github.event_name != 'pull_request' }}

    outputs:
      image_ref: ${{ steps.image.outputs.image_ref }}
      deploy_tag: ${{ needs.test.outputs.deploy_tag }}
      digest: ${{ steps.build.outputs.digest }}

    steps:
      - name: Checkout source
        uses: actions/checkout@v4

      - name: Decide image push
        id: push
        shell: bash
        run: |
          if [[ "${{ github.event_name }}" == "workflow_dispatch" ]]; then
            echo "enabled=${{ inputs.push_image }}" >> "$GITHUB_OUTPUT"
          else
            echo "enabled=true" >> "$GITHUB_OUTPUT"
          fi

      - name: Define image ref
        id: image
        run: |
          IMAGE_REF="${IMAGE_NAME}:${{ needs.test.outputs.deploy_tag }}"
          echo "image_ref=$IMAGE_REF" >> "$GITHUB_OUTPUT"
          echo "Image ref: $IMAGE_REF"

      - name: Login to GHCR
        if: ${{ steps.push.outputs.enabled == 'true' }}
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Install Cosign
        if: ${{ steps.push.outputs.enabled == 'true' }}
        uses: sigstore/cosign-installer@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push image with SBOM/provenance
        id: build
        uses: docker/build-push-action@v6
        with:
          context: ${{ env.APP_DIR }}
          file: ${{ env.APP_DIR }}/Dockerfile.industry
          target: runtime
          push: ${{ steps.push.outputs.enabled }}
          tags: |
            ${{ steps.image.outputs.image_ref }}
            ${{ env.IMAGE_NAME }}:${{ needs.test.outputs.short_sha }}
          labels: |
            org.opencontainers.image.source=https://github.com/${{ github.repository }}
            org.opencontainers.image.revision=${{ github.sha }}
            org.opencontainers.image.version=${{ needs.test.outputs.deploy_tag }}
          build-args: |
            APP_VERSION=${{ needs.test.outputs.deploy_tag }}
            COMMIT_SHA=${{ needs.test.outputs.short_sha }}
          sbom: true
          provenance: mode=max

      - name: Sign image with Cosign keyless
        if: ${{ steps.push.outputs.enabled == 'true' }}
        run: |
          cosign sign --yes "${{ steps.image.outputs.image_ref }}"

      - name: Verify image signature
        if: ${{ steps.push.outputs.enabled == 'true' }}
        run: |
          cosign verify \
            --certificate-identity-regexp "https://github.com/${{ github.repository }}/.github/workflows/.*" \
            --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
            "${{ steps.image.outputs.image_ref }}"

      - name: Create build evidence
        run: |
          mkdir -p pipeline-evidence

          cat > pipeline-evidence/build-evidence.json <<EOF
          {
            "service_name": "demo-node-api",
            "image_ref": "${{ steps.image.outputs.image_ref }}",
            "image_digest": "${{ steps.build.outputs.digest }}",
            "deploy_tag": "${{ needs.test.outputs.deploy_tag }}",
            "commit_sha": "${{ github.sha }}",
            "build_status": "passed",
            "push_enabled": "${{ steps.push.outputs.enabled }}",
            "sbom_attestation": "enabled",
            "provenance_attestation": "enabled",
            "signature_status": "verified_when_pushed",
            "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
          }
          EOF

          cat pipeline-evidence/build-evidence.json

      - name: Upload build evidence
        uses: actions/upload-artifact@v4
        with:
          name: build-evidence-${{ needs.test.outputs.deploy_tag }}
          path: pipeline-evidence/build-evidence.json

  release_metadata:
    name: Create release metadata
    runs-on: ubuntu-latest
    needs:
      - test
      - build_publish

    if: ${{ github.event_name != 'pull_request' }}

    steps:
      - name: Create release metadata
        run: |
          mkdir -p release-evidence

          cat > release-evidence/release-metadata.json <<EOF
          {
            "service_name": "demo-node-api",
            "repository": "${{ github.repository }}",
            "workflow": "${{ github.workflow }}",
            "run_id": "${{ github.run_id }}",
            "actor": "${{ github.actor }}",
            "commit_sha": "${{ github.sha }}",
            "short_sha": "${{ needs.test.outputs.short_sha }}",
            "version": "${{ needs.test.outputs.version }}",
            "channel": "${{ needs.test.outputs.channel }}",
            "deploy_tag": "${{ needs.test.outputs.deploy_tag }}",
            "image_ref": "${{ needs.build_publish.outputs.image_ref }}",
            "image_digest": "${{ needs.build_publish.outputs.digest }}",
            "test_status": "passed",
            "build_status": "passed",
            "sbom_attestation": "enabled",
            "provenance_attestation": "enabled",
            "signature_status": "verified_when_pushed",
            "rollback_strategy": "deploy previous known-good immutable image tag",
            "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
          }
          EOF

          cat release-evidence/release-metadata.json

      - name: Upload release metadata
        uses: actions/upload-artifact@v4
        with:
          name: release-metadata-${{ needs.test.outputs.deploy_tag }}
          path: release-evidence/release-metadata.json

  promote_staging:
    name: Promote to staging
    runs-on: ubuntu-latest
    needs:
      - test
      - build_publish
      - release_metadata

    if: ${{ github.event_name != 'pull_request' }}

    environment: staging

    steps:
      - name: Create staging promotion record
        run: |
          mkdir -p promotion-evidence

          cat > promotion-evidence/staging-promotion.json <<EOF
          {
            "service_name": "demo-node-api",
            "artifact": "${{ needs.build_publish.outputs.image_ref }}",
            "image_digest": "${{ needs.build_publish.outputs.digest }}",
            "from_environment": "dev",
            "to_environment": "staging",
            "promoted_by": "${{ github.actor }}",
            "test_status": "passed",
            "build_status": "passed",
            "signature_status": "verified_when_pushed",
            "status": "promoted",
            "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
          }
          EOF

          cat promotion-evidence/staging-promotion.json

      - name: Deployment placeholder
        run: |
          echo "Deploy placeholder:"
          echo "Image: ${{ needs.build_publish.outputs.image_ref }}"
          echo "Target: staging"
          echo "Later lessons will replace this with real deployment."

      - name: Upload promotion evidence
        uses: actions/upload-artifact@v4
        with:
          name: staging-promotion-${{ needs.test.outputs.deploy_tag }}
          path: promotion-evidence/staging-promotion.json
```

This is your first real production-grade GitHub Actions pipeline.

---

# 7. Copy Workflow into Real GitHub Actions Path

Run:

```bash id="z3n44o"
cd ~/devops-masterclass

cp 08-cicd-pipelines/github-actions/production/github-actions-production-pipeline.yml \
   .github/workflows/github-actions-production-pipeline.yml
```

Validate files:

```bash id="a035g5"
ls -la .github/workflows
```

---

# 8. Why Pull Requests Do Not Push Images

Notice this line:

```yaml id="u8uprl"
if: ${{ github.event_name != 'pull_request' }}
```

For pull requests, the pipeline should run tests but avoid publishing artifacts from untrusted or unmerged code.

Reason:

```text id="kyjbz9"
PR code may be untrusted.
Secrets may be unavailable.
Pushing registry images from PRs can pollute artifact stores.
Fork PRs have additional security restrictions.
```

Professional rule:

```text id="glciy5"
PR workflows validate. Main/tag workflows publish.
```

---

# 9. Why We Use Immutable Tags

The tag is:

```text id="3e4ou4"
VERSION-SHORT_SHA
```

Example:

```text id="m22noo"
0.8.0-dev-a1b2c3d
```

Why?

```text id="mvmj5e"
human-readable version
source commit traceability
rollback-friendly
registry-friendly
promotion-friendly
```

Avoid production deployment using:

```text id="18hnbf"
latest
prod
stable
current
```

Those are mutable pointers, not strong artifact identities.

---

# 10. Docker Build and Attestations

This step is important:

```yaml id="y335eu"
sbom: true
provenance: mode=max
```

It means Docker Buildx/build-push-action should create SBOM and provenance attestations for the image. Docker’s GitHub Actions attestation docs describe SBOM and provenance as metadata about image contents and how the image was built. ([Docker Documentation][3])

Professional note:

```text id="uqxl3c"
Attestations are strongest when the image is pushed to a registry.
```

---

# 11. Cosign Signing and Verification

This step signs:

```yaml id="n8zwnc"
cosign sign --yes "${{ steps.image.outputs.image_ref }}"
```

This step verifies:

```yaml id="3323o8"
cosign verify \
  --certificate-identity-regexp "https://github.com/${{ github.repository }}/.github/workflows/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "${{ steps.image.outputs.image_ref }}"
```

Cosign is Sigstore’s command-line utility for signing and verifying software artifacts. ([Sigstore][4])

Beginner meaning:

```text id="6ukb88"
The image is signed by the GitHub Actions workflow identity.
Then the same workflow verifies that signature.
```

Professional warning:

```text id="ps6dx1"
A broad regex is okay for learning, but production should narrow identity to the exact trusted workflow path and branch/tag policy.
```

Later, you should use stricter verification like:

```bash id="hfpfyy"
cosign verify \
  --certificate-identity "https://github.com/OWNER/REPO/.github/workflows/github-actions-production-pipeline.yml@refs/heads/main" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "$IMAGE_REF"
```

---

# 12. Release Metadata Job

This job creates:

```text id="buwbxq"
release-evidence/release-metadata.json
```

It stores:

```text id="zr65ml"
repository
workflow
run ID
actor
commit SHA
version
deploy tag
image ref
image digest
test status
build status
SBOM/provenance status
signature status
rollback strategy
```

This is your audit trail.

Professional rule:

```text id="o1srap"
Never rely only on CI logs. Store structured release metadata as an artifact.
```

GitHub Actions artifacts are used to store and share files generated during workflow runs. ([GitHub Docs][5])

---

# 13. Staging Promotion Job

This job uses:

```yaml id="d82dxv"
environment: staging
```

In GitHub, environments can be configured with protection rules and secrets. You can later add required reviewers for production.

For staging, you may allow automatic promotion.

For production, you should require approval.

Professional rule:

```text id="9o4pi9"
Staging can be automatic; production should have stronger gates.
```

---

# 14. Add Production Promotion Workflow

Create a separate workflow for production approval.

This is better than pushing production deployment into every CI run.

Create:

```bash id="djuxjh"
cd ~/devops-masterclass/08-cicd-pipelines

nano github-actions/production/github-actions-production-promotion.yml
```

Paste:

```yaml id="r17wi6"
name: Production Promotion

on:
  workflow_dispatch:
    inputs:
      image_ref:
        description: "Full immutable image reference"
        required: true
        type: string
      image_digest:
        description: "Image digest from release metadata"
        required: false
        type: string
      rollback_version:
        description: "Previous known-good image tag"
        required: true
        type: string

permissions:
  contents: read
  packages: read
  id-token: write

jobs:
  production_promotion:
    name: Approve production promotion
    runs-on: ubuntu-latest

    environment: production

    steps:
      - name: Validate image reference
        shell: bash
        run: |
          IMAGE_REF="${{ inputs.image_ref }}"

          case "$IMAGE_REF" in
            *:latest|*:prod|*:production|*:stable)
              echo "Forbidden mutable production tag: $IMAGE_REF" >&2
              exit 1
              ;;
          esac

          if [[ "$IMAGE_REF" != ghcr.io/* ]]; then
            echo "Expected GHCR image for this workflow. Got: $IMAGE_REF" >&2
            exit 1
          fi

          echo "Image reference accepted: $IMAGE_REF"

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Login to GHCR for private image verification
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Verify image signature
        run: |
          cosign verify \
            --certificate-identity-regexp "https://github.com/${{ github.repository }}/.github/workflows/.*" \
            --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
            "${{ inputs.image_ref }}"

      - name: Create production promotion record
        run: |
          mkdir -p production-promotion

          cat > production-promotion/production-promotion.json <<EOF
          {
            "artifact": "${{ inputs.image_ref }}",
            "image_digest": "${{ inputs.image_digest }}",
            "target_environment": "production",
            "approved_by": "${{ github.actor }}",
            "approval_gate": "GitHub Environment: production",
            "signature_status": "verified",
            "rollback_version": "${{ inputs.rollback_version }}",
            "status": "promoted",
            "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
          }
          EOF

          cat production-promotion/production-promotion.json

      - name: Deployment placeholder
        run: |
          echo "Production deployment placeholder"
          echo "Image: ${{ inputs.image_ref }}"
          echo "Rollback version: ${{ inputs.rollback_version }}"
          echo "Later lessons will replace this with SSH/Compose/Kubernetes/GitOps deployment."

      - name: Upload production promotion record
        uses: actions/upload-artifact@v4
        with:
          name: production-promotion-record
          path: production-promotion/
```

Copy:

```bash id="x358yd"
cd ~/devops-masterclass

cp 08-cicd-pipelines/github-actions/production/github-actions-production-promotion.yml \
   .github/workflows/github-actions-production-promotion.yml
```

---

# 15. Configure GitHub Environments

In GitHub UI:

```text id="jrrd9m"
Repository
  -> Settings
  -> Environments
  -> New environment
  -> staging
```

Then create:

```text id="fw51x9"
production
```

For `production`, configure:

```text id="h3z7sm"
Required reviewers
Deployment branches/tags rule if needed
Environment secrets if needed
```

Production should not be a normal automatic job.

Professional pattern:

```text id="jezygw"
CI publishes artifact.
Manual production promotion verifies and records artifact.
Deployment uses approved artifact.
```

---

# 16. Create Pipeline README

Create:

```bash id="h9v3k3"
cd ~/devops-masterclass/08-cicd-pipelines

nano github-actions/production/README.md
```

Paste:

````markdown id="1km02e"
# GitHub Actions Production Pipeline

## Workflows

### `github-actions-production-pipeline.yml`

Runs on:

- push to main
- tag push `v*`
- manual dispatch

Pipeline:

1. test application
2. compute immutable version tag
3. build Docker image
4. push image to GHCR
5. attach SBOM/provenance
6. sign image with Cosign keyless
7. verify signature
8. create release metadata
9. promote to staging

### `github-actions-production-promotion.yml`

Runs manually for production promotion.

Requires:

- immutable image reference
- rollback version
- GitHub environment approval
- signature verification

## Required GitHub Environments

- `staging`
- `production`

Production should have required reviewers.

## Required Permissions

```yaml
permissions:
  contents: read
  packages: write
  id-token: write
  attestations: write
````

## Production Rules

* PR workflows do not push images.
* Main/tag workflows can publish.
* Production promotion is manual.
* Images use immutable version-SHA tags.
* Signature verification happens before production promotion.
* Rollback version is required.

````id="v3v4ik"

---

# 17. Create Workflow Troubleshooting Notes

Create:

```bash id="fgnfbh"
nano github-actions/production/production-pipeline-troubleshooting.md
````

Paste:

````markdown id="x7f9l5"
# GitHub Actions Production Pipeline Troubleshooting

## GHCR push fails

Check:

```yaml
permissions:
  packages: write
````

Check package settings:

```text
GitHub -> Packages -> demo-node-api -> Package settings -> Actions access
```

## Cosign signing fails

Check:

```yaml
permissions:
  id-token: write
```

Check that image was pushed before signing.

## Cosign verification fails

Possible causes:

* image was not signed
* wrong image reference
* identity regex too strict
* image signed by different workflow
* private package auth failed

## Docker build fails

Check:

* `context`
* `file`
* Dockerfile target
* `.dockerignore`
* package lockfile
* build args

## npm ci fails

Check:

* package-lock exists
* package-lock matches package.json
* Node.js version
* working directory

## Artifact upload fails

Use:

```yaml
uses: actions/upload-artifact@v4
```

Check that the file path exists before upload.

## Production environment approval does not appear

Check:

* job uses `environment: production`
* environment exists in GitHub settings
* required reviewers configured
* workflow has reached that job

````id="mjo40q"

---

# 18. Validate Workflow Files Locally

Run:

```bash id="wrbtab"
cd ~/devops-masterclass

ls -la .github/workflows

git diff -- .github/workflows
````

If `yamllint` is installed:

```bash id="4nt6fj"
yamllint .github/workflows/github-actions-production-pipeline.yml
yamllint .github/workflows/github-actions-production-promotion.yml
```

If not installed:

```bash id="ct3bgm"
python3 -m pip install --user yamllint
```

Basic syntax check with Python YAML if available:

```bash id="isf9mk"
python3 - <<'PY'
from pathlib import Path
try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML not installed. Run: python3 -m pip install --user pyyaml")

for path in Path(".github/workflows").glob("*.yml"):
    with path.open() as f:
        yaml.safe_load(f)
    print(f"OK: {path}")
PY
```

---

# 19. Create Local Validation Script

Create:

```bash id="2sxde1"
cd ~/devops-masterclass/08-cicd-pipelines

nano github-actions/production/validate-production-workflows.sh
```

Paste:

```bash id="z6rtbi"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"

PIPELINE="$ROOT_DIR/.github/workflows/github-actions-production-pipeline.yml"
PROMOTION="$ROOT_DIR/.github/workflows/github-actions-production-promotion.yml"

echo "===== Validate GitHub Actions Production Workflows ====="

test -f "$PIPELINE"
test -f "$PROMOTION"

grep -q "packages: write" "$PIPELINE"
grep -q "id-token: write" "$PIPELINE"
grep -q "docker/build-push-action" "$PIPELINE"
grep -q "sigstore/cosign-installer" "$PIPELINE"
grep -q "cosign sign" "$PIPELINE"
grep -q "cosign verify" "$PIPELINE"
grep -q "upload-artifact@v4" "$PIPELINE"

grep -q "environment: production" "$PROMOTION"
grep -q "rollback_version" "$PROMOTION"
grep -q "cosign verify" "$PROMOTION"

echo "Production workflow validation passed."
```

Make executable:

```bash id="9s5agy"
chmod +x github-actions/production/validate-production-workflows.sh
```

Run:

```bash id="6n3azr"
./github-actions/production/validate-production-workflows.sh
```

---

# 20. Add Makefile Targets

Open:

```bash id="73w39v"
cd ~/devops-masterclass/08-cicd-pipelines

nano Makefile
```

Add:

```Makefile id="7id1z5"
.PHONY: copy-gha-production validate-gha-production

copy-gha-production:
	mkdir -p $(ROOT_DIR)/.github/workflows
	cp github-actions/production/github-actions-production-pipeline.yml $(ROOT_DIR)/.github/workflows/github-actions-production-pipeline.yml
	cp github-actions/production/github-actions-production-promotion.yml $(ROOT_DIR)/.github/workflows/github-actions-production-promotion.yml
	@echo "Production GitHub Actions workflows copied."

validate-gha-production:
	./github-actions/production/validate-production-workflows.sh
```

Run:

```bash id="685had"
make copy-gha-production
make validate-gha-production
```

---

# 21. Commit and Push

Run:

```bash id="8hi8s1"
cd ~/devops-masterclass

git status

git add .github/workflows/github-actions-production-pipeline.yml \
        .github/workflows/github-actions-production-promotion.yml \
        08-cicd-pipelines

git commit -m "feat: add GitHub Actions production pipeline"
git push
```

After push:

```text id="ul60nl"
GitHub repository
  -> Actions
  -> GitHub Actions Production Pipeline
```

Expected on `main` push:

```text id="ojyfno"
test job runs
build_publish job pushes GHCR image
Cosign signs image
Cosign verifies image
release metadata artifact uploads
staging promotion artifact uploads
```

---

# 22. Manual Run

In GitHub UI:

```text id="m0z0wy"
Actions
  -> GitHub Actions Production Pipeline
  -> Run workflow
```

Inputs:

```text id="q47mkd"
base_version: 0.8.0
channel: dev
push_image: true
```

Expected image:

```text id="xjk3p7"
ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.8.0-dev-<sha>
```

Download artifacts:

```text id="qi4o8j"
test-evidence-...
build-evidence-...
release-metadata-...
staging-promotion-...
```

---

# 23. Manual Production Promotion

After the production pipeline creates an image, run:

```text id="7o1qpl"
Actions
  -> Production Promotion
  -> Run workflow
```

Inputs:

```text id="x76ddf"
image_ref:
  ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:0.8.0-dev-a1b2c3d

image_digest:
  sha256:... from release metadata

rollback_version:
  previous known-good version, for example 0.7.0-a1b2c3d
```

GitHub should pause at the `production` environment if required reviewers are configured.

---

# 24. Important Production Improvement

Current verification uses:

```bash id="3ayg2l"
--certificate-identity-regexp "https://github.com/${{ github.repository }}/.github/workflows/.*"
```

This accepts any workflow in the repository.

For stronger production, replace it with exact workflow identity:

```bash id="7clwvi"
--certificate-identity "https://github.com/${{ github.repository }}/.github/workflows/github-actions-production-pipeline.yml@refs/heads/main"
```

Use broad regex while learning.

Use strict identity for production.

Professional rule:

```text id="kgmj2h"
Production verification should trust exact workflow identity, not any workflow in the repo.
```

---

# 25. Pipeline Security Review

Your workflow follows these strong rules:

```text id="i4sd8y"
explicit permissions
no secrets printed
GITHUB_TOKEN used for GHCR
OIDC enabled for keyless signing
PR does not push image
immutable version-SHA tag
SBOM/provenance enabled
signature verification
release metadata artifact
production promotion is manual
rollback version required
```

Remaining improvements for later:

```text id="5edq4j"
add container vulnerability scan job
add secret scanning
add exact signer identity
add real deployment job
add rollback workflow
add environment-specific secrets
add branch protection
add workflow concurrency
add notifications
```

---

# 26. Optional: Add Concurrency

Concurrency prevents overlapping deployments.

Add near top of workflow:

```yaml id="ffbbqg"
concurrency:
  group: production-pipeline-${{ github.ref }}
  cancel-in-progress: false
```

Meaning:

```text id="nhyxvi"
Only one pipeline per branch/ref group runs at a time.
Do not cancel active production-capable pipelines automatically.
```

For PR-only CI, `cancel-in-progress: true` is often okay.

For deploy pipelines, be careful.

---

# 27. Optional: Add Timeout

Add to jobs:

```yaml id="hww12g"
timeout-minutes: 30
```

Example:

```yaml id="tjc2wv"
jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 20
```

Why?

```text id="tqe4eo"
prevents stuck jobs from running forever
controls cost
improves operational reliability
```

---

# 28. Optional: Add Summary

GitHub supports writing Markdown to `$GITHUB_STEP_SUMMARY`.

Add at end of `release_metadata` job:

```yaml id="b2iedx"
      - name: Write job summary
        run: |
          {
            echo "## Release Metadata"
            echo ""
            echo "- Image: \`${{ needs.build_publish.outputs.image_ref }}\`"
            echo "- Digest: \`${{ needs.build_publish.outputs.digest }}\`"
            echo "- Commit: \`${{ github.sha }}\`"
            echo "- Deploy tag: \`${{ needs.test.outputs.deploy_tag }}\`"
          } >> "$GITHUB_STEP_SUMMARY"
```

This gives readable workflow output.

---

# 29. Interview Explanation

## What does a production GitHub Actions pipeline include?

Strong answer:

```text id="ykc0x4"
A production GitHub Actions pipeline includes source checkout, runtime setup, deterministic dependency installation, tests, Docker image build, security scanning, registry push, immutable tagging, SBOM/provenance generation, image signing, signature verification, release metadata, promotion records, environment approvals, deployment verification, and rollback metadata.
```

## Why should PR workflows not push images?

Strong answer:

```text id="fpwb6l"
Pull request workflows validate code but should not publish production artifacts because PR code may be untrusted, secrets may be restricted, and pushing artifacts from every PR can pollute the registry. Main or tag workflows should publish artifacts after merge.
```

## Why use GitHub Environments?

Strong answer:

```text id="wt124n"
GitHub Environments let us apply deployment protection rules such as required reviewers and environment-specific secrets. They are useful for staging and production promotion gates.
```

## Why use Cosign in CI?

Strong answer:

```text id="xzmb3a"
Cosign lets the pipeline sign the pushed image and verify that the artifact was signed by a trusted GitHub Actions identity. This improves supply-chain trust before promotion or deployment.
```

## What is the purpose of release metadata?

Strong answer:

```text id="8n06sx"
Release metadata provides structured traceability. It records the image reference, digest, commit SHA, workflow run, test status, build status, SBOM/provenance status, signature status, and rollback strategy.
```

## Why use `needs`?

Strong answer:

```text id="5pgqgh"
`needs` creates job dependencies. For example, the build job should wait for the test job, and the promotion job should wait for build and release metadata. This models the real pipeline flow.
```

---

# 30. Today’s Core Rules

```text id="3dqwif"
Production pipelines create trusted artifacts.
PR workflows validate but should not publish production artifacts.
Main/tag workflows can publish.
Use immutable version-SHA tags.
Use explicit minimum permissions.
Use GHCR with packages: write.
Use OIDC for keyless signing.
Use SBOM/provenance attestations.
Sign and verify images.
Upload release evidence as artifacts.
Use GitHub Environments for promotion gates.
Production promotion should be separate and manual.
Rollback version must be known.
Do not deploy latest.
```

---

# Next Lesson

# Lesson 8.4 — Jenkins Fundamentals

We will go deep into:

```text id="4y2cd6"
Jenkins controller and agents
Jenkinsfile syntax
declarative pipeline
scripted pipeline overview
stages and steps
environment variables
parameters
credentials
tools
workspace
artifacts
post actions
input approvals
common Jenkins errors
basic Node.js pipeline
how Jenkins maps to GitHub Actions
```

[1]: https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching?utm_source=chatgpt.com "Dependency caching reference"
[2]: https://github.com/actions/upload-artifact?utm_source=chatgpt.com "actions/upload-artifact"
[3]: https://docs.docker.com/build/ci/github-actions/attestations/?utm_source=chatgpt.com "Add SBOM and provenance attestations with GitHub Actions"
[4]: https://docs.sigstore.dev/quickstart/quickstart-cosign/?utm_source=chatgpt.com "Sigstore Quickstart with Cosign"
[5]: https://docs.github.com/en/actions/concepts/workflows-and-actions/dependency-caching?utm_source=chatgpt.com "Dependency caching"

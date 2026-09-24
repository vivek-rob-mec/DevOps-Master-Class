# Lesson 7.9 — Image Signing with Cosign and Sigstore Concepts

# Key-Based Signing, Keyless Signing, Fulcio, Rekor, Verification, GitHub Actions, and Policy-Based Deployment

In Lesson 7.8, we learned:

```text id="gk9eh4"
SBOM = what is inside the artifact
Provenance = how the artifact was built
```

Now we learn:

```text id="27tqr2"
Signature = proof that a trusted identity signed the artifact
```

Image signing answers:

```text id="54cdp7"
Can I trust this image?
Was it signed by our CI system?
Was it signed by the expected GitHub repository?
Was it tampered with after build?
Should production be allowed to deploy it?
```

Sigstore is an open-source project for improving software supply-chain security, and its tooling can sign and verify artifacts such as container images, release files, binaries, and SBOMs. Sigstore also records signing events in a tamper-resistant public log for auditability. ([Sigstore][1])

---

# 1. Beginner Level — Why Image Signing Matters

Without signing, your production deployment may only know:

```text id="yq8xr1"
image tag = demo-node-api:0.7.0-a1b2c3d
```

But tags can be pushed by the wrong person if credentials are compromised.

A signature helps answer:

```text id="ojl9wq"
Was this image signed by a trusted identity?
Was this image produced by our expected CI/CD process?
Can we verify the image before deployment?
```

Simple definition:

```text id="4c3mwp"
Image signing creates a cryptographic proof that a trusted signer approved or produced a container image.
```

Core idea:

```text id="l5j6fk"
Do not only trust the image name.
Verify the image signature.
```

---

# 2. Beginner Mental Model

Imagine a container image is a document.

```text id="4bvn9l"
Docker image:
  document

SBOM:
  ingredients list

Provenance:
  build history

Signature:
  trusted stamp
```

A deployment system should ask:

```text id="tx2tst"
Is the image from the right registry?
Is the tag/version allowed?
Does the digest match?
Does SBOM exist?
Does provenance exist?
Is the image signed by a trusted identity?
```

Professional rule:

```text id="t5zyda"
A production artifact should be identifiable, traceable, and verifiable.
```

---

# 3. What Is Cosign?

Cosign is the Sigstore tool commonly used to sign and verify container images and other software artifacts. The official Cosign quick start describes signing a container image with default identity-based “keyless signing” and verifying the image afterward. ([GitHub][2])

Cosign can sign:

```text id="5awnai"
container images
files/blobs
SBOMs
attestations
checksums
```

Common commands:

```bash id="h7x4lq"
cosign sign <image>
cosign verify <image>
```

Cosign supports both:

```text id="c829f2"
key-based signing
keyless signing
```

---

# 4. What Is Sigstore?

Sigstore is the wider ecosystem.

Important components:

```text id="jjyae4"
Cosign:
  signing and verification tool

Fulcio:
  certificate authority for keyless signing

Rekor:
  transparency log

OIDC identity provider:
  GitHub, Google, Microsoft, etc.

Policy engine:
  decides whether artifact should be accepted
```

Sigstore’s documentation explains that keyless signing uses identities rather than long-lived keys; Fulcio issues short-lived certificates binding an ephemeral key to an OIDC identity, and signing events are logged in Rekor, the transparency log. ([Sigstore][3])

Beginner summary:

```text id="7evsq4"
Cosign signs.
Fulcio issues short-lived certificates.
Rekor records signing events.
OIDC proves identity.
Verification checks trust.
```

---

# 5. Key-Based Signing vs Keyless Signing

## Key-based signing

You generate and manage a private key.

```text id="9g2z86"
private key signs image
public key verifies image
```

Pros:

```text id="cjulb8"
simple mental model
works offline/private environments
familiar cryptographic pattern
```

Cons:

```text id="g8y66l"
private key must be protected
key rotation is your responsibility
key leakage is serious
CI secret management required
```

---

## Keyless signing

You do not manage long-lived signing keys.

```text id="xz87oi"
CI authenticates with OIDC
Fulcio issues short-lived cert
Cosign signs image
Rekor records event
verifier checks identity + signature
```

Pros:

```text id="yfkfvw"
no long-lived private signing key
great for GitHub Actions
identity-based verification
audit trail through transparency log
```

Cons:

```text id="i2jntg"
requires understanding OIDC identity
requires online verification infrastructure
policy must check identity correctly
```

Professional recommendation:

```text id="8w0oo4"
Use keyless signing for GitHub Actions and modern CI/CD where possible.
Use key-based signing when your environment requires offline/private signing.
```

---

# 6. Install Cosign

Official Sigstore documentation says you can install Cosign with Go 1.20+ using:

```bash id="bqzkvh"
go install github.com/sigstore/cosign/v3/cmd/cosign@latest
```

The binary is placed in `$GOPATH/bin/cosign` or `$GOBIN/cosign` if set. ([Sigstore][4])

Check:

```bash id="hnnxi4"
cosign version
```

For GitHub Actions, Sigstore’s quickstart notes that you can use the official GitHub Actions Cosign installer. ([Sigstore][5])

Example action:

```yaml id="8cqbew"
- name: Install Cosign
  uses: sigstore/cosign-installer@v3
```

---

# 7. Hands-On Directory Setup

Run:

```bash id="hxlp5w"
cd ~/devops-masterclass/07-artifact-management-registries

mkdir -p signing/{keys,policies,records,reports,examples}
```

Check:

```bash id="zpr669"
tree -L 2 signing
```

Expected:

```text id="nd3wco"
signing
├── examples
├── keys
├── policies
├── records
└── reports
```

Add key files to `.gitignore`:

```bash id="di0ew8"
cat >> .gitignore <<'EOF'

# Signing keys and sensitive signing material
signing/keys/*
!signing/keys/.gitkeep
*.key
*.pub
*.pem
EOF

touch signing/keys/.gitkeep
```

Important:

```text id="v0qd15"
Never commit private signing keys.
```

---

# 8. Build or Reuse Image

Compute deploy tag:

```bash id="6gc8s6"
cd ~/devops-masterclass/07-artifact-management-registries

VERSION_JSON="$(BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"

echo "$DEPLOY_TAG"
```

Build image:

```bash id="qy32o5"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
```

For signing, it is best to sign an image pushed to a registry.

Example GHCR image:

```text id="rmq48a"
ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:$DEPLOY_TAG
```

Push if needed:

```bash id="lz9xz9"
cd ~/devops-masterclass/07-artifact-management-registries

GITHUB_USERNAME=YOUR_GITHUB_USERNAME \
GHCR_TOKEN=YOUR_TOKEN \
IMAGE_TAG="$DEPLOY_TAG" \
./scripts/ghcr-push.sh
```

---

# 9. Key-Based Signing — Generate Key Pair

For learning key-based signing:

```bash id="9u6q0m"
cd ~/devops-masterclass/07-artifact-management-registries

cosign generate-key-pair \
  --output-key-prefix signing/keys/demo-node-api-cosign
```

This creates:

```text id="ep3xbd"
signing/keys/demo-node-api-cosign.key
signing/keys/demo-node-api-cosign.pub
```

You will be asked for a password.

Important:

```text id="fbufjd"
The .key file is sensitive.
The .pub file can be shared for verification.
```

Never commit:

```text id="doeoyo"
*.key
```

---

# 10. Key-Based Signing — Sign Image

Sign GHCR image:

```bash id="ctll53"
IMAGE_REF="ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:$DEPLOY_TAG"

cosign sign \
  --key signing/keys/demo-node-api-cosign.key \
  "$IMAGE_REF"
```

Cosign may ask for confirmation to upload the signature to the registry.

Why registry?

```text id="5h83os"
Cosign stores signatures alongside the image in the registry.
```

Professional rule:

```text id="yvr5kc"
Sign the registry image reference, not just a local image tag.
```

---

# 11. Key-Based Verification

Verify:

```bash id="7f0yjm"
cosign verify \
  --key signing/keys/demo-node-api-cosign.pub \
  "$IMAGE_REF"
```

Cosign’s verification documentation shows the general command format:

```bash id="mnsiln"
cosign verify [--key <key path>|<key url>|<kms uri>] <image uri>
```

The verifier checks the signature for the supplied image reference. ([Sigstore][6])

Expected output contains signature information and payload.

Professional rule:

```text id="qjx2m7"
Verification should happen before deployment, not after production is already running.
```

---

# 12. Keyless Signing — Local Interactive

Cosign keyless signing can use OIDC authentication.

The official signing docs state that keyless container signing can be done with:

```bash id="nq4h0a"
cosign sign $IMAGE
```

and that Cosign uses ephemeral keys through OIDC-supported authentication such as Google, GitHub, or Microsoft. ([Sigstore][7])

Example:

```bash id="zbrt3m"
IMAGE_REF="ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:$DEPLOY_TAG"

cosign sign "$IMAGE_REF"
```

This may open a browser for identity authentication.

For local learning, that is okay.

For CI/CD, GitHub Actions uses OIDC automatically.

---

# 13. Keyless Verification

For keyless verification, you should verify identity.

Example pattern:

```bash id="7n2qt7"
cosign verify \
  --certificate-identity "https://github.com/YOUR_GITHUB_USERNAME/devops-masterclass/.github/workflows/ghcr-build-push.yml@refs/heads/main" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "$IMAGE_REF"
```

The exact certificate identity depends on how the image was signed, which workflow signed it, and whether it used branch, tag, or environment context. Cosign’s verification docs cover keyless verification using OpenID identities and `cosign verify`. ([Sigstore][6])

Professional rule:

```text id="nkp27b"
Do not only check “signature exists.”
Check that it was signed by the expected identity.
```

---

# 14. GitHub Actions Keyless Signing Workflow

Create example:

```bash id="1t1sjq"
cd ~/devops-masterclass/07-artifact-management-registries

nano examples/github-actions-cosign-keyless.yml
```

Paste:

```yaml id="s671t4"
name: GHCR Build Sign Verify

on:
  workflow_dispatch:
  push:
    branches:
      - main
    tags:
      - "v*"

permissions:
  contents: read
  packages: write
  id-token: write

env:
  APP_DIR: 05-application-runtime/demo-node-api
  IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/demo-node-api
  BASE_VERSION: "0.7.0"

jobs:
  build-sign-verify:
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
          echo "deploy_tag=$DEPLOY_TAG" >> "$GITHUB_OUTPUT"

      - name: Login to GHCR
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push image
        id: build
        uses: docker/build-push-action@v6
        with:
          context: ${{ env.APP_DIR }}
          file: ${{ env.APP_DIR }}/Dockerfile.industry
          target: runtime
          push: true
          tags: |
            ${{ env.IMAGE_NAME }}:${{ steps.version.outputs.deploy_tag }}
          labels: |
            org.opencontainers.image.source=https://github.com/${{ github.repository }}
            org.opencontainers.image.revision=${{ github.sha }}
            org.opencontainers.image.version=${{ steps.version.outputs.deploy_tag }}
          build-args: |
            APP_VERSION=${{ steps.version.outputs.deploy_tag }}
            COMMIT_SHA=${{ steps.version.outputs.short_sha }}
          sbom: true
          provenance: mode=max

      - name: Sign image with Cosign keyless
        env:
          IMAGE_REF: ${{ env.IMAGE_NAME }}:${{ steps.version.outputs.deploy_tag }}
        run: |
          cosign sign --yes "$IMAGE_REF"

      - name: Verify image signature
        env:
          IMAGE_REF: ${{ env.IMAGE_NAME }}:${{ steps.version.outputs.deploy_tag }}
        run: |
          cosign verify \
            --certificate-identity-regexp "https://github.com/${{ github.repository }}/.github/workflows/.*" \
            --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
            "$IMAGE_REF"
```

Why `id-token: write`?

```text id="m3ghsk"
GitHub Actions needs OIDC token permission for keyless signing.
```

Why verify after signing?

```text id="eflrkk"
It catches signing or identity mistakes immediately in CI.
```

---

# 15. ECR Keyless Signing Workflow

Cosign can sign images in ECR too, because signatures are stored as registry artifacts.

Example image:

```text id="whwt0c"
123456789012.dkr.ecr.ap-south-1.amazonaws.com/demo-node-api:0.7.0-a1b2c3d
```

GitHub Actions flow:

```text id="23gidp"
assume AWS role with OIDC
login to ECR
build image
push image
install cosign
cosign sign image
cosign verify image
```

Example signing step after ECR push:

```yaml id="6qf3jz"
      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Sign ECR image
        env:
          IMAGE_REF: ${{ steps.ecr.outputs.image_ref }}
        run: |
          cosign sign --yes "$IMAGE_REF"
```

Verification:

```yaml id="vkz8fj"
      - name: Verify ECR image signature
        env:
          IMAGE_REF: ${{ steps.ecr.outputs.image_ref }}
        run: |
          cosign verify \
            --certificate-identity-regexp "https://github.com/${{ github.repository }}/.github/workflows/.*" \
            --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
            "$IMAGE_REF"
```

Important:

```text id="hhv8jv"
The registry credential must allow writing signature artifacts as well as the image.
```

---

# 16. Create Signing Policy

Create:

```bash id="cnuqnj"
nano signing/policies/demo-node-api-signing-policy.json
```

Paste:

```json id="qkncfa"
{
  "service_name": "demo-node-api",
  "allowed_registries": [
    "ghcr.io",
    "dkr.ecr.ap-south-1.amazonaws.com"
  ],
  "allowed_oidc_issuer": "https://token.actions.githubusercontent.com",
  "allowed_certificate_identity_patterns": [
    "https://github.com/YOUR_GITHUB_USERNAME/devops-masterclass/.github/workflows/ghcr-build-push.yml@refs/heads/main",
    "https://github.com/YOUR_GITHUB_USERNAME/devops-masterclass/.github/workflows/ecr-build-push.yml@refs/heads/main"
  ],
  "requirements": {
    "signature_required": true,
    "keyless_preferred": true,
    "latest_forbidden": true,
    "digest_recording_required": true
  }
}
```

Replace:

```text id="ge9gal"
YOUR_GITHUB_USERNAME
```

with your real username.

This policy is documentation now. Later, policy engines can enforce it.

---

# 17. Create Key-Based Signing Script

Create:

```bash id="q2t3q5"
nano scripts/sign-image-key.sh
```

Paste:

```bash id="iwwzmj"
#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF="${IMAGE_REF:-}"
KEY_PATH="${KEY_PATH:-signing/keys/demo-node-api-cosign.key}"

if [ -z "$IMAGE_REF" ]; then
  echo "ERROR: IMAGE_REF is required" >&2
  echo "Example: IMAGE_REF=ghcr.io/user/demo-node-api:tag $0" >&2
  exit 1
fi

if [ ! -f "$KEY_PATH" ]; then
  echo "ERROR: key file not found: $KEY_PATH" >&2
  exit 1
fi

echo "===== Sign Image with Key ====="
echo "Image: $IMAGE_REF"
echo "Key: $KEY_PATH"

cosign sign \
  --key "$KEY_PATH" \
  "$IMAGE_REF"

mkdir -p signing/records

cat > "signing/records/$(echo "$IMAGE_REF" | tr '/:@' '____').key-sign-record.json" <<EOF
{
  "image_ref": "$IMAGE_REF",
  "signing_mode": "key",
  "key_path": "$KEY_PATH",
  "signed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

echo "Signing completed."
```

Make executable:

```bash id="l8flra"
chmod +x scripts/sign-image-key.sh
```

Run:

```bash id="2szw1v"
IMAGE_REF="ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:$DEPLOY_TAG" \
./scripts/sign-image-key.sh
```

---

# 18. Create Key-Based Verification Script

Create:

```bash id="qms268"
nano scripts/verify-image-key.sh
```

Paste:

```bash id="r3mpkf"
#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF="${IMAGE_REF:-}"
PUBLIC_KEY_PATH="${PUBLIC_KEY_PATH:-signing/keys/demo-node-api-cosign.pub}"

if [ -z "$IMAGE_REF" ]; then
  echo "ERROR: IMAGE_REF is required" >&2
  echo "Example: IMAGE_REF=ghcr.io/user/demo-node-api:tag $0" >&2
  exit 1
fi

if [ ! -f "$PUBLIC_KEY_PATH" ]; then
  echo "ERROR: public key file not found: $PUBLIC_KEY_PATH" >&2
  exit 1
fi

echo "===== Verify Image with Public Key ====="
echo "Image: $IMAGE_REF"
echo "Public key: $PUBLIC_KEY_PATH"

cosign verify \
  --key "$PUBLIC_KEY_PATH" \
  "$IMAGE_REF" \
  | tee signing/reports/verify-key-$(date +%Y%m%d_%H%M%S).json

echo "Verification completed."
```

Make executable:

```bash id="ibd7ft"
chmod +x scripts/verify-image-key.sh
```

Run:

```bash id="8ojg8g"
IMAGE_REF="ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:$DEPLOY_TAG" \
./scripts/verify-image-key.sh
```

---

# 19. Create Keyless Verification Script

Create:

```bash id="3u7y9j"
nano scripts/verify-image-keyless.sh
```

Paste:

```bash id="09frsi"
#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF="${IMAGE_REF:-}"
CERT_IDENTITY="${CERT_IDENTITY:-}"
CERT_IDENTITY_REGEXP="${CERT_IDENTITY_REGEXP:-}"
OIDC_ISSUER="${OIDC_ISSUER:-https://token.actions.githubusercontent.com}"

if [ -z "$IMAGE_REF" ]; then
  echo "ERROR: IMAGE_REF is required" >&2
  exit 1
fi

if [ -z "$CERT_IDENTITY" ] && [ -z "$CERT_IDENTITY_REGEXP" ]; then
  echo "ERROR: CERT_IDENTITY or CERT_IDENTITY_REGEXP is required" >&2
  echo "Example:" >&2
  echo "CERT_IDENTITY_REGEXP='https://github.com/USER/REPO/.github/workflows/.*' IMAGE_REF=... $0" >&2
  exit 1
fi

mkdir -p signing/reports

echo "===== Verify Image Keyless ====="
echo "Image: $IMAGE_REF"
echo "OIDC issuer: $OIDC_ISSUER"

if [ -n "$CERT_IDENTITY" ]; then
  cosign verify \
    --certificate-identity "$CERT_IDENTITY" \
    --certificate-oidc-issuer "$OIDC_ISSUER" \
    "$IMAGE_REF" \
    | tee "signing/reports/verify-keyless-$(date +%Y%m%d_%H%M%S).json"
else
  cosign verify \
    --certificate-identity-regexp "$CERT_IDENTITY_REGEXP" \
    --certificate-oidc-issuer "$OIDC_ISSUER" \
    "$IMAGE_REF" \
    | tee "signing/reports/verify-keyless-$(date +%Y%m%d_%H%M%S).json"
fi

echo "Keyless verification completed."
```

Make executable:

```bash id="nz0218"
chmod +x scripts/verify-image-keyless.sh
```

Run:

```bash id="k6k9a1"
IMAGE_REF="ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:$DEPLOY_TAG" \
CERT_IDENTITY_REGEXP="https://github.com/YOUR_GITHUB_USERNAME/devops-masterclass/.github/workflows/.*" \
./scripts/verify-image-keyless.sh
```

---

# 20. Add Signature Verification Before Compose Deployment

This is a professional deployment gate.

Create wrapper:

```bash id="1q7t06"
cd ~/devops-masterclass/07-artifact-management-registries

nano scripts/verify-then-deploy-compose.sh
```

Paste:

```bash id="4jxpxv"
#!/usr/bin/env bash
set -euo pipefail

APP_IMAGE="${APP_IMAGE:-}"
APP_VERSION="${APP_VERSION:-}"
COMPOSE_DIR="${COMPOSE_DIR:-../06-docker-containers/compose-demo}"
COMPOSE_FILES="${COMPOSE_FILES:-compose.yaml compose.prod.yaml}"

VERIFY_MODE="${VERIFY_MODE:-keyless}" # keyless or key
PUBLIC_KEY_PATH="${PUBLIC_KEY_PATH:-signing/keys/demo-node-api-cosign.pub}"
CERT_IDENTITY="${CERT_IDENTITY:-}"
CERT_IDENTITY_REGEXP="${CERT_IDENTITY_REGEXP:-}"
OIDC_ISSUER="${OIDC_ISSUER:-https://token.actions.githubusercontent.com}"

if [ -z "$APP_IMAGE" ] || [ -z "$APP_VERSION" ]; then
  echo "ERROR: APP_IMAGE and APP_VERSION are required" >&2
  exit 1
fi

IMAGE_REF="$APP_IMAGE:$APP_VERSION"

echo "===== Verify Then Deploy ====="
echo "Image: $IMAGE_REF"
echo "Verify mode: $VERIFY_MODE"

case "$VERIFY_MODE" in
  key)
    IMAGE_REF="$IMAGE_REF" PUBLIC_KEY_PATH="$PUBLIC_KEY_PATH" ./scripts/verify-image-key.sh
    ;;
  keyless)
    IMAGE_REF="$IMAGE_REF" \
    CERT_IDENTITY="$CERT_IDENTITY" \
    CERT_IDENTITY_REGEXP="$CERT_IDENTITY_REGEXP" \
    OIDC_ISSUER="$OIDC_ISSUER" \
    ./scripts/verify-image-keyless.sh
    ;;
  *)
    echo "ERROR: unsupported VERIFY_MODE=$VERIFY_MODE" >&2
    exit 1
    ;;
esac

echo
echo "Signature verification passed. Deploying..."

cd "$COMPOSE_DIR"

APP_IMAGE="$APP_IMAGE" \
APP_VERSION="$APP_VERSION" \
COMPOSE_FILES="$COMPOSE_FILES" \
./scripts/deploy-compose.sh
```

Make executable:

```bash id="6iazg3"
chmod +x scripts/verify-then-deploy-compose.sh
```

Usage key-based:

```bash id="sidm0x"
APP_IMAGE=ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api \
APP_VERSION="$DEPLOY_TAG" \
VERIFY_MODE=key \
PUBLIC_KEY_PATH=signing/keys/demo-node-api-cosign.pub \
./scripts/verify-then-deploy-compose.sh
```

Usage keyless:

```bash id="tmwh5o"
APP_IMAGE=ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api \
APP_VERSION="$DEPLOY_TAG" \
VERIFY_MODE=keyless \
CERT_IDENTITY_REGEXP="https://github.com/YOUR_GITHUB_USERNAME/devops-masterclass/.github/workflows/.*" \
./scripts/verify-then-deploy-compose.sh
```

This is a serious production pattern:

```text id="dj8t9b"
verify signature first
deploy only if trusted
```

---

# 21. Signing Records and Release Metadata

Create signing record manually:

```bash id="1oihw3"
nano scripts/create-signing-record.sh
```

Paste:

```bash id="ht05zk"
#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF="${IMAGE_REF:-}"
SIGNING_MODE="${SIGNING_MODE:-keyless}"
SIGNER_IDENTITY="${SIGNER_IDENTITY:-unknown}"
OUTPUT_DIR="${OUTPUT_DIR:-signing/records}"

if [ -z "$IMAGE_REF" ]; then
  echo "ERROR: IMAGE_REF is required" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

SAFE_IMAGE="$(echo "$IMAGE_REF" | tr '/:@' '____')"
OUTPUT_FILE="$OUTPUT_DIR/$SAFE_IMAGE.signing-record.json"

cat > "$OUTPUT_FILE" <<EOF
{
  "image_ref": "$IMAGE_REF",
  "signing_mode": "$SIGNING_MODE",
  "signer_identity": "$SIGNER_IDENTITY",
  "recorded_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

echo "Signing record created:"
cat "$OUTPUT_FILE" | jq .
```

Make executable:

```bash id="zlvb8n"
chmod +x scripts/create-signing-record.sh
```

Run:

```bash id="2oxcda"
IMAGE_REF="ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:$DEPLOY_TAG" \
SIGNING_MODE=keyless \
SIGNER_IDENTITY="https://github.com/YOUR_GITHUB_USERNAME/devops-masterclass/.github/workflows/ghcr-build-push.yml@refs/heads/main" \
./scripts/create-signing-record.sh
```

Add to release metadata:

```bash id="qkmi4m"
SIGNING_RECORD="$(ls -t signing/records/*.signing-record.json | head -n 1)"

BASE_VERSION=0.7.0 \
CHANNEL=stable \
IMAGE_NAME=demo-node-api \
REGISTRY_IMAGE="ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api" \
TEST_STATUS=passed \
SCAN_STATUS=passed \
SBOM_PATH="$LATEST_SBOM" \
PROVENANCE_PATH="$LATEST_PROV" \
SIGNING_RECORD_PATH="$SIGNING_RECORD" \
./scripts/create-release-metadata.sh
```

Add variable to `create-release-metadata.sh` if needed:

```bash id="jhgdaf"
SIGNING_RECORD_PATH="${SIGNING_RECORD_PATH:-}"
```

Add JSON field:

```json id="vfd2ne"
  "signing_record_path": "$SIGNING_RECORD_PATH",
```

---

# 22. Production Policy-Based Deployment

Professional deployment gate:

```text id="asr1wj"
Before deploy:
  image tag is immutable
  image digest recorded
  SBOM exists
  vulnerability scan passed
  provenance exists
  signature verifies
  signer identity matches policy
  source repo/workflow matches policy
```

Bad deployment:

```text id="9tzdko"
docker compose up -d
```

Better deployment:

```text id="9a5ci2"
resolve exact image
verify signature
verify provenance
verify scan result
deploy
health check
record deployment
```

Expert principle:

```text id="kpl3v5"
Production deployment should be an admission decision, not just a shell command.
```

In Kubernetes later, this becomes:

```text id="tq55lt"
admission controller
Kyverno
OPA Gatekeeper
Cosigned policy-controller
Sigstore policy-controller
```

For now, your shell script is the learning version.

---

# 23. Key Management Best Practices

If using key-based signing:

```text id="7djp0o"
store private key securely
encrypt key
restrict access
rotate key
document signer ownership
backup key securely
revoke/replace if compromised
never commit private key
avoid sharing one key across everything
```

If using keyless signing:

```text id="pkp6lb"
restrict OIDC workflow permissions
protect main branch
protect release tags
require PR review
use GitHub environments for production
verify certificate identity
verify OIDC issuer
```

Professional rule:

```text id="mzhtgw"
Keyless signing reduces key management burden, but shifts trust to CI identity and workflow protection.
```

---

# 24. Signing Notes

Create:

```bash id="73sl2p"
nano notes/image-signing-cosign-sigstore.md
```

Paste:

````markdown id="sqnczr"
# Image Signing with Cosign and Sigstore

## Why Sign Images?

Image signing proves that an artifact was signed by a trusted identity.

It helps prevent untrusted images from reaching production.

## Core Concepts

- Cosign: signing and verification tool
- Sigstore: supply-chain signing ecosystem
- Fulcio: certificate authority for keyless signing
- Rekor: transparency log
- OIDC: identity layer for keyless signing

## SBOM vs Provenance vs Signature

- SBOM: what is inside
- Provenance: how it was built
- Signature: trusted signing proof

## Key-Based Signing

```bash
cosign generate-key-pair --output-key-prefix signing/keys/demo-node-api-cosign
cosign sign --key signing/keys/demo-node-api-cosign.key IMAGE
cosign verify --key signing/keys/demo-node-api-cosign.pub IMAGE
````

## Keyless Signing

```bash id="jix9io"
cosign sign IMAGE
```

Verify with expected identity:

```bash id="78znq9"
cosign verify \
  --certificate-identity-regexp "https://github.com/USER/REPO/.github/workflows/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  IMAGE
```

## GitHub Actions Requirements

```yaml
permissions:
  contents: read
  packages: write
  id-token: write
```

## Production Rules

* Sign images after pushing to registry.
* Verify images before deployment.
* Prefer keyless signing in GitHub Actions.
* Verify signer identity, not just signature existence.
* Protect branches and release tags.
* Do not use build args for secrets.
* Store signing records with release metadata.

````id="mx4m50"

---

# 25. Signing Troubleshooting Notes

Create:

```bash id="4qsdm5"
nano notes/signing-troubleshooting-playbook.md
````

Paste:

````markdown id="hsa542"
# Signing Troubleshooting Playbook

## cosign: command not found

Install Cosign or use GitHub Actions installer.

```bash
go install github.com/sigstore/cosign/v3/cmd/cosign@latest
````

## Signing fails: registry denied

Common causes:

* not logged into registry
* token lacks write permission
* ECR IAM role lacks PutImage or upload permissions
* registry blocks signature artifact upload

## Verification fails with key

Common causes:

* wrong public key
* image was not signed
* image ref/tag differs
* tag was overwritten
* signature stored in different registry

## Verification fails keyless

Common causes:

* wrong certificate identity
* wrong OIDC issuer
* image signed by different workflow
* image signed from tag ref, not branch ref
* no keyless signature exists

## GitHub Actions keyless signing fails

Check workflow permissions:

```yaml
permissions:
  contents: read
  packages: write
  id-token: write
```

## Do not fix by

* disabling verification
* accepting any signer
* using broad identity regex forever
* using latest in production

````

---

# 26. Add Makefile Targets

Open:

```bash id="huk5uk"
cd ~/devops-masterclass/07-artifact-management-registries

nano Makefile
````

Add:

```Makefile id="e5itxv"
.PHONY: cosign-keygen sign-key verify-key verify-keyless signing-record verify-deploy

cosign-keygen:
	cosign generate-key-pair --output-key-prefix signing/keys/demo-node-api-cosign

sign-key:
	@test -n "$(IMAGE_REF)" || (echo "Usage: make sign-key IMAGE_REF=<image>" && exit 1)
	IMAGE_REF="$(IMAGE_REF)" ./scripts/sign-image-key.sh

verify-key:
	@test -n "$(IMAGE_REF)" || (echo "Usage: make verify-key IMAGE_REF=<image>" && exit 1)
	IMAGE_REF="$(IMAGE_REF)" ./scripts/verify-image-key.sh

verify-keyless:
	@test -n "$(IMAGE_REF)" || (echo "Usage: make verify-keyless IMAGE_REF=<image> CERT_IDENTITY_REGEXP=<regexp>" && exit 1)
	IMAGE_REF="$(IMAGE_REF)" CERT_IDENTITY_REGEXP="$(CERT_IDENTITY_REGEXP)" ./scripts/verify-image-keyless.sh

signing-record:
	@test -n "$(IMAGE_REF)" || (echo "Usage: make signing-record IMAGE_REF=<image>" && exit 1)
	IMAGE_REF="$(IMAGE_REF)" SIGNING_MODE="$${SIGNING_MODE:-keyless}" SIGNER_IDENTITY="$${SIGNER_IDENTITY:-unknown}" ./scripts/create-signing-record.sh

verify-deploy:
	@test -n "$(APP_IMAGE)" || (echo "Usage: make verify-deploy APP_IMAGE=<image> APP_VERSION=<tag>" && exit 1)
	@test -n "$(APP_VERSION)" || (echo "Usage: make verify-deploy APP_IMAGE=<image> APP_VERSION=<tag>" && exit 1)
	APP_IMAGE="$(APP_IMAGE)" APP_VERSION="$(APP_VERSION)" VERIFY_MODE="$${VERIFY_MODE:-keyless}" CERT_IDENTITY_REGEXP="$(CERT_IDENTITY_REGEXP)" ./scripts/verify-then-deploy-compose.sh
```

Use key-based:

```bash id="qj3ou9"
make sign-key IMAGE_REF="ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:$DEPLOY_TAG"
make verify-key IMAGE_REF="ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:$DEPLOY_TAG"
```

Use keyless:

```bash id="xmo3z8"
make verify-keyless \
  IMAGE_REF="ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:$DEPLOY_TAG" \
  CERT_IDENTITY_REGEXP="https://github.com/YOUR_GITHUB_USERNAME/devops-masterclass/.github/workflows/.*"
```

---

# 27. Final Validation Flow

Compute tag:

```bash id="5dm7m3"
cd ~/devops-masterclass/07-artifact-management-registries

VERSION_JSON="$(BASE_VERSION=0.7.0 CHANNEL=stable ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"
IMAGE_REF="ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api:$DEPLOY_TAG"

echo "$DEPLOY_TAG"
echo "$IMAGE_REF"
```

Push image if not already pushed:

```bash id="mxxhi5"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh

cd ~/devops-masterclass/07-artifact-management-registries
GITHUB_USERNAME=YOUR_GITHUB_USERNAME GHCR_TOKEN=YOUR_TOKEN IMAGE_TAG="$DEPLOY_TAG" ./scripts/ghcr-push.sh
```

Generate key pair if not created:

```bash id="4s4htd"
cosign generate-key-pair --output-key-prefix signing/keys/demo-node-api-cosign
```

Sign:

```bash id="tvx5t3"
IMAGE_REF="$IMAGE_REF" ./scripts/sign-image-key.sh
```

Verify:

```bash id="7na7ls"
IMAGE_REF="$IMAGE_REF" ./scripts/verify-image-key.sh
```

Create signing record:

```bash id="0yehjz"
IMAGE_REF="$IMAGE_REF" \
SIGNING_MODE=key \
SIGNER_IDENTITY="local-cosign-key" \
./scripts/create-signing-record.sh
```

Create release metadata:

```bash id="xhvwl9"
LATEST_SBOM="$(ls -t sbom/cyclonedx/demo-node-api-$DEPLOY_TAG*.json 2>/dev/null | head -n 1 || true)"
LATEST_PROV="$(ls -t provenance/manual/*.manual-provenance.json 2>/dev/null | head -n 1 || true)"
SIGNING_RECORD="$(ls -t signing/records/*.signing-record.json | head -n 1)"

BASE_VERSION=0.7.0 \
CHANNEL=stable \
IMAGE_NAME=demo-node-api \
REGISTRY_IMAGE="ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api" \
TEST_STATUS=passed \
SCAN_STATUS=passed \
SBOM_PATH="$LATEST_SBOM" \
PROVENANCE_PATH="$LATEST_PROV" \
SIGNING_RECORD_PATH="$SIGNING_RECORD" \
./scripts/create-release-metadata.sh
```

Verify then deploy:

```bash id="mhl4nd"
APP_IMAGE=ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api \
APP_VERSION="$DEPLOY_TAG" \
VERIFY_MODE=key \
PUBLIC_KEY_PATH=signing/keys/demo-node-api-cosign.pub \
./scripts/verify-then-deploy-compose.sh
```

---

# 28. Commit Work

Run:

```bash id="8ralr1"
cd ~/devops-masterclass

git status
git add 07-artifact-management-registries

git commit -m "feat: add image signing with cosign and sigstore workflows"
git push
```

Do **not** add private keys. Confirm:

```bash id="pf61ll"
git status --ignored | grep signing/keys || true
```

---

# 29. Interview Explanation

## Why sign container images?

Strong answer:

```text id="qpr1ev"
Image signing provides cryptographic proof that a container image was signed by a trusted identity. It helps deployment systems reject untrusted or tampered images and improves supply-chain integrity.
```

## What is Cosign?

Strong answer:

```text id="rtx3zi"
Cosign is a Sigstore tool used to sign and verify container images and other artifacts. It supports key-based signing and keyless signing using OIDC identities.
```

## What is keyless signing?

Strong answer:

```text id="jp1g3v"
Keyless signing avoids long-lived private signing keys. In CI, the workflow authenticates using OIDC, Sigstore Fulcio issues a short-lived certificate for that identity, Cosign signs the artifact, and the signing event can be recorded in Rekor.
```

## What are Fulcio and Rekor?

Strong answer:

```text id="lytyls"
Fulcio is Sigstore’s certificate authority that issues short-lived certificates for keyless signing. Rekor is Sigstore’s transparency log that records signing events for auditability.
```

## How do you verify a keyless signature?

Strong answer:

```text id="3wc19i"
I verify the image with Cosign and check both the OIDC issuer and the expected certificate identity, such as the GitHub Actions workflow path for the trusted repository. I do not just check that any signature exists.
```

## Signature vs SBOM vs provenance?

Strong answer:

```text id="yrxm2l"
An SBOM tells what components are inside the artifact. Provenance tells how and where it was built. A signature proves that a trusted identity signed the artifact or claim.
```

## How would you enforce signed images in production?

Strong answer:

```text id="ipfg56"
Before deployment, I would verify the image signature, expected signer identity, image digest, provenance, SBOM, and scan status. In Kubernetes, I would enforce this with admission policies using tools like policy controllers, Kyverno, or OPA-style policy systems.
```

---

# Today’s Core Rules

```text id="gschw0"
Image signing proves trust.
Cosign signs and verifies artifacts.
Sigstore provides the signing ecosystem.
Fulcio issues short-lived certificates for keyless signing.
Rekor records signing events.
Key-based signing requires private key protection.
Keyless signing is excellent for GitHub Actions.
Verify signer identity, not only signature existence.
Use id-token: write for GitHub keyless signing.
Sign registry image references.
Verify before deployment.
Do not put secrets in build args.
Store signing records with release metadata.
Production deployment should reject unsigned or untrusted images.
```

---

# Next Lesson

# Lesson 7.10 — Artifact Promotion: Dev → Staging → Production

We will go deeper into:

```text id="yyjczn"
artifact promotion vs rebuild
environment approval gates
promotion records
release candidates
same image through environments
staging validation
production approval
rollback metadata
GitHub Environments
Jenkins approvals
ECR/GHCR promotion patterns
production deployment governance
```

[1]: https://docs.sigstore.dev/about/overview/?utm_source=chatgpt.com "Overview"
[2]: https://github.com/sigstore/cosign?utm_source=chatgpt.com "sigstore/cosign: Code signing and transparency ..."
[3]: https://docs.sigstore.dev/cosign/signing/overview/?utm_source=chatgpt.com "Overview"
[4]: https://docs.sigstore.dev/cosign/system_config/installation/?utm_source=chatgpt.com "Installation"
[5]: https://docs.sigstore.dev/quickstart/quickstart-cosign/?utm_source=chatgpt.com "Sigstore Quickstart with Cosign"
[6]: https://docs.sigstore.dev/cosign/verifying/verify/?utm_source=chatgpt.com "Verifying Signatures - Cosign"
[7]: https://docs.sigstore.dev/cosign/signing/signing_with_containers/?utm_source=chatgpt.com "Signing Containers"

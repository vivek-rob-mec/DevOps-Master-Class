#!/usr/bin/env sh
set -eu
: "${IMAGE_DIGEST:?set IMAGE_DIGEST to registry/repository@sha256:...}"
: "${CERTIFICATE_IDENTITY:?set expected workflow identity}"
: "${OIDC_ISSUER:=https://token.actions.githubusercontent.com}"
cosign verify "$IMAGE_DIGEST" --certificate-identity "$CERTIFICATE_IDENTITY" --certificate-oidc-issuer "$OIDC_ISSUER"
cosign verify-attestation "$IMAGE_DIGEST" --type slsaprovenance --certificate-identity "$CERTIFICATE_IDENTITY" --certificate-oidc-issuer "$OIDC_ISSUER"
grype "$IMAGE_DIGEST" --fail-on high --only-fixed

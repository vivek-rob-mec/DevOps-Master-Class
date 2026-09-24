# Lesson 8.5 — Jenkins Production Pipeline

# Checkout → Version → Test → Docker Build → Scan → SBOM → Provenance → Push → Sign → Release Metadata → Promote → Deploy → Verify → Rollback Evidence

In Lesson 8.4, you learned Jenkins fundamentals.

Now we build a **production-grade Jenkins pipeline** for your `demo-node-api`.

This is the Jenkins equivalent of the GitHub Actions production workflow from Lesson 8.3.

Jenkins Pipeline uses a `Jenkinsfile` to define stages and steps as code, and Jenkins’ official Pipeline syntax treats steps as the basic execution units inside stages. Jenkins also provides credentials helpers for safely binding secrets into Pipeline execution. ([Jenkins][1])

---

# 1. Jenkins Production Pipeline Goal

Your Jenkins production pipeline should answer:

```text id="hfj92g"
What commit was built?
What version was created?
Did tests pass?
Was the Docker image built?
Was the image scanned?
Was an SBOM generated?
Was provenance recorded?
Was the image pushed to a registry?
Was the image signed?
Was release metadata archived?
Was staging promotion recorded?
Was production approval required?
Is rollback information available?
```

Pipeline flow:

```text id="dgr1o4"
checkout
  ↓
compute version
  ↓
install dependencies
  ↓
test
  ↓
build Docker image
  ↓
scan image
  ↓
generate SBOM
  ↓
generate provenance
  ↓
push image to GHCR/ECR
  ↓
sign image
  ↓
verify signature
  ↓
create release metadata
  ↓
promote to staging
  ↓
deploy/placeholder
  ↓
production approval
  ↓
production promotion record
  ↓
archive evidence
```

Professional rule:

```text id="xnkzcd"
Jenkins should produce trusted artifacts and archived release evidence, not just console logs.
```

---

# 2. Jenkins vs GitHub Actions Production Difference

GitHub Actions can do keyless signing easily because GitHub provides OIDC identity to the workflow.

Jenkins can also integrate with modern identity systems, but the simplest production pattern for Jenkins is usually:

```text id="h4g9vf"
key-based Cosign signing
```

So in this Jenkins lesson:

```text id="42zp2k"
GitHub Actions:
  keyless signing with OIDC

Jenkins:
  key-based signing using Jenkins Credentials
```

Cosign supports signing and verifying container images; its verification command can verify signatures using a key or other supported verification options. ([GitHub][2])

---

# 3. Required Jenkins Agent Tools

Your Jenkins agent should have:

```text id="l2odyb"
git
bash
node
npm
docker
jq
trivy
cosign
```

Check on the Jenkins agent:

```bash id="ofp9ln"
git --version
node --version
npm --version
docker --version
jq --version
trivy --version || true
cosign version || true
```

If some tools are missing, you can either:

```text id="zwf3x7"
install them on the agent
use Jenkins tools
use Dockerized tool containers
use dedicated labeled agents
```

Jenkins can also run Pipeline stages inside Docker containers, and the Docker Pipeline documentation explains that Docker images can be used as execution environments for stages or entire pipelines. ([Jenkins][3])

---

# 4. Required Jenkins Credentials

Create these credentials in Jenkins:

```text id="zjfqk0"
Manage Jenkins
  -> Credentials
  -> Global credentials
```

## GHCR credentials

Credential type:

```text id="fm42og"
Username with password
```

ID:

```text id="whp8g0"
ghcr-creds
```

Username:

```text id="zb086u"
YOUR_GITHUB_USERNAME
```

Password:

```text id="em7cx4"
GHCR token with package write permission
```

## Cosign private key

Credential type:

```text id="zplcnb"
Secret file
```

ID:

```text id="11ij2k"
cosign-private-key
```

File:

```text id="vj8bem"
cosign.key
```

## Cosign password

Credential type:

```text id="tn7x6k"
Secret text
```

ID:

```text id="2blodf"
cosign-password
```

Value:

```text id="a9k8m6"
password used when generating Cosign key pair
```

Jenkins Credentials and the Credentials Binding plugin allow secrets to be injected into builds without hardcoding them in the Jenkinsfile. ([Jenkins][1])

---

# 5. Create Jenkins Production Directory

Run:

```bash id="c1yk2m"
cd ~/devops-masterclass/08-cicd-pipelines

mkdir -p jenkins/production/{pipelines,scripts,notes,runbooks,reports,examples}
```

---

# 6. Create Jenkins Production Notes

Create:

```bash id="gkdej0"
nano jenkins/production/notes/jenkins-production-pipeline.md
```

Paste:

```markdown id="rvt0uz"
# Jenkins Production Pipeline

## Goal

Build a production-style CI/CD pipeline for `demo-node-api`.

## Pipeline Stages

1. Checkout
2. Compute version
3. Install dependencies
4. Test
5. Docker build
6. Security scan
7. SBOM generation
8. Provenance record
9. Registry push
10. Image signing
11. Signature verification
12. Release metadata
13. Staging promotion
14. Staging deployment or placeholder
15. Production approval
16. Production promotion
17. Archive evidence

## Rules

- Use immutable version-SHA tags.
- Do not deploy `latest`.
- Use Jenkins Credentials for secrets.
- Archive release evidence.
- Production approval must approve a specific image.
- Rollback version must be recorded.
- Servers should pull images; CI should push images.
```

---

# 7. Create Jenkins Compose Deploy Helper

This helper lets Jenkins deploy through your existing Docker Compose deployment scripts when the agent has access.

Create:

```bash id="nl9u8s"
nano jenkins/production/scripts/jenkins-compose-deploy.sh
```

Paste:

```bash id="8f42w1"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
COMPOSE_DIR="${COMPOSE_DIR:-$ROOT_DIR/06-docker-containers/compose-demo}"
APP_IMAGE="${APP_IMAGE:-}"
APP_VERSION="${APP_VERSION:-}"
TARGET_ENV="${TARGET_ENV:-staging}"
COMPOSE_FILES="${COMPOSE_FILES:-compose.yaml compose.prod.yaml}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:8080/health}"
VERSION_URL="${VERSION_URL:-http://127.0.0.1:8080/version}"

if [ -z "$APP_IMAGE" ] || [ -z "$APP_VERSION" ]; then
  echo "ERROR: APP_IMAGE and APP_VERSION are required" >&2
  exit 1
fi

echo "===== Jenkins Compose Deploy ====="
echo "Target env: $TARGET_ENV"
echo "Compose dir: $COMPOSE_DIR"
echo "Image: $APP_IMAGE:$APP_VERSION"
echo "Compose files: $COMPOSE_FILES"

cd "$COMPOSE_DIR"

APP_IMAGE="$APP_IMAGE" \
APP_VERSION="$APP_VERSION" \
COMPOSE_FILES="$COMPOSE_FILES" \
HEALTH_URL="$HEALTH_URL" \
VERSION_URL="$VERSION_URL" \
./scripts/deploy-compose.sh

echo
echo "===== Runtime Verification ====="

curl -fsS "$HEALTH_URL" || {
  echo "ERROR: health check failed" >&2
  exit 1
}

echo
curl -fsS "$VERSION_URL" || true

echo
echo "Deployment completed for $TARGET_ENV"
```

Make executable:

```bash id="3iw523"
chmod +x jenkins/production/scripts/jenkins-compose-deploy.sh
```

---

# 8. Create Jenkins Release Evidence Helper

This script creates one final Jenkins evidence file.

Create:

```bash id="m9hxn2"
nano jenkins/production/scripts/create-jenkins-release-evidence.sh
```

Paste:

```bash id="fqzgj3"
#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${OUTPUT_DIR:-08-cicd-pipelines/jenkins/production/reports}"
SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"
IMAGE_REF="${IMAGE_REF:-}"
IMAGE_DIGEST="${IMAGE_DIGEST:-}"
DEPLOY_TAG="${DEPLOY_TAG:-}"
COMMIT_SHA="${COMMIT_SHA:-}"
BUILD_URL_VALUE="${BUILD_URL:-}"
JOB_NAME_VALUE="${JOB_NAME:-}"
BUILD_NUMBER_VALUE="${BUILD_NUMBER:-}"
TEST_STATUS="${TEST_STATUS:-unknown}"
SCAN_STATUS="${SCAN_STATUS:-unknown}"
SBOM_PATH="${SBOM_PATH:-}"
PROVENANCE_PATH="${PROVENANCE_PATH:-}"
SIGNATURE_STATUS="${SIGNATURE_STATUS:-unknown}"
PROMOTION_STATUS="${PROMOTION_STATUS:-unknown}"
ROLLBACK_VERSION="${ROLLBACK_VERSION:-}"

mkdir -p "$OUTPUT_DIR"

SAFE_TAG="$(echo "${DEPLOY_TAG:-unknown}" | tr '/:@' '____')"
OUTPUT_FILE="$OUTPUT_DIR/jenkins-release-evidence-$SAFE_TAG.json"

cat > "$OUTPUT_FILE" <<EOF
{
  "service_name": "$SERVICE_NAME",
  "ci_system": "jenkins",
  "job_name": "$JOB_NAME_VALUE",
  "build_number": "$BUILD_NUMBER_VALUE",
  "build_url": "$BUILD_URL_VALUE",
  "commit_sha": "$COMMIT_SHA",
  "deploy_tag": "$DEPLOY_TAG",
  "image_ref": "$IMAGE_REF",
  "image_digest": "$IMAGE_DIGEST",
  "test_status": "$TEST_STATUS",
  "scan_status": "$SCAN_STATUS",
  "sbom_path": "$SBOM_PATH",
  "provenance_path": "$PROVENANCE_PATH",
  "signature_status": "$SIGNATURE_STATUS",
  "promotion_status": "$PROMOTION_STATUS",
  "rollback_version": "$ROLLBACK_VERSION",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$OUTPUT_FILE" | jq .
echo "Evidence file: $OUTPUT_FILE"
```

Make executable:

```bash id="d9slo7"
chmod +x jenkins/production/scripts/create-jenkins-release-evidence.sh
```

---

# 9. Create Jenkins Production Pipeline

Create:

```bash id="9scrbx"
nano jenkins/production/pipelines/Jenkinsfile.production
```

Paste:

```groovy id="ej7c2d"
pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '30', artifactNumToKeepStr: '30'))
    timeout(time: 60, unit: 'MINUTES')
  }

  parameters {
    string(name: 'BASE_VERSION', defaultValue: '0.8.0', description: 'Base semantic version')
    choice(name: 'CHANNEL', choices: ['dev', 'rc', 'stable'], description: 'Release channel')
    booleanParam(name: 'PUSH_IMAGE', defaultValue: false, description: 'Push image to GHCR?')
    booleanParam(name: 'RUN_SCAN', defaultValue: true, description: 'Run Trivy image scan?')
    booleanParam(name: 'GENERATE_SBOM', defaultValue: true, description: 'Generate SBOM with Trivy?')
    booleanParam(name: 'SIGN_IMAGE', defaultValue: false, description: 'Sign image with Cosign key?')
    booleanParam(name: 'DEPLOY_STAGING', defaultValue: false, description: 'Deploy to staging using local Compose?')
    booleanParam(name: 'DEPLOY_PRODUCTION', defaultValue: false, description: 'Request production approval and deploy?')
    string(name: 'ROLLBACK_VERSION', defaultValue: '', description: 'Previous known-good version for rollback')
    choice(name: 'DEPLOY_MODE', choices: ['none', 'local-compose'], description: 'Deployment mode')
  }

  environment {
    APP_DIR = '05-application-runtime/demo-node-api'
    MODULE7_DIR = '07-artifact-management-registries'
    MODULE8_DIR = '08-cicd-pipelines'
    SERVICE_NAME = 'demo-node-api'
    LOCAL_IMAGE = 'demo-node-api'
    REGISTRY_IMAGE = 'ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api'
    REPORT_DIR = '08-cicd-pipelines/jenkins/production/reports'
    COMPOSE_FILES = 'compose.yaml compose.prod.yaml'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm

        sh '''
          echo "Workspace: $WORKSPACE"
          echo "Job: $JOB_NAME"
          echo "Build: $BUILD_NUMBER"
          git rev-parse --short HEAD
          git status --short || true
        '''
      }
    }

    stage('Preflight Tools') {
      steps {
        sh '''
          set -e
          echo "===== Tool Versions ====="
          git --version
          node --version
          npm --version
          docker --version
          jq --version
          trivy --version || true
          cosign version || true
        '''
      }
    }

    stage('Compute Version') {
      steps {
        script {
          def shortSha = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          def version = params.BASE_VERSION

          if (params.CHANNEL == 'dev') {
            version = "${params.BASE_VERSION}-dev"
          } else if (params.CHANNEL == 'rc') {
            version = "${params.BASE_VERSION}-rc.1"
          } else if (params.CHANNEL == 'stable') {
            version = "${params.BASE_VERSION}"
          } else {
            error("Unsupported channel: ${params.CHANNEL}")
          }

          env.SHORT_SHA = shortSha
          env.VERSION = version
          env.DEPLOY_TAG = "${version}-${shortSha}"
          env.IMAGE_REF = "${env.REGISTRY_IMAGE}:${env.DEPLOY_TAG}"
          env.LOCAL_IMAGE_REF = "${env.LOCAL_IMAGE}:${env.DEPLOY_TAG}"
          env.COMMIT_SHA = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()

          echo "Version: ${env.VERSION}"
          echo "Deploy tag: ${env.DEPLOY_TAG}"
          echo "Local image: ${env.LOCAL_IMAGE_REF}"
          echo "Registry image: ${env.IMAGE_REF}"
        }
      }
    }

    stage('Install Dependencies') {
      steps {
        dir("${APP_DIR}") {
          sh '''
            set -e
            npm ci
          '''
        }
      }
    }

    stage('Test') {
      steps {
        dir("${APP_DIR}") {
          sh '''
            set -e
            npm test
          '''
        }

        script {
          env.TEST_STATUS = 'passed'
        }
      }
    }

    stage('Docker Build') {
      steps {
        dir("${APP_DIR}") {
          sh '''
            set -e
            VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
            docker image inspect "$LOCAL_IMAGE_REF" >/dev/null
          '''
        }

        script {
          env.BUILD_STATUS = 'passed'
        }
      }
    }

    stage('Image Scan') {
      when {
        expression { return params.RUN_SCAN }
      }

      steps {
        sh '''
          set -e
          mkdir -p "$REPORT_DIR"

          if command -v trivy >/dev/null 2>&1; then
            trivy image \
              --severity HIGH,CRITICAL \
              --format json \
              --output "$REPORT_DIR/trivy-scan-$DEPLOY_TAG.json" \
              "$LOCAL_IMAGE_REF"

            echo "Trivy scan report:"
            jq '.Results | length' "$REPORT_DIR/trivy-scan-$DEPLOY_TAG.json" || true
          else
            echo "ERROR: trivy not installed on Jenkins agent" >&2
            exit 1
          fi
        '''

        script {
          env.SCAN_STATUS = 'passed'
        }
      }
    }

    stage('Generate SBOM') {
      when {
        expression { return params.GENERATE_SBOM }
      }

      steps {
        sh '''
          set -e
          cd "$MODULE7_DIR"

          mkdir -p sbom/cyclonedx sbom/spdx sbom/reports

          if command -v trivy >/dev/null 2>&1; then
            trivy image \
              --format cyclonedx \
              --output "sbom/cyclonedx/$SERVICE_NAME-$DEPLOY_TAG.jenkins.cdx.json" \
              "$LOCAL_IMAGE_REF"

            trivy image \
              --format spdx-json \
              --output "sbom/spdx/$SERVICE_NAME-$DEPLOY_TAG.jenkins.spdx.json" \
              "$LOCAL_IMAGE_REF"

            echo "SBOM generated."
          else
            echo "ERROR: trivy not installed on Jenkins agent" >&2
            exit 1
          fi
        '''

        script {
          env.SBOM_PATH = "${env.MODULE7_DIR}/sbom/cyclonedx/${env.SERVICE_NAME}-${env.DEPLOY_TAG}.jenkins.cdx.json"
        }
      }
    }

    stage('Create Provenance Record') {
      steps {
        sh '''
          set -e
          cd "$MODULE7_DIR"

          IMAGE_NAME="$LOCAL_IMAGE" \
          IMAGE_TAG="$DEPLOY_TAG" \
          SOURCE_REPO="$JOB_NAME" \
          COMMIT_SHA="$SHORT_SHA" \
          BUILDER="Jenkins" \
          BUILD_TYPE="jenkins-pipeline" \
          WORKFLOW="Jenkinsfile.production" \
          ./scripts/create-manual-provenance.sh

          LATEST_PROV="$(ls -t provenance/manual/*.manual-provenance.json | head -n 1)"
          ./scripts/validate-manual-provenance.sh "$LATEST_PROV"
        '''

        script {
          env.PROVENANCE_PATH = sh(script: "cd ${env.MODULE7_DIR} && ls -t provenance/manual/*.manual-provenance.json | head -n 1", returnStdout: true).trim()
        }
      }
    }

    stage('Login and Push Image') {
      when {
        expression { return params.PUSH_IMAGE }
      }

      steps {
        withCredentials([usernamePassword(credentialsId: 'ghcr-creds', usernameVariable: 'GHCR_USERNAME', passwordVariable: 'GHCR_TOKEN')]) {
          sh '''
            set -e

            echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USERNAME" --password-stdin

            docker tag "$LOCAL_IMAGE_REF" "$IMAGE_REF"
            docker push "$IMAGE_REF"

            IMAGE_DIGEST="$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE_REF" 2>/dev/null || true)"
            echo "$IMAGE_DIGEST" > "$REPORT_DIR/image-digest-$DEPLOY_TAG.txt"

            echo "Pushed image: $IMAGE_REF"
            cat "$REPORT_DIR/image-digest-$DEPLOY_TAG.txt" || true
          '''
        }

        script {
          env.PUSH_STATUS = 'passed'
          env.IMAGE_DIGEST = sh(script: "cat ${env.REPORT_DIR}/image-digest-${env.DEPLOY_TAG}.txt 2>/dev/null || true", returnStdout: true).trim()
        }
      }

      post {
        always {
          sh 'docker logout ghcr.io || true'
        }
      }
    }

    stage('Sign Image with Cosign Key') {
      when {
        expression { return params.PUSH_IMAGE && params.SIGN_IMAGE }
      }

      steps {
        withCredentials([
          file(credentialsId: 'cosign-private-key', variable: 'COSIGN_KEY_FILE'),
          string(credentialsId: 'cosign-password', variable: 'COSIGN_PASSWORD')
        ]) {
          sh '''
            set -e

            if ! command -v cosign >/dev/null 2>&1; then
              echo "ERROR: cosign not installed on Jenkins agent" >&2
              exit 1
            fi

            cosign sign \
              --yes \
              --key "$COSIGN_KEY_FILE" \
              "$IMAGE_REF"

            echo "Image signed: $IMAGE_REF"
          '''
        }

        script {
          env.SIGNATURE_STATUS = 'signed'
        }
      }
    }

    stage('Verify Cosign Signature') {
      when {
        expression { return params.PUSH_IMAGE && params.SIGN_IMAGE }
      }

      steps {
        withCredentials([file(credentialsId: 'cosign-public-key', variable: 'COSIGN_PUBLIC_KEY_FILE')]) {
          sh '''
            set -e

            cosign verify \
              --key "$COSIGN_PUBLIC_KEY_FILE" \
              "$IMAGE_REF" \
              | tee "$REPORT_DIR/cosign-verify-$DEPLOY_TAG.json"
          '''
        }

        script {
          env.SIGNATURE_STATUS = 'verified'
        }
      }
    }

    stage('Create Release Metadata') {
      steps {
        sh '''
          set -e
          cd "$MODULE7_DIR"

          BASE_VERSION="$BASE_VERSION" \
          CHANNEL="$CHANNEL" \
          IMAGE_NAME="$LOCAL_IMAGE" \
          REGISTRY_IMAGE="$REGISTRY_IMAGE" \
          TEST_STATUS="${TEST_STATUS:-passed}" \
          SCAN_STATUS="${SCAN_STATUS:-not_run}" \
          SBOM_PATH="${SBOM_PATH:-}" \
          PROVENANCE_PATH="${PROVENANCE_PATH:-}" \
          SIGNING_RECORD_PATH="" \
          ./scripts/create-release-metadata.sh

          LATEST_METADATA="$(ls -t release-records/$SERVICE_NAME-*.json | head -n 1)"
          ./scripts/validate-release-metadata.sh "$LATEST_METADATA" || true
          cat "$LATEST_METADATA" | jq .
        '''
      }
    }

    stage('Create Jenkins Release Evidence') {
      steps {
        sh '''
          set -e

          IMAGE_DIGEST_VALUE=""
          if [ -f "$REPORT_DIR/image-digest-$DEPLOY_TAG.txt" ]; then
            IMAGE_DIGEST_VALUE="$(cat "$REPORT_DIR/image-digest-$DEPLOY_TAG.txt")"
          fi

          IMAGE_REF_VALUE="$LOCAL_IMAGE_REF"
          if [ "$PUSH_IMAGE" = "true" ]; then
            IMAGE_REF_VALUE="$IMAGE_REF"
          fi

          SERVICE_NAME="$SERVICE_NAME" \
          IMAGE_REF="$IMAGE_REF_VALUE" \
          IMAGE_DIGEST="$IMAGE_DIGEST_VALUE" \
          DEPLOY_TAG="$DEPLOY_TAG" \
          COMMIT_SHA="$COMMIT_SHA" \
          TEST_STATUS="${TEST_STATUS:-passed}" \
          SCAN_STATUS="${SCAN_STATUS:-not_run}" \
          SBOM_PATH="${SBOM_PATH:-}" \
          PROVENANCE_PATH="${PROVENANCE_PATH:-}" \
          SIGNATURE_STATUS="${SIGNATURE_STATUS:-not_signed}" \
          PROMOTION_STATUS="not_promoted" \
          ROLLBACK_VERSION="${ROLLBACK_VERSION}" \
          ./08-cicd-pipelines/jenkins/production/scripts/create-jenkins-release-evidence.sh
        '''
      }
    }

    stage('Promote to Staging') {
      steps {
        sh '''
          set -e
          cd "$MODULE7_DIR"

          ARTIFACT="$LOCAL_IMAGE_REF"
          if [ "$PUSH_IMAGE" = "true" ]; then
            ARTIFACT="$IMAGE_REF"
          fi

          ARTIFACT="$ARTIFACT" \
          IMAGE_TAG="$DEPLOY_TAG" \
          FROM_ENV=dev \
          TO_ENV=staging \
          TEST_STATUS="${TEST_STATUS:-passed}" \
          SCAN_STATUS="${SCAN_STATUS:-not_run}" \
          SBOM_PATH="${SBOM_PATH:-}" \
          PROVENANCE_PATH="${PROVENANCE_PATH:-}" \
          SIGNATURE_STATUS="${SIGNATURE_STATUS:-not_signed}" \
          ./scripts/create-promotion-record-v2.sh

          LATEST_PROMOTION="$(ls -t promotion/records/*.json | head -n 1)"
          ./scripts/validate-promotion-record.sh "$LATEST_PROMOTION"
        '''
      }
    }

    stage('Deploy Staging') {
      when {
        expression { return params.DEPLOY_STAGING && params.DEPLOY_MODE == 'local-compose' }
      }

      steps {
        sh '''
          set -e

          APP_IMAGE="$LOCAL_IMAGE" \
          APP_VERSION="$DEPLOY_TAG" \
          TARGET_ENV=staging \
          COMPOSE_FILES="$COMPOSE_FILES" \
          ./08-cicd-pipelines/jenkins/production/scripts/jenkins-compose-deploy.sh
        '''
      }
    }

    stage('Production Approval') {
      when {
        expression { return params.DEPLOY_PRODUCTION }
      }

      steps {
        script {
          if (!params.ROLLBACK_VERSION?.trim()) {
            error('ROLLBACK_VERSION is required for production deployment')
          }

          def artifact = params.PUSH_IMAGE ? env.IMAGE_REF : env.LOCAL_IMAGE_REF

          input message: "Approve production deployment of ${artifact} with rollback ${params.ROLLBACK_VERSION}?",
                ok: 'Approve Production'
        }
      }
    }

    stage('Promote to Production') {
      when {
        expression { return params.DEPLOY_PRODUCTION }
      }

      steps {
        sh '''
          set -e
          cd "$MODULE7_DIR"

          ARTIFACT="$LOCAL_IMAGE_REF"
          if [ "$PUSH_IMAGE" = "true" ]; then
            ARTIFACT="$IMAGE_REF"
          fi

          ARTIFACT="$ARTIFACT" \
          IMAGE_TAG="$DEPLOY_TAG" \
          FROM_ENV=staging \
          TO_ENV=production \
          APPROVAL_REQUIRED=true \
          TEST_STATUS="${TEST_STATUS:-passed}" \
          SCAN_STATUS="${SCAN_STATUS:-not_run}" \
          SBOM_PATH="${SBOM_PATH:-}" \
          PROVENANCE_PATH="${PROVENANCE_PATH:-}" \
          SIGNATURE_STATUS="${SIGNATURE_STATUS:-not_signed}" \
          STAGING_DEPLOYMENT_STATUS=passed \
          ROLLBACK_VERSION="$ROLLBACK_VERSION" \
          ./scripts/create-promotion-record-v2.sh

          LATEST_PROMOTION="$(ls -t promotion/records/*.json | head -n 1)"
          ./scripts/validate-promotion-record.sh "$LATEST_PROMOTION"
        '''
      }
    }

    stage('Deploy Production') {
      when {
        expression { return params.DEPLOY_PRODUCTION && params.DEPLOY_MODE == 'local-compose' }
      }

      steps {
        sh '''
          set -e

          APP_IMAGE="$LOCAL_IMAGE" \
          APP_VERSION="$DEPLOY_TAG" \
          TARGET_ENV=production \
          COMPOSE_FILES="$COMPOSE_FILES" \
          ./08-cicd-pipelines/jenkins/production/scripts/jenkins-compose-deploy.sh
        '''
      }
    }
  }

  post {
    always {
      sh '''
        mkdir -p "$REPORT_DIR"
        echo "Build result: ${currentBuild.currentResult:-unknown}" > "$REPORT_DIR/final-status-$DEPLOY_TAG.txt" 2>/dev/null || true
        find 07-artifact-management-registries -maxdepth 3 -type f \\( -name "*.json" -o -name "*.md" \\) | sort | tail -n 50 || true
      '''

      archiveArtifacts artifacts: '''
        08-cicd-pipelines/jenkins/production/reports/**/*,
        07-artifact-management-registries/release-records/**/*,
        07-artifact-management-registries/promotion/records/**/*,
        07-artifact-management-registries/provenance/manual/**/*,
        07-artifact-management-registries/sbom/**/*,
        07-artifact-management-registries/checksums/**/*
      ''', allowEmptyArchive: true
    }

    success {
      echo "Jenkins production pipeline succeeded for ${env.DEPLOY_TAG}"
    }

    failure {
      echo "Jenkins production pipeline failed. Check archived evidence and console logs."
    }

    cleanup {
      sh '''
        docker logout ghcr.io || true
      '''
    }
  }
}
```

---

# 10. Important Correction: Add Public Key Credential

The pipeline verification stage expects:

```text id="qbytov"
cosign-public-key
```

Create it in Jenkins:

```text id="h38dyj"
Credential type:
  Secret file

ID:
  cosign-public-key

File:
  cosign.pub
```

If you do not want signing yet, run with:

```text id="1qvkjl"
SIGN_IMAGE=false
```

Then those signing stages are skipped.

---

# 11. Generate Cosign Key Pair Locally

From Module 7:

```bash id="5xw464"
cd ~/devops-masterclass/07-artifact-management-registries

mkdir -p signing/keys

cosign generate-key-pair \
  --output-key-prefix signing/keys/demo-node-api-cosign
```

This creates:

```text id="16u85d"
signing/keys/demo-node-api-cosign.key
signing/keys/demo-node-api-cosign.pub
```

Upload these into Jenkins credentials:

```text id="iggdqs"
private key -> cosign-private-key
public key  -> cosign-public-key
password    -> cosign-password
```

Never commit the private key.

---

# 12. Fix Jenkinsfile Environment Username

In the Jenkinsfile, replace:

```groovy id="rta2nf"
REGISTRY_IMAGE = 'ghcr.io/YOUR_GITHUB_USERNAME/demo-node-api'
```

with your real GHCR namespace:

```groovy id="wzj1pi"
REGISTRY_IMAGE = 'ghcr.io/vivek-saroj/demo-node-api'
```

or your exact GitHub username/org.

If your GitHub username is different, use that.

---

# 13. Validate Jenkinsfile Structure

Run:

```bash id="iavhxd"
cd ~/devops-masterclass/08-cicd-pipelines

./jenkins/scripts/validate-jenkinsfiles.sh
```

The basic validator may not scan the production directory. Run:

```bash id="hlbnk4"
DIR=jenkins/production/pipelines ./jenkins/scripts/validate-jenkinsfiles.sh
```

Expected:

```text id="9dye4y"
Basic Jenkinsfile validation passed.
```

---

# 14. Create Production Pipeline Validation Script

Create:

```bash id="oqid4h"
nano jenkins/production/scripts/validate-jenkins-production-files.sh
```

Paste:

```bash id="y6tx6x"
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-08-cicd-pipelines/jenkins/production}"

echo "===== Validate Jenkins Production Pipeline Files ====="

test -f "$BASE_DIR/pipelines/Jenkinsfile.production"
test -x "$BASE_DIR/scripts/jenkins-compose-deploy.sh"
test -x "$BASE_DIR/scripts/create-jenkins-release-evidence.sh"
test -f "$BASE_DIR/notes/jenkins-production-pipeline.md"

grep -q "stage('Docker Build')" "$BASE_DIR/pipelines/Jenkinsfile.production"
grep -q "stage('Image Scan')" "$BASE_DIR/pipelines/Jenkinsfile.production"
grep -q "stage('Generate SBOM')" "$BASE_DIR/pipelines/Jenkinsfile.production"
grep -q "stage('Create Provenance Record')" "$BASE_DIR/pipelines/Jenkinsfile.production"
grep -q "stage('Login and Push Image')" "$BASE_DIR/pipelines/Jenkinsfile.production"
grep -q "stage('Production Approval')" "$BASE_DIR/pipelines/Jenkinsfile.production"
grep -q "archiveArtifacts" "$BASE_DIR/pipelines/Jenkinsfile.production"

echo "Jenkins production files validated."
```

Make executable:

```bash id="i6nzge"
chmod +x jenkins/production/scripts/validate-jenkins-production-files.sh
```

Run from repo root:

```bash id="9ncsag"
cd ~/devops-masterclass

./08-cicd-pipelines/jenkins/production/scripts/validate-jenkins-production-files.sh
```

---

# 15. Add Makefile Targets

Open:

```bash id="xtqgsg"
cd ~/devops-masterclass/08-cicd-pipelines

nano Makefile
```

Add:

```Makefile id="wmpz5y"
.PHONY: validate-jenkins-production

validate-jenkins-production:
	cd $(ROOT_DIR) && ./08-cicd-pipelines/jenkins/production/scripts/validate-jenkins-production-files.sh
	DIR=jenkins/production/pipelines ./jenkins/scripts/validate-jenkinsfiles.sh
```

Run:

```bash id="ii3by9"
make validate-jenkins-production
```

---

# 16. Configure Jenkins Job

In Jenkins UI:

```text id="rka15i"
New Item
  -> Pipeline
  -> Pipeline from SCM
  -> Git
  -> Repository URL: your repo
  -> Script Path:
     08-cicd-pipelines/jenkins/production/pipelines/Jenkinsfile.production
```

Recommended job name:

```text id="b99hvl"
demo-node-api-production-pipeline
```

First run with safe parameters:

```text id="fw9ww5"
BASE_VERSION=0.8.0
CHANNEL=dev
PUSH_IMAGE=false
RUN_SCAN=true
GENERATE_SBOM=true
SIGN_IMAGE=false
DEPLOY_STAGING=false
DEPLOY_PRODUCTION=false
ROLLBACK_VERSION=
DEPLOY_MODE=none
```

This should:

```text id="et32r8"
checkout
test
build local Docker image
scan
generate SBOM
create provenance
create metadata
create staging promotion record
archive evidence
```

Then run with registry push:

```text id="dkfghw"
PUSH_IMAGE=true
SIGN_IMAGE=false
```

Then run with signing:

```text id="kybcwe"
PUSH_IMAGE=true
SIGN_IMAGE=true
```

Then staging deploy:

```text id="cxbsf3"
DEPLOY_STAGING=true
DEPLOY_MODE=local-compose
```

Then production approval:

```text id="crzreq"
DEPLOY_PRODUCTION=true
ROLLBACK_VERSION=0.7.0-previous
DEPLOY_MODE=none
```

Use `DEPLOY_MODE=local-compose` for production only if the Jenkins agent is allowed to deploy to that environment.

---

# 17. Trivy Scan Behavior

The pipeline uses:

```bash id="ldv3bz"
trivy image --severity HIGH,CRITICAL --format json --output report.json IMAGE
```

This creates a JSON vulnerability report.

Trivy can also generate CycloneDX SBOMs using `--format cyclonedx`, and its official SBOM docs describe using regular subcommands like `image` with `--format cyclonedx`. ([Trivy][4])

For stricter gate behavior, add:

```bash id="tm9cqg"
--exit-code 1
```

Example:

```bash id="h42keq"
trivy image \
  --severity CRITICAL \
  --exit-code 1 \
  "$LOCAL_IMAGE_REF"
```

Recommended policy:

```text id="l6ek5e"
dev:
  report high/critical

staging:
  fail critical

production:
  fail critical unless approved exception exists
```

---

# 18. Deployment Strategy Notes

This Jenkinsfile supports:

```text id="28q8wf"
DEPLOY_MODE=none
DEPLOY_MODE=local-compose
```

## `none`

Use for safe CI/CD artifact workflow:

```text id="gd5yaa"
build
scan
push
sign
metadata
promotion
no runtime deployment
```

## `local-compose`

Use only when Jenkins agent can safely run your Compose deployment:

```text id="sa4tiw"
APP_IMAGE=demo-node-api
APP_VERSION=0.8.0-dev-a1b2c3d
./scripts/deploy-compose.sh
```

Production warning:

```text id="9tza57"
Do not give every Jenkins agent production deployment access.
```

Better production models later:

```text id="ilgg35"
SSH deploy with restricted key
Kubernetes deploy with limited kubeconfig
GitOps commit to environment repo
ArgoCD sync
ECS service update
manual approval plus deployment runner
```

---

# 19. Rollback-Aware Design

The production approval stage requires:

```text id="3vnqif"
ROLLBACK_VERSION
```

Why?

```text id="8y2e7b"
Production deployment without rollback metadata is unsafe.
```

The approval message includes:

```text id="urvwcq"
artifact image
rollback version
```

Good approval:

```text id="28s5z2"
Approve production deployment of ghcr.io/user/demo-node-api:0.8.0-dev-a1b2c3d with rollback 0.7.0-a9b8c7d?
```

Bad approval:

```text id="61i1qz"
Deploy latest?
```

Professional rule:

```text id="73ro1j"
Approvals must reference exact immutable artifacts.
```

---

# 20. Create Jenkins Production Runbook

Create:

```bash id="8uyczp"
nano jenkins/production/runbooks/jenkins-production-pipeline-runbook.md
```

Paste:

````markdown id="pk69z7"
# Jenkins Production Pipeline Runbook

## Job

`demo-node-api-production-pipeline`

## Jenkinsfile

```text
08-cicd-pipelines/jenkins/production/pipelines/Jenkinsfile.production
````

## Safe First Run

```text
PUSH_IMAGE=false
SIGN_IMAGE=false
DEPLOY_STAGING=false
DEPLOY_PRODUCTION=false
DEPLOY_MODE=none
```

## Registry Push Run

```text
PUSH_IMAGE=true
SIGN_IMAGE=false
DEPLOY_MODE=none
```

## Signed Release Run

```text
PUSH_IMAGE=true
SIGN_IMAGE=true
DEPLOY_MODE=none
```

## Staging Deploy

```text
DEPLOY_STAGING=true
DEPLOY_MODE=local-compose
```

## Production Promotion

```text
DEPLOY_PRODUCTION=true
ROLLBACK_VERSION=<previous-known-good>
DEPLOY_MODE=none
```

## Production Deploy

Only use when Jenkins agent is approved for production deployment:

```text
DEPLOY_PRODUCTION=true
ROLLBACK_VERSION=<previous-known-good>
DEPLOY_MODE=local-compose
```

## Evidence

Archived artifacts include:

* release metadata
* promotion records
* SBOMs
* provenance records
* Trivy reports
* Jenkins release evidence
* signature verification reports

## Emergency Rollback

Use previous known-good image:

```bash
APP_IMAGE=demo-node-api \
APP_VERSION=<rollback-version> \
COMPOSE_FILES="compose.yaml compose.prod.yaml" \
./scripts/deploy-compose.sh
```

````

---

# 21. Create Jenkins Production Troubleshooting Notes

Create:

```bash id="zxvj24"
nano jenkins/production/runbooks/jenkins-production-troubleshooting.md
````

Paste:

````markdown id="agjcug"
# Jenkins Production Pipeline Troubleshooting

## Docker build fails

Check:

```bash
cd 05-application-runtime/demo-node-api
VERSION=test ./scripts/docker-build.sh
````

Common causes:

* Docker daemon unavailable
* Jenkins user lacks Docker permission
* wrong Dockerfile path
* `.dockerignore` excluded required file

## Trivy missing

Check:

```bash
trivy --version
```

Fix:

* install Trivy on Jenkins agent
* run Trivy in Docker
* use a dedicated security scanning agent

## GHCR login fails

Check:

* Jenkins credential ID: `ghcr-creds`
* token has package write permission
* registry image path is correct
* package access settings in GitHub

## Cosign signing fails

Check:

* `cosign-private-key` secret file exists
* `cosign-password` secret text exists
* image was pushed before signing
* cosign installed on agent

## Cosign verification fails

Check:

* `cosign-public-key` secret file exists
* correct image ref
* image was signed with matching private key
* signature was pushed to registry

## Production approval blocked

Check:

* build page input prompt
* user has permission to approve
* ROLLBACK_VERSION provided

## Deployment fails

Check:

```bash
docker ps
docker logs <container>
curl -v http://127.0.0.1:8080/health
curl -v http://127.0.0.1:8080/version
```

## Rollback fails

Check:

* rollback image still exists
* rollback version is correct
* registry credentials still work
* Compose files are valid

````

---

# 22. Jenkins Pipeline Security Review

This pipeline has good controls:

```text id="0w5l86"
secrets stored in Jenkins Credentials
GHCR push controlled by parameter
signing controlled by parameter
production approval uses input step
rollback version required
artifacts archived
no latest tag used
image tag includes version and Git SHA
````

Still improve later:

```text id="q23o11"
use dedicated Docker agent
use restricted deployment agent
add exact vulnerability policy
separate CI and CD jobs
add notifications
add branch restrictions
add role-based approval
integrate OPA/Kyverno later
use cloud roles instead of static cloud keys
```

---

# 23. Common Jenkins Production Mistakes

Avoid:

```text id="0tdlrm"
running builds on controller
hardcoding GHCR token
printing secrets
deploying latest
allowing production deploy without approval
deploying without rollback version
mixing every environment into one uncontrolled job
not archiving release evidence
using the same Jenkins credential for everything
giving all agents Docker socket access
```

Strong production rule:

```text id="2tuqpp"
Separate build trust, registry trust, and deployment trust.
```

---

# 24. Optional: Split CI and CD Jobs

The single Jenkinsfile is good for learning.

For real production, split:

```text id="fy6gx7"
Job 1: CI Build
  test
  build
  scan
  push
  sign
  metadata

Job 2: Staging Deploy
  takes image tag
  verifies image
  deploys staging

Job 3: Production Promote/Deploy
  takes approved image tag
  requires input
  verifies signature
  deploys production
```

Why split?

```text id="qjqzje"
separate permissions
separate approvals
separate agents
smaller blast radius
clearer audit trail
```

We will do that style in later deployment lessons.

---

# 25. Practical Lab

Run local validations:

```bash id="4kvded"
cd ~/devops-masterclass/08-cicd-pipelines

DIR=jenkins/production/pipelines ./jenkins/scripts/validate-jenkinsfiles.sh
cd ~/devops-masterclass
./08-cicd-pipelines/jenkins/production/scripts/validate-jenkins-production-files.sh
```

Check files:

```bash id="nmxri4"
find 08-cicd-pipelines/jenkins/production -type f | sort
```

Expected:

```text id="xd91nh"
08-cicd-pipelines/jenkins/production/notes/jenkins-production-pipeline.md
08-cicd-pipelines/jenkins/production/pipelines/Jenkinsfile.production
08-cicd-pipelines/jenkins/production/runbooks/jenkins-production-pipeline-runbook.md
08-cicd-pipelines/jenkins/production/runbooks/jenkins-production-troubleshooting.md
08-cicd-pipelines/jenkins/production/scripts/create-jenkins-release-evidence.sh
08-cicd-pipelines/jenkins/production/scripts/jenkins-compose-deploy.sh
08-cicd-pipelines/jenkins/production/scripts/validate-jenkins-production-files.sh
```

---

# 26. Commit Work

Run:

```bash id="t3gzrk"
cd ~/devops-masterclass

git status
git add 08-cicd-pipelines

git commit -m "feat: add Jenkins production pipeline"
git push
```

---

# 27. Interview Explanation

## What does your Jenkins production pipeline do?

Strong answer:

```text id="1nfv53"
My Jenkins production pipeline checks out the code, computes an immutable version-SHA tag, installs dependencies, runs tests, builds a Docker image, scans it, generates SBOM and provenance records, optionally pushes it to GHCR, optionally signs and verifies the image with Cosign, creates release metadata, records promotion, requires production approval, and archives all release evidence.
```

## How do you handle secrets in Jenkins?

Strong answer:

```text id="vvkckl"
I store secrets in Jenkins Credentials and access them with `withCredentials` or credential bindings. I do not hardcode tokens in the Jenkinsfile and I avoid printing secrets in logs.
```

## Why use parameters?

Strong answer:

```text id="3ao3zp"
Parameters let the same Jenkinsfile safely support different release modes, such as dev, rc, stable, push image, sign image, deploy staging, or request production approval.
```

## Why archive artifacts?

Strong answer:

```text id="jakkaf"
Archived artifacts preserve structured release evidence such as scan reports, SBOMs, provenance, promotion records, release metadata, and Jenkins evidence files. This supports debugging, audit, incident response, and rollback.
```

## Why require rollback version before production?

Strong answer:

```text id="j2ceey"
A production deployment should know the previous known-good artifact before it starts. If the new deployment fails, rollback should use a known immutable version, not guess from latest or rebuild under pressure.
```

## Why should Jenkins agents be restricted?

Strong answer:

```text id="6x6d9i"
Agents execute pipeline commands and may have access to Docker, credentials, or deployment targets. Docker socket access and production credentials are powerful, so they should only exist on trusted, restricted agents.
```

---

# 28. Today’s Core Rules

```text id="ar60aq"
Jenkins builds should run on agents.
Use Jenkinsfile as pipeline-as-code.
Use immutable version-SHA tags.
Do not deploy latest.
Use Jenkins Credentials for secrets.
Archive release evidence.
Scan images before promotion.
Generate SBOM and provenance.
Sign images when registry push is enabled.
Verify signatures before trusting artifacts.
Production approval must approve a specific artifact.
Rollback version is required for production.
Deployment access should be restricted.
Split CI and CD jobs in mature systems.
```

---

# Next Lesson

# Lesson 8.6 — GitLab CI Fundamentals

We will cover:

```text id="s1vwrr"
.gitlab-ci.yml
stages
jobs
script
before_script
after_script
variables
artifacts
cache
rules
only/except legacy concept
needs
services
Docker-in-Docker
GitLab runners
secrets/variables
environments
manual jobs
basic Node.js pipeline
GitLab CI vs GitHub Actions vs Jenkins
```

[1]: https://www.jenkins.io/doc/book/pipeline/jenkinsfile/?utm_source=chatgpt.com "Using a Jenkinsfile"
[2]: https://github.com/sigstore/cosign?utm_source=chatgpt.com "sigstore/cosign: Code signing and transparency ..."
[3]: https://www.jenkins.io/doc/book/pipeline/docker/?utm_source=chatgpt.com "Using Docker with Pipeline"
[4]: https://trivy.dev/docs/latest/supply-chain/sbom/?utm_source=chatgpt.com "SBOM"

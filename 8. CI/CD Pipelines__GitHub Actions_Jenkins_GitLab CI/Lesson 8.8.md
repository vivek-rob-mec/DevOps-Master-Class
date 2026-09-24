# Lesson 8.8 — Secrets and OIDC in CI/CD

# GitHub Secrets, GitLab Variables, Jenkins Credentials, OIDC, AWS Federation, Masking Limits, Rotation, Least Privilege, and Secret-Leak Incident Response

This lesson is extremely important.

A CI/CD system is powerful because it can:

```text id="73avt0"
read source code
build artifacts
push to registries
deploy to servers
modify cloud infrastructure
access production secrets
```

That also makes CI/CD one of the most dangerous places to leak credentials.

A weak pipeline can expose:

```text id="ax4l74"
AWS keys
registry tokens
SSH private keys
database passwords
Cosign private keys
Kubernetes kubeconfig
Terraform backend credentials
production API keys
```

So today we learn how to protect secrets and replace long-lived credentials with **OIDC short-lived cloud access** where possible.

GitHub’s OIDC documentation explains that workflows often need cloud access, and OIDC lets workflows request short-lived access tokens from a cloud provider instead of storing long-lived cloud credentials as GitHub secrets. ([GitHub Docs][1]) GitLab similarly supports CI/CD ID tokens for OIDC authentication with third-party services, including cloud services and secrets providers. ([GitLab Docs][2])

---

# 1. Beginner Level — What Is a CI/CD Secret?

A secret is any sensitive value that gives access to something.

Examples:

```text id="nziuk6"
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
GHCR_TOKEN
DOCKERHUB_TOKEN
SSH_PRIVATE_KEY
DATABASE_URL
KUBE_CONFIG
COSIGN_PASSWORD
COSIGN_PRIVATE_KEY
SLACK_WEBHOOK_URL
```

A secret is dangerous because anyone who gets it can often act as your pipeline.

Bad:

```yaml id="ck5788"
env:
  AWS_SECRET_ACCESS_KEY: "actual-secret-here"
```

Good:

```yaml id="lbufd6"
env:
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

Best when supported:

```text id="ab9fgd"
No long-lived AWS secret at all.
Use OIDC to request short-lived temporary credentials.
```

---

# 2. Why CI/CD Secrets Are High Risk

CI/CD secrets are dangerous because pipelines run automatically.

If an attacker gets control of a workflow, they may try to:

```text id="tsjk5w"
print secrets in logs
push malicious images
deploy malicious artifacts
read private registry images
modify AWS resources
exfiltrate kubeconfig
steal SSH keys
delete artifacts
disable security controls
```

Common leak locations:

```text id="63kz1z"
workflow YAML
Jenkinsfile
.gitlab-ci.yml
pipeline logs
debug output
environment dumps
artifact uploads
Docker image layers
npm config files
shell history
temporary files
build cache
```

Professional rule:

```text id="q78c4c"
A secret used by CI/CD should be treated as production infrastructure access.
```

---

# 3. The Best Secret Is No Static Secret

Old style:

```text id="al3mzz"
Create AWS IAM user
Generate access key
Store key in GitHub/GitLab/Jenkins
Pipeline uses key forever
```

Modern style:

```text id="9psbpm"
Configure cloud trust
Pipeline requests short-lived token
Cloud verifies pipeline identity
Cloud returns temporary credentials
Credentials expire automatically
```

This is the core value of OIDC.

```text id="dtgzui"
Long-lived static secret:
  dangerous if leaked

Short-lived OIDC credential:
  expires quickly and is bound to trusted identity conditions
```

GitHub’s AWS OIDC guide specifically describes configuring AWS to trust GitHub’s OIDC provider and using `aws-actions/configure-aws-credentials` to retrieve temporary credentials without storing AWS keys in GitHub. ([GitHub Docs][3]) GitLab’s AWS OIDC guide similarly shows using a GitLab CI/CD JWT to retrieve temporary AWS credentials without storing secrets. ([GitLab Docs][4])

---

# 4. Secret Storage by Platform

| Platform       | Secret Feature                     | Best Use                                        |
| -------------- | ---------------------------------- | ----------------------------------------------- |
| GitHub Actions | Repository/org/environment secrets | Tokens, API keys, SSH keys                      |
| GitLab CI      | Project/group CI/CD variables      | Tokens, deploy variables, protected secrets     |
| Jenkins        | Jenkins Credentials                | Username/password, secret text, files, SSH keys |
| AWS/GCP/Azure  | IAM/OIDC/federation                | Prefer for cloud access                         |
| Vault          | Dynamic secrets                    | Enterprise secrets workflows                    |

Professional rule:

```text id="qkn52c"
Use the native secret manager of the CI/CD platform, but prefer OIDC for cloud access when possible.
```

---

# 5. Secret Masking Is Not a Complete Defense

Secret masking hides exact secret values in logs.

But masking has limits.

Example:

```text id="5s20c0"
secret:
  abc123XYZ

masked log:
  ***
```

But secrets can still leak through:

```text id="jmeo6l"
base64 encoding
partial printing
JSON escaping
URL encoding
writing to artifact files
copying into Docker image layers
uploading environment dumps
debug shells
malicious scripts
```

GitHub’s secure-use reference says sensitive data should not be stored as plaintext in workflow files and recommends using masking for sensitive values that are not already GitHub secrets. It also explicitly includes guidance to delete and rotate exposed secrets. ([GitHub Docs][5])

Professional rule:

```text id="opew5y"
Masking reduces accidental exposure. It does not make unsafe secret handling safe.
```

---

# 6. Golden Rules for CI/CD Secrets

Use these everywhere:

```text id="9tywz7"
Never hardcode secrets.
Never echo secrets.
Never run env dumps in production pipelines.
Never store secrets in artifacts.
Never bake secrets into Docker images.
Never use production secrets in pull request workflows from forks.
Use least privilege.
Use short-lived credentials.
Use protected variables/environments.
Rotate secrets after exposure.
Separate build credentials from deploy credentials.
```

Bad debug command:

```bash id="453p2a"
env
```

Better debug:

```bash id="7z2wk6"
echo "Branch: $CI_COMMIT_BRANCH"
echo "Commit: $CI_COMMIT_SHA"
echo "Node: $(node --version)"
```

---

# 7. GitHub Actions Secrets

GitHub secrets are referenced with:

```yaml id="0y1tiu"
${{ secrets.SECRET_NAME }}
```

Example:

```yaml id="bssfcg"
env:
  GHCR_TOKEN: ${{ secrets.GHCR_TOKEN }}
```

Use GitHub secrets for:

```text id="sg9ogd"
third-party API tokens
non-cloud legacy credentials
SSH deploy keys
Docker Hub tokens
webhooks
```

Avoid storing AWS access keys when OIDC is available.

GitHub Actions workflows can access secrets through the `secrets` context, and GitHub provides separate repository, organization, and environment secret scopes. ([GitHub Docs][5])

---

# 8. GitHub Environment Secrets

Use environment secrets for environment-specific values:

```text id="8luut8"
staging:
  STAGING_SSH_KEY
  STAGING_HOST

production:
  PRODUCTION_SSH_KEY
  PRODUCTION_HOST
```

Pattern:

```yaml id="47jfu4"
jobs:
  deploy-production:
    environment: production
    steps:
      - run: echo "Deploying production"
```

Why this matters:

```text id="m3btqa"
production secrets are only available to jobs targeting production
production environment can require approval
staging and production secrets are separated
```

Professional rule:

```text id="2soolp"
Do not use one global secret for all environments.
```

---

# 9. GitHub OIDC to AWS

GitHub OIDC flow:

```text id="0za901"
GitHub workflow starts
  ↓
workflow requests OIDC token
  ↓
AWS trusts GitHub OIDC provider
  ↓
AWS evaluates IAM role trust policy
  ↓
AWS returns temporary credentials
  ↓
workflow uses AWS CLI
```

Workflow permissions required:

```yaml id="sk9c09"
permissions:
  contents: read
  id-token: write
```

The `id-token: write` permission allows a GitHub Actions workflow to request an OIDC token, and GitHub’s AWS guide shows using that token with `aws-actions/configure-aws-credentials` to assume an AWS role. ([GitHub Docs][3])

---

# 10. AWS Trust Policy for GitHub Actions

Create directory:

```bash id="4akzwf"
cd ~/devops-masterclass/08-cicd-pipelines

mkdir -p secrets-oidc/{notes,github-actions,gitlab,jenkins,scripts,policies,runbooks,reports,examples}
```

Create:

```bash id="jv4wcx"
nano secrets-oidc/policies/github-actions-aws-oidc-trust-policy.json
```

Paste:

```json id="qfseut"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowGitHubActionsAssumeRoleWithOIDC",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/devops-masterclass:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Replace:

```text id="pk8e1n"
123456789012
YOUR_GITHUB_USERNAME
```

Meaning:

```text id="haqzxm"
Only the main branch of this specific repository can assume this role.
```

For tags:

```json id="9lccnp"
"token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/devops-masterclass:ref:refs/tags/v*"
```

For GitHub environment:

```json id="43vlpr"
"token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/devops-masterclass:environment:production"
```

Professional rule:

```text id="yh6fqg"
OIDC trust policy must be narrow. Do not allow every branch and every repo.
```

---

# 11. GitHub Actions AWS OIDC Workflow

Create:

```bash id="ijqqct"
nano secrets-oidc/github-actions/aws-oidc-smoke-test.yml
```

Paste:

```yaml id="aatzyd"
name: AWS OIDC Smoke Test

on:
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

env:
  AWS_REGION: ap-south-1

jobs:
  aws-identity:
    runs-on: ubuntu-latest
    environment: staging

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials using OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_GITHUB_ACTIONS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Show AWS identity
        run: |
          aws sts get-caller-identity
```

Copy to real workflow path:

```bash id="5v94nr"
cd ~/devops-masterclass

cp 08-cicd-pipelines/secrets-oidc/github-actions/aws-oidc-smoke-test.yml \
   .github/workflows/aws-oidc-smoke-test.yml
```

In GitHub, create a secret:

```text id="dlt5cp"
AWS_GITHUB_ACTIONS_ROLE_ARN
```

Example value:

```text id="746se2"
arn:aws:iam::123456789012:role/github-actions-devops-masterclass-role
```

This is not a secret in the same way as an access key, but storing it as a secret keeps config tidy.

---

# 12. GitHub Actions OIDC ECR Push Pattern

Create:

```bash id="mm0989"
nano secrets-oidc/github-actions/ecr-push-with-oidc.yml
```

Paste:

```yaml id="9dt22s"
name: ECR Push With OIDC

on:
  workflow_dispatch:
    inputs:
      image_tag:
        description: "Image tag"
        required: true
        default: "0.8.0-dev-manual"

permissions:
  contents: read
  id-token: write

env:
  AWS_REGION: ap-south-1
  ECR_REPOSITORY: demo-node-api
  APP_DIR: 05-application-runtime/demo-node-api

jobs:
  build-push-ecr:
    runs-on: ubuntu-latest
    environment: staging

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials using OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_GITHUB_ACTIONS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Get AWS account ID
        id: aws
        run: |
          ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
          echo "account_id=$ACCOUNT_ID" >> "$GITHUB_OUTPUT"

      - name: Login to ECR
        run: |
          aws ecr get-login-password --region "$AWS_REGION" \
            | docker login \
                --username AWS \
                --password-stdin \
                "${{ steps.aws.outputs.account_id }}.dkr.ecr.${AWS_REGION}.amazonaws.com"

      - name: Build and push image
        run: |
          IMAGE_REF="${{ steps.aws.outputs.account_id }}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${{ inputs.image_tag }}"

          docker build \
            -f "$APP_DIR/Dockerfile.industry" \
            --target runtime \
            --build-arg APP_VERSION="${{ inputs.image_tag }}" \
            --build-arg COMMIT_SHA="${GITHUB_SHA::7}" \
            -t "$IMAGE_REF" \
            "$APP_DIR"

          docker push "$IMAGE_REF"

          echo "Pushed: $IMAGE_REF"
```

This uses no static AWS access key.

---

# 13. GitLab CI/CD Variables

GitLab stores secrets as CI/CD variables.

Use for:

```text id="xhkoxb"
Docker Hub token
external API token
SSH deploy key
legacy cloud key
rollback version
environment URL
```

Recommended settings:

```text id="5rw0mf"
Masked:
  hides value in logs when possible

Protected:
  only available on protected branches/tags

Environment-scoped:
  only available for matching environment
```

GitLab docs describe CI/CD variables, including masking, protected variables, and environment-scoped variables for controlling where variables are available. ([GitLab Docs][6])

Professional rule:

```text id="36z1qz"
Production variables should be protected and environment-scoped.
```

---

# 14. GitLab OIDC to AWS

GitLab OIDC flow:

```text id="56f1ac"
GitLab job starts
  ↓
GitLab generates ID token
  ↓
AWS trusts GitLab as OIDC provider
  ↓
job calls AWS STS AssumeRoleWithWebIdentity
  ↓
AWS returns temporary credentials
  ↓
job uses AWS CLI
```

GitLab says each job can be configured with ID tokens provided as CI/CD variables, and those JWTs can authenticate with OIDC-supported cloud providers such as AWS, Azure, GCP, and Vault. ([GitLab Docs][6])

---

# 15. AWS Trust Policy for GitLab

Create:

```bash id="jfcuoh"
nano secrets-oidc/policies/gitlab-aws-oidc-trust-policy.json
```

Paste:

```json id="bqg26u"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowGitLabAssumeRoleWithOIDC",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/gitlab.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "gitlab.com:aud": "https://gitlab.com"
        },
        "StringLike": {
          "gitlab.com:sub": "project_path:YOUR_GROUP/devops-masterclass:ref_type:branch:ref:main"
        }
      }
    }
  ]
}
```

Replace:

```text id="a8yogd"
123456789012
YOUR_GROUP
```

If self-managed GitLab is used, issuer and condition keys differ.

Professional rule:

```text id="seprvc"
GitLab OIDC trust policy must match your actual GitLab issuer and project identity.
```

---

# 16. GitLab AWS OIDC Example

Create:

```bash id="42nv82"
nano secrets-oidc/gitlab/.gitlab-ci.aws-oidc.yml
```

Paste:

```yaml id="qxq73s"
stages:
  - aws

variables:
  AWS_REGION: "ap-south-1"

aws_oidc_identity:
  stage: aws
  image:
    name: amazon/aws-cli:2
    entrypoint: [""]
  id_tokens:
    GITLAB_OIDC_TOKEN:
      aud: https://gitlab.com
  script:
    - |
      if [ -z "${AWS_ROLE_ARN:-}" ]; then
        echo "ERROR: AWS_ROLE_ARN CI/CD variable is required" >&2
        exit 1
      fi

      CREDS="$(aws sts assume-role-with-web-identity \
        --role-arn "$AWS_ROLE_ARN" \
        --role-session-name "GitLab-${CI_PROJECT_ID}-${CI_PIPELINE_ID}" \
        --web-identity-token "$GITLAB_OIDC_TOKEN" \
        --duration-seconds 3600 \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text)"

      export AWS_ACCESS_KEY_ID="$(echo "$CREDS" | awk '{print $1}')"
      export AWS_SECRET_ACCESS_KEY="$(echo "$CREDS" | awk '{print $2}')"
      export AWS_SESSION_TOKEN="$(echo "$CREDS" | awk '{print $3}')"

      aws sts get-caller-identity
```

GitLab’s AWS OIDC guide shows using a job token with `aws sts assume-role-with-web-identity` to retrieve temporary credentials from AWS without storing static AWS secrets. ([GitLab Docs][4])

---

# 17. Jenkins Credentials

Jenkins stores credentials centrally.

Credential types:

```text id="kl316p"
secret text
username/password
secret file
SSH username with private key
certificate
AWS credentials via plugins
```

Jenkins credentials can be added through Jenkins Credentials management, and Jenkins permissions control who can create/manage credentials. ([Jenkins][7]) The Credentials Binding plugin exposes credentials to Pipeline steps as environment variables only within the binding scope. ([Jenkins][8])

Good Jenkins pattern:

```groovy id="0y9qsj"
withCredentials([string(credentialsId: 'ghcr-token', variable: 'GHCR_TOKEN')]) {
  sh '''
    echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
  '''
}
```

Bad:

```groovy id="o59opu"
sh 'docker login ghcr.io -u user -p actual-token'
```

---

# 18. Jenkins Secure Credentials Example

Create:

```bash id="cf1hr8"
nano secrets-oidc/jenkins/Jenkinsfile.credentials-safe
```

Paste:

```groovy id="s1jt1x"
pipeline {
  agent any

  environment {
    GITHUB_USERNAME = 'YOUR_GITHUB_USERNAME'
  }

  stages {
    stage('Safe GHCR Login') {
      steps {
        withCredentials([string(credentialsId: 'ghcr-token', variable: 'GHCR_TOKEN')]) {
          sh '''
            set +x
            echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
            docker logout ghcr.io || true
          '''
        }
      }
    }

    stage('Safe Secret File Use') {
      steps {
        withCredentials([file(credentialsId: 'cosign-private-key', variable: 'COSIGN_KEY_FILE')]) {
          sh '''
            set +x
            test -f "$COSIGN_KEY_FILE"
            echo "Secret file exists and was used without printing its content."
          '''
        }
      }
    }
  }

  post {
    always {
      sh 'docker logout ghcr.io || true'
    }
  }
}
```

Important details:

```text id="xwwztj"
set +x prevents shell command tracing
do not cat secret files
do not echo secret values
scope credentials only around the commands that need them
```

Jenkins warns that credentials should not be used by untrusted Pipeline jobs, and credential access depends on item/folder credential visibility. ([Jenkins][9])

---

# 19. Jenkins and OIDC

Jenkins OIDC is not as standardized out-of-the-box as GitHub Actions OIDC.

Common Jenkins cloud-auth patterns:

```text id="u74n2e"
Jenkins agent runs on EC2 with instance profile
Jenkins agent runs in EKS with IRSA/pod identity
Jenkins uses Vault to generate dynamic cloud credentials
Jenkins uses AWS STS assume-role from a base credential
Jenkins uses cloud-specific credentials plugin
```

Best pattern for AWS-hosted Jenkins agents:

```text id="ljrwvu"
Attach a least-privilege IAM role to the Jenkins agent.
Do not store AWS access keys in Jenkins if the agent can use instance metadata safely.
```

Example:

```bash id="oxj4b8"
aws sts get-caller-identity
```

If this works on the Jenkins agent without secrets, the agent likely has IAM role access.

Professional rule:

```text id="qqk2l7"
For Jenkins, prefer workload identity or instance roles over static AWS keys where your infrastructure supports it.
```

---

# 20. Secret Scope Matrix

Create:

```bash id="le85fl"
nano secrets-oidc/notes/secret-scope-matrix.md
```

Paste:

```markdown id="ehy6gc"
# Secret Scope Matrix

| Secret | Scope | Platform | Environment | Notes |
|---|---|---|---|---|
| GHCR push token | CI publish job only | Jenkins/GitHub | build | Should not be available to deploy-only jobs |
| Docker Hub token | CI publish job only | all | build | Prefer org token with least privilege |
| AWS deploy role | OIDC role | GitHub/GitLab | staging/prod | Prefer short-lived credentials |
| SSH staging key | environment secret | GitHub/GitLab/Jenkins | staging | Do not expose to PRs |
| SSH production key | protected environment secret | all | production | Approval/protected branch required |
| Cosign private key | Jenkins secret file | Jenkins | build/sign | Do not archive or print |
| Cosign password | secret text | Jenkins | build/sign | Rotate if exposed |
| Database URL | runtime secret manager | deploy platform | environment-specific | Do not bake into image |
| Rollback version | protected variable | GitLab/GitHub/Jenkins parameter | production | Not sensitive, but production-critical |
```

---

# 21. Secret Handling Policy

Create:

```bash id="qzv8sg"
nano secrets-oidc/notes/cicd-secrets-policy.md
```

Paste:

```markdown id="7us9gx"
# CI/CD Secrets Policy

## Rules

- Do not hardcode secrets in workflow files.
- Do not echo secrets.
- Do not upload secrets as artifacts.
- Do not store secrets in Docker images.
- Do not expose production secrets to pull requests.
- Use environment-specific secrets.
- Use protected variables for production.
- Use least privilege.
- Prefer OIDC for cloud access.
- Prefer short-lived credentials.
- Rotate secrets after exposure.
- Delete unused secrets.
- Audit secret access regularly.

## GitHub Actions

- Use repository/org/environment secrets.
- Use `id-token: write` only when OIDC is needed.
- Use environment approvals for production.
- Avoid broad `permissions: write-all`.

## GitLab CI

- Use CI/CD variables.
- Use masked variables for sensitive values.
- Use protected variables for production.
- Use environment-scoped variables.
- Use OIDC ID tokens where possible.

## Jenkins

- Use Jenkins Credentials.
- Use `withCredentials`.
- Restrict credentials by folder/job where possible.
- Do not allow untrusted Jenkinsfiles to access trusted credentials.
- Prefer instance roles or dynamic secrets for cloud access.
```

---

# 22. GitHub Secure AWS Deployment Pattern

Create:

```bash id="8l5vys"
nano secrets-oidc/github-actions/secure-aws-deploy-pattern.yml
```

Paste:

```yaml id="8wt6sk"
name: Secure AWS Deploy Pattern

on:
  workflow_dispatch:
    inputs:
      image_tag:
        required: true
        description: "Immutable image tag to deploy"

permissions:
  contents: read
  id-token: write

env:
  AWS_REGION: ap-south-1

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment: staging

    steps:
      - uses: actions/checkout@v4

      - name: Validate immutable tag
        run: |
          case "${{ inputs.image_tag }}" in
            latest|prod|production|stable)
              echo "Refusing mutable tag"
              exit 1
              ;;
          esac

      - name: Configure AWS credentials with OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_STAGING_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Deploy placeholder
        run: |
          aws sts get-caller-identity
          echo "Deploy staging image tag: ${{ inputs.image_tag }}"

  deploy-production:
    runs-on: ubuntu-latest
    environment: production
    needs: deploy-staging

    steps:
      - uses: actions/checkout@v4

      - name: Validate rollback input exists
        run: |
          echo "Production deployment must include rollback metadata in real workflow."

      - name: Configure AWS credentials with OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_PRODUCTION_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Production deploy placeholder
        run: |
          aws sts get-caller-identity
          echo "Production deploy requires environment approval."
```

Why separate roles?

```text id="j4gqwe"
staging role can deploy staging only
production role can deploy production only
```

Professional rule:

```text id="cbn0zx"
Do not use one AWS role for every environment.
```

---

# 23. Secret Leak Detection Script

Create:

```bash id="blbbce"
nano secrets-oidc/scripts/detect-secret-patterns.sh
```

Paste:

```bash id="l1z3h3"
#!/usr/bin/env bash
set -euo pipefail

SCAN_DIR="${SCAN_DIR:-.}"
REPORT_DIR="${REPORT_DIR:-08-cicd-pipelines/secrets-oidc/reports}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/secret-pattern-scan-$TIMESTAMP.txt"

mkdir -p "$REPORT_DIR"

echo "===== Secret Pattern Scan ====="
echo "Scan dir: $SCAN_DIR"
echo "Report: $REPORT_FILE"

{
  echo "Secret pattern scan generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo

  echo "## AWS access key-like patterns"
  grep -RInE 'AKIA[0-9A-Z]{16}' "$SCAN_DIR" \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude-dir=coverage \
    --exclude-dir=reports \
    || true

  echo
  echo "## Possible private keys"
  grep -RInE 'BEGIN (RSA |OPENSSH |EC |DSA |)PRIVATE KEY' "$SCAN_DIR" \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude-dir=coverage \
    --exclude-dir=reports \
    || true

  echo
  echo "## Possible hardcoded passwords/tokens"
  grep -RInE '(password|passwd|token|secret|api_key|apikey)[[:space:]]*[:=][[:space:]]*["'\'']?[A-Za-z0-9_./+=-]{12,}' "$SCAN_DIR" \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude-dir=coverage \
    --exclude-dir=reports \
    || true

} | tee "$REPORT_FILE"

echo
echo "Scan completed. Review findings manually."
```

Make executable:

```bash id="h4b33d"
chmod +x secrets-oidc/scripts/detect-secret-patterns.sh
```

Run:

```bash id="wrty3o"
cd ~/devops-masterclass

./08-cicd-pipelines/secrets-oidc/scripts/detect-secret-patterns.sh
```

Note:

```text id="xpyoj8"
This is a simple learning scanner. Use professional tools like GitHub secret scanning, GitLab secret detection, Gitleaks, TruffleHog, or enterprise scanners for real production.
```

---

# 24. Secret Inventory Script

Create:

```bash id="5j2r34"
cd ~/devops-masterclass/08-cicd-pipelines

nano secrets-oidc/scripts/create-secret-inventory-template.sh
```

Paste:

```bash id="p7nxqf"
#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${OUTPUT_DIR:-secrets-oidc/reports}"
OUTPUT_FILE="$OUTPUT_DIR/secret-inventory-template.json"

mkdir -p "$OUTPUT_DIR"

cat > "$OUTPUT_FILE" <<'EOF'
{
  "service_name": "demo-node-api",
  "inventory_version": "1.0",
  "secrets": [
    {
      "name": "AWS_GITHUB_ACTIONS_ROLE_ARN",
      "platform": "GitHub Actions",
      "type": "role_arn",
      "environment": "staging",
      "sensitivity": "low_config",
      "rotation_required": false,
      "notes": "Role ARN used for OIDC assume role; not a static secret"
    },
    {
      "name": "AWS_STAGING_ROLE_ARN",
      "platform": "GitHub Actions",
      "type": "role_arn",
      "environment": "staging",
      "sensitivity": "low_config",
      "rotation_required": false,
      "notes": "OIDC role ARN"
    },
    {
      "name": "AWS_PRODUCTION_ROLE_ARN",
      "platform": "GitHub Actions",
      "type": "role_arn",
      "environment": "production",
      "sensitivity": "low_config",
      "rotation_required": false,
      "notes": "OIDC role ARN"
    },
    {
      "name": "ghcr-creds",
      "platform": "Jenkins",
      "type": "username_password",
      "environment": "build",
      "sensitivity": "high",
      "rotation_required": true,
      "notes": "Used to push images to GHCR"
    },
    {
      "name": "cosign-private-key",
      "platform": "Jenkins",
      "type": "secret_file",
      "environment": "build_sign",
      "sensitivity": "critical",
      "rotation_required": true,
      "notes": "Used for image signing"
    },
    {
      "name": "PRODUCTION_ROLLBACK_VERSION",
      "platform": "GitLab CI",
      "type": "protected_variable",
      "environment": "production",
      "sensitivity": "operational",
      "rotation_required": false,
      "notes": "Not secret, but production-critical"
    }
  ]
}
EOF

cat "$OUTPUT_FILE" | jq .
echo "Inventory template written: $OUTPUT_FILE"
```

Make executable:

```bash id="2nuw7n"
chmod +x secrets-oidc/scripts/create-secret-inventory-template.sh
```

Run:

```bash id="r6swmb"
./secrets-oidc/scripts/create-secret-inventory-template.sh
```

---

# 25. Secret Rotation Runbook

Create:

```bash id="48e1q2"
nano secrets-oidc/runbooks/secret-rotation-runbook.md
```

Paste:

```markdown id="9wcijq"
# Secret Rotation Runbook

## When to Rotate

Rotate secrets when:

- secret is exposed in logs
- secret is committed to Git
- employee/user access changes
- token is older than policy allows
- permissions are changed
- suspicious activity is detected
- vendor/tool recommends rotation

## Rotation Steps

1. Identify the secret and where it is used.
2. Create replacement secret with least privilege.
3. Add replacement to CI/CD secret store.
4. Run pipeline in staging.
5. Switch production pipeline to new secret.
6. Revoke old secret.
7. Confirm old secret no longer works.
8. Document rotation record.

## Emergency Rotation

1. Stop affected pipelines.
2. Revoke exposed secret immediately.
3. Rotate dependent credentials.
4. Review logs for misuse.
5. Deploy known-good artifact if needed.
6. Create incident record.
7. Add prevention controls.

## Never

- rotate blindly without knowing consumers
- leave old token active after replacement
- paste new token in chat/email
- print token to validate it
```

---

# 26. Secret Leak Incident Runbook

Create:

```bash id="poy1ie"
nano secrets-oidc/runbooks/secret-leak-incident-response.md
```

Paste:

```markdown id="txsysy"
# Secret Leak Incident Response

## Immediate Actions

1. Stop affected pipeline if still running.
2. Revoke exposed credential.
3. Rotate replacement credential.
4. Check pipeline logs and artifacts.
5. Check registry/cloud audit logs.
6. Identify blast radius.
7. Remove leaked secret from repository history if committed.
8. Invalidate caches/artifacts that may contain the secret.
9. Re-run deployment only with trusted credentials.
10. Document incident.

## AWS Key Leak

- Disable or delete access key.
- Review CloudTrail.
- Check IAM user/role activity.
- Rotate dependent secrets.
- Prefer replacing with OIDC.

## Registry Token Leak

- Revoke token.
- Review image push/delete events.
- Check for suspicious tags.
- Verify signatures/provenance.
- Rotate token with reduced scope.

## SSH Key Leak

- Remove public key from server.
- Rotate key.
- Review auth logs.
- Check deployed files.
- Restrict new key to required commands if possible.

## Cosign Key Leak

- Stop trusting affected key.
- Generate new key pair.
- Re-sign trusted artifacts if required.
- Update verification policy.
- Investigate forged signatures.
```

---

# 27. Least Privilege Examples

## Bad AWS policy

```json id="icppxx"
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}
```

## Better ECR push policy

```json id="k7vel1"
{
  "Effect": "Allow",
  "Action": [
    "ecr:BatchCheckLayerAvailability",
    "ecr:CompleteLayerUpload",
    "ecr:InitiateLayerUpload",
    "ecr:PutImage",
    "ecr:UploadLayerPart",
    "ecr:BatchGetImage",
    "ecr:DescribeImages"
  ],
  "Resource": "arn:aws:ecr:ap-south-1:123456789012:repository/demo-node-api"
}
```

## Better deploy policy

```text id="g7h1r5"
Only update the target service.
Only read required registry images.
Only access one environment.
No wildcard admin access.
```

Professional rule:

```text id="8i0v8e"
Least privilege means both action scope and resource scope are limited.
```

---

# 28. Environment Separation Pattern

Use separate identities:

```text id="acdh69"
github-actions-staging-role
github-actions-production-role
gitlab-staging-role
gitlab-production-role
jenkins-build-role
jenkins-deploy-role
```

Do not use:

```text id="78z85d"
one mega CI/CD admin role
```

Good environment split:

```text id="ei3r3g"
build role:
  push image

staging deploy role:
  deploy staging

production deploy role:
  deploy production

security audit role:
  read scan/log data
```

Professional rule:

```text id="4i0ws0"
Build credentials and deploy credentials should be separate.
```

---

# 29. Add Makefile Targets

Open:

```bash id="pb4g12"
cd ~/devops-masterclass/08-cicd-pipelines

nano Makefile
```

Add:

```Makefile id="se5zfp"
.PHONY: secrets-scan secrets-inventory list-secrets-oidc

secrets-scan:
	cd $(ROOT_DIR) && ./08-cicd-pipelines/secrets-oidc/scripts/detect-secret-patterns.sh

secrets-inventory:
	./secrets-oidc/scripts/create-secret-inventory-template.sh

list-secrets-oidc:
	find secrets-oidc -type f | sort
```

Run:

```bash id="0fswzn"
make secrets-inventory
make list-secrets-oidc
```

Run scanner from repo root:

```bash id="3dw4q6"
make secrets-scan
```

---

# 30. Validation Checklist

Run:

```bash id="bn6rwm"
cd ~/devops-masterclass/08-cicd-pipelines

test -f secrets-oidc/policies/github-actions-aws-oidc-trust-policy.json
test -f secrets-oidc/policies/gitlab-aws-oidc-trust-policy.json
test -f secrets-oidc/github-actions/aws-oidc-smoke-test.yml
test -f secrets-oidc/gitlab/.gitlab-ci.aws-oidc.yml
test -f secrets-oidc/jenkins/Jenkinsfile.credentials-safe
test -x secrets-oidc/scripts/detect-secret-patterns.sh
test -x secrets-oidc/scripts/create-secret-inventory-template.sh

echo "Lesson 8.8 files validated."
```

---

# 31. Practical Lab

Run:

```bash id="lhemp6"
cd ~/devops-masterclass/08-cicd-pipelines

mkdir -p secrets-oidc/{notes,github-actions,gitlab,jenkins,scripts,policies,runbooks,reports,examples}

make secrets-inventory
make list-secrets-oidc
```

Optional scan:

```bash id="cwbkj5"
cd ~/devops-masterclass
./08-cicd-pipelines/secrets-oidc/scripts/detect-secret-patterns.sh
```

Copy GitHub OIDC workflow:

```bash id="07417c"
mkdir -p .github/workflows

cp 08-cicd-pipelines/secrets-oidc/github-actions/aws-oidc-smoke-test.yml \
   .github/workflows/aws-oidc-smoke-test.yml
```

Commit:

```bash id="yizf0u"
git status
git add 08-cicd-pipelines/secrets-oidc .github/workflows/aws-oidc-smoke-test.yml

git commit -m "feat: add CI/CD secrets and OIDC security patterns"
git push
```

---

# 32. Common Mistakes

Avoid:

```text id="k6xocv"
putting AWS keys in workflow YAML
using AWS admin user for CI
using one secret for all environments
printing env in logs
uploading .env files as artifacts
using production secrets in PR workflows
using unprotected GitLab variables for production
allowing untrusted Jenkinsfiles to access credentials
using broad OIDC trust policies
using wildcard IAM permissions
not rotating exposed secrets
```

Bad OIDC trust:

```json id="fbhr8s"
"token.actions.githubusercontent.com:sub": "repo:*"
```

Better:

```json id="3bqjsv"
"token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/devops-masterclass:ref:refs/heads/main"
```

Best for production:

```text id="dndxjy"
specific repo
specific branch/tag/environment
specific AWS role
specific permissions
```

---

# 33. Interview Explanation

## What is OIDC in CI/CD?

Strong answer:

```text id="eq8uvo"
OIDC lets a CI/CD job prove its identity to a cloud provider and receive short-lived credentials without storing long-lived access keys in the CI/CD platform. The cloud provider validates claims such as repository, branch, tag, or environment before allowing the job to assume a role.
```

## Why is OIDC better than static AWS keys?

Strong answer:

```text id="bzwhsi"
Static AWS keys are long-lived and dangerous if leaked. OIDC uses short-lived credentials and trust policies tied to pipeline identity, such as a specific repository and branch. This reduces secret storage and limits blast radius.
```

## How do you protect secrets in GitHub Actions?

Strong answer:

```text id="m4ma49"
I store secrets in GitHub repository, organization, or environment secrets; use explicit minimal workflow permissions; avoid printing secrets; use environment approvals for production; and prefer OIDC for cloud credentials instead of storing AWS access keys.
```

## How do you protect secrets in GitLab CI?

Strong answer:

```text id="oij5hx"
I use GitLab CI/CD variables with masking, protection, and environment scoping. Production variables are protected and only available on protected branches or tags. For cloud access, I prefer GitLab ID tokens and OIDC to retrieve short-lived credentials.
```

## How do you protect secrets in Jenkins?

Strong answer:

```text id="vkv2e8"
I store secrets in Jenkins Credentials and access them with `withCredentials` only around the steps that need them. I avoid echoing secrets, restrict credential visibility, prevent untrusted Jenkinsfiles from accessing trusted credentials, and prefer instance roles or dynamic secrets for cloud access.
```

## What should you do if a secret leaks?

Strong answer:

```text id="j6icm6"
I would stop affected pipelines, revoke the leaked secret, rotate it, check logs and artifacts for exposure, review cloud or registry audit logs, identify suspicious activity, remove the secret from source history if committed, invalidate caches if needed, and document the incident with prevention steps.
```

---

# 34. Today’s Core Rules

```text id="9osid4"
Never hardcode secrets.
Never echo secrets.
Never upload secrets as artifacts.
Never bake secrets into Docker images.
Use platform secret stores.
Use environment-specific secrets.
Use protected variables for production.
Use least privilege.
Prefer OIDC for cloud access.
OIDC trust policies must be narrow.
Separate build and deploy credentials.
Do not expose production secrets to PRs.
Masking is not a complete defense.
Rotate exposed secrets immediately.
Audit secret access.
Use short-lived credentials wherever possible.
```

---

# Next Lesson

# Lesson 8.9 — Quality Gates and DevSecOps Checks in CI/CD

We will build production-grade gates for:

```text id="bk7jcz"
linting
format checks
unit tests
integration tests
coverage thresholds
Dockerfile checks
secret scanning
dependency scanning
container image scanning
SBOM validation
license policy
IaC scanning
policy-as-code
fail vs warn strategy
quality gate reports
GitHub Actions implementation
Jenkins implementation
GitLab CI implementation
```

[1]: https://docs.github.com/en/actions/concepts/security/openid-connect?utm_source=chatgpt.com "OpenID Connect"
[2]: https://docs.gitlab.com/ci/secrets/id_token_authentication/?utm_source=chatgpt.com "OpenID Connect (OIDC) Authentication Using ID Tokens"
[3]: https://docs.github.com/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services?utm_source=chatgpt.com "Configuring OpenID Connect in Amazon Web Services"
[4]: https://docs.gitlab.com/ci/cloud_services/aws/?utm_source=chatgpt.com "Configure OpenID Connect in AWS to retrieve temporary ..."
[5]: https://docs.github.com/en/actions/reference/security/secure-use?utm_source=chatgpt.com "Secure use reference - GitHub Docs"
[6]: https://docs.gitlab.com/ci/cloud_services/?utm_source=chatgpt.com "Connect to cloud services"
[7]: https://www.jenkins.io/doc/book/using/using-credentials/?utm_source=chatgpt.com "Using credentials"
[8]: https://www.jenkins.io/doc/pipeline/steps/credentials-binding/?utm_source=chatgpt.com "Credentials Binding Plugin"
[9]: https://www.jenkins.io/doc/book/pipeline/jenkinsfile/?utm_source=chatgpt.com "Using a Jenkinsfile"

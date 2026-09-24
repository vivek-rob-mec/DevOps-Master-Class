# Module 8 — CI/CD Pipelines

# Lesson 8.1 — CI/CD Mental Model Masterclass

# GitHub Actions, Jenkins, GitLab CI, Stages, Jobs, Steps, Runners, Agents, Artifacts, Gates, Deployments, and Rollbacks

You completed:

```text id="tdmpgf"
Module 7 — Artifact Management and Registries
```

Now we start:

```text id="d8slk6"
Module 8 — CI/CD Pipelines
```

This module will connect everything you built so far:

```text id="qwi8oo"
Git
Linux
Python automation
production app runtime
Docker
registries
SBOM
provenance
signing
promotion
cleanup
```

into real CI/CD systems:

```text id="szqldk"
GitHub Actions
Jenkins
GitLab CI
```

A GitHub Actions workflow is a configurable automated process made up of one or more jobs, defined in YAML. Jenkins Pipeline uses stages and steps to define what Jenkins executes. GitLab CI/CD pipelines are made of jobs and stages, where stages define execution order and jobs define tasks. ([GitHub Docs][1])

---

# 1. What CI/CD Really Means

CI/CD is not just:

```text id="i31g2r"
run some commands after git push
```

CI/CD is a controlled automation system for moving code safely from source to production.

```text id="m06fwp"
source code
  ↓
validate
  ↓
test
  ↓
build
  ↓
scan
  ↓
package
  ↓
publish artifact
  ↓
promote
  ↓
deploy
  ↓
verify
  ↓
rollback if needed
```

Professional definition:

```text id="r9rl3e"
CI/CD is the automated and governed path from code change to verified runtime.
```

---

# 2. CI vs CD

## CI — Continuous Integration

CI answers:

```text id="rbxqph"
Did this code change integrate safely?
```

CI usually includes:

```text id="o2t0it"
checkout source
install dependencies
lint
unit tests
integration tests
build
security scan
artifact creation
```

Example:

```text id="6zl0jv"
Developer pushes code
  ↓
CI runs tests
  ↓
CI builds Docker image
  ↓
CI publishes artifact
```

---

## CD — Continuous Delivery / Deployment

CD answers:

```text id="zscsmb"
Can this artifact be delivered safely to an environment?
```

Continuous Delivery:

```text id="d6m52l"
artifact is ready for production
human approval may be required
```

Continuous Deployment:

```text id="na6g7k"
artifact automatically reaches production after passing gates
```

Professional difference:

```text id="tcj1t3"
Continuous Delivery prepares production-ready artifacts.
Continuous Deployment automatically deploys them to production.
```

For production systems, many companies use:

```text id="ej96v2"
automatic CI
automatic dev deploy
automatic staging deploy
manual approval for production
automatic production deployment after approval
```

---

# 3. Beginner Mental Model

Think of CI/CD like an airport security system.

```text id="jzudss"
source code = passenger
pipeline = airport process
quality gates = security checks
artifact = boarding pass / approved package
deployment = flight
monitoring = arrival confirmation
rollback = emergency return plan
```

A weak pipeline asks:

```text id="pw9otx"
Did the command finish?
```

A strong pipeline asks:

```text id="wbhxmi"
Was the code tested?
Was the artifact built once?
Was it scanned?
Was it signed?
Was it promoted?
Was deployment verified?
Can we rollback?
Do we know what is running?
```

---

# 4. CI/CD Core Vocabulary

## Pipeline

A pipeline is the full automated workflow.

```text id="weae8o"
test -> build -> scan -> publish -> deploy
```

## Stage

A stage is a logical phase.

```text id="u6a5at"
test
build
scan
deploy
```

## Job

A job is a unit of work usually running on one runner/agent.

```text id="wx8thn"
backend-tests
docker-build
security-scan
deploy-staging
```

## Step

A step is one command or action inside a job.

```text id="6hlvz5"
npm ci
npm test
docker build
docker push
```

GitHub Actions jobs are sets of steps executed on the same runner, and each step can run a shell script or an action. ([GitHub Docs][2])

## Runner / Agent

The machine that executes pipeline jobs.

```text id="jix9av"
GitHub Actions runner
Jenkins agent
GitLab runner
```

## Artifact

The output of a pipeline.

```text id="ca3u8x"
Docker image
tar.gz package
SBOM
test report
coverage report
release metadata
deployment report
```

## Gate

A condition that must pass before moving forward.

```text id="y0cjvs"
tests passed
scan passed
manual approval
signature verified
health check passed
```

---

# 5. Universal CI/CD Flow

This flow applies to GitHub Actions, Jenkins, GitLab CI, Azure DevOps, CircleCI, and most CI/CD platforms.

```text id="p1z5n1"
Trigger
  ↓
Checkout
  ↓
Setup runtime
  ↓
Install dependencies
  ↓
Static checks
  ↓
Tests
  ↓
Build artifact
  ↓
Scan artifact
  ↓
Publish artifact
  ↓
Generate metadata
  ↓
Promote artifact
  ↓
Deploy
  ↓
Verify
  ↓
Rollback if needed
```

For your project:

```text id="atxap5"
Git push
  ↓
checkout repo
  ↓
setup Node.js
  ↓
npm ci
  ↓
npm test
  ↓
docker build
  ↓
Trivy/Docker Scout scan
  ↓
generate SBOM
  ↓
push image to GHCR/ECR
  ↓
create release metadata
  ↓
promote to staging
  ↓
deploy Compose stack
  ↓
curl /health and /version
  ↓
rollback if failed
```

---

# 6. GitHub Actions Mental Model

GitHub Actions structure:

```text id="2gzdr7"
.github/workflows/workflow-name.yml
  workflow
    jobs
      job
        steps
```

Example:

```yaml id="szt2l1"
name: CI

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Run tests
        run: npm test
```

GitHub Actions workflow syntax defines workflows using YAML files, and workflows are made up of jobs. ([GitHub Docs][1])

Mental model:

```text id="i1d5ge"
workflow = entire automation
job      = work unit on runner
step     = command/action
runner   = VM/container machine executing job
```

---

# 7. Jenkins Mental Model

Jenkins structure:

```text id="qxuqbg"
Jenkinsfile
  pipeline
    agent
    stages
      stage
        steps
```

Example:

```groovy id="8gh5dc"
pipeline {
  agent any

  stages {
    stage('Test') {
      steps {
        sh 'npm test'
      }
    }
  }
}
```

Jenkins Declarative Pipeline uses `stages` and `steps`; the `stages` and `steps` directives tell Jenkins what to execute and in which stage. ([Jenkins][3])

Mental model:

```text id="mcoq49"
pipeline = full Jenkins automation
agent    = machine/executor
stage    = visible phase
steps    = actual commands
```

Your previous Jenkins work already used this pattern:

```text id="2d9mka"
artifact handling
atomic deployment
PM2 restart
runtime validation
rollback
```

Now we will formalize it.

---

# 8. GitLab CI Mental Model

GitLab CI structure:

```text id="ozygy0"
.gitlab-ci.yml
  stages
  jobs
    script
```

Example:

```yaml id="jka8vp"
stages:
  - test
  - build
  - deploy

test:
  stage: test
  script:
    - npm test
```

GitLab CI jobs are configured in `.gitlab-ci.yml`, and jobs execute on runners. GitLab stages define order; jobs in the same stage can run in parallel, and later stages usually run only if earlier stages succeed. ([GitLab Docs][4])

Mental model:

```text id="i4uyeg"
pipeline = full automation
stage    = ordered phase
job      = task assigned to a runner
script   = commands inside job
runner   = execution machine
```

---

# 9. GitHub Actions vs Jenkins vs GitLab CI

| Feature           | GitHub Actions                                | Jenkins                              | GitLab CI               |
| ----------------- | --------------------------------------------- | ------------------------------------ | ----------------------- |
| Pipeline file     | `.github/workflows/*.yml`                     | `Jenkinsfile`                        | `.gitlab-ci.yml`        |
| Execution machine | Runner                                        | Agent/node                           | Runner                  |
| Main unit         | Workflow/job/step                             | Pipeline/stage/step                  | Pipeline/stage/job      |
| Best for          | GitHub-native CI/CD                           | Highly customizable enterprise CI/CD | GitLab-native DevSecOps |
| Setup             | Mostly managed if using GitHub-hosted runners | Self-managed or controller/agents    | Managed or self-managed |
| Flexibility       | High                                          | Very high                            | High                    |
| Maintenance       | Lower for simple projects                     | Higher, especially plugins/agents    | Medium                  |

Professional summary:

```text id="7hogca"
GitHub Actions is excellent for GitHub-native projects.
Jenkins is excellent when you need deep customization and self-managed control.
GitLab CI is excellent when your source, CI, registry, and DevSecOps are in GitLab.
```

---

# 10. CI/CD Pipeline Maturity Levels

## Level 1 — Basic CI

```text id="yr3jxs"
run tests on push
```

## Level 2 — Build pipeline

```text id="i7y8es"
test
build artifact
save artifact
```

## Level 3 — Container pipeline

```text id="l2pgcu"
test
build Docker image
push to registry
```

## Level 4 — Secure artifact pipeline

```text id="8x06g6"
test
build
scan
SBOM
provenance
sign
push
```

## Level 5 — Delivery pipeline

```text id="be3qpm"
promote
deploy staging
verify
approve production
deploy production
rollback
```

## Level 6 — Enterprise pipeline

```text id="9rlxyn"
policy-as-code
signed artifacts
admission control
change records
audit
observability
SLO-aware rollout
progressive delivery
```

Your target:

```text id="50r7fv"
Level 5 now.
Level 6 later with Kubernetes, GitOps, DevSecOps, and SRE.
```

---

# 11. Module 8 Folder Setup

Run:

```bash id="ckqkg3"
cd ~/devops-masterclass

mkdir -p 08-cicd-pipelines/{notes,github-actions,jenkins,gitlab,shared-scripts,runbooks,reports,examples,capstone}
```

Check:

```bash id="o8qvxy"
tree -L 2 08-cicd-pipelines
```

Expected:

```text id="42tbfk"
08-cicd-pipelines
├── capstone
├── examples
├── github-actions
├── gitlab
├── jenkins
├── notes
├── reports
├── runbooks
└── shared-scripts
```

---

# 12. Create CI/CD Mental Model Notes

Create:

```bash id="vc67wl"
cd ~/devops-masterclass/08-cicd-pipelines

nano notes/ci-cd-mental-model.md
```

Paste:

````markdown id="btk780"
# CI/CD Mental Model

## What CI/CD Means

CI/CD is the automated and governed path from code change to verified runtime.

## CI

Continuous Integration validates whether code integrates safely.

Typical CI stages:

- checkout
- setup runtime
- install dependencies
- lint
- test
- build
- scan

## CD

Continuous Delivery prepares a production-ready artifact.

Continuous Deployment automatically deploys approved artifacts.

## Universal Pipeline

```text
trigger
  -> checkout
  -> setup runtime
  -> install dependencies
  -> static checks
  -> tests
  -> build artifact
  -> scan artifact
  -> publish artifact
  -> generate metadata
  -> promote
  -> deploy
  -> verify
  -> rollback if needed
````

## Platform Vocabulary

| Concept        | GitHub Actions            | Jenkins                         | GitLab CI                      |
| -------------- | ------------------------- | ------------------------------- | ------------------------------ |
| Pipeline file  | `.github/workflows/*.yml` | `Jenkinsfile`                   | `.gitlab-ci.yml`               |
| Worker         | runner                    | agent/node                      | runner                         |
| Phase          | job                       | stage                           | stage                          |
| Command unit   | step                      | step                            | script                         |
| Artifact store | artifacts/packages        | archived artifacts/repositories | job artifacts/package registry |

## Production Rules

* Do not build directly on production servers.
* Do not deploy untested code.
* Do not deploy `latest`.
* Build once, promote many.
* Keep artifacts traceable.
* Store release metadata.
* Verify deployments.
* Rollback must be tested.
* Secrets must be controlled.
* CI/CD logs must not leak secrets.

````

---

# 13. Create Universal Pipeline Stages JSON

Create:

```bash id="ym9h0i"
nano examples/universal-pipeline-stages.json
````

Paste:

```json id="8qmkdr"
{
  "pipeline": "universal-ci-cd",
  "service": "demo-node-api",
  "stages": [
    {
      "name": "trigger",
      "purpose": "Start pipeline from push, pull request, tag, schedule, or manual dispatch"
    },
    {
      "name": "checkout",
      "purpose": "Retrieve source code at exact commit"
    },
    {
      "name": "setup",
      "purpose": "Install runtime and pipeline tools"
    },
    {
      "name": "dependencies",
      "purpose": "Install locked dependencies"
    },
    {
      "name": "quality",
      "purpose": "Run lint, formatting, type checks, and static analysis"
    },
    {
      "name": "test",
      "purpose": "Run unit, integration, and smoke tests"
    },
    {
      "name": "build",
      "purpose": "Create deployable artifact"
    },
    {
      "name": "scan",
      "purpose": "Check vulnerabilities and policy violations"
    },
    {
      "name": "publish",
      "purpose": "Push artifact to registry or artifact store"
    },
    {
      "name": "metadata",
      "purpose": "Create release metadata, SBOM, provenance, and reports"
    },
    {
      "name": "promote",
      "purpose": "Approve artifact for environment"
    },
    {
      "name": "deploy",
      "purpose": "Run artifact in target environment"
    },
    {
      "name": "verify",
      "purpose": "Health check, readiness check, version check, and smoke test"
    },
    {
      "name": "rollback",
      "purpose": "Restore previous known-good artifact when deployment fails"
    }
  ]
}
```

Inspect:

```bash id="lo9fln"
jq . examples/universal-pipeline-stages.json
```

---

# 14. Create CI/CD Platform Comparison Notes

Create:

```bash id="62g6yy"
nano notes/github-jenkins-gitlab-comparison.md
```

Paste:

````markdown id="1rwsm5"
# GitHub Actions vs Jenkins vs GitLab CI

## GitHub Actions

Best when:

- code is in GitHub
- you want fast setup
- you want native package/registry integration
- you want OIDC integration with cloud providers
- you want pull request and branch workflows

Common file:

```text
.github/workflows/*.yml
````

## Jenkins

Best when:

* you need self-managed CI/CD
* you need custom agents
* you have complex enterprise workflows
* you integrate legacy tools
* you need deep control over execution environment

Common file:

```text
Jenkinsfile
```

## GitLab CI

Best when:

* code is in GitLab
* you want integrated CI, registry, security, and deployments
* you want `.gitlab-ci.yml` workflow control
* you use GitLab runners

Common file:

```text
.gitlab-ci.yml
```

## Professional Decision

Use the CI/CD platform closest to your source control and enterprise ecosystem unless there is a strong reason not to.

````

---

# 15. Create a Local Pipeline Simulator

Before writing real CI/CD, create a local simulator.

This helps you understand what every CI/CD platform is doing.

Create:

```bash id="k7ka83"
nano shared-scripts/pipeline-simulator.sh
````

Paste:

```bash id="brlx61"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$HOME/devops-masterclass}"
APP_DIR="${APP_DIR:-$ROOT_DIR/05-application-runtime/demo-node-api}"
MODULE7_DIR="${MODULE7_DIR:-$ROOT_DIR/07-artifact-management-registries}"
REPORT_DIR="${REPORT_DIR:-$ROOT_DIR/08-cicd-pipelines/reports}"

BASE_VERSION="${BASE_VERSION:-0.8.0}"
CHANNEL="${CHANNEL:-dev}"
RUN_DOCKER_BUILD="${RUN_DOCKER_BUILD:-true}"
RUN_MODULE7_METADATA="${RUN_MODULE7_METADATA:-true}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/pipeline-simulator-$TIMESTAMP.json"

log_stage() {
  echo
  echo "===== $1 ====="
}

log_stage "Pipeline Context"
echo "Root: $ROOT_DIR"
echo "App: $APP_DIR"
echo "Module7: $MODULE7_DIR"
echo "Base version: $BASE_VERSION"
echo "Channel: $CHANNEL"

log_stage "Checkout Simulation"
cd "$ROOT_DIR"
COMMIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
echo "Commit: $COMMIT_SHA"
echo "Branch: $BRANCH"

log_stage "Setup Runtime"
node --version || true
npm --version || true
docker --version || true

log_stage "Install Dependencies"
cd "$APP_DIR"
npm ci

log_stage "Test"
npm test
TEST_STATUS="passed"

log_stage "Compute Version"
cd "$MODULE7_DIR"
VERSION_JSON="$(BASE_VERSION="$BASE_VERSION" CHANNEL="$CHANNEL" ./scripts/compute-version.sh)"
DEPLOY_TAG="$(echo "$VERSION_JSON" | jq -r '.deploy_tag')"
echo "$VERSION_JSON" | jq .

log_stage "Build Artifact"
if [ "$RUN_DOCKER_BUILD" = "true" ]; then
  cd "$APP_DIR"
  VERSION="$DEPLOY_TAG" ./scripts/docker-build.sh
  BUILD_STATUS="passed"
else
  BUILD_STATUS="skipped"
fi

log_stage "Metadata"
RELEASE_METADATA=""
if [ "$RUN_MODULE7_METADATA" = "true" ]; then
  cd "$MODULE7_DIR"
  BASE_VERSION="$BASE_VERSION" \
  CHANNEL="$CHANNEL" \
  IMAGE_NAME=demo-node-api \
  TEST_STATUS="$TEST_STATUS" \
  SCAN_STATUS=not_run \
  ./scripts/create-release-metadata.sh

  RELEASE_METADATA="$(ls -t release-records/demo-node-api-*.json | head -n 1)"
fi

log_stage "Pipeline Report"
cat > "$REPORT_FILE" <<EOF
{
  "pipeline": "local-simulator",
  "commit_sha": "$COMMIT_SHA",
  "branch": "$BRANCH",
  "base_version": "$BASE_VERSION",
  "channel": "$CHANNEL",
  "deploy_tag": "$DEPLOY_TAG",
  "test_status": "$TEST_STATUS",
  "build_status": "$BUILD_STATUS",
  "release_metadata": "$RELEASE_METADATA",
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

cat "$REPORT_FILE" | jq .

echo
echo "Pipeline simulator completed."
echo "Report: $REPORT_FILE"
```

Make executable:

```bash id="wuuczt"
chmod +x shared-scripts/pipeline-simulator.sh
```

Run:

```bash id="rgwdf4"
BASE_VERSION=0.8.0 CHANNEL=dev ./shared-scripts/pipeline-simulator.sh
```

This is your local CI/CD pipeline without any CI/CD platform.

---

# 16. Create GitHub Actions Skeleton

Create:

```bash id="64gyyh"
nano github-actions/ci-basic.yml
```

Paste:

```yaml id="2g3mco"
name: Basic CI

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

env:
  APP_DIR: 05-application-runtime/demo-node-api

jobs:
  test:
    name: Test Node.js app
    runs-on: ubuntu-latest

    steps:
      - name: Checkout source
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: npm
          cache-dependency-path: ${{ env.APP_DIR }}/package-lock.json

      - name: Install dependencies
        working-directory: ${{ env.APP_DIR }}
        run: npm ci

      - name: Run tests
        working-directory: ${{ env.APP_DIR }}
        run: npm test
```

Later we will copy this into:

```text id="42odm8"
.github/workflows/ci-basic.yml
```

---

# 17. Create Jenkins Skeleton

Create:

```bash id="8na2l3"
nano jenkins/Jenkinsfile.basic
```

Paste:

```groovy id="ry1hud"
pipeline {
  agent any

  environment {
    APP_DIR = '05-application-runtime/demo-node-api'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Setup') {
      steps {
        sh '''
          node --version
          npm --version
        '''
      }
    }

    stage('Install Dependencies') {
      steps {
        dir("${APP_DIR}") {
          sh 'npm ci'
        }
      }
    }

    stage('Test') {
      steps {
        dir("${APP_DIR}") {
          sh 'npm test'
        }
      }
    }
  }

  post {
    always {
      echo 'Pipeline finished.'
    }

    success {
      echo 'Pipeline succeeded.'
    }

    failure {
      echo 'Pipeline failed.'
    }
  }
}
```

---

# 18. Create GitLab CI Skeleton

Create:

```bash id="jb6j5g"
nano gitlab/.gitlab-ci.basic.yml
```

Paste:

```yaml id="46x3dq"
stages:
  - test

variables:
  APP_DIR: "05-application-runtime/demo-node-api"

test_node_app:
  stage: test
  image: node:22-alpine
  before_script:
    - cd "$APP_DIR"
    - npm ci
  script:
    - npm test
```

Later, if you host this repo in GitLab, this file becomes:

```text id="fpgl1q"
.gitlab-ci.yml
```

---

# 19. Pipeline Quality Gates

A production pipeline should have gates.

## Test gate

```text id="kj9kek"
unit tests must pass
```

## Build gate

```text id="pl27nu"
artifact must build successfully
```

## Scan gate

```text id="revg56"
critical vulnerabilities fail build unless approved
```

## Metadata gate

```text id="iwm8gx"
release metadata must be generated
```

## Registry gate

```text id="qrw0ar"
artifact must be pushed to registry
```

## Signature gate

```text id="x42ksu"
production artifact must be signed/verified
```

## Deployment gate

```text id="r9as93"
health/readiness/version checks must pass
```

## Rollback gate

```text id="z00hzs"
previous known-good version must be known
```

Professional rule:

```text id="7u9zaw"
A pipeline without gates is just a remote shell script.
```

---

# 20. Create CI/CD Quality Gate Checklist

Create:

```bash id="1gh7gm"
nano notes/cicd-quality-gates.md
```

Paste:

```markdown id="osdby9"
# CI/CD Quality Gates

## Required Gates

### Source Gate

- commit exists
- branch/tag is allowed
- pull request rules satisfied

### Dependency Gate

- lockfile used
- deterministic install
- no dependency install from untrusted source

### Test Gate

- unit tests pass
- integration tests pass where applicable
- smoke tests pass

### Build Gate

- artifact builds successfully
- artifact has version metadata
- artifact does not contain secrets

### Security Gate

- vulnerability scan completed
- high/critical policy applied
- secrets scan completed
- container hardening checked

### Artifact Gate

- immutable tag created
- image digest recorded
- SBOM generated
- provenance generated
- signing completed where required

### Deployment Gate

- environment approved
- artifact promoted
- deployment health check passed
- version endpoint matches expected version

### Rollback Gate

- previous version known
- rollback command tested
- rollback artifact retained
```

---

# 21. Pipeline Anti-Patterns

Avoid:

```text id="oezc2u"
building on production server
deploying from developer laptop
deploying latest
skipping tests to save time
using same credential for push and pull
putting secrets in pipeline logs
using long-lived cloud keys when OIDC is available
manual docker build on EC2
rebuilding artifact for production
no rollback step
no deployment verification
no release metadata
pipeline only works on one person's laptop
```

Strong rule:

```text id="h0e1qn"
A pipeline should be reproducible, observable, and safe to rerun.
```

---

# 22. CI/CD Failure Types

Professional engineers know pipeline failures are not all the same.

```text id="vxl1g7"
source failure:
  bad code or merge conflict

dependency failure:
  npm install fails, registry unavailable

test failure:
  code behavior failed

build failure:
  Dockerfile or packaging failed

scan failure:
  vulnerabilities or policy violation

registry failure:
  push/pull/auth failure

deployment failure:
  app does not start or health check fails

environment failure:
  server/network/secret/config issue

pipeline infrastructure failure:
  runner/agent/plugin/cache issue
```

Different failures require different fixes.

---

# 23. Create CI/CD Troubleshooting Notes

Create:

```bash id="dh7627"
nano runbooks/cicd-troubleshooting.md
```

Paste:

````markdown id="d7fwuh"
# CI/CD Troubleshooting Runbook

## Failure: dependency install failed

Check:

```bash
node --version
npm --version
npm ci
cat package-lock.json
````

Possible causes:

* lockfile mismatch
* registry outage
* wrong Node.js version
* private package auth missing

## Failure: tests failed

Check:

```bash id="zyqhkn"
npm test
```

Possible causes:

* actual bug
* environment variable missing
* flaky test
* test depends on external service

## Failure: Docker build failed

Check:

```bash id="x4r5sq"
docker build -t test .
```

Possible causes:

* wrong Dockerfile path
* missing file due to `.dockerignore`
* dependency install failure
* build arg missing

## Failure: registry push failed

Check:

```bash id="fto1xs"
docker login
docker tag
docker push
```

Possible causes:

* not logged in
* wrong image name
* token lacks permission
* tag immutability conflict

## Failure: deployment health check failed

Check:

```bash id="1wakip"
docker ps
docker logs CONTAINER
curl -v http://localhost:8080/health
curl -v http://localhost:8080/version
```

Possible causes:

* app crashed
* wrong port
* missing secret
* database unavailable
* readiness delay
* bad environment config

## Failure: rollback failed

Check:

```bash id="26out4"
cat promotion/state/environments.json
docker pull previous-image
```

Possible causes:

* previous image deleted
* previous tag overwritten
* rollback script broken
* environment state missing

````

---

# 24. Create Module 8 README

Create:

```bash id="stuxd0"
nano README.md
````

Paste:

````markdown id="p6ks7o"
# Module 8 — CI/CD Pipelines

This module covers production-grade CI/CD using:

- GitHub Actions
- Jenkins
- GitLab CI

## Goals

- Understand CI/CD mental model
- Build basic and advanced pipelines
- Use stages, jobs, steps, runners, and agents
- Build and publish artifacts
- Add test, scan, and deployment gates
- Use approvals and promotion workflows
- Implement rollback-aware deployment pipelines
- Secure CI/CD secrets and permissions

## Lessons

1. CI/CD Mental Model
2. GitHub Actions Fundamentals
3. GitHub Actions Production Pipeline
4. Jenkins Fundamentals
5. Jenkins Production Pipeline
6. GitLab CI Fundamentals
7. GitLab CI Production Pipeline
8. Secrets and OIDC in CI/CD
9. Quality Gates and DevSecOps Checks
10. Deployment and Rollback Pipelines
11. Pipeline Observability and Debugging
12. CI/CD Capstone

## Core Principle

```text
CI/CD is the automated and governed path from code change to verified runtime.
````

````

---

# 25. Create Makefile

Create:

```bash id="e9ymiz"
nano Makefile
````

Paste:

```Makefile id="5wz71g"
ROOT_DIR ?= $(HOME)/devops-masterclass
BASE_VERSION ?= 0.8.0
CHANNEL ?= dev

.PHONY: simulator validate-notes show-stages

simulator:
	BASE_VERSION="$(BASE_VERSION)" CHANNEL="$(CHANNEL)" ./shared-scripts/pipeline-simulator.sh

show-stages:
	jq . examples/universal-pipeline-stages.json

validate-notes:
	@test -f notes/ci-cd-mental-model.md
	@test -f notes/github-jenkins-gitlab-comparison.md
	@test -f notes/cicd-quality-gates.md
	@test -f runbooks/cicd-troubleshooting.md
	@echo "Module 8 Lesson 8.1 notes validated."
```

Run:

```bash id="shz3a8"
make show-stages
make validate-notes
make simulator BASE_VERSION=0.8.0 CHANNEL=dev
```

---

# 26. Practical Lab

Run the complete lab:

```bash id="v0xgly"
cd ~/devops-masterclass/08-cicd-pipelines

make validate-notes
make show-stages
make simulator BASE_VERSION=0.8.0 CHANNEL=dev
```

Check reports:

```bash id="4jdnkp"
ls -lt reports | head
LATEST_REPORT="$(ls -t reports/pipeline-simulator-*.json | head -n 1)"
cat "$LATEST_REPORT" | jq .
```

Expected report fields:

```json id="ov2y8h"
{
  "pipeline": "local-simulator",
  "commit_sha": "...",
  "branch": "...",
  "base_version": "0.8.0",
  "channel": "dev",
  "deploy_tag": "...",
  "test_status": "passed",
  "build_status": "passed"
}
```

---

# 27. How This Connects to Your Existing Project

Your previous project work already contains many real CI/CD concepts:

```text id="vy84w7"
Jenkins artifact deployment
atomic symlink release
PM2 restart
Docker build
Docker Compose deployment
GHCR/ECR push
SBOM
provenance
signing
promotion records
rollback scripts
runtime validation
```

Module 8 will now teach you how to place these into real pipeline systems.

Final goal:

```text id="4794zw"
One production-grade CI/CD system that can test, build, scan, publish, promote, deploy, verify, and rollback your app.
```

---

# 28. Interview Explanation

## What is CI/CD?

Strong answer:

```text id="ok44uu"
CI/CD is the automated and governed process of taking a code change from source control through validation, testing, artifact creation, security checks, deployment, verification, and rollback readiness.
```

## What is the difference between CI and CD?

Strong answer:

```text id="r1xgum"
CI focuses on integrating code safely by running checks like dependency install, linting, tests, and builds. CD focuses on delivering or deploying the built artifact to environments using promotion, approval, deployment, health checks, and rollback controls.
```

## What is a pipeline?

Strong answer:

```text id="6kmpps"
A pipeline is a sequence of automated stages and jobs that validate, build, package, publish, deploy, and verify software.
```

## What is a runner or agent?

Strong answer:

```text id="fuf8dr"
A runner or agent is the machine that executes pipeline jobs. In GitHub Actions it is called a runner, in Jenkins it is commonly called an agent or node, and in GitLab CI it is called a runner.
```

## GitHub Actions vs Jenkins vs GitLab CI?

Strong answer:

```text id="152ic3"
GitHub Actions is best for GitHub-native workflows and quick setup. Jenkins is best for highly customizable self-managed enterprise pipelines. GitLab CI is best when using GitLab as the integrated source, CI, registry, and DevSecOps platform.
```

## What makes a pipeline production-grade?

Strong answer:

```text id="ijw55c"
A production-grade pipeline has deterministic dependency installation, tests, artifact builds, security scans, SBOM/provenance generation, registry publishing, immutable tags, environment promotion, approval gates, deployment verification, release metadata, and rollback support.
```

---

# 29. Commit Work

Run:

```bash id="q4jk15"
cd ~/devops-masterclass

git status
git add 08-cicd-pipelines

git commit -m "feat: start CI/CD pipelines module with mental model"
git push
```

---

# 30. Today’s Core Rules

```text id="9rwh1i"
CI/CD is not just automation.
CI validates code integration.
CD delivers verified artifacts.
Pipeline means controlled path from code to runtime.
Stages organize work.
Jobs execute work.
Steps are commands/actions.
Runners/agents execute jobs.
Artifacts are the deployment units.
Quality gates protect environments.
Do not deploy latest.
Do not build on production servers.
Build once, promote many.
Verify after deployment.
Rollback must be planned.
Pipeline security matters as much as application security.
```

---

# Next Lesson

# Lesson 8.2 — GitHub Actions Fundamentals

We will go deep into:

```text id="x7iok0"
workflow syntax
events
jobs
steps
runners
actions
permissions
environment variables
secrets
caching
artifacts
matrix builds
workflow_dispatch
pull_request workflows
push workflows
basic Node.js CI pipeline
common GitHub Actions errors
```

[1]: https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions?utm_source=chatgpt.com "Workflow syntax for GitHub Actions"
[2]: https://docs.github.com/articles/getting-started-with-github-actions?utm_source=chatgpt.com "Understanding GitHub Actions"
[3]: https://www.jenkins.io/doc/book/pipeline/jenkinsfile/?utm_source=chatgpt.com "Using a Jenkinsfile"
[4]: https://docs.gitlab.com/ci/jobs/?utm_source=chatgpt.com "CI/CD Jobs"

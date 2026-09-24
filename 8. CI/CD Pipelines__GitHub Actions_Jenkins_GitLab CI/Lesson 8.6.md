# Lesson 8.6 — GitLab CI Fundamentals Masterclass

# `.gitlab-ci.yml`, Stages, Jobs, Scripts, Variables, Artifacts, Cache, Rules, Needs, Services, Docker-in-Docker, Runners, Environments, Manual Jobs, and Basic Node.js Pipeline

Now we cover the third major CI/CD platform in Module 8:

```text id="szl2ke"
GitLab CI/CD
```

GitLab CI/CD pipelines are defined in a file named:

```text id="ke5yq0"
.gitlab-ci.yml
```

GitLab’s official docs describe this file as the place where you define the CI/CD jobs that make up your pipeline. Jobs are the fundamental elements of GitLab pipelines, and they execute on GitLab Runners. ([GitLab Docs][1])

---

# 1. GitLab CI Mental Model

GitLab CI structure:

```text id="uptxoe"
repository
  ↓
.gitlab-ci.yml
  ↓
pipeline
  ↓
stages
  ↓
jobs
  ↓
runner
  ↓
script commands
```

Simple example:

```yaml id="a5tlbw"
stages:
  - test

test_node_app:
  stage: test
  image: node:22-alpine
  script:
    - node --version
    - npm --version
    - npm test
```

Meaning:

```text id="hphmoy"
stages:
  ordered pipeline phases

job:
  task executed by a runner

stage:
  which phase the job belongs to

image:
  container image used to run the job

script:
  shell commands executed by the job
```

GitLab jobs are configured in `.gitlab-ci.yml` with commands to execute; jobs can run independently and are executed by runners, often inside Docker containers. ([GitLab Docs][2])

---

# 2. GitLab vs GitHub Actions vs Jenkins

| Concept             | GitHub Actions                  | Jenkins             | GitLab CI          |
| ------------------- | ------------------------------- | ------------------- | ------------------ |
| Pipeline file       | `.github/workflows/*.yml`       | `Jenkinsfile`       | `.gitlab-ci.yml`   |
| Worker              | Runner                          | Agent/node          | Runner             |
| Main unit           | Workflow/job/step               | Pipeline/stage/step | Pipeline/stage/job |
| Command section     | `run`                           | `sh` / steps        | `script`           |
| Artifact upload     | `upload-artifact`               | `archiveArtifacts`  | `artifacts`        |
| Dependency cache    | `actions/cache` / setup actions | plugin/custom       | `cache`            |
| Manual approval     | Environment approval            | `input` step        | `when: manual`     |
| Container execution | `container:` / Docker actions   | Docker agent        | `image:`           |

Professional summary:

```text id="6oc2v7"
GitHub Actions is GitHub-native.
Jenkins is highly customizable and self-managed.
GitLab CI is GitLab-native and integrates source, CI, registry, environments, and security workflows.
```

---

# 3. Stages

Stages define pipeline order.

Example:

```yaml id="u5cb91"
stages:
  - validate
  - test
  - build
  - scan
  - publish
  - deploy
```

Jobs assigned to earlier stages run before later stages.

Example:

```yaml id="vopbzi"
test:
  stage: test
  script:
    - npm test

build:
  stage: build
  script:
    - docker build -t app .
```

The usual mental model:

```text id="gjyn4v"
all jobs in test stage
  ↓
all jobs in build stage
  ↓
all jobs in deploy stage
```

GitLab stages define execution order; jobs in the same stage can run in parallel, while later stages generally wait for earlier stages to complete successfully. ([GitLab Docs][2])

---

# 4. Jobs

A job is one task.

Example:

```yaml id="ewqfog"
unit_tests:
  stage: test
  image: node:22-alpine
  script:
    - npm ci
    - npm test
```

Job names are arbitrary:

```text id="k7oyrp"
unit_tests
docker_build
trivy_scan
deploy_staging
```

Professional naming rule:

```text id="v7ik6s"
Job names should explain what they do.
```

Bad:

```yaml id="h4t9be"
job1:
```

Good:

```yaml id="3ii1o6"
node_unit_tests:
docker_image_build:
deploy_staging:
```

---

# 5. `script`, `before_script`, and `after_script`

## `script`

Main commands:

```yaml id="m2y5ws"
test:
  script:
    - npm ci
    - npm test
```

## `before_script`

Commands before job script:

```yaml id="wz6sfm"
before_script:
  - node --version
  - npm --version
```

## `after_script`

Commands after job script:

```yaml id="d56gi5"
after_script:
  - echo "Job finished"
```

Use `before_script` for:

```text id="fr2c5h"
tool version output
login setup
directory preparation
dependency setup shared by jobs
```

Use `after_script` for:

```text id="qjvgzb"
debug output
cleanup
final log collection
```

Professional rule:

```text id="dr0yj2"
Keep job-specific logic in the job. Avoid hiding too much behavior in global before_script.
```

---

# 6. Images

GitLab jobs can run inside container images.

Example:

```yaml id="brk5zd"
image: node:22-alpine
```

Job-level image:

```yaml id="ti0etd"
test:
  image: node:22-alpine
  script:
    - npm test
```

Global image:

```yaml id="v9gme9"
image: node:22-alpine

test:
  script:
    - npm test
```

GitLab docs explain that with Docker executor runners, you can specify the container image where CI/CD jobs run, and you can optionally run additional service containers. ([GitLab Docs][3])

Professional rule:

```text id="diwpls"
Use images to make jobs reproducible.
```

---

# 7. Variables

Variables store configuration.

Global variables:

```yaml id="wwwp5t"
variables:
  APP_DIR: "05-application-runtime/demo-node-api"
  NODE_VERSION: "22"
```

Use in scripts:

```yaml id="90p77o"
script:
  - cd "$APP_DIR"
  - npm ci
```

GitLab also provides predefined CI/CD variables like commit SHA, branch name, project path, and registry variables. GitLab docs warn not to override predefined variables because it can cause pipeline behavior problems. ([GitLab Docs][4])

Common predefined variables:

```text id="eyxhqh"
CI_COMMIT_SHA
CI_COMMIT_SHORT_SHA
CI_COMMIT_BRANCH
CI_COMMIT_TAG
CI_PROJECT_PATH
CI_PROJECT_NAME
CI_REGISTRY
CI_REGISTRY_IMAGE
CI_PIPELINE_ID
CI_JOB_ID
```

Example:

```yaml id="ogx5fa"
script:
  - echo "Commit: $CI_COMMIT_SHA"
  - echo "Short SHA: $CI_COMMIT_SHORT_SHA"
  - echo "Image: $CI_REGISTRY_IMAGE"
```

Professional rule:

```text id="sad8qm"
Use variables for safe config. Use GitLab CI/CD variables for secrets.
```

---

# 8. Secrets / CI/CD Variables

In GitLab, secrets are usually stored as CI/CD variables in project/group settings.

Example usage:

```yaml id="labzyy"
script:
  - echo "$REGISTRY_PASSWORD" | docker login registry.example.com -u "$REGISTRY_USER" --password-stdin
```

Rules:

```text id="y3oe4o"
mark sensitive variables as masked
mark production variables as protected
do not echo secrets
do not commit secrets
use environment-scoped variables for staging/prod when needed
```

Professional rule:

```text id="hnzq3d"
Treat CI variables like production credentials.
```

---

# 9. Cache

Cache speeds up jobs by reusing dependencies.

Example for npm:

```yaml id="l3oboy"
cache:
  key:
    files:
      - 05-application-runtime/demo-node-api/package-lock.json
  paths:
    - 05-application-runtime/demo-node-api/.npm/
```

Use npm cache path:

```yaml id="h28s31"
script:
  - cd "$APP_DIR"
  - npm ci --cache .npm --prefer-offline
```

GitLab docs explain that caches are meant for dependencies downloaded from the internet, while artifacts are generated by jobs and stored in GitLab for download or use by later jobs. Both cache and artifact paths are relative to the project directory. ([GitLab Docs][5])

Cache is for:

```text id="3sao6g"
npm packages
pip cache
Maven cache
Gradle cache
Terraform plugin cache
```

Cache is not for:

```text id="7s3pso"
release metadata
SBOM
deployment reports
test reports
final build outputs
```

---

# 10. Artifacts

Artifacts preserve files from a job.

Example:

```yaml id="ijgabd"
artifacts:
  when: always
  paths:
    - reports/
  expire_in: 7 days
```

GitLab docs define job artifacts as archives of files and directories output by a job, such as build output or report files. ([GitLab Docs][6])

Use artifacts for:

```text id="d3pgzj"
test reports
coverage reports
scan reports
SBOM files
release metadata
promotion records
deployment logs
```

Professional distinction:

```text id="c0joh6"
cache:
  speeds up future jobs

artifacts:
  preserve outputs from this pipeline
```

---

# 11. `needs`

By default, jobs follow stage order.

`needs` lets a job start earlier or explicitly depend on another job.

Example:

```yaml id="cxlytr"
test:
  stage: test
  script:
    - npm test

build:
  stage: build
  needs:
    - test
  script:
    - docker build -t app .
```

Use `needs` for:

```text id="6suohy"
faster pipelines
explicit dependencies
artifact passing between jobs
```

Professional rule:

```text id="uysrvz"
Use stages for broad flow; use needs for precise dependencies.
```

---

# 12. `rules`

`rules` decide when jobs run.

Example:

```yaml id="4hkki5"
rules:
  - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
  - if: '$CI_COMMIT_BRANCH == "main"'
  - if: '$CI_COMMIT_TAG'
```

Common patterns:

```yaml id="zzyogt"
rules:
  - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    when: always
  - if: '$CI_COMMIT_BRANCH == "main"'
    when: always
  - when: never
```

Use `rules` instead of old `only/except` for modern pipelines.

Professional examples:

```text id="6r65pv"
MR pipeline:
  test only

main branch:
  test, build, push

tag:
  release pipeline

manual:
  deploy production
```

GitLab’s YAML reference covers the configuration options available in `.gitlab-ci.yml`, including job behavior and pipeline keywords. ([GitLab Docs][1])

---

# 13. Manual Jobs

Manual job:

```yaml id="x4w1kf"
deploy_production:
  stage: deploy
  when: manual
  script:
    - echo "Deploy production"
```

With rules:

```yaml id="pu6jr8"
deploy_production:
  stage: deploy
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual
    - when: never
  script:
    - echo "Deploy production"
```

Mental model:

```text id="syn75m"
GitHub Actions:
  environment approval

Jenkins:
  input step

GitLab CI:
  manual job
```

Professional rule:

```text id="nj7avz"
Manual production jobs should deploy exact immutable artifacts, not rebuild or deploy latest.
```

---

# 14. Environments

GitLab environments represent deployment targets.

Example:

```yaml id="fjmdit"
deploy_staging:
  stage: deploy
  environment:
    name: staging
  script:
    - echo "Deploy staging"

deploy_production:
  stage: deploy
  environment:
    name: production
  when: manual
  script:
    - echo "Deploy production"
```

Use environments for:

```text id="jy49j9"
staging
production
review apps
temporary test environments
```

Professional rule:

```text id="71uyzg"
A deployment job should declare the environment it targets.
```

---

# 15. Services

Services are helper containers available to a job.

Example with MongoDB:

```yaml id="8fnl2l"
test_with_mongo:
  image: node:22-alpine
  services:
    - name: mongo:7
      alias: mongo
  variables:
    DATABASE_URL: "mongodb://mongo:27017/demo"
  script:
    - npm ci
    - npm test
```

GitLab Docker image docs mention that you can run additional services such as databases in containers through the `services` keyword in `.gitlab-ci.yml`. ([GitLab Docs][3])

Use services for:

```text id="0izya4"
MongoDB
PostgreSQL
Redis
MySQL
LocalStack
test dependencies
```

Professional warning:

```text id="1kr2z9"
Services are good for integration tests, but production deployment should use real managed infrastructure or proper environment services.
```

---

# 16. Docker-in-Docker

Docker-in-Docker lets a GitLab CI job build Docker images using a Docker daemon service.

Typical pattern:

```yaml id="s3kjwe"
docker_build:
  image: docker:27
  services:
    - docker:27-dind
  variables:
    DOCKER_TLS_CERTDIR: "/certs"
  script:
    - docker version
    - docker build -t "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA" .
```

GitLab’s Docker-in-Docker docs explain that `dind` uses a Docker image with Docker tools and runs the job in privileged mode with Docker executor or Kubernetes executor. ([GitLab Docs][7])

Professional warning:

```text id="6gjowq"
Docker-in-Docker usually requires privileged runners. Privileged CI runners are powerful and must be restricted.
```

Alternatives:

```text id="yychug"
Kaniko
Buildah
Docker Buildx with secure runner setup
remote builder
GitLab shared runner features if available
```

GitLab also documents using Docker/Buildah-style flows to build and push container images in CI/CD. ([GitLab Docs][8])

---

# 17. Hands-On — Create GitLab Lesson Directory

Run:

```bash id="rkg3zy"
cd ~/devops-masterclass/08-cicd-pipelines

mkdir -p gitlab/{notes,pipelines,examples,runbooks,reports,scripts}
```

---

# 18. Create GitLab Fundamentals Notes

Create:

```bash id="f94vk2"
nano gitlab/notes/gitlab-ci-fundamentals.md
```

Paste:

````markdown id="mfhq4f"
# GitLab CI Fundamentals

## Core File

```text
.gitlab-ci.yml
````

## Mental Model

```text
pipeline
  -> stages
    -> jobs
      -> script commands
        -> runner execution
```

## Core Keywords

* `stages`: ordered pipeline phases
* `job`: named task
* `stage`: phase assigned to a job
* `image`: container image used by job
* `script`: commands executed by job
* `before_script`: commands before script
* `after_script`: commands after script
* `variables`: pipeline/job variables
* `cache`: reusable dependencies
* `artifacts`: job outputs
* `needs`: explicit job dependencies
* `rules`: decide when jobs run
* `services`: helper containers
* `environment`: deployment target
* `when: manual`: manual approval job

## Production Rules

* Use immutable version-SHA tags.
* Do not deploy `latest`.
* Use artifacts for release evidence.
* Use cache for dependencies.
* Use rules to separate MR, main, tag, and deploy behavior.
* Restrict privileged Docker runners.
* Store secrets in CI/CD variables.
* Use manual jobs for production approval.

````

---

# 19. Create Basic Node.js GitLab CI Pipeline

Create:

```bash id="8zf7j5"
nano gitlab/pipelines/.gitlab-ci.basic.yml
````

Paste:

```yaml id="ycowci"
stages:
  - test

variables:
  APP_DIR: "05-application-runtime/demo-node-api"

node_tests:
  stage: test
  image: node:22-alpine
  before_script:
    - node --version
    - npm --version
  script:
    - cd "$APP_DIR"
    - npm ci
    - npm test
```

This is your simplest GitLab CI pipeline.

If your repo is hosted in GitLab, copy it to root:

```bash id="stsvga"
cd ~/devops-masterclass

cp 08-cicd-pipelines/gitlab/pipelines/.gitlab-ci.basic.yml .gitlab-ci.yml
```

---

# 20. Create GitLab CI Pipeline With Cache and Artifacts

Create:

```bash id="v2kog7"
cd ~/devops-masterclass/08-cicd-pipelines

nano gitlab/pipelines/.gitlab-ci.node-ci.yml
```

Paste:

```yaml id="o4msdg"
stages:
  - test
  - report

variables:
  APP_DIR: "05-application-runtime/demo-node-api"
  NODE_ENV: "test"

cache:
  key:
    files:
      - 05-application-runtime/demo-node-api/package-lock.json
  paths:
    - 05-application-runtime/demo-node-api/.npm/

node_tests:
  stage: test
  image: node:22-alpine
  before_script:
    - node --version
    - npm --version
  script:
    - cd "$APP_DIR"
    - npm ci --cache .npm --prefer-offline
    - npm test
    - mkdir -p ../../08-cicd-pipelines/gitlab/reports
    - |
      cat > ../../08-cicd-pipelines/gitlab/reports/node-test-report.json <<EOF
      {
        "pipeline": "gitlab-node-ci",
        "commit_sha": "$CI_COMMIT_SHA",
        "short_sha": "$CI_COMMIT_SHORT_SHA",
        "branch": "$CI_COMMIT_BRANCH",
        "test_status": "passed",
        "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
      }
      EOF
  artifacts:
    when: always
    expire_in: 7 days
    paths:
      - 08-cicd-pipelines/gitlab/reports/node-test-report.json

show_report:
  stage: report
  image: alpine:3.20
  needs:
    - job: node_tests
      artifacts: true
  script:
    - cat 08-cicd-pipelines/gitlab/reports/node-test-report.json
```

This teaches:

```text id="g6j7z1"
cache:
  npm dependency cache

artifacts:
  report file from job

needs:
  pass artifact to later job
```

---

# 21. Create GitLab CI With Rules

Create:

```bash id="w04s49"
nano gitlab/pipelines/.gitlab-ci.rules-demo.yml
```

Paste:

```yaml id="z13j7w"
stages:
  - validate
  - build
  - deploy

validate:
  stage: validate
  image: alpine:3.20
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == "main"'
    - if: '$CI_COMMIT_TAG'
  script:
    - echo "Validate source for $CI_COMMIT_REF_NAME"

build_main:
  stage: build
  image: alpine:3.20
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
    - when: never
  script:
    - echo "Build artifact on main"

release_tag:
  stage: build
  image: alpine:3.20
  rules:
    - if: '$CI_COMMIT_TAG'
    - when: never
  script:
    - echo "Release from tag $CI_COMMIT_TAG"

deploy_production:
  stage: deploy
  image: alpine:3.20
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual
    - when: never
  environment:
    name: production
  script:
    - echo "Manual production deploy"
```

This gives:

```text id="nrp2pd"
merge request:
  validate only

main:
  validate + build + optional production manual

tag:
  validate + release
```

---

# 22. Create GitLab CI Docker Build Example

Create:

```bash id="d5rn3l"
nano gitlab/pipelines/.gitlab-ci.docker-build.yml
```

Paste:

```yaml id="c5w8ma"
stages:
  - test
  - build

variables:
  APP_DIR: "05-application-runtime/demo-node-api"
  DOCKER_TLS_CERTDIR: "/certs"

node_tests:
  stage: test
  image: node:22-alpine
  script:
    - cd "$APP_DIR"
    - npm ci
    - npm test

docker_build:
  stage: build
  image: docker:27
  services:
    - name: docker:27-dind
      alias: docker
  needs:
    - node_tests
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
    - if: '$CI_COMMIT_TAG'
    - when: never
  before_script:
    - docker version
  script:
    - cd "$APP_DIR"
    - docker build -f Dockerfile.industry --target runtime -t "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA" .
```

Important:

```text id="l8afch"
This requires a GitLab runner that supports Docker-in-Docker and privileged mode.
```

Do not run privileged shared runners casually.

---

# 23. Create GitLab CI Registry Push Example

GitLab has predefined registry variables when using GitLab Container Registry.

Create:

```bash id="qpbq61"
nano gitlab/pipelines/.gitlab-ci.registry-push.yml
```

Paste:

```yaml id="7p8tau"
stages:
  - test
  - build
  - publish

variables:
  APP_DIR: "05-application-runtime/demo-node-api"
  DOCKER_TLS_CERTDIR: "/certs"

node_tests:
  stage: test
  image: node:22-alpine
  script:
    - cd "$APP_DIR"
    - npm ci
    - npm test

docker_build_publish:
  stage: publish
  image: docker:27
  services:
    - name: docker:27-dind
      alias: docker
  needs:
    - node_tests
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
    - if: '$CI_COMMIT_TAG'
    - when: never
  before_script:
    - docker version
    - echo "$CI_REGISTRY_PASSWORD" | docker login "$CI_REGISTRY" -u "$CI_REGISTRY_USER" --password-stdin
  script:
    - |
      if [ -n "$CI_COMMIT_TAG" ]; then
        VERSION="${CI_COMMIT_TAG#v}"
        CHANNEL="stable"
      else
        VERSION="0.8.0-dev"
        CHANNEL="dev"
      fi

      DEPLOY_TAG="$VERSION-$CI_COMMIT_SHORT_SHA"
      IMAGE_REF="$CI_REGISTRY_IMAGE:$DEPLOY_TAG"

      echo "DEPLOY_TAG=$DEPLOY_TAG" > build.env
      echo "IMAGE_REF=$IMAGE_REF" >> build.env

      cd "$APP_DIR"

      docker build \
        -f Dockerfile.industry \
        --target runtime \
        --build-arg APP_VERSION="$DEPLOY_TAG" \
        --build-arg COMMIT_SHA="$CI_COMMIT_SHORT_SHA" \
        -t "$IMAGE_REF" \
        .

      docker push "$IMAGE_REF"
  artifacts:
    reports:
      dotenv: build.env
    paths:
      - build.env
    expire_in: 7 days
```

This produces:

```text id="wxpdkb"
DEPLOY_TAG
IMAGE_REF
```

as artifact metadata.

---

# 24. Create GitLab Manual Deploy Example

Create:

```bash id="xaokq1"
nano gitlab/pipelines/.gitlab-ci.manual-deploy.yml
```

Paste:

```yaml id="ds02uk"
stages:
  - publish
  - deploy

variables:
  IMAGE_REF: "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA"

publish_placeholder:
  stage: publish
  image: alpine:3.20
  script:
    - echo "Pretend image was published:"
    - echo "$IMAGE_REF"

deploy_staging:
  stage: deploy
  image: alpine:3.20
  environment:
    name: staging
  script:
    - echo "Deploy staging:"
    - echo "$IMAGE_REF"

deploy_production:
  stage: deploy
  image: alpine:3.20
  environment:
    name: production
  when: manual
  allow_failure: false
  script:
    - echo "Manual production deploy:"
    - echo "$IMAGE_REF"
```

Professional rule:

```text id="uwvb7t"
Production deploy should be manual or protected unless your organization intentionally uses full continuous deployment.
```

---

# 25. Basic GitLab Runner Notes

A GitLab Runner executes CI/CD jobs.

Runner types:

```text id="mej8qi"
shared runner:
  managed/shared by GitLab or organization

group runner:
  available to a GitLab group

project runner:
  specific to one project

self-hosted runner:
  installed and managed by you
```

Runner executors:

```text id="85cav5"
shell
docker
docker+machine
kubernetes
ssh
custom
```

For your DevOps learning:

```text id="muhtso"
Node tests:
  Docker executor with node image

Docker builds:
  restricted Docker-in-Docker runner or alternative builder

Production deploy:
  protected runner with limited deployment access
```

Professional rule:

```text id="ws185r"
Do not run untrusted jobs on privileged production-capable runners.
```

---

# 26. Create GitLab Runner Notes

Create:

```bash id="e0lwkk"
nano gitlab/notes/gitlab-runners.md
```

Paste:

````markdown id="oe5gki"
# GitLab Runners

## What is a runner?

A runner executes GitLab CI/CD jobs.

## Common Executors

- shell
- docker
- kubernetes
- ssh
- custom

## Recommended Learning Setup

For Node.js tests:

```yaml
image: node:22-alpine
````

For Docker builds:

```yaml id="itbkfh"
image: docker:27
services:
  - docker:27-dind
```

Requires a privileged Docker-capable runner.

## Production Rules

* Use protected runners for protected branches/tags.
* Do not expose production credentials to untrusted pipelines.
* Restrict privileged Docker runners.
* Separate test runners from deployment runners.
* Use environment-specific variables.

````

---

# 27. Create GitLab Troubleshooting Runbook

Create:

```bash id="fif3sg"
nano gitlab/runbooks/gitlab-ci-troubleshooting.md
````

Paste:

````markdown id="yiitcx"
# GitLab CI Troubleshooting

## Pipeline does not start

Check:

- `.gitlab-ci.yml` exists at repository root
- YAML syntax is valid
- pipeline rules allow the event
- project has runners available
- CI/CD is enabled

## Job stuck

Common causes:

- no runner available
- runner tags mismatch
- protected runner cannot run unprotected branch
- runner offline

## npm ci fails

Check:

```bash
cd 05-application-runtime/demo-node-api
npm ci
````

Common causes:

* wrong APP_DIR
* missing package-lock.json
* lockfile mismatch
* Node version mismatch

## Docker build fails

Check:

* runner supports Docker
* Docker-in-Docker service is configured
* privileged mode is enabled if using dind
* Dockerfile path is correct
* `.dockerignore` did not exclude required files

## Registry login fails

Check:

* CI_REGISTRY variables
* registry enabled
* permissions
* docker login command
* protected branch/tag variable restrictions

## Artifacts missing

Check:

* artifact paths are relative to project root
* file exists before job finishes
* expire_in not too short
* needs/artifacts configured correctly

## Cache not working

Check:

* cache key
* cache path
* runner cache configuration
* lockfile path

````

---

# 28. Create GitLab Best Practices Notes

Create:

```bash id="031o93"
nano gitlab/notes/gitlab-ci-best-practices.md
````

Paste:

```markdown id="pttr3h"
# GitLab CI Best Practices

## Pipeline Design

- Keep `.gitlab-ci.yml` readable.
- Use clear stage names.
- Use clear job names.
- Use `rules` for modern conditional logic.
- Use `needs` for explicit dependencies.
- Use artifacts for reports and release evidence.
- Use cache for dependencies.

## Security

- Store secrets in GitLab CI/CD variables.
- Mask sensitive variables.
- Protect production variables.
- Protect production runners.
- Restrict privileged Docker runners.
- Do not print secrets.
- Do not deploy `latest`.

## Docker

- Use immutable version-SHA tags.
- Build once, promote many.
- Avoid production rebuilds.
- Use registry variables carefully.
- Separate build and deploy permissions.

## Deployment

- Use environments.
- Use manual jobs for production.
- Require rollback version.
- Verify deployments.
- Archive deployment evidence.
```

---

# 29. Create GitLab CI Syntax Validation Script

Create:

```bash id="b9kup2"
nano gitlab/scripts/validate-gitlab-ci-files.sh
```

Paste:

```bash id="78hd13"
#!/usr/bin/env bash
set -euo pipefail

DIR="${DIR:-gitlab/pipelines}"

echo "===== Validate GitLab CI Example Files ====="

if [ ! -d "$DIR" ]; then
  echo "ERROR: directory not found: $DIR" >&2
  exit 1
fi

FAILED=0

for file in "$DIR"/.gitlab-ci*.yml; do
  [ -f "$file" ] || continue

  echo "Checking: $file"

  if ! grep -q "stages:" "$file"; then
    echo "  ERROR: missing stages"
    FAILED=1
  fi

  if ! grep -q "script:" "$file"; then
    echo "  ERROR: missing script"
    FAILED=1
  fi

  if grep -q "latest" "$file"; then
    echo "  WARNING: found 'latest' string. Ensure it is not used for production images."
  fi
done

if [ "$FAILED" -ne 0 ]; then
  echo "Validation failed."
  exit 1
fi

echo "Basic GitLab CI validation passed."
```

Make executable:

```bash id="mglqdk"
chmod +x gitlab/scripts/validate-gitlab-ci-files.sh
```

Run:

```bash id="ji8cww"
./gitlab/scripts/validate-gitlab-ci-files.sh
```

---

# 30. Create GitLab CI Combined Learning Pipeline

Create:

```bash id="7hf3uo"
nano gitlab/pipelines/.gitlab-ci.learning-combined.yml
```

Paste:

```yaml id="jk5xdc"
stages:
  - validate
  - test
  - build
  - report
  - deploy

variables:
  APP_DIR: "05-application-runtime/demo-node-api"
  BASE_VERSION: "0.8.0"
  NODE_ENV: "test"
  DOCKER_TLS_CERTDIR: "/certs"

cache:
  key:
    files:
      - 05-application-runtime/demo-node-api/package-lock.json
  paths:
    - 05-application-runtime/demo-node-api/.npm/

validate_context:
  stage: validate
  image: alpine:3.20
  script:
    - echo "Project: $CI_PROJECT_PATH"
    - echo "Commit: $CI_COMMIT_SHA"
    - echo "Short SHA: $CI_COMMIT_SHORT_SHA"
    - echo "Branch: $CI_COMMIT_BRANCH"
    - echo "Tag: $CI_COMMIT_TAG"
    - echo "Pipeline source: $CI_PIPELINE_SOURCE"

node_tests:
  stage: test
  image: node:22-alpine
  needs:
    - validate_context
  script:
    - cd "$APP_DIR"
    - npm ci --cache .npm --prefer-offline
    - npm test
    - mkdir -p ../../08-cicd-pipelines/gitlab/reports
    - |
      cat > ../../08-cicd-pipelines/gitlab/reports/test-report.json <<EOF
      {
        "service_name": "demo-node-api",
        "commit_sha": "$CI_COMMIT_SHA",
        "short_sha": "$CI_COMMIT_SHORT_SHA",
        "test_status": "passed",
        "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
      }
      EOF
  artifacts:
    when: always
    expire_in: 7 days
    paths:
      - 08-cicd-pipelines/gitlab/reports/test-report.json

compute_version:
  stage: build
  image: alpine:3.20
  needs:
    - node_tests
  script:
    - |
      if [ -n "$CI_COMMIT_TAG" ]; then
        VERSION="${CI_COMMIT_TAG#v}"
        CHANNEL="stable"
      elif [ "$CI_COMMIT_BRANCH" = "main" ]; then
        VERSION="$BASE_VERSION-dev"
        CHANNEL="dev"
      else
        SAFE_REF="$(echo "$CI_COMMIT_REF_NAME" | tr '/' '-' | tr -cd 'a-zA-Z0-9._-')"
        VERSION="$BASE_VERSION-$SAFE_REF"
        CHANNEL="branch"
      fi

      DEPLOY_TAG="$VERSION-$CI_COMMIT_SHORT_SHA"

      echo "VERSION=$VERSION" > version.env
      echo "CHANNEL=$CHANNEL" >> version.env
      echo "DEPLOY_TAG=$DEPLOY_TAG" >> version.env

      cat version.env
  artifacts:
    reports:
      dotenv: version.env
    paths:
      - version.env
    expire_in: 7 days

release_report:
  stage: report
  image: alpine:3.20
  needs:
    - job: node_tests
      artifacts: true
    - job: compute_version
      artifacts: true
  script:
    - mkdir -p 08-cicd-pipelines/gitlab/reports
    - |
      cat > 08-cicd-pipelines/gitlab/reports/release-report.json <<EOF
      {
        "service_name": "demo-node-api",
        "commit_sha": "$CI_COMMIT_SHA",
        "version": "$VERSION",
        "channel": "$CHANNEL",
        "deploy_tag": "$DEPLOY_TAG",
        "test_status": "passed",
        "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
      }
      EOF
    - cat 08-cicd-pipelines/gitlab/reports/release-report.json
  artifacts:
    when: always
    expire_in: 14 days
    paths:
      - 08-cicd-pipelines/gitlab/reports/

deploy_staging_placeholder:
  stage: deploy
  image: alpine:3.20
  needs:
    - release_report
  environment:
    name: staging
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
    - when: never
  script:
    - echo "Deploy staging placeholder for $DEPLOY_TAG"

deploy_production_placeholder:
  stage: deploy
  image: alpine:3.20
  needs:
    - release_report
  environment:
    name: production
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual
    - when: never
  allow_failure: false
  script:
    - echo "Manual production deployment placeholder for $DEPLOY_TAG"
```

This is the best learning pipeline for GitLab fundamentals.

---

# 31. Copy Combined Pipeline to Root

Only do this if you are testing in GitLab.

```bash id="esrtjy"
cd ~/devops-masterclass

cp 08-cicd-pipelines/gitlab/pipelines/.gitlab-ci.learning-combined.yml .gitlab-ci.yml
```

Commit:

```bash id="8ma9xo"
git add .gitlab-ci.yml 08-cicd-pipelines/gitlab
git commit -m "feat: add GitLab CI fundamentals pipeline"
git push
```

If your primary remote is GitHub, this file will not run unless the repo is mirrored/imported into GitLab.

---

# 32. Update Makefile

Open:

```bash id="kjhdy3"
cd ~/devops-masterclass/08-cicd-pipelines

nano Makefile
```

Add:

```Makefile id="z0jvka"
.PHONY: validate-gitlab list-gitlab copy-gitlab-learning

validate-gitlab:
	./gitlab/scripts/validate-gitlab-ci-files.sh

list-gitlab:
	find gitlab -type f | sort

copy-gitlab-learning:
	cp gitlab/pipelines/.gitlab-ci.learning-combined.yml $(ROOT_DIR)/.gitlab-ci.yml
	@echo "Copied GitLab learning pipeline to repo root."
```

Run:

```bash id="k70zt5"
make validate-gitlab
make list-gitlab
```

---

# 33. Practical Lab

Run:

```bash id="1q1x9t"
cd ~/devops-masterclass/08-cicd-pipelines

mkdir -p gitlab/{notes,pipelines,examples,runbooks,reports,scripts}

./gitlab/scripts/validate-gitlab-ci-files.sh
make validate-gitlab
make list-gitlab
```

Inspect examples:

```bash id="keuxck"
cat gitlab/pipelines/.gitlab-ci.basic.yml
cat gitlab/pipelines/.gitlab-ci.node-ci.yml
cat gitlab/pipelines/.gitlab-ci.learning-combined.yml
```

Optional root copy:

```bash id="vzbfoa"
make copy-gitlab-learning
```

---

# 34. Common GitLab CI Errors

## Pipeline does not run

Check:

```text id="zquokj"
.gitlab-ci.yml is at repo root
YAML syntax is valid
GitLab CI/CD is enabled
rules allow this branch/event
runner is available
```

## Job stuck

Usually:

```text id="kn9qgg"
no runner
runner offline
runner tags mismatch
protected runner restrictions
```

## `npm ci` fails

Check:

```text id="j5cp4c"
wrong APP_DIR
missing package-lock.json
Node version mismatch
package-lock does not match package.json
```

## Docker-in-Docker fails

Check:

```text id="agxxkk"
runner uses Docker executor
runner privileged mode enabled
docker:dind service running
DOCKER_TLS_CERTDIR setting
docker client/server connectivity
```

## Artifacts missing

Check:

```text id="65rg49"
paths are relative to project root
file exists before job exits
artifact expiry not too short
needs includes artifacts if used
```

## Cache not working

Check:

```text id="q70td7"
cache key
cache path
runner cache storage
lockfile path
branch-specific cache behavior
```

---

# 35. Interview Explanation

## What is GitLab CI/CD?

Strong answer:

```text id="vxmhhu"
GitLab CI/CD is GitLab’s pipeline automation system. Pipelines are defined in a `.gitlab-ci.yml` file and contain jobs organized into stages. Jobs run on GitLab Runners and execute script commands to test, build, scan, publish, deploy, and verify software.
```

## What is a GitLab Runner?

Strong answer:

```text id="ssq11r"
A GitLab Runner is the worker that executes CI/CD jobs. It can use executors such as shell, Docker, Kubernetes, or custom executors. For production, runners should be separated and protected based on job trust level.
```

## Cache vs artifacts in GitLab?

Strong answer:

```text id="yfx2bc"
Cache is used to speed up jobs by reusing dependencies such as npm or Maven caches. Artifacts are job outputs such as reports, SBOMs, release metadata, and build results that should be stored and passed between jobs or downloaded after the pipeline.
```

## What are `rules`?

Strong answer:

```text id="ph7i57"
`rules` decide whether a GitLab CI job runs and under what condition. They are used to separate merge request validation, main branch builds, tag releases, and manual deployment jobs.
```

## What is Docker-in-Docker?

Strong answer:

```text id="1n7uya"
Docker-in-Docker lets a GitLab CI job use a Docker daemon service to build and push Docker images. It often requires privileged runners, so it should be restricted and used carefully.
```

## How do you do production approval in GitLab CI?

Strong answer:

```text id="lkiwt1"
A common pattern is to use a deployment job with `when: manual`, assign it to the production environment, and require it to deploy a specific immutable artifact tag rather than rebuilding or deploying latest.
```

---

# 36. Commit Work

Run:

```bash id="w4socm"
cd ~/devops-masterclass

git status
git add 08-cicd-pipelines/gitlab

git commit -m "feat: add GitLab CI fundamentals"
git push
```

If you copied `.gitlab-ci.yml` to root:

```bash id="5iv7vb"
git add .gitlab-ci.yml
git commit -m "feat: add GitLab CI learning pipeline"
git push
```

---

# 37. Today’s Core Rules

```text id="cmynap"
GitLab CI uses .gitlab-ci.yml.
Stages define pipeline order.
Jobs perform work.
Scripts run commands.
Runners execute jobs.
Images make jobs reproducible.
Variables store config.
Secrets belong in CI/CD variables.
Cache dependencies, not release evidence.
Artifacts preserve job outputs.
Rules control when jobs run.
Needs defines explicit dependencies.
Services provide test dependencies.
Docker-in-Docker requires privileged runners.
Production deployment should be manual/protected.
Do not deploy latest.
Build once, promote many.
```

---

# Next Lesson

# Lesson 8.7 — GitLab CI Production Pipeline

We will build the full production GitLab CI version of your pipeline:

```text id="5f0wr3"
version computation
Node.js tests
Docker build
container registry push
Trivy scan
SBOM artifact
provenance record
release metadata
staging deployment placeholder
manual production deployment
rollback metadata
protected variables
protected runners
pipeline artifacts
```

[1]: https://docs.gitlab.com/ci/yaml/?utm_source=chatgpt.com "CI/CD YAML syntax reference"
[2]: https://docs.gitlab.com/ci/jobs/?utm_source=chatgpt.com "CI/CD Jobs"
[3]: https://docs.gitlab.com/ci/docker/using_docker_images/?utm_source=chatgpt.com "Run your CI/CD jobs in Docker containers"
[4]: https://docs.gitlab.com/ci/variables/predefined_variables/?utm_source=chatgpt.com "Predefined CI/CD variables reference"
[5]: https://docs.gitlab.com/ci/caching/?utm_source=chatgpt.com "Caching in GitLab CI/CD"
[6]: https://docs.gitlab.com/ci/jobs/job_artifacts/?utm_source=chatgpt.com "Job artifacts"
[7]: https://docs.gitlab.com/ci/docker/docker_in_docker/?utm_source=chatgpt.com "Use Docker-in-Docker"
[8]: https://docs.gitlab.com/ci/docker/using_docker_build/?utm_source=chatgpt.com "Use Docker to build Docker images | GitLab Docs"

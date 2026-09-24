# Lesson 8.2 — GitHub Actions Fundamentals Masterclass

# Workflow Syntax, Events, Jobs, Steps, Runners, Actions, Permissions, Env, Secrets, Caching, Artifacts, Matrix Builds, and Common Errors

GitHub Actions is GitHub’s CI/CD automation platform. A workflow is defined as a YAML file inside your repository, usually under:

```text id="u25cfj"
.github/workflows/
```

A workflow is made of one or more jobs, and jobs are made of steps. Steps can run shell commands or call reusable actions from the GitHub Marketplace or a repository. ([GitHub Docs][1])

---

# 1. GitHub Actions Mental Model

Think like this:

```text id="p2zb1k"
repository
  ↓
.github/workflows/*.yml
  ↓
workflow
  ↓
event trigger
  ↓
jobs
  ↓
runner
  ↓
steps
  ↓
commands/actions
```

Example:

```yaml id="5xdp55"
name: Basic CI

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Run command
        run: echo "Hello CI/CD"
```

Meaning:

```text id="wfnzdx"
name:
  workflow display name

on:
  event that triggers workflow

jobs:
  work units

runs-on:
  runner machine

steps:
  commands or actions inside job
```

---

# 2. Workflow File Location

GitHub only detects workflow files placed here:

```text id="n4tf21"
.github/workflows/<workflow-name>.yml
.github/workflows/<workflow-name>.yaml
```

Example:

```bash id="mhhzdy"
cd ~/devops-masterclass

mkdir -p .github/workflows
```

For learning, we also keep examples in Module 8:

```text id="cqh9ac"
08-cicd-pipelines/github-actions/
```

Final workflows go into:

```text id="yk0y0v"
.github/workflows/
```

---

# 3. Workflow Events

Events decide **when** the workflow runs.

Common events:

```yaml id="s3bizr"
on:
  push:
  pull_request:
  workflow_dispatch:
```

Common production pattern:

```yaml id="emh1h4"
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
```

Meaning:

```text id="t2hkkm"
push:
  run when code is pushed

pull_request:
  run when PR is opened/updated

workflow_dispatch:
  allow manual run from GitHub UI
```

GitHub workflow syntax supports many trigger events and also supports manual workflows through `workflow_dispatch`. ([GitHub Docs][1])

---

# 4. Jobs

A job is a unit of work.

Example:

```yaml id="g5q8wd"
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Running tests"

  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Building artifact"
```

By default, jobs can run in parallel.

If one job must wait for another:

```yaml id="z23zkd"
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - run: echo "build"
```

Meaning:

```text id="vn7gmg"
build waits for test
```

Professional rule:

```text id="rw3lh6"
Use `needs` to model real pipeline dependencies.
```

---

# 5. Steps

A step is one action or shell command inside a job.

Command step:

```yaml id="it8d68"
- name: Run tests
  run: npm test
```

Action step:

```yaml id="qhfb0n"
- name: Checkout
  uses: actions/checkout@v4
```

Working directory:

```yaml id="806muu"
- name: Run backend tests
  working-directory: 05-application-runtime/demo-node-api
  run: npm test
```

Multi-line shell:

```yaml id="v3ree8"
- name: Show context
  run: |
    node --version
    npm --version
    pwd
    ls -la
```

GitHub Actions steps can run scripts or actions, and all steps in one job execute on the same runner. ([GitHub Docs][2])

---

# 6. Runners

A runner is the machine that executes your job.

Example:

```yaml id="erh8wu"
runs-on: ubuntu-latest
```

Common GitHub-hosted runners:

```text id="pyvriu"
ubuntu-latest
windows-latest
macos-latest
```

For DevOps/Linux/Docker workflows, use:

```yaml id="bazclp"
runs-on: ubuntu-latest
```

Professional note:

```text id="jhfo9m"
GitHub-hosted runners are temporary machines. Do not expect files from one workflow run to exist in the next run unless you upload artifacts, use cache, or push to an external store.
```

---

# 7. Actions

Actions are reusable workflow building blocks.

Examples:

```yaml id="qg5n5b"
- uses: actions/checkout@v4

- uses: actions/setup-node@v4
  with:
    node-version: "22"
```

Good practice:

```text id="mk0yxb"
Pin action versions.
Use official or trusted actions.
Avoid random unreviewed third-party actions in production workflows.
```

For stronger security, enterprises often pin actions to a commit SHA instead of a version tag.

Example:

```yaml id="c0gh6e"
- uses: actions/checkout@v4
```

is easy and common.

Stronger:

```yaml id="bqgvn9"
- uses: actions/checkout@<full-commit-sha>
```

---

# 8. Permissions

This is very important.

GitHub workflows use `GITHUB_TOKEN` for repository automation, and workflow permissions control what that token can do. GitHub recommends granting the minimum required permissions. ([GitHub Docs][3])

Basic read-only workflow:

```yaml id="ls7oz6"
permissions:
  contents: read
```

Workflow that publishes to GHCR:

```yaml id="zvbq2l"
permissions:
  contents: read
  packages: write
```

Workflow that uses OIDC to AWS:

```yaml id="5e40td"
permissions:
  contents: read
  id-token: write
```

Workflow that creates attestations:

```yaml id="y9x99r"
permissions:
  contents: read
  packages: write
  id-token: write
  attestations: write
```

Bad:

```yaml id="d4bacn"
permissions: write-all
```

Good:

```yaml id="iyyp0g"
permissions:
  contents: read
  packages: write
```

Professional rule:

```text id="kz7hpq"
Set explicit minimal permissions at the top of every workflow.
```

---

# 9. Environment Variables

Workflow-level env:

```yaml id="6zx1uz"
env:
  APP_DIR: 05-application-runtime/demo-node-api
  NODE_VERSION: "22"
```

Job-level env:

```yaml id="ungxhq"
jobs:
  test:
    env:
      APP_ENV: test
```

Step-level env:

```yaml id="62vbh6"
- name: Run test
  env:
    LOG_LEVEL: debug
  run: npm test
```

Use env when values are:

```text id="a8hppm"
non-secret
reused
configuration-like
safe to print
```

Do not put secrets in `env` directly unless pulling them from GitHub secrets.

---

# 10. Secrets

Secrets are sensitive values stored in GitHub repository/org/environment settings.

Use:

```yaml id="5v3zt1"
env:
  GHCR_TOKEN: ${{ secrets.GHCR_TOKEN }}
```

GitHub docs explain that secrets can be accessed through the `secrets` context in workflows. ([GitHub Docs][4])

Bad:

```yaml id="68hhxc"
env:
  PASSWORD: my-real-password
```

Good:

```yaml id="a03hob"
env:
  PASSWORD: ${{ secrets.PROD_PASSWORD }}
```

Rules:

```text id="auyewk"
Never echo secrets.
Never commit secrets.
Never print full environment in CI.
Use OIDC instead of static cloud keys where possible.
Use environment secrets for staging/prod separation.
```

---

# 11. Contexts

Contexts are GitHub Actions objects that expose workflow data.

Examples:

```yaml id="bumtg4"
${{ github.sha }}
${{ github.ref }}
${{ github.repository }}
${{ github.actor }}
${{ secrets.GHCR_TOKEN }}
${{ env.APP_DIR }}
${{ steps.version.outputs.deploy_tag }}
```

GitHub provides a contexts reference for values available in workflows, including `github`, `env`, `secrets`, `steps`, `job`, and others. ([GitHub Docs][5])

Example:

```yaml id="2bmx37"
- name: Show GitHub context
  run: |
    echo "Repository: ${{ github.repository }}"
    echo "Commit: ${{ github.sha }}"
    echo "Actor: ${{ github.actor }}"
```

Do not print sensitive contexts.

---

# 12. Outputs Between Steps

A step can produce an output.

Example:

```yaml id="2febpp"
- name: Compute version
  id: version
  run: |
    SHORT_SHA="${GITHUB_SHA::7}"
    DEPLOY_TAG="0.8.0-dev-$SHORT_SHA"

    echo "short_sha=$SHORT_SHA" >> "$GITHUB_OUTPUT"
    echo "deploy_tag=$DEPLOY_TAG" >> "$GITHUB_OUTPUT"

- name: Use version
  run: |
    echo "Deploy tag: ${{ steps.version.outputs.deploy_tag }}"
```

This pattern is very important for CI/CD.

You will use it for:

```text id="f5n07o"
Docker tags
release metadata
image names
artifact names
deployment versions
```

GitHub workflow commands support setting outputs and communicating values between steps. ([GitHub Docs][6])

---

# 13. Dependency Caching

Caching speeds up pipelines.

For Node.js:

```yaml id="awwgox"
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: "22"
    cache: npm
    cache-dependency-path: 05-application-runtime/demo-node-api/package-lock.json
```

GitHub dependency caching stores files that do not change often between workflow runs, such as package manager dependencies, and a cache hit occurs when the key matches an existing cache. ([GitHub Docs][7])

Important distinction:

```text id="imnuae"
cache:
  reuse dependencies between runs

artifact:
  save output files from a workflow run
```

GitHub docs explicitly distinguish dependency caches from workflow artifacts: caches are for reusable dependencies, while artifacts are for files produced by a workflow run. ([GitHub Docs][8])

---

# 14. Artifacts

Artifacts are files saved from a workflow run.

Examples:

```text id="sql6cb"
test reports
coverage reports
SBOM files
release metadata
deployment reports
logs
build outputs
```

Upload artifact:

```yaml id="sevxj2"
- name: Upload release metadata
  uses: actions/upload-artifact@v4
  with:
    name: release-metadata
    path: 07-artifact-management-registries/release-records/
```

Download artifact in another job:

```yaml id="06u69k"
- name: Download release metadata
  uses: actions/download-artifact@v4
  with:
    name: release-metadata
```

GitHub provides workflow artifact features to store and share data produced by workflow jobs. ([GitHub Docs][9])

---

# 15. Matrix Builds

Matrix builds run job variations.

Example:

```yaml id="npljye"
strategy:
  matrix:
    node-version: [20, 22]

steps:
  - uses: actions/setup-node@v4
    with:
      node-version: ${{ matrix.node-version }}
```

This creates multiple job runs:

```text id="9awodr"
Node 20
Node 22
```

GitHub matrix strategy lets you use variables in one job definition to automatically create multiple job runs from combinations. ([GitHub Docs][10])

Use matrix for:

```text id="9e8bzz"
multiple Node versions
multiple operating systems
multiple package managers
multiple Docker targets
multiple Terraform versions
```

Do not overuse matrix when it increases cost without value.

---

# 16. Hands-On — Create Lesson Folder

Run:

```bash id="qeaowl"
cd ~/devops-masterclass/08-cicd-pipelines

mkdir -p github-actions/{workflows,notes,reports,examples}
```

---

# 17. Create GitHub Actions Fundamentals Notes

Create:

```bash id="mtzv3t"
nano github-actions/notes/github-actions-fundamentals.md
```

Paste:

````markdown id="lk5xrp"
# GitHub Actions Fundamentals

## Core Structure

```text
.github/workflows/*.yml
  workflow
    jobs
      job
        steps
````

## Core Keywords

* `name`: workflow name
* `on`: trigger events
* `permissions`: GITHUB_TOKEN permissions
* `env`: environment variables
* `jobs`: workflow jobs
* `runs-on`: runner type
* `steps`: actions or shell commands
* `uses`: reusable action
* `run`: shell command
* `with`: action inputs
* `needs`: job dependency
* `strategy.matrix`: job variations

## Events

Common events:

* `push`
* `pull_request`
* `workflow_dispatch`
* `schedule`

## Production Rules

* Use explicit permissions.
* Use least privilege.
* Do not print secrets.
* Use `npm ci`, not `npm install`, in CI.
* Cache dependencies safely.
* Upload reports as artifacts.
* Use immutable Docker tags.
* Avoid `latest` for production.
* Build once, promote many.

````

---

# 18. Create Basic Node.js CI Workflow

Create a learning copy:

```bash id="49o5dr"
nano github-actions/workflows/node-basic-ci.yml
````

Paste:

```yaml id="j6qodf"
name: Node Basic CI

on:
  push:
    branches:
      - main
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

env:
  APP_DIR: 05-application-runtime/demo-node-api
  NODE_VERSION: "22"

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
          node-version: ${{ env.NODE_VERSION }}
          cache: npm
          cache-dependency-path: ${{ env.APP_DIR }}/package-lock.json

      - name: Show versions
        run: |
          node --version
          npm --version

      - name: Install dependencies
        working-directory: ${{ env.APP_DIR }}
        run: npm ci

      - name: Run tests
        working-directory: ${{ env.APP_DIR }}
        run: npm test
```

Copy into real workflow path:

```bash id="bqpzf5"
cd ~/devops-masterclass

mkdir -p .github/workflows
cp 08-cicd-pipelines/github-actions/workflows/node-basic-ci.yml .github/workflows/node-basic-ci.yml
```

Commit later after validation.

---

# 19. Create Workflow With Step Outputs

Create:

```bash id="eyav63"
cd ~/devops-masterclass/08-cicd-pipelines

nano github-actions/workflows/version-output-demo.yml
```

Paste:

```yaml id="d0lpv4"
name: Version Output Demo

on:
  workflow_dispatch:

permissions:
  contents: read

env:
  BASE_VERSION: "0.8.0"

jobs:
  version:
    runs-on: ubuntu-latest

    steps:
      - name: Compute version
        id: version
        shell: bash
        run: |
          SHORT_SHA="${GITHUB_SHA::7}"
          DEPLOY_TAG="${BASE_VERSION}-dev-${SHORT_SHA}"

          echo "short_sha=$SHORT_SHA" >> "$GITHUB_OUTPUT"
          echo "deploy_tag=$DEPLOY_TAG" >> "$GITHUB_OUTPUT"

      - name: Show computed version
        run: |
          echo "Short SHA: ${{ steps.version.outputs.short_sha }}"
          echo "Deploy tag: ${{ steps.version.outputs.deploy_tag }}"
```

Copy if you want to test:

```bash id="dqwsr0"
cd ~/devops-masterclass
cp 08-cicd-pipelines/github-actions/workflows/version-output-demo.yml .github/workflows/version-output-demo.yml
```

---

# 20. Create Workflow With Artifacts

Create:

```bash id="2756ze"
cd ~/devops-masterclass/08-cicd-pipelines

nano github-actions/workflows/artifact-demo.yml
```

Paste:

```yaml id="fpckb9"
name: Artifact Demo

on:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  create-report:
    runs-on: ubuntu-latest

    steps:
      - name: Create report
        run: |
          mkdir -p reports

          cat > reports/report.json <<EOF
          {
            "workflow": "artifact-demo",
            "commit": "${GITHUB_SHA}",
            "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
          }
          EOF

          cat reports/report.json

      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: demo-report
          path: reports/report.json

  consume-report:
    needs: create-report
    runs-on: ubuntu-latest

    steps:
      - name: Download report
        uses: actions/download-artifact@v4
        with:
          name: demo-report
          path: downloaded-report

      - name: Show report
        run: |
          cat downloaded-report/report.json
```

This teaches:

```text id="qflfwc"
one job creates artifact
another job consumes artifact
```

---

# 21. Create Workflow With Matrix Build

Create:

```bash id="10fn04"
nano github-actions/workflows/node-matrix-ci.yml
```

Paste:

```yaml id="f9im94"
name: Node Matrix CI

on:
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

env:
  APP_DIR: 05-application-runtime/demo-node-api

jobs:
  test:
    name: Test on Node ${{ matrix.node-version }}
    runs-on: ubuntu-latest

    strategy:
      fail-fast: false
      matrix:
        node-version: [20, 22]

    steps:
      - name: Checkout source
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: npm
          cache-dependency-path: ${{ env.APP_DIR }}/package-lock.json

      - name: Install dependencies
        working-directory: ${{ env.APP_DIR }}
        run: npm ci

      - name: Run tests
        working-directory: ${{ env.APP_DIR }}
        run: npm test
```

Professional note:

```text id="vbjibg"
Use matrix builds for compatibility checks, not for every pipeline if it slows feedback unnecessarily.
```

---

# 22. Create First Production-Style GitHub Actions CI

Now create a stronger workflow for your actual app.

Create:

```bash id="x5lndp"
nano github-actions/workflows/node-production-ci.yml
```

Paste:

```yaml id="22hog4"
name: Node Production CI

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read

env:
  APP_DIR: 05-application-runtime/demo-node-api
  NODE_VERSION: "22"
  BASE_VERSION: "0.8.0"

jobs:
  validate:
    name: Validate source
    runs-on: ubuntu-latest

    steps:
      - name: Checkout source
        uses: actions/checkout@v4

      - name: Show pipeline context
        run: |
          echo "Repository: ${{ github.repository }}"
          echo "Actor: ${{ github.actor }}"
          echo "Ref: ${{ github.ref }}"
          echo "SHA: ${{ github.sha }}"

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

      - name: Compute version
        id: version
        shell: bash
        run: |
          SHORT_SHA="${GITHUB_SHA::7}"

          if [[ "${GITHUB_REF_TYPE}" == "tag" ]]; then
            VERSION="${GITHUB_REF_NAME#v}"
            CHANNEL="stable"
          elif [[ "${GITHUB_REF_NAME}" == "main" ]]; then
            VERSION="${BASE_VERSION}-dev"
            CHANNEL="dev"
          else
            SAFE_REF="$(echo "${GITHUB_REF_NAME}" | tr '/' '-' | tr -cd 'a-zA-Z0-9._-')"
            VERSION="${BASE_VERSION}-${SAFE_REF}"
            CHANNEL="branch"
          fi

          DEPLOY_TAG="$VERSION-$SHORT_SHA"

          echo "short_sha=$SHORT_SHA" >> "$GITHUB_OUTPUT"
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
          echo "channel=$CHANNEL" >> "$GITHUB_OUTPUT"
          echo "deploy_tag=$DEPLOY_TAG" >> "$GITHUB_OUTPUT"

      - name: Create CI report
        run: |
          mkdir -p ci-reports

          cat > ci-reports/node-ci-report.json <<EOF
          {
            "workflow": "Node Production CI",
            "repository": "${{ github.repository }}",
            "ref": "${{ github.ref }}",
            "sha": "${{ github.sha }}",
            "version": "${{ steps.version.outputs.version }}",
            "deploy_tag": "${{ steps.version.outputs.deploy_tag }}",
            "test_status": "passed",
            "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
          }
          EOF

          cat ci-reports/node-ci-report.json

      - name: Upload CI report
        uses: actions/upload-artifact@v4
        with:
          name: node-ci-report-${{ steps.version.outputs.deploy_tag }}
          path: ci-reports/
```

Copy:

```bash id="54pq0h"
cd ~/devops-masterclass

cp 08-cicd-pipelines/github-actions/workflows/node-production-ci.yml .github/workflows/node-production-ci.yml
```

---

# 23. Validate Workflow YAML Locally

Basic check:

```bash id="wu52gb"
cd ~/devops-masterclass

find .github/workflows -name "*.yml" -print
```

If you have `yamllint`:

```bash id="hz1dln"
yamllint .github/workflows/node-basic-ci.yml
yamllint .github/workflows/node-production-ci.yml
```

Install if needed:

```bash id="qaatrp"
python3 -m pip install --user yamllint
```

Use `git diff`:

```bash id="6g0isr"
git diff -- .github/workflows 08-cicd-pipelines
```

---

# 24. Common GitHub Actions Errors

## Error: workflow does not run

Check:

```text id="axk0nn"
file is inside .github/workflows/
file extension is .yml or .yaml
YAML syntax is valid
event matches your action
branch filter matches current branch
workflow is committed and pushed
Actions are enabled in repository
```

---

## Error: `npm ci` fails

Common causes:

```text id="xbkdsl"
package-lock.json missing
package.json and package-lock.json mismatch
wrong working-directory
wrong Node.js version
private npm package auth missing
```

Fix:

```bash id="a438a7"
cd 05-application-runtime/demo-node-api
npm install
git add package-lock.json
```

---

## Error: wrong directory

Bad:

```yaml id="6m9d6e"
run: npm test
```

from repo root when app is in subfolder.

Good:

```yaml id="brcsbl"
working-directory: 05-application-runtime/demo-node-api
run: npm test
```

---

## Error: permission denied for package push

Fix:

```yaml id="f5o2xl"
permissions:
  contents: read
  packages: write
```

Also check GHCR package settings if the package already exists.

---

## Error: secret empty

Check:

```text id="su2zku"
secret name matches exactly
secret is configured at repository/org/environment level
workflow environment is correct
PR from fork may not receive secrets
```

Do not debug by printing the secret.

---

## Error: cache not working

Check:

```text id="3jw824"
cache-dependency-path points to correct lockfile
lockfile is committed
package manager matches cache setting
```

GitHub cache behavior depends on cache keys; an exact key match is a cache hit, otherwise a new cache can be created after successful job completion. ([GitHub Docs][7])

---

# 25. GitHub Actions Security Rules

GitHub’s secure-use reference covers best practices for workflows and security features. ([GitHub Docs][11])

Use these rules:

```text id="100xju"
Set explicit permissions.
Use least privilege.
Do not print secrets.
Use trusted actions.
Pin action versions.
Avoid running untrusted PR code with secrets.
Use OIDC instead of long-lived cloud keys.
Use environments for production approvals.
Separate CI and CD permissions.
```

Dangerous pattern:

```yaml id="61y41q"
pull_request_target:
  steps:
    - run: ./script-from-pr.sh
```

Why dangerous?

```text id="otgdoo"
pull_request_target can run with elevated permissions in the base repository context. Be very careful with untrusted PR code.
```

For now, use:

```yaml id="mlm578"
pull_request:
```

for normal PR validation.

---

# 26. Create GitHub Actions Troubleshooting Notes

Create:

```bash id="1vrjhe"
cd ~/devops-masterclass/08-cicd-pipelines

nano github-actions/notes/github-actions-troubleshooting.md
```

Paste:

````markdown id="uifm2f"
# GitHub Actions Troubleshooting

## Workflow does not appear

Check:

- file is in `.github/workflows/`
- file extension is `.yml` or `.yaml`
- YAML syntax is valid
- workflow is committed and pushed
- Actions are enabled

## Workflow does not trigger

Check:

- `on:` event matches action
- branch filters match
- tag filters match
- path filters if used
- workflow file exists on default branch for some event types

## npm ci fails

Check:

```bash
cd 05-application-runtime/demo-node-api
npm ci
````

Common causes:

* missing lockfile
* package-lock mismatch
* wrong Node version
* wrong working directory

## Permission denied to GHCR

Check:

```yaml
permissions:
  contents: read
  packages: write
```

Also check package access settings.

## Secret unavailable

Check:

* secret name spelling
* repository/org/environment scope
* fork PR restrictions
* environment approval rules

## Docker build fails

Check:

* Dockerfile path
* context path
* `.dockerignore`
* missing files
* build args

## Best Debug Commands

```yaml
- run: |
    pwd
    ls -la
    git status
    node --version
    npm --version
    docker --version
```

Never print secrets.

````

---

# 27. Create GitHub Actions Best Practices Notes

Create:

```bash id="mlc9xd"
nano github-actions/notes/github-actions-best-practices.md
````

Paste:

```markdown id="kpizob"
# GitHub Actions Best Practices

## Workflow Design

- Keep workflows readable.
- Split CI and CD when complexity grows.
- Use job names clearly.
- Use `needs` for dependencies.
- Upload reports as artifacts.
- Use workflow_dispatch for controlled manual runs.

## Security

- Use minimal permissions.
- Avoid `write-all`.
- Avoid printing secrets.
- Prefer OIDC for cloud authentication.
- Use GitHub Environments for production approval.
- Use trusted actions.
- Pin action versions.

## Node.js

- Use `npm ci`.
- Commit `package-lock.json`.
- Use `actions/setup-node` cache.
- Set correct working directory.

## Docker

- Use immutable tags.
- Avoid `latest` for production.
- Build once and promote.
- Push to GHCR/ECR.
- Generate SBOM/provenance for production.

## Debugging

- Print safe context only.
- Use artifacts for logs/reports.
- Keep failed workflow logs.
- Reproduce locally when possible.
```

---

# 28. Update Module 8 Makefile

Open:

```bash id="mktpwc"
cd ~/devops-masterclass/08-cicd-pipelines

nano Makefile
```

Replace or extend with:

```Makefile id="9ocfln"
ROOT_DIR ?= $(HOME)/devops-masterclass
BASE_VERSION ?= 0.8.0
CHANNEL ?= dev

.PHONY: simulator validate-notes show-stages copy-gha validate-gha list-gha

simulator:
	BASE_VERSION="$(BASE_VERSION)" CHANNEL="$(CHANNEL)" ./shared-scripts/pipeline-simulator.sh

show-stages:
	jq . examples/universal-pipeline-stages.json

validate-notes:
	@test -f notes/ci-cd-mental-model.md
	@test -f notes/github-jenkins-gitlab-comparison.md
	@test -f notes/cicd-quality-gates.md
	@test -f runbooks/cicd-troubleshooting.md
	@test -f github-actions/notes/github-actions-fundamentals.md
	@test -f github-actions/notes/github-actions-troubleshooting.md
	@test -f github-actions/notes/github-actions-best-practices.md
	@echo "Module 8 notes validated."

copy-gha:
	mkdir -p $(ROOT_DIR)/.github/workflows
	cp github-actions/workflows/node-basic-ci.yml $(ROOT_DIR)/.github/workflows/node-basic-ci.yml
	cp github-actions/workflows/node-production-ci.yml $(ROOT_DIR)/.github/workflows/node-production-ci.yml
	@echo "GitHub Actions workflows copied."

list-gha:
	find $(ROOT_DIR)/.github/workflows -maxdepth 1 -type f -name "*.yml" -print

validate-gha:
	@test -f $(ROOT_DIR)/.github/workflows/node-basic-ci.yml
	@test -f $(ROOT_DIR)/.github/workflows/node-production-ci.yml
	@echo "GitHub Actions workflow files exist."
```

Run:

```bash id="zfzabr"
make validate-notes
make copy-gha
make list-gha
make validate-gha
```

---

# 29. Practical Lab

Run full lab:

```bash id="1qpapu"
cd ~/devops-masterclass/08-cicd-pipelines

make validate-notes
make copy-gha
make list-gha
make validate-gha
```

Check workflow files:

```bash id="3iuf2y"
cd ~/devops-masterclass

ls -la .github/workflows
cat .github/workflows/node-basic-ci.yml
cat .github/workflows/node-production-ci.yml
```

Commit and push:

```bash id="wq4g2y"
git status

git add .github/workflows/node-basic-ci.yml \
        .github/workflows/node-production-ci.yml \
        08-cicd-pipelines

git commit -m "feat: add GitHub Actions fundamentals workflows"
git push
```

After push, go to GitHub:

```text id="uxdh2q"
Repository
  -> Actions tab
  -> Node Basic CI
  -> Node Production CI
```

Expected:

```text id="ko8yiz"
workflow starts
runner provisions
checkout runs
Node.js setup runs
npm ci runs
npm test runs
CI report artifact uploads
```

---

# 30. Interview Explanation

## What is a GitHub Actions workflow?

Strong answer:

```text id="6yswpt"
A GitHub Actions workflow is an automated process defined in a YAML file under `.github/workflows`. It is triggered by events like push, pull_request, or workflow_dispatch, and it contains jobs made of steps that run on GitHub-hosted or self-hosted runners.
```

## What is the difference between jobs and steps?

Strong answer:

```text id="2nwyv8"
A job is a unit of work that runs on a runner. A step is an individual command or reusable action inside that job. Steps in a job run sequentially on the same runner, while jobs can run in parallel unless dependencies are defined with `needs`.
```

## What is `runs-on`?

Strong answer:

```text id="041esm"
`runs-on` selects the runner environment for a job, such as `ubuntu-latest`. The runner is the machine where the workflow job executes.
```

## Why use `npm ci` in CI?

Strong answer:

```text id="hwx1lb"
`npm ci` installs dependencies from the lockfile in a clean and deterministic way, which is better for CI than `npm install` because CI should reproduce the dependency tree exactly.
```

## Why set workflow permissions explicitly?

Strong answer:

```text id="69a2y7"
Explicit permissions reduce the power of the workflow token. A CI workflow may only need `contents: read`, while a registry-publishing workflow may need `packages: write`. This follows least privilege and reduces blast radius if a workflow is compromised.
```

## Cache vs artifact?

Strong answer:

```text id="2p9q2n"
A cache stores reusable dependencies between workflow runs to speed up future jobs. An artifact stores files produced by a workflow run, such as reports, logs, SBOMs, or release metadata, so they can be downloaded or used by later jobs.
```

## What is a matrix build?

Strong answer:

```text id="h9128t"
A matrix build runs the same job with multiple variable combinations, such as different Node.js versions or operating systems. It is useful for compatibility testing.
```

---

# 31. Today’s Core Rules

```text id="bb3cov"
Workflow files live in .github/workflows.
Events trigger workflows.
Jobs run on runners.
Steps run commands or actions.
Use explicit permissions.
Use npm ci for CI.
Use working-directory for subfolder apps.
Use cache for dependencies.
Use artifacts for reports.
Use outputs to pass values between steps.
Use matrix builds for compatibility.
Never print secrets.
Do not use latest for production.
Keep CI workflows small before making them complex.
```

---

# Next Lesson

# Lesson 8.3 — GitHub Actions Production Pipeline

We will build a full production-grade workflow:

```text id="2q61k0"
checkout
Node.js setup
dependency cache
tests
Docker build
Docker metadata
container scan
GHCR login
image push
SBOM/provenance
Cosign signing
release metadata artifact
staging promotion
production environment approval
deployment placeholder
rollback metadata
```

[1]: https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions?utm_source=chatgpt.com "Workflow syntax for GitHub Actions"
[2]: https://docs.github.com/articles/getting-started-with-github-actions?utm_source=chatgpt.com "Understanding GitHub Actions"
[3]: https://docs.github.com/actions/reference/authentication-in-a-workflow?utm_source=chatgpt.com "Use GITHUB_TOKEN for authentication in workflows"
[4]: https://docs.github.com/actions/security-guides/using-secrets-in-github-actions?utm_source=chatgpt.com "Using secrets in GitHub Actions"
[5]: https://docs.github.com/en/actions/reference/workflows-and-actions/contexts?utm_source=chatgpt.com "Contexts reference"
[6]: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands?utm_source=chatgpt.com "Workflow commands for GitHub Actions"
[7]: https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching?utm_source=chatgpt.com "Dependency caching reference - GitHub Actions"
[8]: https://docs.github.com/en/enterprise-server%403.20/actions/concepts/workflows-and-actions/dependency-caching?utm_source=chatgpt.com "Dependency caching - GitHub Enterprise Server 3.20 Docs"
[9]: https://docs.github.com/en/actions/tutorials/store-and-share-data?utm_source=chatgpt.com "Store and share data with workflow artifacts"
[10]: https://docs.github.com/actions/writing-workflows/choosing-what-your-workflow-does/running-variations-of-jobs-in-a-workflow?utm_source=chatgpt.com "Running variations of jobs in a workflow"
[11]: https://docs.github.com/en/actions/reference/security/secure-use?utm_source=chatgpt.com "Secure use reference - GitHub Docs"

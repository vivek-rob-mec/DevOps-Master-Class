# Lesson 2.5 — GitHub Actions Foundation: CI Workflow, Status Checks, Secrets, Artifacts, Matrix Builds

Now we enter automation.

Until now, we learned:

```text
Issue → Branch → Commit → Pull Request → Review → Merge → Release
```

But in real DevOps, humans should not manually verify everything.

CI should automatically check every important change.

Your uploaded curriculum already includes GitHub Actions anatomy, triggers, runners, contexts, matrix builds, reusable workflows, environments, security scans, and approval gates, so this lesson starts that CI/CD foundation properly. 

---

# 1. What is GitHub Actions?

GitHub Actions is GitHub’s built-in automation system.

It can run jobs when something happens in your repository.

Examples:

```text
Pull request opened
Code pushed to main
Tag created
Issue opened
Manual workflow triggered
Scheduled time reached
```

In DevOps, GitHub Actions is used for:

```text
CI testing
Linting
Security scanning
Docker image building
Artifact publishing
Terraform validation
Kubernetes deployment
Release creation
Documentation checks
```

---

# 2. What is CI?

CI means **Continuous Integration**.

CI answers:

```text
Can this change safely merge into main?
```

A CI workflow usually checks:

```text
Does the code build?
Do tests pass?
Does lint pass?
Are scripts valid?
Are secrets leaked?
Are dependencies safe?
Does Docker build?
Does Terraform validate?
```

CI is not deployment yet.

CI protects `main`.

---

# 3. GitHub Actions Core Building Blocks

A workflow has this structure:

```yaml
name: Workflow Name

on:
  pull_request:
    branches:
      - main

jobs:
  job-name:
    runs-on: ubuntu-latest

    steps:
      - name: Step name
        run: echo "Hello"
```

Now understand each part.

---

## `name`

The workflow name shown in GitHub UI.

```yaml
name: Validate Repository
```

---

## `on`

Defines when the workflow runs.

```yaml
on:
  pull_request:
    branches:
      - main
```

This means:

```text
Run when a pull request targets main.
```

Other common triggers:

```yaml
on:
  push:
    branches:
      - main
```

```yaml
on:
  push:
    tags:
      - "v*.*.*"
```

```yaml
on:
  workflow_dispatch:
```

`workflow_dispatch` means manual trigger from GitHub UI.

---

## `jobs`

A workflow contains one or more jobs.

```yaml
jobs:
  validate:
    runs-on: ubuntu-latest
```

A job runs on a runner.

---

## `runs-on`

Defines the machine used to run the job.

```yaml
runs-on: ubuntu-latest
```

Common runners:

```text
ubuntu-latest
windows-latest
macos-latest
self-hosted
```

For DevOps work, `ubuntu-latest` is most common.

---

## `steps`

Steps are commands or actions inside a job.

```yaml
steps:
  - name: Checkout repository
    uses: actions/checkout@v4

  - name: Run validation
    run: echo "Validating..."
```

Steps run in order.

---

## `uses`

Uses a prebuilt GitHub Action.

```yaml
uses: actions/checkout@v4
```

This downloads your repo into the runner.

Without checkout, the runner has no code.

---

## `run`

Runs shell commands.

```yaml
run: |
  echo "Hello"
  ls -la
```

---

# 4. First CI Workflow

Create this file:

```bash
mkdir -p .github/workflows
nano .github/workflows/ci.yml
```

Paste:

```yaml
name: CI

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main

jobs:
  validate:
    name: Validate repository
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Show runner info
        run: |
          echo "Runner OS: $RUNNER_OS"
          echo "Repository: $GITHUB_REPOSITORY"
          echo "Branch: $GITHUB_REF"
          pwd
          ls -la

      - name: Validate required structure
        run: |
          test -d 00-notes
          test -d 02-git-github
          test -f README.md
          test -f .gitignore

      - name: Validate shell scripts
        run: |
          find . -name "*.sh" -print0 | xargs -0 -r bash -n

      - name: Block committed env files
        run: |
          if find . -name ".env" -o -name ".env.*" | grep -v ".env.example"; then
            echo "Real environment file detected. Do not commit secrets."
            exit 1
          fi
```

This workflow checks:

```text
Repository structure
Shell syntax
Accidental .env files
```

---

# 5. Important Fix for `.env.example`

This command:

```bash
find . -name ".env" -o -name ".env.*" | grep -v ".env.example"
```

can behave unexpectedly because of operator precedence.

Better version:

```yaml
- name: Block committed env files
  run: |
    disallowed_files=$(find . \( -name ".env" -o -name ".env.*" \) ! -name ".env.example")
    if [ -n "$disallowed_files" ]; then
      echo "Real environment files detected:"
      echo "$disallowed_files"
      exit 1
    fi
```

Use this improved version.

Why?

```text
It explicitly groups .env patterns and excludes .env.example.
```

This is how you think like a DevOps engineer: even validation scripts need correctness.

---

# 6. Status Checks

A status check is the result of a workflow on a PR.

Examples:

```text
CI / Validate repository — passed
CI / Validate repository — failed
```

In GitHub branch protection, you can require status checks before merge.

Go to:

```text
Repository → Settings → Branches → Branch protection rule
```

Enable:

```text
Require status checks to pass before merging
```

Select your CI workflow.

This means:

```text
No passing CI = no merge to main.
```

That is a production safety gate.

---

# 7. Workflow Contexts

GitHub provides built-in variables called contexts.

Examples:

```yaml
${{ github.repository }}
${{ github.ref }}
${{ github.sha }}
${{ github.actor }}
${{ github.event_name }}
```

Use them like:

```yaml
- name: Print GitHub context
  run: |
    echo "Repository: ${{ github.repository }}"
    echo "Commit SHA: ${{ github.sha }}"
    echo "Actor: ${{ github.actor }}"
    echo "Event: ${{ github.event_name }}"
```

Important ones:

| Context             | Meaning                     |
| ------------------- | --------------------------- |
| `github.sha`        | Commit SHA                  |
| `github.ref`        | Branch or tag ref           |
| `github.actor`      | User who triggered workflow |
| `github.repository` | owner/repo                  |
| `secrets.NAME`      | GitHub secret               |
| `env.NAME`          | Environment variable        |
| `needs.job.outputs` | Output from previous job    |

---

# 8. Environment Variables

You can define env globally:

```yaml
env:
  APP_NAME: devops-masterclass
```

Use inside job:

```yaml
- name: Print app name
  run: echo "$APP_NAME"
```

Job-level env:

```yaml
jobs:
  validate:
    runs-on: ubuntu-latest
    env:
      MODULE: git-github
```

Step-level env:

```yaml
- name: Print module
  env:
    MODULE: module-02
  run: echo "$MODULE"
```

Precedence:

```text
Step env > job env > workflow env
```

---

# 9. Secrets

GitHub Secrets store sensitive values.

Examples:

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
AWS_ROLE_ARN
SLACK_WEBHOOK_URL
```

Add secrets here:

```text
Repository → Settings → Secrets and variables → Actions → New repository secret
```

Use secret:

```yaml
- name: Use secret safely
  run: echo "Secret exists"
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

Do **not** print secrets.

Bad:

```yaml
run: echo "${{ secrets.AWS_SECRET_ACCESS_KEY }}"
```

Good:

```yaml
run: |
  if [ -z "$SLACK_WEBHOOK_URL" ]; then
    echo "Missing secret"
    exit 1
  fi
```

Important rule:

```text
Secrets should be used, not displayed.
```

---

# 10. GitHub Actions Permissions

GitHub gives workflow tokens permissions.

Bad:

```yaml
permissions: write-all
```

Better:

```yaml
permissions:
  contents: read
```

For simple CI validation, use:

```yaml
permissions:
  contents: read
```

For creating releases, you may need:

```yaml
permissions:
  contents: write
```

For OIDC to AWS later:

```yaml
permissions:
  id-token: write
  contents: read
```

Rule:

```text
Give minimum permissions required.
```

This is DevSecOps thinking.

---

# 11. Artifacts

Artifacts are files saved from workflow runs.

Examples:

```text
Test reports
Coverage reports
Build files
Logs
Terraform plans
Security scan reports
```

Upload artifact:

```yaml
- name: Create report
  run: |
    mkdir -p reports
    echo "CI report for $GITHUB_SHA" > reports/ci-report.txt

- name: Upload CI report
  uses: actions/upload-artifact@v4
  with:
    name: ci-report
    path: reports/
```

Why artifacts matter:

```text
They preserve evidence from pipeline runs.
They help debugging.
They support audit trails.
```

Later we will upload:

```text
Jest reports
Coverage
Trivy scan reports
Terraform plan files
SBOM files
```

---

# 12. Job Dependencies

Multiple jobs can depend on each other.

Example:

```yaml
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - run: echo "validate"

  security:
    runs-on: ubuntu-latest
    needs: validate
    steps:
      - run: echo "security"
```

This means:

```text
security runs only after validate succeeds.
```

This is useful for pipelines:

```text
lint → test → scan → build → deploy
```

---

# 13. Matrix Builds

Matrix builds run the same job with multiple versions.

Example:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        node-version: [18, 20, 22]

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}

      - name: Show Node version
        run: node -v
```

This tests your project on Node 18, 20, and 22.

Use matrix when:

```text
Your app must support multiple versions.
You want compatibility confidence.
```

For production apps, you usually build with one pinned version, but testing multiple versions can be useful for libraries.

---

# 14. Caching

Caching speeds up workflows.

For Node:

```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: 20
    cache: npm
```

For Python:

```yaml
- name: Setup Python
  uses: actions/setup-python@v5
  with:
    python-version: "3.12"
    cache: pip
```

Why caching matters:

```text
Faster CI
Lower waiting time
Less repeated dependency download
```

But bad cache keys can cause stale dependency issues.

---

# 15. Manual Workflow Trigger

Add:

```yaml
on:
  workflow_dispatch:
```

This lets you run a workflow manually.

Useful for:

```text
Manual validation
Release workflows
Terraform plan
Security scans
Environment checks
```

Example:

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: "Target environment"
        required: true
        default: "dev"
        type: choice
        options:
          - dev
          - staging
          - production
```

Then use:

```yaml
${{ inputs.environment }}
```

---

# 16. Workflow Failure Behavior

By default, if a step fails, the job fails.

Example:

```yaml
- name: Run command
  run: exit 1
```

The workflow stops.

You can allow failure:

```yaml
continue-on-error: true
```

Use carefully.

For security scans, usually do **not** allow failure.

Bad:

```yaml
- name: Secret scan
  run: gitleaks detect
  continue-on-error: true
```

This hides serious risk.

---

# 17. Complete Beginner-Friendly CI Workflow

Use this as your improved CI file:

```yaml
name: CI

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read

env:
  PROJECT_NAME: devops-masterclass

jobs:
  validate:
    name: Validate repository
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Show workflow context
        run: |
          echo "Project: $PROJECT_NAME"
          echo "Repository: ${{ github.repository }}"
          echo "Event: ${{ github.event_name }}"
          echo "Commit: ${{ github.sha }}"
          echo "Actor: ${{ github.actor }}"

      - name: Validate required structure
        run: |
          test -d 00-notes
          test -d 02-git-github
          test -f README.md
          test -f .gitignore

      - name: Validate shell script syntax
        run: |
          find . -name "*.sh" -print0 | xargs -0 -r bash -n

      - name: Block committed env files
        run: |
          disallowed_files=$(find . \( -name ".env" -o -name ".env.*" \) ! -name ".env.example")
          if [ -n "$disallowed_files" ]; then
            echo "Real environment files detected:"
            echo "$disallowed_files"
            exit 1
          fi

      - name: Generate CI report
        run: |
          mkdir -p reports
          {
            echo "Project: $PROJECT_NAME"
            echo "Repository: ${{ github.repository }}"
            echo "Commit: ${{ github.sha }}"
            echo "Event: ${{ github.event_name }}"
            echo "Status: validation completed"
          } > reports/ci-report.txt

      - name: Upload CI report
        uses: actions/upload-artifact@v4
        with:
          name: ci-report
          path: reports/
```

---

# 18. Mini Lab — Add GitHub Actions CI Notes

Create issue:

```text
docs: add GitHub Actions foundation notes
```

Acceptance criteria:

```markdown
- [ ] Explain workflow structure
- [ ] Explain triggers
- [ ] Explain jobs and steps
- [ ] Explain secrets
- [ ] Explain artifacts
- [ ] Explain matrix builds
- [ ] Add starter CI workflow
```

Create branch:

```bash
cd ~/devops-masterclass

git switch main
git pull origin main

git switch -c docs/github-actions-foundation
```

Create notes:

```bash
nano 02-git-github/github-actions-foundation.md
```

Paste:

````markdown
# GitHub Actions Foundation

## What is GitHub Actions?

GitHub Actions is GitHub's automation system for running workflows on events like pull requests, pushes, tags, schedules, or manual triggers.

## CI

CI means Continuous Integration. It verifies whether a change can safely merge into main.

## Workflow Structure

```yaml
name: CI

on:
  pull_request:
    branches:
      - main

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "Hello CI"
````

## Core Concepts

* Workflow: automation file in `.github/workflows`
* Trigger: event that starts workflow
* Job: group of steps running on a runner
* Step: command or action
* Runner: machine that executes the job
* Secret: sensitive value stored securely
* Artifact: file saved from workflow run
* Matrix: run same job across multiple versions

## Security Rules

* Use minimum permissions
* Do not print secrets
* Do not deploy from untrusted pull requests
* Do not allow security scans to fail silently
* Pin actions to stable versions

## Status Checks

Branch protection can require CI checks to pass before merging into main.

## Common CI Flow

```text
Pull Request → CI validation → review → merge
```

````

Create workflow:

```bash
mkdir -p .github/workflows
nano .github/workflows/ci.yml
````

Paste the complete beginner-friendly CI workflow from section 17.

Commit:

```bash
git status
git diff
git add 02-git-github/github-actions-foundation.md .github/workflows/ci.yml
git diff --staged
git commit -m "ci: add GitHub Actions foundation workflow"
git push -u origin docs/github-actions-foundation
```

Open PR.

---

# 19. Mini Lab — Add CI Status Check to Branch Protection

After the workflow runs once:

```text
GitHub → Repository → Settings → Branches → main protection rule
```

Enable:

```text
Require status checks to pass before merging
```

Select:

```text
Validate repository
```

Now `main` is protected by CI.

This is your first real CI quality gate.

---

# 20. Interview Answer

Question:

```text
What is a GitHub Actions workflow?
```

Strong answer:

```text
A GitHub Actions workflow is an automation file stored under .github/workflows. It runs when configured events happen, such as a pull request, push to main, tag creation, schedule, or manual trigger. A workflow contains jobs, jobs run on runners, and jobs contain steps. Steps can run shell commands or use reusable actions. In CI, I use workflows to validate code, run tests, check scripts, scan for secrets, and protect the main branch with status checks.
```

Question:

```text
How do you handle secrets in GitHub Actions?
```

Strong answer:

```text
I store secrets in GitHub repository or environment secrets, not in code. In workflows, I inject them only into the steps that need them using the secrets context or environment variables. I never print secrets in logs, and I use minimum token permissions. For cloud access, I prefer short-lived credentials through OIDC instead of long-lived static keys when possible.
```

---

# Today’s Core Rules

```text
CI protects main.
Workflows live in .github/workflows.
Triggers decide when automation runs.
Jobs run on runners.
Steps run commands or actions.
Secrets should be used, never printed.
Artifacts preserve pipeline evidence.
Status checks should block unsafe merges.
Use minimum permissions.
Tag workflows can drive releases.
```

Next lesson:

# Lesson 2.6 — GitHub Security: Dependabot, Secret Scanning, CodeQL, Gitleaks, Branch Protection, OIDC Basics

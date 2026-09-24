# Lesson 2.7 — Module 2 Mini Project: Professional GitHub Workflow + Security-Gated Repository

Now we complete **Module 2: Git, GitHub & Engineering Workflow** with a mini project.

The goal is to convert your repository into a **professional, security-gated GitHub repository**.

By the end, your repo should prove that you understand:

```text
Git workflow
Branching strategy
Pull requests
CI status checks
Release management
GitHub security
Secret scanning
Dependabot
Changelog
Version tags
Professional documentation
```

Your current curriculum already includes GitHub workflow, CI/CD, branch protection, security gates, and interview preparation, so this mini project closes that module properly. 

---

# Mini Project Goal

Build this:

```text
Professional GitHub Repository
  ↓
Protected main branch
  ↓
Issue + PR workflow
  ↓
CI validation
  ↓
Secret scanning
  ↓
Dependabot
  ↓
Release notes + changelog
  ↓
Module 2 documentation
```

This becomes your first real DevOps governance layer.

---

# Final Module 2 Folder Structure

Inside:

```bash
~/devops-masterclass
```

You should have:

```text
02-git-github/
├── github-workflow.md
├── branching-strategies.md
├── pr-review-checklist.md
├── release-management.md
├── github-actions-foundation.md
├── github-security.md
└── module-02-mini-project.md

.github/
├── workflows/
│   ├── ci.yml
│   └── gitleaks.yml
├── ISSUE_TEMPLATE/
│   ├── feature.md
│   ├── bug.md
│   └── security.md
├── CODEOWNERS
├── dependabot.yml
└── pull_request_template.md

CHANGELOG.md
README.md
.env.example
```

---

# Step 1 — Create the Mini Project Branch

Start clean:

```bash
cd ~/devops-masterclass

git switch main
git pull origin main

git switch -c docs/module-02-mini-project
```

---

# Step 2 — Create Module 2 Mini Project File

Create:

```bash
nano 02-git-github/module-02-mini-project.md
```

Paste:

````markdown
# Module 2 Mini Project — Professional GitHub Workflow + Security-Gated Repository

## Goal

The goal of this mini project is to configure this repository like a professional DevOps project.

This includes:

- GitHub workflow documentation
- Branching strategy
- Pull request review checklist
- Release management process
- GitHub Actions CI workflow
- GitHub security notes
- Secret scanning workflow
- Dependabot configuration
- Changelog
- Protected main branch

## Repository Workflow

```text
Issue → Branch → Commit → Pull Request → CI Checks → Review → Merge → Release Tag
````

## Branching Strategy

This repository uses GitHub Flow:

```text
main = stable
feature/docs/security branches = work in progress
pull request = required before merge
CI checks = required before merge
tags = release markers
```

Example branches:

```text
docs/module-02-mini-project
feat/linux-healthcheck-script
ci/add-validation-workflow
security/add-gitleaks-scan
infra/add-terraform-vpc
```

## Pull Request Rules

Every PR should explain:

* What changed
* Why it changed
* How it was tested
* What risk exists
* How to rollback if needed

## Required Checks

Before merge:

* CI validation must pass
* Gitleaks secret scan must pass
* PR description must be complete
* No secrets should be committed
* Documentation must be updated if needed

## Security Controls

Implemented security controls:

* Branch protection for main
* Pull request required before merge
* CI status checks
* Gitleaks secret scanning
* Dependabot configuration
* CODEOWNERS
* `.env` blocked from commit
* `.env.example` allowed
* Minimum workflow permissions

## Release Process

Release flow:

```text
Merge PRs to main
  ↓
Update CHANGELOG.md
  ↓
Create Git tag
  ↓
Create GitHub Release
```

Example:

```bash
git tag -a v0.2.0 -m "Complete Module 2 Git and GitHub engineering workflow"
git push origin v0.2.0
```

## Rollback

For documentation releases, rollback means reverting to a previous Git tag.

For application releases later, rollback will mean deploying the previous immutable Docker image tag.

## Completion Criteria

* [ ] Module 2 notes added
* [ ] CI workflow added
* [ ] Gitleaks workflow added
* [ ] Dependabot added
* [ ] CHANGELOG.md updated
* [ ] CODEOWNERS added
* [ ] PR template added
* [ ] Issue templates added
* [ ] Branch protection enabled
* [ ] Release tag created

## Interview Summary

This repository follows a professional GitHub workflow where all changes go through issues, branches, pull requests, CI checks, review, and release tags. The main branch is protected, secrets are scanned using Gitleaks, dependencies are monitored using Dependabot, and releases are tracked using semantic version tags and a changelog.

````

---

# Step 3 — Confirm CI Workflow

Check that this file exists:

```bash
ls -la .github/workflows/ci.yml
````

If it does not exist, create it:

```bash
mkdir -p .github/workflows
nano .github/workflows/ci.yml
```

Use this final version:

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

# Step 4 — Confirm Gitleaks Workflow

Check:

```bash
ls -la .github/workflows/gitleaks.yml
```

If missing:

```bash
nano .github/workflows/gitleaks.yml
```

Paste:

```yaml
name: Gitleaks Secret Scan

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

jobs:
  gitleaks:
    name: Scan for secrets
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
```

---

# Step 5 — Confirm Dependabot

Check:

```bash
ls -la .github/dependabot.yml
```

If missing:

```bash
nano .github/dependabot.yml
```

Paste:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

Later, when we add application code, we will add:

```yaml
  - package-ecosystem: "npm"
    directory: "/04-app-runtime/todo-app"
    schedule:
      interval: "weekly"
```

---

# Step 6 — Confirm Pull Request Template

Check:

```bash
ls -la .github/pull_request_template.md
```

If missing:

```bash
nano .github/pull_request_template.md
```

Paste:

````markdown
## Summary

What changed?

## Why

Why is this change needed?

## Type of Change

- [ ] Feature
- [ ] Bug fix
- [ ] Documentation
- [ ] Infrastructure
- [ ] Security
- [ ] Refactor
- [ ] Lab

## Production Impact

- [ ] No production impact
- [ ] Changes deployment
- [ ] Changes infrastructure
- [ ] Changes secrets/config
- [ ] Changes monitoring/alerts
- [ ] Changes security

## Risk

What can break?

## Rollback

How can this be undone?

## Checklist

- [ ] I tested the change locally
- [ ] I updated documentation if needed
- [ ] I did not commit secrets
- [ ] I reviewed logs/output for errors
- [ ] I added screenshots/commands where useful

## Verification

Commands run:

```bash
paste commands here
````

Output/result:

```text
paste result here
```

## Related Issue

Closes #

````

---

# Step 7 — Confirm CODEOWNERS

Check:

```bash
ls -la .github/CODEOWNERS
````

If missing:

```bash
nano .github/CODEOWNERS
```

Paste and replace `YOUR_USERNAME`:

```text
# Default owner for all files
* @YOUR_USERNAME

# CI/CD ownership
.github/workflows/ @YOUR_USERNAME

# Infrastructure ownership
10-terraform-ansible/ @YOUR_USERNAME
11-aws/ @YOUR_USERNAME

# Kubernetes ownership
09-kubernetes/ @YOUR_USERNAME
12-gitops-argocd/ @YOUR_USERNAME

# Security ownership
08-devsecops/ @YOUR_USERNAME
.github/dependabot.yml @YOUR_USERNAME
```

---

# Step 8 — Confirm Issue Templates

Check:

```bash
ls -la .github/ISSUE_TEMPLATE
```

You should have:

```text
feature.md
bug.md
security.md
```

If missing, add them later. For now, the important part is that you understand why they exist:

```text
Issues standardize how work is requested and tracked.
```

---

# Step 9 — Update CHANGELOG

Open:

```bash
nano CHANGELOG.md
```

Add this entry at the top:

```markdown
## [v0.2.0] - 2026-06-28

### Added
- Added GitHub engineering workflow notes.
- Added branching strategy notes.
- Added pull request review checklist.
- Added release management notes.
- Added GitHub Actions foundation notes.
- Added GitHub security notes.
- Added Module 2 mini project documentation.
- Added CI validation workflow.
- Added Gitleaks secret scanning workflow.
- Added Dependabot configuration.

### Security
- Added minimum permissions to GitHub Actions workflows.
- Added guidance for secret scanning and leaked secret response.
- Added `.env` blocking validation in CI.
```

---

# Step 10 — Commit the Mini Project

Check everything:

```bash
git status
git diff
```

Stage:

```bash
git add .
```

Review staged changes:

```bash
git diff --staged
```

Commit:

```bash
git commit -m "docs: complete module 2 GitHub workflow mini project"
```

Push:

```bash
git push -u origin docs/module-02-mini-project
```

---

# Step 11 — Open Pull Request

PR title:

```text
docs: complete module 2 GitHub workflow mini project
```

PR description:

````markdown
## Summary

Completed Module 2 mini project for professional GitHub workflow and security-gated repository setup.

## Included

- Module 2 mini project documentation
- GitHub workflow notes
- Branching strategy notes
- PR review checklist
- Release management notes
- GitHub Actions foundation notes
- GitHub security notes
- CI workflow
- Gitleaks workflow
- Dependabot configuration
- Changelog update

## Security Controls

- CI validates repository structure
- CI blocks committed `.env` files
- Gitleaks scans for secrets
- Dependabot monitors GitHub Actions dependencies
- Workflows use minimum permissions

## Verification

Commands run:

```bash
git status
git diff --staged
````

Expected result:

```text
No secrets committed.
CI and Gitleaks should pass.
```

## Rollback

Revert this PR or return to previous tag v0.1.0.

## Related Issue

Closes #

````

---

# Step 12 — Merge and Tag Module 2

After CI and Gitleaks pass, merge PR.

Then locally:

```bash
git switch main
git pull origin main
````

Create tag:

```bash
git tag -a v0.2.0 -m "Complete Module 2 Git and GitHub engineering workflow"
git push origin v0.2.0
```

Create GitHub Release:

```text
GitHub → Releases → Draft a new release → Choose tag v0.2.0
```

Release title:

```text
v0.2.0 — Git and GitHub Engineering Workflow
```

Release notes:

```markdown
## Summary

Completed Module 2 of the DevOps + DevSecOps + SRE Masterclass.

## Included

- Professional GitHub workflow
- Branching strategy
- Pull request review checklist
- Release management
- GitHub Actions CI foundation
- GitHub security controls
- Secret scanning with Gitleaks
- Dependabot configuration

## Security

- Main branch protected
- CI required before merge
- Gitleaks secret scan configured
- Minimum workflow permissions used

## Previous Stable Version

v0.1.0
```

---

# Module 2 Completion Criteria

Module 2 is complete when:

```text
GitHub workflow notes exist
Branching strategy notes exist
PR review checklist exists
Release management notes exist
GitHub Actions notes exist
GitHub security notes exist
CI workflow is active
Gitleaks workflow is active
Dependabot config exists
CHANGELOG.md updated
main branch protected
PR merged
v0.2.0 tag created
GitHub Release created
```

---

# What You Have Learned in Module 2

You now understand:

```text
Professional GitHub workflow
Issue → Branch → PR → Merge flow
Branching strategies
GitHub Flow vs GitFlow vs trunk-based development
Pull request review for DevOps changes
Release management
Semantic versioning
Git tags
Changelog
GitHub Actions CI basics
Status checks
GitHub secrets
Artifacts
Matrix builds
Dependabot
Secret scanning
Gitleaks
CodeQL basics
GitHub Actions permissions
OIDC basics
```

This is a very strong foundation before Linux and Bash.

---

# Final Module 2 Interview Answer

Question:

```text
How would you set up a professional GitHub workflow for a DevOps project?
```

Strong answer:

```text
I would protect the main branch and require all changes to go through issues, short-lived branches, pull requests, CI checks, and review. I would use GitHub Flow for a small or medium project, with main always stable and release tags marking completed versions. I would add PR templates, issue templates, CODEOWNERS, and conventional commit messages. For automation, I would configure GitHub Actions to validate the repository and block unsafe files like real .env files. For security, I would enable Dependabot, secret scanning, and a Gitleaks workflow, and I would use minimum workflow permissions. Releases would be tracked using semantic version tags, CHANGELOG.md, and GitHub Releases.
```

---

# Module 2 Status

```text
Module 2: Git, GitHub & Engineering Workflow
Status: Complete after PR merge and v0.2.0 release
```

Next module:

# Module 3 — Linux, Bash & Networking

This is where we become dangerous in the terminal — in the good way.

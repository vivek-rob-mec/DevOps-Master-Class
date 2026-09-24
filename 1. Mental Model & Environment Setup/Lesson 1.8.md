# Lesson 1.8 — GitHub Repository Setup: README, Branch Protection, Issues, PR Template, Project Structure

Now we move from “learning notes” to **engineering workflow**.

A real DevOps engineer does not just write commands. They create systems where work is:

```text
Tracked
Reviewed
Tested
Secured
Documented
Repeatable
Auditable
```

Your curriculum already includes GitHub account setup, SSH keys, CI/CD, branch protection, security scans, and production-style workflows, so this lesson connects the foundation to real team practice. 

---

# 1. Why GitHub Repository Setup Matters

A weak beginner repo looks like this:

```text
project/
├── app.js
├── test.js
└── random-notes.txt
```

No README.
No structure.
No `.gitignore`.
No branch protection.
No issues.
No PR process.
No CI/CD.
No documentation.

A professional repo looks like this:

```text
project/
├── README.md
├── docs/
├── src/
├── tests/
├── scripts/
├── .github/
│   ├── workflows/
│   ├── ISSUE_TEMPLATE/
│   └── pull_request_template.md
├── .gitignore
├── .env.example
├── Dockerfile
├── docker-compose.yml
└── Makefile
```

This tells recruiters and companies:

```text
This person understands engineering workflow, not just coding.
```

---

# 2. Create GitHub Repository

Go to GitHub and create a new repo:

```text
devops-masterclass
```

Recommended settings:

```text
Visibility: Public, if portfolio
README: Do not initialize if you already committed locally
.gitignore: Do not initialize if local repo already has it
License: Optional
```

Then connect your local repo:

```bash
cd ~/devops-masterclass

git remote add origin git@github.com:YOUR_USERNAME/devops-masterclass.git

git branch -M main

git push -u origin main
```

Verify:

```bash
git remote -v
```

Expected:

```text
origin  git@github.com:YOUR_USERNAME/devops-masterclass.git (fetch)
origin  git@github.com:YOUR_USERNAME/devops-masterclass.git (push)
```

---

# 3. README.md — Your Project’s Front Door

A README is not decoration.

It answers:

```text
What is this project?
Why does it exist?
How do I run it?
What tools are used?
What is the architecture?
What is the learning roadmap?
What is completed?
What is pending?
```

Create it:

```bash
cd ~/devops-masterclass
touch README.md
```

Add:

````markdown
# DevOps + DevSecOps + SRE Masterclass

This repository contains my complete hands-on DevOps learning journey.

The goal is to build real-world skills in Linux, Git, Docker, CI/CD, Jenkins, Kubernetes, Terraform, AWS, DevSecOps, Observability, SRE, Platform Engineering, and FinOps.

## Learning Method

Concept → Real-world example → Diagram → Commands → Lab → Break it → Debug it → Secure it → Interview answer → Mini project

## Masterclass Roadmap

1. Mental Model & Environment Setup
2. Git, GitHub & Engineering Workflow
3. Linux, Bash & Networking
4. Python for DevOps Automation
5. Application Runtime & Production App Basics
6. Docker & Container Fundamentals
7. Artifact Management & Registries
8. CI/CD Pipelines: GitHub Actions, Jenkins, GitLab CI
9. DevSecOps Security Gates
10. Kubernetes Production Operations
11. Advanced Kubernetes Troubleshooting
12. Terraform, Ansible & Infrastructure as Code
13. AWS Production Architecture
14. GitOps with ArgoCD
15. Observability with Prometheus, Grafana, Loki, Tempo, OpenTelemetry
16. SRE, Incident Response & On-call
17. System Design for DevOps/SRE
18. Platform Engineering
19. FinOps & Cost Optimization
20. Final Mega Capstone Project

## Repository Structure

```text
devops-masterclass/
├── 00-notes/
├── 01-linux-bash-networking/
├── 02-git-github/
├── 03-python-automation/
├── 04-app-runtime/
├── 05-docker/
├── 06-artifacts-registries/
├── 07-cicd/
├── 08-devsecops/
├── 09-kubernetes/
├── 10-terraform-ansible/
├── 11-aws/
├── 12-gitops-argocd/
├── 13-observability/
├── 14-sre-incidents/
├── 15-system-design/
├── 16-platform-engineering/
├── 17-finops/
└── 18-final-capstone/
````

## Current Status

* [x] Environment setup
* [x] Git repository initialized
* [x] Masterclass structure created
* [ ] GitHub workflow setup
* [ ] Linux labs
* [ ] Docker labs
* [ ] CI/CD labs
* [ ] Kubernetes labs
* [ ] Final capstone

## Core Principles

* Never commit secrets
* Build once, promote the same artifact
* Automate repeatable work
* Secure by default
* Monitor everything important
* Rollback first when users are impacted
* Document decisions and incidents

````

Commit:

```bash
git add README.md
git commit -m "docs: add masterclass README"
git push
````

---

# 4. Add `.env.example`

You should never commit real `.env` files.

But you should commit `.env.example`.

Create:

```bash
touch .env.example
```

Add:

```env
# Example environment variables
APP_ENV=local
APP_PORT=3000
LOG_LEVEL=info

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/appdb

# Redis
REDIS_URL=redis://localhost:6379

# External services
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/example
```

Commit:

```bash
git add .env.example
git commit -m "docs: add environment variable example"
git push
```

Rule:

```text
.env.example shows required config.
.env stores real secrets and must stay uncommitted.
```

---

# 5. GitHub Issues

Issues are used to track work.

Create labels:

```text
type:feature
type:bug
type:docs
type:security
type:infra
type:lab
priority:high
priority:medium
priority:low
status:blocked
status:in-progress
```

Example issue:

```markdown
## Task

Set up environment verification script.

## Why

Before starting hands-on labs, I need a repeatable script to confirm that Git, Docker, Node.js, Python, DNS, and internet access are working.

## Acceptance Criteria

- [ ] Script checks required commands
- [ ] Script checks Docker daemon
- [ ] Script checks DNS
- [ ] Script checks GitHub connectivity
- [ ] Script is executable
- [ ] Script is documented in README
```

This builds professional project management habits.

---

# 6. Issue Templates

Create folder:

```bash
mkdir -p .github/ISSUE_TEMPLATE
```

Create feature template:

```bash
nano .github/ISSUE_TEMPLATE/feature.md
```

Paste:

```markdown
---
name: Feature
about: Add a new feature, lab, or module
title: "feat: "
labels: "type:feature"
---

## Goal

What are we trying to build or learn?

## Why it matters

Why is this useful in real DevOps/SRE work?

## Tasks

- [ ] 
- [ ] 
- [ ] 

## Acceptance Criteria

- [ ] 
- [ ] 

## Notes

Any commands, links, diagrams, or references.
```

Create bug template:

```bash
nano .github/ISSUE_TEMPLATE/bug.md
```

Paste:

````markdown
---
name: Bug
about: Report a broken command, lab, script, or configuration
title: "fix: "
labels: "type:bug"
---

## Problem

What is broken?

## Expected Behavior

What should happen?

## Actual Behavior

What happened instead?

## Steps to Reproduce

1. 
2. 
3. 

## Logs / Error Output

```text
paste error here
````

## Possible Cause

What do you think caused it?

````

Create security template:

```bash
nano .github/ISSUE_TEMPLATE/security.md
````

Paste:

```markdown
---
name: Security Task
about: Track security improvements or findings
title: "security: "
labels: "type:security"
---

## Security Concern

What is the risk?

## Affected Area

- [ ] Code
- [ ] Docker
- [ ] CI/CD
- [ ] Kubernetes
- [ ] Terraform
- [ ] AWS
- [ ] Secrets
- [ ] Dependencies

## Remediation Plan

- [ ] 
- [ ] 

## Verification

How will we confirm the risk is fixed?
```

Commit:

```bash
git add .github/ISSUE_TEMPLATE
git commit -m "chore: add GitHub issue templates"
git push
```

---

# 7. Pull Request Template

Create:

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

Commit:

```bash
git add .github/pull_request_template.md
git commit -m "chore: add pull request template"
git push
````

This forces discipline.

Every PR must explain:

```text
What changed?
Why?
How was it tested?
What issue does it close?
```

---

# 8. Branching Workflow

Use this simple professional workflow:

```text
main = stable branch
feature branches = all work happens here
pull request = review + CI before merge
```

Never work directly on `main`.

Bad:

```bash
git checkout main
# edit files
git commit -m "changes"
git push
```

Good:

```bash
git checkout -b feat/linux-healthcheck-script
# edit files
git add .
git commit -m "feat: add linux healthcheck script"
git push -u origin feat/linux-healthcheck-script
```

Then open a Pull Request.

---

# 9. Branch Protection

In GitHub:

```text
Repository → Settings → Branches → Add branch protection rule
```

Branch name pattern:

```text
main
```

Enable:

```text
Require a pull request before merging
Require approvals
Require status checks to pass before merging
Require conversation resolution before merging
Require linear history
Do not allow force pushes
Do not allow deletions
```

For now, if you are working alone, approval can be optional. But still use PRs.

Professional rule:

```text
main should always be deployable.
```

---

# 10. Commit Message Standard

Use conventional commits:

```text
feat: add new feature
fix: fix bug
docs: update documentation
chore: maintenance work
refactor: code improvement without behavior change
test: add or update tests
security: fix security issue
ci: update CI/CD pipeline
infra: update infrastructure
```

Examples:

```bash
git commit -m "docs: add environment setup notes"

git commit -m "feat: add environment verification script"

git commit -m "ci: add GitHub Actions workflow"

git commit -m "security: add gitleaks config"

git commit -m "infra: add Terraform backend module"
```

This becomes useful later for release notes and changelogs.

---

# 11. CODEOWNERS

CODEOWNERS defines who owns which parts of the repo.

Create:

```bash
nano .github/CODEOWNERS
```

For solo learning:

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
```

Commit:

```bash
git add .github/CODEOWNERS
git commit -m "chore: add CODEOWNERS"
git push
```

In companies, CODEOWNERS ensures the right team reviews the right files.

---

# 12. GitHub Actions Starter Workflow

Create:

```bash
mkdir -p .github/workflows
nano .github/workflows/validate.yml
```

Paste:

```yaml
name: Validate Repository

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main

jobs:
  validate:
    name: Validate files and scripts
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Check repository structure
        run: |
          test -d 00-notes
          test -d 01-linux-bash-networking
          test -f README.md
          test -f .gitignore

      - name: Check shell script syntax
        run: |
          find . -name "*.sh" -print0 | xargs -0 -r bash -n

      - name: Check for accidental env files
        run: |
          if find . -name ".env" -o -name ".env.*" | grep -v ".env.example"; then
            echo "Real env file found. Do not commit secrets."
            exit 1
          fi
```

Commit:

```bash
git add .github/workflows/validate.yml
git commit -m "ci: add repository validation workflow"
git push
```

This is your first CI workflow.

It checks:

```text
Repo structure exists
Shell scripts have valid syntax
Real env files are not committed
```

---

# 13. Security Basics for GitHub Repo

Enable these in GitHub:

```text
Settings → Code security and analysis
```

Turn on:

```text
Dependency graph
Dependabot alerts
Dependabot security updates
Secret scanning, if available
Code scanning, later when configured
```

Also add this rule:

```text
Never paste AWS keys, tokens, database passwords, or private keys into GitHub.
```

If a secret is committed accidentally:

```text
1. Rotate the secret immediately
2. Remove from git history if needed
3. Add detection to prevent repeat
```

Deleting the file is not enough because Git keeps history.

---

# 14. GitHub Project Board

Create a GitHub Project:

```text
DevOps Masterclass Board
```

Columns:

```text
Backlog
Ready
In Progress
Review
Done
Blocked
```

Create initial issues:

```text
Set up masterclass repository
Create environment verification script
Document production request flow
Create Linux healthcheck script
Create Docker Compose Todo app
Create Jenkins CI pipeline
Create Kubernetes deployment
Create Terraform AWS infrastructure
Create observability stack
Create final capstone architecture
```

This teaches project tracking.

---

# 15. Your First Real Workflow

From now on, use this process:

```text
Create issue
  ↓
Create branch
  ↓
Make change
  ↓
Commit
  ↓
Push branch
  ↓
Open PR
  ↓
CI runs
  ↓
Review checklist
  ↓
Merge to main
```

Example:

```bash
git checkout -b docs/add-github-workflow-notes

# edit notes

git add .
git commit -m "docs: add GitHub workflow notes"
git push -u origin docs/add-github-workflow-notes
```

Then open PR on GitHub.

---

# 16. Mini Lab — Complete Repo Professionalization

Do these tasks:

```text
1. Push devops-masterclass repo to GitHub
2. Add README.md
3. Add .env.example
4. Add issue templates
5. Add PR template
6. Add CODEOWNERS
7. Add validate.yml GitHub Actions workflow
8. Enable branch protection on main
9. Create GitHub Project board
10. Create first 5 issues
```

Then your repo becomes professional.

---

# 17. Interview Answer

Question:

```text
How do you set up a professional GitHub repository for a DevOps project?
```

Strong answer:

```text
I start with a clear README that explains the project purpose, architecture, setup steps, and roadmap. I add a proper .gitignore and .env.example so required configuration is documented without exposing secrets. I use issue templates and a pull request template to standardize work tracking and reviews. I protect the main branch so changes go through pull requests and CI checks before merging. I add CODEOWNERS for ownership and a starter GitHub Actions workflow to validate structure and scripts. I also enable security features like Dependabot and secret scanning where available. The goal is to make the repository auditable, secure, and easy for a team to collaborate on.
```

---

# Today’s Core Rules

```text
README is the front door.
main should always be stable.
Never commit secrets.
Every change should have a branch and PR.
Issues track work.
PRs explain change.
CI validates change.
Branch protection prevents accidents.
.env.example is safe; .env is not.
```

Next lesson:

# Lesson 1.9 — Git Deep Mental Model: Commit, Branch, Merge, Rebase, Reset, Revert, Tag

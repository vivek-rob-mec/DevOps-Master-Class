# Lesson 2.6 — GitHub Security: Dependabot, Secret Scanning, CodeQL, Gitleaks, Branch Protection, OIDC Basics

Now we move from normal GitHub workflow to **secure GitHub workflow**.

In real DevOps, GitHub is not only a code repository. It becomes the control center for:

```text
Source code
CI/CD workflows
Secrets
Docker builds
Terraform plans
Kubernetes manifests
Production deployments
Release tags
Security scans
```

So if GitHub is insecure, your entire DevOps pipeline is insecure.

Your curriculum already includes secret scanning, dependency scanning, SAST, branch protection, GitHub Actions security, and CI/CD security gates, so this lesson is very important. 

---

# 1. Why GitHub Security Matters

A beginner thinks:

```text
GitHub just stores code.
```

A DevOps engineer thinks:

```text
GitHub controls the software supply chain.
```

If an attacker gets access to your GitHub repo, they may be able to:

```text
Steal secrets
Modify CI/CD workflows
Inject malicious code
Deploy to production
Change Terraform infrastructure
Push malicious Docker images
Disable security checks
Create fake releases
```

That is why GitHub security is part of DevSecOps.

---

# 2. Common GitHub Security Risks

Common mistakes:

```text
Committing .env files
Committing AWS keys
Using weak branch protection
Allowing direct push to main
Giving too many people admin access
Using long-lived cloud access keys
Printing secrets in CI logs
Using untrusted GitHub Actions
Giving workflows write-all permissions
Skipping dependency scanning
Skipping code scanning
```

One leaked AWS key can create a real cloud bill.

One malicious workflow can steal all repository secrets.

One unreviewed change to Terraform can expose infrastructure.

---

# 3. Security Layer 1 — Branch Protection

Branch protection prevents unsafe changes from entering `main`.

Enable:

```text
Repository → Settings → Branches → Add branch protection rule
```

For `main`, enable:

```text
Require pull request before merging
Require status checks to pass
Require conversation resolution
Require linear history, optional
Do not allow force pushes
Do not allow deletions
Restrict who can push, for team repos
```

Professional rule:

```text
Nobody pushes directly to main.
```

Even if you are solo, practice this.

Why?

```text
It builds production discipline.
```

---

# 4. Security Layer 2 — CODEOWNERS

`CODEOWNERS` defines who must review sensitive areas.

Example:

```text
# Default owner
* @YOUR_USERNAME

# CI/CD
.github/workflows/ @YOUR_USERNAME

# Infrastructure
10-terraform-ansible/ @YOUR_USERNAME
11-aws/ @YOUR_USERNAME

# Kubernetes and GitOps
09-kubernetes/ @YOUR_USERNAME
12-gitops-argocd/ @YOUR_USERNAME

# Security
08-devsecops/ @YOUR_USERNAME
```

Why this matters:

```text
A frontend developer should not silently change production Terraform.
A random PR should not silently change Jenkins deployment logic.
A Kubernetes RBAC change should receive careful review.
```

In companies, CODEOWNERS maps files to teams.

---

# 5. Security Layer 3 — Dependabot

Dependabot checks dependency vulnerabilities.

It can scan:

```text
npm package.json
Python requirements.txt
Dockerfiles
GitHub Actions
Terraform providers, in some cases
```

Enable:

```text
Repository → Settings → Code security and analysis → Dependabot alerts
```

Also create:

```bash
mkdir -p .github
nano .github/dependabot.yml
```

Example:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"

  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"

  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
```

For your current masterclass repo, GitHub Actions scanning is useful immediately.

Later, when you add Node.js apps, Dockerfiles, and Terraform, Dependabot becomes more useful.

---

# 6. Security Layer 4 — Secret Scanning

Secret scanning detects accidentally committed credentials.

Examples:

```text
AWS access keys
GitHub tokens
Docker Hub tokens
Slack webhooks
Private keys
Database URLs
API keys
```

Turn on:

```text
Repository → Settings → Code security and analysis → Secret scanning
```

Also add local and CI secret scanning with **Gitleaks**.

Why both?

```text
GitHub secret scanning helps on GitHub.
Gitleaks can run locally and in CI.
```

Defense in depth.

---

# 7. Gitleaks

Gitleaks scans Git history and files for secrets.

Install locally later if needed, but in GitHub Actions you can add:

```yaml
name: Secret Scan

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
    name: Gitleaks secret scan
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
```

Important:

```text
fetch-depth: 0 lets Gitleaks inspect full Git history.
```

If Gitleaks finds a real secret:

```text
1. Rotate the secret immediately.
2. Remove it from the repo/history if needed.
3. Add prevention checks.
```

Do not just delete the file.

Git history still contains it.

---

# 8. Security Layer 5 — CodeQL

CodeQL is GitHub’s code scanning engine.

It finds security issues in code.

Examples:

```text
SQL injection
Path traversal
Unsafe deserialization
Hardcoded credentials
Command injection
XSS patterns
```

For JavaScript/TypeScript projects, a basic workflow:

```yaml
name: CodeQL

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main
  schedule:
    - cron: "0 2 * * 1"

permissions:
  security-events: write
  contents: read

jobs:
  analyze:
    name: CodeQL analysis
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: javascript-typescript

      - name: Autobuild
        uses: github/codeql-action/autobuild@v3

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
```

For your current notes-only repo, CodeQL is not very useful yet.

But once we add the Todo app code, it becomes useful.

---

# 9. Security Layer 6 — GitHub Actions Permissions

By default, do not give broad permissions.

Bad:

```yaml
permissions: write-all
```

Better for validation workflows:

```yaml
permissions:
  contents: read
```

For release creation:

```yaml
permissions:
  contents: write
```

For security scanning results:

```yaml
permissions:
  security-events: write
  contents: read
```

For AWS OIDC later:

```yaml
permissions:
  id-token: write
  contents: read
```

Rule:

```text
Every workflow should declare minimum required permissions.
```

This is one of the simplest ways to improve GitHub Actions security.

---

# 10. Security Layer 7 — Avoid Dangerous Pull Request Triggers

There are two similar triggers:

```yaml
pull_request
pull_request_target
```

Use `pull_request` for normal PR checks.

Be very careful with `pull_request_target`.

Why?

```text
pull_request_target runs with permissions from the target repository.
If used incorrectly, untrusted fork code can access powerful context.
```

Beginner rule:

```text
Use pull_request.
Avoid pull_request_target until you deeply understand it.
```

Especially never check out and run untrusted PR code with secrets.

---

# 11. Security Layer 8 — Pin GitHub Actions

Common:

```yaml
uses: actions/checkout@v4
```

This is okay for learning and common practice.

More secure for high-security environments:

```yaml
uses: actions/checkout@<full_commit_sha>
```

Why?

```text
Tags can theoretically move.
Commit SHAs are immutable.
```

For your learning repo, stable major versions like `@v4` are okay.

For production security-sensitive pipelines, pinning to SHA is stronger.

---

# 12. Security Layer 9 — Environment Protection

GitHub Environments can protect deployments.

Example environments:

```text
dev
staging
production
```

For production:

```text
Settings → Environments → production
```

Enable:

```text
Required reviewers
Deployment branches
Environment secrets
Wait timer, optional
```

Then workflow:

```yaml
jobs:
  deploy-production:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - run: echo "Deploying to production"
```

This means:

```text
Production deployment pauses for approval before running.
```

Very important for real CI/CD.

---

# 13. Security Layer 10 — OIDC Basics

OIDC means OpenID Connect.

In DevOps context, it allows GitHub Actions to access cloud providers without storing long-lived access keys.

Bad old method:

```text
Store AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in GitHub Secrets.
```

Better modern method:

```text
GitHub Actions requests short-lived token.
AWS trusts GitHub OIDC provider.
AWS role is assumed temporarily.
No static AWS secret stored in GitHub.
```

Flow:

```text
GitHub Actions workflow
  ↓
Requests OIDC token
  ↓
AWS verifies token
  ↓
AWS grants temporary role credentials
  ↓
Workflow deploys infrastructure/app
```

GitHub Actions permissions:

```yaml
permissions:
  id-token: write
  contents: read
```

Later AWS workflow:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::<account-id>:role/github-actions-deploy-role
    aws-region: ap-south-1
```

Why OIDC is better:

```text
No long-lived AWS keys in GitHub.
Temporary credentials expire.
IAM role can be scoped to repo/branch/environment.
```

We will implement this deeply in AWS + CI/CD module.

For now, understand the mental model.

---

# 14. Security Layer 11 — Signed Commits and Tags

Advanced but useful.

Signed commits prove the commit was made by a trusted identity.

Signed tags prove the release tag was created by a trusted identity.

GitHub can show:

```text
Verified
```

This is useful for release trust.

We do not need to enforce this immediately, but for enterprise projects:

```text
Require signed commits
Require signed tags
Protect release branches
```

---

# 15. Security Layer 12 — Repository Access Control

Use least privilege.

Roles:

```text
Read
Triage
Write
Maintain
Admin
```

Do not give everyone admin.

Rule:

```text
Admin access should be rare.
```

For teams:

```text
Developers: write
Maintainers: maintain
DevOps leads: admin
External contributors: no direct write
```

For production-sensitive repos, restrict:

```text
Who can approve PRs
Who can merge
Who can deploy
Who can edit workflows
Who can manage secrets
```

---

# 16. What Happens if a Secret is Committed?

Suppose this is committed:

```text
AWS_SECRET_ACCESS_KEY=abc123
```

Correct response:

```text
1. Treat it as compromised.
2. Rotate/delete the key in AWS immediately.
3. Check cloud activity logs.
4. Remove secret from repository and history if needed.
5. Add secret scanning to prevent repeat.
6. Document the incident.
```

Wrong response:

```text
Delete the line and commit again.
```

Why wrong?

```text
The secret still exists in Git history.
```

Production mindset:

```text
Once secret is pushed, assume it is leaked.
```

---

# 17. Recommended Security Setup for Your Repo Now

For your current `devops-masterclass` repo, enable:

```text
Branch protection on main
Require PR before merge
Require CI status checks
Dependabot alerts
Secret scanning, if available
CODEOWNERS
Gitleaks workflow
Minimum permissions in workflows
.env blocking workflow
```

Later, add:

```text
CodeQL when app code exists
Trivy when Dockerfiles exist
Checkov/tfsec when Terraform exists
Kubescape/Kube-score when Kubernetes exists
OIDC when AWS deployment starts
Environment protection when deployment starts
```

This phased approach is correct.

---

# 18. Mini Lab — Add GitHub Security Notes

Create issue:

```text
docs: add GitHub security notes
```

Acceptance criteria:

```markdown
- [ ] Explain branch protection
- [ ] Explain Dependabot
- [ ] Explain secret scanning
- [ ] Explain Gitleaks
- [ ] Explain CodeQL
- [ ] Explain workflow permissions
- [ ] Explain OIDC basics
```

Create branch:

```bash
cd ~/devops-masterclass

git switch main
git pull origin main

git switch -c docs/github-security
```

Create file:

```bash
nano 02-git-github/github-security.md
```

Paste:

````markdown
# GitHub Security

## Why GitHub Security Matters

GitHub is part of the software supply chain. It stores code, CI/CD workflows, secrets, infrastructure code, Kubernetes manifests, and release tags.

## Branch Protection

Protect `main` with:

- Pull requests required
- Status checks required
- No force pushes
- No branch deletion
- Conversation resolution required

## Dependabot

Dependabot detects vulnerable dependencies and can open update PRs.

Useful for:

- GitHub Actions
- npm
- Docker
- Python
- Other ecosystems

## Secret Scanning

Secret scanning detects accidentally committed credentials such as API keys, cloud keys, tokens, and private keys.

If a secret is committed, rotate it immediately.

## Gitleaks

Gitleaks scans the repository and Git history for secrets.

Important CI setting:

```yaml
with:
  fetch-depth: 0
````

This allows scanning full history.

## CodeQL

CodeQL performs static analysis to detect security issues in application code.

Useful once application code exists in the repository.

## GitHub Actions Permissions

Use minimum required permissions.

Example for CI:

```yaml
permissions:
  contents: read
```

Avoid:

```yaml
permissions: write-all
```

## OIDC

OIDC allows GitHub Actions to access cloud providers using short-lived credentials instead of storing long-lived access keys.

Flow:

```text
GitHub Actions → OIDC token → AWS IAM role → temporary credentials
```

## Core Rules

* Never commit secrets
* Protect main
* Require CI checks
* Use least privilege permissions
* Avoid long-lived cloud keys
* Rotate leaked secrets immediately

````

Commit:

```bash
git status
git diff
git add 02-git-github/github-security.md
git diff --staged
git commit -m "docs: add GitHub security notes"
git push -u origin docs/github-security
````

Open PR.

---

# 19. Mini Lab — Add Gitleaks Workflow

Create workflow:

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

Commit:

```bash
git add .github/workflows/gitleaks.yml
git commit -m "security: add Gitleaks secret scan workflow"
git push
```

Now every PR can be scanned for secrets.

---

# 20. Mini Lab — Add Dependabot Config

Create:

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

Commit:

```bash
git add .github/dependabot.yml
git commit -m "security: add Dependabot configuration"
git push
```

Later, when you add apps:

```yaml
  - package-ecosystem: "npm"
    directory: "/04-app-runtime/todo-app"
    schedule:
      interval: "weekly"
```

---

# 21. Interview Answer

Question:

```text
How would you secure a GitHub repository used for DevOps?
```

Strong answer:

```text
I would protect the main branch with required pull requests, required CI checks, no force pushes, and no deletions. I would add CODEOWNERS for sensitive areas like CI/CD, Terraform, Kubernetes, and security files. I would enable Dependabot, secret scanning, and add Gitleaks in CI to detect leaked secrets. Workflows should use minimum permissions instead of write-all, and production deployments should use GitHub Environments with required approvals. For cloud access, I prefer OIDC with short-lived credentials instead of storing long-lived AWS keys in GitHub Secrets.
```

Question:

```text
What do you do if a secret is committed to GitHub?
```

Strong answer:

```text
I treat the secret as compromised. First, I rotate or delete the secret at the provider, such as AWS or Docker Hub. Then I check logs for misuse, remove the secret from the repository and history if needed, add secret scanning such as Gitleaks, and document the incident. Simply deleting the line in a new commit is not enough because the secret remains in Git history.
```

---

# Today’s Core Rules

```text
GitHub is part of the software supply chain.
Protect main.
Require PRs and status checks.
Never commit secrets.
Use Gitleaks and secret scanning.
Use Dependabot for dependency updates.
Use minimum workflow permissions.
Avoid pull_request_target unless you understand it deeply.
Use OIDC instead of long-lived cloud keys where possible.
Treat pushed secrets as compromised.
```

Next lesson:

# Lesson 2.7 — Module 2 Mini Project: Professional GitHub Workflow + Security-Gated Repository

# Lesson 2.2 — Branching Strategies: GitHub Flow, GitFlow, Trunk-Based Development, Release Branches

Now we learn how teams decide **which branches exist**, **how code moves**, and **how releases are controlled**.

This matters because your CI/CD pipeline, Jenkins pipeline, GitHub Actions workflow, Docker image tagging, and production deployment strategy all depend on your branching model. Your curriculum already includes Git branching strategy and CI/CD flow, so this lesson connects Git workflow to real DevOps delivery. 

---

# 1. Why Branching Strategy Matters

Without a branching strategy, teams end up with chaos:

```text
main
develop
dev
dev-new
feature-final
staging-fix
prod-hotfix-final
vivek-test
release-old
```

Nobody knows:

```text
Which branch is production?
Which branch is safe?
Where should I merge?
Which branch triggers deployment?
Which branch should Jenkins build?
```

A branching strategy answers:

```text
Where does daily development happen?
Where do releases happen?
Where do hotfixes happen?
Which branch deploys to which environment?
How do we protect production?
```

---

# 2. Strategy 1 — GitHub Flow

GitHub Flow is simple and very common.

## Flow

```text
main
 ↓
feature branch
 ↓
pull request
 ↓
CI checks
 ↓
merge to main
 ↓
deploy
```

Diagram:

```text
main ────────●────────●────────●
              \        \
feature         ●──●     ●──●
                 PR       PR
```

## Branches

Usually only:

```text
main
feature/*
fix/*
docs/*
```

Example:

```bash
git switch main
git pull origin main
git switch -c feat/add-healthcheck
```

After PR approval:

```text
feature branch → main
```

## Best For

```text
Small to medium teams
Web apps
SaaS products
Frequent deployments
Simple CI/CD
GitHub-based projects
```

## Environment Mapping

Simple mapping:

```text
Pull Request → CI checks
main         → deploy to staging or production
tag          → production release
```

For your masterclass, this is the best starting strategy.

---

# 3. GitHub Flow Example for Your Project

For your repo:

```text
devops-masterclass
```

Workflow:

```text
Create issue
  ↓
Create branch: docs/module-02-branching-strategies
  ↓
Add notes
  ↓
Open PR
  ↓
GitHub Actions validates
  ↓
Merge to main
  ↓
Tag release if needed
```

Example command:

```bash
git switch main
git pull origin main
git switch -c docs/module-02-branching-strategies
```

Commit:

```bash
git add .
git commit -m "docs: add branching strategies notes"
git push -u origin docs/module-02-branching-strategies
```

---

# 4. Strategy 2 — GitFlow

GitFlow is older, heavier, and more structured.

## Main Branches

```text
main       → production-ready code
develop    → integration branch for next release
feature/*  → new features
release/*  → release stabilization
hotfix/*   → urgent production fixes
```

Diagram:

```text
main      ●──────────────●──────────────●
           \              \              \
release     \              ●──fix──●      \
             \            /        \       \
develop       ●──●──●──●────────────●──────●
                \    \
feature          ●──●  ●──●
```

## Flow

```text
feature branch → develop
develop → release branch
release branch → main
main → production
hotfix branch → main and develop
```

## Best For

```text
Large teams
Scheduled releases
Enterprise products
Desktop/mobile software
Products with versioned releases
```

## Weakness

GitFlow can become heavy.

Problems:

```text
Too many long-lived branches
Merge conflicts increase
develop and main drift apart
Slower delivery
Harder CI/CD
```

For modern cloud apps, many teams prefer simpler workflows.

---

# 5. GitFlow Example

Feature work:

```bash
git switch develop
git pull origin develop
git switch -c feature/add-login
```

Merge feature:

```text
feature/add-login → develop
```

Create release:

```bash
git switch develop
git switch -c release/v1.2.0
```

Fix bugs on release branch.

Then merge:

```text
release/v1.2.0 → main
release/v1.2.0 → develop
```

Tag:

```bash
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
```

Hotfix:

```bash
git switch main
git switch -c hotfix/fix-payment-timeout
```

Then merge hotfix into:

```text
main
develop
```

---

# 6. Strategy 3 — Trunk-Based Development

Trunk-based development means everyone integrates into `main` frequently.

Here, `main` is the trunk.

## Flow

```text
small branch
  ↓
short-lived PR
  ↓
merge to main quickly
  ↓
deploy frequently
```

Diagram:

```text
main ●─●─●─●─●─●─●─●─●
       \   \ \   \
        ●   ● ●   ●
       PR  PR PR  PR
```

Branches live for hours or 1–2 days, not weeks.

## Best For

```text
High-performing teams
Frequent deployments
Strong automated tests
Feature flags
Continuous delivery
SaaS products
```

## Requires

```text
Strong CI pipeline
Good tests
Small changes
Feature flags
Fast review process
Rollback strategy
Monitoring
```

Without these, trunk-based development can be risky.

---

# 7. Why Trunk-Based Development Is Powerful

Long-lived branches create problems:

```text
Merge conflicts
Late integration bugs
Huge PRs
Slow review
Different branches behave differently
```

Trunk-based development reduces this by integrating small changes frequently.

Rule:

```text
Small changes are safer than huge changes.
```

Bad:

```text
Feature branch lives 3 weeks
PR changes 80 files
CI fails
Merge conflicts everywhere
```

Good:

```text
Small branch lives 1 day
PR changes 3 files
CI passes
Easy review
```

---

# 8. Feature Flags and Trunk-Based Development

Feature flags make trunk-based development safe.

Example:

```text
New payment code is merged to main.
Feature flag is OFF.
Users cannot access it yet.
```

Later:

```text
Enable for internal users.
Enable for 5%.
Enable for 25%.
Enable for 100%.
```

So the code is deployed, but not fully released.

This connects to our previous rule:

```text
Deployment is not always release.
```

---

# 9. Strategy 4 — Release Branches

Release branches are used when you need to stabilize a version before production.

Example:

```text
main
release/v1.3.0
```

Flow:

```text
main has ongoing development
release/v1.3.0 only receives bug fixes
when stable, release/v1.3.0 is tagged and deployed
```

Use release branches when:

```text
You have scheduled releases
QA needs time to test
Customers use specific versions
Multiple versions are supported
```

Avoid release branches if:

```text
You deploy many times per day
Your CI/CD is mature
You can use feature flags
Your app is a SaaS with one live version
```

---

# 10. Strategy 5 — Environment Branches

Some beginners use:

```text
dev
staging
production
```

Where each branch maps to environment.

Example:

```text
dev branch      → dev environment
staging branch  → staging environment
main branch     → production
```

This can work, but be careful.

## Problem

Branches can drift.

```text
dev has code A
staging has code B
production has code C
```

Then nobody knows what is truly tested.

Better model:

```text
Same artifact promoted across environments.
```

Instead of environment branches, prefer:

```text
main builds Docker image once
image tag promoted dev → staging → production
```

Environment-specific config should live separately:

```text
helm values-dev.yaml
helm values-staging.yaml
helm values-prod.yaml
```

or:

```text
environments/dev/
environments/staging/
environments/prod/
```

---

# 11. Recommended Strategy for You

For this masterclass, use this:

```text
GitHub Flow + release tags
```

That means:

```text
main = stable
feature branches = all work
PR = required before merge
GitHub Actions = validates PR
tags = mark releases
```

Recommended branch examples:

```text
docs/module-02-branching-strategies
feat/linux-healthcheck-script
ci/add-jenkins-pipeline
security/add-gitleaks-scan
infra/add-terraform-vpc
```

Recommended release tags:

```text
v0.1.0 = Module 1 complete
v0.2.0 = Module 2 complete
v0.3.0 = Linux module complete
v1.0.0 = Final capstone complete
```

This is simple, clean, and portfolio-friendly.

---

# 12. Branching Strategy Comparison

| Strategy             |  Complexity | Best For                      | Weakness                        |
| -------------------- | ----------: | ----------------------------- | ------------------------------- |
| GitHub Flow          |         Low | Small/medium teams, web apps  | Needs good main discipline      |
| GitFlow              |        High | Scheduled enterprise releases | Heavy, slower delivery          |
| Trunk-Based          |      Medium | Mature CI/CD teams            | Requires strong tests and flags |
| Release Branches     |      Medium | Versioned releases            | Can drift if unmanaged          |
| Environment Branches | Medium/High | Simple deployment mapping     | Drift risk, artifact confusion  |

---

# 13. What Real Companies Use

Many modern teams use:

```text
Trunk-based development
GitHub Flow
Short-lived branches
Feature flags
CI/CD gates
Release tags
GitOps for deployment
```

Many enterprise teams still use:

```text
GitFlow
release branches
Jenkins
manual approval gates
environment branches in older systems
```

As a DevOps engineer, you should understand all of them.

But for building your learning portfolio:

```text
Use GitHub Flow first.
Understand GitFlow.
Move toward trunk-based thinking.
```

---

# 14. CI/CD Trigger Mapping

Branching affects CI/CD.

Example:

```yaml
on:
  pull_request:
    branches:
      - main
```

This means:

```text
Run CI when PR targets main.
```

Example:

```yaml
on:
  push:
    branches:
      - main
```

This means:

```text
Run CI or deploy when code is merged to main.
```

Example:

```yaml
on:
  push:
    tags:
      - "v*.*.*"
```

This means:

```text
Run release pipeline when semantic version tag is pushed.
```

Later, Jenkins can do similar:

```text
PR branch      → test only
main branch    → build and push artifact
release tag    → production deployment
```

---

# 15. Hotfix Strategy

A hotfix is an urgent production fix.

Example:

```text
Production is broken.
main currently reflects production.
Create hotfix branch from main.
Fix.
PR.
Merge.
Deploy.
Tag new patch version.
```

Commands:

```bash
git switch main
git pull origin main
git switch -c hotfix/fix-api-timeout
```

Commit:

```bash
git commit -m "fix: reduce API timeout failure"
```

After merge:

```bash
git tag -a v1.2.1 -m "Hotfix API timeout"
git push origin v1.2.1
```

Patch version increases:

```text
v1.2.0 → v1.2.1
```

---

# 16. Bad Branching Habits

Avoid these:

```text
Working directly on main
Long-lived feature branches
Huge PRs
Branch names like final/final2/test
Merging without CI
Using branches as backups
Keeping stale branches forever
Force pushing shared branches
Having no release tags
Deploying unreviewed code
```

Better habits:

```text
Small branches
Small PRs
Clear commit messages
CI before merge
Protected main
Release tags
Delete merged branches
Use feature flags for incomplete features
```

---

# 17. Mini Lab — Add Branching Strategy Notes

Create GitHub issue:

```text
docs: add branching strategy notes
```

Acceptance criteria:

```markdown
- [ ] Explain GitHub Flow
- [ ] Explain GitFlow
- [ ] Explain trunk-based development
- [ ] Explain release branches
- [ ] Explain recommended strategy for this masterclass
- [ ] Include CI/CD trigger mapping
```

Now locally:

```bash
cd ~/devops-masterclass

git switch main
git pull origin main

git switch -c docs/module-02-branching-strategies

nano 02-git-github/branching-strategies.md
```

Paste:

````markdown
# Branching Strategies

## Why Branching Strategy Matters

A branching strategy defines how code moves from development to production safely.

## GitHub Flow

Simple workflow:

```text
main → feature branch → PR → CI → merge → deploy
````

Best for:

* Web apps
* Small/medium teams
* Frequent deployment

## GitFlow

Branches:

* main
* develop
* feature/*
* release/*
* hotfix/*

Best for:

* Enterprise projects
* Scheduled releases
* Versioned software

## Trunk-Based Development

Developers merge small changes into main frequently.

Requires:

* Strong CI
* Automated tests
* Feature flags
* Fast reviews

## Release Branches

Used to stabilize a version before production.

Example:

```text
release/v1.2.0
```

## Recommended Strategy for This Masterclass

Use GitHub Flow with release tags.

```text
main = stable
feature branches = all work
PR required before merge
CI validates PR
tags mark releases
```

## CI/CD Trigger Mapping

```text
Pull Request → run validation
main push → build artifact
version tag → release/deploy
```

````

Commit:

```bash
git status
git diff
git add 02-git-github/branching-strategies.md
git diff --staged
git commit -m "docs: add branching strategies notes"
git push -u origin docs/module-02-branching-strategies
````

Open PR and link issue.

---

# 18. Interview Answer

Question:

```text
What branching strategy would you choose for a small DevOps project and why?
```

Strong answer:

```text
For a small DevOps project, I would choose GitHub Flow. I would keep main stable and protected, create short-lived feature branches for each change, open pull requests, run CI checks, and merge only after validation. Releases can be marked using semantic version tags. This is simpler than GitFlow and works well for frequent delivery. As the project matures, I would move toward trunk-based development practices with smaller PRs, stronger automated tests, and feature flags.
```

Question:

```text
What is the problem with long-lived branches?
```

Strong answer:

```text
Long-lived branches increase merge conflicts, delay integration, make testing harder, and allow branches to drift away from main. When they are finally merged, the change is usually large and risky. Short-lived branches and frequent integration reduce risk because problems are found earlier and PRs stay small enough to review properly.
```

---

# Today’s Core Rules

```text
Choose the simplest branching strategy that supports safe delivery.
main should always be stable.
Use short-lived branches.
Use PRs and CI before merge.
Use tags for releases.
Avoid environment branch drift.
Build artifacts once and promote them.
Feature flags make trunk-based development safer.
```

Next lesson:

# Lesson 2.3 — Pull Request Review Masterclass: How to Review Code, Infra, CI/CD, Docker, Terraform, and Kubernetes Changes

# Module 2 — Git, GitHub & Engineering Workflow

Now we go deeper into Git and GitHub as a **real engineering workflow**, not just commands.

Module 1 gave you the production mindset. Module 2 teaches how professional teams manage code, collaboration, releases, reviews, and automation. Your uploaded curriculum already includes Git branching strategy, branch protection, semantic versioning, conventional commits, PR checks, and CI/CD foundations, so now we turn that into a complete workflow. 

---

# Module 2 Goal

By the end of this module, you should be able to work like this:

```text
Issue created
  ↓
Branch created
  ↓
Code/docs changed
  ↓
Commit with proper message
  ↓
Push branch
  ↓
Open Pull Request
  ↓
CI checks run
  ↓
Review happens
  ↓
Merge safely
  ↓
Release tag created
  ↓
Changelog updated
```

This is how real software teams work.

---

# Lesson 2.1 — GitHub Workflow: Issue → Branch → PR → Merge

A beginner workflow is:

```bash
git add .
git commit -m "update"
git push
```

A professional workflow is:

```text
Plan the work
  ↓
Track it in an issue
  ↓
Create a branch
  ↓
Make a focused change
  ↓
Open a pull request
  ↓
Run CI checks
  ↓
Review
  ↓
Merge to main
```

The difference is huge.

The first one only saves code.

The second one creates an **audit trail**.

---

# 1. Why Issues Exist

An issue is a unit of work.

It answers:

```text
What needs to be done?
Why does it matter?
What is the expected result?
How do we know it is complete?
```

Example issue:

```markdown
# Add Linux healthcheck script

## Goal

Create a Bash script that checks CPU, memory, disk, uptime, and open ports.

## Why

This script will become the first Linux automation lab in the DevOps masterclass.

## Acceptance Criteria

- [ ] Script checks CPU load
- [ ] Script checks memory usage
- [ ] Script checks disk usage
- [ ] Script checks open ports
- [ ] Script uses set -euo pipefail
- [ ] Script has clear output
- [ ] README explains how to run it
```

This is much better than randomly starting work.

---

# 2. Why Branches Exist

A branch isolates work.

Main branch should stay clean:

```text
main = stable
feature branch = work in progress
```

Bad:

```bash
git switch main
# edit files directly
git commit -m "changes"
git push
```

Good:

```bash
git switch main
git pull origin main
git switch -c feat/linux-healthcheck-script
```

Now your work is isolated.

If something breaks, `main` is still safe.

---

# 3. Branch Naming Convention

Use meaningful branch names.

Good examples:

```text
feat/linux-healthcheck-script
docs/module-02-github-workflow
fix/docker-compose-healthcheck
ci/add-repository-validation
security/add-gitleaks-config
infra/add-terraform-vpc
```

Pattern:

```text
type/short-description
```

Common types:

```text
feat      new feature
fix       bug fix
docs      documentation
ci        CI/CD change
infra     infrastructure change
security  security improvement
test      test changes
chore     maintenance
```

Avoid:

```text
new-branch
test
vivek-work
final-changes
update2
```

---

# 4. Why Pull Requests Exist

A Pull Request is not just a merge button.

A PR explains:

```text
What changed?
Why did it change?
How was it tested?
What issue does it close?
What risk exists?
```

A strong PR makes review easy.

Example PR:

````markdown
## Summary

Added a Linux healthcheck script for Module 3.

## Why

This gives a hands-on lab for checking CPU, memory, disk, and open ports.

## Changes

- Added `healthcheck.sh`
- Added usage instructions
- Added sample output

## Verification

```bash
bash -n healthcheck.sh
./healthcheck.sh
````

## Related Issue

Closes #3

````

---

# 5. Why CI Checks Exist

CI checks protect the main branch.

Before merge, CI should verify:

```text
Does the code build?
Do tests pass?
Are scripts valid?
Are secrets accidentally committed?
Does lint pass?
Are dependencies safe?
````

For now, your basic validation workflow can check:

```text
Repository structure
Shell script syntax
No real .env files
Markdown files exist
```

Later, CI will become stronger:

```text
Unit tests
Docker build
Trivy scan
Gitleaks scan
Semgrep scan
Terraform validate
Kubernetes manifest validation
```

---

# 6. Full Professional Flow

For every task, follow this:

```bash
# 1. Start clean
git switch main
git pull origin main

# 2. Create branch
git switch -c docs/module-02-github-workflow

# 3. Make changes
mkdir -p 02-git-github
nano 02-git-github/github-workflow.md

# 4. Review changes
git status
git diff

# 5. Stage and review staged diff
git add .
git diff --staged

# 6. Commit
git commit -m "docs: add GitHub workflow notes"

# 7. Push branch
git push -u origin docs/module-02-github-workflow
```

Then open PR on GitHub.

---

# 7. Commit Message Discipline

Bad commit messages:

```text
update
changes
fix
final
new code
working
```

Good commit messages:

```text
docs: add GitHub workflow notes
feat: add Linux healthcheck script
fix: correct Docker healthcheck path
ci: add shell syntax validation
security: add gitleaks configuration
infra: add Terraform remote backend
```

Why this matters:

```text
Release notes become easier
Git history becomes readable
Rollback is easier
Code review is easier
Automation becomes possible
```

---

# 8. Conventional Commit Format

Use:

```text
type(scope): message
```

Examples:

```text
docs(git): add pull request workflow
feat(linux): add healthcheck script
fix(docker): correct backend port mapping
ci(github): add validation workflow
security(secrets): add gitleaks config
infra(terraform): add vpc module
```

Scope is optional, but useful.

Simple version is also fine:

```text
docs: add pull request workflow
```

---

# 9. What Should Be in One Commit?

A commit should contain one logical change.

Good:

```text
Commit 1: add healthcheck script
Commit 2: add README instructions
Commit 3: add CI validation for shell scripts
```

Bad:

```text
One commit containing:
- healthcheck script
- Dockerfile
- Terraform VPC
- README rewrite
- random formatting
```

Why bad?

Because if something breaks, rollback becomes difficult.

---

# 10. Mini Lab — Create Module 2 First File

Create an issue on GitHub:

```text
docs: add GitHub workflow notes
```

Issue body:

```markdown
## Goal

Add notes explaining the professional GitHub workflow.

## Acceptance Criteria

- [ ] Explain issue → branch → PR → merge flow
- [ ] Explain branch naming
- [ ] Explain PR purpose
- [ ] Explain CI checks
- [ ] Add command examples
```

Then locally:

```bash
cd ~/devops-masterclass

git switch main
git pull origin main

git switch -c docs/module-02-github-workflow

mkdir -p 02-git-github
nano 02-git-github/github-workflow.md
```

Paste:

```markdown
# GitHub Engineering Workflow

## Professional Flow

Issue → Branch → Commit → Pull Request → CI Checks → Review → Merge

## Why Issues Matter

Issues define what needs to be done, why it matters, and how completion will be verified.

## Why Branches Matter

Branches isolate work so that main remains stable.

## Why Pull Requests Matter

Pull Requests explain what changed, why it changed, and how it was tested.

## Why CI Matters

CI protects the main branch by running automated checks before merge.

## Branch Naming

Examples:

- feat/linux-healthcheck-script
- docs/module-02-github-workflow
- ci/add-validation-workflow
- security/add-gitleaks-config
- infra/add-terraform-vpc

## Commit Message Examples

- docs: add GitHub workflow notes
- feat: add Linux healthcheck script
- ci: add shell script validation
- security: add secret scanning config

## Core Rule

main should always be stable and deployable.
```

Commit:

```bash
git status
git diff
git add 02-git-github/github-workflow.md
git diff --staged
git commit -m "docs: add GitHub workflow notes"
git push -u origin docs/module-02-github-workflow
```

Open PR and connect it to your issue.

---

# 11. Interview Answer

Question:

```text
How do you work on a task in a professional GitHub workflow?
```

Strong answer:

```text
I start by creating or picking an issue that clearly defines the goal and acceptance criteria. Then I update my local main branch, create a focused feature branch, make the change, review the diff, and commit using a clear conventional commit message. I push the branch and open a pull request explaining what changed, why it changed, and how I tested it. CI checks run automatically, and after review and successful checks, the PR is merged into main. This keeps main stable, creates an audit trail, and makes collaboration safer.
```

---

# Today’s Core Rules

```text
Issue defines the work.
Branch isolates the work.
Commit saves one logical change.
PR explains the work.
CI verifies the work.
Review improves the work.
main stays stable.
```

Next lesson:

# Lesson 2.2 — Branching Strategies: GitHub Flow, GitFlow, Trunk-Based Development, Release Branches

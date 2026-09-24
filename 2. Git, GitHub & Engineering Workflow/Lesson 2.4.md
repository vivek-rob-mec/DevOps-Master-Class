# Lesson 2.4 — Release Management: Semantic Versioning, Tags, Changelog, GitHub Releases, Hotfixes

Now we learn how professional teams answer this question:

```text
What version is running in production?
```

A weak team says:

```text
Latest code from main.
```

A strong team says:

```text
Production is running v1.4.2, built from commit a1b2c3d, deployed by pipeline #214, approved by Vivek, and rollback target is v1.4.1.
```

That is release management.

Your roadmap already includes CI/CD, deployment strategy, semantic versioning, artifact promotion, and rollback thinking, so this lesson connects Git workflow with production delivery. 

---

# 1. What is Release Management?

Release management is the process of planning, versioning, publishing, and tracking software releases.

It answers:

```text
What changed?
Which version contains the change?
When was it released?
Who approved it?
Which artifact was deployed?
How do we rollback?
```

Release management connects:

```text
Git commit
  ↓
Git tag
  ↓
Changelog
  ↓
Docker image
  ↓
GitHub/Jenkins pipeline
  ↓
Deployment
  ↓
Monitoring
```

---

# 2. Why “latest” is Dangerous

Bad Docker image tag:

```text
todo-app:latest
```

Problem:

```text
latest does not tell you which code is running.
latest can change.
rollback becomes unclear.
debugging becomes harder.
```

Better:

```text
todo-app:sha-a1b2c3d
todo-app:v1.4.2
```

Best production practice:

```text
Use immutable tags for deployment.
```

Example:

```text
Git commit: a1b2c3d
Git tag: v1.4.2
Docker image: todo-app:v1.4.2
Docker image also tagged: todo-app:sha-a1b2c3d
```

---

# 3. Semantic Versioning

Semantic versioning uses:

```text
MAJOR.MINOR.PATCH
```

Example:

```text
v2.5.1
```

Meaning:

```text
MAJOR = breaking change
MINOR = new backward-compatible feature
PATCH = backward-compatible bug fix
```

Examples:

```text
v1.0.0 → first stable release
v1.1.0 → new feature added
v1.1.1 → bug fix
v2.0.0 → breaking change
```

---

# 4. When to Increase Version

## Patch Version

Use patch for bug fixes.

```text
v1.2.0 → v1.2.1
```

Example:

```text
fix: correct API timeout handling
fix: repair broken health check
fix: resolve login error
```

---

## Minor Version

Use minor for new backward-compatible features.

```text
v1.2.0 → v1.3.0
```

Example:

```text
feat: add Redis cache
feat: add user profile endpoint
feat: add Jenkins CI pipeline
```

---

## Major Version

Use major for breaking changes.

```text
v1.2.0 → v2.0.0
```

Example:

```text
BREAKING CHANGE: rename /api/get-todo to /api/todos
BREAKING CHANGE: change database schema in non-compatible way
BREAKING CHANGE: remove old authentication method
```

---

# 5. Git Tags

A Git tag marks a specific commit as a release.

Create annotated tag:

```bash
git tag -a v0.2.0 -m "Complete Module 2 Git and GitHub workflow"
```

Push tag:

```bash
git push origin v0.2.0
```

List tags:

```bash
git tag
```

Show tag:

```bash
git show v0.2.0
```

Delete local tag:

```bash
git tag -d v0.2.0
```

Delete remote tag:

```bash
git push origin --delete v0.2.0
```

Use deletion carefully.

---

# 6. Tag-Based CI/CD

Later, we can configure GitHub Actions or Jenkins like this:

```text
Push to feature branch → run tests only
PR to main → run validation
Push to main → build artifact
Push tag v*.*.* → create release and deploy
```

Example GitHub Actions trigger:

```yaml
on:
  push:
    tags:
      - "v*.*.*"
```

This means:

```text
Only run release workflow when version tag is pushed.
```

Jenkins can also use:

```text
Build when tag is created
Build only release tags
Deploy only from approved release tags
```

---

# 7. Changelog

A changelog explains what changed between releases.

File:

```text
CHANGELOG.md
```

Create:

```bash
touch CHANGELOG.md
```

Basic format:

```markdown
# Changelog

## [v0.2.0] - 2026-06-28

### Added
- Added GitHub workflow notes
- Added branching strategy notes
- Added PR review checklist

### Changed
- Improved repository structure

### Fixed
- Fixed documentation formatting

### Security
- Added notes for secret-safe PR review
```

A good changelog helps:

```text
Developers
DevOps engineers
QA
Managers
Recruiters
Future you
```

---

# 8. Changelog Categories

Use:

```text
Added
Changed
Deprecated
Removed
Fixed
Security
```

Example:

```markdown
## [v1.3.0] - 2026-07-10

### Added
- Added Jenkins pipeline for Docker build and Trivy scan.
- Added staging deployment workflow.

### Changed
- Updated Docker image tagging strategy to use Git SHA.

### Fixed
- Fixed health check endpoint path in Docker Compose.

### Security
- Added Gitleaks secret scanning to CI.
```

---

# 9. GitHub Releases

A GitHub Release is a published release page connected to a Git tag.

It usually includes:

```text
Version tag
Release title
Release notes
Artifacts
Checksums
Docker image reference
Upgrade notes
Rollback notes
```

Example title:

```text
v0.2.0 — Git and GitHub Workflow Module Complete
```

Example release notes:

```markdown
## Summary

Completed Module 2 notes for Git, GitHub workflow, branching strategy, and PR review.

## Included

- GitHub workflow notes
- Branching strategy notes
- PR review checklist
- Release management notes

## Docker Image

Not applicable for this documentation release.

## Rollback

Revert to tag v0.1.0 if needed.
```

---

# 10. Release Candidate

A release candidate is a version that might become final if testing passes.

Example:

```text
v1.4.0-rc.1
v1.4.0-rc.2
```

Use when:

```text
QA needs to test before stable release
You want staging validation before production
Release is large or risky
```

Example flow:

```text
v1.4.0-rc.1 → staging
Tests pass
v1.4.0 → production
```

For your masterclass project, we can mostly use simple stable tags:

```text
v0.1.0
v0.2.0
v0.3.0
```

---

# 11. Hotfix Release

A hotfix is an urgent production fix.

Example:

```text
Current production: v1.4.0
Bug found in production
Create hotfix branch
Fix bug
Release v1.4.1
Deploy v1.4.1
```

Commands:

```bash
git switch main
git pull origin main
git switch -c hotfix/fix-healthcheck-timeout
```

After fix:

```bash
git add .
git commit -m "fix: correct healthcheck timeout"
git push -u origin hotfix/fix-healthcheck-timeout
```

After PR merge:

```bash
git switch main
git pull origin main
git tag -a v1.4.1 -m "Hotfix healthcheck timeout"
git push origin v1.4.1
```

Patch version increases:

```text
v1.4.0 → v1.4.1
```

---

# 12. Release and Docker Image Mapping

A proper release should map like this:

```text
Git tag: v1.4.1
Git commit: a1b2c3d
Docker image:
  todo-app:v1.4.1
  todo-app:sha-a1b2c3d
```

Why tag both?

```text
v1.4.1 is human-friendly.
sha-a1b2c3d is commit-exact.
```

In production deployment, you can use:

```text
todo-app:v1.4.1
```

For debugging, you can trace it back to:

```text
commit a1b2c3d
```

---

# 13. Release Checklist

Before creating a release, check:

```text
main is stable
CI checks passed
PRs are merged
CHANGELOG.md updated
Version number chosen
Tag created from correct commit
Release notes written
Artifact built once
Security scans passed
Rollback version known
Monitoring plan ready
```

Production release should also include:

```text
Approval
Smoke test
Rollback plan
Post-deploy monitoring
Incident communication path
```

---

# 14. Rollback Using Tags

If production is on:

```text
v1.4.1
```

And it breaks, rollback to:

```text
v1.4.0
```

Deployment system should support:

```text
Deploy previous Docker image tag
```

Example:

```bash
docker pull myrepo/todo-app:v1.4.0
docker compose up -d
```

In Kubernetes/Helm:

```bash
helm rollback todo-app 3 -n production
```

In GitOps:

```text
Revert the Git change that updated image tag from v1.4.0 to v1.4.1
ArgoCD syncs cluster back to v1.4.0
```

---

# 15. Bad Release Habits

Avoid:

```text
No version tags
Using latest in production
No changelog
No release notes
No rollback target
Manual untracked server changes
Building separately for each environment
Deploying from developer laptop
Not knowing which commit is live
```

Good release habits:

```text
Use semantic versioning
Tag releases
Write changelog
Build once
Promote same artifact
Use immutable Docker tags
Automate release pipeline
Keep rollback simple
```

---

# 16. Mini Lab — Add Release Management Notes

Create issue:

```text
docs: add release management notes
```

Acceptance criteria:

```markdown
- [ ] Explain semantic versioning
- [ ] Explain Git tags
- [ ] Explain changelog
- [ ] Explain GitHub releases
- [ ] Explain hotfix flow
- [ ] Add release checklist
```

Now locally:

```bash
cd ~/devops-masterclass

git switch main
git pull origin main

git switch -c docs/release-management

nano 02-git-github/release-management.md
```

Paste:

````markdown
# Release Management

## Goal

Release management tracks what version is running, what changed, and how to rollback.

## Semantic Versioning

Format:

```text
MAJOR.MINOR.PATCH
````

Examples:

* PATCH: v1.2.0 → v1.2.1 for bug fix
* MINOR: v1.2.0 → v1.3.0 for new backward-compatible feature
* MAJOR: v1.2.0 → v2.0.0 for breaking change

## Git Tags

Create release tag:

```bash
git tag -a v0.2.0 -m "Complete Module 2 Git workflow"
git push origin v0.2.0
```

## Changelog

A changelog explains what changed between versions.

Categories:

* Added
* Changed
* Fixed
* Security
* Removed
* Deprecated

## GitHub Releases

GitHub Releases attach release notes and artifacts to a Git tag.

## Hotfix Flow

```text
main → hotfix branch → PR → merge → patch tag → deploy
```

Example:

```text
v1.4.0 → v1.4.1
```

## Release Checklist

* [ ] main is stable
* [ ] CI passed
* [ ] CHANGELOG.md updated
* [ ] Version selected
* [ ] Git tag created
* [ ] Release notes written
* [ ] Artifact built once
* [ ] Security scans passed
* [ ] Rollback version known

````

Commit:

```bash
git status
git diff
git add 02-git-github/release-management.md
git diff --staged
git commit -m "docs: add release management notes"
git push -u origin docs/release-management
````

Open PR and merge after checks.

---

# 17. Mini Lab — Create CHANGELOG.md

Create another branch or include in same PR if small:

```bash
nano CHANGELOG.md
```

Paste:

```markdown
# Changelog

All notable changes to this repository will be documented in this file.

## [v0.2.0] - 2026-06-28

### Added
- Added GitHub engineering workflow notes.
- Added branching strategy notes.
- Added pull request review checklist.
- Added release management notes.

### Changed
- Improved Module 2 documentation structure.

### Security
- Added PR review guidance for secrets, Docker, CI/CD, Terraform, and Kubernetes.
```

Commit:

```bash
git add CHANGELOG.md
git commit -m "docs: add changelog"
git push
```

---

# 18. Create Module 2 Release Tag

After Module 2 is complete and merged:

```bash
git switch main
git pull origin main

git tag -a v0.2.0 -m "Complete Module 2 Git and GitHub engineering workflow"
git push origin v0.2.0
```

Then create GitHub Release from tag:

```text
GitHub → Releases → Draft a new release → Choose v0.2.0
```

Release title:

```text
v0.2.0 — Git and GitHub Engineering Workflow
```

Release notes:

```markdown
## Summary

Completed Module 2 foundational Git and GitHub engineering workflow documentation.

## Included

- GitHub workflow notes
- Branching strategy notes
- Pull request review checklist
- Release management notes
- Changelog

## Rollback

Previous stable tag: v0.1.0
```

---

# 19. Interview Answer

Question:

```text
How do you manage releases in a DevOps project?
```

Strong answer:

```text
I use semantic versioning, Git tags, changelogs, and immutable artifacts. Each release is tied to a specific Git commit and version tag, such as v1.4.2. The CI/CD pipeline builds the artifact once, often a Docker image tagged with both the version and Git SHA, then promotes that same artifact through environments. Release notes explain what changed, and the rollback target is known before deployment. For urgent production fixes, I use a hotfix branch and publish a patch version like v1.4.1.
```

Question:

```text
Why should we avoid using latest in production?
```

Strong answer:

```text
The latest tag is mutable, so it does not reliably identify which code is running. It can change without the deployment configuration changing, which makes debugging, auditing, and rollback harder. In production, I prefer immutable tags such as a semantic version or Git SHA, for example todo-app:v1.4.2 or todo-app:sha-a1b2c3d.
```

---

# Today’s Core Rules

```text
Use semantic versioning.
Use Git tags for releases.
Use CHANGELOG.md.
Use GitHub Releases for release notes.
Never rely on latest in production.
Build once, promote the same artifact.
Every release needs a rollback target.
Hotfixes increase patch version.
Version should map to commit and artifact.
```

Next lesson:

# Lesson 2.5 — GitHub Actions Foundation: CI Workflow, Status Checks, Secrets, Artifacts, Matrix Builds

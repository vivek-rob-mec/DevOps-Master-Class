# Lesson 1.9 — Git Deep Mental Model: Commit, Branch, Merge, Rebase, Reset, Revert, Tag

Now we learn Git properly.

Most beginners use Git like this:

```text
git add .
git commit -m "update"
git push
```

That is not enough.

A DevOps engineer must understand Git because CI/CD, Jenkins, GitHub Actions, GitOps, ArgoCD, Terraform collaboration, release tagging, rollback, and audit history all depend on Git. Your curriculum already includes Git branching strategy, branch protection, semantic versioning, conventional commits, and CI/CD workflows, so this lesson builds the foundation for that. 

---

# 1. What Git Actually Is

Git is a **distributed version control system**.

That means:

```text
Every developer has a full copy of the project history.
```

Git tracks snapshots of your project over time.

It helps answer:

```text
What changed?
Who changed it?
When was it changed?
Why was it changed?
Can we go back?
Can we compare versions?
Can we release a specific version?
```

In DevOps, Git is more than code storage.

Git becomes the source of truth for:

```text
Application code
Infrastructure code
Kubernetes manifests
CI/CD pipelines
Documentation
Runbooks
GitOps desired state
```

Important rule:

```text
If it matters, it should be version-controlled.
```

Except secrets.

Secrets should not be committed.

---

# 2. Git’s Core Mental Model

Git has three main areas:

```text
Working Directory
  ↓
Staging Area
  ↓
Repository
```

## Working Directory

This is where you edit files.

Example:

```text
README.md modified
script.sh modified
new file created
```

## Staging Area

This is where you choose what will go into the next commit.

Command:

```bash
git add README.md
```

## Repository

This is where commits are permanently stored in Git history.

Command:

```bash
git commit -m "docs: update README"
```

Mental model:

```text
Working directory = current edits
Staging area = selected edits for next snapshot
Repository = saved history
```

---

# 3. Check Git Status

Most important command:

```bash
git status
```

Use it constantly.

It tells you:

```text
Current branch
Modified files
Staged files
Untracked files
Whether branch is ahead/behind remote
```

Before every commit, run:

```bash
git status
```

Before every push, run:

```bash
git status
```

Before every dangerous command, run:

```bash
git status
```

---

# 4. What is a Commit?

A commit is a snapshot of your project at a point in time.

Each commit has:

```text
Unique hash
Author
Timestamp
Message
Pointer to parent commit
Snapshot of files
```

Example:

```bash
git log --oneline
```

Output:

```text
a1b2c3d docs: add README
d4e5f6g feat: add environment check script
h7i8j9k chore: initialize repo
```

A commit should represent one logical change.

Bad commit:

```text
update
```

Better commit:

```text
docs: add environment setup instructions
```

Best habit:

```text
One commit = one meaningful change.
```

---

# 5. What is a Branch?

A branch is a movable pointer to a commit.

Example:

```text
main ── A ── B ── C
```

If you create a new branch:

```bash
git checkout -b feat/add-healthcheck
```

Now:

```text
main                 A ── B ── C
feat/add-healthcheck A ── B ── C
```

When you commit on feature branch:

```text
main                 A ── B ── C
feat/add-healthcheck A ── B ── C ── D
```

So the feature branch has new work, while `main` stays stable.

---

# 6. Why Branches Matter in DevOps

Branches allow safe work.

You can build:

```text
Feature branch → Pull request → CI checks → Review → Merge to main
```

Instead of:

```text
Direct push to main → broken production
```

Professional rule:

```text
main should always be deployable.
```

For this masterclass, use branches like:

```bash
feat/linux-healthcheck-script
docs/add-git-notes
ci/add-jenkins-pipeline
infra/add-terraform-vpc
security/add-gitleaks-scan
```

---

# 7. Create, Switch, and Delete Branches

Create branch:

```bash
git checkout -b feat/example
```

Modern alternative:

```bash
git switch -c feat/example
```

List branches:

```bash
git branch
```

Switch branch:

```bash
git switch main
```

Delete local branch:

```bash
git branch -d feat/example
```

Force delete local branch:

```bash
git branch -D feat/example
```

Use force delete only when you are sure.

---

# 8. What is Merge?

Merge combines changes from one branch into another.

Example:

```text
main:     A ── B ── C
feature:          └── D ── E
```

Merge feature into main:

```text
main:     A ── B ── C ── M
                    \   /
feature:             D ─ E
```

`M` is a merge commit.

Command:

```bash
git switch main
git merge feat/add-healthcheck
```

In GitHub, merging usually happens through a Pull Request.

---

# 9. What is Fast-Forward Merge?

If `main` has not changed since the feature branch was created:

```text
main:     A ── B
feature:       └── C ── D
```

Git can simply move `main` forward:

```text
main:     A ── B ── C ── D
```

This is called fast-forward.

No merge commit needed.

---

# 10. What is Rebase?

Rebase moves your branch to start from the latest commit of another branch.

Before:

```text
main:     A ── B ── C
feature:       └── D ── E
```

After rebase:

```text
main:     A ── B ── C
feature:             └── D' ── E'
```

Command:

```bash
git switch feature
git rebase main
```

Rebase gives a cleaner linear history.

But be careful:

```text
Do not rebase shared branches that others are using.
```

Because rebase rewrites commit history.

---

# 11. Merge vs Rebase

| Concept              | Merge                      | Rebase                            |
| -------------------- | -------------------------- | --------------------------------- |
| What it does         | Combines histories         | Rewrites branch on top of another |
| History              | Preserves original history | Creates linear history            |
| Safety               | Safer for shared branches  | Risky if pushed/shared            |
| Common use           | PR merges                  | Clean local feature branch        |
| Creates merge commit | Often yes                  | No                                |

Simple rule:

```text
Use merge for shared branch integration.
Use rebase to clean your local feature branch before PR.
```

For beginners:

```text
Prefer merge until you understand rebase deeply.
```

---

# 12. What is Conflict?

A conflict happens when Git cannot automatically combine changes.

Example:

Two people edit the same line:

```text
main changes line 10
feature changes line 10 differently
```

Git shows:

```text
<<<<<<< HEAD
current branch version
=======
incoming branch version
>>>>>>> feature
```

You must manually choose the correct final version.

After fixing:

```bash
git add fixed-file
git commit
```

During rebase conflict:

```bash
git add fixed-file
git rebase --continue
```

Abort merge:

```bash
git merge --abort
```

Abort rebase:

```bash
git rebase --abort
```

Important:

```text
Conflicts are normal. They are not Git errors.
```

---

# 13. What is Reset?

`git reset` moves your branch pointer.

It can be dangerous.

There are three common modes:

```bash
git reset --soft
git reset --mixed
git reset --hard
```

## Soft reset

```bash
git reset --soft HEAD~1
```

Meaning:

```text
Undo last commit, keep changes staged.
```

## Mixed reset

```bash
git reset --mixed HEAD~1
```

Meaning:

```text
Undo last commit, keep changes in working directory, unstaged.
```

## Hard reset

```bash
git reset --hard HEAD~1
```

Meaning:

```text
Undo last commit and delete changes from working directory.
```

Danger:

```text
git reset --hard can destroy uncommitted work.
```

Before using it:

```bash
git status
```

---

# 14. What is Revert?

`git revert` creates a new commit that undoes a previous commit.

Example:

```bash
git revert a1b2c3d
```

This is safer than reset for shared branches.

Why?

Because it does not rewrite history.

History before:

```text
A ── B ── C
```

Revert C:

```text
A ── B ── C ── D
```

Where `D` undoes `C`.

Production rule:

```text
Use revert for commits already pushed to shared branches.
```

---

# 15. Reset vs Revert

| Command | What it does           | Safe for shared branch? |
| ------- | ---------------------- | ----------------------- |
| reset   | Moves history backward | No                      |
| revert  | Adds new undo commit   | Yes                     |

Simple rule:

```text
Local mistake before push → reset may be okay.
Pushed mistake on main → use revert.
```

---

# 16. What is Tag?

A tag points to a specific commit.

Tags are used for releases.

Example:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Annotated tag:

```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

Tags help CI/CD:

```text
Push tag v1.0.0
  ↓
Pipeline builds release artifact
  ↓
Docker image tagged v1.0.0
  ↓
Deploy release
```

Example Docker tag mapping:

```text
Git tag: v1.0.0
Docker image: todo-app:v1.0.0
```

---

# 17. Semantic Versioning

Use:

```text
MAJOR.MINOR.PATCH
```

Example:

```text
v2.4.1
```

Meaning:

```text
MAJOR = breaking change
MINOR = new backward-compatible feature
PATCH = bug fix
```

Examples:

```text
v1.0.0 → first stable release
v1.1.0 → new feature
v1.1.1 → bug fix
v2.0.0 → breaking change
```

This matters for release automation.

---

# 18. Git Log and History Commands

View simple history:

```bash
git log --oneline
```

View branch graph:

```bash
git log --oneline --graph --decorate --all
```

View last commit:

```bash
git show HEAD
```

View specific commit:

```bash
git show <commit-hash>
```

View file changes:

```bash
git diff
```

View staged changes:

```bash
git diff --staged
```

View who changed a line:

```bash
git blame README.md
```

---

# 19. Git Stash

Stash temporarily saves uncommitted work.

Example:

```bash
git stash
```

List stashes:

```bash
git stash list
```

Apply latest stash:

```bash
git stash pop
```

Use case:

```text
You are working on a feature.
Urgent bug fix comes.
Your current work is not ready to commit.
Stash it, switch branch, fix bug, come back.
```

Commands:

```bash
git stash push -m "work in progress on healthcheck script"
git switch main
git pull
git switch -c fix/readme-typo
```

---

# 20. Git Pull and Fetch

`git fetch` downloads remote changes but does not merge them.

```bash
git fetch origin
```

`git pull` downloads and integrates remote changes.

```bash
git pull
```

Mental model:

```text
git pull = git fetch + git merge
```

For safer workflow:

```bash
git fetch origin
git status
git log --oneline --graph --decorate --all
```

Then decide whether to merge or rebase.

---

# 21. Remote Repository

Remote means GitHub/GitLab server.

Check remotes:

```bash
git remote -v
```

Add remote:

```bash
git remote add origin git@github.com:USER/repo.git
```

Push branch:

```bash
git push -u origin feat/example
```

Pull latest main:

```bash
git switch main
git pull origin main
```

---

# 22. Professional Git Workflow

Use this every time:

```text
1. Pull latest main
2. Create issue
3. Create feature branch
4. Make small change
5. Check status
6. Check diff
7. Commit with conventional message
8. Push branch
9. Open PR
10. CI runs
11. Review
12. Merge
13. Delete branch
14. Pull latest main
```

Commands:

```bash
git switch main
git pull origin main

git switch -c feat/add-linux-notes

# make changes

git status
git diff
git add .
git diff --staged
git commit -m "docs: add Linux notes"
git push -u origin feat/add-linux-notes
```

---

# 23. Dangerous Commands Checklist

Be careful with:

```bash
git reset --hard
git clean -fd
git push --force
git rebase
```

Before using dangerous commands:

```bash
git status
git branch
git log --oneline --graph --decorate --all -10
```

Important:

```text
Never force push to main.
Never reset shared main history.
Never rewrite history others depend on.
```

---

# 24. DevOps Use Cases of Git

Git is used for:

```text
CI/CD trigger
Jenkinsfile versioning
GitHub Actions workflow versioning
Terraform modules
Ansible playbooks
Dockerfile changes
Kubernetes YAML
Helm charts
ArgoCD GitOps
Release tags
Rollback history
Audit trail
```

In GitOps:

```text
Git repository = desired production state
```

ArgoCD watches Git and makes Kubernetes match Git.

So if Git is messy, GitOps becomes messy.

---

# 25. Mini Lab — Practice Git Properly

Inside your masterclass repo:

```bash
cd ~/devops-masterclass
git switch main
git pull origin main
git switch -c docs/git-mental-model
```

Create file:

```bash
mkdir -p 02-git-github
nano 02-git-github/git-mental-model.md
```

Paste:

```markdown
# Git Mental Model

## Three Areas

Working Directory → Staging Area → Repository

## Important Concepts

- Commit: snapshot of project history
- Branch: movable pointer to a commit
- Merge: combine histories
- Rebase: replay commits on top of another branch
- Reset: move branch pointer, can rewrite history
- Revert: safely undo a commit with a new commit
- Tag: mark a release commit

## Rules

- main should always be stable
- use feature branches
- use pull requests
- use conventional commits
- use revert for pushed/shared commits
- never commit secrets
```

Check:

```bash
git status
git diff
```

Stage and commit:

```bash
git add 02-git-github/git-mental-model.md
git diff --staged
git commit -m "docs: add Git mental model notes"
git push -u origin docs/git-mental-model
```

Open a PR on GitHub.

---

# 26. Mini Lab — Create a Release Tag

After merging your PR to main:

```bash
git switch main
git pull origin main
git tag -a v0.1.0 -m "Initial masterclass structure and Git workflow"
git push origin v0.1.0
```

This is your first release tag.

Meaning:

```text
v0.1.0 = initial structured learning repo release
```

Later, CI/CD can trigger on tags.

---

# 27. Interview Answer

Question:

```text
What is the difference between git reset and git revert?
```

Strong answer:

```text
git reset moves the branch pointer backward and can rewrite history. It is useful for local commits that have not been pushed yet, but it can be dangerous on shared branches. git revert creates a new commit that undoes the changes from a previous commit without rewriting history. For commits already pushed to main or used by others, revert is safer and preferred.
```

Question:

```text
What is the difference between merge and rebase?
```

Strong answer:

```text
Merge combines two branches and preserves their original history, often creating a merge commit. Rebase takes commits from one branch and replays them on top of another branch, creating a cleaner linear history but rewriting commit hashes. I use merge for shared branch integration and rebase only for cleaning up my local feature branch before opening a pull request.
```

---

# Today’s Core Rules

```text
Git is not just code storage.
Commit small logical changes.
main should always be stable.
Use feature branches and PRs.
Use conventional commits.
Use tags for releases.
Use revert for pushed/shared mistakes.
Be careful with reset, rebase, clean, and force push.
In GitOps, Git becomes production source of truth.
```

Next lesson:

# Lesson 1.10 — Final Module 1 Mini Project: Production-Ready Learning Repository + Architecture Notes

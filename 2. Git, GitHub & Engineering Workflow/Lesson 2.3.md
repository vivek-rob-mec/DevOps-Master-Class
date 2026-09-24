# Lesson 2.3 — Pull Request Review Masterclass

Now we learn one of the most important real-world engineering skills:

> How to review changes before they enter `main`.

A Pull Request is not only for code review. In DevOps, PRs may change:

```text
Application code
Dockerfiles
Jenkinsfiles
GitHub Actions workflows
Terraform infrastructure
Ansible playbooks
Kubernetes manifests
Helm charts
Security policies
Monitoring alerts
Runbooks
```

A bad PR review can cause production incidents.

Your current roadmap already includes CI/CD, DevSecOps, Kubernetes, Terraform, Ansible, and production reliability, so PR review must become a core engineering habit. 

---

# 1. What is a Pull Request Review?

A PR review means checking a proposed change before it is merged.

You are checking:

```text
Is the change correct?
Is it safe?
Is it tested?
Is it secure?
Is it maintainable?
Can it break production?
Can we rollback if needed?
Is the documentation updated?
```

A beginner reviews like this:

```text
Looks good.
```

A professional reviews like this:

```text
What changed?
Why was it changed?
What risk does it introduce?
How was it tested?
What happens if this fails in production?
```

---

# 2. The PR Review Mindset

When reviewing, think in layers:

```text
Correctness
Security
Reliability
Maintainability
Observability
Rollback
Cost
Documentation
```

For DevOps/SRE work, a PR is not complete just because the syntax is valid.

Example:

```yaml
replicas: 1
```

This may be valid Kubernetes YAML.

But production question is:

```text
Is one replica enough?
What happens during node failure?
What happens during rolling deployment?
Is there a PodDisruptionBudget?
```

That is the difference between syntax review and production review.

---

# 3. Good PR Review Questions

Use these questions for almost every PR:

```text
What problem does this solve?
Is the change small enough to review?
Are tests included or updated?
Are secrets exposed?
Does this affect production traffic?
Does this affect infrastructure cost?
Does this affect security?
Does this affect rollback?
Does this require documentation?
Does this require monitoring or alert changes?
```

For any risky change, ask:

```text
What is the rollback plan?
```

If there is no rollback plan, the PR is not production-ready.

---

# 4. PR Size Rule

Small PRs are easier to review.

Good PR:

```text
Adds one healthcheck script
Changes 3 files
Clear description
Easy to test
```

Bad PR:

```text
Changes Dockerfile
Changes Terraform VPC
Changes Kubernetes deployment
Changes Jenkinsfile
Changes app code
Changes README
All in one PR
```

Why bad?

```text
Hard to review
Hard to test
Hard to rollback
High risk
Root cause is unclear if it breaks
```

Rule:

```text
One PR should solve one problem.
```

---

# 5. PR Description Template

Every good PR should include:

```markdown
## Summary

What changed?

## Why

Why is this needed?

## Risk

What can break?

## Testing

How was this verified?

## Rollback

How can we undo this?

## Related Issue

Closes #
```

For DevOps changes, add:

```markdown
## Production Impact

- [ ] No production impact
- [ ] Changes deployment
- [ ] Changes infrastructure
- [ ] Changes secrets/config
- [ ] Changes monitoring/alerts
- [ ] Changes security
```

This forces real thinking.

---

# 6. Code Review Checklist

For application code PRs, check:

```text
Does the code solve the issue?
Is the logic simple?
Are errors handled?
Are logs useful?
Are tests added?
Are environment variables documented?
Are secrets avoided?
Does it fail safely?
Does it expose sensitive data?
```

Example bad code:

```js
console.log("DB password:", process.env.DB_PASSWORD);
```

Why bad?

```text
Secret may leak into logs.
Logs may go to Loki, ELK, CloudWatch, or third-party tools.
```

Better:

```js
console.log("Database configuration loaded");
```

---

# 7. Dockerfile Review Checklist

For Dockerfile PRs, check:

```text
Is the base image pinned?
Is :latest avoided?
Is multi-stage build used if needed?
Is the final image small?
Is the app running as non-root?
Are secrets copied into the image?
Is .dockerignore present?
Are package files copied before source for cache?
Does CMD use exec form?
Is there a HEALTHCHECK if appropriate?
```

Bad:

```dockerfile
FROM node:latest
WORKDIR /app
COPY . .
RUN npm install
CMD node server.js
```

Problems:

```text
latest is unstable
npm install is less reproducible than npm ci
COPY . . may copy secrets
Runs as root by default
CMD shell form handles signals poorly
No healthcheck
```

Better:

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app
USER node
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/package.json ./
CMD ["node", "dist/server.js"]
```

---

# 8. Docker Compose Review Checklist

For `docker-compose.yml`, check:

```text
Are services separated properly?
Is database separate from app?
Are ports exposed only when needed?
Are healthchecks added?
Are volumes used for persistent data?
Are secrets avoided in plain text?
Are restart policies defined?
Are logs limited?
Are resource limits considered?
Are networks used properly?
```

Bad:

```yaml
ports:
  - "5432:5432"
```

If this is production, exposing Postgres publicly is dangerous.

Better:

```yaml
# No public ports for database.
# Only backend service can reach it through internal Docker network.
```

---

# 9. Jenkinsfile Review Checklist

For Jenkins PRs, check:

```text
Are stages clear?
Are credentials handled with withCredentials?
Are secrets avoided in logs?
Are tools pinned?
Are tests before build?
Are scans before deploy?
Is production approval required?
Is rollback considered?
Are post actions added?
Are artifacts archived?
Are agents used properly?
```

Bad:

```groovy
sh 'docker login -u vivek -p mypassword'
```

Better:

```groovy
withCredentials([usernamePassword(
    credentialsId: 'dockerhub-creds',
    usernameVariable: 'DOCKER_USER',
    passwordVariable: 'DOCKER_PASS'
)]) {
    sh 'echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin'
}
```

Important Jenkins review question:

```text
Can this pipeline leak credentials in console logs?
```

---

# 10. GitHub Actions Review Checklist

For GitHub Actions workflow PRs, check:

```text
Are actions pinned to stable versions?
Are permissions minimized?
Are secrets used safely?
Does PR workflow avoid deploying?
Are production deploys protected?
Are cache keys safe?
Are untrusted PRs prevented from accessing secrets?
Are security scans included?
```

Bad:

```yaml
permissions: write-all
```

Better:

```yaml
permissions:
  contents: read
```

Only give more permissions when required.

For production deployment:

```yaml
environment: production
```

Then configure GitHub Environment approval.

---

# 11. Terraform Review Checklist

For Terraform PRs, check:

```text
Is terraform fmt applied?
Does terraform validate pass?
Is plan attached or reviewed?
Are resources named consistently?
Are variables documented?
Are outputs safe?
Are secrets avoided in state?
Are security groups too open?
Is public access intentional?
Is cost impact understood?
Is deletion risk understood?
```

Danger example:

```hcl
cidr_blocks = ["0.0.0.0/0"]
from_port   = 22
to_port     = 22
```

This exposes SSH to the world.

Better:

```hcl
cidr_blocks = [var.admin_ip_cidr]
from_port   = 22
to_port     = 22
```

Terraform PR golden rule:

```text
Never approve Terraform without reviewing the plan.
```

---

# 12. Ansible Review Checklist

For Ansible PRs, check:

```text
Are tasks idempotent?
Are handlers used properly?
Are templates used instead of inline hacks?
Are secrets encrypted with Ansible Vault?
Are package names OS-aware?
Are become privileges limited?
Are changes safe to rerun?
Is inventory correct?
```

Bad:

```yaml
- name: Install package
  shell: apt install nginx -y
```

Better:

```yaml
- name: Install nginx
  apt:
    name: nginx
    state: present
    update_cache: yes
```

Why?

```text
The apt module is idempotent.
The shell command is harder to reason about and less safe.
```

---

# 13. Kubernetes Review Checklist

For Kubernetes PRs, check:

```text
Are resource requests and limits set?
Are liveness/readiness probes configured?
Are replicas appropriate?
Are secrets handled safely?
Are ConfigMaps used for non-secret config?
Is service type correct?
Is ingress secure?
Are labels/selectors correct?
Is namespace correct?
Is RBAC least privilege?
Are NetworkPolicies needed?
Is image tag immutable?
```

Bad:

```yaml
image: todo-app:latest
```

Better:

```yaml
image: todo-app:sha-a1b2c3d
```

Why?

```text
latest is not immutable.
You cannot reliably know what is running.
Rollback becomes unclear.
```

---

# 14. Helm Chart Review Checklist

For Helm PRs, check:

```text
Are values separated by environment?
Are templates readable?
Are defaults safe?
Are secrets avoided in values.yaml?
Are helpers used consistently?
Does helm template render correctly?
Does helm lint pass?
Are image tags configurable?
Are probes/resources configurable?
```

Important commands:

```bash
helm lint ./chart
helm template todo-app ./chart -f values-dev.yaml
```

Never approve Helm blindly.

Rendered YAML matters more than template appearance.

---

# 15. Security Review Checklist

For any PR, check:

```text
Are secrets committed?
Are credentials printed?
Are permissions too broad?
Are containers running as root?
Are public ports exposed?
Are dependencies vulnerable?
Are images scanned?
Are IAM policies least privilege?
Are Kubernetes RBAC permissions too broad?
Are sensitive logs exposed?
```

Common dangerous IAM policy:

```json
{
  "Action": "*",
  "Resource": "*",
  "Effect": "Allow"
}
```

This may work, but it is not secure.

Ask:

```text
What exact permissions are needed?
```

---

# 16. Observability Review Checklist

Any production change should consider observability.

Ask:

```text
Will we know if this breaks?
Are logs useful?
Are metrics available?
Are traces impacted?
Do alerts need updates?
Does dashboard need update?
Is there a runbook?
```

Example:

If PR adds a new background worker, it should also consider:

```text
Queue depth metric
Worker error count
Retry count
Dead-letter queue count
Worker logs
Alert if queue grows
```

A feature without observability is hard to operate.

---

# 17. Documentation Review Checklist

Check:

```text
Is README updated?
Are run commands updated?
Are environment variables documented?
Is .env.example updated?
Are diagrams updated?
Are runbooks updated?
Are troubleshooting notes added?
```

If a PR changes deployment behavior but does not update docs, it is incomplete.

---

# 18. How to Give Good Review Comments

Bad review comment:

```text
Wrong.
```

Better:

```text
This may expose the database publicly because port 5432 is mapped to the host. Can we remove the public port and keep Postgres accessible only through the internal Docker network?
```

Good review comments are:

```text
Specific
Respectful
Actionable
Reasoned
Production-aware
```

Use this format:

```text
Observation:
Risk:
Suggestion:
```

Example:

```text
Observation: The Docker image uses node:latest.
Risk: latest can change unexpectedly and break reproducible builds.
Suggestion: Pin to a specific LTS version like node:20-alpine.
```

---

# 19. How to Respond to PR Review

Do not take review personally.

Good response:

```text
Good catch. I changed the image tag from latest to node:20-alpine and updated the Dockerfile.
```

Bad response:

```text
It works on my machine.
```

Professional mindset:

```text
Review protects production.
```

---

# 20. Approval Rules

Do not approve if:

```text
CI failed
Secrets are exposed
Terraform plan is not reviewed
Production deploy lacks rollback
Security group is too open without reason
Kubernetes uses latest tag
No healthcheck for critical service
Docs are missing for operational changes
```

Approve when:

```text
Change is clear
Risk is understood
Tests/checks pass
Rollback exists
Security is acceptable
Docs are updated
```

---

# 21. Mini Lab — Add PR Review Checklist

Create issue:

```text
docs: add pull request review checklist
```

Acceptance criteria:

```markdown
- [ ] Add general PR checklist
- [ ] Add Docker review checklist
- [ ] Add Jenkins/GitHub Actions checklist
- [ ] Add Terraform checklist
- [ ] Add Kubernetes checklist
- [ ] Add security checklist
```

Now locally:

```bash
cd ~/devops-masterclass

git switch main
git pull origin main

git switch -c docs/pr-review-checklist

nano 02-git-github/pr-review-checklist.md
```

Paste:

```markdown
# Pull Request Review Checklist

## General Review

- [ ] The PR solves one clear problem
- [ ] The description explains what changed and why
- [ ] CI checks passed
- [ ] Tests or verification steps are included
- [ ] No secrets are committed
- [ ] Documentation is updated if needed
- [ ] Rollback plan is clear for risky changes

## Docker Review

- [ ] Base image is pinned
- [ ] No `latest` tag in production
- [ ] App does not run as root
- [ ] `.dockerignore` exists
- [ ] Secrets are not copied into the image
- [ ] Image can be rebuilt reproducibly

## CI/CD Review

- [ ] Secrets are handled through credentials/secrets manager
- [ ] Tests run before build/deploy
- [ ] Security scans run before deploy
- [ ] Production deploy requires approval
- [ ] Rollback is considered

## Terraform Review

- [ ] `terraform fmt` and `terraform validate` pass
- [ ] Terraform plan is reviewed
- [ ] Security groups are not overly open
- [ ] IAM permissions follow least privilege
- [ ] Cost impact is understood
- [ ] No secrets are exposed in code or outputs

## Kubernetes Review

- [ ] Resource requests and limits are set
- [ ] Readiness and liveness probes are configured
- [ ] Image tag is immutable
- [ ] Secrets are handled safely
- [ ] RBAC follows least privilege
- [ ] Service and ingress are correctly configured

## Security Review

- [ ] No hardcoded credentials
- [ ] No sensitive values in logs
- [ ] Dependencies are scanned
- [ ] Containers avoid privileged mode
- [ ] Public exposure is intentional
- [ ] Access follows least privilege
```

Commit:

```bash
git status
git diff
git add 02-git-github/pr-review-checklist.md
git diff --staged
git commit -m "docs: add pull request review checklist"
git push -u origin docs/pr-review-checklist
```

Open PR and review it using your own checklist.

---

# 22. Interview Answer

Question:

```text
What do you check when reviewing a DevOps pull request?
```

Strong answer:

```text
I check correctness, risk, security, reliability, rollback, and documentation. For Docker changes, I check pinned base images, non-root users, .dockerignore, and secrets. For CI/CD changes, I check credentials handling, scan gates, approvals, and rollback. For Terraform, I review the plan, security groups, IAM permissions, cost impact, and state safety. For Kubernetes, I check resource limits, probes, immutable image tags, RBAC, secrets, and service exposure. I also make sure CI passes and the PR explains how the change was tested.
```

Question:

```text
Why are small pull requests better?
```

Strong answer:

```text
Small pull requests are easier to review, test, and rollback. They reduce the chance of hidden bugs and make it easier to identify root cause if something breaks. Large PRs often mix unrelated changes, which increases review time and production risk. I prefer one PR to solve one clear problem with a clear description and verification steps.
```

---

# Today’s Core Rules

```text
A PR is a production safety gate.
Review risk, not only syntax.
Small PRs are safer.
Never approve secrets.
Never approve Terraform without a plan.
Never approve production deploy changes without rollback thinking.
Kubernetes needs probes, resources, and immutable image tags.
Review comments should be specific, respectful, and actionable.
```

Next lesson:

# Lesson 2.4 — Release Management: Semantic Versioning, Tags, Changelog, GitHub Releases, Hotfixes

Good. We continue properly.

# Lesson 1.2 — Environments: Local, Dev, Staging, Production

In real companies, you do **not** directly deploy code to production.

A beginner flow looks like this:

```text
Developer writes code
  ↓
Pushes code
  ↓
Directly changes production
```

This is dangerous.

A real-world DevOps flow looks like this:

```text
Local
  ↓
Dev
  ↓
Staging
  ↓
Production
```

Your uploaded curriculum already starts with this idea: companies use Dev, Staging, and Production because deployment can break systems, rollback matters, and production needs safety. 

---

# 1. What is Local Environment?

Local means your own laptop or workstation.

Example:

```text
Your Windows/WSL/Ubuntu machine
Your VS Code
Your local Docker
Your local database
Your local Node.js app
```

Purpose:

```text
Write code
Test quickly
Break things safely
Experiment freely
```

Example:

```bash
npm run dev
docker compose up
python app.py
```

Local environment is for speed, not perfect production accuracy.

---

# 2. What is Dev Environment?

Dev environment is a shared testing environment for developers.

```text
Developer pushes code
  ↓
CI pipeline builds it
  ↓
App deploys to Dev environment
```

Purpose:

```text
Check if code works outside your laptop
Test with shared services
Catch environment-specific bugs
Allow team testing
```

Example:

```text
dev.yourdatascientist.tech
api-dev.yourdatascientist.tech
```

Dev can be unstable. It is okay if dev breaks sometimes.

---

# 3. What is Staging Environment?

Staging should be as close to production as possible.

```text
Same type of server
Same Docker image
Same Kubernetes manifests
Same Terraform modules
Same database engine
Same monitoring setup
```

Purpose:

```text
Final testing before production
Smoke testing
QA testing
Security testing
Performance testing
Deployment rehearsal
```

Example:

```text
staging.yourdatascientist.tech
api-staging.yourdatascientist.tech
```

Important rule:

```text
If it does not work in staging, it should not go to production.
```

---

# 4. What is Production Environment?

Production is the real system used by real users.

```text
Real users
Real data
Real payments
Real uptime expectations
Real incidents
Real business impact
```

Production must be protected.

You do not experiment in production.

You do not manually change production unless it is an emergency.

You do not deploy untested code to production.

Production requires:

```text
Access control
Backups
Monitoring
Alerts
Rollback
Audit logs
Security
Change approval
```

---

# Full Release Flow

A mature release flow looks like this:

```text
Developer writes code locally
  ↓
Creates feature branch
  ↓
Opens pull request
  ↓
CI runs tests, lint, security scans
  ↓
Code review happens
  ↓
Merge to main
  ↓
Build Docker image once
  ↓
Deploy image to Dev
  ↓
Promote same image to Staging
  ↓
Run smoke tests
  ↓
Manual approval
  ↓
Promote same image to Production
  ↓
Monitor metrics/logs
  ↓
Rollback if needed
```

Important point:

```text
Build once, promote the same artifact.
```

Do **not** rebuild separately for dev, staging, and production.

Bad:

```text
Build image for dev
Build image again for staging
Build image again for production
```

Good:

```text
Build image once
Tag it with Git SHA
Promote the same image to every environment
```

Example:

```text
todo-app:sha-a1b2c3d
```

That same image moves through:

```text
Dev → Staging → Production
```

---

# Why This Matters

Imagine you build separately for each environment.

Dev image:

```text
todo-app:dev-build
```

Staging image:

```text
todo-app:staging-build
```

Production image:

```text
todo-app:prod-build
```

Now production breaks.

Question:

```text
Are you sure the production image is exactly the same as the staging image?
```

Maybe not.

That is why serious teams build once and promote.

---

# Environment Differences

Each environment should have the same code but different configuration.

Same Docker image:

```text
todo-app:sha-a1b2c3d
```

Different environment variables:

```text
DEV_DATABASE_URL
STAGING_DATABASE_URL
PROD_DATABASE_URL
```

Different domains:

```text
dev.example.com
staging.example.com
example.com
```

Different resource size:

```text
Dev: small server
Staging: medium server
Production: autoscaling/high availability
```

Different access level:

```text
Dev: developers can access
Staging: developers + QA
Production: restricted access only
```

---

# Real-World Example: Todo App

For your Todo app, the environment design could be:

```text
Local:
localhost:3000 frontend
localhost:3002 backend
local MongoDB/PostgreSQL

Dev:
dev-todo.yourdatascientist.tech
dev-api.yourdatascientist.tech
small cloud database

Staging:
staging-todo.yourdatascientist.tech
staging-api.yourdatascientist.tech
production-like database

Production:
todo.yourdatascientist.tech
api.yourdatascientist.tech
managed database with backups
monitoring and alerts enabled
```

---

# Common Beginner Mistakes

## Mistake 1 — Direct production deployment

```text
SSH into server
git pull
npm install
pm2 restart app
```

This is risky because:

```text
No audit trail
No repeatability
No rollback plan
No approval
No artifact versioning
```

Better:

```text
Pipeline deploys versioned artifact.
```

---

## Mistake 2 — Different code in staging and production

Bad:

```text
Staging runs branch: staging
Production runs branch: main
```

Better:

```text
Both run the same Docker image tag.
```

Only config should differ.

---

## Mistake 3 — No rollback

Bad deployment happens.

Beginner response:

```text
Let me debug the issue on production.
```

Production response:

```text
Rollback first.
Debug after service is restored.
```

---

## Mistake 4 — Secrets stored in code

Bad:

```js
const DB_PASSWORD = "mypassword123";
```

Good:

```js
const DB_PASSWORD = process.env.DB_PASSWORD;
```

Secrets should come from:

```text
GitHub Secrets
Jenkins Credentials
AWS Secrets Manager
Vault
Kubernetes Secrets with external secret manager
```

---

# Environment Promotion Model

Think of deployment like this:

```text
Code is not promoted.
Artifacts are promoted.
```

Better mental model:

```text
Git commit
  ↓
Docker image
  ↓
Dev
  ↓
Staging
  ↓
Production
```

Example:

```text
Commit: a1b2c3d
Image: todo-app:a1b2c3d
Dev: running todo-app:a1b2c3d
Staging: running todo-app:a1b2c3d
Prod: running todo-app:a1b2c3d
```

This gives traceability.

You can answer:

```text
Which commit is running in production?
Which pipeline deployed it?
Who approved it?
When was it deployed?
Can we rollback?
```

---

# Mini Lab — Design Your Environments

Create this section in your `devops-masterclass-notes.md`:

```markdown
## Lesson 1.2 — Environments

### Local
Purpose:
Tools:
URL:
Database:

### Dev
Purpose:
URL:
Who can access:
Deployment method:

### Staging
Purpose:
URL:
How similar to production:
Tests before production:

### Production
Purpose:
URL:
Access control:
Backup strategy:
Monitoring:
Rollback strategy:
```

Now fill it for your Todo App.

Example:

```markdown
### Production
Purpose: Real users use the Todo app
URL: todo.yourdatascientist.tech
Access control: Only admin/DevOps can deploy
Backup strategy: Daily database backup
Monitoring: Prometheus + Grafana alerts
Rollback strategy: Deploy previous Docker image tag
```

---

# Interview Answer

Question:

```text
Why do companies use dev, staging, and production environments?
```

Strong answer:

```text
Companies separate environments to reduce deployment risk. Local is for fast development, dev is for shared integration testing, staging is a production-like environment for final validation, and production is the real user-facing system. Code should be built once into an immutable artifact, usually a Docker image tagged with the Git SHA, and the same artifact should be promoted from dev to staging to production. Only configuration should differ between environments. This gives traceability, safer deployments, easier rollback, and fewer production incidents.
```

---

# Today’s Key Rule

Remember this:

```text
Never treat production as a testing environment.
```

And this:

```text
Build once. Promote the same artifact.
```

Next lesson:

# Lesson 1.3 — What is Deployment, Release, Rollback, and Roll Forward?

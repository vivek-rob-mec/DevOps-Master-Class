Perfect. Let’s continue.

# Lesson 1.3 — Deployment, Release, Rollback, and Roll Forward

Most beginners use these words as if they mean the same thing:

```text
deploy
release
rollback
roll forward
```

But in real DevOps/SRE work, they are different.

Your curriculum already says deployment, rollback, and production safety are core concepts before tools, so this lesson is important before we touch Jenkins, Docker, or Kubernetes deeply. 

---

# 1. What is a Deployment?

A **deployment** means putting a new version of the application into an environment.

Example:

```text
Deploy version v1.4.2 to staging
Deploy Docker image todo-app:sha-a1b2c3d to production
Deploy Helm chart version 0.8.1 to Kubernetes
```

Deployment is a technical action.

It means the new code or artifact is now running somewhere.

Example flow:

```text
Docker image built
  ↓
Image pushed to registry
  ↓
Server/Kubernetes pulls image
  ↓
Old container stopped
  ↓
New container started
  ↓
Health check passes
```

That is deployment.

---

# 2. What is a Release?

A **release** means making a feature available to users.

Deployment and release can happen at the same time, but mature companies separate them.

Beginner model:

```text
Deploy = Release
```

Better production model:

```text
Deploy code first
Release feature later
```

Example:

```text
You deploy code for a new payment feature today.
But the feature flag is OFF.
Users cannot see it yet.

Tomorrow, you enable the feature flag for 5% of users.
That is the release.
```

This is powerful because deployment becomes safer.

You can put code in production without immediately exposing it.

---

# Deployment vs Release

| Concept      | Meaning                             | Example                    |
| ------------ | ----------------------------------- | -------------------------- |
| Deployment   | New code/artifact is running        | New Docker image deployed  |
| Release      | Users can access the feature        | Feature flag enabled       |
| Rollback     | Go back to previous working version | Revert to old Docker image |
| Roll forward | Fix the issue with a new version    | Deploy patched version     |

Important:

```text
Deployment is technical.
Release is product/user-facing.
```

---

# 3. What is Rollback?

A **rollback** means returning to a previous known-good version.

Example:

```text
Current version: todo-app:sha-bad123
Previous version: todo-app:sha-good456

Rollback:
todo-app:sha-bad123 → todo-app:sha-good456
```

Rollback is used when the new deployment breaks production.

Example incident:

```text
10:00 AM — Deploy version v2
10:03 AM — Error rate jumps to 45%
10:04 AM — Rollback to v1
10:07 AM — Error rate normal again
```

Correct production behavior:

```text
Rollback first.
Investigate after service is stable.
```

---

# 4. What is Roll Forward?

A **roll forward** means fixing the problem by deploying a newer version instead of going back.

Example:

```text
v1 is running
v2 deployed and has bug
v3 contains hotfix
Deploy v3
```

This is roll forward.

Use roll forward when rollback is difficult or unsafe.

Common reason:

```text
Database migration changed the schema.
Old app version may not work with new schema.
```

Example:

```text
v1 app uses column: username
v2 migration renames it to: user_name

If you rollback app to v1, it may fail because username column no longer exists.
```

In this case, rolling forward with a fix may be safer.

---

# 5. Why Database Changes Are Dangerous

Application rollback is usually easy.

Database rollback is hard.

Bad migration example:

```sql
ALTER TABLE users DROP COLUMN username;
```

If production breaks, rollback is painful because data may be gone.

Safer migration approach:

```text
Step 1: Add new column
Step 2: Write app that supports both old and new columns
Step 3: Backfill data
Step 4: Switch reads to new column
Step 5: Later remove old column
```

This is called **backward-compatible migration**.

Real-world rule:

```text
Never make a database migration that forces instant app rollback failure.
```

---

# 6. Real Deployment Strategies

## Strategy 1 — Recreate Deployment

Stop old version, start new version.

```text
Stop v1
Start v2
```

Simple but causes downtime.

Use for:

```text
Small internal tools
Learning projects
Non-critical apps
```

Avoid for production user-facing systems.

---

## Strategy 2 — Rolling Deployment

Replace instances one by one.

```text
App v1, App v1, App v1
  ↓
App v2, App v1, App v1
  ↓
App v2, App v2, App v1
  ↓
App v2, App v2, App v2
```

Benefits:

```text
No full downtime
Safer than recreate
Default in Kubernetes Deployments
```

Risk:

```text
For some time, v1 and v2 run together.
They must be compatible.
```

---

## Strategy 3 — Blue/Green Deployment

Two environments exist:

```text
Blue  = current production
Green = new version
```

Flow:

```text
Traffic → Blue

Deploy new version to Green
Test Green
Switch traffic from Blue to Green
```

If Green fails:

```text
Switch traffic back to Blue
```

Benefits:

```text
Fast rollback
Very safe
Easy testing before traffic switch
```

Downside:

```text
More infrastructure cost
Need duplicate environment
Database compatibility still matters
```

---

## Strategy 4 — Canary Deployment

Send small traffic to new version first.

```text
95% traffic → v1
5% traffic  → v2
```

If metrics are good:

```text
50% traffic → v2
100% traffic → v2
```

If metrics are bad:

```text
0% traffic → v2
Rollback
```

Canary is advanced and powerful.

Use when:

```text
Large user base
High-risk changes
Need gradual release
Strong monitoring exists
```

Without monitoring, canary is useless.

---

## Strategy 5 — Feature Flag Release

Deploy code with feature OFF.

```text
New code deployed
Feature flag OFF
No user impact
```

Then release gradually:

```text
Enable for internal team
Enable for 5% users
Enable for 25% users
Enable for 100% users
```

If problem happens:

```text
Turn feature flag OFF
```

This can be faster than rollback.

---

# 7. Deployment Pipeline Mental Model

A strong production pipeline looks like this:

```text
Code push
  ↓
CI tests
  ↓
Security scans
  ↓
Docker image build
  ↓
Image scan
  ↓
Push artifact to registry
  ↓
Deploy to dev
  ↓
Deploy to staging
  ↓
Smoke test
  ↓
Manual approval
  ↓
Deploy to production
  ↓
Health check
  ↓
Monitor metrics
  ↓
Rollback automatically if needed
```

The pipeline should answer:

```text
What was deployed?
Who approved it?
When was it deployed?
Which commit created it?
Which tests passed?
How do we rollback?
```

---

# 8. What is a Smoke Test?

A smoke test is a small test after deployment to verify the app is basically alive.

Example:

```bash
curl -f https://api.example.com/health
```

For your Todo app:

```bash
curl -f https://api.yourdatascientist.tech/api/get-todo
```

Smoke test checks:

```text
App starts
Health endpoint responds
Database connection works
Basic API route works
```

It does not test everything.

It asks:

```text
Is this deployment obviously broken?
```

---

# 9. Good Health Check Design

Bad health endpoint:

```js
app.get("/health", (req, res) => {
  res.send("ok");
});
```

This only says the web server is alive.

Better health endpoint:

```text
/health
Checks app process is alive.

/ready
Checks app is ready to receive traffic.
Includes database/cache dependency check.
```

In production:

```text
Liveness = should this process be restarted?
Readiness = should this process receive traffic?
```

This becomes extremely important in Kubernetes.

---

# 10. Real Incident Example

Imagine this:

```text
Version v1 is running fine.
You deploy v2.
Users start getting 500 errors.
Grafana shows error rate rising.
Logs show database query failure.
```

Beginner response:

```text
Open server.
Edit code manually.
Restart app.
Try random fixes.
```

Production response:

```text
1. Stop the bleeding.
2. Rollback to v1.
3. Confirm error rate returns to normal.
4. Announce status.
5. Investigate root cause.
6. Fix properly.
7. Add test to prevent repeat.
8. Deploy v3 later.
```

This is professional incident behavior.

---

# 11. Mini Lab — Write Your Deployment Plan

In `devops-masterclass-notes.md`, add:

```markdown
## Lesson 1.3 — Deployment, Release, Rollback

### Deployment
Deployment means:

### Release
Release means:

### Rollback
Rollback means:

### Roll Forward
Roll forward means:

### My Todo App Deployment Plan

Artifact:
Environment flow:
Health check URL:
Smoke test command:
Rollback strategy:
Production approval:
Monitoring check after deployment:
```

Fill it like this:

```markdown
### My Todo App Deployment Plan

Artifact:
Docker image tagged with Git SHA, for example todo-app:sha-a1b2c3d

Environment flow:
Local → Dev → Staging → Production

Health check URL:
https://api.yourdatascientist.tech/health

Smoke test command:
curl -f https://api.yourdatascientist.tech/health

Rollback strategy:
Deploy previous Docker image tag

Production approval:
Manual approval in Jenkins or GitHub Actions before production deployment

Monitoring check after deployment:
Check error rate, latency, CPU, memory, and application logs
```

---

# 12. Interview Answer

Question:

```text
What is the difference between deployment and release?
```

Strong answer:

```text
Deployment means putting a new version of code or an artifact into an environment. Release means making a feature available to users. In mature systems, these are often separated using feature flags. For example, a team can deploy code to production with a feature disabled, then release it gradually to 5%, 25%, and 100% of users. This reduces risk because if something goes wrong, the feature can be turned off without rolling back the entire deployment.
```

Question:

```text
Production broke after deployment. What do you do?
```

Strong answer:

```text
First, I rollback or disable the feature flag to restore service. I do not debug for a long time while users are impacted. After rollback, I verify recovery using metrics like error rate, latency, and health checks. Then I investigate logs, compare the bad deployment with the previous version, identify root cause, add tests or safeguards, and deploy a fixed version later.
```

---

# Today’s Core Rules

Remember these deeply:

```text
Deployment is not always release.
Rollback first, investigate second.
Build once, promote the same artifact.
Database migrations must be backward-compatible.
Smoke tests protect production.
Feature flags make releases safer.
```

Next lesson:

# Lesson 1.4 — Uptime, SLA, SLO, SLI, Error Budget

This is where we start thinking like an SRE.

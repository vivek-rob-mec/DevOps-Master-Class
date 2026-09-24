# Lesson 1.10 — Module 1 Mini Project: Production-Ready Learning Repository + Architecture Notes

Now we finish **Module 1: Mental Model & Environment Setup** with a mini project.

This is important because masterclass learning should not stay only theoretical. Every module must produce something visible, reusable, and portfolio-friendly.

Your current curriculum already emphasizes project-based outcomes, capstones, environment setup, production thinking, and understanding why tools exist before using them. This mini project follows that same direction. 

---

# Mini Project Goal

By the end of this mini project, you should have a GitHub repository that proves:

```text
You understand production architecture.
You understand environments.
You understand deployment and rollback.
You understand SLA/SLO/SLI basics.
You understand failure thinking.
You can organize a professional DevOps learning repo.
You can use GitHub workflow properly.
```

This becomes the foundation for the rest of the masterclass.

---

# Project Name

Use this repository:

```text
devops-masterclass
```

Inside it, create a Module 1 project folder:

```bash
cd ~/devops-masterclass
mkdir -p 00-notes/module-01-foundation
```

---

# Final Folder Structure for Module 1

Create this:

```bash
mkdir -p 00-notes/module-01-foundation/diagrams
mkdir -p 00-notes/module-01-foundation/runbooks
mkdir -p 00-notes/module-01-foundation/interview-answers
mkdir -p 00-notes/module-01-foundation/labs
```

Expected structure:

```text
00-notes/module-01-foundation/
├── README.md
├── production-request-flow.md
├── environments.md
├── deployment-release-rollback.md
├── sla-slo-sli-error-budget.md
├── production-architecture.md
├── failure-map.md
├── diagrams/
├── runbooks/
│   └── app-down-runbook.md
├── interview-answers/
│   └── module-01-interview-answers.md
└── labs/
    └── environment-checklist.md
```

---

# File 1 — Module README

Create:

```bash
nano 00-notes/module-01-foundation/README.md
```

Add:

```markdown
# Module 1 — Mental Model & Environment Setup

## Goal

This module builds the foundation for the DevOps + DevSecOps + SRE Masterclass.

Before learning tools like Docker, Jenkins, Kubernetes, Terraform, AWS, or ArgoCD, this module explains how production systems actually work.

## Topics Covered

- Production request flow
- Local, Dev, Staging, and Production environments
- Deployment vs Release
- Rollback and Roll Forward
- SLA, SLO, SLI, and Error Budget
- Monolith vs Microservices
- Load Balancer, Database, Cache, Queue, Worker
- Production failure thinking
- GitHub repository setup
- Git workflow basics

## Core Learning Method

Concept → Real-world example → Diagram → Commands → Lab → Break it → Debug it → Secure it → Interview answer → Mini project

## Key Rules

- Production is not a testing environment.
- Build once, promote the same artifact.
- Deployment is not always release.
- Rollback first when users are impacted.
- Database is the source of truth.
- Cache is an optimization.
- Queue is for async work and retries.
- main branch should always be stable.
- Never commit secrets.
```

---

# File 2 — Production Request Flow

Create:

```bash
nano 00-notes/module-01-foundation/production-request-flow.md
```

Add:

````markdown
# Production Request Flow

## What happens when a user opens a website?

Example:

```text
https://yourdatascientist.tech
````

Request flow:

```text
User Browser
  ↓
DNS
  ↓
CDN / CloudFront
  ↓
WAF
  ↓
Load Balancer
  ↓
Reverse Proxy / Ingress
  ↓
Frontend Service
  ↓
Backend API
  ↓
Database / Cache / Queue
  ↓
Response returns to user
```

## Layer Responsibilities

| Layer         | Responsibility                        | Common Failure                |
| ------------- | ------------------------------------- | ----------------------------- |
| Browser       | Sends request and renders response    | JS error, CORS issue          |
| DNS           | Resolves domain to IP or CDN endpoint | Wrong record, TTL cache       |
| CDN           | Caches and serves content globally    | Stale cache, wrong origin     |
| WAF           | Blocks malicious traffic              | False positive blocking users |
| Load Balancer | Distributes traffic                   | No healthy targets            |
| Reverse Proxy | Routes traffic                        | Wrong proxy_pass or route     |
| Frontend      | User interface                        | Wrong API URL                 |
| Backend API   | Business logic                        | Crash, config error           |
| Database      | Persistent data                       | Connection timeout            |
| Cache         | Fast temporary data                   | Stale data or Redis down      |
| Queue         | Async jobs                            | Jobs stuck                    |
| Worker        | Background processing                 | Worker crashed                |

## Core Idea

A production engineer does not guess. A production engineer identifies the failing layer.

````

---

# File 3 — Environments

Create:

```bash
nano 00-notes/module-01-foundation/environments.md
````

Add:

````markdown
# Environments

## Environment Flow

```text
Local → Dev → Staging → Production
````

## Local

Purpose:

* Fast development
* Experiment safely
* Run code on personal machine

Example:

```text
localhost:3000
localhost:3002
local database
```

## Dev

Purpose:

* Shared development testing
* Integration testing
* Team validation

Example:

```text
dev.yourdatascientist.tech
api-dev.yourdatascientist.tech
```

## Staging

Purpose:

* Production-like validation
* Smoke testing
* QA testing
* Security testing
* Deployment rehearsal

Example:

```text
staging.yourdatascientist.tech
api-staging.yourdatascientist.tech
```

## Production

Purpose:

* Real users
* Real data
* Real business impact

Production requires:

* Monitoring
* Alerts
* Backups
* Access control
* Rollback
* Audit logs
* Security

## Golden Rule

Build once, promote the same artifact.

```text
Git commit → Docker image → Dev → Staging → Production
```

````

---

# File 4 — Deployment, Release, Rollback

Create:

```bash
nano 00-notes/module-01-foundation/deployment-release-rollback.md
````

Add:

````markdown
# Deployment, Release, Rollback, and Roll Forward

## Deployment

Deployment means putting a new version of the application into an environment.

Example:

```text
Deploy Docker image todo-app:sha-a1b2c3d to staging.
````

## Release

Release means making a feature available to users.

Deployment and release can be separated using feature flags.

```text
Deploy code with feature flag OFF.
Release feature later by turning flag ON.
```

## Rollback

Rollback means going back to a previous known-good version.

```text
todo-app:sha-bad123 → todo-app:sha-good456
```

## Roll Forward

Roll forward means fixing the issue with a newer version.

```text
v1 → v2 broken → v3 hotfix
```

## Deployment Strategies

| Strategy     | Meaning                                 | Use Case                 |
| ------------ | --------------------------------------- | ------------------------ |
| Recreate     | Stop old, start new                     | Simple/internal apps     |
| Rolling      | Replace instances gradually             | Kubernetes default       |
| Blue/Green   | Switch traffic between two environments | Safer production deploys |
| Canary       | Send small traffic to new version       | High-risk changes        |
| Feature Flag | Deploy code but release separately      | Safer product rollout    |

## Core Rules

* Deployment is technical.
* Release is user-facing.
* Rollback first if users are impacted.
* Database migrations must be backward-compatible.
* Smoke tests protect production.

````

---

# File 5 — SLA, SLO, SLI, Error Budget

Create:

```bash
nano 00-notes/module-01-foundation/sla-slo-sli-error-budget.md
````

Add:

````markdown
# SLA, SLO, SLI, and Error Budget

## Definitions

| Term | Meaning |
|---|---|
| SLI | Actual measurement |
| SLO | Internal reliability target |
| SLA | External customer promise |
| Error Budget | Allowed failure before violating SLO |

## Example

```text
SLI: Current API success rate is 99.94%.
SLO: API success rate should be 99.9% over 30 days.
SLA: Customer contract promises 99.5% uptime.
````

## Availability

| Availability | Allowed Downtime Per Month |
| ------------ | -------------------------: |
| 99%          |        ~7 hours 18 minutes |
| 99.9%        |                ~43 minutes |
| 99.95%       |                ~21 minutes |
| 99.99%       |      ~4 minutes 23 seconds |
| 99.999%      |                ~26 seconds |

## Todo App Example SLOs

1. 99.9% of API requests should not return 5xx over 30 days.
2. 95% of API requests should complete under 500ms.
3. 99.9% of frontend page loads should succeed.

## Four Golden Signals

* Latency
* Traffic
* Errors
* Saturation

## Core Rule

Alert on user impact, not only machine symptoms.

````

---

# File 6 — Production Architecture

Create:

```bash
nano 00-notes/module-01-foundation/production-architecture.md
````

Add:

````markdown
# Production Architecture

## Simple Architecture

```text
User → Frontend → Backend API → Database
````

## Production Architecture

```text
User Browser
   ↓
DNS / Route 53
   ↓
CDN / CloudFront
   ↓
WAF
   ↓
Application Load Balancer
   ↓
Reverse Proxy / Ingress
   ↓
Frontend Service
   ↓
Backend API Service
   ↓
Database / Cache / Queue / Object Storage
   ↓
Observability
```

## Monolith

A monolith is an application deployed as one unit.

Advantages:

* Simple to build
* Simple to deploy
* Easier debugging
* Good for small teams

Disadvantages:

* Harder independent scaling
* One bad module can affect whole app
* Large codebase can become harder to manage

## Microservices

Microservices split the system into independent services.

Advantages:

* Independent scaling
* Team ownership
* Smaller deploy units

Disadvantages:

* Network failures
* Distributed tracing required
* More CI/CD complexity
* More operational complexity

## Cache

Cache is temporary fast storage.

Example:

```text
Backend → Redis → Database
```

Rule:

```text
Database is the source of truth.
Cache is an optimization.
```

## Queue

Queue is used for async work.

Example:

```text
Backend API → Queue → Worker → Email/SMS provider
```

Use queues for:

* Emails
* Reports
* Notifications
* Payment workflows
* Retryable jobs

````

---

# File 7 — Failure Map

Create:

```bash
nano 00-notes/module-01-foundation/failure-map.md
````

Add:

````markdown
# Production Failure Map

## Debugging Method

```text
1. Define the symptom
2. Identify the affected layer
3. Check the fastest evidence
4. Confirm the root cause
5. Restore service
6. Prevent repeat
````

## Failure Layers

| Layer         | What Can Break             | How to Debug                      |
| ------------- | -------------------------- | --------------------------------- |
| Browser       | JS error, CORS issue       | DevTools Console/Network          |
| DNS           | Wrong record, TTL cache    | dig, nslookup                     |
| TLS/SSL       | Expired/wrong certificate  | openssl s_client                  |
| CDN           | Stale cache, wrong origin  | curl -I, CDN logs                 |
| WAF           | False positive block       | WAF logs                          |
| Load Balancer | No healthy targets         | Target group health, curl /health |
| Nginx/Proxy   | Wrong proxy_pass           | nginx -t, logs                    |
| Frontend      | Wrong API URL              | Browser Network tab               |
| Backend       | Crash, missing env         | logs, curl /health, ss -tulnp     |
| Database      | Timeout, wrong credentials | nc, DB client, DB logs            |
| Cache         | Redis down, stale data     | redis-cli ping/info               |
| Queue         | Jobs stuck                 | queue depth, worker logs          |
| External API  | Timeout/rate limit         | provider logs, retries            |

## Recent Change Checklist

* New deployment?
* DNS change?
* Certificate change?
* Terraform apply?
* Database migration?
* Secret rotation?
* WAF/security rule change?
* Traffic spike?

## Core Rule

Do not guess. Isolate the failing layer.

````

---

# File 8 — App Down Runbook

Create:

```bash
nano 00-notes/module-01-foundation/runbooks/app-down-runbook.md
````

Add:

````markdown
# Runbook — App Down

## Symptom

Users report the application is down or not working.

## First Questions

1. Is it down for everyone or one user?
2. When did it start?
3. What changed recently?
4. Is there user impact?
5. Do we need rollback?

## Triage Steps

### 1. Check DNS

```bash
dig yourdatascientist.tech
````

### 2. Check HTTPS

```bash
curl -Iv https://yourdatascientist.tech
```

### 3. Check API Health

```bash
curl -f https://api.yourdatascientist.tech/health
```

### 4. Check Backend Logs

```bash
docker logs backend
```

or:

```bash
journalctl -u myapp -f
```

### 5. Check Listening Ports

```bash
ss -tulnp
```

### 6. Check Database Connectivity

```bash
nc -vz database-host 5432
```

## Rollback Decision

Rollback if:

* Error rate is high
* Users are impacted
* Issue started after deployment
* Root cause is not immediately clear

## After Recovery

* Write timeline
* Identify root cause
* Add prevention
* Update runbook

````

---

# File 9 — Interview Answers

Create:

```bash
nano 00-notes/module-01-foundation/interview-answers/module-01-interview-answers.md
````

Add:

```markdown
# Module 1 Interview Answers

## Q1. What happens when you type a URL in the browser?

First, the browser resolves the domain using DNS. Then it opens a TCP connection and performs a TLS handshake for HTTPS. After that, it sends an HTTP request. The request may pass through a CDN, WAF, load balancer, reverse proxy, frontend service, backend API, cache, and database. The response returns to the browser, which renders the page. In production, every layer should be observable using logs, metrics, and traces.

## Q2. Why do companies use dev, staging, and production environments?

Companies use separate environments to reduce deployment risk. Local is for fast development, dev is for shared integration testing, staging is for production-like validation, and production is for real users. Code should be built once into an immutable artifact and promoted through environments. Only configuration should differ.

## Q3. What is the difference between deployment and release?

Deployment means putting a new version of code or artifact into an environment. Release means making a feature available to users. Mature teams separate them using feature flags so code can be deployed safely before being released gradually.

## Q4. What is the difference between SLA, SLO, and SLI?

SLI is the actual measurement, SLO is the internal target, and SLA is the external customer promise. For example, current API success rate is an SLI, 99.9% success over 30 days is an SLO, and 99.5% uptime promised to customers is an SLA.

## Q5. What is an error budget?

An error budget is the amount of unreliability allowed by the SLO. If the SLO is 99.9%, then 0.1% failure is allowed. If the budget is healthy, the team can ship faster. If it is nearly exhausted, the team should focus on reliability.

## Q6. When would you choose monolith vs microservices?

I would start with a monolith or modular monolith when the team is small and the product is early. It is simpler to build, test, deploy, and debug. I would move to microservices only when there is real pain such as independent scaling needs, large team boundaries, or deployment bottlenecks.

## Q7. A user says the website is down. How do you troubleshoot?

I first define the scope. Then I check from outside in: DNS, TLS, CDN/load balancer response, target health, frontend, API calls, backend logs, database connectivity, and recent changes. I do not randomly restart services. If user impact is high after a deployment, I rollback first and investigate after recovery.
```

---

# File 10 — Environment Checklist

Create:

```bash
nano 00-notes/module-01-foundation/labs/environment-checklist.md
```

Add:

````markdown
# Environment Setup Checklist

## Required Tools

- [ ] WSL2 Ubuntu or Ubuntu VM
- [ ] VS Code with Remote WSL
- [ ] Git
- [ ] SSH key added to GitHub
- [ ] Docker
- [ ] Docker Compose
- [ ] Node.js via nvm
- [ ] Python3 and venv
- [ ] curl
- [ ] jq
- [ ] dig/nslookup
- [ ] htop
- [ ] tree

## Verification Commands

```bash
git --version
docker --version
docker compose version
node -v
npm -v
python3 --version
curl --version
jq --version
dig google.com
````

## Docker Test

```bash
docker run hello-world
```

## GitHub SSH Test

```bash
ssh -T git@github.com
```

## Notes

Work inside Linux filesystem:

```bash
~/devops-masterclass
```

Avoid working inside:

```bash
/mnt/c/Users/...
```

````

---

# Add Everything to Git

Now commit the mini project.

```bash
cd ~/devops-masterclass

git switch main
git pull origin main

git switch -c docs/module-01-mini-project

git status
git add 00-notes/module-01-foundation
git diff --staged

git commit -m "docs: add module 1 foundation mini project"
git push -u origin docs/module-01-mini-project
````

Then open a PR on GitHub.

PR title:

```text
docs: add module 1 foundation mini project
```

PR description:

```markdown
## Summary

Added Module 1 foundation documentation for the DevOps + DevSecOps + SRE Masterclass.

## Included

- Production request flow
- Environment model
- Deployment, release, rollback notes
- SLA/SLO/SLI/error budget notes
- Production architecture notes
- Failure map
- App down runbook
- Interview answers
- Environment setup checklist

## Verification

- Markdown files created
- Repo structure checked
- No secrets committed
```

---

# Module 1 Completion Criteria

You can mark Module 1 complete when you have:

```text
README created
Repo pushed to GitHub
Branch protection enabled
Issue/PR templates added
GitHub Actions validation workflow added
Module 1 notes added
Failure map added
Runbook added
Interview answers added
Environment checklist added
PR merged to main
Release tag created
```

After merge, create tag:

```bash
git switch main
git pull origin main

git tag -a v0.1.0 -m "Complete Module 1 foundation"
git push origin v0.1.0
```

---

# What You Have Learned in Module 1

You now understand:

```text
How production systems work
Why environments exist
What deployment really means
Why release is different from deployment
How rollback and roll forward work
What SLA, SLO, SLI, and error budget mean
How monolith and microservices differ
Why load balancer, cache, queue, and database matter
How to think about failures layer by layer
How to structure a professional GitHub learning repo
How to create notes, runbooks, and interview answers
```

This is a strong foundation.

---

# Final Module 1 Interview Answer

Question:

```text
What did you learn in your first DevOps module?
```

Strong answer:

```text
I learned how production systems work end to end, from browser request to DNS, CDN, WAF, load balancer, frontend, backend, database, cache, queue, and observability. I learned why companies separate local, dev, staging, and production environments, and why artifacts should be built once and promoted through environments. I also learned the difference between deployment and release, how rollback and roll forward work, and how SLOs, SLIs, SLAs, and error budgets guide reliability decisions. Finally, I created a professional GitHub repository with documentation, runbooks, failure maps, and interview answers, which becomes the foundation for the rest of my DevOps masterclass.
```

---

# Module 1 Status

```text
Module 1: Mental Model & Environment Setup
Status: Complete after mini project PR is merged
```

Next module:

# Module 2 — Git, GitHub & Engineering Workflow

This will go deeper into real GitHub team workflow, PR reviews, branch strategies, release management, GitHub Actions basics, and professional collaboration.

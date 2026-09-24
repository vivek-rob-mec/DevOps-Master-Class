Great. We start now.

# Module 1 — Mental Model & Environment Setup

Before Linux, Docker, Jenkins, Kubernetes, Terraform, or AWS, you need one thing:

> A clear mental model of how real production systems work.

Most beginners learn DevOps like this:

```text
Linux commands → Docker → Jenkins → Kubernetes → AWS
```

That is not wrong, but it becomes weak if you do not know **why** each tool exists.

Our masterclass method will be:

```text
Concept → Real-world example → Diagram → Commands → Lab → Break it → Debug it → Secure it → Interview answer → Mini project
```

Your uploaded curriculum already begins with this mindset: first understand how production systems work, then move into tools like Linux, Docker, CI/CD, Kubernetes, Cloud, and SRE. 

---

# Lesson 1.1 — What Actually Happens When a User Opens a Website?

Imagine a user opens:

```text
https://yourdatascientist.tech
```

A beginner thinks:

```text
Browser opens website.
```

A DevOps engineer thinks:

```text
Browser
  ↓
DNS resolution
  ↓
TLS/HTTPS handshake
  ↓
CDN or Load Balancer
  ↓
Reverse proxy
  ↓
Frontend application
  ↓
Backend API
  ↓
Database/cache/object storage
  ↓
Response returns to user
```

This is the first real-world mental model.

---

# The Production Request Flow

```text
User Browser
    ↓
DNS
    ↓
CDN / CloudFront
    ↓
WAF / Security Layer
    ↓
Load Balancer
    ↓
Reverse Proxy / Ingress
    ↓
Frontend Service
    ↓
Backend API Service
    ↓
Database / Redis / S3
    ↓
Logs, Metrics, Traces
```

Now understand each layer.

---

## 1. Browser

The browser sends a request.

Example:

```text
GET / HTTP/1.1
Host: yourdatascientist.tech
```

The browser wants to know:

```text
Where is this domain hosted?
Is the connection secure?
Which server should I talk to?
What content should I display?
```

---

## 2. DNS

DNS converts a human-friendly name into an IP address.

```text
yourdatascientist.tech → 13.32.45.100
```

DNS records can be:

```text
A record      → domain to IPv4
AAAA record   → domain to IPv6
CNAME record  → alias to another domain
MX record     → mail server
TXT record    → verification/security records
```

Real-world example:

```text
yourdatascientist.tech
  ↓ CNAME
d123abc.cloudfront.net
```

This means your domain points to CloudFront.

---

## 3. CDN

A CDN caches content near users.

Example:

```text
User in India
  ↓
CloudFront edge location near India
  ↓
Cached frontend files served quickly
```

CDN is useful for:

```text
Frontend static files
Images
CSS
JavaScript
Downloads
Global low latency
DDoS absorption
```

But CDN can also create problems:

```text
Old cached files
403 errors
Wrong origin
SSL mismatch
Cache invalidation issues
```

---

## 4. WAF

WAF means Web Application Firewall.

It blocks common attacks:

```text
SQL injection
XSS attempts
Bot traffic
Bad IPs
Suspicious request patterns
```

Example:

```text
CloudFront
  ↓
AWS WAF
  ↓
ALB
```

---

## 5. Load Balancer

A load balancer distributes traffic across multiple servers or containers.

```text
Load Balancer
   ↓       ↓       ↓
App-1   App-2   App-3
```

Why it exists:

```text
High availability
Traffic distribution
Health checks
Zero-downtime deployments
SSL termination
```

If App-2 is unhealthy:

```text
Load Balancer stops sending traffic to App-2
```

This is why health checks matter.

---

## 6. Reverse Proxy

A reverse proxy sits in front of your app.

Common tools:

```text
Nginx
Apache
Traefik
Kubernetes Ingress Controller
AWS ALB
```

It handles:

```text
Routing
Compression
SSL
Headers
Rate limiting
Static files
Proxying requests to backend
```

Example:

```text
/api/users  → backend service
/           → frontend service
```

---

## 7. Frontend Application

Frontend could be:

```text
React
Next.js
Angular
Vue
Static HTML/CSS/JS
```

In production, frontend is often served by:

```text
Nginx
S3 + CloudFront
Vercel
Netlify
Kubernetes service
```

Frontend talks to backend APIs:

```text
GET https://api.yourdatascientist.tech/api/todos
```

---

## 8. Backend API

Backend handles business logic.

Examples:

```text
Node.js Express
FastAPI
Django
Spring Boot
Go
Java
```

Backend usually talks to:

```text
Database
Cache
Queue
Object storage
Third-party APIs
```

Example:

```text
POST /api/add-todo
  ↓
Backend validates request
  ↓
Backend writes to database
  ↓
Backend returns success response
```

---

## 9. Database

Database stores persistent data.

Examples:

```text
PostgreSQL
MongoDB
MySQL
DynamoDB
Redis
```

Important DevOps concerns:

```text
Backups
Replication
Encryption
Connection pooling
Monitoring
Slow queries
Storage size
Failover
Migrations
```

A bad deployment can break the app.

A bad database migration can break the business.

That is why DevOps engineers must understand databases at least operationally.

---

## 10. Logs, Metrics, and Traces

A real production system must be observable.

### Logs answer:

```text
What happened?
```

Example:

```text
User login failed because password was wrong.
```

### Metrics answer:

```text
How much? How often? How fast?
```

Example:

```text
CPU usage: 85%
Error rate: 4%
API latency p95: 750ms
```

### Traces answer:

```text
Where did the request spend time?
```

Example:

```text
Frontend → API Gateway → Auth Service → User Service → Database
```

If you cannot observe the system, you cannot operate it.

---

# The Same Request with DevOps Tools

Now map tools to the request flow:

```text
User
 ↓
DNS                    → Route 53 / Cloudflare
 ↓
CDN                    → CloudFront
 ↓
WAF                    → AWS WAF
 ↓
Load Balancer          → ALB / NLB / Nginx
 ↓
Containers             → Docker
 ↓
Orchestration          → Kubernetes / ECS
 ↓
App Deployment         → Jenkins / GitHub Actions / ArgoCD
 ↓
Infrastructure         → Terraform
 ↓
Configuration          → Ansible
 ↓
Secrets                → Vault / AWS Secrets Manager
 ↓
Monitoring             → Prometheus + Grafana
 ↓
Logs                   → Loki / ELK
 ↓
Tracing                → OpenTelemetry + Tempo / Jaeger
 ↓
Incident Response      → SRE process
```

Now the tools have meaning.

You are not learning random tools.

You are learning how to build and operate this flow.

---

# Real Production Failure Examples

## Failure 1 — DNS issue

User says:

```text
Website not opening.
```

Possible reason:

```text
DNS record is wrong.
Domain expired.
TTL still cached old value.
CNAME points to wrong CloudFront distribution.
```

Debug tools:

```bash
dig yourdatascientist.tech
nslookup yourdatascientist.tech
```

---

## Failure 2 — SSL issue

Browser shows:

```text
Your connection is not private
```

Possible reason:

```text
Certificate expired.
Certificate does not include domain.
CloudFront using wrong ACM certificate.
Certificate created in wrong AWS region for CloudFront.
```

Debug tool:

```bash
openssl s_client -connect yourdatascientist.tech:443 -servername yourdatascientist.tech
```

---

## Failure 3 — Load balancer issue

User gets:

```text
502 Bad Gateway
```

Possible reason:

```text
Backend app is down.
Health check is failing.
Wrong target port.
Security group blocking traffic.
App listening on localhost instead of 0.0.0.0.
```

Debug tools:

```bash
curl -v http://backend:3000/health
ss -tulnp
docker ps
docker logs app
```

---

## Failure 4 — Database issue

App logs show:

```text
connection timeout
```

Possible reason:

```text
Database is down.
Security group blocks DB port.
Wrong DB URL.
Connection pool exhausted.
Database CPU is high.
```

Debug tools:

```bash
nc -vz database-host 5432
psql -h database-host -U appuser -d appdb
```

---

## Failure 5 — Deployment issue

After deployment:

```text
Error rate jumps from 0.1% to 40%
```

Correct response:

```text
Rollback first.
Investigate second.
```

Wrong response:

```text
Keep debugging while users suffer.
```

Production mindset:

```text
Restore service first, root cause later.
```

---

# Core DevOps Mental Model

DevOps is not just tools.

DevOps is the discipline of making software delivery:

```text
Fast
Safe
Repeatable
Observable
Secure
Recoverable
Automated
```

Every tool exists for one of these reasons.

| Goal                        | Tool/Practice                |
| --------------------------- | ---------------------------- |
| Repeatable environment      | Docker                       |
| Automated deployment        | Jenkins / GitHub Actions     |
| Scalable app runtime        | Kubernetes                   |
| Reproducible infrastructure | Terraform                    |
| Server configuration        | Ansible                      |
| Monitoring                  | Prometheus                   |
| Dashboards                  | Grafana                      |
| Logs                        | Loki / ELK                   |
| Tracing                     | OpenTelemetry                |
| Secure pipeline             | DevSecOps scans              |
| Safer deployment            | Blue/green, canary, rollback |
| Production reliability      | SRE                          |

---

# Lab 1 — Draw Your First Production Architecture

Before commands, do this.

Draw this architecture in your notebook:

```text
User
 ↓
DNS
 ↓
CloudFront / CDN
 ↓
WAF
 ↓
Load Balancer
 ↓
Frontend
 ↓
Backend API
 ↓
Database
 ↓
Cache
 ↓
Monitoring + Logs
```

Then write beside every box:

```text
What is its job?
What can go wrong here?
How would I debug it?
```

Example:

```text
DNS
Job: Convert domain to IP/server.
Can go wrong: wrong record, expired domain, cached old record.
Debug: dig, nslookup.
```

This one exercise will make your DevOps learning 10x clearer.

---

# Lab 2 — Trace a Real Request Locally

Run these commands on your machine:

```bash
ping google.com
```

Purpose:

```text
Checks if domain resolves and network path works.
```

Then:

```bash
nslookup google.com
```

Purpose:

```text
Shows DNS resolution.
```

Then:

```bash
curl -I https://google.com
```

Purpose:

```text
Fetches only HTTP headers.
```

Then:

```bash
curl -v https://google.com
```

Purpose:

```text
Shows DNS, TCP, TLS, and HTTP details.
```

Do not memorize the output yet. Just observe.

---

# Mini Interview Answer

Question:

```text
What happens when you type a URL in the browser and press Enter?
```

Strong answer:

```text
First, the browser checks cache and resolves the domain using DNS. DNS returns the IP address or CDN endpoint. Then the browser opens a TCP connection and performs a TLS handshake for HTTPS. After that, it sends an HTTP request. The request may pass through a CDN, WAF, load balancer, reverse proxy, frontend service, backend API, cache, and database. The server returns a response, and the browser renders the page. In production, every layer must be observable with logs, metrics, and traces so failures can be diagnosed quickly.
```

This answer is already better than most beginner answers.

---

# Your Homework Before Next Lesson

Create a file called:

```text
devops-masterclass-notes.md
```

Add this:

```markdown
# DevOps Masterclass Notes

## Module 1 — Mental Model & Environment Setup

### What happens when a user opens a website?

User → DNS → CDN/WAF → Load Balancer → Reverse Proxy → Frontend → Backend → Database/Cache → Response

### What DevOps is really about

DevOps makes software delivery fast, safe, repeatable, observable, secure, recoverable, and automated.

### My current understanding

Write your own explanation here.
```

Then also draw the architecture on paper or in Excalidraw/draw.io.

When you are ready, we continue to:

# Lesson 1.2 — Environments: Local, Dev, Staging, Production

That lesson will explain why companies do not deploy directly to production and how real release flow works.

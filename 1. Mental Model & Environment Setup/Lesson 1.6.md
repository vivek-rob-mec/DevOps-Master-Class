# Lesson 1.6 — Real Production Failure Thinking: What Can Break at Every Layer?

This is one of the most important lessons in the whole masterclass.

A normal beginner asks:

```text
How do I deploy the app?
```

A production engineer asks:

```text
What can break?
How will I detect it?
How will I recover?
How will I prevent it next time?
```

Your curriculum already emphasizes this mindset: understand what each layer does, what breaks when misconfigured, and how to troubleshoot instead of memorizing random commands. 

---

# 1. Production Systems Fail in Layers

A user says:

```text
Website is not working.
```

That sentence is not enough.

The failure could be anywhere:

```text
User Browser
  ↓
DNS
  ↓
CDN
  ↓
WAF
  ↓
Load Balancer
  ↓
Reverse Proxy / Ingress
  ↓
Frontend
  ↓
Backend API
  ↓
Database
  ↓
Cache
  ↓
Queue
  ↓
Worker
  ↓
External Service
```

Your job is not to guess.

Your job is to isolate the failing layer.

---

# 2. The Production Debugging Method

Use this method every time:

```text
1. Define the symptom
2. Identify the affected layer
3. Check the fastest evidence
4. Confirm the root cause
5. Restore service
6. Prevent repeat
```

Never start with random fixes.

Bad:

```text
Restart everything.
Clear cache.
Rebuild container.
Change security group.
Try random Stack Overflow command.
```

Good:

```text
What exactly is failing?
Which users are affected?
When did it start?
What changed recently?
Which layer shows the first error?
Can we rollback?
```

---

# 3. Layer 1 — User / Browser Failure

Symptoms:

```text
Page not loading
White screen
JavaScript error
CORS error
Mixed content error
Login not working
```

Possible causes:

```text
Broken frontend build
Wrong API URL
Browser cache serving old files
CORS misconfiguration
HTTPS frontend calling HTTP backend
Expired session/cookie issue
```

Debug:

```text
Open browser DevTools
Check Console tab
Check Network tab
Check HTTP status codes
Check failed API request
Check response body
```

Example issue:

```text
Frontend deployed with wrong backend URL:
REACT_APP_API_URL=http://localhost:3002
```

In production, browser tries to call localhost, which means the user’s own machine, not your server.

Correct production config:

```text
REACT_APP_API_URL=https://api.yourdatascientist.tech
```

---

# 4. Layer 2 — DNS Failure

Symptoms:

```text
Domain does not resolve
Website works for some users but not others
New domain config not active yet
Browser says server IP address could not be found
```

Possible causes:

```text
Wrong A record
Wrong CNAME record
Domain expired
Nameserver mismatch
DNS propagation delay
TTL cache still holding old value
```

Debug commands:

```bash
dig yourdatascientist.tech

nslookup yourdatascientist.tech

dig CNAME www.yourdatascientist.tech
```

What to check:

```text
Does domain resolve?
Does it point to the expected CloudFront/ALB?
Are nameservers correct?
Was DNS recently changed?
What is the TTL?
```

Common mistake:

```text
Changing DNS and expecting it to update instantly everywhere.
```

DNS is cached.

---

# 5. Layer 3 — TLS / SSL Failure

Symptoms:

```text
Your connection is not private
SSL certificate expired
Certificate name mismatch
HTTPS not working
CloudFront custom domain not working
```

Possible causes:

```text
Expired certificate
Wrong certificate attached
Certificate does not include domain
CloudFront certificate not in us-east-1
Intermediate certificate issue
HTTP-to-HTTPS redirect misconfigured
```

Debug:

```bash
openssl s_client -connect yourdatascientist.tech:443 -servername yourdatascientist.tech
```

Check:

```text
Certificate subject
Certificate expiry date
Issuer
SAN names
TLS handshake success/failure
```

Common AWS mistake:

```text
Creating ACM certificate in ap-south-1 for CloudFront.
```

For CloudFront, ACM certificate must be in:

```text
us-east-1
```

---

# 6. Layer 4 — CDN Failure

Symptoms:

```text
403 Forbidden
Old frontend still showing
New deployment not visible
Some files return 404
CSS/JS broken
```

Possible causes:

```text
CloudFront origin misconfigured
S3 bucket policy wrong
Cache serving old files
Default root object missing
Origin path wrong
Invalid SSL between CDN and origin
```

Debug:

```bash
curl -I https://yourdatascientist.tech
curl -I https://yourdatascientist.tech/index.html
```

Check headers:

```text
x-cache
via
server
status code
cache-control
```

Common issue:

```text
You deployed new frontend files, but CloudFront still serves cached old files.
```

Fix:

```text
Create CloudFront invalidation
Use versioned asset filenames
Set correct cache-control headers
```

---

# 7. Layer 5 — WAF / Security Layer Failure

Symptoms:

```text
403 Forbidden
Only some requests blocked
API works locally but fails through CDN/WAF
Login blocked
File upload blocked
```

Possible causes:

```text
WAF rule blocking request
Rate limit triggered
SQL injection rule false positive
Blocked IP/country
Request body too large
Missing required header
```

Debug:

```text
Check WAF logs
Check blocked rule ID
Compare working request vs blocked request
Check source IP
Check request path and body
```

Important mindset:

```text
Security tools can also break legitimate traffic.
```

So when you add WAF, always monitor false positives.

---

# 8. Layer 6 — Load Balancer Failure

Symptoms:

```text
502 Bad Gateway
503 Service Unavailable
504 Gateway Timeout
Target unhealthy
App works directly but not through load balancer
```

Possible causes:

```text
Wrong target port
Health check path wrong
Security group blocking traffic
App listening on localhost instead of 0.0.0.0
Backend container crashed
Timeout too low
No healthy targets
```

Debug:

```bash
curl -v http://app-server-ip:3002/health
ss -tulnp
docker ps
docker logs backend
```

For AWS ALB, check:

```text
Target group health
Health check path
Health check port
Security group inbound/outbound rules
Listener rules
Target port
```

Classic mistake:

```text
App listens on 127.0.0.1 inside server.
```

Better:

```text
App listens on 0.0.0.0
```

Because load balancer needs to reach it from outside the process.

---

# 9. Layer 7 — Reverse Proxy / Nginx Failure

Symptoms:

```text
502 Bad Gateway
404 from Nginx
Static files not found
API route not forwarded
Large upload fails
```

Possible causes:

```text
Wrong proxy_pass
Backend service down
Wrong root directory
Missing try_files for React SPA
Body size limit too small
Timeout too low
Header forwarding missing
```

Debug:

```bash
sudo nginx -t

sudo systemctl status nginx

sudo journalctl -u nginx -f

tail -f /var/log/nginx/error.log
```

Common React/Nginx issue:

```text
Directly opening /dashboard gives 404.
```

Why?

Nginx looks for `/dashboard` file, but React routing is client-side.

Fix:

```nginx
try_files $uri /index.html;
```

---

# 10. Layer 8 — Frontend App Failure

Symptoms:

```text
Blank screen
Broken UI
API calls failing
Static files 404
Wrong environment config
```

Possible causes:

```text
Build failed
Wrong API base URL
Missing environment variable
Old cached JS file
CORS issue
Frontend and backend version mismatch
```

Debug:

```text
Browser Console
Browser Network tab
Check build output
Check environment variables
Check deployed static files
```

For frontend, the most important debugging place is often:

```text
Browser DevTools → Network tab
```

---

# 11. Layer 9 — Backend API Failure

Symptoms:

```text
500 Internal Server Error
API timeout
Connection refused
App crashes after startup
Health endpoint fails
```

Possible causes:

```text
Missing environment variable
Wrong database URL
Port conflict
Unhandled exception
Memory leak
Dependency unavailable
Bad deployment
Invalid config
```

Debug:

```bash
curl -v http://localhost:3002/health

docker logs backend

pm2 logs

journalctl -u myapp -f

ss -tulnp
```

Check:

```text
Is process running?
Is app listening on expected port?
Can it connect to database?
Did it crash?
What changed in last deployment?
```

---

# 12. Layer 10 — Database Failure

Symptoms:

```text
API returns 500
Login slow
Save operation fails
Connection timeout
Too many connections
Queries slow
```

Possible causes:

```text
Wrong credentials
DB down
Security group blocking DB port
Connection pool exhausted
Storage full
CPU high
Slow query
Migration broke schema
Backup/maintenance running
```

Debug examples:

For PostgreSQL:

```bash
nc -vz db-host 5432

psql -h db-host -U appuser -d appdb
```

For MongoDB:

```bash
mongosh "mongodb://host:27017/dbname"
```

Check:

```text
Can backend reach DB?
Are credentials correct?
Is DB accepting connections?
Is storage full?
Did migration run?
Are indexes missing?
```

Important rule:

```text
If the database is down, the app may be running but the service is still down.
```

---

# 13. Layer 11 — Cache Failure

Symptoms:

```text
App slow
Stale data shown
High DB load
Redis connection error
Login/session issues
```

Possible causes:

```text
Redis down
Wrong Redis URL
Cache TTL too long
Cache not invalidated
Redis memory full
Cache stampede
```

Debug:

```bash
redis-cli -h redis-host ping

redis-cli info memory

redis-cli keys '*'
```

Be careful with this in production:

```bash
redis-cli keys '*'
```

On large Redis instances, `KEYS *` can be dangerous because it scans everything and can block Redis.

Better:

```bash
redis-cli scan 0
```

Core rule:

```text
Cache failure should not destroy the source of truth.
```

Database remains the source of truth.

---

# 14. Layer 12 — Queue / Worker Failure

Symptoms:

```text
Emails not sent
Reports not generated
Jobs stuck
Notifications delayed
Queue length increasing
```

Possible causes:

```text
Worker not running
Queue connection broken
Job handler crashing
External provider down
Retry policy wrong
Dead-letter queue filling
```

Debug:

```text
Check queue depth
Check worker logs
Check failed jobs
Check retry count
Check dead-letter queue
Check external API status
```

Important metric:

```text
Queue depth
```

If queue depth keeps increasing, workers are not keeping up.

---

# 15. Layer 13 — External Service Failure

Symptoms:

```text
Payment failed
Email not sent
SMS delayed
Login through OAuth broken
File upload failing
```

Possible causes:

```text
Third-party API outage
API key expired
Rate limit exceeded
Network issue
Webhook secret changed
Provider changed API behavior
```

Production design:

```text
Use retries with backoff
Use circuit breaker
Use queue for async work
Set timeouts
Log provider response
Do not let one external service crash the whole app
```

Bad:

```text
Payment provider slow → entire API hangs forever.
```

Good:

```text
Set timeout.
Return clear error.
Retry safely if operation is idempotent.
Alert team.
```

---

# 16. The “What Changed?” Rule

When production breaks, always ask:

```text
What changed recently?
```

Changes may include:

```text
New deployment
New environment variable
DNS change
Certificate change
Database migration
Terraform apply
Security group update
WAF rule update
Dependency upgrade
Secret rotation
Cloud provider outage
Traffic spike
```

Most incidents are caused by change.

Not always, but often.

So during incident response, check:

```text
Recent deploys
Recent infrastructure changes
Recent config changes
Recent secret rotations
Recent traffic changes
```

---

# 17. Fast Triage Checklist

When someone says “app is down”, check in this order:

```text
1. Is it down for everyone or only one user?
2. Does DNS resolve?
3. Does HTTPS work?
4. Does CDN/load balancer return response?
5. Are targets healthy?
6. Is frontend loading?
7. Are API calls working?
8. Is backend process running?
9. Can backend reach database?
10. Are logs showing errors?
11. Did anything change recently?
12. Should we rollback?
```

This is how you avoid guessing.

---

# 18. Example Incident Walkthrough

Symptom:

```text
Users report Todo app is not saving tasks.
```

Do not say:

```text
MongoDB problem.
```

Investigate.

Step 1: Browser network tab

```text
POST /api/add-todo returns 500
```

Step 2: Backend logs

```text
MongoServerSelectionError: connection timeout
```

Step 3: Check DB connectivity

```bash
nc -vz mongodb-host 27017
```

Fails.

Step 4: Check recent changes

```text
Security group changed 10 minutes ago.
MongoDB port 27017 no longer allowed from backend.
```

Root cause:

```text
Security group blocked backend → database traffic.
```

Immediate fix:

```text
Restore correct security group rule.
```

Prevent repeat:

```text
Terraform-managed security group
CI check for required ports
Monitoring alert for DB connectivity
Runbook updated
```

This is production thinking.

---

# 19. Mini Lab — Failure Map for Your Todo App

Add this to your notes:

```markdown
## Lesson 1.6 — Production Failure Thinking

### Failure Map

Browser:
What can break:
How to debug:

DNS:
What can break:
How to debug:

TLS/SSL:
What can break:
How to debug:

CDN/WAF:
What can break:
How to debug:

Load Balancer:
What can break:
How to debug:

Frontend:
What can break:
How to debug:

Backend:
What can break:
How to debug:

Database:
What can break:
How to debug:

Cache:
What can break:
How to debug:

Queue/Worker:
What can break:
How to debug:

### Recent Change Checklist

Recent deployment:
Recent config change:
Recent DNS change:
Recent Terraform change:
Recent database migration:
Recent secret rotation:
Recent traffic spike:
```

Fill at least three layers for your Todo app.

Example:

```markdown
Backend:
What can break:
Missing env variables, app crash, wrong port, DB connection failure.

How to debug:
Check docker logs, curl /health, check ss -tulnp, verify DATABASE_URL.

Database:
What can break:
Wrong credentials, DB down, port blocked, storage full.

How to debug:
Use nc to test port, connect with client, check DB logs, check security group.

Load Balancer:
What can break:
Wrong health check path, unhealthy targets, wrong target port.

How to debug:
Check target group health, curl backend /health, check security groups.
```

---

# 20. Interview Answer

Question:

```text
A user says the website is down. How do you troubleshoot?
```

Strong answer:

```text
I first define the scope: whether it affects one user, one region, or everyone. Then I check from the outside in: DNS resolution, TLS, CDN or load balancer response, target health, frontend loading, API calls, backend logs, database connectivity, and recent changes. I do not randomly restart services. I look for the first failing layer, confirm with evidence, restore service quickly, and then document the root cause and prevention steps. If the issue started after a deployment and user impact is high, I rollback first and investigate after recovery.
```

---

# Today’s Core Rules

```text
Do not guess. Isolate the failing layer.
Always ask: what changed recently?
User impact matters more than machine status.
Rollback first when a bad deployment hurts users.
Logs tell what happened.
Metrics tell how much.
Traces tell where time was spent.
A running server does not mean a working service.
```

Next lesson:

# Lesson 1.7 — Environment Setup for the Masterclass: WSL/Ubuntu, Git, Docker, VS Code, SSH, Cloud Accounts

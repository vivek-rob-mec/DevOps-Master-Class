# Module 5 — Application Runtime and Production App Basics

# Lesson 5.1 — How Applications Actually Run in Production

You have completed Linux, Bash, networking, and Python automation.

Now we move to a very important DevOps topic:

```text
Application runtime
```

This means:

```text
How an application starts
How it listens on a port
How users reach it
How it reads config
How it logs
How it is monitored
How it is restarted
How it is deployed
How it is rolled back
```

DevOps engineers must understand this deeply because CI/CD, Docker, Kubernetes, Nginx, PM2, systemd, and cloud deployments all depend on runtime fundamentals.

---

# 1. What Is an Application Runtime?

An application runtime is the environment and process model that allows your application to execute.

Example:

```text
Node.js app
  runs using node
  listens on port 3000
  reads environment variables
  writes logs
  connects to MongoDB
```

Example:

```text
Python FastAPI app
  runs using uvicorn/gunicorn
  listens on port 8000
  reads environment variables
  writes logs
  connects to PostgreSQL
```

Example:

```text
React/Next.js frontend
  built into static or server-rendered assets
  served by Nginx, Node.js, or CDN
```

DevOps question:

```text
Can I start it, stop it, configure it, expose it, monitor it, and recover it?
```

---

# 2. Development Runtime vs Production Runtime

Development runtime is for coding.

Production runtime is for users.

## Development Runtime

```text
hot reload
debug logs
local database
manual start
developer user
.env files
localhost only
fast feedback
```

Example:

```bash
npm run dev
```

or:

```bash
uvicorn app.main:app --reload
```

## Production Runtime

```text
stable process manager
controlled environment variables
limited permissions
structured logs
health checks
reverse proxy
restart policy
monitoring
rollback strategy
security hardening
```

Example:

```bash
pm2 start ecosystem.config.js
```

or:

```bash
sudo systemctl start demo-api
```

or:

```bash
docker run ...
```

or:

```bash
kubectl apply -f deployment.yaml
```

Core rule:

```text
Never confuse “it runs locally” with “it is production-ready.”
```

---

# 3. The Production Request Flow

A typical production web app request flow:

```text
User Browser
  ↓
DNS
  ↓
Load Balancer / CDN
  ↓
Reverse Proxy
  ↓
Application Process
  ↓
Database / Cache / External APIs
```

Example:

```text
yourdatascientist.tech
  ↓
CloudFront
  ↓
ALB
  ↓
Nginx
  ↓
Node.js app on port 3000
  ↓
MongoDB
```

For your Todo/DevOps background:

```text
Browser
  ↓
Frontend
  ↓
Backend API
  ↓
MongoDB
```

The backend app itself usually does not directly listen on port 443.

Usually:

```text
Nginx/ALB/CloudFront handles public HTTP/HTTPS
App listens on internal port like 3000, 3002, or 8000
```

---

# 4. Process, Port, and Protocol

Every web app runtime needs these basics:

```text
process
port
protocol
```

## Process

A process is the running instance of the application.

Check processes:

```bash
ps aux | grep node
ps aux | grep python
```

Better:

```bash
pgrep -a node
pgrep -a python
```

## Port

A port is where the app listens.

Examples:

```text
Node backend: 3000 / 3001 / 3002
FastAPI: 8000
Nginx: 80 / 443
MongoDB: 27017
PostgreSQL: 5432
Redis: 6379
```

Check listening ports:

```bash
ss -tuln
```

With process info:

```bash
sudo ss -tulnp
```

Find who is using port 3002:

```bash
sudo ss -tulnp | grep ':3002'
```

or:

```bash
sudo lsof -i :3002
```

## Protocol

Common protocols:

```text
HTTP
HTTPS
TCP
WebSocket
gRPC
```

Most web apps use HTTP internally and HTTPS externally.

---

# 5. Build a Demo Runtime App

We will create a small production-style Node.js app.

Directory:

```bash
cd ~/devops-masterclass
mkdir -p 05-application-runtime/demo-node-api
cd 05-application-runtime/demo-node-api
```

Create package:

```bash
npm init -y
```

Install dependencies:

```bash
npm install express
```

Create app:

```bash
nano server.js
```

Paste:

```javascript
const express = require("express");

const app = express();

const APP_NAME = process.env.APP_NAME || "demo-node-api";
const APP_ENV = process.env.APP_ENV || "dev";
const PORT = Number(process.env.PORT || 3000);
const STARTED_AT = new Date().toISOString();

app.get("/", (req, res) => {
  res.json({
    app: APP_NAME,
    environment: APP_ENV,
    message: "Hello from demo-node-api",
  });
});

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "ok",
    app: APP_NAME,
    environment: APP_ENV,
    uptime_seconds: Math.floor(process.uptime()),
    started_at: STARTED_AT,
  });
});

app.get("/ready", (req, res) => {
  res.status(200).json({
    status: "ready",
    app: APP_NAME,
  });
});

app.get("/version", (req, res) => {
  res.json({
    app: APP_NAME,
    version: process.env.APP_VERSION || "0.1.0",
    commit_sha: process.env.COMMIT_SHA || "unknown",
  });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(
    JSON.stringify({
      level: "info",
      message: "server_started",
      app: APP_NAME,
      environment: APP_ENV,
      port: PORT,
      started_at: STARTED_AT,
    })
  );
});
```

Update package script:

```bash
npm pkg set scripts.start="node server.js"
npm pkg set scripts.dev="APP_ENV=dev PORT=3000 node server.js"
```

Run:

```bash
npm run dev
```

In another terminal:

```bash
curl http://127.0.0.1:3000/
curl http://127.0.0.1:3000/health
curl http://127.0.0.1:3000/ready
curl http://127.0.0.1:3000/version
```

Stop with:

```text
Ctrl + C
```

---

# 6. Important Production Endpoints

A production app should usually expose:

```text
/health
/ready
/version
/metrics
```

## `/health`

Answers:

```text
Is the process alive?
```

Example:

```json
{
  "status": "ok"
}
```

Used by:

```text
load balancers
Kubernetes liveness probes
monitoring tools
deployment validation
```

## `/ready`

Answers:

```text
Is the app ready to receive traffic?
```

It may check:

```text
database connection
cache connection
required config loaded
migrations complete
```

Used by:

```text
Kubernetes readiness probes
load balancer registration
deployment rollout
```

## `/version`

Answers:

```text
What version is running?
```

Useful during deployment and rollback.

Example:

```json
{
  "version": "0.1.0",
  "commit_sha": "abc123"
}
```

## `/metrics`

Used by Prometheus later.

Example:

```text
http_requests_total
process_cpu_seconds_total
app_errors_total
```

We will cover this deeply in the observability module.

---

# 7. Health vs Readiness

This is very important.

```text
Health means the process is alive.
Readiness means the app can safely receive traffic.
```

Example:

```text
App process is running
but database is unavailable
```

Then:

```text
/health = ok
/ready = failed
```

Why?

Because the process itself is alive, but it should not receive production traffic.

In Kubernetes:

```text
livenessProbe  -> restart container if dead
readinessProbe -> remove from traffic if not ready
```

Core rule:

```text
Do not make liveness too strict.
Readiness can be stricter than health.
```

---

# 8. Runtime Configuration with Environment Variables

Production apps should not hardcode runtime values.

Bad:

```javascript
const PORT = 3000;
const DB_URL = "mongodb://localhost:27017/todo";
```

Good:

```javascript
const PORT = process.env.PORT || 3000;
const DB_URL = process.env.DATABASE_URL;
```

Run app with environment variables:

```bash
APP_NAME=demo-node-api \
APP_ENV=prod \
APP_VERSION=0.1.0 \
COMMIT_SHA=abc123 \
PORT=3000 \
npm start
```

Check:

```bash
curl http://127.0.0.1:3000/version
```

Expected:

```json
{
  "app": "demo-node-api",
  "version": "0.1.0",
  "commit_sha": "abc123"
}
```

Core rule:

```text
Build once, configure per environment.
```

That means the same artifact should run in:

```text
dev
staging
prod
```

with different config.

---

# 9. The Twelve-Factor App Runtime Idea

For DevOps, the most important runtime ideas are:

```text
Store config in environment variables
Treat logs as event streams
Run as stateless processes
Expose services through ports
Separate build and run stages
Scale by process count
```

Practical meaning:

```text
Do not hardcode config.
Do not write important state to local disk.
Do not require manual terminal sessions.
Do not depend on developer machine behavior.
```

---

# 10. Foreground vs Background Process

When you run:

```bash
npm start
```

the app runs in the foreground.

If terminal closes, app stops.

Production needs a process manager:

```text
systemd
PM2
supervisor
Docker restart policy
Kubernetes Deployment
```

Bad production practice:

```bash
node server.js &
```

Why bad?

```text
no proper restart policy
logs may be lost
harder to manage
not integrated with boot
not clean for deployment
```

Better:

```bash
pm2 start server.js
```

or:

```bash
sudo systemctl start demo-node-api
```

We will do both in later lessons.

---

# 11. Basic Runtime Debugging Commands

## Check process

```bash
pgrep -a node
```

## Check port

```bash
ss -tuln | grep ':3000'
```

## Check HTTP

```bash
curl -i http://127.0.0.1:3000/health
```

## Check logs

If running in terminal, logs are visible there.

Later with systemd:

```bash
journalctl -u demo-node-api -f
```

Later with PM2:

```bash
pm2 logs demo-node-api
```

## Check environment of a running process

Find PID:

```bash
pgrep -f "node server.js"
```

Then:

```bash
tr '\0' '\n' < /proc/<PID>/environ
```

Example:

```bash
PID=$(pgrep -f "node server.js" | head -n 1)
tr '\0' '\n' < /proc/$PID/environ | sort
```

Be careful:

```text
This may show secrets.
Do not paste production env output publicly.
```

---

# 12. Common Runtime Failure Scenarios

## Failure 1 — Port already in use

Start app twice on same port.

Terminal 1:

```bash
PORT=3000 npm start
```

Terminal 2:

```bash
PORT=3000 npm start
```

You may see:

```text
EADDRINUSE: address already in use 0.0.0.0:3000
```

Debug:

```bash
sudo ss -tulnp | grep ':3000'
```

Fix:

```text
stop old process
or use different port
or configure process manager correctly
```

## Failure 2 — App only listens on localhost

If app listens on:

```text
127.0.0.1
```

then only local machine can reach it.

If app listens on:

```text
0.0.0.0
```

then it accepts connections on all interfaces.

In containers/cloud deployments, apps usually need:

```javascript
app.listen(PORT, "0.0.0.0")
```

Core rule:

```text
Inside Docker/Kubernetes, listen on 0.0.0.0, not only 127.0.0.1.
```

## Failure 3 — Missing environment variable

Example:

```text
DATABASE_URL is required
```

Good apps fail fast with clear errors.

Bad apps start and fail later.

## Failure 4 — Health endpoint missing

Deployment pipeline cannot validate service.

Fix:

```text
add /health
add /ready
add /version
```

## Failure 5 — Logs are not useful

Bad:

```text
error happened
```

Good:

```json
{
  "level": "error",
  "message": "database_connection_failed",
  "service": "demo-node-api",
  "environment": "prod"
}
```

---

# 13. Add Runtime Notes

Create:

```bash
cd ~/devops-masterclass/05-application-runtime
nano runtime-basics.md
```

Paste:

````markdown
# Application Runtime Basics

## Runtime Questions

A DevOps engineer should know:

- How does the app start?
- Which process runs it?
- Which port does it listen on?
- Which protocol does it use?
- How is it configured?
- Where do logs go?
- How is health checked?
- How is it restarted?
- How is it stopped?
- How is it deployed?
- How is it rolled back?

## Development vs Production

Development:

- hot reload
- local debugging
- manual process
- local .env
- developer user

Production:

- process manager
- restart policy
- reverse proxy
- health checks
- controlled config
- structured logs
- least privilege user
- monitoring
- rollback

## Important Endpoints

| Endpoint | Purpose |
|---|---|
| `/health` | process alive |
| `/ready` | ready for traffic |
| `/version` | running version |
| `/metrics` | metrics for monitoring |

## Runtime Debug Commands

```bash
pgrep -a node
ss -tuln
sudo ss -tulnp
curl -i http://127.0.0.1:3000/health
journalctl -u service-name -f
````

## Core Rules

* Build once, configure per environment.
* Do not hardcode runtime config.
* Use health/readiness/version endpoints.
* Listen on `0.0.0.0` in containers/cloud.
* Use a process manager in production.
* Generate useful logs.
* Do not expose secrets in logs.

````

---

# 14. Add README for Module 5

Create:

```bash
cd ~/devops-masterclass/05-application-runtime
nano README.md
````

Paste:

````markdown
# Module 5 — Application Runtime and Production App Basics

This module covers how applications run in production.

## Topics

- process lifecycle
- ports and protocols
- environment variables
- health/readiness/version endpoints
- logs
- reverse proxies
- PM2
- systemd
- production users
- deployment layout
- graceful shutdown
- zero-downtime basics
- runtime troubleshooting

## Demo App

```bash
cd demo-node-api
npm install
npm run dev
````

Check:

```bash
curl http://127.0.0.1:3000/health
curl http://127.0.0.1:3000/ready
curl http://127.0.0.1:3000/version
```

````

---

# 15. Validate Lesson Work

From:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api
````

Run:

```bash
npm install
APP_NAME=demo-node-api APP_ENV=dev APP_VERSION=0.1.0 COMMIT_SHA=local PORT=3000 npm start
```

In another terminal:

```bash
curl -s http://127.0.0.1:3000/ | jq .
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/ready | jq .
curl -s http://127.0.0.1:3000/version | jq .
```

Check process:

```bash
pgrep -a node
```

Check port:

```bash
ss -tuln | grep ':3000'
```

Stop app:

```text
Ctrl + C
```

---

# 16. Commit Work

From repo root:

```bash
cd ~/devops-masterclass

git status
git add 05-application-runtime
git commit -m "feat: start application runtime module"
git push
```

---

# 17. Interview Explanation

Question:

```text
What is application runtime in DevOps?
```

Strong answer:

```text
Application runtime means the way an application actually runs in an environment. It includes the process, port, protocol, configuration, environment variables, logs, health checks, readiness checks, process manager, restart policy, and deployment layout. As a DevOps engineer, I need to know how to start, stop, expose, monitor, troubleshoot, and recover the application in production.
```

Question:

```text
What is the difference between development runtime and production runtime?
```

Strong answer:

```text
Development runtime is optimized for developer speed with hot reload, local config, debug logs, and manual execution. Production runtime is optimized for stability and reliability. It uses a process manager, controlled configuration, health checks, structured logs, restart policies, reverse proxies, monitoring, and rollback strategy.
```

Question:

```text
Why do applications need health and readiness endpoints?
```

Strong answer:

```text
Health endpoints show whether the process is alive. Readiness endpoints show whether the app is ready to receive traffic, including dependencies like database or cache. Load balancers, Kubernetes, CI/CD pipelines, and monitoring systems use these endpoints to decide whether to route traffic, restart the app, or fail a deployment.
```

Question:

```text
Why should apps use environment variables?
```

Strong answer:

```text
Environment variables allow the same build artifact to run in different environments with different configuration. This supports the build-once-configure-per-environment model and avoids hardcoding secrets, ports, URLs, or environment-specific values into source code.
```

---

# Today’s Core Rules

```text
Understand process, port, and protocol.
Development runtime is not production runtime.
Use environment variables for runtime config.
Expose /health, /ready, and /version endpoints.
Use 0.0.0.0 for container/cloud app listeners.
Use a process manager in production.
Do not run production apps manually in terminals.
Check processes with pgrep/ps.
Check ports with ss/lsof.
Check HTTP with curl.
Do not log secrets.
Build once, configure per environment.
```

Next lesson:

# Lesson 5.2 — Environment Variables, Config Files, Secrets, and Runtime Safety for Production Apps.

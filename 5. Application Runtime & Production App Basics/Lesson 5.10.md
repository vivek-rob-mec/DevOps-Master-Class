# Lesson 5.10 — Production Runtime Capstone

# Node App + Config + Logs + PM2/systemd + Nginx + Atomic Deployment + Auto-Rollback

This is the final capstone for Module 5.

You have already learned:

```text
how apps run as processes
ports and protocols
runtime config
secrets safety
structured JSON logs
PM2
systemd
Nginx reverse proxy
HTTPS/TLS with Certbot
release directories
current symlink
atomic deployment
auto-rollback
graceful shutdown
readiness
```

Now we combine everything into one production runtime capstone.

---

# 1. Capstone Goal

By the end, your runtime architecture will look like this:

```text
User / curl / Browser
  ↓
Nginx :80 / :443
  ↓
127.0.0.1:3000
  ↓
systemd service: demo-node-api
  ↓
/opt/demo-node-api/current
  ↓
/opt/demo-node-api/releases/<release-id>
```

Deployment flow:

```text
source code
  ↓
advanced deploy script
  ↓
new release directory
  ↓
RELEASE.json
  ↓
current symlink switch
  ↓
systemd restart
  ↓
/ready validation
  ↓
auto-rollback if failed
  ↓
deployment report
```

---

# 2. Final Runtime Checklist

Your production-style app should have:

```text
/health
/ready
/version
/release
/config-summary
structured JSON logs
request IDs
safe config validation
graceful shutdown
startup readiness delay support
systemd service
Nginx reverse proxy
release directory layout
auto-rollback deployment
deployment reports
```

This is a strong DevOps portfolio/runtime project.

---

# 3. Confirm Final App Structure

Go to the app:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Expected structure:

```text
demo-node-api/
├── server.js
├── package.json
├── package-lock.json
├── .env.example
├── .gitignore
├── ecosystem.config.example.js
├── src/
│   ├── config.js
│   └── logger.js
└── scripts/
    ├── runtime-config-lab.sh
    ├── log-summary.sh
    ├── deploy-release.sh
    ├── rollback-release.sh
    ├── cleanup-releases.sh
    ├── deploy-advanced.sh
    ├── graceful-shutdown-lab.sh
    └── force-kill-lab.sh
```

Check:

```bash
tree -a -I 'node_modules|.env|*.log'
```

---

# 4. Final `server.js` Checklist

Your `server.js` should include these capabilities:

```text
load config safely
create logger
trust proxy
request ID middleware
health endpoint
ready endpoint
version endpoint
release endpoint
config summary endpoint
slow endpoint
simulate warning endpoint
simulate error endpoint
graceful shutdown
uncaught exception handling
unhandled rejection handling
```

Important lines that must exist:

```javascript
app.set("trust proxy", true);
```

```javascript
process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
```

```javascript
server.close(() => {
  logger.info("shutdown_complete");
  process.exit(0);
});
```

```javascript
app.get("/ready", (req, res) => {
```

```javascript
app.get("/release", (req, res) => {
```

Check quickly:

```bash
grep -n 'trust proxy\|SIGTERM\|/ready\|/release\|shutdown_complete' server.js
```

---

# 5. Final `src/config.js` Checklist

Your config should validate:

```text
APP_ENV
PORT
LOG_LEVEL
DATABASE_URL
CORS_ORIGIN
ENABLE_CACHE
REQUEST_TIMEOUT_MS
STARTUP_DELAY_MS
```

Check:

```bash
grep -n 'APP_ENV\|PORT\|LOG_LEVEL\|DATABASE_URL\|STARTUP_DELAY_MS' src/config.js
```

Run config lab:

```bash
./scripts/runtime-config-lab.sh
```

Expected:

```text
invalid APP_ENV fails
invalid PORT fails
invalid boolean fails
```

---

# 6. Final `src/logger.js` Checklist

Your logger should output JSON fields like:

```text
timestamp
level
message
service
environment
version
commit_sha
request_id
status_code
duration_ms
```

Check:

```bash
cat src/logger.js
```

Run app and test logs:

```bash
APP_ENV=dev PORT=3000 LOG_LEVEL=info LOAD_DOTENV=false npm start
```

In another terminal:

```bash
curl -s -H "x-request-id: capstone-test-1" http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/simulate-warning | jq .
curl -i http://127.0.0.1:3000/simulate-error
```

Stop with:

```text
Ctrl + C
```

---

# 7. Create Final Runtime Environment File

Create or verify:

```bash
sudo mkdir -p /etc/demo-node-api
sudo nano /etc/demo-node-api/demo-node-api.env
```

Use:

```bash
APP_NAME=demo-node-api
APP_ENV=prod
APP_VERSION=0.1.0
COMMIT_SHA=runtime-capstone
PORT=3000
LOG_LEVEL=info
LOAD_DOTENV=false
DATABASE_URL=mongodb://localhost:27017/demo
CORS_ORIGIN=https://example.com
ENABLE_CACHE=true
REQUEST_TIMEOUT_MS=5000
STARTUP_DELAY_MS=0
```

Set permissions:

```bash
sudo chown root:demoapp /etc/demo-node-api/demo-node-api.env
sudo chmod 640 /etc/demo-node-api/demo-node-api.env
ls -l /etc/demo-node-api/demo-node-api.env
```

Expected:

```text
-rw-r----- root demoapp
```

---

# 8. Confirm systemd Service

Open:

```bash
sudo nano /etc/systemd/system/demo-node-api.service
```

Final service should look like:

```ini
[Unit]
Description=Demo Node API
After=network.target

[Service]
Type=simple
User=demoapp
Group=demoapp
WorkingDirectory=/opt/demo-node-api/current
EnvironmentFile=/etc/demo-node-api/demo-node-api.env
ExecStart=/usr/bin/node /opt/demo-node-api/current/server.js
Restart=always
RestartSec=5
KillSignal=SIGTERM
TimeoutStopSec=15
StandardOutput=journal
StandardError=journal

NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

Check Node path:

```bash
which node
```

If needed, replace `/usr/bin/node` with the actual path.

Reload:

```bash
sudo systemctl daemon-reload
sudo systemctl enable demo-node-api
```

---

# 9. Run Final Advanced Deployment

Deploy from source into `/opt/demo-node-api/releases/...`:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api

HEALTH_URL=http://127.0.0.1:3000/ready \
SERVICE_NAME=demo-node-api \
VERSION=0.1.0 \
COMMIT_SHA=runtime-capstone \
AUTO_ROLLBACK=true \
KEEP_RELEASES=5 \
./scripts/deploy-advanced.sh
```

Validate:

```bash
sudo systemctl status demo-node-api --no-pager
readlink -f /opt/demo-node-api/current

curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/ready | jq .
curl -s http://127.0.0.1:3000/version | jq .
curl -s http://127.0.0.1:3000/release | jq .
curl -s http://127.0.0.1:3000/config-summary | jq .
```

Check deployment report:

```bash
ls -lh /opt/demo-node-api/shared/reports
cat /opt/demo-node-api/shared/reports/deploy-*runtime-capstone*.json | jq .
```

---

# 10. Confirm Nginx Reverse Proxy

Check Nginx config:

```bash
sudo nginx -t
sudo systemctl status nginx --no-pager
```

Test through Nginx:

```bash
curl -i http://127.0.0.1/nginx-health
curl -s http://127.0.0.1/health | jq .
curl -s http://127.0.0.1/ready | jq .
curl -s http://127.0.0.1/version | jq .
curl -s http://127.0.0.1/release | jq .
```

Check headers:

```bash
curl -I http://127.0.0.1/health
```

Expected security headers:

```text
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
Referrer-Policy: strict-origin-when-cross-origin
```

Check Nginx logs:

```bash
sudo tail -n 20 /var/log/nginx/demo-node-api-access.log
sudo tail -n 20 /var/log/nginx/demo-node-api-error.log
```

Check app logs:

```bash
journalctl -u demo-node-api -n 50 --no-pager
```

---

# 11. HTTPS Validation

For local WSL/VM without a real domain, only HTTP validation is expected.

For a real server with domain:

```bash
DOMAIN=app.example.com

dig "$DOMAIN"
curl -I "http://$DOMAIN"
sudo certbot --nginx -d "$DOMAIN"

curl -I "https://$DOMAIN"
curl -I "http://$DOMAIN"
curl -s "https://$DOMAIN/health" | jq .
sudo certbot renew --dry-run
```

Production rule:

```text
Do not mark HTTPS complete until certificate renewal dry-run succeeds.
```

---

# 12. Capstone Failure Test — Auto-Rollback

Now test the most important production behavior: rollback.

Create broken source:

```bash
cd ~/devops-masterclass/05-application-runtime

rm -rf /tmp/demo-node-api-capstone-broken
cp -a demo-node-api /tmp/demo-node-api-capstone-broken

cat > /tmp/demo-node-api-capstone-broken/server.js <<'EOF'
throw new Error("runtime capstone broken release");
EOF
```

Deploy broken source:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api

SOURCE_DIR=/tmp/demo-node-api-capstone-broken \
HEALTH_URL=http://127.0.0.1:3000/ready \
SERVICE_NAME=demo-node-api \
VERSION=0.1.1 \
COMMIT_SHA=runtime-capstone-broken \
AUTO_ROLLBACK=true \
./scripts/deploy-advanced.sh || true
```

Validate rollback:

```bash
readlink -f /opt/demo-node-api/current
curl -s http://127.0.0.1:3000/release | jq .
curl -s http://127.0.0.1:3000/health | jq .
sudo systemctl status demo-node-api --no-pager
```

Check failed deployment report:

```bash
cat /opt/demo-node-api/shared/reports/deploy-*runtime-capstone-broken*.json | jq .
```

Expected:

```json
{
  "status": "failed",
  "rollback_status": "succeeded"
}
```

This proves your deployment system can recover from a bad release.

---

# 13. Capstone Failure Test — Port Conflict

Port conflicts are common.

Check current listener:

```bash
sudo ss -tulnp | grep ':3000'
```

If PM2 is accidentally running the same app:

```bash
pm2 list
pm2 stop demo-node-api
pm2 delete demo-node-api
```

Then restart systemd:

```bash
sudo systemctl restart demo-node-api
```

Validate:

```bash
curl -s http://127.0.0.1:3000/health | jq .
```

Core rule:

```text
Do not run the same app under PM2 and systemd on the same port.
```

---

# 14. Capstone Failure Test — Readiness Delay

Test startup delay and deployment retry behavior.

Update env temporarily:

```bash
sudo cp /etc/demo-node-api/demo-node-api.env /etc/demo-node-api/demo-node-api.env.bak

sudo sed -i 's/^STARTUP_DELAY_MS=.*/STARTUP_DELAY_MS=10000/' /etc/demo-node-api/demo-node-api.env
```

Deploy:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api

HEALTH_URL=http://127.0.0.1:3000/ready \
SERVICE_NAME=demo-node-api \
VERSION=0.1.2 \
COMMIT_SHA=runtime-capstone-delay \
AUTO_ROLLBACK=true \
./scripts/deploy-advanced.sh
```

Because the script retries health checks, it should pass after readiness becomes OK.

Restore env:

```bash
sudo mv /etc/demo-node-api/demo-node-api.env.bak /etc/demo-node-api/demo-node-api.env
sudo systemctl restart demo-node-api
```

---

# 15. Final Operations Commands

These are the commands you should remember.

## App status

```bash
sudo systemctl status demo-node-api --no-pager
journalctl -u demo-node-api -f
```

## Nginx status

```bash
sudo nginx -t
sudo systemctl status nginx --no-pager
sudo tail -f /var/log/nginx/demo-node-api-access.log
sudo tail -f /var/log/nginx/demo-node-api-error.log
```

## Runtime validation

```bash
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/ready | jq .
curl -s http://127.0.0.1:3000/release | jq .

curl -s http://127.0.0.1/health | jq .
curl -s http://127.0.0.1/ready | jq .
curl -s http://127.0.0.1/release | jq .
```

## Deployment

```bash
HEALTH_URL=http://127.0.0.1:3000/ready \
SERVICE_NAME=demo-node-api \
VERSION=0.1.0 \
COMMIT_SHA=<commit-sha> \
AUTO_ROLLBACK=true \
./scripts/deploy-advanced.sh
```

## Manual rollback

```bash
ls -1 /opt/demo-node-api/releases

sudo ln -sfn /opt/demo-node-api/releases/<previous-release> /opt/demo-node-api/current
sudo chown -h demoapp:demoapp /opt/demo-node-api/current
sudo systemctl restart demo-node-api
curl -fsS http://127.0.0.1:3000/ready
```

## Deployment reports

```bash
ls -lh /opt/demo-node-api/shared/reports
cat /opt/demo-node-api/shared/reports/deploy-*.json | jq .
```

---

# 16. Add Capstone Notes

Create:

```bash
cd ~/devops-masterclass/05-application-runtime
nano production-runtime-capstone.md
```

Paste:

````markdown
# Production Runtime Capstone

## Architecture

```text
User
  ↓
Nginx :80/:443
  ↓
127.0.0.1:3000
  ↓
systemd service
  ↓
/opt/demo-node-api/current
  ↓
/opt/demo-node-api/releases/<release-id>
````

## App Features

* runtime config validation
* safe config summary
* structured JSON logs
* request IDs
* `/health`
* `/ready`
* `/version`
* `/release`
* graceful shutdown
* startup readiness delay simulation

## Runtime Features

* systemd process manager
* protected environment file
* Nginx reverse proxy
* optional HTTPS with Certbot
* release directory layout
* current symlink
* advanced deployment script
* auto-rollback
* deployment reports

## Main Deployment Command

```bash
HEALTH_URL=http://127.0.0.1:3000/ready \
SERVICE_NAME=demo-node-api \
VERSION=0.1.0 \
COMMIT_SHA=abc123 \
AUTO_ROLLBACK=true \
./scripts/deploy-advanced.sh
```

## Validate

```bash
curl -s http://127.0.0.1/health | jq .
curl -s http://127.0.0.1/ready | jq .
curl -s http://127.0.0.1/release | jq .
journalctl -u demo-node-api -n 100 --no-pager
sudo tail -n 50 /var/log/nginx/demo-node-api-access.log
```

## Core Rules

* do not run production apps manually
* use a process manager
* keep app behind Nginx
* validate config at startup
* never expose secrets
* log structured JSON
* use request IDs
* use release directories
* switch current symlink atomically
* validate readiness after deployment
* rollback automatically on failed health
* archive deployment reports

````

---

# 17. Add Final Runbook

Create:

```bash
nano production-runtime-runbook.md
````

Paste:

````markdown
# Production Runtime Runbook

## 1. Check Service

```bash
sudo systemctl status demo-node-api --no-pager
journalctl -u demo-node-api -n 100 --no-pager
````

## 2. Check Nginx

```bash
sudo nginx -t
sudo systemctl status nginx --no-pager
curl -i http://127.0.0.1/nginx-health
```

## 3. Check App Directly

```bash
curl -i http://127.0.0.1:3000/health
curl -i http://127.0.0.1:3000/ready
curl -i http://127.0.0.1:3000/release
```

## 4. Check Through Nginx

```bash
curl -i http://127.0.0.1/health
curl -i http://127.0.0.1/ready
curl -i http://127.0.0.1/release
```

## 5. Check Current Release

```bash
readlink -f /opt/demo-node-api/current
cat /opt/demo-node-api/current/RELEASE.json | jq .
```

## 6. Check Deployment Reports

```bash
ls -lh /opt/demo-node-api/shared/reports
cat /opt/demo-node-api/shared/reports/deploy-*.json | jq .
```

## 7. Manual Rollback

```bash
ls -1 /opt/demo-node-api/releases

sudo ln -sfn /opt/demo-node-api/releases/<previous-release> /opt/demo-node-api/current
sudo chown -h demoapp:demoapp /opt/demo-node-api/current
sudo systemctl restart demo-node-api
curl -fsS http://127.0.0.1:3000/ready
```

## 8. Common Issues

### 502 from Nginx

```bash
curl -i http://127.0.0.1:3000/health
sudo ss -tulnp | grep ':3000'
sudo tail -n 100 /var/log/nginx/demo-node-api-error.log
journalctl -u demo-node-api -n 100 --no-pager
```

### Service Failed

```bash
sudo systemctl status demo-node-api --no-pager
journalctl -u demo-node-api -n 100 --no-pager
```

### Port Conflict

```bash
sudo ss -tulnp | grep ':3000'
pm2 list
```

### Bad Config

```bash
sudo cat /etc/demo-node-api/demo-node-api.env
journalctl -u demo-node-api -n 100 --no-pager
```

Do not paste secrets publicly.

````

---

# 18. Add Final Architecture Diagram

Create:

```bash
nano production-runtime-architecture.md
````

Paste:

````markdown
# Production Runtime Architecture

```text
+-------------------+
| User / Browser    |
+---------+---------+
          |
          | HTTP/HTTPS
          v
+---------+---------+
| Nginx :80/:443    |
| reverse proxy     |
+---------+---------+
          |
          | HTTP localhost
          v
+---------+---------+
| Node.js App :3000 |
| systemd managed   |
+---------+---------+
          |
          v
+-------------------------------+
| /opt/demo-node-api/current    |
| symlink to active release     |
+---------------+---------------+
                |
                v
+-------------------------------+
| /opt/demo-node-api/releases/  |
| immutable release folders     |
+-------------------------------+

Deployment:
source -> release dir -> current symlink -> restart -> readiness -> report
````

````

---

# 19. Update Module 5 README

Open:

```bash
nano README.md
````

Add:

````markdown
## Production Runtime Capstone

The capstone combines:

- Node.js runtime app
- environment config validation
- secrets safety
- structured JSON logs
- graceful shutdown
- PM2/systemd process management
- Nginx reverse proxy
- HTTPS/TLS with Certbot
- release directory layout
- atomic deployment
- auto-rollback
- deployment reports

Main deployment command:

```bash
cd demo-node-api

HEALTH_URL=http://127.0.0.1:3000/ready \
SERVICE_NAME=demo-node-api \
VERSION=0.1.0 \
COMMIT_SHA=abc123 \
AUTO_ROLLBACK=true \
./scripts/deploy-advanced.sh
````

Validation:

```bash
curl -s http://127.0.0.1/health | jq .
curl -s http://127.0.0.1/ready | jq .
curl -s http://127.0.0.1/release | jq .
```

````

---

# 20. Final Validation Checklist

Run these commands and verify success.

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api
npm install
````

Config lab:

```bash
./scripts/runtime-config-lab.sh
```

Graceful shutdown lab:

```bash
./scripts/graceful-shutdown-lab.sh
```

Deploy:

```bash
HEALTH_URL=http://127.0.0.1:3000/ready \
SERVICE_NAME=demo-node-api \
VERSION=0.1.0 \
COMMIT_SHA=module5-final \
AUTO_ROLLBACK=true \
./scripts/deploy-advanced.sh
```

Direct app:

```bash
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/ready | jq .
curl -s http://127.0.0.1:3000/release | jq .
```

Through Nginx:

```bash
curl -s http://127.0.0.1/health | jq .
curl -s http://127.0.0.1/ready | jq .
curl -s http://127.0.0.1/release | jq .
```

Logs:

```bash
journalctl -u demo-node-api -n 50 --no-pager
sudo tail -n 20 /var/log/nginx/demo-node-api-access.log
```

Report:

```bash
cat /opt/demo-node-api/shared/reports/deploy-*module5-final*.json | jq .
```

Broken rollback test:

```bash
cd ~/devops-masterclass/05-application-runtime

rm -rf /tmp/demo-node-api-final-broken
cp -a demo-node-api /tmp/demo-node-api-final-broken
echo 'throw new Error("final broken release");' > /tmp/demo-node-api-final-broken/server.js

cd demo-node-api

SOURCE_DIR=/tmp/demo-node-api-final-broken \
HEALTH_URL=http://127.0.0.1:3000/ready \
SERVICE_NAME=demo-node-api \
VERSION=0.1.1 \
COMMIT_SHA=module5-final-broken \
AUTO_ROLLBACK=true \
./scripts/deploy-advanced.sh || true
```

Validate rollback:

```bash
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/release | jq .
cat /opt/demo-node-api/shared/reports/deploy-*module5-final-broken*.json | jq .
```

---

# 21. Commit Module 5 Capstone

From repo root:

```bash
cd ~/devops-masterclass

git status
git add 05-application-runtime
git commit -m "feat: complete production runtime capstone"
git push
```

Tag Module 5:

```bash
git tag -a v0.5.0 -m "Complete Module 5 application runtime and production basics"
git push origin v0.5.0
```

---

# 22. Module 5 Completion Summary

You completed:

```text
Lesson 5.1  How applications run in production
Lesson 5.2  Runtime config, env vars, and secrets safety
Lesson 5.3  Logs, stdout/stderr, JSON logging, request IDs
Lesson 5.4  PM2 and systemd process managers
Lesson 5.5  Nginx reverse proxy
Lesson 5.6  HTTPS, TLS, Certbot, domain setup
Lesson 5.7  Deployment layout, releases, symlinks, rollback
Lesson 5.8  Advanced deployment with auto-rollback
Lesson 5.9  Graceful shutdown, signals, readiness, zero-downtime basics
Lesson 5.10 Production runtime capstone
```

You now understand the practical runtime layer between code and containers/Kubernetes.

That is very important.

Docker and Kubernetes will make much more sense now because you understand:

```text
processes
ports
env vars
logs
health checks
readiness
reverse proxy
restart policy
deployment layout
rollback
```

---

# 23. Portfolio Explanation

Use this in your resume/project explanation:

```text
Built a production-style Node.js runtime environment with environment-based configuration validation, structured JSON logging, request IDs, health/readiness/version/release endpoints, graceful shutdown, PM2/systemd process management, Nginx reverse proxy, HTTPS/TLS setup with Certbot, release-directory deployment layout, atomic current symlink switching, readiness-based deployment validation, auto-rollback, and deployment reports.
```

Shorter version:

```text
Implemented production runtime patterns for a Node.js app, including systemd, Nginx, runtime config, structured logs, health/readiness endpoints, atomic deployments, and auto-rollback.
```

---

# 24. Interview Questions

## What is a production runtime?

Strong answer:

```text
A production runtime is the complete environment and lifecycle for running an application in production. It includes the process manager, configuration, environment variables, ports, logs, health checks, reverse proxy, restart policy, deployment layout, graceful shutdown, and rollback strategy.
```

## Why use Nginx in front of Node.js?

Strong answer:

```text
Nginx provides a stable public entrypoint on ports 80 and 443, handles reverse proxying, TLS termination, headers, logs, compression, timeouts, request limits, and security headers. The Node.js app can run internally on a non-public port like 3000.
```

## How do you make deployment safer?

Strong answer:

```text
I use release directories and a current symlink. A new release is prepared in its own directory, validated, then current is switched atomically. After restart, readiness checks verify the deployment. If validation fails, the script rolls back by repointing current to the previous release and restarting the service.
```

## Why is readiness different from health?

Strong answer:

```text
Health checks whether the process is alive. Readiness checks whether the app is ready to receive traffic. During startup, dependency failure, or shutdown, an app may be healthy but not ready. Deployment and load balancers should use readiness for traffic decisions.
```

## What is graceful shutdown?

Strong answer:

```text
Graceful shutdown means handling SIGTERM by marking the app not ready, stopping new requests, allowing active requests to finish, closing resources, and exiting cleanly before the process manager force-kills it.
```

---

# 25. Module 5 Final Rules

```text
Do not run production apps manually in terminals.
Use systemd, PM2, Docker, or Kubernetes.
Separate code from runtime config.
Never commit real secrets.
Validate config at startup.
Use structured JSON logs.
Use request IDs.
Expose /health, /ready, /version, and safe /release.
Put Nginx in front of app ports.
Use HTTPS for public apps.
Use release directories.
Use current symlink for active release.
Validate readiness after deployment.
Rollback automatically on failed health.
Handle SIGTERM gracefully.
Archive deployment reports.
```

---

# Module 5 is complete.

Next module:

# Module 6 — Docker and Container Fundamentals

In Module 6, we will cover:

```text
what containers actually are
image vs container
Dockerfile basics
build context
layers and cache
.dockerignore
ports and volumes
environment variables
container logs
health checks
Docker networking
Docker Compose
multi-stage builds
Node.js Dockerfile
Python/FastAPI Dockerfile
image tagging
security basics
local registry basics
production container patterns
Docker capstone
```

Start with:

```text
start Module 6
```

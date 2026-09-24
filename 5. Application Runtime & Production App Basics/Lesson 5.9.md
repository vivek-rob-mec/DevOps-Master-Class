# Lesson 5.9 — Graceful Shutdown, Signals, Draining, Timeouts, and Zero-Downtime Deployment Basics

In Lesson 5.8, we built an advanced deployment script with:

```text
preflight
release directory
current symlink
health check
auto-rollback
deployment report
```

Now we learn what happens when an app is restarted.

A production restart should not abruptly kill active requests.

This lesson covers:

```text
Linux signals
SIGTERM vs SIGKILL
graceful shutdown
connection draining
restart timeouts
PM2/systemd shutdown behavior
zero-downtime deployment basics
```

---

# 1. The Problem with Bad Restarts

Bad restart behavior:

```text
deployment starts
old app is killed instantly
active user request fails
new app starts slowly
Nginx returns 502 for a few seconds
users see errors
```

This can happen when:

```text
process is killed with kill -9
app does not handle SIGTERM
process manager timeout is too short
health check starts too early
reverse proxy sends traffic before app is ready
```

Good restart behavior:

```text
new deployment prepared
old app receives SIGTERM
old app stops accepting new connections
active requests finish
process exits cleanly
new app starts
health check passes
traffic continues
```

Core rule:

```text
A production app should shut down gracefully.
```

---

# 2. Linux Signals

A signal is a message sent to a process.

Common signals:

```text
SIGTERM  polite request to terminate
SIGINT   interrupt, usually Ctrl+C
SIGKILL  force kill, cannot be handled
SIGHUP   reload/reopen config in some apps
```

Check process:

```bash
pgrep -a node
```

Send SIGTERM:

```bash
kill -TERM <PID>
```

Send SIGINT:

```bash
kill -INT <PID>
```

Send SIGKILL:

```bash
kill -9 <PID>
```

Important:

```text
SIGTERM can be handled.
SIGKILL cannot be handled.
```

Production process managers usually send SIGTERM first. If the app does not exit in time, they send SIGKILL.

---

# 3. What Graceful Shutdown Means

Graceful shutdown means:

```text
receive termination signal
stop accepting new requests
finish existing requests
close server
close database/cache connections
flush logs/metrics if needed
exit with code 0
```

Bad app:

```text
SIGTERM received
process exits instantly
active requests are dropped
```

Good app:

```text
SIGTERM received
server.close()
existing requests finish
then process exits
```

Your app already has a shutdown function from earlier lessons. Now we improve and test it.

---

# 4. Current Shutdown Code

Your `server.js` already has this pattern:

```javascript
function shutdown(signal) {
  logger.info("shutdown_started", {
    signal,
  });

  server.close(() => {
    logger.info("shutdown_complete");
    process.exit(0);
  });

  setTimeout(() => {
    logger.error("shutdown_forced");
    process.exit(1);
  }, 10000).unref();
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
```

This is good.

But to properly test graceful shutdown, we need a slow endpoint.

---

# 5. Add Slow Request Endpoint

Go to app:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Open:

```bash
nano server.js
```

Add this route before the error handlers:

```javascript
app.get("/slow", async (req, res) => {
  const delayMs = Number(req.query.delay_ms || 5000);

  logger.info("slow_request_started", {
    request_id: req.requestId,
    delay_ms: delayMs,
  });

  await new Promise((resolve) => setTimeout(resolve, delayMs));

  logger.info("slow_request_completed", {
    request_id: req.requestId,
    delay_ms: delayMs,
  });

  res.json({
    status: "completed",
    delay_ms: delayMs,
  });
});
```

Now your app can simulate a long-running request.

---

# 6. Test Graceful Shutdown Manually

Start app directly:

```bash
APP_ENV=dev PORT=3000 LOG_LEVEL=info LOAD_DOTENV=false npm start
```

In another terminal, start a slow request:

```bash
curl -i "http://127.0.0.1:3000/slow?delay_ms=8000"
```

While that request is running, in a third terminal:

```bash
PID=$(pgrep -f "node server.js" | head -n 1)
kill -TERM "$PID"
```

Expected behavior:

```text
app logs shutdown_started
slow request continues
slow request completes
app logs shutdown_complete
process exits
```

This proves graceful shutdown works.

---

# 7. Compare with SIGKILL

Start app again:

```bash
APP_ENV=dev PORT=3000 LOG_LEVEL=info LOAD_DOTENV=false npm start
```

Start slow request:

```bash
curl -i "http://127.0.0.1:3000/slow?delay_ms=8000"
```

Kill forcefully:

```bash
PID=$(pgrep -f "node server.js" | head -n 1)
kill -9 "$PID"
```

Expected:

```text
slow request fails
no shutdown_complete log
process is killed immediately
```

This is why `kill -9` should not be the normal deployment method.

Core rule:

```text
Use SIGTERM for normal shutdown. Use SIGKILL only as last resort.
```

---

# 8. systemd Shutdown Behavior

In your systemd unit, you configured:

```ini
KillSignal=SIGTERM
TimeoutStopSec=15
Restart=always
```

Meaning:

```text
systemd sends SIGTERM
waits up to 15 seconds
if app does not stop, systemd force kills it
```

Your app forced shutdown timeout is:

```javascript
setTimeout(..., 10000)
```

That means:

```text
app gives itself 10 seconds
systemd gives app 15 seconds
```

Good.

Core rule:

```text
App graceful timeout should be lower than process manager kill timeout.
```

Example:

```text
app timeout: 10s
systemd TimeoutStopSec: 15s
Nginx proxy_read_timeout: 30s
```

This gives each layer enough time.

---

# 9. PM2 Shutdown Behavior

In PM2 ecosystem config, you set:

```javascript
kill_timeout: 10000
```

PM2 sends stop signal, then waits before force killing.

For graceful shutdown, keep:

```text
app shutdown timeout <= PM2 kill_timeout
```

Better:

```javascript
kill_timeout: 15000
```

If your app needs 10 seconds to shutdown, PM2 should wait at least 15 seconds.

Update `ecosystem.config.example.js`:

```bash
nano ecosystem.config.example.js
```

Change:

```javascript
kill_timeout: 10000,
```

to:

```javascript
kill_timeout: 15000,
```

---

# 10. Add Readiness During Shutdown

When an app is shutting down, it should not be considered ready.

Add a global flag.

Open:

```bash
nano server.js
```

After:

```javascript
const STARTED_AT = new Date().toISOString();
```

Add:

```javascript
let isShuttingDown = false;
```

Update `/ready` route.

Find:

```javascript
app.get("/ready", (req, res) => {
```

At the beginning of the route, add:

```javascript
  if (isShuttingDown) {
    return res.status(503).json({
      status: "not_ready",
      reason: "server is shutting down",
    });
  }
```

So `/ready` becomes:

```javascript
app.get("/ready", (req, res) => {
  if (isShuttingDown) {
    return res.status(503).json({
      status: "not_ready",
      reason: "server is shutting down",
    });
  }

  const databaseRequired = config.appEnv === "prod";
  const databaseReady = !databaseRequired || Boolean(config.databaseUrl);

  if (!databaseReady) {
    logger.warn("readiness_failed", {
      reason: "DATABASE_URL is required in prod",
    });

    return res.status(503).json({
      status: "not_ready",
      reason: "DATABASE_URL is required in prod",
    });
  }

  return res.status(200).json({
    status: "ready",
    app: config.appName,
    database_configured: Boolean(config.databaseUrl),
  });
});
```

Update shutdown function:

```javascript
function shutdown(signal) {
  isShuttingDown = true;

  logger.info("shutdown_started", {
    signal,
  });

  server.close(() => {
    logger.info("shutdown_complete");
    process.exit(0);
  });

  setTimeout(() => {
    logger.error("shutdown_forced");
    process.exit(1);
  }, 10000).unref();
}
```

Now during shutdown, readiness becomes false.

This matters deeply in Kubernetes and load balancers.

---

# 11. Draining Concept

Draining means:

```text
stop sending new traffic to this instance
allow old requests to finish
then stop the instance
```

In a single VM with Nginx and one app process, draining is limited.

In a multi-instance setup:

```text
Load Balancer
  ↓
App instance 1
App instance 2
App instance 3
```

Deployment can do:

```text
remove instance 1 from traffic
wait for active requests to finish
restart instance 1
check readiness
add instance 1 back
repeat for instance 2 and 3
```

This is rolling deployment.

---

# 12. Zero-Downtime Deployment Basics

Zero downtime means users should not see errors during deployment.

Common patterns:

```text
rolling deployment
blue-green deployment
canary deployment
PM2 cluster reload
Kubernetes rolling update
load balancer draining
```

For one VM and one process, true zero downtime is hard because when the single process restarts, there may be a small gap.

To get closer, you need:

```text
multiple app instances
reverse proxy/load balancer
health/readiness checks
graceful shutdown
connection draining
```

---

# 13. PM2 Reload for Zero-Downtime Node Apps

PM2 supports reload in cluster mode.

In fork mode:

```bash
pm2 restart demo-node-api
```

This restarts the process.

In cluster mode:

```javascript
instances: 2,
exec_mode: "cluster"
```

Then:

```bash
pm2 reload demo-node-api
```

PM2 reloads workers one by one.

This can reduce downtime.

But cluster mode requires care:

```text
app must be stateless
sessions should not be stored in memory
background jobs should not run in every worker unless intended
ports are shared by PM2 master
```

For learning, we keep fork mode first.

---

# 14. systemd and Zero Downtime

Plain systemd with one service process usually restarts the process.

That can cause a small gap.

To achieve zero downtime with systemd, you usually need:

```text
two services on different ports
Nginx upstream switching
blue-green deployments
load balancer with multiple instances
socket activation for some app types
```

Example:

```text
demo-node-api-blue  -> port 3001
demo-node-api-green -> port 3002
Nginx routes to active upstream
```

Then deployment switches Nginx upstream from blue to green.

We will keep full blue-green deployment for a later advanced module.

---

# 15. Timeout Layering

Timeouts must be aligned.

Example stack:

```text
Client timeout: 60s
Nginx proxy_read_timeout: 30s
App graceful shutdown: 10s
systemd TimeoutStopSec: 15s
Health check retry window: 20s
```

Bad:

```text
app needs 20s to shutdown
systemd kills after 5s
```

Bad:

```text
Nginx waits 3s
app slow request needs 8s
```

Good:

```text
process manager timeout > app graceful timeout
proxy timeout > expected request time
health retry window > app startup time
```

Core rule:

```text
Timeouts should be intentionally designed, not random.
```

---

# 16. Add Startup Delay Simulation

Sometimes apps take time to become ready.

Add config:

Open `src/config.js`:

```bash
nano src/config.js
```

In returned config object, add:

```javascript
startupDelayMs: numberFromEnv("STARTUP_DELAY_MS", 0, {
  min: 0,
  max: 60000,
}),
```

Full section:

```javascript
return {
  appName: optionalString("APP_NAME", "demo-node-api"),
  appEnv,
  appVersion: optionalString("APP_VERSION", "0.1.0"),
  commitSha: optionalString("COMMIT_SHA", "unknown"),
  port: numberFromEnv("PORT", 3000, {
    min: 1,
    max: 65535,
  }),
  logLevel,
  databaseUrl,
  corsOrigin,
  enableCache: booleanFromEnv("ENABLE_CACHE", false),
  requestTimeoutMs: numberFromEnv("REQUEST_TIMEOUT_MS", 5000, {
    min: 100,
    max: 60000,
  }),
  startupDelayMs: numberFromEnv("STARTUP_DELAY_MS", 0, {
    min: 0,
    max: 60000,
  }),
};
```

Add to `safeConfigSummary`:

```javascript
startupDelayMs: config.startupDelayMs,
```

Open `server.js`.

After:

```javascript
let isShuttingDown = false;
```

Add:

```javascript
let isStartupComplete = config.startupDelayMs === 0;

if (!isStartupComplete) {
  logger.info("startup_delay_started", {
    delay_ms: config.startupDelayMs,
  });

  setTimeout(() => {
    isStartupComplete = true;
    logger.info("startup_delay_completed");
  }, config.startupDelayMs);
}
```

Update `/ready` route after shutdown check:

```javascript
  if (!isStartupComplete) {
    return res.status(503).json({
      status: "not_ready",
      reason: "startup delay in progress",
    });
  }
```

Now readiness can simulate startup dependency warming.

---

# 17. Test Startup Readiness Delay

Run:

```bash
APP_ENV=dev \
PORT=3000 \
LOG_LEVEL=info \
STARTUP_DELAY_MS=10000 \
LOAD_DOTENV=false \
npm start
```

In another terminal immediately:

```bash
curl -i http://127.0.0.1:3000/ready
```

Expected:

```text
HTTP/1.1 503 Service Unavailable
```

After 10 seconds:

```bash
curl -i http://127.0.0.1:3000/ready
```

Expected:

```text
HTTP/1.1 200 OK
```

This is exactly why deployment scripts should retry readiness/health checks.

---

# 18. Improve Deployment Script Health Check to Use Readiness

Currently `deploy-advanced.sh` uses:

```bash
HEALTH_URL=http://127.0.0.1:3000/health
```

For deployment success, readiness is often better:

```bash
HEALTH_URL=http://127.0.0.1:3000/ready
```

Why?

```text
/health = process alive
/ready = ready for traffic
```

Change deployment command:

```bash
HEALTH_URL=http://127.0.0.1:3000/ready \
SERVICE_NAME=demo-node-api \
VERSION=0.1.3 \
COMMIT_SHA=lesson59-ready \
./scripts/deploy-advanced.sh
```

Update default in `deploy-advanced.sh`:

```bash
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:3000/ready}"
```

Keep `/health` for basic process liveness.

Use `/ready` for deployment validation.

---

# 19. Add Graceful Shutdown Test Script

Create:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api
nano scripts/graceful-shutdown-lab.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-3000}"
DELAY_MS="${DELAY_MS:-8000}"

echo "===== Graceful Shutdown Lab ====="
echo "Port: $PORT"
echo "Slow request delay: $DELAY_MS ms"

APP_ENV=dev \
PORT="$PORT" \
LOG_LEVEL=info \
LOAD_DOTENV=false \
node server.js > graceful-app.log 2> graceful-error.log &

APP_PID=$!

echo "Started app PID: $APP_PID"

sleep 2

echo
echo "Starting slow request in background..."
curl -s "http://127.0.0.1:$PORT/slow?delay_ms=$DELAY_MS" > graceful-curl-output.json &
CURL_PID=$!

sleep 2

echo
echo "Sending SIGTERM to app..."
kill -TERM "$APP_PID"

echo
echo "Waiting for slow request..."
wait "$CURL_PID" || true

echo
echo "Waiting for app process..."
wait "$APP_PID" || true

echo
echo "Curl output:"
cat graceful-curl-output.json
echo

echo
echo "App logs:"
cat graceful-app.log

echo
echo "Error logs:"
cat graceful-error.log

echo
echo "Lab completed."
```

Make executable:

```bash
chmod +x scripts/graceful-shutdown-lab.sh
```

Run:

```bash
./scripts/graceful-shutdown-lab.sh
```

Expected:

```text
slow request completes
shutdown_complete appears in logs
```

---

# 20. Add SIGKILL Comparison Script

Create:

```bash
nano scripts/force-kill-lab.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-3000}"
DELAY_MS="${DELAY_MS:-8000}"

echo "===== Force Kill Lab ====="
echo "Port: $PORT"
echo "Slow request delay: $DELAY_MS ms"

APP_ENV=dev \
PORT="$PORT" \
LOG_LEVEL=info \
LOAD_DOTENV=false \
node server.js > force-app.log 2> force-error.log &

APP_PID=$!

echo "Started app PID: $APP_PID"

sleep 2

echo
echo "Starting slow request in background..."
set +e
curl -s "http://127.0.0.1:$PORT/slow?delay_ms=$DELAY_MS" > force-curl-output.json &
CURL_PID=$!
set -e

sleep 2

echo
echo "Sending SIGKILL to app..."
kill -9 "$APP_PID"

echo
echo "Waiting for slow request..."
set +e
wait "$CURL_PID"
CURL_CODE=$?
set -e

echo "Curl exit code: $CURL_CODE"

echo
echo "App logs:"
cat force-app.log || true

echo
echo "Error logs:"
cat force-error.log || true

echo
echo "Force kill lab completed."
```

Make executable:

```bash
chmod +x scripts/force-kill-lab.sh
```

Run:

```bash
./scripts/force-kill-lab.sh
```

Expected:

```text
request fails or curl exits non-zero
no shutdown_complete log
```

---

# 21. Update `.env.example`

Open:

```bash
nano .env.example
```

Add:

```bash
STARTUP_DELAY_MS=0
```

Full relevant part:

```bash
REQUEST_TIMEOUT_MS=5000
STARTUP_DELAY_MS=0
```

---

# 22. Update systemd Timeout Example

Open repo example:

```bash
cd ~/devops-masterclass/05-application-runtime
nano examples/systemd/demo-node-api.service
```

Make sure it has:

```ini
KillSignal=SIGTERM
TimeoutStopSec=15
```

Add comment in notes, not in production unit if you prefer clean config.

---

# 23. Add Graceful Shutdown Notes

Create:

```bash
nano graceful-shutdown-draining-zero-downtime.md
```

Paste:

````markdown
# Graceful Shutdown, Draining, and Zero-Downtime Basics

## Signals

| Signal | Meaning |
|---|---|
| SIGTERM | polite termination request |
| SIGINT | interrupt, usually Ctrl+C |
| SIGKILL | force kill, cannot be handled |

## Graceful Shutdown Flow

```text
receive SIGTERM
mark app not ready
stop accepting new requests
finish active requests
close server/dependencies
exit cleanly
````

## Why Readiness Matters

During startup or shutdown, `/ready` should return 503.

This prevents load balancers and orchestrators from sending traffic to an instance that is not ready.

## Timeout Layering

Example:

```text
app graceful timeout: 10s
systemd TimeoutStopSec: 15s
Nginx proxy_read_timeout: 30s
deployment health retry window: 20s
```

## Zero-Downtime Basics

True zero downtime usually requires:

* multiple app instances
* load balancer or reverse proxy
* readiness checks
* graceful shutdown
* connection draining
* rolling/blue-green/canary deployment

## Core Rules

* handle SIGTERM
* do not use SIGKILL for normal deploys
* mark readiness false during shutdown
* use `/ready` for deployment validation
* align timeouts intentionally
* use multiple instances for real zero downtime

````

---

# 24. Add Deployment Notes Update

Open:

```bash
nano advanced-deployment-auto-rollback.md
````

Add this section:

````markdown
## Health vs Readiness in Deployment

Use `/health` to know whether the process is alive.

Use `/ready` to know whether the app is ready to receive traffic.

Deployment validation should usually use `/ready`.

```bash
HEALTH_URL=http://127.0.0.1:3000/ready ./scripts/deploy-advanced.sh
````

````

---

# 25. Validate Work

Run local graceful test:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api

./scripts/graceful-shutdown-lab.sh
./scripts/force-kill-lab.sh
````

Run app with startup delay:

```bash
APP_ENV=dev \
PORT=3000 \
LOG_LEVEL=info \
STARTUP_DELAY_MS=10000 \
LOAD_DOTENV=false \
npm start
```

In another terminal:

```bash
curl -i http://127.0.0.1:3000/ready
sleep 12
curl -i http://127.0.0.1:3000/ready
```

Deploy with readiness:

```bash
HEALTH_URL=http://127.0.0.1:3000/ready \
SERVICE_NAME=demo-node-api \
VERSION=0.1.3 \
COMMIT_SHA=lesson59 \
./scripts/deploy-advanced.sh
```

Check:

```bash
curl -s http://127.0.0.1:3000/release | jq .
cat /opt/demo-node-api/shared/reports/deploy-*lesson59*.json | jq .
```

---

# 26. Commit Work

From repo root:

```bash
cd ~/devops-masterclass

git status
git add 05-application-runtime
git commit -m "feat: add graceful shutdown and readiness deployment basics"
git push
```

---

# 27. Interview Explanation

Question:

```text
What is graceful shutdown?
```

Strong answer:

```text
Graceful shutdown means the application handles a termination signal like SIGTERM by stopping new work, finishing active requests, closing resources, and exiting cleanly. This prevents dropped requests and makes deployments safer.
```

Question:

```text
What is the difference between SIGTERM and SIGKILL?
```

Strong answer:

```text
SIGTERM is a polite termination signal that the application can handle and use for graceful shutdown. SIGKILL forcefully kills the process immediately and cannot be handled, so active requests may be dropped and cleanup code will not run.
```

Question:

```text
Why should readiness become false during shutdown?
```

Strong answer:

```text
When an app is shutting down, it should not receive new traffic. Returning 503 from readiness tells load balancers or orchestrators to stop routing new requests to that instance while existing requests finish.
```

Question:

```text
What is required for zero-downtime deployment?
```

Strong answer:

```text
True zero-downtime deployment usually requires multiple app instances, a load balancer or reverse proxy, readiness checks, graceful shutdown, and connection draining. With only one process, a restart can still cause a small gap, so multiple instances or blue-green/rolling deployment is needed.
```

---

# Today’s Core Rules

```text
Handle SIGTERM.
Avoid SIGKILL for normal deployments.
Finish active requests before exit.
Mark readiness false during shutdown.
Use /ready for deployment validation.
Use /health for liveness.
Process manager timeout must be longer than app shutdown timeout.
Proxy timeout must match expected request behavior.
True zero downtime needs multiple instances.
Timeouts must be intentionally layered.
```

Next lesson:

# Lesson 5.10 — Production Runtime Capstone: Node App + Config + Logs + PM2/systemd + Nginx + HTTPS + Atomic Deployment + Auto-Rollback.

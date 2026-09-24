# Lesson 5.3 — Logs, stdout/stderr, JSON Logging, Log Levels, and Production Debugging

In production, logs are one of the first things DevOps engineers check.

When an app fails, you usually ask:

```text id="dn1nlb"
Did the process start?
Which port did it bind?
Which environment is it running in?
Did config validation pass?
Did it connect to dependencies?
Did it receive requests?
Did it throw errors?
Did it shut down cleanly?
```

Logs answer these questions.

---

# 1. What Are Application Logs?

Application logs are runtime messages emitted by the app.

Examples:

```text id="qbfa6j"
server started
request received
database connected
config validation failed
payment API failed
health check passed
shutdown started
uncaught exception
```

Bad logs:

```text id="ds4drb"
error
failed
something broke
```

Good logs:

```json id="hx9x13"
{
  "level": "error",
  "message": "database_connection_failed",
  "service": "demo-node-api",
  "environment": "prod",
  "error": "connection timeout",
  "timestamp": "2026-06-29T10:30:00.000Z"
}
```

Core rule:

```text id="qn6a91"
Logs should help another engineer debug the issue without guessing.
```

---

# 2. stdout and stderr

Linux processes have three standard streams:

```text id="hs16e7"
stdin   input
stdout  normal output
stderr  error output
```

For applications:

```text id="k0sa8d"
stdout = normal logs
stderr = error logs
```

Example:

```javascript id="iugtwx"
console.log("normal message");
console.error("error message");
```

In production:

```text id="qa23p2"
systemd captures stdout/stderr into journald
Docker captures stdout/stderr into container logs
Kubernetes captures stdout/stderr into pod logs
PM2 captures stdout/stderr into PM2 logs
CI/CD captures stdout/stderr into build logs
```

Core rule:

```text id="o9kcwf"
Production apps should write logs to stdout/stderr, not random local files.
```

Files can still be used in some VM deployments, but stdout/stderr is the modern default.

---

# 3. Log Levels

Common log levels:

```text id="ho8xv4"
debug
info
warn
error
fatal
```

Use them correctly.

## debug

Detailed troubleshooting.

```text id="81v63m"
request payload shape
retry attempt details
internal state
```

Only enable when needed.

## info

Normal lifecycle events.

```text id="m4ub80"
server started
database connected
request completed
deployment version loaded
```

## warn

Something unusual happened but the app can continue.

```text id="sgtlft"
retrying API request
cache unavailable, using fallback
deprecated config used
high latency detected
```

## error

An operation failed.

```text id="lyex5p"
database query failed
request failed
config invalid
external API failed
```

## fatal

App cannot continue.

```text id="2cm03j"
required config missing
cannot bind port
database migration failed
```

Core rule:

```text id="6wl8xy"
Do not log everything as error.
```

If everything is error, nothing is useful.

---

# 4. Text Logs vs JSON Logs

## Text logs

Example:

```text id="el2h6c"
2026-06-29 10:30:00 INFO server started on port 3000
```

Good for humans.

## JSON logs

Example:

```json id="n7eq9q"
{
  "timestamp": "2026-06-29T10:30:00.000Z",
  "level": "info",
  "message": "server_started",
  "service": "demo-node-api",
  "environment": "prod",
  "port": 3000
}
```

Better for machines.

JSON logs are easier to query in:

```text id="f9w90i"
ELK
Loki
CloudWatch Logs
Datadog
Splunk
OpenSearch
Grafana
```

Production rule:

```text id="znjvx4"
Use structured logs when logs will be collected and searched centrally.
```

---

# 5. Add a Logger Module to Demo App

Go to your app:

```bash id="eykl6i"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Create logger:

```bash id="o45fce"
nano src/logger.js
```

Paste:

```javascript id="4pns9f"
function createLogger(config) {
  const levels = {
    debug: 10,
    info: 20,
    warn: 30,
    error: 40,
  };

  const configuredLevel = config.logLevel || "info";
  const minimumLevel = levels[configuredLevel] || levels.info;

  function write(level, message, fields = {}) {
    if (levels[level] < minimumLevel) {
      return;
    }

    const payload = {
      timestamp: new Date().toISOString(),
      level,
      message,
      service: config.appName,
      environment: config.appEnv,
      version: config.appVersion,
      commit_sha: config.commitSha,
      ...fields,
    };

    const line = JSON.stringify(payload);

    if (level === "error") {
      console.error(line);
    } else {
      console.log(line);
    }
  }

  return {
    debug: (message, fields) => write("debug", message, fields),
    info: (message, fields) => write("info", message, fields),
    warn: (message, fields) => write("warn", message, fields),
    error: (message, fields) => write("error", message, fields),
  };
}

module.exports = {
  createLogger,
};
```

This gives you structured JSON logging with log-level filtering.

---

# 6. Update `server.js` to Use Logger

Open:

```bash id="miihtf"
nano server.js
```

Replace with:

```javascript id="r4l5ml"
const express = require("express");
const { loadConfig, safeConfigSummary } = require("./src/config");
const { createLogger } = require("./src/logger");

let config;

try {
  config = loadConfig();
} catch (error) {
  console.error(
    JSON.stringify({
      timestamp: new Date().toISOString(),
      level: "fatal",
      message: "config_validation_failed",
      error: error.message,
    })
  );
  process.exit(1);
}

const logger = createLogger(config);
const app = express();
const STARTED_AT = new Date().toISOString();

app.use(express.json());

app.use((req, res, next) => {
  const startedAt = Date.now();

  res.on("finish", () => {
    const durationMs = Date.now() - startedAt;

    logger.info("http_request_completed", {
      method: req.method,
      path: req.path,
      status_code: res.statusCode,
      duration_ms: durationMs,
      user_agent: req.get("user-agent") || "",
      remote_ip: req.ip,
    });
  });

  next();
});

app.get("/", (req, res) => {
  res.json({
    app: config.appName,
    environment: config.appEnv,
    message: "Hello from demo-node-api",
  });
});

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "ok",
    app: config.appName,
    environment: config.appEnv,
    uptime_seconds: Math.floor(process.uptime()),
    started_at: STARTED_AT,
  });
});

app.get("/ready", (req, res) => {
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

app.get("/version", (req, res) => {
  res.json({
    app: config.appName,
    version: config.appVersion,
    commit_sha: config.commitSha,
  });
});

app.get("/config-summary", (req, res) => {
  res.json(safeConfigSummary(config));
});

app.get("/simulate-warning", (req, res) => {
  logger.warn("simulated_warning", {
    reason: "manual test endpoint",
  });

  res.json({
    status: "warning_logged",
  });
});

app.get("/simulate-error", (req, res) => {
  logger.error("simulated_error", {
    reason: "manual test endpoint",
  });

  res.status(500).json({
    status: "error_logged",
  });
});

const server = app.listen(config.port, "0.0.0.0", () => {
  logger.info("server_started", {
    ...safeConfigSummary(config),
    started_at: STARTED_AT,
  });
});

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

process.on("uncaughtException", (error) => {
  logger.error("uncaught_exception", {
    error: error.message,
    stack: error.stack,
  });
  process.exit(1);
});

process.on("unhandledRejection", (reason) => {
  logger.error("unhandled_rejection", {
    reason: String(reason),
  });
  process.exit(1);
});
```

Now your app logs:

```text id="cfi0zn"
startup events
HTTP requests
readiness failures
warnings
errors
shutdown events
uncaught exceptions
unhandled promise rejections
```

---

# 7. Run and Inspect Logs

Run:

```bash id="x7nsur"
APP_ENV=dev LOG_LEVEL=info PORT=3000 LOAD_DOTENV=false npm start
```

You should see a JSON startup log.

In another terminal:

```bash id="s4d3uz"
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/ready | jq .
curl -s http://127.0.0.1:3000/simulate-warning | jq .
curl -s -i http://127.0.0.1:3000/simulate-error
```

Your app terminal should show JSON logs for each request.

Stop:

```text id="nyb3vl"
Ctrl + C
```

You should see shutdown logs.

---

# 8. Test Log Level Filtering

Run with `error` only:

```bash id="v3ic7k"
APP_ENV=dev LOG_LEVEL=error PORT=3000 LOAD_DOTENV=false npm start
```

In another terminal:

```bash id="jzdghi"
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/simulate-warning | jq .
curl -s -i http://127.0.0.1:3000/simulate-error
```

You should see:

```text id="e9h0z1"
health request log hidden because info < error
warning log hidden because warn < error
error log visible
```

Run with debug:

```bash id="io8e38"
APP_ENV=dev LOG_LEVEL=debug PORT=3000 LOAD_DOTENV=false npm start
```

Debug-level logs would appear if you add them.

Core rule:

```text id="my6h5v"
Production usually uses info.
Debug is temporary and should be used carefully.
```

---

# 9. Redirect Logs to Files for Local Debugging

Although production should usually use stdout/stderr, you can redirect locally.

Run:

```bash id="qyg9s8"
APP_ENV=dev PORT=3000 LOAD_DOTENV=false npm start > app.log 2> error.log
```

In another terminal:

```bash id="ar15t9"
curl -s http://127.0.0.1:3000/health | jq .
curl -s -i http://127.0.0.1:3000/simulate-error
```

View logs:

```bash id="o2wuqj"
cat app.log
cat error.log
```

Parse JSON logs:

```bash id="36gp39"
cat app.log | jq .
cat error.log | jq .
```

For line-by-line JSON logs:

```bash id="1u3lll"
while read -r line; do echo "$line" | jq .; done < app.log
```

Stop app:

```bash id="bgpttz"
PID=$(pgrep -f "node server.js" | head -n 1)
kill "$PID"
```

---

# 10. Add Request IDs

In production, request IDs help trace a single request across logs.

Install UUID package:

```bash id="otb38d"
npm install uuid
```

However, modern Node apps can also use simple random IDs.

To avoid ESM/CommonJS issues with newer UUID packages, we’ll use Node’s built-in crypto.

Open `server.js`:

```bash id="o96t1q"
nano server.js
```

Add near the top:

```javascript id="anqwyo"
const crypto = require("crypto");
```

Find this middleware:

```javascript id="1i4boi"
app.use((req, res, next) => {
  const startedAt = Date.now();
```

Replace the full middleware with:

```javascript id="l6rf7z"
app.use((req, res, next) => {
  const startedAt = Date.now();
  const requestId = req.get("x-request-id") || crypto.randomUUID();

  req.requestId = requestId;
  res.setHeader("x-request-id", requestId);

  res.on("finish", () => {
    const durationMs = Date.now() - startedAt;

    logger.info("http_request_completed", {
      request_id: requestId,
      method: req.method,
      path: req.path,
      status_code: res.statusCode,
      duration_ms: durationMs,
      user_agent: req.get("user-agent") || "",
      remote_ip: req.ip,
    });
  });

  next();
});
```

Now every response includes:

```text id="mdrlje"
x-request-id
```

Run:

```bash id="mawbuk"
APP_ENV=dev PORT=3000 LOAD_DOTENV=false npm start
```

Test:

```bash id="o6rk1l"
curl -i http://127.0.0.1:3000/health
```

With custom request ID:

```bash id="votvwp"
curl -i -H "x-request-id: test-123" http://127.0.0.1:3000/health
```

Your log should include:

```json id="3d1oca"
"request_id": "test-123"
```

Core rule:

```text id="5kk5iq"
Every production request should have a request ID or trace ID.
```

---

# 11. What Not to Log

Never log:

```text id="vxizb6"
passwords
tokens
API keys
JWTs
session cookies
authorization headers
full database URLs with passwords
credit card data
personal sensitive data
private keys
```

Bad:

```javascript id="8e4a53"
logger.info("request_headers", {
  headers: req.headers,
});
```

Danger:

```text id="pxxgeu"
req.headers may include Authorization and Cookie.
```

Better:

```javascript id="9yyoe2"
logger.info("http_request_completed", {
  method: req.method,
  path: req.path,
  status_code: res.statusCode,
});
```

Core rule:

```text id="l7pbrx"
Log metadata, not secrets.
```

---

# 12. Runtime Debugging with Logs

Common debugging patterns:

## App does not start

Check logs for:

```text id="u84me9"
config_validation_failed
EADDRINUSE
permission denied
module not found
database connection failed
```

## App starts but health fails

Check:

```bash id="3i2cuw"
curl -i http://127.0.0.1:3000/health
```

Then logs for request completion.

## App healthy but not ready

Check:

```bash id="u2bevt"
curl -i http://127.0.0.1:3000/ready
```

Then look for:

```text id="exn0dc"
readiness_failed
database missing
dependency unavailable
```

## Slow requests

Look for:

```json id="fl7w6y"
"duration_ms": 2450
```

Search:

```bash id="ol9km3"
cat app.log | jq 'select(.duration_ms > 1000)'
```

## 5xx errors

Search:

```bash id="2j9xq8"
cat app.log | jq 'select(.status_code >= 500)'
```

Or stderr:

```bash id="d2szie"
cat error.log | jq .
```

---

# 13. Add Log Parsing Script

Create:

```bash id="vz9rdr"
mkdir -p scripts
nano scripts/log-summary.sh
```

Paste:

```bash id="n4dyil"
#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${1:-app.log}"

if [ ! -f "$LOG_FILE" ]; then
  echo "ERROR: log file not found: $LOG_FILE" >&2
  exit 1
fi

echo "===== Log Summary: $LOG_FILE ====="

echo
echo "Total log lines:"
wc -l "$LOG_FILE"

echo
echo "By level:"
jq -r '.level // "unknown"' "$LOG_FILE" | sort | uniq -c | sort -nr

echo
echo "HTTP status count:"
jq -r 'select(.status_code != null) | .status_code' "$LOG_FILE" | sort | uniq -c | sort -nr || true

echo
echo "Slow requests > 1000ms:"
jq 'select(.duration_ms != null and .duration_ms > 1000)' "$LOG_FILE" || true

echo
echo "Errors:"
jq 'select(.level == "error" or .level == "fatal")' "$LOG_FILE" || true
```

Make executable:

```bash id="5wjpbd"
chmod +x scripts/log-summary.sh
```

Use:

```bash id="75d5pn"
APP_ENV=dev PORT=3000 LOAD_DOTENV=false npm start > app.log 2> error.log
```

Generate traffic:

```bash id="372vlk"
curl -s http://127.0.0.1:3000/health > /dev/null
curl -s http://127.0.0.1:3000/simulate-warning > /dev/null
curl -s http://127.0.0.1:3000/simulate-error > /dev/null
```

Run summary:

```bash id="bg64bg"
./scripts/log-summary.sh app.log
./scripts/log-summary.sh error.log
```

---

# 14. Log Rotation Concept

If apps write to files, logs can fill disk.

That is why production uses:

```text id="s5yqd5"
journald retention
Docker log rotation
logrotate
central logging systems
```

If using file logs, you need rotation.

Example logrotate config concept:

```conf id="d9uj4q"
/var/log/demo-node-api/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    copytruncate
}
```

But for modern containerized apps:

```text id="ztya2g"
App writes stdout/stderr
Runtime handles collection/rotation
```

Core rule:

```text id="5r3htt"
Unrotated logs can cause disk-full incidents.
```

---

# 15. Add Logging Notes

Create:

```bash id="jo41a0"
cd ~/devops-masterclass/05-application-runtime
nano runtime-logging.md
```

Paste:

````markdown id="w8ffvh"
# Runtime Logging

## Purpose

Logs help answer:

- did the app start?
- what config summary is active?
- which requests happened?
- which requests failed?
- how long did requests take?
- did the app shut down cleanly?

## stdout/stderr

- stdout for normal logs
- stderr for errors
- systemd, Docker, Kubernetes, PM2, and CI/CD capture stdout/stderr

## Log Levels

| Level | Use |
|---|---|
| debug | detailed troubleshooting |
| info | normal lifecycle and request logs |
| warn | unusual but non-fatal |
| error | failed operation |
| fatal | app cannot continue |

## Structured Logs

Prefer JSON logs in production.

Useful fields:

- timestamp
- level
- message
- service
- environment
- version
- commit_sha
- request_id
- method
- path
- status_code
- duration_ms

## Do Not Log

- passwords
- tokens
- API keys
- JWTs
- cookies
- authorization headers
- private keys
- full secret URLs

## Debug Commands

```bash
curl -i http://127.0.0.1:3000/health
curl -i -H "x-request-id: test-123" http://127.0.0.1:3000/health

cat app.log | jq .
cat error.log | jq .
cat app.log | jq 'select(.status_code >= 500)'
cat app.log | jq 'select(.duration_ms > 1000)'
````

````id="1r4y38"

---

# 16. Validate Work

Run:

```bash id="1yd2mt"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
npm install
````

Start app with log files:

```bash id="rtwrvi"
APP_ENV=dev LOG_LEVEL=info PORT=3000 LOAD_DOTENV=false npm start > app.log 2> error.log
```

In another terminal:

```bash id="3dyhbm"
curl -s http://127.0.0.1:3000/health | jq .
curl -s -H "x-request-id: lesson-5-3" http://127.0.0.1:3000/ready | jq .
curl -s http://127.0.0.1:3000/simulate-warning | jq .
curl -s -i http://127.0.0.1:3000/simulate-error
```

Summarize logs:

```bash id="70z3gg"
./scripts/log-summary.sh app.log
./scripts/log-summary.sh error.log
```

Stop app:

```bash id="4vw56c"
PID=$(pgrep -f "node server.js" | head -n 1)
kill "$PID"
```

---

# 17. Commit Work

From repo root:

```bash id="oijre2"
cd ~/devops-masterclass

git status
git add 05-application-runtime
git commit -m "feat: add structured runtime logging"
git push
```

---

# 18. Interview Explanation

Question:

```text id="23me8s"
How should production applications handle logs?
```

Strong answer:

```text id="xv8yl8"
Production applications should write logs to stdout and stderr so the runtime platform can collect them. Logs should use proper levels like debug, info, warn, error, and fatal. For modern systems, structured JSON logs are preferred because they can be searched and filtered in tools like ELK, Loki, CloudWatch, or Splunk. Logs should include useful metadata such as service, environment, version, request ID, status code, and duration, but must never include secrets.
```

Question:

```text id="igrbjy"
Why are request IDs important?
```

Strong answer:

```text id="20ub5e"
Request IDs allow engineers to trace all logs related to a single request. They are especially useful when debugging distributed systems, reverse proxies, APIs, and microservices. A request ID can be passed from the client or generated by the app and returned in the response header.
```

Question:

```text id="jga4o8"
What should not be logged?
```

Strong answer:

```text id="iz7jup"
Secrets should never be logged. That includes passwords, tokens, API keys, JWTs, session cookies, authorization headers, private keys, and full secret URLs. Logs should contain metadata and safe summaries, not sensitive values.
```

Question:

```text id="ct60dz"
What is the difference between logs and metrics?
```

Strong answer:

```text id="wlvpy5"
Logs are event records that explain what happened at a specific point in time. Metrics are numerical time-series values like request count, error rate, latency, CPU, and memory. Logs are useful for debugging details, while metrics are useful for trends, alerting, and dashboards.
```

---

# Today’s Core Rules

```text id="8aj1vb"
Use stdout for normal logs.
Use stderr for errors.
Use log levels correctly.
Prefer JSON logs in production.
Include service, environment, version, and request ID.
Log request method, path, status code, and duration.
Never log secrets.
Do not dump all headers.
Use request IDs for traceability.
Rotate file logs or let runtime handle logs.
Use logs for debugging, not as the only monitoring system.
```

Next lesson:

# Lesson 5.4 — Process Managers: PM2 and systemd for Production Node.js Apps.

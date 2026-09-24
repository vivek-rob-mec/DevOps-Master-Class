# Lesson 5.2 — Environment Variables, Config Files, Secrets, and Runtime Safety for Production Apps

In Lesson 5.1, we learned how apps run as processes, listen on ports, expose health endpoints, and behave differently in development vs production.

Now we focus on runtime configuration.

This is one of the most important production topics.

A production app usually needs:

```text id="kx9u9t"
PORT
APP_ENV
DATABASE_URL
REDIS_URL
JWT_SECRET
API_KEY
LOG_LEVEL
CORS_ORIGIN
FEATURE_FLAGS
```

The question is:

```text id="gq3xk2"
Where should these values come from?
How do we validate them?
How do we avoid leaking secrets?
How do we safely run the same app in dev, staging, and prod?
```

---

# 1. Configuration Categories

Runtime configuration usually falls into four categories:

```text id="qpi42e"
non-sensitive config
sensitive secrets
environment identity
feature/runtime behavior
```

## Non-sensitive config

Examples:

```text id="y705p7"
PORT=3000
APP_ENV=prod
LOG_LEVEL=info
CORS_ORIGIN=https://example.com
```

These are not secrets, but still important.

## Sensitive secrets

Examples:

```text id="6cgmno"
DATABASE_URL
JWT_SECRET
GITHUB_TOKEN
AWS_SECRET_ACCESS_KEY
WEBHOOK_URL
SMTP_PASSWORD
```

These must not be committed, printed, or exposed.

## Environment identity

Examples:

```text id="60kdt7"
APP_ENV=dev
APP_ENV=staging
APP_ENV=prod
```

This decides which environment the app thinks it is running in.

## Feature/runtime behavior

Examples:

```text id="gmfq63"
FEATURE_NEW_UI=true
ENABLE_CACHE=true
MAX_UPLOAD_MB=25
REQUEST_TIMEOUT_MS=5000
```

These change app behavior.

---

# 2. Core Production Rule

```text id="78pwzd"
Code should be the same across environments.
Configuration should change across environments.
```

Bad:

```javascript id="qgvz29"
if (environment === "prod") {
  databaseUrl = "mongodb://prod-db:27017/app";
} else {
  databaseUrl = "mongodb://localhost:27017/app";
}
```

Better:

```javascript id="ml5tco"
const databaseUrl = process.env.DATABASE_URL;
```

Then run with:

```bash id="3rppv5"
DATABASE_URL=mongodb://localhost:27017/app npm start
```

or in production:

```bash id="himqbn"
DATABASE_URL=mongodb://prod-db:27017/app npm start
```

This supports:

```text id="54k2bj"
same code
same artifact
different config
```

---

# 3. Config Priority Order

A common config priority model:

```text id="m3dbmy"
default values
  ↓
config files
  ↓
environment variables
  ↓
CLI arguments
```

Highest priority wins.

Example:

```text id="ro1x1z"
default PORT=3000
config file PORT=4000
environment PORT=5000
CLI --port 6000

final PORT=6000
```

In many production apps, the most common source is:

```text id="4tdlxw"
environment variables
```

In Docker/Kubernetes/systemd/PM2/Jenkins/GitHub Actions, environment variables are easy to inject.

---

# 4. `.env` Files

A `.env` file is useful for local development.

Example:

```bash id="d5qnme"
APP_NAME=demo-node-api
APP_ENV=dev
PORT=3000
APP_VERSION=0.1.0
COMMIT_SHA=local
LOG_LEVEL=debug
```

But production rule:

```text id="gof0y7"
Do not commit real .env files.
```

Commit only:

```text id="h27i6f"
.env.example
```

Example `.env.example`:

```bash id="bhwj0j"
APP_NAME=demo-node-api
APP_ENV=dev
PORT=3000
APP_VERSION=0.1.0
COMMIT_SHA=replace-with-commit-sha
DATABASE_URL=replace-with-database-url
JWT_SECRET=replace-with-secret
LOG_LEVEL=info
```

`.env.example` documents required variables without exposing real values.

---

# 5. Update Demo Node App with Config Validation

Go to your demo app:

```bash id="ehudrw"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Install dotenv for local development:

```bash id="v9dhew"
npm install dotenv
```

Create config module:

```bash id="nykha7"
mkdir -p src
nano src/config.js
```

Paste:

```javascript id="w55u62"
const path = require("path");

if (process.env.LOAD_DOTENV !== "false") {
  require("dotenv").config({
    path: path.resolve(process.cwd(), ".env"),
  });
}

const allowedEnvironments = new Set(["dev", "staging", "prod", "test"]);
const allowedLogLevels = new Set(["debug", "info", "warn", "error"]);

function requireString(name, options = {}) {
  const value = process.env[name];

  if (!value || value.trim() === "") {
    if (options.required === false) {
      return options.defaultValue || "";
    }

    throw new Error(`${name} is required`);
  }

  return value;
}

function optionalString(name, defaultValue = "") {
  const value = process.env[name];

  if (!value || value.trim() === "") {
    return defaultValue;
  }

  return value;
}

function numberFromEnv(name, defaultValue, options = {}) {
  const rawValue = process.env[name];

  if (!rawValue || rawValue.trim() === "") {
    return defaultValue;
  }

  const value = Number(rawValue);

  if (!Number.isInteger(value)) {
    throw new Error(`${name} must be an integer`);
  }

  if (options.min !== undefined && value < options.min) {
    throw new Error(`${name} must be >= ${options.min}`);
  }

  if (options.max !== undefined && value > options.max) {
    throw new Error(`${name} must be <= ${options.max}`);
  }

  return value;
}

function booleanFromEnv(name, defaultValue = false) {
  const rawValue = process.env[name];

  if (!rawValue || rawValue.trim() === "") {
    return defaultValue;
  }

  const normalized = rawValue.toLowerCase();

  if (["true", "1", "yes"].includes(normalized)) {
    return true;
  }

  if (["false", "0", "no"].includes(normalized)) {
    return false;
  }

  throw new Error(`${name} must be true or false`);
}

function validateUrl(name, value, options = {}) {
  if (!value) {
    return value;
  }

  let parsed;

  try {
    parsed = new URL(value);
  } catch {
    throw new Error(`${name} must be a valid URL`);
  }

  if (!["http:", "https:", "mongodb:", "postgres:", "redis:"].includes(parsed.protocol)) {
    throw new Error(`${name} has unsupported protocol: ${parsed.protocol}`);
  }

  if (options.requireHttps && parsed.protocol !== "https:") {
    throw new Error(`${name} must use https`);
  }

  return value;
}

function loadConfig() {
  const appEnv = optionalString("APP_ENV", "dev").toLowerCase();

  if (!allowedEnvironments.has(appEnv)) {
    throw new Error(`APP_ENV must be one of: ${Array.from(allowedEnvironments).join(", ")}`);
  }

  const logLevel = optionalString("LOG_LEVEL", "info").toLowerCase();

  if (!allowedLogLevels.has(logLevel)) {
    throw new Error(`LOG_LEVEL must be one of: ${Array.from(allowedLogLevels).join(", ")}`);
  }

  const databaseUrl = optionalString("DATABASE_URL", "");

  if (databaseUrl) {
    validateUrl("DATABASE_URL", databaseUrl);
  }

  const corsOrigin = optionalString("CORS_ORIGIN", "*");

  if (corsOrigin !== "*") {
    validateUrl("CORS_ORIGIN", corsOrigin, {
      requireHttps: appEnv === "prod",
    });
  }

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
  };
}

function safeConfigSummary(config) {
  return {
    appName: config.appName,
    appEnv: config.appEnv,
    appVersion: config.appVersion,
    commitSha: config.commitSha,
    port: config.port,
    logLevel: config.logLevel,
    databaseUrlConfigured: Boolean(config.databaseUrl),
    corsOrigin: config.corsOrigin,
    enableCache: config.enableCache,
    requestTimeoutMs: config.requestTimeoutMs,
  };
}

module.exports = {
  loadConfig,
  safeConfigSummary,
};
```

This gives the app a proper runtime config layer.

---

# 6. Update `server.js`

Open:

```bash id="xzj5ql"
nano server.js
```

Replace with:

```javascript id="c1l7a3"
const express = require("express");
const { loadConfig, safeConfigSummary } = require("./src/config");

let config;

try {
  config = loadConfig();
} catch (error) {
  console.error(
    JSON.stringify({
      level: "error",
      message: "config_validation_failed",
      error: error.message,
    })
  );
  process.exit(1);
}

const app = express();
const STARTED_AT = new Date().toISOString();

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

const server = app.listen(config.port, "0.0.0.0", () => {
  console.log(
    JSON.stringify({
      level: "info",
      message: "server_started",
      ...safeConfigSummary(config),
      started_at: STARTED_AT,
    })
  );
});

function shutdown(signal) {
  console.log(
    JSON.stringify({
      level: "info",
      message: "shutdown_started",
      signal,
    })
  );

  server.close(() => {
    console.log(
      JSON.stringify({
        level: "info",
        message: "shutdown_complete",
      })
    );
    process.exit(0);
  });

  setTimeout(() => {
    console.error(
      JSON.stringify({
        level: "error",
        message: "shutdown_forced",
      })
    );
    process.exit(1);
  }, 10000).unref();
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
```

Now the app has:

```text id="x7n3xt"
config validation
safe config summary
readiness behavior
JSON logs
graceful shutdown
```

---

# 7. Create `.env.example`

Create:

```bash id="27bbno"
nano .env.example
```

Paste:

```bash id="psudti"
APP_NAME=demo-node-api
APP_ENV=dev
APP_VERSION=0.1.0
COMMIT_SHA=local
PORT=3000
LOG_LEVEL=debug
DATABASE_URL=
CORS_ORIGIN=*
ENABLE_CACHE=false
REQUEST_TIMEOUT_MS=5000
```

Create local `.env`:

```bash id="c9kepb"
cp .env.example .env
```

Make sure `.gitignore` exists:

```bash id="xi49d5"
nano .gitignore
```

Paste:

```gitignore id="065lka"
node_modules/
.env
.env.*
!.env.example
npm-debug.log*
```

---

# 8. Run with `.env`

Run:

```bash id="pvlmlf"
npm start
```

In another terminal:

```bash id="lqpg12"
curl -s http://127.0.0.1:3000/config-summary | jq .
curl -s http://127.0.0.1:3000/ready | jq .
```

Expected config summary:

```json id="fq5oo5"
{
  "appName": "demo-node-api",
  "appEnv": "dev",
  "appVersion": "0.1.0",
  "commitSha": "local",
  "port": 3000,
  "logLevel": "debug",
  "databaseUrlConfigured": false,
  "corsOrigin": "*",
  "enableCache": false,
  "requestTimeoutMs": 5000
}
```

Stop app:

```text id="1xh8cg"
Ctrl + C
```

---

# 9. Test Invalid Config

Invalid port:

```bash id="gp9z3u"
PORT=99999 npm start
```

Expected:

```json id="6svmkd"
{
  "level": "error",
  "message": "config_validation_failed",
  "error": "PORT must be <= 65535"
}
```

Invalid environment:

```bash id="7i6ao8"
APP_ENV=production npm start
```

Expected:

```json id="7f18nu"
{
  "level": "error",
  "message": "config_validation_failed",
  "error": "APP_ENV must be one of: dev, staging, prod, test"
}
```

Invalid boolean:

```bash id="1twyvk"
ENABLE_CACHE=maybe npm start
```

Expected:

```text id="68zvxm"
ENABLE_CACHE must be true or false
```

This is good.

Production apps should fail fast when config is invalid.

---

# 10. Production Config Behavior

Run prod without database:

```bash id="rlyq5d"
APP_ENV=prod PORT=3000 npm start
```

In another terminal:

```bash id="87b3e0"
curl -i http://127.0.0.1:3000/ready
```

Expected:

```text id="exmj90"
HTTP/1.1 503 Service Unavailable
```

Because in our app:

```text id="k0jhw8"
prod requires DATABASE_URL for readiness
```

Now run with database configured:

```bash id="y4o55l"
APP_ENV=prod \
DATABASE_URL=mongodb://localhost:27017/demo \
PORT=3000 \
npm start
```

Check:

```bash id="xvia2q"
curl -s http://127.0.0.1:3000/ready | jq .
```

Expected:

```json id="oy32qn"
{
  "status": "ready",
  "app": "demo-node-api",
  "database_configured": true
}
```

Important difference:

```text id="2fe0ly"
The app can be healthy but not ready.
```

---

# 11. Secrets Safety

Never expose raw secrets.

Bad endpoint:

```javascript id="7bf3p2"
app.get("/config", (req, res) => {
  res.json(process.env);
});
```

Very dangerous.

It may expose:

```text id="pd2cvs"
DATABASE_URL
JWT_SECRET
AWS keys
webhook URLs
tokens
passwords
```

Good:

```javascript id="w4jod2"
app.get("/config-summary", (req, res) => {
  res.json(safeConfigSummary(config));
});
```

This only shows:

```text id="zcymnq"
whether secret is configured
not the secret value
```

Rule:

```text id="r4vqwc"
Expose config state, not secret values.
```

---

# 12. Runtime Config Debugging Commands

Check current shell env:

```bash id="7rpng3"
env | sort
```

Check only app vars:

```bash id="07q98m"
env | grep -E 'APP_|PORT|DATABASE|LOG_LEVEL|CORS|CACHE|TIMEOUT' | sort
```

Run with inline env:

```bash id="x84sw4"
APP_ENV=staging PORT=4000 npm start
```

Run with exported env:

```bash id="el0uql"
export APP_ENV=staging
export PORT=4000
npm start
```

Unset:

```bash id="8jmwt4"
unset APP_ENV
unset PORT
```

Load `.env` manually in Bash:

```bash id="19ls3g"
set -a
source .env
set +a
npm start
```

Check env of running process:

```bash id="1skmsy"
PID=$(pgrep -f "node server.js" | head -n 1)
tr '\0' '\n' < /proc/$PID/environ | sort
```

Warning:

```text id="phjv0g"
This can reveal secrets. Use carefully.
```

---

# 13. Config Files vs Environment Variables

## Environment variables are good for:

```text id="wz5xpt"
ports
environment names
secrets references
URLs
feature flags
small config values
CI/CD injection
Docker/Kubernetes/systemd integration
```

## Config files are good for:

```text id="tiv2ko"
large structured config
route maps
multi-service lists
complex policies
non-secret app rules
```

Example config file:

```yaml id="3wpwb2"
rate_limits:
  default_per_minute: 100
  admin_per_minute: 1000

features:
  new_dashboard: true
  beta_api: false
```

But secrets should usually come from:

```text id="iq28k3"
environment variables
secret manager
Kubernetes Secret
Jenkins credentials
GitHub Actions secrets
AWS Secrets Manager
Vault
```

---

# 14. systemd Environment Patterns

Later we will create a real systemd unit.

Common patterns:

## Inline env in unit file

```ini id="bm5m6d"
Environment=APP_ENV=prod
Environment=PORT=3000
```

Okay for non-sensitive values.

## Environment file

```ini id="6wxi6d"
EnvironmentFile=/etc/demo-node-api/demo-node-api.env
```

Then:

```bash id="hz2q34"
sudo nano /etc/demo-node-api/demo-node-api.env
```

Example:

```bash id="1sdl8n"
APP_ENV=prod
PORT=3000
DATABASE_URL=mongodb://localhost:27017/demo
```

Security:

```bash id="q6ubd2"
sudo chown root:demoapp /etc/demo-node-api/demo-node-api.env
sudo chmod 640 /etc/demo-node-api/demo-node-api.env
```

---

# 15. PM2 Environment Pattern

PM2 commonly uses ecosystem files.

Example:

```javascript id="iuoe7x"
module.exports = {
  apps: [
    {
      name: "demo-node-api",
      script: "server.js",
      env: {
        APP_ENV: "dev",
        PORT: 3000
      },
      env_production: {
        APP_ENV: "prod",
        PORT: 3000
      }
    }
  ]
};
```

Run:

```bash id="zt7jhw"
pm2 start ecosystem.config.js --env production
```

We will cover PM2 deeper soon.

---

# 16. Docker Environment Pattern

Docker:

```bash id="ru6xb0"
docker run \
  -e APP_ENV=prod \
  -e PORT=3000 \
  -e DATABASE_URL=mongodb://mongo:27017/demo \
  -p 3000:3000 \
  demo-node-api:0.1.0
```

Docker Compose:

```yaml id="dv9am4"
services:
  demo-node-api:
    image: demo-node-api:0.1.0
    environment:
      APP_ENV: prod
      PORT: 3000
      DATABASE_URL: mongodb://mongo:27017/demo
```

We will cover this deeply in Docker module.

---

# 17. Kubernetes Environment Pattern

Kubernetes:

```yaml id="qvmgw6"
env:
  - name: APP_ENV
    value: "prod"
  - name: PORT
    value: "3000"
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: demo-node-api-secret
        key: database-url
```

ConfigMap for non-secret config.

Secret for sensitive config.

We will cover this deeply in Kubernetes module.

---

# 18. Runtime Safety Checklist

Before running an app in production, check:

```text id="0u277s"
Required config is validated
Invalid config fails fast
Secrets are not logged
Secrets are not exposed via endpoint
.env is not committed
.env.example exists
Port is configurable
Environment is explicit
CORS is safe
Readiness checks dependencies
Health is not too strict
Version endpoint exists
Logs are useful
Graceful shutdown exists
```

---

# 19. Add Config Notes

Create:

```bash id="w08h11"
cd ~/devops-masterclass/05-application-runtime
nano runtime-config-secrets.md
```

Paste:

````markdown id="yk9bs5"
# Runtime Config, Secrets, and Safety

## Config Types

- non-sensitive config
- secrets
- environment identity
- feature flags
- runtime behavior

## Rules

- Do not hardcode environment-specific values.
- Use environment variables for runtime config.
- Use `.env` only for local development.
- Commit `.env.example`, not `.env`.
- Validate config at startup.
- Fail fast on invalid config.
- Do not print secrets.
- Do not expose raw environment variables through endpoints.
- Expose safe config summary only.
- Use readiness checks for dependency requirements.
- Keep health checks simple.

## Common Variables

```bash
APP_NAME=demo-node-api
APP_ENV=prod
APP_VERSION=0.1.0
COMMIT_SHA=abc123
PORT=3000
LOG_LEVEL=info
DATABASE_URL=mongodb://localhost:27017/demo
CORS_ORIGIN=https://example.com
ENABLE_CACHE=true
REQUEST_TIMEOUT_MS=5000
````

## Debug Commands

```bash
env | sort
env | grep -E 'APP_|PORT|DATABASE|LOG_LEVEL|CORS|CACHE|TIMEOUT' | sort

PID=$(pgrep -f "node server.js" | head -n 1)
tr '\0' '\n' < /proc/$PID/environ | sort
```

Warning: process environment may contain secrets.

````id="1s7wuf"

---

# 20. Add Runtime Config Lab Script

Create:

```bash id="3f9kps"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
mkdir -p scripts
nano scripts/runtime-config-lab.sh
````

Paste:

```bash id="940ilt"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Runtime Config Lab ====="

echo
echo "1. Testing invalid APP_ENV..."
set +e
APP_ENV=production LOAD_DOTENV=false node server.js
code=$?
set -e
echo "Exit code: $code"

echo
echo "2. Testing invalid PORT..."
set +e
PORT=99999 LOAD_DOTENV=false node server.js
code=$?
set -e
echo "Exit code: $code"

echo
echo "3. Testing invalid boolean..."
set +e
ENABLE_CACHE=maybe LOAD_DOTENV=false node server.js
code=$?
set -e
echo "Exit code: $code"

echo
echo "Runtime config validation lab completed."
```

Make executable:

```bash id="1vcmge"
chmod +x scripts/runtime-config-lab.sh
```

Run:

```bash id="w2j23m"
./scripts/runtime-config-lab.sh
```

Expected:

```text id="qcgu3e"
Each invalid config should fail with exit code 1.
```

---

# 21. Validate Work

Run:

```bash id="9l1scb"
cd ~/devops-masterclass/05-application-runtime/demo-node-api
npm install
./scripts/runtime-config-lab.sh
```

Run app:

```bash id="l6lyno"
APP_ENV=dev PORT=3000 LOAD_DOTENV=false npm start
```

In another terminal:

```bash id="ulnd97"
curl -s http://127.0.0.1:3000/config-summary | jq .
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/ready | jq .
curl -s http://127.0.0.1:3000/version | jq .
```

Stop:

```text id="1hsp4c"
Ctrl + C
```

---

# 22. Commit Work

From repo root:

```bash id="1h189n"
cd ~/devops-masterclass

git status
git add 05-application-runtime
git commit -m "feat: add runtime config validation and secrets safety"
git push
```

---

# 23. Interview Explanation

Question:

```text id="0ibg5v"
How should production apps handle configuration?
```

Strong answer:

```text id="sq0jra"
Production apps should keep code and configuration separate. The same build artifact should run in dev, staging, and prod with different environment variables or config sources. Required config should be validated at startup, invalid config should fail fast, and secrets should never be committed, logged, or exposed through endpoints.
```

Question:

```text id="3xebcp"
What is the purpose of `.env.example`?
```

Strong answer:

```text id="21ablf"
`.env.example` documents the environment variables required by the app using placeholder values. It helps developers set up the app locally without exposing real secrets. The real `.env` file should be ignored by Git.
```

Question:

```text id="qibfks"
How do you prevent secrets from leaking?
```

Strong answer:

```text id="cm9qt8"
I avoid hardcoding secrets, keep real `.env` files out of Git, use secret managers or CI/CD secret stores, avoid printing raw environment variables, and expose only safe config summaries that show whether a secret is configured, not the secret value.
```

Question:

```text id="7xuwll"
What is fail-fast config validation?
```

Strong answer:

```text id="cpj6fl"
Fail-fast config validation means the app validates required environment variables and config values during startup. If a required value is missing or invalid, the app exits immediately with a clear error instead of starting in a broken or unsafe state.
```

---

# Today’s Core Rules

```text id="z7jwx6"
Separate code from config.
Use environment variables for runtime config.
Use .env only for local development.
Commit .env.example, not .env.
Validate config at startup.
Fail fast on invalid config.
Never log secrets.
Never expose process.env through an endpoint.
Expose safe config summary only.
Use readiness checks for dependency/config readiness.
Use explicit APP_ENV values.
```

Next lesson:

# Lesson 5.3 — Logs, stdout/stderr, JSON logging, log levels, and production debugging.

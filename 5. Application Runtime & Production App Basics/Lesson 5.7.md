# Lesson 5.7 — Deployment Layouts, Release Directories, Symlinks, Atomic Deployments, and Rollback Basics

So far in Module 5, your app can:

```text
run as a process
read runtime config
produce structured logs
run under PM2/systemd
sit behind Nginx
use HTTPS through Nginx/Certbot
```

Now we learn how real deployments are organized on a Linux server.

This lesson is very important because it connects directly with your previous Jenkins atomic deployment experience.

---

# 1. The Problem with Simple Deployment

Bad deployment style:

```bash
cd /var/www/demo-node-api
git pull
npm install
pm2 restart demo-node-api
```

This looks simple, but it has problems:

```text
deployment can leave app half-updated
rollback is difficult
old version is overwritten
no clear release history
npm install can fail midway
current running version is unclear
deployment and runtime files are mixed
```

If something breaks, you may not know:

```text
which version is running
which commit was deployed
how to rollback quickly
what files changed
whether deployment finished fully
```

Production needs a safer layout.

---

# 2. Better Deployment Layout

A common production layout:

```text
/opt/demo-node-api/
├── releases/
│   ├── 20260629-101500-abc123/
│   ├── 20260629-112000-def456/
│   └── 20260629-121000-fed789/
├── shared/
│   ├── logs/
│   └── config/
└── current -> /opt/demo-node-api/releases/20260629-121000-fed789
```

Important parts:

```text
releases/  = immutable deployed versions
shared/    = persistent files/config/logs
current    = symlink pointing to active release
```

Your app runs from:

```text
/opt/demo-node-api/current
```

Not directly from a specific release folder.

---

# 3. Why Use Release Directories?

Release directories give you:

```text
clean version history
fast rollback
atomic switch
deployment traceability
separate build artifacts
safer deployments
```

Example:

```text
current -> releases/v1
```

Deploy new version:

```text
extract releases/v2
install dependencies
validate health
switch current -> releases/v2
restart app
```

Rollback:

```text
current -> releases/v1
restart app
```

Rollback becomes a symlink change.

---

# 4. What Is an Atomic Deployment?

Atomic means the switch happens as one quick operation.

Instead of modifying the running directory file-by-file, you prepare a new release separately.

Then you switch:

```bash
ln -sfn /opt/demo-node-api/releases/new-release /opt/demo-node-api/current
```

The app sees either:

```text
old release
```

or:

```text
new release
```

Not a half-updated mix.

Core rule:

```text
Build and prepare first. Switch only after validation.
```

---

# 5. Create Deployment Layout Locally

We will create a local deployment layout under your Module 5 folder first.

Run:

```bash
cd ~/devops-masterclass/05-application-runtime
mkdir -p deployment-layout-demo/{releases,shared/logs,shared/config}
cd deployment-layout-demo
```

Check:

```bash
tree .
```

Expected:

```text
.
├── releases
└── shared
    ├── config
    └── logs
```

---

# 6. Create Release v1

Create first release:

```bash
mkdir -p releases/20260629-lesson-v1
```

Create a simple app file:

```bash
cat > releases/20260629-lesson-v1/app.txt <<'EOF'
demo-node-api
version=v1
commit=abc123
EOF
```

Point `current` to v1:

```bash
ln -sfn releases/20260629-lesson-v1 current
```

Check:

```bash
ls -l
cat current/app.txt
```

Expected:

```text
version=v1
commit=abc123
```

---

# 7. Deploy Release v2

Create new release:

```bash
mkdir -p releases/20260629-lesson-v2
```

Add file:

```bash
cat > releases/20260629-lesson-v2/app.txt <<'EOF'
demo-node-api
version=v2
commit=def456
EOF
```

Before switching:

```bash
cat current/app.txt
```

Still v1.

Switch:

```bash
ln -sfn releases/20260629-lesson-v2 current
```

Check:

```bash
cat current/app.txt
```

Now v2.

That is the core of atomic deployment.

---

# 8. Rollback to v1

Rollback:

```bash
ln -sfn releases/20260629-lesson-v1 current
```

Check:

```bash
cat current/app.txt
```

Expected:

```text
version=v1
commit=abc123
```

This is why symlink deployments are powerful.

---

# 9. Use Absolute Symlinks in Real Production

For local demo, this works:

```bash
ln -sfn releases/20260629-lesson-v2 current
```

For production, prefer absolute symlink:

```bash
ln -sfn /opt/demo-node-api/releases/20260629-lesson-v2 /opt/demo-node-api/current
```

Why?

```text
less ambiguity
works from any working directory
easier to inspect
clearer for systemd/PM2
```

Check symlink target:

```bash
readlink current
readlink -f current
```

---

# 10. Real App Deployment Layout

Now we create a production-style layout for your Node app.

Target:

```text
/opt/demo-node-api/
├── releases/
├── shared/
│   ├── config/
│   └── logs/
└── current
```

Create directories:

```bash
sudo mkdir -p /opt/demo-node-api/releases
sudo mkdir -p /opt/demo-node-api/shared/config
sudo mkdir -p /opt/demo-node-api/shared/logs
```

Set ownership:

```bash
sudo chown -R demoapp:demoapp /opt/demo-node-api
```

If `demoapp` does not exist from Lesson 5.4:

```bash
sudo useradd --system --create-home --shell /usr/sbin/nologin demoapp
sudo chown -R demoapp:demoapp /opt/demo-node-api
```

---

# 11. Create a Release from Current Demo App

Go to source app:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Create release ID:

```bash
RELEASE_ID="$(date +%Y%m%d-%H%M%S)-local"
echo "$RELEASE_ID"
```

Create release directory:

```bash
sudo mkdir -p "/opt/demo-node-api/releases/$RELEASE_ID"
```

Copy app:

```bash
sudo rsync -av \
  --exclude node_modules \
  --exclude .env \
  --exclude app.log \
  --exclude error.log \
  --exclude ecosystem.config.js \
  ./ "/opt/demo-node-api/releases/$RELEASE_ID/"
```

Install production dependencies:

```bash
cd "/opt/demo-node-api/releases/$RELEASE_ID"
sudo npm install --omit=dev
```

Fix ownership:

```bash
sudo chown -R demoapp:demoapp "/opt/demo-node-api/releases/$RELEASE_ID"
```

Switch symlink:

```bash
sudo ln -sfn "/opt/demo-node-api/releases/$RELEASE_ID" /opt/demo-node-api/current
sudo chown -h demoapp:demoapp /opt/demo-node-api/current
```

Check:

```bash
ls -l /opt/demo-node-api
readlink -f /opt/demo-node-api/current
ls -l /opt/demo-node-api/current
```

---

# 12. Update systemd to Run from `current`

Open service:

```bash
sudo nano /etc/systemd/system/demo-node-api.service
```

Change:

```ini
WorkingDirectory=/opt/demo-node-api
ExecStart=/usr/bin/node /opt/demo-node-api/server.js
```

to:

```ini
WorkingDirectory=/opt/demo-node-api/current
ExecStart=/usr/bin/node /opt/demo-node-api/current/server.js
```

Full important part:

```ini
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
```

Reload and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart demo-node-api
```

Check:

```bash
sudo systemctl status demo-node-api --no-pager
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/version | jq .
```

Now systemd runs whatever `/opt/demo-node-api/current` points to.

---

# 13. Add Release Metadata File

A release should contain metadata.

Inside current release:

```bash
cd /opt/demo-node-api/current
```

Create metadata:

```bash
sudo tee RELEASE.json > /dev/null <<EOF
{
  "service": "demo-node-api",
  "version": "0.1.0",
  "release_id": "$RELEASE_ID",
  "commit_sha": "local",
  "created_at": "$(date -Iseconds)"
}
EOF
```

Fix owner:

```bash
sudo chown demoapp:demoapp /opt/demo-node-api/current/RELEASE.json
```

Check:

```bash
cat /opt/demo-node-api/current/RELEASE.json | jq .
```

Production rule:

```text
Every release directory should include release metadata.
```

This helps debugging and rollback.

---

# 14. Add `/release` Endpoint to App

Your `/version` endpoint shows runtime version from environment. Now we add a `/release` endpoint that reads `RELEASE.json`.

Go to source app:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Open:

```bash
nano server.js
```

Add near top:

```javascript
const fs = require("fs");
const path = require("path");
```

Add this function before routes:

```javascript
function readReleaseMetadata() {
  const releasePath = path.join(process.cwd(), "RELEASE.json");

  if (!fs.existsSync(releasePath)) {
    return {
      available: false,
      reason: "RELEASE.json not found",
    };
  }

  try {
    return {
      available: true,
      ...JSON.parse(fs.readFileSync(releasePath, "utf8")),
    };
  } catch (error) {
    return {
      available: false,
      reason: "invalid RELEASE.json",
      error: error.message,
    };
  }
}
```

Add endpoint after `/version`:

```javascript
app.get("/release", (req, res) => {
  res.json(readReleaseMetadata());
});
```

Test locally after deployment later.

---

# 15. Create Deployment Script

Now we automate the layout.

Create scripts directory:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api
mkdir -p scripts
nano scripts/deploy-release.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"
APP_USER="${APP_USER:-demoapp}"
APP_GROUP="${APP_GROUP:-demoapp}"
APP_ROOT="${APP_ROOT:-/opt/demo-node-api}"
SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"
VERSION="${VERSION:-0.1.0}"
COMMIT_SHA="${COMMIT_SHA:-local}"
RELEASE_ID="${RELEASE_ID:-$(date +%Y%m%d-%H%M%S)-$COMMIT_SHA}"

RELEASE_DIR="$APP_ROOT/releases/$RELEASE_ID"
CURRENT_LINK="$APP_ROOT/current"

echo "===== Deploy Release ====="
echo "Service: $SERVICE_NAME"
echo "Source: $SOURCE_DIR"
echo "Release: $RELEASE_ID"
echo "Release dir: $RELEASE_DIR"

sudo mkdir -p "$APP_ROOT/releases" "$APP_ROOT/shared/config" "$APP_ROOT/shared/logs"
sudo mkdir -p "$RELEASE_DIR"

sudo rsync -av \
  --exclude node_modules \
  --exclude .env \
  --exclude app.log \
  --exclude error.log \
  --exclude ecosystem.config.js \
  "$SOURCE_DIR/" "$RELEASE_DIR/"

cd "$RELEASE_DIR"

sudo npm install --omit=dev

sudo tee "$RELEASE_DIR/RELEASE.json" > /dev/null <<EOF
{
  "service": "$SERVICE_NAME",
  "version": "$VERSION",
  "release_id": "$RELEASE_ID",
  "commit_sha": "$COMMIT_SHA",
  "created_at": "$(date -Iseconds)"
}
EOF

sudo chown -R "$APP_USER:$APP_GROUP" "$APP_ROOT"

echo "Validating release files..."
test -f "$RELEASE_DIR/server.js"
test -f "$RELEASE_DIR/package.json"
test -f "$RELEASE_DIR/RELEASE.json"

echo "Switching current symlink..."
sudo ln -sfn "$RELEASE_DIR" "$CURRENT_LINK"
sudo chown -h "$APP_USER:$APP_GROUP" "$CURRENT_LINK"

echo "Restarting service..."
sudo systemctl restart "$SERVICE_NAME"

echo "Waiting for app health..."
sleep 2

curl -fsS "http://127.0.0.1:3000/health" > /dev/null

echo "Release deployed successfully:"
readlink -f "$CURRENT_LINK"
```

Make executable:

```bash
chmod +x scripts/deploy-release.sh
```

Run:

```bash
SERVICE_NAME=demo-node-api \
VERSION=0.1.0 \
COMMIT_SHA=lesson57 \
./scripts/deploy-release.sh
```

Check:

```bash
curl -s http://127.0.0.1:3000/release | jq .
readlink -f /opt/demo-node-api/current
```

---

# 16. Create Rollback Script

Create:

```bash
nano scripts/rollback-release.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-demo-node-api}"
APP_ROOT="${APP_ROOT:-/opt/demo-node-api}"
TARGET_RELEASE="${1:-}"

if [ -z "$TARGET_RELEASE" ]; then
  echo "Usage: $0 <release-id-or-release-path>" >&2
  echo
  echo "Available releases:" >&2
  ls -1 "$APP_ROOT/releases" >&2
  exit 1
fi

if [ -d "$TARGET_RELEASE" ]; then
  RELEASE_DIR="$TARGET_RELEASE"
else
  RELEASE_DIR="$APP_ROOT/releases/$TARGET_RELEASE"
fi

if [ ! -d "$RELEASE_DIR" ]; then
  echo "ERROR: release directory not found: $RELEASE_DIR" >&2
  exit 1
fi

if [ ! -f "$RELEASE_DIR/server.js" ]; then
  echo "ERROR: invalid release, missing server.js: $RELEASE_DIR" >&2
  exit 1
fi

echo "===== Rollback Release ====="
echo "Service: $SERVICE_NAME"
echo "Target release: $RELEASE_DIR"

sudo ln -sfn "$RELEASE_DIR" "$APP_ROOT/current"

echo "Restarting service..."
sudo systemctl restart "$SERVICE_NAME"

sleep 2

echo "Checking health..."
curl -fsS "http://127.0.0.1:3000/health" > /dev/null

echo "Rollback completed successfully:"
readlink -f "$APP_ROOT/current"
```

Make executable:

```bash
chmod +x scripts/rollback-release.sh
```

List releases:

```bash
ls -1 /opt/demo-node-api/releases
```

Rollback:

```bash
./scripts/rollback-release.sh <release-id>
```

---

# 17. Create Release Cleanup Script

Over time, release folders grow.

Keep last 5 releases:

```bash
nano scripts/cleanup-releases.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="${APP_ROOT:-/opt/demo-node-api}"
KEEP="${KEEP:-5}"
RELEASES_DIR="$APP_ROOT/releases"
CURRENT_TARGET="$(readlink -f "$APP_ROOT/current" || true)"

echo "===== Cleanup Releases ====="
echo "App root: $APP_ROOT"
echo "Keep latest: $KEEP"
echo "Current target: $CURRENT_TARGET"

mapfile -t RELEASES < <(find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d | sort -r)

COUNT=0

for release in "${RELEASES[@]}"; do
  if [ "$release" = "$CURRENT_TARGET" ]; then
    echo "Keeping current: $release"
    continue
  fi

  COUNT=$((COUNT + 1))

  if [ "$COUNT" -le "$KEEP" ]; then
    echo "Keeping: $release"
  else
    echo "Removing old release: $release"
    sudo rm -rf "$release"
  fi
done

echo "Cleanup complete."
```

Make executable:

```bash
chmod +x scripts/cleanup-releases.sh
```

Run dry thought first by reading output. Then:

```bash
KEEP=5 ./scripts/cleanup-releases.sh
```

Core rule:

```text
Never delete the current symlink target.
```

Our script protects the current release.

---

# 18. Deployment Validation Flow

A safer production deployment sequence:

```text
1. Create new release directory.
2. Copy/extract artifact.
3. Install dependencies.
4. Write RELEASE.json.
5. Validate required files.
6. Switch current symlink.
7. Restart app.
8. Run health check.
9. If health fails, rollback to previous symlink target.
10. Cleanup old releases.
```

Better deployment scripts also remember previous target:

```bash
PREVIOUS_TARGET="$(readlink -f /opt/demo-node-api/current || true)"
```

If health fails:

```bash
ln -sfn "$PREVIOUS_TARGET" /opt/demo-node-api/current
systemctl restart demo-node-api
```

We will add that in an advanced deployment lesson.

---

# 19. PM2 with Symlink Layout

PM2 can also use this layout.

Example ecosystem file:

```javascript
module.exports = {
  apps: [
    {
      name: "demo-node-api",
      script: "/opt/demo-node-api/current/server.js",
      cwd: "/opt/demo-node-api/current",
      env_production: {
        APP_ENV: "prod",
        PORT: 3000,
        LOAD_DOTENV: "false"
      }
    }
  ]
};
```

After symlink switch:

```bash
pm2 restart demo-node-api --update-env
```

Important:

```text
systemd uses WorkingDirectory and ExecStart.
PM2 uses cwd and script.
```

The principle is the same:

```text
process manager points to current symlink
deployments update current symlink
```

---

# 20. Add Deployment Layout Notes

Create:

```bash
cd ~/devops-masterclass/05-application-runtime
nano deployment-layouts-atomic-rollbacks.md
```

Paste:

````markdown
# Deployment Layouts, Atomic Deployments, and Rollbacks

## Recommended Layout

```text
/opt/demo-node-api/
├── releases/
│   ├── 20260629-101500-abc123/
│   ├── 20260629-112000-def456/
│   └── 20260629-121000-fed789/
├── shared/
│   ├── config/
│   └── logs/
└── current -> /opt/demo-node-api/releases/20260629-121000-fed789
````

## Why This Layout?

* keeps old releases
* enables fast rollback
* avoids half-updated deployments
* separates runtime state from releases
* makes current version easy to inspect

## Atomic Deployment

Prepare new release first:

```bash
mkdir -p /opt/demo-node-api/releases/new-release
rsync app files
npm install --omit=dev
write RELEASE.json
```

Then switch:

```bash
ln -sfn /opt/demo-node-api/releases/new-release /opt/demo-node-api/current
systemctl restart demo-node-api
```

## Rollback

```bash
ln -sfn /opt/demo-node-api/releases/previous-release /opt/demo-node-api/current
systemctl restart demo-node-api
```

## Core Rules

* never modify current release in place
* create a new release directory
* validate before switching
* switch using symlink
* run health check after restart
* rollback by pointing current to previous release
* keep release metadata
* clean old releases safely
* never delete current symlink target

````

---

# 21. Add Deployment Scripts Notes

Create:

```bash
nano deployment-scripts.md
````

Paste:

````markdown
# Deployment Scripts

## Scripts

Inside `demo-node-api/scripts`:

```text
deploy-release.sh
rollback-release.sh
cleanup-releases.sh
````

## Deploy

```bash
SERVICE_NAME=demo-node-api \
VERSION=0.1.0 \
COMMIT_SHA=abc123 \
./scripts/deploy-release.sh
```

## Rollback

```bash
./scripts/rollback-release.sh <release-id>
```

## Cleanup

```bash
KEEP=5 ./scripts/cleanup-releases.sh
```

## Validation

```bash
readlink -f /opt/demo-node-api/current
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/release | jq .
journalctl -u demo-node-api -n 100 --no-pager
```

````

---

# 22. Validate Everything

Run:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api
````

Deploy:

```bash
SERVICE_NAME=demo-node-api \
VERSION=0.1.0 \
COMMIT_SHA=lesson57a \
./scripts/deploy-release.sh
```

Check release:

```bash
curl -s http://127.0.0.1:3000/release | jq .
readlink -f /opt/demo-node-api/current
```

Create another release:

```bash
SERVICE_NAME=demo-node-api \
VERSION=0.1.1 \
COMMIT_SHA=lesson57b \
./scripts/deploy-release.sh
```

List:

```bash
ls -1 /opt/demo-node-api/releases
readlink -f /opt/demo-node-api/current
```

Rollback to previous release:

```bash
./scripts/rollback-release.sh <previous-release-id>
```

Check:

```bash
curl -s http://127.0.0.1:3000/release | jq .
```

Cleanup:

```bash
KEEP=5 ./scripts/cleanup-releases.sh
```

---

# 23. Commit Work

From repo root:

```bash
cd ~/devops-masterclass

git status
git add 05-application-runtime
git commit -m "feat: add atomic deployment layout and rollback scripts"
git push
```

---

# 24. Interview Explanation

Question:

```text
What is an atomic deployment?
```

Strong answer:

```text
An atomic deployment is a deployment pattern where a new release is prepared in a separate directory and only switched into service when it is ready. Usually a `current` symlink points to the active release. The deployment updates the symlink to the new release in one quick operation, preventing half-updated application states.
```

Question:

```text
Why use release directories and a current symlink?
```

Strong answer:

```text
Release directories keep each deployed version separate and immutable. The `current` symlink identifies the active release. This makes deployments safer, provides release history, enables fast rollback, and makes it easy for process managers like systemd or PM2 to run the currently active version.
```

Question:

```text
How do you rollback with this layout?
```

Strong answer:

```text
Rollback is done by repointing the `current` symlink to a previous known-good release and restarting the process manager. Because old releases are kept, rollback is fast and does not require rebuilding or re-copying files.
```

Question:

```text
What should every release directory contain?
```

Strong answer:

```text
Every release directory should contain the application files, dependency files, and release metadata such as service name, version, release ID, commit SHA, and creation timestamp. This helps with debugging, auditability, and incident response.
```

---

# Today’s Core Rules

```text
Do not deploy by modifying the running directory in place.
Use release directories.
Use a current symlink.
Prepare before switching.
Validate required files before restart.
Restart app after symlink switch.
Run health check after deployment.
Rollback by repointing current to previous release.
Keep RELEASE.json metadata.
Never delete the current release.
Clean old releases carefully.
```

Next lesson:

# Lesson 5.8 — Advanced Deployment Script: Preflight, Previous Release Tracking, Health Validation, Auto-Rollback, and Deployment Reports.

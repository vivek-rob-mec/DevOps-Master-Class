# Lesson 5.8 — Advanced Deployment Script

# Preflight, Previous Release Tracking, Health Validation, Auto-Rollback, and Deployment Reports

In Lesson 5.7, you learned the core atomic deployment layout:

```text
/opt/demo-node-api/
├── releases/
├── shared/
└── current -> releases/<active-release>
```

Now we improve the deployment script.

A professional deployment should not only copy files and restart the app. It should also:

```text
run preflight checks
remember previous release
prepare new release safely
validate files
switch symlink atomically
restart service
run health check
auto-rollback if health fails
write deployment report
cleanup old releases
```

This is very close to what real Jenkins/GitHub Actions deployment stages do.

---

# 1. Target Deployment Flow

Current simple flow:

```text
copy files
switch current
restart
health check
```

Advanced flow:

```text
1. Validate source directory
2. Validate required commands
3. Validate app user and service
4. Capture previous release target
5. Create new release directory
6. Copy source files
7. Install production dependencies
8. Write RELEASE.json
9. Validate required files
10. Switch current symlink
11. Restart service
12. Run health check
13. If health fails, rollback to previous release
14. Write deployment report
15. Cleanup old releases
```

Core rule:

```text
A deployment script should know how to fail safely.
```

---

# 2. Create Advanced Deployment Script

Go to the app:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Create:

```bash
nano scripts/deploy-advanced.sh
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
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:3000/health}"
RELEASE_URL="${RELEASE_URL:-http://127.0.0.1:3000/release}"
KEEP_RELEASES="${KEEP_RELEASES:-5}"
AUTO_ROLLBACK="${AUTO_ROLLBACK:-true}"

RELEASES_DIR="$APP_ROOT/releases"
SHARED_DIR="$APP_ROOT/shared"
REPORTS_DIR="$SHARED_DIR/reports"
RELEASE_DIR="$RELEASES_DIR/$RELEASE_ID"
CURRENT_LINK="$APP_ROOT/current"
DEPLOY_REPORT="$REPORTS_DIR/deploy-$RELEASE_ID.json"

PREVIOUS_TARGET=""

log() {
  echo "[$(date -Iseconds)] $*"
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))'
}

write_report() {
  local status="$1"
  local message="$2"
  local rollback_status="${3:-not_required}"

  sudo mkdir -p "$REPORTS_DIR"

  local current_target
  current_target="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"

  sudo tee "$DEPLOY_REPORT" > /dev/null <<EOF
{
  "service": "$SERVICE_NAME",
  "status": "$status",
  "message": $(printf "%s" "$message" | json_escape),
  "version": "$VERSION",
  "commit_sha": "$COMMIT_SHA",
  "release_id": "$RELEASE_ID",
  "release_dir": "$RELEASE_DIR",
  "previous_target": "$PREVIOUS_TARGET",
  "current_target": "$current_target",
  "health_url": "$HEALTH_URL",
  "rollback_status": "$rollback_status",
  "created_at": "$(date -Iseconds)"
}
EOF

  sudo chown -R "$APP_USER:$APP_GROUP" "$REPORTS_DIR" || true
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

preflight() {
  log "Running preflight checks..."

  require_command rsync
  require_command npm
  require_command node
  require_command curl
  require_command systemctl
  require_command python3

  [ -d "$SOURCE_DIR" ] || fail "source directory not found: $SOURCE_DIR"
  [ -f "$SOURCE_DIR/server.js" ] || fail "server.js not found in source directory"
  [ -f "$SOURCE_DIR/package.json" ] || fail "package.json not found in source directory"

  id "$APP_USER" >/dev/null 2>&1 || fail "app user not found: $APP_USER"
  getent group "$APP_GROUP" >/dev/null 2>&1 || fail "app group not found: $APP_GROUP"

  systemctl list-unit-files | grep -q "^$SERVICE_NAME.service" || {
    log "WARNING: systemd unit not found in list-unit-files: $SERVICE_NAME.service"
  }

  sudo mkdir -p "$RELEASES_DIR" "$SHARED_DIR/config" "$SHARED_DIR/logs" "$REPORTS_DIR"
  sudo chown -R "$APP_USER:$APP_GROUP" "$APP_ROOT"

  PREVIOUS_TARGET="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"

  if [ -n "$PREVIOUS_TARGET" ]; then
    log "Previous release: $PREVIOUS_TARGET"
  else
    log "No previous release found."
  fi

  if [ -e "$RELEASE_DIR" ]; then
    fail "release directory already exists: $RELEASE_DIR"
  fi

  log "Preflight checks completed."
}

prepare_release() {
  log "Preparing release: $RELEASE_ID"

  sudo mkdir -p "$RELEASE_DIR"

  sudo rsync -av \
    --exclude node_modules \
    --exclude .env \
    --exclude app.log \
    --exclude error.log \
    --exclude ecosystem.config.js \
    "$SOURCE_DIR/" "$RELEASE_DIR/"

  cd "$RELEASE_DIR"

  log "Installing production dependencies..."
  sudo npm install --omit=dev

  log "Writing RELEASE.json..."
  sudo tee "$RELEASE_DIR/RELEASE.json" > /dev/null <<EOF
{
  "service": "$SERVICE_NAME",
  "version": "$VERSION",
  "release_id": "$RELEASE_ID",
  "commit_sha": "$COMMIT_SHA",
  "created_at": "$(date -Iseconds)"
}
EOF

  sudo chown -R "$APP_USER:$APP_GROUP" "$RELEASE_DIR"
}

validate_release() {
  log "Validating release files..."

  [ -f "$RELEASE_DIR/server.js" ] || fail "missing server.js"
  [ -f "$RELEASE_DIR/package.json" ] || fail "missing package.json"
  [ -f "$RELEASE_DIR/RELEASE.json" ] || fail "missing RELEASE.json"
  [ -d "$RELEASE_DIR/node_modules" ] || fail "missing node_modules"

  log "Release validation completed."
}

switch_release() {
  log "Switching current symlink..."
  sudo ln -sfn "$RELEASE_DIR" "$CURRENT_LINK"
  sudo chown -h "$APP_USER:$APP_GROUP" "$CURRENT_LINK"

  log "Current now points to:"
  readlink -f "$CURRENT_LINK"
}

restart_service() {
  log "Restarting service: $SERVICE_NAME"
  sudo systemctl restart "$SERVICE_NAME"
}

health_check() {
  log "Running health check: $HEALTH_URL"

  local max_attempts=10
  local attempt=1

  while [ "$attempt" -le "$max_attempts" ]; do
    if curl -fsS "$HEALTH_URL" >/dev/null; then
      log "Health check passed on attempt $attempt"
      return 0
    fi

    log "Health check failed on attempt $attempt/$max_attempts"
    sleep 2
    attempt=$((attempt + 1))
  done

  return 1
}

show_release_endpoint() {
  log "Release endpoint output:"
  curl -fsS "$RELEASE_URL" || true
  echo
}

rollback() {
  if [ "$AUTO_ROLLBACK" != "true" ]; then
    log "Auto-rollback disabled."
    return 1
  fi

  if [ -z "$PREVIOUS_TARGET" ] || [ ! -d "$PREVIOUS_TARGET" ]; then
    log "No previous release available for rollback."
    return 1
  fi

  log "Rolling back to previous release: $PREVIOUS_TARGET"

  sudo ln -sfn "$PREVIOUS_TARGET" "$CURRENT_LINK"
  sudo chown -h "$APP_USER:$APP_GROUP" "$CURRENT_LINK"

  sudo systemctl restart "$SERVICE_NAME"

  if health_check; then
    log "Rollback health check passed."
    write_report "failed" "deployment failed health check; rollback succeeded" "succeeded"
    return 0
  fi

  log "Rollback health check failed."
  write_report "failed" "deployment failed health check; rollback also failed" "failed"
  return 1
}

cleanup_releases() {
  log "Cleaning old releases. Keeping latest $KEEP_RELEASES non-current releases."

  local current_target
  current_target="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"

  mapfile -t releases < <(find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d | sort -r)

  local kept=0

  for release in "${releases[@]}"; do
    if [ "$release" = "$current_target" ]; then
      log "Keeping current release: $release"
      continue
    fi

    kept=$((kept + 1))

    if [ "$kept" -le "$KEEP_RELEASES" ]; then
      log "Keeping old release: $release"
    else
      log "Removing old release: $release"
      sudo rm -rf "$release"
    fi
  done
}

main() {
  log "===== Advanced Deployment Started ====="
  log "Service: $SERVICE_NAME"
  log "Version: $VERSION"
  log "Commit: $COMMIT_SHA"
  log "Release ID: $RELEASE_ID"
  log "Source: $SOURCE_DIR"
  log "App root: $APP_ROOT"

  preflight
  prepare_release
  validate_release
  switch_release
  restart_service

  if health_check; then
    show_release_endpoint
    write_report "success" "deployment succeeded" "not_required"
    cleanup_releases
    log "Deployment succeeded."
    log "Report: $DEPLOY_REPORT"
    exit 0
  fi

  log "Deployment health check failed."

  if rollback; then
    log "Deployment failed, but rollback succeeded."
    log "Report: $DEPLOY_REPORT"
    exit 1
  fi

  write_report "failed" "deployment failed and rollback was not completed" "failed"
  log "Deployment failed."
  log "Report: $DEPLOY_REPORT"
  exit 1
}

main "$@"
```

Make executable:

```bash
chmod +x scripts/deploy-advanced.sh
```

---

# 3. What This Script Improves

Compared to the simple script, this adds:

```text
preflight checks
previous release tracking
release validation
health retry loop
auto-rollback
deployment report
release cleanup
safer failure behavior
```

Most important line conceptually:

```bash
PREVIOUS_TARGET="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
```

This remembers the previous good release before switching.

Rollback uses:

```bash
sudo ln -sfn "$PREVIOUS_TARGET" "$CURRENT_LINK"
sudo systemctl restart "$SERVICE_NAME"
```

---

# 4. Run a Successful Advanced Deployment

Make sure systemd service exists and points to `/opt/demo-node-api/current`.

Check:

```bash
sudo systemctl status demo-node-api --no-pager
```

Run deployment:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api

SERVICE_NAME=demo-node-api \
VERSION=0.1.0 \
COMMIT_SHA=lesson58-success \
./scripts/deploy-advanced.sh
```

Check:

```bash
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/release | jq .
readlink -f /opt/demo-node-api/current
```

Check deployment report:

```bash
ls -lh /opt/demo-node-api/shared/reports
cat /opt/demo-node-api/shared/reports/deploy-*lesson58-success*.json | jq .
```

Expected report:

```json
{
  "service": "demo-node-api",
  "status": "success",
  "message": "deployment succeeded",
  "version": "0.1.0",
  "commit_sha": "lesson58-success",
  "rollback_status": "not_required"
}
```

---

# 5. Simulate a Bad Deployment

Now we intentionally break the app to test auto-rollback.

Create a temporary broken copy:

```bash
cd ~/devops-masterclass/05-application-runtime

rm -rf /tmp/demo-node-api-broken
cp -a demo-node-api /tmp/demo-node-api-broken
```

Break `server.js`:

```bash
cat > /tmp/demo-node-api-broken/server.js <<'EOF'
throw new Error("simulated broken release");
EOF
```

Deploy broken release:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api

SOURCE_DIR=/tmp/demo-node-api-broken \
SERVICE_NAME=demo-node-api \
VERSION=0.1.1 \
COMMIT_SHA=lesson58-broken \
./scripts/deploy-advanced.sh || true
```

Expected behavior:

```text
new release is prepared
current switches to broken release
systemd restart fails or health check fails
script rolls back to previous release
previous release becomes current again
script exits non-zero
deployment report says rollback succeeded
```

Check:

```bash
readlink -f /opt/demo-node-api/current
curl -s http://127.0.0.1:3000/release | jq .
sudo systemctl status demo-node-api --no-pager
```

Check report:

```bash
cat /opt/demo-node-api/shared/reports/deploy-*lesson58-broken*.json | jq .
```

Expected:

```json
{
  "status": "failed",
  "message": "deployment failed health check; rollback succeeded",
  "rollback_status": "succeeded"
}
```

This is a major production deployment pattern.

---

# 6. Add a Deployment Report Endpoint? No.

You may think:

```text
Should the app expose deployment reports?
```

Usually no.

Deployment reports may contain:

```text
server paths
release IDs
internal deployment metadata
failure reasons
```

Keep reports on the server or CI/CD artifact storage.

Expose only safe runtime endpoints:

```text
/health
/ready
/version
/release
```

Even `/release` should only contain safe metadata.

---

# 7. Improve `.gitignore`

The app may generate logs or local files.

Open:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api
nano .gitignore
```

Make sure it includes:

```gitignore
node_modules/
.env
.env.*
!.env.example
app.log
error.log
*.log
ecosystem.config.js
!ecosystem.config.example.js
```

---

# 8. Add Deployment Report Example to Repo

Create an examples folder:

```bash
cd ~/devops-masterclass/05-application-runtime
mkdir -p examples/deployment
nano examples/deployment/deploy-report.example.json
```

Paste:

```json
{
  "service": "demo-node-api",
  "status": "success",
  "message": "deployment succeeded",
  "version": "0.1.0",
  "commit_sha": "abc123",
  "release_id": "20260629-120000-abc123",
  "release_dir": "/opt/demo-node-api/releases/20260629-120000-abc123",
  "previous_target": "/opt/demo-node-api/releases/20260629-110000-old123",
  "current_target": "/opt/demo-node-api/releases/20260629-120000-abc123",
  "health_url": "http://127.0.0.1:3000/health",
  "rollback_status": "not_required",
  "created_at": "2026-06-29T12:00:00+05:30"
}
```

Create failed example:

```bash
nano examples/deployment/deploy-report-rollback.example.json
```

Paste:

```json
{
  "service": "demo-node-api",
  "status": "failed",
  "message": "deployment failed health check; rollback succeeded",
  "version": "0.1.1",
  "commit_sha": "def456",
  "release_id": "20260629-123000-def456",
  "release_dir": "/opt/demo-node-api/releases/20260629-123000-def456",
  "previous_target": "/opt/demo-node-api/releases/20260629-120000-abc123",
  "current_target": "/opt/demo-node-api/releases/20260629-120000-abc123",
  "health_url": "http://127.0.0.1:3000/health",
  "rollback_status": "succeeded",
  "created_at": "2026-06-29T12:30:00+05:30"
}
```

---

# 9. Add Advanced Deployment Notes

Create:

```bash
cd ~/devops-masterclass/05-application-runtime
nano advanced-deployment-auto-rollback.md
```

Paste:

````markdown
# Advanced Deployment with Auto-Rollback

## Goal

Create a deployment script that can safely deploy a new release and rollback automatically if health checks fail.

## Flow

```text
preflight
prepare release
validate release
capture previous current target
switch current symlink
restart service
run health check
rollback if health fails
write deployment report
cleanup old releases
````

## Key Variables

```bash
SERVICE_NAME=demo-node-api
APP_ROOT=/opt/demo-node-api
VERSION=0.1.0
COMMIT_SHA=abc123
HEALTH_URL=http://127.0.0.1:3000/health
AUTO_ROLLBACK=true
KEEP_RELEASES=5
```

## Deploy

```bash
SERVICE_NAME=demo-node-api \
VERSION=0.1.0 \
COMMIT_SHA=abc123 \
./scripts/deploy-advanced.sh
```

## Broken Release Test

```bash
SOURCE_DIR=/tmp/demo-node-api-broken \
SERVICE_NAME=demo-node-api \
VERSION=0.1.1 \
COMMIT_SHA=broken \
./scripts/deploy-advanced.sh || true
```

## Validate

```bash
readlink -f /opt/demo-node-api/current
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/release | jq .
cat /opt/demo-node-api/shared/reports/deploy-*.json | jq .
```

## Core Rules

* Capture previous release before switching.
* Health check after restart.
* Rollback automatically when health fails.
* Write a deployment report.
* Do not delete current release.
* Keep deployment reports for audits and incidents.

````

---

# 10. Add Jenkins Stage Example

Create:

```bash
nano jenkins-advanced-deployment-stage.md
````

Paste:

````markdown
# Jenkins Advanced Deployment Stage

Example Jenkins stage using the advanced deployment script.

```groovy
stage('Deploy with Auto-Rollback') {
  steps {
    dir('05-application-runtime/demo-node-api') {
      sh '''
        set -euo pipefail

        SERVICE_NAME=demo-node-api \
        VERSION="${VERSION}" \
        COMMIT_SHA="${GIT_COMMIT}" \
        HEALTH_URL="http://127.0.0.1:3000/health" \
        AUTO_ROLLBACK=true \
        KEEP_RELEASES=5 \
        ./scripts/deploy-advanced.sh
      '''
    }
  }
}

post {
  always {
    archiveArtifacts artifacts: '05-application-runtime/demo-node-api/deploy-*.json', allowEmptyArchive: true
  }
}
````

Better production pattern:

```text
Deployment reports should be copied back from the remote server to Jenkins workspace,
or uploaded from the server to S3/artifact storage.
```

````

---

# 11. Add GitHub Actions Note

For real deployment through GitHub Actions, you usually deploy over SSH.

Pattern:

```text
GitHub Actions runner
  ↓ SSH
remote server
  ↓ run deploy-advanced.sh
````

Create:

```bash
nano github-actions-ssh-deployment-pattern.md
```

Paste:

````markdown
# GitHub Actions SSH Deployment Pattern

A GitHub Actions workflow can deploy by SSHing into the server and running the deployment script.

Example concept:

```yaml
- name: Deploy over SSH
  run: |
    ssh deploy@server.example.com '
      cd /srv/devops-masterclass/05-application-runtime/demo-node-api &&
      SERVICE_NAME=demo-node-api \
      VERSION="${{ github.ref_name }}" \
      COMMIT_SHA="${{ github.sha }}" \
      AUTO_ROLLBACK=true \
      ./scripts/deploy-advanced.sh
    '
````

## Important

* Store SSH private key in GitHub Secrets.
* Restrict SSH user permissions.
* Archive or upload deployment reports.
* Do not expose secrets in logs.
* Use environment protection for production.
* Require approvals for production deployments.

````

---

# 12. Improve Cleanup Logic Understanding

The cleanup function keeps:

```text
current release always
latest N non-current releases
````

Example:

```text
KEEP_RELEASES=5
```

Means:

```text
keep current release
keep 5 additional old releases
delete older ones
```

Why not keep only 1?

```text
You may need to rollback more than one version.
You may need old releases for investigation.
```

Why not keep unlimited?

```text
Disk can fill.
node_modules can be large.
Old artifacts can consume GBs.
```

Production usually keeps:

```text
5, 10, or 20 releases
```

depending on disk and release frequency.

---

# 13. Add Manual Recovery Playbook

Create:

```bash
cd ~/devops-masterclass/05-application-runtime
nano deployment-recovery-playbook.md
```

Paste:

````markdown
# Deployment Recovery Playbook

## Scenario: Deployment Failed

Check service:

```bash
sudo systemctl status demo-node-api --no-pager
journalctl -u demo-node-api -n 100 --no-pager
````

Check current release:

```bash
readlink -f /opt/demo-node-api/current
cat /opt/demo-node-api/current/RELEASE.json | jq .
```

Check reports:

```bash
ls -lh /opt/demo-node-api/shared/reports
cat /opt/demo-node-api/shared/reports/deploy-*.json | jq .
```

List releases:

```bash
ls -1 /opt/demo-node-api/releases
```

Manual rollback:

```bash
sudo ln -sfn /opt/demo-node-api/releases/<previous-release> /opt/demo-node-api/current
sudo chown -h demoapp:demoapp /opt/demo-node-api/current
sudo systemctl restart demo-node-api
curl -fsS http://127.0.0.1:3000/health
```

Check through Nginx:

```bash
curl -i http://127.0.0.1/health
```

## Scenario: Port Conflict

```bash
sudo ss -tulnp | grep ':3000'
pm2 list
sudo systemctl status demo-node-api --no-pager
```

Stop wrong process:

```bash
pm2 stop demo-node-api
sudo systemctl restart demo-node-api
```

## Scenario: Bad Config

```bash
sudo cat /etc/demo-node-api/demo-node-api.env
journalctl -u demo-node-api -n 100 --no-pager
```

Do not paste secrets publicly.

````

---

# 14. Validate Successful Deployment Again

Run:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api

SERVICE_NAME=demo-node-api \
VERSION=0.1.2 \
COMMIT_SHA=lesson58-final \
./scripts/deploy-advanced.sh
````

Validate:

```bash
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/release | jq .
readlink -f /opt/demo-node-api/current
cat /opt/demo-node-api/shared/reports/deploy-*lesson58-final*.json | jq .
```

Through Nginx:

```bash
curl -s http://127.0.0.1/health | jq .
curl -s http://127.0.0.1/release | jq .
```

---

# 15. Common Problems and Fixes

## Problem: `systemctl restart demo-node-api` fails

Check:

```bash
sudo systemctl status demo-node-api --no-pager
journalctl -u demo-node-api -n 100 --no-pager
```

Likely causes:

```text
bad ExecStart path
current symlink broken
missing node_modules
invalid config
port conflict
permission issue
```

---

## Problem: Health check fails but app is running

Check direct endpoint:

```bash
curl -i http://127.0.0.1:3000/health
```

Check wrong port:

```bash
sudo ss -tulnp | grep node
```

Check env file:

```bash
sudo cat /etc/demo-node-api/demo-node-api.env
```

Maybe the app is running on a different `PORT`.

---

## Problem: Rollback fails

Check previous release path:

```bash
ls -ld /opt/demo-node-api/releases/*
readlink -f /opt/demo-node-api/current
```

Check whether previous release has dependencies:

```bash
ls -ld /opt/demo-node-api/releases/<release>/node_modules
```

Check service logs:

```bash
journalctl -u demo-node-api -n 100 --no-pager
```

---

## Problem: Permission denied

Fix ownership:

```bash
sudo chown -R demoapp:demoapp /opt/demo-node-api
sudo chown -h demoapp:demoapp /opt/demo-node-api/current
```

Fix env file permissions:

```bash
sudo chown root:demoapp /etc/demo-node-api/demo-node-api.env
sudo chmod 640 /etc/demo-node-api/demo-node-api.env
```

---

# 16. Commit Work

From repo root:

```bash
cd ~/devops-masterclass

git status
git add 05-application-runtime
git commit -m "feat: add advanced deployment with auto rollback"
git push
```

---

# 17. Interview Explanation

Question:

```text
How do you design a safe deployment script?
```

Strong answer:

```text
I design deployment scripts around preflight, atomic release preparation, health validation, and rollback. The script first validates required commands, source files, service user, and target directories. It captures the previous current symlink target, prepares a new immutable release directory, installs dependencies, writes release metadata, switches the current symlink, restarts the process manager, and runs health checks. If health fails, it automatically points current back to the previous release and restarts the service. It also writes a deployment report for audit and incident response.
```

Question:

```text
Why capture the previous release before deployment?
```

Strong answer:

```text
Capturing the previous release before switching allows automatic rollback. If the new release fails health checks, the script can repoint the current symlink to the previous known-good release and restart the service quickly.
```

Question:

```text
What should a deployment report contain?
```

Strong answer:

```text
A deployment report should include service name, version, commit SHA, release ID, release directory, previous target, current target, health URL, deployment status, rollback status, message, and timestamp. This helps with auditing, debugging, and incident response.
```

Question:

```text
Why use health checks after restart?
```

Strong answer:

```text
Restart success only means the process manager started or attempted to start the process. A health check verifies that the application is actually responding correctly. Deployment should be considered successful only after the health endpoint passes.
```

---

# Today’s Core Rules

```text
Preflight before deployment.
Prepare release before switching.
Capture previous release.
Validate files before restart.
Switch using current symlink.
Restart process manager.
Health check after restart.
Auto-rollback if health fails.
Write deployment report.
Keep old releases, but clean safely.
Never delete current release.
Archive deployment reports.
```

Next lesson:

# Lesson 5.9 — Graceful Shutdown, Signals, Draining, Timeouts, and Zero-Downtime Deployment Basics.

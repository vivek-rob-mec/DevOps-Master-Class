# Lesson 3.19 — Linux Module Capstone

This is the final capstone for Module 3:

```text
Linux, Bash, Networking, Security, Troubleshooting
```

Now we combine everything into a realistic production-style VM setup.

You will build a small but professional server setup:

```text
Secure Linux VM
  ↓
Dedicated service user
  ↓
Demo application
  ↓
systemd service
  ↓
Nginx reverse proxy
  ↓
Logs and logrotate
  ↓
Healthcheck scripts
  ↓
Security baseline
  ↓
Troubleshooting runbooks
```

This capstone is designed like a real DevOps interview/project demonstration.

---

# 1. Capstone Goal

By the end, you should be able to explain:

```text
I can provision and operate a Linux server.
I can run an application as a non-root service user.
I can manage it with systemd.
I can expose it safely through Nginx.
I can inspect logs, ports, processes, disk, CPU, memory, and network.
I can secure SSH and permissions.
I can create healthcheck and troubleshooting scripts.
I can document runbooks and interview answers.
```

This is the foundation before Docker, Kubernetes, Terraform, Ansible, and CI/CD.

---

# 2. Final Project Structure

Inside your repo:

```bash
cd ~/devops-masterclass
mkdir -p 03-linux-bash-networking/capstone-linux-vm/{app,systemd,nginx,scripts,docs,logs}
```

Expected structure:

```text
03-linux-bash-networking/capstone-linux-vm/
├── README.md
├── app/
│   ├── server.py
│   └── health.json
├── systemd/
│   └── demo-api.service
├── nginx/
│   └── demo-api.conf
├── scripts/
│   ├── install-demo-api.sh
│   ├── deploy-demo-api.sh
│   ├── validate-demo-api.sh
│   ├── rollback-demo-api.sh
│   └── uninstall-demo-api.sh
├── docs/
│   ├── runbook.md
│   ├── troubleshooting.md
│   ├── security-checklist.md
│   └── interview-review.md
└── logs/
    └── .gitkeep
```

Create:

```bash
cd ~/devops-masterclass
mkdir -p 03-linux-bash-networking/capstone-linux-vm/{app,systemd,nginx,scripts,docs,logs}
touch 03-linux-bash-networking/capstone-linux-vm/logs/.gitkeep
```

---

# 3. The Demo Application

We will create a small Python HTTP API.

Create:

```bash
nano 03-linux-bash-networking/capstone-linux-vm/app/server.py
```

Paste:

```python
#!/usr/bin/env python3

from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
import socket
import time
from datetime import datetime, timezone


APP_NAME = os.environ.get("APP_NAME", "demo-api")
APP_ENV = os.environ.get("APP_ENV", "dev")
APP_VERSION = os.environ.get("APP_VERSION", "0.1.0")
HOST = os.environ.get("HOST", "127.0.0.1")
PORT = int(os.environ.get("PORT", "8080"))


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def log(level, message, **fields):
    payload = {
        "timestamp": now_iso(),
        "level": level,
        "service": APP_NAME,
        "env": APP_ENV,
        "version": APP_VERSION,
        "message": message,
        **fields,
    }
    print(json.dumps(payload), flush=True)


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, status_code, payload):
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        start = time.time()

        if self.path == "/health":
            status_code = 200
            payload = {
                "status": "ok",
                "service": APP_NAME,
                "env": APP_ENV,
                "version": APP_VERSION,
                "hostname": socket.gethostname(),
                "time": now_iso(),
            }
        elif self.path == "/":
            status_code = 200
            payload = {
                "message": "Hello from Linux capstone demo-api",
                "service": APP_NAME,
                "version": APP_VERSION,
            }
        elif self.path == "/slow":
            time.sleep(2)
            status_code = 200
            payload = {
                "message": "slow response completed",
                "duration_seconds": 2,
            }
        elif self.path == "/error":
            status_code = 500
            payload = {
                "status": "error",
                "message": "simulated application error",
            }
        else:
            status_code = 404
            payload = {
                "status": "not_found",
                "path": self.path,
            }

        duration_ms = int((time.time() - start) * 1000)

        log(
            "INFO" if status_code < 500 else "ERROR",
            "request handled",
            method="GET",
            path=self.path,
            status=status_code,
            duration_ms=duration_ms,
            client=self.client_address[0],
        )

        self._send_json(status_code, payload)

    def log_message(self, format, *args):
        return


def main():
    log(
        "INFO",
        "starting server",
        host=HOST,
        port=PORT,
    )

    server = HTTPServer((HOST, PORT), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/capstone-linux-vm/app/server.py
```

Test locally:

```bash
cd ~/devops-masterclass/03-linux-bash-networking/capstone-linux-vm/app

APP_NAME=demo-api APP_ENV=dev APP_VERSION=0.1.0 HOST=127.0.0.1 PORT=8080 ./server.py
```

In another terminal:

```bash
curl -fsS http://127.0.0.1:8080/health | jq .
curl -i http://127.0.0.1:8080/
curl -i http://127.0.0.1:8080/error
```

Stop with:

```text
Ctrl+C
```

---

# 4. Create Environment File Template

Create:

```bash
nano 03-linux-bash-networking/capstone-linux-vm/app/demo-api.env.example
```

Paste:

```bash
APP_NAME=demo-api
APP_ENV=production
APP_VERSION=0.1.0
HOST=127.0.0.1
PORT=8080
```

Important:

```text
This file is safe to commit because it has no secrets.
Real env files under /etc should not be committed.
```

---

# 5. systemd Unit File

Create:

```bash
nano 03-linux-bash-networking/capstone-linux-vm/systemd/demo-api.service
```

Paste:

```ini
[Unit]
Description=Linux Capstone Demo API
Documentation=https://example.local/demo-api
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=demo-api
Group=demo-api
WorkingDirectory=/opt/demo-api/current
EnvironmentFile=/etc/demo-api/demo-api.env
ExecStart=/usr/bin/python3 /opt/demo-api/current/server.py
Restart=on-failure
RestartSec=3

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/opt/demo-api /var/log/demo-api

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Important directives:

```text
User=demo-api                  app does not run as root
EnvironmentFile=               config separated from code
Restart=on-failure             systemd restarts crashed app
NoNewPrivileges=true           prevents privilege escalation
PrivateTmp=true                private /tmp
ProtectSystem=full             protects system paths
ProtectHome=true               blocks home directories
ReadWritePaths=                explicitly writable paths
StandardOutput=journal         logs go to journalctl
```

This is much more professional than running:

```bash
python3 server.py
```

inside a terminal.

---

# 6. Nginx Reverse Proxy Config

Create:

```bash
nano 03-linux-bash-networking/capstone-linux-vm/nginx/demo-api.conf
```

Paste:

```nginx
server {
    listen 80;
    server_name _;

    access_log /var/log/nginx/demo-api-access.log;
    error_log  /var/log/nginx/demo-api-error.log;

    location / {
        proxy_pass http://127.0.0.1:8080;

        proxy_http_version 1.1;

        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 5s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    location /nginx-health {
        access_log off;
        return 200 "ok\n";
        add_header Content-Type text/plain;
    }
}
```

Architecture:

```text
User browser/client
  ↓
Nginx :80 on 0.0.0.0
  ↓
demo-api :8080 on 127.0.0.1
```

This means:

```text
Only Nginx is public.
The Python app is local-only.
```

That is a common production pattern.

---

# 7. Installation Script

Create:

```bash
nano 03-linux-bash-networking/capstone-linux-vm/scripts/install-demo-api.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="demo-api"
APP_USER="demo-api"
APP_GROUP="demo-api"
INSTALL_ROOT="/opt/demo-api"
RELEASES_DIR="$INSTALL_ROOT/releases"
CURRENT_LINK="$INSTALL_ROOT/current"
CONFIG_DIR="/etc/demo-api"
LOG_DIR="/var/log/demo-api"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

log() {
  echo "$(date -Is) [INFO] $*"
}

die() {
  echo "$(date -Is) [ERROR] $*" >&2
  exit 1
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "Run with sudo/root"
  fi
}

main() {
  require_root

  log "Installing $APP_NAME from $PROJECT_DIR"

  if ! id "$APP_USER" >/dev/null 2>&1; then
    log "Creating service user: $APP_USER"
    useradd --system --shell /usr/sbin/nologin --home "$INSTALL_ROOT" "$APP_USER"
  else
    log "Service user already exists: $APP_USER"
  fi

  log "Creating directories"
  mkdir -p "$RELEASES_DIR" "$CONFIG_DIR" "$LOG_DIR"

  chown -R "$APP_USER:$APP_GROUP" "$INSTALL_ROOT" "$LOG_DIR"
  chmod 750 "$INSTALL_ROOT" "$LOG_DIR"

  if [ ! -f "$CONFIG_DIR/demo-api.env" ]; then
    log "Creating env file"
    cp "$PROJECT_DIR/app/demo-api.env.example" "$CONFIG_DIR/demo-api.env"
    chown root:"$APP_GROUP" "$CONFIG_DIR/demo-api.env"
    chmod 640 "$CONFIG_DIR/demo-api.env"
  else
    log "Env file already exists: $CONFIG_DIR/demo-api.env"
  fi

  release_version="$(date +%Y%m%d-%H%M%S)"
  release_dir="$RELEASES_DIR/$release_version"

  log "Creating release: $release_dir"
  mkdir -p "$release_dir"
  cp "$PROJECT_DIR/app/server.py" "$release_dir/server.py"
  chmod +x "$release_dir/server.py"
  chown -R "$APP_USER:$APP_GROUP" "$release_dir"

  log "Updating current symlink"
  ln -sfn "$release_dir" "$CURRENT_LINK"
  chown -h "$APP_USER:$APP_GROUP" "$CURRENT_LINK"

  log "Installing systemd unit"
  cp "$PROJECT_DIR/systemd/demo-api.service" /etc/systemd/system/demo-api.service
  systemctl daemon-reload
  systemctl enable demo-api.service

  log "Starting service"
  systemctl restart demo-api.service

  log "Validating service"
  systemctl is-active --quiet demo-api.service
  curl -fsS http://127.0.0.1:8080/health >/dev/null

  log "Install completed successfully"
  systemctl status demo-api.service --no-pager
}

main "$@"
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/capstone-linux-vm/scripts/install-demo-api.sh
```

Run:

```bash
cd ~/devops-masterclass
sudo ./03-linux-bash-networking/capstone-linux-vm/scripts/install-demo-api.sh
```

Validate:

```bash
systemctl status demo-api --no-pager
journalctl -u demo-api -n 50 --no-pager
curl -fsS http://127.0.0.1:8080/health | jq .
sudo ss -tulnp | grep ':8080'
```

---

# 8. Install Nginx Reverse Proxy

Install Nginx:

```bash
sudo apt update
sudo apt install -y nginx
```

Copy config:

```bash
sudo cp ~/devops-masterclass/03-linux-bash-networking/capstone-linux-vm/nginx/demo-api.conf /etc/nginx/sites-available/demo-api.conf
```

Enable site:

```bash
sudo ln -sfn /etc/nginx/sites-available/demo-api.conf /etc/nginx/sites-enabled/demo-api.conf
```

Optional: disable default site:

```bash
sudo rm -f /etc/nginx/sites-enabled/default
```

Test:

```bash
sudo nginx -t
```

Reload:

```bash
sudo systemctl reload nginx
```

Validate:

```bash
curl -i http://127.0.0.1/
curl -i http://127.0.0.1/health
curl -i http://127.0.0.1/nginx-health
```

Check ports:

```bash
sudo ss -tulnp | grep -E ':80|:8080'
```

Expected:

```text
Nginx listens on 0.0.0.0:80
demo-api listens on 127.0.0.1:8080
```

---

# 9. Deployment Script

Create:

```bash
nano 03-linux-bash-networking/capstone-linux-vm/scripts/deploy-demo-api.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="demo-api"
APP_USER="demo-api"
APP_GROUP="demo-api"
INSTALL_ROOT="/opt/demo-api"
RELEASES_DIR="$INSTALL_ROOT/releases"
CURRENT_LINK="$INSTALL_ROOT/current"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

VERSION="${1:-}"

log() {
  echo "$(date -Is) [INFO] $*"
}

warn() {
  echo "$(date -Is) [WARN] $*" >&2
}

die() {
  echo "$(date -Is) [ERROR] $*" >&2
  exit 1
}

usage() {
  echo "Usage: $0 <version>" >&2
  echo "Example: $0 0.1.1" >&2
}

retry() {
  local attempts="$1"
  local delay="$2"
  shift 2

  local attempt=1

  until "$@"; do
    if [ "$attempt" -ge "$attempts" ]; then
      return 1
    fi

    warn "Attempt $attempt/$attempts failed. Retrying in ${delay}s..."
    sleep "$delay"
    attempt=$((attempt + 1))
  done
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "Run with sudo/root"
  fi
}

main() {
  require_root

  [ -n "$VERSION" ] || {
    usage
    exit 1
  }

  [ -f "$PROJECT_DIR/app/server.py" ] || die "Missing app/server.py"

  previous_release=""
  if [ -L "$CURRENT_LINK" ]; then
    previous_release="$(readlink -f "$CURRENT_LINK")"
  fi

  release_dir="$RELEASES_DIR/$VERSION-$(date +%Y%m%d-%H%M%S)"

  log "Deploying version $VERSION"
  log "Previous release: ${previous_release:-none}"
  log "New release: $release_dir"

  mkdir -p "$release_dir"
  cp "$PROJECT_DIR/app/server.py" "$release_dir/server.py"
  chmod +x "$release_dir/server.py"
  chown -R "$APP_USER:$APP_GROUP" "$release_dir"

  log "Updating APP_VERSION in env file"
  if [ -f /etc/demo-api/demo-api.env ]; then
    if grep -q '^APP_VERSION=' /etc/demo-api/demo-api.env; then
      sed -i "s/^APP_VERSION=.*/APP_VERSION=$VERSION/" /etc/demo-api/demo-api.env
    else
      echo "APP_VERSION=$VERSION" >> /etc/demo-api/demo-api.env
    fi
  else
    die "/etc/demo-api/demo-api.env missing"
  fi

  log "Switching symlink"
  ln -sfn "$release_dir" "$CURRENT_LINK"
  chown -h "$APP_USER:$APP_GROUP" "$CURRENT_LINK"

  log "Restarting service"
  systemctl restart "$APP_NAME"

  log "Running health check"
  if retry 10 2 curl -fsS http://127.0.0.1:8080/health >/dev/null; then
    log "Deployment healthy"
  else
    warn "Health check failed"

    if [ -n "$previous_release" ] && [ -d "$previous_release" ]; then
      warn "Rolling back to $previous_release"
      ln -sfn "$previous_release" "$CURRENT_LINK"
      chown -h "$APP_USER:$APP_GROUP" "$CURRENT_LINK"
      systemctl restart "$APP_NAME"
      retry 10 2 curl -fsS http://127.0.0.1:8080/health >/dev/null \
        || die "Rollback health check failed"
      die "Deployment failed. Rolled back to previous release."
    else
      die "Deployment failed and no previous release available"
    fi
  fi

  systemctl status "$APP_NAME" --no-pager
}

main "$@"
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/capstone-linux-vm/scripts/deploy-demo-api.sh
```

Deploy:

```bash
sudo ./03-linux-bash-networking/capstone-linux-vm/scripts/deploy-demo-api.sh 0.1.1
```

Validate:

```bash
curl -fsS http://127.0.0.1:8080/health | jq .
readlink -f /opt/demo-api/current
journalctl -u demo-api -n 30 --no-pager
```

---

# 10. Validation Script

Create:

```bash
nano 03-linux-bash-networking/capstone-linux-vm/scripts/validate-demo-api.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SERVICE="demo-api"
LOCAL_URL="http://127.0.0.1:8080/health"
NGINX_URL="http://127.0.0.1/health"

section() {
  echo
  echo "============================================================"
  echo "$*"
  echo "============================================================"
}

section "Service Status"
systemctl status "$SERVICE" --no-pager || true

section "Service Active Check"
systemctl is-active --quiet "$SERVICE"
echo "OK: $SERVICE is active"

section "Listening Ports"
sudo ss -tulnp | grep -E ':80|:8080' || true

section "Local App Health"
curl -fsS "$LOCAL_URL" | jq . || curl -fsS "$LOCAL_URL"

section "Nginx Proxy Health"
curl -i "$NGINX_URL"

section "Recent Service Logs"
journalctl -u "$SERVICE" -n 50 --no-pager

section "Nginx Error Logs"
sudo tail -n 50 /var/log/nginx/demo-api-error.log 2>/dev/null || true

section "System Resources"
uptime
free -h
df -h
df -i

echo
echo "Validation completed."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/capstone-linux-vm/scripts/validate-demo-api.sh
```

Run:

```bash
./03-linux-bash-networking/capstone-linux-vm/scripts/validate-demo-api.sh
```

---

# 11. Rollback Script

Create:

```bash
nano 03-linux-bash-networking/capstone-linux-vm/scripts/rollback-demo-api.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="demo-api"
INSTALL_ROOT="/opt/demo-api"
RELEASES_DIR="$INSTALL_ROOT/releases"
CURRENT_LINK="$INSTALL_ROOT/current"
TARGET_RELEASE="${1:-}"

usage() {
  echo "Usage: $0 <release-directory-name-or-full-path>" >&2
  echo "Available releases:" >&2
  ls -1 "$RELEASES_DIR" 2>/dev/null || true
}

die() {
  echo "$(date -Is) [ERROR] $*" >&2
  exit 1
}

log() {
  echo "$(date -Is) [INFO] $*"
}

if [ "$(id -u)" -ne 0 ]; then
  die "Run with sudo/root"
fi

if [ -z "$TARGET_RELEASE" ]; then
  usage
  exit 1
fi

if [[ "$TARGET_RELEASE" = /* ]]; then
  release_path="$TARGET_RELEASE"
else
  release_path="$RELEASES_DIR/$TARGET_RELEASE"
fi

[ -d "$release_path" ] || die "Release not found: $release_path"

log "Rolling back $APP_NAME to $release_path"

ln -sfn "$release_path" "$CURRENT_LINK"
chown -h demo-api:demo-api "$CURRENT_LINK"

systemctl restart "$APP_NAME"

for i in {1..10}; do
  if curl -fsS http://127.0.0.1:8080/health >/dev/null; then
    log "Rollback health check passed"
    systemctl status "$APP_NAME" --no-pager
    exit 0
  fi

  log "Waiting for health check... attempt $i/10"
  sleep 2
done

die "Rollback failed health check"
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/capstone-linux-vm/scripts/rollback-demo-api.sh
```

List releases:

```bash
ls -1 /opt/demo-api/releases
```

Rollback:

```bash
sudo ./03-linux-bash-networking/capstone-linux-vm/scripts/rollback-demo-api.sh <release-name>
```

---

# 12. Uninstall Script

Create:

```bash
nano 03-linux-bash-networking/capstone-linux-vm/scripts/uninstall-demo-api.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="demo-api"

confirm() {
  read -r -p "This will remove demo-api service files and install directories. Type yes: " answer
  [ "$answer" = "yes" ]
}

die() {
  echo "$(date -Is) [ERROR] $*" >&2
  exit 1
}

if [ "$(id -u)" -ne 0 ]; then
  die "Run with sudo/root"
fi

confirm || {
  echo "Aborted"
  exit 1
}

systemctl disable --now "$APP_NAME" 2>/dev/null || true
rm -f /etc/systemd/system/demo-api.service
systemctl daemon-reload

rm -f /etc/nginx/sites-enabled/demo-api.conf
rm -f /etc/nginx/sites-available/demo-api.conf
nginx -t && systemctl reload nginx || true

rm -rf /opt/demo-api
rm -rf /etc/demo-api
rm -rf /var/log/demo-api

echo "demo-api removed."
echo "Service user demo-api was not deleted automatically."
echo "To delete user manually: sudo userdel demo-api"
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/capstone-linux-vm/scripts/uninstall-demo-api.sh
```

Do not run this unless you want to remove the capstone app.

---

# 13. Logging and Journal Checks

Check application logs:

```bash
journalctl -u demo-api -f
```

Generate requests:

```bash
curl http://127.0.0.1/
curl http://127.0.0.1/health
curl http://127.0.0.1/error
curl http://127.0.0.1/not-found
```

Check logs:

```bash
journalctl -u demo-api -n 100 --no-pager
```

You should see JSON logs.

Filter errors:

```bash
journalctl -u demo-api --since "10 minutes ago" -o cat | grep '"level": "ERROR"'
```

Nginx logs:

```bash
sudo tail -f /var/log/nginx/demo-api-access.log
sudo tail -f /var/log/nginx/demo-api-error.log
```

---

# 14. logrotate Config

Create:

```bash
nano 03-linux-bash-networking/capstone-linux-vm/systemd/demo-api-logrotate.conf
```

Paste:

```text
/var/log/nginx/demo-api-*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        systemctl reload nginx >/dev/null 2>&1 || true
    endscript
}
```

Install:

```bash
sudo cp 03-linux-bash-networking/capstone-linux-vm/systemd/demo-api-logrotate.conf /etc/logrotate.d/demo-api
```

Test dry run:

```bash
sudo logrotate -d /etc/logrotate.d/demo-api
```

Force only for testing:

```bash
sudo logrotate -f /etc/logrotate.d/demo-api
```

Check:

```bash
ls -lh /var/log/nginx/demo-api-*
```

---

# 15. Firewall Baseline

If this is a real remote VM, be careful.

Check:

```bash
sudo ufw status verbose
```

Allow SSH first:

```bash
sudo ufw allow OpenSSH
```

Allow HTTP:

```bash
sudo ufw allow 80/tcp
```

Do not expose app port 8080 publicly:

```bash
sudo ufw deny 8080/tcp
```

Enable only after verifying SSH rule:

```bash
sudo ufw enable
```

Check:

```bash
sudo ufw status numbered
```

Security design:

```text
Public:
  22/tcp restricted
  80/tcp allowed
  443/tcp allowed later

Private/local:
  8080/tcp local only
```

Because app binds to `127.0.0.1`, it is already local-only, but firewall adds another layer.

---

# 16. Break and Debug Labs

These labs intentionally break things.

## Break 1 — Stop the Service

```bash
sudo systemctl stop demo-api
```

Symptom:

```bash
curl -i http://127.0.0.1/health
```

Likely Nginx returns 502.

Debug:

```bash
sudo systemctl status demo-api --no-pager
journalctl -u demo-api -n 50 --no-pager
sudo tail -n 50 /var/log/nginx/demo-api-error.log
sudo ss -tulnp | grep ':8080'
```

Fix:

```bash
sudo systemctl start demo-api
curl -fsS http://127.0.0.1/health
```

---

## Break 2 — Wrong Permission

Break:

```bash
sudo chmod 000 /opt/demo-api/current/server.py
sudo systemctl restart demo-api
```

Debug:

```bash
systemctl status demo-api --no-pager
journalctl -u demo-api -n 50 --no-pager
namei -l /opt/demo-api/current/server.py
ls -l /opt/demo-api/current/server.py
```

Fix:

```bash
sudo chmod 755 /opt/demo-api/current/server.py
sudo chown demo-api:demo-api /opt/demo-api/current/server.py
sudo systemctl restart demo-api
curl -fsS http://127.0.0.1:8080/health
```

---

## Break 3 — Wrong Env Port

Break:

```bash
sudo sed -i 's/^PORT=.*/PORT=9999/' /etc/demo-api/demo-api.env
sudo systemctl restart demo-api
```

Nginx still points to `127.0.0.1:8080`.

Symptom:

```bash
curl -i http://127.0.0.1/health
```

Debug:

```bash
sudo ss -tulnp | grep -E ':8080|:9999'
journalctl -u demo-api -n 50 --no-pager
sudo tail -n 50 /var/log/nginx/demo-api-error.log
```

Fix:

```bash
sudo sed -i 's/^PORT=.*/PORT=8080/' /etc/demo-api/demo-api.env
sudo systemctl restart demo-api
curl -fsS http://127.0.0.1/health
```

---

## Break 4 — Bad Nginx Config

Break carefully:

```bash
sudo cp -a /etc/nginx/sites-available/demo-api.conf /etc/nginx/sites-available/demo-api.conf.bak
sudo sed -i 's/127.0.0.1:8080/127.0.0.1:9999/' /etc/nginx/sites-available/demo-api.conf
sudo nginx -t
sudo systemctl reload nginx
```

Symptom:

```bash
curl -i http://127.0.0.1/health
```

Debug:

```bash
sudo nginx -t
sudo tail -n 50 /var/log/nginx/demo-api-error.log
sudo ss -tulnp | grep -E ':8080|:9999'
curl -v http://127.0.0.1:8080/health
```

Fix:

```bash
sudo cp -a /etc/nginx/sites-available/demo-api.conf.bak /etc/nginx/sites-available/demo-api.conf
sudo nginx -t
sudo systemctl reload nginx
curl -fsS http://127.0.0.1/health
```

---

# 17. Capstone Runbook

Create:

```bash
nano 03-linux-bash-networking/capstone-linux-vm/docs/runbook.md
```

Paste:

````markdown
# Demo API Runbook

## Service

Service name:

```bash
demo-api
````

## Paths

| Item             | Path                                       |
| ---------------- | ------------------------------------------ |
| Install root     | `/opt/demo-api`                            |
| Current symlink  | `/opt/demo-api/current`                    |
| Releases         | `/opt/demo-api/releases`                   |
| Env file         | `/etc/demo-api/demo-api.env`               |
| systemd unit     | `/etc/systemd/system/demo-api.service`     |
| Nginx config     | `/etc/nginx/sites-available/demo-api.conf` |
| Nginx access log | `/var/log/nginx/demo-api-access.log`       |
| Nginx error log  | `/var/log/nginx/demo-api-error.log`        |

## Commands

Status:

```bash
systemctl status demo-api --no-pager
```

Logs:

```bash
journalctl -u demo-api -f
journalctl -u demo-api -n 100 --no-pager
```

Restart:

```bash
sudo systemctl restart demo-api
```

Health:

```bash
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1/health
```

Ports:

```bash
sudo ss -tulnp | grep -E ':80|:8080'
```

Nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
sudo tail -n 100 /var/log/nginx/demo-api-error.log
```

Deploy:

```bash
sudo ./scripts/deploy-demo-api.sh 0.1.1
```

Validate:

```bash
./scripts/validate-demo-api.sh
```

Rollback:

```bash
ls -1 /opt/demo-api/releases
sudo ./scripts/rollback-demo-api.sh <release-name>
```

````

---

# 18. Troubleshooting Doc

Create:

```bash
nano 03-linux-bash-networking/capstone-linux-vm/docs/troubleshooting.md
````

Paste:

````markdown
# Demo API Troubleshooting

## 502 from Nginx

Check Nginx error log:

```bash
sudo tail -n 100 /var/log/nginx/demo-api-error.log
````

Check backend port:

```bash
sudo ss -tulnp | grep ':8080'
```

Check backend health:

```bash
curl -v http://127.0.0.1:8080/health
```

Check service:

```bash
systemctl status demo-api --no-pager
journalctl -u demo-api -n 100 --no-pager
```

## Service Not Starting

```bash
systemctl status demo-api --no-pager
journalctl -u demo-api -n 100 --no-pager
systemctl cat demo-api
```

Check:

* env file exists
* service user exists
* paths exist
* permissions are correct
* Python path is correct
* port not already in use

## Permission Denied

```bash
systemctl show demo-api -p User -p Group
namei -l /opt/demo-api/current/server.py
ls -l /etc/demo-api/demo-api.env
sudo -u demo-api cat /etc/demo-api/demo-api.env
```

## Port Already in Use

```bash
sudo ss -tulnp | grep ':8080'
sudo lsof -i :8080
```

## Disk Full

```bash
df -h
df -i
sudo du -xhd1 / | sort -hr | head
sudo lsof +L1
```

## High CPU or Memory

```bash
uptime
free -h
ps -eo pid,user,%cpu,%mem,rss,cmd --sort=-%cpu | head
ps -eo pid,user,%cpu,%mem,rss,cmd --sort=-rss | head
```

````

---

# 19. Security Checklist

Create:

```bash
nano 03-linux-bash-networking/capstone-linux-vm/docs/security-checklist.md
````

Paste:

```markdown
# Demo API Security Checklist

## Service User

- [ ] App runs as `demo-api`, not root.
- [ ] `demo-api` uses `/usr/sbin/nologin`.
- [ ] App files owned by `demo-api:demo-api`.
- [ ] Env file is not world-readable.

## systemd

- [ ] `User=demo-api`
- [ ] `Group=demo-api`
- [ ] `NoNewPrivileges=true`
- [ ] `PrivateTmp=true`
- [ ] `ProtectSystem=full`
- [ ] `ProtectHome=true`

## Network

- [ ] Python app listens on `127.0.0.1:8080`.
- [ ] Nginx listens on public port `80`.
- [ ] App port `8080` is not exposed publicly.
- [ ] Firewall allows only required ports.

## Secrets

- [ ] Real env files are not committed.
- [ ] `.env.example` contains no real secrets.
- [ ] `/etc/demo-api/demo-api.env` permission is `640` or stricter.

## Logs

- [ ] Application logs go to journald.
- [ ] Nginx logs have logrotate.
- [ ] Logs do not contain secrets.
```

---

# 20. Interview Review

Create:

```bash
nano 03-linux-bash-networking/capstone-linux-vm/docs/interview-review.md
```

Paste:

```markdown
# Linux Capstone Interview Review

## Project Explanation

I built a production-style Linux VM capstone where a Python API runs as a non-root systemd service behind Nginx. The app listens only on localhost, while Nginx exposes port 80 and proxies requests to the app. I configured a dedicated service user, environment file, systemd hardening options, health checks, logs through journald, Nginx access/error logs, logrotate, deployment and rollback scripts, and troubleshooting runbooks.

## Why run the app as a non-root user?

Running the app as a non-root service user limits blast radius. If the app is compromised, the attacker gets only the service user's permissions instead of root.

## Why use Nginx in front?

Nginx handles public HTTP traffic, reverse proxying, headers, timeouts, logging, and later TLS. It allows the backend app to stay private on `127.0.0.1`.

## How do you debug 502?

I check Nginx error logs, verify the backend is listening on the expected port, curl the backend health endpoint directly, check systemd service status and logs, and verify resource issues like CPU, memory, and disk.

## How does rollback work?

The deployment creates versioned release directories under `/opt/demo-api/releases` and updates `/opt/demo-api/current` as a symlink. Rollback repoints the symlink to a previous release and restarts the service.

## What Linux skills are demonstrated?

- systemd
- journald
- Nginx reverse proxy
- service users
- permissions
- environment files
- ports and networking
- logrotate
- Bash automation
- health checks
- deployment and rollback
- troubleshooting playbooks
- Linux security basics
```

---

# 21. Main Capstone README

Create:

```bash
nano 03-linux-bash-networking/capstone-linux-vm/README.md
```

Paste:

````markdown
# Linux VM Capstone: Secure Service Deployment

This capstone demonstrates Linux, Bash, networking, systemd, Nginx, logging, security, and troubleshooting fundamentals.

## Architecture

```text
Client
  ↓
Nginx :80
  ↓
demo-api :8080 on 127.0.0.1
  ↓
systemd manages demo-api
````

## Components

* Python demo API
* Dedicated `demo-api` service user
* systemd service unit
* Nginx reverse proxy
* journald logs
* Nginx access/error logs
* logrotate config
* install/deploy/validate/rollback scripts
* runbook and troubleshooting docs

## Install

```bash
sudo ./scripts/install-demo-api.sh
```

## Nginx Setup

```bash
sudo apt update
sudo apt install -y nginx
sudo cp nginx/demo-api.conf /etc/nginx/sites-available/demo-api.conf
sudo ln -sfn /etc/nginx/sites-available/demo-api.conf /etc/nginx/sites-enabled/demo-api.conf
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

## Validate

```bash
./scripts/validate-demo-api.sh
```

## Deploy

```bash
sudo ./scripts/deploy-demo-api.sh 0.1.1
```

## Rollback

```bash
ls -1 /opt/demo-api/releases
sudo ./scripts/rollback-demo-api.sh <release-name>
```

## Logs

```bash
journalctl -u demo-api -f
sudo tail -f /var/log/nginx/demo-api-access.log
sudo tail -f /var/log/nginx/demo-api-error.log
```

## Health Checks

```bash
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1/health
```

## Security Model

* App runs as `demo-api`, not root.
* App binds to `127.0.0.1`.
* Nginx exposes port `80`.
* Env file lives in `/etc/demo-api/demo-api.env`.
* systemd hardening options are enabled.

````

---

# 22. Final Validation Checklist

Run:

```bash
cd ~/devops-masterclass/03-linux-bash-networking/capstone-linux-vm

./scripts/validate-demo-api.sh
````

Manual checks:

```bash
systemctl status demo-api --no-pager
journalctl -u demo-api -n 50 --no-pager
curl -fsS http://127.0.0.1:8080/health | jq .
curl -i http://127.0.0.1/health
sudo nginx -t
sudo ss -tulnp | grep -E ':80|:8080'
ls -l /etc/demo-api/demo-api.env
readlink -f /opt/demo-api/current
```

Security checks:

```bash
id demo-api
getent passwd demo-api
systemctl cat demo-api
sudo ufw status verbose
```

Troubleshooting checks:

```bash
../scripts/first-response-triage.sh
../scripts/service-incident-debug.sh demo-api 8080 http://127.0.0.1:8080/health
```

---

# 23. Commit Capstone

Run from repo root:

```bash
cd ~/devops-masterclass

git status
git diff
```

Add:

```bash
git add 03-linux-bash-networking/capstone-linux-vm
```

Review:

```bash
git diff --staged
```

Commit:

```bash
git commit -m "feat: add Linux VM capstone"
```

Push:

```bash
git push
```

Tag module completion:

```bash
git tag -a v0.3.0 -m "Complete Linux Bash Networking module"
git push origin v0.3.0
```

---

# 24. What You Can Now Say in an Interview

Use this answer:

```text
In my Linux module capstone, I deployed a Python API as a secure systemd service behind Nginx. I created a dedicated non-root service user, configured environment files under /etc, managed versioned releases under /opt, used a current symlink for atomic-style deployment, and added rollback capability. The app listens only on localhost, while Nginx exposes port 80 and proxies to it. I configured journald logs, Nginx access and error logs, logrotate, healthcheck scripts, service validation, and troubleshooting runbooks. I also documented security checks, including SSH hardening, least privilege, file permissions, and firewall principles.
```

That is a strong DevOps foundation answer.

---

# 25. Module 3 Final Review

You completed:

```text
Linux mental model
Filesystem
File operations
Text processing
Permissions
Users and groups
sudo
SSH
Processes
systemd
Logs
Disk and storage
CPU and memory troubleshooting
Bash scripting
Advanced Bash
Bash automation toolkit
Networking foundation
Deep networking troubleshooting
Linux security basics
Troubleshooting playbooks
Linux VM capstone
```

This is a serious foundation.

Now Docker will make much more sense because Docker uses many of these Linux concepts:

```text
Processes
Namespaces
Filesystems
Mounts
Users
Ports
Networking
Logs
Resource limits
Security boundaries
```

---

# Today’s Core Rules

```text
Run apps as non-root users.
Use systemd for long-running VM services.
Use Nginx as a reverse proxy.
Keep backend app ports private where possible.
Use health checks after deployment.
Use logs as evidence.
Use versioned releases and symlinks for rollback.
Use least privilege for files, users, and services.
Validate before and after every change.
Document runbooks and troubleshooting steps.
```

Next module:

# Module 4 — Python for DevOps Automation

Next lesson:

# Lesson 4.1 — Python for DevOps: Why Python, virtual environments, CLI scripts, subprocess, pathlib, JSON/YAML, requests, and automation structure.

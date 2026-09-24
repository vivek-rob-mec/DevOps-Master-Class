# Lesson 5.4 — Process Managers: PM2 and systemd for Production Node.js Apps

Until now, we ran the app manually:

```bash
npm start
```

That is fine for learning, but not for production.

In production, an app needs:

```text
automatic restart
startup on boot
log handling
status checks
controlled stop/start/restart
environment management
graceful shutdown
process monitoring
```

That is the job of a **process manager**.

Today we will learn two important process managers:

```text
PM2
systemd
```

---

# 1. Why Manual App Start Is Not Production-Ready

Bad production style:

```bash
node server.js
```

or:

```bash
npm start
```

Problem:

```text
terminal closes → app stops
server reboots → app does not start automatically
crash happens → app stays down
logs are not managed properly
no standard status command
no restart policy
```

Production apps should be controlled by something like:

```text
PM2
systemd
Docker
Kubernetes
supervisor
```

In this module, we focus on PM2 and systemd.

---

# 2. PM2 vs systemd

| Tool       | Best For                                   |
| ---------- | ------------------------------------------ |
| PM2        | Node.js apps, quick app process management |
| systemd    | Linux-native service management            |
| Docker     | containerized process runtime              |
| Kubernetes | container orchestration                    |

Simple difference:

```text
PM2 understands Node.js app workflows.
systemd understands Linux service lifecycle.
```

Both can run a Node app.

---

# 3. PM2 Mental Model

PM2 manages Node.js processes.

It can:

```text
start app
restart app
stop app
show logs
restart on crash
save process list
start processes after reboot
run cluster mode
manage env-specific config
```

Common commands:

```bash
pm2 start server.js --name demo-node-api
pm2 list
pm2 logs demo-node-api
pm2 restart demo-node-api
pm2 stop demo-node-api
pm2 delete demo-node-api
pm2 save
pm2 startup
```

---

# 4. Install PM2

Go to your app:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api
```

Install PM2 globally:

```bash
sudo npm install -g pm2
```

Check:

```bash
pm2 --version
which pm2
```

---

# 5. Start App with PM2

Start the app:

```bash
APP_ENV=dev \
PORT=3000 \
LOG_LEVEL=info \
LOAD_DOTENV=false \
pm2 start server.js --name demo-node-api
```

Check process:

```bash
pm2 list
```

Check logs:

```bash
pm2 logs demo-node-api
```

Check app:

```bash
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/version | jq .
```

Check Linux process:

```bash
pgrep -a node
ss -tuln | grep ':3000'
```

---

# 6. PM2 Basic Operations

Restart:

```bash
pm2 restart demo-node-api
```

Stop:

```bash
pm2 stop demo-node-api
```

Start again:

```bash
pm2 start demo-node-api
```

Delete from PM2:

```bash
pm2 delete demo-node-api
```

Show details:

```bash
pm2 show demo-node-api
```

Monitor:

```bash
pm2 monit
```

Exit monitor:

```text
q
```

---

# 7. PM2 Logs

View logs:

```bash
pm2 logs demo-node-api
```

Only last lines:

```bash
pm2 logs demo-node-api --lines 100
```

Flush PM2 logs:

```bash
pm2 flush demo-node-api
```

PM2 log files are usually under:

```bash
~/.pm2/logs/
```

Check:

```bash
ls -lh ~/.pm2/logs/
```

Because our app logs JSON, you can parse PM2 logs too:

```bash
cat ~/.pm2/logs/demo-node-api-out.log | tail -n 20
cat ~/.pm2/logs/demo-node-api-error.log | tail -n 20
```

---

# 8. PM2 Ecosystem File

Running with many inline env vars is messy.

Better use an ecosystem config.

Create:

```bash
nano ecosystem.config.js
```

Paste:

```javascript
module.exports = {
  apps: [
    {
      name: "demo-node-api",
      script: "server.js",
      instances: 1,
      exec_mode: "fork",
      env: {
        APP_NAME: "demo-node-api",
        APP_ENV: "dev",
        APP_VERSION: "0.1.0",
        COMMIT_SHA: "local",
        PORT: 3000,
        LOG_LEVEL: "info",
        LOAD_DOTENV: "false",
        ENABLE_CACHE: "false",
        REQUEST_TIMEOUT_MS: 5000
      },
      env_staging: {
        APP_NAME: "demo-node-api",
        APP_ENV: "staging",
        APP_VERSION: "0.1.0",
        COMMIT_SHA: "staging",
        PORT: 3000,
        LOG_LEVEL: "info",
        LOAD_DOTENV: "false",
        ENABLE_CACHE: "false",
        REQUEST_TIMEOUT_MS: 5000
      },
      env_production: {
        APP_NAME: "demo-node-api",
        APP_ENV: "prod",
        APP_VERSION: "0.1.0",
        COMMIT_SHA: "prod",
        PORT: 3000,
        LOG_LEVEL: "info",
        LOAD_DOTENV: "false",
        DATABASE_URL: "mongodb://localhost:27017/demo",
        CORS_ORIGIN: "https://example.com",
        ENABLE_CACHE: "true",
        REQUEST_TIMEOUT_MS: 5000
      },
      max_memory_restart: "300M",
      kill_timeout: 10000,
      restart_delay: 2000
    }
  ]
};
```

Start dev:

```bash
pm2 start ecosystem.config.js
```

Restart with staging env:

```bash
pm2 restart ecosystem.config.js --env staging
```

Restart with production env:

```bash
pm2 restart ecosystem.config.js --env production
```

Check:

```bash
curl -s http://127.0.0.1:3000/config-summary | jq .
```

---

# 9. PM2 Important Config Options

## `name`

```javascript
name: "demo-node-api"
```

This is the PM2 process name.

## `script`

```javascript
script: "server.js"
```

This is the app entrypoint.

## `instances`

```javascript
instances: 1
```

Number of app instances.

For cluster mode:

```javascript
instances: "max"
```

We will keep `1` for now.

## `exec_mode`

```javascript
exec_mode: "fork"
```

Simple mode.

Cluster mode:

```javascript
exec_mode: "cluster"
```

Cluster mode is useful for using multiple CPU cores, but it needs more careful behavior.

## `max_memory_restart`

```javascript
max_memory_restart: "300M"
```

If the process uses more memory, PM2 restarts it.

## `kill_timeout`

```javascript
kill_timeout: 10000
```

How long PM2 waits before force killing after stop/restart.

This matches our graceful shutdown timeout.

---

# 10. PM2 Startup on Boot

PM2 can generate startup integration.

Run:

```bash
pm2 startup
```

PM2 will print a command. Copy and run that command with `sudo`.

Then save current process list:

```bash
pm2 save
```

Check saved dump:

```bash
ls -lh ~/.pm2/dump.pm2
```

Core rule:

```text
pm2 start starts the app now.
pm2 save saves the app list for reboot restore.
pm2 startup configures boot integration.
```

Without `pm2 save`, reboot behavior may not include your current app list.

---

# 11. PM2 Crash Restart Test

Start app:

```bash
pm2 start ecosystem.config.js
```

Find process:

```bash
pm2 list
pgrep -a node
```

Kill Node process manually:

```bash
PID=$(pgrep -f "node.*server.js" | head -n 1)
kill -9 "$PID"
```

Check PM2:

```bash
pm2 list
pm2 logs demo-node-api --lines 50
```

PM2 should restart it.

This is a major production feature.

---

# 12. systemd Mental Model

`systemd` is the native Linux service manager.

It manages services like:

```text
nginx
ssh
docker
postgresql
your application
```

Common commands:

```bash
sudo systemctl start service
sudo systemctl stop service
sudo systemctl restart service
sudo systemctl status service
sudo systemctl enable service
sudo systemctl disable service
journalctl -u service -f
```

Important states:

```text
active
inactive
failed
activating
deactivating
```

---

# 13. PM2 vs systemd in Production

Use PM2 when:

```text
you want quick Node.js process management
you need PM2 logs and process list
you use ecosystem.config.js
your deployment already uses PM2
```

Use systemd when:

```text
you want Linux-native service management
you want consistent VM service behavior
you want service user isolation
you want journald logging
you want explicit dependency ordering
```

For your Jenkins atomic deployment with PM2, PM2 is practical.

For a Linux service capstone, systemd is more universal.

---

# 14. Create a Dedicated Linux User

Production apps should not usually run as root.

Create a system user:

```bash
sudo useradd --system --create-home --shell /usr/sbin/nologin demoapp
```

Check:

```bash
id demoapp
getent passwd demoapp
```

Create app directory:

```bash
sudo mkdir -p /opt/demo-node-api
sudo chown -R demoapp:demoapp /opt/demo-node-api
```

Copy app files:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api

sudo rsync -av \
  --exclude node_modules \
  --exclude .env \
  --exclude app.log \
  --exclude error.log \
  ./ /opt/demo-node-api/
```

Install dependencies as root or app user.

Option 1:

```bash
cd /opt/demo-node-api
sudo npm install --omit=dev
sudo chown -R demoapp:demoapp /opt/demo-node-api
```

Better in mature production:

```text
build artifact contains node_modules or uses npm ci --omit=dev during deployment
```

---

# 15. Create Environment File for systemd

Create config directory:

```bash
sudo mkdir -p /etc/demo-node-api
```

Create env file:

```bash
sudo nano /etc/demo-node-api/demo-node-api.env
```

Paste:

```bash
APP_NAME=demo-node-api
APP_ENV=prod
APP_VERSION=0.1.0
COMMIT_SHA=local-systemd
PORT=3000
LOG_LEVEL=info
LOAD_DOTENV=false
DATABASE_URL=mongodb://localhost:27017/demo
CORS_ORIGIN=https://example.com
ENABLE_CACHE=true
REQUEST_TIMEOUT_MS=5000
```

Set permissions:

```bash
sudo chown root:demoapp /etc/demo-node-api/demo-node-api.env
sudo chmod 640 /etc/demo-node-api/demo-node-api.env
```

Check:

```bash
ls -l /etc/demo-node-api/demo-node-api.env
```

Expected:

```text
-rw-r----- root demoapp
```

---

# 16. Create systemd Service

Create:

```bash
sudo nano /etc/systemd/system/demo-node-api.service
```

Paste:

```ini
[Unit]
Description=Demo Node API
After=network.target

[Service]
Type=simple
User=demoapp
Group=demoapp
WorkingDirectory=/opt/demo-node-api
EnvironmentFile=/etc/demo-node-api/demo-node-api.env
ExecStart=/usr/bin/node /opt/demo-node-api/server.js
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

If your Node path is not `/usr/bin/node`, update `ExecStart`.

Example:

```ini
ExecStart=/usr/local/bin/node /opt/demo-node-api/server.js
```

---

# 17. Start systemd Service

Reload systemd:

```bash
sudo systemctl daemon-reload
```

Start:

```bash
sudo systemctl start demo-node-api
```

Check status:

```bash
sudo systemctl status demo-node-api --no-pager
```

Enable on boot:

```bash
sudo systemctl enable demo-node-api
```

Check app:

```bash
curl -s http://127.0.0.1:3000/health | jq .
curl -s http://127.0.0.1:3000/config-summary | jq .
```

Logs:

```bash
journalctl -u demo-node-api -n 100 --no-pager
journalctl -u demo-node-api -f
```

---

# 18. systemd Operations

Restart:

```bash
sudo systemctl restart demo-node-api
```

Stop:

```bash
sudo systemctl stop demo-node-api
```

Start:

```bash
sudo systemctl start demo-node-api
```

Disable boot startup:

```bash
sudo systemctl disable demo-node-api
```

Check failed services:

```bash
systemctl --failed
```

Reset failed state:

```bash
sudo systemctl reset-failed demo-node-api
```

---

# 19. systemd Crash Restart Test

Start service:

```bash
sudo systemctl start demo-node-api
```

Find PID:

```bash
systemctl show demo-node-api --property MainPID
```

Kill:

```bash
PID=$(systemctl show demo-node-api --property MainPID --value)
sudo kill -9 "$PID"
```

Wait:

```bash
sleep 3
```

Check:

```bash
sudo systemctl status demo-node-api --no-pager
journalctl -u demo-node-api -n 50 --no-pager
```

Because we configured:

```ini
Restart=always
RestartSec=5
```

systemd should restart it.

---

# 20. Important systemd Security Options

We used:

```ini
NoNewPrivileges=true
PrivateTmp=true
```

Meaning:

```text
NoNewPrivileges=true
  prevents process from gaining new privileges

PrivateTmp=true
  gives service isolated /tmp
```

Later, advanced hardening can include:

```ini
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/demo-node-api
CapabilityBoundingSet=
```

But be careful. Too much hardening can break apps if you do not understand file access needs.

---

# 21. PM2 and systemd Should Not Both Run Same App on Same Port

Do not run both at the same time on port 3000.

If PM2 is running:

```bash
pm2 stop demo-node-api
pm2 delete demo-node-api
```

Then start systemd:

```bash
sudo systemctl start demo-node-api
```

If systemd is running:

```bash
sudo systemctl stop demo-node-api
```

Then start PM2:

```bash
pm2 start ecosystem.config.js
```

If you get port conflict:

```bash
sudo ss -tulnp | grep ':3000'
```

---

# 22. Add Process Manager Notes

Create:

```bash
cd ~/devops-masterclass/05-application-runtime
nano process-managers-pm2-systemd.md
```

Paste:

````markdown
# Process Managers: PM2 and systemd

## Why Process Managers Matter

Manual app startup is not production-ready.

A process manager provides:

- start/stop/restart
- crash restart
- boot startup
- logs
- status
- process lifecycle control

## PM2

Common commands:

```bash
pm2 start ecosystem.config.js
pm2 list
pm2 logs demo-node-api
pm2 restart demo-node-api
pm2 stop demo-node-api
pm2 delete demo-node-api
pm2 save
pm2 startup
````

## systemd

Common commands:

```bash
sudo systemctl start demo-node-api
sudo systemctl stop demo-node-api
sudo systemctl restart demo-node-api
sudo systemctl status demo-node-api --no-pager
sudo systemctl enable demo-node-api
journalctl -u demo-node-api -f
```

## PM2 vs systemd

PM2 is convenient for Node.js apps.

systemd is Linux-native and excellent for VM services.

## Core Rules

* Do not run production apps manually in a terminal.
* Do not run the same app under PM2 and systemd on the same port.
* Use restart policies.
* Use a dedicated service user.
* Keep secrets in protected environment files or secret stores.
* Check ports with `ss`.
* Check logs with PM2 logs or journalctl.

````

---

# 23. Add PM2 Ecosystem to Git

Your `ecosystem.config.js` is useful, but it contains production-like values.

For real projects:

```text
Do not put real secrets in ecosystem.config.js.
Use placeholder values or load secrets externally.
````

In our demo, the `DATABASE_URL` is local and not real secret.

Create safer example file:

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api
nano ecosystem.config.example.js
```

Paste:

```javascript
module.exports = {
  apps: [
    {
      name: "demo-node-api",
      script: "server.js",
      instances: 1,
      exec_mode: "fork",
      env: {
        APP_NAME: "demo-node-api",
        APP_ENV: "dev",
        APP_VERSION: "0.1.0",
        COMMIT_SHA: "local",
        PORT: 3000,
        LOG_LEVEL: "info",
        LOAD_DOTENV: "false"
      },
      env_production: {
        APP_NAME: "demo-node-api",
        APP_ENV: "prod",
        APP_VERSION: "replace-with-version",
        COMMIT_SHA: "replace-with-commit",
        PORT: 3000,
        LOG_LEVEL: "info",
        LOAD_DOTENV: "false",
        DATABASE_URL: "replace-with-database-url",
        CORS_ORIGIN: "https://example.com"
      },
      max_memory_restart: "300M",
      kill_timeout: 10000,
      restart_delay: 2000
    }
  ]
};
```

Optional: ignore real ecosystem file if it contains secrets.

Open `.gitignore`:

```bash
nano .gitignore
```

Add:

```gitignore
ecosystem.config.js
!ecosystem.config.example.js
```

But if your `ecosystem.config.js` contains no real secrets and is intended as deployment config, you may commit it. In real production, be careful.

---

# 24. Add systemd Unit Example to Repo

Create examples folder:

```bash
cd ~/devops-masterclass/05-application-runtime
mkdir -p examples/systemd
nano examples/systemd/demo-node-api.service
```

Paste:

```ini
[Unit]
Description=Demo Node API
After=network.target

[Service]
Type=simple
User=demoapp
Group=demoapp
WorkingDirectory=/opt/demo-node-api
EnvironmentFile=/etc/demo-node-api/demo-node-api.env
ExecStart=/usr/bin/node /opt/demo-node-api/server.js
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

Create env example:

```bash
nano examples/systemd/demo-node-api.env.example
```

Paste:

```bash
APP_NAME=demo-node-api
APP_ENV=prod
APP_VERSION=0.1.0
COMMIT_SHA=replace-with-commit
PORT=3000
LOG_LEVEL=info
LOAD_DOTENV=false
DATABASE_URL=replace-with-database-url
CORS_ORIGIN=https://example.com
ENABLE_CACHE=true
REQUEST_TIMEOUT_MS=5000
```

---

# 25. Validation Commands

## PM2 validation

```bash
cd ~/devops-masterclass/05-application-runtime/demo-node-api

pm2 delete demo-node-api || true
pm2 start ecosystem.config.example.js --env production
pm2 list
curl -s http://127.0.0.1:3000/health | jq .
pm2 logs demo-node-api --lines 20
pm2 delete demo-node-api
```

If `DATABASE_URL=replace-with-database-url` causes config validation failure, use dev env:

```bash
pm2 start ecosystem.config.example.js
```

## systemd validation

```bash
sudo systemctl daemon-reload
sudo systemctl start demo-node-api
sudo systemctl status demo-node-api --no-pager
curl -s http://127.0.0.1:3000/health | jq .
journalctl -u demo-node-api -n 50 --no-pager
```

Stop:

```bash
sudo systemctl stop demo-node-api
```

---

# 26. Troubleshooting PM2

## App not listed

```bash
pm2 list
```

Start:

```bash
pm2 start ecosystem.config.example.js
```

## App errored

```bash
pm2 logs demo-node-api --lines 100
pm2 show demo-node-api
```

## Port already used

```bash
sudo ss -tulnp | grep ':3000'
```

Stop old app:

```bash
pm2 stop demo-node-api
sudo systemctl stop demo-node-api
```

## Restart loop

```bash
pm2 logs demo-node-api --lines 100
```

Usually caused by:

```text
bad config
missing dependency
port conflict
invalid environment value
```

---

# 27. Troubleshooting systemd

## Unit file changed but not applied

Run:

```bash
sudo systemctl daemon-reload
```

## Service failed

```bash
sudo systemctl status demo-node-api --no-pager
journalctl -u demo-node-api -n 100 --no-pager
```

## Node path wrong

Check:

```bash
which node
```

Update:

```ini
ExecStart=/actual/path/to/node /opt/demo-node-api/server.js
```

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl restart demo-node-api
```

## Permission denied

Check:

```bash
ls -ld /opt/demo-node-api
ls -l /etc/demo-node-api/demo-node-api.env
id demoapp
```

Fix:

```bash
sudo chown -R demoapp:demoapp /opt/demo-node-api
sudo chown root:demoapp /etc/demo-node-api/demo-node-api.env
sudo chmod 640 /etc/demo-node-api/demo-node-api.env
```

## Port conflict

```bash
sudo ss -tulnp | grep ':3000'
```

---

# 28. Commit Work

From repo root:

```bash
cd ~/devops-masterclass

git status
git add 05-application-runtime
git commit -m "feat: add PM2 and systemd process manager examples"
git push
```

---

# 29. Interview Explanation

Question:

```text
Why do production apps need process managers?
```

Strong answer:

```text
Production apps need process managers because manually running an app in a terminal is not reliable. A process manager provides controlled start, stop, restart, crash recovery, boot startup, logging integration, status checks, and lifecycle management. Examples include PM2 for Node.js apps and systemd for Linux services.
```

Question:

```text
What is the difference between PM2 and systemd?
```

Strong answer:

```text
PM2 is a Node.js-focused process manager that makes it easy to manage Node processes, logs, restart behavior, and ecosystem configs. systemd is the native Linux service manager used to manage system services with boot startup, journald logs, service users, dependencies, restart policies, and security options. PM2 is convenient for Node deployments, while systemd is more Linux-native and universal.
```

Question:

```text
How do you debug a failed systemd service?
```

Strong answer:

```text
I first check `systemctl status service --no-pager`, then inspect logs with `journalctl -u service -n 100 --no-pager`. I verify the ExecStart path, working directory, environment file, permissions, service user, and whether the configured port is already in use. After changing unit files, I run `systemctl daemon-reload` and restart the service.
```

Question:

```text
What does `pm2 save` do?
```

Strong answer:

```text
`pm2 save` saves the current PM2 process list so it can be restored after reboot when PM2 startup integration is configured. Starting a process with PM2 runs it now, but `pm2 save` records it for future resurrection.
```

---

# Today’s Core Rules

```text
Do not run production apps manually in terminals.
Use a process manager.
PM2 is convenient for Node.js apps.
systemd is Linux-native and production-friendly.
Use dedicated service users.
Use restart policies.
Use protected environment files.
Do not run PM2 and systemd for the same app on the same port.
Check ports with ss.
Check PM2 logs with pm2 logs.
Check systemd logs with journalctl.
Run daemon-reload after systemd unit changes.
Use pm2 save for reboot persistence.
```

Next lesson:

# Lesson 5.5 — Reverse Proxy with Nginx: public port 80/443 to internal app port, headers, health checks, and production routing.

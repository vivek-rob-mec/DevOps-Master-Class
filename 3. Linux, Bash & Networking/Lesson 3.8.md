# Lesson 3.8 — systemd Masterclass

Now we learn **systemd**, one of the most important Linux production topics.

Most modern Linux servers use systemd to manage services.

When you run production apps on a VM or bare Linux server, systemd answers:

```text
Is my app running?
Should it start after reboot?
How do I restart it safely?
Where are its logs?
Which user runs it?
What environment variables does it use?
Should it auto-restart after crash?
What command starts it?
What dependencies does it need?
```

In real DevOps, systemd is used for:

```text
Nginx
Docker
Jenkins
PostgreSQL
Redis
Prometheus
Grafana
Node.js apps
Python FastAPI apps
Background workers
Custom scripts
Scheduled jobs with timers
```

---

# 1. What is systemd?

`systemd` is the system and service manager used by many Linux distributions.

It is usually PID 1.

Check:

```bash
ps -p 1 -o pid,ppid,user,stat,cmd
```

Example output:

```text
PID  PPID USER STAT CMD
1       0 root Ss   /sbin/init
```

or:

```text
PID  PPID USER STAT CMD
1       0 root Ss   /lib/systemd/systemd
```

PID 1 is special because it is the first userspace process started by the kernel.

systemd manages:

```text
Services
Boot process
Targets
Mounts
Sockets
Timers
Logs through journald
Dependencies
Restart policies
```

For DevOps, the most important part is:

```text
systemd manages services.
```

---

# 2. What is a systemd Unit?

A systemd **unit** is a configuration object managed by systemd.

Common unit types:

```text
.service   service/process
.socket    socket activation
.timer     scheduled task
.mount     filesystem mount
.target    group of units
.path      path-based activation
```

Examples:

```text
nginx.service
docker.service
jenkins.service
ssh.service
postgresql.service
myapp.service
backup.timer
```

List unit files:

```bash
systemctl list-unit-files
```

List services:

```bash
systemctl list-units --type=service
```

List running services:

```bash
systemctl list-units --type=service --state=running
```

List failed services:

```bash
systemctl --failed
```

---

# 3. `systemctl` Core Commands

Check status:

```bash
sudo systemctl status nginx
```

Start service:

```bash
sudo systemctl start nginx
```

Stop service:

```bash
sudo systemctl stop nginx
```

Restart service:

```bash
sudo systemctl restart nginx
```

Reload service config without full restart, if supported:

```bash
sudo systemctl reload nginx
```

Enable service at boot:

```bash
sudo systemctl enable nginx
```

Disable service at boot:

```bash
sudo systemctl disable nginx
```

Enable and start now:

```bash
sudo systemctl enable --now nginx
```

Check if enabled:

```bash
systemctl is-enabled nginx
```

Check if active:

```bash
systemctl is-active nginx
```

Production note:

```text
start/stop affects current runtime.
enable/disable affects boot behavior.
```

This is a common beginner confusion.

---

# 4. `status` Output Explained

Run:

```bash
sudo systemctl status ssh
```

or on some systems:

```bash
sudo systemctl status sshd
```

Output may look like:

```text
● ssh.service - OpenBSD Secure Shell server
     Loaded: loaded (/lib/systemd/system/ssh.service; enabled; vendor preset: enabled)
     Active: active (running) since Sun 2026-06-28 10:00:00 IST; 1h ago
   Main PID: 1234 (sshd)
      Tasks: 1
     Memory: 5.8M
        CPU: 120ms
     CGroup: /system.slice/ssh.service
             └─1234 sshd: /usr/sbin/sshd -D
```

Meaning:

```text
Loaded    unit file exists and was loaded
enabled   starts at boot
Active    current runtime state
Main PID  main process ID
Memory    memory usage
CGroup    process group managed by systemd
```

If service failed, status often shows recent logs too.

---

# 5. Service States

Common states:

```text
active (running)     service is running
inactive (dead)      service is stopped
failed               service crashed or start failed
activating           service is starting
deactivating         service is stopping
reloading            service is reloading config
```

Check only active state:

```bash
systemctl is-active nginx
```

This is useful in scripts:

```bash
if systemctl is-active --quiet nginx; then
  echo "nginx is running"
else
  echo "nginx is not running"
fi
```

---

# 6. Unit File Locations

systemd unit files live in several places.

Common locations:

```text
/lib/systemd/system/       package-provided unit files
/usr/lib/systemd/system/   package-provided unit files on some distros
/etc/systemd/system/       local/custom/admin unit files
/run/systemd/system/       runtime unit files
```

Important rule:

```text
Custom units should usually go in /etc/systemd/system/
```

Do not edit package-provided unit files directly if avoidable.

Better:

```text
Use systemctl edit service-name
or create override files.
```

Show unit file:

```bash
systemctl cat nginx
```

Show where unit is loaded from:

```bash
systemctl status nginx
```

---

# 7. Anatomy of a Service Unit File

A basic service file:

```ini
[Unit]
Description=My App Service
After=network.target

[Service]
User=myapp
Group=myapp
WorkingDirectory=/opt/myapp/current
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

Sections:

```text
[Unit]      metadata and dependencies
[Service]   how to run the process
[Install]   how unit is enabled at boot
```

---

# 8. `[Unit]` Section

Example:

```ini
[Unit]
Description=Todo API Service
After=network.target
Wants=network-online.target
```

Important directives:

```text
Description     human-readable description
After           ordering dependency
Before          ordering dependency
Requires        hard dependency
Wants           soft dependency
Documentation   docs link
```

`After=network.target` means:

```text
Start this after network.target has started.
```

But it does **not** mean the network is fully online.

For services needing actual internet/network readiness:

```ini
After=network-online.target
Wants=network-online.target
```

---

# 9. `After` vs `Requires` vs `Wants`

This is important.

## `After`

Controls order only.

```ini
After=network.target
```

Meaning:

```text
Start after network.target.
```

It does not pull `network.target` in by itself.

## `Requires`

Hard dependency.

```ini
Requires=postgresql.service
```

If required unit fails, this service may be stopped.

Use carefully.

## `Wants`

Soft dependency.

```ini
Wants=network-online.target
```

systemd tries to start it, but failure does not necessarily fail your service.

Common pattern:

```ini
After=network-online.target
Wants=network-online.target
```

---

# 10. `[Service]` Section

Example:

```ini
[Service]
Type=simple
User=todo-api
Group=todo-api
WorkingDirectory=/opt/todo-api/current
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=5
EnvironmentFile=/etc/todo-api/todo-api.env
```

Important directives:

```text
Type               service startup type
User               run as user
Group              run as group
WorkingDirectory   app directory
ExecStart          command to start
ExecReload         command to reload
ExecStop           command to stop
Restart            restart behavior
RestartSec         delay before restart
Environment        inline env var
EnvironmentFile    env file
```

---

# 11. Service Types

Common `Type` values:

```text
simple       default; process started by ExecStart is main process
forking      service forks into background
oneshot      short task that exits
notify       service tells systemd when ready
```

For most Node.js/Python apps:

```ini
Type=simple
```

For scripts that run once:

```ini
Type=oneshot
```

For older daemons that fork:

```ini
Type=forking
```

Use `simple` unless you know you need another type.

---

# 12. `ExecStart`

`ExecStart` is the command systemd runs.

Example:

```ini
ExecStart=/usr/bin/node server.js
```

Important:

```text
Use absolute paths.
```

Bad:

```ini
ExecStart=node server.js
```

Why bad?

```text
systemd may not have your interactive shell PATH.
```

Find binary:

```bash
command -v node
command -v python3
command -v bash
```

Example:

```bash
command -v node
```

Could output:

```text
/home/vivek/.nvm/versions/node/v20.11.1/bin/node
```

Be careful with `nvm` in systemd. Systemd does not load your `.bashrc` by default.

For production, prefer Node installed in a stable system path or explicitly use full path.

---

# 13. Environment Variables in systemd

Inline:

```ini
Environment=NODE_ENV=production
Environment=PORT=3000
```

Environment file:

```ini
EnvironmentFile=/etc/todo-api/todo-api.env
```

Example env file:

```text
NODE_ENV=production
PORT=3000
LOG_LEVEL=info
DATABASE_URL=mongodb://localhost:27017/todo
```

Permissions:

```bash
sudo chown root:todo-api /etc/todo-api/todo-api.env
sudo chmod 640 /etc/todo-api/todo-api.env
```

Important:

```text
Environment files may contain secrets.
Do not make them world-readable.
Do not commit them to Git.
Use .env.example in Git instead.
```

---

# 14. Restart Policies

Common:

```ini
Restart=no
Restart=on-failure
Restart=always
```

Recommended for app service:

```ini
Restart=on-failure
RestartSec=5
```

Meaning:

```text
If app exits with failure, restart after 5 seconds.
```

`Restart=always` restarts even after clean exit.

Use when that is intended.

Avoid restart loops:

```ini
StartLimitIntervalSec=60
StartLimitBurst=5
```

Meaning:

```text
If service starts too many times in 60 seconds, systemd stops trying.
```

Example:

```ini
[Unit]
Description=Todo API Service

[Service]
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=5
StartLimitIntervalSec=60
StartLimitBurst=5
```

---

# 15. `[Install]` Section

Example:

```ini
[Install]
WantedBy=multi-user.target
```

This tells systemd where to attach the service when enabled.

`multi-user.target` is common for server services.

When you run:

```bash
sudo systemctl enable todo-api
```

systemd creates a symlink so the service starts during boot under `multi-user.target`.

---

# 16. Reloading systemd Daemon

After creating or changing a unit file:

```bash
sudo systemctl daemon-reload
```

This tells systemd:

```text
Reload unit file definitions.
```

Then:

```bash
sudo systemctl start myapp
sudo systemctl status myapp
```

If you change only app code, you usually restart service.

If you change unit file, run daemon-reload first.

---

# 17. Create a Test systemd Service

We will create a safe test service.

Create script:

```bash
cd ~/devops-masterclass
mkdir -p 03-linux-bash-networking/systemd-demo
nano 03-linux-bash-networking/systemd-demo/demo-service.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

while true; do
  echo "$(date -Is) demo-service running as $(whoami), pid=$$"
  sleep 5
done
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/systemd-demo/demo-service.sh
```

Create service user:

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin demo-service || true
```

Create app directory:

```bash
sudo mkdir -p /opt/demo-service
sudo cp 03-linux-bash-networking/systemd-demo/demo-service.sh /opt/demo-service/demo-service.sh
sudo chown -R demo-service:demo-service /opt/demo-service
sudo chmod 750 /opt/demo-service
sudo chmod 750 /opt/demo-service/demo-service.sh
```

Create unit:

```bash
sudo nano /etc/systemd/system/demo-service.service
```

Paste:

```ini
[Unit]
Description=Demo Service for DevOps Masterclass
After=network.target

[Service]
Type=simple
User=demo-service
Group=demo-service
WorkingDirectory=/opt/demo-service
ExecStart=/opt/demo-service/demo-service.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Reload:

```bash
sudo systemctl daemon-reload
```

Start:

```bash
sudo systemctl start demo-service
```

Check:

```bash
sudo systemctl status demo-service
```

Logs:

```bash
journalctl -u demo-service -n 20
```

Follow logs:

```bash
journalctl -u demo-service -f
```

Enable at boot:

```bash
sudo systemctl enable demo-service
```

Check:

```bash
systemctl is-enabled demo-service
systemctl is-active demo-service
```

Stop:

```bash
sudo systemctl stop demo-service
```

Disable:

```bash
sudo systemctl disable demo-service
```

---

# 18. journalctl — systemd Logs

systemd logs are managed by journald.

Basic:

```bash
journalctl
```

Logs for service:

```bash
journalctl -u demo-service
```

Last 50 lines:

```bash
journalctl -u demo-service -n 50
```

Follow logs:

```bash
journalctl -u demo-service -f
```

Logs since today:

```bash
journalctl -u demo-service --since today
```

Logs since time:

```bash
journalctl -u demo-service --since "2026-06-28 10:00:00"
```

Logs between times:

```bash
journalctl -u demo-service --since "2026-06-28 10:00:00" --until "2026-06-28 11:00:00"
```

Current boot only:

```bash
journalctl -b
```

Previous boot:

```bash
journalctl -b -1
```

Kernel logs:

```bash
journalctl -k
```

Priority errors:

```bash
journalctl -p err
```

Service errors:

```bash
journalctl -u demo-service -p err
```

No pager:

```bash
journalctl -u demo-service --no-pager
```

---

# 19. journald Log Fields

Show verbose output:

```bash
journalctl -u demo-service -o verbose -n 1
```

Different output formats:

```bash
journalctl -u demo-service -o short
journalctl -u demo-service -o cat
journalctl -u demo-service -o json-pretty
```

JSON logs:

```bash
journalctl -u demo-service -o json | jq .
```

This is useful for automation.

Example:

```bash
journalctl -u demo-service -o json --since today | jq -r '.MESSAGE'
```

---

# 20. Where are journal logs stored?

Depending on config, journald logs may be:

```text
/run/log/journal/       volatile logs
/var/log/journal/       persistent logs
```

Check:

```bash
ls -ld /var/log/journal /run/log/journal 2>/dev/null
```

Config:

```text
/etc/systemd/journald.conf
```

View:

```bash
grep -v '^#' /etc/systemd/journald.conf | sed '/^$/d'
```

Persistent logs can be enabled by creating:

```bash
sudo mkdir -p /var/log/journal
sudo systemctl restart systemd-journald
```

Be cautious on production. Log storage affects disk usage.

---

# 21. journalctl Disk Usage

Check journal disk usage:

```bash
journalctl --disk-usage
```

Vacuum logs older than 7 days:

```bash
sudo journalctl --vacuum-time=7d
```

Limit journal size:

```bash
sudo journalctl --vacuum-size=500M
```

Production note:

```text
Do not delete random journal files manually.
Use journalctl vacuum commands.
```

---

# 22. systemd Environment Debugging

Show service properties:

```bash
systemctl show demo-service
```

Show selected properties:

```bash
systemctl show demo-service -p User -p Group -p ExecStart -p WorkingDirectory -p Restart
```

Show environment:

```bash
systemctl show demo-service -p Environment
```

If using `EnvironmentFile`, systemctl may not show secret values directly depending on context, but be careful.

View full unit:

```bash
systemctl cat demo-service
```

---

# 23. Override Units Safely

Instead of editing package unit files, use:

```bash
sudo systemctl edit nginx
```

This creates an override file like:

```text
/etc/systemd/system/nginx.service.d/override.conf
```

Example override:

```ini
[Service]
Restart=on-failure
RestartSec=5
```

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl restart nginx
```

Show combined config:

```bash
systemctl cat nginx
```

Remove override:

```bash
sudo systemctl revert nginx
```

This is safer than editing package-managed unit files.

---

# 24. systemd Drop-in for Environment

For custom environment override:

```bash
sudo systemctl edit demo-service
```

Add:

```ini
[Service]
Environment=LOG_LEVEL=debug
```

Reload and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart demo-service
```

Check logs:

```bash
journalctl -u demo-service -n 20
```

For our demo script, it does not print `LOG_LEVEL`, but your real app could use it.

---

# 25. Environment File Example

Create env directory:

```bash
sudo mkdir -p /etc/demo-service
sudo nano /etc/demo-service/demo-service.env
```

Paste:

```text
MESSAGE=hello-from-env-file
SLEEP_SECONDS=5
```

Permissions:

```bash
sudo chown root:demo-service /etc/demo-service/demo-service.env
sudo chmod 640 /etc/demo-service/demo-service.env
```

Update script:

```bash
nano 03-linux-bash-networking/systemd-demo/demo-service-env.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

MESSAGE="${MESSAGE:-default-message}"
SLEEP_SECONDS="${SLEEP_SECONDS:-5}"

while true; do
  echo "$(date -Is) message=${MESSAGE} user=$(whoami) pid=$$"
  sleep "$SLEEP_SECONDS"
done
```

Copy:

```bash
chmod +x 03-linux-bash-networking/systemd-demo/demo-service-env.sh
sudo cp 03-linux-bash-networking/systemd-demo/demo-service-env.sh /opt/demo-service/demo-service-env.sh
sudo chown demo-service:demo-service /opt/demo-service/demo-service-env.sh
sudo chmod 750 /opt/demo-service/demo-service-env.sh
```

Update unit:

```bash
sudo nano /etc/systemd/system/demo-service.service
```

Use:

```ini
[Unit]
Description=Demo Service for DevOps Masterclass
After=network.target

[Service]
Type=simple
User=demo-service
Group=demo-service
WorkingDirectory=/opt/demo-service
EnvironmentFile=/etc/demo-service/demo-service.env
ExecStart=/opt/demo-service/demo-service-env.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Reload and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart demo-service
journalctl -u demo-service -n 20
```

---

# 26. Common systemd Failure: Missing Executable Permission

Problem:

```text
demo-service.service: Failed at step EXEC spawning /opt/demo-service/demo-service.sh: Permission denied
```

Debug:

```bash
ls -l /opt/demo-service/demo-service.sh
namei -l /opt/demo-service/demo-service.sh
```

Fix:

```bash
sudo chmod 750 /opt/demo-service/demo-service.sh
sudo chown demo-service:demo-service /opt/demo-service/demo-service.sh
sudo systemctl restart demo-service
```

---

# 27. Common systemd Failure: Wrong User Permissions

Problem:

```text
App cannot write logs.
```

Check unit user:

```bash
systemctl show demo-service -p User -p Group
```

Check log directory:

```bash
ls -ld /var/log/demo-service
```

Test as service user:

```bash
sudo -u demo-service touch /var/log/demo-service/test.log
```

If permission denied, fix ownership or group:

```bash
sudo mkdir -p /var/log/demo-service
sudo chown demo-service:demo-service /var/log/demo-service
sudo chmod 750 /var/log/demo-service
```

---

# 28. Common systemd Failure: Working Directory Missing

Problem:

```text
CHDIR failed: No such file or directory
```

Check:

```bash
systemctl cat demo-service
ls -ld /opt/demo-service
```

Fix path or create directory.

---

# 29. Common systemd Failure: Command Works Manually but Not in systemd

Common causes:

```text
Different PATH
Different user
Different working directory
Missing environment variables
nvm/pyenv not loaded
Permission issue
Relative paths
Secrets not available
```

Debug checklist:

```bash
systemctl cat myapp
systemctl show myapp -p User -p Group -p WorkingDirectory -p Environment
journalctl -u myapp -n 100
command -v node
namei -l /path/to/executable
sudo -u myapp /full/path/to/command
```

Professional rule:

```text
If it only works in your interactive shell, it is not production-ready yet.
```

---

# 30. systemd Timers

systemd timers can replace cron for scheduled jobs.

Timer unit:

```text
backup.timer
```

Service unit:

```text
backup.service
```

The timer triggers the service.

Advantages over cron:

```text
Logs in journal
systemctl status
Dependency support
Missed-run handling with Persistent=true
Better integration with systemd
```

---

# 31. Create a systemd Timer Demo

Create script:

```bash
sudo nano /opt/demo-service/timer-task.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail
echo "$(date -Is) timer task ran as $(whoami)"
```

Permissions:

```bash
sudo chown demo-service:demo-service /opt/demo-service/timer-task.sh
sudo chmod 750 /opt/demo-service/timer-task.sh
```

Create service:

```bash
sudo nano /etc/systemd/system/demo-timer-task.service
```

Paste:

```ini
[Unit]
Description=Demo Timer Task Service

[Service]
Type=oneshot
User=demo-service
Group=demo-service
ExecStart=/opt/demo-service/timer-task.sh
```

Create timer:

```bash
sudo nano /etc/systemd/system/demo-timer-task.timer
```

Paste:

```ini
[Unit]
Description=Run Demo Timer Task Every Minute

[Timer]
OnCalendar=*:0/1
Persistent=true

[Install]
WantedBy=timers.target
```

Reload:

```bash
sudo systemctl daemon-reload
```

Start timer:

```bash
sudo systemctl enable --now demo-timer-task.timer
```

List timers:

```bash
systemctl list-timers
```

Check logs:

```bash
journalctl -u demo-timer-task.service -n 20
```

Stop timer:

```bash
sudo systemctl disable --now demo-timer-task.timer
```

---

# 32. Timer Syntax Examples

Every 5 minutes:

```ini
OnCalendar=*:0/5
```

Daily at 2 AM:

```ini
OnCalendar=*-*-* 02:00:00
```

Every Monday at 3 AM:

```ini
OnCalendar=Mon *-*-* 03:00:00
```

After boot delay:

```ini
OnBootSec=10min
```

Repeated after active:

```ini
OnUnitActiveSec=1h
```

For many operational tasks, this is cleaner than cron.

---

# 33. Cleanup Demo Service

When done:

```bash
sudo systemctl stop demo-service || true
sudo systemctl disable demo-service || true
sudo systemctl disable --now demo-timer-task.timer || true

sudo rm -f /etc/systemd/system/demo-service.service
sudo rm -f /etc/systemd/system/demo-timer-task.service
sudo rm -f /etc/systemd/system/demo-timer-task.timer

sudo systemctl daemon-reload

sudo rm -rf /opt/demo-service
sudo rm -rf /etc/demo-service

sudo userdel demo-service || true
```

Only run cleanup after you finish practicing.

---

# 34. Script — systemd Service Inspector

Create:

```bash
cd ~/devops-masterclass
nano 03-linux-bash-networking/scripts/systemd-service-inspector.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SERVICE="${1:-}"

if [ -z "$SERVICE" ]; then
  echo "Usage: $0 <service-name>" >&2
  echo "Example: $0 nginx" >&2
  exit 1
fi

echo "===== systemd Service Inspector ====="
echo "Service: $SERVICE"
echo "Generated at: $(date)"
echo

echo "===== Active State ====="
systemctl is-active "$SERVICE" || true
echo

echo "===== Enabled State ====="
systemctl is-enabled "$SERVICE" || true
echo

echo "===== Status ====="
systemctl status "$SERVICE" --no-pager || true
echo

echo "===== Unit File ====="
systemctl cat "$SERVICE" || true
echo

echo "===== Selected Properties ====="
systemctl show "$SERVICE" \
  -p Id \
  -p Description \
  -p LoadState \
  -p ActiveState \
  -p SubState \
  -p UnitFileState \
  -p User \
  -p Group \
  -p ExecStart \
  -p WorkingDirectory \
  -p Restart \
  -p MainPID || true
echo

echo "===== Recent Logs ====="
journalctl -u "$SERVICE" -n 50 --no-pager || true
echo

echo "===== Failed Units ====="
systemctl --failed --no-pager || true

echo
echo "Done."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/systemd-service-inspector.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/systemd-service-inspector.sh ssh
```

or:

```bash
./03-linux-bash-networking/scripts/systemd-service-inspector.sh docker
```

depending on services installed.

---

# 35. Script — Service Health Check

Create:

```bash
nano 03-linux-bash-networking/scripts/service-health-check.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SERVICES=("$@")

if [ "${#SERVICES[@]}" -eq 0 ]; then
  echo "Usage: $0 <service1> [service2] ..." >&2
  echo "Example: $0 ssh docker nginx" >&2
  exit 1
fi

echo "===== Service Health Check ====="
echo "Generated at: $(date)"
echo

FAILED=0

for service in "${SERVICES[@]}"; do
  echo "----- $service -----"

  if systemctl is-active --quiet "$service"; then
    echo "Active: yes"
  else
    echo "Active: no"
    FAILED=1
  fi

  if systemctl is-enabled --quiet "$service"; then
    echo "Enabled: yes"
  else
    echo "Enabled: no"
  fi

  MAIN_PID="$(systemctl show "$service" -p MainPID --value 2>/dev/null || echo 0)"
  echo "MainPID: $MAIN_PID"

  if [ "$MAIN_PID" != "0" ] && [ -d "/proc/$MAIN_PID" ]; then
    ps -p "$MAIN_PID" -o pid,user,stat,%cpu,%mem,etime,cmd || true
  fi

  echo
done

if [ "$FAILED" -ne 0 ]; then
  echo "One or more services are not active." >&2
  exit 1
fi

echo "All services are active."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/service-health-check.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/service-health-check.sh ssh
```

This script is useful in CI/CD or server validation.

---

# 36. Create Notes

Create:

```bash
nano 03-linux-bash-networking/systemd.md
```

Paste:

````markdown
# systemd Masterclass

## Mental Model

systemd is the system and service manager. It usually runs as PID 1 and manages services, boot targets, timers, sockets, mounts, and logs through journald.

## Core Commands

```bash
systemctl status nginx
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx
sudo systemctl reload nginx
sudo systemctl enable nginx
sudo systemctl disable nginx
sudo systemctl enable --now nginx
systemctl is-active nginx
systemctl is-enabled nginx
systemctl list-units --type=service
systemctl --failed
systemctl cat nginx
systemctl show nginx
sudo systemctl daemon-reload
````

## Unit File Locations

| Path                       | Purpose                                |
| -------------------------- | -------------------------------------- |
| `/lib/systemd/system/`     | package-provided units                 |
| `/usr/lib/systemd/system/` | package-provided units on some distros |
| `/etc/systemd/system/`     | custom/admin units                     |
| `/run/systemd/system/`     | runtime units                          |

## Service File Sections

```ini
[Unit]
Description=My App
After=network.target

[Service]
Type=simple
User=myapp
Group=myapp
WorkingDirectory=/opt/myapp/current
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=5
EnvironmentFile=/etc/myapp/myapp.env

[Install]
WantedBy=multi-user.target
```

## journalctl

```bash
journalctl -u myapp
journalctl -u myapp -n 100
journalctl -u myapp -f
journalctl -u myapp --since today
journalctl -b
journalctl -b -1
journalctl -p err
journalctl --disk-usage
sudo journalctl --vacuum-time=7d
```

## Production Rules

* Use absolute paths in `ExecStart`.
* Run apps as dedicated service users, not root.
* Use `EnvironmentFile` for config, but protect permissions.
* Run `daemon-reload` after unit file changes.
* Use `Restart=on-failure` for long-running apps.
* Use `journalctl` for logs.
* Use `systemctl edit` for package service overrides.
* Validate service user permissions.
* If command works manually but not in systemd, check PATH, user, working directory, and environment.

````

Commit:

```bash
git status
git diff

git add 03-linux-bash-networking/systemd.md \
        03-linux-bash-networking/systemd-demo \
        03-linux-bash-networking/scripts/systemd-service-inspector.sh \
        03-linux-bash-networking/scripts/service-health-check.sh

git diff --staged

git commit -m "docs: add systemd masterclass"
git push
````

---

# 37. Real Production Scenario — Node App as systemd Service

Example app:

```text
/opt/todo-api/current/server.js
```

Service user:

```bash
sudo useradd --system --shell /usr/sbin/nologin --home /opt/todo-api todo-api
sudo mkdir -p /opt/todo-api/current
sudo mkdir -p /etc/todo-api
sudo mkdir -p /var/log/todo-api
sudo chown -R todo-api:todo-api /opt/todo-api /var/log/todo-api
```

Env file:

```bash
sudo nano /etc/todo-api/todo-api.env
```

```text
NODE_ENV=production
PORT=3000
DATABASE_URL=mongodb://127.0.0.1:27017/todo
```

Permissions:

```bash
sudo chown root:todo-api /etc/todo-api/todo-api.env
sudo chmod 640 /etc/todo-api/todo-api.env
```

Unit:

```bash
sudo nano /etc/systemd/system/todo-api.service
```

```ini
[Unit]
Description=Todo API Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=todo-api
Group=todo-api
WorkingDirectory=/opt/todo-api/current
EnvironmentFile=/etc/todo-api/todo-api.env
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=5
StartLimitIntervalSec=60
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
```

Commands:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now todo-api
sudo systemctl status todo-api
journalctl -u todo-api -f
```

Check port:

```bash
sudo ss -tulnp | grep ':3000'
```

Health check:

```bash
curl -f http://127.0.0.1:3000/health
```

---

# 38. Real Production Scenario — Service Fails After Reboot

Problem:

```text
App works after manual start but not after reboot.
```

Check:

```bash
systemctl status myapp
journalctl -u myapp -b -n 100
```

Possible causes:

```text
Service not enabled
Network not ready
Database not ready
Wrong working directory
Environment file missing
App depends on mounted disk not ready
Permission issue
```

Check enabled:

```bash
systemctl is-enabled myapp
```

Enable:

```bash
sudo systemctl enable myapp
```

If network dependency:

```ini
After=network-online.target
Wants=network-online.target
```

If mount dependency, use correct mount unit or dependency.

---

# 39. Real Production Scenario — Restart Loop

Problem:

```text
Service keeps restarting.
```

Check:

```bash
systemctl status myapp
journalctl -u myapp -n 100
```

Look for:

```text
Start request repeated too quickly
Main process exited
Failed with result 'exit-code'
```

Debug:

```bash
systemctl show myapp -p Restart -p RestartUSec -p NRestarts
journalctl -u myapp --since "10 minutes ago"
```

Common causes:

```text
Bad config
Missing env variable
Cannot connect DB
Port already in use
Permission denied
ExecStart wrong path
App exits immediately
```

---

# 40. Interview Answers

Question:

```text
What is systemd?
```

Strong answer:

```text
systemd is the system and service manager used by many Linux distributions. It usually runs as PID 1 and manages services, boot targets, timers, sockets, mounts, dependencies, restart policies, and logs through journald. In DevOps, I use systemd to run and manage services like Nginx, Docker, Jenkins, and custom applications.
```

Question:

```text
What is the difference between systemctl start and enable?
```

Strong answer:

```text
systemctl start starts a service immediately for the current runtime. systemctl enable configures the service to start automatically at boot. If I want both, I use systemctl enable --now service-name.
```

Question:

```text
How do you debug a failed systemd service?
```

Strong answer:

```text
I start with systemctl status service-name to see the active state, exit code, main PID, and recent logs. Then I check detailed logs with journalctl -u service-name -n 100 or -f. I inspect the unit file with systemctl cat and check properties like User, WorkingDirectory, ExecStart, EnvironmentFile, and Restart policy. Common issues are wrong paths, missing execute permission, wrong user permissions, missing environment variables, port conflicts, or commands that work only in an interactive shell.
```

Question:

```text
Why should ExecStart use absolute paths?
```

Strong answer:

```text
systemd services do not run inside my normal interactive shell and may not have the same PATH, shell profile, nvm, pyenv, or environment variables. Using absolute paths makes the service predictable and avoids “command not found” errors.
```

---

# Today’s Core Rules

```text
systemd usually runs as PID 1.
Services are defined using unit files.
Use systemctl to manage services.
Use journalctl to read service logs.
start means now; enable means at boot.
Custom units usually go in /etc/systemd/system.
Run daemon-reload after unit changes.
Use absolute paths in ExecStart.
Run apps as dedicated non-root service users.
Protect EnvironmentFile permissions.
Use Restart=on-failure carefully.
Use systemctl edit for package service overrides.
If it works manually but not in systemd, check user, PATH, working directory, and environment.
```

Next lesson:

# Lesson 3.9 — Logs Masterclass: /var/log, journald, logrotate, application logs, structured logs, retention, and incident log analysis

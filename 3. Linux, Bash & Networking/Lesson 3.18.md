# Lesson 3.18 — Linux Troubleshooting Playbooks

Now we convert everything from Module 3 into **production troubleshooting playbooks**.

This lesson is important because interviews and real incidents do not ask:

```text
Explain ps.
Explain df.
Explain journalctl.
```

They ask:

```text
The application is down. What will you do?
Server CPU is high. What will you check?
Disk is full. How will you safely fix it?
SSH is not working. How will you debug it?
Nginx is returning 502. What is your workflow?
```

A DevOps/SRE engineer needs **repeatable playbooks**.

---

# 1. What is a Troubleshooting Playbook?

A playbook is a structured step-by-step workflow for handling a known class of incident.

Example:

```text
Incident: Application is down

1. Confirm impact.
2. Check service state.
3. Check listening port.
4. Check logs.
5. Check system resources.
6. Check dependency connectivity.
7. Mitigate.
8. Verify.
9. Document timeline.
```

Why playbooks matter:

```text
They reduce panic.
They prevent random debugging.
They make incidents repeatable.
They help junior engineers act safely.
They improve postmortems.
They become runbooks for production.
```

---

# 2. Universal Incident Workflow

For almost every incident, follow this:

```text
1. Confirm the symptom.
2. Define scope.
3. Check what changed.
4. Identify failing layer.
5. Collect evidence.
6. Mitigate user impact.
7. Verify recovery.
8. Document root cause and prevention.
```

Commands usually start with:

```bash
date -Is
hostname
uptime
systemctl --failed
df -h
free -h
journalctl -p err --since "30 minutes ago"
```

This gives a quick baseline.

---

# 3. First 5-Minute Server Triage

When you SSH into a problematic server, run:

```bash
date -Is
hostname
uptime
who
df -h
df -i
free -h
systemctl --failed
sudo ss -tulnp
journalctl -p err --since "30 minutes ago" --no-pager
```

Then top resource users:

```bash
ps -eo pid,ppid,user,stat,%cpu,%mem,rss,etime,cmd --sort=-%cpu | head -15
ps -eo pid,ppid,user,stat,%cpu,%mem,rss,etime,cmd --sort=-rss | head -15
```

This tells you:

```text
Is the server overloaded?
Is disk full?
Are inodes full?
Is memory low?
Are services failed?
Are expected ports listening?
Are recent system errors visible?
```

---

# 4. Playbook 1 — Application Service Down

## Symptom

```text
Application is not responding.
Health check fails.
Users see 503/502/connection refused.
```

## Step 1: Check service status

```bash
sudo systemctl status todo-api --no-pager
```

If service name is unknown:

```bash
systemctl list-units --type=service | grep -Ei 'todo|api|node|app'
```

## Step 2: Check logs

```bash
journalctl -u todo-api -n 100 --no-pager
journalctl -u todo-api --since "30 minutes ago" --no-pager
```

Look for:

```text
Permission denied
Missing environment variable
Port already in use
Database connection failed
Module not found
Syntax error
OOM killed
Restart loop
```

## Step 3: Check process

```bash
pgrep -a node
ps -eo pid,ppid,user,stat,%cpu,%mem,etime,cmd | grep todo
```

## Step 4: Check port

```bash
sudo ss -tulnp | grep ':3000'
```

## Step 5: Check local health

```bash
curl -v http://127.0.0.1:3000/health
```

## Step 6: Check system resources

```bash
df -h
df -i
free -h
uptime
```

## Step 7: Mitigate

If config/deployment issue:

```bash
# rollback to previous known good release
sudo ln -sfn /opt/todo-api/releases/<previous-version> /opt/todo-api/current
sudo systemctl restart todo-api
```

If service crashed and restart is safe:

```bash
sudo systemctl restart todo-api
```

## Step 8: Verify

```bash
systemctl is-active todo-api
curl -fsS http://127.0.0.1:3000/health
journalctl -u todo-api -n 50 --no-pager
```

---

# 5. Playbook 2 — Nginx 502 Bad Gateway

## Symptom

```text
Website opens, but returns 502 Bad Gateway.
```

This usually means:

```text
Nginx is reachable, but upstream backend is not working correctly.
```

## Step 1: Confirm response

```bash
curl -Iv https://your-domain.com
```

or locally:

```bash
curl -Iv http://127.0.0.1
```

## Step 2: Check Nginx config

```bash
sudo nginx -t
```

## Step 3: Check Nginx logs

```bash
sudo tail -n 100 /var/log/nginx/error.log
sudo tail -n 100 /var/log/nginx/access.log
```

Common error:

```text
connect() failed (111: Connection refused) while connecting to upstream
```

Meaning:

```text
Backend port is not accepting connections.
```

Common error:

```text
upstream timed out
```

Meaning:

```text
Backend accepted connection but responded too slowly.
```

## Step 4: Check backend port

```bash
sudo ss -tulnp | grep ':3000'
```

## Step 5: Check backend health

```bash
curl -v http://127.0.0.1:3000/health
```

## Step 6: Check backend service

```bash
sudo systemctl status todo-api --no-pager
journalctl -u todo-api -n 100 --no-pager
```

## Step 7: Fix based on cause

Backend down:

```bash
sudo systemctl restart todo-api
```

Wrong Nginx upstream:

```bash
sudo nano /etc/nginx/sites-available/your-site
sudo nginx -t
sudo systemctl reload nginx
```

Backend slow:

```bash
uptime
free -h
ps -eo pid,user,%cpu,%mem,cmd --sort=-%cpu | head
journalctl -u todo-api --since "30 minutes ago"
```

---

# 6. Playbook 3 — High CPU

## Symptom

```text
Server slow.
CPU alert firing.
Application latency high.
```

## Step 1: Check load and CPU cores

```bash
uptime
nproc
```

Compare load average to CPU cores.

## Step 2: Check live CPU

```bash
top
```

Press:

```text
1     show per-core CPU
P     sort by CPU
```

## Step 3: Find top CPU processes

```bash
ps -eo pid,ppid,user,stat,%cpu,%mem,etime,cmd --sort=-%cpu | head -15
```

## Step 4: Inspect process

```bash
PID=<pid>
ps -p "$PID" -o pid,ppid,user,stat,%cpu,%mem,rss,vsz,etime,cmd
readlink /proc/"$PID"/cwd
tr '\0' ' ' < /proc/"$PID"/cmdline
```

## Step 5: Check logs

```bash
journalctl -u todo-api --since "30 minutes ago" --no-pager
```

Look for:

```text
Traffic spike
Repeated errors
Expensive endpoint
Job loop
Timeout loop
Deployment time correlation
```

## Step 6: Mitigate

Possible mitigations:

```text
Restart stuck worker carefully.
Scale horizontally.
Rollback bad deployment.
Rate-limit abusive traffic.
Move heavy work to queue.
Optimize code/database query.
```

Do not blindly kill processes without understanding what manages them.

If systemd manages it:

```bash
sudo systemctl restart todo-api
```

If Docker manages it:

```bash
docker restart <container>
```

If Kubernetes manages it:

```bash
kubectl rollout restart deployment/<name>
```

---

# 7. Playbook 4 — High Memory / OOM

## Symptom

```text
App suddenly restarted.
Container exit code 137.
Server sluggish.
Memory alert firing.
```

## Step 1: Check memory

```bash
free -h
swapon --show
```

Focus on:

```text
available memory
swap usage
```

## Step 2: Find top memory processes

```bash
ps -eo pid,ppid,user,stat,%mem,rss,vsz,etime,cmd --sort=-rss | head -15
```

## Step 3: Check OOM killer

```bash
journalctl -k --since "2 hours ago" --no-pager | grep -Ei "oom|out of memory|killed process"
```

or:

```bash
dmesg -T | grep -Ei "oom|out of memory|killed process"
```

## Step 4: Watch suspected process

```bash
watch -n 5 'ps -p <pid> -o pid,user,%mem,rss,vsz,etime,cmd'
```

## Step 5: Check service logs

```bash
journalctl -u todo-api --since "2 hours ago" --no-pager
```

## Step 6: Mitigate

Possible mitigations:

```text
Restart leaking process.
Rollback recent deployment.
Reduce worker count.
Increase memory.
Add swap carefully for VM workloads.
Scale horizontally.
Fix memory leak.
Move large processing to background jobs.
```

Important:

```text
Restarting may restore service, but it does not fix the root cause.
```

---

# 8. Playbook 5 — Disk Full

## Symptom

```text
No space left on device.
App cannot write logs.
Database write errors.
Deployment fails.
```

## Step 1: Check disk and inodes

```bash
df -h
df -i
```

## Step 2: Find full filesystem

Example:

```text
/ is 95% full
```

## Step 3: Drill down safely

```bash
sudo du -xhd1 / | sort -hr | head
sudo du -xhd1 /var | sort -hr | head
sudo du -xhd1 /var/log | sort -hr | head
```

## Step 4: Check deleted open files

```bash
sudo lsof +L1
```

If large deleted files are held open, restart or reload the owning process.

## Step 5: Check Docker

```bash
docker system df
sudo du -sh /var/lib/docker
```

Be careful with volumes.

## Step 6: Safe cleanup options

APT cache:

```bash
sudo apt clean
sudo apt autoremove -y
```

Old logs:

```bash
sudo find /var/log -type f -size +100M -exec ls -lh {} \;
```

Journal cleanup:

```bash
journalctl --disk-usage
sudo journalctl --vacuum-time=7d
```

Docker cache, with caution:

```bash
docker builder prune
docker image prune
docker container prune
```

Avoid unless sure:

```bash
docker volume prune
docker system prune -a --volumes
```

## Step 7: Long-term fix

```text
Configure logrotate.
Configure Docker log rotation.
Configure Jenkins build retention.
Move data to separate disk.
Increase disk size.
Add monitoring at 80/90%.
```

---

# 9. Playbook 6 — Inodes Full

## Symptom

```text
No space left on device.
df -h shows free space.
df -i shows 100%.
```

## Step 1: Check inodes

```bash
df -i
```

## Step 2: Find many-file directories

```bash
sudo find / -xdev -type f 2>/dev/null | cut -d/ -f2 | sort | uniq -c | sort -nr | head
```

For `/var`:

```bash
sudo find /var -xdev -type f 2>/dev/null | cut -d/ -f3 | sort | uniq -c | sort -nr | head
```

## Step 3: Drill down

```bash
sudo find /var/tmp -type f | wc -l
sudo find /tmp -type f | wc -l
```

## Step 4: Fix carefully

Common fixes:

```text
Clean old cache files.
Clean old temp files.
Fix app creating millions of small files.
Configure cleanup timer.
Move workload to suitable storage.
```

Do not delete randomly.

---

# 10. Playbook 7 — Network Connectivity Failure

## Symptom

```text
App cannot connect to API/database.
curl timeout.
nc timeout/refused.
```

## Step 1: DNS

```bash
getent hosts api.example.com
dig +short api.example.com
```

## Step 2: Route

```bash
IP="$(getent hosts api.example.com | awk '{print $1}' | head -1)"
ip route get "$IP"
```

## Step 3: TCP port

```bash
nc -vz api.example.com 443
```

## Step 4: HTTP/TLS

```bash
curl -Iv https://api.example.com
```

## Step 5: Timing

```bash
curl -o /dev/null -s -w \
"dns=%{time_namelookup} connect=%{time_connect} tls=%{time_appconnect} starttransfer=%{time_starttransfer} total=%{time_total} status=%{http_code}\n" \
https://api.example.com
```

## Step 6: If local service

On server:

```bash
sudo ss -tulnp | grep ':3000'
curl -v http://127.0.0.1:3000/health
```

## Step 7: Interpret

```text
DNS fails        → DNS/record/resolver issue
Connection refused → host reachable, no listener or active reject
Timeout          → firewall/security group/routing/drop
TLS failure      → certificate/SNI/protocol issue
HTTP 502         → upstream/backend issue
HTTP 504         → upstream timeout/backend slow
HTTP 500         → application error
```

---

# 11. Playbook 8 — Permission Denied

## Symptom

```text
Permission denied.
App cannot read config.
App cannot write logs.
Script cannot execute.
SSH key refused.
```

## Step 1: Identify user

```bash
whoami
id
```

For service:

```bash
systemctl show todo-api -p User -p Group
```

## Step 2: Check target file/dir

```bash
ls -l /path/to/file
stat /path/to/file
```

## Step 3: Check parent directories

```bash
namei -l /path/to/file
```

This is very important.

A file may be readable, but parent directory may block traversal.

## Step 4: Test as service user

```bash
sudo -u todo-api cat /etc/todo-api/todo-api.env
sudo -u todo-api touch /var/log/todo-api/test.log
```

## Step 5: Fix ownership/permissions

Example env file:

```bash
sudo chown root:todo-api /etc/todo-api/todo-api.env
sudo chmod 640 /etc/todo-api/todo-api.env
```

Example log directory:

```bash
sudo mkdir -p /var/log/todo-api
sudo chown todo-api:todo-api /var/log/todo-api
sudo chmod 750 /var/log/todo-api
```

Avoid:

```bash
chmod 777
```

---

# 12. Playbook 9 — SSH Not Working

## Symptom

```text
SSH timeout.
Permission denied publickey.
Connection refused.
```

## Case 1: Timeout

From client:

```bash
ping -c 4 server-ip
nc -vz server-ip 22
```

Likely:

```text
Security group/firewall/routing/server down/private subnet.
```

On server via console/SSM:

```bash
sudo ss -tulnp | grep ':22'
sudo systemctl status ssh
sudo ufw status verbose
```

## Case 2: Connection refused

Likely:

```text
Server reachable but sshd not listening.
```

Check:

```bash
sudo systemctl status ssh
sudo ss -tulnp | grep ':22'
```

## Case 3: Permission denied publickey

Client debug:

```bash
ssh -vvv user@server-ip
```

Server checks:

```bash
ls -ld ~/.ssh
ls -l ~/.ssh/authorized_keys
sudo tail -n 100 /var/log/auth.log
```

Correct permissions:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_ed25519
```

Check user:

```bash
getent passwd user
```

Check SSH config:

```bash
sudo sshd -t
sudo sshd -T | grep -Ei 'passwordauthentication|pubkeyauthentication|permitrootlogin|allowusers'
```

---

# 13. Playbook 10 — Security Incident Suspicion

## Symptom

```text
Suspicious SSH attempts.
Unknown process.
Unexpected open port.
High CPU from unknown binary.
```

## Step 1: Preserve evidence

Do not immediately delete everything.

Collect:

```bash
date -Is
hostname
who
last -a | head
sudo ss -tulnp
ps aux --sort=-%cpu | head -20
systemctl --failed
journalctl -p err --since "24 hours ago" --no-pager
```

## Step 2: Check auth logs

```bash
sudo grep "Accepted" /var/log/auth.log | tail -100
sudo grep "Failed password" /var/log/auth.log | tail -100
sudo grep "sudo" /var/log/auth.log | tail -100
```

## Step 3: Check users and sudo

```bash
cut -d: -f1,3,7 /etc/passwd
getent group sudo
sudo -l
```

## Step 4: Check unknown processes

```bash
ps aux --sort=-%cpu | head
ps aux --sort=-%mem | head
sudo lsof -i -P -n
```

## Step 5: Check persistence

```bash
systemctl list-unit-files --state=enabled
crontab -l
sudo ls -la /etc/cron.*
sudo ls -la /var/spool/cron/crontabs 2>/dev/null
```

## Step 6: Mitigate

Depending on severity:

```text
Restrict firewall/security group.
Disable compromised users.
Rotate SSH keys/secrets.
Snapshot instance for forensics.
Replace instance from clean image.
Patch vulnerability.
Review CI/CD credentials.
```

Production rule:

```text
If compromise is likely, rebuilding from a clean image is safer than trying to clean manually.
```

---

# 14. Incident Timeline Template

During incidents, write a timeline.

Create:

```bash
nano 03-linux-bash-networking/incident-timeline-template.md
```

Paste:

```markdown
# Incident Timeline Template

## Incident Summary

- Date:
- Service:
- Environment:
- Severity:
- Reporter:
- Start time:
- End time:
- User impact:

## Timeline

| Time | Event | Evidence |
|---|---|---|
| 10:00 | Alert fired | CPU > 90% |
| 10:03 | Checked service | `systemctl status todo-api` |
| 10:05 | Found DB timeout errors | `journalctl -u todo-api` |
| 10:10 | Rolled back release | release v1.2.2 |
| 10:15 | Health checks recovered | `/health` 200 |

## Root Cause

Write the confirmed root cause.

## Contributing Factors

- Missing alert?
- Missing limit?
- Bad deployment?
- No rollback?
- Weak test coverage?
- Capacity issue?

## Mitigation

What fixed the user impact?

## Prevention

- Monitoring:
- Automation:
- Runbook:
- Tests:
- Architecture:
- Security:
```

---

# 15. Build a Master Troubleshooting Script

Create:

```bash
cd ~/devops-masterclass
nano 03-linux-bash-networking/scripts/first-response-triage.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SINCE="${1:-30 minutes ago}"

section() {
  echo
  echo "============================================================"
  echo "$*"
  echo "============================================================"
}

section "First Response Triage"
echo "Time: $(date -Is)"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo "Since: $SINCE"

section "Uptime and Load"
uptime
echo "CPU cores: $(nproc)"

section "Memory"
free -h
swapon --show || true

section "Disk"
df -h
echo
df -i

section "Top CPU Processes"
ps -eo pid,ppid,user,stat,%cpu,%mem,rss,etime,cmd --sort=-%cpu | head -15

section "Top Memory Processes"
ps -eo pid,ppid,user,stat,%cpu,%mem,rss,etime,cmd --sort=-rss | head -15

section "Failed systemd Units"
systemctl --failed --no-pager || true

section "Listening Ports"
sudo ss -tulnp 2>/dev/null || ss -tuln || true

section "Recent Error Logs"
journalctl -p err --since "$SINCE" --no-pager 2>/dev/null || true

section "Recent OOM Events"
journalctl -k --since "$SINCE" --no-pager 2>/dev/null \
  | grep -Ei "oom|out of memory|killed process" \
  || echo "No OOM events found"

section "Deleted Open Files"
if command -v lsof >/dev/null 2>&1; then
  sudo lsof +L1 2>/dev/null | head -30 || true
else
  echo "lsof not installed"
fi

section "Network Interfaces"
ip -br addr || true

section "Routes"
ip route || true

section "Logged-in Users"
who || true

section "Recent Logins"
last -a | head -20 || true

echo
echo "First response triage completed."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/first-response-triage.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/first-response-triage.sh
```

With custom window:

```bash
./03-linux-bash-networking/scripts/first-response-triage.sh "2 hours ago"
```

---

# 16. Build a Service Incident Script

Create:

```bash
nano 03-linux-bash-networking/scripts/service-incident-debug.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SERVICE="${1:-}"
PORT="${2:-}"
HEALTH_URL="${3:-}"
SINCE="${SINCE:-30 minutes ago}"

usage() {
  echo "Usage: $0 <service> [port] [health-url]" >&2
  echo "Example: $0 todo-api 3000 http://127.0.0.1:3000/health" >&2
}

section() {
  echo
  echo "============================================================"
  echo "$*"
  echo "============================================================"
}

if [ -z "$SERVICE" ]; then
  usage
  exit 1
fi

section "Service Incident Debug"
echo "Time: $(date -Is)"
echo "Service: $SERVICE"
echo "Port: ${PORT:-not provided}"
echo "Health URL: ${HEALTH_URL:-not provided}"
echo "Since: $SINCE"

section "Service Status"
systemctl status "$SERVICE" --no-pager || true

section "Service Properties"
systemctl show "$SERVICE" \
  -p ActiveState \
  -p SubState \
  -p MainPID \
  -p User \
  -p Group \
  -p WorkingDirectory \
  -p ExecStart \
  -p Restart \
  --no-pager || true

section "Service Logs"
journalctl -u "$SERVICE" --since "$SINCE" --no-pager || true

section "Main Process"
MAIN_PID="$(systemctl show "$SERVICE" -p MainPID --value 2>/dev/null || echo 0)"

if [ "$MAIN_PID" != "0" ] && [ -d "/proc/$MAIN_PID" ]; then
  ps -p "$MAIN_PID" -o pid,ppid,user,group,stat,%cpu,%mem,rss,vsz,etime,cmd || true
  echo
  echo "CWD:"
  readlink "/proc/$MAIN_PID/cwd" || true
  echo
  echo "Command line:"
  tr '\0' ' ' < "/proc/$MAIN_PID/cmdline" || true
  echo
else
  echo "No running MainPID found"
fi

if [ -n "$PORT" ]; then
  section "Port Check"
  sudo ss -tulnp 2>/dev/null | grep ":$PORT" || echo "No listener found on port $PORT"
fi

if [ -n "$HEALTH_URL" ]; then
  section "Health Check"
  curl -v --connect-timeout 5 --max-time 10 "$HEALTH_URL" || true
fi

section "System Resources"
uptime
free -h
df -h
df -i

section "Recent OOM Events"
journalctl -k --since "$SINCE" --no-pager 2>/dev/null \
  | grep -Ei "oom|out of memory|killed process" \
  || echo "No OOM events found"

echo
echo "Service incident debug completed."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/service-incident-debug.sh
```

Run example:

```bash
./03-linux-bash-networking/scripts/service-incident-debug.sh ssh 22
```

For Todo API later:

```bash
SINCE="1 hour ago" ./03-linux-bash-networking/scripts/service-incident-debug.sh \
  todo-api 3000 http://127.0.0.1:3000/health
```

---

# 17. Create Troubleshooting Playbook Notes

Create:

```bash
nano 03-linux-bash-networking/linux-troubleshooting-playbooks.md
```

Paste:

````markdown
# Linux Troubleshooting Playbooks

## Universal Workflow

```text
1. Confirm symptom
2. Define scope
3. Check what changed
4. Identify failing layer
5. Collect evidence
6. Mitigate user impact
7. Verify recovery
8. Document root cause and prevention
````

## First 5-Minute Triage

```bash
date -Is
hostname
uptime
df -h
df -i
free -h
systemctl --failed
sudo ss -tulnp
journalctl -p err --since "30 minutes ago" --no-pager
ps -eo pid,ppid,user,stat,%cpu,%mem,rss,etime,cmd --sort=-%cpu | head -15
ps -eo pid,ppid,user,stat,%cpu,%mem,rss,etime,cmd --sort=-rss | head -15
```

## Service Down

```bash
systemctl status service-name
journalctl -u service-name -n 100
sudo ss -tulnp | grep ':PORT'
curl -v http://127.0.0.1:PORT/health
df -h
free -h
```

## Nginx 502

```bash
curl -Iv https://domain
sudo nginx -t
sudo tail -n 100 /var/log/nginx/error.log
sudo ss -tulnp | grep ':backend-port'
curl -v http://127.0.0.1:backend-port/health
journalctl -u backend-service -n 100
```

## High CPU

```bash
uptime
nproc
top
ps -eo pid,ppid,user,stat,%cpu,%mem,etime,cmd --sort=-%cpu | head
journalctl -u service --since "30 minutes ago"
```

## High Memory / OOM

```bash
free -h
swapon --show
ps -eo pid,ppid,user,stat,%mem,rss,vsz,etime,cmd --sort=-rss | head
journalctl -k --since "2 hours ago" | grep -Ei "oom|out of memory|killed process"
```

## Disk Full

```bash
df -h
df -i
sudo du -xhd1 / | sort -hr | head
sudo du -xhd1 /var | sort -hr | head
sudo lsof +L1
journalctl --disk-usage
docker system df
```

## Network Failure

```bash
getent hosts host
dig +short host
ip route get IP
nc -vz host port
curl -Iv https://host
```

## Permission Denied

```bash
id
systemctl show service -p User -p Group
ls -l /path
stat /path
namei -l /path
sudo -u service-user cat /path/to/file
```

## SSH Failure

```bash
nc -vz server-ip 22
ssh -vvv user@server-ip
sudo systemctl status ssh
sudo ss -tulnp | grep ':22'
sudo sshd -t
sudo tail -n 100 /var/log/auth.log
```

## Security Suspicion

```bash
who
last -a | head
sudo ss -tulnp
ps aux --sort=-%cpu | head
sudo grep "Accepted" /var/log/auth.log | tail
sudo grep "Failed password" /var/log/auth.log | tail
getent group sudo
systemctl list-unit-files --state=enabled
```

````

---

# 18. Commit Work

Run:

```bash
git status
git diff
````

Add:

```bash
git add 03-linux-bash-networking/linux-troubleshooting-playbooks.md \
        03-linux-bash-networking/incident-timeline-template.md \
        03-linux-bash-networking/scripts/first-response-triage.sh \
        03-linux-bash-networking/scripts/service-incident-debug.sh
```

Review:

```bash
git diff --staged
```

Commit:

```bash
git commit -m "docs: add Linux troubleshooting playbooks"
git push
```

---

# 19. Real Interview Scenario — “Website is Down”

Strong answer:

```text
I would troubleshoot layer by layer. First I would confirm the issue using curl and check the HTTP status code. Then I would check DNS resolution with getent hosts or dig, and TCP/TLS connectivity with curl -Iv or nc. If the site returns 502 or 504, I would inspect Nginx or load balancer logs and then verify the backend service status, listening port, and health endpoint. On the server, I would check system resources like disk, memory, CPU, failed services, and recent journal errors. Once I identify the failing layer, I would mitigate user impact, for example restart or rollback the backend, fix proxy config, or restore dependency connectivity, then verify recovery and document the timeline.
```

---

# 20. Real Interview Scenario — “Server is Slow”

Strong answer:

```text
I start by checking uptime and load average, then compare load with CPU cores using nproc. I use top or ps sorted by CPU and memory to identify resource-heavy processes. I check free -h and swap usage for memory pressure, vmstat for CPU versus I/O wait, and iostat if I/O wait is high. I also check disk and inode usage with df -h and df -i, and recent logs with journalctl. Based on evidence, I decide whether the issue is CPU saturation, memory pressure, disk I/O, application behavior, or a recent deployment.
```

---

# 21. Real Interview Scenario — “Disk is Full”

Strong answer:

```text
I first check df -h to identify the full filesystem and df -i to check inode exhaustion. Then I drill down with du, usually using sudo du -xhd1 / and then checking large directories like /var, /var/log, /var/lib/docker, or /var/lib/jenkins. I check deleted open files with sudo lsof +L1 because deleted logs can still consume disk. I clean safely based on evidence, for example apt cache, old logs, journald vacuum, Docker build cache, or Jenkins old artifacts. I avoid deleting unknown data and implement long-term fixes like logrotate, Docker log rotation, artifact retention, disk expansion, and monitoring.
```

---

# 22. Real Interview Scenario — “Permission Denied”

Strong answer:

```text
I first identify which user is running the command or service. For a systemd service, I check systemctl show service -p User -p Group. Then I inspect the target file or directory using ls -l and stat, and use namei -l to check every parent directory because execute permission is required to traverse directories. I test access as the service user using sudo -u. Then I fix ownership or permissions using least privilege, not chmod 777.
```

---

# 23. Today’s Core Rules

```text
Troubleshooting must be systematic.
Always confirm the symptom.
Always define the failing layer.
Check what changed recently.
Collect evidence before changing things.
Mitigate user impact first when needed.
Verify recovery with health checks.
Document timeline and root cause.
Do not randomly reboot.
Do not randomly delete files.
Do not chmod 777 as a fix.
Use the right manager: systemd, Docker, Kubernetes, Jenkins, or cloud console.
Every incident should improve the runbook.
```

Next lesson:

# Lesson 3.19 — Linux Module Capstone: Full Production VM Setup, Secure Service Deployment, Healthchecks, Logs, Troubleshooting, and Final Interview Review.

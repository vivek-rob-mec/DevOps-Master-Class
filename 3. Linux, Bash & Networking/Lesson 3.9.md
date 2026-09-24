# Lesson 3.9 — Logs Masterclass

Now we learn logs deeply.

Logs are one of the first things you check during production incidents.

When something breaks, logs help answer:

```text
What happened?
When did it happen?
Which service failed?
Which user/request was affected?
Was it a code error, config error, permission error, network error, or dependency error?
Did it start after deployment?
Is it repeating?
Is it getting worse?
```

A beginner says:

```text
Application is not working.
```

A DevOps engineer says:

```text
At 10:14:32, todo-api started returning 500 for POST /api/todos.
Logs show MongoDB connection timeout.
The issue started 2 minutes after deployment v1.2.3.
Rollback candidate is v1.2.2.
```

That is the difference.

---

# 1. What Are Logs?

Logs are timestamped records of events.

Examples:

```text
Application started
User logged in
Request received
Database query failed
Permission denied
Service restarted
Disk full
SSH login failed
Nginx returned 502
Jenkins build failed
Kubernetes pod crashed
```

Logs are not just text.

They are evidence.

In production, logs support:

```text
Debugging
Incident response
Security investigation
Audit trail
Performance analysis
Compliance
Postmortems
```

---

# 2. Types of Logs

Common Linux and DevOps logs:

```text
System logs
Authentication logs
Kernel logs
Service logs
Application logs
Web server access logs
Web server error logs
Database logs
Container logs
CI/CD logs
Security logs
Audit logs
```

Examples:

```text
/var/log/syslog
/var/log/auth.log
journalctl -k
journalctl -u nginx
/var/log/nginx/access.log
/var/log/nginx/error.log
/var/log/postgresql/
/var/log/mysql/
/var/log/jenkins/
docker logs <container>
kubectl logs <pod>
```

---

# 3. Main Linux Log Locations

Most traditional logs live under:

```text
/var/log
```

Check:

```bash
ls -lh /var/log
```

Common files on Ubuntu:

```text
/var/log/syslog
/var/log/auth.log
/var/log/kern.log
/var/log/dpkg.log
/var/log/apt/
/var/log/nginx/
/var/log/journal/
```

Not every system has the exact same files.

Some logs may be handled mainly by `journald`.

---

# 4. `/var/log/syslog`

`syslog` contains general system logs.

View:

```bash
sudo less /var/log/syslog
```

Last 100 lines:

```bash
sudo tail -n 100 /var/log/syslog
```

Follow live:

```bash
sudo tail -f /var/log/syslog
```

Search errors:

```bash
sudo grep -i "error" /var/log/syslog
```

Search warnings/errors:

```bash
sudo grep -Ei "error|fail|warn|denied" /var/log/syslog
```

Production use:

```text
System-level troubleshooting
Service startup issues
Package/service messages
General host activity
```

---

# 5. `/var/log/auth.log`

`auth.log` contains authentication and authorization logs.

View:

```bash
sudo less /var/log/auth.log
```

Failed SSH logins:

```bash
sudo grep "Failed password" /var/log/auth.log
```

Accepted SSH logins:

```bash
sudo grep "Accepted" /var/log/auth.log
```

Sudo usage:

```bash
sudo grep "sudo" /var/log/auth.log
```

Follow live:

```bash
sudo tail -f /var/log/auth.log
```

Production use:

```text
SSH troubleshooting
Suspicious login attempts
Sudo audit
User access investigation
Brute-force detection
```

Example:

```bash
sudo grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | head
```

This attempts to count source IPs for failed SSH attempts, but auth log formats can vary. Always inspect the raw lines first.

---

# 6. Kernel Logs

Kernel logs show low-level system events.

Using journalctl:

```bash
journalctl -k
```

Current boot only:

```bash
journalctl -k -b
```

Traditional file sometimes:

```bash
sudo less /var/log/kern.log
```

Useful for:

```text
OOM killer events
Disk errors
Network driver issues
Filesystem errors
Hardware problems
Kernel warnings
```

Find OOM events:

```bash
journalctl -k | grep -i "out of memory"
```

or:

```bash
journalctl -k | grep -i "killed process"
```

Production example:

```text
App disappeared.
systemd says process exited.
Kernel log shows OOM killer killed node process.
Root cause is memory exhaustion.
```

---

# 7. `journalctl` Recap

systemd logs are read with `journalctl`.

All logs:

```bash
journalctl
```

Current boot:

```bash
journalctl -b
```

Previous boot:

```bash
journalctl -b -1
```

Service logs:

```bash
journalctl -u nginx
```

Last 100 lines:

```bash
journalctl -u nginx -n 100
```

Follow:

```bash
journalctl -u nginx -f
```

Since time:

```bash
journalctl -u nginx --since "2026-06-28 10:00:00"
```

Since relative time:

```bash
journalctl -u nginx --since "30 minutes ago"
```

Errors only:

```bash
journalctl -p err
```

Service errors:

```bash
journalctl -u nginx -p err
```

No pager:

```bash
journalctl -u nginx --no-pager
```

Output only message:

```bash
journalctl -u nginx -o cat
```

JSON output:

```bash
journalctl -u nginx -o json-pretty
```

---

# 8. Log Levels

Common log levels:

```text
TRACE
DEBUG
INFO
WARN
ERROR
FATAL
```

Meaning:

```text
TRACE  very detailed diagnostic information
DEBUG  developer/debug information
INFO   normal important events
WARN   something unexpected but not fatal
ERROR  operation failed
FATAL  service cannot continue
```

Production rule:

```text
Default production logs should usually be INFO or WARN.
DEBUG can be enabled temporarily during investigation.
```

Why not always DEBUG?

```text
Too much log volume
Higher storage cost
Sensitive data risk
Harder to search
Performance impact
```

---

# 9. Good Logs vs Bad Logs

Bad log:

```text
Error happened
```

Better log:

```text
Failed to create todo
```

Good log:

```text
level=ERROR service=todo-api env=production request_id=req-123 user_id=42 method=POST path=/api/todos status=500 error="mongodb timeout" duration_ms=1200
```

A good log should answer:

```text
When?
Where?
What service?
Which request?
What action?
What result?
What error?
How long did it take?
Can we correlate it?
```

---

# 10. Structured Logs

Unstructured log:

```text
User Vivek created todo successfully
```

Structured log:

```text
timestamp=2026-06-28T10:00:00Z level=INFO service=todo-api user=vivek action=create_todo status=success duration_ms=45
```

JSON structured log:

```json
{
  "timestamp": "2026-06-28T10:00:00Z",
  "level": "INFO",
  "service": "todo-api",
  "user": "vivek",
  "action": "create_todo",
  "status": "success",
  "duration_ms": 45
}
```

Why structured logs are better:

```text
Easier searching
Easier parsing
Better dashboards
Better alerting
Better correlation
Works well with ELK/Loki/CloudWatch
```

---

# 11. Request IDs and Correlation IDs

In distributed systems, one user request may touch many services:

```text
Frontend
Backend API
Auth service
Database
Queue
Worker
Payment API
```

A request ID helps connect logs across services.

Example:

```text
request_id=req-a1b2c3
```

Backend log:

```text
level=INFO request_id=req-a1b2c3 method=POST path=/api/todos status=201
```

Worker log:

```text
level=INFO request_id=req-a1b2c3 job=send_notification status=success
```

Production rule:

```text
Every request should have a request ID.
```

Later, OpenTelemetry traces will take this further.

---

# 12. Sensitive Data in Logs

Never log:

```text
Passwords
Tokens
API keys
Private keys
Full credit card numbers
Session cookies
Authorization headers
Personal sensitive data unless required and protected
Database connection strings with credentials
```

Bad:

```js
console.log("Authorization:", req.headers.authorization);
```

Bad:

```js
console.log("DB URL:", process.env.DATABASE_URL);
```

Better:

```js
console.log("Database configuration loaded");
```

Production rule:

```text
Logs are often copied to external systems.
Treat logs as semi-sensitive.
```

---

# 13. Nginx Logs

Nginx commonly has:

```text
/var/log/nginx/access.log
/var/log/nginx/error.log
```

Access log records requests.

Error log records Nginx errors.

View:

```bash
sudo tail -n 100 /var/log/nginx/access.log
sudo tail -n 100 /var/log/nginx/error.log
```

Follow:

```bash
sudo tail -f /var/log/nginx/access.log
```

Common access log line:

```text
10.0.0.11 - - [28/Jun/2026:10:00:01 +0000] "GET /api/todos HTTP/1.1" 200 123 "-" "Mozilla/5.0"
```

Fields often mean:

```text
IP
identity
user
timestamp
request line
status code
response size
referrer
user agent
```

Top IPs:

```bash
sudo awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -nr | head
```

Top status codes:

```bash
sudo awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -nr
```

Top paths:

```bash
sudo awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -nr | head
```

5xx errors:

```bash
sudo awk '$9 ~ /^5/ {print}' /var/log/nginx/access.log
```

404s:

```bash
sudo awk '$9 == 404 {print}' /var/log/nginx/access.log | head
```

---

# 14. Nginx 502 Troubleshooting with Logs

A `502 Bad Gateway` usually means:

```text
Nginx could not successfully talk to upstream backend.
```

Check error log:

```bash
sudo tail -n 100 /var/log/nginx/error.log
```

Common causes:

```text
Backend not running
Backend listening on wrong port
Backend listening only on wrong interface
Nginx proxy_pass wrong
Permission issue with Unix socket
Backend crashed
Firewall/security group issue
Timeout
```

Debug:

```bash
sudo ss -tulnp | grep ':3000'
curl -v http://127.0.0.1:3000/health
sudo nginx -t
sudo systemctl status nginx
journalctl -u nginx -n 100
```

Logs tell where to go next.

---

# 15. Application Logs

Application logs can go to:

```text
stdout/stderr
files under /var/log/myapp
journald through systemd
container log driver
centralized logging system
```

Modern best practice for containers:

```text
Write logs to stdout/stderr.
Let container runtime/platform collect them.
```

For systemd services:

```text
stdout/stderr automatically go to journal.
```

Example service script:

```bash
echo "app started"
echo "error happened" >&2
```

Then read:

```bash
journalctl -u myapp
```

---

# 16. Docker Logs

For containers:

```bash
docker logs <container>
```

Follow:

```bash
docker logs -f <container>
```

Last lines:

```bash
docker logs --tail 100 <container>
```

Since time:

```bash
docker logs --since 30m <container>
```

With timestamps:

```bash
docker logs -t <container>
```

Common production issue:

```text
Container logs grow and fill disk.
```

Docker logging should be configured with rotation.

Example Docker daemon config:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  }
}
```

We will cover Docker logging later in Docker module.

---

# 17. Kubernetes Logs Preview

Later in Kubernetes module:

```bash
kubectl logs pod-name
kubectl logs pod-name -c container-name
kubectl logs -f pod-name
kubectl logs --previous pod-name
```

Important:

```text
kubectl logs --previous is useful after container restart/crash.
```

But for now, understand the concept:

```text
App writes stdout/stderr.
Platform captures logs.
You query logs using platform tools.
```

---

# 18. CI/CD Logs

CI/CD logs are also production evidence.

Examples:

```text
GitHub Actions logs
Jenkins console output
Terraform plan output
Docker build output
Security scan output
Deployment logs
```

CI/CD logs must not print secrets.

Bad:

```bash
echo "$AWS_SECRET_ACCESS_KEY"
```

Good:

```bash
echo "AWS credentials configured"
```

Jenkins/GitHub often mask known secrets, but do not rely only on masking.

---

# 19. Log Rotation

Logs can fill disk.

Log rotation means:

```text
Rename old log
Create new log
Compress old log
Delete after retention period
```

Example:

```text
app.log
app.log.1
app.log.2.gz
app.log.3.gz
```

Linux commonly uses `logrotate`.

Check config:

```bash
ls -la /etc/logrotate.conf
ls -la /etc/logrotate.d/
```

View:

```bash
cat /etc/logrotate.conf
ls /etc/logrotate.d/
```

Example:

```bash
cat /etc/logrotate.d/nginx
```

---

# 20. logrotate Config Example

Create app log directory:

```bash
sudo mkdir -p /var/log/demo-app
sudo touch /var/log/demo-app/app.log
```

Example logrotate file:

```bash
sudo nano /etc/logrotate.d/demo-app
```

Paste:

```text
/var/log/demo-app/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}
```

Meaning:

```text
daily          rotate daily
rotate 7       keep 7 rotated logs
compress       gzip old logs
delaycompress  compress from second rotation
missingok      no error if log missing
notifempty     do not rotate empty logs
create         create new log with mode owner group
```

Test dry run:

```bash
sudo logrotate -d /etc/logrotate.d/demo-app
```

Force rotation:

```bash
sudo logrotate -f /etc/logrotate.d/demo-app
```

Use force carefully.

---

# 21. copytruncate vs signal reload

Some apps keep writing to the same file descriptor.

Logrotate has two common approaches:

## Better approach

Rotate file, then tell app to reopen logs.

Example for Nginx:

```text
postrotate
    invoke-rc.d nginx rotate >/dev/null 2>&1
endscript
```

## copytruncate

```text
copytruncate
```

Meaning:

```text
Copy current log to rotated file, then truncate original file in place.
```

Pros:

```text
App does not need to reopen logs.
```

Cons:

```text
Small chance of losing log lines during copy/truncate.
```

Use when app cannot reopen logs.

For apps writing to stdout/journald, this is less relevant.

---

# 22. journald Retention

Check journal disk usage:

```bash
journalctl --disk-usage
```

Clean old logs:

```bash
sudo journalctl --vacuum-time=7d
```

Limit size:

```bash
sudo journalctl --vacuum-size=500M
```

Config file:

```text
/etc/systemd/journald.conf
```

Useful settings:

```text
SystemMaxUse=
SystemKeepFree=
MaxRetentionSec=
```

Example:

```bash
sudo mkdir -p /var/log/journal
sudo systemctl restart systemd-journald
```

This can enable persistent journal logs if not already enabled.

But be careful with disk usage.

---

# 23. Log Retention

Retention means how long logs are kept.

Examples:

```text
Debug logs: 1-3 days
Application logs: 7-30 days
Security logs: 90+ days
Audit logs: 1 year or more depending on compliance
```

Retention depends on:

```text
Disk cost
Compliance
Security needs
Incident response needs
Privacy requirements
Business requirements
```

Production rule:

```text
Keep enough logs to investigate incidents, but not unlimited logs.
```

---

# 24. Create Practice Logs

Create lab:

```bash
cd ~/devops-masterclass
mkdir -p 03-linux-bash-networking/labs/logs
nano 03-linux-bash-networking/labs/logs/todo-api.log
```

Paste:

```text
2026-06-28T10:00:01+05:30 INFO service=todo-api env=dev version=v0.1.0 request_id=req-001 user=vivek method=GET path=/api/todos status=200 latency_ms=42 message="list todos"
2026-06-28T10:00:03+05:30 INFO service=todo-api env=dev version=v0.1.0 request_id=req-002 user=asha method=POST path=/api/todos status=201 latency_ms=88 message="create todo"
2026-06-28T10:00:05+05:30 WARN service=todo-api env=dev version=v0.1.0 request_id=req-003 user=rahul method=POST path=/api/todos status=429 latency_ms=18 message="rate limited"
2026-06-28T10:00:07+05:30 ERROR service=todo-api env=dev version=v0.1.0 request_id=req-004 user=vivek method=POST path=/api/todos status=500 latency_ms=1200 error="mongodb timeout"
2026-06-28T10:00:09+05:30 ERROR service=todo-api env=dev version=v0.1.0 request_id=req-005 user=asha method=GET path=/api/todos status=502 latency_ms=900 error="upstream unavailable"
2026-06-28T10:00:11+05:30 INFO service=todo-api env=dev version=v0.1.1 request_id=req-006 user=meera method=DELETE path=/api/todos/123 status=204 latency_ms=75 message="delete todo"
2026-06-28T10:00:13+05:30 ERROR service=todo-api env=dev version=v0.1.1 request_id=req-007 user=vivek method=POST path=/api/todos status=500 latency_ms=1400 error="mongodb timeout"
2026-06-28T10:00:15+05:30 INFO service=todo-api env=dev version=v0.1.1 request_id=req-008 user=vivek method=GET path=/api/health status=200 latency_ms=9 message="health check"
```

---

# 25. Basic Log Analysis Commands

Move into lab:

```bash
cd ~/devops-masterclass/03-linux-bash-networking/labs/logs
```

Count lines:

```bash
wc -l todo-api.log
```

Show errors:

```bash
grep "ERROR" todo-api.log
```

Show warnings/errors:

```bash
grep -E "WARN|ERROR" todo-api.log
```

Count log levels:

```bash
awk '{print $2}' todo-api.log | sort | uniq -c | sort -nr
```

Count status codes:

```bash
awk '{
  for (i=1; i<=NF; i++) {
    if ($i ~ /^status=/) {
      split($i,a,"=");
      print a[2]
    }
  }
}' todo-api.log | sort | uniq -c | sort -nr
```

Find slow requests above 500ms:

```bash
awk '{
  for (i=1; i<=NF; i++) {
    if ($i ~ /^latency_ms=/) {
      split($i,a,"=");
      if (a[2] > 500) print
    }
  }
}' todo-api.log
```

Find MongoDB timeout errors:

```bash
grep 'error="mongodb timeout"' todo-api.log
```

Find errors after version v0.1.1:

```bash
grep "version=v0.1.1" todo-api.log | grep "ERROR"
```

---

# 26. Incident Log Analysis Method

When investigating logs, follow this sequence:

```text
1. Define incident time window
2. Identify affected service
3. Check errors around that time
4. Compare before vs after deployment
5. Count frequency
6. Identify affected users/paths/status codes
7. Correlate request IDs
8. Check dependency errors
9. Check system logs
10. Write timeline
```

Example incident:

```text
Users report todo creation failing around 10:00.
```

Commands:

```bash
grep "POST path=/api/todos" todo-api.log
grep "ERROR" todo-api.log
grep 'error="mongodb timeout"' todo-api.log
```

Affected request IDs:

```bash
grep "ERROR" todo-api.log | grep -o "request_id=[^ ]*"
```

Affected users:

```bash
grep "ERROR" todo-api.log | grep -o "user=[^ ]*" | sort | uniq -c
```

Affected versions:

```bash
grep "ERROR" todo-api.log | grep -o "version=[^ ]*" | sort | uniq -c
```

This tells whether errors increased after a version change.

---

# 27. Create Log Triage Script

Create:

```bash
cd ~/devops-masterclass
nano 03-linux-bash-networking/scripts/log-triage.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${1:-}"
SLOW_THRESHOLD="${2:-500}"

if [ -z "$LOG_FILE" ]; then
  echo "Usage: $0 <log-file> [slow-threshold-ms]" >&2
  exit 1
fi

if [ ! -f "$LOG_FILE" ]; then
  echo "ERROR: Log file does not exist: $LOG_FILE" >&2
  exit 1
fi

if ! [[ "$SLOW_THRESHOLD" =~ ^[0-9]+$ ]]; then
  echo "ERROR: slow threshold must be numeric" >&2
  exit 1
fi

echo "===== Log Triage Report ====="
echo "File: $LOG_FILE"
echo "Slow threshold: ${SLOW_THRESHOLD}ms"
echo "Generated at: $(date -Is)"
echo

echo "===== Total Lines ====="
wc -l "$LOG_FILE"
echo

echo "===== Log Level Counts ====="
awk '{print $2}' "$LOG_FILE" | sort | uniq -c | sort -nr
echo

echo "===== Status Code Counts ====="
awk '{
  for (i=1; i<=NF; i++) {
    if ($i ~ /^status=/) {
      split($i,a,"=");
      print a[2]
    }
  }
}' "$LOG_FILE" | sort | uniq -c | sort -nr
echo

echo "===== Error Lines ====="
grep "ERROR" "$LOG_FILE" || echo "No ERROR lines found"
echo

echo "===== Slow Requests ====="
awk -v threshold="$SLOW_THRESHOLD" '{
  latency="";
  for (i=1; i<=NF; i++) {
    if ($i ~ /^latency_ms=/) {
      split($i,a,"=");
      latency=a[2]
    }
  }
  if (latency != "" && latency > threshold) {
    print
  }
}' "$LOG_FILE" || true
echo

echo "===== Top Users in Errors ====="
grep "ERROR" "$LOG_FILE" | grep -o "user=[^ ]*" | sort | uniq -c | sort -nr || true
echo

echo "===== Top Paths ====="
grep -o "path=[^ ]*" "$LOG_FILE" | sort | uniq -c | sort -nr | head -10 || true
echo

echo "===== Versions in Errors ====="
grep "ERROR" "$LOG_FILE" | grep -o "version=[^ ]*" | sort | uniq -c | sort -nr || true
echo

echo "===== Request IDs for Errors ====="
grep "ERROR" "$LOG_FILE" | grep -o "request_id=[^ ]*" || true
echo

echo "===== Done ====="
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/log-triage.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/log-triage.sh 03-linux-bash-networking/labs/logs/todo-api.log
```

With custom slow threshold:

```bash
./03-linux-bash-networking/scripts/log-triage.sh 03-linux-bash-networking/labs/logs/todo-api.log 1000
```

---

# 28. Create JSON Log Example

Create:

```bash
nano 03-linux-bash-networking/labs/logs/todo-api-json.log
```

Paste:

```json
{"timestamp":"2026-06-28T10:00:01+05:30","level":"INFO","service":"todo-api","env":"dev","version":"v0.1.0","request_id":"req-001","user":"vivek","method":"GET","path":"/api/todos","status":200,"latency_ms":42}
{"timestamp":"2026-06-28T10:00:03+05:30","level":"INFO","service":"todo-api","env":"dev","version":"v0.1.0","request_id":"req-002","user":"asha","method":"POST","path":"/api/todos","status":201,"latency_ms":88}
{"timestamp":"2026-06-28T10:00:07+05:30","level":"ERROR","service":"todo-api","env":"dev","version":"v0.1.0","request_id":"req-004","user":"vivek","method":"POST","path":"/api/todos","status":500,"latency_ms":1200,"error":"mongodb timeout"}
{"timestamp":"2026-06-28T10:00:09+05:30","level":"ERROR","service":"todo-api","env":"dev","version":"v0.1.0","request_id":"req-005","user":"asha","method":"GET","path":"/api/todos","status":502,"latency_ms":900,"error":"upstream unavailable"}
{"timestamp":"2026-06-28T10:00:13+05:30","level":"ERROR","service":"todo-api","env":"dev","version":"v0.1.1","request_id":"req-007","user":"vivek","method":"POST","path":"/api/todos","status":500,"latency_ms":1400,"error":"mongodb timeout"}
```

Analyze with `jq`.

Pretty print first line:

```bash
head -1 todo-api-json.log | jq .
```

Show errors:

```bash
jq -c 'select(.level == "ERROR")' todo-api-json.log
```

Show error request IDs:

```bash
jq -r 'select(.level == "ERROR") | .request_id' todo-api-json.log
```

Show slow requests:

```bash
jq -c 'select(.latency_ms > 1000)' todo-api-json.log
```

Count by status:

```bash
jq -r '.status' todo-api-json.log | sort | uniq -c | sort -nr
```

Show useful error summary:

```bash
jq -r 'select(.level == "ERROR") | "\(.timestamp) \(.request_id) \(.user) \(.path) status=\(.status) latency=\(.latency_ms) error=\(.error)"' todo-api-json.log
```

This is why JSON logs are powerful.

---

# 29. Create JSON Log Triage Script

Create:

```bash
nano 03-linux-bash-networking/scripts/json-log-triage.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${1:-}"
SLOW_THRESHOLD="${2:-500}"

if [ -z "$LOG_FILE" ]; then
  echo "Usage: $0 <json-log-file> [slow-threshold-ms]" >&2
  exit 1
fi

if [ ! -f "$LOG_FILE" ]; then
  echo "ERROR: Log file does not exist: $LOG_FILE" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed" >&2
  exit 1
fi

if ! [[ "$SLOW_THRESHOLD" =~ ^[0-9]+$ ]]; then
  echo "ERROR: slow threshold must be numeric" >&2
  exit 1
fi

echo "===== JSON Log Triage Report ====="
echo "File: $LOG_FILE"
echo "Slow threshold: ${SLOW_THRESHOLD}ms"
echo "Generated at: $(date -Is)"
echo

echo "===== Total Lines ====="
wc -l "$LOG_FILE"
echo

echo "===== Level Counts ====="
jq -r '.level' "$LOG_FILE" | sort | uniq -c | sort -nr
echo

echo "===== Status Counts ====="
jq -r '.status' "$LOG_FILE" | sort | uniq -c | sort -nr
echo

echo "===== Errors ====="
jq -r '
  select(.level == "ERROR")
  | "\(.timestamp) request_id=\(.request_id) user=\(.user) path=\(.path) status=\(.status) latency_ms=\(.latency_ms) error=\(.error // "unknown")"
' "$LOG_FILE"
echo

echo "===== Slow Requests ====="
jq -r --argjson threshold "$SLOW_THRESHOLD" '
  select(.latency_ms > $threshold)
  | "\(.timestamp) request_id=\(.request_id) user=\(.user) path=\(.path) status=\(.status) latency_ms=\(.latency_ms)"
' "$LOG_FILE"
echo

echo "===== Error Request IDs ====="
jq -r 'select(.level == "ERROR") | .request_id' "$LOG_FILE"
echo

echo "===== Done ====="
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/json-log-triage.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/json-log-triage.sh 03-linux-bash-networking/labs/logs/todo-api-json.log
```

---

# 30. Logs During Deployment

During deployment, always watch logs.

Example systemd app:

```bash
journalctl -u todo-api -f
```

In another terminal:

```bash
sudo systemctl restart todo-api
```

Watch for:

```text
Startup errors
Missing env variables
Permission denied
Port already in use
Database connection failures
Unhandled exceptions
Health check failures
Restart loops
```

For Nginx reload:

```bash
sudo nginx -t
sudo systemctl reload nginx
sudo tail -f /var/log/nginx/error.log
```

For Docker:

```bash
docker compose up -d
docker compose logs -f backend
```

For Kubernetes later:

```bash
kubectl rollout status deployment/todo-api
kubectl logs -f deployment/todo-api
```

---

# 31. Incident Timeline from Logs

A good incident timeline looks like:

```text
10:00:01 deployment v0.1.1 started
10:00:05 todo-api restarted
10:00:07 first 500 error for POST /api/todos
10:00:09 Nginx reports upstream timeout
10:00:13 MongoDB timeout repeated
10:02:00 rollback to v0.1.0 started
10:03:00 error rate returned to normal
```

Logs help build this.

Command idea:

```bash
grep -E "ERROR|WARN|deploy|restart|timeout" todo-api.log
```

If systemd:

```bash
journalctl -u todo-api --since "2026-06-28 10:00:00" --until "2026-06-28 10:10:00"
```

If multiple logs:

```bash
grep -h "2026-06-28T10:" app.log worker.log nginx.log | sort
```

This combines and sorts logs.

---

# 32. Log-Based Alerting Basics

Later in observability module, we will use Loki/ELK/Prometheus.

But conceptually, alerts may trigger on:

```text
High 5xx count
Repeated ERROR logs
Authentication failures
OOM killer events
Disk full messages
Service restart loops
Queue processing failures
Payment failures
Database connection errors
```

Bad alert:

```text
Any single ERROR log
```

This can be noisy.

Better alert:

```text
5xx errors > 5% for 5 minutes
```

or:

```text
MongoDB timeout errors > 10 in 5 minutes
```

Production rule:

```text
Alert on user impact and actionable symptoms.
```

---

# 33. Common Logging Mistakes

## Mistake 1 — No timestamps

Bad:

```text
database error
```

Good:

```text
2026-06-28T10:00:07+05:30 ERROR database error
```

## Mistake 2 — No request ID

Bad:

```text
failed to create todo
```

Good:

```text
request_id=req-123 failed to create todo
```

## Mistake 3 — Logging secrets

Bad:

```text
token=eyJhbGciOi...
```

Good:

```text
token_present=true
```

## Mistake 4 — Too much debug logging in production

Bad:

```text
Log every SQL query with user data forever
```

Good:

```text
Enable debug temporarily during investigation.
```

## Mistake 5 — No retention

Bad:

```text
Logs grow forever until disk fills.
```

Good:

```text
Use logrotate/journald retention/centralized logging retention.
```

---

# 34. Script — Journal Error Summary

Create:

```bash
cd ~/devops-masterclass
nano 03-linux-bash-networking/scripts/journal-error-summary.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SERVICE="${1:-}"
SINCE="${2:-1 hour ago}"

if [ -z "$SERVICE" ]; then
  echo "Usage: $0 <service-name> [since]" >&2
  echo "Example: $0 nginx '30 minutes ago'" >&2
  exit 1
fi

echo "===== Journal Error Summary ====="
echo "Service: $SERVICE"
echo "Since: $SINCE"
echo "Generated at: $(date -Is)"
echo

echo "===== Service State ====="
systemctl status "$SERVICE" --no-pager || true
echo

echo "===== Error Priority Logs ====="
journalctl -u "$SERVICE" --since "$SINCE" -p err --no-pager || true
echo

echo "===== Warning/Error Keyword Search ====="
journalctl -u "$SERVICE" --since "$SINCE" -o cat --no-pager \
  | grep -Ei "error|failed|failure|timeout|denied|refused|unavailable|exception" \
  || echo "No matching warning/error keywords found"
echo

echo "===== Restart/Start/Stop Events ====="
journalctl -u "$SERVICE" --since "$SINCE" -o cat --no-pager \
  | grep -Ei "start|stop|restart|exited|failed" \
  || echo "No lifecycle events found"
echo

echo "Done."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/journal-error-summary.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/journal-error-summary.sh ssh "1 hour ago"
```

or:

```bash
./03-linux-bash-networking/scripts/journal-error-summary.sh demo-service "10 minutes ago"
```

---

# 35. Create Notes

Create:

```bash
nano 03-linux-bash-networking/logs.md
```

Paste:

````markdown
# Logs Masterclass

## Why Logs Matter

Logs are timestamped evidence of system, service, application, security, and deployment events.

Logs help answer:

- What happened?
- When did it happen?
- Which service failed?
- Which request/user was affected?
- What changed before failure?
- What is the root cause?
- What should be rolled back?

## Common Log Locations

| Location | Purpose |
|---|---|
| `/var/log/syslog` | general system logs |
| `/var/log/auth.log` | authentication and sudo logs |
| `/var/log/kern.log` | kernel logs |
| `/var/log/nginx/access.log` | Nginx request logs |
| `/var/log/nginx/error.log` | Nginx error logs |
| `journalctl -u service` | systemd service logs |
| `docker logs container` | container logs |
| `kubectl logs pod` | Kubernetes pod logs |

## journalctl Commands

```bash
journalctl -u myapp
journalctl -u myapp -n 100
journalctl -u myapp -f
journalctl -u myapp --since "30 minutes ago"
journalctl -u myapp -p err
journalctl -b
journalctl -b -1
journalctl -k
journalctl --disk-usage
sudo journalctl --vacuum-time=7d
````

## Log Levels

* TRACE
* DEBUG
* INFO
* WARN
* ERROR
* FATAL

## Good Log Fields

* timestamp
* level
* service
* environment
* version
* request_id
* user_id
* method
* path
* status
* latency_ms
* error

## Log Analysis Commands

```bash
grep "ERROR" app.log
grep -E "WARN|ERROR" app.log
awk '{print $2}' app.log | sort | uniq -c | sort -nr
awk '{print $9}' access.log | sort | uniq -c | sort -nr
journalctl -u nginx --since "30 minutes ago"
docker logs --tail 100 container
jq -r 'select(.level == "ERROR") | .request_id' app-json.log
```

## Rules

* Logs need timestamps.
* Use request IDs for correlation.
* Do not log secrets.
* Use structured logs where possible.
* Use logrotate or journald retention.
* Watch logs during deployment.
* Build incident timelines from logs.
* Alert on user impact, not noise.

````

Commit:

```bash
git status
git diff

git add 03-linux-bash-networking/logs.md \
        03-linux-bash-networking/labs/logs \
        03-linux-bash-networking/scripts/log-triage.sh \
        03-linux-bash-networking/scripts/json-log-triage.sh \
        03-linux-bash-networking/scripts/journal-error-summary.sh

git diff --staged

git commit -m "docs: add logs masterclass"
git push
````

---

# 36. Real Production Scenario — API 500 Errors

Incident:

```text
Users report todo creation failing.
```

Triage:

```bash
journalctl -u todo-api --since "30 minutes ago" -p err
```

Check app logs:

```bash
grep -E "ERROR|WARN" /var/log/todo-api/app.log | tail -50
```

Count errors:

```bash
grep "ERROR" /var/log/todo-api/app.log | wc -l
```

Find failing path:

```bash
grep "ERROR" /var/log/todo-api/app.log | grep -o "path=[^ ]*" | sort | uniq -c | sort -nr
```

Find versions in errors:

```bash
grep "ERROR" /var/log/todo-api/app.log | grep -o "version=[^ ]*" | sort | uniq -c
```

If errors started after new version, rollback may be fastest mitigation.

---

# 37. Real Production Scenario — Suspicious SSH Attempts

Check failed logins:

```bash
sudo grep "Failed password" /var/log/auth.log | tail -50
```

Count source IPs:

```bash
sudo grep "Failed password" /var/log/auth.log \
  | grep -oE 'from ([0-9]{1,3}\.){3}[0-9]{1,3}' \
  | awk '{print $2}' \
  | sort | uniq -c | sort -nr | head
```

Check accepted logins:

```bash
sudo grep "Accepted" /var/log/auth.log
```

Mitigations:

```text
Disable password auth
Use SSH keys
Restrict security group/firewall
Use fail2ban if appropriate
Use VPN/bastion/SSM
Review users and authorized_keys
```

---

# 38. Real Production Scenario — OOM Killer

App disappears.

Check service:

```bash
systemctl status todo-api
```

Check kernel logs:

```bash
journalctl -k --since "1 hour ago" | grep -Ei "killed process|out of memory|oom"
```

If OOM:

```text
Kernel killed the process because system memory was exhausted.
```

Next steps:

```text
Check memory usage
Check app memory leaks
Check traffic spike
Check container/system limits
Add memory monitoring
Tune service
Scale or increase memory
```

Commands:

```bash
free -h
ps -eo pid,user,%mem,rss,cmd --sort=-%mem | head
```

---

# 39. Interview Answers

Question:

```text
How do you use logs during an incident?
```

Strong answer:

```text
I first define the incident time window and affected service. Then I check service logs using journalctl or application log files, filtering for ERROR, WARN, timeouts, denied, refused, and dependency failures. I count frequency, identify affected paths, users, status codes, versions, and request IDs. I compare logs before and after deployment and correlate with system logs such as kernel OOM or auth logs if needed. Finally, I build a timeline and use the evidence to decide whether to rollback, fix config, restart a service, or escalate.
```

Question:

```text
What should not be logged?
```

Strong answer:

```text
Secrets should not be logged. That includes passwords, tokens, API keys, private keys, session cookies, authorization headers, and database URLs containing credentials. Sensitive personal data should also be avoided unless there is a specific protected logging requirement. Logs are often shipped to centralized systems, so I treat them as semi-sensitive.
```

Question:

```text
What is log rotation and why is it needed?
```

Strong answer:

```text
Log rotation is the process of periodically rotating, compressing, and deleting old logs based on time or size. It prevents logs from growing forever and filling disk. On Linux, logrotate is commonly used for file logs, while journald has its own retention and vacuum settings. Good retention keeps enough logs for investigation without risking disk exhaustion.
```

Question:

```text
Why are structured logs useful?
```

Strong answer:

```text
Structured logs store events in consistent key-value or JSON format. They are easier to parse, search, aggregate, alert on, and visualize. Fields like service, environment, version, request_id, path, status, and latency make incident analysis much faster than free-form text logs.
```

---

# Today’s Core Rules

```text
Logs are production evidence.
Start with the incident time window.
Use journalctl for systemd services.
Use /var/log for traditional logs.
Use grep/awk/jq to summarize logs.
Use request IDs for correlation.
Do not log secrets.
Prefer structured logs.
Watch logs during deployment.
Use log rotation and retention.
Check kernel logs for OOM and hardware/system issues.
Build timelines from logs.
Alert on actionable user-impacting symptoms.
```

Next lesson:

# Lesson 3.10 — Disk and Storage Masterclass: df, du, lsblk, mount, fstab, inodes, log cleanup, disk-full incidents, and safe storage operations

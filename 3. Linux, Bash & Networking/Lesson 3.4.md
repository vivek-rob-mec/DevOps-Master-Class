# Lesson 3.4 — Text Processing Masterclass

Now we learn one of the most powerful Linux skills:

```text
Reading, filtering, transforming, and analyzing text.
```

This is a core DevOps skill because almost everything is text:

```text
Logs
Config files
YAML
JSON
.env files
Dockerfiles
Nginx configs
Systemd units
Terraform plans
Kubernetes manifests
CI/CD output
Application error traces
```

A beginner opens files manually.

A DevOps engineer uses pipelines:

```bash
cat app.log | grep ERROR | awk '{print $1,$2}' | sort | uniq -c | sort -nr
```

But we will learn this properly, not blindly.

---

# 1. Why Text Processing Matters in DevOps

In real production work, you often need to answer questions fast:

```text
What errors happened in the last 10 minutes?
Which IP is hitting the server most?
Which endpoint is slow?
Which process is writing logs?
Which config line changed?
Which Kubernetes pod is failing?
Which Terraform resource will be destroyed?
Which JSON field contains the image tag?
```

Linux gives you small tools that can be combined:

```text
cat
less
head
tail
grep
awk
sed
cut
sort
uniq
wc
tr
xargs
jq
```

These tools become extremely powerful when connected with pipes.

---

# 2. Core Idea — Input, Filter, Transform, Output

Most text processing follows this pattern:

```text
Input → Filter → Transform → Aggregate → Output
```

Example:

```bash
grep "ERROR" app.log | awk '{print $1}' | sort | uniq -c
```

Meaning:

```text
Input: app.log
Filter: only ERROR lines
Transform: print first column
Aggregate: count unique values
Output: summary
```

This pattern will appear everywhere.

---

# 3. Create Practice Log File

Create a lab file:

```bash
cd ~/devops-masterclass
mkdir -p 03-linux-bash-networking/labs/text-processing
nano 03-linux-bash-networking/labs/text-processing/app.log
```

Paste:

```text
2026-06-28T10:00:01Z INFO user=vivek ip=10.0.0.11 method=GET path=/api/todos status=200 latency_ms=45
2026-06-28T10:00:03Z INFO user=asha ip=10.0.0.12 method=GET path=/api/todos status=200 latency_ms=51
2026-06-28T10:00:05Z WARN user=rahul ip=10.0.0.13 method=POST path=/api/todos status=429 latency_ms=20
2026-06-28T10:00:07Z ERROR user=vivek ip=10.0.0.11 method=POST path=/api/todos status=500 latency_ms=340
2026-06-28T10:00:09Z INFO user=meera ip=10.0.0.14 method=DELETE path=/api/todos/123 status=204 latency_ms=80
2026-06-28T10:00:11Z ERROR user=asha ip=10.0.0.12 method=GET path=/api/todos status=502 latency_ms=1200
2026-06-28T10:00:13Z INFO user=vivek ip=10.0.0.11 method=GET path=/api/health status=200 latency_ms=10
2026-06-28T10:00:15Z WARN user=rahul ip=10.0.0.13 method=GET path=/api/todos status=429 latency_ms=25
2026-06-28T10:00:17Z ERROR user=guest ip=10.0.0.99 method=GET path=/admin status=403 latency_ms=15
2026-06-28T10:00:19Z INFO user=meera ip=10.0.0.14 method=POST path=/api/todos status=201 latency_ms=95
2026-06-28T10:00:21Z ERROR user=vivek ip=10.0.0.11 method=POST path=/api/todos status=500 latency_ms=410
2026-06-28T10:00:23Z INFO user=asha ip=10.0.0.12 method=GET path=/api/todos status=200 latency_ms=49
```

Now work inside:

```bash
cd 03-linux-bash-networking/labs/text-processing
```

---

# 4. `cat` — Print File Content

Basic:

```bash
cat app.log
```

With line numbers:

```bash
cat -n app.log
```

Show hidden/control characters:

```bash
cat -A app.log
```

Use `cat` for small files.

Do not use `cat` for huge logs unless you really mean it.

Bad:

```bash
cat /var/log/syslog
```

Better:

```bash
less /var/log/syslog
```

or:

```bash
tail -100 /var/log/syslog
```

---

# 5. `less` — Read Large Files Safely

Open file:

```bash
less app.log
```

Inside `less`:

```text
Space       next page
b           previous page
/ERROR      search forward for ERROR
n           next match
N           previous match
q           quit
G           go to end
g           go to beginning
```

Follow mode, similar to `tail -f`:

```bash
less +F app.log
```

Inside follow mode:

```text
Ctrl+C      stop following
q           quit
```

Production use:

```bash
sudo less /var/log/syslog
sudo less /var/log/nginx/error.log
```

---

# 6. `head` and `tail`

First lines:

```bash
head app.log
```

First 3 lines:

```bash
head -3 app.log
```

Last lines:

```bash
tail app.log
```

Last 5 lines:

```bash
tail -5 app.log
```

Follow file:

```bash
tail -f app.log
```

Follow with last 100 lines:

```bash
tail -n 100 -f app.log
```

Production use:

```bash
sudo tail -n 100 -f /var/log/nginx/error.log
```

For systemd logs, use:

```bash
journalctl -u nginx -f
```

We will cover `journalctl` deeply later.

---

# 7. `wc` — Count Lines, Words, Bytes

Count lines:

```bash
wc -l app.log
```

Count words:

```bash
wc -w app.log
```

Count bytes:

```bash
wc -c app.log
```

Count matching lines:

```bash
grep "ERROR" app.log | wc -l
```

Meaning:

```text
How many ERROR lines are in this log?
```

---

# 8. `grep` — Search Text

Basic search:

```bash
grep "ERROR" app.log
```

Case-insensitive:

```bash
grep -i "error" app.log
```

Show line numbers:

```bash
grep -n "ERROR" app.log
```

Invert match:

```bash
grep -v "INFO" app.log
```

Show only matching part:

```bash
grep -o "status=[0-9]*" app.log
```

Extended regex:

```bash
grep -E "ERROR|WARN" app.log
```

Recursive search:

```bash
grep -R "TODO" .
```

Exclude directory:

```bash
grep -R "TODO" . --exclude-dir=.git
```

Search only certain files:

```bash
grep -R "ERROR" . --include="*.log"
```

Count matches per file:

```bash
grep -R -c "ERROR" . --include="*.log"
```

---

# 9. Useful `grep` Patterns

Find 5xx status codes:

```bash
grep -E "status=5[0-9][0-9]" app.log
```

Find 4xx status codes:

```bash
grep -E "status=4[0-9][0-9]" app.log
```

Find errors and warnings:

```bash
grep -E "ERROR|WARN" app.log
```

Find specific IP:

```bash
grep "ip=10.0.0.11" app.log
```

Find admin access:

```bash
grep "path=/admin" app.log
```

Find high latency roughly starting with 4 digits:

```bash
grep -E "latency_ms=[0-9]{4,}" app.log
```

This catches:

```text
latency_ms=1200
```

---

# 10. `cut` — Extract Columns

`cut` is simple and fast when data has clear delimiters.

Example:

```bash
echo "user=vivek ip=10.0.0.11 status=200" | cut -d' ' -f1
```

Output:

```text
user=vivek
```

From log:

```bash
cut -d' ' -f1 app.log
```

Gets timestamps.

Second column:

```bash
cut -d' ' -f2 app.log
```

Gets log levels.

Problem:

```text
cut is simple, but not flexible when spacing varies.
```

For complex extraction, use `awk`.

---

# 11. `awk` — Column Processing Power Tool

Print first column:

```bash
awk '{print $1}' app.log
```

Print first and second column:

```bash
awk '{print $1, $2}' app.log
```

Print log level and path field:

```bash
awk '{print $2, $6}' app.log
```

In our log format:

```text
$1 timestamp
$2 level
$3 user=...
$4 ip=...
$5 method=...
$6 path=...
$7 status=...
$8 latency_ms=...
```

Print only ERROR lines:

```bash
awk '$2 == "ERROR" {print}' app.log
```

Print path and status for errors:

```bash
awk '$2 == "ERROR" {print $6, $7}' app.log
```

Count lines by status:

```bash
awk '{print $7}' app.log | sort | uniq -c | sort -nr
```

Output example:

```text
4 status=200
2 status=500
2 status=429
1 status=502
1 status=403
1 status=204
1 status=201
```

---

# 12. `awk` with Field Separator

Our fields are separated by spaces, but key-value pairs use `=`.

Extract status code:

```bash
awk '{split($7,a,"="); print a[2]}' app.log
```

Meaning:

```text
Take field 7: status=200
Split by =
a[1] = status
a[2] = 200
Print a[2]
```

Count status codes:

```bash
awk '{split($7,a,"="); print a[2]}' app.log | sort | uniq -c | sort -nr
```

Extract IPs:

```bash
awk '{split($4,a,"="); print a[2]}' app.log
```

Count requests per IP:

```bash
awk '{split($4,a,"="); print a[2]}' app.log | sort | uniq -c | sort -nr
```

Extract latency:

```bash
awk '{split($8,a,"="); print a[2]}' app.log
```

Show slow requests above 300ms:

```bash
awk '{split($8,a,"="); if (a[2] > 300) print}' app.log
```

Show path and latency for slow requests:

```bash
awk '{split($8,l,"="); if (l[2] > 300) print $6, $8}' app.log
```

---

# 13. `sort` — Sort Lines

Sort alphabetically:

```bash
awk '{print $2}' app.log | sort
```

Sort numerically:

```bash
printf "10\n2\n100\n" | sort -n
```

Reverse sort:

```bash
printf "10\n2\n100\n" | sort -nr
```

Human-readable sort:

```bash
du -h . | sort -hr
```

Use case:

```bash
du -h --max-depth=1 /var 2>/dev/null | sort -hr | head
```

---

# 14. `uniq` — Unique Adjacent Lines

Important:

```text
uniq only works properly on sorted input when counting all duplicates.
```

Bad:

```bash
awk '{print $2}' app.log | uniq -c
```

Better:

```bash
awk '{print $2}' app.log | sort | uniq -c
```

Sort by count descending:

```bash
awk '{print $2}' app.log | sort | uniq -c | sort -nr
```

Count log levels:

```bash
awk '{print $2}' app.log | sort | uniq -c | sort -nr
```

---

# 15. `sed` — Stream Editor

`sed` can replace, delete, and transform text.

Replace first occurrence per line:

```bash
sed 's/ERROR/ERR/' app.log
```

Replace globally per line:

```bash
sed 's/status=/http_status=/g' app.log
```

Print specific lines:

```bash
sed -n '1,5p' app.log
```

Delete lines matching pattern:

```bash
sed '/INFO/d' app.log
```

Edit file in-place with backup:

```bash
sed -i.bak 's/old/new/g' file.txt
```

Important:

```text
Be careful with sed -i.
Use backup suffix first.
```

Good:

```bash
sed -i.bak 's/localhost/127.0.0.1/g' config.txt
```

Then compare:

```bash
diff -u config.txt.bak config.txt
```

---

# 16. `tr` — Translate Characters

Convert lowercase to uppercase:

```bash
echo "hello" | tr 'a-z' 'A-Z'
```

Replace spaces with newlines:

```bash
echo "one two three" | tr ' ' '\n'
```

Delete characters:

```bash
echo "hello!!!" | tr -d '!'
```

Useful for simple transformations.

---

# 17. `jq` — JSON Processing

`jq` is essential in DevOps.

Install if missing:

```bash
sudo apt update
sudo apt install -y jq
```

Create JSON file:

```bash
nano response.json
```

Paste:

```json
{
  "service": "todo-api",
  "environment": "staging",
  "version": "v1.2.0",
  "status": "healthy",
  "metrics": {
    "requests": 1200,
    "errors": 12,
    "p95_latency_ms": 430
  },
  "pods": [
    {
      "name": "todo-api-abc",
      "status": "Running",
      "restarts": 0
    },
    {
      "name": "todo-api-def",
      "status": "CrashLoopBackOff",
      "restarts": 5
    }
  ]
}
```

Pretty print:

```bash
jq . response.json
```

Extract field:

```bash
jq '.service' response.json
```

Raw output:

```bash
jq -r '.service' response.json
```

Extract nested field:

```bash
jq '.metrics.p95_latency_ms' response.json
```

Extract array items:

```bash
jq '.pods[]' response.json
```

Extract pod names:

```bash
jq -r '.pods[].name' response.json
```

Filter pods not running:

```bash
jq -r '.pods[] | select(.status != "Running") | .name' response.json
```

Print name and restarts:

```bash
jq -r '.pods[] | "\(.name) \(.status) restarts=\(.restarts)"' response.json
```

Real DevOps use:

```bash
kubectl get pods -o json | jq -r '.items[].metadata.name'
```

AWS use:

```bash
aws ec2 describe-instances | jq '.Reservations[].Instances[].InstanceId'
```

GitHub API use:

```bash
curl -s https://api.github.com/repos/OWNER/REPO | jq -r '.default_branch'
```

---

# 18. Log Analysis Patterns

## Count errors

```bash
grep "ERROR" app.log | wc -l
```

## Count by log level

```bash
awk '{print $2}' app.log | sort | uniq -c | sort -nr
```

## Count by status code

```bash
awk '{split($7,a,"="); print a[2]}' app.log | sort | uniq -c | sort -nr
```

## Count by IP

```bash
awk '{split($4,a,"="); print a[2]}' app.log | sort | uniq -c | sort -nr
```

## Show 5xx errors

```bash
awk '{split($7,s,"="); if (s[2] >= 500) print}' app.log
```

## Show slow requests

```bash
awk '{split($8,l,"="); if (l[2] > 300) print}' app.log
```

## Top paths

```bash
awk '{split($6,p,"="); print p[2]}' app.log | sort | uniq -c | sort -nr
```

## Top user errors

```bash
awk '$2 == "ERROR" {print $3}' app.log | sort | uniq -c | sort -nr
```

---

# 19. Pipelines for Real Troubleshooting

Question:

```text
Which IP caused the most 5xx errors?
```

Command:

```bash
awk '{split($7,s,"="); if (s[2] >= 500) print $4}' app.log | sort | uniq -c | sort -nr
```

Question:

```text
Which path has the most requests?
```

Command:

```bash
awk '{split($6,p,"="); print p[2]}' app.log | sort | uniq -c | sort -nr
```

Question:

```text
Which requests were slow?
```

Command:

```bash
awk '{split($8,l,"="); if (l[2] > 300) print $1, $3, $6, $7, $8}' app.log
```

Question:

```text
How many non-200 responses?
```

Command:

```bash
awk '{split($7,s,"="); if (s[2] != 200) print}' app.log | wc -l
```

Better classification:

```bash
awk '{
  split($7,s,"=");
  code=s[2];
  if (code >= 200 && code < 300) success++;
  else if (code >= 400 && code < 500) client++;
  else if (code >= 500) server++;
}
END {
  print "2xx:", success+0;
  print "4xx:", client+0;
  print "5xx:", server+0;
}' app.log
```

---

# 20. Create Log Analyzer Script

Create:

```bash
cd ~/devops-masterclass
mkdir -p 03-linux-bash-networking/scripts
nano 03-linux-bash-networking/scripts/log-summary.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${1:-}"

if [ -z "$LOG_FILE" ]; then
  echo "Usage: $0 <log-file>" >&2
  exit 1
fi

if [ ! -f "$LOG_FILE" ]; then
  echo "ERROR: Log file does not exist: $LOG_FILE" >&2
  exit 1
fi

echo "===== Log Summary ====="
echo "File: $LOG_FILE"
echo "Generated at: $(date)"
echo

echo "===== Total Lines ====="
wc -l "$LOG_FILE"
echo

echo "===== Log Levels ====="
awk '{print $2}' "$LOG_FILE" | sort | uniq -c | sort -nr
echo

echo "===== Status Codes ====="
awk '{
  for (i=1; i<=NF; i++) {
    if ($i ~ /^status=/) {
      split($i,a,"=");
      print a[2];
    }
  }
}' "$LOG_FILE" | sort | uniq -c | sort -nr
echo

echo "===== Top IPs ====="
awk '{
  for (i=1; i<=NF; i++) {
    if ($i ~ /^ip=/) {
      split($i,a,"=");
      print a[2];
    }
  }
}' "$LOG_FILE" | sort | uniq -c | sort -nr | head -10
echo

echo "===== Top Paths ====="
awk '{
  for (i=1; i<=NF; i++) {
    if ($i ~ /^path=/) {
      split($i,a,"=");
      print a[2];
    }
  }
}' "$LOG_FILE" | sort | uniq -c | sort -nr | head -10
echo

echo "===== Slow Requests > 300ms ====="
awk '{
  latency=0;
  for (i=1; i<=NF; i++) {
    if ($i ~ /^latency_ms=/) {
      split($i,a,"=");
      latency=a[2];
    }
  }
  if (latency > 300) {
    print;
  }
}' "$LOG_FILE"
echo

echo "===== 5xx Errors ====="
awk '{
  status=0;
  for (i=1; i<=NF; i++) {
    if ($i ~ /^status=/) {
      split($i,a,"=");
      status=a[2];
    }
  }
  if (status >= 500) {
    print;
  }
}' "$LOG_FILE"
echo

echo "===== Done ====="
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/log-summary.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/log-summary.sh 03-linux-bash-networking/labs/text-processing/app.log
```

---

# 21. Why This Script is Better Than One-Liners

One-liners are good for quick investigation.

Scripts are better when:

```text
You repeat the task often
You want consistent output
You want to share with team
You want CI/CD usage
You want operational runbook tooling
```

This script gives:

```text
Total lines
Log level counts
Status code counts
Top IPs
Top paths
Slow requests
5xx errors
```

This is already close to a real production log triage script.

---

# 22. Make Script More Flexible

Later we can improve it with options:

```bash
./log-summary.sh app.log --slow-threshold 500
./log-summary.sh app.log --only-errors
./log-summary.sh app.log --json
```

But for now, keep it simple.

Simple scripts are easier to debug.

---

# 23. Create Text Processing Notes

Create:

```bash
nano 03-linux-bash-networking/text-processing.md
```

Paste:

````markdown
# Text Processing Masterclass

## Mental Model

Most text processing follows:

```text
Input → Filter → Transform → Aggregate → Output
````

## Core Tools

| Tool   | Purpose                          |
| ------ | -------------------------------- |
| `cat`  | Print small files                |
| `less` | Read large files safely          |
| `head` | Show first lines                 |
| `tail` | Show last lines or follow logs   |
| `wc`   | Count lines/words/bytes          |
| `grep` | Search/filter text               |
| `cut`  | Extract delimited columns        |
| `awk`  | Process columns and patterns     |
| `sed`  | Edit/transform streams           |
| `sort` | Sort lines                       |
| `uniq` | Count/remove adjacent duplicates |
| `tr`   | Translate/delete characters      |
| `jq`   | Process JSON                     |

## Useful Commands

```bash
grep "ERROR" app.log
grep -E "ERROR|WARN" app.log
grep -E "status=5[0-9][0-9]" app.log
awk '{print $2}' app.log | sort | uniq -c | sort -nr
awk '{split($7,a,"="); print a[2]}' app.log | sort | uniq -c | sort -nr
awk '{split($8,l,"="); if (l[2] > 300) print}' app.log
jq -r '.pods[].name' response.json
```

## Rules

* Use `less` for large files.
* Use `tail -f` for live logs.
* Use `grep` for filtering.
* Use `awk` for field extraction and calculations.
* Use `sed -i.bak` when editing files in-place.
* Sort before using `uniq -c`.
* Use `jq` for JSON, not grep.
* Build pipelines step by step.

````

Commit:

```bash
git status
git diff

git add 03-linux-bash-networking/text-processing.md \
        03-linux-bash-networking/labs/text-processing/app.log \
        03-linux-bash-networking/labs/text-processing/response.json \
        03-linux-bash-networking/scripts/log-summary.sh

git diff --staged

git commit -m "docs: add text processing masterclass"
git push
````

If `response.json` was not created, either create it from section 17 or remove it from `git add`.

---

# 24. Real Production Scenario — Nginx Access Log

Nginx access log may look like:

```text
10.0.0.11 - - [28/Jun/2026:10:00:01 +0000] "GET /api/todos HTTP/1.1" 200 123 "-" "Mozilla/5.0"
```

Top IPs:

```bash
awk '{print $1}' access.log | sort | uniq -c | sort -nr | head
```

Top status codes:

```bash
awk '{print $9}' access.log | sort | uniq -c | sort -nr
```

Top requested paths:

```bash
awk '{print $7}' access.log | sort | uniq -c | sort -nr | head
```

5xx errors:

```bash
awk '$9 ~ /^5/ {print}' access.log
```

404s:

```bash
awk '$9 == 404 {print}' access.log
```

---

# 25. Real Production Scenario — App Log Triage

Incident:

```text
Users report API errors.
```

First:

```bash
tail -n 100 app.log
```

Then:

```bash
grep -E "ERROR|WARN" app.log | tail -50
```

Count errors:

```bash
grep "ERROR" app.log | wc -l
```

Find 5xx:

```bash
grep -E "status=5[0-9][0-9]" app.log
```

Find slow requests:

```bash
awk '{split($8,l,"="); if (l[2] > 500) print}' app.log
```

Summarize:

```bash
./log-summary.sh app.log
```

This is real production work.

---

# 26. Real Production Scenario — JSON API Debugging

Check health API:

```bash
curl -s https://api.example.com/health | jq .
```

Extract status:

```bash
curl -s https://api.example.com/health | jq -r '.status'
```

Check version:

```bash
curl -s https://api.example.com/health | jq -r '.version'
```

In Kubernetes:

```bash
kubectl get pods -n production -o json | jq -r '.items[] | "\(.metadata.name) \(.status.phase)"'
```

Find non-running pods:

```bash
kubectl get pods -n production -o json | jq -r '.items[] | select(.status.phase != "Running") | .metadata.name'
```

This is why `jq` is non-negotiable for DevOps.

---

# 27. Common Beginner Mistakes

## Mistake 1 — Grepping JSON

Bad:

```bash
curl -s api/health | grep status
```

Better:

```bash
curl -s api/health | jq -r '.status'
```

---

## Mistake 2 — Using `cat` Unnecessarily

Not terrible:

```bash
cat app.log | grep ERROR
```

Better:

```bash
grep ERROR app.log
```

But do not be too dogmatic. In long pipelines, `cat` can improve readability.

---

## Mistake 3 — Forgetting `sort` Before `uniq`

Bad:

```bash
awk '{print $2}' app.log | uniq -c
```

Better:

```bash
awk '{print $2}' app.log | sort | uniq -c
```

---

## Mistake 4 — Editing with `sed -i` Without Backup

Bad:

```bash
sed -i 's/dev/prod/g' config.env
```

Better:

```bash
sed -i.bak 's/dev/prod/g' config.env
diff -u config.env.bak config.env
```

---

## Mistake 5 — Not Quoting Patterns

Bad:

```bash
find . -name *.log
```

Better:

```bash
find . -name "*.log"
```

Why?

The shell may expand `*.log` before `find` receives it.

---

# 28. Practice Challenges

Use `app.log`.

Answer these using commands:

```text
1. How many total log lines?
2. How many ERROR lines?
3. How many WARN lines?
4. Which IP appears most?
5. Which path appears most?
6. How many 5xx responses?
7. Which requests are slower than 300ms?
8. Which users caused ERROR logs?
9. Count status codes.
10. Show only timestamp, user, path, status, latency for slow requests.
```

Example answer for #10:

```bash
awk '{
  user=$3; path=$6; status=$7; latency=$8;
  split(latency,l,"=");
  if (l[2] > 300) print $1, user, path, status, latency;
}' app.log
```

---

# 29. Interview Answers

Question:

```text
How do you analyze logs in Linux?
```

Strong answer:

```text
I start by checking recent logs using tail or less. Then I filter relevant patterns with grep, such as ERROR, WARN, or 5xx status codes. For structured or semi-structured logs, I use awk to extract fields like status code, IP, path, and latency. Then I aggregate with sort, uniq -c, and wc to identify top errors, noisy IPs, slow endpoints, or common failure patterns. For JSON logs or API responses, I use jq instead of grep.
```

Question:

```text
What is the difference between grep, awk, sed, and jq?
```

Strong answer:

```text
grep is mainly for searching and filtering lines. awk is for field-based processing, extraction, and simple calculations. sed is for stream editing and text replacement. jq is for parsing and querying JSON safely. In DevOps, I use grep to find lines, awk to summarize logs, sed to transform config carefully, and jq to inspect API, AWS, Docker, or Kubernetes JSON output.
```

Question:

```text
Why should you sort before uniq -c?
```

Strong answer:

```text
uniq only counts adjacent duplicate lines. If the same value appears in different parts of the input, uniq will treat them separately unless the input is sorted first. So for accurate counting, I usually use sort before uniq -c.
```

---

# Today’s Core Rules

```text
Logs are text until you make them useful.
Use less for large files.
Use tail -f for live logs.
Use grep to filter.
Use awk to extract and summarize.
Use sed carefully, preferably with backups.
Use jq for JSON.
Sort before uniq -c.
Build pipelines step by step.
Turn repeated one-liners into scripts.
Never grep JSON when jq is available.
```

Next lesson:

# Lesson 3.5 — Permissions Masterclass: chmod, chown, groups, umask, sticky bit, setuid, setgid, sudo, SSH key permissions

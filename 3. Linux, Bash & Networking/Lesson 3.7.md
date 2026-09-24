# Lesson 3.7 — Processes Masterclass

Now we learn Linux processes deeply.

This is one of the most important DevOps/SRE topics because almost every production issue eventually becomes a question like:

```text
Is the process running?
Which user is running it?
How much CPU is it using?
How much memory is it using?
Which port is it listening on?
Which files has it opened?
Why is it stuck?
Can I stop it safely?
Why did it become zombie?
Why did systemd restart it?
```

A beginner says:

```bash
sudo reboot
```

A DevOps engineer investigates:

```bash
ps
top
htop
pgrep
kill
lsof
ss
journalctl
systemctl
/proc/<pid>
```

---

# 1. What is a Process?

A process is a running instance of a program.

Example:

```text
Program file: /usr/bin/nginx
Running process: nginx with PID 1234
```

One program can have many processes.

Example:

```text
nginx master process
nginx worker process 1
nginx worker process 2
nginx worker process 3
```

Node.js app:

```text
/usr/bin/node server.js
```

Python app:

```text
/usr/bin/python3 app.py
```

Jenkins:

```text
java -jar jenkins.war
```

Docker daemon:

```text
dockerd
```

---

# 2. Every Process Has Metadata

A process has:

```text
PID                 Process ID
PPID                Parent process ID
User                Which user owns/runs it
Command             What command started it
State               Running, sleeping, zombie, stopped
CPU usage
Memory usage
Open files
Open network sockets
Environment variables
Current working directory
Exit code when it finishes
```

This means process debugging is not guessing.

You inspect process metadata.

---

# 3. PID and PPID

PID means process ID.

PPID means parent process ID.

Check your current shell PID:

```bash
echo $$
```

Check parent process:

```bash
ps -o pid,ppid,user,stat,cmd -p $$
```

Example output:

```text
PID    PPID USER   STAT CMD
2451   2440 vivek  Ss   bash
```

Meaning:

```text
Current shell PID is 2451.
Its parent process is 2440.
The process user is vivek.
State is Ss.
Command is bash.
```

---

# 4. Process Tree

Processes form a tree.

Example:

```text
systemd
 ├── sshd
 │    └── sshd
 │         └── bash
 │              └── node server.js
 ├── docker
 ├── nginx
 │    ├── nginx worker
 │    └── nginx worker
 └── jenkins
```

View process tree:

```bash
ps -ef --forest
```

If installed:

```bash
pstree -p
```

Install:

```bash
sudo apt install -y psmisc
```

Then:

```bash
pstree -p
```

This helps you understand who started what.

---

# 5. `ps` — Process Snapshot

Basic:

```bash
ps
```

Shows processes in your current shell session.

More useful:

```bash
ps aux
```

Columns commonly include:

```text
USER
PID
%CPU
%MEM
VSZ
RSS
TTY
STAT
START
TIME
COMMAND
```

Example:

```text
vivek     1234  0.1  1.2 500000 50000 pts/0 Sl   10:00 0:02 node server.js
```

Meaning:

```text
User: vivek
PID: 1234
CPU: 0.1%
Memory: 1.2%
RSS: 50000 KB physical memory
State: Sl
Command: node server.js
```

---

# 6. Useful `ps` Formats

Show all processes with custom columns:

```bash
ps -eo pid,ppid,user,stat,%cpu,%mem,cmd
```

Sort by CPU:

```bash
ps -eo pid,ppid,user,stat,%cpu,%mem,cmd --sort=-%cpu | head
```

Sort by memory:

```bash
ps -eo pid,ppid,user,stat,%cpu,%mem,cmd --sort=-%mem | head
```

Show process by PID:

```bash
ps -p 1234 -o pid,ppid,user,stat,%cpu,%mem,etime,cmd
```

Show elapsed runtime:

```bash
ps -eo pid,user,etime,cmd | grep node
```

`etime` is useful because it tells how long a process has been running.

---

# 7. Process State

In `ps`, the `STAT` column shows process state.

Common states:

```text
R    running or runnable
S    sleeping/interrupted sleep
D    uninterruptible sleep, usually I/O wait
T    stopped
Z    zombie
I    idle kernel thread
<    high priority
N    low priority
s    session leader
l    multi-threaded
+    foreground process group
```

Examples:

```text
Ss   sleeping, session leader
Sl   sleeping, multi-threaded
R+   running in foreground
Z    zombie
D    stuck waiting on I/O
```

Important production states:

```text
R = actively running
S = normal sleeping/waiting
D = dangerous if stuck; often disk/network I/O wait
Z = zombie process
```

---

# 8. `pgrep` — Find Process IDs

Find process by name:

```bash
pgrep nginx
```

Show process and command:

```bash
pgrep -a nginx
```

Find Node processes:

```bash
pgrep -a node
```

Find Python processes:

```bash
pgrep -a python
```

Find by exact name:

```bash
pgrep -x bash
```

Find by user:

```bash
pgrep -u "$USER" -a
```

Example:

```bash
pgrep -u www-data -a
```

This shows processes running as `www-data`.

---

# 9. `pidof`

Another simple command:

```bash
pidof nginx
```

Example output:

```text
1234 1235 1236
```

`pgrep -a` is usually more informative.

---

# 10. `top` — Live Process View

Run:

```bash
top
```

Inside `top`:

```text
q       quit
P       sort by CPU
M       sort by memory
k       kill process
1       show CPU cores
c       show full command
```

Top area shows:

```text
Load average
Tasks
CPU usage
Memory
Swap
```

Process table shows:

```text
PID
USER
PR
NI
VIRT
RES
SHR
S
%CPU
%MEM
TIME+
COMMAND
```

---

# 11. `htop` — Better Interactive Process Viewer

Install:

```bash
sudo apt install -y htop
```

Run:

```bash
htop
```

Useful keys:

```text
F3    search
F4    filter
F5    tree view
F6    sort
F9    kill
F10   quit
```

`htop` is often easier than `top`.

Production note:

```text
Use htop for interactive investigation.
Use ps/top batch mode for scripts and automation.
```

---

# 12. CPU Usage

Find high CPU processes:

```bash
ps -eo pid,user,%cpu,%mem,cmd --sort=-%cpu | head -10
```

With `top`:

```bash
top
```

Sort by CPU with `P`.

High CPU causes:

```text
Traffic spike
Infinite loop
Expensive query
Compression/encryption work
Bad deployment
Runaway background job
Mining malware
Too many workers
```

Do not kill immediately unless user impact requires it.

First collect evidence:

```bash
ps -p <pid> -o pid,ppid,user,stat,%cpu,%mem,etime,cmd
```

Then inspect logs.

---

# 13. Memory Usage

Find memory-heavy processes:

```bash
ps -eo pid,user,%mem,rss,vsz,cmd --sort=-%mem | head -10
```

RSS means resident set size, real memory used.

VSZ means virtual memory size.

In most practical troubleshooting, RSS is more useful than VSZ.

Use:

```bash
free -h
```

Check memory pressure.

Common causes:

```text
Memory leak
Too many application workers
Large file processing
Bad query result loaded into memory
Container memory limit too low
Cache growth
```

---

# 14. Start a Test Process

Create a test process:

```bash
sleep 300
```

Your terminal is blocked because `sleep` is running in foreground.

Open another terminal and run:

```bash
pgrep -a sleep
```

Or stop foreground process with:

```text
Ctrl+C
```

Now start in background:

```bash
sleep 300 &
```

Output:

```text
[1] 12345
```

Meaning:

```text
Job number 1
PID 12345
```

Check jobs:

```bash
jobs
```

Bring to foreground:

```bash
fg
```

Stop with Ctrl+Z:

```text
Ctrl+Z
```

Resume in background:

```bash
bg
```

Kill test process:

```bash
kill 12345
```

or:

```bash
pkill sleep
```

---

# 15. Foreground and Background Jobs

Run:

```bash
sleep 100 &
sleep 200 &
jobs
```

You may see:

```text
[1]- Running sleep 100 &
[2]+ Running sleep 200 &
```

Bring job 1 foreground:

```bash
fg %1
```

Send stopped job background:

```bash
bg %1
```

Kill job:

```bash
kill %1
```

This is shell job control.

Useful when working manually, less common in production services because systemd manages services.

---

# 16. Signals

Signals are messages sent to processes.

Common signals:

```text
SIGTERM  15   Ask process to terminate gracefully
SIGKILL  9    Force kill immediately
SIGHUP   1    Hangup/reload for some daemons
SIGINT   2    Interrupt, Ctrl+C
SIGSTOP  19   Stop/pause process
SIGCONT  18   Continue stopped process
```

List signals:

```bash
kill -l
```

Graceful stop:

```bash
kill -TERM <pid>
```

Same default:

```bash
kill <pid>
```

Force kill:

```bash
kill -KILL <pid>
```

or:

```bash
kill -9 <pid>
```

Important:

```text
kill -9 should be last resort.
```

Why?

```text
Process cannot clean up.
No graceful shutdown.
No final logs.
No connection draining.
May leave lock files or corrupted state.
```

---

# 17. SIGTERM vs SIGKILL

SIGTERM:

```text
Polite request: please stop.
Application can handle it.
Can close connections.
Can flush logs.
Can finish current request.
Can release locks.
```

SIGKILL:

```text
Kernel immediately terminates process.
Application cannot handle it.
No cleanup.
No graceful shutdown.
```

Production rule:

```text
Try SIGTERM first.
Use SIGKILL only if process refuses to stop and impact requires it.
```

Example:

```bash
kill -TERM <pid>
sleep 5
ps -p <pid>
kill -KILL <pid>
```

---

# 18. `pkill` and `killall`

Kill by process name:

```bash
pkill sleep
```

Show what would match:

```bash
pgrep -a sleep
```

Then:

```bash
pkill sleep
```

Kill by full command pattern:

```bash
pkill -f "node server.js"
```

Be careful.

This can match more than expected.

Safer:

```bash
pgrep -af "node server.js"
```

Then kill exact PID.

`killall` kills by name:

```bash
killall sleep
```

Again, be careful on production.

---

# 19. Process Priority: nice and renice

Linux schedules CPU time.

Niceness affects priority.

Range:

```text
-20 = highest priority
0   = normal
19  = lowest priority
```

Start command with lower priority:

```bash
nice -n 10 tar -czf backup.tar.gz large-folder/
```

Change existing process priority:

```bash
renice 10 -p <pid>
```

Need sudo to increase priority:

```bash
sudo renice -5 -p <pid>
```

Use case:

```text
Run backup/compression with lower priority so it does not affect production app.
```

---

# 20. Open Files and `lsof`

Processes open files, directories, sockets, libraries, logs, and devices.

Install if missing:

```bash
sudo apt install -y lsof
```

List open files for PID:

```bash
sudo lsof -p <pid>
```

Find process using a file:

```bash
sudo lsof /var/log/syslog
```

Find process using a directory/mount:

```bash
sudo lsof +D /mnt/data
```

This can be slow on large directories.

Find process using port:

```bash
sudo lsof -i :3000
```

Example:

```bash
sudo lsof -i :80
```

This tells which process listens on port 80.

---

# 21. Deleted Files Still Taking Disk Space

Important production scenario.

A process can keep a deleted file open.

Example:

```text
Huge log file deleted.
Disk space still not freed.
Why?
Process still has file descriptor open.
```

Find deleted open files:

```bash
sudo lsof | grep deleted
```

More targeted:

```bash
sudo lsof +L1
```

This shows open files with link count less than 1.

Fix:

```text
Restart or reload the process holding the deleted file.
```

Do not always reboot.

Find the process first.

---

# 22. `/proc/<pid>` Deep Dive

Every process has a directory:

```text
/proc/<pid>
```

Example:

```bash
PID=$$
ls -la /proc/$PID
```

Useful files:

```text
/proc/<pid>/cmdline      command line
/proc/<pid>/environ      environment variables
/proc/<pid>/cwd          current working directory symlink
/proc/<pid>/exe          executable symlink
/proc/<pid>/fd           open file descriptors
/proc/<pid>/status       process status
/proc/<pid>/limits       resource limits
/proc/<pid>/net          network info
```

View command line:

```bash
tr '\0' ' ' < /proc/<pid>/cmdline
```

View working directory:

```bash
readlink /proc/<pid>/cwd
```

View executable:

```bash
readlink /proc/<pid>/exe
```

View file descriptors:

```bash
ls -la /proc/<pid>/fd
```

View status:

```bash
cat /proc/<pid>/status
```

Security note:

```text
Environment variables can be visible through /proc depending on permissions.
Do not put highly sensitive secrets everywhere casually.
```

---

# 23. Environment Variables of a Process

View environment:

```bash
sudo tr '\0' '\n' < /proc/<pid>/environ
```

Example use:

```text
App is connecting to wrong database.
Check DATABASE_URL of running process.
```

Command:

```bash
sudo tr '\0' '\n' < /proc/<pid>/environ | grep DATABASE
```

Be careful not to print secrets in shared terminal logs.

---

# 24. Zombie Processes

A zombie process is a process that has finished execution but still has an entry in the process table because its parent has not collected its exit status.

In `ps`:

```text
STAT = Z
```

Find zombies:

```bash
ps aux | awk '$8 ~ /Z/ {print}'
```

or:

```bash
ps -eo pid,ppid,stat,cmd | awk '$3 ~ /Z/ {print}'
```

Important:

```text
You cannot kill a zombie directly because it is already dead.
```

Fix usually involves:

```text
Fix or restart the parent process.
```

Find parent:

```bash
ps -o pid,ppid,stat,cmd -p <zombie_pid>
```

Then inspect PPID.

If parent is broken, restart parent service carefully.

---

# 25. Orphan Processes

If a parent process exits, child processes may become orphaned.

They are adopted by PID 1, usually `systemd`.

This is not always bad.

But in services, orphaned processes can indicate bad process management.

In Docker containers, poor signal handling can leave child processes around.

This is why containers should run one main process and handle signals properly.

---

# 26. Process Limits

View limits for current shell:

```bash
ulimit -a
```

View limits for process:

```bash
cat /proc/<pid>/limits
```

Common limits:

```text
open files
max user processes
stack size
core file size
locked memory
```

Open files limit is very important.

Check:

```bash
ulimit -n
```

Production error:

```text
Too many open files
```

This means process hit file descriptor limit.

Debug:

```bash
cat /proc/<pid>/limits | grep "open files"
sudo lsof -p <pid> | wc -l
```

Fix may involve systemd limits, app connection leaks, or OS config.

---

# 27. Process and Ports

Processes often listen on ports.

Use:

```bash
ss -tulnp
```

Meaning:

```text
-t TCP
-u UDP
-l listening
-n numeric
-p process
```

Find port 3000:

```bash
sudo ss -tulnp | grep ':3000'
```

Alternative:

```bash
sudo lsof -i :3000
```

Example:

```text
node is listening on 127.0.0.1:3000
```

Important distinction:

```text
127.0.0.1:3000 = only local machine can connect
0.0.0.0:3000   = all network interfaces
```

This matters for ALB, Nginx, Docker, and Kubernetes.

---

# 28. Process Troubleshooting Method

When an app is not working:

```text
1. Is the process running?
2. Which user runs it?
3. What command started it?
4. How long has it been running?
5. Is it using CPU/memory?
6. Is it listening on expected port?
7. Is it reading expected config/env?
8. What files/logs does it have open?
9. What do logs say?
10. Was it killed by OOM/systemd/user?
```

Commands:

```bash
pgrep -a myapp
ps -p <pid> -o pid,ppid,user,stat,%cpu,%mem,etime,cmd
sudo ss -tulnp | grep ':3000'
sudo lsof -p <pid> | head
readlink /proc/<pid>/cwd
sudo tr '\0' '\n' < /proc/<pid>/environ
journalctl -u myapp -n 100
```

---

# 29. Lab — Process Practice

Create test process:

```bash
sleep 600 &
```

Save PID:

```bash
SLEEP_PID=$!
echo "$SLEEP_PID"
```

Inspect:

```bash
ps -p "$SLEEP_PID" -o pid,ppid,user,stat,%cpu,%mem,etime,cmd
```

Check `/proc`:

```bash
readlink /proc/"$SLEEP_PID"/cwd
tr '\0' ' ' < /proc/"$SLEEP_PID"/cmdline
ls -la /proc/"$SLEEP_PID"/fd
cat /proc/"$SLEEP_PID"/status | head
```

Kill gracefully:

```bash
kill -TERM "$SLEEP_PID"
```

Check:

```bash
ps -p "$SLEEP_PID"
echo $?
```

---

# 30. Lab — Port Process

Start simple HTTP server:

```bash
cd ~/devops-masterclass
python3 -m http.server 8080 &
```

Save PID:

```bash
HTTP_PID=$!
echo "$HTTP_PID"
```

Check process:

```bash
ps -p "$HTTP_PID" -o pid,ppid,user,stat,%cpu,%mem,etime,cmd
```

Check port:

```bash
sudo ss -tulnp | grep ':8080'
```

Test:

```bash
curl -I http://127.0.0.1:8080
```

Find with lsof:

```bash
sudo lsof -i :8080
```

Stop:

```bash
kill -TERM "$HTTP_PID"
```

Confirm:

```bash
sudo ss -tulnp | grep ':8080' || echo "Port 8080 is free"
```

---

# 31. Script — Process Inspector

Create:

```bash
cd ~/devops-masterclass
nano 03-linux-bash-networking/scripts/process-inspector.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

PID="${1:-}"

if [ -z "$PID" ]; then
  echo "Usage: $0 <pid>" >&2
  exit 1
fi

if ! [[ "$PID" =~ ^[0-9]+$ ]]; then
  echo "ERROR: PID must be numeric" >&2
  exit 1
fi

if [ ! -d "/proc/$PID" ]; then
  echo "ERROR: Process does not exist: $PID" >&2
  exit 1
fi

echo "===== Process Inspector ====="
echo "PID: $PID"
echo "Generated at: $(date)"
echo

echo "===== ps summary ====="
ps -p "$PID" -o pid,ppid,user,group,stat,%cpu,%mem,rss,vsz,etime,cmd
echo

echo "===== Command Line ====="
tr '\0' ' ' < "/proc/$PID/cmdline"
echo
echo

echo "===== Executable ====="
readlink "/proc/$PID/exe" 2>/dev/null || echo "Cannot read executable"
echo

echo "===== Working Directory ====="
readlink "/proc/$PID/cwd" 2>/dev/null || echo "Cannot read cwd"
echo

echo "===== Process Status ====="
grep -E "^(Name|State|Pid|PPid|Uid|Gid|VmRSS|VmSize|Threads):" "/proc/$PID/status" || true
echo

echo "===== Limits ====="
cat "/proc/$PID/limits"
echo

echo "===== Open File Descriptors ====="
ls -la "/proc/$PID/fd" 2>/dev/null | head -30 || echo "Cannot read file descriptors"
echo

echo "===== Listening Ports for PID ====="
if command -v ss >/dev/null 2>&1; then
  sudo ss -tulnp 2>/dev/null | grep "pid=$PID" || echo "No listening ports found for PID or insufficient permission"
else
  echo "ss command not found"
fi
echo

echo "===== Open Files Summary ====="
if command -v lsof >/dev/null 2>&1; then
  sudo lsof -p "$PID" 2>/dev/null | head -30 || echo "lsof failed or insufficient permission"
else
  echo "lsof not installed"
fi

echo
echo "Done."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/process-inspector.sh
```

Test:

```bash
sleep 600 &
TEST_PID=$!
./03-linux-bash-networking/scripts/process-inspector.sh "$TEST_PID"
kill "$TEST_PID"
```

---

# 32. Script — Top Resource Processes

Create:

```bash
nano 03-linux-bash-networking/scripts/top-processes.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

LIMIT="${1:-10}"

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: limit must be numeric" >&2
  exit 1
fi

echo "===== Top Processes by CPU ====="
ps -eo pid,ppid,user,stat,%cpu,%mem,rss,etime,cmd --sort=-%cpu | head -n "$((LIMIT + 1))"
echo

echo "===== Top Processes by Memory ====="
ps -eo pid,ppid,user,stat,%cpu,%mem,rss,etime,cmd --sort=-%mem | head -n "$((LIMIT + 1))"
echo

echo "===== System Memory ====="
free -h
echo

echo "===== Load Average ====="
uptime
echo

echo "Done."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/top-processes.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/top-processes.sh
```

or:

```bash
./03-linux-bash-networking/scripts/top-processes.sh 5
```

---

# 33. Script — Port Owner

Create:

```bash
nano 03-linux-bash-networking/scripts/port-owner.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-}"

if [ -z "$PORT" ]; then
  echo "Usage: $0 <port>" >&2
  exit 1
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: port must be numeric" >&2
  exit 1
fi

echo "===== Port Owner ====="
echo "Port: $PORT"
echo "Generated at: $(date)"
echo

echo "===== ss result ====="
sudo ss -tulnp | grep ":$PORT" || echo "No listening process found with ss"
echo

echo "===== lsof result ====="
if command -v lsof >/dev/null 2>&1; then
  sudo lsof -i ":$PORT" || echo "No process found with lsof"
else
  echo "lsof not installed"
fi

echo
echo "Done."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/port-owner.sh
```

Test:

```bash
python3 -m http.server 8080 &
HTTP_PID=$!

./03-linux-bash-networking/scripts/port-owner.sh 8080

kill "$HTTP_PID"
```

---

# 34. Create Notes

Create:

```bash
nano 03-linux-bash-networking/processes.md
```

Paste:

````markdown
# Linux Processes Masterclass

## Mental Model

A process is a running instance of a program.

Every process has:

- PID
- PPID
- User
- State
- CPU usage
- Memory usage
- Open files
- Environment variables
- Current working directory
- Command line

## Important Commands

```bash
ps aux
ps -ef --forest
ps -eo pid,ppid,user,stat,%cpu,%mem,cmd --sort=-%cpu | head
pgrep -a nginx
pidof nginx
top
htop
jobs
fg
bg
kill -TERM <pid>
kill -KILL <pid>
pkill process-name
nice -n 10 command
renice 10 -p <pid>
sudo lsof -p <pid>
sudo lsof -i :3000
ss -tulnp
````

## Process States

| State | Meaning                               |
| ----- | ------------------------------------- |
| R     | running/runnable                      |
| S     | sleeping                              |
| D     | uninterruptible sleep, often I/O wait |
| T     | stopped                               |
| Z     | zombie                                |

## Signals

| Signal  | Number | Meaning              |
| ------- | -----: | -------------------- |
| SIGTERM |     15 | graceful termination |
| SIGKILL |      9 | force kill           |
| SIGHUP  |      1 | reload/hangup        |
| SIGINT  |      2 | interrupt, Ctrl+C    |
| SIGSTOP |     19 | stop/pause           |
| SIGCONT |     18 | continue             |

## /proc

Useful paths:

```text
/proc/<pid>/cmdline
/proc/<pid>/environ
/proc/<pid>/cwd
/proc/<pid>/exe
/proc/<pid>/fd
/proc/<pid>/status
/proc/<pid>/limits
```

## Rules

* Try SIGTERM before SIGKILL.
* Use `pgrep -a` before `pkill`.
* Inspect process user and command before killing.
* Use `lsof` to find open files and port owners.
* Use `/proc/<pid>` for deep inspection.
* Zombie processes cannot be killed directly; inspect parent.
* Deleted files may still consume disk if a process keeps them open.

````

Commit:

```bash
git status
git diff

git add 03-linux-bash-networking/processes.md \
        03-linux-bash-networking/scripts/process-inspector.sh \
        03-linux-bash-networking/scripts/top-processes.sh \
        03-linux-bash-networking/scripts/port-owner.sh

git diff --staged

git commit -m "docs: add Linux processes masterclass"
git push
````

---

# 35. Real Production Scenario — Port Already in Use

Error:

```text
Error: listen EADDRINUSE: address already in use 0.0.0.0:3000
```

Debug:

```bash
sudo ss -tulnp | grep ':3000'
```

or:

```bash
sudo lsof -i :3000
```

Find PID.

Inspect:

```bash
ps -p <pid> -o pid,ppid,user,stat,%cpu,%mem,etime,cmd
```

If it is old app process:

```bash
kill -TERM <pid>
```

If managed by systemd, do not kill manually first. Use:

```bash
sudo systemctl status myapp
sudo systemctl restart myapp
```

If Docker:

```bash
docker ps
docker stop <container>
```

Correct tool depends on who manages the process.

---

# 36. Real Production Scenario — High CPU

Alert:

```text
CPU usage high on app server.
```

Debug:

```bash
uptime
top
ps -eo pid,user,%cpu,%mem,etime,cmd --sort=-%cpu | head
```

Inspect top PID:

```bash
./process-inspector.sh <pid>
```

Check logs:

```bash
journalctl -u myapp -n 100
```

Questions:

```text
Is this expected traffic?
Did deployment happen?
Is one process stuck?
Is there a bad request pattern?
Is a background job running?
Is there malware?
```

Do not instantly kill unless service impact is severe.

---

# 37. Real Production Scenario — Disk Still Full After Deleting Log

Problem:

```text
Deleted 10GB log file, but df -h still shows disk full.
```

Reason:

```text
Process still has deleted file open.
```

Find:

```bash
sudo lsof +L1
```

or:

```bash
sudo lsof | grep deleted
```

You may see:

```text
node 1234 appuser 5w REG ... /var/log/myapp/app.log (deleted)
```

Fix:

```bash
sudo systemctl restart myapp
```

or reload log writer if supported.

Do not reboot by default.

---

# 38. Real Production Scenario — Zombie Processes

Find zombies:

```bash
ps -eo pid,ppid,stat,cmd | awk '$3 ~ /Z/ {print}'
```

Example:

```text
12345 12000 Z [worker] <defunct>
```

Inspect parent:

```bash
ps -p 12000 -o pid,ppid,user,stat,cmd
```

If parent is a service:

```bash
sudo systemctl status myservice
```

Fix might be:

```bash
sudo systemctl restart myservice
```

Root cause:

```text
Parent process is not reaping child processes properly.
Application bug or process supervisor issue.
```

---

# 39. Interview Answers

Question:

```text
How do you find which process is using a port?
```

Strong answer:

```text
I use ss or lsof. For example, sudo ss -tulnp | grep ':3000' shows listening TCP/UDP sockets with process information. I can also use sudo lsof -i :3000. After finding the PID, I inspect it with ps to see the user, command, CPU, memory, and runtime before deciding whether to stop it.
```

Question:

```text
What is the difference between SIGTERM and SIGKILL?
```

Strong answer:

```text
SIGTERM is a graceful termination request. The process can handle it, close connections, flush logs, and clean up resources. SIGKILL immediately terminates the process at the kernel level and cannot be caught or handled. I try SIGTERM first and use SIGKILL only as a last resort.
```

Question:

```text
What is a zombie process?
```

Strong answer:

```text
A zombie process is a process that has already exited but still has an entry in the process table because its parent has not collected its exit status. It appears with state Z. You cannot kill a zombie directly because it is already dead. The fix is usually to inspect or restart the parent process.
```

Question:

```text
How do you troubleshoot a high CPU process?
```

Strong answer:

```text
I first identify the top CPU consumers using top or ps sorted by CPU. Then I inspect the PID, user, command, runtime, and parent process. I check logs and recent deployments to understand whether the load is expected or caused by a bug. If the process is managed by systemd or Docker, I use the proper manager rather than killing randomly. If user impact is severe, I may gracefully restart or scale the service while preserving evidence for root cause analysis.
```

---

# Today’s Core Rules

```text
A process is a running program.
Every process has PID, PPID, user, state, command, CPU, memory, and open files.
Use ps for snapshots.
Use top/htop for live investigation.
Use pgrep -a before killing by name.
Use SIGTERM before SIGKILL.
Use lsof to inspect open files and ports.
Use /proc/<pid> for deep process details.
Zombie processes are already dead; inspect parent.
Deleted files can still consume disk if open.
Use the process manager: systemd, Docker, Kubernetes, or supervisor.
```

Next lesson:

# Lesson 3.8 — systemd Masterclass: services, units, targets, journalctl, service files, restart policies, environment files, timers

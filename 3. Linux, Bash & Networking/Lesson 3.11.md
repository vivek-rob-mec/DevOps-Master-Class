# Lesson 3.11 — CPU, Memory, Load Average, OOM Killer, and Performance Troubleshooting

Now we learn how to understand **server performance**.

When a server is slow, people usually say:

```text
Server is hanging.
Application is slow.
CPU is high.
Memory is full.
System is not responding.
```

A DevOps/SRE engineer must convert that into evidence:

```text
CPU saturation?
Memory pressure?
Disk I/O wait?
Too many processes?
Too many open files?
Swap usage?
OOM killer?
Load average high?
Single process consuming resources?
Kernel blocked on I/O?
```

This lesson teaches the Linux performance basics you need before Docker, Kubernetes, monitoring, Prometheus, Grafana, and SRE.

---

# 1. Performance Troubleshooting Mental Model

A Linux server has limited resources:

```text
CPU
Memory
Disk I/O
Network I/O
File descriptors
Processes/threads
```

When performance is bad, ask:

```text
Which resource is saturated?
Who is consuming it?
Is it temporary or increasing?
Did something change?
Is the app slow, or is the host slow?
```

Core troubleshooting flow:

```text
1. Check load and uptime
2. Check CPU
3. Check memory and swap
4. Check top processes
5. Check disk I/O
6. Check network if needed
7. Check logs
8. Correlate with deployment/traffic
```

Core commands:

```bash
uptime
top
htop
free -h
vmstat 1
ps aux --sort=-%cpu
ps aux --sort=-%mem
journalctl -k
dmesg
iostat -xz 1
```

---

# 2. `uptime` and Load Average

Run:

```bash
uptime
```

Example:

```text
10:30:01 up 5 days,  2:10,  2 users,  load average: 0.45, 0.70, 0.90
```

Meaning:

```text
Current time: 10:30:01
Server uptime: 5 days, 2 hours, 10 minutes
Logged-in users: 2
Load average: 1-minute, 5-minute, 15-minute
```

Load average values:

```text
0.45  last 1 minute
0.70  last 5 minutes
0.90  last 15 minutes
```

Load average is not exactly CPU usage.

It roughly represents:

```text
Processes running on CPU
+
Processes waiting for CPU
+
Processes stuck in uninterruptible I/O wait
```

This is important.

High load can be caused by CPU pressure or disk I/O pressure.

---

# 3. How to Interpret Load Average

You must compare load average to CPU cores.

Check CPU cores:

```bash
nproc
```

Example:

```text
4
```

If server has 4 CPU cores:

```text
Load 1.0  = light
Load 4.0  = around fully utilized
Load 8.0  = overloaded
```

General rule:

```text
Load average near number of CPU cores = busy but maybe okay.
Load average much higher than CPU cores = overloaded or blocked.
```

Examples:

| CPU Cores | Load Average | Interpretation |
| --------: | -----------: | -------------- |
|         1 |         1.00 | fully busy     |
|         1 |         4.00 | overloaded     |
|         4 |         2.00 | okay           |
|         4 |         4.00 | busy           |
|         4 |        10.00 | overloaded     |
|         8 |         4.00 | okay           |
|         8 |        16.00 | overloaded     |

But always check **why** load is high.

---

# 4. Load Trend

Example:

```text
load average: 10.0, 4.0, 2.0
```

Meaning:

```text
1-minute load is much higher than 5-minute and 15-minute.
Load recently spiked.
```

Example:

```text
load average: 2.0, 8.0, 12.0
```

Meaning:

```text
Load was high earlier but is coming down.
```

Example:

```text
load average: 10.0, 10.5, 10.2
```

Meaning:

```text
Sustained high load.
```

This helps you know whether the problem is new, recovering, or persistent.

---

# 5. CPU Usage with `top`

Run:

```bash
top
```

Top section example:

```text
%Cpu(s): 80.0 us, 10.0 sy, 0.0 ni, 5.0 id, 4.0 wa, 0.0 hi, 1.0 si, 0.0 st
```

Fields:

```text
us = user CPU, application code
sy = system CPU, kernel work
ni = nice CPU, low-priority processes
id = idle CPU
wa = I/O wait
hi = hardware interrupt
si = software interrupt
st = steal time, virtualized CPU stolen by hypervisor
```

Important fields:

```text
High us = application using CPU
High sy = kernel/system overhead
High wa = disk/network I/O wait
High st = cloud/VM CPU contention
Low id = CPU is busy
```

---

# 6. CPU Interpretation

## High user CPU

```text
us is high
```

Possible causes:

```text
Application traffic spike
CPU-heavy processing
Infinite loop
Bad algorithm
Compression/encryption
Too many workers
```

Check:

```bash
ps -eo pid,user,%cpu,%mem,etime,cmd --sort=-%cpu | head
```

## High system CPU

```text
sy is high
```

Possible causes:

```text
Too many system calls
High network packet processing
Filesystem overhead
Kernel-level work
Container/network overhead
```

## High I/O wait

```text
wa is high
```

Possible causes:

```text
Slow disk
Database I/O
Log writing bottleneck
Disk saturated
NFS/EBS/storage latency
```

Check:

```bash
iostat -xz 1
```

## High steal time

```text
st is high
```

Possible causes:

```text
Cloud host contention
Noisy neighbor
Overcommitted VM host
Burstable instance CPU credit issue
```

On cloud, high steal time can mean the VM is not getting CPU time from the hypervisor.

---

# 7. Find Top CPU Processes

Use:

```bash
ps -eo pid,ppid,user,stat,%cpu,%mem,etime,cmd --sort=-%cpu | head -15
```

Example:

```text
PID   PPID USER  STAT %CPU %MEM ELAPSED CMD
1234     1 app   R    95.0 10.2 01:20:33 node server.js
```

Meaning:

```text
PID 1234 is using high CPU.
It runs as app user.
State R means running.
Command is node server.js.
```

Inspect:

```bash
ps -p 1234 -o pid,ppid,user,stat,%cpu,%mem,rss,vsz,etime,cmd
```

Then check logs:

```bash
journalctl -u myapp --since "30 minutes ago"
```

---

# 8. CPU Core View

In `top`, press:

```text
1
```

This shows each CPU core.

Why useful?

```text
One core at 100% may mean single-threaded bottleneck.
All cores at 100% may mean full CPU saturation.
```

Example:

```text
Node.js app single process uses one core heavily.
Even if server has 8 cores, one Node process may bottleneck on one core.
```

Solutions may include:

```text
Scale horizontally
Use Node cluster/workers
Optimize CPU-heavy code
Move CPU-heavy work to queue/worker
Use more instances/pods
```

---

# 9. Memory Basics

Memory terms:

```text
RAM       physical memory
Swap      disk-backed emergency memory
Cache     memory used by Linux for filesystem cache
Buffers   block device metadata/cache
Available memory  estimate of memory available for apps
```

Run:

```bash
free -h
```

Example:

```text
               total        used        free      shared  buff/cache   available
Mem:           7.7Gi       3.0Gi       1.0Gi       100Mi       3.7Gi       4.2Gi
Swap:          2.0Gi       0.0Gi       2.0Gi
```

Important:

```text
Do not panic because free memory is low.
Linux uses memory for cache.
Look at available memory.
```

---

# 10. `free -h` Explained

Columns:

```text
total       total RAM
used        used memory
free        unused memory
shared      shared memory/tmpfs
buff/cache  filesystem cache and buffers
available   estimated memory available for new apps
```

The most useful column:

```text
available
```

If `available` is healthy, the system may be fine.

If `available` is very low and swap is used heavily, memory pressure may exist.

---

# 11. Swap

Swap is disk space used as memory fallback.

Check:

```bash
free -h
swapon --show
```

Swap can prevent immediate crashes, but heavy swap usage causes slowness because disk is much slower than RAM.

Signs of memory pressure:

```text
Available memory very low
Swap used and increasing
High si/so in vmstat
OOM killer logs
Processes killed unexpectedly
System sluggish
```

`vmstat` shows swap activity.

---

# 12. `vmstat`

Run:

```bash
vmstat 1
```

Example:

```text
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 2  0      0 500000 100000 2000000   0    0    10    20  100  200 20  5 70  5  0
```

Important columns:

```text
r   runnable processes waiting/running on CPU
b   blocked processes, usually I/O
si  swap in
so  swap out
us  user CPU
sy  system CPU
id  idle CPU
wa  I/O wait
st  steal time
```

Interpretation:

```text
High r compared to CPU cores = CPU contention
High b = I/O blocking
High si/so = active swapping
High wa = I/O wait
Low id = busy CPU
```

Example:

```text
r=20 on 4-core system
```

CPU queue is high.

Example:

```text
b=15 and wa=50
```

Processes are blocked on I/O.

---

# 13. OOM Killer

OOM means **Out Of Memory**.

When Linux cannot allocate memory, the kernel may kill a process to protect the system.

This is called OOM killer.

Symptoms:

```text
App suddenly died
No application error
systemd shows process killed
Container restarted
Exit code 137
```

Check kernel logs:

```bash
journalctl -k --since "1 hour ago" | grep -Ei "out of memory|oom|killed process"
```

or:

```bash
dmesg -T | grep -Ei "out of memory|oom|killed process"
```

Example OOM log:

```text
Out of memory: Killed process 1234 (node) total-vm:...
```

Meaning:

```text
Kernel killed PID 1234 because memory was exhausted.
```

---

# 14. Exit Code 137

In containers and Linux process management, exit code 137 often means:

```text
128 + 9 = 137
```

Signal 9 is SIGKILL.

Common reason:

```text
OOM kill
```

In Docker/Kubernetes:

```text
Container terminated with exit code 137
```

Likely causes:

```text
Memory limit too low
Memory leak
Traffic spike
Large data processing
Too many workers
```

Debug:

```bash
docker inspect <container>
kubectl describe pod <pod>
kubectl logs --previous <pod>
journalctl -k | grep -i oom
```

We will cover container-specific details later.

---

# 15. Find Top Memory Processes

Run:

```bash
ps -eo pid,ppid,user,stat,%mem,rss,vsz,etime,cmd --sort=-rss | head -15
```

RSS is in KB.

Human-readable-ish:

```bash
ps -eo pid,user,%mem,rss,cmd --sort=-rss | awk 'NR==1 {print} NR>1 {printf "%s %s %s %.1fMB %s\n", $1,$2,$3,$4/1024,$5}'
```

Simpler:

```bash
top
```

Press:

```text
M
```

to sort by memory.

In `htop`, sort by memory with F6.

---

# 16. Memory Leak Pattern

A memory leak means a process keeps using more memory over time.

Symptoms:

```text
RSS keeps increasing
Eventually OOM killer kills process
Restart temporarily fixes it
Problem returns after hours/days
```

Observe process memory:

```bash
watch -n 5 'ps -p <pid> -o pid,%mem,rss,vsz,etime,cmd'
```

Example:

```bash
watch -n 5 'ps -p 1234 -o pid,%mem,rss,vsz,etime,cmd'
```

If RSS grows continuously without returning, possible leak.

But be careful:

```text
Some apps intentionally cache memory.
Memory growth alone is not always a leak.
```

Correlate with traffic and app behavior.

---

# 17. Buffers and Cache

Linux uses free memory to cache disk data.

This improves performance.

So this:

```text
free memory low
buff/cache high
available healthy
```

is normal.

You may hear:

```text
Linux ate my RAM
```

Better understanding:

```text
Linux is using unused RAM for cache and can reclaim it when apps need memory.
```

Do not clear cache randomly in production.

There is a command:

```bash
sudo sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
```

But do not use it casually.

It can hurt performance and hides real issues.

---

# 18. Disk I/O Wait

High load with low CPU usage often means I/O wait.

Check `top`:

```text
wa high
```

Check `vmstat`:

```text
b high, wa high
```

Install tools:

```bash
sudo apt install -y sysstat iotop
```

Run:

```bash
iostat -xz 1
```

Important fields:

```text
%util     device utilization
await     average wait time
r/s,w/s   read/write operations per second
rkB/s,wkB/s throughput
```

If `%util` near 100% and `await` high, disk is saturated or slow.

Use:

```bash
sudo iotop
```

to find processes doing I/O.

---

# 19. `iostat -xz 1` Basic Interpretation

Example:

```text
Device            r/s     w/s   await  %util
sda              10.0   200.0    50.0   98.0
```

Meaning:

```text
Disk is very busy.
Writes are high.
Average wait is 50ms.
Utilization is 98%.
```

Possible causes:

```text
Database heavy writes
Log storm
Backup running
Docker image extraction
Jenkins build
Swap activity
```

Next commands:

```bash
sudo iotop
ps aux --sort=-%cpu | head
journalctl --since "15 minutes ago"
```

---

# 20. File Descriptors and “Too Many Open Files”

Processes use file descriptors for:

```text
Files
Sockets
Pipes
Logs
Connections
```

Check shell limit:

```bash
ulimit -n
```

Check process limits:

```bash
cat /proc/<pid>/limits | grep "open files"
```

Count open files for process:

```bash
sudo lsof -p <pid> | wc -l
```

Common error:

```text
Too many open files
```

Possible causes:

```text
Connection leak
File handle leak
Too many clients
Limit too low
Bad application cleanup
```

For systemd service, limit can be set:

```ini
[Service]
LimitNOFILE=65535
```

But increasing limit without fixing leak is not enough.

---

# 21. Threads and Process Count

Too many processes/threads can also hurt performance.

Check process count:

```bash
ps -e --no-headers | wc -l
```

Check thread count for process:

```bash
grep Threads /proc/<pid>/status
```

Show process/thread view:

```bash
ps -eLf | head
```

Common issues:

```text
Thread leak
Too many worker processes
Fork bomb
Bad queue worker scaling
Too many web server workers
```

Check user process limits:

```bash
ulimit -u
```

Systemd can limit tasks:

```ini
[Service]
TasksMax=500
```

---

# 22. CPU vs Memory vs I/O Diagnosis Table

| Symptom                     | Likely Area          | Commands                            |
| --------------------------- | -------------------- | ----------------------------------- |
| Load high, CPU high         | CPU saturation       | `top`, `ps --sort=-%cpu`            |
| Load high, CPU low, wa high | Disk I/O wait        | `vmstat 1`, `iostat -xz 1`, `iotop` |
| App killed suddenly         | OOM                  | `journalctl -k`, `free -h`          |
| System slow, swap active    | Memory pressure      | `free -h`, `vmstat 1`               |
| Too many open files         | FD limit/leak        | `lsof`, `/proc/<pid>/limits`        |
| One app slow, host okay     | App-level issue      | logs, app metrics                   |
| All apps slow               | Host resource issue  | `top`, `vmstat`, `iostat`           |
| High steal time             | Cloud CPU contention | `top`, cloud metrics                |

---

# 23. Performance Triage Script

Create:

```bash
cd ~/devops-masterclass
nano 03-linux-bash-networking/scripts/performance-triage.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

TOP_N="${1:-10}"

if ! [[ "$TOP_N" =~ ^[0-9]+$ ]]; then
  echo "ERROR: TOP_N must be numeric" >&2
  exit 1
fi

echo "===== Performance Triage ====="
echo "Generated at: $(date -Is)"
echo "Hostname: $(hostname)"
echo

echo "===== Uptime and Load ====="
uptime
echo "CPU cores: $(nproc)"
echo

echo "===== Memory ====="
free -h
echo

echo "===== Swap ====="
swapon --show || true
echo

echo "===== Disk Filesystems ====="
df -h
echo

echo "===== Inodes ====="
df -i
echo

echo "===== Top CPU Processes ====="
ps -eo pid,ppid,user,stat,%cpu,%mem,rss,etime,cmd --sort=-%cpu | head -n "$((TOP_N + 1))"
echo

echo "===== Top Memory Processes ====="
ps -eo pid,ppid,user,stat,%cpu,%mem,rss,etime,cmd --sort=-rss | head -n "$((TOP_N + 1))"
echo

echo "===== vmstat Snapshot ====="
vmstat 1 5
echo

echo "===== Recent OOM Events ====="
journalctl -k --since "24 hours ago" --no-pager 2>/dev/null \
  | grep -Ei "out of memory|oom|killed process" \
  || echo "No OOM events found in kernel logs from last 24 hours"
echo

echo "===== Failed systemd Units ====="
systemctl --failed --no-pager || true
echo

echo "Done."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/performance-triage.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/performance-triage.sh
```

This is a real first-response script.

---

# 24. CPU Stress Lab

Install stress tool:

```bash
sudo apt update
sudo apt install -y stress
```

Start CPU stress for 30 seconds:

```bash
stress --cpu 2 --timeout 30
```

In another terminal:

```bash
top
uptime
vmstat 1
```

Observe:

```text
CPU usage increases
Load average may rise
r column in vmstat may rise
```

Do not run heavy stress on production servers.

This is only for lab systems.

---

# 25. Memory Stress Lab

Run controlled memory stress:

```bash
stress --vm 1 --vm-bytes 256M --timeout 30
```

Observe:

```bash
free -h
vmstat 1
```

Do not allocate near your full RAM.

Bad:

```bash
stress --vm 4 --vm-bytes 90% --timeout 300
```

This can make your system unstable.

---

# 26. I/O Stress Lab

Create write activity:

```bash
mkdir -p /tmp/io-lab
dd if=/dev/zero of=/tmp/io-lab/testfile bs=1M count=512 conv=fdatasync
```

Observe:

```bash
iostat -xz 1
vmstat 1
```

Cleanup:

```bash
rm -rf /tmp/io-lab
```

If `iostat` missing:

```bash
sudo apt install -y sysstat
```

---

# 27. OOM Investigation Lab Concept

Do not intentionally trigger OOM on your working machine.

Instead, learn the commands:

```bash
journalctl -k --since "24 hours ago" | grep -Ei "oom|out of memory|killed process"
free -h
ps -eo pid,user,%mem,rss,cmd --sort=-rss | head
```

In Kubernetes later, we will safely inspect OOMKilled pods.

---

# 28. Script — Process Memory Watcher

Create:

```bash
nano 03-linux-bash-networking/scripts/process-memory-watch.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

PID="${1:-}"
INTERVAL="${2:-5}"

if [ -z "$PID" ]; then
  echo "Usage: $0 <pid> [interval-seconds]" >&2
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

if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]]; then
  echo "ERROR: interval must be numeric" >&2
  exit 1
fi

echo "Watching memory for PID $PID every ${INTERVAL}s"
echo "Press Ctrl+C to stop."
echo

while [ -d "/proc/$PID" ]; do
  date -Is
  ps -p "$PID" -o pid,user,%mem,rss,vsz,etime,cmd
  echo
  sleep "$INTERVAL"
done

echo "Process $PID no longer exists."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/process-memory-watch.sh
```

Test:

```bash
sleep 300 &
TEST_PID=$!
./03-linux-bash-networking/scripts/process-memory-watch.sh "$TEST_PID" 2
```

Stop watcher with `Ctrl+C`, then:

```bash
kill "$TEST_PID"
```

---

# 29. Script — OOM Checker

Create:

```bash
nano 03-linux-bash-networking/scripts/oom-check.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SINCE="${1:-24 hours ago}"

echo "===== OOM Checker ====="
echo "Since: $SINCE"
echo "Generated at: $(date -Is)"
echo

echo "===== Memory Summary ====="
free -h
echo

echo "===== Swap ====="
swapon --show || true
echo

echo "===== Kernel OOM Logs ====="
journalctl -k --since "$SINCE" --no-pager 2>/dev/null \
  | grep -Ei "out of memory|oom|killed process" \
  || echo "No OOM-related kernel logs found"
echo

echo "===== Top Memory Processes Now ====="
ps -eo pid,ppid,user,stat,%mem,rss,vsz,etime,cmd --sort=-rss | head -15
echo

echo "Done."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/oom-check.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/oom-check.sh
```

or:

```bash
./03-linux-bash-networking/scripts/oom-check.sh "2 hours ago"
```

---

# 30. Create Notes

Create:

```bash
nano 03-linux-bash-networking/cpu-memory-performance.md
```

Paste:

````markdown
# CPU, Memory, Load Average, and Performance Troubleshooting

## Mental Model

Performance troubleshooting means identifying which resource is saturated:

- CPU
- Memory
- Disk I/O
- Network I/O
- File descriptors
- Processes/threads

## Core Commands

```bash
uptime
nproc
top
htop
free -h
swapon --show
vmstat 1
ps -eo pid,ppid,user,stat,%cpu,%mem,cmd --sort=-%cpu | head
ps -eo pid,ppid,user,stat,%mem,rss,cmd --sort=-rss | head
journalctl -k | grep -Ei "oom|out of memory|killed process"
iostat -xz 1
sudo iotop
ulimit -n
cat /proc/<pid>/limits
sudo lsof -p <pid> | wc -l
````

## Load Average

Load average must be compared with CPU cores.

```bash
uptime
nproc
```

General rule:

```text
load near CPU cores = busy
load much higher than CPU cores = overloaded or blocked
```

## CPU Fields in top

| Field | Meaning                |
| ----- | ---------------------- |
| us    | user/application CPU   |
| sy    | system/kernel CPU      |
| id    | idle                   |
| wa    | I/O wait               |
| st    | steal time in VM/cloud |

## Memory

Use:

```bash
free -h
```

Focus on:

```text
available memory
swap usage
```

## OOM Killer

Check:

```bash
journalctl -k --since "1 hour ago" | grep -Ei "oom|out of memory|killed process"
```

Exit code 137 usually means SIGKILL and often indicates OOM in containers.

## Rules

* High load is not always CPU; check I/O wait.
* Low free memory is not always bad; check available memory.
* Heavy swap usage means memory pressure.
* Check OOM logs if a process disappeared.
* Use ps/top/htop to find top processes.
* Use vmstat to distinguish CPU, memory, swap, and I/O pressure.
* Use iostat/iotop for disk I/O problems.
* Increasing limits without fixing leaks is not a real fix.

````

Commit:

```bash
git status
git diff

git add 03-linux-bash-networking/cpu-memory-performance.md \
        03-linux-bash-networking/scripts/performance-triage.sh \
        03-linux-bash-networking/scripts/process-memory-watch.sh \
        03-linux-bash-networking/scripts/oom-check.sh

git diff --staged

git commit -m "docs: add CPU memory and performance troubleshooting"
git push
````

---

# 31. Real Production Scenario — API Slow, CPU High

Incident:

```text
API latency increased.
CPU alert firing.
```

Triage:

```bash
uptime
nproc
top
ps -eo pid,user,%cpu,%mem,etime,cmd --sort=-%cpu | head
journalctl -u todo-api --since "30 minutes ago"
```

If one process is high CPU:

```bash
ps -p <pid> -o pid,ppid,user,stat,%cpu,%mem,etime,cmd
```

Check app logs:

```bash
journalctl -u todo-api --since "30 minutes ago" | grep -Ei "slow|timeout|error"
```

Possible mitigations:

```text
Scale out
Restart stuck worker carefully
Rollback bad deployment
Move heavy job to background queue
Rate-limit abusive traffic
Optimize hot code path
```

---

# 32. Real Production Scenario — App Died Suddenly

Incident:

```text
todo-api stopped unexpectedly.
```

Check service:

```bash
systemctl status todo-api
journalctl -u todo-api --since "1 hour ago"
```

Check OOM:

```bash
journalctl -k --since "1 hour ago" | grep -Ei "oom|out of memory|killed process"
```

If OOM:

```text
The app likely used too much memory or the host was under memory pressure.
```

Next:

```bash
free -h
ps -eo pid,user,%mem,rss,cmd --sort=-rss | head
```

Possible fixes:

```text
Increase memory
Reduce worker count
Fix memory leak
Add container memory requests/limits correctly
Scale horizontally
Move large processing out of request path
```

---

# 33. Real Production Scenario — High Load but CPU Looks Idle

Symptoms:

```text
Load average high.
CPU idle is high.
Application slow.
```

Check:

```bash
top
vmstat 1
```

If `wa` high and `b` high:

```text
Processes are blocked on I/O.
```

Check:

```bash
iostat -xz 1
sudo iotop
df -h
journalctl -k --since "1 hour ago" | grep -Ei "disk|i/o|ext4|xfs|nvme"
```

Possible causes:

```text
Disk saturated
Database heavy writes
Slow EBS volume
Backup job
Log storm
Swap activity
Filesystem issue
```

---

# 34. Real Production Scenario — Too Many Open Files

Error:

```text
EMFILE: too many open files
```

Find PID:

```bash
pgrep -a todo-api
```

Check limits:

```bash
cat /proc/<pid>/limits | grep "open files"
```

Count open files:

```bash
sudo lsof -p <pid> | wc -l
```

If close to limit:

```text
The process may be leaking file descriptors or handling too many connections.
```

Temporary systemd increase:

```ini
[Service]
LimitNOFILE=65535
```

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl restart todo-api
```

But root cause may be app leak or connection management.

---

# 35. Interview Answers

Question:

```text
How do you troubleshoot high load average?
```

Strong answer:

```text
I first compare load average with the number of CPU cores using uptime and nproc. Then I check top or vmstat to determine whether the load is from CPU saturation or I/O wait. If CPU is high, I identify top CPU processes with ps or top. If CPU is idle but load is high, I check blocked processes, I/O wait, iostat, and disk activity. I also correlate with logs, deployments, traffic, and system events.
```

Question:

```text
How do you check memory pressure?
```

Strong answer:

```text
I use free -h to check available memory and swap usage, then vmstat 1 to see active swap in/out. I identify top memory processes with ps sorted by RSS or top sorted by memory. If a process disappeared or restarted, I check kernel logs for OOM killer events using journalctl -k. I also check whether memory usage is steadily increasing over time to detect possible leaks.
```

Question:

```text
What is the OOM killer?
```

Strong answer:

```text
The OOM killer is a Linux kernel mechanism that kills processes when the system runs out of memory and cannot satisfy allocations. It protects the system from complete failure. I check OOM events in kernel logs using journalctl -k and look for messages like “Out of memory” or “Killed process”. In containers, exit code 137 often indicates SIGKILL and may be caused by OOM.
```

Question:

```text
What is I/O wait?
```

Strong answer:

```text
I/O wait is CPU time spent waiting for disk or network I/O operations to complete. High I/O wait means processes are blocked waiting on storage or I/O rather than actively using CPU. I check it with top or vmstat, then use iostat and iotop to identify saturated disks or I/O-heavy processes.
```

---

# Today’s Core Rules

```text
Load average must be compared with CPU cores.
High load is not always CPU.
Use top to inspect CPU fields.
Use free -h and available memory, not just free memory.
Use vmstat to identify CPU, swap, and I/O pressure.
Use ps to find top CPU and memory processes.
Use journalctl -k to find OOM killer events.
Exit code 137 often means SIGKILL/OOM in containers.
High iowait points to storage bottlenecks.
Do not clear cache randomly.
Do not increase limits without understanding leaks.
Correlate performance issues with logs, traffic, and deployments.
```

Next lesson:

# Lesson 3.12 — Bash Scripting Foundation: variables, arguments, conditions, loops, functions, exit codes, traps, and automation structure

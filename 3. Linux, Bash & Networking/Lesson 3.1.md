# Module 3 — Linux, Bash & Networking

Now we begin the real terminal foundation.

This module is where you become comfortable with:

```text
Linux internals
Filesystem
Permissions
Users and groups
Processes
Signals
systemd
Logs
Bash scripting
Networking
DNS
HTTP/TLS debugging
Troubleshooting
Automation scripts
```

Your uploaded curriculum already says this phase is the absolute foundation because everything else runs on Linux and communicates over networks. It also includes Linux internals, Bash scripting, networking fundamentals, log analysis, and troubleshooting as core topics. 

We will go deeper than normal tutorials.

The method will be:

```text
Concept → Kernel/OS mental model → Command → Output explanation → Production example → Mistake → Debugging → Script → Interview answer → Lab
```

---

# Module 3 Roadmap — Linux, Bash & Networking

We will cover this module in depth:

```text
3.1  Linux mental model: kernel, shell, processes, files
3.2  Filesystem hierarchy: /etc, /var, /proc, /sys, /dev, /tmp, /opt
3.3  File commands: ls, cp, mv, rm, find, locate, tree, stat
3.4  Text processing: cat, less, head, tail, grep, awk, sed, cut, sort, uniq, wc
3.5  Permissions: rwx, chmod, chown, groups, umask, sticky bit, setuid, setgid
3.6  Users and groups: useradd, passwd, sudo, su, /etc/passwd, /etc/shadow
3.7  Processes: ps, top, htop, pgrep, kill, signals, zombies, nice, renice
3.8  systemd: services, unit files, journalctl, timers
3.9  Logs: /var/log, journald, application logs, log rotation
3.10 Disk and storage: df, du, lsblk, mount, fstab, inode issues
3.11 CPU and memory: uptime, free, vmstat, iostat, load average, OOM killer
3.12 Bash basics: variables, conditions, loops, functions, arguments
3.13 Bash safety: set -euo pipefail, traps, error handling, logging
3.14 Bash automation project: production healthcheck script
3.15 Networking fundamentals: IP, port, TCP, UDP, DNS, HTTP, TLS
3.16 Networking commands: ip, ss, ping, traceroute, dig, nslookup, curl, nc, tcpdump
3.17 Web debugging: curl -v, headers, status codes, TLS certs
3.18 Linux troubleshooting drills
3.19 Module 3 mini project: server health monitor + network diagnostic toolkit
```

This will become one of the strongest modules in the masterclass.

---

# Lesson 3.1 — Linux Mental Model: Kernel, Shell, Processes, Files

Before commands, understand what Linux actually is.

A beginner thinks:

```text
Linux = terminal commands
```

A DevOps engineer thinks:

```text
Linux = kernel + processes + filesystems + users + permissions + networking + services + logs
```

Most production servers run Linux. Docker containers use Linux kernel features. Kubernetes runs Linux containers. Jenkins agents often run Linux. Terraform and Ansible usually operate against Linux servers. Logs, processes, ports, and services all require Linux understanding.

So this module is not optional.

---

# 1. What is Linux?

Linux is technically the **kernel**.

The kernel is the core part of the operating system.

It manages:

```text
CPU
Memory
Processes
Filesystems
Devices
Networking
Permissions
System calls
```

A complete Linux system includes:

```text
Linux kernel
GNU tools
Shell
Package manager
System services
Filesystem
User-space programs
```

When you use Ubuntu, you are using a Linux distribution.

A distribution includes:

```text
Linux kernel
apt package manager
systemd
bash
core utilities
network tools
default configs
```

Examples of Linux distributions:

```text
Ubuntu
Debian
RHEL
CentOS Stream
Rocky Linux
AlmaLinux
Amazon Linux
Fedora
Arch
```

In DevOps, Ubuntu and RHEL-like systems are very common.

---

# 2. Kernel vs Shell

This is a very important mental model.

```text
You type command
  ↓
Shell interprets command
  ↓
Program runs
  ↓
Program asks kernel for resources
  ↓
Kernel talks to CPU/memory/disk/network
```

Example:

```bash
ls -la
```

What happens?

```text
Bash receives "ls -la"
Bash finds /usr/bin/ls
Bash starts a process
ls asks kernel to read directory entries
Kernel reads filesystem metadata
ls prints output to terminal
```

So `ls` is not magic.

It is a program.

The shell launches it.

The kernel provides system access.

---

# 3. What is a Shell?

A shell is a command interpreter.

Common shells:

```text
bash
zsh
sh
fish
dash
```

Check your shell:

```bash
echo $SHELL
```

Check current shell process:

```bash
ps -p $$
```

Example output:

```text
PID TTY          TIME CMD
1234 pts/0    00:00:00 bash
```

Meaning:

```text
Your current terminal session is running bash.
```

In this masterclass, we will use Bash.

Why?

```text
Bash is available almost everywhere.
CI/CD scripts use Bash.
Linux automation often uses Bash.
Docker entrypoints often use Bash/sh.
Jenkins shell steps often use Bash.
GitHub Actions run shell commands.
```

---

# 4. What is a Command?

A command can be:

```text
Binary executable
Shell builtin
Shell function
Alias
Script
```

Example:

```bash
type cd
type ls
type echo
type grep
```

You may see:

```text
cd is a shell builtin
ls is aliased to `ls --color=auto`
grep is /usr/bin/grep
```

This matters.

For example, `cd` must be a shell builtin because it changes the shell’s current directory.

If `cd` were an external program, it would change only its own process directory and exit.

---

# 5. PATH — How Linux Finds Commands

When you run:

```bash
git
```

The shell searches directories listed in `PATH`.

Check:

```bash
echo $PATH
```

Example:

```text
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

Find command location:

```bash
which git
```

or:

```bash
command -v git
```

Example:

```text
/usr/bin/git
```

If command is not found:

```text
Either it is not installed
or its directory is not in PATH
```

Production example:

```bash
node -v
```

If it works in your terminal but not in Jenkins, maybe Jenkins has a different `PATH`.

That is a real-world issue.

---

# 6. Everything is a File

Linux uses a powerful idea:

```text
Everything is represented as a file or file-like interface.
```

Examples:

```text
Regular files       → /home/vivek/file.txt
Directories         → /etc
Devices             → /dev/sda
Processes           → /proc/<pid>
Kernel info         → /proc/meminfo
System info         → /sys
Logs                → /var/log
Sockets             → file descriptors
```

This is why you can run:

```bash
cat /proc/meminfo
```

You are not reading a normal disk file.

You are reading live kernel information exposed as a virtual file.

---

# 7. Filesystem Mental Model

Linux has one tree starting from:

```text
/
```

This is called the root directory.

Everything lives under `/`.

```text
/
├── bin
├── boot
├── dev
├── etc
├── home
├── lib
├── media
├── mnt
├── opt
├── proc
├── root
├── run
├── sbin
├── sys
├── tmp
├── usr
└── var
```

Unlike Windows, Linux does not have:

```text
C:
D:
E:
```

Disks and partitions are mounted into the same tree.

Example:

```text
/data disk mounted at /mnt/data
external disk mounted at /media/user/disk
```

This matters for servers, Docker volumes, Kubernetes mounts, and cloud disks.

---

# 8. Absolute Path vs Relative Path

Absolute path starts from `/`.

Example:

```bash
/home/vivek/devops-masterclass
/etc/nginx/nginx.conf
/var/log/syslog
```

Relative path starts from current directory.

Example:

```bash
./script.sh
../README.md
02-git-github/github-security.md
```

Check current directory:

```bash
pwd
```

Example:

```text
/home/vivek/devops-masterclass
```

If you are here:

```text
/home/vivek/devops-masterclass
```

Then this relative path:

```text
02-git-github/github-security.md
```

Means:

```text
/home/vivek/devops-masterclass/02-git-github/github-security.md
```

Production mistake:

```bash
rm -rf logs/*
```

This is safe only if you are in the correct directory.

If your script runs from a different working directory, it can delete the wrong files.

That is why scripts should use absolute paths or carefully calculate their base directory.

---

# 9. Current Directory and Home Directory

Important symbols:

```text
.   current directory
..  parent directory
~   current user's home directory
/   root directory
```

Examples:

```bash
pwd
ls .
ls ..
cd ~
cd /
cd -
```

`cd -` returns to the previous directory.

Very useful.

---

# 10. Basic Navigation Commands

```bash
pwd
ls
ls -l
ls -la
cd /etc
cd ~
cd -
tree -L 2
```

What `ls -la` means:

```text
-l   long format
-a   show hidden files
```

Hidden files in Linux start with dot:

```text
.bashrc
.gitignore
.env
.ssh
```

Important:

```text
Hidden does not mean secure.
```

A `.env` file is hidden from normal `ls`, but anyone with permission can still read it.

---

# 11. File Metadata with `stat`

Use:

```bash
stat README.md
```

It shows:

```text
Size
Blocks
Permissions
Owner
Group
Access time
Modify time
Change time
Birth time, sometimes
```

Important difference:

```text
mtime = file content modified
ctime = metadata changed
atime = file accessed
```

Example:

```bash
chmod 600 file.txt
```

This changes `ctime`, not necessarily `mtime`.

Why DevOps cares:

```text
Troubleshooting changed files
Detecting unexpected permission changes
Checking if config file was modified
Auditing deployments
```

---

# 12. Processes Mental Model

A process is a running program.

Example:

```text
nginx process
node process
python process
bash process
docker process
sshd process
```

Every process has:

```text
PID
Parent PID
Owner user
Memory usage
CPU usage
Open files
Environment variables
Current working directory
Command
```

Check processes:

```bash
ps aux
```

Better tree view:

```bash
ps -ef --forest
```

Find a process:

```bash
pgrep -a nginx
pgrep -a node
```

Show current shell PID:

```bash
echo $$
```

Show parent process:

```bash
ps -o pid,ppid,cmd -p $$
```

---

# 13. Parent and Child Processes

When you run a command from Bash:

```bash
sleep 60
```

Bash creates a child process.

```text
bash
 └── sleep 60
```

Run:

```bash
sleep 60 &
```

Then:

```bash
ps -ef | grep sleep
```

You will see `sleep`.

Stop it:

```bash
pkill sleep
```

This process model matters for:

```text
systemd services
Docker containers
Jenkins shell steps
Signal handling
Graceful shutdown
Zombie processes
```

---

# 14. Exit Codes

Every command returns an exit code.

```text
0     success
non-0 failure
```

Run:

```bash
ls /etc
echo $?
```

You should see:

```text
0
```

Now:

```bash
ls /does-not-exist
echo $?
```

You will see non-zero, often:

```text
2
```

In Bash scripts and CI/CD, exit codes decide success or failure.

Example GitHub Actions step:

```yaml
run: npm test
```

If `npm test` exits non-zero, the workflow fails.

Example Jenkins step:

```groovy
sh 'npm test'
```

If `npm test` exits non-zero, Jenkins stage fails.

Exit codes are the language of automation.

---

# 15. Standard Streams: stdin, stdout, stderr

Every Linux process usually has three streams:

```text
stdin   = input
stdout  = normal output
stderr  = error output
```

Numbers:

```text
0 = stdin
1 = stdout
2 = stderr
```

Example:

```bash
echo "hello"
```

This writes to stdout.

Example error:

```bash
ls /does-not-exist
```

This writes to stderr.

Redirect stdout:

```bash
echo "hello" > output.txt
```

Append stdout:

```bash
echo "again" >> output.txt
```

Redirect stderr:

```bash
ls /does-not-exist 2> error.txt
```

Redirect stdout and stderr:

```bash
command > output.log 2>&1
```

Modern Bash version:

```bash
command &> output.log
```

Discard output:

```bash
command > /dev/null 2>&1
```

DevOps example:

```bash
./backup.sh > /var/log/backup.log 2>&1
```

This stores both normal and error logs.

---

# 16. Pipes

A pipe sends stdout of one command to stdin of another.

```bash
ps aux | grep nginx
```

Flow:

```text
ps aux output
  ↓
grep nginx input
```

More examples:

```bash
cat /var/log/syslog | grep error
```

Better:

```bash
grep error /var/log/syslog
```

Count matching lines:

```bash
grep -i error /var/log/syslog | wc -l
```

Top 10 largest files in current directory:

```bash
du -ah . | sort -hr | head -10
```

Pipes are the basis of Linux power.

---

# 17. Environment Variables

Environment variables are key-value values available to processes.

Check:

```bash
env
```

Print one:

```bash
echo $HOME
echo $USER
echo $PATH
```

Set variable for current shell:

```bash
APP_ENV=dev
echo $APP_ENV
```

Export variable so child processes can see it:

```bash
export APP_ENV=dev
```

Run command with temporary environment variable:

```bash
APP_ENV=prod node server.js
```

DevOps use cases:

```text
DATABASE_URL
NODE_ENV
AWS_REGION
LOG_LEVEL
PORT
DOCKER_BUILDKIT
KUBECONFIG
```

Important:

```text
Environment variables are not automatically secret.
They can leak through logs, process inspection, crash dumps, CI output.
```

Never print sensitive environment variables.

---

# 18. Shell Configuration Files

Common Bash files:

```text
~/.bashrc
~/.profile
~/.bash_profile
/etc/profile
/etc/bash.bashrc
```

`~/.bashrc` runs for interactive Bash shells.

Check:

```bash
ls -la ~/.bashrc
```

Common uses:

```text
Aliases
PATH additions
Shell prompt customization
nvm loading
kubectl aliases
Terraform aliases
```

Example alias:

```bash
alias ll='ls -la'
```

Add to `~/.bashrc`:

```bash
echo "alias ll='ls -la'" >> ~/.bashrc
source ~/.bashrc
```

Be careful not to blindly paste large shell config snippets.

A broken `.bashrc` can break your terminal experience.

---

# 19. Package Managers

Ubuntu uses `apt`.

Common commands:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y nginx
sudo apt remove nginx
sudo apt search nginx
apt show nginx
dpkg -l | grep nginx
```

Important difference:

```bash
sudo apt update
```

Updates package index.

```bash
sudo apt upgrade
```

Upgrades installed packages.

Beginner mistake:

```text
Thinking apt update upgrades software.
```

It does not. It updates the package list.

---

# 20. Manual Pages and Help

Linux has built-in documentation.

```bash
man ls
man grep
man chmod
```

Short help:

```bash
ls --help
grep --help
```

Search man pages:

```bash
man -k network
```

In production, you may not always have internet access.

Learn to use local help.

---

# 21. First Command Practice Lab

Run these:

```bash
cd ~/devops-masterclass

pwd

ls

ls -la

tree -L 2

stat README.md

type cd

type ls

which git

command -v bash

echo $SHELL

ps -p $$

echo $PATH

env | sort | head

ls /does-not-exist

echo $?
```

Do not just run them.

Write what each output means.

---

# 22. Create Lesson Notes

Create:

```bash
cd ~/devops-masterclass

git switch main
git pull origin main

git switch -c docs/linux-mental-model

mkdir -p 03-linux-bash-networking
nano 03-linux-bash-networking/linux-mental-model.md
```

Paste:

````markdown
# Linux Mental Model

## Linux System

Linux is built around:

- Kernel
- Shell
- Processes
- Filesystem
- Users and permissions
- Networking
- Services
- Logs

## Kernel vs Shell

The shell interprets commands. The kernel manages CPU, memory, processes, filesystems, devices, and networking.

## Everything is a File

Linux exposes many system resources as files:

- `/proc` for process and kernel information
- `/sys` for kernel and device information
- `/dev` for devices
- `/var/log` for logs

## Important Concepts

- Command
- Process
- PID
- Parent process
- Exit code
- stdin
- stdout
- stderr
- Pipe
- Environment variable
- PATH

## Core Commands

```bash
pwd
ls -la
cd
tree -L 2
stat README.md
type cd
which git
command -v bash
echo $PATH
ps aux
ps -ef --forest
echo $?
env
````

## Rules

* Always know your current directory before destructive commands.
* Exit code `0` means success.
* Non-zero exit code means failure.
* Use pipes to combine small tools.
* Do not print secrets from environment variables.
* Work inside Linux filesystem, not Windows-mounted paths.

````

Commit:

```bash
git status
git diff
git add 03-linux-bash-networking/linux-mental-model.md
git diff --staged
git commit -m "docs: add Linux mental model notes"
git push -u origin docs/linux-mental-model
````

Open PR.

---

# 23. Mini Script — System Identity Script

Now create your first Linux script in this module.

```bash
mkdir -p 03-linux-bash-networking/scripts
nano 03-linux-bash-networking/scripts/system-identity.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "===== System Identity ====="
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo "Shell: ${SHELL:-unknown}"
echo "Current directory: $(pwd)"
echo "Date: $(date)"
echo

echo "===== OS Info ====="
if [ -f /etc/os-release ]; then
  cat /etc/os-release
else
  echo "Cannot find /etc/os-release"
fi

echo
echo "===== Kernel ====="
uname -a

echo
echo "===== CPU Count ====="
nproc

echo
echo "===== Memory ====="
free -h

echo
echo "===== Disk ====="
df -h

echo
echo "===== IP Addresses ====="
ip addr show || true

echo
echo "===== Listening Ports ====="
ss -tulnp || true

echo
echo "===== Done ====="
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/system-identity.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/system-identity.sh
```

Commit:

```bash
git add 03-linux-bash-networking/scripts/system-identity.sh
git commit -m "feat: add system identity script"
git push
```

---

# 24. Understand the Script

Important line:

```bash
#!/usr/bin/env bash
```

This tells Linux:

```text
Run this script using bash found in PATH.
```

Important line:

```bash
set -euo pipefail
```

Meaning:

```text
-e  exit on command failure
-u  error on undefined variables
-o pipefail  fail pipeline if any command fails
```

This is the standard safety baseline for Bash scripts.

This line:

```bash
${SHELL:-unknown}
```

Means:

```text
Use SHELL if set.
Otherwise use unknown.
```

This avoids failure with `set -u`.

This line:

```bash
ip addr show || true
```

Means:

```text
Try to run ip addr show.
If it fails, do not fail the whole script.
```

Use this carefully.

Do not hide important failures accidentally.

---

# 25. Production Example

Suppose you SSH into a new server and need to quickly understand it.

Run:

```bash
./system-identity.sh
```

It tells you:

```text
Who am I?
Which host is this?
Which OS?
Which kernel?
How much CPU?
How much RAM?
How much disk?
Which IPs?
Which ports are listening?
```

This is exactly how real troubleshooting starts.

Before changing anything, observe the system.

---

# 26. Common Beginner Mistakes

## Mistake 1 — Not knowing where you are

Bad:

```bash
rm -rf *
```

Without checking:

```bash
pwd
```

Always know current directory.

---

## Mistake 2 — Ignoring exit codes

Bad:

```bash
backup_database
upload_backup
echo "Backup successful"
```

If backup failed but script continued, you have fake success.

Better:

```bash
set -euo pipefail
```

---

## Mistake 3 — Printing secrets

Bad:

```bash
echo "DB password is $DB_PASSWORD"
```

Good:

```bash
echo "DB password variable is set"
```

---

## Mistake 4 — Running random commands with sudo

Bad:

```bash
sudo chmod -R 777 /
```

Catastrophic.

Better:

```text
Understand exactly which path, owner, and permission are needed.
```

---

# 27. Interview Answers

Question:

```text
What is the difference between kernel and shell?
```

Strong answer:

```text
The kernel is the core of the operating system. It manages CPU, memory, processes, filesystems, devices, networking, and system calls. The shell is a user-space program that interprets commands and starts processes. When I run a command like ls, the shell finds and starts the ls program, and that program asks the kernel to read filesystem information.
```

Question:

```text
What does exit code 0 mean?
```

Strong answer:

```text
Exit code 0 means the command completed successfully. A non-zero exit code indicates failure or abnormal result. CI/CD systems like GitHub Actions and Jenkins rely on exit codes to decide whether a step passes or fails.
```

Question:

```text
What are stdin, stdout, and stderr?
```

Strong answer:

```text
They are the standard streams of a process. stdin is input, stdout is normal output, and stderr is error output. They are represented by file descriptors 0, 1, and 2. In scripts and CI/CD, redirecting stdout and stderr properly is important for logging and troubleshooting.
```

---

# Today’s Core Rules

```text
Linux is not commands; it is a system model.
The shell runs commands; the kernel manages resources.
Everything is exposed as files or file-like interfaces.
Always know your current directory.
Exit codes control automation.
stdin, stdout, stderr are essential for scripting.
PATH decides how commands are found.
Processes have PIDs and parent processes.
Observe first, change later.
```

Next lesson:

# Lesson 3.2 — Linux Filesystem Deep Dive: /etc, /var, /proc, /sys, /dev, /run, /tmp, /opt, /usr, /home

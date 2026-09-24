# Lesson 3.2 — Linux Filesystem Deep Dive

Now we go deeper into the Linux filesystem.

In DevOps, this is extremely important because almost every production task involves knowing **where things live**:

```text
Application config
System config
Logs
Services
Temporary files
Mount points
Secrets
Process information
Device files
Runtime sockets
Package binaries
```

A weak Linux user memorizes commands.

A strong DevOps engineer understands the filesystem layout.

---

# 1. Linux Filesystem Mental Model

Linux has one root tree:

```text
/
```

Everything starts from `/`.

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

Unlike Windows:

```text
C:
D:
E:
```

Linux mounts everything into one directory tree.

Example:

```text
Disk partition mounted at /
Extra disk mounted at /mnt/data
USB disk mounted at /media/vivek/usb
Kubernetes volume mounted at /app/data
Docker volume mounted inside container at /var/lib/postgresql/data
```

This matters for Docker, Kubernetes, EC2, EBS volumes, Nginx, logs, databases, and troubleshooting.

---

# 2. Why DevOps Engineers Must Know This

When production breaks, you may need to quickly answer:

```text
Where is the config file?
Where are the logs?
Where is the service file?
Where is the mounted disk?
Where is the app installed?
Where is the process information?
Where is the socket file?
Where are temporary files?
Where is the SSH config?
Where is the systemd unit?
```

Examples:

```text
Nginx config             → /etc/nginx/
Application logs         → /var/log/
Systemd services         → /etc/systemd/system/
Runtime sockets          → /run/
User SSH keys            → ~/.ssh/
Kernel process info      → /proc/
Device files             → /dev/
Mounted external disks   → /mnt/ or /media/
Optional software        → /opt/
```

If you know the filesystem, troubleshooting becomes much faster.

---

# 3. `/` — Root Directory

`/` is the top of the filesystem.

Check:

```bash
cd /
ls -la
```

Output will show directories like:

```text
bin
boot
dev
etc
home
proc
run
tmp
usr
var
```

Important:

```text
Do not randomly create project folders directly under /.
```

Bad:

```bash
sudo mkdir /myapp
```

Better:

```bash
mkdir -p ~/devops-masterclass
```

or for production apps:

```text
/opt/myapp
/srv/myapp
/var/www/myapp
```

---

# 4. `/home` — User Home Directories

Normal users live under:

```text
/home
```

Your user home is usually:

```text
/home/vivek
```

Check:

```bash
echo $HOME
cd ~
pwd
```

Example:

```text
/home/vivek
```

Common files:

```text
~/.bashrc
~/.profile
~/.ssh/
~/.gitconfig
~/.cache/
~/.config/
```

Your learning repo should live here:

```text
~/devops-masterclass
```

Good:

```bash
cd ~/devops-masterclass
```

Bad for WSL performance:

```bash
cd /mnt/c/Users/Vivek/Desktop/project
```

For WSL development, prefer Linux filesystem:

```text
/home/vivek/...
```

---

# 5. `/root` — Root User Home

Root user’s home directory is:

```text
/root
```

This is not the same as `/`.

Check:

```bash
sudo ls -la /root
```

Important distinction:

```text
/      = filesystem root
/root  = root user's home directory
```

Beginner confusion:

```text
“I am in root”
```

This can mean two different things:

```text
You are in /
or
You are logged in as root user
or
You are inside /root
```

Always check:

```bash
pwd
whoami
```

---

# 6. `/etc` — System Configuration

`/etc` contains system-wide configuration files.

Examples:

```text
/etc/hosts
/etc/hostname
/etc/passwd
/etc/group
/etc/shadow
/etc/ssh/sshd_config
/etc/nginx/nginx.conf
/etc/systemd/system/
```

Useful commands:

```bash
ls -la /etc
cat /etc/os-release
cat /etc/hostname
cat /etc/hosts
```

Production examples:

```text
Nginx configuration     → /etc/nginx/
SSH server config       → /etc/ssh/sshd_config
Systemd service units   → /etc/systemd/system/
Environment config      → sometimes /etc/default/
```

Important rule:

```text
Before editing files in /etc, take a backup.
```

Example:

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
```

Then edit:

```bash
sudo nano /etc/ssh/sshd_config
```

Validate before restarting service if possible.

For Nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Do not restart blindly.

---

# 7. `/var` — Variable Data

`/var` contains data that changes over time.

Examples:

```text
/var/log
/var/www
/var/lib
/var/cache
/var/tmp
/var/spool
```

Most important for DevOps:

```text
/var/log
/var/lib
/var/www
```

Check:

```bash
ls -la /var
```

---

## `/var/log`

System and application logs often live here.

Examples:

```text
/var/log/syslog
/var/log/auth.log
/var/log/nginx/access.log
/var/log/nginx/error.log
/var/log/dpkg.log
```

Commands:

```bash
ls -lh /var/log
sudo tail -f /var/log/syslog
sudo tail -f /var/log/auth.log
```

Nginx logs:

```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

Production habit:

```text
When something fails, check logs first.
```

---

## `/var/lib`

Application state data often lives here.

Examples:

```text
/var/lib/docker
/var/lib/postgresql
/var/lib/mysql
/var/lib/jenkins
/var/lib/redis
```

Important:

```text
Do not casually delete /var/lib/*.
```

This may delete Docker images, database data, Jenkins jobs, or package state.

Example:

```bash
sudo du -sh /var/lib/docker
```

This shows Docker storage usage.

---

## `/var/www`

Often used for web content.

Example:

```text
/var/www/html
```

Nginx/Apache may serve files from here.

Check:

```bash
ls -la /var/www
```

Example:

```bash
echo "hello" | sudo tee /var/www/html/index.html
```

---

# 8. `/tmp` — Temporary Files

`/tmp` is for temporary files.

Check:

```bash
ls -la /tmp
```

Important properties:

```text
Usually world-writable
Often cleaned automatically
Not for permanent data
```

Create temp file:

```bash
touch /tmp/test-file
ls -la /tmp/test-file
```

In scripts, use:

```bash
mktemp
```

Example:

```bash
tmpfile=$(mktemp)
echo "hello" > "$tmpfile"
cat "$tmpfile"
rm -f "$tmpfile"
```

Why `mktemp`?

```text
It avoids unsafe predictable temp filenames.
```

Bad:

```bash
tmpfile="/tmp/my-script-output.txt"
```

Another process could conflict with it.

Better:

```bash
tmpfile=$(mktemp)
```

---

# 9. `/var/tmp` vs `/tmp`

Both are temporary, but:

```text
/tmp      may be cleared on reboot
/var/tmp  usually persists across reboot
```

Use `/tmp` for short-lived temporary files.

Use `/var/tmp` for temporary files that may need to survive reboot.

But do not store important data in either.

---

# 10. `/proc` — Process and Kernel Information

`/proc` is a virtual filesystem.

It does not store normal files on disk.

It exposes live kernel and process information.

Check:

```bash
ls -la /proc | head
```

Examples:

```bash
cat /proc/cpuinfo
cat /proc/meminfo
cat /proc/loadavg
cat /proc/uptime
cat /proc/version
```

Process-specific:

```bash
echo $$
ls -la /proc/$$
```

`$$` is current shell PID.

Useful files:

```text
/proc/<pid>/cmdline
/proc/<pid>/environ
/proc/<pid>/cwd
/proc/<pid>/fd
/proc/<pid>/status
```

Example:

```bash
cat /proc/$$/status
```

Show current process working directory:

```bash
readlink /proc/$$/cwd
```

Show file descriptors:

```bash
ls -la /proc/$$/fd
```

DevOps use case:

```text
Find what files a process has open.
Find a process environment.
Find current working directory of a stuck process.
Check memory/process state.
```

Important security note:

```text
Environment variables may be visible through /proc depending on permissions.
Do not assume env vars are perfectly secret.
```

---

# 11. `/sys` — Kernel and Device Information

`/sys` is another virtual filesystem.

It exposes kernel device and hardware information.

Check:

```bash
ls -la /sys
```

Examples:

```text
/sys/class/net
/sys/block
/sys/devices
```

Show network interfaces:

```bash
ls -la /sys/class/net
```

Show block devices:

```bash
ls -la /sys/block
```

Most daily DevOps work uses `/proc` more than `/sys`, but `/sys` is important for low-level debugging.

---

# 12. `/dev` — Device Files

`/dev` contains device files.

Examples:

```text
/dev/sda
/dev/nvme0n1
/dev/null
/dev/zero
/dev/random
/dev/urandom
/dev/tty
```

Check:

```bash
ls -la /dev | head
```

Very important special files:

---

## `/dev/null`

Discards output.

```bash
command > /dev/null 2>&1
```

Use case:

```bash
curl -s https://example.com > /dev/null
```

---

## `/dev/zero`

Produces endless zero bytes.

Example:

```bash
head -c 1M /dev/zero > zero-file
ls -lh zero-file
rm zero-file
```

---

## `/dev/random` and `/dev/urandom`

Used for random data.

Example:

```bash
head -c 16 /dev/urandom | xxd
```

---

# 13. `/run` — Runtime State

`/run` stores runtime data since boot.

Examples:

```text
PID files
Socket files
Lock files
Runtime service state
```

Check:

```bash
ls -la /run
```

Examples:

```text
/run/docker.sock
/run/systemd/
```

Docker socket may be:

```text
/var/run/docker.sock
```

Often `/var/run` is a symlink to `/run`.

Check:

```bash
ls -ld /var/run
```

Important:

```text
Access to docker.sock is powerful.
A user who can access Docker socket can often control the host.
```

Do not casually give users access to Docker group on production machines.

---

# 14. `/usr` — User System Resources

`/usr` contains most user-space programs and libraries.

Common:

```text
/usr/bin
/usr/sbin
/usr/lib
/usr/local/bin
/usr/share
```

Check:

```bash
ls -la /usr
```

Where many commands live:

```bash
ls /usr/bin | head
which git
which python3
which curl
```

Usually:

```text
/usr/bin/git
/usr/bin/python3
/usr/bin/curl
```

---

## `/usr/local/bin`

Locally installed custom binaries often go here.

Example:

```text
/usr/local/bin/docker-compose
/usr/local/bin/kubectl
/usr/local/bin/helm
```

Check:

```bash
echo $PATH
ls -la /usr/local/bin
```

If you install a custom script globally, you may place it in:

```text
/usr/local/bin
```

Example:

```bash
sudo cp myscript /usr/local/bin/myscript
sudo chmod +x /usr/local/bin/myscript
```

Then run:

```bash
myscript
```

But for learning scripts, keep them in your repo.

---

# 15. `/bin` and `/sbin`

Historically:

```text
/bin   essential user commands
/sbin  essential system/admin commands
```

Examples:

```text
/bin/ls
/bin/bash
/sbin/ip
/sbin/reboot
```

On modern Ubuntu, `/bin` may be symlinked to `/usr/bin`.

Check:

```bash
ls -ld /bin
ls -ld /sbin
```

You may see:

```text
/bin -> usr/bin
/sbin -> usr/sbin
```

This is normal.

---

# 16. `/opt` — Optional Software

`/opt` is often used for third-party or manually installed software.

Examples:

```text
/opt/myapp
/opt/prometheus
/opt/grafana-agent
/opt/company-app
```

For production app installed manually:

```bash
sudo mkdir -p /opt/todo-app
```

Then deploy app files there.

Important:

```text
/opt is common for self-contained software.
```

But if using Docker/Kubernetes, app files usually live inside containers/images instead.

---

# 17. `/srv` — Service Data

`/srv` can store data served by the system.

Examples:

```text
/srv/www
/srv/git
/srv/ftp
/srv/myapp
```

Not always used by default.

Some teams prefer:

```text
/srv/app-name
```

Others prefer:

```text
/opt/app-name
/var/www/app-name
```

The exact choice depends on company convention.

The important thing is consistency.

---

# 18. `/mnt` and `/media` — Mount Points

`/mnt` is commonly used for manually mounted filesystems.

`/media` is commonly used for removable media.

Examples:

```text
/mnt/data
/mnt/backup
/media/vivek/USB
```

Commands:

```bash
lsblk
df -h
mount | column -t
```

Example mount:

```bash
sudo mkdir -p /mnt/data
sudo mount /dev/sdb1 /mnt/data
```

Unmount:

```bash
sudo umount /mnt/data
```

Production warning:

```text
Never unmount a disk without checking what is using it.
```

Check open files:

```bash
sudo lsof +f -- /mnt/data
```

or:

```bash
fuser -vm /mnt/data
```

---

# 19. `/boot` — Boot Files

`/boot` contains files needed to boot Linux.

Examples:

```text
Kernel images
initramfs
GRUB config
```

Check:

```bash
ls -lh /boot
```

Production issue:

```text
/boot partition full
```

This can prevent kernel updates.

Check:

```bash
df -h /boot
```

Do not randomly delete files from `/boot`.

Use package manager cleanup.

---

# 20. Important Config Files to Know

## OS info

```bash
cat /etc/os-release
```

## Hostname

```bash
cat /etc/hostname
hostname
hostnamectl
```

## Hosts file

```bash
cat /etc/hosts
```

Used for local hostname resolution.

Example:

```text
127.0.0.1 localhost
```

## Users

```bash
cat /etc/passwd
```

## Groups

```bash
cat /etc/group
```

## Password hashes

```bash
sudo cat /etc/shadow
```

Do not expose `/etc/shadow`.

## Filesystems

```bash
cat /etc/fstab
```

`fstab` controls filesystems mounted at boot.

Wrong `fstab` entries can break boot.

Always be careful.

---

# 21. Finding Files

Use `find`.

Find by name:

```bash
find . -name "*.md"
```

Find under `/etc`:

```bash
sudo find /etc -name "nginx.conf"
```

Find large files:

```bash
find . -type f -size +100M
```

Find recently modified files:

```bash
find . -type f -mtime -1
```

Meaning:

```text
Files modified in the last 1 day.
```

Find empty files:

```bash
find . -type f -empty
```

Find executable scripts:

```bash
find . -type f -name "*.sh" -perm /111
```

Find and delete carefully:

```bash
find . -type f -name "*.tmp" -print
```

Only after reviewing:

```bash
find . -type f -name "*.tmp" -delete
```

Production rule:

```text
Print before delete.
```

---

# 22. Disk Usage Commands

Check filesystem usage:

```bash
df -h
```

Check current directory size:

```bash
du -sh .
```

Check top large directories:

```bash
du -h --max-depth=1 . | sort -hr | head
```

Check root large directories:

```bash
sudo du -h --max-depth=1 / 2>/dev/null | sort -hr | head
```

Common production issue:

```text
Server disk full
```

Debug path:

```bash
df -h
sudo du -h --max-depth=1 / | sort -hr | head
sudo du -h --max-depth=1 /var | sort -hr | head
sudo du -h --max-depth=1 /var/log | sort -hr | head
```

Possible causes:

```text
Logs too large
Docker images/containers
Database files
Backups
Core dumps
Temporary files
Jenkins workspace
```

---

# 23. Inodes

Disk can be full in two ways:

```text
No space left
No inodes left
```

Check disk space:

```bash
df -h
```

Check inode usage:

```bash
df -i
```

If inodes are full, you may have too many small files.

Example causes:

```text
Millions of cache files
Session files
Small log fragments
Node modules
Build artifacts
```

Find directories with many files:

```bash
find . -xdev -type f | cut -d/ -f2 | sort | uniq -c | sort -nr | head
```

We will go deeper in storage lesson.

For now, remember:

```text
df -h checks space.
df -i checks inode count.
```

---

# 24. Symlinks

A symlink is a pointer to another file or directory.

Create:

```bash
ln -s target link-name
```

Example:

```bash
echo "hello" > original.txt
ln -s original.txt shortcut.txt
cat shortcut.txt
```

Check:

```bash
ls -la shortcut.txt
```

Output:

```text
shortcut.txt -> original.txt
```

Remove symlink:

```bash
rm shortcut.txt
```

This removes the link, not the original file.

Production use:

```text
Atomic deployments
current -> releases/v1.2.0
```

Example:

```text
/opt/myapp/releases/v1.2.0
/opt/myapp/releases/v1.2.1
/opt/myapp/current -> /opt/myapp/releases/v1.2.1
```

Rollback:

```bash
ln -sfn /opt/myapp/releases/v1.2.0 /opt/myapp/current
```

This is how many deployment systems work.

---

# 25. Hard Links

A hard link is another directory entry pointing to the same inode.

Create:

```bash
echo "hello" > file1.txt
ln file1.txt file2.txt
```

Check inode:

```bash
ls -li file1.txt file2.txt
```

Both have same inode.

If you delete `file1.txt`, data still exists through `file2.txt`.

Hard links are less commonly used in daily DevOps than symlinks, but you should know they exist.

---

# 26. Practical Lab — Explore Your System

Run these commands and observe output:

```bash
cd /

pwd

ls -la

tree -L 1 /

cat /etc/os-release

cat /etc/hostname

cat /etc/hosts

ls -lh /var/log

df -h

df -i

lsblk

mount | head

cat /proc/meminfo | head

cat /proc/cpuinfo | head

cat /proc/loadavg

ls -la /sys/class/net

ls -la /dev | head

ls -ld /bin /sbin /var/run

echo $PATH

which bash

which git
```

Write notes for each:

```text
What did this command show?
Why might this matter in production?
```

---

# 27. Script — Filesystem Inspector

Now create a useful script.

```bash
cd ~/devops-masterclass

mkdir -p 03-linux-bash-networking/scripts
nano 03-linux-bash-networking/scripts/filesystem-inspector.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_PATH="${1:-/}"

if [ ! -e "$TARGET_PATH" ]; then
  echo "ERROR: Path does not exist: $TARGET_PATH" >&2
  exit 1
fi

echo "===== Filesystem Inspector ====="
echo "Target path: $TARGET_PATH"
echo "User: $(whoami)"
echo "Date: $(date)"
echo

echo "===== Path Metadata ====="
stat "$TARGET_PATH"
echo

echo "===== Disk Usage for Filesystem ====="
df -h "$TARGET_PATH"
echo

echo "===== Inode Usage for Filesystem ====="
df -i "$TARGET_PATH"
echo

if [ -d "$TARGET_PATH" ]; then
  echo "===== Directory Size ====="
  du -sh "$TARGET_PATH" 2>/dev/null || true
  echo

  echo "===== Top 10 Largest Items ====="
  du -h --max-depth=1 "$TARGET_PATH" 2>/dev/null | sort -hr | head -10 || true
  echo

  echo "===== Recently Modified Files ====="
  find "$TARGET_PATH" -xdev -type f -mtime -1 2>/dev/null | head -20 || true
else
  echo "===== File Details ====="
  ls -lh "$TARGET_PATH"
fi

echo
echo "===== Done ====="
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/filesystem-inspector.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/filesystem-inspector.sh .
```

Try:

```bash
./03-linux-bash-networking/scripts/filesystem-inspector.sh /var
```

Try:

```bash
./03-linux-bash-networking/scripts/filesystem-inspector.sh /does-not-exist
```

Expected behavior:

```text
It should print an error and exit non-zero.
```

Check exit code:

```bash
echo $?
```

---

# 28. Understand the Script

This line:

```bash
TARGET_PATH="${1:-/}"
```

Means:

```text
Use first argument if provided.
Otherwise use /.
```

So:

```bash
./filesystem-inspector.sh /var
```

sets:

```text
TARGET_PATH=/var
```

But:

```bash
./filesystem-inspector.sh
```

sets:

```text
TARGET_PATH=/
```

This block:

```bash
if [ ! -e "$TARGET_PATH" ]; then
  echo "ERROR: Path does not exist: $TARGET_PATH" >&2
  exit 1
fi
```

Means:

```text
If path does not exist, print error to stderr and exit with failure.
```

This:

```bash
>&2
```

sends output to stderr.

This:

```bash
2>/dev/null
```

hides permission errors.

Use carefully. In scripts, hiding errors is okay only when you intentionally expect some unreadable files.

This:

```bash
|| true
```

prevents the script from failing due to that command.

Because we used:

```bash
set -e
```

a failed command would normally stop the script.

---

# 29. Commit Your Work

Create notes:

```bash
nano 03-linux-bash-networking/linux-filesystem.md
```

Paste:

```markdown
# Linux Filesystem Deep Dive

## Root Filesystem

Linux has one filesystem tree starting from `/`.

## Important Directories

| Directory | Purpose |
|---|---|
| `/etc` | System configuration |
| `/var` | Variable data such as logs and app state |
| `/var/log` | Logs |
| `/var/lib` | Application state |
| `/home` | Normal user home directories |
| `/root` | Root user home |
| `/tmp` | Temporary files |
| `/proc` | Virtual process/kernel info |
| `/sys` | Kernel/device info |
| `/dev` | Device files |
| `/run` | Runtime state |
| `/usr` | User-space programs and libraries |
| `/usr/local/bin` | Locally installed binaries |
| `/opt` | Optional third-party software |
| `/mnt` | Manual mount points |
| `/media` | Removable media |
| `/boot` | Boot files |

## Production Rules

- Check `pwd` before destructive commands.
- Take backups before editing `/etc`.
- Logs usually live in `/var/log`.
- Application state often lives in `/var/lib`.
- Do not casually delete files from `/var/lib`.
- Use `df -h` for disk space.
- Use `df -i` for inode usage.
- Use `du` to find large directories.
- Use `/tmp` only for temporary files.
- Use `mktemp` in scripts.
- Print before delete when using `find`.
```

Commit:

```bash
git status
git diff

git add 03-linux-bash-networking/linux-filesystem.md \
        03-linux-bash-networking/scripts/filesystem-inspector.sh

git diff --staged

git commit -m "docs: add Linux filesystem deep dive"
git push -u origin docs/linux-mental-model
```

If you are still on the previous branch, this is okay for now. Better professional workflow would create a new branch:

```bash
git switch main
git pull origin main
git switch -c docs/linux-filesystem
```

Then commit there.

---

# 30. Real Production Scenario — Disk Full

Incident:

```text
Application returns 500 errors.
Logs show: No space left on device.
```

Debug:

```bash
df -h
```

Find full filesystem.

Then:

```bash
sudo du -h --max-depth=1 / 2>/dev/null | sort -hr | head
```

If `/var` is large:

```bash
sudo du -h --max-depth=1 /var 2>/dev/null | sort -hr | head
```

If logs are large:

```bash
sudo du -h --max-depth=1 /var/log 2>/dev/null | sort -hr | head
```

Check huge files:

```bash
sudo find /var/log -type f -size +100M -exec ls -lh {} \;
```

Short-term safe response:

```text
Compress or rotate logs if appropriate.
Clean known safe cache.
Remove old Docker images if verified.
Expand disk if needed.
```

Dangerous response:

```bash
sudo rm -rf /var/lib/docker
```

This may destroy containers/images/volumes.

Better Docker cleanup:

```bash
docker system df
docker image prune
docker container prune
```

Even then, understand what will be removed.

---

# 31. Real Production Scenario — Config Broken

Incident:

```text
Nginx not starting after config change.
```

Debug:

```bash
sudo nginx -t
```

If failed, check:

```bash
sudo journalctl -u nginx -xe
```

Restore backup:

```bash
sudo cp /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
sudo nginx -t
sudo systemctl reload nginx
```

Lesson:

```text
Always backup config before editing.
Always validate before reload/restart.
```

---

# 32. Interview Answers

Question:

```text
What is the purpose of /etc in Linux?
```

Strong answer:

```text
/etc contains system-wide configuration files. Examples include SSH config, hosts file, hostname, user/group files, Nginx config, and systemd service files. In production, I take a backup before editing important files in /etc and validate the configuration before reloading services.
```

Question:

```text
What is the difference between /proc and /var/log?
```

Strong answer:

```text
/proc is a virtual filesystem that exposes live kernel and process information. It is not normal persistent disk data. /var/log contains log files written by the system and applications. I use /proc to inspect live system/process state and /var/log to troubleshoot historical or current service logs.
```

Question:

```text
How do you troubleshoot disk full issue?
```

Strong answer:

```text
First I check filesystem usage with df -h and inode usage with df -i. Then I identify large directories using du, usually starting from / and drilling into /var, /var/log, /var/lib, or application directories. I check whether logs, Docker data, backups, database files, or temporary files are consuming space. I avoid deleting unknown data and prefer safe cleanup, log rotation, pruning verified unused Docker objects, or expanding disk if required.
```

---

# Today’s Core Rules

```text
Linux has one filesystem tree starting at /.
Configuration usually lives in /etc.
Logs usually live in /var/log.
Application state often lives in /var/lib.
Temporary files belong in /tmp, not important data.
Process and kernel info live in /proc.
Device files live in /dev.
Runtime state lives in /run.
Use df -h for space and df -i for inodes.
Use du to find what is consuming space.
Backup config before editing.
Validate config before restarting services.
Print before delete.
```

Next lesson:

# Lesson 3.3 — File Operations Masterclass: ls, cp, mv, rm, mkdir, touch, find, stat, tar, gzip, rsync, safe deletion patterns

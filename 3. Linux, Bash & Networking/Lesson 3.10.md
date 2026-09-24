# Lesson 3.10 — Disk and Storage Masterclass

Now we learn Linux storage properly.

This topic is extremely important because many real production outages happen because of storage problems:

```text
Disk full
No space left on device
No inodes left
Application cannot write logs
Database cannot write data
Docker filled /var/lib/docker
Jenkins workspace filled disk
EBS volume attached but not mounted
Wrong fstab entry broke boot
Deleted log file but space not freed
Filesystem mounted read-only
Permission issue on mounted volume
```

A beginner sees:

```text
No space left on device
```

and starts deleting random files.

A DevOps engineer investigates:

```text
Which filesystem is full?
Is it disk space or inode exhaustion?
Which directory is consuming space?
Is a deleted file still open?
Is Docker using the space?
Is log rotation broken?
Can I safely clean, rotate, archive, or expand the disk?
```

---

# 1. Linux Storage Mental Model

Linux storage has layers.

```text
Physical disk / cloud disk
  ↓
Partition
  ↓
Filesystem
  ↓
Mount point
  ↓
Directories and files
```

Example on a cloud server:

```text
AWS EBS volume
  ↓
/dev/nvme1n1
  ↓
partition /dev/nvme1n1p1
  ↓
ext4 filesystem
  ↓
mounted at /mnt/data
  ↓
application writes files
```

Important idea:

```text
A disk is not useful to applications until it is formatted with a filesystem and mounted somewhere.
```

---

# 2. Key Storage Commands

You must become comfortable with these:

```bash
df -h
df -i
du -sh
du -h --max-depth=1
lsblk
blkid
mount
findmnt
sudo fdisk -l
sudo parted -l
sudo lsof +L1
stat
file
```

What they answer:

| Command            | Answers                           |
| ------------------ | --------------------------------- |
| `df -h`            | Which filesystems are full?       |
| `df -i`            | Are inodes full?                  |
| `du -sh`           | How large is this directory/file? |
| `du --max-depth=1` | Which subdirectory is large?      |
| `lsblk`            | What disks/partitions exist?      |
| `blkid`            | What filesystem UUID/type exists? |
| `mount`            | What is mounted right now?        |
| `findmnt`          | Clean mount tree view             |
| `lsof +L1`         | Deleted files still using disk    |
| `fdisk -l`         | Disk partition details            |
| `stat`             | File metadata                     |

---

# 3. `df -h` — Filesystem Usage

Run:

```bash
df -h
```

Example output:

```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        50G   42G  5.5G  89% /
tmpfs           2.0G     0  2.0G   0% /dev/shm
/dev/sdb1       100G   10G   90G  10% /mnt/data
```

Meaning:

```text
Filesystem  storage device or virtual filesystem
Size        total size
Used        used space
Avail       available space
Use%        percentage used
Mounted on  where it appears in Linux tree
```

Important:

```text
df shows filesystem-level usage, not directory-level usage.
```

If `/` is 95% full, then something somewhere under `/` is consuming space.

---

# 4. `df -h` vs `du -sh`

This is very important.

## `df -h`

Shows filesystem usage.

```bash
df -h /
```

Example:

```text
/dev/sda1  50G  45G  3G  94% /
```

## `du -sh`

Shows directory/file usage.

```bash
sudo du -sh /var
```

Example:

```text
30G /var
```

Use them together.

```text
df tells which filesystem is full.
du helps find what directory is consuming it.
```

---

# 5. Disk Full Investigation Flow

When disk is full:

```bash
df -h
```

Find full mount.

If `/` is full:

```bash
sudo du -h --max-depth=1 / 2>/dev/null | sort -hr | head
```

If `/var` is huge:

```bash
sudo du -h --max-depth=1 /var 2>/dev/null | sort -hr | head
```

If `/var/log` is huge:

```bash
sudo du -h --max-depth=1 /var/log 2>/dev/null | sort -hr | head
```

If Docker is huge:

```bash
sudo du -sh /var/lib/docker
docker system df
```

If Jenkins is huge:

```bash
sudo du -h --max-depth=1 /var/lib/jenkins 2>/dev/null | sort -hr | head
```

This is the professional drill-down pattern.

```text
Start broad.
Find the mount.
Find the top directory.
Drill down.
Only then clean safely.
```

---

# 6. `du` Masterclass

Directory size:

```bash
du -sh .
```

All items one level deep:

```bash
du -h --max-depth=1 .
```

Sort largest first:

```bash
du -h --max-depth=1 . | sort -hr | head
```

Check `/var`:

```bash
sudo du -h --max-depth=1 /var 2>/dev/null | sort -hr | head
```

Check only apparent size:

```bash
du -sh --apparent-size .
```

Exclude directory:

```bash
du -h --max-depth=1 --exclude=node_modules .
```

Common command:

```bash
sudo du -xhd1 / | sort -hr | head
```

Meaning:

```text
-x   stay on one filesystem
-h   human-readable
-d1  max depth 1
```

Why `-x` matters:

```text
If other disks are mounted under /, du may include them.
-x keeps the search on the same filesystem.
```

Very useful in production.

---

# 7. Inodes — The Hidden Disk Full

Linux filesystems have inodes.

An inode stores file metadata:

```text
Owner
Group
Permissions
Size
Timestamps
Pointers to data blocks
```

Each file uses an inode.

You can have free disk space but no free inodes.

Check disk space:

```bash
df -h
```

Check inodes:

```bash
df -i
```

Example:

```text
Filesystem      Inodes  IUsed   IFree IUse% Mounted on
/dev/sda1      3276800 3276000     800  100% /
```

Problem:

```text
No space left on device
```

But `df -h` shows free space.

Then `df -i` shows 100%.

That means too many files.

Common causes:

```text
Millions of cache files
Session files
Small temporary files
Node modules
Build artifacts
Small log fragments
Mail queue files
Application bug creating files
```

---

# 8. Find Inode Consumers

Count files under top-level directories:

```bash
sudo find / -xdev -type f 2>/dev/null | cut -d/ -f2 | sort | uniq -c | sort -nr | head
```

For `/var`:

```bash
sudo find /var -xdev -type f 2>/dev/null | cut -d/ -f3 | sort | uniq -c | sort -nr | head
```

Count files in current tree:

```bash
find . -type f | wc -l
```

Find directories with many files:

```bash
find . -xdev -type f | sed 's#/[^/]*$##' | sort | uniq -c | sort -nr | head
```

Production rule:

```text
Disk full can mean bytes full or inodes full.
Always check both df -h and df -i.
```

---

# 9. `lsblk` — Block Devices

Run:

```bash
lsblk
```

Example:

```text
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda       8:0    0   50G  0 disk
└─sda1    8:1    0   50G  0 part /
sdb       8:16   0  100G  0 disk
└─sdb1    8:17   0  100G  0 part /mnt/data
```

Meaning:

```text
sda      disk
sda1     partition
sdb      another disk
sdb1     partition
/        root mount
/mnt/data data disk mount
```

Better output:

```bash
lsblk -f
```

Shows filesystem type and UUID.

Example:

```text
NAME   FSTYPE LABEL UUID                                 MOUNTPOINTS
sda1   ext4         a1b2-c3d4                            /
sdb1   ext4         e5f6-g7h8                            /mnt/data
```

---

# 10. Device Names in Cloud

On local Linux, disks may look like:

```text
/dev/sda
/dev/sdb
```

On AWS Nitro instances, EBS volumes often appear as:

```text
/dev/nvme0n1
/dev/nvme1n1
```

Partitions:

```text
/dev/nvme0n1p1
/dev/nvme1n1p1
```

Important:

```text
Cloud device names can differ from what you specified while attaching.
Always verify with lsblk.
```

---

# 11. `blkid` — Filesystem UUID

Run:

```bash
sudo blkid
```

Example:

```text
/dev/sda1: UUID="abc-123" TYPE="ext4"
/dev/sdb1: UUID="def-456" TYPE="ext4"
```

UUID is useful in `/etc/fstab`.

Why?

```text
Device names can change.
UUID is more stable.
```

---

# 12. `mount` and `findmnt`

Show mounted filesystems:

```bash
mount
```

Cleaner view:

```bash
findmnt
```

Show one mount:

```bash
findmnt /
findmnt /mnt/data
```

Show source and filesystem:

```bash
findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS
```

Example output:

```text
TARGET    SOURCE      FSTYPE OPTIONS
/         /dev/sda1   ext4   rw,relatime
/mnt/data /dev/sdb1   ext4   rw,relatime
```

Important mount options:

```text
rw       read-write
ro       read-only
noexec   cannot execute binaries/scripts
nosuid   ignore setuid/setgid bits
nodev    no device files
relatime access time optimization
```

If filesystem is mounted read-only:

```text
Application may fail to write even if permissions look correct.
```

Check:

```bash
findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS /path
```

---

# 13. Manual Mounting

Create mount point:

```bash
sudo mkdir -p /mnt/data
```

Mount device:

```bash
sudo mount /dev/sdb1 /mnt/data
```

Check:

```bash
df -h /mnt/data
findmnt /mnt/data
```

Unmount:

```bash
sudo umount /mnt/data
```

If busy:

```text
target is busy
```

Find users:

```bash
sudo lsof +f -- /mnt/data
```

or:

```bash
sudo fuser -vm /mnt/data
```

Production warning:

```text
Do not unmount a filesystem until you know what processes are using it.
```

---

# 14. Formatting a Disk

A new disk may not have a filesystem.

Check:

```bash
lsblk -f
```

If blank, create filesystem.

For ext4:

```bash
sudo mkfs.ext4 /dev/sdb1
```

For XFS:

```bash
sudo mkfs.xfs /dev/sdb1
```

Critical warning:

```text
mkfs destroys existing data on that partition/device.
```

Before running `mkfs`, triple-check:

```bash
lsblk
sudo blkid
mount
```

Do not format the wrong disk.

---

# 15. Partitioning Basic Idea

A disk can have partitions.

Example:

```text
/dev/sdb       disk
/dev/sdb1      partition 1
```

Partition tools:

```bash
sudo fdisk /dev/sdb
sudo parted /dev/sdb
```

For learning, do not randomly partition your real disk.

In cloud, often a volume may already be partitioned or used directly.

You must inspect with:

```bash
lsblk
sudo fdisk -l
```

---

# 16. `/etc/fstab` — Persistent Mounts

Manual mount disappears after reboot.

Persistent mounts are configured in:

```text
/etc/fstab
```

View:

```bash
cat /etc/fstab
```

Example entry:

```text
UUID=def-456 /mnt/data ext4 defaults,nofail 0 2
```

Fields:

```text
device/UUID
mount point
filesystem type
options
dump
fsck order
```

Important options:

```text
defaults   common default mount options
nofail     boot continues if disk unavailable
x-systemd.device-timeout=10s  wait limit
```

Example safer cloud mount:

```text
UUID=def-456 /mnt/data ext4 defaults,nofail,x-systemd.device-timeout=10s 0 2
```

Production warning:

```text
A bad fstab entry can break boot or delay boot.
```

Always test:

```bash
sudo mount -a
```

If no error, fstab is syntactically okay.

Before editing:

```bash
sudo cp -a /etc/fstab "/etc/fstab.$(date +%Y%m%d-%H%M%S).bak"
```

---

# 17. Safe fstab Workflow

Professional workflow:

```bash
lsblk -f
sudo blkid
sudo mkdir -p /mnt/data
sudo cp -a /etc/fstab "/etc/fstab.$(date +%Y%m%d-%H%M%S).bak"
sudo nano /etc/fstab
sudo mount -a
findmnt /mnt/data
df -h /mnt/data
```

If `mount -a` fails:

```bash
sudo cp -a /etc/fstab.<backup> /etc/fstab
sudo mount -a
```

Never reboot before testing `mount -a`.

---

# 18. Deleted Files Still Taking Space

This is a classic production trap.

Scenario:

```text
/var/log/app.log is 20GB.
Someone runs rm /var/log/app.log.
df -h still shows disk full.
```

Why?

```text
A process still has the deleted file open.
The directory entry is gone, but disk blocks remain until process closes file descriptor.
```

Find:

```bash
sudo lsof +L1
```

or:

```bash
sudo lsof | grep deleted
```

Example:

```text
node 1234 appuser 5w REG 8,1 21474836480 /var/log/app.log (deleted)
```

Fix:

```bash
sudo systemctl restart app
```

or signal log reopen if supported.

Professional response:

```text
Find the process holding the file.
Restart/reload that process safely.
Configure log rotation.
```

---

# 19. Safe Log Cleanup

Do not blindly:

```bash
sudo rm -rf /var/log/*
```

Better:

```bash
sudo du -h --max-depth=1 /var/log | sort -hr | head
```

Find large logs:

```bash
sudo find /var/log -type f -size +100M -exec ls -lh {} \;
```

Compress old logs:

```bash
sudo gzip /var/log/myapp/old.log
```

Truncate a log if absolutely needed and safe:

```bash
sudo truncate -s 0 /var/log/myapp/app.log
```

Why truncate can be better than rm?

```text
The process keeps writing to same file path/file descriptor.
Space is freed without deleting the file entry.
```

But do this only when you are sure logs are not needed for investigation.

Better long-term:

```text
Configure logrotate.
Ship logs to centralized system.
Set retention.
```

---

# 20. Docker Disk Usage

Docker commonly fills disk under:

```text
/var/lib/docker
```

Check:

```bash
sudo du -sh /var/lib/docker
docker system df
```

Docker cleanup commands:

```bash
docker container prune
docker image prune
docker volume prune
docker builder prune
docker system prune
```

Danger:

```bash
docker system prune -a --volumes
```

This can remove:

```text
Unused images
Stopped containers
Unused networks
Build cache
Volumes if --volumes is used
```

Volumes may contain database data.

Professional workflow:

```bash
docker system df
docker ps -a
docker images
docker volume ls
docker system prune --dry-run
```

Then clean intentionally.

If production database data lives in Docker volumes, be extremely careful.

---

# 21. Jenkins Disk Usage

Jenkins commonly uses:

```text
/var/lib/jenkins
```

Check:

```bash
sudo du -h --max-depth=1 /var/lib/jenkins 2>/dev/null | sort -hr | head
```

Common disk consumers:

```text
workspaces
build artifacts
old builds
plugins
logs
caches
```

Better cleanup:

```text
Configure build discard policy
Clean workspace after build
Limit artifact retention
Move heavy artifacts to S3/Nexus/Artifactory
```

Bad:

```bash
sudo rm -rf /var/lib/jenkins/jobs
```

This deletes jobs.

---

# 22. Package Cache Cleanup

APT cache:

```bash
sudo du -sh /var/cache/apt
```

Clean apt cache:

```bash
sudo apt clean
```

Remove unused packages:

```bash
sudo apt autoremove -y
```

Check logs:

```bash
du -sh /var/log/apt
```

Safe and common, but do not rely on package cache cleanup for recurring disk-full issues.

Fix root cause.

---

# 23. Temporary Files

Temporary locations:

```text
/tmp
/var/tmp
```

Check:

```bash
sudo du -h --max-depth=1 /tmp 2>/dev/null | sort -hr | head
sudo du -h --max-depth=1 /var/tmp 2>/dev/null | sort -hr | head
```

Find old temp files:

```bash
sudo find /tmp -type f -mtime +7 -print
```

Do not blindly delete active sockets or files.

Some apps use `/tmp`.

Safer cleanup often handled by systemd-tmpfiles.

Check:

```bash
systemd-tmpfiles --help
```

---

# 24. Filesystem Read-Only Issue

Sometimes a filesystem becomes read-only due to errors.

Symptoms:

```text
Read-only file system
Cannot write
Database errors
Logs cannot write
```

Check mount options:

```bash
findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS /
```

Look for `ro`.

Check kernel logs:

```bash
journalctl -k --since "1 hour ago" | grep -Ei "error|readonly|read-only|ext4|xfs|i/o"
```

If disk/filesystem errors exist:

```text
Do not just remount rw blindly.
Investigate storage health.
Snapshot/backup if possible.
Repair carefully.
```

Emergency remount may be:

```bash
sudo mount -o remount,rw /
```

But only if you understand the risk and root cause.

---

# 25. Disk Performance Basics

Storage issues are not only space.

They can be performance:

```text
High disk I/O
Slow reads/writes
High iowait
Database latency
Log writes blocking
```

Basic tools:

```bash
iostat
iotop
vmstat
```

Install:

```bash
sudo apt install -y sysstat iotop
```

Use:

```bash
iostat -xz 1
```

```bash
sudo iotop
```

```bash
vmstat 1
```

We will go deeper in CPU/memory/performance lessons, but remember disk can be slow even when not full.

---

# 26. Storage Safety Checklist

Before cleaning or modifying storage:

```text
Which filesystem is affected?
Is it space or inode issue?
What directory is consuming space?
Is this data important?
Is there a backup?
Is a process still using deleted files?
Is this Docker/Jenkins/database data?
Can logs be rotated instead of deleted?
Can disk be expanded?
Will cleanup break running apps?
```

Commands:

```bash
df -h
df -i
findmnt
sudo du -xhd1 / | sort -hr | head
sudo lsof +L1
```

---

# 27. Lab — Disk Investigation Practice

Create lab:

```bash
cd ~/devops-masterclass
mkdir -p 03-linux-bash-networking/labs/storage
cd 03-linux-bash-networking/labs/storage
```

Create files:

```bash
mkdir logs cache data
dd if=/dev/zero of=logs/app.log bs=1M count=20
dd if=/dev/zero of=cache/cache.bin bs=1M count=10
touch data/file-{1..1000}.txt
```

Check:

```bash
du -h --max-depth=1 .
df -h .
df -i .
find . -type f | wc -l
```

Find large files:

```bash
find . -type f -size +5M -exec ls -lh {} \;
```

Compress log:

```bash
gzip logs/app.log
du -h --max-depth=1 .
```

Cleanup:

```bash
rm -rf logs cache data
```

Lesson:

```text
du shows which directory consumes space.
find can identify large files.
Many tiny files affect inode count.
Compression reduces log size.
```

---

# 28. Lab — Deleted Open File Demo

Create a file and keep it open using Python:

```bash
cd ~/devops-masterclass/03-linux-bash-networking/labs/storage
python3 -c 'import time; f=open("held.log","w"); f.write("hello\n"); f.flush(); time.sleep(600)' &
HELD_PID=$!
```

Check:

```bash
ls -lh held.log
sudo lsof -p "$HELD_PID" | grep held.log
```

Delete file:

```bash
rm held.log
```

Check:

```bash
ls -lh held.log || echo "file deleted from directory"
sudo lsof -p "$HELD_PID" | grep deleted
sudo lsof +L1 | grep "$HELD_PID"
```

Stop process:

```bash
kill "$HELD_PID"
```

Now space is released.

This demonstrates why deleting a file does not always immediately free space.

---

# 29. Script — Disk Triage

Create:

```bash
cd ~/devops-masterclass
nano 03-linux-bash-networking/scripts/disk-triage.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_PATH="${1:-/}"
DEPTH="${2:-1}"

if [ ! -e "$TARGET_PATH" ]; then
  echo "ERROR: path does not exist: $TARGET_PATH" >&2
  exit 1
fi

if ! [[ "$DEPTH" =~ ^[0-9]+$ ]]; then
  echo "ERROR: depth must be numeric" >&2
  exit 1
fi

echo "===== Disk Triage ====="
echo "Target path: $TARGET_PATH"
echo "Depth: $DEPTH"
echo "Generated at: $(date -Is)"
echo

echo "===== Filesystem Usage ====="
df -h "$TARGET_PATH"
echo

echo "===== Inode Usage ====="
df -i "$TARGET_PATH"
echo

echo "===== Mount Info ====="
findmnt -T "$TARGET_PATH" -o TARGET,SOURCE,FSTYPE,OPTIONS || true
echo

if [ -d "$TARGET_PATH" ]; then
  echo "===== Top Directory Sizes ====="
  sudo du -xhd "$DEPTH" "$TARGET_PATH" 2>/dev/null | sort -hr | head -20 || true
  echo

  echo "===== Large Files > 100M ====="
  sudo find "$TARGET_PATH" -xdev -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -50 || true
  echo

  echo "===== File Count Summary ====="
  sudo find "$TARGET_PATH" -xdev -type f 2>/dev/null | wc -l || true
else
  echo "===== File Details ====="
  ls -lh "$TARGET_PATH"
fi

echo
echo "===== Deleted Open Files ====="
if command -v lsof >/dev/null 2>&1; then
  sudo lsof +L1 2>/dev/null | head -30 || true
else
  echo "lsof not installed"
fi

echo
echo "Done."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/disk-triage.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/disk-triage.sh .
```

Run on `/var`:

```bash
./03-linux-bash-networking/scripts/disk-triage.sh /var 1
```

This becomes a real incident helper script.

---

# 30. Script — Safe Old File Finder

Create:

```bash
nano 03-linux-bash-networking/scripts/find-old-large-files.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-}"
DAYS_OLD="${2:-7}"
SIZE="${3:-100M}"

if [ -z "$TARGET_DIR" ]; then
  echo "Usage: $0 <target-dir> [days-old] [size]" >&2
  echo "Example: $0 /var/log 14 100M" >&2
  exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
  echo "ERROR: target is not a directory: $TARGET_DIR" >&2
  exit 1
fi

if ! [[ "$DAYS_OLD" =~ ^[0-9]+$ ]]; then
  echo "ERROR: days-old must be numeric" >&2
  exit 1
fi

echo "===== Old Large File Finder ====="
echo "Target: $TARGET_DIR"
echo "Older than: $DAYS_OLD days"
echo "Larger than: $SIZE"
echo "Generated at: $(date -Is)"
echo

sudo find "$TARGET_DIR" -xdev -type f -mtime +"$DAYS_OLD" -size +"$SIZE" -exec ls -lh {} \; 2>/dev/null || true

echo
echo "Dry-run only. No files deleted."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/find-old-large-files.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/find-old-large-files.sh /var/log 7 50M
```

This is safe because it only prints.

---

# 31. Script — fstab Backup and Validator

Create:

```bash
nano 03-linux-bash-networking/scripts/fstab-backup-validate.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

BACKUP_FILE="/etc/fstab.$(date +%Y%m%d-%H%M%S).bak"

echo "===== fstab Backup and Validator ====="
echo "Backup file: $BACKUP_FILE"
echo

echo "Creating backup..."
sudo cp -a /etc/fstab "$BACKUP_FILE"

echo "Current /etc/fstab:"
cat /etc/fstab
echo

echo "Testing mount -a..."
if sudo mount -a; then
  echo "mount -a completed successfully."
else
  echo "ERROR: mount -a failed. Backup exists at $BACKUP_FILE" >&2
  exit 1
fi

echo
echo "Current mounts:"
findmnt

echo
echo "Done."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/fstab-backup-validate.sh
```

Run only when you intend to validate fstab:

```bash
./03-linux-bash-networking/scripts/fstab-backup-validate.sh
```

Important:

```text
This script does not edit fstab.
It backs it up and validates current entries.
```

---

# 32. Create Notes

Create:

```bash
nano 03-linux-bash-networking/disk-storage.md
```

Paste:

````markdown
# Disk and Storage Masterclass

## Storage Mental Model

```text
Disk / Cloud Volume
  ↓
Partition
  ↓
Filesystem
  ↓
Mount point
  ↓
Directories and files
````

## Core Commands

```bash
df -h
df -i
du -sh .
du -h --max-depth=1 . | sort -hr | head
sudo du -xhd1 / | sort -hr | head
lsblk
lsblk -f
sudo blkid
mount
findmnt
findmnt -T /path
sudo fdisk -l
sudo lsof +L1
```

## Disk Full Investigation

```bash
df -h
df -i
sudo du -xhd1 / | sort -hr | head
sudo du -xhd1 /var | sort -hr | head
sudo find /var/log -type f -size +100M -exec ls -lh {} \;
sudo lsof +L1
```

## Important Concepts

* `df -h` shows filesystem space usage.
* `du` shows directory/file usage.
* `df -i` shows inode usage.
* Disk can be full because of bytes or inodes.
* Deleted files can still consume disk if a process keeps them open.
* `/etc/fstab` controls persistent mounts.
* `mount -a` validates fstab before reboot.
* UUIDs are safer than device names in fstab.
* Docker often consumes `/var/lib/docker`.
* Jenkins often consumes `/var/lib/jenkins`.

## Safe Cleanup Rules

* Do not delete random files.
* Find what is consuming space first.
* Check whether data is important.
* Check for deleted open files with `lsof +L1`.
* Prefer logrotate over manual log deletion.
* Be careful with Docker volumes.
* Backup `/etc/fstab` before editing.
* Test `mount -a` before rebooting.

````

Commit:

```bash
git status
git diff

git add 03-linux-bash-networking/disk-storage.md \
        03-linux-bash-networking/scripts/disk-triage.sh \
        03-linux-bash-networking/scripts/find-old-large-files.sh \
        03-linux-bash-networking/scripts/fstab-backup-validate.sh \
        03-linux-bash-networking/labs/storage

git diff --staged

git commit -m "docs: add disk and storage masterclass"
git push
````

---

# 33. Real Production Scenario — Root Disk 95% Full

Alert:

```text
Root filesystem / is 95% full.
```

Triage:

```bash
df -h /
df -i /
sudo du -xhd1 / | sort -hr | head
```

Suppose `/var` is large:

```bash
sudo du -xhd1 /var | sort -hr | head
```

Suppose `/var/lib/docker` is large:

```bash
docker system df
docker ps -a
docker images
docker volume ls
```

Safe cleanup options:

```bash
docker image prune
docker container prune
docker builder prune
```

Be careful with:

```bash
docker volume prune
```

because volumes may contain persistent data.

Long-term fixes:

```text
Docker log rotation
Artifact cleanup policy
Move data to separate disk
Increase disk size
Monitoring alert before 90%
```

---

# 34. Real Production Scenario — No Space Left but df Shows Space

Error:

```text
No space left on device
```

But:

```bash
df -h
```

shows free space.

Check:

```bash
df -i
```

If inode usage is 100%, find many-file directories:

```bash
sudo find / -xdev -type f 2>/dev/null | cut -d/ -f2 | sort | uniq -c | sort -nr | head
```

If `/tmp` has millions of files:

```bash
sudo find /tmp -xdev -type f | wc -l
```

Fix depends on source:

```text
Clean old cache files
Fix application bug creating files
Configure temp cleanup
Move workload to better storage
```

---

# 35. Real Production Scenario — New EBS Volume Attached but Not Visible to App

Steps:

```bash
lsblk
lsblk -f
sudo blkid
```

If new disk has no filesystem, carefully create one:

```bash
sudo mkfs.ext4 /dev/nvme1n1
```

Only if you are sure it is empty and correct.

Mount:

```bash
sudo mkdir -p /mnt/data
sudo mount /dev/nvme1n1 /mnt/data
df -h /mnt/data
```

Make persistent:

```bash
sudo blkid
sudo cp -a /etc/fstab "/etc/fstab.$(date +%Y%m%d-%H%M%S).bak"
sudo nano /etc/fstab
sudo mount -a
findmnt /mnt/data
```

Set ownership:

```bash
sudo chown -R appuser:appuser /mnt/data
```

Application can now use `/mnt/data`.

---

# 36. Real Production Scenario — fstab Broke Boot

Cause:

```text
Bad /etc/fstab entry without nofail.
System waits or fails during boot.
```

Prevention:

```text
Use UUID
Use nofail for non-critical disks
Use x-systemd.device-timeout
Always test mount -a
Keep backup
Have console access
```

Safer entry:

```text
UUID=def-456 /mnt/data ext4 defaults,nofail,x-systemd.device-timeout=10s 0 2
```

---

# 37. Interview Answers

Question:

```text
How do you troubleshoot disk full in Linux?
```

Strong answer:

```text
I first run df -h to identify which filesystem is full and df -i to check inode exhaustion. Then I drill down with du, usually sudo du -xhd1 / and then into large directories like /var, /var/log, /var/lib/docker, or /var/lib/jenkins. I check for deleted open files with sudo lsof +L1 because deleted files may still consume disk. I avoid deleting unknown data and prefer safe cleanup, log rotation, Docker pruning with caution, artifact retention policies, or disk expansion.
```

Question:

```text
What is the difference between df and du?
```

Strong answer:

```text
df reports usage at the filesystem level, showing total, used, and available space for mounted filesystems. du reports disk usage for files and directories. I use df to find which filesystem is full, then du to find which directory or file is consuming the space.
```

Question:

```text
What are inodes and how can they cause disk-full errors?
```

Strong answer:

```text
An inode stores metadata for a file, such as owner, permissions, timestamps, and pointers to data blocks. Each file consumes an inode. A filesystem can run out of inodes even if it still has free disk space, usually when there are millions of small files. I check this with df -i and then find directories with large file counts.
```

Question:

```text
Why can disk space remain full after deleting a large log file?
```

Strong answer:

```text
If a process still has the deleted file open, the directory entry is removed but the disk blocks remain allocated until the process closes the file descriptor. I check this with sudo lsof +L1 or lsof | grep deleted. The fix is usually to restart or reload the process holding the file, then configure proper log rotation.
```

Question:

```text
How do you safely add a persistent disk mount?
```

Strong answer:

```text
I identify the disk with lsblk and blkid, create a filesystem only if the disk is confirmed empty, create a mount point, mount it manually, and verify with df and findmnt. For persistence, I use the filesystem UUID in /etc/fstab, backup fstab first, add options like nofail for non-critical disks, and run mount -a to test before rebooting.
```

---

# Today’s Core Rules

```text
df shows filesystem usage.
du shows directory/file usage.
Always check df -h and df -i.
Use du to drill down from broad to specific.
Use lsblk and blkid to inspect disks.
Use findmnt to inspect mounts.
Use UUIDs in fstab.
Backup fstab before editing.
Run mount -a before reboot.
Deleted files can still consume disk if open.
Use lsof +L1 to find deleted open files.
Be careful with Docker volumes and database data.
Prefer log rotation over manual deletion.
Do not randomly delete production files.
```

Next lesson:

# Lesson 3.11 — CPU, Memory, Load Average, OOM Killer, and Performance Troubleshooting

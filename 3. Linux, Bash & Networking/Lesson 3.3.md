# Lesson 3.3 — File Operations Masterclass

Now we learn Linux file operations properly.

This lesson is not only about commands like `cp`, `mv`, and `rm`.

It is about using file operations safely in real systems.

In production, one wrong file command can:

```text
Delete application data
Break permissions
Remove logs needed for investigation
Overwrite config files
Destroy deployment artifacts
Fill disk
Break symlinks
Delete the wrong environment
```

So we will learn commands with a DevOps mindset.

---

# 1. File Operation Mental Model

Linux file operations usually answer:

```text
Where am I?
What exists?
What type is it?
Who owns it?
What permissions does it have?
How large is it?
When was it changed?
Can I copy it safely?
Can I move it safely?
Can I delete it safely?
Can I archive it safely?
Can I sync it safely?
```

Before modifying files, always check:

```bash
pwd
ls -la
```

Before deleting files, check:

```bash
find ... -print
```

Before overwriting files, backup:

```bash
cp file.conf file.conf.bak
```

Production rule:

```text
Observe first. Modify second. Delete last.
```

---

# 2. `pwd` — Print Working Directory

`pwd` shows where you are.

```bash
pwd
```

Example:

```text
/home/vivek/devops-masterclass
```

This is simple but critical.

Dangerous example:

```bash
rm -rf *
```

This command means:

```text
Delete everything in the current directory.
```

So before destructive commands:

```bash
pwd
ls -la
```

Do not trust your memory.

Trust the terminal output.

---

# 3. `ls` — List Files

Basic:

```bash
ls
```

Long format:

```bash
ls -l
```

Show hidden files:

```bash
ls -la
```

Human-readable sizes:

```bash
ls -lh
```

Sort by modified time:

```bash
ls -lt
```

Reverse order:

```bash
ls -ltr
```

Show inode numbers:

```bash
ls -li
```

Useful combined:

```bash
ls -lah
```

Output example:

```text
-rw-r--r-- 1 vivek vivek  120 Jun 28 10:00 README.md
drwxr-xr-x 3 vivek vivek 4096 Jun 28 10:01 scripts
lrwxrwxrwx 1 vivek vivek   12 Jun 28 10:02 current -> releases/v1
```

Understand the first character:

```text
-  regular file
d  directory
l  symbolic link
c  character device
b  block device
s  socket
p  named pipe
```

Example:

```text
-rw-r--r--  file
drwxr-xr-x  directory
lrwxrwxrwx  symlink
```

---

# 4. `file` — Identify File Type

Use:

```bash
file README.md
```

Examples:

```text
README.md: ASCII text
script.sh: Bourne-Again shell script
app.tar.gz: gzip compressed data
```

Why useful?

Sometimes file extensions lie.

Example:

```bash
file backup.sql.gz
```

It tells whether it is really gzip compressed.

---

# 5. `stat` — Metadata

Use:

```bash
stat README.md
```

Shows:

```text
Size
Blocks
Device
Inode
Links
Permissions
Owner
Group
Access time
Modify time
Change time
Birth time
```

Important times:

```text
mtime = content modified
ctime = metadata changed
atime = file accessed
```

Example:

```bash
chmod 600 README.md
stat README.md
```

Changing permission updates `ctime`.

Editing content updates `mtime`.

Production use:

```text
Did config content change?
Did only permission/owner change?
When was this file last modified?
```

---

# 6. `touch` — Create or Update Timestamp

Create empty file:

```bash
touch app.log
```

Update timestamp:

```bash
touch README.md
```

Create multiple files:

```bash
touch file1.txt file2.txt file3.txt
```

Use case:

```bash
touch /tmp/deploy-started
```

But for structured logs, prefer real log messages.

---

# 7. `mkdir` — Create Directories

Create one directory:

```bash
mkdir logs
```

Create nested directories:

```bash
mkdir -p app/logs/nginx
```

`-p` means:

```text
Create parent directories if needed.
Do not fail if directory already exists.
```

Script example:

```bash
mkdir -p "$BACKUP_DIR"
```

This is common in automation scripts.

---

# 8. `cp` — Copy Files and Directories

Copy file:

```bash
cp source.txt destination.txt
```

Copy into directory:

```bash
cp README.md /tmp/
```

Copy directory recursively:

```bash
cp -r scripts scripts-backup
```

Preserve permissions, ownership, timestamps:

```bash
cp -a app app-backup
```

`-a` means archive mode.

It preserves:

```text
Permissions
Ownership where possible
Timestamps
Symlinks
Directory structure
```

Backup config before editing:

```bash
sudo cp -a /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
```

Safer backup with timestamp:

```bash
sudo cp -a /etc/nginx/nginx.conf "/etc/nginx/nginx.conf.$(date +%Y%m%d-%H%M%S).bak"
```

Important option:

```bash
cp -i source.txt destination.txt
```

`-i` asks before overwrite.

Force overwrite:

```bash
cp -f source.txt destination.txt
```

Be careful with `-f`.

---

# 9. `mv` — Move or Rename

Rename file:

```bash
mv old.txt new.txt
```

Move file into directory:

```bash
mv app.log logs/
```

Move directory:

```bash
mv old-folder new-folder
```

Interactive:

```bash
mv -i source.txt destination.txt
```

Production use:

```bash
mv app.log app.log.old
```

Important:

```text
mv within same filesystem is usually atomic.
mv across filesystems becomes copy + delete.
```

This matters for deployment.

Atomic symlink switch:

```bash
ln -sfn /opt/myapp/releases/v1.2.1 /opt/myapp/current
```

This is safer than copying files into a live directory.

---

# 10. `rm` — Remove Files

Remove file:

```bash
rm file.txt
```

Remove empty directory:

```bash
rmdir empty-dir
```

Remove directory recursively:

```bash
rm -r folder
```

Force remove:

```bash
rm -f file.txt
```

Dangerous:

```bash
rm -rf folder
```

Very dangerous:

```bash
sudo rm -rf /
sudo rm -rf /*
sudo rm -rf $SOME_VARIABLE/*
```

Especially dangerous if variable is empty:

```bash
TARGET_DIR=""
rm -rf "$TARGET_DIR"/*
```

This becomes:

```bash
rm -rf /*
```

Catastrophic.

---

# 11. Safe Deletion Pattern

Never delete first.

Print first:

```bash
find /tmp -name "*.tmp" -type f -print
```

Then delete only after review:

```bash
find /tmp -name "*.tmp" -type f -delete
```

Safer script pattern:

```bash
TARGET_DIR="${1:-}"

if [ -z "$TARGET_DIR" ]; then
  echo "ERROR: TARGET_DIR is empty" >&2
  exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
  echo "ERROR: Not a directory: $TARGET_DIR" >&2
  exit 1
fi

find "$TARGET_DIR" -type f -name "*.tmp" -print
```

Then add deletion only when confident.

Production rule:

```text
Dry run first. Delete second.
```

---

# 12. `find` — Search Files Like a Pro

Find by name:

```bash
find . -name "*.md"
```

Case-insensitive:

```bash
find . -iname "*.MD"
```

Find files only:

```bash
find . -type f
```

Find directories only:

```bash
find . -type d
```

Find by size:

```bash
find . -type f -size +100M
```

Find modified in last day:

```bash
find . -type f -mtime -1
```

Find modified more than 7 days ago:

```bash
find . -type f -mtime +7
```

Find empty files:

```bash
find . -type f -empty
```

Find executable scripts:

```bash
find . -type f -name "*.sh" -perm /111
```

Find and run command:

```bash
find . -name "*.log" -type f -exec ls -lh {} \;
```

Find large logs:

```bash
sudo find /var/log -type f -size +100M -exec ls -lh {} \;
```

Find recently changed config files:

```bash
sudo find /etc -type f -mtime -1 -exec ls -lh {} \;
```

DevOps incident use:

```text
Something changed recently.
Find files changed in /etc during last day.
```

Command:

```bash
sudo find /etc -type f -mtime -1 -print
```

---

# 13. `locate` — Fast File Search

`locate` searches a database, not live filesystem.

Install if missing:

```bash
sudo apt update
sudo apt install -y plocate
```

Update database:

```bash
sudo updatedb
```

Search:

```bash
locate nginx.conf
```

Difference:

```text
find   = live filesystem search, slower, accurate now
locate = database search, faster, may be outdated
```

Use `find` for production-critical recent changes.

Use `locate` for quick discovery.

---

# 14. `tree` — Visual Directory Structure

Install if missing:

```bash
sudo apt install -y tree
```

Show two levels:

```bash
tree -L 2
```

Ignore directories:

```bash
tree -L 2 -I "node_modules|.git"
```

For documentation, tree is very useful.

Example:

```bash
tree -L 3 ~/devops-masterclass
```

---

# 15. Wildcards and Globs

Common globs:

```text
*       match anything
*.log   all files ending .log
file?   file1, fileA, etc.
[abc]   one of a,b,c
```

Examples:

```bash
ls *.md
rm *.tmp
cp *.log logs/
```

Danger:

```bash
rm -rf *
```

Safer:

```bash
printf '%s\n' *.tmp
```

Then delete if correct:

```bash
rm -- *.tmp
```

Use `--` to stop option parsing.

Example:

```bash
rm -- -weird-file-name
```

Without `--`, Linux may treat `-weird-file-name` as an option.

---

# 16. Quoting Variables

Always quote variables in scripts.

Bad:

```bash
rm -rf $TARGET_DIR
```

Good:

```bash
rm -rf "$TARGET_DIR"
```

Why?

If path has spaces:

```text
/home/vivek/my folder
```

Unquoted variable becomes two arguments:

```text
/home/vivek/my
folder
```

Also dangerous with empty values.

Quote variables by default.

---

# 17. Archive with `tar`

Create tar archive:

```bash
tar -cvf app.tar app/
```

Extract:

```bash
tar -xvf app.tar
```

Create gzip compressed archive:

```bash
tar -czvf app.tar.gz app/
```

Extract gzip archive:

```bash
tar -xzvf app.tar.gz
```

List contents without extracting:

```bash
tar -tzvf app.tar.gz
```

Flags:

```text
-c  create
-x  extract
-t  list
-v  verbose
-f  file
-z  gzip
```

Production use:

```bash
tar -czvf "logs-$(date +%Y%m%d-%H%M%S).tar.gz" /var/log/myapp/
```

Be careful with absolute paths inside archives.

Prefer archiving relative paths:

```bash
cd /var/log
sudo tar -czvf "/tmp/myapp-logs.tar.gz" myapp/
```

---

# 18. Compression with `gzip` and `gunzip`

Compress file:

```bash
gzip app.log
```

Creates:

```text
app.log.gz
```

Decompress:

```bash
gunzip app.log.gz
```

Keep original while compressing:

```bash
gzip -c app.log > app.log.gz
```

View compressed file:

```bash
zcat app.log.gz | head
```

Search compressed file:

```bash
zgrep "ERROR" app.log.gz
```

This is useful for rotated logs.

---

# 19. `rsync` — Powerful File Sync

`rsync` copies/syncs files efficiently.

Basic:

```bash
rsync -av source/ destination/
```

Important trailing slash difference:

```bash
rsync -av source/ destination/
```

Copies contents of `source` into `destination`.

```bash
rsync -av source destination/
```

Copies directory `source` itself into `destination`.

Dry run:

```bash
rsync -av --dry-run source/ destination/
```

Delete extra files in destination:

```bash
rsync -av --delete source/ destination/
```

Be very careful with `--delete`.

Always dry-run first:

```bash
rsync -av --delete --dry-run source/ destination/
```

Remote sync:

```bash
rsync -av app/ user@server:/opt/app/
```

Production deployment example:

```bash
rsync -av --exclude ".git" --exclude "node_modules" ./ user@server:/opt/myapp/releases/v1.2.0/
```

---

# 20. Checksums

Checksums verify file integrity.

SHA256:

```bash
sha256sum file.txt
```

Save checksum:

```bash
sha256sum app.tar.gz > app.tar.gz.sha256
```

Verify:

```bash
sha256sum -c app.tar.gz.sha256
```

Use cases:

```text
Verify downloaded artifact
Verify backup integrity
Verify release artifact
Detect unexpected file changes
```

---

# 21. `diff` — Compare Files

Compare two files:

```bash
diff old.conf new.conf
```

Unified diff:

```bash
diff -u old.conf new.conf
```

Compare directories:

```bash
diff -ru dir1 dir2
```

Production use:

```bash
diff -u nginx.conf.bak nginx.conf
```

Before reload, understand what changed.

---

# 22. `tee` — Write with sudo and View Output

This often fails:

```bash
sudo echo "hello" > /etc/example.conf
```

Because redirection happens in your current shell, not under sudo.

Use:

```bash
echo "hello" | sudo tee /etc/example.conf
```

Append:

```bash
echo "hello" | sudo tee -a /etc/example.conf
```

Discard duplicate output:

```bash
echo "hello" | sudo tee /etc/example.conf > /dev/null
```

This is very common in DevOps scripts.

---

# 23. `xargs` — Build Commands from Input

Example:

```bash
find . -name "*.log" -print | xargs ls -lh
```

Safer with spaces:

```bash
find . -name "*.log" -print0 | xargs -0 ls -lh
```

Delete files safely:

```bash
find . -name "*.tmp" -type f -print0 | xargs -0 rm -f
```

But prefer `find -delete` when possible.

Use `xargs` when passing many files to commands.

---

# 24. File Operation Safety Checklist

Before copy/move/delete/sync/archive:

```text
Am I in the right directory?
Did I quote variables?
Did I check source exists?
Did I check destination?
Could this overwrite data?
Could this delete data?
Did I run dry-run?
Do I need a backup?
Do I need permissions preserved?
Do I need ownership preserved?
Do I need timestamps preserved?
```

Commands to run:

```bash
pwd
ls -la
stat target
df -h
```

---

# 25. Mini Script — Safe Backup Script

Create:

```bash
cd ~/devops-masterclass
mkdir -p 03-linux-bash-networking/scripts
nano 03-linux-bash-networking/scripts/safe-backup.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SOURCE_PATH="${1:-}"
BACKUP_ROOT="${2:-./backups}"

if [ -z "$SOURCE_PATH" ]; then
  echo "Usage: $0 <source-path> [backup-root]" >&2
  exit 1
fi

if [ ! -e "$SOURCE_PATH" ]; then
  echo "ERROR: Source path does not exist: $SOURCE_PATH" >&2
  exit 1
fi

mkdir -p "$BACKUP_ROOT"

SOURCE_BASENAME="$(basename "$SOURCE_PATH")"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="$BACKUP_ROOT/${SOURCE_BASENAME}-${TIMESTAMP}.tar.gz"

echo "===== Safe Backup ====="
echo "Source: $SOURCE_PATH"
echo "Backup root: $BACKUP_ROOT"
echo "Backup file: $BACKUP_FILE"
echo

tar -czf "$BACKUP_FILE" "$SOURCE_PATH"

echo "Backup created:"
ls -lh "$BACKUP_FILE"

echo
echo "SHA256:"
sha256sum "$BACKUP_FILE"

echo
echo "Archive contents preview:"
tar -tzf "$BACKUP_FILE" | head -20

echo
echo "Done."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/safe-backup.sh
```

Test:

```bash
./03-linux-bash-networking/scripts/safe-backup.sh 03-linux-bash-networking
```

Check:

```bash
ls -lh backups
```

---

# 26. Improve the Backup Script

The first version works, but has one issue.

If you run:

```bash
./safe-backup.sh /etc/hosts
```

The tar archive may include path structure like:

```text
etc/hosts
```

For learning, okay.

For production, you often want controlled archive paths.

Improved version:

```bash
#!/usr/bin/env bash
set -euo pipefail

SOURCE_PATH="${1:-}"
BACKUP_ROOT="${2:-./backups}"

if [ -z "$SOURCE_PATH" ]; then
  echo "Usage: $0 <source-path> [backup-root]" >&2
  exit 1
fi

if [ ! -e "$SOURCE_PATH" ]; then
  echo "ERROR: Source path does not exist: $SOURCE_PATH" >&2
  exit 1
fi

mkdir -p "$BACKUP_ROOT"

SOURCE_ABS="$(realpath "$SOURCE_PATH")"
SOURCE_PARENT="$(dirname "$SOURCE_ABS")"
SOURCE_NAME="$(basename "$SOURCE_ABS")"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="$BACKUP_ROOT/${SOURCE_NAME}-${TIMESTAMP}.tar.gz"

echo "===== Safe Backup ====="
echo "Source absolute path: $SOURCE_ABS"
echo "Source parent: $SOURCE_PARENT"
echo "Source name: $SOURCE_NAME"
echo "Backup file: $BACKUP_FILE"
echo

tar -czf "$BACKUP_FILE" -C "$SOURCE_PARENT" "$SOURCE_NAME"

echo "Backup created:"
ls -lh "$BACKUP_FILE"

echo
echo "SHA256:"
sha256sum "$BACKUP_FILE"

echo
echo "Archive contents preview:"
tar -tzf "$BACKUP_FILE" | head -20

echo
echo "Done."
```

Why better?

```text
It archives the source name relative to its parent directory.
The archive structure is cleaner.
```

Example:

```bash
tar -tzf backups/hosts-20260628-120000.tar.gz
```

Shows:

```text
hosts
```

instead of:

```text
etc/hosts
```

---

# 27. Mini Script — Safe Cleanup Dry Run

Create:

```bash
nano 03-linux-bash-networking/scripts/safe-cleanup-dryrun.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-}"
DAYS_OLD="${2:-7}"
PATTERN="${3:-*.log}"

if [ -z "$TARGET_DIR" ]; then
  echo "Usage: $0 <target-dir> [days-old] [pattern]" >&2
  echo "Example: $0 /var/log 7 '*.log'" >&2
  exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
  echo "ERROR: Target is not a directory: $TARGET_DIR" >&2
  exit 1
fi

if ! [[ "$DAYS_OLD" =~ ^[0-9]+$ ]]; then
  echo "ERROR: days-old must be a number" >&2
  exit 1
fi

echo "===== Safe Cleanup Dry Run ====="
echo "Target directory: $TARGET_DIR"
echo "Pattern: $PATTERN"
echo "Older than days: $DAYS_OLD"
echo

echo "Files that would be deleted:"
find "$TARGET_DIR" -type f -name "$PATTERN" -mtime +"$DAYS_OLD" -print

echo
echo "Dry run only. No files deleted."
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/safe-cleanup-dryrun.sh
```

Test:

```bash
./03-linux-bash-networking/scripts/safe-cleanup-dryrun.sh . 1 "*.md"
```

This only prints.

No deletion.

Later we can add `--delete` flag safely.

---

# 28. Why Dry Run Scripts Matter

Bad production cleanup:

```bash
sudo rm -rf /var/log/*.log
```

Better:

```bash
sudo ./safe-cleanup-dryrun.sh /var/log 14 "*.log"
```

Review output.

Then delete manually or add controlled `--delete`.

Professional cleanup scripts should have:

```text
Validation
Dry run
Clear output
Quoted variables
No empty target
No blind rm -rf
Logging
Confirmation or explicit delete flag
```

---

# 29. Lab — Create File Operations Notes

Create:

```bash
nano 03-linux-bash-networking/file-operations.md
```

Paste:

````markdown
# File Operations Masterclass

## Core Commands

- `pwd` — show current directory
- `ls` — list files
- `file` — identify file type
- `stat` — show metadata
- `touch` — create file or update timestamp
- `mkdir -p` — create directories safely
- `cp -a` — copy preserving metadata
- `mv` — move or rename
- `rm` — remove files
- `find` — search files
- `tar` — archive files
- `gzip` — compress files
- `rsync` — sync files
- `sha256sum` — verify integrity
- `diff -u` — compare files
- `tee` — write files with sudo
- `xargs` — build commands from input

## Safety Rules

- Check `pwd` before destructive commands.
- Use `ls -la` before modifying directories.
- Backup config before editing.
- Use `cp -a` when preserving metadata matters.
- Quote variables in scripts.
- Print before delete.
- Dry run before `rsync --delete`.
- Avoid `rm -rf` unless absolutely certain.
- Use `mktemp` for temporary files.
- Use checksums for artifacts and backups.

## Useful Commands

```bash
find . -type f -size +100M
find . -type f -mtime -1
find . -type f -name "*.log" -print
du -h --max-depth=1 . | sort -hr | head
tar -czf backup.tar.gz folder/
tar -tzf backup.tar.gz
sha256sum backup.tar.gz
diff -u old.conf new.conf
rsync -av --dry-run source/ destination/
````

````

Commit everything:

```bash
git status
git diff

git add 03-linux-bash-networking/file-operations.md \
        03-linux-bash-networking/scripts/safe-backup.sh \
        03-linux-bash-networking/scripts/safe-cleanup-dryrun.sh

git diff --staged

git commit -m "docs: add file operations masterclass"
git push
````

---

# 30. Real Production Scenario — Backup Before Config Change

Task:

```text
Change Nginx config safely.
```

Bad:

```bash
sudo nano /etc/nginx/nginx.conf
sudo systemctl restart nginx
```

Better:

```bash
sudo cp -a /etc/nginx/nginx.conf "/etc/nginx/nginx.conf.$(date +%Y%m%d-%H%M%S).bak"

sudo nano /etc/nginx/nginx.conf

sudo nginx -t

sudo systemctl reload nginx
```

If broken:

```bash
sudo cp -a /etc/nginx/nginx.conf.20260628-120000.bak /etc/nginx/nginx.conf
sudo nginx -t
sudo systemctl reload nginx
```

This is professional.

---

# 31. Real Production Scenario — Large Logs

Problem:

```text
Disk is filling up.
```

Find large logs:

```bash
sudo find /var/log -type f -size +100M -exec ls -lh {} \;
```

Archive old app logs:

```bash
cd /var/log
sudo tar -czf "/tmp/app-logs-$(date +%Y%m%d-%H%M%S).tar.gz" myapp/
```

Verify archive:

```bash
tar -tzf /tmp/app-logs-*.tar.gz | head
sha256sum /tmp/app-logs-*.tar.gz
```

Only after verifying and knowing log retention policy, clean safely.

Do not blindly delete logs during an incident. Logs may be needed for root cause analysis.

---

# 32. Real Production Scenario — Atomic Release Directory

Deployment layout:

```text
/opt/myapp/
├── releases/
│   ├── v1.0.0/
│   └── v1.1.0/
└── current -> /opt/myapp/releases/v1.1.0
```

Deploy new release:

```bash
sudo mkdir -p /opt/myapp/releases/v1.2.0
sudo rsync -av app/ /opt/myapp/releases/v1.2.0/
sudo ln -sfn /opt/myapp/releases/v1.2.0 /opt/myapp/current
sudo systemctl restart myapp
```

Rollback:

```bash
sudo ln -sfn /opt/myapp/releases/v1.1.0 /opt/myapp/current
sudo systemctl restart myapp
```

This is simple, powerful, and close to how many deployment systems work.

---

# 33. Interview Answers

Question:

```text
How do you safely delete files in Linux?
```

Strong answer:

```text
I avoid deleting blindly. First I verify the current directory with pwd and inspect the target with ls or find. I use find with -print to preview exactly what will be deleted. Only after reviewing the output do I use -delete or rm. In scripts, I validate that the target variable is not empty, confirm it is a directory, quote all variables, and prefer dry-run mode before actual deletion.
```

Question:

```text
What is the difference between cp -r and cp -a?
```

Strong answer:

```text
cp -r recursively copies directories, but it may not preserve all metadata exactly. cp -a means archive mode and preserves permissions, timestamps, ownership where possible, symlinks, and directory structure. For backups or deployment copies where metadata matters, cp -a is usually safer.
```

Question:

```text
Why is rsync useful in DevOps?
```

Strong answer:

```text
rsync efficiently synchronizes files and copies only changes when possible. It supports preserving metadata, excluding files, remote copy over SSH, dry runs, and deleting extra destination files when required. In DevOps, it is useful for deployments, backups, artifact sync, and moving files between servers. I always dry-run before using rsync --delete.
```

---

# Today’s Core Rules

```text
Observe first, modify second, delete last.
Check pwd before destructive commands.
Use cp -a for backups.
Use timestamped backups for config files.
Use find -print before find -delete.
Quote variables in scripts.
Avoid blind rm -rf.
Use tar/gzip for archives.
Use sha256sum for integrity.
Use rsync --dry-run before --delete.
Use diff before applying config changes.
Use tee when writing privileged files.
```

Next lesson:

# Lesson 3.4 — Text Processing Masterclass: cat, less, head, tail, grep, awk, sed, cut, sort, uniq, wc, jq, log analysis patterns

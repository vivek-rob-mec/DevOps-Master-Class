# Lesson 3.12 — Bash Scripting Foundation

Now we start one of the most important practical DevOps skills:

```text
Bash scripting
```

Bash is used everywhere:

```text
Linux automation
Jenkins shell stages
GitHub Actions run steps
Docker entrypoint scripts
Server health checks
Backup scripts
Deployment scripts
Log analysis scripts
Cron/systemd timer jobs
Terraform/Ansible helper scripts
Kubernetes troubleshooting scripts
```

A beginner writes commands manually.

A DevOps engineer turns repeated commands into safe, reusable automation.

---

# 1. What is Bash?

Bash means:

```text
Bourne Again SHell
```

It is both:

```text
An interactive shell
A scripting language
```

Interactive example:

```bash
ls -la
cd ~/devops-masterclass
git status
```

Script example:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Checking system..."
df -h
free -h
```

Bash is not the best language for every task, but it is excellent for:

```text
Running Linux commands
Connecting tools with pipes
Simple automation
File operations
System checks
CI/CD glue logic
Deployment wrappers
```

Use Python when logic becomes complex, data structures grow, APIs are involved, or testing becomes important.

---

# 2. When to Use Bash

Use Bash for:

```text
Running commands in sequence
Checking files/directories
Calling CLI tools
Simple loops
Deployment steps
Health checks
Log filtering
Backup wrappers
System validation
```

Example:

```bash
#!/usr/bin/env bash
set -euo pipefail

npm test
docker build -t todo-api .
docker run --rm todo-api npm test
```

Use Python instead for:

```text
Complex JSON processing
Large data processing
Complicated error handling
API-heavy automation
Reusable libraries
Unit-tested business logic
```

Rule:

```text
Bash is best when your script is mostly commands.
Python is better when your script is mostly logic.
```

---

# 3. Your First Bash Script Structure

A good Bash script usually has:

```text
Shebang
Safety flags
Constants/config
Functions
Input validation
Main execution
Clear exit codes
```

Basic template:

```bash
#!/usr/bin/env bash
set -euo pipefail

main() {
  echo "Hello from Bash"
}

main "$@"
```

Save as:

```bash
hello.sh
```

Run:

```bash
chmod +x hello.sh
./hello.sh
```

---

# 4. Shebang

At the top:

```bash
#!/usr/bin/env bash
```

This tells Linux:

```text
Run this script using bash found in PATH.
```

Alternative:

```bash
#!/bin/bash
```

Both are common.

I prefer:

```bash
#!/usr/bin/env bash
```

because it finds Bash from the environment.

But in controlled production systems, `/bin/bash` is also fine.

---

# 5. Safety Flags

Use:

```bash
set -euo pipefail
```

This is the default safety baseline.

Breakdown:

```text
-e           exit immediately when a command fails
-u           fail when using undefined variables
-o pipefail  fail a pipeline if any command in it fails
```

Without safety:

```bash
backup_database
upload_backup
echo "Backup successful"
```

If `backup_database` fails, script may continue and falsely say success.

With:

```bash
set -euo pipefail
```

the script stops on failure.

---

# 6. Understand `set -e`

Example:

```bash
#!/usr/bin/env bash
set -e

echo "before"
ls /does-not-exist
echo "after"
```

Run:

```bash
./test.sh
```

Output:

```text
before
ls: cannot access '/does-not-exist': No such file or directory
```

It does not print:

```text
after
```

because the script exits when `ls` fails.

---

# 7. Understand `set -u`

Example:

```bash
#!/usr/bin/env bash
set -u

echo "User is $APP_USER"
```

If `APP_USER` is not defined, script fails.

This prevents hidden bugs.

Safe default:

```bash
APP_USER="${APP_USER:-unknown}"
echo "User is $APP_USER"
```

Meaning:

```text
Use APP_USER if set.
Otherwise use unknown.
```

Required variable pattern:

```bash
: "${DATABASE_URL:?DATABASE_URL is required}"
```

If `DATABASE_URL` is missing, script exits with a clear message.

---

# 8. Understand `pipefail`

Without `pipefail`:

```bash
set -e

grep "ERROR" missing.log | wc -l
echo "done"
```

The pipeline may succeed because `wc -l` succeeds, even though `grep` failed.

With:

```bash
set -euo pipefail
```

the whole pipeline fails if `grep` fails unexpectedly.

Important note:

```bash
grep "ERROR" app.log | wc -l
```

If no match is found, `grep` exits `1`.

With `pipefail`, this can stop the script.

If “no match” is acceptable, handle it:

```bash
grep "ERROR" app.log || true
```

or better:

```bash
error_count="$(grep -c "ERROR" app.log || true)"
```

---

# 9. Comments

Use comments to explain why, not every obvious command.

Good:

```bash
# Use -x to stay on the same filesystem and avoid mounted data disks.
sudo du -xhd1 / | sort -hr | head
```

Bad:

```bash
# Print hello
echo "hello"
```

Scripts are read more often than they are written.

---

# 10. Variables

Create variable:

```bash
APP_NAME="todo-api"
PORT="3000"
```

Use variable:

```bash
echo "$APP_NAME runs on port $PORT"
```

Always quote variables:

```bash
echo "$APP_NAME"
```

Not:

```bash
echo $APP_NAME
```

Why?

If variable contains spaces:

```bash
APP_NAME="todo api"
```

Unquoted usage may split it into multiple words.

Rule:

```text
Quote variables by default.
```

---

# 11. Command Substitution

Store command output in a variable:

```bash
TODAY="$(date +%Y%m%d)"
HOST="$(hostname)"
```

Example:

```bash
BACKUP_FILE="backup-${HOST}-${TODAY}.tar.gz"
echo "$BACKUP_FILE"
```

Use modern syntax:

```bash
VAR="$(command)"
```

Avoid old style:

```bash
VAR=`command`
```

Modern syntax is easier to read and nest.

---

# 12. Script Arguments

Arguments are accessed as:

```text
$0     script name
$1     first argument
$2     second argument
$@     all arguments
$#     number of arguments
$?     previous command exit code
$$     current shell PID
$!     last background process PID
```

Example:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Script: $0"
echo "First argument: ${1:-missing}"
echo "Argument count: $#"
```

Run:

```bash
./args.sh hello world
```

Output:

```text
Script: ./args.sh
First argument: hello
Argument count: 2
```

---

# 13. Required Argument Pattern

Bad:

```bash
TARGET_DIR="$1"
rm -rf "$TARGET_DIR"
```

If no argument is passed, this can fail or become dangerous depending on script style.

Better:

```bash
TARGET_DIR="${1:-}"

if [ -z "$TARGET_DIR" ]; then
  echo "Usage: $0 <target-dir>" >&2
  exit 1
fi
```

Then validate:

```bash
if [ ! -d "$TARGET_DIR" ]; then
  echo "ERROR: Not a directory: $TARGET_DIR" >&2
  exit 1
fi
```

Professional Bash validates input before doing work.

---

# 14. Exit Codes

Every command returns an exit code.

```text
0      success
non-0  failure
```

Check:

```bash
ls /etc
echo $?
```

Failure:

```bash
ls /does-not-exist
echo $?
```

In scripts:

```bash
exit 0
```

means success.

```bash
exit 1
```

means failure.

Use clear failures:

```bash
echo "ERROR: Config file missing" >&2
exit 1
```

---

# 15. stdout vs stderr

Normal output goes to stdout.

Errors should go to stderr.

stdout:

```bash
echo "Backup completed"
```

stderr:

```bash
echo "ERROR: Backup failed" >&2
```

Why?

Because callers can separate normal output and error output:

```bash
./script.sh > output.log 2> error.log
```

This matters in CI/CD, cron, systemd, and automation.

---

# 16. Conditions: `if`

Basic:

```bash
if [ -f "README.md" ]; then
  echo "README exists"
else
  echo "README missing"
fi
```

Common tests:

```bash
[ -f file ]       file exists and is regular file
[ -d dir ]        directory exists
[ -e path ]       path exists
[ -r file ]       readable
[ -w file ]       writable
[ -x file ]       executable
[ -z "$VAR" ]     string is empty
[ -n "$VAR" ]     string is not empty
```

Example:

```bash
CONFIG_FILE="/etc/todo-api/todo-api.env"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: Missing config: $CONFIG_FILE" >&2
  exit 1
fi
```

---

# 17. Numeric Conditions

Use:

```bash
COUNT="5"

if [ "$COUNT" -gt 3 ]; then
  echo "count is greater than 3"
fi
```

Operators:

```text
-eq   equal
-ne   not equal
-gt   greater than
-ge   greater than or equal
-lt   less than
-le   less than or equal
```

Example:

```bash
DISK_USAGE="85"

if [ "$DISK_USAGE" -ge 80 ]; then
  echo "WARNING: disk usage high"
fi
```

---

# 18. String Conditions

```bash
ENVIRONMENT="prod"

if [ "$ENVIRONMENT" = "prod" ]; then
  echo "Production"
fi
```

Not equal:

```bash
if [ "$ENVIRONMENT" != "prod" ]; then
  echo "Not production"
fi
```

Empty:

```bash
if [ -z "$ENVIRONMENT" ]; then
  echo "Environment is empty"
fi
```

Non-empty:

```bash
if [ -n "$ENVIRONMENT" ]; then
  echo "Environment is set"
fi
```

---

# 19. `[[ ]]` vs `[ ]`

Bash supports:

```bash
[ "$VAR" = "value" ]
```

and:

```bash
[[ "$VAR" == "value" ]]
```

`[[ ]]` is Bash-specific and more powerful.

Example pattern matching:

```bash
FILE="app.log"

if [[ "$FILE" == *.log ]]; then
  echo "log file"
fi
```

Regex:

```bash
PORT="3000"

if [[ "$PORT" =~ ^[0-9]+$ ]]; then
  echo "valid port"
fi
```

Since we use Bash, `[[ ]]` is fine.

For POSIX `sh`, use `[ ]`.

---

# 20. Loops: `for`

Loop over values:

```bash
for service in ssh docker nginx; do
  echo "Checking $service"
done
```

Loop over files:

```bash
for file in *.log; do
  echo "$file"
done
```

Safer file loop with `find` for spaces:

```bash
find . -name "*.log" -type f -print0 |
while IFS= read -r -d '' file; do
  echo "Log file: $file"
done
```

For simple cases, `for file in *.log` is okay.

For production scripts where filenames may have spaces/newlines, prefer `find -print0`.

---

# 21. Loops: `while`

Example:

```bash
count=1

while [ "$count" -le 5 ]; do
  echo "count=$count"
  count=$((count + 1))
done
```

Read file line by line:

```bash
while IFS= read -r line; do
  echo "Line: $line"
done < app.log
```

Important:

```text
Use IFS= read -r to preserve whitespace and backslashes.
```

---

# 22. Arithmetic

Use:

```bash
COUNT=1
COUNT=$((COUNT + 1))
echo "$COUNT"
```

Examples:

```bash
TOTAL=$((5 + 3))
PERCENT=$((USED * 100 / TOTAL))
```

Bash arithmetic is integer-only.

For decimals, use tools like `awk` or Python.

---

# 23. Arrays

Create array:

```bash
SERVICES=("ssh" "docker" "nginx")
```

Loop:

```bash
for service in "${SERVICES[@]}"; do
  echo "$service"
done
```

Number of items:

```bash
echo "${#SERVICES[@]}"
```

Important:

```bash
"${SERVICES[@]}"
```

preserves each array item safely.

---

# 24. Functions

Functions help organize scripts.

Example:

```bash
log_info() {
  echo "INFO: $*"
}

log_error() {
  echo "ERROR: $*" >&2
}

log_info "Starting deployment"
log_error "Something failed"
```

Function with return status:

```bash
file_exists() {
  local path="$1"

  if [ -f "$path" ]; then
    return 0
  else
    return 1
  fi
}

if file_exists "README.md"; then
  echo "README exists"
fi
```

Use `local` inside functions:

```bash
local path="$1"
```

This avoids polluting global variables.

---

# 25. `main "$@"` Pattern

Professional Bash scripts often end with:

```bash
main() {
  echo "Script logic here"
}

main "$@"
```

Why?

```text
Keeps script organized.
Makes functions reusable.
Passes all CLI arguments into main safely.
```

Example:

```bash
#!/usr/bin/env bash
set -euo pipefail

main() {
  local name="${1:-world}"
  echo "Hello, $name"
}

main "$@"
```

Run:

```bash
./hello.sh Vivek
```

---

# 26. Case Statements

Useful for commands/options.

```bash
ACTION="${1:-}"

case "$ACTION" in
  start)
    echo "Starting..."
    ;;
  stop)
    echo "Stopping..."
    ;;
  status)
    echo "Checking status..."
    ;;
  *)
    echo "Usage: $0 {start|stop|status}" >&2
    exit 1
    ;;
esac
```

This is cleaner than many `if/elif` blocks.

---

# 27. Trap and Cleanup

`trap` lets you run cleanup when a script exits.

Example:

```bash
#!/usr/bin/env bash
set -euo pipefail

TMP_FILE="$(mktemp)"

cleanup() {
  rm -f "$TMP_FILE"
}

trap cleanup EXIT

echo "temporary data" > "$TMP_FILE"
cat "$TMP_FILE"
```

Even if script fails, `cleanup` runs.

This is very useful for:

```text
Temporary files
Lock files
Background processes
Mount cleanup
Test environment cleanup
```

---

# 28. Temporary Files with `mktemp`

Bad:

```bash
TMP_FILE="/tmp/my-script.tmp"
```

Why bad?

```text
Filename conflict
Security risk
Race condition
```

Good:

```bash
TMP_FILE="$(mktemp)"
```

Directory:

```bash
TMP_DIR="$(mktemp -d)"
```

Cleanup:

```bash
trap 'rm -rf "$TMP_DIR"' EXIT
```

Professional scripts use `mktemp`.

---

# 29. Logging Functions

Useful script pattern:

```bash
log() {
  local level="$1"
  shift
  echo "$(date -Is) [$level] $*"
}

info() {
  log "INFO" "$@"
}

warn() {
  log "WARN" "$@"
}

error() {
  log "ERROR" "$@" >&2
}
```

Usage:

```bash
info "Starting backup"
warn "Disk usage high"
error "Backup failed"
```

Output:

```text
2026-06-28T12:30:00+05:30 [INFO] Starting backup
```

This is much better than random `echo`.

---

# 30. Dry Run Pattern

Many DevOps scripts should support dry-run.

Example:

```bash
DRY_RUN="${DRY_RUN:-true}"

run_cmd() {
  if [ "$DRY_RUN" = "true" ]; then
    echo "[DRY-RUN] $*"
  else
    "$@"
  fi
}

run_cmd rm -f old-file.log
```

Run normally as dry-run:

```bash
./cleanup.sh
```

Actually execute:

```bash
DRY_RUN=false ./cleanup.sh
```

This pattern prevents accidental destructive actions.

---

# 31. Confirm Before Dangerous Action

Interactive confirmation:

```bash
read -r -p "Are you sure? Type yes: " answer

if [ "$answer" != "yes" ]; then
  echo "Aborted"
  exit 1
fi
```

But in CI/CD, avoid interactive prompts.

For automation, prefer explicit flags:

```bash
./cleanup.sh --delete
```

No `--delete`, no deletion.

---

# 32. Parsing Options — Simple Pattern

Example:

```bash
DELETE=false
TARGET_DIR=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --delete)
      DELETE=true
      shift
      ;;
    --target)
      TARGET_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 --target <dir> [--delete]"
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done
```

This is enough for many Bash scripts.

For complex CLI tools, use Python/Go.

---

# 33. Create Bash Foundation Notes

Create:

```bash
cd ~/devops-masterclass
nano 03-linux-bash-networking/bash-scripting-foundation.md
```

Paste:

````markdown
# Bash Scripting Foundation

## Why Bash Matters

Bash is used for Linux automation, CI/CD commands, deployment wrappers, health checks, backup scripts, Docker entrypoints, and troubleshooting helpers.

## Basic Script Template

```bash
#!/usr/bin/env bash
set -euo pipefail

main() {
  echo "Hello from Bash"
}

main "$@"
````

## Safety Flags

```bash
set -euo pipefail
```

* `-e` exits on command failure
* `-u` fails on undefined variables
* `pipefail` fails pipeline if any command fails

## Common Variables

```bash
$0   script name
$1   first argument
$2   second argument
$@   all arguments
$#   argument count
$?   previous exit code
$$   current shell PID
$!   last background process PID
```

## Rules

* Quote variables by default.
* Validate arguments before using them.
* Print errors to stderr.
* Use exit code `0` for success and non-zero for failure.
* Use functions for reusable logic.
* Use `main "$@"` structure.
* Use `mktemp` for temporary files.
* Use `trap` for cleanup.
* Use dry-run mode for destructive scripts.
* Avoid `rm -rf` without validation.

````

Commit later after scripts.

---

# 34. Script Lab 1 — Argument Validator

Create:

```bash
mkdir -p 03-linux-bash-networking/scripts
nano 03-linux-bash-networking/scripts/arg-validator.sh
````

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <file-path>" >&2
}

main() {
  local file_path="${1:-}"

  if [ -z "$file_path" ]; then
    usage
    exit 1
  fi

  if [ ! -e "$file_path" ]; then
    echo "ERROR: Path does not exist: $file_path" >&2
    exit 1
  fi

  echo "Path exists: $file_path"

  if [ -f "$file_path" ]; then
    echo "Type: regular file"
  elif [ -d "$file_path" ]; then
    echo "Type: directory"
  else
    echo "Type: other"
  fi

  echo "Metadata:"
  stat "$file_path"
}

main "$@"
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/arg-validator.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/arg-validator.sh README.md
./03-linux-bash-networking/scripts/arg-validator.sh /does-not-exist
```

This teaches:

```text
arguments
validation
stderr
exit codes
functions
main "$@"
```

---

# 35. Script Lab 2 — Multi-Service Checker

Create:

```bash
nano 03-linux-bash-networking/scripts/check-services.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <service1> [service2] ..." >&2
  echo "Example: $0 ssh docker nginx" >&2
}

check_service() {
  local service="$1"

  echo "----- $service -----"

  if systemctl is-active --quiet "$service"; then
    echo "Active: yes"
  else
    echo "Active: no"
    return 1
  fi

  if systemctl is-enabled --quiet "$service"; then
    echo "Enabled: yes"
  else
    echo "Enabled: no"
  fi

  local main_pid
  main_pid="$(systemctl show "$service" -p MainPID --value 2>/dev/null || echo 0)"
  echo "MainPID: $main_pid"

  if [ "$main_pid" != "0" ] && [ -d "/proc/$main_pid" ]; then
    ps -p "$main_pid" -o pid,user,stat,%cpu,%mem,etime,cmd || true
  fi

  echo
}

main() {
  if [ "$#" -eq 0 ]; then
    usage
    exit 1
  fi

  local failed=0

  for service in "$@"; do
    if ! check_service "$service"; then
      failed=1
    fi
  done

  if [ "$failed" -ne 0 ]; then
    echo "One or more services are inactive." >&2
    exit 1
  fi

  echo "All services are active."
}

main "$@"
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/check-services.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/check-services.sh ssh
```

or:

```bash
./03-linux-bash-networking/scripts/check-services.sh ssh docker
```

This script is very similar to what you might use in deployment validation.

---

# 36. Script Lab 3 — Safe Cleanup with Dry Run and Delete Flag

Create:

```bash
nano 03-linux-bash-networking/scripts/safe-cleanup.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR=""
DAYS_OLD="7"
PATTERN="*.log"
DELETE=false

usage() {
  cat <<EOF
Usage: $0 --target <dir> [--days <days>] [--pattern <pattern>] [--delete]

Examples:
  $0 --target /var/log --days 14 --pattern "*.log"
  $0 --target ./logs --days 7 --pattern "*.tmp" --delete

Default:
  days: 7
  pattern: *.log

Without --delete, this script only performs a dry run.
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --target)
        TARGET_DIR="${2:-}"
        shift 2
        ;;
      --days)
        DAYS_OLD="${2:-}"
        shift 2
        ;;
      --pattern)
        PATTERN="${2:-}"
        shift 2
        ;;
      --delete)
        DELETE=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "ERROR: Unknown option: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
}

validate_inputs() {
  if [ -z "$TARGET_DIR" ]; then
    echo "ERROR: --target is required" >&2
    exit 1
  fi

  if [ ! -d "$TARGET_DIR" ]; then
    echo "ERROR: Target is not a directory: $TARGET_DIR" >&2
    exit 1
  fi

  if ! [[ "$DAYS_OLD" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --days must be numeric" >&2
    exit 1
  fi
}

show_plan() {
  echo "===== Safe Cleanup ====="
  echo "Target: $TARGET_DIR"
  echo "Older than days: $DAYS_OLD"
  echo "Pattern: $PATTERN"
  echo "Delete mode: $DELETE"
  echo
}

find_files() {
  find "$TARGET_DIR" -type f -name "$PATTERN" -mtime +"$DAYS_OLD" -print
}

delete_files() {
  find "$TARGET_DIR" -type f -name "$PATTERN" -mtime +"$DAYS_OLD" -delete
}

main() {
  parse_args "$@"
  validate_inputs
  show_plan

  echo "Files matched:"
  find_files

  if [ "$DELETE" = true ]; then
    echo
    echo "Deleting matched files..."
    delete_files
    echo "Delete completed."
  else
    echo
    echo "Dry run only. Add --delete to actually delete."
  fi
}

main "$@"
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/safe-cleanup.sh
```

Create test files:

```bash
mkdir -p /tmp/bash-cleanup-lab
touch /tmp/bash-cleanup-lab/app.log
touch /tmp/bash-cleanup-lab/debug.tmp
```

Dry run:

```bash
./03-linux-bash-networking/scripts/safe-cleanup.sh \
  --target /tmp/bash-cleanup-lab \
  --days 0 \
  --pattern "*.log"
```

Delete mode:

```bash
./03-linux-bash-networking/scripts/safe-cleanup.sh \
  --target /tmp/bash-cleanup-lab \
  --days 0 \
  --pattern "*.log" \
  --delete
```

Cleanup:

```bash
rm -rf /tmp/bash-cleanup-lab
```

---

# 37. Script Lab 4 — Temporary Directory with Trap

Create:

```bash
nano 03-linux-bash-networking/scripts/temp-workspace-demo.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

TMP_DIR=""

cleanup() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    echo "Cleaning up temporary directory: $TMP_DIR"
    rm -rf "$TMP_DIR"
  fi
}

trap cleanup EXIT

main() {
  TMP_DIR="$(mktemp -d)"

  echo "Temporary directory: $TMP_DIR"

  echo "Creating test files..."
  echo "hello" > "$TMP_DIR/file1.txt"
  echo "world" > "$TMP_DIR/file2.txt"

  echo "Contents:"
  ls -la "$TMP_DIR"

  echo "Simulating work..."
  sleep 2

  echo "Done."
}

main "$@"
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/temp-workspace-demo.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/temp-workspace-demo.sh
```

The temporary directory is deleted automatically.

This is professional cleanup behavior.

---

# 38. Script Lab 5 — Deployment Preflight Checker

Create:

```bash
nano 03-linux-bash-networking/scripts/deploy-preflight.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${1:-}"
REQUIRED_FREE_MB="${REQUIRED_FREE_MB:-500}"

usage() {
  echo "Usage: $0 <app-dir>" >&2
  echo "Environment variables:" >&2
  echo "  REQUIRED_FREE_MB=500" >&2
}

check_command() {
  local cmd="$1"

  if command -v "$cmd" >/dev/null 2>&1; then
    echo "OK: command found: $cmd"
  else
    echo "ERROR: command missing: $cmd" >&2
    return 1
  fi
}

check_disk_space() {
  local path="$1"
  local available_mb

  available_mb="$(df -Pm "$path" | awk 'NR==2 {print $4}')"

  echo "Available disk at $path: ${available_mb}MB"
  echo "Required free disk: ${REQUIRED_FREE_MB}MB"

  if [ "$available_mb" -lt "$REQUIRED_FREE_MB" ]; then
    echo "ERROR: Not enough disk space" >&2
    return 1
  fi
}

main() {
  if [ -z "$APP_DIR" ]; then
    usage
    exit 1
  fi

  if [ ! -d "$APP_DIR" ]; then
    echo "ERROR: App directory does not exist: $APP_DIR" >&2
    exit 1
  fi

  echo "===== Deployment Preflight ====="
  echo "App directory: $APP_DIR"
  echo "Generated at: $(date -Is)"
  echo

  local failed=0

  check_command git || failed=1
  check_command bash || failed=1
  check_command tar || failed=1

  echo
  check_disk_space "$APP_DIR" || failed=1

  echo
  echo "Git status:"
  if [ -d "$APP_DIR/.git" ]; then
    git -C "$APP_DIR" status --short
  else
    echo "No Git repository found at app dir"
  fi

  if [ "$failed" -ne 0 ]; then
    echo "Preflight failed." >&2
    exit 1
  fi

  echo
  echo "Preflight passed."
}

main "$@"
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/deploy-preflight.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/deploy-preflight.sh ~/devops-masterclass
```

Customize required disk:

```bash
REQUIRED_FREE_MB=1000 ./03-linux-bash-networking/scripts/deploy-preflight.sh ~/devops-masterclass
```

This script checks:

```text
Required commands
Disk space
Git status
Input directory
```

This is exactly the kind of script you use before deployments.

---

# 39. Debugging Bash Scripts

Run with debug trace:

```bash
bash -x script.sh
```

Example:

```bash
bash -x 03-linux-bash-networking/scripts/deploy-preflight.sh ~/devops-masterclass
```

Inside script, you can enable:

```bash
set -x
```

Disable:

```bash
set +x
```

Do not use `set -x` around secrets.

Bad:

```bash
set -x
export DATABASE_URL="..."
```

This can print secrets.

Better:

```bash
echo "Database URL configured"
```

---

# 40. Lint Bash with ShellCheck

Install:

```bash
sudo apt update
sudo apt install -y shellcheck
```

Run:

```bash
shellcheck 03-linux-bash-networking/scripts/*.sh
```

ShellCheck catches common Bash bugs:

```text
Unquoted variables
Unused variables
Dangerous patterns
Wrong test syntax
Portability issues
```

This is extremely useful.

Later we can add ShellCheck to GitHub Actions.

---

# 41. Add ShellCheck GitHub Actions Step

In your CI workflow later, add:

```yaml
- name: Install ShellCheck
  run: sudo apt-get update && sudo apt-get install -y shellcheck

- name: Run ShellCheck
  run: shellcheck $(find . -name "*.sh")
```

Better safer version:

```yaml
- name: Run ShellCheck
  run: |
    find . -name "*.sh" -print0 | xargs -0 -r shellcheck
```

This validates your scripts automatically.

---

# 42. Commit Scripts and Notes

Run:

```bash
git status
git diff
```

Add:

```bash
git add 03-linux-bash-networking/bash-scripting-foundation.md \
        03-linux-bash-networking/scripts/arg-validator.sh \
        03-linux-bash-networking/scripts/check-services.sh \
        03-linux-bash-networking/scripts/safe-cleanup.sh \
        03-linux-bash-networking/scripts/temp-workspace-demo.sh \
        03-linux-bash-networking/scripts/deploy-preflight.sh
```

Check staged:

```bash
git diff --staged
```

Commit:

```bash
git commit -m "docs: add Bash scripting foundation"
git push
```

---

# 43. Real Production Example — Safe Deployment Script Structure

A production deployment wrapper may look like this:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="todo-api"
RELEASE_VERSION="${1:-}"
RELEASE_ROOT="/opt/$APP_NAME/releases"
CURRENT_LINK="/opt/$APP_NAME/current"

usage() {
  echo "Usage: $0 <release-version>" >&2
}

main() {
  if [ -z "$RELEASE_VERSION" ]; then
    usage
    exit 1
  fi

  local release_dir="$RELEASE_ROOT/$RELEASE_VERSION"

  if [ ! -d "$release_dir" ]; then
    echo "ERROR: Release directory missing: $release_dir" >&2
    exit 1
  fi

  echo "Switching $APP_NAME to release $RELEASE_VERSION"
  ln -sfn "$release_dir" "$CURRENT_LINK"

  systemctl restart "$APP_NAME"
  systemctl is-active --quiet "$APP_NAME"

  echo "Deployment completed"
}

main "$@"
```

Key ideas:

```text
Validate release version
Check release directory exists
Use symlink switch
Restart service
Verify service active
Exit non-zero on failure
```

This connects Bash, systemd, Linux files, and deployment strategy.

---

# 44. Real Production Example — Health Check Script

```bash
#!/usr/bin/env bash
set -euo pipefail

URL="${1:-http://127.0.0.1:3000/health}"

if curl -fsS "$URL" >/dev/null; then
  echo "Health check passed: $URL"
else
  echo "ERROR: Health check failed: $URL" >&2
  exit 1
fi
```

Useful in:

```text
Jenkins
GitHub Actions
systemd ExecStartPost
Deployment validation
Load balancer target checks
```

---

# 45. Real Production Example — Backup Script Pattern

```bash
#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${1:-}"
BACKUP_DIR="${2:-/var/backups/myapp}"

if [ -z "$SOURCE_DIR" ]; then
  echo "Usage: $0 <source-dir> [backup-dir]" >&2
  exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
  echo "ERROR: Source is not a directory: $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_file="$BACKUP_DIR/backup-$timestamp.tar.gz"

tar -czf "$backup_file" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"

sha256sum "$backup_file" > "$backup_file.sha256"

echo "Backup created: $backup_file"
```

Key ideas:

```text
Input validation
Timestamped artifact
Controlled archive path
Checksum
Clear output
```

---

# 46. Common Bash Mistakes

## Mistake 1 — Unquoted variables

Bad:

```bash
rm -rf $TARGET_DIR
```

Good:

```bash
rm -rf "$TARGET_DIR"
```

## Mistake 2 — No input validation

Bad:

```bash
tar -czf backup.tar.gz "$1"
```

Good:

```bash
if [ -z "${1:-}" ]; then
  echo "Usage: $0 <path>" >&2
  exit 1
fi
```

## Mistake 3 — Ignoring failures

Bad:

```bash
npm test
docker build -t app .
echo "success"
```

Good:

```bash
set -euo pipefail
npm test
docker build -t app .
echo "success"
```

## Mistake 4 — Printing secrets

Bad:

```bash
echo "$DATABASE_URL"
```

Good:

```bash
echo "DATABASE_URL is configured"
```

## Mistake 5 — Using interactive prompts in CI/CD

Bad for CI:

```bash
read -p "Continue?"
```

Good:

```bash
./script.sh --approve
```

## Mistake 6 — Using relative paths blindly

Bad:

```bash
rm -rf ./build
```

Better:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
rm -rf "$BUILD_DIR"
```

---

# 47. Script Directory Pattern

Useful when a script needs paths relative to itself:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
```

Example:

```bash
echo "Script dir: $SCRIPT_DIR"
echo "Project root: $PROJECT_ROOT"
```

This prevents bugs when running the script from a different directory.

---

# 48. Interview Answers

Question:

```text
Why do you use set -euo pipefail in Bash scripts?
```

Strong answer:

```text
I use set -euo pipefail to make scripts fail safely. The -e option exits when a command fails, -u fails on undefined variables, and pipefail makes a pipeline fail if any command in the pipeline fails. This prevents scripts from silently continuing after errors, which is important in CI/CD, deployment, backup, and cleanup automation.
```

Question:

```text
Why should variables be quoted in Bash?
```

Strong answer:

```text
Variables should be quoted to prevent word splitting and glob expansion. If a path contains spaces or if a variable is empty, unquoted variables can cause commands to operate on the wrong arguments. Quoting variables is a basic safety practice, especially for file operations and automation scripts.
```

Question:

```text
How do you make a Bash cleanup script safe?
```

Strong answer:

```text
I validate that the target directory exists and is not empty, quote all variables, print the files that match before deleting, support dry-run mode by default, and require an explicit flag like --delete for destructive actions. I avoid blind rm -rf and use clear error messages and non-zero exit codes on failure.
```

Question:

```text
What is trap used for in Bash?
```

Strong answer:

```text
trap is used to run commands when a script receives a signal or exits. A common use is cleanup: create a temporary file or directory with mktemp, then use trap cleanup EXIT to remove it even if the script fails. This prevents leftover temporary files, lock files, or background processes.
```

---

# Today’s Core Rules

```text
Bash is best when the script is mostly commands.
Use Python when logic becomes complex.
Start scripts with a shebang.
Use set -euo pipefail.
Quote variables by default.
Validate all inputs.
Print errors to stderr.
Use meaningful exit codes.
Use functions and main "$@".
Use mktemp for temporary files.
Use trap for cleanup.
Use dry-run mode before destructive actions.
Use ShellCheck.
Never print secrets.
```

Next lesson:

# Lesson 3.13 — Advanced Bash for DevOps: robust option parsing, logging framework, retries, timeouts, lock files, parallel execution, and production-grade script patterns.

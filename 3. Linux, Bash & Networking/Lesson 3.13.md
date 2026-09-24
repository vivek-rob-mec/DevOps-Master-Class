# Lesson 3.13 — Advanced Bash for DevOps

Now we move from **basic Bash scripting** to **production-grade Bash scripting**.

This lesson is about writing Bash scripts that are safer, clearer, reusable, and useful in real DevOps work.

We will cover:

```text
Robust script structure
Option parsing
Logging framework
Retries
Timeouts
Lock files
Dry-run execution
Safe command execution
Parallel execution
Signal handling
Production deployment patterns
CI/CD usage
```

Basic Bash answers:

```text
Can I automate this?
```

Advanced Bash answers:

```text
Can I automate this safely, repeatedly, and predictably under failure?
```

---

# 1. Why Advanced Bash Matters

In real DevOps, scripts often touch dangerous things:

```text
Deployments
Backups
Cleanup
Server restarts
Database migrations
Disk cleanup
Docker pruning
Kubernetes rollouts
Terraform wrappers
Log collection
Incident triage
```

A bad script can:

```text
Delete wrong files
Deploy wrong version
Restart wrong service
Hide failures
Print secrets
Run twice at the same time
Hang forever
Partially complete and lie
Fail silently in CI/CD
```

So production Bash needs guardrails.

---

# 2. Production Bash Script Checklist

A strong DevOps script should usually have:

```text
Safe mode: set -euo pipefail
Usage/help text
Input validation
Logging functions
Error function
Dry-run support for destructive actions
Explicit delete/apply/deploy flag
Retry support for flaky commands
Timeout support for hanging commands
Lock file for single execution
Cleanup trap
Command existence checks
Clear exit codes
No secret printing
ShellCheck clean
```

Template mindset:

```text
Validate → Log → Execute → Verify → Cleanup → Exit clearly
```

---

# 3. Production Script Skeleton

Create a reusable template:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DRY_RUN=true
VERBOSE=false

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Options:
  --apply       Actually perform changes. Default is dry-run.
  --verbose     Enable verbose output.
  -h, --help    Show help.

Examples:
  $SCRIPT_NAME
  $SCRIPT_NAME --apply
EOF
}

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

die() {
  error "$@"
  exit 1
}

run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    info "[DRY-RUN] $*"
  else
    info "[RUN] $*"
    "$@"
  fi
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --apply)
        DRY_RUN=false
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  info "Starting $SCRIPT_NAME"
  info "Dry-run mode: $DRY_RUN"

  run_cmd echo "Example command"

  info "Completed $SCRIPT_NAME"
}

main "$@"
```

This structure is much safer than random command lists.

---

# 4. Option Parsing with `case`

Basic option parsing:

```bash
while [ "$#" -gt 0 ]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --apply)
      APPLY=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done
```

Important mistake:

```bash
TARGET="$2"
shift 2
```

If `--target` is passed without a value, `$2` may be missing.

Better:

```bash
TARGET="${2:-}"

if [ -z "$TARGET" ]; then
  die "--target requires a value"
fi

shift 2
```

---

# 5. Logging Framework

A real script should produce useful logs.

Basic logging:

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

Use:

```bash
info "Starting deployment"
warn "Disk usage is above warning threshold"
error "Health check failed"
```

Example output:

```text
2026-06-28T12:00:00+05:30 [INFO] Starting deployment
2026-06-28T12:00:02+05:30 [ERROR] Health check failed
```

Why this matters:

```text
Timestamps help incident timelines.
Levels help filtering.
Consistent format helps parsing.
stderr separates errors.
```

---

# 6. `die` Function

Use a common failure function:

```bash
die() {
  error "$@"
  exit 1
}
```

Then:

```bash
[ -n "$TARGET_DIR" ] || die "--target is required"
[ -d "$TARGET_DIR" ] || die "Target is not a directory: $TARGET_DIR"
```

This keeps scripts readable.

---

# 7. Command Existence Checks

Before using external tools, verify they exist.

```bash
require_command() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "Required command not found: $cmd"
  fi
}
```

Use:

```bash
require_command curl
require_command jq
require_command systemctl
require_command tar
```

This prevents confusing failures later.

Bad:

```bash
jq '.status' response.json
```

If `jq` is missing:

```text
jq: command not found
```

Better:

```bash
require_command jq
jq '.status' response.json
```

---

# 8. Dry-Run Pattern

Dry-run should be default for destructive scripts.

```bash
DRY_RUN=true

run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    info "[DRY-RUN] $*"
  else
    info "[RUN] $*"
    "$@"
  fi
}
```

Example:

```bash
run_cmd rm -f "$old_file"
run_cmd systemctl restart "$service"
```

Run safely:

```bash
./cleanup.sh
```

Actually execute:

```bash
./cleanup.sh --apply
```

Rule:

```text
Destructive scripts should require explicit action.
```

Examples of explicit action flags:

```text
--apply
--delete
--deploy
--force
```

Avoid silent destructive defaults.

---

# 9. Safe Command Runner with Arrays

This:

```bash
run_cmd rm -f "$file"
```

is fine because arguments are passed separately.

Avoid this pattern:

```bash
cmd="rm -f $file"
eval "$cmd"
```

`eval` is dangerous.

Why?

```text
It re-parses strings as shell code.
It can execute unexpected content.
It creates injection risks.
```

Bad:

```bash
FILE='somefile; rm -rf /'
eval "rm -f $FILE"
```

Avoid `eval` unless you deeply understand why you need it.

---

# 10. Retries

Network commands can fail temporarily.

Examples:

```text
curl health check
docker pull
apt update
aws cli call
kubectl rollout status
```

Retry helper:

```bash
retry() {
  local attempts="$1"
  local delay="$2"
  shift 2

  local attempt=1

  until "$@"; do
    if [ "$attempt" -ge "$attempts" ]; then
      error "Command failed after $attempt attempts: $*"
      return 1
    fi

    warn "Command failed. Attempt $attempt/$attempts. Retrying in ${delay}s: $*"
    sleep "$delay"
    attempt=$((attempt + 1))
  done
}
```

Use:

```bash
retry 5 3 curl -fsS http://127.0.0.1:3000/health
```

Meaning:

```text
Try up to 5 times.
Wait 3 seconds between attempts.
Fail if all attempts fail.
```

This is useful after service restart because app may need time to start.

---

# 11. Timeout

Some commands hang.

Examples:

```text
curl waiting forever
ssh command stuck
database connection stuck
network call hanging
```

Use `timeout`:

```bash
timeout 10s curl -fsS http://127.0.0.1:3000/health
```

If command exceeds 10 seconds, it is terminated.

Check timeout exists:

```bash
command -v timeout
```

Retry with timeout:

```bash
retry 5 3 timeout 5s curl -fsS http://127.0.0.1:3000/health
```

This is a production-grade pattern.

---

# 12. Health Check Function

Example:

```bash
health_check() {
  local url="$1"

  info "Checking health endpoint: $url"

  retry 10 3 timeout 5s curl -fsS "$url" >/dev/null

  info "Health check passed"
}
```

Use:

```bash
health_check "http://127.0.0.1:3000/health"
```

This works well in deployments.

---

# 13. Lock Files

Some scripts must not run twice simultaneously.

Examples:

```text
Backup script
Cleanup script
Deployment script
Database migration
Log rotation helper
```

Bad scenario:

```text
Two backup jobs run at same time.
Both write same backup file.
One deletes files while the other reads them.
```

Use lock files.

Simple lock directory pattern:

```bash
LOCK_DIR="/tmp/my-script.lock"

acquire_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    trap release_lock EXIT
    info "Acquired lock: $LOCK_DIR"
  else
    die "Another instance is already running"
  fi
}

release_lock() {
  rm -rf "$LOCK_DIR"
}
```

Why directory lock?

```text
mkdir is atomic.
If it succeeds, lock acquired.
If it fails, lock exists.
```

---

# 14. `flock`

Linux also has `flock`.

Example:

```bash
flock -n /tmp/my-script.lock -c './script-body.sh'
```

Inside a script:

```bash
LOCK_FILE="/tmp/my-script.lock"

exec 200>"$LOCK_FILE"

if ! flock -n 200; then
  echo "Another instance is running" >&2
  exit 1
fi
```

`flock` is clean and widely used.

Directory lock is simpler for learning and portable enough for many scripts.

---

# 15. Trap for Cleanup

Use:

```bash
cleanup() {
  info "Cleaning up"
}

trap cleanup EXIT
```

Trap signals:

```bash
trap cleanup EXIT INT TERM
```

Example:

```bash
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT
```

This ensures temp files are removed even if script fails.

---

# 16. Handling Ctrl+C

If user presses Ctrl+C, script receives `SIGINT`.

Example:

```bash
on_interrupt() {
  warn "Interrupted by user"
  exit 130
}

trap on_interrupt INT
```

Exit code 130 commonly means interrupted by Ctrl+C.

---

# 17. Background Processes and Cleanup

If script starts a background process:

```bash
python3 -m http.server 8080 &
SERVER_PID=$!
```

Clean it on exit:

```bash
cleanup() {
  if [ -n "${SERVER_PID:-}" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT
```

This prevents orphan processes.

---

# 18. Parallel Execution

Sometimes you want to check multiple services/hosts in parallel.

Basic background jobs:

```bash
check_service ssh &
check_service docker &
check_service nginx &

wait
```

But you need to capture failures.

Example:

```bash
failed=0

check_service ssh || failed=1 &
pid1=$!

check_service docker || failed=1 &
pid2=$!

wait "$pid1" || failed=1
wait "$pid2" || failed=1

exit "$failed"
```

This can get tricky.

For simple scripts, sequential is safer.

For parallel command execution, tools like GNU `parallel`, Ansible, or Python may be better.

---

# 19. Safe Parallel Pattern

Example:

```bash
run_check() {
  local service="$1"

  if systemctl is-active --quiet "$service"; then
    echo "$service OK"
    return 0
  else
    echo "$service FAIL"
    return 1
  fi
}

main() {
  local failed=0
  local pids=()

  for service in "$@"; do
    run_check "$service" &
    pids+=("$!")
  done

  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      failed=1
    fi
  done

  return "$failed"
}
```

This waits for all checks and fails if any failed.

---

# 20. Strict Mode Caveats

`set -euo pipefail` is good, but you must understand exceptions.

Example:

```bash
grep "ERROR" app.log
```

If no match, grep exits 1.

With `set -e`, script exits.

If no match is acceptable:

```bash
grep "ERROR" app.log || true
```

For count:

```bash
error_count="$(grep -c "ERROR" app.log || true)"
```

For `if`, this is okay:

```bash
if grep -q "ERROR" app.log; then
  echo "errors found"
else
  echo "no errors"
fi
```

Commands used in `if` conditions do not trigger unwanted exit the same way.

---

# 21. Avoid Parsing `ls`

Bad:

```bash
for file in $(ls *.log); do
  echo "$file"
done
```

Problems:

```text
Breaks on spaces
Breaks on newlines
Unnecessary command
```

Better:

```bash
for file in *.log; do
  [ -e "$file" ] || continue
  echo "$file"
done
```

Best for robust file handling:

```bash
find . -name "*.log" -type f -print0 |
while IFS= read -r -d '' file; do
  echo "$file"
done
```

---

# 22. Script Path Safety

Scripts often need paths relative to the script location.

Use:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
```

Then:

```bash
CONFIG_FILE="$PROJECT_ROOT/config/app.conf"
```

This avoids bugs when user runs script from another directory.

---

# 23. Secret Safety

Never do:

```bash
set -x
echo "$DATABASE_URL"
env
```

Why?

```text
Secrets can appear in terminal logs, CI logs, shell history, systemd logs.
```

Safer:

```bash
if [ -n "${DATABASE_URL:-}" ]; then
  info "DATABASE_URL is configured"
else
  die "DATABASE_URL is missing"
fi
```

In CI/CD:

```text
Do not print secrets.
Do not run env blindly.
Disable set -x around secret handling.
```

---

# 24. Script Lab — Advanced Health Check with Retry and Timeout

Create:

```bash
cd ~/devops-masterclass
nano 03-linux-bash-networking/scripts/advanced-health-check.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

URL=""
ATTEMPTS=5
DELAY=3
TIMEOUT_SECONDS=5
VERBOSE=false

usage() {
  cat <<EOF
Usage: $0 --url <health-url> [options]

Options:
  --url <url>          Health check URL
  --attempts <n>       Retry attempts. Default: 5
  --delay <seconds>    Delay between retries. Default: 3
  --timeout <seconds>  Per-request timeout. Default: 5
  --verbose            Enable verbose output
  -h, --help           Show help

Example:
  $0 --url http://127.0.0.1:3000/health --attempts 10 --delay 2
EOF
}

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

die() {
  error "$@"
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
}

retry() {
  local attempts="$1"
  local delay="$2"
  shift 2

  local attempt=1

  until "$@"; do
    if [ "$attempt" -ge "$attempts" ]; then
      error "Command failed after $attempt attempts: $*"
      return 1
    fi

    warn "Attempt $attempt/$attempts failed. Retrying in ${delay}s..."
    sleep "$delay"
    attempt=$((attempt + 1))
  done
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --url)
        URL="${2:-}"
        [ -n "$URL" ] || die "--url requires a value"
        shift 2
        ;;
      --attempts)
        ATTEMPTS="${2:-}"
        shift 2
        ;;
      --delay)
        DELAY="${2:-}"
        shift 2
        ;;
      --timeout)
        TIMEOUT_SECONDS="${2:-}"
        shift 2
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

validate_inputs() {
  [ -n "$URL" ] || die "--url is required"

  [[ "$ATTEMPTS" =~ ^[0-9]+$ ]] || die "--attempts must be numeric"
  [[ "$DELAY" =~ ^[0-9]+$ ]] || die "--delay must be numeric"
  [[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || die "--timeout must be numeric"

  [ "$ATTEMPTS" -gt 0 ] || die "--attempts must be greater than 0"
  [ "$TIMEOUT_SECONDS" -gt 0 ] || die "--timeout must be greater than 0"
}

check_health() {
  if [ "$VERBOSE" = true ]; then
    timeout "${TIMEOUT_SECONDS}s" curl -vfsS "$URL" >/dev/null
  else
    timeout "${TIMEOUT_SECONDS}s" curl -fsS "$URL" >/dev/null
  fi
}

main() {
  parse_args "$@"
  validate_inputs

  require_command curl
  require_command timeout

  info "Starting health check"
  info "URL: $URL"
  info "Attempts: $ATTEMPTS"
  info "Delay: ${DELAY}s"
  info "Timeout: ${TIMEOUT_SECONDS}s"

  retry "$ATTEMPTS" "$DELAY" check_health

  info "Health check passed"
}

main "$@"
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/advanced-health-check.sh
```

Test with a local server:

```bash
python3 -m http.server 8080 &
SERVER_PID=$!

./03-linux-bash-networking/scripts/advanced-health-check.sh \
  --url http://127.0.0.1:8080 \
  --attempts 3 \
  --delay 1 \
  --timeout 2

kill "$SERVER_PID"
```

Test failure:

```bash
./03-linux-bash-networking/scripts/advanced-health-check.sh \
  --url http://127.0.0.1:9999 \
  --attempts 3 \
  --delay 1 \
  --timeout 2
```

---

# 25. Script Lab — Lock-Protected Backup Script

Create:

```bash
nano 03-linux-bash-networking/scripts/locked-backup.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SOURCE_PATH=""
BACKUP_ROOT="./backups"
LOCK_DIR="/tmp/locked-backup.lock"

usage() {
  cat <<EOF
Usage: $0 --source <path> [--backup-root <dir>]

Options:
  --source <path>       File or directory to back up
  --backup-root <dir>   Backup destination. Default: ./backups
  -h, --help            Show help

Example:
  $0 --source ./03-linux-bash-networking --backup-root ./backups
EOF
}

log() {
  local level="$1"
  shift
  echo "$(date -Is) [$level] $*"
}

info() {
  log "INFO" "$@"
}

error() {
  log "ERROR" "$@" >&2
}

die() {
  error "$@"
  exit 1
}

release_lock() {
  if [ -d "$LOCK_DIR" ]; then
    rm -rf "$LOCK_DIR"
    info "Released lock: $LOCK_DIR"
  fi
}

acquire_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    trap release_lock EXIT
    info "Acquired lock: $LOCK_DIR"
  else
    die "Another backup is already running"
  fi
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --source)
        SOURCE_PATH="${2:-}"
        [ -n "$SOURCE_PATH" ] || die "--source requires a value"
        shift 2
        ;;
      --backup-root)
        BACKUP_ROOT="${2:-}"
        [ -n "$BACKUP_ROOT" ] || die "--backup-root requires a value"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

validate_inputs() {
  [ -n "$SOURCE_PATH" ] || die "--source is required"
  [ -e "$SOURCE_PATH" ] || die "Source path does not exist: $SOURCE_PATH"
}

create_backup() {
  local source_abs
  local source_parent
  local source_name
  local timestamp
  local backup_file

  mkdir -p "$BACKUP_ROOT"

  source_abs="$(realpath "$SOURCE_PATH")"
  source_parent="$(dirname "$source_abs")"
  source_name="$(basename "$source_abs")"
  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup_file="$BACKUP_ROOT/${source_name}-${timestamp}.tar.gz"

  info "Creating backup"
  info "Source: $source_abs"
  info "Backup: $backup_file"

  tar -czf "$backup_file" -C "$source_parent" "$source_name"

  sha256sum "$backup_file" > "$backup_file.sha256"

  info "Backup created successfully"
  ls -lh "$backup_file" "$backup_file.sha256"
}

main() {
  parse_args "$@"
  validate_inputs
  acquire_lock
  create_backup
}

main "$@"
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/locked-backup.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/locked-backup.sh \
  --source 03-linux-bash-networking \
  --backup-root backups
```

Test lock behavior by running two copies quickly from two terminals.

---

# 26. Script Lab — Production-Style Service Deployment Validator

Create:

```bash
nano 03-linux-bash-networking/scripts/service-deploy-validator.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SERVICE=""
HEALTH_URL=""
ATTEMPTS=10
DELAY=3

usage() {
  cat <<EOF
Usage: $0 --service <service-name> --health-url <url> [options]

Options:
  --service <name>      systemd service name
  --health-url <url>    health endpoint URL
  --attempts <n>        health check attempts. Default: 10
  --delay <seconds>     delay between attempts. Default: 3
  -h, --help            show help

Example:
  $0 --service todo-api --health-url http://127.0.0.1:3000/health
EOF
}

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

die() {
  error "$@"
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --service)
        SERVICE="${2:-}"
        [ -n "$SERVICE" ] || die "--service requires a value"
        shift 2
        ;;
      --health-url)
        HEALTH_URL="${2:-}"
        [ -n "$HEALTH_URL" ] || die "--health-url requires a value"
        shift 2
        ;;
      --attempts)
        ATTEMPTS="${2:-}"
        shift 2
        ;;
      --delay)
        DELAY="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

validate_inputs() {
  [ -n "$SERVICE" ] || die "--service is required"
  [ -n "$HEALTH_URL" ] || die "--health-url is required"
  [[ "$ATTEMPTS" =~ ^[0-9]+$ ]] || die "--attempts must be numeric"
  [[ "$DELAY" =~ ^[0-9]+$ ]] || die "--delay must be numeric"
}

retry() {
  local attempts="$1"
  local delay="$2"
  shift 2

  local attempt=1

  until "$@"; do
    if [ "$attempt" -ge "$attempts" ]; then
      return 1
    fi

    warn "Attempt $attempt/$attempts failed. Retrying in ${delay}s..."
    sleep "$delay"
    attempt=$((attempt + 1))
  done
}

check_service_active() {
  info "Checking systemd service state: $SERVICE"

  if ! systemctl is-active --quiet "$SERVICE"; then
    systemctl status "$SERVICE" --no-pager || true
    journalctl -u "$SERVICE" -n 50 --no-pager || true
    die "Service is not active: $SERVICE"
  fi

  info "Service is active"
}

check_health() {
  curl -fsS "$HEALTH_URL" >/dev/null
}

show_service_summary() {
  info "Service summary"
  systemctl show "$SERVICE" \
    -p ActiveState \
    -p SubState \
    -p MainPID \
    -p Restart \
    -p User \
    -p Group \
    --no-pager || true
}

main() {
  parse_args "$@"
  validate_inputs

  require_command systemctl
  require_command journalctl
  require_command curl

  info "Starting deployment validation"
  info "Service: $SERVICE"
  info "Health URL: $HEALTH_URL"

  check_service_active
  show_service_summary

  info "Checking health endpoint"
  if retry "$ATTEMPTS" "$DELAY" check_health; then
    info "Health check passed"
  else
    journalctl -u "$SERVICE" -n 100 --no-pager || true
    die "Health check failed after $ATTEMPTS attempts"
  fi

  info "Deployment validation passed"
}

main "$@"
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/service-deploy-validator.sh
```

Example usage:

```bash
./03-linux-bash-networking/scripts/service-deploy-validator.sh \
  --service ssh \
  --health-url http://127.0.0.1:8080
```

For a real app later:

```bash
./service-deploy-validator.sh \
  --service todo-api \
  --health-url http://127.0.0.1:3000/health
```

This script is close to real deployment validation logic.

---

# 27. Script Lab — Parallel Service Checker

Create:

```bash
nano 03-linux-bash-networking/scripts/parallel-service-check.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <service1> [service2] ..." >&2
}

check_service() {
  local service="$1"

  if systemctl is-active --quiet "$service"; then
    echo "$(date -Is) [INFO] $service active"
    return 0
  else
    echo "$(date -Is) [ERROR] $service inactive" >&2
    return 1
  fi
}

main() {
  if [ "$#" -eq 0 ]; then
    usage
    exit 1
  fi

  local pids=()
  local failed=0

  for service in "$@"; do
    check_service "$service" &
    pids+=("$!")
  done

  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      failed=1
    fi
  done

  if [ "$failed" -ne 0 ]; then
    echo "$(date -Is) [ERROR] One or more services failed" >&2
    exit 1
  fi

  echo "$(date -Is) [INFO] All services active"
}

main "$@"
```

Make executable:

```bash
chmod +x 03-linux-bash-networking/scripts/parallel-service-check.sh
```

Run:

```bash
./03-linux-bash-networking/scripts/parallel-service-check.sh ssh
```

Try multiple services if installed:

```bash
./03-linux-bash-networking/scripts/parallel-service-check.sh ssh docker nginx
```

---

# 28. Advanced Bash Notes

Create:

```bash
nano 03-linux-bash-networking/advanced-bash-devops.md
```

Paste:

````markdown
# Advanced Bash for DevOps

## Production Bash Goals

Production Bash scripts should be:

- Safe
- Predictable
- Logged
- Validated
- Retry-aware
- Timeout-aware
- Lock-protected when needed
- Cleanup-safe
- ShellCheck clean

## Production Script Structure

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {}
log() {}
info() {}
warn() {}
error() {}
die() {}
require_command() {}
parse_args() {}
validate_inputs() {}
main() {}

main "$@"
````

## Important Patterns

### Logging

```bash
log() {
  local level="$1"
  shift
  echo "$(date -Is) [$level] $*"
}
```

### Failure

```bash
die() {
  error "$@"
  exit 1
}
```

### Required Commands

```bash
require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}
```

### Retry

```bash
retry 5 3 curl -fsS http://127.0.0.1:3000/health
```

### Timeout

```bash
timeout 5s curl -fsS http://127.0.0.1:3000/health
```

### Lock Directory

```bash
LOCK_DIR="/tmp/my-script.lock"
mkdir "$LOCK_DIR" || exit 1
trap 'rm -rf "$LOCK_DIR"' EXIT
```

### Cleanup Trap

```bash
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
```

## Rules

* Use dry-run by default for destructive scripts.
* Require explicit `--apply` or `--delete`.
* Avoid `eval`.
* Validate option values.
* Use retries for flaky network operations.
* Use timeouts for network calls.
* Use locks for backup/deploy/cleanup scripts.
* Never print secrets.
* Use ShellCheck.

````

---

# 29. Run ShellCheck

Install:

```bash
sudo apt update
sudo apt install -y shellcheck
````

Run:

```bash
find 03-linux-bash-networking/scripts -name "*.sh" -print0 | xargs -0 -r shellcheck
```

Fix any issues ShellCheck reports.

Common warnings:

```text
SC2086: Double quote to prevent globbing and word splitting
SC2155: Declare and assign separately to avoid masking return values
SC2034: Variable appears unused
```

ShellCheck is your Bash mentor.

---

# 30. Commit Work

```bash
git status
git diff
```

Add:

```bash
git add 03-linux-bash-networking/advanced-bash-devops.md \
        03-linux-bash-networking/scripts/advanced-health-check.sh \
        03-linux-bash-networking/scripts/locked-backup.sh \
        03-linux-bash-networking/scripts/service-deploy-validator.sh \
        03-linux-bash-networking/scripts/parallel-service-check.sh
```

Review:

```bash
git diff --staged
```

Commit:

```bash
git commit -m "docs: add advanced Bash DevOps patterns"
git push
```

---

# 31. Real Production Pattern — Deployment with Rollback Hook

A production deployment script often has these phases:

```text
Validate artifact
Create release directory
Extract artifact
Update symlink
Restart service
Run health check
Rollback if health check fails
```

Pseudo-script:

```bash
previous_release="$(readlink -f /opt/todo-api/current)"

ln -sfn "$new_release" /opt/todo-api/current
systemctl restart todo-api

if ! retry 10 3 curl -fsS http://127.0.0.1:3000/health; then
  echo "Health failed. Rolling back..." >&2
  ln -sfn "$previous_release" /opt/todo-api/current
  systemctl restart todo-api
  exit 1
fi
```

Key idea:

```text
A deployment script should know how to fail safely.
```

---

# 32. Real Production Pattern — Backup with Lock

Backup scripts should usually have:

```text
Lock
Timestamped backup
Checksum
Retention
Logs
Exit code
```

Why lock?

```text
Two backups running at the same time can corrupt output or overload disk.
```

Why checksum?

```text
You need to verify artifact integrity.
```

Why retention?

```text
Backups can fill disk.
```

---

# 33. Real Production Pattern — Cleanup with Dry Run

Cleanup script should usually behave like this:

```text
Default: show what would be deleted
With --delete: actually delete
```

Example:

```bash
./cleanup-old-logs.sh --target /var/log/myapp --days 14
```

Output:

```text
Dry run only. 120 files matched.
```

Actual deletion:

```bash
./cleanup-old-logs.sh --target /var/log/myapp --days 14 --delete
```

This prevents accidents.

---

# 34. Real Production Pattern — Retry Health Check After Restart

Bad:

```bash
systemctl restart todo-api
curl http://127.0.0.1:3000/health
```

The app may need time to start.

Better:

```bash
systemctl restart todo-api
retry 10 3 timeout 5s curl -fsS http://127.0.0.1:3000/health
```

This allows startup time but still fails if service does not become healthy.

---

# 35. Real Production Pattern — Time-Limited SSH Command

Bad:

```bash
ssh server "deploy"
```

If SSH hangs, CI hangs.

Better:

```bash
timeout 60s ssh -o BatchMode=yes -o ConnectTimeout=10 server "deploy"
```

Useful SSH options:

```text
BatchMode=yes       do not prompt for password
ConnectTimeout=10   fail connection attempt after 10 seconds
StrictHostKeyChecking=accept-new  accept new host key automatically, use carefully
```

CI/CD scripts should avoid indefinite hangs.

---

# 36. Common Advanced Bash Mistakes

## Mistake 1 — Using `eval`

Bad:

```bash
eval "$cmd"
```

Avoid unless absolutely necessary.

## Mistake 2 — No timeout

Bad:

```bash
curl http://service/health
```

Better:

```bash
timeout 5s curl -fsS http://service/health
```

## Mistake 3 — No lock

Bad:

```bash
backup.sh
```

from cron every hour, but previous run may still be active.

Better:

```bash
locked-backup.sh
```

## Mistake 4 — Destructive action by default

Bad:

```bash
cleanup.sh
```

deletes files immediately.

Better:

```bash
cleanup.sh
```

dry-run, and:

```bash
cleanup.sh --delete
```

deletes.

## Mistake 5 — Hiding all errors

Bad:

```bash
command >/dev/null 2>&1 || true
```

Use only when failure is expected and acceptable.

---

# 37. Interview Answers

Question:

```text
How do you make Bash scripts production-safe?
```

Strong answer:

```text
I use set -euo pipefail, validate all inputs, quote variables, log with timestamps, print errors to stderr, and use clear exit codes. For destructive actions, I use dry-run mode by default and require an explicit flag like --apply or --delete. I add retries for flaky network operations, timeouts for commands that may hang, locks for scripts that must not run concurrently, and traps for cleanup. I also run ShellCheck and avoid printing secrets.
```

Question:

```text
Why are retries and timeouts important?
```

Strong answer:

```text
Retries handle temporary failures such as slow service startup, network flakiness, or transient API errors. Timeouts prevent scripts from hanging forever on stuck commands like curl, ssh, or external API calls. Together, retries and timeouts make automation more reliable and predictable in CI/CD and production operations.
```

Question:

```text
Why use lock files in scripts?
```

Strong answer:

```text
Lock files prevent multiple instances of the same script from running at the same time. This is important for backups, deployments, cleanup jobs, and migrations because concurrent runs can corrupt output, delete files unexpectedly, overload the system, or create inconsistent state. A lock directory or flock can ensure only one instance runs.
```

Question:

```text
Why avoid eval in Bash?
```

Strong answer:

```text
eval re-parses a string as shell code, which can execute unintended commands and create injection risks. It is especially dangerous when the string contains user input, file names, or environment variables. I prefer passing commands and arguments as arrays or function arguments instead of building command strings.
```

---

# Today’s Core Rules

```text
Production Bash must fail safely.
Use structured script layout.
Use logging functions.
Use die for clear failures.
Validate option values.
Use dry-run by default for destructive scripts.
Use retries for temporary failures.
Use timeouts for commands that may hang.
Use lock files for non-concurrent scripts.
Use trap for cleanup.
Avoid eval.
Do not hide errors with || true unless intentional.
Never print secrets.
Run ShellCheck.
```

Next lesson:

# Lesson 3.14 — Bash Automation Project: Production Server Healthcheck Toolkit

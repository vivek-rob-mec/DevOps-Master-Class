# Lesson 3.14 — Bash Automation Project: Production Server Healthcheck Toolkit

Now we combine what we learned into a real mini-project.

We will build a **Production Server Healthcheck Toolkit** using Bash.

This toolkit will check:

```text
System identity
CPU and load
Memory and swap
Disk and inode usage
Top processes
Service status
Open ports
Recent errors from journald
Docker usage if Docker exists
Basic security checks
```

This is the kind of toolkit you can run:

```bash
./healthcheck.sh
```

or before/after deployment:

```bash
./healthcheck.sh --services ssh docker nginx --ports 22 80 443
```

or during incidents:

```bash
./healthcheck.sh --verbose
```

---

# 1. Project Goal

We are creating:

```text
03-linux-bash-networking/projects/server-healthcheck-toolkit/
```

Final structure:

```text
server-healthcheck-toolkit/
├── README.md
├── healthcheck.sh
├── lib/
│   ├── logging.sh
│   ├── checks.sh
│   └── utils.sh
├── reports/
│   └── .gitkeep
└── examples/
    └── sample-run.md
```

This project teaches:

```text
Production script structure
Reusable Bash libraries
Argument parsing
Logging
Health checks
Exit codes
Report generation
Defensive scripting
```

---

# 2. Create Project Directory

Run:

```bash
cd ~/devops-masterclass

mkdir -p 03-linux-bash-networking/projects/server-healthcheck-toolkit/{lib,reports,examples}

touch 03-linux-bash-networking/projects/server-healthcheck-toolkit/reports/.gitkeep
```

Move into project:

```bash
cd 03-linux-bash-networking/projects/server-healthcheck-toolkit
```

---

# 3. Toolkit Design

The main script will be:

```text
healthcheck.sh
```

It will call helper files:

```text
lib/logging.sh
lib/utils.sh
lib/checks.sh
```

Why split files?

```text
Cleaner code
Reusable functions
Easier debugging
Better project structure
More professional than one huge script
```

For small scripts, one file is fine.

For a toolkit, splitting is better.

---

# 4. Create Logging Library

Create:

```bash
nano lib/logging.sh
```

Paste:

```bash
#!/usr/bin/env bash

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

section() {
  echo
  echo "============================================================"
  echo "$*"
  echo "============================================================"
}

die() {
  error "$@"
  exit 1
}
```

Notice:

```text
This file does not use set -euo pipefail.
The main script will control strict mode.
```

---

# 5. Create Utility Library

Create:

```bash
nano lib/utils.sh
```

Paste:

```bash
#!/usr/bin/env bash

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_command() {
  local cmd="$1"

  if ! command_exists "$cmd"; then
    die "Required command not found: $cmd"
  fi
}

safe_run() {
  local description="$1"
  shift

  info "$description"

  if "$@"; then
    return 0
  else
    warn "Command failed: $*"
    return 1
  fi
}

print_command_output() {
  local title="$1"
  shift

  echo
  echo "--- $title ---"

  if "$@"; then
    true
  else
    warn "Failed to run: $*"
  fi
}

is_numeric() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}
```

This file gives reusable helper functions.

---

# 6. Create Checks Library

Create:

```bash
nano lib/checks.sh
```

Paste:

```bash
#!/usr/bin/env bash

check_system_identity() {
  section "System Identity"

  echo "Hostname: $(hostname)"
  echo "User: $(whoami)"
  echo "Date: $(date -Is)"
  echo "Kernel: $(uname -a)"

  if [ -f /etc/os-release ]; then
    echo
    echo "OS:"
    grep -E '^(NAME|VERSION)=' /etc/os-release || true
  fi
}

check_load_cpu() {
  section "CPU and Load"

  echo "CPU cores: $(nproc)"
  echo
  uptime
  echo

  print_command_output "Top CPU Processes" \
    ps -eo pid,ppid,user,stat,%cpu,%mem,etime,cmd --sort=-%cpu
}

check_memory() {
  section "Memory and Swap"

  free -h
  echo

  if command_exists swapon; then
    print_command_output "Swap Devices" swapon --show
  fi

  echo
  print_command_output "Top Memory Processes" \
    ps -eo pid,ppid,user,stat,%cpu,%mem,rss,etime,cmd --sort=-rss
}

check_disk() {
  section "Disk and Inodes"

  print_command_output "Filesystem Usage" df -h
  echo
  print_command_output "Inode Usage" df -i
}

check_mounts() {
  section "Mounts"

  if command_exists findmnt; then
    findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS
  else
    mount
  fi
}

check_failed_units() {
  section "Failed systemd Units"

  if command_exists systemctl; then
    systemctl --failed --no-pager || true
  else
    warn "systemctl not found"
  fi
}

check_services() {
  section "Service Status"

  if [ "${#SERVICES[@]}" -eq 0 ]; then
    warn "No services specified. Use --services ssh docker nginx"
    return 0
  fi

  local failed=0

  for service in "${SERVICES[@]}"; do
    echo
    echo "--- $service ---"

    if systemctl is-active --quiet "$service"; then
      echo "Active: yes"
    else
      echo "Active: no"
      failed=1
    fi

    if systemctl is-enabled --quiet "$service" 2>/dev/null; then
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
  done

  return "$failed"
}

check_ports() {
  section "Port Checks"

  if [ "${#PORTS[@]}" -eq 0 ]; then
    warn "No ports specified. Use --ports 22 80 443"
    return 0
  fi

  if ! command_exists ss; then
    warn "ss command not found"
    return 0
  fi

  local failed=0

  for port in "${PORTS[@]}"; do
    echo
    echo "--- Port $port ---"

    if sudo ss -tulnp 2>/dev/null | grep -q ":$port"; then
      sudo ss -tulnp 2>/dev/null | grep ":$port" || true
    else
      echo "No listener found on port $port"
      failed=1
    fi
  done

  return "$failed"
}

check_recent_errors() {
  section "Recent Journal Errors"

  if ! command_exists journalctl; then
    warn "journalctl not found"
    return 0
  fi

  journalctl --since "$SINCE" -p err --no-pager || true
}

check_oom_events() {
  section "OOM Killer Events"

  if command_exists journalctl; then
    journalctl -k --since "$SINCE" --no-pager 2>/dev/null \
      | grep -Ei "out of memory|oom|killed process" \
      || echo "No OOM events found since: $SINCE"
  else
    warn "journalctl not found"
  fi
}

check_deleted_open_files() {
  section "Deleted Open Files"

  if command_exists lsof; then
    sudo lsof +L1 2>/dev/null | head -50 || true
  else
    warn "lsof not installed"
  fi
}

check_docker() {
  section "Docker Check"

  if ! command_exists docker; then
    warn "Docker not installed"
    return 0
  fi

  docker --version || true
  echo

  if docker info >/dev/null 2>&1; then
    print_command_output "Docker Disk Usage" docker system df
    echo
    print_command_output "Running Containers" docker ps
  else
    warn "Docker exists but current user cannot access Docker daemon"
  fi
}

check_security_basics() {
  section "Basic Security Checks"

  echo "--- Current User ---"
  id
  echo

  echo "--- SSH Directory Permissions ---"
  if [ -d "$HOME/.ssh" ]; then
    ls -ld "$HOME/.ssh"
    ls -la "$HOME/.ssh" | sed -n '1,20p'
  else
    echo "No ~/.ssh directory found"
  fi

  echo
  echo "--- Users with sudo group ---"
  if getent group sudo >/dev/null; then
    getent group sudo
  else
    echo "sudo group not found"
  fi
}
```

This is our core library.

---

# 7. Create Main Script

Create:

```bash
nano healthcheck.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="$SCRIPT_DIR/reports"

# shellcheck source=lib/logging.sh
source "$SCRIPT_DIR/lib/logging.sh"

# shellcheck source=lib/utils.sh
source "$SCRIPT_DIR/lib/utils.sh"

# shellcheck source=lib/checks.sh
source "$SCRIPT_DIR/lib/checks.sh"

SERVICES=()
PORTS=()
SINCE="1 hour ago"
OUTPUT_FILE=""
VERBOSE=false
EXIT_ON_FAILURE=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --services <names...>       Services to check until next option
  --ports <ports...>          Ports to check until next option
  --since <time>              Journal time window. Default: "1 hour ago"
  --output <file>             Save report to file
  --verbose                   Enable verbose output
  --exit-on-failure           Return non-zero if service/port checks fail
  -h, --help                  Show help

Examples:
  ./healthcheck.sh
  ./healthcheck.sh --services ssh docker nginx
  ./healthcheck.sh --ports 22 80 443
  ./healthcheck.sh --services ssh docker --ports 22 2375 --since "30 minutes ago"
  ./healthcheck.sh --output reports/health-\$(date +%Y%m%d-%H%M%S).log
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --services)
        shift
        while [ "$#" -gt 0 ] && [[ "$1" != --* ]]; do
          SERVICES+=("$1")
          shift
        done
        ;;
      --ports)
        shift
        while [ "$#" -gt 0 ] && [[ "$1" != --* ]]; do
          PORTS+=("$1")
          shift
        done
        ;;
      --since)
        SINCE="${2:-}"
        [ -n "$SINCE" ] || die "--since requires a value"
        shift 2
        ;;
      --output)
        OUTPUT_FILE="${2:-}"
        [ -n "$OUTPUT_FILE" ] || die "--output requires a value"
        shift 2
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      --exit-on-failure)
        EXIT_ON_FAILURE=true
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
  for port in "${PORTS[@]}"; do
    is_numeric "$port" || die "Invalid port: $port"
  done

  mkdir -p "$REPORT_DIR"

  if [ -n "$OUTPUT_FILE" ]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")"
  fi
}

run_checks() {
  local failed=0

  section "Server Healthcheck Toolkit"
  echo "Started at: $(date -Is)"
  echo "Script directory: $SCRIPT_DIR"
  echo "Since window: $SINCE"
  echo "Services: ${SERVICES[*]:-none}"
  echo "Ports: ${PORTS[*]:-none}"

  check_system_identity
  check_load_cpu | head -80
  check_memory | head -100
  check_disk
  check_mounts | head -100
  check_failed_units

  check_services || failed=1
  check_ports || failed=1

  check_recent_errors | head -100
  check_oom_events
  check_deleted_open_files
  check_docker
  check_security_basics

  section "Healthcheck Summary"
  echo "Completed at: $(date -Is)"

  if [ "$failed" -ne 0 ]; then
    echo "Result: WARN - one or more service/port checks failed"
  else
    echo "Result: OK"
  fi

  return "$failed"
}

main() {
  parse_args "$@"
  validate_inputs

  require_command ps
  require_command df
  require_command free
  require_command uptime

  if [ -n "$OUTPUT_FILE" ]; then
    info "Writing report to: $OUTPUT_FILE"

    if run_checks > "$OUTPUT_FILE" 2>&1; then
      info "Report completed successfully"
      echo "$OUTPUT_FILE"
    else
      local status=$?
      warn "Report completed with warnings/failures"
      echo "$OUTPUT_FILE"

      if [ "$EXIT_ON_FAILURE" = true ]; then
        exit "$status"
      fi
    fi
  else
    if run_checks; then
      true
    else
      local status=$?

      if [ "$EXIT_ON_FAILURE" = true ]; then
        exit "$status"
      fi
    fi
  fi
}

main "$@"
```

Make executable:

```bash
chmod +x healthcheck.sh
```

---

# 8. Run Basic Healthcheck

From toolkit directory:

```bash
./healthcheck.sh
```

You should see sections like:

```text
System Identity
CPU and Load
Memory and Swap
Disk and Inodes
Mounts
Failed systemd Units
Service Status
Port Checks
Recent Journal Errors
OOM Killer Events
Docker Check
Basic Security Checks
Healthcheck Summary
```

This is already useful.

---

# 9. Run With Services

Example:

```bash
./healthcheck.sh --services ssh
```

Depending on your system, SSH service may be named:

```text
ssh
```

or:

```text
sshd
```

Try:

```bash
systemctl list-units --type=service | grep -Ei 'ssh|docker|nginx'
```

Then run:

```bash
./healthcheck.sh --services ssh docker nginx
```

If a service does not exist or is inactive, the toolkit will report it.

---

# 10. Run With Ports

Check common ports:

```bash
./healthcheck.sh --ports 22 80 443
```

If nothing listens on port 80 or 443, you may see:

```text
No listener found on port 80
```

Start a test HTTP server:

```bash
python3 -m http.server 8080 &
HTTP_PID=$!
```

Run:

```bash
./healthcheck.sh --ports 8080
```

Stop server:

```bash
kill "$HTTP_PID"
```

---

# 11. Save Report to File

Run:

```bash
./healthcheck.sh --output "reports/health-$(date +%Y%m%d-%H%M%S).log"
```

List reports:

```bash
ls -lh reports
```

View:

```bash
less reports/health-*.log
```

This is useful before and after deployments.

Example:

```bash
./healthcheck.sh --output reports/before-deploy.log
# deploy app
./healthcheck.sh --output reports/after-deploy.log
diff -u reports/before-deploy.log reports/after-deploy.log
```

---

# 12. Exit-on-Failure Mode

For CI/CD or deployment validation:

```bash
./healthcheck.sh --services ssh --ports 22 --exit-on-failure
```

If service or port check fails, script exits non-zero.

This is useful in Jenkins/GitHub Actions.

Example Jenkins stage:

```groovy
stage('Server Healthcheck') {
  steps {
    sh './healthcheck.sh --services todo-api nginx --ports 3000 80 --exit-on-failure'
  }
}
```

Example GitHub Actions step:

```yaml
- name: Run healthcheck
  run: |
    ./healthcheck.sh --services ssh --ports 22 --exit-on-failure
```

---

# 13. Add README

Create:

```bash
nano README.md
```

Paste:

````markdown
# Server Healthcheck Toolkit

A Bash-based production server healthcheck toolkit for Linux and DevOps practice.

## Purpose

This toolkit collects useful server health information:

- System identity
- CPU and load
- Memory and swap
- Disk and inode usage
- Mounts
- Failed systemd units
- Service status
- Open port checks
- Recent journald errors
- OOM killer events
- Deleted open files
- Docker disk usage
- Basic security checks

## Usage

```bash
./healthcheck.sh
````

Check services:

```bash
./healthcheck.sh --services ssh docker nginx
```

Check ports:

```bash
./healthcheck.sh --ports 22 80 443
```

Save report:

```bash
./healthcheck.sh --output "reports/health-$(date +%Y%m%d-%H%M%S).log"
```

Use in automation:

```bash
./healthcheck.sh --services ssh --ports 22 --exit-on-failure
```

## Options

| Option              | Description                               |
| ------------------- | ----------------------------------------- |
| `--services`        | List of systemd services to check         |
| `--ports`           | List of ports to check                    |
| `--since`           | Journal time window                       |
| `--output`          | Save report to file                       |
| `--verbose`         | Enable verbose mode                       |
| `--exit-on-failure` | Exit non-zero if service/port checks fail |
| `-h`, `--help`      | Show help                                 |

## Example

```bash
./healthcheck.sh \
  --services ssh docker nginx \
  --ports 22 80 443 \
  --since "30 minutes ago" \
  --output reports/prod-health.log
```

## Notes

Some checks use `sudo`, such as port process details and deleted open files. If sudo is not available, those checks may show limited output.

## Safety

The toolkit is read-only. It does not restart services, delete files, prune Docker resources, or modify system configuration.

````

---

# 14. Add Sample Run Notes

Create:

```bash
nano examples/sample-run.md
````

Paste:

````markdown
# Sample Healthcheck Run

## Basic Run

```bash
./healthcheck.sh
````

## Service and Port Check

```bash
./healthcheck.sh --services ssh docker --ports 22 2375
```

## Save Report

```bash
./healthcheck.sh --output reports/health-sample.log
```

## Deployment Usage

Before deployment:

```bash
./healthcheck.sh --output reports/before-deploy.log
```

After deployment:

```bash
./healthcheck.sh --output reports/after-deploy.log
```

Compare:

```bash
diff -u reports/before-deploy.log reports/after-deploy.log
```

## CI/CD Usage

```bash
./healthcheck.sh --services todo-api nginx --ports 3000 80 --exit-on-failure
```

````

---

# 15. Test the Toolkit

Run from toolkit directory:

```bash
./healthcheck.sh --help
````

Run basic:

```bash
./healthcheck.sh
```

Run with output:

```bash
./healthcheck.sh --output reports/test.log
```

Check report:

```bash
head -40 reports/test.log
```

Run service check:

```bash
./healthcheck.sh --services ssh
```

Run port check with test server:

```bash
python3 -m http.server 8080 &
HTTP_PID=$!

./healthcheck.sh --ports 8080

kill "$HTTP_PID"
```

---

# 16. Run ShellCheck

From repository root:

```bash
cd ~/devops-masterclass

find 03-linux-bash-networking/projects/server-healthcheck-toolkit -name "*.sh" -print0 | xargs -0 -r shellcheck
```

If ShellCheck complains about sourced files, the comments in `healthcheck.sh` help:

```bash
# shellcheck source=lib/logging.sh
source "$SCRIPT_DIR/lib/logging.sh"
```

If ShellCheck still cannot resolve paths, run from project directory:

```bash
cd 03-linux-bash-networking/projects/server-healthcheck-toolkit
shellcheck healthcheck.sh lib/*.sh
```

---

# 17. Important Fix: `head` with pipefail

In `healthcheck.sh`, these lines are useful but can sometimes behave unexpectedly with `pipefail`:

```bash
check_load_cpu | head -80
check_memory | head -100
check_mounts | head -100
check_recent_errors | head -100
```

Because `head` exits early, the producer command can receive SIGPIPE.

A safer simple approach is to remove `head` limits for now:

```bash
check_load_cpu
check_memory
check_mounts
check_recent_errors
```

So update `run_checks()` to:

```bash
run_checks() {
  local failed=0

  section "Server Healthcheck Toolkit"
  echo "Started at: $(date -Is)"
  echo "Script directory: $SCRIPT_DIR"
  echo "Since window: $SINCE"
  echo "Services: ${SERVICES[*]:-none}"
  echo "Ports: ${PORTS[*]:-none}"

  check_system_identity
  check_load_cpu
  check_memory
  check_disk
  check_mounts
  check_failed_units

  check_services || failed=1
  check_ports || failed=1

  check_recent_errors
  check_oom_events
  check_deleted_open_files
  check_docker
  check_security_basics

  section "Healthcheck Summary"
  echo "Completed at: $(date -Is)"

  if [ "$failed" -ne 0 ]; then
    echo "Result: WARN - one or more service/port checks failed"
  else
    echo "Result: OK"
  fi

  return "$failed"
}
```

This is more reliable for learning.

Later, we can implement a safe `limit_output` helper.

---

# 18. Add Safer Output Limiter

If you want output limits safely, add this to `lib/utils.sh`:

```bash
limit_output() {
  local max_lines="$1"
  shift

  local tmp_file
  tmp_file="$(mktemp)"

  if "$@" > "$tmp_file" 2>&1; then
    sed -n "1,${max_lines}p" "$tmp_file"
  else
    sed -n "1,${max_lines}p" "$tmp_file"
    rm -f "$tmp_file"
    return 1
  fi

  rm -f "$tmp_file"
}
```

Then you can use:

```bash
limit_output 100 check_memory || true
```

But for now, keeping full output is simpler.

---

# 19. Add GitHub Actions ShellCheck Workflow

Create from repo root:

```bash
cd ~/devops-masterclass
mkdir -p .github/workflows
nano .github/workflows/shellcheck.yml
```

Paste:

```yaml
name: ShellCheck

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read

jobs:
  shellcheck:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install ShellCheck
        run: sudo apt-get update && sudo apt-get install -y shellcheck

      - name: Run ShellCheck
        run: |
          find . -name "*.sh" -print0 | xargs -0 -r shellcheck
```

This makes your repo more professional.

---

# 20. Add Project Notes to Module

Create from repo root:

```bash
nano 03-linux-bash-networking/bash-automation-project.md
```

Paste:

````markdown
# Bash Automation Project: Server Healthcheck Toolkit

## Goal

Build a production-style Bash toolkit that collects server health information and can be used during deployments, incidents, and routine checks.

## Toolkit Checks

- System identity
- CPU and load
- Memory and swap
- Disk usage
- Inodes
- Mounts
- Failed systemd units
- Service status
- Port listeners
- Recent journal errors
- OOM events
- Deleted open files
- Docker usage
- Basic security checks

## Important Concepts Practiced

- `set -euo pipefail`
- `main "$@"`
- `source` libraries
- arrays
- option parsing
- reusable functions
- logging functions
- exit codes
- report generation
- ShellCheck
- read-only operational scripts

## Example Usage

```bash
./healthcheck.sh
./healthcheck.sh --services ssh docker nginx
./healthcheck.sh --ports 22 80 443
./healthcheck.sh --output reports/health.log
./healthcheck.sh --services todo-api nginx --ports 3000 80 --exit-on-failure
````

## Production Rule

A healthcheck toolkit should be read-only by default. It should collect evidence, not modify the server.

````

---

# 21. Commit the Project

Run:

```bash
cd ~/devops-masterclass

git status
````

Add:

```bash
git add 03-linux-bash-networking/projects/server-healthcheck-toolkit \
        03-linux-bash-networking/bash-automation-project.md \
        .github/workflows/shellcheck.yml
```

Review:

```bash
git diff --staged
```

Commit:

```bash
git commit -m "feat: add Bash server healthcheck toolkit"
```

Push:

```bash
git push
```

---

# 22. Real Production Usage Pattern

Before deployment:

```bash
./healthcheck.sh \
  --services todo-api nginx \
  --ports 3000 80 \
  --output reports/before-deploy.log \
  --exit-on-failure
```

Deploy:

```bash
sudo systemctl restart todo-api
```

After deployment:

```bash
./healthcheck.sh \
  --services todo-api nginx \
  --ports 3000 80 \
  --output reports/after-deploy.log \
  --exit-on-failure
```

Compare:

```bash
diff -u reports/before-deploy.log reports/after-deploy.log
```

This gives evidence:

```text
Was service active before?
Is it active after?
Was port listening before?
Is it listening after?
Did new journal errors appear?
Did OOM happen?
Did disk become full?
```

---

# 23. What Makes This Toolkit Professional?

Because it is:

```text
Read-only
Modular
ShellCheck-compatible
Argument-driven
Report-capable
CI/CD-friendly
Useful during incidents
Useful before and after deployment
Built with safe Bash practices
```

This is no longer random Bash practice.

This is a real DevOps utility.

---

# 24. Possible Future Improvements

Later, you can improve it with:

```text
JSON output mode
HTML report
Slack notification
Email report
Threshold-based warnings
CPU/load thresholds
Disk usage threshold
Memory threshold
Service-specific health URLs
Docker container health checks
Kubernetes node checks
Prometheus node exporter comparison
```

Example future command:

```bash
./healthcheck.sh \
  --services todo-api nginx \
  --ports 3000 80 \
  --disk-threshold 85 \
  --memory-threshold 90 \
  --format json
```

We will revisit this idea later in Observability and SRE modules.

---

# 25. Interview Explanation

Question:

```text
Tell me about a Bash automation project you built.
```

Strong answer:

```text
I built a Linux server healthcheck toolkit in Bash. It collects system identity, CPU and load, memory and swap, disk and inode usage, failed systemd units, service states, port listeners, recent journal errors, OOM killer events, deleted open files, Docker disk usage, and basic security checks. The script is modular, uses reusable libraries, supports service and port arguments, can write reports to files, and can exit non-zero for CI/CD validation. I used safe Bash practices such as set -euo pipefail, quoted variables, input validation, logging functions, and ShellCheck.
```

Question:

```text
How would you use this during deployment?
```

Strong answer:

```text
I would run the healthcheck before deployment and save a report, then deploy the application, run the healthcheck again, and compare the before and after reports. I would check that the expected services are active, required ports are listening, disk and memory are healthy, and no new journal errors or OOM events appeared. In CI/CD, I would use exit-on-failure mode to fail the pipeline if critical services or ports are not healthy.
```

---

# Today’s Core Rules

```text
A good operational script should collect evidence safely.
Healthcheck tools should be read-only.
Use modular Bash for larger scripts.
Use functions instead of repeated command blocks.
Use arrays for service and port lists.
Use reports for before/after comparisons.
Use non-zero exit codes for CI/CD.
Run ShellCheck.
Never let a healthcheck modify production state.
```

Next lesson:

# Lesson 3.15 — Networking Foundation: IP addresses, ports, protocols, DNS, TCP/UDP, routing, firewalls, and Linux network commands.

# Module 4 — Python for DevOps Automation

# Lesson 4.1 — Python for DevOps Foundation

Now we start Python.

You already learned Bash.

Bash is excellent when your automation is mostly Linux commands.

Python is better when automation needs:

```text
structured logic
JSON/YAML parsing
API calls
cloud automation
file processing
report generation
error handling
reusable functions
testing
larger scripts
```

In DevOps, Bash and Python are not enemies.

They are used together.

```text
Bash = command glue
Python = automation logic
```

---

# 1. Why Python for DevOps?

Python is widely used in DevOps, SRE, Platform Engineering, Cloud Automation, and Security Automation.

Common use cases:

```text
AWS/GCP/Azure automation
Kubernetes scripts
CI/CD helper tools
log parsers
healthcheck tools
backup automation
inventory generation
Terraform output parsing
Ansible dynamic inventory
Slack/Email notifications
GitHub API automation
monitoring scripts
incident report generators
JSON/YAML config validation
```

Example:

Bash is good for:

```bash
df -h
systemctl status nginx
curl -fsS http://localhost/health
```

Python is better for:

```text
Read 100 servers from YAML
Call each health endpoint
Collect JSON responses
Retry failed checks
Generate a report
Send summary to Slack
Exit non-zero if critical services fail
```

---

# 2. Bash vs Python Decision Rule

Use **Bash** when:

```text
You are mostly running shell commands.
The script is short.
The logic is simple.
You are working directly with Linux tools.
```

Use **Python** when:

```text
You need structured data.
You need JSON/YAML.
You need APIs.
You need complex conditions.
You need reusable modules.
You need testing.
You need cross-platform behavior.
You need better error handling.
```

Simple rule:

```text
If the script is mostly commands, use Bash.
If the script is mostly logic, use Python.
```

Example Bash:

```bash
#!/usr/bin/env bash
set -euo pipefail

systemctl is-active --quiet nginx
curl -fsS http://127.0.0.1/health
```

Example Python:

```python
#!/usr/bin/env python3

import requests

services = [
    {"name": "frontend", "url": "http://127.0.0.1/"},
    {"name": "backend", "url": "http://127.0.0.1:3000/health"},
]

for service in services:
    response = requests.get(service["url"], timeout=5)
    print(service["name"], response.status_code)
```

---

# 3. Python DevOps Mental Model

A Python DevOps script usually follows this structure:

```text
Input
  ↓
Validate
  ↓
Process
  ↓
Call system/API
  ↓
Handle errors
  ↓
Output result
  ↓
Exit code
```

Example:

```text
Input:
  config.yaml

Validate:
  required fields exist

Process:
  loop over services

Call:
  HTTP health check

Handle errors:
  timeout, connection error, non-200 response

Output:
  table/report/json

Exit:
  0 if healthy
  1 if unhealthy
```

This is the same operational thinking you learned in Bash, but with stronger programming tools.

---

# 4. Check Python Version

Run:

```bash
python3 --version
```

Also:

```bash
which python3
```

Example:

```text
Python 3.12.3
/usr/bin/python3
```

Check pip:

```bash
python3 -m pip --version
```

If pip is missing:

```bash
sudo apt update
sudo apt install -y python3-pip python3-venv
```

Important:

```text
Use python3 -m pip instead of plain pip.
```

Why?

```text
It ensures pip belongs to the Python interpreter you are using.
```

Good:

```bash
python3 -m pip install requests
```

Less reliable:

```bash
pip install requests
```

---

# 5. Python Virtual Environments

A virtual environment isolates Python packages for a project.

Without venv:

```text
Packages install globally.
Versions can conflict.
System Python can become messy.
```

With venv:

```text
Project has its own dependencies.
You can reproduce the environment.
You avoid breaking system Python.
```

Create project directory:

```bash
cd ~/devops-masterclass
mkdir -p 04-python-devops-automation
cd 04-python-devops-automation
```

Create venv:

```bash
python3 -m venv .venv
```

Activate:

```bash
source .venv/bin/activate
```

Your prompt may show:

```text
(.venv)
```

Check Python:

```bash
which python
python --version
```

Expected:

```text
~/devops-masterclass/04-python-devops-automation/.venv/bin/python
```

Upgrade pip:

```bash
python -m pip install --upgrade pip
```

Deactivate:

```bash
deactivate
```

Reactivate later:

```bash
cd ~/devops-masterclass/04-python-devops-automation
source .venv/bin/activate
```

---

# 6. Create Python Module Structure

Inside:

```bash
cd ~/devops-masterclass/04-python-devops-automation
```

Create folders:

```bash
mkdir -p scripts configs data reports notes tests
touch reports/.gitkeep
```

Structure:

```text
04-python-devops-automation/
├── .venv/
├── scripts/
├── configs/
├── data/
├── reports/
├── notes/
└── tests/
```

Add `.gitignore` later:

```bash
nano .gitignore
```

Paste:

```gitignore
.venv/
__pycache__/
*.pyc
.env
.env.*
reports/*.json
reports/*.log
reports/*.html
```

Important:

```text
Do not commit .venv.
Do not commit real .env files.
```

---

# 7. Your First Python DevOps Script

Create:

```bash
nano scripts/system_info.py
```

Paste:

```python
#!/usr/bin/env python3

import os
import platform
import socket
from datetime import datetime, timezone


def main() -> int:
    print("===== Python DevOps System Info =====")
    print(f"Time UTC: {datetime.now(timezone.utc).isoformat()}")
    print(f"Hostname: {socket.gethostname()}")
    print(f"User: {os.getenv('USER', 'unknown')}")
    print(f"OS: {platform.system()} {platform.release()}")
    print(f"Python: {platform.python_version()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Make executable:

```bash
chmod +x scripts/system_info.py
```

Run:

```bash
./scripts/system_info.py
```

or:

```bash
python scripts/system_info.py
```

Important structure:

```python
def main() -> int:
    ...
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Why this is good:

```text
main() keeps code organized.
return 0 means success.
raise SystemExit() uses the return code as process exit code.
```

---

# 8. Python Exit Codes

Just like Bash:

```text
0     success
non-0 failure
```

Example:

```python
return 0
```

means success.

```python
return 1
```

means failure.

Create:

```bash
nano scripts/exit_code_demo.py
```

Paste:

```python
#!/usr/bin/env python3

import sys


def main() -> int:
    if len(sys.argv) < 2:
        print("ERROR: missing argument", file=sys.stderr)
        return 1

    print(f"Argument received: {sys.argv[1]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
chmod +x scripts/exit_code_demo.py
./scripts/exit_code_demo.py
echo $?
```

Expected:

```text
ERROR: missing argument
1
```

Run with argument:

```bash
./scripts/exit_code_demo.py hello
echo $?
```

Expected:

```text
Argument received: hello
0
```

This matters in:

```text
Jenkins
GitHub Actions
cron
systemd
deployment scripts
monitoring scripts
```

---

# 9. stdout and stderr in Python

Normal output:

```python
print("normal output")
```

Error output:

```python
print("ERROR: something failed", file=sys.stderr)
```

Example:

```python
import sys

print("Report generated")
print("ERROR: failed to connect", file=sys.stderr)
```

Why it matters:

```bash
python script.py > output.log 2> error.log
```

DevOps scripts should write errors to stderr.

---

# 10. Command-Line Arguments with argparse

`argparse` is the standard way to build Python CLIs.

Create:

```bash
nano scripts/hello_cli.py
```

Paste:

```python
#!/usr/bin/env python3

import argparse


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Simple Python CLI demo for DevOps automation."
    )

    parser.add_argument(
        "--name",
        default="DevOps Engineer",
        help="Name to greet",
    )

    parser.add_argument(
        "--uppercase",
        action="store_true",
        help="Print greeting in uppercase",
    )

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    message = f"Hello, {args.name}"

    if args.uppercase:
        message = message.upper()

    print(message)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
chmod +x scripts/hello_cli.py
./scripts/hello_cli.py
./scripts/hello_cli.py --name Vivek
./scripts/hello_cli.py --name Vivek --uppercase
./scripts/hello_cli.py --help
```

This is already better than manual `sys.argv` parsing.

---

# 11. Python pathlib

Use `pathlib` for file paths.

Bad old style:

```python
import os

path = os.path.join("configs", "services.json")
```

Modern style:

```python
from pathlib import Path

path = Path("configs") / "services.json"
```

Create:

```bash
nano scripts/pathlib_demo.py
```

Paste:

```python
#!/usr/bin/env python3

from pathlib import Path


def main() -> int:
    project_dir = Path(__file__).resolve().parents[1]
    config_dir = project_dir / "configs"
    report_dir = project_dir / "reports"

    print(f"Script: {Path(__file__).resolve()}")
    print(f"Project dir: {project_dir}")
    print(f"Config dir: {config_dir}")
    print(f"Report dir: {report_dir}")

    report_dir.mkdir(parents=True, exist_ok=True)

    output_file = report_dir / "pathlib-demo.txt"
    output_file.write_text("Hello from pathlib\n", encoding="utf-8")

    print(f"Wrote: {output_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
chmod +x scripts/pathlib_demo.py
./scripts/pathlib_demo.py
cat reports/pathlib-demo.txt
```

Important pattern:

```python
Path(__file__).resolve().parents[1]
```

This finds the project directory relative to the script location.

---

# 12. Reading and Writing JSON

JSON is everywhere in DevOps:

```text
AWS CLI output
Kubernetes API
Terraform output
GitHub API
Docker inspect
Monitoring APIs
Application health endpoints
```

Create config:

```bash
nano configs/services.json
```

Paste:

```json
{
  "services": [
    {
      "name": "local-demo",
      "url": "http://127.0.0.1:8080/health",
      "expected_status": 200
    },
    {
      "name": "github",
      "url": "https://github.com",
      "expected_status": 200
    }
  ]
}
```

Create script:

```bash
nano scripts/read_json.py
```

Paste:

```python
#!/usr/bin/env python3

import json
from pathlib import Path


def main() -> int:
    project_dir = Path(__file__).resolve().parents[1]
    config_file = project_dir / "configs" / "services.json"

    with config_file.open("r", encoding="utf-8") as file:
        config = json.load(file)

    services = config.get("services", [])

    for service in services:
        print(f"{service['name']} -> {service['url']} expected={service['expected_status']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
chmod +x scripts/read_json.py
./scripts/read_json.py
```

---

# 13. Writing JSON Reports

Create:

```bash
nano scripts/write_json_report.py
```

Paste:

```python
#!/usr/bin/env python3

import json
import socket
from datetime import datetime, timezone
from pathlib import Path


def main() -> int:
    project_dir = Path(__file__).resolve().parents[1]
    report_dir = project_dir / "reports"
    report_dir.mkdir(parents=True, exist_ok=True)

    report = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "hostname": socket.gethostname(),
        "status": "ok",
        "checks": [
            {"name": "disk", "status": "ok"},
            {"name": "memory", "status": "ok"},
        ],
    }

    output_file = report_dir / "sample-report.json"

    with output_file.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)

    print(f"Wrote report: {output_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
chmod +x scripts/write_json_report.py
./scripts/write_json_report.py
cat reports/sample-report.json | jq .
```

---

# 14. YAML in Python

YAML is common in:

```text
Kubernetes manifests
Docker Compose
GitHub Actions
Ansible
Helm values
Config files
```

Python standard library does not include YAML.

Install PyYAML:

```bash
source .venv/bin/activate
python -m pip install pyyaml
```

Create requirements file:

```bash
python -m pip freeze > requirements.txt
```

Check:

```bash
cat requirements.txt
```

Create YAML config:

```bash
nano configs/services.yaml
```

Paste:

```yaml
services:
  - name: local-demo
    url: http://127.0.0.1:8080/health
    expected_status: 200

  - name: github
    url: https://github.com
    expected_status: 200
```

Create script:

```bash
nano scripts/read_yaml.py
```

Paste:

```python
#!/usr/bin/env python3

from pathlib import Path
import yaml


def main() -> int:
    project_dir = Path(__file__).resolve().parents[1]
    config_file = project_dir / "configs" / "services.yaml"

    with config_file.open("r", encoding="utf-8") as file:
        config = yaml.safe_load(file)

    for service in config.get("services", []):
        print(f"{service['name']} -> {service['url']} expected={service['expected_status']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
chmod +x scripts/read_yaml.py
./scripts/read_yaml.py
```

Important:

```python
yaml.safe_load(file)
```

Use `safe_load`, not unsafe loaders.

---

# 15. HTTP Requests with requests

Install:

```bash
python -m pip install requests
python -m pip freeze > requirements.txt
```

Create:

```bash
nano scripts/http_health_check.py
```

Paste:

```python
#!/usr/bin/env python3

import argparse
import sys
from dataclasses import dataclass
from typing import Optional

import requests


@dataclass
class HealthResult:
    url: str
    expected_status: int
    actual_status: Optional[int]
    ok: bool
    error: Optional[str]


def check_url(url: str, expected_status: int, timeout: int) -> HealthResult:
    try:
        response = requests.get(url, timeout=timeout)
        return HealthResult(
            url=url,
            expected_status=expected_status,
            actual_status=response.status_code,
            ok=response.status_code == expected_status,
            error=None,
        )
    except requests.RequestException as exc:
        return HealthResult(
            url=url,
            expected_status=expected_status,
            actual_status=None,
            ok=False,
            error=str(exc),
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="HTTP health check script.")
    parser.add_argument("--url", required=True, help="URL to check")
    parser.add_argument("--expected-status", type=int, default=200)
    parser.add_argument("--timeout", type=int, default=5)
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    result = check_url(
        url=args.url,
        expected_status=args.expected_status,
        timeout=args.timeout,
    )

    print(f"URL: {result.url}")
    print(f"Expected: {result.expected_status}")
    print(f"Actual: {result.actual_status}")
    print(f"OK: {result.ok}")

    if result.error:
        print(f"ERROR: {result.error}", file=sys.stderr)

    return 0 if result.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
chmod +x scripts/http_health_check.py
./scripts/http_health_check.py --url https://github.com --expected-status 200
echo $?
```

Test failure:

```bash
./scripts/http_health_check.py --url http://127.0.0.1:9999 --expected-status 200
echo $?
```

This script is CI/CD usable because it exits non-zero on failure.

---

# 16. dataclass

We used:

```python
from dataclasses import dataclass
```

A dataclass is a clean way to represent structured data.

Example:

```python
@dataclass
class HealthResult:
    url: str
    expected_status: int
    actual_status: Optional[int]
    ok: bool
    error: Optional[str]
```

Instead of returning a random dictionary:

```python
return {
    "url": url,
    "ok": True,
}
```

dataclass gives more structure and readability.

Useful for DevOps reports:

```text
HealthResult
ServerInfo
DiskCheck
ServiceStatus
DeploymentResult
BackupResult
```

---

# 17. subprocess — Running Linux Commands from Python

Python can run shell commands using `subprocess`.

Important rule:

```text
Avoid shell=True unless necessary.
```

Good:

```python
subprocess.run(["df", "-h"], check=True)
```

Riskier:

```python
subprocess.run("df -h", shell=True)
```

Create:

```bash
nano scripts/subprocess_demo.py
```

Paste:

```python
#!/usr/bin/env python3

import subprocess
import sys


def run_command(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        text=True,
        capture_output=True,
        check=False,
    )


def main() -> int:
    commands = [
        ["hostname"],
        ["uptime"],
        ["df", "-h"],
        ["free", "-h"],
    ]

    for command in commands:
        print()
        print("=" * 60)
        print(" ".join(command))
        print("=" * 60)

        result = run_command(command)

        if result.stdout:
            print(result.stdout)

        if result.stderr:
            print(result.stderr, file=sys.stderr)

        if result.returncode != 0:
            print(f"ERROR: command failed with exit code {result.returncode}", file=sys.stderr)
            return result.returncode

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
chmod +x scripts/subprocess_demo.py
./scripts/subprocess_demo.py
```

---

# 18. subprocess with timeout

Commands can hang.

Use timeout:

```python
subprocess.run(command, timeout=10)
```

Create:

```bash
nano scripts/command_timeout_demo.py
```

Paste:

```python
#!/usr/bin/env python3

import subprocess
import sys


def main() -> int:
    command = ["sleep", "10"]

    try:
        print("Running command with 2-second timeout...")
        subprocess.run(command, timeout=2, check=True)
    except subprocess.TimeoutExpired:
        print("ERROR: command timed out", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as exc:
        print(f"ERROR: command failed: {exc}", file=sys.stderr)
        return exc.returncode

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
chmod +x scripts/command_timeout_demo.py
./scripts/command_timeout_demo.py
echo $?
```

Expected:

```text
ERROR: command timed out
1
```

This is the Python equivalent of Bash `timeout`.

---

# 19. Logging in Python

For quick scripts, `print()` is okay.

For serious automation, use `logging`.

Create:

```bash
nano scripts/logging_demo.py
```

Paste:

```python
#!/usr/bin/env python3

import logging


def configure_logging(verbose: bool = False) -> None:
    level = logging.DEBUG if verbose else logging.INFO

    logging.basicConfig(
        level=level,
        format="%(asctime)s %(levelname)s %(message)s",
    )


def main() -> int:
    configure_logging(verbose=True)

    logging.debug("Debug details")
    logging.info("Starting automation")
    logging.warning("This is a warning")
    logging.error("This is an error")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
chmod +x scripts/logging_demo.py
./scripts/logging_demo.py
```

Logging levels:

```text
DEBUG
INFO
WARNING
ERROR
CRITICAL
```

Production rule:

```text
Use logging for automation that may run in CI/CD, cron, or systemd.
```

---

# 20. Environment Variables

DevOps scripts often read environment variables.

Example:

```bash
export APP_ENV=dev
```

Python:

```python
import os

app_env = os.getenv("APP_ENV", "dev")
```

Required env var pattern:

```python
value = os.getenv("DATABASE_URL")
if not value:
    raise RuntimeError("DATABASE_URL is required")
```

Create:

```bash
nano scripts/env_demo.py
```

Paste:

```python
#!/usr/bin/env python3

import os
import sys


def get_required_env(name: str) -> str:
    value = os.getenv(name)

    if not value:
        raise ValueError(f"{name} is required")

    return value


def main() -> int:
    app_env = os.getenv("APP_ENV", "dev")
    print(f"APP_ENV={app_env}")

    try:
        api_url = get_required_env("API_URL")
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print("API_URL is configured")
    print(f"API_URL={api_url}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run failure:

```bash
chmod +x scripts/env_demo.py
./scripts/env_demo.py
```

Run success:

```bash
API_URL=https://example.com ./scripts/env_demo.py
```

Security note:

```text
Do not print secrets like DATABASE_URL, tokens, or private keys.
```

For real secrets, print only:

```text
DATABASE_URL is configured
```

not the value.

---

# 21. Build a Small Config-Driven Health Checker

Now combine:

```text
argparse
pathlib
YAML
requests
JSON report
exit codes
```

Create:

```bash
nano scripts/config_health_checker.py
```

Paste:

```python
#!/usr/bin/env python3

import argparse
import json
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import requests
import yaml


@dataclass
class CheckResult:
    name: str
    url: str
    expected_status: int
    actual_status: Optional[int]
    ok: bool
    error: Optional[str]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Config-driven HTTP health checker."
    )

    parser.add_argument(
        "--config",
        default="configs/services.yaml",
        help="Path to YAML config file",
    )

    parser.add_argument(
        "--output",
        default="reports/health-report.json",
        help="Path to JSON report output",
    )

    parser.add_argument(
        "--timeout",
        type=int,
        default=5,
        help="HTTP timeout in seconds",
    )

    return parser.parse_args()


def load_config(config_path: Path) -> dict:
    if not config_path.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")

    with config_path.open("r", encoding="utf-8") as file:
        data = yaml.safe_load(file)

    if not isinstance(data, dict):
        raise ValueError("Config must be a YAML object")

    if "services" not in data:
        raise ValueError("Config must contain 'services'")

    if not isinstance(data["services"], list):
        raise ValueError("'services' must be a list")

    return data


def check_service(service: dict, timeout: int) -> CheckResult:
    name = service.get("name")
    url = service.get("url")
    expected_status = service.get("expected_status", 200)

    if not name or not url:
        return CheckResult(
            name=str(name),
            url=str(url),
            expected_status=int(expected_status),
            actual_status=None,
            ok=False,
            error="service requires name and url",
        )

    try:
        response = requests.get(url, timeout=timeout)
        return CheckResult(
            name=name,
            url=url,
            expected_status=int(expected_status),
            actual_status=response.status_code,
            ok=response.status_code == int(expected_status),
            error=None,
        )
    except requests.RequestException as exc:
        return CheckResult(
            name=name,
            url=url,
            expected_status=int(expected_status),
            actual_status=None,
            ok=False,
            error=str(exc),
        )


def write_report(output_path: Path, results: list[CheckResult]) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    report = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "summary": {
            "total": len(results),
            "ok": sum(1 for result in results if result.ok),
            "failed": sum(1 for result in results if not result.ok),
        },
        "results": [asdict(result) for result in results],
    }

    with output_path.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)


def print_summary(results: list[CheckResult]) -> None:
    print("===== Health Check Summary =====")

    for result in results:
        status = "OK" if result.ok else "FAIL"
        print(
            f"{status:4} {result.name:20} "
            f"expected={result.expected_status} actual={result.actual_status} url={result.url}"
        )

        if result.error:
            print(f"     error={result.error}", file=sys.stderr)

    total = len(results)
    failed = sum(1 for result in results if not result.ok)

    print()
    print(f"Total: {total}")
    print(f"Failed: {failed}")


def main() -> int:
    args = parse_args()

    project_dir = Path(__file__).resolve().parents[1]
    config_path = Path(args.config)
    output_path = Path(args.output)

    if not config_path.is_absolute():
        config_path = project_dir / config_path

    if not output_path.is_absolute():
        output_path = project_dir / output_path

    try:
        config = load_config(config_path)
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    results = [
        check_service(service, timeout=args.timeout)
        for service in config["services"]
    ]

    write_report(output_path, results)
    print_summary(results)

    print()
    print(f"Report written: {output_path}")

    return 0 if all(result.ok for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
chmod +x scripts/config_health_checker.py
./scripts/config_health_checker.py
echo $?
```

View report:

```bash
cat reports/health-report.json | jq .
```

If local demo on `127.0.0.1:8080` is not running, that check may fail. That is okay.

---

# 22. Add GitHub Actions for Python Lint-Free Smoke Test

For now, we add a simple workflow that checks Python scripts can compile.

Create:

```bash
cd ~/devops-masterclass
nano .github/workflows/python-smoke.yml
```

Paste:

```yaml
name: Python Smoke Test

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
  python-smoke:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Compile Python files
        run: |
          python -m compileall 04-python-devops-automation
```

This catches syntax errors.

Later we add:

```text
ruff
mypy
pytest
bandit
```

---

# 23. Add Notes File

Create:

```bash
nano notes/python-devops-foundation.md
```

Paste:

````markdown
# Python for DevOps Foundation

## When to Use Python

Use Python when automation needs:

- JSON/YAML parsing
- API calls
- complex logic
- reusable functions
- reports
- testing
- cloud SDKs
- Kubernetes/client libraries

Use Bash when the script is mostly shell commands.

## Virtual Environment

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
````

## Python CLI Pattern

```python
def main() -> int:
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
```

## Important Libraries

| Library       | Purpose                        |
| ------------- | ------------------------------ |
| `argparse`    | CLI arguments                  |
| `pathlib`     | file paths                     |
| `json`        | JSON read/write                |
| `yaml`        | YAML read/write through PyYAML |
| `requests`    | HTTP API calls                 |
| `subprocess`  | run system commands            |
| `logging`     | structured logs                |
| `dataclasses` | structured result objects      |

## Rules

* Use virtual environments.
* Do not commit `.venv`.
* Use `python -m pip`.
* Use `argparse` for CLIs.
* Use `pathlib` for paths.
* Use `yaml.safe_load`.
* Use timeouts for HTTP requests and subprocesses.
* Avoid `shell=True` unless needed.
* Print errors to stderr.
* Return proper exit codes.
* Do not print secrets.

````

---

# 24. requirements.txt

Make sure your venv is active:

```bash
cd ~/devops-masterclass/04-python-devops-automation
source .venv/bin/activate
````

Install required packages:

```bash
python -m pip install requests pyyaml
```

Generate:

```bash
python -m pip freeze > requirements.txt
```

Check:

```bash
cat requirements.txt
```

Later, in CI/CD or another machine:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

---

# 25. Test Everything

From:

```bash
cd ~/devops-masterclass/04-python-devops-automation
source .venv/bin/activate
```

Run:

```bash
python scripts/system_info.py
python scripts/hello_cli.py --name Vivek
python scripts/pathlib_demo.py
python scripts/read_json.py
python scripts/write_json_report.py
python scripts/read_yaml.py
python scripts/http_health_check.py --url https://github.com --expected-status 200
python scripts/subprocess_demo.py
python scripts/logging_demo.py
python scripts/config_health_checker.py
```

Compile all Python files:

```bash
python -m compileall .
```

---

# 26. Commit Work

From repo root:

```bash
cd ~/devops-masterclass

git status
```

Add:

```bash
git add 04-python-devops-automation \
        .github/workflows/python-smoke.yml
```

Review:

```bash
git diff --staged
```

Commit:

```bash
git commit -m "feat: add Python DevOps foundation"
```

Push:

```bash
git push
```

---

# 27. Interview Explanation

Question:

```text
Why do DevOps engineers use Python?
```

Strong answer:

```text
DevOps engineers use Python for automation that requires structured logic, APIs, JSON/YAML parsing, cloud SDKs, report generation, and testing. Bash is great for command glue, but Python is better for larger automation workflows where error handling, data structures, and maintainability matter.
```

Question:

```text
How do you structure a Python DevOps script?
```

Strong answer:

```text
I usually structure it with argparse for CLI arguments, pathlib for file paths, functions for each operation, clear exception handling, logging or stderr for errors, proper exit codes, and a main() function that returns an integer. I also use virtual environments and requirements.txt for dependency management.
```

Question:

```text
How do you safely run shell commands from Python?
```

Strong answer:

```text
I use subprocess.run with a list of arguments rather than shell=True. I set capture_output and text when I need output, check return codes, and use timeout to avoid hanging commands. I avoid shell=True unless absolutely necessary because it can introduce quoting and injection risks.
```

Question:

```text
How do you handle HTTP checks in Python?
```

Strong answer:

```text
I use the requests library with a timeout, catch requests.RequestException, compare the actual status code with the expected status, and return a clear result object. For CI/CD usage, the script exits 0 when all checks pass and non-zero when any critical check fails.
```

---

# Today’s Core Rules

```text
Use Bash for command-heavy automation.
Use Python for logic-heavy automation.
Always use virtual environments.
Do not commit .venv.
Use python -m pip.
Use argparse for CLI scripts.
Use pathlib for paths.
Use json and yaml safely.
Use requests with timeout.
Use subprocess without shell=True by default.
Use proper exit codes.
Print errors to stderr.
Do not print secrets.
```

Next lesson:

# Lesson 4.2 — Python Project Structure for DevOps: packages, modules, config loaders, logging setup, exceptions, reusable utilities, and tests.

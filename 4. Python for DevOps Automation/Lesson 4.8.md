# Lesson 4.8 — Python Automation Mini Project

# Server Audit and Health Report CLI

Now we combine Module 4 into one professional mini project.

You will build a Python CLI tool that can:

```text
load config
validate settings
run Linux checks
run HTTP/API checks
generate JSON report
generate Markdown report
generate HTML report
create notification payload
create incident summary if failed
run tests
pass quality gates
```

This is exactly the type of tool DevOps/SRE teams build internally.

---

# 1. Project Goal

Final command:

```bash
python -m devops_toolkit.audit_cli --env prod
```

or:

```bash
./scripts/server-audit --env prod
```

It will produce:

```text
reports/prod-audit.json
reports/prod-audit.md
reports/prod-audit.html
reports/prod-incident-summary.md  # only useful if checks fail
```

The tool will check:

```text
Linux:
  disk usage
  memory
  load average
  systemd services
  listening ports
  recent journal errors

HTTP/API:
  configured service URLs
```

Then it will summarize:

```text
PASSED or FAILED
total checks
failed checks
report paths
exit code
```

---

# 2. Architecture

```text
CLI
 ↓
settings.py
 ↓
config.py
 ↓
linux_checks.py + health.py
 ↓
reports.py
 ↓
report_renderers.py
 ↓
notifications.py
 ↓
incident.py
```

This is why we structured code in previous lessons.

Now the CLI only orchestrates reusable modules.

---

# 3. Add Audit Config

Create:

```bash
cd ~/devops-masterclass/04-python-devops-automation
source .venv/bin/activate

mkdir -p configs/audit
nano configs/audit/prod.yaml
```

Paste:

```yaml
environment: prod

linux:
  disk:
    path: /
    threshold: 85

  memory:
    min_available_mb: 256

  load:
    max_load_per_core: 2.0

  services:
    - ssh

  ports:
    - 22

  journal:
    since: "30 minutes ago"
    max_lines: 50

http:
  services:
    - name: github
      url: https://github.com
      expected_status: 200
```

For WSL, SSH may not be active. You can temporarily use:

```yaml
services: []
ports: []
```

Create dev config:

```bash
nano configs/audit/dev.yaml
```

Paste:

```yaml
environment: dev

linux:
  disk:
    path: /
    threshold: 90

  memory:
    min_available_mb: 128

  load:
    max_load_per_core: 3.0

  services: []

  ports: []

  journal:
    since: "30 minutes ago"
    max_lines: 50

http:
  services:
    - name: local-demo
      url: http://127.0.0.1:8080/health
      expected_status: 200

    - name: github
      url: https://github.com
      expected_status: 200
```

---

# 4. Add Audit Config Loader

Create:

```bash
nano devops_toolkit/audit_config.py
```

Paste:

```python
from pathlib import Path
from typing import Any

from devops_toolkit.config import load_yaml_file, validate_services_config
from devops_toolkit.exceptions import ConfigError
from devops_toolkit.paths import CONFIG_DIR
from devops_toolkit.validators import (
    validate_environment,
    validate_percent_threshold,
    validate_port,
    validate_positive_int,
)


def resolve_audit_config_path(environment: str) -> Path:
    env = validate_environment(environment)
    path = CONFIG_DIR / "audit" / f"{env}.yaml"

    if not path.exists():
        raise ConfigError(f"Audit config not found for environment '{env}': {path}")

    return path


def load_audit_config(path: Path) -> dict[str, Any]:
    config = load_yaml_file(path)

    environment = validate_environment(str(config.get("environment", "")))

    linux = config.get("linux", {})
    http = config.get("http", {})

    if not isinstance(linux, dict):
        raise ConfigError("linux must be an object")

    if not isinstance(http, dict):
        raise ConfigError("http must be an object")

    disk = linux.get("disk", {})
    memory = linux.get("memory", {})
    load = linux.get("load", {})
    journal = linux.get("journal", {})

    if not isinstance(disk, dict):
        raise ConfigError("linux.disk must be an object")

    if not isinstance(memory, dict):
        raise ConfigError("linux.memory must be an object")

    if not isinstance(load, dict):
        raise ConfigError("linux.load must be an object")

    if not isinstance(journal, dict):
        raise ConfigError("linux.journal must be an object")

    services = linux.get("services", [])
    ports = linux.get("ports", [])

    if not isinstance(services, list):
        raise ConfigError("linux.services must be a list")

    if not all(isinstance(service, str) for service in services):
        raise ConfigError("linux.services must contain only strings")

    if not isinstance(ports, list):
        raise ConfigError("linux.ports must be a list")

    validated_ports = [validate_port(int(port)) for port in ports]

    http_services = validate_services_config({"services": http.get("services", [])})

    return {
        "environment": environment,
        "linux": {
            "disk": {
                "path": str(disk.get("path", "/")),
                "threshold": validate_percent_threshold(
                    "linux.disk.threshold",
                    int(disk.get("threshold", 85)),
                ),
            },
            "memory": {
                "min_available_mb": validate_positive_int(
                    "linux.memory.min_available_mb",
                    int(memory.get("min_available_mb", 256)),
                    min_value=1,
                ),
            },
            "load": {
                "max_load_per_core": float(load.get("max_load_per_core", 2.0)),
            },
            "services": services,
            "ports": validated_ports,
            "journal": {
                "since": str(journal.get("since", "30 minutes ago")),
                "max_lines": validate_positive_int(
                    "linux.journal.max_lines",
                    int(journal.get("max_lines", 50)),
                    min_value=1,
                    max_value=500,
                ),
            },
        },
        "http": {
            "services": http_services,
        },
    }
```

This validates the audit config before any checks run.

---

# 5. Create Audit Engine

Create:

```bash
nano devops_toolkit/audit.py
```

Paste:

```python
import logging
from dataclasses import asdict
from datetime import datetime, timezone
from typing import Any

from devops_toolkit.health import check_services as check_http_services
from devops_toolkit.linux_checks import (
    CheckResult,
    check_disk,
    check_load,
    check_memory,
    check_port,
    check_service,
    scan_journal_errors,
)


logger = logging.getLogger(__name__)


def run_linux_audit(config: dict[str, Any]) -> list[CheckResult]:
    linux = config["linux"]
    results: list[CheckResult] = []

    logger.info("running disk check")
    results.append(
        check_disk(
            path=linux["disk"]["path"],
            threshold=linux["disk"]["threshold"],
        )
    )

    logger.info("running memory check")
    results.append(
        check_memory(
            min_available_mb=linux["memory"]["min_available_mb"],
        )
    )

    logger.info("running load check")
    results.append(
        check_load(
            max_load_per_core=linux["load"]["max_load_per_core"],
        )
    )

    for service in linux["services"]:
        logger.info("checking service", extra={"service": service})
        results.append(check_service(service))

    for port in linux["ports"]:
        logger.info("checking port", extra={"port": port})
        results.append(check_port(port))

    logger.info("scanning journal errors")
    results.append(
        scan_journal_errors(
            since=linux["journal"]["since"],
            max_lines=linux["journal"]["max_lines"],
        )
    )

    return results


def run_http_audit(config: dict[str, Any], timeout: int) -> list:
    logger.info("running HTTP checks")
    return check_http_services(config["http"]["services"], timeout=timeout)


def build_audit_report(
    *,
    environment: str,
    linux_results: list[CheckResult],
    http_results: list,
) -> dict[str, Any]:
    normalized_linux = [
        {
            "category": "linux",
            **asdict(result),
        }
        for result in linux_results
    ]

    normalized_http = [
        {
            "category": "http",
            "name": f"http:{result.name}",
            "ok": result.ok,
            "status": "ok" if result.ok else "failed",
            "details": {
                "url": result.url,
                "expected_status": result.expected_status,
                "actual_status": result.actual_status,
            },
            "error": result.error,
        }
        for result in http_results
    ]

    all_results = normalized_linux + normalized_http

    failed = sum(1 for result in all_results if not result["ok"])

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "environment": environment,
        "summary": {
            "total": len(all_results),
            "ok": len(all_results) - failed,
            "failed": failed,
        },
        "results": all_results,
    }
```

This engine separates audit execution from the CLI.

---

# 6. Create Audit CLI

Create:

```bash
nano devops_toolkit/audit_cli.py
```

Paste:

```python
import argparse
import json
import logging
import sys
from pathlib import Path

from devops_toolkit.audit import build_audit_report, run_http_audit, run_linux_audit
from devops_toolkit.audit_config import load_audit_config, resolve_audit_config_path
from devops_toolkit.exceptions import ConfigError
from devops_toolkit.incident import render_incident_summary
from devops_toolkit.logging_config import configure_logging
from devops_toolkit.notifications import build_health_notification_payload
from devops_toolkit.paths import REPORT_DIR
from devops_toolkit.report_renderers import (
    render_health_html,
    render_health_markdown,
    write_text_report,
)
from devops_toolkit.settings import load_app_settings
from devops_toolkit.webhooks import send_json_webhook


logger = logging.getLogger(__name__)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Server audit and health report CLI.")

    parser.add_argument(
        "--env",
        choices=["dev", "staging", "prod", "test"],
        help="Environment name. Defaults to APP_ENV.",
    )

    parser.add_argument(
        "--config",
        help="Explicit audit config file path.",
    )

    parser.add_argument(
        "--output-prefix",
        help="Output prefix. Example: reports/prod-audit",
    )

    parser.add_argument(
        "--timeout",
        type=int,
        help="HTTP timeout in seconds.",
    )

    parser.add_argument(
        "--json-logs",
        action="store_true",
        help="Enable JSON logs.",
    )

    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable debug logs.",
    )

    parser.add_argument(
        "--notify",
        action="store_true",
        help="Send webhook notification using WEBHOOK_URL.",
    )

    parser.add_argument(
        "--dry-run-notify",
        action="store_true",
        help="Print notification payload without sending.",
    )

    return parser.parse_args()


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def main() -> int:
    args = parse_args()

    try:
        settings = load_app_settings()
    except ConfigError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    environment = args.env or settings.app_env
    timeout = args.timeout or settings.default_timeout

    output_prefix = (
        Path(args.output_prefix)
        if args.output_prefix
        else REPORT_DIR / f"{environment}-audit"
    )

    log_file = output_prefix.with_suffix(".log")

    configure_logging(
        verbose=args.verbose,
        json_logs=args.json_logs,
        log_file=log_file,
    )

    logger.info(
        "starting audit",
        extra={
            "environment": environment,
            "timeout": timeout,
        },
    )

    try:
        config_path = Path(args.config) if args.config else resolve_audit_config_path(environment)
        config = load_audit_config(config_path)
    except ConfigError as exc:
        logger.error("config error", extra={"error": str(exc)})
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    linux_results = run_linux_audit(config)
    http_results = run_http_audit(config, timeout=timeout)

    report = build_audit_report(
        environment=environment,
        linux_results=linux_results,
        http_results=http_results,
    )

    json_path = output_prefix.with_suffix(".json")
    markdown_path = output_prefix.with_suffix(".md")
    html_path = output_prefix.with_suffix(".html")
    incident_path = output_prefix.with_name(f"{output_prefix.name}-incident-summary.md")

    write_json(json_path, report)

    markdown = render_health_markdown(report, title=f"{environment} Server Audit Report")
    html = render_health_html(report, title=f"{environment} Server Audit Report")

    write_text_report(markdown_path, markdown)
    write_text_report(html_path, html)

    payload = build_health_notification_payload(
        report,
        title=f"{environment} Server Audit",
        environment=environment,
        report_path=str(json_path),
    )

    if args.dry_run_notify:
        print(json.dumps(payload, indent=2))

    if args.notify:
        if not settings.webhook_url:
            logger.error("WEBHOOK_URL is required for notifications")
            print("ERROR: WEBHOOK_URL is required for --notify", file=sys.stderr)
            return 1

        notify_result = send_json_webhook(settings.webhook_url, payload)

        if not notify_result.ok:
            logger.error(
                "notification failed",
                extra={
                    "status_code": notify_result.status_code,
                    "error": notify_result.error,
                },
            )
            return 1

    failed = report["summary"]["failed"]

    if failed:
        incident = render_incident_summary(
            report,
            service="server-audit",
            environment=environment,
            severity="SEV-3",
        )
        write_text_report(incident_path, incident)

    print("===== Server Audit Summary =====")
    print(f"Environment: {environment}")
    print(f"Config: {config_path}")
    print(f"Total: {report['summary']['total']}")
    print(f"OK: {report['summary']['ok']}")
    print(f"Failed: {failed}")
    print()
    print(f"JSON report: {json_path}")
    print(f"Markdown report: {markdown_path}")
    print(f"HTML report: {html_path}")
    print(f"Log file: {log_file}")

    if failed:
        print(f"Incident summary: {incident_path}")

    logger.info(
        "audit completed",
        extra={
            "failed": failed,
            "json_report": str(json_path),
        },
    )

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
```

---

# 7. Add Wrapper Script

Create:

```bash
nano scripts/server-audit
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

exec python -m devops_toolkit.audit_cli "$@"
```

Make executable:

```bash
chmod +x scripts/server-audit
```

Run help:

```bash
./scripts/server-audit --help
```

Run prod audit:

```bash
./scripts/server-audit --env prod --dry-run-notify
```

For WSL/local where SSH is not running, run dev:

```bash
./scripts/server-audit --env dev --dry-run-notify
```

---

# 8. Expected Behavior

If everything passes:

```text
exit code 0
```

If any check fails:

```text
exit code 1
incident summary generated
reports still generated
```

That is exactly what CI/CD or cron needs.

Run:

```bash
echo $?
```

after audit.

---

# 9. View Reports

```bash
ls -lh reports/*audit*
```

JSON:

```bash
cat reports/prod-audit.json | jq .
```

Markdown:

```bash
cat reports/prod-audit.md
```

HTML:

```bash
explorer.exe reports/prod-audit.html
```

If not on WSL:

```bash
xdg-open reports/prod-audit.html
```

Log:

```bash
cat reports/prod-audit.log
```

JSON logs:

```bash
./scripts/server-audit --env prod --json-logs --dry-run-notify || true
```

---

# 10. Add Tests for Audit Config

Create:

```bash
nano tests/test_audit_config.py
```

Paste:

```python
from pathlib import Path

import pytest

from devops_toolkit.audit_config import load_audit_config
from devops_toolkit.exceptions import ConfigError


def test_load_audit_config_valid(tmp_path: Path) -> None:
    config_file = tmp_path / "audit.yaml"
    config_file.write_text(
        """
environment: prod

linux:
  disk:
    path: /
    threshold: 85
  memory:
    min_available_mb: 256
  load:
    max_load_per_core: 2.0
  services:
    - ssh
  ports:
    - 22
  journal:
    since: "30 minutes ago"
    max_lines: 50

http:
  services:
    - name: github
      url: https://github.com
      expected_status: 200
""",
        encoding="utf-8",
    )

    config = load_audit_config(config_file)

    assert config["environment"] == "prod"
    assert config["linux"]["disk"]["threshold"] == 85
    assert config["linux"]["ports"] == [22]
    assert config["http"]["services"][0]["name"] == "github"


def test_load_audit_config_invalid_env(tmp_path: Path) -> None:
    config_file = tmp_path / "audit.yaml"
    config_file.write_text(
        """
environment: production
linux: {}
http: {}
""",
        encoding="utf-8",
    )

    with pytest.raises(ConfigError, match="Invalid APP_ENV"):
        load_audit_config(config_file)


def test_load_audit_config_invalid_port(tmp_path: Path) -> None:
    config_file = tmp_path / "audit.yaml"
    config_file.write_text(
        """
environment: prod
linux:
  ports:
    - 70000
http:
  services: []
""",
        encoding="utf-8",
    )

    with pytest.raises(ConfigError):
        load_audit_config(config_file)
```

Run:

```bash
pytest tests/test_audit_config.py
```

---

# 11. Add Tests for Audit Report

Create:

```bash
nano tests/test_audit.py
```

Paste:

```python
from devops_toolkit.audit import build_audit_report
from devops_toolkit.health import HealthResult
from devops_toolkit.linux_checks import CheckResult


def test_build_audit_report() -> None:
    linux_results = [
        CheckResult(
            name="disk:/",
            ok=True,
            status="ok",
            details={"usage_percent": 40},
            error=None,
        )
    ]

    http_results = [
        HealthResult(
            name="github",
            url="https://github.com",
            expected_status=200,
            actual_status=200,
            ok=True,
            error=None,
        ),
        HealthResult(
            name="api",
            url="https://api.example.com",
            expected_status=200,
            actual_status=500,
            ok=False,
            error=None,
        ),
    ]

    report = build_audit_report(
        environment="prod",
        linux_results=linux_results,
        http_results=http_results,
    )

    assert report["environment"] == "prod"
    assert report["summary"]["total"] == 3
    assert report["summary"]["ok"] == 2
    assert report["summary"]["failed"] == 1
    assert report["results"][0]["category"] == "linux"
    assert report["results"][1]["category"] == "http"
```

Run:

```bash
pytest tests/test_audit.py
```

---

# 12. Add CLI Smoke Test

Open:

```bash
nano tests/test_cli_smoke.py
```

Add:

```python
def test_audit_cli_help() -> None:
    result = run_cli(["-m", "devops_toolkit.audit_cli", "--help"])

    assert result.returncode == 0
    assert "server audit" in result.stdout.lower()
```

Run:

```bash
pytest tests/test_cli_smoke.py
```

---

# 13. Update Makefile

Open:

```bash
nano Makefile
```

Replace with:

```makefile
.PHONY: test coverage compile lint format typecheck security quality health env-health linux-health github-report render-report notify-dry-run audit audit-dev full-workflow clean

test:
	pytest

coverage:
	coverage run -m pytest
	coverage report

compile:
	python -m compileall devops_toolkit scripts tests

lint:
	ruff check .
	ruff format --check .

format:
	ruff check . --fix
	ruff format .

typecheck:
	mypy devops_toolkit

security:
	bandit -r devops_toolkit scripts

quality: compile lint typecheck security coverage

health:
	python -m devops_toolkit.cli --config configs/services.yaml --output reports/health-report.json

env-health:
	python -m devops_toolkit.env_health_cli --env prod --output reports/env-health-report.json

linux-health:
	python -m devops_toolkit.linux_cli --services ssh --ports 22 --output reports/linux-report.json

github-report:
	python -m devops_toolkit.github_cli --user octocat --max-pages 1 --output reports/github-repos.json

render-report:
	python -m devops_toolkit.report_cli --input reports/env-health-report.json --markdown-output reports/env-health-report.md --html-output reports/env-health-report.html

notify-dry-run:
	python -m devops_toolkit.notify_cli --report reports/env-health-report.json --env prod --dry-run

audit:
	python -m devops_toolkit.audit_cli --env prod --dry-run-notify

audit-dev:
	python -m devops_toolkit.audit_cli --env dev --dry-run-notify

full-workflow:
	./scripts/full-health-workflow prod demo-api

clean:
	find . -type d -name "__pycache__" -prune -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	rm -rf htmlcov .coverage .mypy_cache .ruff_cache
```

Run:

```bash
make compile
make test
make audit-dev || true
make quality
```

If `make quality` fails due to formatting, run:

```bash
make format
make quality
```

---

# 14. Add CI Workflow for Audit Smoke

Your `python-quality.yml` already runs tests and quality gates.

Add one smoke step after tests:

```yaml
      - name: Audit CLI help
        run: python -m devops_toolkit.audit_cli --help
```

Open:

```bash
cd ~/devops-masterclass
nano .github/workflows/python-quality.yml
```

Add before or after tests:

```yaml
      - name: Audit CLI help
        run: python -m devops_toolkit.audit_cli --help
```

Do not run the real audit in GitHub Actions because Linux services/ports differ on hosted runners.

---

# 15. Add Project README Section

Open:

```bash
cd ~/devops-masterclass/04-python-devops-automation
nano README.md
```

If the file does not exist, create it.

Paste:

````markdown
# Python DevOps Automation Toolkit

This module contains a Python DevOps automation toolkit built during the DevOps learning journey.

## Features

- Config-driven HTTP health checks
- Linux server checks
- API automation patterns
- Environment-aware settings
- JSON, Markdown, and HTML reports
- Notification payload generation
- Incident summary generation
- Tests and quality gates

## Main Commands

```bash
make quality
make audit
make audit-dev
````

## Server Audit

```bash
python -m devops_toolkit.audit_cli --env prod --dry-run-notify
./scripts/server-audit --env prod --dry-run-notify
```

Generated artifacts:

```text
reports/prod-audit.json
reports/prod-audit.md
reports/prod-audit.html
reports/prod-audit.log
reports/prod-audit-incident-summary.md
```

## Quality Gates

```bash
make compile
make lint
make typecheck
make security
make coverage
make quality
```

````

---

# 16. Add Mini Project Notes

Create:

```bash
nano notes/python-automation-mini-project.md
````

Paste:

````markdown
# Python Automation Mini Project: Server Audit CLI

## Goal

Build a config-driven server audit CLI that runs Linux checks and HTTP checks, then generates reports and notifications.

## Checks

Linux checks:

- disk usage
- memory availability
- load average
- systemd services
- listening ports
- journal errors

HTTP checks:

- configured service URLs
- expected HTTP status codes

## Outputs

- JSON report
- Markdown report
- HTML report
- log file
- notification payload
- incident summary if failed

## Main Command

```bash
./scripts/server-audit --env prod --dry-run-notify
````

## Architecture

```text
audit_cli.py
  -> settings.py
  -> audit_config.py
  -> audit.py
  -> linux_checks.py
  -> health.py
  -> report_renderers.py
  -> notifications.py
  -> incident.py
```

## Production Lessons

* Validate config before running checks.
* Separate CLI orchestration from logic.
* Generate machine-readable and human-readable reports.
* Exit non-zero when checks fail.
* Do not depend on real external systems in unit tests.
* Keep CI quality gates separate from environment-specific runtime checks.

````

---

# 17. Final Validation

Run:

```bash
cd ~/devops-masterclass/04-python-devops-automation
source .venv/bin/activate
````

Then:

```bash
python -m compileall devops_toolkit scripts tests
pytest
ruff check .
ruff format --check .
mypy devops_toolkit
bandit -r devops_toolkit scripts
coverage run -m pytest
coverage report
```

Run the mini project:

```bash
./scripts/server-audit --env prod --dry-run-notify || true
```

or:

```bash
./scripts/server-audit --env dev --dry-run-notify || true
```

Check artifacts:

```bash
ls -lh reports/*audit*
```

---

# 18. Commit Work

From repo root:

```bash
cd ~/devops-masterclass

git status
git diff
```

Add:

```bash
git add 04-python-devops-automation \
        .github/workflows/python-quality.yml
```

Review:

```bash
git diff --staged
```

Commit:

```bash
git commit -m "feat: add Python server audit mini project"
```

Push:

```bash
git push
```

---

# 19. What You Can Say in Interviews

Use this:

```text
I built a Python DevOps automation toolkit with a server audit CLI. It loads environment-specific YAML config, validates inputs, runs Linux checks for disk, memory, load, systemd services, ports, and journal errors, and runs HTTP health checks for configured services. It produces JSON, Markdown, and HTML reports, creates notification payloads, and generates an incident summary when checks fail. The tool has pytest tests, mocked subprocess/API logic, coverage, Ruff linting, mypy type checks, Bandit security scanning, and GitHub Actions quality gates.
```

That is a strong project explanation.

---

# 20. Common Production Extensions

You can extend this project later with:

```text
Slack/Teams real notifications
S3 report upload
GitHub PR comment with Markdown report
Prometheus Pushgateway metrics
Jenkins artifact upload
Ansible dynamic inventory
AWS EC2 tag-based checks
Kubernetes cluster health checks
Docker container checks
HTML dashboard
SQLite history database
```

This mini project can become a portfolio project by itself.

---

# 21. Common Mistakes

## Mistake 1 — Running environment-specific checks in generic CI

Bad:

```text
CI expects ssh service and port 22 to exist.
```

Better:

```text
CI runs tests and --help smoke checks.
Real server audit runs on actual server, cron, Jenkins agent, or deployment host.
```

## Mistake 2 — No clear exit code

Bad:

```text
Reports fail but command exits 0.
```

Better:

```text
Exit 0 only when all critical checks pass.
Exit 1 when checks fail.
```

## Mistake 3 — Report generated only on success

Bad:

```text
Failure occurs and no artifact exists.
```

Better:

```text
Always generate reports, especially on failure.
```

## Mistake 4 — CLI has all logic

Bad:

```text
audit_cli.py is 1000 lines.
```

Better:

```text
CLI orchestrates.
audit.py runs checks.
audit_config.py validates.
report_renderers.py renders.
```

---

# 22. Final Module 4 Skills So Far

You now know:

```text
Python virtual environments
project structure
packages and modules
argparse CLIs
pathlib
JSON/YAML
requests API calls
sessions and retries
subprocess wrappers
Linux checks
config validation
settings objects
safe secret masking
structured logging
JSON logs
JSON/Markdown/HTML reports
notifications
incident summaries
pytest
fixtures
mocking
coverage
ruff
mypy
bandit
CI quality gates
mini project integration
```

This is a serious DevOps Python foundation.

---

# Today’s Core Rules

```text
Validate config before action.
Keep CLI thin.
Separate checks, reports, notifications, and config.
Always generate evidence reports.
Exit non-zero on failed checks.
Mock external systems in tests.
Run quality gates locally and in CI.
Do not run host-specific checks in generic CI.
Never print secrets.
Make automation explainable in interviews.
```

Next lesson:

# Lesson 4.9 — Python for CI/CD and Jenkins/GitHub Actions: writing pipeline helper scripts, artifact validation, release metadata, deployment preflight checks, and rollback decision automation.

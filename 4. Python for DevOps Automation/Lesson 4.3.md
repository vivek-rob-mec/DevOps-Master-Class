# Lesson 4.2 — Python Project Structure for DevOps

In Lesson 4.1, we wrote standalone Python scripts.

Now we move to a more professional structure.

A beginner creates:

```text id="py4x0p"
script1.py
script2.py
script_final.py
script_new_final.py
```

A DevOps engineer creates:

```text id="l3v3sx"
a small Python package
reusable modules
config loader
logging setup
custom exceptions
tests
CLI entrypoint
```

This lesson teaches how to structure Python automation so it does not become messy when it grows.

---

# 1. Why Project Structure Matters

Small scripts are okay at first.

But DevOps automation grows quickly:

```text id="b9loup"
health checks
config parsing
API calls
report generation
retry logic
logging
notifications
tests
CI/CD
```

Without structure, you get:

```text id="fxc16g"
duplicate code
hardcoded paths
unclear errors
hard-to-test scripts
copy-paste functions
broken imports
messy CLI behavior
```

With good structure, you get:

```text id="84msyk"
reusable functions
clear modules
clean imports
testable code
better debugging
CI/CD readiness
team-friendly code
```

---

# 2. Target Project Structure

Inside your Python module folder:

```bash id="2ckoc6"
cd ~/devops-masterclass/04-python-devops-automation
```

Create this structure:

```text id="bza1lr"
04-python-devops-automation/
├── devops_toolkit/
│   ├── __init__.py
│   ├── cli.py
│   ├── config.py
│   ├── exceptions.py
│   ├── health.py
│   ├── logging_config.py
│   ├── paths.py
│   └── reports.py
├── configs/
│   └── services.yaml
├── reports/
│   └── .gitkeep
├── scripts/
├── tests/
│   ├── __init__.py
│   ├── test_config.py
│   └── test_health.py
├── notes/
├── requirements.txt
└── .gitignore
```

Create directories and files:

```bash id="b2b1a4"
cd ~/devops-masterclass/04-python-devops-automation

mkdir -p devops_toolkit tests configs reports notes

touch devops_toolkit/__init__.py
touch tests/__init__.py
touch reports/.gitkeep
```

---

# 3. What is a Python Package?

A folder becomes a Python package when it contains:

```text id="pruvgg"
__init__.py
```

Example:

```text id="9xv5wq"
devops_toolkit/
├── __init__.py
├── config.py
└── health.py
```

Now Python can import from it:

```python id="fqfm4e"
from devops_toolkit.config import load_config
from devops_toolkit.health import check_service
```

This is better than one huge file.

---

# 4. Module Responsibility

Each file should have a clear job:

| File                | Responsibility                |
| ------------------- | ----------------------------- |
| `paths.py`          | project paths                 |
| `exceptions.py`     | custom errors                 |
| `logging_config.py` | logging setup                 |
| `config.py`         | load and validate YAML config |
| `health.py`         | perform health checks         |
| `reports.py`        | write JSON reports            |
| `cli.py`            | command-line interface        |

Professional rule:

```text id="cc62yg"
One module should have one main responsibility.
```

---

# 5. Create `paths.py`

Create:

```bash id="xaihr5"
nano devops_toolkit/paths.py
```

Paste:

```python id="c9jasu"
from pathlib import Path


PACKAGE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = PACKAGE_DIR.parent
CONFIG_DIR = PROJECT_DIR / "configs"
REPORT_DIR = PROJECT_DIR / "reports"
```

Why this is useful:

```text id="zeqgxv"
Scripts can find configs and reports reliably.
No need to depend on current working directory.
```

Example:

```python id="e0oybj"
from devops_toolkit.paths import CONFIG_DIR

config_file = CONFIG_DIR / "services.yaml"
```

---

# 6. Create Custom Exceptions

Create:

```bash id="sjyqvd"
nano devops_toolkit/exceptions.py
```

Paste:

```python id="3m7zk0"
class DevOpsToolkitError(Exception):
    """Base exception for devops_toolkit."""


class ConfigError(DevOpsToolkitError):
    """Raised when configuration is invalid."""


class HealthCheckError(DevOpsToolkitError):
    """Raised when a health check cannot be performed."""
```

Why custom exceptions?

Instead of generic errors everywhere:

```text id="zxkpfs"
ValueError
RuntimeError
Exception
```

you can raise meaningful errors:

```python id="6r4stw"
raise ConfigError("services must be a list")
```

This improves debugging and testing.

---

# 7. Create Logging Setup

Create:

```bash id="l1vi0b"
nano devops_toolkit/logging_config.py
```

Paste:

```python id="w9xsp5"
import logging


def configure_logging(verbose: bool = False) -> None:
    level = logging.DEBUG if verbose else logging.INFO

    logging.basicConfig(
        level=level,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
```

Usage:

```python id="uz4kbs"
from devops_toolkit.logging_config import configure_logging

configure_logging(verbose=True)
```

Why use this module?

```text id="re51d4"
All scripts use the same logging format.
Verbose mode is consistent.
Debugging becomes easier.
```

---

# 8. Create Config Loader

Create:

```bash id="snnab9"
nano devops_toolkit/config.py
```

Paste:

```python id="o1ba32"
from pathlib import Path
from typing import Any

import yaml

from devops_toolkit.exceptions import ConfigError


def load_yaml_file(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise ConfigError(f"Config file not found: {path}")

    if not path.is_file():
        raise ConfigError(f"Config path is not a file: {path}")

    try:
        with path.open("r", encoding="utf-8") as file:
            data = yaml.safe_load(file)
    except yaml.YAMLError as exc:
        raise ConfigError(f"Invalid YAML in {path}: {exc}") from exc

    if data is None:
        raise ConfigError(f"Config file is empty: {path}")

    if not isinstance(data, dict):
        raise ConfigError("Config root must be a YAML object")

    return data


def validate_services_config(config: dict[str, Any]) -> list[dict[str, Any]]:
    services = config.get("services")

    if services is None:
        raise ConfigError("Config must contain 'services'")

    if not isinstance(services, list):
        raise ConfigError("'services' must be a list")

    validated_services: list[dict[str, Any]] = []

    for index, service in enumerate(services, start=1):
        if not isinstance(service, dict):
            raise ConfigError(f"Service #{index} must be an object")

        name = service.get("name")
        url = service.get("url")
        expected_status = service.get("expected_status", 200)

        if not name or not isinstance(name, str):
            raise ConfigError(f"Service #{index} requires string field 'name'")

        if not url or not isinstance(url, str):
            raise ConfigError(f"Service '{name}' requires string field 'url'")

        if not isinstance(expected_status, int):
            raise ConfigError(f"Service '{name}' expected_status must be an integer")

        validated_services.append(
            {
                "name": name,
                "url": url,
                "expected_status": expected_status,
            }
        )

    return validated_services


def load_services_config(path: Path) -> list[dict[str, Any]]:
    config = load_yaml_file(path)
    return validate_services_config(config)
```

This module does three important things:

```text id="j6plrn"
reads YAML safely
validates required fields
raises clear ConfigError messages
```

---

# 9. Create Health Check Module

Create:

```bash id="756gyz"
nano devops_toolkit/health.py
```

Paste:

```python id="wbs15y"
from dataclasses import dataclass
from typing import Optional

import requests


@dataclass(frozen=True)
class HealthResult:
    name: str
    url: str
    expected_status: int
    actual_status: Optional[int]
    ok: bool
    error: Optional[str]


def check_service(
    name: str,
    url: str,
    expected_status: int = 200,
    timeout: int = 5,
) -> HealthResult:
    try:
        response = requests.get(url, timeout=timeout)
    except requests.RequestException as exc:
        return HealthResult(
            name=name,
            url=url,
            expected_status=expected_status,
            actual_status=None,
            ok=False,
            error=str(exc),
        )

    return HealthResult(
        name=name,
        url=url,
        expected_status=expected_status,
        actual_status=response.status_code,
        ok=response.status_code == expected_status,
        error=None,
    )


def check_services(
    services: list[dict],
    timeout: int = 5,
) -> list[HealthResult]:
    results: list[HealthResult] = []

    for service in services:
        results.append(
            check_service(
                name=service["name"],
                url=service["url"],
                expected_status=service.get("expected_status", 200),
                timeout=timeout,
            )
        )

    return results
```

Important:

```python id="dmj8pw"
@dataclass(frozen=True)
```

`frozen=True` means the object is immutable after creation.

This makes results safer and easier to reason about.

---

# 10. Create Reports Module

Create:

```bash id="ozp9qz"
nano devops_toolkit/reports.py
```

Paste:

```python id="k4mh7q"
import json
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

from devops_toolkit.health import HealthResult


def build_health_report(results: list[HealthResult]) -> dict:
    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "summary": {
            "total": len(results),
            "ok": sum(1 for result in results if result.ok),
            "failed": sum(1 for result in results if not result.ok),
        },
        "results": [asdict(result) for result in results],
    }


def write_json_report(path: Path, report: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    with path.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)


def print_health_summary(results: list[HealthResult]) -> None:
    print("===== Health Check Summary =====")

    for result in results:
        status = "OK" if result.ok else "FAIL"

        print(
            f"{status:4} {result.name:20} "
            f"expected={result.expected_status} "
            f"actual={result.actual_status} "
            f"url={result.url}"
        )

        if result.error:
            print(f"     error={result.error}")

    print()
    print(f"Total: {len(results)}")
    print(f"Failed: {sum(1 for result in results if not result.ok)}")
```

Now report logic is separate from health check logic.

That is clean design.

---

# 11. Create CLI Module

Create:

```bash id="dr3et0"
nano devops_toolkit/cli.py
```

Paste:

```python id="4kz8qz"
import argparse
import logging
import sys
from pathlib import Path

from devops_toolkit.config import load_services_config
from devops_toolkit.exceptions import DevOpsToolkitError
from devops_toolkit.health import check_services
from devops_toolkit.logging_config import configure_logging
from devops_toolkit.paths import CONFIG_DIR, REPORT_DIR
from devops_toolkit.reports import (
    build_health_report,
    print_health_summary,
    write_json_report,
)


logger = logging.getLogger(__name__)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="DevOps Toolkit: config-driven health checker."
    )

    parser.add_argument(
        "--config",
        default=str(CONFIG_DIR / "services.yaml"),
        help="Path to services YAML config",
    )

    parser.add_argument(
        "--output",
        default=str(REPORT_DIR / "health-report.json"),
        help="Path to JSON report output",
    )

    parser.add_argument(
        "--timeout",
        type=int,
        default=5,
        help="HTTP timeout in seconds",
    )

    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable debug logging",
    )

    return parser.parse_args()


def main() -> int:
    args = parse_args()
    configure_logging(verbose=args.verbose)

    config_path = Path(args.config)
    output_path = Path(args.output)

    logger.info("Loading config from %s", config_path)

    try:
        services = load_services_config(config_path)
        results = check_services(services, timeout=args.timeout)
        report = build_health_report(results)
        write_json_report(output_path, report)
    except DevOpsToolkitError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print_health_summary(results)
    print()
    print(f"Report written: {output_path}")

    return 0 if all(result.ok for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
```

Run as a module:

```bash id="sq2wmv"
python -m devops_toolkit.cli --help
```

Run actual check:

```bash id="17tu2w"
python -m devops_toolkit.cli
echo $?
```

If one configured service is down, exit code will be non-zero.

That is expected.

---

# 12. Create Config File

Make sure config exists:

```bash id="hx4e0m"
nano configs/services.yaml
```

Paste:

```yaml id="j1ncc0"
services:
  - name: github
    url: https://github.com
    expected_status: 200

  - name: local-demo
    url: http://127.0.0.1:8080/health
    expected_status: 200
```

Run:

```bash id="4s09th"
python -m devops_toolkit.cli --config configs/services.yaml --output reports/toolkit-health.json
```

View report:

```bash id="3hb65a"
cat reports/toolkit-health.json | jq .
```

---

# 13. Why `python -m package.module`?

This:

```bash id="ioob1t"
python -m devops_toolkit.cli
```

runs the module as part of the package.

This helps imports work correctly:

```python id="hp5yv3"
from devops_toolkit.config import load_services_config
```

Avoid running package files directly like:

```bash id="v2az7e"
python devops_toolkit/cli.py
```

That can create import confusion in larger projects.

Professional rule:

```text id="q40mqv"
Run package entrypoints with python -m package.module.
```

---

# 14. Add a Thin Script Wrapper

Sometimes you want a simple script command.

Create:

```bash id="n56kgp"
nano scripts/devops-health
```

Paste:

```bash id="v99pm9"
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

exec python -m devops_toolkit.cli "$@"
```

Make executable:

```bash id="dgb49s"
chmod +x scripts/devops-health
```

Run:

```bash id="vfd8qe"
./scripts/devops-health --help
./scripts/devops-health --config configs/services.yaml --output reports/devops-health.json
```

This gives you a nice operational command while keeping logic inside Python modules.

---

# 15. Add pytest

Install:

```bash id="sql9pe"
source .venv/bin/activate
python -m pip install pytest
python -m pip freeze > requirements.txt
```

Check:

```bash id="y3ekoc"
pytest --version
```

Why tests matter?

```text id="l5gqi0"
Automation scripts can break production.
Tests catch mistakes before CI/CD runs them.
Config validation can be tested.
Health check logic can be mocked.
Report generation can be tested.
```

---

# 16. Test Config Validation

Create:

```bash id="0v4fjy"
nano tests/test_config.py
```

Paste:

```python id="19l6pi"
from pathlib import Path

import pytest

from devops_toolkit.config import load_services_config
from devops_toolkit.exceptions import ConfigError


def test_load_services_config_valid(tmp_path: Path) -> None:
    config_file = tmp_path / "services.yaml"
    config_file.write_text(
        """
services:
  - name: example
    url: https://example.com
    expected_status: 200
""",
        encoding="utf-8",
    )

    services = load_services_config(config_file)

    assert len(services) == 1
    assert services[0]["name"] == "example"
    assert services[0]["url"] == "https://example.com"
    assert services[0]["expected_status"] == 200


def test_load_services_config_missing_file(tmp_path: Path) -> None:
    config_file = tmp_path / "missing.yaml"

    with pytest.raises(ConfigError, match="Config file not found"):
        load_services_config(config_file)


def test_load_services_config_missing_services(tmp_path: Path) -> None:
    config_file = tmp_path / "services.yaml"
    config_file.write_text("not_services: []\n", encoding="utf-8")

    with pytest.raises(ConfigError, match="services"):
        load_services_config(config_file)


def test_load_services_config_invalid_service(tmp_path: Path) -> None:
    config_file = tmp_path / "services.yaml"
    config_file.write_text(
        """
services:
  - name: bad-service
""",
        encoding="utf-8",
    )

    with pytest.raises(ConfigError, match="url"):
        load_services_config(config_file)
```

Run:

```bash id="ubvw0b"
pytest tests/test_config.py -v
```

---

# 17. Test Health Logic with Monkeypatch

We do not want tests to depend on real internet.

So we mock `requests.get`.

Create:

```bash id="0q8qh3"
nano tests/test_health.py
```

Paste:

```python id="fmohzm"
import requests

from devops_toolkit.health import check_service


class FakeResponse:
    def __init__(self, status_code: int) -> None:
        self.status_code = status_code


def test_check_service_ok(monkeypatch) -> None:
    def fake_get(url: str, timeout: int) -> FakeResponse:
        return FakeResponse(status_code=200)

    monkeypatch.setattr(requests, "get", fake_get)

    result = check_service(
        name="example",
        url="https://example.com",
        expected_status=200,
        timeout=5,
    )

    assert result.ok is True
    assert result.actual_status == 200
    assert result.error is None


def test_check_service_unexpected_status(monkeypatch) -> None:
    def fake_get(url: str, timeout: int) -> FakeResponse:
        return FakeResponse(status_code=500)

    monkeypatch.setattr(requests, "get", fake_get)

    result = check_service(
        name="example",
        url="https://example.com",
        expected_status=200,
        timeout=5,
    )

    assert result.ok is False
    assert result.actual_status == 500


def test_check_service_connection_error(monkeypatch) -> None:
    def fake_get(url: str, timeout: int):
        raise requests.ConnectionError("connection failed")

    monkeypatch.setattr(requests, "get", fake_get)

    result = check_service(
        name="example",
        url="https://example.com",
        expected_status=200,
        timeout=5,
    )

    assert result.ok is False
    assert result.actual_status is None
    assert "connection failed" in str(result.error)
```

Run:

```bash id="a6ec37"
pytest tests/test_health.py -v
```

Run all tests:

```bash id="mmnxjc"
pytest -v
```

---

# 18. Test Reports

Create:

```bash id="sr61qb"
nano tests/test_reports.py
```

Paste:

```python id="72k92c"
import json
from pathlib import Path

from devops_toolkit.health import HealthResult
from devops_toolkit.reports import build_health_report, write_json_report


def test_build_health_report_summary() -> None:
    results = [
        HealthResult(
            name="ok-service",
            url="https://example.com",
            expected_status=200,
            actual_status=200,
            ok=True,
            error=None,
        ),
        HealthResult(
            name="bad-service",
            url="https://bad.example.com",
            expected_status=200,
            actual_status=500,
            ok=False,
            error=None,
        ),
    ]

    report = build_health_report(results)

    assert report["summary"]["total"] == 2
    assert report["summary"]["ok"] == 1
    assert report["summary"]["failed"] == 1
    assert len(report["results"]) == 2


def test_write_json_report(tmp_path: Path) -> None:
    output_file = tmp_path / "report.json"
    report = {
        "summary": {
            "total": 1,
            "ok": 1,
            "failed": 0,
        }
    }

    write_json_report(output_file, report)

    loaded = json.loads(output_file.read_text(encoding="utf-8"))
    assert loaded["summary"]["total"] == 1
```

Run:

```bash id="fj6gue"
pytest tests/test_reports.py -v
```

Run all:

```bash id="53zrtf"
pytest -v
```

---

# 19. Why Mocking Matters

Without mocking, tests depend on:

```text id="ma9kj2"
internet availability
GitHub uptime
DNS
firewall
network latency
external API behavior
```

That makes tests flaky.

With monkeypatch, we test our logic:

```text id="e99n1e"
200 response means ok
500 response means fail
connection error is handled
```

Production rule:

```text id="v2m9z1"
Unit tests should not depend on external systems.
Integration tests may depend on real systems, but should be separate.
```

---

# 20. Add `pytest.ini`

Create:

```bash id="aue3tm"
nano pytest.ini
```

Paste:

```ini id="54cv9h"
[pytest]
testpaths = tests
python_files = test_*.py
addopts = -v
```

Now run:

```bash id="3c6ox4"
pytest
```

---

# 21. Add Makefile

A `Makefile` gives easy commands.

Create:

```bash id="zmtc6d"
nano Makefile
```

Paste:

```makefile id="q26zx4"
.PHONY: test compile health clean

test:
	pytest

compile:
	python -m compileall devops_toolkit scripts tests

health:
	python -m devops_toolkit.cli --config configs/services.yaml --output reports/health-report.json

clean:
	find . -type d -name "__pycache__" -prune -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
```

Important: Makefile commands must start with a **tab**, not spaces.

Run:

```bash id="fa8xfm"
make compile
make test
make health
```

If `make` is missing:

```bash id="sumfpr"
sudo apt install -y make
```

---

# 22. Add GitHub Actions for Python Tests

Update or create:

```bash id="3ezovv"
cd ~/devops-masterclass
nano .github/workflows/python-tests.yml
```

Paste:

```yaml id="h9riep"
name: Python Tests

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
  test:
    runs-on: ubuntu-latest

    defaults:
      run:
        working-directory: 04-python-devops-automation

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          python -m pip install -r requirements.txt

      - name: Compile
        run: python -m compileall devops_toolkit scripts tests

      - name: Run tests
        run: pytest
```

Now Python automation has CI tests.

---

# 23. Add Notes

Create:

```bash id="ruvule"
nano notes/python-project-structure.md
```

Paste:

````markdown id="byng4b"
# Python Project Structure for DevOps

## Why Structure Matters

Good structure makes automation:

- reusable
- testable
- maintainable
- CI/CD friendly
- easier to debug

## Package Layout

```text
devops_toolkit/
  __init__.py
  cli.py
  config.py
  exceptions.py
  health.py
  logging_config.py
  paths.py
  reports.py
````

## Responsibilities

| Module              | Purpose                                |
| ------------------- | -------------------------------------- |
| `cli.py`            | CLI argument parsing and orchestration |
| `config.py`         | Load and validate config               |
| `health.py`         | Health check logic                     |
| `reports.py`        | Build/write reports                    |
| `logging_config.py` | Logging setup                          |
| `exceptions.py`     | Custom exceptions                      |
| `paths.py`          | Project paths                          |

## Testing

Use pytest.

```bash
pytest
```

Use monkeypatch to avoid real network calls.

## Rules

* Keep CLI thin.
* Put logic in reusable modules.
* Use custom exceptions for clear errors.
* Use dataclasses for structured results.
* Use tests for validation logic.
* Mock external systems in unit tests.
* Run package modules with `python -m package.module`.
* Use CI/CD to run compile and tests.

````

---

# 24. Run Final Validation

From:

```bash id="g9ccvk"
cd ~/devops-masterclass/04-python-devops-automation
source .venv/bin/activate
````

Run:

```bash id="u5njkl"
python -m compileall devops_toolkit scripts tests
pytest
python -m devops_toolkit.cli --help
python -m devops_toolkit.cli --config configs/services.yaml --output reports/final-health.json
cat reports/final-health.json | jq .
make compile
make test
```

If `local-demo` fails because port 8080 is not running, the CLI may exit non-zero. That is expected.

To test all-green, temporarily use only GitHub in `configs/services.yaml`, or start your capstone demo API.

Start demo API if installed:

```bash id="bofjn8"
sudo systemctl start demo-api
curl -fsS http://127.0.0.1:8080/health
```

---

# 25. Commit Work

From repo root:

```bash id="ow8agh"
cd ~/devops-masterclass

git status
git diff
```

Add:

```bash id="qdw1ud"
git add 04-python-devops-automation \
        .github/workflows/python-tests.yml
```

Review:

```bash id="1xi448"
git diff --staged
```

Commit:

```bash id="rrqy1g"
git commit -m "feat: structure Python DevOps toolkit"
```

Push:

```bash id="w3hp3u"
git push
```

---

# 26. Common Mistakes

## Mistake 1 — Putting everything in one file

Bad:

```text id="s92gk3"
all_logic.py with 800 lines
```

Better:

```text id="k1vs6h"
config.py
health.py
reports.py
cli.py
```

## Mistake 2 — Hardcoded paths

Bad:

```python id="b0ma9i"
open("/home/vivek/project/configs/services.yaml")
```

Better:

```python id="e2gqao"
from devops_toolkit.paths import CONFIG_DIR

config_file = CONFIG_DIR / "services.yaml"
```

## Mistake 3 — Real network in unit tests

Bad:

```python id="efbxdm"
requests.get("https://github.com")
```

Better:

```python id="5i6ceb"
monkeypatch.setattr(requests, "get", fake_get)
```

## Mistake 4 — Generic exceptions

Bad:

```python id="xd1aqb"
raise Exception("bad config")
```

Better:

```python id="9sq95o"
raise ConfigError("Config must contain 'services'")
```

## Mistake 5 — Business logic inside CLI

Bad:

```python id="3na1d2"
def main():
    # parse args
    # read YAML
    # validate YAML
    # call requests
    # write JSON
    # print report
    # all in one function
```

Better:

```text id="zgsf62"
cli.py orchestrates.
config.py validates.
health.py checks.
reports.py writes.
```

---

# 27. Interview Answers

Question:

```text id="z7p69e"
How do you structure a Python DevOps automation project?
```

Strong answer:

```text id="fe7iap"
I structure it as a small Python package, not just one script. I usually separate CLI parsing, config loading, core logic, report generation, logging setup, and exceptions into modules. The CLI should be thin and orchestrate reusable functions. I use pathlib for paths, dataclasses for structured results, custom exceptions for clear failures, pytest for tests, and CI to compile and run tests.
```

Question:

```text id="3pgtdb"
Why should the CLI be thin?
```

Strong answer:

```text id="is7vjm"
A thin CLI keeps argument parsing and orchestration separate from business logic. This makes the core logic reusable from tests, other scripts, or future APIs. If all logic is inside main(), it becomes hard to test and maintain.
```

Question:

```text id="7sun3d"
How do you test code that calls external APIs?
```

Strong answer:

```text id="3p6or6"
For unit tests, I mock the external API calls using monkeypatch or a mocking library, so tests do not depend on the internet or third-party uptime. I test our logic for success, failure status codes, and exceptions. Real external calls can be covered separately as integration tests.
```

Question:

```text id="807dl2"
Why use custom exceptions?
```

Strong answer:

```text id="pp5m3h"
Custom exceptions make errors more meaningful and easier to handle. For example, ConfigError clearly indicates a configuration problem. The CLI can catch application-specific exceptions and print clean user-friendly error messages, while unexpected exceptions still indicate bugs.
```

---

# Today’s Core Rules

```text id="1oa9ty"
Structure Python automation as packages when it grows.
Keep CLI thin.
Put reusable logic in modules.
Use pathlib for paths.
Use dataclasses for structured results.
Use custom exceptions.
Use logging configuration consistently.
Validate config early.
Write JSON reports from dedicated report functions.
Test config and logic with pytest.
Mock external systems in unit tests.
Run compile and tests in CI.
```

Next lesson:

# Lesson 4.3 — Python Automation with Linux: subprocess wrappers, service checks, disk/memory parsing, log scanning, report generation, and safe command execution.

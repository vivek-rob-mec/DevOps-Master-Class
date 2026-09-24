# Lesson 4.7 — Python Testing and Quality Gates

Now we make your Python DevOps automation more professional by adding **quality gates**.

A beginner runs:

```bash
python script.py
```

A DevOps engineer runs:

```bash
pytest
ruff check
mypy
bandit
coverage
python -m compileall
```

Then CI/CD blocks bad code before it reaches production.

---

# 1. What Are Quality Gates?

A quality gate is an automated check that must pass before code is merged or deployed.

Examples:

```text
Syntax check
Unit tests
Code style check
Type check
Security scan
Coverage threshold
Dependency vulnerability scan
```

In DevOps, quality gates protect automation code from breaking infrastructure.

Bad automation can:

```text
deploy wrong version
delete wrong files
restart wrong service
leak secrets
fail silently
break CI/CD
misreport health status
```

So Python automation needs tests and gates.

---

# 2. Quality Gate Stack for This Module

We will add these tools:

| Tool         | Purpose                         |
| ------------ | ------------------------------- |
| `pytest`     | run tests                       |
| `coverage`   | measure test coverage           |
| `ruff`       | linting and formatting checks   |
| `mypy`       | type checking                   |
| `bandit`     | Python security scanning        |
| `compileall` | syntax/import compilation check |

Final command will be:

```bash
make quality
```

And CI will run the same checks.

---

# 3. Install Quality Tools

Go to your Python project:

```bash
cd ~/devops-masterclass/04-python-devops-automation
source .venv/bin/activate
```

Install:

```bash
python -m pip install pytest coverage ruff mypy bandit
python -m pip freeze > requirements.txt
```

Check versions:

```bash
pytest --version
coverage --version
ruff --version
mypy --version
bandit --version
```

---

# 4. Testing Layers

There are different kinds of tests.

```text
Unit tests
  Test one function/module in isolation.

Integration tests
  Test multiple components together.

End-to-end tests
  Test the real workflow from outside.

Smoke tests
  Quick basic checks that the app/tool starts.

Regression tests
  Tests for bugs that happened before.
```

For DevOps automation:

```text
Unit tests:
  config validation
  parser functions
  report rendering
  notification payloads

Integration tests:
  CLI command with test config
  JSON report generated correctly

Smoke tests:
  --help works
  package imports compile

Avoid in unit tests:
  real GitHub API
  real Slack webhook
  real systemctl dependencies
  real production services
```

---

# 5. pytest Fixtures

A fixture provides reusable test setup.

Example:

```python
import pytest

@pytest.fixture
def sample_report() -> dict:
    return {
        "summary": {"total": 1, "ok": 1, "failed": 0},
        "results": [],
    }
```

Then tests can use it:

```python
def test_report(sample_report):
    assert sample_report["summary"]["failed"] == 0
```

Fixtures reduce duplication.

---

# 6. Create `tests/conftest.py`

`conftest.py` is where shared pytest fixtures live.

Create:

```bash
nano tests/conftest.py
```

Paste:

```python
from pathlib import Path

import pytest


@pytest.fixture
def sample_health_report() -> dict:
    return {
        "timestamp": "2026-06-28T00:00:00+00:00",
        "summary": {
            "total": 2,
            "ok": 1,
            "failed": 1,
        },
        "results": [
            {
                "name": "service:ssh",
                "ok": True,
                "status": "active",
                "details": {"service": "ssh"},
                "error": None,
            },
            {
                "name": "port:80",
                "ok": False,
                "status": "not_listening",
                "details": {"port": 80},
                "error": "no listener found on port 80",
            },
        ],
    }


@pytest.fixture
def valid_services_yaml(tmp_path: Path) -> Path:
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
    return config_file
```

Now tests can reuse these fixtures.

---

# 7. Update Report Renderer Test to Use Fixture

Open:

```bash
nano tests/test_report_renderers.py
```

Replace with:

```python
from devops_toolkit.report_renderers import render_health_html, render_health_markdown


def test_render_health_markdown(sample_health_report: dict) -> None:
    markdown = render_health_markdown(sample_health_report, title="Test Report")

    assert "# Test Report" in markdown
    assert "service:ssh" in markdown
    assert "port:80" in markdown
    assert "❌ FAIL" in markdown


def test_render_health_html(sample_health_report: dict) -> None:
    html = render_health_html(sample_health_report, title="Test Report")

    assert "<html>" in html
    assert "Test Report" in html
    assert "service:ssh" in html
    assert "port:80" in html
```

Run:

```bash
pytest tests/test_report_renderers.py
```

---

# 8. Testing CLI with subprocess

For CLI integration tests, we can call Python modules using `subprocess`.

Create:

```bash
nano tests/test_cli_smoke.py
```

Paste:

```python
import subprocess
import sys
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]


def run_cli(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, *args],
        cwd=PROJECT_DIR,
        text=True,
        capture_output=True,
        timeout=20,
        check=False,
    )


def test_main_health_cli_help() -> None:
    result = run_cli(["-m", "devops_toolkit.cli", "--help"])

    assert result.returncode == 0
    assert "health checker" in result.stdout.lower()


def test_linux_cli_help() -> None:
    result = run_cli(["-m", "devops_toolkit.linux_cli", "--help"])

    assert result.returncode == 0
    assert "linux server health" in result.stdout.lower()


def test_report_cli_help() -> None:
    result = run_cli(["-m", "devops_toolkit.report_cli", "--help"])

    assert result.returncode == 0
    assert "convert json health reports" in result.stdout.lower()


def test_env_health_cli_with_prod_config(tmp_path: Path) -> None:
    output_file = tmp_path / "report.json"

    result = run_cli(
        [
            "-m",
            "devops_toolkit.env_health_cli",
            "--env",
            "prod",
            "--output",
            str(output_file),
        ]
    )

    assert output_file.exists()
    assert "Environment: prod" in result.stdout
```

Run:

```bash
pytest tests/test_cli_smoke.py
```

Note: this test may do a real HTTP check to GitHub because `prod.yaml` uses GitHub. For fully offline CI, use an explicit test config instead.

---

# 9. Safer Offline CLI Test

Create a test config with a fake URL and expected failure. The goal is to test report creation, not internet success.

Add this to `tests/test_cli_smoke.py`:

```python
def test_health_cli_with_local_test_config(tmp_path: Path) -> None:
    config_file = tmp_path / "services.yaml"
    output_file = tmp_path / "report.json"

    config_file.write_text(
        """
services:
  - name: unavailable-local
    url: http://127.0.0.1:9/health
    expected_status: 200
""",
        encoding="utf-8",
    )

    result = run_cli(
        [
            "-m",
            "devops_toolkit.cli",
            "--config",
            str(config_file),
            "--output",
            str(output_file),
            "--timeout",
            "1",
        ]
    )

    assert result.returncode == 1
    assert output_file.exists()
    assert "unavailable-local" in result.stdout
```

Now we have a deterministic failing check.

---

# 10. Mocking subprocess-Based Linux Checks

Our Linux checks call `run_command`. We can monkeypatch that function.

Create:

```bash
nano tests/test_linux_check_logic.py
```

Paste:

```python
from devops_toolkit.commands import CommandResult
from devops_toolkit import linux_checks


def fake_command_result(command: list[str], stdout: str, returncode: int = 0) -> CommandResult:
    return CommandResult(
        command=command,
        returncode=returncode,
        stdout=stdout,
        stderr="",
        timed_out=False,
        timeout_seconds=5,
    )


def test_check_disk_ok(monkeypatch) -> None:
    def fake_run_command(command: list[str], timeout: int = 10) -> CommandResult:
        return fake_command_result(
            command,
            """Filesystem     1024-blocks     Used Available Capacity Mounted on
/dev/sda1         30428648 12000000  18428648      40% /
""",
        )

    monkeypatch.setattr(linux_checks, "run_command", fake_run_command)

    result = linux_checks.check_disk("/", threshold=85)

    assert result.ok is True
    assert result.details["usage_percent"] == 40


def test_check_disk_threshold_exceeded(monkeypatch) -> None:
    def fake_run_command(command: list[str], timeout: int = 10) -> CommandResult:
        return fake_command_result(
            command,
            """Filesystem     1024-blocks     Used Available Capacity Mounted on
/dev/sda1         30428648 29000000  1428648      95% /
""",
        )

    monkeypatch.setattr(linux_checks, "run_command", fake_run_command)

    result = linux_checks.check_disk("/", threshold=85)

    assert result.ok is False
    assert result.status == "threshold_exceeded"


def test_check_service_active(monkeypatch) -> None:
    def fake_run_command(command: list[str], timeout: int = 10) -> CommandResult:
        return fake_command_result(command, "active\n", returncode=0)

    monkeypatch.setattr(linux_checks, "run_command", fake_run_command)

    result = linux_checks.check_service("ssh")

    assert result.ok is True
    assert result.status == "active"


def test_check_service_inactive(monkeypatch) -> None:
    def fake_run_command(command: list[str], timeout: int = 10) -> CommandResult:
        return CommandResult(
            command=command,
            returncode=3,
            stdout="inactive\n",
            stderr="",
            timed_out=False,
            timeout_seconds=5,
        )

    monkeypatch.setattr(linux_checks, "run_command", fake_run_command)

    result = linux_checks.check_service("nginx")

    assert result.ok is False
    assert result.status == "inactive"
```

Run:

```bash
pytest tests/test_linux_check_logic.py
```

This is better than relying on your real systemd state.

---

# 11. Coverage

Coverage tells how much of your code is executed by tests.

Run:

```bash
coverage run -m pytest
coverage report
```

HTML report:

```bash
coverage html
```

Open:

```bash
explorer.exe htmlcov/index.html
```

On Linux desktop:

```bash
xdg-open htmlcov/index.html
```

Coverage is not perfect, but it helps find untested modules.

---

# 12. Add Coverage Config

Create:

```bash
nano .coveragerc
```

Paste:

```ini
[run]
source = devops_toolkit
omit =
    tests/*
    .venv/*

[report]
show_missing = True
skip_empty = True
fail_under = 70

[html]
directory = htmlcov
```

Now run:

```bash
coverage run -m pytest
coverage report
```

If coverage is below 70%, either add tests or temporarily lower the threshold while learning.

Production rule:

```text
Coverage threshold should increase over time, not decrease forever.
```

---

# 13. Ruff Linting

Ruff is a fast Python linter.

Run:

```bash
ruff check .
```

Ruff may report issues.

Auto-fix safe ones:

```bash
ruff check . --fix
```

Format check:

```bash
ruff format --check .
```

Apply formatting:

```bash
ruff format .
```

For a learning project, formatting with Ruff is fine.

---

# 14. Add Ruff Config

Create:

```bash
nano pyproject.toml
```

Paste:

```toml
[tool.ruff]
line-length = 100
target-version = "py312"

[tool.ruff.lint]
select = [
  "E",
  "F",
  "I",
  "B",
  "UP",
  "SIM",
]
ignore = []

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
```

Meaning:

```text
E/F  pycodestyle/pyflakes basics
I    import sorting
B    bugbear common bug patterns
UP   modern Python upgrades
SIM  simplify code
```

Run:

```bash
ruff check .
ruff format --check .
```

Fix:

```bash
ruff check . --fix
ruff format .
```

---

# 15. mypy Type Checking

Mypy checks type hints.

Run:

```bash
mypy devops_toolkit
```

You may see missing type stubs for third-party libraries.

Install stubs:

```bash
python -m pip install types-requests
python -m pip freeze > requirements.txt
```

PyYAML stubs may not always be needed depending on mypy version.

---

# 16. Add mypy Config

Add to `pyproject.toml`:

```toml
[tool.mypy]
python_version = "3.12"
warn_return_any = false
warn_unused_configs = true
disallow_untyped_defs = false
ignore_missing_imports = true
```

For learning, we keep it moderate.

Later, stricter:

```toml
disallow_untyped_defs = true
no_implicit_optional = true
warn_unused_ignores = true
```

Run:

```bash
mypy devops_toolkit
```

---

# 17. Bandit Security Scan

Bandit scans Python code for common security issues.

Run:

```bash
bandit -r devops_toolkit scripts
```

Common findings:

```text
subprocess usage
hardcoded password-looking strings
shell=True
assert usage
unsafe yaml loading
```

We already use:

```python
yaml.safe_load()
```

and avoid:

```python
shell=True
```

So Bandit should be mostly okay.

If Bandit flags intentional safe subprocess usage, review carefully before ignoring.

Production rule:

```text
Never blindly suppress security scanner findings.
Understand them first.
```

---

# 18. Add Quality Makefile Targets

Open:

```bash
nano Makefile
```

Replace with:

```makefile
.PHONY: test coverage compile lint format typecheck security quality health env-health linux-health github-report render-report notify-dry-run full-workflow clean

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
make coverage
make lint
make typecheck
make security
```

Then:

```bash
make quality
```

---

# 19. Handling Tool Failures

When you first run quality tools, you may see failures.

Do not panic.

Typical flow:

```bash
ruff check . --fix
ruff format .
pytest
mypy devops_toolkit
bandit -r devops_toolkit scripts
coverage run -m pytest
coverage report
```

If Ruff changes files:

```bash
git diff
```

Review changes before committing.

If mypy complains, either:

```text
add a type hint
simplify a function
ignore missing imports in config
fix Optional handling
```

If Bandit complains:

```text
understand the risk
fix if real
document/skip only if safe and justified
```

---

# 20. Update GitHub Actions Quality Workflow

Create:

```bash
cd ~/devops-masterclass
nano .github/workflows/python-quality.yml
```

Paste:

```yaml
name: Python Quality Gates

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
  quality:
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

      - name: Ruff lint
        run: |
          ruff check .
          ruff format --check .

      - name: Type check
        run: mypy devops_toolkit

      - name: Security scan
        run: bandit -r devops_toolkit scripts

      - name: Test with coverage
        run: |
          coverage run -m pytest
          coverage report
```

Now CI has quality gates.

---

# 21. What About Existing `python-tests.yml`?

You may now have:

```text
python-smoke.yml
python-tests.yml
python-quality.yml
```

That is okay while learning.

But in a real repo, avoid duplicate workflows doing the same thing.

Recommended final state:

```text
python-quality.yml
```

can replace the simpler test workflow.

For now, you can keep both or remove older duplicate workflows later.

---

# 22. Add Quality Notes

Create:

```bash
nano notes/python-testing-quality-gates.md
```

Paste:

````markdown
# Python Testing and Quality Gates

## Quality Gates

A quality gate is an automated check that must pass before code is merged or deployed.

Common Python DevOps gates:

- compile check
- unit tests
- coverage
- linting
- formatting check
- type checking
- security scanning

## Tools

| Tool | Purpose |
|---|---|
| `pytest` | tests |
| `coverage` | test coverage |
| `ruff` | lint and format |
| `mypy` | type checking |
| `bandit` | security scanning |
| `compileall` | syntax compilation |

## Commands

```bash
make compile
make test
make coverage
make lint
make typecheck
make security
make quality
````

## Testing Rules

* Unit tests should not call real APIs.
* Unit tests should not depend on real systemd state.
* Mock subprocess/API calls.
* Put shared fixtures in `tests/conftest.py`.
* Test parsers with sample command output.
* Test validation errors.
* Test CLI `--help`.
* Save coverage reports when useful.

## Production Rules

* Do not blindly ignore security findings.
* Keep quality gates in CI.
* Make local `make quality` match CI.
* Increase coverage over time.
* Keep automation testable by separating logic from CLI.

````

---

# 23. Final Validation

Run:

```bash
cd ~/devops-masterclass/04-python-devops-automation
source .venv/bin/activate
````

Then:

```bash
python -m compileall devops_toolkit scripts tests
pytest
coverage run -m pytest
coverage report
ruff check .
ruff format --check .
mypy devops_toolkit
bandit -r devops_toolkit scripts
make quality
```

If Ruff finds formatting issues:

```bash
ruff check . --fix
ruff format .
make quality
```

If coverage is below threshold:

```bash
coverage report
```

Then add tests for low-coverage modules or temporarily adjust threshold while learning.

---

# 24. Commit Work

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
git commit -m "test: add Python quality gates"
```

Push:

```bash
git push
```

---

# 25. Common Mistakes

## Mistake 1 — Tests depend on internet

Bad:

```python
requests.get("https://github.com")
```

Better:

```python
monkeypatch.setattr(requests, "get", fake_get)
```

## Mistake 2 — Tests depend on real services

Bad:

```python
assert check_service("nginx").ok
```

Better:

```python
monkeypatch.setattr(linux_checks, "run_command", fake_run_command)
```

## Mistake 3 — Ignoring Bandit blindly

Bad:

```text
Bandit says subprocess risk, ignore everything.
```

Better:

```text
Check whether shell=True is used.
Check whether user input reaches command.
Fix or document safely.
```

## Mistake 4 — Coverage obsession

Coverage helps, but 100% coverage does not guarantee correctness.

Better target:

```text
critical logic has tests
parsers have tests
validation has tests
error paths have tests
```

## Mistake 5 — CI does not match local

Bad:

```text
Local runs pytest only.
CI runs lint/mypy/security and fails later.
```

Better:

```bash
make quality
```

locally and in CI.

---

# 26. Interview Answers

Question:

```text
What quality gates would you add for Python DevOps automation?
```

Strong answer:

```text
I would add compile checks, pytest unit tests, coverage, linting and formatting with Ruff, type checking with mypy, and security scanning with Bandit. I would run the same quality command locally and in CI, and block merges if critical gates fail.
```

Question:

```text
How do you test automation that calls APIs or Linux commands?
```

Strong answer:

```text
I mock external dependencies. For APIs, I mock the HTTP request layer and test success, retryable errors, non-retryable errors, and exceptions. For Linux commands, I mock the subprocess wrapper and return sample command outputs. This keeps unit tests deterministic and independent of internet, systemd, or the host machine.
```

Question:

```text
Why use coverage?
```

Strong answer:

```text
Coverage helps identify which parts of the code are not executed by tests. It is not a guarantee of correctness, but it highlights untested areas, especially error handling, config validation, parsers, and report generation. I use it as a guide, not as the only quality metric.
```

Question:

```text
What does Bandit do?
```

Strong answer:

```text
Bandit scans Python code for common security issues such as unsafe subprocess usage, hardcoded secrets, insecure random usage, unsafe YAML loading, and risky patterns. I review findings carefully and fix real issues instead of blindly suppressing them.
```

---

# Today’s Core Rules

```text
Quality gates protect automation from breaking production.
Unit tests should be deterministic.
Mock APIs and subprocess calls.
Test parsers and config validation.
Use coverage as a guide.
Use Ruff for linting and formatting.
Use mypy for type checking.
Use Bandit for security scanning.
Make local quality checks match CI.
Do not blindly ignore scanner warnings.
```

Next lesson:

# Lesson 4.8 — Python Automation Mini Project: Server Audit and Health Report CLI with config, Linux checks, API checks, reports, notifications, tests, and CI quality gates.

# Lesson 4.5 — Python Configuration and Validation

Now we learn a very important DevOps automation skill:

```text
safe configuration handling
```

Most automation scripts fail not because Python syntax is wrong, but because input/config is bad:

```text
wrong URL
missing token
wrong environment name
invalid port
bad YAML indentation
wrong threshold
missing required field
secret accidentally printed
production script run with dev config
```

So today we build safer config patterns.

---

# 1. Why Configuration Validation Matters

Bad automation:

```python
config = yaml.safe_load(file)
url = config["url"]
timeout = config["timeout"]
```

If the YAML is wrong, you get messy errors:

```text
KeyError
TypeError
NoneType object is not subscriptable
```

Good automation validates early:

```text
Config file exists
YAML is valid
Required fields exist
Types are correct
Values are allowed
Secrets are not printed
Defaults are applied intentionally
Errors are human-readable
```

Production rule:

```text
Fail fast before making changes.
```

---

# 2. Configuration Sources in DevOps

Python DevOps tools usually read config from:

```text
CLI arguments
YAML files
JSON files
environment variables
.env files
CI/CD secrets
cloud secret managers
Terraform outputs
Kubernetes ConfigMaps/Secrets
```

Common pattern:

```text
Defaults
  ↓
Config file
  ↓
Environment variables
  ↓
CLI arguments
```

Highest priority usually comes last.

Example:

```text
default timeout = 10
config file timeout = 5
environment TIMEOUT = 3
CLI --timeout 1
final timeout = 1
```

---

# 3. What We Will Build

We will add configuration validation to your Python toolkit.

New files:

```text
devops_toolkit/
├── settings.py
└── validators.py
```

We will validate:

```text
environment name
URLs
ports
timeouts
thresholds
service config
secret presence
```

We will also add:

```text
.env loading pattern
typed settings object
tests
CLI usage
notes
```

---

# 4. Install `python-dotenv`

Go to the project:

```bash
cd ~/devops-masterclass/04-python-devops-automation
source .venv/bin/activate
```

Install:

```bash
python -m pip install python-dotenv
python -m pip freeze > requirements.txt
```

Why?

```text
python-dotenv can load local .env files for development.
In production/CI, use real environment variables or secret managers.
```

Important:

```text
.env is for local development convenience.
Do not commit real .env files.
```

---

# 5. Create `.env.example`

From:

```bash
cd ~/devops-masterclass/04-python-devops-automation
```

Create or update:

```bash
nano .env.example
```

Paste:

```bash
APP_ENV=dev
LOG_LEVEL=INFO
DEFAULT_TIMEOUT=10
DEFAULT_RETRIES=3
GITHUB_TOKEN=replace-with-your-token
WEBHOOK_URL=https://example.invalid/webhook
```

Make sure `.gitignore` contains:

```gitignore
.env
.env.*
```

But allow:

```gitignore
!.env.example
```

So update:

```bash
nano .gitignore
```

Use:

```gitignore
.venv/
__pycache__/
*.pyc
.env
.env.*
!.env.example
reports/*.json
reports/*.log
reports/*.html
```

---

# 6. Create `validators.py`

Create:

```bash
nano devops_toolkit/validators.py
```

Paste:

```python
from urllib.parse import urlparse

from devops_toolkit.exceptions import ConfigError


ALLOWED_ENVIRONMENTS = {"dev", "staging", "prod", "test"}


def validate_environment(value: str) -> str:
    normalized = value.strip().lower()

    if normalized not in ALLOWED_ENVIRONMENTS:
        allowed = ", ".join(sorted(ALLOWED_ENVIRONMENTS))
        raise ConfigError(f"Invalid APP_ENV '{value}'. Allowed values: {allowed}")

    return normalized


def validate_positive_int(name: str, value: int, *, min_value: int = 1, max_value: int | None = None) -> int:
    if not isinstance(value, int):
        raise ConfigError(f"{name} must be an integer")

    if value < min_value:
        raise ConfigError(f"{name} must be >= {min_value}")

    if max_value is not None and value > max_value:
        raise ConfigError(f"{name} must be <= {max_value}")

    return value


def validate_port(port: int) -> int:
    return validate_positive_int("port", port, min_value=1, max_value=65535)


def validate_timeout(timeout: int) -> int:
    return validate_positive_int("timeout", timeout, min_value=1, max_value=300)


def validate_retries(retries: int) -> int:
    return validate_positive_int("retries", retries, min_value=1, max_value=20)


def validate_percent_threshold(name: str, value: int) -> int:
    return validate_positive_int(name, value, min_value=1, max_value=100)


def validate_url(name: str, value: str, *, require_https: bool = False) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ConfigError(f"{name} must be a non-empty string")

    parsed = urlparse(value)

    if parsed.scheme not in {"http", "https"}:
        raise ConfigError(f"{name} must start with http:// or https://")

    if require_https and parsed.scheme != "https":
        raise ConfigError(f"{name} must use https://")

    if not parsed.netloc:
        raise ConfigError(f"{name} must include a hostname")

    return value


def validate_optional_secret(name: str, value: str | None) -> str | None:
    if value is None or value == "":
        return None

    if len(value) < 8:
        raise ConfigError(f"{name} looks too short to be a valid secret")

    return value


def mask_secret(value: str | None) -> str:
    if not value:
        return "<not set>"

    if len(value) <= 8:
        return "********"

    return f"{value[:4]}...{value[-4:]}"
```

Key idea:

```text
Validation logic should be reusable and testable.
```

---

# 7. Create `settings.py`

Create:

```bash
nano devops_toolkit/settings.py
```

Paste:

```python
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv

from devops_toolkit.exceptions import ConfigError
from devops_toolkit.validators import (
    mask_secret,
    validate_environment,
    validate_optional_secret,
    validate_retries,
    validate_timeout,
)


@dataclass(frozen=True)
class AppSettings:
    app_env: str
    log_level: str
    default_timeout: int
    default_retries: int
    github_token: Optional[str]
    webhook_url: Optional[str]

    def safe_summary(self) -> dict:
        return {
            "app_env": self.app_env,
            "log_level": self.log_level,
            "default_timeout": self.default_timeout,
            "default_retries": self.default_retries,
            "github_token": mask_secret(self.github_token),
            "webhook_url": mask_secret(self.webhook_url),
        }


def _get_int_env(name: str, default: int) -> int:
    raw = os.getenv(name)

    if raw is None or raw == "":
        return default

    try:
        return int(raw)
    except ValueError as exc:
        raise ConfigError(f"{name} must be an integer") from exc


def load_app_settings(
    *,
    env_file: Path | None = None,
    load_dotenv_file: bool = True,
) -> AppSettings:
    if load_dotenv_file:
        if env_file:
            load_dotenv(env_file)
        else:
            load_dotenv()

    app_env = validate_environment(os.getenv("APP_ENV", "dev"))

    log_level = os.getenv("LOG_LEVEL", "INFO").upper()

    if log_level not in {"DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"}:
        raise ConfigError("LOG_LEVEL must be DEBUG, INFO, WARNING, ERROR, or CRITICAL")

    default_timeout = validate_timeout(_get_int_env("DEFAULT_TIMEOUT", 10))
    default_retries = validate_retries(_get_int_env("DEFAULT_RETRIES", 3))

    github_token = validate_optional_secret("GITHUB_TOKEN", os.getenv("GITHUB_TOKEN"))
    webhook_url = os.getenv("WEBHOOK_URL") or None

    return AppSettings(
        app_env=app_env,
        log_level=log_level,
        default_timeout=default_timeout,
        default_retries=default_retries,
        github_token=github_token,
        webhook_url=webhook_url,
    )
```

This gives a typed settings object:

```python
settings = load_app_settings()
settings.default_timeout
settings.github_token
```

Better than reading `os.getenv()` everywhere.

---

# 8. Why `safe_summary()`?

Bad:

```python
print(settings)
```

This may print secrets.

Good:

```python
print(settings.safe_summary())
```

Output:

```json
{
  "app_env": "dev",
  "github_token": "ghp_...abcd"
}
```

Production rule:

```text
Settings objects should have a safe way to print configuration without exposing secrets.
```

---

# 9. Create Settings Demo Script

Create:

```bash
nano scripts/settings_demo.py
```

Paste:

```python
#!/usr/bin/env python3

import json
import sys

from devops_toolkit.exceptions import ConfigError
from devops_toolkit.settings import load_app_settings


def main() -> int:
    try:
        settings = load_app_settings()
    except ConfigError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print(json.dumps(settings.safe_summary(), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
chmod +x scripts/settings_demo.py
python scripts/settings_demo.py
```

Test with env vars:

```bash
APP_ENV=prod DEFAULT_TIMEOUT=20 DEFAULT_RETRIES=5 python scripts/settings_demo.py
```

Test invalid:

```bash
APP_ENV=production python scripts/settings_demo.py
```

Expected:

```text
ERROR: Invalid APP_ENV 'production'. Allowed values: dev, prod, staging, test
```

Good. Human-readable failure.

---

# 10. Add Config Schema Validation for Services

Your existing `config.py` validates services. Now we improve URL validation and expected status.

Edit:

```bash
nano devops_toolkit/config.py
```

Add imports:

```python
from devops_toolkit.validators import validate_url
```

Find this part:

```python
if not url or not isinstance(url, str):
    raise ConfigError(f"Service '{name}' requires string field 'url'")
```

Replace with:

```python
if not url or not isinstance(url, str):
    raise ConfigError(f"Service '{name}' requires string field 'url'")

url = validate_url(f"Service '{name}' url", url)
```

Find:

```python
if not isinstance(expected_status, int):
    raise ConfigError(f"Service '{name}' expected_status must be an integer")
```

Replace with:

```python
if not isinstance(expected_status, int):
    raise ConfigError(f"Service '{name}' expected_status must be an integer")

if expected_status < 100 or expected_status > 599:
    raise ConfigError(f"Service '{name}' expected_status must be between 100 and 599")
```

Now bad URLs fail before requests are made.

---

# 11. Add Environment-Specific Config

Create config files:

```bash
mkdir -p configs/environments
```

Create dev:

```bash
nano configs/environments/dev.yaml
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

Create prod example:

```bash
nano configs/environments/prod.yaml
```

Paste:

```yaml
services:
  - name: github
    url: https://github.com
    expected_status: 200
```

Why separate files?

```text
dev can include local services.
prod should include production-safe checks.
```

Production rule:

```text
Do not accidentally run dev config against prod or prod automation against dev.
```

---

# 12. Create Config Resolver

Add to `config.py`:

```bash
nano devops_toolkit/config.py
```

At bottom, add:

```python
from devops_toolkit.paths import CONFIG_DIR


def resolve_environment_config(app_env: str) -> Path:
    path = CONFIG_DIR / "environments" / f"{app_env}.yaml"

    if not path.exists():
        raise ConfigError(f"No config file found for environment '{app_env}': {path}")

    return path
```

Now app can choose config based on `APP_ENV`.

---

# 13. Create Environment Health CLI

Create:

```bash
nano devops_toolkit/env_health_cli.py
```

Paste:

```python
import argparse
import sys
from pathlib import Path

from devops_toolkit.config import load_services_config, resolve_environment_config
from devops_toolkit.exceptions import ConfigError
from devops_toolkit.health import check_services
from devops_toolkit.reports import build_health_report, print_health_summary, write_json_report
from devops_toolkit.settings import load_app_settings
from devops_toolkit.paths import REPORT_DIR


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Environment-aware health checker.")

    parser.add_argument(
        "--env",
        choices=["dev", "staging", "prod", "test"],
        help="Environment name. Overrides APP_ENV.",
    )

    parser.add_argument(
        "--config",
        help="Explicit config file path. Overrides environment config.",
    )

    parser.add_argument(
        "--output",
        default=str(REPORT_DIR / "env-health-report.json"),
        help="Output JSON report path",
    )

    parser.add_argument(
        "--timeout",
        type=int,
        help="HTTP timeout. Overrides DEFAULT_TIMEOUT.",
    )

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        settings = load_app_settings()
        app_env = args.env or settings.app_env
        timeout = args.timeout or settings.default_timeout

        if args.config:
            config_path = Path(args.config)
        else:
            config_path = resolve_environment_config(app_env)

        services = load_services_config(config_path)
    except ConfigError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    results = check_services(services, timeout=timeout)
    report = build_health_report(results)

    output_path = Path(args.output)
    write_json_report(output_path, report)

    print(f"Environment: {app_env}")
    print(f"Config: {config_path}")
    print(f"Timeout: {timeout}")
    print()
    print_health_summary(results)
    print()
    print(f"Report written: {output_path}")

    return 0 if all(result.ok for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
python -m devops_toolkit.env_health_cli --env prod
```

Run dev:

```bash
python -m devops_toolkit.env_health_cli --env dev
```

If local demo is not running, dev may fail. That is okay.

---

# 14. Add Wrapper Script

Create:

```bash
nano scripts/env-health
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

exec python -m devops_toolkit.env_health_cli "$@"
```

Make executable:

```bash
chmod +x scripts/env-health
```

Run:

```bash
./scripts/env-health --env prod
```

---

# 15. Add Tests for Validators

Create:

```bash
nano tests/test_validators.py
```

Paste:

```python
import pytest

from devops_toolkit.exceptions import ConfigError
from devops_toolkit.validators import (
    mask_secret,
    validate_environment,
    validate_port,
    validate_timeout,
    validate_url,
)


def test_validate_environment_ok() -> None:
    assert validate_environment("DEV") == "dev"
    assert validate_environment("prod") == "prod"


def test_validate_environment_invalid() -> None:
    with pytest.raises(ConfigError, match="Invalid APP_ENV"):
        validate_environment("production")


def test_validate_port_ok() -> None:
    assert validate_port(80) == 80
    assert validate_port(65535) == 65535


def test_validate_port_invalid() -> None:
    with pytest.raises(ConfigError):
        validate_port(0)

    with pytest.raises(ConfigError):
        validate_port(70000)


def test_validate_timeout_invalid() -> None:
    with pytest.raises(ConfigError):
        validate_timeout(0)


def test_validate_url_ok() -> None:
    assert validate_url("url", "https://example.com") == "https://example.com"


def test_validate_url_requires_http() -> None:
    with pytest.raises(ConfigError, match="http"):
        validate_url("url", "example.com")


def test_validate_url_require_https() -> None:
    with pytest.raises(ConfigError, match="https"):
        validate_url("url", "http://example.com", require_https=True)


def test_mask_secret() -> None:
    assert mask_secret(None) == "<not set>"
    assert mask_secret("short") == "********"
    assert mask_secret("abcdefghijkl") == "abcd...ijkl"
```

Run:

```bash
pytest tests/test_validators.py
```

---

# 16. Add Tests for Settings

Create:

```bash
nano tests/test_settings.py
```

Paste:

```python
from pathlib import Path

import pytest

from devops_toolkit.exceptions import ConfigError
from devops_toolkit.settings import load_app_settings


def test_load_app_settings_defaults(monkeypatch) -> None:
    for key in [
        "APP_ENV",
        "LOG_LEVEL",
        "DEFAULT_TIMEOUT",
        "DEFAULT_RETRIES",
        "GITHUB_TOKEN",
        "WEBHOOK_URL",
    ]:
        monkeypatch.delenv(key, raising=False)

    settings = load_app_settings(load_dotenv_file=False)

    assert settings.app_env == "dev"
    assert settings.log_level == "INFO"
    assert settings.default_timeout == 10
    assert settings.default_retries == 3
    assert settings.github_token is None


def test_load_app_settings_from_env(monkeypatch) -> None:
    monkeypatch.setenv("APP_ENV", "prod")
    monkeypatch.setenv("LOG_LEVEL", "DEBUG")
    monkeypatch.setenv("DEFAULT_TIMEOUT", "20")
    monkeypatch.setenv("DEFAULT_RETRIES", "5")
    monkeypatch.setenv("GITHUB_TOKEN", "abcdefgh12345678")

    settings = load_app_settings(load_dotenv_file=False)

    assert settings.app_env == "prod"
    assert settings.log_level == "DEBUG"
    assert settings.default_timeout == 20
    assert settings.default_retries == 5
    assert settings.github_token == "abcdefgh12345678"


def test_load_app_settings_invalid_env(monkeypatch) -> None:
    monkeypatch.setenv("APP_ENV", "production")

    with pytest.raises(ConfigError, match="Invalid APP_ENV"):
        load_app_settings(load_dotenv_file=False)


def test_load_app_settings_invalid_timeout(monkeypatch) -> None:
    monkeypatch.setenv("DEFAULT_TIMEOUT", "abc")

    with pytest.raises(ConfigError, match="DEFAULT_TIMEOUT"):
        load_app_settings(load_dotenv_file=False)


def test_load_app_settings_from_env_file(tmp_path: Path, monkeypatch) -> None:
    for key in ["APP_ENV", "LOG_LEVEL", "DEFAULT_TIMEOUT", "DEFAULT_RETRIES"]:
        monkeypatch.delenv(key, raising=False)

    env_file = tmp_path / ".env"
    env_file.write_text(
        """
APP_ENV=staging
LOG_LEVEL=WARNING
DEFAULT_TIMEOUT=15
DEFAULT_RETRIES=4
""",
        encoding="utf-8",
    )

    settings = load_app_settings(env_file=env_file, load_dotenv_file=True)

    assert settings.app_env == "staging"
    assert settings.log_level == "WARNING"
    assert settings.default_timeout == 15
    assert settings.default_retries == 4
```

Run:

```bash
pytest tests/test_settings.py
```

Run all:

```bash
pytest
```

---

# 17. Update Makefile

Edit:

```bash
nano Makefile
```

Update:

```makefile
.PHONY: test compile health linux-health github-report env-health clean

test:
	pytest

compile:
	python -m compileall devops_toolkit scripts tests

health:
	python -m devops_toolkit.cli --config configs/services.yaml --output reports/health-report.json

env-health:
	python -m devops_toolkit.env_health_cli --env prod --output reports/env-health-report.json

linux-health:
	python -m devops_toolkit.linux_cli --services ssh --ports 22 --output reports/linux-report.json

github-report:
	python -m devops_toolkit.github_cli --user octocat --max-pages 1 --output reports/github-repos.json

clean:
	find . -type d -name "__pycache__" -prune -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
```

Run:

```bash
make compile
make test
make env-health
```

---

# 18. Update Requirements

Run:

```bash
python -m pip freeze > requirements.txt
cat requirements.txt
```

You should see packages similar to:

```text
certifi
charset-normalizer
idna
iniconfig
packaging
pluggy
pytest
python-dotenv
PyYAML
requests
urllib3
```

Exact versions may differ.

---

# 19. Configuration Validation Rules

A strong config validation layer should check:

```text
Required fields exist
Field types are correct
Numbers are within safe ranges
URLs are valid
Ports are valid
Environment names are allowed
Secrets are present only when required
Defaults are intentional
Errors are clear
```

Bad error:

```text
KeyError: 'services'
```

Good error:

```text
ERROR: Config must contain 'services'
```

Bad error:

```text
ValueError invalid literal for int()
```

Good error:

```text
ERROR: DEFAULT_TIMEOUT must be an integer
```

---

# 20. `.env` Handling Rules

Use `.env` for local dev:

```bash
cp .env.example .env
nano .env
python scripts/settings_demo.py
```

Use real env vars in CI/CD:

```yaml
env:
  APP_ENV: prod
  DEFAULT_TIMEOUT: 10
```

Use secrets manager for sensitive values:

```text
GitHub Actions Secrets
Jenkins Credentials
AWS Secrets Manager
SSM Parameter Store
Kubernetes Secrets
Vault
```

Never:

```text
commit .env
print tokens
hardcode credentials
include secrets in .env.example
```

---

# 21. Environment-Specific Safety

Bad:

```bash
python deploy.py
```

No idea which environment.

Better:

```bash
python deploy.py --env staging
```

Even better for dangerous actions:

```bash
python deploy.py --env prod --confirm-prod
```

For future production tools, use explicit confirmation:

```text
If app_env == prod and destructive_action:
    require --confirm-prod
```

This prevents accidental prod changes.

---

# 22. Add Notes

Create:

```bash
nano notes/python-config-validation.md
```

Paste:

````markdown
# Python Configuration and Validation

## Why Config Validation Matters

Automation should fail before making changes when config is invalid.

Bad config can cause:

- wrong environment changes
- failed deployments
- invalid API calls
- missing tokens
- wrong ports
- unsafe thresholds
- secret leaks

## Config Sources

Common sources:

- defaults
- YAML/JSON files
- environment variables
- `.env` files for local dev
- CLI arguments
- CI/CD secrets
- secret managers

## Priority Pattern

```text
defaults
  ↓
config file
  ↓
environment variables
  ↓
CLI arguments
````

## Rules

* Validate required fields.
* Validate types.
* Validate ranges.
* Validate URLs.
* Validate ports.
* Validate allowed environment names.
* Use clear error messages.
* Do not print secrets.
* Use `.env.example`, not real `.env`.
* Use typed settings objects.
* Use tests for validators and settings.

## Files Added

```text
devops_toolkit/validators.py
devops_toolkit/settings.py
devops_toolkit/env_health_cli.py
```

## Commands

```bash
python scripts/settings_demo.py
python -m devops_toolkit.env_health_cli --env prod
./scripts/env-health --env prod
pytest tests/test_validators.py tests/test_settings.py
```

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
python scripts/settings_demo.py
python -m devops_toolkit.env_health_cli --env prod --output reports/env-health-report.json
./scripts/env-health --env prod
make compile
make test
make env-health
```

View report:

```bash
cat reports/env-health-report.json | jq .
```

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
git add 04-python-devops-automation
```

Review:

```bash
git diff --staged
```

Commit:

```bash
git commit -m "feat: add Python configuration validation"
```

Push:

```bash
git push
```

---

# 25. Real Production Use Cases

## Use Case 1 — Safe deployment config

Before deployment, validate:

```text
environment is allowed
service name exists
artifact version exists
target hosts are not empty
health URL is valid
timeout is reasonable
rollback enabled
```

## Use Case 2 — API automation config

Validate:

```text
base URL is HTTPS
token exists
timeout is set
retries are reasonable
pagination limit is safe
output path is valid
```

## Use Case 3 — Monitoring config

Validate:

```text
disk threshold between 1 and 100
memory threshold positive
service list not empty
ports between 1 and 65535
webhook URL configured
```

---

# 26. Common Mistakes

## Mistake 1 — Using raw `os.getenv()` everywhere

Bad:

```python
timeout = int(os.getenv("TIMEOUT"))
```

Better:

```python
settings = load_app_settings()
timeout = settings.default_timeout
```

## Mistake 2 — No allowed environment list

Bad:

```text
APP_ENV=production
APP_ENV=prod
APP_ENV=prd
APP_ENV=live
```

Better:

```text
Allowed: dev, staging, prod, test
```

## Mistake 3 — Printing settings directly

Bad:

```python
print(settings)
```

Better:

```python
print(settings.safe_summary())
```

## Mistake 4 — `.env.example` contains real secrets

Bad:

```bash
GITHUB_TOKEN=ghp_real_token
```

Better:

```bash
GITHUB_TOKEN=replace-with-your-token
```

## Mistake 5 — No tests for validation

Config validation is logic. Logic needs tests.

---

# 27. Interview Answers

Question:

```text
How do you handle configuration in Python automation?
```

Strong answer:

```text
I centralize configuration loading in a settings module instead of reading environment variables everywhere. I use defaults, environment variables, optional .env loading for local development, and CLI overrides where needed. I validate types, ranges, allowed environment names, URLs, ports, timeouts, and required secrets. I also make sure secrets are never printed directly and provide a safe summary for debugging.
```

Question:

```text
How do you prevent automation from running against the wrong environment?
```

Strong answer:

```text
I use explicit environment names like dev, staging, prod, and test, validate them against an allowed list, and load environment-specific config files. For risky production actions, I require explicit CLI flags such as --env prod and sometimes --confirm-prod. I avoid relying on implicit defaults for destructive operations.
```

Question:

```text
How do you handle `.env` files?
```

Strong answer:

```text
I use .env files only for local development convenience and keep real .env files out of Git. I commit .env.example with placeholder values only. In CI/CD or production, I use environment variables from a secret store, Jenkins credentials, GitHub Actions Secrets, Kubernetes Secrets, or a cloud secret manager.
```

Question:

```text
Why validate config early?
```

Strong answer:

```text
Validating config early makes automation fail fast before it performs API calls, deployments, or infrastructure changes. It gives clear human-readable errors and prevents partial changes caused by missing fields, invalid URLs, unsafe thresholds, or wrong environment names.
```

---

# Today’s Core Rules

```text
Centralize settings loading.
Validate config before doing work.
Use typed settings objects.
Use clear ConfigError messages.
Use allowed environment names.
Use safe secret masking.
Do not print secrets.
Use .env only for local development.
Commit .env.example, not .env.
Validate URLs, ports, timeouts, retries, and thresholds.
Use tests for validators and settings.
Require explicit confirmation for risky prod actions.
```

Next lesson:

# Lesson 4.6 — Python Logging, Reports, and Notifications: structured logs, JSON logs, rotating files, HTML/Markdown reports, Slack-style notifications, and incident summaries.

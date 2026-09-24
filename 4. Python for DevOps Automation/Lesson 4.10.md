# Lesson 4.10 — Python Module Capstone

# Full CI/CD Automation Toolkit

This is the final capstone for Module 4.

You have already built many useful Python DevOps components:

```text
config validation
Linux checks
HTTP checks
API client
reports
notifications
incident summary
release metadata
artifact validation
preflight checks
rollback decision
tests
quality gates
```

Now we combine them into one complete **CI/CD Automation Toolkit**.

---

# 1. Capstone Goal

By the end of this lesson, you will have a professional Python toolkit that supports this workflow:

```text
Build artifact
  ↓
Generate release metadata
  ↓
Validate artifact
  ↓
Run deployment preflight
  ↓
Run server audit
  ↓
Generate reports
  ↓
Send notification payload
  ↓
Decide rollback
  ↓
Archive evidence
```

This is exactly the kind of internal automation DevOps teams build for production pipelines.

Final command:

```bash
./scripts/cicd-capstone \
  --service demo-api \
  --version 0.1.1 \
  --env prod \
  --artifact reports/demo-api-0.1.1.tar.gz \
  --required-file app/server.py \
  --dry-run-notify
```

Expected outputs:

```text
reports/cicd-capstone/release-metadata.json
reports/cicd-capstone/artifact-validation.json
reports/cicd-capstone/preflight-report.json
reports/cicd-capstone/server-audit.json
reports/cicd-capstone/server-audit.md
reports/cicd-capstone/server-audit.html
reports/cicd-capstone/notification-payload.json
reports/cicd-capstone/rollback-decision.json
```

---

# 2. Capstone Architecture

```text
cicd_capstone_cli.py
  ↓
release.py
artifact.py
preflight.py
audit.py
rollback.py
notifications.py
report_renderers.py
incident.py
settings.py
config.py
```

The CLI orchestrates. The modules do the work.

This is the professional pattern:

```text
CLI = orchestration
Modules = reusable logic
Tests = confidence
Reports = evidence
Exit codes = pipeline decisions
```

---

# 3. Create CI/CD Capstone CLI

Go to your Python project:

```bash
cd ~/devops-masterclass/04-python-devops-automation
source .venv/bin/activate
```

Create:

```bash
nano devops_toolkit/cicd_capstone_cli.py
```

Paste:

```python
import argparse
import json
import sys
from dataclasses import asdict
from pathlib import Path

from devops_toolkit.artifact import validate_artifact
from devops_toolkit.audit import build_audit_report, run_http_audit, run_linux_audit
from devops_toolkit.audit_config import load_audit_config, resolve_audit_config_path
from devops_toolkit.exceptions import ConfigError
from devops_toolkit.incident import render_incident_summary
from devops_toolkit.notifications import build_health_notification_payload
from devops_toolkit.release import build_release_metadata
from devops_toolkit.report_renderers import (
    render_health_html,
    render_health_markdown,
    write_text_report,
)
from devops_toolkit.rollback import decide_rollback
from devops_toolkit.settings import load_app_settings
from devops_toolkit.webhooks import send_json_webhook


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="CI/CD capstone workflow for release validation, audit, reports, and rollback decision."
    )

    parser.add_argument("--service", required=True, help="Service name")
    parser.add_argument("--version", required=True, help="Release version")
    parser.add_argument("--env", required=True, choices=["dev", "staging", "prod", "test"])
    parser.add_argument("--artifact", required=True, help="Artifact path")
    parser.add_argument("--required-file", action="append", default=[])
    parser.add_argument("--commit-sha")
    parser.add_argument("--branch")
    parser.add_argument("--build-number")
    parser.add_argument("--audit-config", help="Explicit audit config path")
    parser.add_argument("--output-dir", default="reports/cicd-capstone")
    parser.add_argument("--timeout", type=int)
    parser.add_argument("--notify", action="store_true")
    parser.add_argument("--dry-run-notify", action="store_true")
    parser.add_argument(
        "--allow-audit-failure",
        action="store_true",
        help="Generate reports and rollback decision, but do not fail the capstone command on audit failures.",
    )

    return parser.parse_args()


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def main() -> int:
    args = parse_args()

    try:
        settings = load_app_settings()
    except ConfigError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    artifact_path = Path(args.artifact)
    timeout = args.timeout or settings.default_timeout

    print("===== CI/CD Capstone Workflow =====")
    print(f"Service: {args.service}")
    print(f"Version: {args.version}")
    print(f"Environment: {args.env}")
    print(f"Artifact: {artifact_path}")
    print(f"Output dir: {output_dir}")
    print()

    try:
        release_metadata = build_release_metadata(
            service=args.service,
            version=args.version,
            environment=args.env,
            artifact=str(artifact_path),
            commit_sha=args.commit_sha,
            branch=args.branch,
            build_number=args.build_number,
        )
    except ConfigError as exc:
        print(f"ERROR: release metadata failed: {exc}", file=sys.stderr)
        return 2

    release_path = output_dir / "release-metadata.json"
    write_json(release_path, release_metadata.to_dict())
    print(f"Release metadata: {release_path}")

    try:
        artifact_result = validate_artifact(
            artifact_path,
            required_files=args.required_file,
        )
    except ConfigError as exc:
        print(f"ERROR: artifact validation failed: {exc}", file=sys.stderr)
        return 2

    artifact_report_path = output_dir / "artifact-validation.json"
    write_json(artifact_report_path, asdict(artifact_result))
    print(f"Artifact validation: {artifact_report_path}")

    if not artifact_result.ok:
        print("ERROR: artifact validation failed", file=sys.stderr)
        return 1

    preflight_payload = {
        "ok": True,
        "checks": [
            {
                "name": "release_metadata",
                "ok": True,
                "path": str(release_path),
            },
            {
                "name": "artifact",
                "ok": artifact_result.ok,
                "path": str(artifact_path),
                "sha256": artifact_result.sha256,
                "missing": artifact_result.required_files_missing,
            },
        ],
    }

    preflight_path = output_dir / "preflight-report.json"
    write_json(preflight_path, preflight_payload)
    print(f"Preflight report: {preflight_path}")

    try:
        audit_config_path = Path(args.audit_config) if args.audit_config else resolve_audit_config_path(args.env)
        audit_config = load_audit_config(audit_config_path)
    except ConfigError as exc:
        print(f"ERROR: audit config failed: {exc}", file=sys.stderr)
        return 2

    linux_results = run_linux_audit(audit_config)
    http_results = run_http_audit(audit_config, timeout=timeout)

    audit_report = build_audit_report(
        environment=args.env,
        linux_results=linux_results,
        http_results=http_results,
    )

    audit_json_path = output_dir / "server-audit.json"
    audit_md_path = output_dir / "server-audit.md"
    audit_html_path = output_dir / "server-audit.html"

    write_json(audit_json_path, audit_report)
    write_text_report(
        audit_md_path,
        render_health_markdown(audit_report, title=f"{args.env} Server Audit Report"),
    )
    write_text_report(
        audit_html_path,
        render_health_html(audit_report, title=f"{args.env} Server Audit Report"),
    )

    print(f"Server audit JSON: {audit_json_path}")
    print(f"Server audit Markdown: {audit_md_path}")
    print(f"Server audit HTML
```
# Lesson 4.10 — Continued

# Complete CI/CD Capstone CLI + Tests + Workflow + Module 4 Wrap-Up

We stopped inside `devops_toolkit/cicd_capstone_cli.py`.

Continue from this part:

```python id="mwf4he"
    print(f"Server audit JSON: {audit_json_path}")
    print(f"Server audit Markdown: {audit_md_path}")
    print(f"Server audit HTML: {audit_html_path}")
```

Now add the remaining code below it.

---

# 4. Finish `cicd_capstone_cli.py`

Open the file again:

```bash id="y7x7gg"
cd ~/devops-masterclass/04-python-devops-automation
source .venv/bin/activate

nano devops_toolkit/cicd_capstone_cli.py
```

Make sure the full file ends like this:

```python id="xefvig"
    print(f"Server audit JSON: {audit_json_path}")
    print(f"Server audit Markdown: {audit_md_path}")
    print(f"Server audit HTML: {audit_html_path}")

    notification_payload = build_health_notification_payload(
        audit_report,
        title=f"{args.env} CI/CD Capstone Audit",
        environment=args.env,
        report_path=str(audit_json_path),
    )

    notification_path = output_dir / "notification-payload.json"
    write_json(notification_path, notification_payload)
    print(f"Notification payload: {notification_path}")

    if args.dry_run_notify:
        print()
        print("===== Notification Dry Run =====")
        print(json.dumps(notification_payload, indent=2))

    if args.notify:
        if not settings.webhook_url:
            print("ERROR: WEBHOOK_URL is required for --notify", file=sys.stderr)
            return 2

        notify_result = send_json_webhook(settings.webhook_url, notification_payload)

        if not notify_result.ok:
            print(
                f"ERROR: notification failed status={notify_result.status_code} error={notify_result.error}",
                file=sys.stderr,
            )
            return 2

        print("Notification sent successfully")

    rollback_decision = decide_rollback(audit_report)

    rollback_path = output_dir / "rollback-decision.json"
    write_json(rollback_path, asdict(rollback_decision))
    print(f"Rollback decision: {rollback_path}")

    incident_path = output_dir / "incident-summary.md"

    if audit_report["summary"]["failed"] > 0:
        incident_summary = render_incident_summary(
            audit_report,
            service=args.service,
            environment=args.env,
            severity="SEV-3",
        )
        write_text_report(incident_path, incident_summary)
        print(f"Incident summary: {incident_path}")

    print()
    print("===== Capstone Summary =====")
    print(f"Release metadata: {release_path}")
    print(f"Artifact validation: {artifact_report_path}")
    print(f"Preflight report: {preflight_path}")
    print(f"Audit report: {audit_json_path}")
    print(f"Notification payload: {notification_path}")
    print(f"Rollback decision: {rollback_path}")
    print()
    print(f"Total checks: {audit_report['summary']['total']}")
    print(f"OK: {audit_report['summary']['ok']}")
    print(f"Failed: {audit_report['summary']['failed']}")
    print(f"Should rollback: {rollback_decision.should_rollback}")
    print(f"Rollback reason: {rollback_decision.reason}")

    if rollback_decision.should_rollback:
        print("ROLLBACK REQUIRED")

    if args.allow_audit_failure:
        return 0

    return 1 if rollback_decision.should_rollback else 0


if __name__ == "__main__":
    raise SystemExit(main())
```

So the full final CLI does this:

```text id="gbtkai"
1. loads settings
2. generates release metadata
3. validates artifact
4. writes preflight report
5. loads audit config
6. runs Linux checks
7. runs HTTP checks
8. generates JSON/Markdown/HTML reports
9. builds notification payload
10. optionally sends webhook
11. decides rollback
12. generates incident summary if failed
13. exits with pipeline-friendly code
```

---

# 5. Add Wrapper Script

Create:

```bash id="750g6r"
nano scripts/cicd-capstone
```

Paste:

```bash id="j7tdw4"
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

exec python -m devops_toolkit.cicd_capstone_cli "$@"
```

Make executable:

```bash id="8tzk1e"
chmod +x scripts/cicd-capstone
```

Test help:

```bash id="uq4yd0"
./scripts/cicd-capstone --help
```

Expected:

```text id="yas2xx"
CI/CD capstone workflow for release validation, audit, reports, and rollback decision.
```

---

# 6. Create Demo Artifact

Before running the capstone, create a sample artifact:

```bash id="z1spz2"
mkdir -p /tmp/cicd-capstone-demo/app

cat > /tmp/cicd-capstone-demo/app/server.py <<'EOF'
print("hello from demo-api")
EOF

cat > /tmp/cicd-capstone-demo/app/demo-api.env.example <<'EOF'
APP_ENV=prod
PORT=8080
EOF

tar -czf reports/demo-api-0.1.1.tar.gz -C /tmp/cicd-capstone-demo app
```

Validate tar contents:

```bash id="qepqx3"
tar -tzf reports/demo-api-0.1.1.tar.gz
```

Expected:

```text id="t7056h"
app/
app/server.py
app/demo-api.env.example
```

---

# 7. Run Capstone Workflow

Run with prod config:

```bash id="63kgvd"
./scripts/cicd-capstone \
  --service demo-api \
  --version 0.1.1 \
  --env prod \
  --artifact reports/demo-api-0.1.1.tar.gz \
  --required-file app/server.py \
  --required-file app/demo-api.env.example \
  --commit-sha abc123 \
  --branch main \
  --build-number 42 \
  --dry-run-notify || true
```

Why `|| true`?

Because if audit checks fail, the command returns non-zero. That is correct behavior.

Check generated files:

```bash id="r7zbuv"
ls -lh reports/cicd-capstone
```

Expected files:

```text id="lcoyn3"
artifact-validation.json
incident-summary.md
notification-payload.json
preflight-report.json
release-metadata.json
rollback-decision.json
server-audit.html
server-audit.json
server-audit.md
```

View reports:

```bash id="euuoig"
cat reports/cicd-capstone/release-metadata.json | jq .
cat reports/cicd-capstone/artifact-validation.json | jq .
cat reports/cicd-capstone/preflight-report.json | jq .
cat reports/cicd-capstone/server-audit.json | jq .
cat reports/cicd-capstone/rollback-decision.json | jq .
```

Open HTML:

```bash id="y1j5gp"
explorer.exe reports/cicd-capstone/server-audit.html
```

For Linux desktop:

```bash id="tyacvc"
xdg-open reports/cicd-capstone/server-audit.html
```

---

# 8. Run Capstone with Dev Config

If prod config fails because SSH or port 22 is not available, test dev:

```bash id="eny25w"
./scripts/cicd-capstone \
  --service demo-api \
  --version 0.1.1 \
  --env dev \
  --artifact reports/demo-api-0.1.1.tar.gz \
  --required-file app/server.py \
  --required-file app/demo-api.env.example \
  --dry-run-notify \
  --allow-audit-failure
```

`--allow-audit-failure` is useful for learning/demo mode.

In production, you normally do **not** use it.

---

# 9. Add Makefile Targets

Open:

```bash id="nn1lri"
nano Makefile
```

Add these targets:

```makefile id="r6ndw1"
capstone-artifact:
	mkdir -p /tmp/cicd-capstone-demo/app
	echo 'print("hello from demo-api")' > /tmp/cicd-capstone-demo/app/server.py
	echo 'APP_ENV=prod' > /tmp/cicd-capstone-demo/app/demo-api.env.example
	tar -czf reports/demo-api-0.1.1.tar.gz -C /tmp/cicd-capstone-demo app

capstone-demo: capstone-artifact
	python -m devops_toolkit.cicd_capstone_cli \
		--service demo-api \
		--version 0.1.1 \
		--env dev \
		--artifact reports/demo-api-0.1.1.tar.gz \
		--required-file app/server.py \
		--required-file app/demo-api.env.example \
		--dry-run-notify \
		--allow-audit-failure
```

Also update your `.PHONY` line to include:

```makefile id="e41ci3"
capstone-artifact capstone-demo
```

Run:

```bash id="u5n51s"
make capstone-demo
```

---

# 10. Add Tests for Capstone CLI Help

Open:

```bash id="551rhg"
nano tests/test_cli_smoke.py
```

Add:

```python id="f8k1lr"
def test_cicd_capstone_cli_help() -> None:
    result = run_cli(["-m", "devops_toolkit.cicd_capstone_cli", "--help"])

    assert result.returncode == 0
    assert "cicd capstone" in result.stdout.lower() or "ci/cd capstone" in result.stdout.lower()
```

Run:

```bash id="6g3t9c"
pytest tests/test_cli_smoke.py
```

---

# 11. Add Capstone Integration Test

Create:

```bash id="mjpsnr"
nano tests/test_cicd_capstone_cli.py
```

Paste:

```python id="1kjxl3"
import subprocess
import sys
import tarfile
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]


def create_test_artifact(path: Path) -> None:
    source_dir = path.parent / "source"
    app_dir = source_dir / "app"
    app_dir.mkdir(parents=True)

    (app_dir / "server.py").write_text("print('hello')\n", encoding="utf-8")
    (app_dir / "demo-api.env.example").write_text("APP_ENV=test\n", encoding="utf-8")

    with tarfile.open(path, "w:gz") as tar:
        tar.add(app_dir, arcname="app")


def test_cicd_capstone_cli_generates_reports(tmp_path: Path) -> None:
    artifact = tmp_path / "demo-api-0.1.1.tar.gz"
    output_dir = tmp_path / "reports"

    create_test_artifact(artifact)

    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "devops_toolkit.cicd_capstone_cli",
            "--service",
            "demo-api",
            "--version",
            "0.1.1",
            "--env",
            "dev",
            "--artifact",
            str(artifact),
            "--required-file",
            "app/server.py",
            "--required-file",
            "app/demo-api.env.example",
            "--output-dir",
            str(output_dir),
            "--dry-run-notify",
            "--allow-audit-failure",
        ],
        cwd=PROJECT_DIR,
        text=True,
        capture_output=True,
        timeout=60,
        check=False,
    )

    assert result.returncode == 0
    assert (output_dir / "release-metadata.json").exists()
    assert (output_dir / "artifact-validation.json").exists()
    assert (output_dir / "preflight-report.json").exists()
    assert (output_dir / "server-audit.json").exists()
    assert (output_dir / "server-audit.md").exists()
    assert (output_dir / "server-audit.html").exists()
    assert (output_dir / "notification-payload.json").exists()
    assert (output_dir / "rollback-decision.json").exists()
```

Run:

```bash id="ztzvft"
pytest tests/test_cicd_capstone_cli.py
```

Run all:

```bash id="gc6sz4"
pytest
```

---

# 12. Add GitHub Actions Capstone Workflow

Create:

```bash id="2qvofy"
cd ~/devops-masterclass
nano .github/workflows/python-capstone-demo.yml
```

Paste:

```yaml id="ap07mi"
name: Python Capstone Demo

on:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  capstone-demo:
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

      - name: Create demo artifact
        run: |
          mkdir -p /tmp/cicd-capstone-demo/app
          echo 'print("hello from demo-api")' > /tmp/cicd-capstone-demo/app/server.py
          echo 'APP_ENV=test' > /tmp/cicd-capstone-demo/app/demo-api.env.example
          tar -czf reports/demo-api-0.1.1.tar.gz -C /tmp/cicd-capstone-demo app

      - name: Run capstone workflow
        run: |
          python -m devops_toolkit.cicd_capstone_cli \
            --service demo-api \
            --version 0.1.1 \
            --env dev \
            --artifact reports/demo-api-0.1.1.tar.gz \
            --required-file app/server.py \
            --required-file app/demo-api.env.example \
            --dry-run-notify \
            --allow-audit-failure

      - name: Upload capstone reports
        uses: actions/upload-artifact@v4
        with:
          name: python-capstone-reports
          path: 04-python-devops-automation/reports/cicd-capstone/
```

Why `--allow-audit-failure` in GitHub Actions?

Because hosted runners are not your production server. Services, ports, and local health endpoints may differ.

CI can demo the workflow and upload reports, but real audits should run on target servers or deployment agents.

---

# 13. Jenkins Capstone Example

Create:

```bash id="e7ur0z"
cd ~/devops-masterclass/04-python-devops-automation
nano notes/jenkins-cicd-capstone-example.md
```

Paste:

````markdown id="utthpb"
# Jenkins CI/CD Capstone Example

This example shows how the Python CI/CD capstone helper can fit into a Jenkins pipeline.

```groovy
pipeline {
  agent any

  environment {
    APP_ENV = "prod"
    SERVICE_NAME = "demo-api"
    VERSION = "0.1.1"
    ARTIFACT = "reports/demo-api-0.1.1.tar.gz"
  }

  stages {
    stage('Setup Python') {
      steps {
        dir('04-python-devops-automation') {
          sh '''
            python3 -m venv .venv
            . .venv/bin/activate
            python -m pip install --upgrade pip
            python -m pip install -r requirements.txt
          '''
        }
      }
    }

    stage('Quality Gates') {
      steps {
        dir('04-python-devops-automation') {
          sh '''
            . .venv/bin/activate
            make quality
          '''
        }
      }
    }

    stage('Build Artifact') {
      steps {
        dir('04-python-devops-automation') {
          sh '''
            mkdir -p /tmp/cicd-capstone-demo/app
            echo 'print("hello from demo-api")' > /tmp/cicd-capstone-demo/app/server.py
            echo 'APP_ENV=prod' > /tmp/cicd-capstone-demo/app/demo-api.env.example
            tar -czf "$ARTIFACT" -C /tmp/cicd-capstone-demo app
          '''
        }
      }
    }

    stage('CI/CD Capstone Pre-Deploy') {
      steps {
        dir('04-python-devops-automation') {
          sh '''
            . .venv/bin/activate
            python -m devops_toolkit.cicd_capstone_cli \
              --service "$SERVICE_NAME" \
              --version "$VERSION" \
              --env "$APP_ENV" \
              --artifact "$ARTIFACT" \
              --required-file app/server.py \
              --required-file app/demo-api.env.example \
              --commit-sha "${GIT_COMMIT}" \
              --branch "${BRANCH_NAME}" \
              --build-number "${BUILD_NUMBER}" \
              --dry-run-notify
          '''
        }
      }
    }

    stage('Deploy') {
      steps {
        echo 'Real deployment would happen here'
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: '04-python-devops-automation/reports/**', fingerprint: true
    }
  }
}
````

## Production Notes

* Run target-server audit on the actual deployment server or deployment agent.
* Use Jenkins Credentials for webhook URLs and tokens.
* Archive JSON, Markdown, HTML, and log files.
* Treat rollback decision exit code separately from script errors.

```
```

---

# 14. Update README

Open:

```bash id="qvnr0m"
nano README.md
```

Add this section:

````markdown id="wi204d"
## CI/CD Capstone Workflow

The capstone command combines release metadata, artifact validation, preflight reporting, server audit, notification payload generation, and rollback decision.

```bash
./scripts/cicd-capstone \
  --service demo-api \
  --version 0.1.1 \
  --env dev \
  --artifact reports/demo-api-0.1.1.tar.gz \
  --required-file app/server.py \
  --required-file app/demo-api.env.example \
  --dry-run-notify \
  --allow-audit-failure
````

Generated files:

```text
reports/cicd-capstone/release-metadata.json
reports/cicd-capstone/artifact-validation.json
reports/cicd-capstone/preflight-report.json
reports/cicd-capstone/server-audit.json
reports/cicd-capstone/server-audit.md
reports/cicd-capstone/server-audit.html
reports/cicd-capstone/notification-payload.json
reports/cicd-capstone/rollback-decision.json
```

````

---

# 15. Add Capstone Notes

Create:

```bash id="3u686s"
nano notes/python-module-capstone.md
````

Paste:

````markdown id="0n1fug"
# Python Module Capstone

## Goal

Build a CI/CD automation toolkit that provides release metadata, artifact validation, preflight checks, audit reports, notification payloads, and rollback decision logic.

## Main Command

```bash
./scripts/cicd-capstone \
  --service demo-api \
  --version 0.1.1 \
  --env prod \
  --artifact reports/demo-api-0.1.1.tar.gz \
  --required-file app/server.py \
  --dry-run-notify
````

## Workflow

```text
Generate release metadata
Validate artifact
Write preflight report
Run Linux audit
Run HTTP audit
Generate JSON/Markdown/HTML reports
Generate notification payload
Decide rollback
Generate incident summary if failed
```

## Outputs

```text
release-metadata.json
artifact-validation.json
preflight-report.json
server-audit.json
server-audit.md
server-audit.html
notification-payload.json
rollback-decision.json
incident-summary.md
```

## Production Rules

* Generate release metadata for every deployment.
* Validate artifacts before deployment.
* Run preflight checks before touching target systems.
* Generate reports even when checks fail.
* Use rollback decision logic after deployment.
* Archive reports as CI/CD artifacts.
* Keep pipeline YAML/Jenkinsfile as orchestration.
* Put complex logic in tested Python modules.

````

---

# 16. Final Validation

Run from Python project:

```bash id="uovbxy"
cd ~/devops-masterclass/04-python-devops-automation
source .venv/bin/activate
````

Run quality gates:

```bash id="56a1d6"
python -m compileall devops_toolkit scripts tests
pytest
ruff check .
ruff format --check .
mypy devops_toolkit
bandit -r devops_toolkit scripts
coverage run -m pytest
coverage report
```

Run capstone demo:

```bash id="gs6ut5"
make capstone-demo
```

Or manually:

```bash id="rhm3xy"
mkdir -p /tmp/cicd-capstone-demo/app
echo 'print("hello from demo-api")' > /tmp/cicd-capstone-demo/app/server.py
echo 'APP_ENV=dev' > /tmp/cicd-capstone-demo/app/demo-api.env.example
tar -czf reports/demo-api-0.1.1.tar.gz -C /tmp/cicd-capstone-demo app

./scripts/cicd-capstone \
  --service demo-api \
  --version 0.1.1 \
  --env dev \
  --artifact reports/demo-api-0.1.1.tar.gz \
  --required-file app/server.py \
  --required-file app/demo-api.env.example \
  --dry-run-notify \
  --allow-audit-failure
```

Check output:

```bash id="92oqtq"
find reports/cicd-capstone -maxdepth 1 -type f -print
```

---

# 17. Commit Work

From repo root:

```bash id="e290lr"
cd ~/devops-masterclass

git status
git diff
```

Add:

```bash id="cxnbe7"
git add 04-python-devops-automation \
        .github/workflows/python-capstone-demo.yml
```

Review:

```bash id="ylc8ke"
git diff --staged
```

Commit:

```bash id="is6fbg"
git commit -m "feat: complete Python CI/CD capstone toolkit"
```

Push:

```bash id="ayioau"
git push
```

Tag Module 4 completion:

```bash id="jb241u"
git tag -a v0.4.0 -m "Complete Module 4 Python DevOps automation"
git push origin v0.4.0
```

---

# 18. How to Explain This Capstone in Interviews

Use this answer:

```text id="gmsn4l"
I built a Python CI/CD automation toolkit for DevOps workflows. It generates release metadata, validates deployment artifacts, runs preflight checks, performs Linux and HTTP server audits, generates JSON/Markdown/HTML reports, creates notification payloads, generates incident summaries, and decides whether rollback is required based on health reports.

The toolkit is structured as reusable Python modules with a thin CLI layer. It includes config validation, safe subprocess execution, API automation, structured logging, tests with pytest, mocked external dependencies, coverage, Ruff linting, mypy type checking, Bandit security scanning, and GitHub Actions/Jenkins integration examples.
```

Short version for resume:

```text id="kx84bq"
Built a Python DevOps automation toolkit for CI/CD workflows, including release metadata generation, artifact validation, deployment preflight checks, server audits, multi-format reports, notification payloads, rollback decision logic, pytest tests, quality gates, and GitHub Actions/Jenkins integration.
```

---

# 19. Production Extensions

You can extend this capstone into a real production tool by adding:

```text id="jshj43"
real Slack/Teams notifications
Jenkins artifact publishing
S3 report upload
GitHub PR comments
Prometheus metrics export
SQLite deployment history
AWS EC2 tag-based server checks
Docker container checks
Kubernetes deployment checks
ArgoCD application status checks
SonarQube quality gate integration
Trivy scan parsing
SBOM validation
```

---

# 20. Module 4 Completion Summary

You completed:

```text id="ejb69m"
Lesson 4.1  Python DevOps foundation
Lesson 4.2  Project structure
Lesson 4.3  Linux automation
Lesson 4.4  API automation
Lesson 4.5  Config validation
Lesson 4.6  Logging, reports, notifications
Lesson 4.7  Testing and quality gates
Lesson 4.8  Server audit mini project
Lesson 4.9  Python for CI/CD helpers
Lesson 4.10 Module capstone
```

You now have strong practical skills in:

```text id="t2rezi"
Python virtual environments
CLI tools
YAML/JSON config
settings management
safe secret handling
API clients
subprocess wrappers
Linux checks
HTTP health checks
structured logging
JSON logs
JSON reports
Markdown reports
HTML reports
notifications
incident summaries
release metadata
artifact validation
preflight checks
rollback decisions
pytest
fixtures
mocking
coverage
ruff
mypy
bandit
GitHub Actions
Jenkins integration
```

---

# 21. Module 4 Final Rules

```text id="jcmdc4"
Python is automation glue for DevOps.
Keep pipeline logic small.
Move complex logic into tested Python modules.
Validate config before action.
Use safe subprocess patterns.
Use timeouts for commands and APIs.
Never print secrets.
Generate reports as evidence.
Use exit codes for pipeline decisions.
Mock external systems in tests.
Run quality gates locally and in CI.
Archive reports for audits and incidents.
```

---

# Module 4 is now complete.

Next module:

# Module 5 — Application Runtime and Production App Basics

In Module 5, we will learn:

```text id="elwlel"
how apps run in production
process lifecycle
ports and listeners
environment variables
config files
reverse proxy basics
health endpoints
graceful shutdown
logs
runtime users
PM2/systemd
Node.js production runtime
Python/FastAPI production runtime
zero-downtime basics
deployment layouts
```

Start next with:

```text id="c5oiwe"
 start Module 5
```

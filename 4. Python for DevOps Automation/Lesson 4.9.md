# Lesson 4.9 — Python for CI/CD and Jenkins/GitHub Actions

Now we connect Python automation with CI/CD.

In real DevOps work, Python scripts are often used inside pipelines for:

```text
artifact validation
release metadata generation
deployment preflight checks
health checks
rollback decision logic
GitHub Actions helper scripts
Jenkins helper scripts
report generation
notification payloads
```

You already built the Python toolkit. Now we make it useful for CI/CD.

---

# 1. Why Python in CI/CD?

CI/CD pipelines should not become huge unreadable YAML or Jenkinsfile logic.

Bad pipeline:

```text
1000 lines of Bash inside Jenkinsfile
complex JSON parsing with jq everywhere
duplicated validation logic
hardcoded release names
manual rollback decisions
```

Better pipeline:

```text
Pipeline orchestrates
Python scripts validate, parse, decide, report
```

Good pattern:

```text
Jenkins/GitHub Actions
  ↓
python -m devops_toolkit.release_cli
  ↓
python -m devops_toolkit.artifact_cli
  ↓
python -m devops_toolkit.preflight_cli
  ↓
python -m devops_toolkit.audit_cli
```

Pipeline should answer:

```text
Can I build?
Can I test?
Can I package?
Is the artifact valid?
Can I deploy safely?
Is the target server healthy?
Did deployment succeed?
Should I rollback?
```

---

# 2. CI/CD Helper Scripts We Will Build

We will add these modules:

```text
devops_toolkit/
├── release.py
├── release_cli.py
├── artifact.py
├── artifact_cli.py
├── preflight.py
├── preflight_cli.py
├── rollback.py
└── rollback_cli.py
```

They will provide:

```text
release metadata JSON
artifact checksum validation
artifact required-file validation
deployment preflight checks
rollback decision from health report
CI/CD-friendly exit codes
```

---

# 3. Release Metadata

A release should have metadata.

Example:

```json
{
  "service": "demo-api",
  "version": "0.1.1",
  "commit_sha": "abc123",
  "branch": "main",
  "build_number": "42",
  "environment": "prod",
  "artifact": "demo-api-0.1.1.tar.gz",
  "created_at": "2026-06-28T10:30:00+00:00"
}
```

Why it matters:

```text
Traceability
Rollback
Auditing
Debugging
Incident response
Deployment history
```

Production rule:

```text
Every deployment should know exactly what version, commit, artifact, and environment was deployed.
```

---

# 4. Create `release.py`

Go to project:

```bash
cd ~/devops-masterclass/04-python-devops-automation
source .venv/bin/activate
```

Create:

```bash
nano devops_toolkit/release.py
```

Paste:

```python
import os
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path

from devops_toolkit.exceptions import ConfigError
from devops_toolkit.validators import validate_environment


@dataclass(frozen=True)
class ReleaseMetadata:
    service: str
    version: str
    environment: str
    commit_sha: str
    branch: str
    build_number: str
    artifact: str
    created_at: str

    def to_dict(self) -> dict:
        return asdict(self)


def get_env_value(name: str, default: str = "unknown") -> str:
    value = os.getenv(name)
    return value if value else default


def build_release_metadata(
    *,
    service: str,
    version: str,
    environment: str,
    artifact: str,
    commit_sha: str | None = None,
    branch: str | None = None,
    build_number: str | None = None,
) -> ReleaseMetadata:
    if not service.strip():
        raise ConfigError("service is required")

    if not version.strip():
        raise ConfigError("version is required")

    if not artifact.strip():
        raise ConfigError("artifact is required")

    validated_environment = validate_environment(environment)

    return ReleaseMetadata(
        service=service,
        version=version,
        environment=validated_environment,
        commit_sha=commit_sha or get_env_value("GITHUB_SHA", get_env_value("GIT_COMMIT")),
        branch=branch
        or get_env_value("GITHUB_REF_NAME", get_env_value("BRANCH_NAME")),
        build_number=build_number
        or get_env_value("GITHUB_RUN_NUMBER", get_env_value("BUILD_NUMBER")),
        artifact=artifact,
        created_at=datetime.now(timezone.utc).isoformat(),
    )


def write_release_metadata(path: Path, metadata: ReleaseMetadata) -> None:
    import json

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(metadata.to_dict(), indent=2), encoding="utf-8")
```

---

# 5. Create Release CLI

Create:

```bash
nano devops_toolkit/release_cli.py
```

Paste:

```python
import argparse
import json
import sys
from pathlib import Path

from devops_toolkit.exceptions import ConfigError
from devops_toolkit.release import build_release_metadata, write_release_metadata


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate release metadata.")

    parser.add_argument("--service", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--env", required=True, choices=["dev", "staging", "prod", "test"])
    parser.add_argument("--artifact", required=True)
    parser.add_argument("--commit-sha")
    parser.add_argument("--branch")
    parser.add_argument("--build-number")
    parser.add_argument("--output", required=True)

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        metadata = build_release_metadata(
            service=args.service,
            version=args.version,
            environment=args.env,
            artifact=args.artifact,
            commit_sha=args.commit_sha,
            branch=args.branch,
            build_number=args.build_number,
        )
    except ConfigError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    output_path = Path(args.output)
    write_release_metadata(output_path, metadata)

    print(json.dumps(metadata.to_dict(), indent=2))
    print(f"Release metadata written: {output_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
python -m devops_toolkit.release_cli \
  --service demo-api \
  --version 0.1.1 \
  --env prod \
  --artifact demo-api-0.1.1.tar.gz \
  --commit-sha abc123 \
  --branch main \
  --build-number 42 \
  --output reports/release-metadata.json
```

View:

```bash
cat reports/release-metadata.json | jq .
```

---

# 6. Add Wrapper Script

Create:

```bash
nano scripts/release-metadata
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

exec python -m devops_toolkit.release_cli "$@"
```

Make executable:

```bash
chmod +x scripts/release-metadata
```

Run:

```bash
./scripts/release-metadata \
  --service demo-api \
  --version 0.1.1 \
  --env prod \
  --artifact demo-api-0.1.1.tar.gz \
  --output reports/release-metadata.json
```

---

# 7. Artifact Validation

A pipeline should validate artifacts before deployment.

Checks:

```text
artifact file exists
artifact is not empty
checksum matches
required files exist inside tar archive
artifact name matches release metadata
```

Example artifact:

```text
demo-api-0.1.1.tar.gz
```

Bad pipeline:

```text
Build artifact missing but deployment continues.
Tar file corrupt.
Wrong version deployed.
Required app file missing.
```

Good pipeline:

```text
Validate artifact before deployment.
Fail early.
```

---

# 8. Create `artifact.py`

Create:

```bash
nano devops_toolkit/artifact.py
```

Paste:

```python
import hashlib
import tarfile
from dataclasses import dataclass
from pathlib import Path

from devops_toolkit.exceptions import ConfigError


@dataclass(frozen=True)
class ArtifactValidationResult:
    artifact_path: str
    exists: bool
    size_bytes: int
    sha256: str | None
    required_files_found: list[str]
    required_files_missing: list[str]
    ok: bool


def calculate_sha256(path: Path) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)

    return digest.hexdigest()


def list_tar_members(path: Path) -> list[str]:
    try:
        with tarfile.open(path, "r:*") as tar:
            return tar.getnames()
    except tarfile.TarError as exc:
        raise ConfigError(f"Invalid tar artifact: {path}: {exc}") from exc


def validate_artifact(
    path: Path,
    *,
    expected_sha256: str | None = None,
    required_files: list[str] | None = None,
) -> ArtifactValidationResult:
    required_files = required_files or []

    if not path.exists():
        return ArtifactValidationResult(
            artifact_path=str(path),
            exists=False,
            size_bytes=0,
            sha256=None,
            required_files_found=[],
            required_files_missing=required_files,
            ok=False,
        )

    if not path.is_file():
        raise ConfigError(f"Artifact path is not a file: {path}")

    size_bytes = path.stat().st_size

    if size_bytes <= 0:
        return ArtifactValidationResult(
            artifact_path=str(path),
            exists=True,
            size_bytes=size_bytes,
            sha256=None,
            required_files_found=[],
            required_files_missing=required_files,
            ok=False,
        )

    sha256 = calculate_sha256(path)

    if expected_sha256 and sha256 != expected_sha256:
        return ArtifactValidationResult(
            artifact_path=str(path),
            exists=True,
            size_bytes=size_bytes,
            sha256=sha256,
            required_files_found=[],
            required_files_missing=required_files,
            ok=False,
        )

    members: list[str] = []

    if path.name.endswith((".tar.gz", ".tgz", ".tar")):
        members = list_tar_members(path)

    found: list[str] = []
    missing: list[str] = []

    for required in required_files:
        if any(member == required or member.endswith(f"/{required}") for member in members):
            found.append(required)
        else:
            missing.append(required)

    ok = bool(path.exists()) and size_bytes > 0 and not missing

    return ArtifactValidationResult(
        artifact_path=str(path),
        exists=True,
        size_bytes=size_bytes,
        sha256=sha256,
        required_files_found=found,
        required_files_missing=missing,
        ok=ok,
    )
```

---

# 9. Create Artifact CLI

Create:

```bash
nano devops_toolkit/artifact_cli.py
```

Paste:

```python
import argparse
import json
import sys
from dataclasses import asdict
from pathlib import Path

from devops_toolkit.artifact import validate_artifact
from devops_toolkit.exceptions import ConfigError


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate deployment artifact.")

    parser.add_argument("--artifact", required=True, help="Artifact path")
    parser.add_argument("--expected-sha256", help="Expected SHA256 checksum")
    parser.add_argument(
        "--required-file",
        action="append",
        default=[],
        help="Required file inside tar artifact. Can be specified multiple times.",
    )
    parser.add_argument("--output", help="Optional JSON validation report path")

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        result = validate_artifact(
            Path(args.artifact),
            expected_sha256=args.expected_sha256,
            required_files=args.required_file,
        )
    except ConfigError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    payload = asdict(result)
    print(json.dumps(payload, indent=2))

    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        print(f"Artifact validation report written: {output_path}")

    return 0 if result.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
```

---

# 10. Test Artifact Validation Locally

Create sample artifact:

```bash
mkdir -p /tmp/demo-artifact/app
echo 'print("hello")' > /tmp/demo-artifact/app/server.py
echo 'APP_NAME=demo-api' > /tmp/demo-artifact/app/demo-api.env.example

tar -czf reports/demo-api-0.1.1.tar.gz -C /tmp/demo-artifact app
```

Validate:

```bash
python -m devops_toolkit.artifact_cli \
  --artifact reports/demo-api-0.1.1.tar.gz \
  --required-file app/server.py \
  --required-file app/demo-api.env.example \
  --output reports/artifact-validation.json
```

Failure example:

```bash
python -m devops_toolkit.artifact_cli \
  --artifact reports/demo-api-0.1.1.tar.gz \
  --required-file app/missing.py
```

Expected:

```text
exit code 1
```

---

# 11. Deployment Preflight Checks

Before deployment, validate:

```text
release metadata exists
artifact exists and is valid
target environment is allowed
server health is acceptable
disk has enough room
memory is sufficient
required service manager exists
```

We will create a preflight checker that reads:

```text
release metadata JSON
artifact validation
optional Linux audit report
```

---

# 12. Create `preflight.py`

Create:

```bash
nano devops_toolkit/preflight.py
```

Paste:

```python
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from devops_toolkit.artifact import validate_artifact
from devops_toolkit.exceptions import ConfigError


@dataclass(frozen=True)
class PreflightResult:
    ok: bool
    checks: list[dict[str, Any]]


def load_json_file(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise ConfigError(f"JSON file not found: {path}")

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ConfigError(f"Invalid JSON file {path}: {exc}") from exc

    if not isinstance(data, dict):
        raise ConfigError(f"JSON root must be object: {path}")

    return data


def check_release_metadata(metadata: dict[str, Any]) -> dict[str, Any]:
    required = ["service", "version", "environment", "commit_sha", "artifact", "created_at"]
    missing = [field for field in required if not metadata.get(field)]

    return {
        "name": "release_metadata",
        "ok": not missing,
        "missing": missing,
    }


def check_audit_report(report: dict[str, Any], max_failed: int = 0) -> dict[str, Any]:
    summary = report.get("summary", {})
    failed = int(summary.get("failed", 0))

    return {
        "name": "audit_report",
        "ok": failed <= max_failed,
        "failed": failed,
        "max_failed": max_failed,
    }


def run_preflight(
    *,
    release_metadata_path: Path,
    artifact_path: Path,
    audit_report_path: Path | None = None,
    required_files: list[str] | None = None,
) -> PreflightResult:
    checks: list[dict[str, Any]] = []

    metadata = load_json_file(release_metadata_path)
    checks.append(check_release_metadata(metadata))

    artifact_result = validate_artifact(
        artifact_path,
        required_files=required_files or [],
    )

    checks.append(
        {
            "name": "artifact",
            "ok": artifact_result.ok,
            "artifact_path": artifact_result.artifact_path,
            "size_bytes": artifact_result.size_bytes,
            "sha256": artifact_result.sha256,
            "missing": artifact_result.required_files_missing,
        }
    )

    if audit_report_path:
        audit_report = load_json_file(audit_report_path)
        checks.append(check_audit_report(audit_report, max_failed=0))

    ok = all(check["ok"] for check in checks)

    return PreflightResult(ok=ok, checks=checks)
```

---

# 13. Create Preflight CLI

Create:

```bash
nano devops_toolkit/preflight_cli.py
```

Paste:

```python
import argparse
import json
import sys
from dataclasses import asdict
from pathlib import Path

from devops_toolkit.exceptions import ConfigError
from devops_toolkit.preflight import run_preflight


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Deployment preflight checker.")

    parser.add_argument("--release-metadata", required=True)
    parser.add_argument("--artifact", required=True)
    parser.add_argument("--audit-report")
    parser.add_argument("--required-file", action="append", default=[])
    parser.add_argument("--output", default="reports/preflight-report.json")

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        result = run_preflight(
            release_metadata_path=Path(args.release_metadata),
            artifact_path=Path(args.artifact),
            audit_report_path=Path(args.audit_report) if args.audit_report else None,
            required_files=args.required_file,
        )
    except ConfigError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    payload = asdict(result)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    print(json.dumps(payload, indent=2))
    print(f"Preflight report written: {output_path}")

    return 0 if result.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
python -m devops_toolkit.preflight_cli \
  --release-metadata reports/release-metadata.json \
  --artifact reports/demo-api-0.1.1.tar.gz \
  --required-file app/server.py \
  --output reports/preflight-report.json
```

---

# 14. Rollback Decision Logic

After deployment, a pipeline can run health checks.

If health report failed, decide rollback.

Rules:

```text
If failed checks == 0 → no rollback
If failed checks > 0 → rollback recommended
If critical service failed → rollback required
If only warning-level check failed → maybe continue
```

We will implement simple logic first.

---

# 15. Create `rollback.py`

Create:

```bash
nano devops_toolkit/rollback.py
```

Paste:

```python
import json
from dataclasses import dataclass
from pathlib import Path

from devops_toolkit.exceptions import ConfigError


@dataclass(frozen=True)
class RollbackDecision:
    should_rollback: bool
    reason: str
    failed_count: int
    failed_checks: list[str]


def load_health_report(path: Path) -> dict:
    if not path.exists():
        raise ConfigError(f"Health report not found: {path}")

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ConfigError(f"Invalid health report JSON: {exc}") from exc

    if not isinstance(data, dict):
        raise ConfigError("Health report root must be an object")

    return data


def decide_rollback(report: dict) -> RollbackDecision:
    results = report.get("results", [])

    if not isinstance(results, list):
        raise ConfigError("Health report results must be a list")

    failed = [result for result in results if not result.get("ok", False)]
    failed_names = [str(result.get("name", "unknown")) for result in failed]

    if not failed:
        return RollbackDecision(
            should_rollback=False,
            reason="all checks passed",
            failed_count=0,
            failed_checks=[],
        )

    critical_failures = [
        name
        for name in failed_names
        if name.startswith("http:")
        or name.startswith("service:")
        or name.startswith("port:")
    ]

    if critical_failures:
        return RollbackDecision(
            should_rollback=True,
            reason="critical health checks failed",
            failed_count=len(failed),
            failed_checks=failed_names,
        )

    return RollbackDecision(
        should_rollback=False,
        reason="only non-critical checks failed",
        failed_count=len(failed),
        failed_checks=failed_names,
    )


def decide_rollback_from_file(path: Path) -> RollbackDecision:
    report = load_health_report(path)
    return decide_rollback(report)
```

---

# 16. Create Rollback CLI

Create:

```bash
nano devops_toolkit/rollback_cli.py
```

Paste:

```python
import argparse
import json
from dataclasses import asdict
from pathlib import Path
import sys

from devops_toolkit.exceptions import ConfigError
from devops_toolkit.rollback import decide_rollback_from_file


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Decide whether rollback is required.")
    parser.add_argument("--health-report", required=True)
    parser.add_argument("--output", default="reports/rollback-decision.json")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        decision = decide_rollback_from_file(Path(args.health_report))
    except ConfigError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    payload = asdict(decision)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    print(json.dumps(payload, indent=2))
    print(f"Rollback decision written: {output_path}")

    return 10 if decision.should_rollback else 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Exit codes:

```text
0   no rollback
10  rollback required
2   script/config error
```

Why not just `1`?

```text
Distinct exit code helps pipeline know the difference between:
rollback required
script failed
```

Run:

```bash
python -m devops_toolkit.rollback_cli \
  --health-report reports/prod-audit.json \
  --output reports/rollback-decision.json

echo $?
```

---

# 17. Add Wrapper Scripts

Create artifact wrapper:

```bash
nano scripts/validate-artifact
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

exec python -m devops_toolkit.artifact_cli "$@"
```

Create preflight wrapper:

```bash
nano scripts/deploy-preflight
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

exec python -m devops_toolkit.preflight_cli "$@"
```

Create rollback wrapper:

```bash
nano scripts/rollback-decision
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

exec python -m devops_toolkit.rollback_cli "$@"
```

Make executable:

```bash
chmod +x scripts/validate-artifact scripts/deploy-preflight scripts/rollback-decision
```

---

# 18. GitHub Actions Example

Create a sample workflow:

```bash
cd ~/devops-masterclass
nano .github/workflows/python-cicd-helper-demo.yml
```

Paste:

```yaml
name: Python CI/CD Helper Demo

on:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  cicd-helper-demo:
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

      - name: Create sample artifact
        run: |
          mkdir -p /tmp/demo-artifact/app
          echo 'print("hello")' > /tmp/demo-artifact/app/server.py
          echo 'APP_NAME=demo-api' > /tmp/demo-artifact/app/demo-api.env.example
          tar -czf reports/demo-api-0.1.1.tar.gz -C /tmp/demo-artifact app

      - name: Generate release metadata
        run: |
          python -m devops_toolkit.release_cli \
            --service demo-api \
            --version 0.1.1 \
            --env test \
            --artifact reports/demo-api-0.1.1.tar.gz \
            --output reports/release-metadata.json

      - name: Validate artifact
        run: |
          python -m devops_toolkit.artifact_cli \
            --artifact reports/demo-api-0.1.1.tar.gz \
            --required-file app/server.py \
            --required-file app/demo-api.env.example \
            --output reports/artifact-validation.json

      - name: Deployment preflight
        run: |
          python -m devops_toolkit.preflight_cli \
            --release-metadata reports/release-metadata.json \
            --artifact reports/demo-api-0.1.1.tar.gz \
            --required-file app/server.py \
            --output reports/preflight-report.json

      - name: Upload reports
        uses: actions/upload-artifact@v4
        with:
          name: cicd-helper-reports
          path: 04-python-devops-automation/reports/
```

This workflow does not deploy. It demonstrates helper scripts safely.

---

# 19. Jenkins Pipeline Example

Create notes file:

```bash
cd ~/devops-masterclass/04-python-devops-automation
nano notes/jenkins-python-helper-example.md
```

Paste:

````markdown
# Jenkins Python Helper Example

Example Jenkins stages using Python helper scripts.

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

    stage('Release Metadata') {
      steps {
        dir('04-python-devops-automation') {
          sh '''
            . .venv/bin/activate
            python -m devops_toolkit.release_cli \
              --service "$SERVICE_NAME" \
              --version "$VERSION" \
              --env "$APP_ENV" \
              --artifact "$ARTIFACT" \
              --output reports/release-metadata.json
          '''
        }
      }
    }

    stage('Validate Artifact') {
      steps {
        dir('04-python-devops-automation') {
          sh '''
            . .venv/bin/activate
            python -m devops_toolkit.artifact_cli \
              --artifact "$ARTIFACT" \
              --required-file app/server.py \
              --output reports/artifact-validation.json
          '''
        }
      }
    }

    stage('Preflight') {
      steps {
        dir('04-python-devops-automation') {
          sh '''
            . .venv/bin/activate
            python -m devops_toolkit.preflight_cli \
              --release-metadata reports/release-metadata.json \
              --artifact "$ARTIFACT" \
              --required-file app/server.py \
              --output reports/preflight-report.json
          '''
        }
      }
    }

    stage('Deploy') {
      steps {
        echo 'Deploy would happen here'
      }
    }

    stage('Post Deploy Audit') {
      steps {
        dir('04-python-devops-automation') {
          sh '''
            . .venv/bin/activate
            python -m devops_toolkit.audit_cli --env "$APP_ENV" --dry-run-notify || true
          '''
        }
      }
    }

    stage('Rollback Decision') {
      steps {
        dir('04-python-devops-automation') {
          sh '''
            . .venv/bin/activate
            set +e
            python -m devops_toolkit.rollback_cli \
              --health-report reports/${APP_ENV}-audit.json \
              --output reports/rollback-decision.json
            code=$?
            set -e

            if [ "$code" -eq 10 ]; then
              echo "Rollback required"
              exit 1
            elif [ "$code" -ne 0 ]; then
              echo "Rollback decision script failed"
              exit "$code"
            else
              echo "No rollback required"
            fi
          '''
        }
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

````

---

# 20. Tests for Release and Rollback

Create:

```bash
nano tests/test_release.py
````

Paste:

```python
from devops_toolkit.release import build_release_metadata


def test_build_release_metadata() -> None:
    metadata = build_release_metadata(
        service="demo-api",
        version="0.1.1",
        environment="prod",
        artifact="demo-api-0.1.1.tar.gz",
        commit_sha="abc123",
        branch="main",
        build_number="42",
    )

    assert metadata.service == "demo-api"
    assert metadata.environment == "prod"
    assert metadata.commit_sha == "abc123"
```

Create:

```bash
nano tests/test_rollback.py
```

Paste:

```python
from devops_toolkit.rollback import decide_rollback


def test_decide_rollback_all_ok() -> None:
    report = {
        "results": [
            {"name": "http:github", "ok": True},
            {"name": "disk:/", "ok": True},
        ]
    }

    decision = decide_rollback(report)

    assert decision.should_rollback is False
    assert decision.failed_count == 0


def test_decide_rollback_critical_failure() -> None:
    report = {
        "results": [
            {"name": "http:api", "ok": False},
            {"name": "disk:/", "ok": True},
        ]
    }

    decision = decide_rollback(report)

    assert decision.should_rollback is True
    assert decision.failed_count == 1
    assert "http:api" in decision.failed_checks


def test_decide_rollback_non_critical_failure() -> None:
    report = {
        "results": [
            {"name": "journal_errors", "ok": False},
            {"name": "disk:/", "ok": True},
        ]
    }

    decision = decide_rollback(report)

    assert decision.should_rollback is False
    assert decision.failed_count == 1
```

Run:

```bash
pytest tests/test_release.py tests/test_rollback.py
```

---

# 21. Tests for Artifact

Create:

```bash
nano tests/test_artifact.py
```

Paste:

```python
import tarfile
from pathlib import Path

from devops_toolkit.artifact import calculate_sha256, validate_artifact


def create_test_tar(path: Path) -> None:
    source_dir = path.parent / "source"
    app_dir = source_dir / "app"
    app_dir.mkdir(parents=True)
    (app_dir / "server.py").write_text("print('hello')\n", encoding="utf-8")

    with tarfile.open(path, "w:gz") as tar:
        tar.add(app_dir, arcname="app")


def test_calculate_sha256(tmp_path: Path) -> None:
    file_path = tmp_path / "file.txt"
    file_path.write_text("hello\n", encoding="utf-8")

    digest = calculate_sha256(file_path)

    assert len(digest) == 64


def test_validate_artifact_ok(tmp_path: Path) -> None:
    artifact = tmp_path / "artifact.tar.gz"
    create_test_tar(artifact)

    result = validate_artifact(artifact, required_files=["app/server.py"])

    assert result.ok is True
    assert result.exists is True
    assert result.required_files_missing == []


def test_validate_artifact_missing_required_file(tmp_path: Path) -> None:
    artifact = tmp_path / "artifact.tar.gz"
    create_test_tar(artifact)

    result = validate_artifact(artifact, required_files=["app/missing.py"])

    assert result.ok is False
    assert result.required_files_missing == ["app/missing.py"]


def test_validate_artifact_missing_file(tmp_path: Path) -> None:
    artifact = tmp_path / "missing.tar.gz"

    result = validate_artifact(artifact, required_files=["app/server.py"])

    assert result.ok is False
    assert result.exists is False
```

Run:

```bash
pytest tests/test_artifact.py
```

---

# 22. Update Makefile

Open:

```bash
nano Makefile
```

Add targets:

```makefile
release-demo:
	python -m devops_toolkit.release_cli --service demo-api --version 0.1.1 --env test --artifact reports/demo-api-0.1.1.tar.gz --output reports/release-metadata.json

artifact-demo:
	mkdir -p /tmp/demo-artifact/app
	echo 'print("hello")' > /tmp/demo-artifact/app/server.py
	tar -czf reports/demo-api-0.1.1.tar.gz -C /tmp/demo-artifact app
	python -m devops_toolkit.artifact_cli --artifact reports/demo-api-0.1.1.tar.gz --required-file app/server.py --output reports/artifact-validation.json

preflight-demo:
	python -m devops_toolkit.preflight_cli --release-metadata reports/release-metadata.json --artifact reports/demo-api-0.1.1.tar.gz --required-file app/server.py --output reports/preflight-report.json

rollback-demo:
	python -m devops_toolkit.rollback_cli --health-report reports/prod-audit.json --output reports/rollback-decision.json
```

Also update `.PHONY` line to include:

```makefile
release-demo artifact-demo preflight-demo rollback-demo
```

Run:

```bash
make artifact-demo
make release-demo
make preflight-demo
```

---

# 23. Final Validation

Run:

```bash
cd ~/devops-masterclass/04-python-devops-automation
source .venv/bin/activate
```

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

Run helper demos:

```bash
make artifact-demo
make release-demo
make preflight-demo
```

Run rollback decision only if you have a report:

```bash
./scripts/server-audit --env prod --dry-run-notify || true

python -m devops_toolkit.rollback_cli \
  --health-report reports/prod-audit.json \
  --output reports/rollback-decision.json || true
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
git add 04-python-devops-automation \
        .github/workflows/python-cicd-helper-demo.yml
```

Review:

```bash
git diff --staged
```

Commit:

```bash
git commit -m "feat: add Python CI/CD helper scripts"
```

Push:

```bash
git push
```

---

# 25. How This Fits Your Jenkins Atomic Deployment

You already used a pattern like:

```text
extract release
npm install
symlink current
PM2 start/restart
health check
rollback if failed
```

Now Python can improve the pipeline:

```text
Before deploy:
  generate release metadata
  validate artifact
  run preflight

Deploy:
  switch symlink
  restart service

After deploy:
  run health/audit
  create report
  decide rollback
  notify
```

Professional deployment flow:

```text
Build
  ↓
Test
  ↓
Package artifact
  ↓
Generate release metadata
  ↓
Validate artifact
  ↓
Preflight target
  ↓
Deploy
  ↓
Post-deploy health audit
  ↓
Rollback decision
  ↓
Notify/report/archive artifacts
```

---

# 26. Interview Answers

Question:

```text
How do you use Python in CI/CD pipelines?
```

Strong answer:

```text
I use Python for pipeline helper logic that becomes hard to maintain in YAML or shell. Examples include generating release metadata, validating artifacts, parsing JSON/YAML config, running preflight checks, generating reports, deciding rollback based on health checks, and sending notifications. The pipeline orchestrates stages, while Python performs structured logic with tests and clear exit codes.
```

Question:

```text
What release metadata do you capture?
```

Strong answer:

```text
I capture service name, version, environment, commit SHA, branch, build number, artifact name, and creation timestamp. This gives traceability for deployments, rollback, auditing, and incident response.
```

Question:

```text
How do you validate an artifact before deployment?
```

Strong answer:

```text
I check that the artifact exists, is not empty, has the expected checksum if available, and contains required files such as the application entrypoint or config template. For tar artifacts, I inspect members before deployment. If validation fails, the pipeline stops before touching production.
```

Question:

```text
How do you automate rollback decisions?
```

Strong answer:

```text
After deployment, I run health checks and generate a structured report. A rollback decision script reads that report and applies rules. For example, if HTTP, service, or port checks fail, rollback is required. The script uses distinct exit codes so the pipeline can separate rollback-required from script failure.
```

---

# Today’s Core Rules

```text
Keep pipeline YAML/Jenkinsfile as orchestration.
Put complex logic in tested Python helpers.
Generate release metadata for every deployment.
Validate artifacts before deployment.
Run preflight before touching target systems.
Always run post-deploy health checks.
Use structured reports as pipeline artifacts.
Use clear exit codes for pipeline decisions.
Separate rollback-required from script-error.
Archive reports for audit and incident response.
```

Next lesson:

# Lesson 4.10 — Python Module Capstone: Full CI/CD Automation Toolkit with release metadata, artifact validation, server audit, reports, notifications, rollback decision, tests, and GitHub Actions/Jenkins integration.

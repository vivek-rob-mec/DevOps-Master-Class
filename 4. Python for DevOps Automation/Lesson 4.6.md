# Lesson 4.6 — Python Logging, Reports, and Notifications

Now we learn how to make Python DevOps automation **operationally useful**.

A script that only prints random output is okay for learning.

A production-ready automation tool should produce:

```text
clear logs
structured evidence
machine-readable reports
human-readable reports
notifications
safe error messages
incident summaries
```

Today we will extend your Python toolkit with:

```text
structured logging
JSON log formatting
file logging
Markdown reports
HTML reports
notification/webhook payloads
incident summary generation
tests
```

---

# 1. Why Logging and Reports Matter

During production work, you need to answer:

```text
What ran?
When did it run?
Which environment?
Which checks passed?
Which checks failed?
What changed?
Where is the evidence?
Can another engineer understand this later?
```

Bad automation output:

```text
failed
```

Good automation output:

```text
2026-06-28T10:20:30 INFO Starting health check env=prod
2026-06-28T10:20:31 INFO Checked github status=200 ok=true
2026-06-28T10:20:32 ERROR Checked api status=500 ok=false
Report written: reports/env-health-report.json
Markdown summary written: reports/env-health-report.md
Exit code: 1
```

Production rule:

```text
Logs are for timeline.
Reports are for evidence.
Notifications are for action.
```

---

# 2. Logs vs Reports vs Notifications

| Item            | Purpose                   | Example                                   |
| --------------- | ------------------------- | ----------------------------------------- |
| Logs            | execution timeline        | “started check”, “API failed”, “retrying” |
| JSON report     | machine-readable evidence | CI artifact, API upload, automation input |
| Markdown report | human-readable summary    | PR comment, incident note                 |
| HTML report     | shareable visual report   | daily operations report                   |
| Notification    | alert/action prompt       | Slack/Teams/webhook message               |

A good DevOps tool often produces all four.

---

# 3. Logging Levels

Python logging levels:

```text
DEBUG     detailed troubleshooting
INFO      normal execution progress
WARNING   something unusual but not fatal
ERROR     operation failed
CRITICAL  severe failure
```

Use them like this:

```text
DEBUG     request payload without secrets
INFO      started deployment
WARNING   retrying failed API request
ERROR     health check failed
CRITICAL  cannot continue safely
```

Avoid:

```text
Using ERROR for everything
Using print everywhere
Logging secrets
Logging huge payloads unnecessarily
```

---

# 4. Improve Logging Configuration

You already have:

```text
devops_toolkit/logging_config.py
```

Now we improve it.

Open:

```bash
cd ~/devops-masterclass/04-python-devops-automation
source .venv/bin/activate

nano devops_toolkit/logging_config.py
```

Replace with:

```python
import json
import logging
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)

        for key, value in record.__dict__.items():
            if key.startswith("_"):
                continue

            if key in {
                "name",
                "msg",
                "args",
                "levelname",
                "levelno",
                "pathname",
                "filename",
                "module",
                "exc_info",
                "exc_text",
                "stack_info",
                "lineno",
                "funcName",
                "created",
                "msecs",
                "relativeCreated",
                "thread",
                "threadName",
                "processName",
                "process",
            }:
                continue

            payload[key] = value

        return json.dumps(payload, default=str)


def configure_logging(
    verbose: bool = False,
    *,
    json_logs: bool = False,
    log_file: Path | None = None,
) -> None:
    level = logging.DEBUG if verbose else logging.INFO

    handlers: list[logging.Handler] = []

    console_handler = logging.StreamHandler(sys.stderr)

    if json_logs:
        console_handler.setFormatter(JsonFormatter())
    else:
        console_handler.setFormatter(
            logging.Formatter("%(asctime)s %(levelname)s %(name)s %(message)s")
        )

    handlers.append(console_handler)

    if log_file:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        file_handler = logging.FileHandler(log_file, encoding="utf-8")

        if json_logs:
            file_handler.setFormatter(JsonFormatter())
        else:
            file_handler.setFormatter(
                logging.Formatter("%(asctime)s %(levelname)s %(name)s %(message)s")
            )

        handlers.append(file_handler)

    logging.basicConfig(
        level=level,
        handlers=handlers,
        force=True,
    )
```

Key improvements:

```text
optional JSON logs
optional log file
stderr console logging
safe structured fields
force=True so config is applied consistently
```

---

# 5. Logging Demo with Structured Fields

Create:

```bash
nano scripts/structured_logging_demo.py
```

Paste:

```python
#!/usr/bin/env python3

import argparse
import logging
from pathlib import Path

from devops_toolkit.logging_config import configure_logging


logger = logging.getLogger(__name__)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Structured logging demo.")
    parser.add_argument("--json-logs", action="store_true")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--log-file", default="")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    configure_logging(
        verbose=args.verbose,
        json_logs=args.json_logs,
        log_file=Path(args.log_file) if args.log_file else None,
    )

    logger.info(
        "starting automation",
        extra={
            "env": "dev",
            "tool": "structured_logging_demo",
        },
    )

    logger.warning(
        "retrying API request",
        extra={
            "attempt": 1,
            "max_attempts": 3,
            "status_code": 503,
        },
    )

    logger.error(
        "health check failed",
        extra={
            "service": "demo-api",
            "url": "http://127.0.0.1:8080/health",
            "status_code": 500,
        },
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
chmod +x scripts/structured_logging_demo.py

python scripts/structured_logging_demo.py
python scripts/structured_logging_demo.py --json-logs
python scripts/structured_logging_demo.py --json-logs --log-file reports/demo.log
cat reports/demo.log | jq .
```

If `jq` fails because the log file has multiple JSON lines, use:

```bash
while read -r line; do echo "$line" | jq .; done < reports/demo.log
```

---

# 6. JSON Logs vs JSON Reports

JSON logs are usually one JSON object per line:

```json
{"timestamp":"...","level":"INFO","message":"starting automation"}
{"timestamp":"...","level":"ERROR","message":"health check failed"}
```

This is called:

```text
JSON Lines
NDJSON
newline-delimited JSON
```

JSON reports are usually one complete JSON document:

```json
{
  "timestamp": "...",
  "summary": {
    "total": 5,
    "failed": 1
  },
  "results": []
}
```

Rule:

```text
Use JSON logs for event streams.
Use JSON reports for final evidence.
```

---

# 7. Create Report Rendering Module

Create:

```bash
nano devops_toolkit/report_renderers.py
```

Paste:

```python
from html import escape
from pathlib import Path
from typing import Any


def render_health_markdown(report: dict[str, Any], title: str = "Health Report") -> str:
    summary = report.get("summary", {})
    results = report.get("results", [])

    lines = [
        f"# {title}",
        "",
        f"- Timestamp: `{report.get('timestamp', 'unknown')}`",
        f"- Total: `{summary.get('total', 0)}`",
        f"- OK: `{summary.get('ok', 0)}`",
        f"- Failed: `{summary.get('failed', 0)}`",
        "",
        "## Results",
        "",
        "| Status | Name | Details | Error |",
        "|---|---|---|---|",
    ]

    for result in results:
        ok = result.get("ok", False)
        status_icon = "✅ OK" if ok else "❌ FAIL"
        name = str(result.get("name", "unknown"))
        error = str(result.get("error") or "")
        details = result.get("details", {})

        compact_details = ", ".join(
            f"{key}={value}" for key, value in details.items() if key != "lines"
        )

        lines.append(
            f"| {status_icon} | `{name}` | {compact_details} | {error} |"
        )

    lines.append("")
    return "\n".join(lines)


def render_health_html(report: dict[str, Any], title: str = "Health Report") -> str:
    summary = report.get("summary", {})
    results = report.get("results", [])

    rows = []

    for result in results:
        ok = result.get("ok", False)
        status = "OK" if ok else "FAIL"
        name = escape(str(result.get("name", "unknown")))
        error = escape(str(result.get("error") or ""))
        details = result.get("details", {})

        compact_details = escape(
            ", ".join(f"{key}={value}" for key, value in details.items() if key != "lines")
        )

        rows.append(
            f"""
            <tr>
              <td>{status}</td>
              <td><code>{name}</code></td>
              <td>{compact_details}</td>
              <td>{error}</td>
            </tr>
            """
        )

    return f"""<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>{escape(title)}</title>
  <style>
    body {{
      font-family: Arial, sans-serif;
      margin: 2rem;
      line-height: 1.5;
    }}
    table {{
      border-collapse: collapse;
      width: 100%;
    }}
    th, td {{
      border: 1px solid #ddd;
      padding: 8px;
      vertical-align: top;
    }}
    th {{
      background: #f2f2f2;
      text-align: left;
    }}
    code {{
      background: #f6f8fa;
      padding: 2px 4px;
      border-radius: 4px;
    }}
  </style>
</head>
<body>
  <h1>{escape(title)}</h1>

  <ul>
    <li><strong>Timestamp:</strong> <code>{escape(str(report.get("timestamp", "unknown")))}</code></li>
    <li><strong>Total:</strong> {escape(str(summary.get("total", 0)))}</li>
    <li><strong>OK:</strong> {escape(str(summary.get("ok", 0)))}</li>
    <li><strong>Failed:</strong> {escape(str(summary.get("failed", 0)))}</li>
  </ul>

  <h2>Results</h2>

  <table>
    <thead>
      <tr>
        <th>Status</th>
        <th>Name</th>
        <th>Details</th>
        <th>Error</th>
      </tr>
    </thead>
    <tbody>
      {"".join(rows)}
    </tbody>
  </table>
</body>
</html>
"""


def write_text_report(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
```

This lets us convert JSON reports into Markdown and HTML.

---

# 8. Create Report Converter CLI

Create:

```bash
nano devops_toolkit/report_cli.py
```

Paste:

```python
import argparse
import json
import sys
from pathlib import Path

from devops_toolkit.report_renderers import (
    render_health_html,
    render_health_markdown,
    write_text_report,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert JSON health reports to Markdown/HTML.")

    parser.add_argument("--input", required=True, help="Input JSON report")
    parser.add_argument("--markdown-output", help="Markdown output path")
    parser.add_argument("--html-output", help="HTML output path")
    parser.add_argument("--title", default="Health Report")

    return parser.parse_args()


def load_report(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"Report not found: {path}")

    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    args = parse_args()
    input_path = Path(args.input)

    try:
        report = load_report(input_path)
    except (FileNotFoundError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if not args.markdown_output and not args.html_output:
        print("ERROR: specify --markdown-output and/or --html-output", file=sys.stderr)
        return 1

    if args.markdown_output:
        markdown = render_health_markdown(report, title=args.title)
        write_text_report(Path(args.markdown_output), markdown)
        print(f"Markdown report written: {args.markdown_output}")

    if args.html_output:
        html = render_health_html(report, title=args.title)
        write_text_report(Path(args.html_output), html)
        print(f"HTML report written: {args.html_output}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run using an existing report:

```bash
python -m devops_toolkit.env_health_cli --env prod --output reports/env-health-report.json

python -m devops_toolkit.report_cli \
  --input reports/env-health-report.json \
  --markdown-output reports/env-health-report.md \
  --html-output reports/env-health-report.html \
  --title "Production Health Report"
```

View:

```bash
cat reports/env-health-report.md
```

On WSL, to open HTML from Windows:

```bash
explorer.exe reports/env-health-report.html
```

---

# 9. Add Wrapper Script

Create:

```bash
nano scripts/render-report
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

exec python -m devops_toolkit.report_cli "$@"
```

Make executable:

```bash
chmod +x scripts/render-report
```

Run:

```bash
./scripts/render-report \
  --input reports/env-health-report.json \
  --markdown-output reports/env-health-report.md \
  --html-output reports/env-health-report.html
```

---

# 10. Notification Payloads

A notification should be:

```text
short
actionable
safe
clear about status
linked to report if possible
not full of secrets
```

Bad notification:

```text
failed
```

Good notification:

```text
❌ Production Health Check Failed

Environment: prod
Total checks: 5
Failed: 1
Failed checks:
- service:demo-api — service not active

Report: reports/env-health-report.json
```

---

# 11. Create Notification Module

Create:

```bash
nano devops_toolkit/notifications.py
```

Paste:

```python
from typing import Any


def build_health_notification_payload(
    report: dict[str, Any],
    *,
    title: str = "Health Check",
    environment: str = "unknown",
    report_path: str | None = None,
) -> dict[str, Any]:
    summary = report.get("summary", {})
    results = report.get("results", [])

    failed_results = [result for result in results if not result.get("ok", False)]
    failed_count = int(summary.get("failed", len(failed_results)))
    total = int(summary.get("total", len(results)))

    status_icon = "✅" if failed_count == 0 else "❌"
    status_text = "PASSED" if failed_count == 0 else "FAILED"

    lines = [
        f"{status_icon} {title} {status_text}",
        "",
        f"Environment: {environment}",
        f"Total checks: {total}",
        f"Failed checks: {failed_count}",
    ]

    if failed_results:
        lines.append("")
        lines.append("Failed:")
        for result in failed_results[:10]:
            name = result.get("name", "unknown")
            error = result.get("error") or result.get("status") or "failed"
            lines.append(f"- {name}: {error}")

    if report_path:
        lines.append("")
        lines.append(f"Report: {report_path}")

    return {
        "text": "\n".join(lines),
        "status": status_text.lower(),
        "environment": environment,
        "total": total,
        "failed": failed_count,
    }
```

This creates a generic JSON payload that works for Slack-style or custom webhook receivers.

---

# 12. Create Notify CLI

Create:

```bash
nano devops_toolkit/notify_cli.py
```

Paste:

```python
import argparse
import json
import os
import sys
from pathlib import Path

from devops_toolkit.notifications import build_health_notification_payload
from devops_toolkit.webhooks import send_json_webhook


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Send health report notification.")

    parser.add_argument("--report", required=True, help="JSON health report path")
    parser.add_argument("--env", default="unknown", help="Environment name")
    parser.add_argument("--title", default="Health Check", help="Notification title")
    parser.add_argument("--webhook-url", help="Webhook URL. Defaults to WEBHOOK_URL env var.")
    parser.add_argument("--dry-run", action="store_true", help="Print payload without sending")

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    report_path = Path(args.report)

    if not report_path.exists():
        print(f"ERROR: report not found: {report_path}", file=sys.stderr)
        return 1

    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON report: {exc}", file=sys.stderr)
        return 1

    payload = build_health_notification_payload(
        report,
        title=args.title,
        environment=args.env,
        report_path=str(report_path),
    )

    if args.dry_run:
        print(json.dumps(payload, indent=2))
        return 0

    webhook_url = args.webhook_url or os.getenv("WEBHOOK_URL")

    if not webhook_url:
        print("ERROR: webhook URL required via --webhook-url or WEBHOOK_URL", file=sys.stderr)
        return 1

    result = send_json_webhook(webhook_url, payload)

    if not result.ok:
        print(
            f"ERROR: webhook failed status={result.status_code} error={result.error}",
            file=sys.stderr,
        )
        return 1

    print("Notification sent successfully")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run dry-run:

```bash
python -m devops_toolkit.notify_cli \
  --report reports/env-health-report.json \
  --env prod \
  --title "Production Health Check" \
  --dry-run
```

Do not use a real webhook until you are ready.

---

# 13. Add Wrapper Script

Create:

```bash
nano scripts/notify-health
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

exec python -m devops_toolkit.notify_cli "$@"
```

Make executable:

```bash
chmod +x scripts/notify-health
```

Run:

```bash
./scripts/notify-health \
  --report reports/env-health-report.json \
  --env prod \
  --dry-run
```

---

# 14. Incident Summary Generator

Incident summaries are common in SRE/DevOps.

We will generate a Markdown incident summary from a health report.

Create:

```bash
nano devops_toolkit/incident.py
```

Paste:

```python
from typing import Any


def render_incident_summary(
    report: dict[str, Any],
    *,
    service: str = "unknown",
    environment: str = "unknown",
    severity: str = "SEV-3",
) -> str:
    summary = report.get("summary", {})
    results = report.get("results", [])
    failed_results = [result for result in results if not result.get("ok", False)]

    lines = [
        "# Incident Summary",
        "",
        "## Metadata",
        "",
        f"- Service: `{service}`",
        f"- Environment: `{environment}`",
        f"- Severity: `{severity}`",
        f"- Report timestamp: `{report.get('timestamp', 'unknown')}`",
        f"- Total checks: `{summary.get('total', len(results))}`",
        f"- Failed checks: `{summary.get('failed', len(failed_results))}`",
        "",
        "## Impact",
        "",
        "Describe user or system impact here.",
        "",
        "## Failed Checks",
        "",
    ]

    if failed_results:
        for result in failed_results:
            lines.extend(
                [
                    f"### {result.get('name', 'unknown')}",
                    "",
                    f"- Status: `{result.get('status', 'unknown')}`",
                    f"- Error: `{result.get('error') or 'n/a'}`",
                    f"- Details: `{result.get('details', {})}`",
                    "",
                ]
            )
    else:
        lines.append("No failed checks were reported.")
        lines.append("")

    lines.extend(
        [
            "## Timeline",
            "",
            "| Time | Event | Evidence |",
            "|---|---|---|",
            "| TBD | Alert detected | Health report |",
            "| TBD | Investigation started | Logs/metrics |",
            "| TBD | Mitigation applied | Change record |",
            "| TBD | Service recovered | Health check |",
            "",
            "## Root Cause",
            "",
            "TBD",
            "",
            "## Mitigation",
            "",
            "TBD",
            "",
            "## Prevention",
            "",
            "- Add or improve monitoring.",
            "- Update runbook.",
            "- Add tests or validation.",
            "- Improve deployment safety.",
            "",
        ]
    )

    return "\n".join(lines)
```

Create CLI:

```bash
nano devops_toolkit/incident_cli.py
```

Paste:

```python
import argparse
import json
import sys
from pathlib import Path

from devops_toolkit.incident import render_incident_summary
from devops_toolkit.report_renderers import write_text_report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate incident summary from health report.")

    parser.add_argument("--report", required=True, help="Input JSON health report")
    parser.add_argument("--output", required=True, help="Output Markdown incident summary")
    parser.add_argument("--service", default="unknown")
    parser.add_argument("--env", default="unknown")
    parser.add_argument("--severity", default="SEV-3")

    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report_path = Path(args.report)

    if not report_path.exists():
        print(f"ERROR: report not found: {report_path}", file=sys.stderr)
        return 1

    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON report: {exc}", file=sys.stderr)
        return 1

    content = render_incident_summary(
        report,
        service=args.service,
        environment=args.env,
        severity=args.severity,
    )

    write_text_report(Path(args.output), content)
    print(f"Incident summary written: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
python -m devops_toolkit.incident_cli \
  --report reports/env-health-report.json \
  --output reports/incident-summary.md \
  --service demo-api \
  --env prod \
  --severity SEV-3

cat reports/incident-summary.md
```

---

# 15. Add Wrapper Script

Create:

```bash
nano scripts/incident-summary
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

exec python -m devops_toolkit.incident_cli "$@"
```

Make executable:

```bash
chmod +x scripts/incident-summary
```

Run:

```bash
./scripts/incident-summary \
  --report reports/env-health-report.json \
  --output reports/incident-summary.md \
  --service demo-api \
  --env prod
```

---

# 16. One Command Full Workflow

Now you can run a complete automation workflow:

```bash
./scripts/env-health --env prod --output reports/prod-health.json || true

./scripts/render-report \
  --input reports/prod-health.json \
  --markdown-output reports/prod-health.md \
  --html-output reports/prod-health.html \
  --title "Production Health Report"

./scripts/notify-health \
  --report reports/prod-health.json \
  --env prod \
  --title "Production Health Check" \
  --dry-run

./scripts/incident-summary \
  --report reports/prod-health.json \
  --output reports/prod-incident-summary.md \
  --service demo-api \
  --env prod
```

Why `|| true` in first command?

Because the health command exits non-zero if checks fail. For report rendering practice, you may still want to continue generating reports.

In CI/CD, you would usually capture the exit code and decide whether to continue.

---

# 17. Add Automation Workflow Script

Create:

```bash
nano scripts/full-health-workflow
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-prod}"
SERVICE="${2:-demo-api}"

REPORT_JSON="reports/${ENVIRONMENT}-health.json"
REPORT_MD="reports/${ENVIRONMENT}-health.md"
REPORT_HTML="reports/${ENVIRONMENT}-health.html"
INCIDENT_MD="reports/${ENVIRONMENT}-incident-summary.md"

health_exit=0

python -m devops_toolkit.env_health_cli \
  --env "$ENVIRONMENT" \
  --output "$REPORT_JSON" || health_exit=$?

python -m devops_toolkit.report_cli \
  --input "$REPORT_JSON" \
  --markdown-output "$REPORT_MD" \
  --html-output "$REPORT_HTML" \
  --title "${ENVIRONMENT} Health Report"

python -m devops_toolkit.notify_cli \
  --report "$REPORT_JSON" \
  --env "$ENVIRONMENT" \
  --title "${ENVIRONMENT} Health Check" \
  --dry-run

if [ "$health_exit" -ne 0 ]; then
  python -m devops_toolkit.incident_cli \
    --report "$REPORT_JSON" \
    --output "$INCIDENT_MD" \
    --service "$SERVICE" \
    --env "$ENVIRONMENT"

  echo "Health check failed. Incident summary generated: $INCIDENT_MD"
else
  echo "Health check passed."
fi

echo "JSON report: $REPORT_JSON"
echo "Markdown report: $REPORT_MD"
echo "HTML report: $REPORT_HTML"

exit "$health_exit"
```

Make executable:

```bash
chmod +x scripts/full-health-workflow
```

Run:

```bash
./scripts/full-health-workflow prod demo-api
```

This is now a professional mini DevOps workflow.

---

# 18. Tests for Report Renderers

Create:

```bash
nano tests/test_report_renderers.py
```

Paste:

```python
from devops_toolkit.report_renderers import render_health_html, render_health_markdown


def sample_report() -> dict:
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


def test_render_health_markdown() -> None:
    markdown = render_health_markdown(sample_report(), title="Test Report")

    assert "# Test Report" in markdown
    assert "service:ssh" in markdown
    assert "port:80" in markdown
    assert "❌ FAIL" in markdown


def test_render_health_html() -> None:
    html = render_health_html(sample_report(), title="Test Report")

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

# 19. Tests for Notifications

Create:

```bash
nano tests/test_notifications.py
```

Paste:

```python
from devops_toolkit.notifications import build_health_notification_payload


def test_build_health_notification_payload_passed() -> None:
    report = {
        "summary": {
            "total": 1,
            "ok": 1,
            "failed": 0,
        },
        "results": [
            {
                "name": "service:ssh",
                "ok": True,
                "status": "active",
                "error": None,
            }
        ],
    }

    payload = build_health_notification_payload(
        report,
        title="Health Check",
        environment="prod",
        report_path="reports/health.json",
    )

    assert payload["status"] == "passed"
    assert payload["failed"] == 0
    assert "PASSED" in payload["text"]


def test_build_health_notification_payload_failed() -> None:
    report = {
        "summary": {
            "total": 1,
            "ok": 0,
            "failed": 1,
        },
        "results": [
            {
                "name": "service:api",
                "ok": False,
                "status": "inactive",
                "error": "service not active",
            }
        ],
    }

    payload = build_health_notification_payload(
        report,
        title="Health Check",
        environment="prod",
    )

    assert payload["status"] == "failed"
    assert payload["failed"] == 1
    assert "service:api" in payload["text"]
```

Run:

```bash
pytest tests/test_notifications.py
```

Run all:

```bash
pytest
```

---

# 20. Update Makefile

Open:

```bash
nano Makefile
```

Replace with:

```makefile
.PHONY: test compile health env-health linux-health github-report render-report notify-dry-run full-workflow clean

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

render-report:
	python -m devops_toolkit.report_cli --input reports/env-health-report.json --markdown-output reports/env-health-report.md --html-output reports/env-health-report.html

notify-dry-run:
	python -m devops_toolkit.notify_cli --report reports/env-health-report.json --env prod --dry-run

full-workflow:
	./scripts/full-health-workflow prod demo-api

clean:
	find . -type d -name "__pycache__" -prune -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
```

Run:

```bash
make compile
make test
make env-health || true
make render-report
make notify-dry-run
```

---

# 21. Update `.gitignore`

Because reports are generated artifacts, we usually do not commit them.

Open:

```bash
nano .gitignore
```

Make sure:

```gitignore
reports/*.json
reports/*.log
reports/*.html
reports/*.md
```

Keep:

```text
reports/.gitkeep
```

If needed, add:

```gitignore
!reports/.gitkeep
```

Final useful `.gitignore`:

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
reports/*.md
!reports/.gitkeep
```

---

# 22. Notes File

Create:

```bash
nano notes/python-logging-reports-notifications.md
```

Paste:

````markdown
# Python Logging, Reports, and Notifications

## Purpose

Production automation should produce:

- logs for timeline
- JSON reports for machines
- Markdown reports for humans
- HTML reports for sharing
- notifications for action
- incident summaries for postmortems

## Logging Rules

- Use logging instead of random print statements.
- Use DEBUG for details.
- Use INFO for normal progress.
- Use WARNING for unusual but non-fatal events.
- Use ERROR for failed operations.
- Do not log secrets.
- Use JSON logs when logs are consumed by machines.

## Report Rules

- JSON reports should be machine-readable.
- Markdown reports should be readable in GitHub/PRs.
- HTML reports should be shareable.
- Reports should include timestamp, summary, and detailed results.

## Notification Rules

- Keep notifications short.
- Include environment.
- Include status.
- Include failed checks.
- Include report path/link.
- Do not include secrets.

## Files Added

```text
devops_toolkit/report_renderers.py
devops_toolkit/report_cli.py
devops_toolkit/notifications.py
devops_toolkit/notify_cli.py
devops_toolkit/incident.py
devops_toolkit/incident_cli.py
scripts/render-report
scripts/notify-health
scripts/incident-summary
scripts/full-health-workflow
````

## Commands

```bash
python -m devops_toolkit.report_cli --input reports/env-health-report.json --markdown-output reports/env-health-report.md --html-output reports/env-health-report.html

python -m devops_toolkit.notify_cli --report reports/env-health-report.json --env prod --dry-run

python -m devops_toolkit.incident_cli --report reports/env-health-report.json --output reports/incident-summary.md --service demo-api --env prod

./scripts/full-health-workflow prod demo-api
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
python scripts/structured_logging_demo.py --json-logs
python -m devops_toolkit.env_health_cli --env prod --output reports/env-health-report.json
python -m devops_toolkit.report_cli --input reports/env-health-report.json --markdown-output reports/env-health-report.md --html-output reports/env-health-report.html
python -m devops_toolkit.notify_cli --report reports/env-health-report.json --env prod --dry-run
python -m devops_toolkit.incident_cli --report reports/env-health-report.json --output reports/incident-summary.md --service demo-api --env prod
make compile
make test
```

Optional:

```bash
./scripts/full-health-workflow prod demo-api
```

If health fails, it should generate an incident summary and exit non-zero. That is expected behavior.

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
git commit -m "feat: add Python logging reports and notifications"
```

Push:

```bash
git push
```

---

# 25. Real Production Use Cases

## Use Case 1 — CI/CD deployment report

After deployment:

```bash
./scripts/full-health-workflow prod demo-api
```

Artifacts:

```text
prod-health.json
prod-health.md
prod-health.html
prod-incident-summary.md if failed
```

In GitHub Actions/Jenkins, upload these as build artifacts.

## Use Case 2 — Daily operations report

Run daily via cron/systemd timer:

```bash
python -m devops_toolkit.env_health_cli --env prod --output reports/daily-prod-health.json
python -m devops_toolkit.report_cli --input reports/daily-prod-health.json --markdown-output reports/daily-prod-health.md --html-output reports/daily-prod-health.html
```

## Use Case 3 — Incident notification

When health fails:

```bash
WEBHOOK_URL="$SLACK_WEBHOOK_URL" \
python -m devops_toolkit.notify_cli \
  --report reports/prod-health.json \
  --env prod \
  --title "Production Health Check"
```

## Use Case 4 — Postmortem starter

Generate a draft:

```bash
python -m devops_toolkit.incident_cli \
  --report reports/prod-health.json \
  --output reports/incident-summary.md \
  --service demo-api \
  --env prod \
  --severity SEV-3
```

Then fill in root cause, mitigation, prevention.

---

# 26. Common Mistakes

## Mistake 1 — Only printing output

Bad:

```python
print("failed")
```

Better:

```text
log error
write JSON report
return non-zero
generate human summary
```

## Mistake 2 — Logging secrets

Bad:

```python
logger.info("token=%s", token)
```

Better:

```python
logger.info("token configured")
```

## Mistake 3 — Notifications too noisy

Bad:

```text
Send 500-line report to Slack.
```

Better:

```text
Send short summary and link/path to full report.
```

## Mistake 4 — No artifacts

Bad:

```text
CI job failed but no report remains.
```

Better:

```text
Always save JSON/Markdown/HTML reports as artifacts.
```

## Mistake 5 — No incident template

Bad:

```text
Everyone writes incident notes differently.
```

Better:

```text
Generate consistent incident summary template.
```

---

# 27. Interview Answers

Question:

```text
How do you design logging for Python DevOps automation?
```

Strong answer:

```text
I use the Python logging module instead of random print statements. I configure consistent formatting, support verbose mode for DEBUG logs, and optionally JSON logs for machine parsing. I log normal progress at INFO, retries at WARNING, failures at ERROR, and I never log secrets. For production automation, I also write reports separately from logs.
```

Question:

```text
What is the difference between logs and reports?
```

Strong answer:

```text
Logs show the execution timeline and help debug what happened step by step. Reports summarize final results and evidence in a structured way, usually JSON for machines and Markdown or HTML for humans. Logs are event streams, while reports are final artifacts.
```

Question:

```text
How would you notify a team about a failed automation check?
```

Strong answer:

```text
I would send a short actionable notification with the environment, overall status, number of failed checks, top failed checks, and a link or path to the full report. I would avoid dumping full logs into the notification and never include secrets.
```

Question:

```text
How do you support incident response with automation?
```

Strong answer:

```text
I generate structured health reports and, when checks fail, create an incident summary template with metadata, failed checks, timeline placeholders, impact, root cause, mitigation, and prevention sections. This gives responders a consistent starting point and preserves evidence for postmortems.
```

---

# Today’s Core Rules

```text
Use logs for timeline.
Use reports for evidence.
Use notifications for action.
Use JSON logs when machines consume logs.
Use JSON reports for automation artifacts.
Use Markdown/HTML reports for humans.
Keep notifications short and actionable.
Never log secrets.
Always save reports in CI/CD.
Generate incident summaries for failures.
```

Next lesson:

# Lesson 4.7 — Python Testing and Quality Gates: pytest deeper, fixtures, mocking subprocess/API calls, coverage, ruff, mypy basics, bandit security scanning, and CI quality gates.

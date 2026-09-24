# Lesson 4.4 — Python API Automation

Now we learn one of the most useful Python DevOps skills:

```text
API automation
```

Modern DevOps work is full of APIs:

```text
GitHub API
GitLab API
Jenkins API
AWS APIs
Kubernetes API
Docker registry API
Prometheus API
Grafana API
Slack/Teams webhooks
PagerDuty/Opsgenie APIs
Cloudflare API
SonarQube API
Security scanner APIs
```

Bash can call APIs with `curl`.

Python is better when you need:

```text
authentication
retries
timeouts
pagination
JSON parsing
error handling
report generation
multiple API calls
clean reusable code
tests
```

---

# 1. API Automation Mental Model

An API request usually has:

```text
URL
HTTP method
headers
query parameters
body/payload
authentication
timeout
response status code
response body
error handling
```

Example:

```text
GET https://api.github.com/repos/octocat/Hello-World

Headers:
  Accept: application/vnd.github+json
  Authorization: Bearer <token>
```

Python flow:

```text
Build request
  ↓
Send request with timeout
  ↓
Check status code
  ↓
Parse JSON
  ↓
Handle errors
  ↓
Return structured result
```

---

# 2. Why Not Just Use curl?

`curl` is great for quick testing:

```bash
curl -I https://api.github.com
```

But Python is better for automation like:

```text
Read repositories from config
Call GitHub API for each repo
Handle rate limits
Retry transient failures
Paginate results
Generate JSON report
Exit non-zero if policy fails
```

Example Bash becomes messy:

```bash
curl -sS "$URL" | jq ...
```

Example Python is easier to structure:

```python
response = session.get(url, timeout=10)
data = response.json()
```

---

# 3. HTTP Methods

Common API methods:

| Method   | Meaning        | Example         |
| -------- | -------------- | --------------- |
| `GET`    | read data      | list repos      |
| `POST`   | create/action  | trigger webhook |
| `PUT`    | replace/create | upload config   |
| `PATCH`  | partial update | update issue    |
| `DELETE` | delete         | remove resource |

DevOps examples:

```text
GET deployment status
POST Slack notification
POST Jenkins build trigger
PATCH GitHub issue
DELETE old artifact
```

---

# 4. HTTP Status Codes for APIs

Common status codes:

|        Code | Meaning               | DevOps Interpretation             |
| ----------: | --------------------- | --------------------------------- |
|         200 | OK                    | request succeeded                 |
|         201 | Created               | resource created                  |
|         202 | Accepted              | async job accepted                |
|         204 | No Content            | success without body              |
|         400 | Bad Request           | wrong payload/params              |
|         401 | Unauthorized          | missing/invalid token             |
|         403 | Forbidden             | token lacks permission/rate limit |
|         404 | Not Found             | resource missing or no permission |
|         409 | Conflict              | state conflict                    |
|         422 | Validation Failed     | bad input                         |
|         429 | Too Many Requests     | rate limited                      |
|         500 | Server Error          | API server problem                |
| 502/503/504 | Gateway/service issue | retry may help                    |

Production rule:

```text
Do not treat every non-200 the same.
Different status codes need different action.
```

---

# 5. `requests.Session`

A `Session` reuses connection settings and default headers.

Bad for repeated calls:

```python
requests.get(url1)
requests.get(url2)
requests.get(url3)
```

Better:

```python
session = requests.Session()
session.headers.update({"Accept": "application/json"})

session.get(url1)
session.get(url2)
session.get(url3)
```

Benefits:

```text
shared headers
connection reuse
cleaner auth handling
easier testing
consistent timeouts through wrapper
```

---

# 6. Create `api_client.py`

Go to your Python project:

```bash
cd ~/devops-masterclass/04-python-devops-automation
source .venv/bin/activate
```

Create:

```bash
nano devops_toolkit/api_client.py
```

Paste:

```python
import logging
import time
from dataclasses import dataclass
from typing import Any, Optional

import requests


logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class ApiResponse:
    method: str
    url: str
    status_code: Optional[int]
    ok: bool
    data: Any
    error: Optional[str]
    attempts: int


class ApiClient:
    def __init__(
        self,
        base_url: str = "",
        headers: Optional[dict[str, str]] = None,
        timeout: int = 10,
        retries: int = 3,
        retry_delay: float = 1.0,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.retries = retries
        self.retry_delay = retry_delay
        self.session = requests.Session()

        if headers:
            self.session.headers.update(headers)

    def build_url(self, path_or_url: str) -> str:
        if path_or_url.startswith("http://") or path_or_url.startswith("https://"):
            return path_or_url

        if not self.base_url:
            return path_or_url

        return f"{self.base_url}/{path_or_url.lstrip('/')}"

    def request(
        self,
        method: str,
        path_or_url: str,
        *,
        params: Optional[dict[str, Any]] = None,
        json_body: Optional[dict[str, Any]] = None,
        expected_statuses: tuple[int, ...] = (200,),
    ) -> ApiResponse:
        url = self.build_url(path_or_url)
        method_upper = method.upper()

        last_error: Optional[str] = None
        last_status: Optional[int] = None
        last_data: Any = None

        for attempt in range(1, self.retries + 1):
            try:
                logger.debug(
                    "API request attempt=%s method=%s url=%s",
                    attempt,
                    method_upper,
                    url,
                )

                response = self.session.request(
                    method=method_upper,
                    url=url,
                    params=params,
                    json=json_body,
                    timeout=self.timeout,
                )

                last_status = response.status_code

                try:
                    last_data = response.json() if response.content else None
                except ValueError:
                    last_data = response.text

                if response.status_code in expected_statuses:
                    return ApiResponse(
                        method=method_upper,
                        url=url,
                        status_code=response.status_code,
                        ok=True,
                        data=last_data,
                        error=None,
                        attempts=attempt,
                    )

                last_error = f"unexpected status {response.status_code}"

                if not self._should_retry(response.status_code):
                    break

            except requests.RequestException as exc:
                last_error = str(exc)

            if attempt < self.retries:
                time.sleep(self.retry_delay)

        return ApiResponse(
            method=method_upper,
            url=url,
            status_code=last_status,
            ok=False,
            data=last_data,
            error=last_error,
            attempts=self.retries,
        )

    @staticmethod
    def _should_retry(status_code: int) -> bool:
        return status_code in {408, 429, 500, 502, 503, 504}

    def get(
        self,
        path_or_url: str,
        *,
        params: Optional[dict[str, Any]] = None,
        expected_statuses: tuple[int, ...] = (200,),
    ) -> ApiResponse:
        return self.request(
            "GET",
            path_or_url,
            params=params,
            expected_statuses=expected_statuses,
        )

    def post(
        self,
        path_or_url: str,
        *,
        json_body: Optional[dict[str, Any]] = None,
        expected_statuses: tuple[int, ...] = (200, 201, 202, 204),
    ) -> ApiResponse:
        return self.request(
            "POST",
            path_or_url,
            json_body=json_body,
            expected_statuses=expected_statuses,
        )
```

This gives us:

```text
reusable API client
session support
timeouts
retries
JSON parsing
expected status handling
structured result
```

---

# 7. Why Retry Only Some Status Codes?

Retrying every failure is dangerous.

Retryable:

```text
408 request timeout
429 rate limited
500 server error
502 bad gateway
503 service unavailable
504 gateway timeout
network timeout/connection reset
```

Usually not retryable:

```text
400 bad request
401 unauthorized
403 forbidden
404 not found
422 validation error
```

Why?

```text
If payload is invalid, retrying will not fix it.
If token is wrong, retrying will not fix it.
If resource does not exist, retrying usually will not fix it.
```

Production rule:

```text
Retry transient failures, not permanent input/auth failures.
```

---

# 8. Create Basic API Demo

Create:

```bash
nano scripts/api_get_demo.py
```

Paste:

```python
#!/usr/bin/env python3

from devops_toolkit.api_client import ApiClient


def main() -> int:
    client = ApiClient(
        base_url="https://api.github.com",
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "devops-toolkit-learning",
        },
        timeout=10,
        retries=3,
    )

    response = client.get("/repos/octocat/Hello-World")

    print(f"OK: {response.ok}")
    print(f"Status: {response.status_code}")
    print(f"Attempts: {response.attempts}")

    if not response.ok:
        print(f"ERROR: {response.error}")
        return 1

    print(f"Repo: {response.data['full_name']}")
    print(f"Stars: {response.data['stargazers_count']}")
    print(f"Forks: {response.data['forks_count']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
chmod +x scripts/api_get_demo.py
python scripts/api_get_demo.py
```

---

# 9. Authentication with Tokens

Many APIs require tokens.

Typical header:

```text
Authorization: Bearer <token>
```

GitHub commonly uses:

```text
Authorization: Bearer <GITHUB_TOKEN>
```

Do not hardcode tokens:

Bad:

```python
headers = {"Authorization": "Bearer ghp_real_token_here"}
```

Good:

```python
import os

token = os.getenv("GITHUB_TOKEN")
```

Create:

```bash
nano scripts/github_auth_demo.py
```

Paste:

```python
#!/usr/bin/env python3

import os
import sys

from devops_toolkit.api_client import ApiClient


def main() -> int:
    token = os.getenv("GITHUB_TOKEN")

    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "devops-toolkit-learning",
    }

    if token:
        headers["Authorization"] = f"Bearer {token}"
        print("GITHUB_TOKEN is configured")
    else:
        print("GITHUB_TOKEN is not configured; using unauthenticated request")

    client = ApiClient(
        base_url="https://api.github.com",
        headers=headers,
        timeout=10,
        retries=3,
    )

    response = client.get("/user" if token else "/rate_limit")

    if not response.ok:
        print(f"ERROR: {response.error}", file=sys.stderr)
        print(f"Status: {response.status_code}", file=sys.stderr)
        return 1

    print(response.data)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run unauthenticated:

```bash
chmod +x scripts/github_auth_demo.py
python scripts/github_auth_demo.py
```

Run authenticated:

```bash
GITHUB_TOKEN=your_token_here python scripts/github_auth_demo.py
```

Security rule:

```text
Do not paste real tokens into scripts.
Do not commit tokens.
Do not print tokens.
```

---

# 10. Use `.env.example`, Not Real `.env`

Create:

```bash
nano .env.example
```

Paste:

```bash
GITHUB_TOKEN=replace-with-your-token
SLACK_WEBHOOK_URL=https://example.invalid/webhook
```

Ensure `.gitignore` has:

```gitignore
.env
.env.*
```

Commit `.env.example`, not `.env`.

If using local env:

```bash
cp .env.example .env
nano .env
```

Load manually:

```bash
set -a
source .env
set +a
```

But never commit `.env`.

---

# 11. API Pagination

Many APIs do not return all results in one response.

They paginate.

Common styles:

```text
page + per_page
next cursor
Link header
next token
```

GitHub uses `page` and `per_page`, plus `Link` headers.

Example:

```text
GET /users/octocat/repos?per_page=30&page=1
GET /users/octocat/repos?per_page=30&page=2
```

Create a helper function for simple page-based pagination.

Create:

```bash
nano devops_toolkit/github.py
```

Paste:

```python
from typing import Any

from devops_toolkit.api_client import ApiClient


def create_github_client(token: str | None = None) -> ApiClient:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "devops-toolkit-learning",
    }

    if token:
        headers["Authorization"] = f"Bearer {token}"

    return ApiClient(
        base_url="https://api.github.com",
        headers=headers,
        timeout=10,
        retries=3,
        retry_delay=1.0,
    )


def list_user_repos(
    client: ApiClient,
    username: str,
    per_page: int = 30,
    max_pages: int = 3,
) -> list[dict[str, Any]]:
    repos: list[dict[str, Any]] = []

    for page in range(1, max_pages + 1):
        response = client.get(
            f"/users/{username}/repos",
            params={
                "per_page": per_page,
                "page": page,
                "sort": "updated",
            },
        )

        if not response.ok:
            raise RuntimeError(
                f"GitHub API failed: status={response.status_code} error={response.error}"
            )

        page_data = response.data

        if not isinstance(page_data, list):
            raise RuntimeError("GitHub API returned unexpected non-list response")

        if not page_data:
            break

        repos.extend(page_data)

        if len(page_data) < per_page:
            break

    return repos
```

Create script:

```bash
nano scripts/github_repos.py
```

Paste:

```python
#!/usr/bin/env python3

import argparse
import json
import os
import sys
from pathlib import Path

from devops_toolkit.github import create_github_client, list_user_repos


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="List GitHub user repositories.")
    parser.add_argument("--user", required=True, help="GitHub username")
    parser.add_argument("--per-page", type=int, default=30)
    parser.add_argument("--max-pages", type=int, default=2)
    parser.add_argument("--output", default="reports/github-repos.json")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    token = os.getenv("GITHUB_TOKEN")
    client = create_github_client(token)

    try:
        repos = list_user_repos(
            client=client,
            username=args.user,
            per_page=args.per_page,
            max_pages=args.max_pages,
        )
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    simplified = [
        {
            "name": repo["name"],
            "full_name": repo["full_name"],
            "private": repo["private"],
            "html_url": repo["html_url"],
            "language": repo["language"],
            "stars": repo["stargazers_count"],
            "forks": repo["forks_count"],
            "updated_at": repo["updated_at"],
        }
        for repo in repos
    ]

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(simplified, indent=2), encoding="utf-8")

    print(f"Repos found: {len(simplified)}")
    print(f"Report written: {output_path}")

    for repo in simplified[:10]:
        print(f"- {repo['full_name']} stars={repo['stars']} updated={repo['updated_at']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
chmod +x scripts/github_repos.py
python scripts/github_repos.py --user octocat --max-pages 1
cat reports/github-repos.json | jq .
```

---

# 12. Rate Limit Awareness

APIs often rate-limit you.

GitHub has a rate limit endpoint:

```text
GET /rate_limit
```

Create:

```bash
nano scripts/github_rate_limit.py
```

Paste:

```python
#!/usr/bin/env python3

import os
import sys

from devops_toolkit.github import create_github_client


def main() -> int:
    token = os.getenv("GITHUB_TOKEN")
    client = create_github_client(token)

    response = client.get("/rate_limit")

    if not response.ok:
        print(f"ERROR: {response.error}", file=sys.stderr)
        return 1

    core = response.data.get("resources", {}).get("core", {})

    print("===== GitHub Rate Limit =====")
    print(f"Limit: {core.get('limit')}")
    print(f"Remaining: {core.get('remaining')}")
    print(f"Used: {core.get('used')}")
    print(f"Reset epoch: {core.get('reset')}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
chmod +x scripts/github_rate_limit.py
python scripts/github_rate_limit.py
```

Production rule:

```text
If an API returns 429 or rate limit headers, back off instead of hammering it.
```

---

# 13. Webhook Pattern

A webhook is an HTTP endpoint where you send events.

Examples:

```text
Slack incoming webhook
Microsoft Teams webhook
Discord webhook
Custom incident receiver
Deployment notification endpoint
```

Typical pattern:

```text
POST webhook URL
JSON payload
Check response status
Do not print webhook secret URL
```

Create generic webhook module:

```bash
nano devops_toolkit/webhooks.py
```

Paste:

```python
from dataclasses import dataclass
from typing import Optional

from devops_toolkit.api_client import ApiClient


@dataclass(frozen=True)
class WebhookResult:
    ok: bool
    status_code: Optional[int]
    error: Optional[str]


def send_json_webhook(
    webhook_url: str,
    payload: dict,
    timeout: int = 10,
) -> WebhookResult:
    client = ApiClient(timeout=timeout, retries=3, retry_delay=1.0)

    response = client.post(
        webhook_url,
        json_body=payload,
        expected_statuses=(200, 201, 202, 204),
    )

    return WebhookResult(
        ok=response.ok,
        status_code=response.status_code,
        error=response.error,
    )
```

Create script:

```bash
nano scripts/webhook_demo.py
```

Paste:

```python
#!/usr/bin/env python3

import os
import sys
from datetime import datetime, timezone

from devops_toolkit.webhooks import send_json_webhook


def main() -> int:
    webhook_url = os.getenv("WEBHOOK_URL")

    if not webhook_url:
        print("ERROR: WEBHOOK_URL is required", file=sys.stderr)
        return 1

    payload = {
        "text": "DevOps toolkit webhook test",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "status": "ok",
    }

    result = send_json_webhook(webhook_url, payload)

    if not result.ok:
        print(f"ERROR: webhook failed status={result.status_code} error={result.error}", file=sys.stderr)
        return 1

    print("Webhook sent successfully")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run with a test webhook only:

```bash
WEBHOOK_URL="https://example.invalid/webhook" python scripts/webhook_demo.py
```

It will fail for example.invalid, but the structure is correct.

Security rule:

```text
Webhook URLs are secrets.
Do not commit or print real webhook URLs.
```

---

# 14. Robust Error Handling Pattern

Bad:

```python
response = requests.get(url)
data = response.json()
print(data["name"])
```

Problems:

```text
No timeout
No error handling
No status check
Assumes JSON
Assumes key exists
```

Better:

```python
try:
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    data = response.json()
except requests.RequestException as exc:
    ...
except ValueError:
    ...
```

Our `ApiClient` centralizes this.

Production rule:

```text
Do not repeat raw requests logic everywhere.
Wrap it once and reuse.
```

---

# 15. Add Tests for API Client

We will mock `requests.Session.request`.

Create:

```bash
nano tests/test_api_client.py
```

Paste:

```python
import requests

from devops_toolkit.api_client import ApiClient


class FakeResponse:
    def __init__(self, status_code: int, data=None, text: str = "") -> None:
        self.status_code = status_code
        self._data = data
        self.text = text
        self.content = b"{}" if data is not None else text.encode("utf-8")

    def json(self):
        if self._data is None:
            raise ValueError("not json")
        return self._data


def test_build_url_with_base_url() -> None:
    client = ApiClient(base_url="https://api.example.com")
    assert client.build_url("/v1/items") == "https://api.example.com/v1/items"


def test_build_url_absolute_url() -> None:
    client = ApiClient(base_url="https://api.example.com")
    assert client.build_url("https://other.example.com/x") == "https://other.example.com/x"


def test_get_success(monkeypatch) -> None:
    def fake_request(**kwargs):
        return FakeResponse(200, data={"ok": True})

    client = ApiClient(base_url="https://api.example.com", retries=1)
    monkeypatch.setattr(client.session, "request", fake_request)

    response = client.get("/health")

    assert response.ok is True
    assert response.status_code == 200
    assert response.data == {"ok": True}
    assert response.attempts == 1


def test_get_non_retryable_status(monkeypatch) -> None:
    calls = {"count": 0}

    def fake_request(**kwargs):
        calls["count"] += 1
        return FakeResponse(401, data={"message": "bad token"})

    client = ApiClient(base_url="https://api.example.com", retries=3)
    monkeypatch.setattr(client.session, "request", fake_request)

    response = client.get("/user")

    assert response.ok is False
    assert response.status_code == 401
    assert response.attempts == 3
    assert calls["count"] == 1


def test_get_retryable_status(monkeypatch) -> None:
    calls = {"count": 0}

    def fake_request(**kwargs):
        calls["count"] += 1
        if calls["count"] == 1:
            return FakeResponse(503, data={"message": "temporary"})
        return FakeResponse(200, data={"ok": True})

    client = ApiClient(base_url="https://api.example.com", retries=3, retry_delay=0)
    monkeypatch.setattr(client.session, "request", fake_request)

    response = client.get("/health")

    assert response.ok is True
    assert response.status_code == 200
    assert calls["count"] == 2


def test_request_exception(monkeypatch) -> None:
    def fake_request(**kwargs):
        raise requests.ConnectionError("connection failed")

    client = ApiClient(base_url="https://api.example.com", retries=1)
    monkeypatch.setattr(client.session, "request", fake_request)

    response = client.get("/health")

    assert response.ok is False
    assert response.status_code is None
    assert "connection failed" in str(response.error)
```

Run:

```bash
pytest tests/test_api_client.py
```

Run all tests:

```bash
pytest
```

Small note: In `test_get_non_retryable_status`, our `ApiClient` currently returns `attempts=self.retries` in final failure even if it stopped early. The call count is still correct, but the attempts field is not exact for early break. We can improve that now.

---

# 16. Improve Attempts Count

Edit:

```bash
nano devops_toolkit/api_client.py
```

Find this part:

```python
last_error: Optional[str] = None
last_status: Optional[int] = None
last_data: Any = None

for attempt in range(1, self.retries + 1):
```

Change to:

```python
last_error: Optional[str] = None
last_status: Optional[int] = None
last_data: Any = None
attempts_used = 0

for attempt in range(1, self.retries + 1):
    attempts_used = attempt
```

Then at the final return, change:

```python
attempts=self.retries,
```

to:

```python
attempts=attempts_used,
```

Now the final part should be:

```python
return ApiResponse(
    method=method_upper,
    url=url,
    status_code=last_status,
    ok=False,
    data=last_data,
    error=last_error,
    attempts=attempts_used,
)
```

Update test:

```bash
nano tests/test_api_client.py
```

Change:

```python
assert response.attempts == 3
```

to:

```python
assert response.attempts == 1
```

Run:

```bash
pytest tests/test_api_client.py
pytest
```

---

# 17. Add CLI for GitHub Repo Report

Create:

```bash
nano devops_toolkit/github_cli.py
```

Paste:

```python
import argparse
import json
import os
import sys
from pathlib import Path

from devops_toolkit.github import create_github_client, list_user_repos
from devops_toolkit.paths import REPORT_DIR


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="GitHub repository report tool.")

    parser.add_argument("--user", required=True, help="GitHub username")
    parser.add_argument("--per-page", type=int, default=30)
    parser.add_argument("--max-pages", type=int, default=2)
    parser.add_argument(
        "--output",
        default=str(REPORT_DIR / "github-repos.json"),
        help="Output JSON report path",
    )

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    token = os.getenv("GITHUB_TOKEN")
    client = create_github_client(token)

    try:
        repos = list_user_repos(
            client=client,
            username=args.user,
            per_page=args.per_page,
            max_pages=args.max_pages,
        )
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    report = {
        "user": args.user,
        "total": len(repos),
        "repositories": [
            {
                "name": repo.get("name"),
                "full_name": repo.get("full_name"),
                "private": repo.get("private"),
                "html_url": repo.get("html_url"),
                "language": repo.get("language"),
                "stars": repo.get("stargazers_count"),
                "forks": repo.get("forks_count"),
                "updated_at": repo.get("updated_at"),
            }
            for repo in repos
        ],
    }

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2), encoding="utf-8")

    print(f"GitHub user: {args.user}")
    print(f"Repositories: {len(repos)}")
    print(f"Report written: {output_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run:

```bash
python -m devops_toolkit.github_cli --user octocat --max-pages 1
cat reports/github-repos.json | jq .
```

---

# 18. Add Bash Wrapper

Create:

```bash
nano scripts/github-report
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

exec python -m devops_toolkit.github_cli "$@"
```

Make executable:

```bash
chmod +x scripts/github-report
```

Run:

```bash
./scripts/github-report --user octocat --max-pages 1
```

---

# 19. Add Makefile Targets

Edit:

```bash
nano Makefile
```

Update:

```makefile
.PHONY: test compile health linux-health github-report clean

test:
	pytest

compile:
	python -m compileall devops_toolkit scripts tests

health:
	python -m devops_toolkit.cli --config configs/services.yaml --output reports/health-report.json

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
make github-report
```

---

# 20. API Automation Notes

Create:

```bash
nano notes/python-api-automation.md
```

Paste:

````markdown
# Python API Automation

## Why Python for APIs?

Python is useful for API automation because it provides:

- structured error handling
- JSON parsing
- sessions
- retries
- timeouts
- authentication headers
- pagination
- report generation
- tests

## API Client Rules

- Use `requests.Session`.
- Always set timeouts.
- Retry transient failures.
- Do not retry permanent errors like 400/401/403/404.
- Do not print tokens.
- Load tokens from environment variables.
- Use structured response objects.
- Handle JSON parsing errors.
- Generate reports for automation output.

## Retryable Status Codes

```text
408
429
500
502
503
504
````

## Non-Retryable Common Status Codes

```text
400 bad request
401 unauthorized
403 forbidden
404 not found
422 validation error
```

## Token Pattern

```python
token = os.getenv("GITHUB_TOKEN")
headers = {}

if token:
    headers["Authorization"] = f"Bearer {token}"
```

## GitHub Examples

```bash
python -m devops_toolkit.github_cli --user octocat --max-pages 1
python scripts/github_rate_limit.py
```

## Webhook Pattern

```python
send_json_webhook(webhook_url, payload)
```

Webhook URLs are secrets.

````

---

# 21. Update GitHub Actions Tests

Your existing workflow should already install `requirements.txt` and run tests.

Make sure `requirements.txt` includes:

```text
requests
PyYAML
pytest
````

Run:

```bash
python -m pip freeze > requirements.txt
cat requirements.txt
```

Then:

```bash
pytest
python -m compileall devops_toolkit scripts tests
```

---

# 22. Final Validation

From Python project:

```bash
cd ~/devops-masterclass/04-python-devops-automation
source .venv/bin/activate
```

Run:

```bash
python -m compileall devops_toolkit scripts tests
pytest
python scripts/api_get_demo.py
python scripts/github_rate_limit.py
python -m devops_toolkit.github_cli --user octocat --max-pages 1
./scripts/github-report --user octocat --max-pages 1
make compile
make test
```

If GitHub rate limit or network blocks occur, the tests should still pass because tests mock API calls. Only live demo scripts depend on internet.

---

# 23. Commit Work

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
git commit -m "feat: add Python API automation patterns"
```

Push:

```bash
git push
```

---

# 24. Real Production Use Cases

## Use Case 1 — GitHub repository audit

```bash
python -m devops_toolkit.github_cli \
  --user your-org-or-user \
  --max-pages 5 \
  --output reports/github-audit.json
```

Later, you can extend it to check:

```text
archived repos
default branch
open issues
last updated time
license
visibility
branch protection
security settings
```

## Use Case 2 — Deployment notification webhook

After deployment:

```bash
WEBHOOK_URL="$SLACK_WEBHOOK_URL" python scripts/webhook_demo.py
```

Later payload can include:

```text
service name
version
environment
deployment status
commit SHA
deployed by
timestamp
rollback link
```

## Use Case 3 — API health checker

Use `ApiClient` for internal APIs:

```python
client = ApiClient(
    base_url="https://internal-api.example.com",
    headers={"Authorization": f"Bearer {token}"},
)
response = client.get("/health")
```

---

# 25. Common Mistakes

## Mistake 1 — No timeout

Bad:

```python
requests.get(url)
```

Good:

```python
requests.get(url, timeout=10)
```

## Mistake 2 — Hardcoded token

Bad:

```python
headers = {"Authorization": "Bearer ghp_xxx"}
```

Good:

```python
token = os.getenv("GITHUB_TOKEN")
```

## Mistake 3 — Retrying bad requests

Bad:

```text
Retry 400/401/403 forever
```

Good:

```text
Retry only transient failures.
```

## Mistake 4 — No pagination

Bad:

```python
repos = client.get("/users/user/repos").data
```

This may return only first page.

Good:

```python
for page in range(1, max_pages + 1):
    ...
```

## Mistake 5 — Printing secrets

Bad:

```python
print(webhook_url)
print(token)
```

Good:

```python
print("WEBHOOK_URL is configured")
```

---

# 26. Interview Answers

Question:

```text
How do you build robust Python API automation?
```

Strong answer:

```text
I create a reusable API client around requests.Session. I set default headers, authentication, timeouts, retries for transient failures, and structured response objects. I handle status codes carefully, parse JSON safely, avoid printing secrets, and load tokens from environment variables. For APIs that paginate, I implement pagination with limits. I also write tests by mocking API calls so unit tests do not depend on external services.
```

Question:

```text
Which API failures should be retried?
```

Strong answer:

```text
I retry transient failures like timeouts, connection errors, 429 rate limiting, and 5xx gateway or server errors such as 500, 502, 503, and 504. I generally do not retry 400, 401, 403, 404, or 422 because those usually indicate bad input, authentication or permission issues, missing resources, or validation errors.
```

Question:

```text
How do you handle API tokens securely?
```

Strong answer:

```text
I do not hardcode tokens in code or commit them to Git. I load tokens from environment variables or a secret manager, pass them in Authorization headers, and avoid printing them in logs. If a token is accidentally committed or exposed, I rotate it immediately.
```

Question:

```text
How do you test code that calls APIs?
```

Strong answer:

```text
For unit tests, I mock the HTTP layer so tests do not call real APIs. I test success responses, non-retryable errors, retryable errors, JSON parsing, and connection exceptions. Real API calls can be covered by separate integration tests with controlled credentials and rate limits.
```

---

# Today’s Core Rules

```text
Use requests.Session for repeated API calls.
Always set timeouts.
Retry transient failures only.
Do not retry bad input/auth errors blindly.
Use environment variables for tokens.
Never print secrets.
Handle JSON parsing safely.
Implement pagination.
Generate JSON reports.
Mock API calls in unit tests.
Keep live API demos separate from unit tests.
```

Next lesson:

# Lesson 4.5 — Python Configuration and Validation: Pydantic-style validation, environment config, schema checks, `.env` handling, typed settings, and safer automation inputs.

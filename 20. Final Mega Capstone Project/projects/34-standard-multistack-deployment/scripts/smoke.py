"""HTTP contract checks against any stack, locally or after a rollout."""
import argparse
import json
import time
import urllib.error
import urllib.request


def request(base, path, method="GET"):
    req = urllib.request.Request(base.rstrip("/") + path, method=method)
    try:
        response = urllib.request.urlopen(req, timeout=3)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        if "application/json" not in response.headers.get("Content-Type", ""):
            raise AssertionError("Expected JSON content type")
        return response.status, json.load(response)


def check(base, stack, version=None, environment=None, wait=60):
    deadline = time.monotonic() + wait
    while True:
        try:
            assert request(base, "/readyz") == (200, {"status": "ok"})
            break
        except (OSError, AssertionError, ValueError):
            if time.monotonic() >= deadline:
                raise
            time.sleep(1)
    for path in ("/healthz", "/readyz", "/healthz?probe=1"):
        assert request(base, path) == (200, {"status": "ok"}), path
    status, info = request(base, "/api/info")
    assert status == 200 and info["stack"] == stack and info["service"] == "deployment-demo", info
    assert set(info) == {"service", "stack", "version", "environment"}, info
    if version is not None:
        assert info["version"] == version, info
    if environment is not None:
        assert info["environment"] == environment, info
    assert request(base, "/missing") == (404, {"error": "not found"})
    assert request(base, "/api/info", "POST") == (405, {"error": "method not allowed"})
    print(f"PASS: {stack}: probes, query handling, service identity, version/environment, 404 and 405")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url")
    parser.add_argument("--stack", required=True)
    parser.add_argument("--version")
    parser.add_argument("--environment")
    parser.add_argument("--wait", type=int, default=60)
    args = parser.parse_args()
    check(args.url, args.stack, args.version, args.environment, args.wait)

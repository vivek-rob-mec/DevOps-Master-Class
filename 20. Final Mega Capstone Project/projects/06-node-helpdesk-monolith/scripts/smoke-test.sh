#!/usr/bin/env sh
set -eu
url="${1:-http://localhost:8080}/health"
for attempt in $(seq 1 30); do
  if curl -fsS "$url"; then printf '\nSmoke test passed.\n'; exit 0; fi
  sleep 2
done
echo "Smoke test failed: $url" >&2
exit 1

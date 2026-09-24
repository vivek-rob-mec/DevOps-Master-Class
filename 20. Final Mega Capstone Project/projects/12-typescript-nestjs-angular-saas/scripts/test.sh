#!/usr/bin/env sh
set -eu
(cd api && npm ci --no-audit --no-fund && npm test && npm run build)
(cd frontend && npm ci --no-audit --no-fund && npm run build)
docker compose config --quiet

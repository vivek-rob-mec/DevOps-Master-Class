#!/usr/bin/env sh
set -eu
node --check api/src/domain.js
node --check api/src/server.js
node --test api/test/*.test.js
docker compose config --quiet

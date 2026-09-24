#!/usr/bin/env sh
set -eu
node --check app/src/domain.js
node --check app/src/server.js
node --test app/test/*.test.js
docker compose config --quiet

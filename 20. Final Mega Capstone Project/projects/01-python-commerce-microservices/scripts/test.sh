#!/usr/bin/env sh
set -eu
python3 -m compileall -q services
docker compose config --quiet

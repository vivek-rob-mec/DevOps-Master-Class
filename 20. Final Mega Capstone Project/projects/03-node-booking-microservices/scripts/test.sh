#!/usr/bin/env sh
set -eu
for file in services/*/src/*.js;do node --check "$file";done
docker compose config --quiet

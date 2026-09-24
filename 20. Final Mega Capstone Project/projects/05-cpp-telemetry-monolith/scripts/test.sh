#!/usr/bin/env sh
set -eu
docker build --target build -t telemetry-cpp-build .
docker compose config --quiet

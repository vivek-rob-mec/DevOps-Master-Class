#!/usr/bin/env sh
set -eu
docker run --rm -v "$PWD/app:/src" -w /src rust:1.97-slim cargo test
docker compose config --quiet

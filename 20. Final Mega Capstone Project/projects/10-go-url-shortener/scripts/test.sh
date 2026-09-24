#!/usr/bin/env sh
set -eu
docker run --rm -v "$PWD/app:/src" -w /src golang:1.25-alpine sh -c 'go test ./...'
docker compose config --quiet

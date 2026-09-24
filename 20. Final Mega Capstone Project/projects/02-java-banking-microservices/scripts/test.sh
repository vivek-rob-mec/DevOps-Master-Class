#!/usr/bin/env sh
set -eu
docker run --rm -v "$PWD:/src" -w /src maven:3.9.9-eclipse-temurin-21 mvn -B -ntp test
docker compose config --quiet

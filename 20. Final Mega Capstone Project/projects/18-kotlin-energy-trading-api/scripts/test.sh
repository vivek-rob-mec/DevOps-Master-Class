#!/usr/bin/env sh
set -eu
docker run --rm -v "$PWD/app:/src" -w /src maven:3.9-eclipse-temurin-25 mvn -B -ntp test
docker compose config --quiet

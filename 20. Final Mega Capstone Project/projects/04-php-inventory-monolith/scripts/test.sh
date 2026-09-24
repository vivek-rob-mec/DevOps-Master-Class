#!/usr/bin/env sh
set -eu
docker run --rm -v "$PWD/app:/app" -w /app php:8.3-cli sh -c 'find . -name "*.php" -print0 | xargs -0 -n1 php -l'
docker run --rm -v "$PWD/app:/app" -w /app composer:2.8 validate --strict
docker compose config --quiet

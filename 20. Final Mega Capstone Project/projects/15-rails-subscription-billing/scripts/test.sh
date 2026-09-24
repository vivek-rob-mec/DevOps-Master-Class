#!/usr/bin/env sh
set -eu
docker run --rm -v "$PWD/app:/app" -w /app ruby:3.4 ruby test/subscription_rules_test.rb
docker compose config --quiet

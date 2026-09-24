#!/usr/bin/env sh
set -eu
PYTHONPATH=app python -m unittest app/test_domain.py
python -m py_compile app/main.py app/domain.py
docker compose config --quiet

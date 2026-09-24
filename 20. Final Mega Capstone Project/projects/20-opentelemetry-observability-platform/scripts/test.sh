#!/usr/bin/env sh
set -eu
cd app
python -m unittest test_domain.py -v
python -m py_compile main.py domain.py
cd ..
docker compose config --quiet

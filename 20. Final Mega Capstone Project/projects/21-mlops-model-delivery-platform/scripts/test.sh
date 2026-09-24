#!/usr/bin/env sh
set -eu
python -m unittest discover -s tests -v
python -m py_compile api/main.py trainer/train.py platform_lib/*.py
docker compose config --quiet

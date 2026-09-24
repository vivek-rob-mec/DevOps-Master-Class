#!/usr/bin/env sh
set -eu
python -m unittest discover -s tests -v
python -m py_compile platform_lib/*.py producers/*.py jobs/*.py dags/*.py
docker compose config --quiet
if command -v terraform >/dev/null 2>&1;then terraform -chdir=terraform fmt -check -recursive;fi

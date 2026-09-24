#!/usr/bin/env sh
set -eu
python -m py_compile app/manage.py app/config/*.py app/shipments/*.py app/shipments/migrations/*.py
cd app
python -m unittest shipments.test_domain -v
cd ..
docker compose config --quiet

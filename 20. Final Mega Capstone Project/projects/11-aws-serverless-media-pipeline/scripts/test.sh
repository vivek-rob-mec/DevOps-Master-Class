#!/usr/bin/env sh
set -eu
python -m unittest discover -s tests -v
python -m py_compile functions/intake/app.py functions/worker/app.py
if command -v sam >/dev/null 2>&1;then sam validate --lint;fi
if command -v terraform >/dev/null 2>&1;then terraform -chdir=terraform fmt -check -recursive;fi

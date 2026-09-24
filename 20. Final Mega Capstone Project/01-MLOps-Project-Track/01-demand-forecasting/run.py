import os
from pathlib import Path
import sys

os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import Project
from mlops_common.runtime import cli

if __name__ == "__main__":
    cli(Project(), 8211)

import importlib.util
import os
from pathlib import Path
import sys

os.environ.setdefault("OMP_NUM_THREADS","1")
os.environ.setdefault("OPENBLAS_NUM_THREADS","1")
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
MODULES={}
for folder in ("01-demand-forecasting","02-payment-risk","03-predictive-maintenance","04-aiops-incident-triage"):
    name=folder.replace("-","_")
    spec=importlib.util.spec_from_file_location(name,ROOT/folder/"app.py")
    module=importlib.util.module_from_spec(spec)
    sys.modules[name]=module
    spec.loader.exec_module(module)
    MODULES[folder[:2]]=module


import pytest


@pytest.fixture(autouse=True)
def isolate_environment(monkeypatch):
    monkeypatch.delenv("STATE_DIR",raising=False)
    monkeypatch.delenv("TELEMETRY_DB",raising=False)


@pytest.fixture(scope="session")
def trained_templates(tmp_path_factory):
    import shutil
    path=tmp_path_factory.mktemp("trained")
    instances={}
    for key,module in MODULES.items():
        project=module.Project(path/key)
        project.demo()
        instances[key]=project
    return instances


@pytest.fixture
def projects(tmp_path,trained_templates):
    import shutil
    result={}
    for key,source in trained_templates.items():
        target=tmp_path/key
        shutil.copytree(source.runtime.state,target/"state")
        result[key]=MODULES[key].Project(target)
    return result

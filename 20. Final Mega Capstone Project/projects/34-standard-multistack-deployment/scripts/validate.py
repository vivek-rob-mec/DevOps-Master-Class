"""Offline checks and Kubernetes rendering; does not contact a cluster."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
STACKS = ("python", "node", "java", "go", "dotnet")


def main():
    kubectl = shutil.which("kubectl")
    if not kubectl:
        sys.exit("kubectl is required to render the Kubernetes overlays")
    count = 0
    for environment in ("dev", "staging", "prod"):
        for stack in STACKS:
            path = ROOT / "k8s" / "overlays" / environment / stack
            config = json.loads((path / "kustomization.yaml").read_text(encoding="utf-8"))
            assert config["namespace"] == "standard-" + environment
            assert config["labels"][0]["pairs"]["app.kubernetes.io/instance"] == stack
            result = subprocess.run([kubectl, "kustomize", str(path)], capture_output=True, text=True)
            if result.returncode:
                sys.exit(f"Cannot render {path}:\n{result.stderr}")
            assert f"name: {stack}-deployment-demo" in result.stdout
            assert "readOnlyRootFilesystem: true" in result.stdout
            count += 1
    subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-v"], cwd=ROOT, check=True)
    print(f"PASS: {count} Kubernetes overlays rendered and promotion tests passed. No cluster was changed.")


if __name__ == "__main__":
    main()

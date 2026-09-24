"""Edit desired state for review; never contacts a cluster or pushes Git."""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
STACKS = ("python", "node", "java", "go", "dotnet")
ENVIRONMENTS = ("dev", "staging", "prod")


def promote(root, stack, environment, release):
    if stack not in STACKS or environment not in ENVIRONMENTS:
        raise ValueError("Unknown stack or environment")
    if release.get("stack") != stack:
        raise ValueError("Release belongs to another stack")
    image, digest, revision = (release.get(key, "") for key in ("image", "digest", "revision"))
    if not re.fullmatch(r"ghcr\.io/[a-z0-9][a-z0-9._-]*/standard-" + stack, image):
        raise ValueError("Expected ghcr.io/<lowercase-owner>/standard-<stack>")
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest) or digest == "sha256:" + "0" * 64:
        raise ValueError("A real sha256 image digest is required; tags are rejected")
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("A full source Git SHA is required")
    directory = Path(root) / "k8s" / "overlays"
    target = directory / environment / stack / "kustomization.yaml"
    config = json.loads(target.read_text(encoding="utf-8"))
    desired = {"name": "deployment-demo", "newName": image, "digest": digest}
    if environment != "dev":
        previous = ENVIRONMENTS[ENVIRONMENTS.index(environment) - 1]
        upstream = json.loads((directory / previous / stack / "kustomization.yaml").read_text(encoding="utf-8"))
        if upstream["images"] != [desired] or "APP_VERSION=" + revision not in upstream["configMapGenerator"][0]["literals"]:
            raise ValueError(f"Promote this exact release to {previous} first")
    config["images"] = [desired]
    config["configMapGenerator"][0]["literals"] = ["APP_ENV=" + environment, "APP_VERSION=" + revision]
    target.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    return target


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stack", choices=STACKS, required=True)
    parser.add_argument("--to", choices=ENVIRONMENTS, required=True)
    parser.add_argument("--release", type=Path, required=True)
    args = parser.parse_args()
    try:
        path = promote(ROOT, args.stack, args.to, json.loads(args.release.read_text(encoding="utf-8")))
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.exit(1, f"Promotion rejected: {error}\n")
    print(f"Updated {path}. Review the diff and submit a promotion PR.")
    print("This validates desired-state order only. Attach CI, deployed-health, and approval evidence to the PR.")

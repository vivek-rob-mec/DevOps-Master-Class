import copy
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("promote", ROOT / "scripts" / "promote.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PromotionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        shutil.copytree(ROOT / "k8s", self.root / "k8s")
        self.release = {"stack": "python", "image": "ghcr.io/example/standard-python",
                        "digest": "sha256:" + "a" * 64, "revision": "b" * 40}

    def promote(self, environment, release=None):
        return module.promote(self.root, "python", environment, release or self.release)

    def test_same_digest_across_all_environments(self):
        for environment in module.ENVIRONMENTS:
            result = json.loads(self.promote(environment).read_text())
            self.assertEqual(result["images"][0]["digest"], self.release["digest"])
            self.assertNotIn("newTag", result["images"][0])
            self.assertIn("APP_ENV=" + environment, result["configMapGenerator"][0]["literals"])

    def test_cannot_skip_staging(self):
        self.promote("dev")
        target = self.root / "k8s/overlays/prod/python/kustomization.yaml"
        before = target.read_bytes()
        with self.assertRaises(ValueError):
            self.promote("prod")
        self.assertEqual(before, target.read_bytes())

    def test_wrong_stack_tag_placeholder_or_revision_rejected(self):
        for key, value in [("stack", "node"), ("digest", "latest"), ("digest", "sha256:" + "0" * 64),
                           ("revision", "main"), ("image", "ghcr.io/OTHER/standard-python")]:
            with self.subTest(key=key, value=value):
                invalid = dict(self.release, **{key: value})
                with self.assertRaises(ValueError):
                    self.promote("dev", invalid)

    def test_different_artifact_or_revision_cannot_be_promoted(self):
        self.promote("dev")
        for key, value in [("digest", "sha256:" + "c" * 64), ("revision", "d" * 40)]:
            with self.assertRaises(ValueError):
                self.promote("staging", dict(self.release, **{key: value}))

    def test_inputs_cannot_escape_overlay_directory(self):
        with self.assertRaises(ValueError):
            module.promote(self.root, "../python", "dev", self.release)
        with self.assertRaises(ValueError):
            module.promote(self.root, "python", "../../prod", self.release)

    def test_other_stack_and_resources_unchanged(self):
        other = self.root / "k8s/overlays/dev/node/kustomization.yaml"
        before = other.read_bytes()
        original = json.loads((self.root / "k8s/overlays/dev/python/kustomization.yaml").read_text())
        updated = json.loads(self.promote("dev").read_text())
        expected = copy.deepcopy(original)
        expected["images"] = updated["images"]
        expected["configMapGenerator"] = updated["configMapGenerator"]
        self.assertEqual(expected, updated)
        self.assertEqual(before, other.read_bytes())


if __name__ == "__main__":
    unittest.main()

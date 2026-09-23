#!/usr/bin/env python3
"""Exercise registry selection and publication without contacting Docker/GHCR."""
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest


HERE = Path(__file__).resolve().parent
CHANNEL = subprocess.check_output([str(HERE / "image-tag")], text=True).strip()
DOCKER_STUB = '''#!/usr/bin/env python3
import os
from pathlib import Path
import sys

args = sys.argv[1:]
with open(os.environ["MOCK_DOCKER_LOG"], "a") as log:
    log.write(" ".join(args) + "\\n")
if args[0] == "login":
    sys.stdin.read()
elif args[0] == "pull":
    sys.exit(int(os.environ.get("MOCK_PULL_STATUS", "0")))
elif args[:2] == ["manifest", "inspect"]:
    status = int(os.environ.get("MOCK_MANIFEST_STATUS", "0"))
    if status:
        print("manifest unknown", file=sys.stderr)
        sys.exit(status)
    print('{"schemaVersion":2}')
elif args[:2] == ["image", "inspect"]:
    if "{{index .RepoDigests 0}}" in args:
        print("ghcr.io/srcshelton/shellcheck-armv6-cross@sha256:" + "a" * 64)
    else:
        print("sha256:" + "b" * 64)
elif args[0] == "run":
    sys.stdout.buffer.write(Path(os.environ["MOCK_ARCHIVE"]).read_bytes())
    sys.exit(int(os.environ.get("MOCK_RUN_STATUS", "0")))
elif args[0] == "push":
    print("digest: sha256:" + "a" * 64)
elif args[0] == "tag":
    pass
else:
    sys.exit("unexpected docker invocation: " + repr(args))
'''


class CISelectionTest(unittest.TestCase):
    def setUp(self):
        parent = os.environ.get("ARMV6_TEST_SCRATCH_PARENT")
        self.temp = tempfile.TemporaryDirectory(prefix="armv6-ci-test-", dir=parent)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        docker = self.bin / "docker"
        docker.write_text(DOCKER_STUB)
        docker.chmod(0o755)
        self.archive = self.root / "source.tar.gz"
        payload = b"mock ARMv6 executable\n"
        with tarfile.open(self.archive, "w:gz") as archive:
            info = tarfile.TarInfo("linux.armv6hf/shellcheck")
            info.size = len(payload)
            archive.addfile(info, io.BytesIO(payload))
        self.log = self.root / "docker.log"
        self.env = os.environ.copy()
        self.env.update({
            "PATH": f"{self.bin}:{self.env['PATH']}",
            "MOCK_DOCKER_LOG": str(self.log),
            "MOCK_ARCHIVE": str(self.archive),
            "GITHUB_REPOSITORY": "srcshelton/shellcheck",
            "GITHUB_ACTOR": "tester",
            "GHCR_TOKEN": "mock-token",
            "GITHUB_STEP_SUMMARY": str(self.root / "summary"),
            "GITHUB_OUTPUT": str(self.root / "github-output"),
        })

    def run_selection(self):
        output = self.root / "output"
        output.mkdir()
        return subprocess.run(
            [str(HERE / "run-preferred"), str(self.archive)],
            cwd=output, env=self.env, capture_output=True, text=True)

    def test_cross_image_is_selected_by_local_image_id(self):
        result = self.run_selection()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ARMv6 builder: qualified cross-GHC", result.stderr)
        self.assertIn("run --platform linux/amd64 -i sha256:", self.log.read_text())
        self.assertNotIn("run -i koalaman/scbuilder", self.log.read_text())
        self.assertTrue((self.root / "output/linux.armv6hf/shellcheck").is_file())

    def test_image_channel_includes_pinned_version_and_recipe_digest(self):
        self.assertRegex(CHANNEL, r"^ghc-9\.12\.2-armv6hf-[0-9a-f]{16}$")

    def test_pinned_ghc_change_selects_a_new_channel(self):
        recipe = self.root / "recipe"
        recipe.mkdir()
        shutil.copy2(HERE / "image-tag", recipe / "image-tag")
        dockerfile = recipe / "Dockerfile"
        dockerfile.write_bytes((HERE / "Dockerfile").read_bytes())
        before = subprocess.check_output([str(recipe / "image-tag")], text=True)
        dockerfile.write_text(dockerfile.read_text().replace(
            "ghc-9.12.2-src.tar.xz", "ghc-9.14.1-src.tar.xz"))
        after = subprocess.check_output([str(recipe / "image-tag")], text=True)
        self.assertNotEqual(before, after)
        self.assertTrue(after.startswith("ghc-9.14.1-armv6hf-"))

    def test_missing_image_uses_emulation(self):
        self.env["MOCK_PULL_STATUS"] = "1"
        result = self.run_selection()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("emulated builder", result.stderr)
        self.assertIn("run -i koalaman/scbuilder-linux-armv6hf", self.log.read_text())

    def test_manual_tagged_release_forces_original_emulated_builder(self):
        self.env["ARMV6_FORCE_EMULATION"] = "1"
        result = self.run_selection()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("manual tagged release rebuild", result.stderr)
        calls = self.log.read_text()
        self.assertIn("run -i koalaman/scbuilder-linux-armv6hf", calls)
        self.assertNotIn("pull --platform linux/amd64", calls)
        self.assertNotIn("login ghcr.io", calls)

    def test_required_image_failure_does_not_fall_back(self):
        self.env["MOCK_PULL_STATUS"] = "1"
        self.env["ARMV6_CROSS_REQUIRED"] = "1"
        result = self.run_selection()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Required qualified ARMv6 image", result.stderr)
        self.assertNotIn("run -i koalaman/scbuilder", self.log.read_text())

    def test_cross_build_failure_does_not_fall_back(self):
        self.env["MOCK_RUN_STATUS"] = "1"
        result = self.run_selection()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("koalaman/scbuilder-linux-armv6hf", self.log.read_text())

    def test_publish_only_after_qualification_and_round_trip(self):
        evidence = self.root / "evidence"
        evidence.mkdir()
        (evidence / "comparison.jsonl").write_text('{"equal":true}\n')
        (evidence / "candidate-container.json").write_text(json.dumps([{
            "Image": "sha256:" + "b" * 64,
        }]))
        for name in ("candidate.sha256", "reference.sha256"):
            (evidence / name).write_text("verified\n")
        (evidence / "status").write_text("0\n")
        self.env.update({
            "GITHUB_REPOSITORY": "srcshelton/shellcheck",
            "GITHUB_RUN_ID": "12345",
            "GITHUB_RUN_ATTEMPT": "1",
        })
        result = subprocess.run(
            [str(HERE / "ci-publish"), str(evidence)],
            cwd=self.root, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.log.read_text()
        self.assertIn(f"push ghcr.io/srcshelton/shellcheck-armv6-cross:{CHANNEL}-run-12345-1", calls)
        self.assertIn(f"push ghcr.io/srcshelton/shellcheck-armv6-cross:{CHANNEL}\n", calls)
        self.assertTrue((evidence / "published-image-digest").is_file())
        self.assertTrue((evidence / "published-image-channel").is_file())

    def test_failed_qualification_cannot_publish(self):
        evidence = self.root / "evidence"
        evidence.mkdir()
        (evidence / "status").write_text("1\n")
        result = subprocess.run(
            [str(HERE / "ci-publish"), str(evidence)],
            cwd=self.root, env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.log.exists())

    def test_existing_image_skips_rebuild(self):
        evidence = self.root / "evidence"
        result = subprocess.run(
            [str(HERE / "ci-image-probe"), str(evidence)],
            cwd=self.root, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("available=true", (self.root / "github-output").read_text())
        self.assertIn(CHANNEL, (evidence / "requested-image").read_text())

    def test_missing_image_requests_qualification(self):
        self.env["MOCK_MANIFEST_STATUS"] = "1"
        result = subprocess.run(
            [str(HERE / "ci-image-probe"), str(self.root / "evidence")],
            cwd=self.root, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("available=false", (self.root / "github-output").read_text())


if __name__ == "__main__":
    unittest.main()

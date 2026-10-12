"""Offline tests for the air-gap CLI; no registries or installed CLI tools needed."""

import contextlib
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import airgap


def create_layout(path):
    (path / "blobs" / "sha256").mkdir(parents=True)

    def blob(value, media_type):
        data = json.dumps(value).encode()
        digest = hashlib.sha256(data).hexdigest()
        (path / "blobs" / "sha256" / digest).write_bytes(data)
        return {"mediaType": media_type, "digest": "sha256:" + digest, "size": len(data)}

    config = blob({"architecture": "amd64", "os": "linux"},
                  "application/vnd.oci.image.config.v1+json")
    amd64 = blob({"schemaVersion": 2, "config": config, "layers": []},
                 "application/vnd.oci.image.manifest.v1+json")
    arm_config = blob({"architecture": "arm64", "os": "linux"},
                      "application/vnd.oci.image.config.v1+json")
    arm64 = blob({"schemaVersion": 2, "config": arm_config, "layers": []},
                 "application/vnd.oci.image.manifest.v1+json")
    index = blob({"schemaVersion": 2, "manifests": [amd64, arm64]},
                 "application/vnd.oci.image.index.v1+json")
    index["annotations"] = {"org.opencontainers.image.ref.name": "bundle"}
    (path / "index.json").write_text(json.dumps({"schemaVersion": 2, "manifests": [index]}))
    (path / "oci-layout").write_text(json.dumps({"imageLayoutVersion": "1.0.0"}))


class ImageTests(unittest.TestCase):
    def test_default_destinations(self):
        cases = {
            "nginx": "nginx:latest",
            "nginx:1.27": "nginx:1.27",
            "library/nginx": "library/nginx:latest",
            "docker.io/library/nginx:1.27": "library/nginx:1.27",
            "localhost:5000/team/app:v2": "team/app:v2",
            "host.example:443/team/nested/app": "team/nested/app:latest",
            "team/a__b/a--b:Tag_1": "team/a__b/a--b:Tag_1",
        }
        for source, destination in cases.items():
            with self.subTest(source=source):
                self.assertEqual(airgap.image_entry(source),
                                 {"source": source, "destination": destination})

    def test_explicit_mapping_and_digest(self):
        for source in ("docker.io/team/app:1", "host.io/team/app@sha256:" + "a" * 64,
                       "host.io/team/app:1@sha256:" + "b" * 64):
            self.assertEqual(airgap.image_entry(source + "=mirror/app:offline")["destination"],
                             "mirror/app:offline")

    def test_invalid_images(self):
        for value in ("", "-app", "../app", "a/../b", "https://host/app:1",
                      "host.io/user:password@app:1", "app=../app:1", "app=/app:1",
                      "app=repo", "app=a:b:c", "app=a:tag=other:tag", "app:bad tag",
                      "UPPER/app", "app@sha256:" + "a" * 64, "app@md5:123=x:1",
                      "host:99999/app:1", "app=x:"):
            with self.subTest(value=value), self.assertRaises(airgap.BundleError):
                airgap.image_entry(value)

    def test_duplicate_destinations(self):
        self.assertEqual(len(airgap.unique_images(["app:1", "app:1"])), 1)
        with self.assertRaises(airgap.BundleError):
            airgap.unique_images(["one.io/app:1", "two.io/app:1"])
        with self.assertRaises(airgap.BundleError):
            airgap.unique_images([])

    def test_registry_prefixes(self):
        self.assertEqual(airgap.registry("registry.internal:5443/offline/team"),
                         "registry.internal:5443/offline/team")
        for value in ("https://host", "host/", "host/../repo", "host:0", "host:65536",
                      "user:password@host", "host//repo", "host/repo:tag", "-host", "a..b"):
            with self.subTest(value=value), self.assertRaises(airgap.BundleError):
                airgap.registry(value)

    def test_chart_is_pinned_oci(self):
        airgap.validate_chart("oci://host:5000/team/chart", "1.2.3-rc.1+build")
        for chart, version in (("https://host/chart", "1.2.3"),
                               ("oci://host/chart", "latest"),
                               ("oci://host/chart", ">=1.0.0"),
                               ("oci://host/../chart", "1.2.3"),
                               ("oci://host/chart:1", "1.2.3")):
            with self.subTest(chart=chart, version=version), self.assertRaises(airgap.BundleError):
                airgap.validate_chart(chart, version)


class BundleTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix=".airgap-test-", dir=Path(__file__).parent)
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.bundle = self.root / "bundle"
        self.commands = []
        self.which = mock.patch("airgap.shutil.which", return_value="/fake/tool")
        self.which.start()
        self.addCleanup(self.which.stop)
        self.process = mock.patch("airgap.subprocess.run", side_effect=self.fake_command)
        self.process.start()
        self.addCleanup(self.process.stop)

    def fake_command(self, command, **kwargs):
        self.commands.append(command)
        self.assertTrue(kwargs["check"])
        if command[:2] == ["helm", "pull"]:
            path = Path(command[command.index("--destination") + 1])
            (path / "chart-1.2.3.tgz").write_bytes(b"chart package fixture")
        elif command[:3] == ["helm", "show", "chart"]:
            return subprocess.CompletedProcess(command, 0, stdout="name: chart\nversion: 1.2.3\n")
        elif command[:2] == ["skopeo", "copy"] and command[-1].startswith("oci:"):
            create_layout(Path(command[-1][4:].rsplit(":", 1)[0]))
        return subprocess.CompletedProcess(command, 0, stdout="")

    def download(self, extra=None):
        arguments = ["download", "--chart", "oci://source.io/charts/chart",
                     "--chart-version", "1.2.3", "--bundle", str(self.bundle)]
        arguments += extra if extra is not None else ["--image", "source.io/team/app:1",
                                                     "--image", "busybox=utils/busybox:stable"]
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return airgap.main(arguments)

    def upload(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(io.StringIO()):
            result = airgap.main(["upload", "--bundle", str(self.bundle),
                                  "--registry", "target.internal:5000/offline"])
        return result, output.getvalue()

    def update_manifest(self, change):
        path = self.bundle / "manifest.json"
        manifest = json.loads(path.read_text())
        change(manifest)
        path.write_text(json.dumps(manifest))

    def test_download_and_offline_upload_commands(self):
        self.assertEqual(self.download(), 0)
        self.assertEqual(len(list(self.root.iterdir())), 1)
        manifest = airgap.validate_bundle(self.bundle)
        self.assertEqual(manifest["schema_version"], 1)
        self.assertEqual(manifest["chart"]["version"], "1.2.3")
        self.assertEqual(set(manifest["files"]), set(airgap.inventory(self.bundle)))
        self.assertEqual(self.commands[0][:5],
                         ["helm", "pull", "oci://source.io/charts/chart", "--version", "1.2.3"])
        pulls = [command for command in self.commands if command[0] == "skopeo"]
        self.assertEqual(len(pulls), 2)
        for command in pulls:
            self.assertEqual(command[:3], ["skopeo", "copy", "--all"])
            self.assertTrue(command[-1].endswith(":bundle"))
        self.commands.clear()
        result, output = self.upload()
        self.assertEqual(result, 0)
        self.assertEqual(output.splitlines(),
                         ["source.io/team/app:1=target.internal:5000/offline/team/app:1",
                          "busybox=target.internal:5000/offline/utils/busybox:stable"])
        self.assertEqual(len(self.commands), 3)
        for i, command in enumerate(self.commands[:-1]):
            self.assertEqual(command[:4], ["skopeo", "copy", "--all", "--preserve-digests"])
            self.assertEqual(command[4], f"oci:{self.bundle}/images/{i:04d}:bundle")
        self.assertEqual(self.commands[-1],
                         ["helm", "push", str(self.bundle / manifest["chart"]["file"]),
                          "oci://target.internal:5000/offline/charts"])
        self.assertFalse(any("login" in c or "--tls-verify=false" in c for c in self.commands))

    def test_download_permits_manifest_conversion_for_digest_pinned_images(self):
        source = "docker.io/library/busybox@sha256:" + "a" * 64
        self.assertEqual(self.download(["--image", source + "=busybox:offline"]), 0)
        copy = next(command for command in self.commands if command[0] == "skopeo")
        self.assertEqual(copy[:3], ["skopeo", "copy", "--all"])
        self.assertEqual(copy[3], "docker://" + source)
        self.assertNotIn("--preserve-digests", copy)
        self.assertNotIn("--format", copy)
        self.assertEqual(airgap.validate_bundle(self.bundle)["images"][0]["source"], source)

    def test_images_file_comments_and_duplicates(self):
        images = self.root / "images.txt"
        images.write_text("# inventory\n\n  # comment\nsource.io/team/app:1\n"
                          "busybox=tools/busybox:1\n")
        self.assertEqual(self.download(["--image", "source.io/team/app:1",
                                       "--images-file", str(images)]), 0)
        self.assertEqual(len(airgap.validate_bundle(self.bundle)["images"]), 2)

    def test_requires_images_before_commands(self):
        self.assertEqual(self.download([]), 1)
        self.assertEqual(self.commands, [])
        self.assertFalse(self.bundle.exists())

    def test_existing_bundle_is_not_overwritten(self):
        self.bundle.mkdir()
        (self.bundle / "keep").write_text("existing")
        self.assertEqual(self.download(), 1)
        self.assertEqual((self.bundle / "keep").read_text(), "existing")
        self.assertEqual(self.commands, [])

    def test_failed_transfer_cleans_staging(self):
        for failing_tool in ("helm", "skopeo"):
            with self.subTest(tool=failing_tool):
                original = self.fake_command

                def fail(command, **kwargs):
                    if command[0] == failing_tool:
                        raise subprocess.CalledProcessError(1, command)
                    return original(command, **kwargs)

                with mock.patch("airgap.subprocess.run", side_effect=fail):
                    self.assertEqual(self.download(), 1)
                self.assertEqual(list(self.root.iterdir()), [])

    def test_wrong_chart_version_cleans_staging(self):
        original = self.fake_command

        def wrong_version(command, **kwargs):
            if command[:3] == ["helm", "show", "chart"]:
                return subprocess.CompletedProcess(command, 0, stdout="version: 9.9.9\n")
            return original(command, **kwargs)

        with mock.patch("airgap.subprocess.run", side_effect=wrong_version):
            self.assertEqual(self.download(), 1)
        self.assertEqual(list(self.root.iterdir()), [])

    def test_every_artifact_is_checked_before_any_upload(self):
        self.assertEqual(self.download(), 0)
        manifest = airgap.validate_bundle(self.bundle)
        self.commands.clear()
        for name in manifest["files"]:
            path = self.bundle / name
            original = path.read_bytes()
            path.write_bytes(original + b"tamper")
            with self.subTest(artifact=name):
                self.assertEqual(self.upload()[0], 1)
                self.assertEqual(self.commands, [])
            path.write_bytes(original)

    def test_missing_extra_and_symlink_files_rejected(self):
        self.assertEqual(self.download(), 0)
        self.commands.clear()
        chart = self.bundle / "chart" / "chart-1.2.3.tgz"
        original = chart.read_bytes()
        chart.unlink()
        self.assertEqual(self.upload()[0], 1)
        chart.write_bytes(original)
        extra = self.bundle / "extra"
        extra.write_bytes(b"unexpected")
        self.assertEqual(self.upload()[0], 1)
        extra.unlink()
        chart.unlink()
        chart.symlink_to(self.root / "external")
        self.assertEqual(self.upload()[0], 1)
        chart.unlink()
        chart.write_bytes(original)
        (self.bundle / "linked-directory").symlink_to(self.root, target_is_directory=True)
        self.assertEqual(self.upload()[0], 1)
        self.assertEqual(self.commands, [])

    def test_unsafe_manifest_paths(self):
        self.assertEqual(self.download(), 0)
        path = self.bundle / "manifest.json"
        original = path.read_text()
        self.commands.clear()
        for name in ("../escape", "/absolute", "images//0000", "images/./0000", r"images\0000"):
            with self.subTest(path=name):
                self.update_manifest(lambda m: m["files"].update({name: "a" * 64}))
                self.assertEqual(self.upload()[0], 1)
                self.assertEqual(self.commands, [])
                path.write_text(original)
        self.update_manifest(lambda m: m["images"][0].update(layout="../escape"))
        self.assertEqual(self.upload()[0], 1)
        self.assertEqual(self.commands, [])

    def test_incomplete_layout_even_with_updated_checksums(self):
        self.assertEqual(self.download(), 0)
        self.commands.clear()
        blob = next((self.bundle / "images/0000/blobs/sha256").iterdir())
        blob.unlink()
        self.update_manifest(lambda m: m.update(files=airgap.inventory(self.bundle)))
        self.assertEqual(self.upload()[0], 1)
        self.assertEqual(self.commands, [])

    def test_wrong_schema_and_duplicate_json_keys(self):
        self.assertEqual(self.download(), 0)
        self.commands.clear()
        self.update_manifest(lambda m: m.update(schema_version=2))
        self.assertEqual(self.upload()[0], 1)
        (self.bundle / "manifest.json").write_text('{"schema_version":1,"schema_version":1}')
        self.assertEqual(self.upload()[0], 1)
        self.assertEqual(self.commands, [])

    def test_unexpected_layout_artifact_even_with_updated_checksums(self):
        self.assertEqual(self.download(), 0)
        self.commands.clear()
        (self.bundle / "images/0000/credentials.json").write_text("{}")
        self.update_manifest(lambda m: m.update(files=airgap.inventory(self.bundle)))
        self.assertEqual(self.upload()[0], 1)
        self.assertEqual(self.commands, [])

    def test_unexpected_empty_directory(self):
        self.assertEqual(self.download(), 0)
        self.commands.clear()
        (self.bundle / "unexpected").mkdir()
        self.assertEqual(self.upload()[0], 1)
        self.assertEqual(self.commands, [])

    def test_manifest_layout_and_root_symlinks(self):
        self.assertEqual(self.download(), 0)
        self.commands.clear()
        for relative in ("manifest.json", "images/0000/oci-layout",
                         "images/0001/index.json"):
            with self.subTest(path=relative):
                path = self.bundle / relative
                external = self.root / "external"
                original = path.read_bytes()
                external.write_bytes(original)
                path.unlink()
                path.symlink_to(external)
                self.assertEqual(self.upload()[0], 1)
                path.unlink()
                path.write_bytes(original)
                external.unlink()
        real = self.root / "real-bundle"
        self.bundle.rename(real)
        self.bundle.symlink_to(real, target_is_directory=True)
        self.assertEqual(self.upload()[0], 1)
        self.assertEqual(self.commands, [])

    def test_duplicate_destination_in_manifest(self):
        self.assertEqual(self.download(), 0)
        self.commands.clear()
        self.update_manifest(lambda m: m["images"][1].update(
            destination=m["images"][0]["destination"]))
        self.assertEqual(self.upload()[0], 1)
        self.assertEqual(self.commands, [])

    def test_upload_tool_failure_is_reported(self):
        self.assertEqual(self.download(), 0)
        self.commands.clear()
        with mock.patch("airgap.subprocess.run",
                        side_effect=subprocess.CalledProcessError(2, ["skopeo", "copy"])):
            self.assertEqual(self.upload()[0], 1)

    def test_missing_tools_are_friendly(self):
        with mock.patch("airgap.shutil.which", return_value=None), \
                contextlib.redirect_stderr(io.StringIO()) as error:
            result = airgap.main(["download", "--chart", "oci://host/chart",
                                 "--chart-version", "1.2.3", "--bundle", str(self.bundle),
                                 "--image", "app:1"])
        self.assertEqual(result, 1)
        self.assertIn("helm is required", error.getvalue())
        self.assertEqual(list(self.root.iterdir()), [])

    def test_help_needs_no_external_tools(self):
        for command in ("download", "upload"):
            with self.subTest(command=command), mock.patch("airgap.tools") as tools, \
                    contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as exit_code:
                airgap.main([command, "--help"])
            self.assertEqual(exit_code.exception.code, 0)
            tools.assert_not_called()


if __name__ == "__main__":
    unittest.main()

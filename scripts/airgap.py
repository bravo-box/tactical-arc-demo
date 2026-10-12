#!/usr/bin/env python3
"""Transfer an explicitly selected Helm chart and images without storing credentials."""

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tempfile


class BundleError(ValueError):
    """Invalid input or an incomplete bundle."""


COMPONENT = r"[a-z0-9]+(?:(?:[._]|__|-+)[a-z0-9]+)*"
REPOSITORY = re.compile(rf"{COMPONENT}(?:/{COMPONENT})*")
TAG = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}")
VERSION = re.compile(r"v?\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?")
SHA256 = re.compile(r"[0-9a-f]{64}")


def require(condition, message):
    if not condition:
        raise BundleError(message)


def registry(value):
    require(isinstance(value, str), "registry must be a string")
    parts = value.split("/")
    host = parts[0]
    match = re.fullmatch(
        r"([A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?)(?::([0-9]+))?", host
    )
    require(match is not None, "registry must be HOST[:PORT][/PREFIX], without a protocol")
    require(all(label and not label.startswith("-") and not label.endswith("-")
                for label in match[1].split(".")), "invalid registry hostname")
    if match[2]:
        require(1 <= int(match[2]) <= 65535, "invalid registry port")
    if len(parts) > 1:
        require(REPOSITORY.fullmatch("/".join(parts[1:])) is not None,
                "invalid registry prefix")
    return value


def tagged_repository(value, require_tag=False):
    require(isinstance(value, str), "image reference must be a string")
    name, separator, tag = value.rpartition(":")
    if not separator:
        require(not require_tag, "destination must include an explicit :tag")
        name, tag = value, "latest"
    require(REPOSITORY.fullmatch(name) is not None, "invalid image repository")
    require(TAG.fullmatch(tag) is not None, "invalid image tag")
    return name + ":" + tag


def image_entry(value):
    require(isinstance(value, str) and value.count("=") <= 1, "invalid image mapping")
    source, separator, destination = value.partition("=")
    require(source and not any(c.isspace() for c in source), "invalid image source")
    reference = source
    if "/" in source:
        first, remainder = source.split("/", 1)
        if "." in first or ":" in first or first == "localhost":
            registry(first)
            reference = remainder
    if "@" in reference:
        name, digest = reference.split("@", 1)
        tagged_repository(name)
        require(re.fullmatch(r"sha256:[0-9a-f]{64}", digest) is not None,
                "invalid digest image reference")
        require(separator, "digest images require SOURCE=DESTINATION_REPOSITORY:TAG")
    else:
        default = tagged_repository(reference)
    if separator:
        destination = tagged_repository(destination, require_tag=True)
    else:
        destination = default
    return {"source": source, "destination": destination}


def unique_images(entries):
    images = []
    destinations = {}
    for entry in entries:
        image = image_entry(entry)
        old = destinations.get(image["destination"])
        require(old is None or old == image["source"],
                "different sources map to the same destination: " + image["destination"])
        if old is None:
            destinations[image["destination"]] = image["source"]
            images.append(image)
    require(images, "at least one --image or --images-file entry is required")
    return images


def safe_path(root, value):
    require(isinstance(value, str) and value and "\\" not in value,
            "invalid bundle path")
    path = PurePosixPath(value)
    require(not path.is_absolute() and all(p not in ("", ".", "..") for p in value.split("/")),
            "unsafe bundle path: " + value)
    current = root
    for part in path.parts:
        current = current / part
        require(not current.is_symlink(), "symlinks are not permitted in bundles")
    return current


def inventory(root):
    require(root.is_dir() and not root.is_symlink(), "bundle must be a real directory")
    files = {}
    for directory, directories, filenames in os.walk(root, followlinks=False):
        for name in directories + filenames:
            path = Path(directory) / name
            require(not path.is_symlink(), "symlinks are not permitted in bundles")
        for name in filenames:
            path = Path(directory) / name
            require(path.is_file(), "bundle contains a non-regular file")
            relative = path.relative_to(root).as_posix()
            safe_path(root, relative)
            if relative != "manifest.json":
                files[relative] = file_hash(path)
    return files


def file_hash(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path):
    def no_duplicates(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "duplicate JSON key: " + key)
            result[key] = value
        return result
    with path.open(encoding="utf-8") as stream:
        return json.load(stream, object_pairs_hook=no_duplicates)


def validate_layout(path):
    require(read_json(path / "oci-layout") == {"imageLayoutVersion": "1.0.0"},
            "invalid OCI layout")
    index = read_json(path / "index.json")
    require(isinstance(index, dict) and index.get("schemaVersion") == 2,
            "invalid OCI index")
    manifests = index.get("manifests")
    require(isinstance(manifests, list) and len(manifests) == 1 and
            isinstance(manifests[0], dict) and
            manifests[0].get("annotations", {}).get("org.opencontainers.image.ref.name") == "bundle",
            "OCI layout must contain exactly one bundle reference")
    visited = set()

    def descriptor(item, manifest_required=False):
        require(isinstance(item, dict), "invalid OCI descriptor")
        digest = item.get("digest", "")
        require(isinstance(digest, str) and
                re.fullmatch(r"sha256:[0-9a-f]{64}", digest) is not None,
                "unsupported or invalid OCI blob digest")
        blob = path / "blobs" / "sha256" / digest[7:]
        require(blob.is_file() and file_hash(blob) == digest[7:] and
                type(item.get("size")) is int and blob.stat().st_size == item["size"],
                "missing or corrupt OCI blob: " + digest)
        if digest in visited:
            return
        visited.add(digest)
        media = item.get("mediaType", "")
        require(isinstance(media, str), "invalid OCI media type")
        is_manifest = media in (
            "application/vnd.oci.image.manifest.v1+json",
            "application/vnd.docker.distribution.manifest.v2+json",
            "application/vnd.oci.image.index.v1+json",
            "application/vnd.docker.distribution.manifest.list.v2+json",
        )
        require(not manifest_required or is_manifest, "unsupported OCI manifest media type")
        if is_manifest:
            document = read_json(blob)
            require(isinstance(document, dict) and document.get("schemaVersion") == 2,
                    "invalid OCI manifest")
            if "manifests" in document:
                require(isinstance(document["manifests"], list) and document["manifests"],
                        "empty OCI image index")
                for child in document["manifests"]:
                    descriptor(child, manifest_required=True)
            else:
                require(isinstance(document.get("layers"), list) and "config" in document,
                        "incomplete OCI image manifest")
                descriptor(document["config"])
                for child in document["layers"]:
                    descriptor(child)

    descriptor(manifests[0], manifest_required=True)


def validate_bundle(root):
    safe_path(root, "manifest.json")
    files = inventory(root)
    manifest = read_json(root / "manifest.json")
    require(isinstance(manifest, dict) and
            set(manifest) == {"schema_version", "chart", "images", "files"} and
            type(manifest["schema_version"]) is int and manifest["schema_version"] == 1,
            "unsupported bundle manifest schema")
    expected = manifest["files"]
    require(isinstance(expected, dict) and expected, "missing artifact checksums")
    for name, digest in expected.items():
        safe_path(root, name)
        require(isinstance(digest, str) and SHA256.fullmatch(digest),
                "invalid artifact checksum")
    require(files == expected, "bundle artifacts are missing, unexpected, or have invalid checksums")
    chart = manifest["chart"]
    require(isinstance(chart, dict) and set(chart) == {"source", "version", "file"},
            "invalid chart metadata")
    validate_chart(chart["source"], chart["version"])
    chart_path = safe_path(root, chart["file"])
    require(chart["file"].startswith("chart/") and chart_path.suffix == ".tgz" and
            chart["file"] in files, "missing chart package")
    require([name for name in files if name.startswith("chart/")] == [chart["file"]],
            "bundle must contain exactly one chart package")
    images = manifest["images"]
    require(isinstance(images, list) and images, "missing bundle images")
    seen = set()
    allowed = {chart["file"]}
    for i, image in enumerate(images):
        require(isinstance(image, dict) and set(image) == {"source", "destination", "layout"},
                "invalid image metadata")
        parsed = image_entry(image["source"] + "=" + image["destination"])
        require(parsed["destination"] not in seen, "duplicate image destination")
        seen.add(parsed["destination"])
        require(image["layout"] == f"images/{i:04d}", "invalid image layout path")
        layout = safe_path(root, image["layout"])
        layout_files = [name for name in files if name.startswith(image["layout"] + "/")]
        for name in layout_files:
            relative = name[len(image["layout"]) + 1:]
            require(relative in ("index.json", "oci-layout") or
                    re.fullmatch(r"blobs/sha256/[0-9a-f]{64}", relative) is not None,
                    "unexpected OCI layout artifact")
        validate_layout(layout)
        allowed.update(layout_files)
    require(set(files) == allowed, "unexpected artifacts outside chart and image layouts")
    return manifest


def validate_chart(source, version):
    require(isinstance(source, str) and source.startswith("oci://"),
            "--chart must be an OCI Helm reference")
    reference = source[6:]
    require("/" in reference, "chart reference must contain a registry and repository")
    host, path = reference.split("/", 1)
    registry(host)
    require(REPOSITORY.fullmatch(path) is not None, "invalid chart repository")
    require(isinstance(version, str) and VERSION.fullmatch(version) is not None,
            "--chart-version must be an exact semantic version")


def tools():
    for name in ("helm", "skopeo"):
        require(shutil.which(name) is not None, f"{name} is required; install it and configure registry login")


def run(command):
    try:
        return subprocess.run(command, check=True, capture_output=True, text=True).stdout
    except subprocess.CalledProcessError as error:
        raise BundleError(f"{command[0]} {command[1]} failed (exit {error.returncode}); "
                          "check registry access, authentication, and TLS trust") from error


def download(args):
    validate_chart(args.chart, args.chart_version)
    entries = list(args.image)
    if args.images_file:
        with Path(args.images_file).open(encoding="utf-8") as stream:
            entries.extend(line.strip() for line in stream
                           if line.strip() and not line.lstrip().startswith("#"))
    images = unique_images(entries)
    bundle = Path(args.bundle).absolute()
    require(not os.path.lexists(bundle), "--bundle must not already exist")
    require(bundle.parent.is_dir(), "bundle parent directory must already exist")
    tools()
    stage = Path(tempfile.mkdtemp(prefix="." + bundle.name + ".staging-", dir=bundle.parent))
    try:
        (stage / "chart").mkdir()
        run(["helm", "pull", args.chart, "--version", args.chart_version,
             "--destination", str(stage / "chart")])
        charts = list((stage / "chart").glob("*.tgz"))
        require(len(charts) == 1, "helm pull must produce exactly one chart package")
        metadata = run(["helm", "show", "chart", str(charts[0])])
        versions = re.findall(r"^version:\s*[\"']?([^\"'\s]+)[\"']?\s*$", metadata, re.MULTILINE)
        require(versions == [args.chart_version.lstrip("v")],
                "downloaded chart version does not match --chart-version")
        (stage / "images").mkdir()
        for i, image in enumerate(images):
            image["layout"] = f"images/{i:04d}"
            run(["skopeo", "copy", "--all", "--preserve-digests",
                 "docker://" + image["source"], f"oci:{stage / image['layout']}:bundle"])
        manifest = {
            "schema_version": 1,
            "chart": {"source": args.chart, "version": args.chart_version,
                      "file": charts[0].relative_to(stage).as_posix()},
            "images": images,
            "files": inventory(stage),
        }
        with (stage / "manifest.json").open("w", encoding="utf-8") as stream:
            json.dump(manifest, stream, indent=2, sort_keys=True)
            stream.write("\n")
        validate_bundle(stage)
        require(not os.path.lexists(bundle), "--bundle appeared during download")
        stage.rename(bundle)
    finally:
        if stage.exists():
            shutil.rmtree(stage)
    print(f"Bundle created: {bundle}")


def upload(args):
    target = registry(args.registry)
    root = Path(args.bundle).absolute()
    manifest = validate_bundle(root)
    tools()
    for image in manifest["images"]:
        destination = target + "/" + image["destination"]
        run(["skopeo", "copy", "--all", "--preserve-digests",
             f"oci:{root / image['layout']}:bundle", "docker://" + destination])
        print(image["source"] + "=" + destination)
    run(["helm", "push", str(root / manifest["chart"]["file"]), "oci://" + target + "/charts"])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    pull = commands.add_parser("download", help="download a pinned OCI chart and explicit images")
    pull.add_argument("--chart", required=True, help="oci://HOST/PATH/CHART")
    pull.add_argument("--chart-version", required=True, help="exact chart semantic version")
    pull.add_argument("--bundle", required=True, help="new bundle directory (parent must exist)")
    pull.add_argument("--image", action="append", default=[], help="SOURCE[=DESTINATION_REPOSITORY:TAG]")
    pull.add_argument("--images-file", help="newline image entries; blank lines and # comments ignored")
    pull.set_defaults(action=download)
    push = commands.add_parser("upload", help="validate and upload an offline bundle")
    push.add_argument("--bundle", required=True, help="existing bundle directory")
    push.add_argument("--registry", required=True, help="HOST[:PORT][/PREFIX], without protocol")
    push.set_defaults(action=upload)
    args = parser.parse_args(argv)
    try:
        args.action(args)
    except (BundleError, OSError, ValueError, TypeError, KeyError, AttributeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

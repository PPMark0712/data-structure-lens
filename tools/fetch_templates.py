#!/usr/bin/env python3
"""Fetch selected Godot export templates from the official archive using HTTP ranges."""
import argparse
import io
from pathlib import Path
import urllib.request
import zipfile

VERSION = "4.7.2"
ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_NAMES = {
    "web": ["web_nothreads_release.zip"],
    "windows": ["windows_release_x86_64.exe"],
    "macos": ["macos.zip"],
}
WEB_TEMPLATE_MEMBERS = {"godot.html", "godot.js", "godot.wasm"}


def _valid_zip(path, required_members=(), required_suffix=""):
    if not path.is_file() or not zipfile.is_zipfile(path):
        return False
    try:
        with zipfile.ZipFile(path) as archive:
            names = archive.namelist()
            return (
                set(required_members).issubset(names)
                and (not required_suffix or any(name.endswith(required_suffix) for name in names))
                and archive.testzip() is None
            )
    except (OSError, zipfile.BadZipFile):
        return False


def template_ready(path):
    path = Path(path)
    if path.name.startswith("web_"):
        return _valid_zip(path, WEB_TEMPLATE_MEMBERS)
    if path.name == "macos.zip":
        return _valid_zip(path, required_suffix="godot_macos_release.universal")
    if path.name.startswith("windows_release_") and path.suffix == ".exe":
        if not path.is_file() or path.stat().st_size < 1024 * 1024:
            return False
        try:
            with path.open("rb") as stream:
                return stream.read(2) == b"MZ"
        except OSError:
            return False
    return False


class RemoteZip(io.RawIOBase):
    def __init__(self, url):
        super().__init__()
        self.url = url
        self.position = 0
        with urllib.request.urlopen(
            urllib.request.Request(url, method="HEAD"), timeout=60
        ) as response:
            self.size = int(response.headers["Content-Length"])
        self.tail_start = max(0, self.size - 65536)
        request = urllib.request.Request(
            url, headers={"Range": f"bytes={self.tail_start}-{self.size - 1}"}
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            if response.status != 206:
                raise RuntimeError("Server must support HTTP Range; refusing a full archive download.")
            self.tail = response.read()

    def seekable(self):
        return True

    def seek(self, offset, whence=0):
        self.position = offset + (0 if whence == 0 else self.position if whence == 1 else self.size)
        return self.position

    def tell(self):
        return self.position

    def read(self, size=-1):
        end = self.size if size < 0 else min(self.size, self.position + size)
        if end <= self.position:
            return b""
        if self.position >= self.tail_start:
            data = self.tail[self.position - self.tail_start:end - self.tail_start]
        else:
            request = urllib.request.Request(
                self.url, headers={"Range": f"bytes={self.position}-{end - 1}"}
            )
            with urllib.request.urlopen(request, timeout=90) as response:
                expected = f"bytes {self.position}-{end - 1}/{self.size}"
                if response.status != 206 or response.headers.get("Content-Range") != expected:
                    raise RuntimeError(f"Unexpected Range response: {response.headers.get('Content-Range')}")
                data = response.read()
            if len(data) != end - self.position:
                raise RuntimeError("Incomplete template download; rerun the command.")
        self.position = end
        return data


def ensure_templates(platforms):
    platforms = set(platforms)
    unknown = platforms.difference(TEMPLATE_NAMES)
    if unknown:
        raise ValueError(f"Unknown template platforms: {sorted(unknown)}")
    target = ROOT / ".tools" / "templates"
    target.mkdir(parents=True, exist_ok=True)
    names = [name for platform in sorted(platforms) for name in TEMPLATE_NAMES[platform]]
    missing = [name for name in names if not template_ready(target / name)]
    if not missing:
        print(f"Templates ready: {target}", flush=True)
        return
    url = (
        f"https://github.com/godotengine/godot/releases/download/{VERSION}-stable/"
        f"Godot_v{VERSION}-stable_export_templates.tpz"
    )
    print(f"Reading Godot {VERSION} archive directory...", flush=True)
    with zipfile.ZipFile(RemoteZip(url)) as archive:
        for name in missing:
            info = archive.getinfo(f"templates/{name}")
            print(f"Downloading {name} ({info.compress_size / 1048576:.1f} MiB)...", flush=True)
            data = archive.read(info)
            temporary = target / (name + ".tmp")
            temporary.write_bytes(data)
            destination = target / name
            temporary.replace(destination)
            if not template_ready(destination):
                destination.unlink(missing_ok=True)
                raise RuntimeError(f"Downloaded template is invalid: {name}")
            print(f"Saved {destination}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--platform",
        action="append",
        choices=[*TEMPLATE_NAMES, "all"],
        help="template platform; repeat as needed (default: web)",
    )
    args = parser.parse_args()
    selected = set(args.platform or ["web"])
    if "all" in selected:
        selected = set(TEMPLATE_NAMES)
    ensure_templates(selected)


if __name__ == "__main__":
    main()

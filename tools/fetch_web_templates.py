#!/usr/bin/env python3
"""Fetch only the Web templates from Godot's large release archive (HTTP Range)."""
import argparse
import io
from pathlib import Path
import urllib.request
import zipfile

VERSION = "4.7.2"
ROOT = Path(__file__).resolve().parents[1]


class RemoteZip(io.RawIOBase):
    def __init__(self, url):
        self.url = url
        self.position = 0
        with urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=60) as response:
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--debug", action="store_true", help="also fetch the single-thread debug template")
    args = parser.parse_args()
    target = ROOT / ".tools" / "templates"
    target.mkdir(parents=True, exist_ok=True)
    names = ["web_nothreads_release.zip"] + (["web_nothreads_debug.zip"] if args.debug else [])
    missing = [name for name in names if not (target / name).exists()]
    if not missing:
        print(f"Templates ready: {target}")
        return
    url = (
        f"https://github.com/godotengine/godot/releases/download/{VERSION}-stable/"
        f"Godot_v{VERSION}-stable_export_templates.tpz"
    )
    print(f"Reading Godot {VERSION} archive directory…", flush=True)
    with zipfile.ZipFile(RemoteZip(url)) as archive:
        for name in missing:
            info = archive.getinfo(f"templates/{name}")
            print(f"Downloading {name} ({info.compress_size / 1048576:.1f} MiB)…", flush=True)
            data = archive.read(info)  # ZipFile verifies the entry's CRC.
            temporary = target / (name + ".tmp")
            temporary.write_bytes(data)
            if not zipfile.is_zipfile(temporary):
                raise RuntimeError(f"{name} is not a valid ZIP template")
            temporary.replace(target / name)
            print(f"Saved {target / name}", flush=True)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Run, check, export, or serve the lab using Python's standard library."""
import argparse
import functools
import http.server
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from fetch_web_templates import VERSION, template_ready


def engine():
    candidates = [
        os.environ.get("GODOT"), ROOT / ".tools" / "godot",
        shutil.which("godot"), shutil.which("godot4"),
        "/Applications/Godot.app/Contents/MacOS/Godot",
    ]
    executable = next((str(path) for path in candidates if path and Path(path).is_file()), None)
    if not executable:
        raise SystemExit(f"Install Godot {VERSION}, or set GODOT to its executable path.")
    version = subprocess.check_output([executable, "--version"], text=True).strip()
    if not version.startswith(VERSION + "."):
        raise SystemExit(f"Expected Godot {VERSION}; found {version}. Set GODOT to the matching executable.")
    return executable


def run_godot(executable, *args, log="godot"):
    logs = ROOT / ".tools"
    logs.mkdir(exist_ok=True)
    subprocess.run(
        [executable, "--path", str(ROOT), "--log-file", str(logs / f"{log}.log"), *args],
        cwd=ROOT, check=True,
    )


def serve(port, bind):
    directory = ROOT / "build" / "web"
    if not (directory / "index.html").exists():
        raise SystemExit("Export first: python3 tools/project.py export")
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(directory))
    with http.server.ThreadingHTTPServer((bind, port), handler) as server:
        print(f"Data Structure Lab: http://{bind}:{port}/ (Ctrl+C to stop)", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["run", "test", "export", "serve"])
    parser.add_argument("--port", type=int, default=8060)
    parser.add_argument("--bind", default="127.0.0.1")
    args = parser.parse_args()
    if args.command == "serve":
        serve(args.port, args.bind)
        return
    if args.command == "export":
        build = ROOT / "build"
        build.mkdir(exist_ok=True)
        (build / ".gdignore").touch()
    executable = engine()
    run_godot(executable, "--headless", "--editor", "--import", "--quit", log="import")
    if args.command == "run":
        run_godot(executable, log="desktop")
        return
    if args.command == "test":
        subprocess.run([sys.executable, "-m", "unittest", "tests.test_tools"], cwd=ROOT, check=True)
        for name in ["models", "advanced", "teaching", "interactions"]:
            run_godot(executable, "--headless", "--script", f"tests/test_{name}.gd", log=name)
    elif args.command == "export":
        template = ROOT / ".tools" / "templates" / "web_nothreads_release.zip"
        if not template_ready(template):
            subprocess.run([sys.executable, str(ROOT / "tools" / "fetch_web_templates.py")], check=True)
        destination = ROOT / "build" / "web"
        destination.mkdir(parents=True, exist_ok=True)
        run_godot(executable, "--headless", "--export-release", "Web", str(destination / "index.html"), log="export")
        (destination / ".nojekyll").touch()
        print(f"Exported to {destination}\nPreview: python3 tools/project.py serve", flush=True)


if __name__ == "__main__":
    main()

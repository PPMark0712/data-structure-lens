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
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
WEB_BUILD = BUILD / "web"
RELEASES = BUILD / "releases"
sys.path.insert(0, str(Path(__file__).resolve().parent))
from fetch_templates import VERSION, ensure_templates


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
    if not (WEB_BUILD / "index.html").exists():
        raise SystemExit("Export first: python3 tools/project.py export")
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(WEB_BUILD))
    with http.server.ThreadingHTTPServer((bind, port), handler) as server:
        print(f"Data Structure Lab: http://{bind}:{port}/ (Ctrl+C to stop)", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


def prepare_build():
    BUILD.mkdir(exist_ok=True)
    (BUILD / ".gdignore").touch()


def clean_directory(path):
    shutil.rmtree(path, ignore_errors=True)
    path.mkdir(parents=True)


def export_web(executable):
    ensure_templates({"web"})
    clean_directory(WEB_BUILD)
    run_godot(
        executable,
        "--headless",
        "--export-release",
        "Web",
        str(WEB_BUILD / "index.html"),
        log="export-web",
    )
    (WEB_BUILD / ".nojekyll").touch()
    print(f"Web build: {WEB_BUILD}", flush=True)


def package_windows(executable):
    windows = BUILD / "windows"
    clean_directory(windows)
    run_godot(
        executable,
        "--headless",
        "--export-release",
        "Windows",
        str(windows / "DataStructureLab.exe"),
        log="export-windows",
    )
    destination = RELEASES / "DataStructureLab-Windows-x86_64.zip"
    destination.unlink(missing_ok=True)
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(windows.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(windows).as_posix())
    with zipfile.ZipFile(destination) as archive:
        if "DataStructureLab.exe" not in archive.namelist() or archive.testzip() is not None:
            raise RuntimeError("Windows release ZIP validation failed.")
    return destination


def install_macos_template(executable):
    executable = Path(executable).resolve()
    if (executable.parent / "_sc_").is_file():
        template_dir = (
            executable.parent
            / "editor_data"
            / "export_templates"
            / f"{VERSION}.stable"
        )
    elif sys.platform == "darwin":
        template_dir = (
            Path.home()
            / "Library"
            / "Application Support"
            / "Godot"
            / "export_templates"
            / f"{VERSION}.stable"
        )
    else:
        template_dir = (
            Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))
            / "godot"
            / "export_templates"
            / f"{VERSION}.stable"
        )
    template_dir.mkdir(parents=True, exist_ok=True)
    destination = template_dir / "macos.zip"
    source = ROOT / ".tools" / "templates" / "macos.zip"
    if destination.exists() or destination.is_symlink():
        destination.unlink()
    try:
        destination.symlink_to(source)
    except OSError:
        shutil.copy2(source, destination)


def package_macos(executable):
    install_macos_template(executable)
    destination = RELEASES / "DataStructureLab-macOS-universal.zip"
    destination.unlink(missing_ok=True)
    run_godot(
        executable,
        "--headless",
        "--export-release",
        "macOS",
        str(destination),
        log="export-macos",
    )
    with zipfile.ZipFile(destination) as archive:
        names = archive.namelist()
        if not any(".app/Contents/MacOS/" in name for name in names) or archive.testzip() is not None:
            raise RuntimeError("macOS release ZIP validation failed.")
    return destination


def package_all(executable):
    ensure_templates({"windows", "macos"})
    clean_directory(RELEASES)
    export_web(executable)
    windows = package_windows(executable)
    macos = package_macos(executable)
    print(f"Windows package: {windows}", flush=True)
    print(f"macOS package:   {macos}", flush=True)
    print("The Web server still serves build/web only.", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command",
        choices=["run", "test", "export", "package", "templates", "serve"],
    )
    parser.add_argument("--port", type=int, default=8060)
    parser.add_argument("--bind", default="127.0.0.1")
    args = parser.parse_args()
    if args.command == "serve":
        serve(args.port, args.bind)
        return
    if args.command == "templates":
        ensure_templates({"web", "windows", "macos"})
        return
    if args.command in ["export", "package"]:
        prepare_build()
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
        export_web(executable)
        print("Preview: python3 tools/project.py serve", flush=True)
    elif args.command == "package":
        package_all(executable)


if __name__ == "__main__":
    main()

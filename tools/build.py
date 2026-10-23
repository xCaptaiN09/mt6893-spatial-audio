#!/usr/bin/env python3
"""Build a deterministic installable ZIP using Python's standard library."""
from pathlib import Path
import argparse
import hashlib
import json
import stat
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "module"
sha = lambda data: hashlib.sha256(data).hexdigest()


def metadata():
    return dict(line.split("=", 1) for line in (MODULE / "module.prop").read_text(encoding="utf-8").splitlines() if "=" in line and not line.startswith("#"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Alternate output ZIP path")
    arguments = parser.parse_args()
    properties = metadata()
    if properties["id"] != "mt6893-spatial-audio":
        raise SystemExit("Internal module ID changed; review update compatibility first")
    output = arguments.output or ROOT / "releases" / ("mt6893-spatial-audio-v" + properties["version"] + ".zip")
    if output.resolve().is_relative_to(MODULE.resolve()):
        raise SystemExit("Output must be outside module/")
    files = sorted(path for path in MODULE.rglob("*") if path.is_file())
    if any(path.is_symlink() for path in MODULE.rglob("*")):
        raise SystemExit("Module source must not contain symlinks")
    build = json.loads((ROOT / "tools/diagnostics/playback/BUILD.json").read_text(encoding="utf-8"))
    for name, key in (("SpatialPlaybackProbe.java", "source_sha256"), ("probe.jar", "jar_sha256")):
        if sha((ROOT / "tools/diagnostics/playback" / name).read_bytes()) != build[key]:
            raise SystemExit("Diagnostic source/JAR changed. Recompile with tools/compile_probe.py before building")
    baseline = json.loads((ROOT / "docs/tuning-baseline.json").read_text(encoding="utf-8"))
    for name, record in baseline["files"].items():
        if sha((MODULE / "system/odm/etc/spatializer" / name).read_bytes()) != record["sha256"]:
            raise SystemExit("Selected original v0.6 tuning changed: " + name)
    if any(path.name == "libaudiopolicyextimpl.so" for path in files):
        raise SystemExit("The phone policy library must be copied during installation, not bundled")
    diagnostic = ROOT / "tools/diagnostics"
    (diagnostic / "SHA256SUMS").write_bytes("".join(f"{sha(p.read_bytes())}  {p.relative_to(diagnostic).as_posix()}\n" for p in sorted(diagnostic.rglob("*")) if p.is_file() and p.name != "SHA256SUMS").encode("utf-8"))
    manifest = "".join(f"{sha(path.read_bytes())}  {path.relative_to(MODULE).as_posix()}\n" for path in files if path.name != "SHA256SUMS")
    (MODULE / "SHA256SUMS").write_bytes(manifest.encode("utf-8"))
    files = sorted(path for path in MODULE.rglob("*") if path.is_file())
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            info = zipfile.ZipInfo(path.relative_to(MODULE).as_posix(), (1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | (0o755 if path.suffix == ".sh" else 0o644)) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, path.read_bytes())
    checksum = sha(output.read_bytes())
    (output.parent / "SHA256SUMS").write_bytes(f"{checksum}  {output.name}\n".encode("utf-8"))
    print("Built:", output)
    print("Size:", output.stat().st_size, "bytes")
    print("SHA-256:", checksum)


if __name__ == "__main__":
    main()

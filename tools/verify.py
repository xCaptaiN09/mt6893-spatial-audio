#!/usr/bin/env python3
"""Audit project source, original tuning, reproduced libraries and release ZIP."""
from pathlib import Path
import ast
import hashlib
import json
import re
import shutil
import stat
import struct
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "module"
sha = lambda data: hashlib.sha256(data).hexdigest()


def require(condition, reason):
    if not condition:
        raise SystemExit("FAIL: " + reason)


def main():
    prop = dict(line.split("=", 1) for line in (MODULE / "module.prop").read_text(encoding="utf-8").splitlines() if "=" in line)
    expected = {"id": "mt6893-spatial-audio", "name": "MT6893 Spatial Audio", "author": "xCaptaiN09", "version": "1.0.0", "versionCode": "100"}
    require(all(prop.get(key) == value for key, value in expected.items()), "module metadata differs from the selected release")
    files = sorted(path for path in MODULE.rglob("*") if path.is_file())
    require(not any(path.is_symlink() for path in ROOT.rglob("*")), "symlink in project")
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix in (".py", ".sh", ".md", ".txt", ".json", ".prop") or path.name in ("LICENSE", "NOTICE", "SHA256SUMS"):
            text = path.read_text(encoding="utf-8")
            require("\r" not in text, "non-LF text: " + str(path.relative_to(ROOT)))
            require(not re.search(r"/work[s]pace/", text), "workspace-specific path: " + str(path.relative_to(ROOT)))
        if path.suffix == ".py":
            ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        if path.suffix == ".sh" and shutil.which("sh"):
            subprocess.run(["sh", "-n", str(path)], check=True)
    print("PASS metadata, source syntax, LF text and portable paths")
    for development_entry in ("reproduction", "playback", "height-test.sh", "PATCHES.json", "README.txt"):
        require(not (MODULE / development_entry).exists(), "development-only entry in flashable source: " + development_entry)
    baseline = json.loads((ROOT / "docs/tuning-baseline.json").read_text(encoding="utf-8"))
    require(baseline["radius_multiplier"] == 1.0 and len(baseline["files"]) == 8, "preferred tuning selection")
    known_originals = {
        "HP_MOVIE_ANALOG.bin": "c92a00e87b4e58786aefde953ca9a5643b0207b190126ad82fd3a2a85dce5c79",
        "HP_MOVIE_BLUETOOTH.bin": "e755958fdd770cf4368e0e7d2ad31265d8d107786d6798b4c0cfbac5dba2cf18",
        "HP_MOVIE_DIGITAL.bin": "c92a00e87b4e58786aefde953ca9a5643b0207b190126ad82fd3a2a85dce5c79",
        "HP_MOVIE_GALILEO.bin": "e755958fdd770cf4368e0e7d2ad31265d8d107786d6798b4c0cfbac5dba2cf18",
        "HP_MUSIC_ANALOG.bin": "2764359e8935703880936371208b1235ebab48762fa35917960ab13d30563f6a",
        "HP_MUSIC_BLUETOOTH.bin": "4b45d1abfe61cfc6f249cd81c6d238f0ee4876d49de15a0307c8056530c7c54c",
        "HP_MUSIC_DIGITAL.bin": "b585e81f4125af94026706789d72bc7721c08e93658fa561431584a2f7fffa7a",
        "HP_MUSIC_GALILEO.bin": "b7790e9bb7e0d849f4ff2467c8a951696433d07099e246988b7992320d873572",
    }
    for name, digest in known_originals.items():
        data = (MODULE / "system/odm/etc/spatializer" / name).read_bytes()
        record = baseline["files"][name]
        require(len(data) == 43556 and sha(data) == digest == record["sha256"], "original v0.6 profile: " + name)
        for positions in record["positions"]:
            for index, values in enumerate(positions["values"]):
                require(list(struct.unpack_from("<3f", data, positions["offset"] + index * 12)) == values, "documented position differs")
    print("PASS all 8 original v0.6 profile hashes and exact documented positions")
    manifest = {}
    for line in (MODULE / "SHA256SUMS").read_text(encoding="utf-8").splitlines():
        digest, name = line.split()
        require(name not in manifest and len(digest) == 64, "invalid/duplicate payload entry")
        require(not Path(name).is_absolute() and ".." not in Path(name).parts, "unsafe payload entry")
        require(sha((MODULE / name).read_bytes()) == digest, "payload hash: " + name)
        manifest[name] = digest
    require(set(manifest) == {path.relative_to(MODULE).as_posix() for path in files if path.name != "SHA256SUMS"}, "payload manifest coverage")
    live = {}
    for line in (MODULE / "LIVE-SHA256SUMS").read_text(encoding="utf-8").splitlines():
        digest, target = line.split()
        require(target not in live, "duplicate live target")
        live[target] = digest
        if target == "/system_ext/lib64/libaudiopolicyextimpl.so":
            require(digest == "0539b48b43c6a5dcb292f82c1861bc9f191590d46e664a4eb3238d3f282f4114", "phone patch output hash")
            require(not (MODULE / ("system" + target)).exists(), "bundled phone policy extension")
        else:
            require(sha((MODULE / ("system" + target)).read_bytes()) == digest, "mounted source: " + target)
    require(len(live) == 16, "live mount count")
    require((MODULE / "patches/settings-wired-branch.bin").read_bytes() == bytes.fromhex("75000037"), "activation instruction changed")
    build = json.loads((ROOT / "tools/diagnostics/playback/BUILD.json").read_text(encoding="utf-8"))
    require(sha((ROOT / "tools/diagnostics/playback/probe.jar").read_bytes()) == build["jar_sha256"], "diagnostic JAR hash")
    require(sha((ROOT / "tools/diagnostics/playback/SpatialPlaybackProbe.java").read_bytes()) == build["source_sha256"], "diagnostic source changed without recompilation")
    diagnostic = ROOT / "tools/diagnostics"
    diagnostic_entries = set()
    for line in (diagnostic / "SHA256SUMS").read_text().splitlines():
        digest, name = line.split()
        require(name not in diagnostic_entries and not Path(name).is_absolute() and ".." not in Path(name).parts, "diagnostic manifest path")
        require(sha((diagnostic / name).read_bytes()) == digest, "diagnostic file hash: " + name)
        diagnostic_entries.add(name)
    require(diagnostic_entries == {p.relative_to(diagnostic).as_posix() for p in diagnostic.rglob("*") if p.is_file() and p.name != "SHA256SUMS"}, "diagnostic manifest coverage")
    subprocess.run([sys.executable, str(ROOT / "tools/reproduce_libraries.py")], check=True)
    print("PASS payload/live manifests, activation bytes, diagnostic pairing and reproduced libraries")
    archive_path = ROOT / "releases" / ("mt6893-spatial-audio-v" + prop["version"] + ".zip")
    with zipfile.ZipFile(archive_path) as archive:
        require(archive.testzip() is None, "ZIP CRC")
        names = archive.namelist()
        require(len(names) == len(set(names)), "duplicate ZIP member")
        require(set(names) == {path.relative_to(MODULE).as_posix() for path in files}, "ZIP coverage")
        for info in archive.infolist():
            require(not Path(info.filename).is_absolute() and ".." not in Path(info.filename).parts, "unsafe ZIP path")
            require(not info.flag_bits & 1 and stat.S_ISREG(info.external_attr >> 16), "nonregular/encrypted ZIP entry")
            require(archive.read(info) == (MODULE / info.filename).read_bytes(), "ZIP/source mismatch: " + info.filename)
            require((info.external_attr >> 16) & 0o777 == (0o755 if info.filename.endswith(".sh") else 0o644), "ZIP permissions")
            require(info.date_time == (1980, 1, 1, 0, 0, 0), "ZIP timestamp")
    checksum = (ROOT / "releases/SHA256SUMS").read_text(encoding="utf-8").split()
    require(checksum == [sha(archive_path.read_bytes()), archive_path.name], "release checksum/name")
    for document in ROOT.rglob("*.md"):
        for link in re.findall(r"\[[^\]]*\]\(([^)]+)\)", document.read_text(encoding="utf-8")):
            if "://" not in link and not link.startswith("#"):
                require((document.parent / link.split("#")[0]).exists(), "broken Markdown link: " + link)
    print("PASS release ZIP source equality, CRC, metadata, permissions, checksum and local links")
    print("AUDIT PASSED. This is a PC release audit, not a new phone playback test.")


if __name__ == "__main__":
    main()

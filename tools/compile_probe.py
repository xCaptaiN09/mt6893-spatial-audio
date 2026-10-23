#!/usr/bin/env python3
"""Recompile the optional diagnostic using the recorded exact ECJ and R8 JARs."""
from pathlib import Path
import argparse
import hashlib
import json
import stat
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PLAYBACK = ROOT / "tools/diagnostics/playback"
sha = lambda data: hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ecj", required=True, type=Path)
    parser.add_argument("--r8", required=True, type=Path)
    parser.add_argument("--java", default="java", help="Java executable")
    args = parser.parse_args()
    record = json.loads((PLAYBACK / "BUILD.json").read_text(encoding="utf-8"))
    for path, key in ((args.ecj, "ecj_sha256"), (args.r8, "r8_sha256")):
        if sha(path.read_bytes()) != record[key]:
            raise SystemExit("Tool checksum differs from recorded build: " + str(path))
    with tempfile.TemporaryDirectory(prefix="mt6893-spatial-java-") as tmp:
        tmp = Path(tmp)
        classes, dex = tmp / "classes", tmp / "dex"
        classes.mkdir()
        dex.mkdir()
        subprocess.run([args.java, "-jar", str(args.ecj.resolve()), "-1.8", "-proc:none", "-d", str(classes), str(PLAYBACK / "SpatialPlaybackProbe.java")], check=True)
        subprocess.run([args.java, "-cp", str(args.r8.resolve()), "com.android.tools.r8.D8", "--min-api", "23", "--output", str(dex), str(classes / "SpatialPlaybackProbe.class")], check=True)
        with zipfile.ZipFile(tmp / "probe.jar", "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            info = zipfile.ZipInfo("classes.dex", (1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, (dex / "classes.dex").read_bytes())
        (PLAYBACK / "probe.jar").write_bytes((tmp / "probe.jar").read_bytes())
    record["source_sha256"] = sha((PLAYBACK / "SpatialPlaybackProbe.java").read_bytes())
    record["jar_sha256"] = sha((PLAYBACK / "probe.jar").read_bytes())
    (PLAYBACK / "BUILD.json").write_bytes((json.dumps(record, indent=2) + "\n").encode("utf-8"))
    print("Diagnostic JAR and build record updated. Run tools/build.py next.")


if __name__ == "__main__":
    main()

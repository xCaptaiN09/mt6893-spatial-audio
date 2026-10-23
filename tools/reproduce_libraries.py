#!/usr/bin/env python3
"""Reproduce and compare the plugin/support patches without modifying sources."""
from pathlib import Path
import hashlib
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "module"
SCRIPTS = ROOT / "tools/reproduction"
sha = lambda data: hashlib.sha256(data).hexdigest()


def main():
    with tempfile.TemporaryDirectory(prefix="mt6893-spatial-reproduce-") as tmp:
        tmp = Path(tmp)
        logs = tmp / "logs.so"
        capability = tmp / "capability.so"
        plugin = tmp / "plugin.so"
        support = tmp / "support.so"
        commands = [
            [SCRIPTS / "patch_room_model_logs.py", SCRIPTS / "liboplus_spatializer.original.so", ROOT / "docs/patches.json", logs],
            [SCRIPTS / "patch_capability_dispatch.py", logs, ROOT / "docs/patches.json", capability],
            [SCRIPTS / "patch_private_support.py", capability, SCRIPTS / "libstdc++.original.so", plugin, support],
        ]
        for command in commands:
            subprocess.run([sys.executable, *map(str, command)], check=True, stdout=subprocess.DEVNULL)
        for actual, selected in ((plugin, MODULE / "system/odm/lib/soundfx/liboplus_spatializer.so"), (support, MODULE / "system/odm/lib/libspstdc.so")):
            if actual.read_bytes() != selected.read_bytes():
                raise SystemExit("Reproduced library differs: " + selected.name)
            print("PASS reproduced", selected.name, sha(actual.read_bytes()))


if __name__ == "__main__":
    main()

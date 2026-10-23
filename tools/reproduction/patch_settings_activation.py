"""Exact-build wired/USB restore-gate repair; modifies a supplied COPY only."""
from pathlib import Path
import hashlib
import sys

ORIGINAL_SHA256 = "353066d5ff729e6e092b46a97e156aed10876322a5d0ed7b723b9bc301a6f389"
OFFSET = 0x44604
ORIGINAL = bytes.fromhex("b5000037")  # tbnz w21, #0, 0x44618
PATCHED = bytes.fromhex("75000037")   # tbnz w21, #0, 0x44610


def patch(data):
    if hashlib.sha256(data).hexdigest() != ORIGINAL_SHA256:
        raise ValueError("Audio policy extension is not the inspected phone build")
    if data[OFFSET:OFFSET + 4] != ORIGINAL:
        raise ValueError("Unexpected original branch")
    result = bytearray(data)
    result[OFFSET:OFFSET + 4] = PATCHED
    return bytes(result)


if __name__ == "__main__":
    source, destination = map(Path, sys.argv[1:])
    if source.resolve() == destination.resolve():
        raise SystemExit("Source and destination must be different files")
    result = patch(source.read_bytes())
    destination.write_bytes(result)
    print(hashlib.sha256(result).hexdigest())

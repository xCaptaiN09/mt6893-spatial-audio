#!/usr/bin/env python3
"""Reproduce the diagnostic string-only patch. Original OEM ownership is unchanged."""
from pathlib import Path
import hashlib
import json
import sys

if len(sys.argv) != 4:
    raise SystemExit('Usage: patch_room_model_logs.py ORIGINAL PATCHES.json OUTPUT')
source = Path(sys.argv[1]).read_bytes()
spec = json.loads(Path(sys.argv[2]).read_text())
if hashlib.sha256(source).hexdigest() != spec['original_sha256']:
    raise SystemExit('Original library checksum mismatch')
result = bytearray(source)
for patch in spec['patches']:
    offset = patch['file_offset']
    old, new = patch['old'].encode(), patch['new'].encode()
    if len(new) > len(old) or source[offset:offset+len(old)+1] != old + b'\0':
        raise SystemExit('Patch bounds or original string mismatch')
    result[offset:offset+len(old)] = new + bytes(len(old)-len(new))
if hashlib.sha256(result).hexdigest() != spec['logging_patched_sha256']:
    raise SystemExit('Patched checksum mismatch')
Path(sys.argv[3]).write_bytes(result)
print('Diagnostic string-only patch reproduced.')

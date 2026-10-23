#!/usr/bin/env python3
"""Reproduce the two instruction changes to the private capability dispatcher."""
from pathlib import Path
import hashlib
import json
import sys
if len(sys.argv) != 4:
    raise SystemExit('Usage: patch_capability_dispatch.py LOG_FIXED_PLUGIN PATCHES.json OUTPUT')
source=Path(sys.argv[1]).read_bytes()
spec=json.loads(Path(sys.argv[2]).read_text())
if hashlib.sha256(source).hexdigest()!=spec['capability_input_sha256']:
    raise SystemExit('Input checksum mismatch')
result=bytearray(source)
for patch in spec['capability_dispatch_patches']:
    offset=patch['file_offset']
    old,new=bytes.fromhex(patch['old_hex']),bytes.fromhex(patch['new_hex'])
    if len(old)!=4 or len(new)!=4 or source[offset:offset+4]!=old:
        raise SystemExit('Original instruction mismatch')
    result[offset:offset+4]=new
if hashlib.sha256(result).hexdigest()!=spec['capability_output_sha256']:
    raise SystemExit('Output checksum mismatch')
Path(sys.argv[3]).write_bytes(result)
print('Private capability-dispatch patch reproduced.')

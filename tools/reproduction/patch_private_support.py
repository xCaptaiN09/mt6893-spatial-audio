"""Give the donor support library a unique ELF identity; preserve all code bytes."""
from pathlib import Path
import hashlib
import json
import struct
import sys

OLD = b'libstdc++.so'
NEW = b'libspstdc.so'
PLUGIN_SHA = '794f872cd1f05c210dc4b8c785a3a09648240f52073d6c04be8e959dabcdc371'
SUPPORT_SHA = '9aa0c1963d0560014a6437b3e865b200e7980a00ba4e3208a3fdee39db455da0'

def sha(data):
    return hashlib.sha256(data).hexdigest()

def elf_hash(value):
    h = 0
    for c in value:
        h = (h << 4) + c
        high = h & 0xf0000000
        if high:
            h ^= high >> 24
        h &= ~high
    return h & 0xffffffff

def change_name(data, offset):
    assert len(OLD) == len(NEW)
    assert data[offset:offset+len(OLD)+1] == OLD+b'\0'
    assert data.count(OLD+b'\0') == 1
    changed = bytearray(data)
    changed[offset:offset+len(NEW)] = NEW
    return changed

def patch(plugin, support):
    if sha(plugin) != PLUGIN_SHA:
        raise ValueError('Expected the exact V5 plugin')
    if sha(support) != SUPPORT_SHA:
        raise ValueError('Expected the exact donor support library')
    renamed_plugin = change_name(plugin, 2497)
    renamed_support = change_name(support, 1938)
    # This dynstr entry is also the VER_FLG_BASE version-definition name.
    # Keep its corresponding SysV ELF hash consistent with the new SONAME.
    old_hash = struct.pack('<I', elf_hash(OLD))
    new_hash = struct.pack('<I', elf_hash(NEW))
    assert support[1036:1040] == old_hash
    renamed_support[1036:1040] = new_hash
    spec = {
        'purpose': 'Load the donor support library by a unique name without replacing the phone libstdc++.so.',
        'old_dependency': OLD.decode(), 'private_dependency': NEW.decode(),
        'plugin_input_sha256': sha(plugin), 'plugin_output_sha256': sha(renamed_plugin),
        'support_input_sha256': sha(support), 'support_output_sha256': sha(renamed_support),
        'changes': [
            {'file': 'plugin', 'file_offset': 2497, 'old_hex': OLD.hex(), 'new_hex': NEW.hex(),
             'purpose': 'DT_NEEDED string'},
            {'file': 'support', 'file_offset': 1938, 'old_hex': OLD.hex(), 'new_hex': NEW.hex(),
             'purpose': 'DT_SONAME and base-version name string'},
            {'file': 'support', 'file_offset': 1036, 'old_hex': old_hash.hex(), 'new_hex': new_hash.hex(),
             'purpose': 'Base-version ELF hash for the renamed SONAME'},
        ],
        'limits': ['No code, data layout, symbol names, symbol-version names or processing parameters are changed.',
                   'The original phone libstdc++.so and libc++_shared.so are not mounted over.',
                   'Phone loading and registration of this renamed pair still require testing.'],
    }
    return bytes(renamed_plugin), bytes(renamed_support), spec

if __name__ == '__main__':
    if len(sys.argv) != 5:
        raise SystemExit('Usage: patch_private_support.py V5_PLUGIN ORIGINAL_SUPPORT OUTPUT_PLUGIN OUTPUT_SUPPORT')
    a, b, spec = patch(Path(sys.argv[1]).read_bytes(), Path(sys.argv[2]).read_bytes())
    Path(sys.argv[3]).write_bytes(a)
    Path(sys.argv[4]).write_bytes(b)
    print(json.dumps(spec, indent=2))

#!/usr/bin/env python3
"""Verify all delivered files against SHA256SUMS.txt (Python 3.9+)."""
from pathlib import Path
import hashlib

root = Path(__file__).resolve().parents[1]
errors = []
listed = set()
for line in (root / 'SHA256SUMS.txt').read_text().splitlines():
    digest, relative = line.split('  ', 1)
    listed.add(relative)
    file = (root / relative).resolve()
    if not file.is_relative_to(root) or not file.is_file():
        errors.append(relative + ': missing or invalid path')
        continue
    actual = hashlib.sha256(file.read_bytes()).hexdigest()
    if actual != digest:
        errors.append(relative + ': checksum mismatch')
actual_files = {p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file()
                and p.name != 'SHA256SUMS.txt' and '__pycache__' not in p.parts}
for name in sorted(actual_files - listed):
    errors.append(name + ': file not listed')
if errors:
    print('\n'.join(errors))
    raise SystemExit(1)
print(f'OK: {len(listed)} files verified')

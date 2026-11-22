#!/usr/bin/env python3
"""Set explicitly supplied Android property values in a copied build.prop."""
import argparse
import re
import shutil
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--file', required=True, type=Path)
p.add_argument('--set', dest='sets', action='append', default=[], metavar='KEY=VALUE', help='repeatable; no inferred defaults')
a = p.parse_args()
if not a.file.is_file(): p.error(f'not a file: {a.file}')
if not a.sets: p.error('provide at least one --set KEY=VALUE')
updates = {}
for item in a.sets:
    if '=' not in item: p.error(f'invalid assignment: {item!r}')
    key, value = item.split('=', 1)
    if not re.fullmatch(r'[A-Za-z0-9_.-]+', key) or not value or any(c in value for c in '\r\n'):
        p.error(f'invalid property assignment: {item!r}')
    updates[key] = value
text = a.file.read_text(encoding='utf-8')
lines = text.splitlines(keepends=True)
seen = set()
out = []
for line in lines:
    m = re.match(r'^\s*([A-Za-z0-9_.-]+)\s*=.*?(\r?\n)?$', line)
    if m and m.group(1) in updates:
        key = m.group(1)
        if key in seen: continue
        ending = m.group(2) or ''
        out.append(f'{key}={updates[key]}{ending}')
        seen.add(key)
    else: out.append(line)
for key, value in updates.items():
    if key not in seen: out.append(f'{key}={value}\n')
backup = a.file.with_name(a.file.name + '.bak')
if backup.exists(): p.error(f'backup already exists; refusing overwrite: {backup}')
shutil.copy2(a.file, backup)
a.file.write_text(''.join(out), encoding='utf-8')
print(f'Updated {len(updates)} property key(s); original saved at {backup}')

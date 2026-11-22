#!/usr/bin/env bash
set -euo pipefail
missing=0
for tool in python3 unzip file; do
  if command -v "$tool" >/dev/null 2>&1; then printf 'OK      %s: %s\n' "$tool" "$(command -v "$tool")"; else printf 'MISSING %s\n' "$tool"; missing=1; fi
done
for tool in lpunpack lpdump lpmake payload-dumper-go simg2img avbtool magiskboot dump.erofs mkfs.erofs mke2fs; do
  if command -v "$tool" >/dev/null 2>&1; then printf 'OK      %s: %s\n' "$tool" "$(command -v "$tool")"; else printf 'OPTIONAL %s (needed only for corresponding format/operation)\n' "$tool"; fi
done
exit "$missing"

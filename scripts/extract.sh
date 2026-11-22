#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
usage(){ echo "Usage: $0 base|donor ARCHIVE" >&2; exit 2; }
[[ $# == 2 ]] || usage
kind=$1 archive=$(realpath "$2")
case "$kind" in base) dest="$ROOT/base_a155f";; donor) dest="$ROOT/donor_emerald";; *) usage;; esac
[[ -f "$archive" ]] || { echo "Not a file: $archive" >&2; exit 1; }
stage="$ROOT/work/staging/${kind}_$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$stage/archive" "$stage/images"
printf 'Archive inventory: %s\n' "$archive"
if command -v 7z >/dev/null 2>&1; then 7z l "$archive"; 7z x -y "-o$stage/archive" "$archive" >/dev/null
elif command -v unzip >/dev/null 2>&1; then unzip -l "$archive" || true; unzip -o "$archive" -d "$stage/archive" >/dev/null || { echo 'Archive is not a ZIP; install 7z or bsdtar for TAR/MD5 archives.' >&2; exit 1; }
else echo 'Install 7z or unzip.' >&2; exit 1; fi
find "$stage/archive" -type f \( -name 'super.img' -o -name 'system.img' -o -name 'payload.bin' -o -name 'boot.img' -o -name 'vendor_boot.img' -o -name 'dtbo.img' -o -name 'vbmeta*.img' -o -name 'AP_*.tar.md5' -o -name 'CSC_*.tar.md5' \) -print
if find "$stage/archive" -type f -name super.img -print -quit | grep -q .; then
  command -v lpunpack >/dev/null || { echo 'Found super.img; install lpunpack to extract logical partitions.' >&2; exit 1; }
  super=$(find "$stage/archive" -type f -name super.img -print -quit)
  lpunpack "$super" "$stage/images"
  command -v lpdump >/dev/null && lpdump "$super" > "$ROOT/work/reports/${kind}-lpdump-$(date -u +%Y%m%dT%H%M%SZ).txt" || true
elif find "$stage/archive" -type f -name payload.bin -print -quit | grep -q .; then
  echo 'payload.bin found. Extract with a trusted payload dumper, then rerun inspection; OTA payload extraction is intentionally not guessed.'
fi
find "$stage" -type f -exec file {} \; > "$ROOT/work/reports/${kind}-file-$(date -u +%Y%m%dT%H%M%SZ).txt"
printf 'Staged archive (original untouched): %s\n' "$stage"

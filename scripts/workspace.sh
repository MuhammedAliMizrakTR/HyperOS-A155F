#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT"/{base_a155f,donor_emerald,work/{staging,reports,images},patches/overlays,out,inputs/{base,donor}}
printf 'Workspace ready at %s\n' "$ROOT"
printf 'Place exact-model firmware in inputs/base and inputs/donor; do not commit proprietary images.\n'

#!/usr/bin/env bash
# Strictly guarded wrapper: lpmake arguments are device-specific and must be reviewed.
set -euo pipefail
if [[ $# -ne 2 ]]; then echo "Usage: $0 REVIEWED_ARGS_FILE OUTPUT_SUPER.img" >&2; exit 2; fi
args_file=$(realpath "$1")
out=$(realpath -m "$2")
[[ -f "$args_file" ]] || { echo 'Argument file missing.' >&2; exit 1; }
[[ ${CONFIRM_DEVICE_SPECIFIC_LAYOUT:-} == YES ]] || { echo 'Refusing: set CONFIRM_DEVICE_SPECIFIC_LAYOUT=YES only after verifying target lpdump, exact super capacity, group limits, image paths and alignment.' >&2; exit 1; }
command -v lpmake >/dev/null || { echo 'lpmake not installed.' >&2; exit 1; }
# One argument per line; shell quoting/expansion is deliberately not evaluated.
mapfile -t args < <(grep -vE '^\s*(#|$)' "$args_file")
[[ ${#args[@]} -gt 0 ]] || { echo 'No lpmake arguments.' >&2; exit 1; }
for arg in "${args[@]}"; do
  [[ "$arg" != *'$('* && "$arg" != *'`'* ]] || { echo 'Shell substitution is not allowed in args file.' >&2; exit 1; }
done
printf 'About to run lpmake with reviewed arguments from %s\nOutput: %s\n' "$args_file" "$out"
printf 'Review lpmake --help and all values before explicitly continuing.\n'
lpmake "${args[@]}" --output "$out"

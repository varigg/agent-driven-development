#!/usr/bin/env bash
# Deterministic next-ADR number: inspect the configured ADR directory's
# immediate files and print max(present number) + 1, never the first gap.
# Why a gap is never reused, and what this does not solve: ../README.md.
#
# Usage: next-adr-number.sh   (run from the project root; takes no arguments)
# The directory comes from ADDW_ADR_DIR in docs/addw.env, read through the
# shared config reader — the reader answers from the file alone, so an
# exported value never makes a missing key look valid, which could silently
# produce 0001 in the wrong project.
# Prints one four-digit, zero-padded number on stdout and nothing else.
# Exit 0 on success; 2 for usage errors; 78 (EX_CONFIG) for a config that is
# invalid or leaves ADDW_ADR_DIR unset or empty; 66/77 for a missing or
# unreadable config (from the reader) and 66 for a configured directory that
# cannot be read.

set -euo pipefail

if [ "$#" -ne 0 ]; then
    printf 'next-adr-number.sh: usage: next-adr-number.sh (no arguments)\n' >&2
    exit 2
fi

# shellcheck source=../config/config.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/config.sh"
config_source ADDW_ADR_DIR

adr_dir="${ADDW_ADR_DIR:-}"
if [ -z "$adr_dir" ]; then
    printf 'next-adr-number.sh: ADDW_ADR_DIR is unset or empty in docs/addw.env\n' >&2
    exit 78
fi

if [ ! -d "$adr_dir" ] || [ ! -r "$adr_dir" ]; then
    printf 'next-adr-number.sh: cannot read ADR directory: %s\n' "$adr_dir" >&2
    exit 66
fi

max=0
while IFS= read -r -d '' file; do
    basename="${file##*/}"
    if [[ "$basename" =~ ^([0-9]{4})[^0-9] ]]; then
        number=$((10#${BASH_REMATCH[1]}))
        if (( number > max )); then
            max=$number
        fi
    fi
done < <(find "$adr_dir" -mindepth 1 -maxdepth 1 -type f -print0)

printf '%04d\n' "$((max + 1))"

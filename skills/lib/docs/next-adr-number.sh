#!/usr/bin/env bash
# Deterministic next-ADR number: inspect the configured ADR directory's
# immediate files and print max(present number) + 1, never the first gap.
# Why a gap is never reused, and what this does not solve: ../README.md.
#
# Usage: next-adr-number.sh [--config <file>]   (run from the repo root)
# The directory comes from ADDW_ADR_DIR in the config (default docs/addw.env).
# Prints one four-digit, zero-padded number on stdout and nothing else.
# Exit 0 on success; exit 2 for usage errors, an unreadable config, or an
# absent, empty, or unusable ADDW_ADR_DIR.

set -euo pipefail

config="docs/addw.env"
if [ "${1:-}" = "--config" ]; then
    if [ "$#" -lt 2 ]; then
        printf 'next-adr-number.sh: --config requires a file argument\n' >&2
        exit 2
    fi
    config="$2"
    shift 2
fi

if [ "$#" -ne 0 ]; then
    printf 'next-adr-number.sh: usage: next-adr-number.sh [--config <file>]\n' >&2
    exit 2
fi

if [ ! -r "$config" ]; then
    printf 'next-adr-number.sh: cannot read config: %s\n' "$config" >&2
    exit 2
fi

# Config values come from this config alone. An exported value must not make a
# missing key look valid, because that can silently produce 0001 in the wrong
# project.
unset ADDW_ADR_DIR
# shellcheck disable=SC1090
if ! . "$config"; then
    printf 'next-adr-number.sh: could not source config: %s\n' "$config" >&2
    exit 2
fi

adr_dir="${ADDW_ADR_DIR:-}"
if [ -z "$adr_dir" ]; then
    printf 'next-adr-number.sh: ADDW_ADR_DIR is unset or empty in config: %s\n' \
        "$config" >&2
    exit 2
fi

if [ ! -d "$adr_dir" ] || [ ! -r "$adr_dir" ]; then
    printf 'next-adr-number.sh: cannot read ADR directory: %s\n' "$adr_dir" >&2
    exit 2
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

#!/usr/bin/env bash
# Deterministic check of a plan's "Files to Modify/Create" section against
# the working tree: (new) paths must not exist yet, (modify)/(delete) paths
# must exist. Catches plans written against a remembered tree instead of the
# real one.
#
# Usage: check-plan-files.sh <plan-path>     (run from the repo root)
# Exit 0: all entries consistent.
# Exit 1: mismatches or unknown verbs (listed on stdout).
# Exit 3: section missing or no parseable entries.
# Exit 64: usage error.

set -euo pipefail

if [ $# -ne 1 ] || [ ! -f "${1:-}" ]; then
    echo "usage: check-plan-files.sh <plan-path>" >&2
    exit 64
fi

# Section body: lines between the heading and the next H2.
SECTION="$(tr -d '\r' < "$1" | awk '/^## Files to Modify\/Create/{f=1; next} /^## /{f=0} f')"

checked=0
mismatches=0
while IFS= read -r line; do
    # Entry shape: optional list marker, then `path` (verb) — anything after is purpose text.
    entry="$(printf '%s\n' "$line" | sed -n 's/^[[:space:]]*[0-9]*\.*[-*]*[[:space:]]*`\([^`]\{1,\}\)`[[:space:]]*(\([^)]\{1,\}\)).*/\1|\2/p')"
    [ -n "$entry" ] || continue
    path="${entry%%|*}"
    verb="$(printf '%s' "${entry#*|}" | tr '[:upper:]' '[:lower:]')"
    verb="${verb%% *}"
    checked=$((checked + 1))
    case "$verb" in
        new|create|add)
            if [ -e "$path" ]; then
                echo "MISMATCH: \`$path\` declared ($verb) but already exists"
                mismatches=$((mismatches + 1))
            fi ;;
        modify|update|edit|change|delete|remove)
            if [ ! -e "$path" ]; then
                echo "MISMATCH: \`$path\` declared ($verb) but does not exist"
                mismatches=$((mismatches + 1))
            fi ;;
        *)
            echo "UNKNOWN VERB: \`$path\` ($verb) — use new, modify, or delete"
            mismatches=$((mismatches + 1)) ;;
    esac
done <<< "$SECTION"

if [ "$checked" -eq 0 ]; then
    echo "no parseable entries found under '## Files to Modify/Create'" >&2
    echo "expected lines like: 1. \`path/to/file\` (modify) - purpose" >&2
    exit 3
fi

if [ "$mismatches" -gt 0 ]; then
    echo "$mismatches of $checked declared files mismatch the working tree"
    exit 1
fi

echo "OK: $checked declared files consistent with the working tree"

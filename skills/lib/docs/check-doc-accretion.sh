#!/usr/bin/env bash
# Deterministic accretion probe for a living design document: count the
# version references it carries now against its copy at the previous release
# tag, and name the lines counted. Why version density is the signal, which
# references legitimately stay, and why no verdict is ever a gate: ../README.md.
#
# Usage: check-doc-accretion.sh [file ...]   (default docs/ARCHITECTURE.md)
# Run from the repo root. Exit 0 on any verdict; 1 if a named file is missing.

set -euo pipefail

if [ $# -eq 0 ]; then
    FILES=(docs/ARCHITECTURE.md)
else
    FILES=("$@")
fi

VERSION_RE='v?[0-9]+\.[0-9]+\.[0-9]+'
# Dotted quads are addresses, not versions; drop them before counting.
IPV4_RE='[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'

# grep exits 1 on no match, which under pipefail would kill the run on exactly
# the clean document this check exists to produce; absorb it.
count_versions() {
    sed -E "s/$IPV4_RE//g" | { grep -oE "$VERSION_RE" || true; } | wc -l | tr -d ' '
}

PREV_TAG="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)"

for f in "${FILES[@]}"; do
    if [ ! -f "$f" ]; then
        echo "FAIL: $f not found"
        exit 1
    fi

    cur="$(count_versions < "$f")"

    # A renamed document has no counterpart under its old name at the tag;
    # say so, rather than reporting a clean delta the comparison never made.
    if [ -z "$PREV_TAG" ] || ! git cat-file -e "$PREV_TAG:$f" 2>/dev/null; then
        echo "OK: $f — $cur version references (baseline: no copy at ${PREV_TAG:-any v* tag})"
        continue
    fi

    prev="$(git show "$PREV_TAG:$f" | count_versions)"

    if [ "$cur" -gt "$prev" ]; then
        echo "ACCRETION: $f — version references $prev → $cur since $PREV_TAG."
        echo "  Justify each new one or rewrite the passage carrying it. Lines counted:"
        sed -E "s/$IPV4_RE//g" "$f" | grep -nE "$VERSION_RE" | sed 's/^/    /'
    else
        echo "OK: $f — version references $prev → $cur since $PREV_TAG"
    fi
done

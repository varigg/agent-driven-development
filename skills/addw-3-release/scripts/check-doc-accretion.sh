#!/usr/bin/env bash
# Deterministic accretion probe for a living design document. Such a document
# describes the system as it is, so a release rewrites the passages it affects
# rather than appending to them. Appending is invisible to a size threshold —
# a document stays well under budget while its overview turns into a changelog
# — so this compares against the previous release instead of against a limit.
#
# The signal is version density: how many version references the document
# carries now versus at the previous tag. A living design document needs
# almost none — the as-built statement, and versions that are live facts a
# reader must act on (a dependency pin, a hazard predating its fix). A count
# that climbs release over release is releases narrating themselves.
#
# Advisory, never a gate: legitimate growth exists, so the probe names the
# lines it counted and leaves the judgement to the reader.
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

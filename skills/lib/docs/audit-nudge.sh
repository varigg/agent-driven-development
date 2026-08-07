#!/usr/bin/env bash
# Deterministic maintenance-audit nudge: count v* release tags created since
# the newest maintenance report in docs/7-maintenance/ (every v* tag if no
# report exists yet) and compare against ADDW_AUDIT_NUDGE_N from docs/addw.env.
#
# Usage: audit-nudge.sh          (run from the repo root)
# Prints one line: "NUDGE: ..." when the threshold is reached, else "OK: ...".
# Exit 0 either way; nonzero only on real errors.

set -euo pipefail

[ -f docs/addw.env ] && source docs/addw.env
THRESHOLD="${ADDW_AUDIT_NUDGE_N:-5}"

# Reference point: last commit touching the newest report, falling back to
# file mtime for an uncommitted report. No report -> 0, so every tag counts.
SINCE=0
NEWEST_REPORT="$(ls -1 docs/7-maintenance/MAINT_*.md 2>/dev/null | sort -V | tail -1 || true)"
if [ -n "$NEWEST_REPORT" ]; then
    SINCE="$(git log -1 --format=%ct -- "$NEWEST_REPORT" 2>/dev/null || true)"
    if [ -z "$SINCE" ]; then
        SINCE="$(stat -c %Y "$NEWEST_REPORT" 2>/dev/null || stat -f %m "$NEWEST_REPORT")"
    fi
fi

COUNT=0
while read -r ts _tag; do
    if [ "$ts" -gt "$SINCE" ]; then
        COUNT=$((COUNT + 1))
    fi
done < <(git for-each-ref --format='%(creatordate:unix) %(refname:short)' 'refs/tags/v*')

LABEL="since the last maintenance report"
[ "$SINCE" -eq 0 ] && LABEL="since init (no maintenance report yet)"

if [ "$COUNT" -ge "$THRESHOLD" ]; then
    echo "NUDGE: $COUNT release tags $LABEL (threshold $THRESHOLD) — suggest running addw-4-maintain"
else
    echo "OK: $COUNT release tags $LABEL (threshold $THRESHOLD)"
fi

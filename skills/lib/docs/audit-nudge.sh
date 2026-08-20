#!/usr/bin/env bash
# Deterministic maintenance-audit nudge: count v* release tags created since
# the last maintenance audit commit (every v* tag if no audit commit exists
# yet) and compare against ADDW_AUDIT_NUDGE_N from docs/addw.env.
# Why the cadence is watched at all: ../README.md.
#
# Usage: audit-nudge.sh          (run from the repo root)
# Prints one line: "NUDGE: ..." when the threshold is reached, else "OK: ...".
# Exit 0 either way; nonzero only on real errors — an invalid docs/addw.env is
# one, and exits 78 (EX_CONFIG); a missing config just means the default.

set -euo pipefail

# shellcheck source=../config/config.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/config.sh"
config_source ADDW_AUDIT_NUDGE_N || {
    config_status=$?
    [ "$config_status" -eq 66 ] || exit "$config_status"
}
THRESHOLD="${ADDW_AUDIT_NUDGE_N:-5}"

# Reference point: the last maintenance audit commit, found by its mandated
# subject. No audit commit -> 0, so every tag counts.
SINCE="$(git log -1 --grep='^chore: maintenance audit' --format=%ct 2>/dev/null || true)"
[ -n "$SINCE" ] || SINCE=0

COUNT=0
while read -r ts _tag; do
    if [ "$ts" -gt "$SINCE" ]; then
        COUNT=$((COUNT + 1))
    fi
done < <(git for-each-ref --format='%(creatordate:unix) %(refname:short)' 'refs/tags/v*')

LABEL="since the last maintenance audit"
[ "$SINCE" -eq 0 ] && LABEL="since init (no maintenance audit yet)"

if [ "$COUNT" -ge "$THRESHOLD" ]; then
    echo "NUDGE: $COUNT release tags $LABEL (threshold $THRESHOLD) — suggest running addw-maintain"
else
    echo "OK: $COUNT release tags $LABEL (threshold $THRESHOLD)"
fi

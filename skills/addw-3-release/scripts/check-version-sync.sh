#!/usr/bin/env bash
# Deterministic pre-commit/pre-tag consistency check: the release version must
# be present in the version file, head the changelog, and not be tagged yet.
# The version lives in several places kept consistent only by attention —
# this replaces the attention.
#
# Usage: check-version-sync.sh <version>    (X.Y.Z or vX.Y.Z, from repo root)
# Exit 0: all checks pass (a README mismatch is WARN only, not a failure).
# Exit 1: a check failed. 64: usage.

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "usage: check-version-sync.sh <version>" >&2
    exit 64
fi

V="${1#v}"

[ -f docs/addw.env ] && source docs/addw.env
if [ -z "${ADDW_VERSION_FILE:-}" ] || [ ! -f "${ADDW_VERSION_FILE:-}" ]; then
    echo "FAIL: ADDW_VERSION_FILE (${ADDW_VERSION_FILE:-unset}) missing — check docs/addw.env"
    exit 1
fi

fail=0

if grep -qF "$V" "$ADDW_VERSION_FILE"; then
    echo "OK: $ADDW_VERSION_FILE contains $V"
else
    echo "FAIL: $ADDW_VERSION_FILE does not contain $V"
    fail=1
fi

FIRST_HEADING="$(grep -m1 '^## ' CHANGELOG.md 2>/dev/null || true)"
case "$FIRST_HEADING" in
    *"v$V"*)
        echo "OK: CHANGELOG.md newest entry is v$V" ;;
    *)
        echo "FAIL: CHANGELOG.md newest entry is '${FIRST_HEADING:-<none>}', expected v$V"
        fail=1 ;;
esac

if git rev-parse -q --verify "refs/tags/v$V" >/dev/null; then
    echo "FAIL: tag v$V already exists"
    fail=1
else
    echo "OK: tag v$V not yet created"
fi

if [ -f README.md ] && ! grep -qF "$V" README.md; then
    echo "WARN: README.md does not mention $V (fine only if the README carries no version)"
fi

exit "$fail"

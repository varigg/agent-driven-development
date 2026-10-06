#!/usr/bin/env bash
# Contract: skills/lib/docs/check-doc-accretion.sh — the accretion probe.
#
# The probe has no default target since ARCHITECTURE.md retired (ADR 0016):
# a run naming no file is a usage error (64, EX_USAGE), not a silent probe of
# a document the install no longer has. Named files keep the old behaviour.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
PROBE="$REPO/skills/lib/docs/check-doc-accretion.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

(
  cd "$work"
  git init -q -b main .
  printf '# Runbook\n' > runbook.md
) >/dev/null

status=0
out="$(cd "$work" && bash "$PROBE" 2>&1)" || status=$?
assert_eq 64 "$status" "no arguments: exits as a usage error"
assert_contains "$out" "Usage:" "no arguments: prints the usage line"

status=0
out="$(cd "$work" && bash "$PROBE" runbook.md 2>&1)" || status=$?
assert_eq 0 "$status" "a named file: probed as before"
assert_contains "$out" "OK: runbook.md" "a named file: reported by name"

echo "check-doc-accretion: no default target; named files probed"

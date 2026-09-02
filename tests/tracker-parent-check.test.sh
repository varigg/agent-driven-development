#!/usr/bin/env bash
# Contract: skills/lib/tracker/tracker.sh parent-check — round-trips a
# ticket's live body through parse.sh parent and fails loudly when it does
# not match the expected parent (#136).
#
# to-tickets can emit "## Parent" as a bare line rather than a list item,
# which the list-items-only parser then reads as no edge at all — invisible
# until spec-complete reports no-children on a fully decomposed spec.
# parent-check exists to catch that right after ticket creation. The gh stub
# answers the body read from a fixture file, so the assertions cover the
# wiring and the exit codes without the network.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
TRACKER="$REPO/skills/lib/tracker/tracker.sh"
FIX=fixtures/tracker

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin"
cat > "$work/bin/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"--json body"*) cat "$STUB_BODY" ;;
  *) echo "gh stub: unexpected call: $*" >&2; exit 97 ;;
esac
SH
chmod +x "$work/bin/gh"
PATH="$work/bin:$PATH"
export PATH

# --- match ---
export STUB_BODY="$REPO/tests/$FIX/parent-and-sentinel.md"
out="$(bash "$TRACKER" parent-check 5 2 2>&1)"
assert_contains "$out" "confirmed" "parent-check: matching parent is confirmed"
assert_exit 0 "parent-check: matching parent exits zero" \
  bash "$TRACKER" parent-check 5 2

# --- mismatch ---
status=0
out="$(bash "$TRACKER" parent-check 5 9 2>&1)" || status=$?
assert_eq 1 "$status" "parent-check: mismatched parent exits 1"
assert_contains "$out" "parses as #2" "parent-check: mismatch names the parsed parent"
assert_contains "$out" "expected #9" "parent-check: mismatch names the expected parent"

# --- unparseable: bare-line parent (the #136 regression) ---
export STUB_BODY="$REPO/tests/$FIX/parent-bare-line.md"
status=0
out="$(bash "$TRACKER" parent-check 5 2 2>&1)" || status=$?
assert_eq 1 "$status" "parent-check: bare-line parent exits 1"
assert_contains "$out" "no parseable parent edge" \
  "parent-check: bare-line parent is reported as unparseable"

# --- unparseable: no parent section at all ---
export STUB_BODY="$REPO/tests/$FIX/no-parent.md"
status=0
out="$(bash "$TRACKER" parent-check 5 2 2>&1)" || status=$?
assert_eq 1 "$status" "parent-check: absent parent section exits 1"
assert_contains "$out" "no parseable parent edge" \
  "parent-check: absent parent section is reported as unparseable"

# --- CLI seam hygiene ---
assert_exit 2 "parent-check: missing arguments refuse loudly" \
  bash "$TRACKER" parent-check
assert_exit 2 "parent-check: missing expected parent refuses loudly" \
  bash "$TRACKER" parent-check 5

echo "tracker-parent-check: all assertions passed"

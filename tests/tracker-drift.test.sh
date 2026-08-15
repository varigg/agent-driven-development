#!/usr/bin/env bash
# Contract: skills/lib/tracker/tracker.sh body-hash / approval-drift — the
# approval-integrity reads (#30).
#
# body-hash prints the truncated sha256 of an issue's current body, the value
# codex-spec-review records in its verdict comment. approval-drift compares
# that live hash against the last recorded "Approved-body:" marker in the
# issue's comments: no marker recorded and a match both exit 0 (a pre-feature
# approval is not drift), a mismatch exits 1. The gh stub answers the two
# reads from fixture files, so the assertions cover the wiring and the exit
# codes without the network.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
TRACKER="$REPO/skills/lib/tracker/tracker.sh"
PARSE="$REPO/skills/lib/tracker/parse.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The stub answers the body read (issue view --json body) and the comments
# read (gh api …/comments) from the files the cases below point it at.
mkdir -p "$work/bin"
cat > "$work/bin/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"--json body"*) cat "$STUB_BODY" ;;
  "api "*) cat "$STUB_COMMENTS" ;;
  *) echo "gh stub: unexpected call: $*" >&2; exit 97 ;;
esac
SH
chmod +x "$work/bin/gh"
PATH="$work/bin:$PATH"
export PATH

printf 'The spec body.\n' > "$work/body.md"
export STUB_BODY="$work/body.md"
hash="$(bash "$PARSE" body-hash "$work/body.md")"

# --- body-hash ---
assert_eq "$hash" "$(bash "$TRACKER" body-hash 5)" \
  "body-hash: hashes the live issue body"
assert_exit 2 "body-hash: missing issue number refuses loudly" \
  bash "$TRACKER" body-hash

# --- approval-drift: unrecorded ---
printf 'Nice work.\n' > "$work/comments.txt"
export STUB_COMMENTS="$work/comments.txt"
out="$(bash "$TRACKER" approval-drift 5 2>&1)"
assert_contains "$out" "no approval hash recorded" \
  "approval-drift: unrecorded approval is reported"
assert_exit 0 "approval-drift: unrecorded approval exits zero" \
  bash "$TRACKER" approval-drift 5

# --- approval-drift: match ---
printf 'Codex spec review: APPROVED after 1 round(s).\nApproved-body: %s\n' \
  "$hash" > "$work/comments.txt"
out="$(bash "$TRACKER" approval-drift 5 2>&1)"
assert_contains "$out" "match" "approval-drift: match is reported"
assert_exit 0 "approval-drift: match exits zero" \
  bash "$TRACKER" approval-drift 5

# --- approval-drift: drift ---
printf 'Codex spec review: APPROVED after 1 round(s).\nApproved-body: sha256:000000000000\n' \
  > "$work/comments.txt"
status=0
out="$(bash "$TRACKER" approval-drift 5 2>&1)" || status=$?
assert_eq 1 "$status" "approval-drift: drift exits 1"
assert_contains "$out" "sha256:000000000000" \
  "approval-drift: drift report names the approved hash"
assert_contains "$out" "$hash" \
  "approval-drift: drift report names the current hash"

# --- CLI seam hygiene ---
assert_exit 2 "approval-drift: missing issue number refuses loudly" \
  bash "$TRACKER" approval-drift

echo "tracker-drift: all assertions passed"

#!/usr/bin/env bash
# Contract: skills/lib/tracker/tracker.sh detach — the deferral seam command
# that moves a ticket out of its spec into the backlog: strips its "## Parent"
# section, swaps ready-for-agent for backlog, and comments naming the former
# parent. It refuses a closed ticket and a ticket with no parseable parent.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
TRACKER="$REPO/skills/lib/tracker/tracker.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The stub answers the state and body reads from fixture files and captures
# each --body-file it is handed (issue edit, issue comment) before the
# command's own tmpdir is cleaned up.
mkdir -p "$work/bin"
cat > "$work/bin/gh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CALLS_LOG"

case "$1 $2" in
  "issue view")
    case "$*" in
      *"--json state"*) printf '%s\n' "${STUB_STATE:-OPEN}" ;;
      *"--json body"*)  cat "$STUB_BODY" ;;
      *) echo "gh stub: unexpected issue view: $*" >&2; exit 97 ;;
    esac
    ;;
  "issue edit")
    prev=""
    for a in "$@"; do
      [ "$prev" = "--body-file" ] && cp "$a" "$EDIT_BODY_CAPTURE"
      prev=$a
    done
    ;;
  "issue comment")
    prev=""
    for a in "$@"; do
      [ "$prev" = "--body-file" ] && cp "$a" "$COMMENT_BODY_CAPTURE"
      prev=$a
    done
    ;;
  *) echo "gh stub: unexpected call: $*" >&2; exit 97 ;;
esac
SH
chmod +x "$work/bin/gh"
PATH="$work/bin:$PATH"
export PATH

CALLS_LOG="$work/calls.txt"
EDIT_BODY_CAPTURE="$work/edit-body.md"
COMMENT_BODY_CAPTURE="$work/comment-body.md"
export CALLS_LOG EDIT_BODY_CAPTURE COMMENT_BODY_CAPTURE

printf '## Parent\n\n- #144\n\n## What to build\n\nA seam command.\n\n## Acceptance criteria\n\n- [ ] a\n' \
  > "$work/body-with-parent.md"
printf '## What to build\n\nNo parent here.\n' > "$work/body-no-parent.md"

# --- refuses a closed ticket ---
: > "$CALLS_LOG"
export STUB_STATE=CLOSED STUB_BODY="$work/body-with-parent.md"
status=0
out="$(bash "$TRACKER" detach 147 2>&1)" || status=$?
assert_eq 1 "$status" "detach: a closed ticket refuses, non-zero"
assert_contains "$out" "is closed" "detach: refusal names the reason (closed)"
assert_eq 0 "$(grep -c '^issue edit ' "$CALLS_LOG" || true)" \
  "detach: a closed ticket is never edited"

# --- refuses a ticket with no parseable parent ---
: > "$CALLS_LOG"
export STUB_STATE=OPEN STUB_BODY="$work/body-no-parent.md"
status=0
out="$(bash "$TRACKER" detach 147 2>&1)" || status=$?
assert_eq 1 "$status" "detach: no parseable parent refuses, non-zero"
assert_contains "$out" "no parseable parent" \
  "detach: refusal names the reason (no parent)"
assert_eq 0 "$(grep -c '^issue edit ' "$CALLS_LOG" || true)" \
  "detach: a parentless ticket is never edited"

# --- success: body, labels, comment ---
: > "$CALLS_LOG"
export STUB_STATE=OPEN STUB_BODY="$work/body-with-parent.md"
bash "$TRACKER" detach 147 >/dev/null

assert_not_contains "$(cat "$EDIT_BODY_CAPTURE")" "## Parent" \
  "detach: the rewritten body drops the Parent section"
assert_contains "$(cat "$EDIT_BODY_CAPTURE")" "## What to build" \
  "detach: the rewritten body keeps every other section"
assert_contains "$(cat "$EDIT_BODY_CAPTURE")" "## Acceptance criteria" \
  "detach: the rewritten body keeps every other section (2)"

edit_call="$(grep '^issue edit ' "$CALLS_LOG")"
assert_contains "$edit_call" "--add-label backlog" \
  "detach: adds the backlog label"
assert_contains "$edit_call" "--remove-label ready-for-agent" \
  "detach: removes ready-for-agent"

assert_contains "$(cat "$COMMENT_BODY_CAPTURE")" "144" \
  "detach: the comment names the former parent"

# --- CLI seam hygiene ---
assert_exit 2 "detach: missing issue number refuses loudly" \
  bash "$TRACKER" detach

echo "tracker-detach: all assertions passed"

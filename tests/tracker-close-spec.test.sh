#!/usr/bin/env bash
# Contract: skills/lib/tracker/tracker.sh close-spec <n> — closes a Complete
# spec, recording each child's delivery. Refuses a partial, planned, or
# no-children spec (naming the verdict and, for partial/planned, the open
# child lines) without ever calling `gh issue close`. On a `complete` verdict
# it derives the record from child-delivery — a tagged child, an unreleased
# child, and an abandoned child — posts it as the closing comment, and closes
# the spec as completed. Like tracker-child-delivery.test.sh, the child-to-PR
# edge comes from a stubbed gh, while the tag fact comes from a real git
# fixture repository.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
TRACKER="$REPO/skills/lib/tracker/tracker.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- git fixture: one tagged child, one unreleased child --------------------

repo="$work/repo"
git init -q "$repo"
mkdir -p "$repo/docs"
printf 'ADDW_MAIN_BRANCH="master"\nADDW_ADR_DIR="docs/adr"\n' > "$repo/docs/addw.env"

commit() { # subject
  git -C "$repo" -c user.name=t -c user.email=t@t \
    commit -q --allow-empty -m "$1"
}
head_sha() { git -C "$repo" rev-parse HEAD; }

commit "chore: bootstrap"
git -C "$repo" tag v1.0.0

commit "feat: deliver child 501"
SHA_501="$(head_sha)"
git -C "$repo" tag v1.1.0

commit "feat: deliver child 502 (stays unreleased)"
SHA_502="$(head_sha)"

commit "feat: deliver child 601"
SHA_601="$(head_sha)"

export SHA_501 SHA_502 SHA_601

# --- gh stub: the issue snapshot, closedByPullRequestsReferences per
#     completed child, and issue close capture --------------------------------

issue() { # number state reason parent-or-empty labels-csv title
  jq -nc --arg n "$1" --arg s "$2" --arg r "$3" --arg p "$4" --arg l "$5" --arg t "$6" '
    {number: ($n | tonumber), title: $t, state: $s,
     stateReason: (if $r == "" then null else $r end),
     labels: ($l | if . == "" then [] else split(",") end | map({name: .})),
     assignees: [],
     body: (if $p == "" then "No parent.\n" else "## Parent\n\n- #" + $p + "\n" end)}'
}

issues="$work/issues.json"
{
  printf '[\n'
  issue 500 OPEN "" "" spec "Spec: complete"
  printf ',\n'
  issue 501 CLOSED COMPLETED 500 ready-for-agent "Tagged child"
  printf ',\n'
  issue 502 CLOSED COMPLETED 500 ready-for-agent "Unreleased child"
  printf ',\n'
  issue 503 CLOSED NOT_PLANNED 500 ready-for-agent "Abandoned child"
  printf ',\n'
  issue 600 OPEN "" "" spec "Spec: partial"
  printf ',\n'
  issue 601 CLOSED COMPLETED 600 ready-for-agent "Delivered child"
  printf ',\n'
  issue 602 OPEN "" 600 ready-for-agent "Still open child"
  printf ',\n'
  issue 700 OPEN "" "" spec "Spec: planned"
  printf ',\n'
  issue 701 OPEN "" 700 ready-for-agent "Only open child"
  printf ',\n'
  issue 800 OPEN "" "" spec "Spec: no children"
  printf '\n]\n'
} > "$issues"
export STUB_ISSUES="$issues"

mkdir -p "$work/bin"
cat > "$work/bin/gh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CALLS_LOG"
case "$*" in
  *"issue list "*"--state all"*) cat "$STUB_ISSUES" ;;
  *"number=501"*) printf '601\t%s\n' "$SHA_501" ;;
  *"number=502"*) printf '602\t%s\n' "$SHA_502" ;;
  *"number=601"*) printf '701\t%s\n' "$SHA_601" ;;
  *"issue close "*)
    prev=""
    for a in "$@"; do
      [ "$prev" = "--comment" ] && printf '%s' "$a" > "$COMMENT_CAPTURE"
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
COMMENT_CAPTURE="$work/comment.md"
export CALLS_LOG COMMENT_CAPTURE

# --- refuses a partial spec, naming the verdict and the open child ----------

: > "$CALLS_LOG"
status=0
out="$(cd "$repo" && bash "$TRACKER" close-spec 600 2>&1)" || status=$?
assert_eq 1 "$status" "close-spec: partial spec refuses, non-zero"
assert_contains "$out" "partial" "close-spec: refusal names the verdict (partial)"
assert_contains "$out" "$(printf '#602\tStill open child')" \
  "close-spec: refusal names the open child"
assert_eq 0 "$(grep -c '^issue close ' "$CALLS_LOG" || true)" \
  "close-spec: a partial spec is never closed"

# --- refuses a planned spec, naming the verdict and the open child ----------

: > "$CALLS_LOG"
status=0
out="$(cd "$repo" && bash "$TRACKER" close-spec 700 2>&1)" || status=$?
assert_eq 1 "$status" "close-spec: planned spec refuses, non-zero"
assert_contains "$out" "planned" "close-spec: refusal names the verdict (planned)"
assert_contains "$out" "$(printf '#701\tOnly open child')" \
  "close-spec: refusal names the open child"
assert_eq 0 "$(grep -c '^issue close ' "$CALLS_LOG" || true)" \
  "close-spec: a planned spec is never closed"

# --- refuses a no-children spec, naming the verdict -------------------------

: > "$CALLS_LOG"
status=0
out="$(cd "$repo" && bash "$TRACKER" close-spec 800 2>&1)" || status=$?
assert_eq 1 "$status" "close-spec: no-children spec refuses, non-zero"
assert_contains "$out" "no-children" \
  "close-spec: refusal names the verdict (no-children)"
assert_eq 0 "$(grep -c '^issue close ' "$CALLS_LOG" || true)" \
  "close-spec: a no-children spec is never closed"

# --- success: a Complete spec closes, recording a tagged, an unreleased, and
#     an abandoned child ------------------------------------------------------

: > "$CALLS_LOG"
(cd "$repo" && bash "$TRACKER" close-spec 500 >/dev/null)

close_call="$(grep '^issue close ' "$CALLS_LOG")"
assert_contains "$close_call" "500 --reason completed" \
  "close-spec: closes the spec issue as completed"

record="$(cat "$COMMENT_CAPTURE")"
assert_contains "$record" "$(printf '#501: #601 (v1.1.0)')" \
  "close-spec: tagged child names its PR and exact tag"
assert_contains "$record" "$(printf '#502: #602 (unreleased)')" \
  "close-spec: unreleased child names its PR, no tag yet"
assert_contains "$record" "$(printf '#503: abandoned')" \
  "close-spec: not-planned child lists as abandoned"

# --- a number that is not a spec-labeled issue refuses loudly ---------------

assert_exit 2 "close-spec: non-spec number refuses" \
  bash -c "cd '$repo' && bash '$TRACKER' close-spec 501"

# --- CLI hygiene --------------------------------------------------------------

assert_exit 2 "close-spec: missing spec number refuses loudly" \
  bash "$TRACKER" close-spec
assert_exit 2 "close-spec: non-numeric spec number refuses loudly" \
  bash "$TRACKER" close-spec abc

echo "tracker-close-spec: all assertions passed"

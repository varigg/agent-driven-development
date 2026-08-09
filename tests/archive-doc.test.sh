#!/usr/bin/env bash
# Contract: skills/lib/docs/archive-doc.sh — retiring a document to the tracker.
#
# Frozen before implementation. This is the critical-path floor on two counts:
# an irreversible deletion, and an outbound write to an external service. The
# script exists at all because the harness forbids writing a file's contents
# anywhere without reading them first, so an agent performing an archival
# guarantees the context contamination the rule exists to prevent — which makes
# "no document content is ever printed" a contract assertion rather than a
# nicety.
#
# The fixture is a real temporary git repository, because the SHA capture, the
# clean-tree check, the staged deletion, and the generated recovery command are
# all claims about an index and an object store rather than about strings. The
# tracker CLI is stubbed on PATH: it dispatches on the subcommand, records every
# invocation, and copies out whatever body file it is handed, so assertions are
# about outbound request shape and nothing reaches the network.
#
# Ordering is the property under test as much as any single step. Every failure
# before the issue exists must leave the tree untouched; after that point the
# residue is loud rather than prevented, since adopt-and-resume would mean
# reading archives back and the archive is write-only by construction.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
SCRIPT="$REPO/skills/lib/docs/archive-doc.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

DOC=docs/proposals/target.md
# A marker in the body, so "no document content reached the output" is an
# assertion about content rather than about a byte count.
MARKER="DOCUMENT-BODY-MARKER-b7f3"
TITLE="A proposal that stopped being true"

# --- the tracker stub -------------------------------------------------------

mkdir -p "$work/bin"
cat >"$work/bin/gh" <<'SH'
#!/usr/bin/env bash
# One record per invocation: a CALL line naming the subcommand pair, then one
# ARG line per argument, so a label containing a space stays one argument.
{
  printf 'CALL\t%s %s\n' "${1:-}" "${2:-}"
  for a in "$@"; do printf 'ARG\t%s\n' "$a"; done
} >>"$GH_LOG"

# Copy out any body file before the caller's tmpdir goes away.
prev=""
for a in "$@"; do
  [ "$prev" != "--body-file" ] || cp "$a" "$BODY_CAPTURE"
  prev="$a"
done

case "${1:-} ${2:-}" in
  "issue list")
    [ -z "${STUB_LIST_FAIL:-}" ] || { echo "gh: could not reach the tracker" >&2; exit 1; }
    cat "$STUB_ISSUES"
    ;;
  "issue create")
    [ -z "${STUB_CREATE_FAIL:-}" ] || { echo "gh: create failed" >&2; exit 1; }
    printf '%s\n' "${STUB_ISSUE_URL:-https://github.com/o/r/issues/99}"
    ;;
  "issue close")
    [ -z "${STUB_CLOSE_FAIL:-}" ] || { echo "gh: close failed" >&2; exit 1; }
    ;;
  "label create") ;;
  *) ;;
esac
SH
chmod +x "$work/bin/gh"
PATH="$work/bin:$PATH"
export PATH

GH_LOG="$work/gh.log"
BODY_CAPTURE="$work/body.md"
export GH_LOG BODY_CAPTURE

# calls — the subcommand pairs recorded, in order, one per line.
calls() { awk -F'\t' '/^CALL\t/{print $2}' "$GH_LOG"; }
# called <pair> — true when the stub saw that subcommand pair.
called() { calls | grep -Fqx -- "$1"; }
# call_args <pair> — the arguments recorded for that invocation alone. Scoped,
# because a label name appears both in its `label create` and in the `issue
# create` that carries it, and a global count would conflate the two.
call_args() {
  awk -F'\t' -v want="$1" '
    /^CALL\t/ { cur = $2; next }
    /^ARG\t/  { if (cur == want) print $2 }
  ' "$GH_LOG"
}
# arg_after <pair> <flag> — the argument following the flag in that invocation.
arg_after() {
  call_args "$1" | awk -v f="$2" 'prev==f{print;exit}{prev=$0}'
}
# arg_count <pair> <value> — how many of that invocation's arguments match.
arg_count() { call_args "$1" | grep -Fxc -- "$2" || true; }

# --- snapshot fixtures ------------------------------------------------------

# issue <number> <state> <labels-csv> <body>
issue() {
  jq -nc --arg n "$1" --arg s "$2" --arg l "$3" --arg b "$4" '
    {number: ($n | tonumber), title: ("issue " + $n), state: $s,
     stateReason: (if $s == "CLOSED" then "COMPLETED" else null end),
     labels: ($l | if . == "" then [] else split(",") end | map({name: .})),
     assignees: [], body: $b}'
}

snapshot_file() { # name <issue-json...>
  local name=$1
  shift
  local out="$work/$name.json" first=1 i
  printf '[' >"$out"
  for i in "$@"; do
    [ "$first" = 1 ] || printf ',' >>"$out"
    first=0
    printf '%s' "$i" >>"$out"
  done
  printf ']\n' >>"$out"
  printf '%s\n' "$out"
}

CLEAN_SNAPSHOT="$(snapshot_file clean \
  "$(issue 10 OPEN ready-for-agent 'An unrelated open ticket.')" \
  "$(issue 11 CLOSED ready-for-agent 'An unrelated finished ticket.')")"

# --- the repository fixture -------------------------------------------------

# make_repo <name> — a git repo holding the target document plus config.
# Echoes its path. Every case gets its own, since most of them mutate it.
make_repo() {
  local repo="$work/$1"
  mkdir -p "$repo/docs/proposals" "$repo/docs/adr"
  printf 'ADDW_MAIN_BRANCH="master"\nADDW_TRACKER_FETCH_LIMIT=50\n' \
    >"$repo/docs/addw.env"
  cat >"$repo/$DOC" <<EOF
# $TITLE

A paragraph of the design that no longer holds. $MARKER

- a list item
- another, with \`backticks\` and a "quote"
EOF
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name "Test"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "initial commit"
  printf '%s\n' "$repo"
}

# run_archive <repo> [args...] — run the script in a repo with a clean log.
# Defaults to archiving the target as a proposal with a fixed reason.
run_archive() {
  local repo=$1
  shift
  : >"$GH_LOG"
  rm -f "$BODY_CAPTURE"
  if [ "$#" -eq 0 ]; then
    set -- "$DOC" proposal "superseded by spec #37"
  fi
  (cd "$repo" && bash "$SCRIPT" "$@")
}

STUB_ISSUES="$CLEAN_SNAPSHOT"
export STUB_ISSUES

# --- the happy path ---------------------------------------------------------

repo="$(make_repo happy)"
original="$(cat "$repo/$DOC")"
out="$(run_archive "$repo" 2>&1)"

assert_contains "$out" "99" "happy: the issue number reaches the caller"
assert_not_contains "$out" "$MARKER" \
  "happy: no document content is printed — the whole reason this is a script"
assert_not_contains "$out" "$TITLE" \
  "happy: not even the document's title is printed"

[ ! -e "$repo/$DOC" ] || fail "happy: the document is removed from the worktree"
assert_eq "D $DOC" \
  "$(git -C "$repo" diff --cached --name-status | tr '\t' ' ')" \
  "happy: the deletion is left staged in the index"

# The order is the contract. The reference check comes first because it is the
# cheapest refusal; both labels exist before the issue that carries them; the
# deletion happens last, after the archive is closed, so every failure before
# the issue exists leaves the tree untouched.
assert_eq "issue list
label create
label create
issue create
issue close" "$(calls)" "happy: the tracker is addressed in the contracted order"

# --- the outbound request shape ---------------------------------------------

assert_eq "$TITLE" "$(arg_after 'issue create' --title)" \
  "shape: the title is the document's H1 with the leading hash removed"
assert_eq 2 "$(arg_count 'issue create' --label)" \
  "shape: each label is passed as its own argument"
assert_eq 1 "$(arg_count 'issue create' archived)" "shape: the state label is passed"
assert_eq 1 "$(arg_count 'issue create' proposal)" "shape: the kind label is passed"
assert_eq "completed" "$(arg_after 'issue close' --reason)" \
  "shape: the archive is closed as completed, never as not planned"
assert_eq "99" "$(call_args 'issue close' | sed -n 3p)" \
  "shape: the issue closed is the one just created"

# --- the provenance block ---------------------------------------------------

body="$(cat "$BODY_CAPTURE")"
sha="$(git -C "$repo" log -1 --format=%H -- "$DOC")"

assert_contains "$body" "$DOC" "body: provenance carries the original path"
assert_contains "$body" "$sha" "body: provenance carries the commit it was taken from"
assert_contains "$body" "superseded by spec #37" "body: provenance carries the reason"
assert_contains "$body" "$MARKER" "body: the document's bytes follow, unchanged"
assert_contains "$body" 'a list item' "body: the document arrives whole"

# --- the recovery command actually recovers ---------------------------------
#
# US10 asks for retrieval to be one copy-paste. Executing the generated command
# turns that from a claim about a string into an assertion about bytes.

recover="$(printf '%s\n' "$body" | sed -n 's/.*\(git show [^`]*\).*/\1/p' | head -1)"
[ -n "$recover" ] || fail "recover: the body carries a git show retrieval command"
(cd "$repo" && eval "$recover")
assert_eq "$original" "$(cat "$repo/$DOC")" \
  "recover: the generated command reproduces the archived bytes exactly"
git -C "$repo" checkout -q -- . 2>/dev/null || true

# --- surviving references refuse --------------------------------------------

repo="$(make_repo tree-ref)"
printf 'See [the proposal](%s) for the design.\n' "$DOC" >"$repo/docs/living.md"
git -C "$repo" add -A && git -C "$repo" commit -q -m "add a living doc pointing at it"

assert_exit 1 "tree-ref: a surviving tree reference refuses" \
  run_archive "$repo"
[ -f "$repo/$DOC" ] || fail "tree-ref: the document stays in the tree"
called "issue create" && fail "tree-ref: nothing is created when the check refuses"
err="$(run_archive "$repo" 2>&1 || true)"
assert_contains "$err" "docs/living.md" "tree-ref: the refusal names the surviving reference"

# An ADR Origin line is provenance — expected to outlive what it cites — and
# must never be the thing that blocks a deletion forever.
repo="$(make_repo origin-exempt)"
cat >"$repo/docs/adr/0001-a-decision.md" <<EOF
# ADR 0001: a decision

- **Status**: active
- **Date**: 2026-08-09
- **Origin**: $DOC
EOF
git -C "$repo" add -A && git -C "$repo" commit -q -m "add an ADR citing it as origin"

run_archive "$repo" >/dev/null 2>&1 \
  || fail "origin-exempt: an ADR Origin line does not block the deletion"
[ ! -e "$repo/$DOC" ] || fail "origin-exempt: the document is archived"

# --- tracker references: open refuses, closed reports ------------------------

repo="$(make_repo open-ref)"
STUB_ISSUES="$(snapshot_file open-ref \
  "$(issue 12 OPEN ready-for-agent "Revise $DOC to match the new design.")")"
assert_exit 1 "open-ref: an open issue referencing the path refuses" \
  run_archive "$repo"
[ -f "$repo/$DOC" ] || fail "open-ref: the document stays in the tree"
called "issue create" && fail "open-ref: nothing is created when the check refuses"
err="$(run_archive "$repo" 2>&1 || true)"
assert_contains "$err" "12" "open-ref: the refusal names the open issue"

# A closed issue's mention is history, and history must not deadlock the tool.
# The seam already drops archives, so a closed hit here is a non-archive one.
repo="$(make_repo closed-ref)"
STUB_ISSUES="$(snapshot_file closed-ref \
  "$(issue 13 CLOSED ready-for-agent "Reviewed $DOC before merging.")")"
out="$(run_archive "$repo" 2>&1)" \
  || fail "closed-ref: a closed issue's mention does not refuse"
[ ! -e "$repo/$DOC" ] || fail "closed-ref: the document is archived"
assert_contains "$out" "13" "closed-ref: the closed hit is reported rather than swallowed"

STUB_ISSUES="$CLEAN_SNAPSHOT"

# --- the seam's truncation refusal propagates -------------------------------
#
# Past the fetch limit no consumer can establish that what it did not see was
# irrelevant, so the reference check cannot vouch for itself either.

repo="$(make_repo truncated)"
printf 'ADDW_MAIN_BRANCH="master"\nADDW_TRACKER_FETCH_LIMIT=2\n' \
  >"$repo/docs/addw.env"
git -C "$repo" add -A && git -C "$repo" commit -q -m "lower the fetch limit"
STUB_ISSUES="$(snapshot_file truncating \
  "$(issue 20 OPEN '' 'one')" "$(issue 21 OPEN '' 'two')")"

assert_exit 1 "truncated: a snapshot at its limit refuses rather than archiving" \
  run_archive "$repo"
[ -f "$repo/$DOC" ] || fail "truncated: the document stays in the tree"
called "issue create" && fail "truncated: nothing is created on an unvouched snapshot"

STUB_ISSUES="$CLEAN_SNAPSHOT"

# --- a dirty target refuses --------------------------------------------------
#
# The body carries the working-tree bytes while the recovery command
# reconstructs the committed ones. Refusing is cheaper than picking a winner:
# archiving uncommitted text would make the recovery command a lie, and
# archiving the committed version would silently discard the operator's edits.

repo="$(make_repo dirty)"
printf '\nAn uncommitted afterthought.\n' >>"$repo/$DOC"
assert_exit 1 "dirty: a modified target refuses" run_archive "$repo"
[ -f "$repo/$DOC" ] || fail "dirty: the document stays in the tree"
called "issue create" && fail "dirty: nothing is created for a dirty target"

# A staged-but-uncommitted change is the same disagreement.
repo="$(make_repo staged)"
printf '\nA staged afterthought.\n' >>"$repo/$DOC"
git -C "$repo" add "$DOC"
assert_exit 1 "staged: a staged modification refuses too" run_archive "$repo"

# --- an unreachable tracker aborts before the tree is touched ---------------

# Exported rather than prefixed onto the call: `VAR=1 func` does not reliably
# reach a process the function starts, and the stub is one.
repo="$(make_repo unreachable)"
export STUB_LIST_FAIL=1
assert_exit 1 "unreachable: the archival aborts" run_archive "$repo"
[ -f "$repo/$DOC" ] || fail "unreachable: the tree is untouched"
called "issue create" && fail "unreachable: no issue is created"
unset STUB_LIST_FAIL

# --- loud residue after the irreversible step -------------------------------
#
# The issue number is printed the moment it exists, so a failure afterwards
# leaves a state the operator can finish by hand rather than one they must
# reconstruct. This stands in for adopt-and-resume, deliberately.

repo="$(make_repo residue)"
export STUB_CLOSE_FAIL=1
set +e
out="$(run_archive "$repo" 2>&1)"
status=$?
set -e
unset STUB_CLOSE_FAIL
[ "$status" -ne 0 ] || fail "residue: a failure after creation is not a success"
assert_contains "$out" "99" "residue: the issue number is emitted despite the failure"
[ -f "$repo/$DOC" ] || fail "residue: the document is left in place"
assert_eq 1 "$(calls | grep -Fxc 'issue create')" \
  "residue: nothing further is created"

# --- labels are created lazily, never provisioned ---------------------------
#
# A project that never archives must not grow labels for an artifact it does
# not have, so neither init nor doctor may know about them.

for f in "$REPO/skills/addw-init/SKILL.md" "$REPO/skills/addw-init/scripts/doctor.sh"; do
  assert_not_contains "$(cat "$f")" "archived" \
    "lazy: $(basename "$f") neither creates nor checks the archived label"
done

# --- usage errors ------------------------------------------------------------

repo="$(make_repo usage)"
assert_exit 2 "usage: too few arguments" \
  run_archive "$repo" "$DOC" proposal
assert_exit 2 "usage: an unknown kind is refused" \
  run_archive "$repo" "$DOC" blueprint "a reason"
assert_exit 2 "usage: an empty reason is refused" \
  run_archive "$repo" "$DOC" proposal ""
assert_exit 2 "usage: a path that does not exist is refused" \
  run_archive "$repo" docs/proposals/nope.md proposal "a reason"

# An untracked file has no committed version to vouch for the recovery command.
printf '# Untracked\n' >"$repo/docs/proposals/untracked.md"
assert_exit 2 "usage: an untracked path is refused" \
  run_archive "$repo" docs/proposals/untracked.md proposal "a reason"

# Without an H1 there is no title, and inventing one would put a document's
# first line somewhere no consumer expects it.
printf 'No heading here.\n' >"$repo/docs/proposals/headless.md"
git -C "$repo" add -A && git -C "$repo" commit -q -m "add a headless document"
assert_exit 2 "usage: a document with no H1 is refused" \
  run_archive "$repo" docs/proposals/headless.md proposal "a reason"

echo "archive-doc: all contract assertions passed"

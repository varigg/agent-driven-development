#!/usr/bin/env bash
# Contract: skills/lib/release/tail.sh — the re-runnable post-merge tail.
#
#   tail.sh [--spec <n>] [--changelog <path>] [--remote <name>] <version>
#
# Run from the repo root with the merge commit checked out. Four steps, in
# order, each skipping what is already done so that running the tail twice is
# harmless and an interrupted run completes on the next invocation:
#
#   1. tag      lay <version> on HEAD, unless the tag already exists
#   2. push     push the tag to <remote> (default origin), unless already there
#   3. release  publish the GitHub Release from the changelog entry for
#               <version>, unless a release for the tag already exists
#   4. spec     close the --spec issue as completed, unless already closed;
#               omitted entirely without --spec (a repository release closes
#               nothing)
#
# Each step prints exactly one line to stdout, `done: ...` or `skip: ...`, so
# the caller can see what an interrupted run had already accomplished.
#
# The release notes are the changelog entry's body: everything under the
# `## <version> ...` heading up to the next `## ` heading, with the heading
# line itself omitted (the release carries the version as its title) and
# surrounding blank lines trimmed. Taking the text from the changelog rather
# than re-deriving it is what makes the published release and the committed
# changelog the same words.
#
# Exit 0 when every step succeeded or skipped; 1 when the release must be
# created but the changelog has no entry for <version>; 2 on usage errors or
# outside a git work tree.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

TAIL="$(pwd)/../skills/lib/release/tail.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

CHANGELOG_FIXTURE='# Changelog

## v1.2.0 — 2026-08-07

### Features

- feat: add the thing

### Fixes

- fix: repair the other thing

## v1.1.0 — 2026-07-01

### Other

- docs: an older entry
'

# The body of the v1.2.0 entry: no heading line, no trailing blank line, and
# nothing from the entry that follows it.
EXPECTED_NOTES='### Features

- feat: add the thing

### Fixes

- fix: repair the other thing'

# --- fixture builders ------------------------------------------------------

# A repo with one commit, a bare origin, a changelog, and a fake gh on PATH.
# Echoes the repo path; the fake gh records every invocation in gh.log and
# keeps its own state under state/ so that creating a release or closing an
# issue is visible to a later run — which is what makes the re-run tests real
# rather than a replay of the same starting conditions.
new_release_repo() { # name
  local repo="$work/$1"
  mkdir -p "$repo" "$repo/../$1-bin" "$repo/../$1-state"
  git init -q "$repo"
  git -C "$repo" config user.email t@example.com
  git -C "$repo" config user.name Test
  printf '%s' "$CHANGELOG_FIXTURE" >"$repo/CHANGELOG.md"
  git -C "$repo" add CHANGELOG.md
  git -C "$repo" commit -qm "feat: add the thing"
  git init -q --bare "$work/$1-remote.git"
  git -C "$repo" remote add origin "$work/$1-remote.git"
  git -C "$repo" push -q origin HEAD:master
  printf '%s\n' "$repo"
}

fake_gh() { # name — write the stub and echo its bin dir
  local bin="$work/$1-bin"
  cat >"$bin/gh" <<'STUB'
#!/usr/bin/env bash
# Records what it was asked to do, then answers from GH_STATE.
set -uo pipefail
printf '%s\n' "$*" >>"$GH_LOG"

case "${1:-}/${2:-}" in
  release/view)
    [ -f "$GH_STATE/release-$3" ] || { echo "release not found" >&2; exit 1; }
    ;;
  release/create)
    tag=$3
    notes_file=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --notes-file) notes_file=$2; shift 2 ;;
        *) shift ;;
      esac
    done
    [ -z "$notes_file" ] || cp "$notes_file" "$GH_STATE/notes-$tag"
    : >"$GH_STATE/release-$tag"
    ;;
  issue/view)
    cat "$GH_STATE/issue-$3.json"
    ;;
  issue/close)
    n=$3
    # A closed issue must read back as closed, or the re-run cannot skip.
    sed 's/"state":"OPEN"/"state":"CLOSED"/' "$GH_STATE/issue-$n.json" \
      >"$GH_STATE/issue-$n.json.tmp"
    mv "$GH_STATE/issue-$n.json.tmp" "$GH_STATE/issue-$n.json"
    ;;
  *)
    echo "fake gh: unexpected invocation: $*" >&2
    exit 90
    ;;
esac
STUB
  chmod +x "$bin/gh"
  printf '%s\n' "$bin"
}

open_issue() { # state-dir number
  printf '{"number":%s,"state":"OPEN","stateReason":"","title":"Spec","labels":[],"assignees":[],"body":"","url":"u"}\n' \
    "$2" >"$1/issue-$2.json"
}

# Runs the tail in a prepared repo with the fake gh on PATH.
run_tail() { # name [args...]
  local name=$1
  shift
  ( cd "$work/$name" \
    && PATH="$work/$name-bin:$PATH" \
       GH_LOG="$work/$name-state/gh.log" \
       GH_STATE="$work/$name-state" \
       bash "$TAIL" "$@" )
}

setup() { # name — repo + stub + empty log, echoes nothing
  new_release_repo "$1" >/dev/null
  fake_gh "$1" >/dev/null
  : >"$work/$1-state/gh.log"
}

# --- usage and environment -------------------------------------------------

setup usage
assert_exit 2 "no version argument" run_tail usage
assert_exit 2 "unknown flag" run_tail usage --nope v1.2.0
assert_exit 2 "--spec without a number" run_tail usage --spec v1.2.0
assert_exit 2 "--spec with a non-numeric value" run_tail usage --spec abc v1.2.0
assert_exit 2 "extra positional argument" run_tail usage v1.2.0 v1.3.0

outside="$work/not-a-repo"
mkdir -p "$outside"
status=0
( cd "$outside" && bash "$TAIL" v1.2.0 ) >/dev/null 2>&1 || status=$?
assert_eq 2 "$status" "outside a git work tree exits 2"

# --- a full spec release, from nothing -------------------------------------

setup spec
open_issue "$work/spec-state" 2
out="$(run_tail spec --spec 2 v1.2.0)"

assert_contains "$out" "done: tagged v1.2.0" "fresh run lays the tag"
assert_contains "$out" "done: pushed v1.2.0" "fresh run pushes the tag"
assert_contains "$out" "done: published" "fresh run publishes the release"
assert_contains "$out" "done: closed spec #2" "fresh run closes the spec issue"
assert_eq 4 "$(printf '%s\n' "$out" | grep -c .)" "one line per step"

head_sha="$(git -C "$work/spec" rev-parse HEAD)"
tag_sha="$(git -C "$work/spec" rev-parse 'v1.2.0^{commit}')"
assert_eq "$head_sha" "$tag_sha" "the tag lands on the checked-out merge commit"
assert_contains "$(git -C "$work/spec" ls-remote --tags origin)" "refs/tags/v1.2.0" \
  "the tag reaches the remote"

log="$(cat "$work/spec-state/gh.log")"
assert_contains "$log" "release create v1.2.0" "the release is created for the tag"
assert_contains "$log" "issue close 2 --reason completed" \
  "the spec issue closes as completed"
assert_eq "$EXPECTED_NOTES" "$(cat "$work/spec-state/notes-v1.2.0")" \
  "the release notes are the changelog entry's body, heading omitted"

# Running it again must change nothing and say so.
out2="$(run_tail spec --spec 2 v1.2.0)"
assert_contains "$out2" "skip: tag v1.2.0" "re-run skips the tag"
assert_contains "$out2" "skip: " "re-run skips"
assert_not_contains "$out2" "done: " "a second run does nothing"
assert_eq 4 "$(printf '%s\n' "$out2" | grep -c '^skip: ')" "re-run skips all four steps"
assert_eq 1 "$(grep -c 'release create' "$work/spec-state/gh.log")" \
  "the release is created exactly once"
assert_eq 1 "$(grep -c 'issue close' "$work/spec-state/gh.log")" \
  "the spec issue is closed exactly once"

# --- a repository release closes nothing -----------------------------------

setup repo
out="$(run_tail repo v1.2.0)"
assert_eq 3 "$(printf '%s\n' "$out" | grep -c .)" "without --spec there are three steps"
assert_not_contains "$out" "spec" "no spec step without --spec"
assert_not_contains "$(cat "$work/repo-state/gh.log")" "issue close" \
  "a repository release closes no issue"

# --- interruption: each partial state resumes ------------------------------

# Interrupted after the tag was laid but before it was pushed.
setup partial1
git -C "$work/partial1" tag v1.2.0
out="$(run_tail partial1 v1.2.0)"
assert_contains "$out" "skip: tag v1.2.0" "an existing tag is left alone"
assert_contains "$out" "done: pushed v1.2.0" "the interrupted push completes"
assert_contains "$out" "done: published" "the release still publishes"

# Interrupted after the push but before the release.
setup partial2
git -C "$work/partial2" tag v1.2.0
git -C "$work/partial2" push -q origin v1.2.0
out="$(run_tail partial2 v1.2.0)"
assert_contains "$out" "skip: tag v1.2.0" "the tag is left alone"
assert_contains "$out" "skip: " "the pushed tag is left alone"
assert_not_contains "$out" "done: pushed" "an already-pushed tag is not re-pushed"
assert_contains "$out" "done: published" "the remaining step completes"

# Interrupted after the release but before the spec closed.
setup partial3
open_issue "$work/partial3-state" 7
git -C "$work/partial3" tag v1.2.0
git -C "$work/partial3" push -q origin v1.2.0
: >"$work/partial3-state/release-v1.2.0"
out="$(run_tail partial3 --spec 7 v1.2.0)"
assert_not_contains "$out" "done: published" "an existing release is not republished"
assert_contains "$out" "done: closed spec #7" "the last step completes"
assert_not_contains "$(cat "$work/partial3-state/gh.log")" "release create" \
  "no release is created when one already exists"

# An already-closed spec issue is skipped, not closed twice.
setup closed
open_issue "$work/closed-state" 5
sed 's/"state":"OPEN"/"state":"CLOSED"/' "$work/closed-state/issue-5.json" \
  >"$work/closed-state/issue-5.json.tmp"
mv "$work/closed-state/issue-5.json.tmp" "$work/closed-state/issue-5.json"
out="$(run_tail closed --spec 5 v1.2.0)"
assert_contains "$out" "skip: spec #5" "an already-closed spec issue is skipped"
assert_not_contains "$(cat "$work/closed-state/gh.log")" "issue close" \
  "a closed spec issue is not closed again"

# --- the changelog entry ---------------------------------------------------

# No entry for the version: the release cannot be published, and the failure
# is loud. The steps that already ran stay done, so a re-run after fixing the
# changelog completes the rest.
setup noentry
status=0
out="$(run_tail noentry v9.9.9 2>&1)" || status=$?
assert_eq 1 "$status" "a missing changelog entry exits 1"
assert_contains "$out" "v9.9.9" "the failure names the version it looked for"
assert_contains "$(git -C "$work/noentry" tag -l)" "v9.9.9" \
  "the steps before the failure are not rolled back"
assert_not_contains "$(cat "$work/noentry-state/gh.log")" "release create" \
  "no release is published without notes"

# An alternate changelog path is honoured.
setup altpath
mkdir -p "$work/altpath/docs"
mv "$work/altpath/CHANGELOG.md" "$work/altpath/docs/HISTORY.md"
run_tail altpath --changelog docs/HISTORY.md v1.2.0 >/dev/null
assert_eq "$EXPECTED_NOTES" "$(cat "$work/altpath-state/notes-v1.2.0")" \
  "--changelog selects the file the entry is read from"

# A bare version (no v prefix) is matched as written, since the tag namespace
# is whatever the repo's last tag established.
setup bare
sed 's/## v1\.2\.0/## 1.2.0/' "$work/bare/CHANGELOG.md" >"$work/bare/CHANGELOG.tmp"
mv "$work/bare/CHANGELOG.tmp" "$work/bare/CHANGELOG.md"
run_tail bare 1.2.0 >/dev/null
assert_eq "$EXPECTED_NOTES" "$(cat "$work/bare-state/notes-1.2.0")" \
  "a bare version matches a bare changelog heading"

# --- the remote is selectable ----------------------------------------------

setup upstream
git -C "$work/upstream" remote rename origin upstream
run_tail upstream --remote upstream v1.2.0 >/dev/null
assert_contains "$(git -C "$work/upstream" ls-remote --tags upstream)" "refs/tags/v1.2.0" \
  "--remote selects where the tag is pushed"

echo "release-tail: contract holds"

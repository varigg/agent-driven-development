#!/usr/bin/env bash
# Contract: skills/lib/release/tail.sh — the re-runnable post-merge tail.
#
#   tail.sh [--commit <sha>] <version>
#
# Run from the repo root after the release PR merged. --commit is that PR's
# merge commit and is what gets tagged; HEAD is only the default. Three fixed
# steps, each skipping what is already done so that running the tail twice is
# harmless and an interrupted run completes on the next invocation:
#
#   1. tag      lay <version> on the release commit, unless already there
#   2. push     push the tag to origin, unless it is already there
#   3. release  publish the GitHub Release from the CHANGELOG.md entry for
#               <version>, unless a release for the tag already exists
#
# Each step prints exactly one line to stdout, `done: ...` or `skip: ...`, so
# the caller can see what an interrupted run had already accomplished.
#
# Everything is validated before anything is mutated: a version with no
# changelog entry, or a tag already pointing elsewhere, fails before the first
# `git tag` rather than after the push, because a published tag is awkward to
# retract. Skipping is likewise about the step's result, not its name — a tag
# that exists but points away from the release commit, locally or on the
# remote, is refused rather than skipped, since skipping would let a tag laid
# from a stale checkout survive the re-run that exists to recover the release.
#
# The release notes come from CHANGELOG.md as it stands *in the release
# commit's tree*, never the working tree: the two differ exactly when it
# matters, and the notes must be present in the code being tagged.
#
# They are the changelog entry's body: everything under the
# `## <version> ...` heading up to the next `## ` heading, with the heading
# line itself omitted (the release carries the version as its title) and
# surrounding blank lines trimmed. Taking the text from the changelog rather
# than re-deriving it is what makes the published release and the committed
# changelog the same words.
#
# Exit 0 when every step succeeded or skipped; 1 when the changelog has no
# entry for <version>; 2 on usage errors, outside a git work tree, on an
# unresolvable --commit, or on a tag that exists but points elsewhere.
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
# The fake records every invocation in gh.log and keeps its own state under
# state/, so that publishing a release is visible to a later run — which is
# what makes the re-run tests real rather than a replay of the same starting
# conditions.
new_release_repo() { # name
  local repo="$work/$1"
  mkdir -p "$repo" "$work/$1-bin" "$work/$1-state"
  git init -q "$repo"
  git -C "$repo" config user.email t@example.com
  git -C "$repo" config user.name Test
  printf '%s' "$CHANGELOG_FIXTURE" >"$repo/CHANGELOG.md"
  git -C "$repo" add CHANGELOG.md
  git -C "$repo" commit -qm "feat: add the thing"
  git init -q --bare "$work/$1-remote.git"
  git -C "$repo" remote add origin "$work/$1-remote.git"
  git -C "$repo" push -q origin HEAD:master
}

fake_gh() { # name — write the stub into the fixture's bin dir
  cat >"$work/$1-bin/gh" <<'STUB'
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
  *)
    echo "fake gh: unexpected invocation: $*" >&2
    exit 90
    ;;
esac
STUB
  chmod +x "$work/$1-bin/gh"
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

setup() { # name — repo + stub + empty log
  new_release_repo "$1"
  fake_gh "$1"
  : >"$work/$1-state/gh.log"
}

# --- usage and environment -------------------------------------------------

setup usage
assert_exit 2 "no version argument" run_tail usage
assert_exit 2 "unknown flag" run_tail usage --nope v1.2.0
assert_exit 2 "extra positional argument" run_tail usage v1.2.0 v1.3.0
assert_exit 2 "--commit without a value" run_tail usage --commit v1.2.0 extra
assert_exit 2 "--commit that resolves to nothing" \
  run_tail usage --commit deadbeef v1.2.0

outside="$work/not-a-repo"
mkdir -p "$outside"
status=0
( cd "$outside" && bash "$TAIL" v1.2.0 ) >/dev/null 2>&1 || status=$?
assert_eq 2 "$status" "outside a git work tree exits 2"

# --- a full release, from nothing -------------------------------------------

setup full
out="$(run_tail full v1.2.0)"

assert_contains "$out" "done: tagged v1.2.0" "fresh run lays the tag"
assert_contains "$out" "done: pushed v1.2.0" "fresh run pushes the tag"
assert_contains "$out" "done: published" "fresh run publishes the release"
assert_eq 3 "$(printf '%s\n' "$out" | grep -c .)" "one line per step"

head_sha="$(git -C "$work/full" rev-parse HEAD)"
tag_sha="$(git -C "$work/full" rev-parse 'v1.2.0^{commit}')"
assert_eq "$head_sha" "$tag_sha" "the tag lands on the checked-out merge commit"
assert_contains "$(git -C "$work/full" ls-remote --tags origin)" "refs/tags/v1.2.0" \
  "the tag reaches the remote"

log="$(cat "$work/full-state/gh.log")"
assert_contains "$log" "release create v1.2.0" "the release is created for the tag"
assert_eq "$EXPECTED_NOTES" "$(cat "$work/full-state/notes-v1.2.0")" \
  "the release notes are the changelog entry's body, heading omitted"

# Running it again must change nothing and say so.
out2="$(run_tail full v1.2.0)"
assert_contains "$out2" "skip: tag v1.2.0 already at" "re-run skips the tag"
assert_contains "$out2" "skip: tag v1.2.0 already on origin" "re-run skips the push"
assert_contains "$out2" "skip: GitHub Release v1.2.0" "re-run skips the release"
assert_not_contains "$out2" "done: " "a second run does nothing"
assert_eq 3 "$(printf '%s\n' "$out2" | grep -c '^skip: ')" "re-run skips all three steps"
assert_eq 1 "$(grep -c 'release create' "$work/full-state/gh.log")" \
  "the release is created exactly once"

# --- a tag pointing elsewhere is refused, never skipped ---------------------

# The dangerous case: the tag was laid from a stale checkout. Skipping on the
# name alone would cement it and publish notes against the wrong commit.
setup stale
git -C "$work/stale" commit -q --allow-empty -m "fix: a later commit"
git -C "$work/stale" tag v1.2.0 HEAD~1
status=0
out="$(run_tail stale v1.2.0 2>&1)" || status=$?
assert_eq 2 "$status" "a tag pointing away from HEAD exits 2"
assert_contains "$out" "v1.2.0" "the refusal names the tag"
assert_not_contains "$out" "done: " "nothing proceeds past the refusal"
assert_eq "" "$(git -C "$work/stale" ls-remote --tags origin)" \
  "the misplaced tag is not pushed"
assert_not_contains "$(cat "$work/stale-state/gh.log")" "release create" \
  "no release is published against the wrong commit"

# A remote tag pointing elsewhere is refused too. The local tag can be absent
# — a fresh clone, or a bad local tag already deleted — so checking only the
# local one would still publish a release against the wrong commit.
setup staleremote
git -C "$work/staleremote" commit -q --allow-empty -m "fix: a later commit"
git -C "$work/staleremote" tag v1.2.0 HEAD~1
git -C "$work/staleremote" push -q origin v1.2.0
git -C "$work/staleremote" tag -d v1.2.0 >/dev/null
status=0
out="$(run_tail staleremote v1.2.0 2>&1)" || status=$?
assert_eq 2 "$status" "a remote tag pointing away from the release commit exits 2"
assert_contains "$out" "remote" "the refusal says which tag is wrong"
assert_eq "" "$(git -C "$work/staleremote" tag -l)" "no local tag is laid over it"
assert_not_contains "$(cat "$work/staleremote-state/gh.log")" "release create" \
  "no release is published against the wrong commit"

# --- the release commit, not whatever HEAD drifted to -----------------------

# The case --commit exists for: another PR merged after the release PR, so
# HEAD covers commits the changelog entry never mentions.
setup drifted
release_sha="$(git -C "$work/drifted" rev-parse HEAD)"
git -C "$work/drifted" commit -q --allow-empty -m "feat: merged after the release"
out="$(run_tail drifted --commit "$release_sha" v1.2.0)"
assert_contains "$out" "done: tagged v1.2.0" "the tag is laid"
assert_eq "$release_sha" "$(git -C "$work/drifted" rev-parse 'v1.2.0^{commit}')" \
  "the tag lands on the release commit, not on HEAD"

# --- interruption: each partial state resumes -------------------------------

# Interrupted after the tag was laid but before it was pushed.
setup partial1
git -C "$work/partial1" tag v1.2.0
out="$(run_tail partial1 v1.2.0)"
assert_contains "$out" "skip: tag v1.2.0 already at" "an existing tag is left alone"
assert_contains "$out" "done: pushed v1.2.0" "the interrupted push completes"
assert_contains "$out" "done: published" "the release still publishes"

# Interrupted after the push but before the release.
setup partial2
git -C "$work/partial2" tag v1.2.0
git -C "$work/partial2" push -q origin v1.2.0
out="$(run_tail partial2 v1.2.0)"
assert_contains "$out" "skip: tag v1.2.0 already at" "the tag is left alone"
assert_contains "$out" "skip: tag v1.2.0 already on origin" \
  "the pushed tag is left alone"
assert_not_contains "$out" "done: pushed" "an already-pushed tag is not re-pushed"
assert_contains "$out" "done: published" "the remaining step completes"

# --- the changelog entry -----------------------------------------------------

# No entry for the version: the release cannot be published, and the failure
# is loud. This is also what catches a version argument that disagrees with
# the one the release PR committed. The steps that already ran stay done, so a
# re-run after fixing the changelog completes the rest.
setup noentry
status=0
out="$(run_tail noentry v9.9.9 2>&1)" || status=$?
assert_eq 1 "$status" "a missing changelog entry exits 1"
assert_contains "$out" "v9.9.9" "the failure names the version it looked for"
assert_eq "" "$(git -C "$work/noentry" tag -l)" \
  "a version the changelog does not know lays no tag"
assert_eq "" "$(git -C "$work/noentry" ls-remote --tags origin)" \
  "and pushes nothing"
assert_eq "" "$(cat "$work/noentry-state/gh.log")" \
  "and reaches no external service at all"

# The entry is read from the release commit's tree, not the working tree. A
# --commit predating the release therefore fails even while the checked-out
# tree carries the entry — otherwise the release would be published against
# code that does not contain its own notes.
setup untracked
before_sha="$(git -C "$work/untracked" rev-parse HEAD)"
printf '\n## v2.0.0 — 2026-09-01\n\n### Features\n\n- feat: later work\n' \
  >>"$work/untracked/CHANGELOG.md"
git -C "$work/untracked" commit -qam "chore(release): v2.0.0"
status=0
out="$(run_tail untracked --commit "$before_sha" v2.0.0 2>&1)" || status=$?
assert_eq 1 "$status" "an entry absent from the release commit exits 1"
assert_eq "" "$(git -C "$work/untracked" tag -l)" "and lays no tag"
assert_eq "" "$(cat "$work/untracked-state/gh.log")" "and publishes nothing"

# An uncommitted entry is the same failure: the working tree is never the
# source of the notes.
setup dirty
printf '\n## v3.0.0 — 2026-09-01\n\n### Features\n\n- feat: uncommitted\n' \
  >>"$work/dirty/CHANGELOG.md"
status=0
run_tail dirty v3.0.0 >/dev/null 2>&1 || status=$?
assert_eq 1 "$status" "an uncommitted changelog entry exits 1"
assert_eq "" "$(git -C "$work/dirty" tag -l)" "and lays no tag"

# A bare version (no v prefix) is matched as written, since the tag namespace
# is whatever the repo's last tag established.
setup bare
sed 's/## v1\.2\.0/## 1.2.0/' "$work/bare/CHANGELOG.md" >"$work/bare/CHANGELOG.tmp"
mv "$work/bare/CHANGELOG.tmp" "$work/bare/CHANGELOG.md"
git -C "$work/bare" commit -qam "chore(release): 1.2.0"
run_tail bare 1.2.0 >/dev/null
assert_eq "$EXPECTED_NOTES" "$(cat "$work/bare-state/notes-1.2.0")" \
  "a bare version matches a bare changelog heading"

echo "release-tail: contract holds"

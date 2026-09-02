#!/usr/bin/env bash
# Contract: skills/lib/worktree/{create,find}.sh — the worktree-per-ticket
# mechanism addw-implement Step 3 and Mode A drive (ADR 0010).
#
#   create.sh <main-branch> <new-branch> <worktree-path>
#     Fetches origin/<main-branch> and branches <new-branch> off it into a
#     new worktree, never touching the caller's own checked-out branch or
#     index. Recreates a symlinked .claude/skills (this repo's own dogfood
#     setup) inside the new worktree, pointed at its own tracked skills/
#     copy — never the original symlink's raw target, so an absolute-path
#     original never leaves the worktree reading someone else's checkout.
#
#   find.sh <branch>
#     Prints the worktree path already holding <branch> checked out, or
#     nothing if there isn't one.
#
# Everything runs offline against real local git repositories in a temp dir:
# a bare "origin" and a clone, exactly as the skill's own commands would see
# them.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
CREATE="$REPO/skills/lib/worktree/create.sh"
FIND="$REPO/skills/lib/worktree/find.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- fixture: a bare origin and a clone with one commit on main -----------
git init -q --bare "$work/origin.git"

git init -q -b main "$work/clone"
git -C "$work/clone" config user.email fixture@example.com
git -C "$work/clone" config user.name Fixture
printf 'hello\n' > "$work/clone/README.md"
git -C "$work/clone" add README.md
git -C "$work/clone" commit -qm "chore: fixture"
git -C "$work/clone" remote add origin "$work/origin.git"
git -C "$work/clone" push -q origin main

# --- create.sh: the plain case ---------------------------------------------

wt="$work/wt-plain"
( cd "$work/clone" && "$CREATE" main feat/1-plain "$wt" ) >/dev/null 2>&1

[ -f "$wt/README.md" ] || fail "create: the worktree checks out the repo's tracked files"
assert_eq "feat/1-plain" "$(git -C "$wt" branch --show-current)" \
  "create: the worktree is on the new branch"
assert_eq "$(git -C "$work/clone" rev-parse main)" "$(git -C "$wt" rev-parse HEAD)" \
  "create: the new branch starts at origin/main"
[ ! -e "$wt/.claude" ] || fail "create: no .claude/skills symlink to recreate is a no-op"

# The origin checkout's own branch and index are untouched — create.sh never
# ran `git checkout`/`git pull` there.
assert_eq "main" "$(git -C "$work/clone" branch --show-current)" \
  "create: the invoking checkout's own branch is untouched"

# --- create.sh: recreates a symlinked .claude/skills ------------------------

mkdir -p "$work/clone/skills"
printf 'stub\n' > "$work/clone/skills/marker.txt"
mkdir -p "$work/clone/.claude"
ln -s ../skills "$work/clone/.claude/skills"
git -C "$work/clone" add skills/marker.txt
git -C "$work/clone" commit -qm "chore: add skills dir"
git -C "$work/clone" push -q origin main

wt2="$work/wt-symlink"
( cd "$work/clone" && "$CREATE" main feat/2-symlink "$wt2" ) >/dev/null 2>&1

[ -L "$wt2/.claude/skills" ] || fail "create: recreates .claude/skills as a symlink"
assert_eq "../skills" "$(readlink "$wt2/.claude/skills")" \
  "create: the recreated symlink is relative, not a copy of the original target"
[ -f "$wt2/.claude/skills/marker.txt" ] || \
  fail "create: the symlink resolves to the new worktree's own tracked skills/"

# An absolute-path original must not leak into the new worktree — the fix
# always recreates the canonical relative form.
rm "$work/clone/.claude/skills"
ln -s "$work/clone/skills" "$work/clone/.claude/skills"
wt3="$work/wt-abssymlink"
( cd "$work/clone" && "$CREATE" main feat/3-abs "$wt3" ) >/dev/null 2>&1
assert_eq "../skills" "$(readlink "$wt3/.claude/skills")" \
  "create: an absolute-path original symlink is not copied verbatim"
assert_not_contains "$(readlink "$wt3/.claude/skills")" "$work/clone" \
  "create: the recreated symlink never points back at the source checkout"

# --- create.sh: usage and propagated failure --------------------------------

assert_exit 2 "create: usage error on wrong argument count" "$CREATE" main only-one-arg

( cd "$work/clone" && "$CREATE" main feat/1-plain "$work/wt-dupe" ) >/dev/null 2>&1 \
  && fail "create: a branch that already exists is refused, not silently reused"

# --- find.sh -----------------------------------------------------------------

# find.sh reads git worktree state, which is shared repo-wide — run it from
# any working copy of the same repository, here the clone.
found="$(cd "$work/clone" && "$FIND" feat/1-plain)"
assert_eq "$wt" "$found" "find: locates the worktree already holding the branch"

found_none="$(cd "$work/clone" && "$FIND" no-such-branch)"
assert_eq "" "$found_none" "find: prints nothing for a branch with no worktree"

assert_exit 2 "find: usage error on wrong argument count" "$FIND"

echo "worktree: all contract assertions passed"

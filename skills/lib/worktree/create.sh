#!/usr/bin/env bash
# Deterministic worktree creation for addw-implement Step 3 (ADR 0004,
# ADR 0010): fetches the main branch's remote-tracking ref and branches a new
# ticket worktree off it, never touching the caller's own checkout — a
# concurrent session running this at the same time never contends with it,
# because a plain `git fetch` touches no working tree or index, unlike
# `git checkout && git pull` in the shared clone.
#
# Usage: create.sh <main-branch> <new-branch> <worktree-path>
#   <main-branch>    bare branch name (e.g. main) — origin/<main-branch> is
#                     fetched and used as the new branch's start point
#   <new-branch>     the ticket branch to create (e.g. feat/138-slug)
#   <worktree-path>  where to create the worktree; must not already exist
#
# Run from the repo's main checkout, or any other worktree of the same
# repository — git worktree state is shared repository-wide either way. If
# the invoking checkout's .claude/skills is a symlink (this repo's own
# dogfood setup — see docs/agents/domain.md), the same relationship is
# recreated inside the new worktree, pointed at its own tracked skills/ copy
# rather than the original symlink's raw target, so an absolute-path original
# never leaves the new worktree reading someone else's checkout. A real
# install's ordinary tracked .claude/skills is left alone — git worktree add
# already checked it out.
#
# Exit 0 on success. A nonzero exit from `git fetch` or `git worktree add`
# propagates as-is (a branch that already exists, a dirty existing path, a
# network failure). 2 for usage errors.
set -euo pipefail

if [ "$#" -ne 3 ]; then
    printf 'create.sh: usage: create.sh <main-branch> <new-branch> <worktree-path>\n' >&2
    exit 2
fi

main_branch=$1
new_branch=$2
wt_path=$3

git fetch origin "$main_branch"
git worktree add -b "$new_branch" "$wt_path" "origin/$main_branch"

if [ -L .claude/skills ]; then
    mkdir -p "$wt_path/.claude"
    ln -s ../skills "$wt_path/.claude/skills"
fi

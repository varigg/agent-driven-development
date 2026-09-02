#!/usr/bin/env bash
# Locate the worktree, if any, that already has a branch checked out — used
# by addw-implement Mode A (ADR 0010) so a review-comments resume enters the
# ticket's existing worktree instead of checking the branch out a second
# time, which git refuses (a branch cannot be checked out in two worktrees at
# once).
#
# Usage: find.sh <branch>
# Prints the worktree's path on stdout if <branch> is checked out somewhere
# in this repository; prints nothing if it is not checked out anywhere — the
# caller's fallback is then a plain checkout in the current working copy.
#
# Exit 0 on a successful `git worktree list`, whether or not a match was
# found — an empty result is not a failure, it means worktree mode was off or
# never ran for this ticket. 2 for usage errors; a nonzero git exit code
# propagates on failure (e.g. run outside a git repository).
set -euo pipefail

if [ "$#" -ne 1 ]; then
    printf 'find.sh: usage: find.sh <branch>\n' >&2
    exit 2
fi

branch=$1
# The path on a `worktree ` line is everything after the 9-character prefix,
# not just its first field — ADDW_WORKTREE_ROOT or the repo basename may
# contain spaces, and splitting on whitespace like the `branch` line below
# would silently truncate such a path.
git worktree list --porcelain | awk -v want="refs/heads/$branch" '
    /^worktree / { path = substr($0, 10) }
    $1 == "branch" && $2 == want { print path }
'

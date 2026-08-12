#!/usr/bin/env bash
# Contract: skills/lib/docs/audit-nudge.sh — the maintenance-audit cadence check.
#
#   audit-nudge.sh          (run from the repo root)
#
# Counts v* release tags created since the last maintenance audit and compares
# against ADDW_AUDIT_NUDGE_N (default 5). The reference point is the newest
# commit whose subject is the mandated audit subject — `chore: maintenance
# audit <date>` — because the audit record IS the audit commit's message; no
# report file is read, and a leftover docs/7-maintenance/ tree is invisible to
# it. No audit commit means SINCE=0 and every tag counts ("since init").
# Exit 0 whether it prints NUDGE or OK; the line is advice, never a gate.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
SCRIPT="$REPO/skills/lib/docs/audit-nudge.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Fixture repos need deterministic ordering between tag and audit timestamps,
# so every commit pins its committer date; a lightweight tag's creatordate is
# its commit's committer date, which keeps the two clocks one clock.
make_repo() { # name -> dir on stdout
  local dir="$work/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  printf '%s\n' "$dir"
}

commit_at() { # dir unix-seconds subject
  GIT_COMMITTER_DATE="@$2 +0000" GIT_AUTHOR_DATE="@$2 +0000" \
    git -C "$1" -c user.name=t -c user.email=t@t \
    commit -q --allow-empty -m "$3"
}

tag_at() { # dir unix-seconds name
  commit_at "$1" "$2" "release $3"
  git -C "$1" tag "$3"
}

run_in() { # dir
  (cd "$1" && bash "$SCRIPT")
}

# --- no audit commit: every tag counts, label says since init ---------------

d="$(make_repo init)"
commit_at "$d" 1000 "chore: init"
tag_at "$d" 2000 v0.1.0
tag_at "$d" 3000 v0.2.0
out="$(run_in "$d")"
assert_contains "$out" "OK: 2 release tags since init (no maintenance audit yet)" \
  "init: no audit commit counts every tag, under threshold"

# --- the audit commit is the reference point --------------------------------

d="$(make_repo reset)"
commit_at "$d" 1000 "chore: init"
tag_at "$d" 2000 v0.1.0
tag_at "$d" 3000 v0.2.0
commit_at "$d" 4000 "chore: maintenance audit 2026-01-01"
tag_at "$d" 5000 v0.3.0
out="$(run_in "$d")"
assert_contains "$out" "OK: 1 release tags since the last maintenance audit" \
  "reset: only tags after the audit commit count"

# --- the newest audit commit wins, not the first ----------------------------

commit_at "$d" 6000 "chore: maintenance audit 2026-02-01"
out="$(run_in "$d")"
assert_contains "$out" "OK: 0 release tags since the last maintenance audit" \
  "newest: a later audit commit resets the count again"

# --- threshold comes from docs/addw.env -------------------------------------

d="$(make_repo threshold)"
mkdir -p "$d/docs"
printf 'ADDW_AUDIT_NUDGE_N=1\n' >"$d/docs/addw.env"
commit_at "$d" 1000 "chore: maintenance audit 2026-01-01"
tag_at "$d" 2000 v0.1.0
out="$(run_in "$d")"
assert_contains "$out" "NUDGE: 1 release tags since the last maintenance audit (threshold 1)" \
  "threshold: ADDW_AUDIT_NUDGE_N=1 nudges on the first post-audit tag"

# --- a mention of the subject mid-line is not an audit commit ---------------

d="$(make_repo mention)"
commit_at "$d" 1000 "docs: describe the chore: maintenance audit cadence"
tag_at "$d" 2000 v0.1.0
out="$(run_in "$d")"
assert_contains "$out" "since init (no maintenance audit yet)" \
  "mention: the audit subject must start the line, not merely appear"

# --- a leftover report file is not a reference point ------------------------
# The retired document class must be invisible: an un-deleted
# docs/7-maintenance/ tree on an upgraded install never masks a missing
# audit commit.

d="$(make_repo leftover)"
mkdir -p "$d/docs/7-maintenance"
printf '# audit\n' >"$d/docs/7-maintenance/MAINT_2026-01-01.md"
commit_at "$d" 1000 "docs: old maintenance report"
tag_at "$d" 2000 v0.1.0
out="$(run_in "$d")"
assert_contains "$out" "since init (no maintenance audit yet)" \
  "leftover: a surviving MAINT_*.md file does not date the last audit"

echo "audit-nudge: all assertions passed"

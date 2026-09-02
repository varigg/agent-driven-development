#!/usr/bin/env bash
# Contract: skills/lib/release/derive.sh — mechanical release derivations.
#
#   derive.sh <changelog|version|range>
#
# All three read the same commit range of the repository at the current
# working directory: every commit since the last tag reachable from HEAD
# (git describe --tags --abbrev=0), or the whole history when no tag exists.
# A commit qualifies iff its subject parses as a conventional commit
# (`type(scope)?!?: description`) and is not a release commit (type
# `release`, or type `chore` with scope `release` — excluded). Unclassifiable
# subjects are warned and listed on stderr, never silently dropped.
#
#   range      stdout is that same range as `<last-tag>..HEAD`, or `HEAD`
#              with no tag — for another script to reuse without recomputing
#              which tag bounds it. Unlike version/changelog it never
#              gathers commit subjects, so an empty range still exits zero.
#
#   version    stdout is exactly two lines:
#                bump: <major|minor|patch>
#                version: <next-version>
#              A `!` subject → major, else any `feat` → minor, else patch.
#              The next version applies the bump to the last tag, preserving
#              its `v`-or-bare prefix; with no tag the base is 0.0.0 with a
#              `v` prefix. A last tag that is not X.Y.Z/vX.Y.Z exits 2.
#
#   changelog  stdout is one Markdown entry: `## <version> — <YYYY-MM-DD>`
#              (the same derived version, today's date), then Breaking /
#              Features / Fixes / Other sections as `### <name>` with one
#              `- <subject verbatim>` bullet per qualifying commit in git-log
#              order (newest first); empty sections are omitted.
#
# Exit 0 on success; 1 when no commit in the range qualifies (stop and ask);
# 2 on usage errors, outside a git work tree, or an unparseable last tag.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

DERIVE="$(pwd)/../skills/lib/release/derive.sh"
TODAY="$(date +%F)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- fixture builders ------------------------------------------------------

new_repo() { # dir — init an empty repo
  git init -q "$1"
}

c() { # dir subject — append an (empty) commit
  git -C "$1" -c user.name=t -c user.email=t@t \
    commit -q --allow-empty -m "$2"
}

# Mixed post-tag history: squash-style, rebase-merged, and hotfix commits,
# plus a release commit and an unclassifiable subject.
mixed="$work/mixed"
new_repo "$mixed"
c "$mixed" "chore: bootstrap"
git -C "$mixed" tag v1.2.3
c "$mixed" "release: v1.2.3"
c "$mixed" "feat(gate): add gate runner (#16)"
c "$mixed" "refactor(tracker): split resolve helpers"
c "$mixed" "test(tracker): freeze resolve contract"
c "$mixed" "fix: repair frontier query (#19)"
c "$mixed" "WIP try things"

# --- changelog: mixed history, frozen full output --------------------------

expected="## v1.3.0 — $TODAY

### Features
- feat(gate): add gate runner (#16)

### Fixes
- fix: repair frontier query (#19)

### Other
- test(tracker): freeze resolve contract
- refactor(tracker): split resolve helpers"

out="$(cd "$mixed" && bash "$DERIVE" changelog 2>/dev/null)"
assert_eq "$expected" "$out" \
  "mixed: changelog projects the exact entry (sections, order, no empties)"

err="$(cd "$mixed" && bash "$DERIVE" changelog 2>&1 >/dev/null)"
assert_contains "$err" "WIP try things" \
  "mixed: unclassifiable subject is listed on stderr"
assert_not_contains "$out" "WIP try things" \
  "mixed: unclassifiable subject stays out of the entry"
assert_not_contains "$out" "release: v1.2.3" \
  "mixed: release commit is excluded from the entry"
assert_not_contains "$out" "chore: bootstrap" \
  "mixed: commits at or before the last tag are out of range"
assert_exit 0 "mixed: changelog exits zero" \
  bash -c "cd '$mixed' && bash '$DERIVE' changelog"

# --- version: mixed history → feat wins, minor over v1.2.3 -----------------

out="$(cd "$mixed" && bash "$DERIVE" version 2>/dev/null)"
assert_eq "bump: minor
version: v1.3.0" "$out" "mixed: feat present → minor bump over the last tag"

# --- version: fixes and chores only → patch; bare-prefix tag preserved -----

patchy="$work/patchy"
new_repo "$patchy"
c "$patchy" "chore: bootstrap"
git -C "$patchy" tag 2.0.0
c "$patchy" "fix: close the gap"
c "$patchy" "docs: explain the gap"
out="$(cd "$patchy" && bash "$DERIVE" version 2>/dev/null)"
assert_eq "bump: patch
version: 2.0.1" "$out" \
  "patchy: no feat, no bang → patch; bare tag prefix preserved"

# --- version: breaking marker → major, resets minor and patch --------------

breaking="$work/breaking"
new_repo "$breaking"
c "$breaking" "chore: bootstrap"
git -C "$breaking" tag v1.2.3
c "$breaking" "feat(api)!: drop legacy flags"
out="$(cd "$breaking" && bash "$DERIVE" version 2>/dev/null)"
assert_eq "bump: major
version: v2.0.0" "$out" "breaking: bang subject → major bump"

# --- no prior tag: whole history projected, version from 0.0.0 -------------

untagged="$work/untagged"
new_repo "$untagged"
c "$untagged" "feat: first feature"
c "$untagged" "docs: add a readme"
out="$(cd "$untagged" && bash "$DERIVE" changelog 2>/dev/null)"
assert_eq "## v0.1.0 — $TODAY

### Features
- feat: first feature

### Other
- docs: add a readme" "$out" \
  "untagged: whole history projected, version applies bump to 0.0.0"
out="$(cd "$untagged" && bash "$DERIVE" version 2>/dev/null)"
assert_eq "bump: minor
version: v0.1.0" "$out" "untagged: version baseline is v0.0.0"

# --- nothing qualifying: stop and ask --------------------------------------

noise="$work/noise"
new_repo "$noise"
c "$noise" "chore: bootstrap"
git -C "$noise" tag v1.0.0
c "$noise" "WIP flailing"
assert_exit 1 "noise: only unclassifiable commits → exit 1" \
  bash -c "cd '$noise' && bash '$DERIVE' changelog"
assert_exit 1 "noise: version stops on the same range" \
  bash -c "cd '$noise' && bash '$DERIVE' version"
err="$(cd "$noise" && bash "$DERIVE" changelog 2>&1 >/dev/null)" || true
assert_contains "$err" "WIP flailing" \
  "noise: the unclassifiable subject is still listed on stderr"

quiet="$work/quiet"
new_repo "$quiet"
c "$quiet" "chore: bootstrap"
git -C "$quiet" tag v1.0.0
assert_exit 1 "quiet: empty range → exit 1" \
  bash -c "cd '$quiet' && bash '$DERIVE' changelog"

releases_only="$work/releases-only"
new_repo "$releases_only"
c "$releases_only" "chore: bootstrap"
git -C "$releases_only" tag v1.0.0
c "$releases_only" "release: v1.1.0"
c "$releases_only" "chore(release): v1.1.0"
assert_exit 1 "releases-only: release commits alone do not qualify" \
  bash -c "cd '$releases_only' && bash '$DERIVE' changelog"

# --- usage and environment errors ------------------------------------------

badtag="$work/badtag"
new_repo "$badtag"
c "$badtag" "chore: bootstrap"
git -C "$badtag" tag snapshot-1
c "$badtag" "feat: something"
assert_exit 2 "badtag: unparseable last tag → exit 2" \
  bash -c "cd '$badtag' && bash '$DERIVE' version"

badtag_noise="$work/badtag-noise"
new_repo "$badtag_noise"
c "$badtag_noise" "chore: bootstrap"
git -C "$badtag_noise" tag snapshot-1
c "$badtag_noise" "WIP only noise here"
assert_exit 2 "badtag-noise: tag validation precedes the nothing-qualifies check" \
  bash -c "cd '$badtag_noise' && bash '$DERIVE' changelog"

shallow="$work/shallow"
git clone -q --depth 1 "file://$mixed" "$shallow" 2>/dev/null
assert_exit 2 "shallow: truncated history is refused, never derived from" \
  bash -c "cd '$shallow' && bash '$DERIVE' version"

assert_exit 2 "usage: missing subcommand → exit 2" \
  bash -c "cd '$mixed' && bash '$DERIVE'"
assert_exit 2 "usage: unknown subcommand → exit 2" \
  bash -c "cd '$mixed' && bash '$DERIVE' bump"

# --- range: the same tag boundary version/changelog derive from ------------

out="$(cd "$mixed" && bash "$DERIVE" range 2>/dev/null)"
assert_eq "v1.2.3..HEAD" "$out" "range: bounded by the last tag"
out="$(cd "$untagged" && bash "$DERIVE" range 2>/dev/null)"
assert_eq "HEAD" "$out" "range: no tag → the whole history"
assert_exit 2 "range: unparseable last tag → exit 2, same as version/changelog" \
  bash -c "cd '$badtag' && bash '$DERIVE' range"
# range never gathers commit subjects, so a range with nothing qualifying
# (or nothing at all) still prints rather than exiting 1 like changelog does.
assert_exit 0 "range: an empty range still exits zero" \
  bash -c "cd '$quiet' && bash '$DERIVE' range"

plain="$work/plain"
mkdir "$plain"
assert_exit 2 "plain: outside a git work tree → exit 2" \
  bash -c "cd '$plain' && GIT_CEILING_DIRECTORIES='$work' bash '$DERIVE' changelog"

# --- prepend: the same entry, written rather than printed ------------------

# The changelog is write-only for the workflow, so the entry is placed by the
# script. Nothing else may author it, and nothing has to read the file to
# place it.
#
# An existing changelog: the entry lands above the newest entry and below the
# title, leaving every older entry untouched.
existing="$work/prepend-existing"
new_repo "$existing"
c "$existing" "chore: bootstrap"
git -C "$existing" tag v1.2.3
c "$existing" "feat(gate): add gate runner (#16)"
printf '# Changelog\n\n## v1.2.3 — 2026-01-01\n\n### Other\n- chore: bootstrap\n' \
  >"$existing/CHANGELOG.md"
out="$(cd "$existing" && bash "$DERIVE" prepend)"
assert_contains "$out" "done: prepended the v1.3.0 entry" "prepend reports the write"
got="$(cat "$existing/CHANGELOG.md")"
assert_eq "# Changelog

## v1.3.0 — $TODAY

### Features
- feat(gate): add gate runner (#16)

## v1.2.3 — 2026-01-01

### Other
- chore: bootstrap" "$got" "prepend: newest entry first, older entries intact"

# Re-running is a skip, not a second copy: a release branch rebuilt after a
# false start must not double-write.
out="$(cd "$existing" && bash "$DERIVE" prepend)"
assert_contains "$out" "skip: " "prepend: an entry already present is skipped"
assert_eq 1 "$(grep -c '^## v1.3.0' "$existing/CHANGELOG.md")" \
  "prepend: the entry is written exactly once"

# No changelog yet: the file is created with a title.
fresh="$work/prepend-fresh"
new_repo "$fresh"
c "$fresh" "chore: bootstrap"
git -C "$fresh" tag v1.2.3
c "$fresh" "fix: repair the thing"
(cd "$fresh" && bash "$DERIVE" prepend >/dev/null)
got="$(cat "$fresh/CHANGELOG.md")"
assert_eq "# Changelog

## v1.2.4 — $TODAY

### Fixes
- fix: repair the thing" "$got" "prepend: a missing changelog is created with a title"

# The written entry and the printed one are the same text, so the release PR
# body and the committed file can never disagree.
assert_contains "$(cat "$fresh/CHANGELOG.md")" \
  "$(cd "$fresh" && bash "$DERIVE" changelog)" \
  "prepend writes exactly what changelog prints"

# A range with nothing qualifying refuses before touching the file.
assert_exit 1 "prepend: empty range → exit 1" \
  bash -c "cd '$quiet' && bash '$DERIVE' prepend"
[ -f "$quiet/CHANGELOG.md" ] && fail "prepend: refused run must not create the file"

echo "release-derive: all assertions passed"

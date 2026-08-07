#!/usr/bin/env bash
# Mechanical release derivations over the repository at the current working
# directory. One commit-collection pass feeds both subcommands, so the
# changelog and the version can never disagree about which commits count.
#
# Usage: derive.sh <changelog|version>
#
# Range: every commit since the last tag reachable from HEAD (git describe
# --tags --abbrev=0), or the whole history when no tag exists. A commit
# qualifies iff its subject parses as a conventional commit
# (`type(scope)?!?: description`) and is not a release commit — type
# `release`, or type `chore` with scope `release` (the subjects addw-release
# gives release PRs). Unclassifiable subjects are warned and listed on
# stderr, never silently dropped.
#
#   version    stdout: `bump: <major|minor|patch>` then `version: <next>`.
#              Any `!` subject → major, else any `feat` → minor, else patch;
#              the bump applies to the last tag, preserving its `v`-or-bare
#              prefix (base v0.0.0 when no tag exists).
#   changelog  stdout: `## <version> — <YYYY-MM-DD>` (the same derived
#              version), then Breaking / Features / Fixes / Other sections
#              with one `- <subject verbatim>` bullet per qualifying commit
#              in git-log order; empty sections are omitted.
#
# Exit 0 on success; 1 when no commit in the range qualifies (stop and ask
# the human); 2 on usage errors, outside a git work tree, or a last tag that
# is not X.Y.Z / vX.Y.Z.
set -euo pipefail

sub="${1:-}"
if [ "$sub" != "changelog" ] && [ "$sub" != "version" ]; then
  printf 'derive.sh: usage: derive.sh <changelog|version>\n' >&2
  exit 2
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'derive.sh: not inside a git work tree\n' >&2
  exit 2
fi

last_tag="$(git describe --tags --abbrev=0 2>/dev/null || true)"
if [ -n "$last_tag" ]; then
  range="$last_tag..HEAD"
else
  range="HEAD"
fi

conventional_re='^([A-Za-z]+)(\(([^)]*)\))?(!?): .+$'
breaking=() features=() fixes=() other=() unclassifiable=()
have_breaking=0 have_feat=0 qualifying=0
while IFS= read -r subject; do
  if [[ "$subject" =~ $conventional_re ]]; then
    type="${BASH_REMATCH[1]}"
    scope="${BASH_REMATCH[3]}"
    bang="${BASH_REMATCH[4]}"
    if [ "$type" = "release" ] ||
      { [ "$type" = "chore" ] && [ "$scope" = "release" ]; }; then
      continue
    fi
    qualifying=$((qualifying + 1))
    if [ -n "$bang" ]; then
      have_breaking=1
      breaking+=("$subject")
    elif [ "$type" = "feat" ]; then
      have_feat=1
      features+=("$subject")
    elif [ "$type" = "fix" ]; then
      fixes+=("$subject")
    else
      other+=("$subject")
    fi
  else
    unclassifiable+=("$subject")
  fi
done < <(git log --format=%s "$range" 2>/dev/null || true)

if [ "${#unclassifiable[@]}" -gt 0 ]; then
  printf 'derive.sh: warning: unclassifiable commit subjects (not projected):\n' >&2
  printf '  %s\n' "${unclassifiable[@]}" >&2
fi

if [ "$qualifying" -eq 0 ]; then
  printf 'derive.sh: no conventional commits since %s — stop and ask\n' \
    "${last_tag:-the beginning}" >&2
  exit 1
fi

if [ "$have_breaking" -eq 1 ]; then
  bump="major"
elif [ "$have_feat" -eq 1 ]; then
  bump="minor"
else
  bump="patch"
fi

prefix=v major=0 minor=0 patch=0
if [ -n "$last_tag" ]; then
  if [[ "$last_tag" =~ ^(v?)([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    prefix="${BASH_REMATCH[1]}"
    major="${BASH_REMATCH[2]}"
    minor="${BASH_REMATCH[3]}"
    patch="${BASH_REMATCH[4]}"
  else
    printf 'derive.sh: last tag %s is not X.Y.Z or vX.Y.Z\n' "$last_tag" >&2
    exit 2
  fi
fi
case "$bump" in
  major) major=$((major + 1)) minor=0 patch=0 ;;
  minor) minor=$((minor + 1)) patch=0 ;;
  patch) patch=$((patch + 1)) ;;
esac
version="$prefix$major.$minor.$patch"

if [ "$sub" = "version" ]; then
  printf 'bump: %s\nversion: %s\n' "$bump" "$version"
  exit 0
fi

printf '## %s — %s\n' "$version" "$(date +%F)"
section() { # name subjects...
  local name="$1"
  shift
  [ "$#" -gt 0 ] || return 0
  printf '\n### %s\n' "$name"
  printf -- '- %s\n' "$@"
}
section "Breaking" "${breaking[@]+"${breaking[@]}"}"
section "Features" "${features[@]+"${features[@]}"}"
section "Fixes" "${fixes[@]+"${fixes[@]}"}"
section "Other" "${other[@]+"${other[@]}"}"

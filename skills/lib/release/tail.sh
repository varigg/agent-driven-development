#!/usr/bin/env bash
# The re-runnable post-merge tail of the ADDW release flow.
#
# Usage: tail.sh [--spec <n>] [--changelog <path>] [--remote <name>] <version>
#
# Run from the repository root after a release PR has been merged. The tail
# lays the version tag on HEAD, pushes it, publishes the GitHub Release using
# the matching changelog entry, and optionally closes the spec issue. Each
# stage skips work that is already complete, so an interrupted run can safely
# be repeated.
#
# Exit 0 when every stage succeeds or skips; 1 when a release must be created
# but the changelog has no entry for the version; 2 on usage errors or outside
# a git work tree.
set -euo pipefail

usage() {
  sed -n 's/^# \{0,1\}//p' "${BASH_SOURCE[0]}" | sed -n '/^Usage:/,/^$/p' >&2
  exit 2
}

changelog=CHANGELOG.md
remote=origin
spec=""
version=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --spec)
      [ "$#" -ge 2 ] || usage
      spec=$2
      [[ "$spec" =~ ^[1-9][0-9]*$ ]] || usage
      shift 2
      ;;
    --changelog)
      [ "$#" -ge 2 ] || usage
      changelog=$2
      [ -n "$changelog" ] || usage
      shift 2
      ;;
    --remote)
      [ "$#" -ge 2 ] || usage
      remote=$2
      [ -n "$remote" ] || usage
      shift 2
      ;;
    --)
      shift
      [ "$#" -eq 1 ] || usage
      version=$1
      shift
      ;;
    -*)
      usage
      ;;
    *)
      [ -z "$version" ] || usage
      version=$1
      shift
      ;;
  esac
done

[ -n "$version" ] || usage

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'tail.sh: not inside a git work tree\n' >&2
  exit 2
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tracker="$here/../tracker/tracker.sh"

if git rev-parse --verify --quiet "refs/tags/$version" >/dev/null 2>&1; then
  printf 'skip: tag %s already exists\n' "$version"
else
  git tag "$version"
  printf 'done: tagged %s at %s\n' "$version" "$(git rev-parse --short HEAD)"
fi

if git ls-remote --exit-code --refs "$remote" "refs/tags/$version" \
  >/dev/null 2>&1; then
  printf 'skip: tag %s already on %s\n' "$version" "$remote"
else
  # --quiet drops the progress and summary lines, not the errors: the tail's
  # own step lines are the whole of its successful output.
  git push --quiet "$remote" "refs/tags/$version:refs/tags/$version"
  printf 'done: pushed %s to %s\n' "$version" "$remote"
fi

if gh release view "$version" >/dev/null 2>&1; then
  printf 'skip: GitHub Release %s already published\n' "$version"
else
  notes_file="$(mktemp)"
  trap 'rm -f "$notes_file"' EXIT

  if ! awk -v wanted="$version" '
    function is_h2(line) {
      return substr(line, 1, 3) == "## "
    }
    !found {
      if (is_h2($0)) {
        heading = substr($0, 4)
        if (heading == wanted ||
          (substr(heading, 1, length(wanted) + 1) == wanted " ")) {
          found = 1
        }
      }
      next
    }
    is_h2($0) {
      exit
    }
    { lines[++count] = $0 }
    END {
      if (!found) {
        exit 1
      }
      first = 1
      while (first <= count && lines[first] ~ /^[[:space:]]*$/) {
        first++
      }
      last = count
      while (last >= first && lines[last] ~ /^[[:space:]]*$/) {
        last--
      }
      for (i = first; i <= last; i++) {
        print lines[i]
      }
    }
  ' "$changelog" >"$notes_file"; then
    printf 'tail.sh: no changelog entry for %s\n' "$version" >&2
    exit 1
  fi

  gh release create "$version" --title "$version" \
    --notes-file "$notes_file" >/dev/null
  printf 'done: published GitHub Release %s\n' "$version"
fi

if [ -n "$spec" ]; then
  issue_json="$(bash "$tracker" view "$spec")"
  state="$(jq -r '.state' <<<"$issue_json")"
  if [ "$state" = CLOSED ]; then
    printf 'skip: spec #%s already closed\n' "$spec"
  else
    bash "$tracker" close "$spec" completed >/dev/null
    printf 'done: closed spec #%s as completed\n' "$spec"
  fi
fi

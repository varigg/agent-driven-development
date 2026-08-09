#!/usr/bin/env bash
# The re-runnable post-merge tail of the ADDW release flow: tag, push,
# GitHub Release, and for a spec release the spec issue's closure. What each
# step is for, why an interrupted run is finished by re-running it, and why
# nothing is mutated before everything is validated: ../README.md.
#
# Usage: tail.sh [--spec <n>] [--commit <sha>] <version>
#   --spec <n>       the spec issue to close as completed; omitted for a
#                    repository release, which closes nothing
#   --commit <sha>   the release PR's merge commit (default HEAD). Callers
#                    should always pass it: let it default once another PR has
#                    merged, and the tag covers commits the changelog entry
#                    never mentions.
#   <version>        the version to tag and publish. Must match an entry in
#                    the target commit's CHANGELOG.md, whose body becomes the
#                    release notes, read from that commit's tree rather than
#                    the working tree.
#
# Run from the repository root after the release PR has been merged. Each step
# prints one `done:`/`skip:` line.
#
# Exit 0 when every step succeeded or skipped; 1 when the release commit's
# CHANGELOG.md has no entry for the version; 2 on usage errors, outside a git
# work tree, on an unresolvable --commit, or on a tag that exists but points
# elsewhere.
set -euo pipefail

usage() {
  sed -n 's/^# \{0,1\}//p' "${BASH_SOURCE[0]}" | sed -n '/^Usage:/,/^$/p' >&2
  exit 2
}

# The changelog path and the remote are fixed by the docs contract and by the
# tracker layer's own `git ls-remote --heads origin`; a project that moved
# either has bigger divergences than a flag would paper over.
changelog=CHANGELOG.md
remote=origin
spec=""
commit=""
version=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --spec)
      [ "$#" -ge 2 ] || usage
      spec=$2
      [[ "$spec" =~ ^[1-9][0-9]*$ ]] || usage
      shift 2
      ;;
    --commit)
      [ "$#" -ge 2 ] || usage
      commit=$2
      [ -n "$commit" ] || usage
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

# --- validation: nothing below this block mutates anything -----------------

if ! target="$(git rev-parse --verify --quiet "${commit:-HEAD}^{commit}")"; then
  printf 'tail.sh: cannot resolve %s to a commit\n' "${commit:-HEAD}" >&2
  exit 2
fi

# The notes are the changelog entry's body, read rather than re-derived:
# deriving twice could disagree, and the published release and the committed
# changelog have to be the same words.
#
# Read from the target commit's tree, never the working tree. The two differ
# exactly when it matters — a --commit that predates the release, or an
# uncommitted local edit — and reading the working tree would let either
# publish a release whose notes are absent from the code being tagged. Binding
# them here is also what catches a version disagreeing with the one the
# release PR committed, before any tag exists.
notes_file="$(mktemp)"
trap 'rm -f "$notes_file"' EXIT

if ! changelog_at_target="$(git show "$target:$changelog" 2>/dev/null)"; then
  printf 'tail.sh: no %s at the release commit %s\n' \
    "$changelog" "$(git rev-parse --short "$target")" >&2
  exit 1
fi

if ! printf '%s\n' "$changelog_at_target" | awk -v wanted="$version" '
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
' >"$notes_file"; then
  printf 'tail.sh: no %s entry for %s at the release commit %s\n' \
    "$changelog" "$version" "$(git rev-parse --short "$target")" >&2
  exit 1
fi

refuse_tag() { # where sha
  printf 'tail.sh: the %s tag %s points at %s, not the release commit (%s)\n' \
    "$1" "$version" "$(git rev-parse --short "$2" 2>/dev/null || printf '%s' "$2")" \
    "$(git rev-parse --short "$target")" >&2
  printf '  pass --commit <merge-sha>, or delete the tag if it is wrong\n' >&2
  exit 2
}

local_tag=""
if local_tag="$(git rev-parse --verify --quiet "refs/tags/$version^{commit}")"; then
  [ "$local_tag" = "$target" ] || refuse_tag local "$local_tag"
fi

# ls-remote reports the tag object; the peeled `^{}` ref is the commit an
# annotated tag wraps, and is absent for the lightweight tags this lays.
remote_tag=""
if remote_refs="$(git ls-remote --tags "$remote" \
  "refs/tags/$version" "refs/tags/$version^{}" 2>/dev/null)" \
  && [ -n "$remote_refs" ]; then
  remote_tag="$(printf '%s\n' "$remote_refs" | awk '
    $2 ~ /\^\{\}$/ { peeled = $1 }
    $2 !~ /\^\{\}$/ { plain = $1 }
    END { print (peeled != "" ? peeled : plain) }
  ')"
  [ "$remote_tag" = "$target" ] || refuse_tag remote "$remote_tag"
fi

# --- mutation: four steps, each skipping what is already done --------------

if [ -n "$local_tag" ]; then
  printf 'skip: tag %s already at %s\n' "$version" "$(git rev-parse --short "$target")"
else
  git tag "$version" "$target"
  printf 'done: tagged %s at %s\n' "$version" "$(git rev-parse --short "$target")"
fi

if [ -n "$remote_tag" ]; then
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
  gh release create "$version" --title "$version" \
    --notes-file "$notes_file" >/dev/null
  printf 'done: published GitHub Release %s\n' "$version"
fi

if [ -n "$spec" ]; then
  if [ "$(bash "$tracker" state "$spec")" = CLOSED ]; then
    printf 'skip: spec #%s already closed\n' "$spec"
  else
    bash "$tracker" close "$spec" completed >/dev/null
    printf 'done: closed spec #%s as completed\n' "$spec"
  fi
fi

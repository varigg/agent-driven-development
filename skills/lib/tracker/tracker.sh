#!/usr/bin/env bash
# The tracker seam: every ADDW tracker operation goes through this file — no
# other script invokes the tracker CLI (gh) for tracker work. The wrappers are
# deliberately thin (dogfood-verified, not unit-tested); the two queries fetch
# a live snapshot and delegate all reasoning to resolve.sh, which is pure and
# contract-tested. This file is the documented seam for a future tracker
# adapter: swapping trackers means reimplementing these subcommands, nothing
# else.
#
# Usage:
#   tracker.sh view <n>                          issue JSON (snapshot shape + url)
#   tracker.sh body <n>                          issue body markdown
#   tracker.sh title <n>                         issue title
#   tracker.sh state <n>                         OPEN | CLOSED
#   tracker.sh edit-body <n> <file>              replace the body from a file
#   tracker.sh label <n> <label>                 add a label
#   tracker.sh unlabel <n> <label>               remove a label
#   tracker.sh comment <n> <file>                comment from a file
#   tracker.sh close <n> <completed|not-planned> [comment-file]
#   tracker.sh assign <n>                        self-assign (@me)
#   tracker.sh create <title> <body-file> [label...]  open an issue
#   tracker.sh auth                              tracker CLI installed and authenticated
#   tracker.sh issues-enabled                    repository issues are enabled
#   tracker.sh labels                            label names, one per line
#   tracker.sh create-label <label>              create an idempotent label
#   tracker.sh snapshot                          all issues, resolver JSON, stdout
#   tracker.sh branches                          remote branch names, one per line
#   tracker.sh frontier                          live frontier listing
#   tracker.sh spec-complete <n>                 live spec-completion query
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVE="$here/resolve.sh"

# The resolver's snapshot shape. --limit raises gh's default of 30; a repo
# outgrowing 1000 issues will need pagination here before anything truncates.
FIELDS='number,title,state,stateReason,labels,assignees,body'

usage() {
  sed -n 's/^# \{0,1\}//p' "${BASH_SOURCE[0]}" | sed -n '/^Usage:/,/^$/p' >&2
  exit 2
}

snapshot() {
  gh issue list --state all --limit 1000 --json "$FIELDS"
}

branches() {
  git ls-remote --heads origin | sed 's|.*refs/heads/||'
}

[ "$#" -ge 1 ] || usage
cmd=$1
shift

case "$cmd" in
  view)
    [ "$#" -eq 1 ] || usage
    gh issue view "$1" --json "$FIELDS,url"
    ;;
  body)
    [ "$#" -eq 1 ] || usage
    gh issue view "$1" --json body --jq .body
    ;;
  title)
    [ "$#" -eq 1 ] || usage
    gh issue view "$1" --json title --jq .title
    ;;
  state)
    # Callers that only need open-vs-closed get it here rather than parsing
    # the snapshot shape themselves — that parsing is what the seam exists to
    # keep in one place.
    [ "$#" -eq 1 ] || usage
    gh issue view "$1" --json state --jq .state
    ;;
  edit-body)
    [ "$#" -eq 2 ] || usage
    gh issue edit "$1" --body-file "$2"
    ;;
  label)
    [ "$#" -eq 2 ] || usage
    gh issue edit "$1" --add-label "$2"
    ;;
  unlabel)
    [ "$#" -eq 2 ] || usage
    gh issue edit "$1" --remove-label "$2"
    ;;
  comment)
    [ "$#" -eq 2 ] || usage
    gh issue comment "$1" --body-file "$2"
    ;;
  close)
    [ "$#" -eq 2 ] || [ "$#" -eq 3 ] || usage
    case "$2" in
      completed) reason="completed" ;;
      not-planned) reason="not planned" ;;
      *) usage ;;
    esac
    if [ "$#" -eq 3 ]; then
      # Read before closing: a cat failure inside the gh argument list would
      # not stop set -e, and the issue would close without its comment.
      comment="$(cat "$3")"
      gh issue close "$1" --reason "$reason" --comment "$comment"
    else
      gh issue close "$1" --reason "$reason"
    fi
    ;;
  assign)
    [ "$#" -eq 1 ] || usage
    gh issue edit "$1" --add-assignee "@me"
    ;;
  create)
    # The operation the happy path never reaches: to-spec and to-tickets author
    # the issues ADDW works on. It is here for the paths that do originate one —
    # addw-maintain routing a substantive finding to a `backlog` issue, and the
    # schema-4 backlog migration.
    [ "$#" -ge 2 ] || usage
    title=$1
    body_file=$2
    shift 2
    # Checked before the call, not by gh: a body-file failure mid-create leaves
    # a titled, bodyless issue behind, and issues cannot be un-created.
    if [ ! -f "$body_file" ]; then
      printf 'tracker.sh: body file not found: %s\n' "$body_file" >&2
      exit 1
    fi
    # One --label per label. A comma-joined string would be read as a single
    # label name containing commas, which silently creates the wrong thing.
    label_args=()
    for label in "$@"; do
      label_args+=(--label "$label")
    done
    gh issue create --title "$title" --body-file "$body_file" \
      ${label_args[@]+"${label_args[@]}"}
    ;;
  auth)
    [ "$#" -eq 0 ] || usage
    gh auth status
    ;;
  issues-enabled)
    [ "$#" -eq 0 ] || usage
    [ "$(gh repo view --json hasIssuesEnabled --jq .hasIssuesEnabled)" = true ]
    ;;
  labels)
    [ "$#" -eq 0 ] || usage
    gh label list --limit 1000 --json name --jq '.[].name'
    ;;
  create-label)
    [ "$#" -eq 1 ] || usage
    gh label create "$1" --force
    ;;
  snapshot)
    [ "$#" -eq 0 ] || usage
    snapshot
    ;;
  branches)
    [ "$#" -eq 0 ] || usage
    branches
    ;;
  frontier)
    [ "$#" -eq 0 ] || usage
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    snapshot > "$tmpdir/issues.json"
    branches > "$tmpdir/branches.txt"
    bash "$RESOLVE" frontier "$tmpdir/issues.json" "$tmpdir/branches.txt"
    ;;
  spec-complete)
    [ "$#" -eq 1 ] || usage
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    snapshot > "$tmpdir/issues.json"
    bash "$RESOLVE" spec-complete "$1" "$tmpdir/issues.json"
    ;;
  *)
    usage
    ;;
esac

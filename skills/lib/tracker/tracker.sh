#!/usr/bin/env bash
# The tracker seam: every ADDW tracker operation goes through this file — no
# other script invokes the tracker CLI (gh) for tracker work. Why the layer is
# shaped this way, and what a future tracker adapter inherits: ../README.md.
#
# Usage:
#   tracker.sh view <n>                          issue JSON (snapshot shape + url)
#   tracker.sh body <n>                          issue body markdown
#   tracker.sh title <n>                         issue title
#   tracker.sh state <n>                         OPEN | CLOSED
#   tracker.sh edit-body <n> <file>              replace the body from a file
#   tracker.sh edit-title <n> <file>             replace the title with the file's first line
#   tracker.sh label <n> <label>                 add a label
#   tracker.sh unlabel <n> <label>               remove a label
#   tracker.sh comment <n> <file>                comment from a file
#   tracker.sh close <n> <completed|not-planned> [comment-file]
#   tracker.sh assign <n>                        self-assign (@me)
#   tracker.sh create <title> <body-file> [label...]  open an issue
#   tracker.sh create --title-file <file> <body-file> [label...]  title from the file's first line
#   tracker.sh auth                              tracker CLI installed and authenticated
#   tracker.sh issues-enabled                    repository issues are enabled
#   tracker.sh labels                            label names, one per line
#   tracker.sh create-label <label>              create an idempotent label
#   tracker.sh snapshot                          the workflow's issues, resolver JSON, stdout
#   tracker.sh branches                          remote branch names, one per line
#   tracker.sh frontier                          live frontier listing
#   tracker.sh spec-complete <n>                 live spec-completion query
#   tracker.sh specs                             live specs-by-verdict listing
#   tracker.sh body-hash <n>                     truncated sha256 of the issue body
#   tracker.sh approval-drift <n>                match/unrecorded exit 0, drift exits 1
#   tracker.sh parent-check <n> <expected>       fail loudly unless <n>'s parsed parent is <expected>
#   tracker.sh child-delivery <n>                live per-spec closed-child delivery lookup
#
# `snapshot` means "the issues the workflow reasons about", not "every issue":
# `archived` issues are dropped immediately after the fetch, so no consumer can
# decode a retired document's body. Single-issue reads through `view` are
# unaffected — an archive stays deliberately fetchable by number.
#
# The fetch is bounded by ADDW_TRACKER_FETCH_LIMIT (default 1000). Reaching that
# bound exits non-zero rather than answering, and every consumer inherits the
# refusal. Why the filter is client-side and why the bound refuses rather than
# truncating: ../README.md.
#
# child-delivery <n> is a live read over spec <n>'s closed children: the
# parent edge is a tracker question (the same body-parsing contract
# resolve.sh uses), but a child's delivery is answered from git — the merge
# commit its closing PR left, whether that commit touched the project's ADR
# directory, and the first tag that shipped it. It stays out of resolve.sh
# because that script's fixture-testability contract forbids git and
# network; this command needs both, so it lives in the seam instead. Why the
# split: ../README.md. One line per closed child, ascending by issue number,
# tab-separated:
#   #<child>\tabandoned                     closed not-planned
#   #<child>\tno-pr                         closed completed, no tracked PR
#   #<child>\tcompleted\t#<PR>\t<sha>\t<adr:yes|no>\t<tag|unreleased>
# <tag> is the first tag containing the merge commit (`git describe --tags
# --contains`, bare tag name); <adr> is `yes` iff that commit added or
# modified a file under docs/adr/. An open child of the spec is silent here —
# `spec-complete` answers those. Exits 2 when <n> is not a spec-labeled issue
# in the snapshot.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVE="$here/resolve.sh"
PARSE="$here/parse.sh"
# shellcheck source=../config/config.sh
. "$here/../config/config.sh"

# The resolver's snapshot shape. --limit raises gh's default of 30.
FIELDS='number,title,state,stateReason,labels,assignees,body'

CONFIG="docs/addw.env"
FETCH_LIMIT_DEFAULT=1000
FETCH_LIMIT=""

# Fixed by the domain-layout contract (docs/agents/domain.md), same as
# release/adr-check.sh's own ADR_DIR — not project config, since a rename
# here is a docs-contract change, not a per-project setting.
ADR_DIR=docs/adr

CLOSING_PR_QUERY='
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    issue(number: $number) {
      closedByPullRequestsReferences(first: 50) {
        nodes { number mergeCommit { oid } }
      }
    }
  }
}'

usage() {
  sed -n 's/^# \{0,1\}//p' "${BASH_SOURCE[0]}" | sed -n '/^Usage:/,/^$/p' >&2
  exit 2
}

# Sets FETCH_LIMIT from the project config, or the default when unconfigured.
# It assigns a global rather than printing one, so the refusals below exit the
# script instead of a command substitution's subshell.
resolve_fetch_limit() {
  # The shared reader answers from the file alone, so a value inherited from
  # the environment cannot make an unconfigured project look configured. A
  # missing config means the default; an invalid one is a defect and takes
  # the seam down with the parser's diagnostic (78, EX_CONFIG).
  local configured=""
  configured="$(config_get ADDW_TRACKER_FETCH_LIMIT)" || {
    local config_status=$?
    [ "$config_status" -eq 66 ] || exit "$config_status"
  }
  [ -n "$configured" ] || configured=$FETCH_LIMIT_DEFAULT
  # Checked here rather than by the tracker CLI, which would reject it with its
  # own diagnostic several layers from the config line that caused it.
  if ! [[ $configured =~ ^[1-9][0-9]*$ ]]; then
    printf 'tracker.sh: ADDW_TRACKER_FETCH_LIMIT must be a positive integer, got %s (in %s)\n' \
      "$(printf '%q' "$configured")" "$CONFIG" >&2
    exit 1
  fi
  FETCH_LIMIT=$configured
}

snapshot() {
  local raw fetched
  resolve_fetch_limit
  raw="$(gh issue list --state all --limit "$FETCH_LIMIT" --json "$FIELDS")"
  fetched="$(printf '%s' "$raw" | jq 'length')"
  # Counted before the filter: archives are what make the bound reachable, so a
  # post-filter count would under-report exactly when it matters.
  if [ "$fetched" -ge "$FETCH_LIMIT" ]; then
    printf 'tracker.sh: the issue fetch returned %s and reached its limit of %s, so this snapshot cannot be shown to be complete.\n' \
      "$fetched" "$FETCH_LIMIT" >&2
    printf 'tracker.sh: raise ADDW_TRACKER_FETCH_LIMIT in %s (default %s). Archived issues are filtered out of the snapshot but still count toward the limit.\n' \
      "$CONFIG" "$FETCH_LIMIT_DEFAULT" >&2
    exit 1
  fi
  printf '%s' "$raw" | jq 'map(select(any(.labels[]?; .name == "archived") | not))'
}

branches() {
  git ls-remote --heads origin | sed 's|.*refs/heads/||'
}

issue_body() { # issue-number
  gh issue view "$1" --json body --jq .body
}

issue_body_hash() { # issue-number
  issue_body "$1" | bash "$PARSE" body-hash
}

approval_drift() { # issue-number
  local issue=$1 current recorded
  current="$(issue_body_hash "$issue")"
  recorded="$(gh api "repos/{owner}/{repo}/issues/$issue/comments" --paginate \
    --jq '.[].body' | bash "$PARSE" approval-hash)"

  if [ -z "$recorded" ]; then
    printf 'approval-drift: no approval hash recorded on issue #%s\n' "$issue"
  elif [ "$recorded" = "$current" ]; then
    printf 'approval-drift: match %s\n' "$current"
  else
    printf 'approval-drift: issue #%s body has drifted from its approved content: approved %s, current %s\n' \
      "$issue" "$recorded" "$current"
    return 1
  fi
}

parent_check() { # issue-number expected-parent
  local issue=$1 expected=$2 parsed
  parsed="$(issue_body "$issue" | bash "$PARSE" parent)"

  if [ -z "$parsed" ]; then
    printf 'parent-check: issue #%s has no parseable parent edge; expected #%s\n' \
      "$issue" "$expected" >&2
    return 1
  elif [ "$parsed" != "$expected" ]; then
    printf 'parent-check: issue #%s parent edge parses as #%s, expected #%s\n' \
      "$issue" "$parsed" "$expected" >&2
    return 1
  else
    printf 'parent-check: issue #%s parent #%s confirmed\n' "$issue" "$expected"
  fi
}

# The PR that closed <issue>, if any: "<PR-number>\t<merge-commit-sha>", or
# empty when no tracked PR closed it (closed by hand) or its merge commit is
# unavailable. Takes the last reference when more than one PR closed the
# issue (a reopen-and-reclose), the same "most recent wins" rule parse.sh's
# approval-hash applies to its own last-marker-wins read.
closing_pr() { # issue-number
  gh api graphql -f query="$CLOSING_PR_QUERY" \
    -F owner='{owner}' -F name='{repo}' -F number="$1" \
    --jq '.data.repository.issue.closedByPullRequestsReferences.nodes
      | map(select(.mergeCommit != null)) | last
      | if . == null then "" else "\(.number)\t\(.mergeCommit.oid)" end'
}

adr_touched() { # commit-sha -> yes|no
  if git show --format= --name-status "$1" -- "$ADR_DIR" 2>/dev/null \
      | awk '$1 ~ /^[AM]/ { f = 1 } END { exit !f }'; then
    echo yes
  else
    echo no
  fi
}

first_tag() { # commit-sha -> tag or unreleased
  local t
  t="$(git describe --tags --contains "$1" 2>/dev/null || true)"
  if [ -z "$t" ]; then
    echo unreleased
  else
    # --contains suffixes an exact match with ~N/^N when the commit predates
    # the tag rather than being it; only the bare tag name is wanted.
    printf '%s\n' "${t%%[~^]*}"
  fi
}

child_delivery() { # spec-number issues.json
  local spec=$1 file=$2 num state reason b64 body parent status pr_line pr sha adr tag

  if ! jq -e --arg n "$spec" \
      '.[] | select((.number | tostring) == $n) | any(.labels[]?; .name == "spec")' \
      "$file" >/dev/null; then
    printf 'tracker.sh: #%s is not a spec-labeled issue in the snapshot\n' "$spec" >&2
    return 2
  fi

  while IFS=$'\x1f' read -r num state reason b64; do
    [ "$state" = "CLOSED" ] || continue
    body="$(printf '%s' "$b64" | base64 -d)"
    parent="$(printf '%s' "$body" | bash "$PARSE" parent)"
    [ "$parent" = "$spec" ] || continue

    status="$(bash "$PARSE" classify-reason "$reason")" || return $?
    if [ "$status" = "not-planned" ]; then
      printf '#%s\tabandoned\n' "$num"
      continue
    fi

    pr_line="$(closing_pr "$num")" || return $?
    if [ -z "$pr_line" ]; then
      printf '#%s\tno-pr\n' "$num"
      continue
    fi
    pr="${pr_line%%$'\t'*}"
    sha="${pr_line#*$'\t'}"
    adr="$(adr_touched "$sha")"
    tag="$(first_tag "$sha")"
    printf '#%s\tcompleted\t#%s\t%s\t%s\t%s\n' "$num" "$pr" "$sha" "$adr" "$tag"
  done < <(jq -r 'sort_by(.number)[] |
      [(.number | tostring), .state, (.stateReason // ""), (.body // "" | @base64)]
      | join("")' "$file")
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
    issue_body "$1"
    ;;
  body-hash)
    [ "$#" -eq 1 ] || usage
    issue_body_hash "$1"
    ;;
  approval-drift)
    [ "$#" -eq 1 ] || usage
    approval_drift "$1"
    ;;
  parent-check)
    [ "$#" -eq 2 ] || usage
    parent_check "$1" "$2"
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
  edit-title)
    # The title rides a file like edit-body's body, so punctuation never has to
    # survive a shell quoting round-trip. Only the first line is the title.
    [ "$#" -eq 2 ] || usage
    title="$(head -n 1 "$2")"
    gh issue edit "$1" --title "$title"
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
    # The title comes positionally, or from a file's first line as in
    # edit-title — the file form spares punctuation a shell quoting round-trip.
    if [ "${1:-}" = "--title-file" ]; then
      [ "$#" -ge 3 ] || usage
      title="$(head -n 1 "$2")"
      shift 2
    else
      [ "$#" -ge 2 ] || usage
      title=$1
      shift
    fi
    body_file=$1
    shift
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
  specs)
    [ "$#" -eq 0 ] || usage
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    snapshot > "$tmpdir/issues.json"
    bash "$RESOLVE" specs "$tmpdir/issues.json"
    ;;
  child-delivery)
    [ "$#" -eq 1 ] || usage
    case "$1" in *[!0-9]* | '') usage ;; esac
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    snapshot > "$tmpdir/issues.json"
    child_delivery "$1" "$tmpdir/issues.json"
    ;;
  *)
    usage
    ;;
esac

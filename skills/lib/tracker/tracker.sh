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
#   tracker.sh detach <n>                        move a ticket out of its
#                                                 spec into the backlog
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
#   tracker.sh contract <n>                      body + amendments of <n> and its parent
#   tracker.sh parent-check <n> <expected>       fail loudly unless <n>'s parsed parent is <expected>
#   tracker.sh child-delivery <n>                live per-spec closed-child delivery lookup
#   tracker.sh close-spec <n>                    close a Complete spec, recording each
#                                                 child's delivery
# Exit status 3 from `frontier`: delivery enrichment failed; output contains
# `complete-specs: unavailable — <diag>` and the ticket sections remain usable.
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
# modified a file under the project's configured ADR directory
# (ADDW_ADR_DIR). An open child of the spec is silent here — `spec-complete` answers those. Exits
# 2 when <n> is not a spec-labeled issue in the snapshot; 78 (EX_CONFIG) when
# ADDW_ADR_DIR is unset or empty; 1 when a closing PR's merge commit is not
# resolvable in this checkout (a shallow or stale clone) — never reported as a
# quiet "no" / "unreleased".
#
# close-spec <n> refuses unless <n>'s verdict (spec-complete's four-way
# read, ADR obligation folded in) is `complete` — non-zero, naming the
# verdict, and for partial/planned also the open child lines. On a `complete`
# verdict it derives the record from child-delivery: for each child, its
# ticket, closing PR, and first tag containing its merge commit, or
# *unreleased*; a not-planned child lists as abandoned; a completed child
# closed by hand with no tracked PR lists as such. That record is posted as
# the closing comment in the same `gh issue close` call, and the spec closes
# as completed. An obligated spec needs ADDW_ADR_DIR configured (78,
# EX_CONFIG, if not) for its ADR-touch projection. A spec with no declared ADR
# obligation gets its PR/commit/tag record from the facts and first-tag
# projections without resolving ADDW_ADR_DIR. Exits 2 when <n> is not a
# spec-labeled issue in the snapshot.
#
# contract <n> prints a ticket's effective contract (spec #243, ADR 0020): a
# block headed `== TICKET #<n> ==` holding the body, then the sections
# `== AMENDMENTS #<n> ==`, `== PRESUMED FOLDED #<n> ==` and `== UNMARKED #<n> ==`.
# When the body names a parent, the same block follows for it, headed
# `== PARENT #<p> ==`. Each section lists comments oldest first (creation
# time, comment ID tie-break), each as `-- <id> <created-at> <author> --` and
# the body verbatim; an empty section prints `(none)`. Only trusted authors'
# comments are read, every page of them. An amendment created before the
# body's last edit is presumed folded; an unmarked comment carries neither
# marker nor a shipped review grammar.
#
# detach <n> is deferral: it rewrites <n>'s body with its "## Parent" section
# removed (parse.sh strip-section), swaps readiness, priority and spec labels
# for `backlog`,
# and comments naming the former parent so the edge survives in the ticket's
# own history. Why deferral is a detach rather than a not-planned close:
# ../README.md. Refuses (1) a closed issue, and an issue with no parseable
# parent — nothing to detach. It does not touch the former parent issue.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVE="$here/resolve.sh"
PARSE="$here/parse.sh"
# shellcheck source=../config/config.sh
. "$here/../config/config.sh"

# The resolver's snapshot shape. --limit raises gh's default of 30.
FIELDS='number,title,state,stateReason,labels,assignees,body,url'

CONFIG="docs/addw.env"
FETCH_LIMIT_DEFAULT=1000
FETCH_LIMIT=""

# Resolved from the project's own ADDW_ADR_DIR (docs/agents/domain.md,
# skills/addw-init's Step 1.5) — the same key next-adr-number.sh and
# codex-code-review's guardrail check already read, so a project that
# configured a non-default ADR directory gets a correct answer here too.
# Empty until resolve_adr_dir() runs. Only the public child-delivery path and
# ADR-obligation delivery gathering need it; tag-only paths stay usable without
# an ADDW_ADR_DIR.
ADR_DIR=""

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

CONTRACT_EDITED_QUERY='
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    issue(number: $number) {
      lastEditedAt
    }
  }
}'

TRUSTED_AUTHOR_JQ='(.author_association | IN("OWNER","MEMBER","COLLABORATOR")) and (.user.type != "Bot")'

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

# Sets ADR_DIR from ADDW_ADR_DIR, the same key next-adr-number.sh requires.
# No default: unlike the fetch limit, a wrong guess here would silently
# mis-locate ADRs in a project that configured a non-default directory, so
# an unset or empty key is a config defect (78, EX_CONFIG), not a fallback.
resolve_adr_dir() {
  config_source ADDW_ADR_DIR
  ADR_DIR="${ADDW_ADR_DIR:-}"
  if [ -z "$ADR_DIR" ]; then
    printf 'tracker.sh: ADDW_ADR_DIR is unset or empty in %s\n' "$CONFIG" >&2
    exit 78
  fi
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

spec_label_for() { # parent-number; empty for an unmapped parent
  local entry number label mappings
  mappings="$(config_get ADDW_SPEC_LABELS)" || return $?
  for entry in $mappings; do
    number=${entry%%=*}
    label=${entry#*=}
    if [ "$number" = "$1" ]; then printf '%s\n' "$label"; return; fi
  done
}

creation_labels() { # body-file [label...]; prints one label per line
  local body_file=$1 parent parent_state expected mappings label ready=0 priority=0 excluded=0
  shift
  for label in "$@"; do
    case "$label" in
      ready-for-agent|ready-for-human) ready=$((ready + 1)) ;;
      priority:high|priority:normal|priority:low) priority=$((priority + 1)) ;;
      backlog|spec|wayfinder:*) excluded=1 ;;
      spec:*) printf 'tracker.sh: spec membership comes from the body Parent section, not a create argument\n' >&2; return 1 ;;
    esac
  done
  if [ "$ready" -gt 1 ] || [ "$priority" -gt 1 ]; then
    printf 'tracker.sh: create needs at most one readiness and priority label\n' >&2
    return 1
  fi
  if [ "$ready" -gt 0 ] && [ "$excluded" -eq 1 ]; then
    printf 'tracker.sh: a ready ticket cannot also be backlog, spec, or wayfinder work\n' >&2
    return 1
  fi
  if [ "$ready" -eq 0 ] && [ "$priority" -gt 0 ]; then
    printf 'tracker.sh: priority applies only to ready implementation tickets\n' >&2
    return 1
  fi
  printf '%s\n' "$@"
  [ "$ready" -eq 1 ] || return 0
  [ "$priority" -eq 1 ] || printf 'priority:normal\n'
  mappings="$(config_get ADDW_SPEC_LABELS)" || return $?
  [ -n "$mappings" ] || return 0
  parent="$(bash "$PARSE" parent "$body_file")"
  [ -n "$parent" ] || return 0
  parent_state="$(gh issue view "$parent" --json state,labels --jq '[.state, ([.labels[].name] | index("spec") != null)] | @tsv')"
  # A historical parent edge can point at a completed spec. It remains in the
  # body, but only an open spec has active membership to mirror as a label.
  if [ "$parent_state" = $'CLOSED\ttrue' ]; then return 0; fi
  if [ "$parent_state" != $'OPEN\ttrue' ]; then
    printf 'tracker.sh: parent #%s is not a spec\n' "$parent" >&2
    return 1
  fi
  expected="$(spec_label_for "$parent")"
  if [ -z "$expected" ]; then
    printf 'tracker.sh: parent #%s has no ADDW_SPEC_LABELS mapping\n' "$parent" >&2
    return 1
  fi
  printf '%s\n' "$expected"
}

label_ticket() { # issue-number label
  local issue=$1 wanted=$2 current label state resolved
  local -a edit_args=(--add-label "$wanted") existing=()
  case "$wanted" in
    priority:high|priority:normal|priority:low)
      current="$(gh issue view "$issue" --json labels --jq '.labels[].name')"
      if ! printf '%s\n' "$current" | grep -Eq '^(ready-for-agent|ready-for-human)$'; then
        printf 'tracker.sh: priority applies only to ready implementation tickets\n' >&2
        return 1
      fi
      while IFS= read -r label; do
        case "$label" in
          priority:high|priority:normal|priority:low)
            [ "$label" = "$wanted" ] || edit_args+=(--remove-label "$label") ;;
        esac
      done <<< "$current"
      ;;
    ready-for-agent|ready-for-human)
      tmpdir="$(mktemp -d)"
      trap 'rm -rf "$tmpdir"' EXIT
      gh issue view "$issue" --json state,body,labels > "$tmpdir/issue.json"
      jq -e '(.state | type == "string") and (.body | type == "string") and (.labels | type == "array")' "$tmpdir/issue.json" >/dev/null
      state="$(jq -r .state "$tmpdir/issue.json")"
      [ "$state" = OPEN ] || { printf 'tracker.sh: only open issues can become ready\n' >&2; return 1; }
      jq -r .body "$tmpdir/issue.json" > "$tmpdir/body.md"
      while IFS= read -r label; do
        case "$label" in
          ready-for-agent|ready-for-human)
            [ "$label" = "$wanted" ] || { printf 'tracker.sh: remove %s before adding %s\n' "$label" "$wanted" >&2; return 1; } ;;
          priority:high|priority:normal|priority:low) existing+=("$label") ;;
          spec:*) edit_args+=(--remove-label "$label") ;;
          backlog) edit_args+=(--remove-label backlog) ;;
          spec|wayfinder:*) printf 'tracker.sh: specs and wayfinder work cannot become ready\n' >&2; return 1 ;;
        esac
      done < <(jq -r '.labels[].name' "$tmpdir/issue.json")
      resolved="$(creation_labels "$tmpdir/body.md" "$wanted" "${existing[@]}")"
      while IFS= read -r label; do
        case "$label" in
          priority:*|spec:*) edit_args+=(--add-label "$label") ;;
        esac
      done <<< "$resolved"
      ;;
  esac
  gh issue edit "$issue" "${edit_args[@]}"
}

issue_body_hash() { # issue-number
  issue_body "$1" | bash "$PARSE" body-hash
}

approval_drift() { # issue-number
  local issue=$1 current recorded
  current="$(issue_body_hash "$issue")"
  # Approvals are human acts: a marker from a bot or stranger is deliberately
  # not counted, so it reads as unrecorded rather than as an approval.
  recorded="$(gh api "repos/{owner}/{repo}/issues/$issue/comments" --paginate \
    --jq ".[] | select($TRUSTED_AUTHOR_JQ) | .body" \
    | bash "$PARSE" approval-hash)"

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

last_edited_at() { # issue-number
  gh api graphql -f query="$CONTRACT_EDITED_QUERY" \
    -F owner='{owner}' -F name='{repo}' -F number="$1" \
    --jq '.data.repository.issue.lastEditedAt // ""'
}

contract_block() { # issue-number header body block-directory
  local issue=$1 header=$2 body=$3 dir=$4
  local last_edited comment id created_at login section

  mkdir -p "$dir"
  : > "$dir/amendments"; : > "$dir/folded"; : > "$dir/unmarked"
  last_edited="$(last_edited_at "$issue")"
  # Read into a file first: a failed read must stop the script, never render
  # as a contract with no amendments. One compact JSON object per trusted
  # comment, oldest first; creation time never changes on edit, so an edited
  # comment keeps its place.
  gh api "repos/{owner}/{repo}/issues/$issue/comments" --paginate \
      --jq ".[] | select($TRUSTED_AUTHOR_JQ) | {id, created_at, user: {login: .user.login}, body}" \
    | jq -s -c 'sort_by([.created_at, .id])[]' > "$dir/comments.jsonl"

  while IFS= read -r comment; do
    IFS=$'\t' read -r id created_at login < <(jq -r '[.id, .created_at, .user.login] | @tsv' <<< "$comment")
    jq -j '.body' <<< "$comment" > "$dir/body"

    if [ -n "$(bash "$PARSE" amendment-summary "$dir/body")" ]; then
      if [ -n "$last_edited" ] && [[ "$created_at" < "$last_edited" ]]; then
        section=folded
      else
        section=amendments
      fi
    else
      [ -z "$(bash "$PARSE" approval-hash "$dir/body")" ] || continue
      case "$(head -n 1 "$dir/body")" in
        "Codex code review:"*|"Codex spec review:"*) continue ;;
      esac
      section=unmarked
    fi

    {
      printf -- '-- %s %s %s --\n' "$id" "$created_at" "$login"
      cat "$dir/body"
      [ -z "$(tail -c 1 "$dir/body")" ] || printf '\n'
    } >> "$dir/$section"
  done < "$dir/comments.jsonl"

  printf '%s\n%s\n' "$header" "$body"
  for section in AMENDMENTS:amendments 'PRESUMED FOLDED:folded' UNMARKED:unmarked; do
    printf '== %s #%s ==\n' "${section%%:*}" "$issue"
    if [ -s "$dir/${section#*:}" ]; then cat "$dir/${section#*:}"; else printf '(none)\n'; fi
  done
}

# tmpdir is deliberately not `local`, matching detach's own reasoning.
contract() { # issue-number
  local issue=$1 ticket_body parent parent_body

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  ticket_body="$(issue_body "$issue")"
  parent="$(printf '%s' "$ticket_body" | bash "$PARSE" parent)"
  contract_block "$issue" "== TICKET #$issue ==" "$ticket_body" "$tmpdir/ticket"
  if [ -n "$parent" ]; then
    parent_body="$(issue_body "$parent")"
    contract_block "$parent" "== PARENT #$parent ==" "$parent_body" "$tmpdir/parent"
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

adr_touched() { # commit-sha — the caller has already verified it resolves
  if git show --format= --name-status "$1" -- "$ADR_DIR" \
      | awk '$1 ~ /^[AM]/ { f = 1 } END { exit !f }'; then
    echo yes
  else
    echo no
  fi
}

first_tag() { # commit-sha
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

detach() { # issue-number
  # tmpdir is deliberately not `local`: its cleanup trap fires on the whole
  # process's EXIT, which runs after this function has returned and its
  # locals have gone out of scope — under `set -u` that reads as unbound.
  local issue=$1 state body parent

  state="$(gh issue view "$issue" --json state --jq .state)"
  if [ "$state" = "CLOSED" ]; then
    printf 'detach: issue #%s is closed; detach only applies to open tickets\n' \
      "$issue" >&2
    return 1
  fi

  body="$(issue_body "$issue")"
  parent="$(printf '%s' "$body" | bash "$PARSE" parent)"
  if [ -z "$parent" ]; then
    printf 'detach: issue #%s has no parseable parent; nothing to detach\n' \
      "$issue" >&2
    return 1
  fi

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  # Validate the label read before preserving the edge in a comment or
  # removing it from the body. A process substitution would hide gh's exit
  # status from the enclosing while loop and could leave stale labels.
  gh issue view "$issue" --json labels > "$tmpdir/labels.json"
  jq -e '.labels | type == "array"' "$tmpdir/labels.json" > /dev/null
  jq -r '.labels[].name' "$tmpdir/labels.json" > "$tmpdir/labels.txt"
  # The comment is posted before the body/label edit, not after: it is the
  # only surviving record of the former-parent edge once the edit removes
  # the "## Parent" section, so a step that can fail must not run after the
  # step it is the sole record of. Reversed, a comment failure would leave
  # the ticket silently detached with no trace of what it detached from; this
  # way, an edit failure after a successful comment leaves an inert stray
  # comment on an otherwise unchanged ticket — safe to retry.
  printf 'Detached from #%s.\n' "$parent" > "$tmpdir/comment.md"
  gh issue comment "$issue" --body-file "$tmpdir/comment.md"
  printf '%s' "$body" | bash "$PARSE" strip-section Parent > "$tmpdir/body.md"
  local -a edit_args=(--body-file "$tmpdir/body.md" --add-label backlog)
  local label
  while IFS= read -r label; do
    case "$label" in
      ready-for-agent|ready-for-human|priority:high|priority:normal|priority:low|spec:*)
        edit_args+=(--remove-label "$label") ;;
    esac
  done < "$tmpdir/labels.txt"
  gh issue edit "$issue" "${edit_args[@]}"
}

# Writes one combined deliveries file (verified child facts plus the ADR-touch
# column, with no tag column) across every open spec-labeled issue that
# actually declares an ADR obligation to <out-file>. resolve.sh's verdict
# never consults a child's delivery unless the spec itself declared an
# obligation, so scoping the lookup the same way means a project with no such
# spec — the common case — never has to configure ADDW_ADR_DIR at all, and
# specs with nothing promised never pay for a delivery lookup they cannot
# affect.
#
# An optional third argument scopes the whole gather to one spec — spec-
# complete's single-target query passes its own number so that some other
# obligated spec's unresolvable merge commit (a shallow or stale clone) can
# never fail a query about a spec it has nothing to do with; specs and
# frontier omit it, since they answer for every open spec at once.
gather_deliveries() { # issues.json out-file [only-spec]
  local file=$1 out=$2 only=${3:-} spec body obligation
  : > "$out"
  local specs obligated=()
  specs="$(jq -r '.[] | select(.state == "OPEN") | select(any(.labels[]?; .name == "spec")) | .number' "$file")"
  [ -n "$specs" ] || return 0
  while IFS= read -r spec; do
    [ -z "$only" ] || [ "$spec" = "$only" ] || continue
    body="$(jq -r --arg n "$spec" '.[] | select((.number | tostring) == $n) | .body // ""' "$file")"
    obligation="$(printf '%s' "$body" | bash "$PARSE" adr-obligation)"
    [ -z "$obligation" ] || obligated+=("$spec")
  done <<< "$specs"
  [ "${#obligated[@]}" -gt 0 ] || return 0
  resolve_adr_dir
  for spec in "${obligated[@]}"; do
    child_facts "$spec" "$file" | project_delivery adr_touched >> "$out"
  done
}

# Appends <projection>'s answer for each completed line's merge commit
# (column 4) to a child_facts stream; other lines pass through unchanged.
project_delivery() { # projection-function
  local line
  local -a fields

  while IFS= read -r line; do
    IFS=$'\t' read -r -a fields <<< "$line"
    if [ "${fields[1]:-}" = completed ]; then
      printf '%s\t%s\n' "$line" "$("$1" "${fields[3]}")"
    else
      printf '%s\n' "$line"
    fi
  done
}

child_facts() { # spec-number issues.json
  local spec=$1 file=$2 num state reason b64 body parent status pr_line pr sha

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
    # Verified before either git read trusts it: a commit this checkout
    # cannot see (a shallow or stale clone) must not read as a quiet "no" /
    # "unreleased" — that would misrepresent a fact this command couldn't
    # actually check.
    if ! git cat-file -e "${sha}^{commit}" 2>/dev/null; then
      printf 'tracker.sh: #%s: merge commit %s (PR #%s) is not in this checkout — fetch full history and retry\n' \
        "$num" "$sha" "$pr" >&2
      return 1
    fi
    printf '#%s\tcompleted\t#%s\t%s\n' "$num" "$pr" "$sha"
  done < <(jq -r 'sort_by(.number)[] |
      [(.number | tostring), .state, (.stateReason // ""), (.body // "" | @base64)]
      | join("")' "$file")
}

child_delivery() { # spec-number issues.json
  child_facts "$1" "$2" |
    project_delivery adr_touched |
    project_delivery first_tag
}

# Closes spec <n> as completed, refusing unless its verdict is `complete`.
# tmpdir is deliberately not `local`, matching detach's own reasoning: its
# cleanup trap fires on the whole process's EXIT, after this function's
# locals have gone out of scope.
close_spec() { # spec-number
  local spec=$1 rc=0 out verdict record num status pr rest

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  snapshot > "$tmpdir/issues.json"
  gather_deliveries "$tmpdir/issues.json" "$tmpdir/deliveries.txt" "$spec"

  out="$(bash "$RESOLVE" spec-complete "$spec" "$tmpdir/issues.json" "$tmpdir/deliveries.txt")" || rc=$?
  [ "$rc" -ne 2 ] || return 2

  verdict="$(printf '%s\n' "$out" | head -n 1)"
  if [ "$verdict" != complete ]; then
    printf 'close-spec: #%s is %s, not complete; refusing\n' "$spec" "$verdict" >&2
    if [ "$verdict" = partial ] || [ "$verdict" = planned ]; then
      printf '%s\n' "$out" | tail -n +2 | awk -F'\t' '$1 == "open"' >&2
    fi
    return 1
  fi

  if [ -s "$tmpdir/deliveries.txt" ]; then
    record="$(project_delivery first_tag < "$tmpdir/deliveries.txt")"
  else
    record="$(child_facts "$spec" "$tmpdir/issues.json" | project_delivery first_tag)"
  fi

  {
    printf 'Closing as Complete.\n\n'
    # The tag is the last field: an obligated spec's record also carries the
    # ADR column before it.
    while IFS=$'\t' read -r num status pr rest; do
      [ -n "$num" ] || continue
      case "$status" in
        abandoned) printf -- '- %s: abandoned\n' "$num" ;;
        no-pr) printf -- '- %s: closed completed, no tracked PR\n' "$num" ;;
        completed) printf -- '- %s: %s (%s)\n' "$num" "$pr" "${rest##*$'\t'}" ;;
      esac
    done <<< "$record"
  } > "$tmpdir/comment.md"

  gh issue close "$spec" --reason completed --comment "$(cat "$tmpdir/comment.md")"
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
  contract)
    [ "$#" -eq 1 ] || usage
    case "$1" in *[!0-9]*|'') usage ;; esac
    contract "$1"
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
    label_ticket "$1" "$2"
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
  detach)
    [ "$#" -eq 1 ] || usage
    detach "$1"
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
    # One --label per label. Resolve parent membership before creating: a
    # failed lookup must never leave a partially classified new issue.
    resolved_labels="$(creation_labels "$body_file" "$@")"
    label_args=()
    while IFS= read -r label; do
      [ -n "$label" ] || continue
      label_args+=(--label "$label")
    done <<< "$resolved_labels"
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
    config_source ADDW_SPEC_LABELS ADDW_HIGH_SEVERITY_BUG_QUEUE ADDW_FOCUS_SPEC
    : > "$tmpdir/bug-queue.md"
    if [ -n "${ADDW_HIGH_SEVERITY_BUG_QUEUE:-}" ]; then
      issue_body "$ADDW_HIGH_SEVERITY_BUG_QUEUE" > "$tmpdir/bug-queue.md"
    fi
    set +e
    (
      set -e
      gather_deliveries "$tmpdir/issues.json" "$tmpdir/deliveries.txt"
    ) 2> "$tmpdir/gather.err"
    rc=$?
    set -e
    branches > "$tmpdir/branches.txt"
    if [ "$rc" -eq 0 ]; then
      ADDW_HIGH_SEVERITY_BUG_QUEUE="${ADDW_HIGH_SEVERITY_BUG_QUEUE:-}" ADDW_SPEC_LABELS="${ADDW_SPEC_LABELS:-}" ADDW_FOCUS_SPEC="${ADDW_FOCUS_SPEC:-}" \
        bash "$RESOLVE" frontier "$tmpdir/issues.json" "$tmpdir/branches.txt" "$tmpdir/deliveries.txt" "$tmpdir/bug-queue.md"
    else
      diag="$(awk 'NR > 1 { printf "; " } { printf "%s", $0 } END { if (NR > 0) printf "\n" }' \
        "$tmpdir/gather.err")"
      [ -n "$diag" ] || diag="delivery gathering exited $rc"
      ADDW_HIGH_SEVERITY_BUG_QUEUE="${ADDW_HIGH_SEVERITY_BUG_QUEUE:-}" ADDW_SPEC_LABELS="${ADDW_SPEC_LABELS:-}" ADDW_FOCUS_SPEC="${ADDW_FOCUS_SPEC:-}" \
        bash "$RESOLVE" frontier --specs-unavailable "$diag" \
          "$tmpdir/issues.json" "$tmpdir/branches.txt" '' "$tmpdir/bug-queue.md"
    fi
    ;;
  spec-complete)
    [ "$#" -eq 1 ] || usage
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    snapshot > "$tmpdir/issues.json"
    gather_deliveries "$tmpdir/issues.json" "$tmpdir/deliveries.txt" "$1"
    bash "$RESOLVE" spec-complete "$1" "$tmpdir/issues.json" "$tmpdir/deliveries.txt"
    ;;
  specs)
    [ "$#" -eq 0 ] || usage
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    snapshot > "$tmpdir/issues.json"
    gather_deliveries "$tmpdir/issues.json" "$tmpdir/deliveries.txt"
    bash "$RESOLVE" specs "$tmpdir/issues.json" "$tmpdir/deliveries.txt"
    ;;
  child-delivery)
    [ "$#" -eq 1 ] || usage
    case "$1" in *[!0-9]*|'') usage ;; esac
    resolve_adr_dir
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    snapshot > "$tmpdir/issues.json"
    child_delivery "$1" "$tmpdir/issues.json"
    ;;
  close-spec)
    [ "$#" -eq 1 ] || usage
    case "$1" in *[!0-9]*|'') usage ;; esac
    close_spec "$1"
    ;;
  *)
    usage
    ;;
esac

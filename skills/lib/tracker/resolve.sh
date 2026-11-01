#!/usr/bin/env bash
# Pure frontier and spec-completion resolution over an issue snapshot — no
# network, no tracker CLI. The snapshot is the gh --json shape (number, title,
# state, stateReason, labels, assignees, body), produced live by tracker.sh or
# checked in as a fixture. Optional nativeBlockers holds REST dependency
# records (number, title, state, state_reason, html_url). Body and native
# blockers form a union by URL; missing nativeBlockers means none.
# Bodies go through parse.sh, which owns the body edge
# semantics; a blocker or child closed for any reason other than completed or
# not-planned refuses loudly (exit 2) rather than guessing an edge.
#
# Usage:
#   resolve.sh frontier <issues.json> [branches-file] [deliveries-file] [bug-queue-body]
#   resolve.sh frontier --specs-unavailable <diag> <issues.json> [branches-file]
#   resolve.sh eligible <issue-number> <issues.json> [bug-queue-body]
#   resolve.sh spec-complete <spec-number> <issues.json> [deliveries-file]
#   resolve.sh specs <issues.json> [deliveries-file]
#
# frontier prints agent-ready and human-ready in priority order, then blocked
# high-severity bugs with their open blockers, the diagnostics below, and
# complete-specs. The tracker supplies body dependencies and the optional maintained
# bug queue; fixture callers can supply the same inputs as files.
#   frontier:            open, unblocked ready-for-agent tickets
#   human-ready:         open, unblocked ready-for-human tickets
#   high-severity-bugs-waiting: high-priority bugs with open blockers
#   needs-rescoping:     dependents of a blocker closed as not planned
#   unknown-blockers:    dependents whose blocker state cannot be resolved
#   label-corrections:   missing/conflicting priority or spec labels
#   complete-specs:      open spec-labeled issues whose verdict is `complete`
#                        after folding in any declared ADR obligation, each
#                        line naming the close command:
#                        #N<TAB>title<TAB>tracker.sh close-spec N
# The branch annotation matches whatever heads the caller passes in, which
# ../README.md's contract fixes as the remote ones. Where a repo keeps merged
# branches, the annotation outlives the work — harmless for the ticket the PR
# closed (closed tickets never reach the listing), stale only for one left open
# afterwards.
# `frontier --specs-unavailable` prints the ticket and diagnostic sections, skips
# open spec-labeled issues, then prints one `complete-specs: unavailable — <diag>`
# line in place of that section and exits 3.
# When one ticket has blockers in several states, the loudest wins the
# listing: unknown over not-planned over open (an open blocker excludes
# silently, except high-severity bugs surfaced in Waiting).
#
# eligible prints eligible (exit 0) only for an open agent-ready ticket with
# valid signals and all effective blockers completed. Otherwise it prints a
# diagnostic (exit 1). Malformed input or unsupported close reasons refuse
# the query, as they do for frontier. No branch or delivery input is needed.
#
# spec-complete prints the four-way verdict — complete, partial, planned, or
# no-children — as its first line (exit 0 iff complete), folding a declared ADR
# obligation into that verdict using the optional deliveries file. It then
# prints one <completed|open|not-planned><TAB>#N<TAB><title> line per child (no
# lines for a childless spec — the verdict line already says so). A number that
# is not a spec-labeled issue in the snapshot exits 2.
#
# specs prints one <#N><TAB><verdict><TAB><title> line per open spec-labeled
# issue in the snapshot, ascending by issue number; each verdict folds in a
# declared ADR obligation from the optional deliveries file. A `complete`
# line carries a fourth field naming the close command:
#   #N<TAB>complete<TAB>title<TAB>tracker.sh close-spec N
set -euo pipefail

if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  printf 'resolve.sh: requires bash >= 4 (associative arrays); this is %s\n' \
    "$BASH_VERSION" >&2
  exit 1
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSE="$here/parse.sh"

usage() {
  sed -n 's/^# \{0,1\}//p' "${BASH_SOURCE[0]}" | sed -n '/^Usage:/,/^$/p' >&2
  exit 2
}

declare -A STATE REASON TITLE LABELS ASSIGNEES PARENT BLOCKERS OBLIGATION DELIVERY_ADR URL QUEUE_POS SPEC_MAP NATIVE_KEYS NATIVE_STATE NATIVE_REASON NATIVE_TITLE NATIVE_NUMBER
NUMBERS=()

load_snapshot() { # issues.json
  local snapshot=$1 num parent blockers obligation state reason labels logins title url
  if [ ! -r "$snapshot" ]; then
    printf 'resolve.sh: cannot read snapshot: %s\n' "$snapshot" >&2
    exit 1
  fi
  if ! jq -e 'type == "array" and all(.[];
      (.nativeBlockers // []) | type == "array" and all(.[];
        (.number | type == "number") and (.title | type == "string") and
        (.html_url | type == "string" and test("^https?://[^[:space:]]+$")) and
        (.state == null or (.state | type == "string")) and
        (.state_reason == null or (.state_reason | type == "string"))))' "$snapshot" >/dev/null 2>&1; then
    printf 'resolve.sh: invalid snapshot or native blocker records: %s\n' "$snapshot" >&2
    exit 1
  fi
  # One jq pass frames each issue as an H header followed by B-prefixed body
  # lines. parse.sh edges extracts all three edge facts in one awk pass and
  # carries the header fields after them so the queries never rescan the
  # snapshot. The separator is the ASCII unit separator, not @tsv, because
  # tab is IFS whitespace and read would collapse the empty stateReason /
  # assignees fields, shifting every later field left.
  while IFS=$'\x1f' read -r num parent blockers obligation state reason labels logins title url; do
    NUMBERS+=("$num")
    PARENT[$num]=$parent
    BLOCKERS[$num]=$blockers
    OBLIGATION[$num]=$obligation
    STATE[$num]=$state
    REASON[$num]=$reason
    LABELS[$num]=",$labels,"
    ASSIGNEES[$num]=$logins
    TITLE[$num]=$title
    URL[$num]=$url
  done < <(
    jq -r '
      sort_by(.number)[] |
      ("H" + ([
        (.number | tostring), .state, (.stateReason // ""),
        ([.labels[].name] | join(",")), ([.assignees[].login] | join(",")),
        .title, (.url // "")
      ] | join("\u001f"))),
      ((.body // "") | tostring | split("\n")[] | "B" + .)
    ' "$snapshot" | bash "$PARSE" edges
  )
  local owner key native_url native_num native_title native_state native_reason
  while IFS=$'\x1f' read -r owner native_url native_num native_title native_state native_reason; do
    key="$owner:$native_url"
    if [ -z "${NATIVE_STATE[$key]+set}" ]; then
      NATIVE_KEYS[$owner]="${NATIVE_KEYS[$owner]:-} $native_url"
    fi
    NATIVE_STATE[$key]=$native_state
    NATIVE_REASON[$key]=$native_reason
    NATIVE_TITLE[$key]=$native_title
    NATIVE_NUMBER[$key]=$native_num
  done < <(
    jq -r '.[] | .number as $owner | .nativeBlockers[]? |
      [$owner, .html_url, .number, .title, (.state // "" | ascii_upcase),
       (.state_reason // "" | ascii_upcase)] |
      map(tostring | gsub("[\u0000-\u001f]"; " ")) | join("\u001f")' "$snapshot"
  )
}

load_signals() { # [queue-body]
  local entry number label queue=${1:-} position=0 line ref section=""
  for entry in ${ADDW_SPEC_LABELS:-}; do
    number=${entry%%=*}; label=${entry#*=}
    SPEC_MAP[$number]=$label
  done
  [ -z "$queue" ] || [ -r "$queue" ] || { printf 'resolve.sh: cannot read bug queue: %s\n' "$queue" >&2; exit 1; }
  [ -n "$queue" ] || return 0
  while IFS= read -r line; do
    case "$line" in
      '## Ordered bugs') section=ordered; continue ;;
      '## '*) section=""; continue ;;
    esac
    [ "$section" = ordered ] || continue
    [[ "$line" =~ ^[0-9]+\.\  ]] || continue
    if [[ "$line" =~ /issues/([0-9]+) ]]; then
      ref=${BASH_REMATCH[1]}
      position=$((position + 1))
      QUEUE_POS[$ref]=$position
    fi
  done < "$queue"
}

signal_issue() { # issue-number; sets priority, spec and diagnostic globals
  local n=$1 label count=0 spec_count=0 actual_spec="" expected="" parent=${PARENT[$1]}
  SIGNAL_PRIORITY="" SIGNAL_SPEC="" SIGNAL_DIAG=""
  local -a split_labels
  IFS=, read -r -a split_labels <<< "${LABELS[$n]#,}"
  for label in "${split_labels[@]}"; do
    case "$label" in
      priority:high|priority:normal|priority:low) count=$((count + 1)); SIGNAL_PRIORITY=$label ;;
      spec:*) spec_count=$((spec_count + 1)); actual_spec=$label ;;
    esac
  done
  if [ "$count" -ne 1 ]; then
    SIGNAL_DIAG="priority labels: $count (expected one)"
    if [ "$count" -eq 0 ]; then SIGNAL_PRIORITY=priority:missing; else SIGNAL_PRIORITY=priority:conflict; fi
  fi
  if [ -n "$parent" ] && [ "${STATE[$parent]:-}" = OPEN ] && has_label "$parent" spec; then
    expected=${SPEC_MAP[$parent]:-}
    if [ -z "$expected" ] && [ -n "${ADDW_SPEC_LABELS:-}" ]; then
      SIGNAL_DIAG="${SIGNAL_DIAG:+$SIGNAL_DIAG; }open parent #$parent has no spec label mapping"
    fi
  fi
  if [ -n "${ADDW_SPEC_LABELS:-}" ] && { [ "$spec_count" -gt 1 ] || [ "$actual_spec" != "$expected" ]; }; then
    SIGNAL_DIAG="${SIGNAL_DIAG:+$SIGNAL_DIAG; }spec labels: ${actual_spec:-none} (expected ${expected:-none})"
  fi
  SIGNAL_SPEC=$actual_spec
}

load_deliveries() { # [deliveries-file]
  local deliveries="${1:-}" child_num
  local -a fields
  DELIVERY_ADR=()
  [ -n "$deliveries" ] && [ -s "$deliveries" ] || return 0

  while IFS=$'\t' read -r -a fields; do
    [ "${fields[1]:-}" = completed ] || continue
    case "${fields[0]:-}:${fields[4]:-}" in
      \#[0-9]*:yes|\#[0-9]*:no)
        child_num=${fields[0]#\#}
        DELIVERY_ADR[$child_num]=${fields[4]}
        ;;
    esac
  done < "$deliveries"
}

has_label() { # num label
  case "${LABELS[$1]}" in
    *",$2,"*) return 0 ;;
    *) return 1 ;;
  esac
}

# classify prints completed | not-planned; parse.sh exits 2 on anything else.
# Call sites append "|| exit $?" so the refusal stays loud even where an
# if-condition or command substitution would otherwise swallow set -e.
classify() { # num
  bash "$PARSE" classify-reason "${REASON[$1]}"
}

# Body references use their repository URL when available, so the same edge
# recorded natively is scanned once. External issues sharing a number differ.
blocker_identity() { # dependent-number blocker-number; sets BLOCKER_KEY
  BLOCKER_KEY=${URL[$2]:-}
  if [ -z "$BLOCKER_KEY" ]; then
    case "${URL[$1]:-}" in
      */issues/*) BLOCKER_KEY="${URL[$1]%/issues/*}/issues/$2" ;;
      *) BLOCKER_KEY="#$2" ;;
    esac
  fi
}

# Shared by frontier and explicit pickup. Native state can resolve a body edge
# absent from the bounded snapshot. Diagnostic precedence is decided by callers.
blocker_scan() { # dependent-number; sets BLOCKER_UNKNOWN/NOTPLANNED/OPEN
  local n=$1 b key edge state reason title url number label native
  local -a keys=()
  local -A seen=() body_numbers=()
  BLOCKER_UNKNOWN="" BLOCKER_NOTPLANNED="" BLOCKER_OPEN=""
  for b in ${BLOCKERS[$n]}; do
    blocker_identity "$n" "$b"
    key=$BLOCKER_KEY
    body_numbers[$key]=$b
    [ -z "${seen[$key]+set}" ] || continue
    seen[$key]=yes
    keys+=("$key")
  done
  for key in ${NATIVE_KEYS[$n]:-}; do
    [ -z "${seen[$key]+set}" ] || continue
    seen[$key]=yes
    keys+=("$key")
  done
  for key in "${keys[@]}"; do
    edge="$n:$key"
    native=no
    if [ -n "${NATIVE_STATE[$edge]+set}" ]; then
      native=yes
      state=${NATIVE_STATE[$edge]}
      reason=${NATIVE_REASON[$edge]}
      title=${NATIVE_TITLE[$edge]}
      number=${NATIVE_NUMBER[$edge]}
      url=$key
      label=$url
    else
      b=${body_numbers[$key]}
      state=${STATE[$b]:-}
      reason=${REASON[$b]:-}
      title=${TITLE[$b]:-}
      number=$b
      url=${URL[$b]:-}
      label="#$b"
    fi
    case "$state" in
      OPEN)
        BLOCKER_OPEN="${BLOCKER_OPEN}${BLOCKER_OPEN:+, }[$number: $title]($url)"
        ;;
      CLOSED)
        case "$reason" in
          COMPLETED) ;;
          NOT_PLANNED) [ -n "$BLOCKER_NOTPLANNED" ] || BLOCKER_NOTPLANNED=$label ;;
          *)
            if [ "$native" = no ]; then classify "$b" >/dev/null || exit $?; fi
            [ -n "$BLOCKER_UNKNOWN" ] || BLOCKER_UNKNOWN="blocker $label has unknown close reason"
            ;;
        esac
        ;;
      *)
        if [ "$native" = no ]; then
          [ -n "$BLOCKER_UNKNOWN" ] || BLOCKER_UNKNOWN="blocker $label not in snapshot"
        else
          [ -n "$BLOCKER_UNKNOWN" ] || BLOCKER_UNKNOWN="blocker $label has unknown state"
        fi
        ;;
    esac
  done
}

# One pass over spec $1's children, classifying each closed one exactly once.
# Sets two globals: SPEC_VERDICT (complete | partial | planned | no-children)
# and SPEC_CHILD_LINES (an array of "<status>\t#<n>\t<title>" entries, empty
# for a childless spec). A not-planned child counts as closed: it neither
# delivers nor holds a spec open. A declared ADR obligation additionally needs
# one child delivery marked yes, even when every child is closed. Runs in the
# caller's shell (never inside a command substitution) so both globals survive.
spec_scan() { # num
  local spec=$1 n count=0 has_open=0 has_completed=0 adr_satisfied=1 status
  [ -n "${OBLIGATION[$spec]:-}" ] && adr_satisfied=0
  SPEC_CHILD_LINES=()
  for n in "${NUMBERS[@]}"; do
    [ "${PARENT[$n]}" = "$spec" ] || continue
    count=$((count + 1))
    if [ "${DELIVERY_ADR[$n]:-}" = yes ]; then
      adr_satisfied=1
    fi
    if [ "${STATE[$n]}" = "OPEN" ]; then
      status=open
      has_open=1
    else
      status="$(classify "$n")" || exit $?
      [ "$status" = "completed" ] && has_completed=1
    fi
    SPEC_CHILD_LINES+=("$(printf '%s\t#%s\t%s' "$status" "$n" "${TITLE[$n]}")")
  done
  if [ "$count" -eq 0 ]; then
    SPEC_VERDICT=no-children
  elif [ "$has_open" -eq 0 ]; then
    if [ "$adr_satisfied" -eq 1 ]; then
      SPEC_VERDICT=complete
    else
      SPEC_VERDICT=partial
    fi
  elif [ "$has_completed" -eq 1 ]; then
    SPEC_VERDICT=partial
  else
    SPEC_VERDICT=planned
  fi
}

frontier() { # [--specs-unavailable diag] issues.json [branches-file] [deliveries-file] [bug-queue-body]
  local specs_unavailable=no diag=""
  if [ "${1:-}" = --specs-unavailable ]; then
    specs_unavailable=yes
    diag=$2
    shift 2
  fi
  local branches="${2:-}"
  local deliveries="${3:-}"
  load_snapshot "$1"
  load_signals "${4:-}"
  [ "$specs_unavailable" = yes ] || load_deliveries "$deliveries"
  if [ -n "$branches" ] && [ ! -r "$branches" ]; then
    printf 'resolve.sh: cannot read branches file: %s\n' "$branches" >&2
    exit 1
  fi

  local agent_lines=() human_lines=() waiting_lines=() rescope_lines=() unknown_lines=() spec_lines=() signal_lines=()
  local n line ann branch ready priority_rank queue_rank focus_rank order_key marker
  for n in "${NUMBERS[@]}"; do
    [ "${STATE[$n]}" = "OPEN" ] || continue

    if has_label "$n" spec; then
      [ "$specs_unavailable" = yes ] && continue
      spec_scan "$n"
      if [ "$SPEC_VERDICT" = complete ]; then
        spec_lines+=("$(printf '#%s\t%s\ttracker.sh close-spec %s' "$n" "${TITLE[$n]}" "$n")")
      fi
      continue
    fi

    ready=""
    if has_label "$n" ready-for-agent; then ready=agent; fi
    if has_label "$n" ready-for-human; then
      if [ -n "$ready" ]; then signal_lines+=("$(printf '#%s\tconflicting readiness labels' "$n")"); continue; fi
      ready=human
    fi
    [ -n "$ready" ] || continue
    if has_label "$n" backlog; then continue; fi
    case "${LABELS[$n]}" in *,wayfinder:*) continue ;; esac
    signal_issue "$n"
    [ -z "$SIGNAL_DIAG" ] || signal_lines+=("$(printf '#%s\t%s' "$n" "$SIGNAL_DIAG")")

    blocker_scan "$n"
    if [ -n "$BLOCKER_UNKNOWN" ]; then
      unknown_lines+=("$(printf '#%s\t%s\t[%s]' "$n" "${TITLE[$n]}" "$BLOCKER_UNKNOWN")")
    elif [ -n "$BLOCKER_NOTPLANNED" ]; then
      rescope_lines+=("$(printf '#%s\t%s\t[blocker %s closed as not planned]' "$n" "${TITLE[$n]}" "$BLOCKER_NOTPLANNED")")
    elif [ -n "$BLOCKER_OPEN" ]; then
      if has_label "$n" bug && has_label "$n" priority:high; then
        waiting_lines+=("$(printf '#%s\t%s\t%s' "$n" "${TITLE[$n]}" "$BLOCKER_OPEN")")
      fi
      continue
    else
      if has_label "$n" bug && [ "$SIGNAL_PRIORITY" = priority:high ] && [ -n "${ADDW_HIGH_SEVERITY_BUG_QUEUE:-}" ] && [ -z "${QUEUE_POS[$n]:-}" ]; then
        signal_lines+=("$(printf '#%s\thigh-severity bug missing from ordered bug queue' "$n")")
      fi
      ann=""
      if [ -n "$branches" ]; then
        branch="$(grep -m1 -E "(^|/)${n}-" "$branches" || true)"
        [ -z "$branch" ] || ann="$(printf '\t[in progress: branch %s]' "$branch")"
      fi
      if [ -z "$ann" ] && [ -n "${ASSIGNEES[$n]}" ]; then
        ann="$(printf '\t[in progress: assignee %s]' "${ASSIGNEES[$n]}")"
      fi
      marker=""
      has_label "$n" bug && marker=' BUG'
      case "$SIGNAL_PRIORITY" in
        priority:high) priority_rank=0 ;;
        priority:normal) priority_rank=1 ;;
        priority:low) priority_rank=2 ;;
        *) priority_rank=3 ;;
      esac
      queue_rank=99999
      if [ "$priority_rank" -eq 0 ] && has_label "$n" bug; then
        queue_rank=${QUEUE_POS[$n]:-99999}
      fi
      focus_rank=1
      if [ "$priority_rank" -eq 1 ] && [ -n "${ADDW_FOCUS_SPEC:-}" ] && [ "${PARENT[$n]}" = "$ADDW_FOCUS_SPEC" ]; then focus_rank=0; fi
      order_key="$(printf '%d\t%05d\t%d\t%05d' "$priority_rank" "$queue_rank" "$focus_rank" "$n")"
      line="$(printf '%s\t%s\t#%s\t%s%s%s%s' "$order_key" "${SIGNAL_PRIORITY:-priority:missing}" "$n" "${TITLE[$n]}" "$marker" "${SIGNAL_SPEC:+ [$SIGNAL_SPEC]}" "$ann")"
      if [ "$ready" = agent ]; then agent_lines+=("$line"); else human_lines+=("$line"); fi
    fi
  done

  print_section frontier: "$(printf '%s\n' "${agent_lines[@]:-}" | sort -t $'\t' -k1,1n -k2,2n -k3,3n -k4,4n | cut -f5-)"
  print_section human-ready: "$(printf '%s\n' "${human_lines[@]:-}" | sort -t $'\t' -k1,1n -k2,2n -k3,3n -k4,4n | cut -f5-)"
  print_section high-severity-bugs-waiting: "${waiting_lines[@]:-}"
  print_section needs-rescoping: "${rescope_lines[@]:-}"
  print_section unknown-blockers: "${unknown_lines[@]:-}"
  print_section label-corrections: "${signal_lines[@]:-}"
  if [ "$specs_unavailable" = yes ]; then
    printf 'complete-specs: unavailable — %s\n' "$diag"
    return 3
  fi
  print_section complete-specs: "${spec_lines[@]:-}"
}

eligible() { # issue-number issues.json [bug-queue-body]
  local n=$1
  load_snapshot "$2"
  load_signals "${3:-}"
  if [ "${STATE[$n]:-}" != OPEN ] || ! has_label "$n" ready-for-agent ||
      has_label "$n" ready-for-human || has_label "$n" spec || has_label "$n" backlog; then
    printf '#%s: not an open agent-ready implementation ticket\n' "$n"
    return 1
  fi
  case "${LABELS[$n]}" in
    *,wayfinder:*) printf '#%s: wayfinder work is not an implementation ticket\n' "$n"; return 1 ;;
  esac
  signal_issue "$n"
  if [ -n "$SIGNAL_DIAG" ]; then
    printf '#%s: %s\n' "$n" "$SIGNAL_DIAG"
    return 1
  fi
  blocker_scan "$n"
  if [ -n "$BLOCKER_UNKNOWN" ]; then
    printf '#%s: %s\n' "$n" "$BLOCKER_UNKNOWN"
  elif [ -n "$BLOCKER_NOTPLANNED" ]; then
    printf '#%s: blocker %s closed as not planned; needs rescoping\n' "$n" "$BLOCKER_NOTPLANNED"
  elif [ -n "$BLOCKER_OPEN" ]; then
    printf '#%s: open blockers: %s\n' "$n" "$BLOCKER_OPEN"
  elif has_label "$n" bug && [ "$SIGNAL_PRIORITY" = priority:high ] &&
      [ -n "${ADDW_HIGH_SEVERITY_BUG_QUEUE:-}" ] && [ -z "${QUEUE_POS[$n]:-}" ]; then
    printf '#%s: high-severity bug missing from ordered bug queue\n' "$n"
  else
    printf 'eligible\n'
    return 0
  fi
  return 1
}

print_section() { # header [lines...]
  printf '%s\n' "$1"
  shift
  local line
  for line in "$@"; do
    [ -n "$line" ] && printf '%s\n' "$line"
  done
  return 0
}

spec_complete() { # spec-number issues.json [deliveries-file]
  local spec=$1
  load_snapshot "$2"
  load_deliveries "${3:-}"
  if [ -z "${STATE[$spec]:-}" ] || ! has_label "$spec" spec; then
    printf 'resolve.sh: #%s is not a spec-labeled issue in the snapshot\n' "$spec" >&2
    exit 2
  fi
  spec_scan "$spec"
  printf '%s\n' "$SPEC_VERDICT"
  local line
  for line in "${SPEC_CHILD_LINES[@]:-}"; do
    [ -n "$line" ] && printf '%s\n' "$line"
  done
  [ "$SPEC_VERDICT" = complete ]
}

specs() { # issues.json [deliveries-file]
  load_snapshot "$1"
  load_deliveries "${2:-}"
  local n
  for n in "${NUMBERS[@]}"; do
    [ "${STATE[$n]}" = "OPEN" ] || continue
    has_label "$n" spec || continue
    spec_scan "$n"
    if [ "$SPEC_VERDICT" = complete ]; then
      printf '#%s\t%s\t%s\ttracker.sh close-spec %s\n' "$n" "$SPEC_VERDICT" "${TITLE[$n]}" "$n"
    else
      printf '#%s\t%s\t%s\n' "$n" "$SPEC_VERDICT" "${TITLE[$n]}"
    fi
  done
}

[ "$#" -ge 1 ] || usage
cmd=$1
shift

case "$cmd" in
  eligible)
    [ "$#" -eq 2 ] || [ "$#" -eq 3 ] || usage
    case "$1" in *[!0-9]*|'') usage ;; esac
    eligible "$@"
    ;;
  frontier)
    if [ "${1:-}" = --specs-unavailable ]; then
      [ "$#" -ge 3 ] && [ "$#" -le 6 ] || usage
    elif [[ "${1:-}" == --* ]]; then
      usage
    else
      [ "$#" -ge 1 ] && [ "$#" -le 4 ] || usage
    fi
    frontier "$@"
    ;;
  spec-complete)
    [ "$#" -eq 2 ] || [ "$#" -eq 3 ] || usage
    case "$1" in *[!0-9]*|'') usage ;; esac
    spec_complete "$@"
    ;;
  specs)
    [ "$#" -eq 1 ] || [ "$#" -eq 2 ] || usage
    specs "$@"
    ;;
  *)
    usage
    ;;
esac

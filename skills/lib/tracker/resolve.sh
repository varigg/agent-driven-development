#!/usr/bin/env bash
# Pure frontier and spec-completion resolution over an issue snapshot — no
# network, no tracker CLI. The snapshot is the gh --json shape (number, title,
# state, stateReason, labels, assignees, body), produced live by tracker.sh or
# checked in as a fixture. Bodies go through parse.sh, which owns the edge
# semantics; a blocker or child closed for any reason other than completed or
# not-planned refuses loudly (exit 2) rather than guessing an edge.
#
# Usage:
#   resolve.sh frontier <issues.json> [branches-file] [deliveries-file] [bug-queue-body]
#   resolve.sh frontier --specs-unavailable <diag> <issues.json> [branches-file]
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
#   unknown-blockers:    dependents of a blocker absent from the snapshot
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
# silently — waiting is the normal case).
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

declare -A STATE REASON TITLE LABELS ASSIGNEES PARENT BLOCKERS OBLIGATION DELIVERY_ADR URL QUEUE_POS SPEC_MAP
NUMBERS=()

load_snapshot() { # issues.json
  local snapshot=$1 num parent blockers obligation state reason labels logins title url
  if [ ! -r "$snapshot" ]; then
    printf 'resolve.sh: cannot read snapshot: %s\n' "$snapshot" >&2
    exit 1
  fi
  if ! jq -e 'type == "array"' "$snapshot" >/dev/null 2>&1; then
    printf 'resolve.sh: snapshot is not a JSON array: %s\n' "$snapshot" >&2
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
  local n b line ann branch ready priority_rank queue_rank focus_rank order_key open_blockers blocker_url marker
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

    local unknown_b="" notplanned_b="" open_seen="" class
    open_blockers=""
    for b in ${BLOCKERS[$n]}; do
      if [ -z "${STATE[$b]:-}" ]; then
        [ -n "$unknown_b" ] || unknown_b=$b
      elif [ "${STATE[$b]}" = "OPEN" ]; then
        open_seen=yes
        blocker_url=${URL[$b]:-}
        open_blockers="${open_blockers}${open_blockers:+, }[$b: ${TITLE[$b]}]($blocker_url)"
      else
        class="$(classify "$b")" || exit $?
        if [ "$class" = "not-planned" ] && [ -z "$notplanned_b" ]; then
          notplanned_b=$b
        fi
      fi
    done

    if [ -n "$unknown_b" ]; then
      unknown_lines+=("$(printf '#%s\t%s\t[blocker #%s not in snapshot]' "$n" "${TITLE[$n]}" "$unknown_b")")
    elif [ -n "$notplanned_b" ]; then
      rescope_lines+=("$(printf '#%s\t%s\t[blocker #%s closed as not planned]' "$n" "${TITLE[$n]}" "$notplanned_b")")
    elif [ -n "$open_seen" ]; then
      if has_label "$n" bug && has_label "$n" priority:high; then
        waiting_lines+=("$(printf '#%s\t%s\t%s' "$n" "${TITLE[$n]}" "$open_blockers")")
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

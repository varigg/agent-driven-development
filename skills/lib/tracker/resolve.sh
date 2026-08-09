#!/usr/bin/env bash
# Pure frontier and spec-completion resolution over an issue snapshot — no
# network, no tracker CLI. The snapshot is the gh --json shape (number, title,
# state, stateReason, labels, assignees, body), produced live by tracker.sh or
# checked in as a fixture. Bodies go through parse.sh, which owns the edge
# semantics; a blocker or child closed for any reason other than completed or
# not-planned refuses loudly (exit 2) rather than guessing an edge.
#
# Usage:
#   resolve.sh frontier <issues.json> [branches-file]
#   resolve.sh spec-complete <spec-number> <issues.json>
#
# frontier prints four fixed sections, headers always present, entries
# tab-separated and ascending by issue number:
#   frontier:            open ready-for-agent tickets (not spec/backlog) whose
#                        every blocker is closed as completed, annotated
#                        [in progress: branch <name>] or [in progress: assignee <login>]
#   needs-rescoping:     dependents of a blocker closed as not planned
#   unknown-blockers:    dependents of a blocker absent from the snapshot
#   release-ready-specs: open spec-labeled issues whose completion query passes
# The branch annotation matches whatever heads the caller passes in, which
# ../README.md's contract fixes as the remote ones. Where a repo keeps merged
# branches, the annotation outlives the work — harmless for the ticket the PR
# closed (closed tickets never reach the listing), stale only for one left open
# afterwards.
# When one ticket has blockers in several states, the loudest wins the
# listing: unknown over not-planned over open (an open blocker excludes
# silently — waiting is the normal case).
#
# spec-complete prints "release-ready" (exit 0) or "not-release-ready"
# (exit 1), then one <completed|open|not-planned><TAB>#N<TAB><title> line per
# child ("no-children" when decomposition hasn't happened). A number that is
# not a spec-labeled issue in the snapshot exits 2.
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

declare -A STATE REASON TITLE LABELS ASSIGNEES PARENT BLOCKERS
NUMBERS=()

load_snapshot() { # issues.json
  local snapshot=$1 num state reason labels logins b64 title body
  if [ ! -r "$snapshot" ]; then
    printf 'resolve.sh: cannot read snapshot: %s\n' "$snapshot" >&2
    exit 1
  fi
  if ! jq -e 'type == "array"' "$snapshot" >/dev/null 2>&1; then
    printf 'resolve.sh: snapshot is not a JSON array: %s\n' "$snapshot" >&2
    exit 1
  fi
  # One jq pass, one parse of each body: parent and blocker edges are indexed
  # here so the queries never rescan the snapshot. The body travels base64'd
  # to keep the record single-line; the separator is the ASCII unit separator,
  # not @tsv, because tab is IFS whitespace and read would collapse the empty
  # stateReason/assignees fields, shifting every later field left.
  while IFS=$'\x1f' read -r num state reason labels logins b64 title; do
    NUMBERS+=("$num")
    STATE[$num]=$state
    REASON[$num]=$reason
    LABELS[$num]=",$labels,"
    ASSIGNEES[$num]=$logins
    TITLE[$num]=$title
    body="$(printf '%s' "$b64" | base64 -d)"
    PARENT[$num]="$(printf '%s' "$body" | bash "$PARSE" parent)"
    BLOCKERS[$num]="$(printf '%s' "$body" | bash "$PARSE" blockers | tr '\n' ' ')"
  done < <(jq -r 'sort_by(.number)[] |
      [(.number | tostring), .state, (.stateReason // ""),
       ([.labels[].name] | join(",")), ([.assignees[].login] | join(",")),
       (.body // "" | @base64), .title] | join("\u001f")' "$snapshot")
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

# Child status lines for spec $1 on stdout; return 0 iff release-ready.
# Callers capturing via command substitution must forward exit 2 themselves
# (a subshell swallows the exit).
spec_children() { # num
  local spec=$1 n count=0 ready=0 status
  for n in "${NUMBERS[@]}"; do
    [ "${PARENT[$n]}" = "$spec" ] || continue
    count=$((count + 1))
    if [ "${STATE[$n]}" = "OPEN" ]; then
      status=open
      ready=1
    else
      status="$(classify "$n")" || exit $?
      [ "$status" = "completed" ] || ready=1
    fi
    printf '%s\t#%s\t%s\n' "$status" "$n" "${TITLE[$n]}"
  done
  if [ "$count" -eq 0 ]; then
    printf 'no-children\n'
    return 1
  fi
  return "$ready"
}

frontier() { # issues.json [branches-file]
  local branches="${2:-}"
  load_snapshot "$1"
  if [ -n "$branches" ] && [ ! -r "$branches" ]; then
    printf 'resolve.sh: cannot read branches file: %s\n' "$branches" >&2
    exit 1
  fi

  local frontier_lines=() rescope_lines=() unknown_lines=() spec_lines=()
  local n b line ann branch
  for n in "${NUMBERS[@]}"; do
    [ "${STATE[$n]}" = "OPEN" ] || continue

    if has_label "$n" spec; then
      if spec_children "$n" >/dev/null; then
        spec_lines+=("$(printf '#%s\t%s' "$n" "${TITLE[$n]}")")
      fi
      continue
    fi

    has_label "$n" ready-for-agent || continue
    if has_label "$n" backlog; then continue; fi

    local unknown_b="" notplanned_b="" open_seen="" class
    for b in ${BLOCKERS[$n]}; do
      if [ -z "${STATE[$b]:-}" ]; then
        [ -n "$unknown_b" ] || unknown_b=$b
      elif [ "${STATE[$b]}" = "OPEN" ]; then
        open_seen=yes
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
      continue
    else
      ann=""
      if [ -n "$branches" ]; then
        branch="$(grep -m1 -E "(^|/)${n}-" "$branches" || true)"
        [ -z "$branch" ] || ann="$(printf '\t[in progress: branch %s]' "$branch")"
      fi
      if [ -z "$ann" ] && [ -n "${ASSIGNEES[$n]}" ]; then
        ann="$(printf '\t[in progress: assignee %s]' "${ASSIGNEES[$n]}")"
      fi
      frontier_lines+=("$(printf '#%s\t%s%s' "$n" "${TITLE[$n]}" "$ann")")
    fi
  done

  print_section frontier: "${frontier_lines[@]:-}"
  print_section needs-rescoping: "${rescope_lines[@]:-}"
  print_section unknown-blockers: "${unknown_lines[@]:-}"
  print_section release-ready-specs: "${spec_lines[@]:-}"
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

spec_complete() { # spec-number issues.json
  local spec=$1
  load_snapshot "$2"
  if [ -z "${STATE[$spec]:-}" ] || ! has_label "$spec" spec; then
    printf 'resolve.sh: #%s is not a spec-labeled issue in the snapshot\n' "$spec" >&2
    exit 2
  fi
  local status=0 lines
  lines="$(spec_children "$spec")" || status=$?
  [ "$status" -le 1 ] || exit "$status"
  if [ "$status" -eq 0 ]; then
    printf 'release-ready\n'
  else
    printf 'not-release-ready\n'
  fi
  printf '%s\n' "$lines"
  return "$status"
}

[ "$#" -ge 1 ] || usage
cmd=$1
shift

case "$cmd" in
  frontier)
    [ "$#" -eq 1 ] || [ "$#" -eq 2 ] || usage
    frontier "$@"
    ;;
  spec-complete)
    [ "$#" -eq 2 ] || usage
    case "$1" in *[!0-9]*|'') usage ;; esac
    spec_complete "$@"
    ;;
  *)
    usage
    ;;
esac

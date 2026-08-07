#!/usr/bin/env bash
# Tracker-contract parsers: pure text-in/conclusion-out, no network, no gh.
# The section encoding is the to-tickets template — a level-2 "## Parent"
# section referencing the spec issue and a "## Blocked by" section listing
# blocking issues as list items (or the literal none-sentinel). Only list
# items carry edges; prose references are never extracted. The none-sentinel
# and an absent section both mean "no edges" and need no special-casing.
#
# Usage:
#   parse.sh parent [file]            -> spec issue number, or empty (exit 0)
#   parse.sh blockers [file]          -> blocker numbers one per line (exit 0)
#   parse.sh classify-reason <reason> -> "completed" | "not-planned" (else exit 2)
#
# parent/blockers read the issue body from <file> or stdin.
set -euo pipefail

usage() {
  sed -n 's/^# \{0,1\}//p' "${BASH_SOURCE[0]}" | sed -n '/^Usage:/,/^$/p' >&2
  exit 2
}

# Print every #N reference found in list items of the named level-2 section.
# A ref counts only when the "#" is not glued to a preceding word character,
# so "PR#12" and prose like "#99" outside list items never become edges.
section_refs() { # section-name
  awk -v want="$1" '
    /^#+[[:space:]]/ || /^#+$/ {
      heading = $0
      sub(/^#+[[:space:]]*/, "", heading)
      gsub(/[[:space:]]+$/, "", heading)
      insec = ($0 ~ /^##[^#]/) && (tolower(heading) == tolower(want))
      next
    }
    insec && /^[[:space:]]*[-*+][[:space:]]/ {
      rest = $0
      while (match(rest, /#[0-9]+/)) {
        pre = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : ""
        if (pre !~ /[[:alnum:]]/) print substr(rest, RSTART + 1, RLENGTH - 1)
        rest = substr(rest, RSTART + RLENGTH)
      }
    }
  '
}

body() { # [file]
  if [ "$#" -eq 0 ]; then
    cat
  elif [ -r "$1" ]; then
    cat "$1"
  else
    printf 'parse.sh: cannot read body file: %s\n' "$1" >&2
    exit 1
  fi
}

[ "$#" -ge 1 ] || usage
cmd=$1
shift

case "$cmd" in
  parent)
    body "$@" | section_refs "Parent" | head -n 1
    ;;
  blockers)
    body "$@" | section_refs "Blocked by" | awk '!seen[$0]++'
    ;;
  classify-reason)
    [ "$#" -eq 1 ] || usage
    normalized="$(printf '%s' "$1" | tr '[:lower:] ' '[:upper:]_')"
    case "$normalized" in
      COMPLETED) echo completed ;;
      NOT_PLANNED) echo not-planned ;;
      *)
        printf 'parse.sh: unknown state reason: %s\n' "$1" >&2
        exit 2
        ;;
    esac
    ;;
  *)
    usage
    ;;
esac

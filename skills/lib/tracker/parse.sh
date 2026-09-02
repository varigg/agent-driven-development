#!/usr/bin/env bash
# Tracker-contract parsers: pure text-in/conclusion-out, no network, no gh.
# The section encoding is the to-tickets template — a level-2 "## Parent"
# section referencing the spec issue and a "## Blocked by" section listing
# blocking issues as list items (or the literal none-sentinel). Only list
# items carry edges; prose references are never extracted. The none-sentinel
# and an absent section both mean "no edges" and need no special-casing.
#
# adr-obligation reads to-spec's contract instead: a level-2
# "## Implementation Decisions" section, whose list items are free prose. It
# looks for the durable structural signal (a list item, in that section) that
# something ADR-shaped was promised, rather than matching a specific phrase
# anywhere in the body.
#
# Usage:
#   parse.sh parent [file]            -> spec issue number, or empty (exit 0)
#   parse.sh blockers [file]          -> blocker numbers one per line (exit 0)
#   parse.sh adr-obligation [file]    -> matching Implementation Decisions
#                                         list items, one per line, or empty (exit 0)
#   parse.sh classify-reason <reason> -> "completed" | "not-planned" (else exit 2)
#   parse.sh body-hash [file]         -> truncated body sha256 (exit 0)
#   parse.sh approval-hash [file]     -> last recorded body hash, or empty (exit 0)
#
# parent/blockers/adr-obligation read the issue body from <file> or stdin.
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

# Print each list item's text within "## Implementation Decisions" that
# mentions ADR as a standalone word: padding the lowercased item with a
# leading/trailing space lets one regex catch the word at either edge, and
# a plural ("ADRs") counts, but "quadrant" or "hadrian" do not.
adr_obligations() {
  awk '
    /^#+[[:space:]]/ || /^#+$/ {
      heading = $0
      sub(/^#+[[:space:]]*/, "", heading)
      gsub(/[[:space:]]+$/, "", heading)
      insec = ($0 ~ /^##[^#]/) && (tolower(heading) == "implementation decisions")
      next
    }
    insec && /^[[:space:]]*[-*+][[:space:]]/ {
      item = $0
      sub(/^[[:space:]]*[-*+][[:space:]]+/, "", item)
      padded = " " tolower(item) " "
      if (padded ~ /[^a-z]adrs?[^a-z]/) print item
    }
  '
}

body_hash() { # [file]
  local contents
  # Command substitution removes every trailing newline before the bytes are
  # hashed, matching the review buffer's normalization guard.
  contents="$(body "$@")"
  printf '%s' "$contents" | sha256sum | cut -c1-12 | sed 's/^/sha256:/'
}

approval_hash() { # [file]
  # Strict marker grammar: anchored, lowercase hex, nothing after the hash —
  # prose mentions, quoted replies, and indented copies never re-record. The
  # last marker wins, so a re-approval shadows the hash it replaces.
  # `|| true` because no marker at all is an answer (empty, exit 0), and
  # pipefail would otherwise turn grep's no-match exit into a failure.
  # A trailing CR is tolerated and stripped: a comment edited in the web UI
  # comes back CRLF, and a CR-blind anchor would fail open — the marker would
  # read as "never recorded" and silently disable the drift check.
  body "$@" | { grep -E $'^Approved-body: sha256:[0-9a-f]{12}\r?$' || true; } \
    | tail -n 1 | sed $'s/^Approved-body: //; s/\r$//'
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
  adr-obligation)
    body "$@" | adr_obligations
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
  body-hash)
    body_hash "$@"
    ;;
  approval-hash)
    approval_hash "$@"
    ;;
  *)
    usage
    ;;
esac

#!/usr/bin/env bash
# Tracker-contract parsers: pure text-in/conclusion-out, no network, no gh.
# The section encoding is the to-tickets template — a level-2 "## Parent"
# section referencing the spec issue and a "## Blocked by" section listing
# blocking issues as list items (or the literal none-sentinel). Only list
# items carry edges; prose references are never extracted. The none-sentinel
# and an absent section both mean "no edges" and need no special-casing.
#
# adr-obligation reads to-spec's contract instead: a level-2
# "## Implementation Decisions" section, whose list items are free prose. An
# obligation is declared by convention, not inferred from prose (ADR 0015): a
# list item whose text, after the list marker and any emphasis wrapping (*,
# _, backtick), begins with the literal label "ADR:" (case-insensitive).
# Everything else — a bare citation ("ADR-035", "ADR 035"), or free prose that
# merely mentions the word — is never an obligation, whatever it says.
#
# Usage:
#   parse.sh parent [file]            -> spec issue number, or empty (exit 0)
#   parse.sh blockers [file]          -> blocker numbers one per line (exit 0)
#   parse.sh adr-obligation [file]    -> matching Implementation Decisions
#                                         list items, one per line, or empty (exit 0)
#   parse.sh edges                    -> framed stdin to one record per issue:
#                                         number\x1fparent\x1fblockers\x1fADR-items
#                                         (blockers are space-separated; ADR items
#                                         use \x1e), followed by any header fields
#                                         after the four edge fields. The framing
#                                         is `H<number>` optionally followed by
#                                         `\x1fstate\x1freason\x1flabels\x1fassignees\x1ftitle`,
#                                         then zero or more `B` plus body-line
#                                         records; each record ends at newline.
#   parse.sh strip-section <name> [file] -> body with that level-2 section
#                                            removed entirely, or the body
#                                            unchanged if the section is
#                                            absent (exit 0)
#   parse.sh classify-reason <reason> -> "completed" | "not-planned" (else exit 2)
#   parse.sh body-hash [file]         -> truncated body sha256 (exit 0)
#   parse.sh approval-hash [file]     -> last recorded body hash, or empty (exit 0)
#   parse.sh amendment-summary [file] -> summary of the last anchored
#                                         "Amends-contract: <summary>" line in
#                                         a comment, or empty (exit 0)
#
# parent/blockers/adr-obligation/strip-section read the issue body from
# <file> or stdin; approval-hash and amendment-summary read a comment.
set -euo pipefail

usage() {
  sed -n 's/^# \{0,1\}//p' "${BASH_SOURCE[0]}" | sed -n '/^Usage:/,/^$/p' >&2
  exit 2
}

# The edge rules live in this one awk program. The single-body commands feed
# it one body; edges feeds it the framed stream and retains the header fields
# after the four edge fields so resolve.sh can index the rest of the snapshot
# without another jq pass.
edge_awk() { # parent | blockers | adr-obligation | edges
  awk -v mode="$1" '
    BEGIN {
      field_sep = sprintf("%c", 31)
      item_sep = sprintf("%c", 30)
      issue = 0
      have_issue = 0
      reset_issue()
    }

    function reset_issue() {
      number = ""
      parent = ""
      blockers = ""
      obligation_count = 0
      in_parent = 0
      in_blockers = 0
      in_adr = 0
      header_count = 0
    }

    function start_issue(line) {
      if (have_issue) emit_issue()
      reset_issue()
      header_count = split(substr(line, 2), header_fields, field_sep)
      number = header_fields[1]
      issue++
      have_issue = 1
    }

    function emit_issue(    i, n, output, item) {
      if (mode == "edges") {
        output = number field_sep parent field_sep blockers field_sep
        for (i = 1; i <= obligation_count; i++) {
          if (i > 1) output = output item_sep
          # A separator inside an item would shift every later field.
          item = obligation_items[issue SUBSEP i]
          gsub(field_sep "|" item_sep, " ", item)
          output = output item
        }
        for (i = 2; i <= header_count; i++) {
          output = output field_sep header_fields[i]
        }
        print output
      } else if (mode == "parent") {
        if (parent != "") print parent
      } else if (mode == "blockers") {
        if (blockers != "") {
          n = split(blockers, blocker_fields, /[[:space:]]+/)
          for (i = 1; i <= n; i++) print blocker_fields[i]
        }
      } else if (mode == "adr-obligation") {
        for (i = 1; i <= obligation_count; i++) {
          print obligation_items[issue SUBSEP i]
        }
      }
    }

    # Only a level-2 heading (`##`, not `###`) opens or closes a section —
    # the same boundary strip_section uses — so a subsection heading never
    # ends a scan early.
    function body_line(line,    heading, rest, pre, ref, item, label) {
      if (line ~ /^##[^#]/) {
        heading = line
        sub(/^##[[:space:]]*/, "", heading)
        gsub(/[[:space:]]+$/, "", heading)
        in_parent = (tolower(heading) == "parent")
        in_blockers = (tolower(heading) == "blocked by")
        in_adr = (tolower(heading) == "implementation decisions")
        return
      }

      # A #N ref in a list item counts only when the "#" is not glued to a
      # preceding word character, so "PR#12" and prose like "#99" outside
      # list items never become edges.
      if ((in_parent || in_blockers) && line ~ /^[[:space:]]*[-*+][[:space:]]/) {
        rest = line
        while (match(rest, /#[0-9]+/)) {
          pre = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : ""
          if (pre !~ /[[:alnum:]]/) {
            ref = substr(rest, RSTART + 1, RLENGTH - 1)
            if (in_parent) {
              if (parent == "") parent = ref
            } else if (!((issue SUBSEP ref) in blocker_seen)) {
              blocker_seen[issue SUBSEP ref] = 1
              if (blockers == "") blockers = ref
              else blockers = blockers " " ref
            }
          }
          rest = substr(rest, RSTART + RLENGTH)
        }
      }

      # Only the "ADR:" label at the start of the item, once leading emphasis
      # wrapping is stripped, declares an obligation: a later citation in the
      # same bullet rides along as free prose, while a bullet with no label —
      # citing a number, or mentioning ADRs in passing — never counts.
      if (in_adr && line ~ /^[[:space:]]*[-*+][[:space:]]/) {
        item = line
        sub(/^[[:space:]]*[-*+][[:space:]]+/, "", item)
        label = item
        gsub(/^[*_`[:space:]]+/, "", label)
        if (tolower(label) ~ /^adr:/) {
          obligation_count++
          obligation_items[issue SUBSEP obligation_count] = item
        }
      }
    }

    mode == "edges" {
      if (substr($0, 1, 1) == "H") start_issue($0)
      else if (substr($0, 1, 1) == "B" && have_issue) body_line(substr($0, 2))
      else exit 2
      next
    }

    {
      body_line($0)
    }

    END {
      if (mode == "edges") {
        if (have_issue) emit_issue()
      } else {
        emit_issue()
      }
    }
  '
}

# Print the body with the named level-2 section — its heading and every line
# up to (not including) the next level-2 heading, or end of body — removed.
# The section's own trailing blank line is dropped with it, so the surviving
# gap between neighboring sections is whatever separator the section *before*
# the removed one already carried, rather than a doubled blank.
strip_section() { # section-name
  awk -v want="$1" '
    /^##[^#]/ {
      heading = $0
      sub(/^##[[:space:]]*/, "", heading)
      gsub(/[[:space:]]+$/, "", heading)
      if (tolower(heading) == tolower(want)) {
        insec = 1
        next
      } else {
        insec = 0
      }
    }
    !insec { print }
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

amendment_summary() { # [file]
  # Same raw-line grammar as the approval marker (ADR 0009): anchored, a
  # trailing CR tolerated and stripped, the last marker wins. The summary must
  # start with a non-space character, so a bare "Amends-contract:" never
  # records an empty amendment. A raw line inside a code fence counts: the
  # scan reads lines, not markdown, exactly as `approval_hash` does.
  body "$@" | { grep -E $'^Amends-contract: [^[:space:]].*$' || true; } \
    | tail -n 1 | sed $'s/^Amends-contract: //; s/\r$//'
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
    body "$@" | edge_awk parent
    ;;
  blockers)
    body "$@" | edge_awk blockers
    ;;
  adr-obligation)
    body "$@" | edge_awk adr-obligation
    ;;
  edges)
    [ "$#" -eq 0 ] || usage
    edge_awk edges
    ;;
  strip-section)
    [ "$#" -ge 1 ] || usage
    name=$1
    shift
    body "$@" | strip_section "$name"
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
  amendment-summary)
    amendment_summary "$@"
    ;;
  *)
    usage
    ;;
esac

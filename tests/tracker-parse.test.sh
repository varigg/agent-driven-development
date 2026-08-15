#!/usr/bin/env bash
# Contract: skills/lib/tracker/parse.sh — pure text-in/conclusion-out parsers
# for the ## Parent / ## Blocked by section encoding and close-reason classification.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

PARSE=../skills/lib/tracker/parse.sh
FIX=fixtures/tracker

# --- parent ---
assert_eq "2" "$(bash "$PARSE" parent "$FIX/parent-and-sentinel.md")" \
  "parent: plain ref"
assert_eq "2" "$(bash "$PARSE" parent "$FIX/blockers.md")" \
  "parent: ref with trailing title"
assert_eq "2" "$(bash "$PARSE" parent < "$FIX/parent-and-sentinel.md")" \
  "parent: body on stdin"
assert_eq "" "$(bash "$PARSE" parent "$FIX/no-parent.md")" \
  "parent: absent section yields empty"
assert_exit 0 "parent: absent section still exits zero" \
  bash "$PARSE" parent "$FIX/no-parent.md"

# --- blockers ---
assert_eq "" "$(bash "$PARSE" blockers "$FIX/parent-and-sentinel.md")" \
  "blockers: none-sentinel yields empty"
assert_eq "$(printf '8\n10\n11')" "$(bash "$PARSE" blockers "$FIX/blockers.md")" \
  "blockers: list refs, with and without trailing titles"
assert_eq "" "$(bash "$PARSE" blockers "$FIX/no-parent.md")" \
  "blockers: absent section yields empty"
assert_exit 0 "blockers: absent section still exits zero" \
  bash "$PARSE" blockers "$FIX/no-parent.md"
assert_eq "" "$(bash "$PARSE" blockers "$FIX/prose-refs.md")" \
  "blockers: prose refs inside the section are not edges"
assert_eq "2" "$(bash "$PARSE" parent "$FIX/prose-refs.md")" \
  "parent: prose fixture still parses parent"
assert_eq "$(printf '8\n9\n11')" "$(bash "$PARSE" blockers "$FIX/multi-ref-item.md")" \
  "blockers: multiple refs in one list item all count"

# --- classify-reason ---
assert_eq "completed" "$(bash "$PARSE" classify-reason COMPLETED)" \
  "classify: COMPLETED"
assert_eq "not-planned" "$(bash "$PARSE" classify-reason NOT_PLANNED)" \
  "classify: NOT_PLANNED"
assert_eq "completed" "$(bash "$PARSE" classify-reason completed)" \
  "classify: case-insensitive"
assert_exit 2 "classify: unknown reason refuses loudly" \
  bash "$PARSE" classify-reason DUPLICATE
assert_exit 2 "classify: empty reason refuses loudly" \
  bash "$PARSE" classify-reason ""

# --- body-hash ---
# The contract: sha256 of the body with every trailing newline stripped,
# truncated to the first 12 hex digits, printed as "sha256:<12hex>".
assert_eq "sha256:$(printf '%s' 'spec body' | sha256sum | cut -c1-12)" \
  "$(printf 'spec body\n\n' | bash "$PARSE" body-hash)" \
  "body-hash: truncated sha256 of the trailing-newline-stripped body"
assert_eq "$(printf 'spec body' | bash "$PARSE" body-hash)" \
  "$(printf 'spec body\n' | bash "$PARSE" body-hash)" \
  "body-hash: a trailing newline is not a difference"
assert_eq "$(bash "$PARSE" body-hash < "$FIX/blockers.md")" \
  "$(bash "$PARSE" body-hash "$FIX/blockers.md")" \
  "body-hash: file argument matches stdin"
[ "$(printf 'a' | bash "$PARSE" body-hash)" != "$(printf 'b' | bash "$PARSE" body-hash)" ] \
  || fail "body-hash: different bodies must hash differently"

# --- approval-hash ---
assert_eq "sha256:bbbbbbbbbbbb" "$(bash "$PARSE" approval-hash "$FIX/approval-comments.md")" \
  "approval-hash: last marker line wins; prose, quoted, indented, malformed ignored"
assert_eq "sha256:bbbbbbbbbbbb" "$(bash "$PARSE" approval-hash < "$FIX/approval-comments.md")" \
  "approval-hash: comments on stdin"
assert_eq "sha256:eeeeeeeeeeee" \
  "$(printf 'Approved-body: sha256:eeeeeeeeeeee\r\n' | bash "$PARSE" approval-hash)" \
  "approval-hash: a CRLF marker (web-edited comment) still records, CR stripped"
assert_eq "" "$(bash "$PARSE" approval-hash "$FIX/approval-comments-none.md")" \
  "approval-hash: no marker yields empty"
assert_exit 0 "approval-hash: no marker still exits zero" \
  bash "$PARSE" approval-hash "$FIX/approval-comments-none.md"

# --- CLI seam hygiene ---
assert_exit 2 "unknown subcommand refuses loudly" \
  bash "$PARSE" frobnicate

echo "tracker-parse: all assertions passed"

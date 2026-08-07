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

# --- CLI seam hygiene ---
assert_exit 2 "unknown subcommand refuses loudly" \
  bash "$PARSE" frobnicate

echo "tracker-parse: all assertions passed"

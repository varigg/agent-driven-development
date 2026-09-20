#!/usr/bin/env bash
# Contract: skills/lib/tracker/parse.sh — pure text-in/conclusion-out parsers
# for the ## Parent / ## Blocked by section encoding and close-reason classification.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

PARSE=../skills/lib/tracker/parse.sh
FIX=fixtures/tracker
SPEC_FIX=fixtures/spec

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
assert_eq "$(printf '8\n10')" "$(bash "$PARSE" blockers "$FIX/blockers-subsection.md")" \
  "blockers: a ### subsection inside Blocked by does not end the section early, and the next ## section still does"

# --- adr-obligation ---
assert_eq "ADR: records the positive decision, losing alternatives as one-liners." \
  "$(bash "$PARSE" adr-obligation "$SPEC_FIX/adr-obligation.md")" \
  "adr-obligation: a list item declaring the ADR: label is extracted"
assert_eq "" "$(bash "$PARSE" adr-obligation "$SPEC_FIX/no-adr-obligation.md")" \
  "adr-obligation: no label yields empty"
assert_exit 0 "adr-obligation: no label still exits zero" \
  bash "$PARSE" adr-obligation "$SPEC_FIX/no-adr-obligation.md"
assert_eq "" "$(bash "$PARSE" adr-obligation "$SPEC_FIX/adr-mentioned-elsewhere.md")" \
  "adr-obligation: a mention outside Implementation Decisions is not an obligation"
assert_eq "" "$(bash "$PARSE" adr-obligation "$FIX/no-parent.md")" \
  "adr-obligation: absent section yields empty"
assert_eq "" "$(bash "$PARSE" adr-obligation "$SPEC_FIX/adr-citation-only.md")" \
  "adr-obligation: bullets that only cite an existing ADR number, with no ADR: label, are not an obligation"
assert_eq "ADR: records the positive decision, losing alternatives as one-liners." \
  "$(bash "$PARSE" adr-obligation "$SPEC_FIX/adr-obligation-mixed.md")" \
  "adr-obligation: a citation bullet and a labelled declaration side by side — only the declaration counts"
assert_eq "ADR: supersedes ADR-033's vocabulary split and ADR-035's extract-only ingestion split." \
  "$(bash "$PARSE" adr-obligation "$SPEC_FIX/adr-declaration-with-citations.md")" \
  "adr-obligation: a declaration bullet still counts even when it also cites existing ADRs after the label"
assert_eq "**ADR:** one record for the decision." \
  "$(bash "$PARSE" adr-obligation "$SPEC_FIX/adr-emphasis-label.md")" \
  "adr-obligation: emphasis-wrapped label (**ADR:**) still counts"
assert_eq "" "$(bash "$PARSE" adr-obligation "$SPEC_FIX/adr-next-heading-ignored.md")" \
  "adr-obligation: an ADR: item under the next ## section is ignored"
assert_eq "ADR: supersedes ADR-033's vocabulary split and ADR-035's extract-only ingestion split." \
  "$(bash "$PARSE" adr-obligation "$SPEC_FIX/adr-obligation-subsection.md")" \
  "adr-obligation: a declaration under a ### subsection of Implementation Decisions is not missed, and citation-only bullets in a sibling subsection stay excluded"

# --- section span agreement: parent/blockers/adr-obligation/strip-section
#     all treat a level-2 section as running to the next ## heading, ###
#     subsections included, over one shared body ---
SPAN_FIX="$FIX/section-span-agreement.md"
assert_eq "2" "$(bash "$PARSE" parent "$SPAN_FIX")" \
  "section-span: parent found under a ### subsection, not the ## Decoy section's own ref"
assert_eq "$(printf '8\n10')" "$(bash "$PARSE" blockers "$SPAN_FIX")" \
  "section-span: blockers found under a ### subsection"
assert_eq "ADR: supersedes ADR-033's vocabulary split." \
  "$(bash "$PARSE" adr-obligation "$SPAN_FIX")" \
  "section-span: adr-obligation found under a ### subsection"
stripped_span="$(bash "$PARSE" strip-section "Implementation Decisions" "$SPAN_FIX")"
assert_eq "0" "$(printf '%s\n' "$stripped_span" | grep -c 'ADR: supersedes' || true)" \
  "section-span: strip-section removes the ### subsection along with its ## heading"
assert_eq "1" "$(printf '%s\n' "$stripped_span" | grep -c '^## Decoy$')" \
  "section-span: strip-section leaves a sibling ## section, subsection and all, untouched"

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

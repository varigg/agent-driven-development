#!/usr/bin/env bash
# Contract: skills/lib/tracker/resolve.sh — pure frontier and spec-completion
# resolution over an issue snapshot (the gh --json shape: number, title, state,
# stateReason, labels, assignees, body). No network, no gh. Bodies are parsed
# through parse.sh, so the section encoding contract is inherited, not restated.
#
#   resolve.sh frontier <issues.json> [branches-file] [deliveries-file]
#   resolve.sh spec-complete <spec-number> <issues.json> [deliveries-file]
#   resolve.sh specs <issues.json> [deliveries-file]
#
# Frontier output: four fixed section headers, always printed, each followed by
# zero or more tab-separated entry lines, ascending by issue number:
#   frontier:            #N<TAB>title[<TAB>[in progress: ...]]
#   needs-rescoping:     #N<TAB>title<TAB>[blocker #M closed as not planned]
#   unknown-blockers:    #N<TAB>title<TAB>[blocker #M not in snapshot]
#   complete-specs:      #N<TAB>title<TAB>tracker.sh close-spec N
#
# Spec-completion output: first line is the four-way verdict — complete,
# partial, planned, or no-children (exit 0 iff complete) — then one line per
# child:
#   <completed|open|not-planned><TAB>#N<TAB>title
# A childless spec prints no child lines (the verdict line already says
# no-children). A number that is not a spec-labeled issue in the snapshot
# exits 2. A declared ADR obligation (a spec body's "## Implementation
# Decisions" list item mentioning ADR) additionally needs one child's delivery
# — read from the optional deliveries-file, in tracker.sh's child-delivery
# line shape — marked adr:yes; otherwise a spec with no open child still
# reports partial rather than complete. No deliveries file (or none of the
# spec's children in it) reads as unsatisfied, same as an explicit "no".
#
# specs output: one line per open spec-labeled issue, ascending by issue
# number: #N<TAB>verdict<TAB>title, plus a fourth field naming the close
# command when verdict is complete: #N<TAB>complete<TAB>title<TAB>tracker.sh
# close-spec N
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

RESOLVE=../skills/lib/tracker/resolve.sh
FIX=fixtures/tracker

# --- frontier ---
out="$(bash "$RESOLVE" frontier "$FIX/issues.json" "$FIX/branches.txt")"
assert_exit 0 "frontier: exits zero" \
  bash "$RESOLVE" frontier "$FIX/issues.json" "$FIX/branches.txt"

frontier_sec="$(sed -n '/^frontier:$/,/^needs-rescoping:$/p' <<<"$out")"
rescope_sec="$(sed -n '/^needs-rescoping:$/,/^unknown-blockers:$/p' <<<"$out")"
unknown_sec="$(sed -n '/^unknown-blockers:$/,/^complete-specs:$/p' <<<"$out")"
specs_sec="$(sed -n '/^complete-specs:$/,$p' <<<"$out")"

assert_contains "$frontier_sec" "$(printf '#4\tAdd the gate runner')" \
  "frontier: unblocked ticket listed"
assert_contains "$frontier_sec" "$(printf '#5\tSlim the maintain skill\t[in progress: assignee octocat]')" \
  "frontier: completed blocker satisfies; assignee annotated in progress"
assert_contains "$frontier_sec" "$(printf '#10\tAdd the widget\t[in progress: branch feat/10-widget-polish]')" \
  "frontier: existing issue branch annotated in progress"
assert_contains "$frontier_sec" "$(printf '#23\tDocument the schema')" \
  "frontier: ticket with a parent spec is still frontier-eligible"
assert_not_contains "$frontier_sec" "$(printf '#6\t')" \
  "frontier: open blocker excludes the dependent"
assert_not_contains "$frontier_sec" "$(printf '#13\t')" \
  "frontier: one open blocker among several still excludes"
assert_not_contains "$frontier_sec" "$(printf '#8\t')" \
  "frontier: backlog label excludes"
assert_not_contains "$frontier_sec" "$(printf '#2\t')" \
  "frontier: spec label excludes even with ready-for-agent"
assert_not_contains "$frontier_sec" "$(printf '#11\t')" \
  "frontier: missing ready-for-agent label excludes"
assert_not_contains "$frontier_sec" "$(printf '#3\t')" \
  "frontier: closed ticket excluded"
assert_not_contains "$frontier_sec" "$(printf '#7\t')" \
  "frontier: not-planned blocker keeps dependent off the frontier"
assert_not_contains "$frontier_sec" "$(printf '#12\t')" \
  "frontier: unknown blocker keeps dependent off the frontier"

assert_eq "4,5,10,23,28" \
  "$(grep -o '^#[0-9]*' <<<"$frontier_sec" | tr -d '#' | paste -sd,)" \
  "frontier: entries ascend by issue number"

assert_contains "$rescope_sec" "$(printf '#7\tRework the exporter\t[blocker #9 closed as not planned]')" \
  "rescoping: dependent of not-planned blocker flagged with the blocker named"
assert_contains "$unknown_sec" "$(printf '#12\tRide the missing blocker\t[blocker #99 not in snapshot]')" \
  "unknown: absent blocker flagged loudly, never treated as satisfied"
assert_contains "$specs_sec" "$(printf '#2\tSpec: sample overlay\ttracker.sh close-spec 2')" \
  "complete-specs: spec with only a completed child surfaced, naming the close command"
assert_contains "$specs_sec" "$(printf '#24\tSpec: waived child\ttracker.sh close-spec 24')" \
  "complete-specs: a not-planned remaining child still counts as complete, naming the close command"
assert_not_contains "$specs_sec" "$(printf '#20\t')" \
  "complete-specs: childless spec not surfaced"
assert_not_contains "$specs_sec" "$(printf '#21\t')" \
  "complete-specs: partial spec (open child) not surfaced"
assert_not_contains "$specs_sec" "$(printf '#27\t')" \
  "complete-specs: planned spec (no delivered child) not surfaced"
assert_not_contains "$specs_sec" "$(printf '#29\t')" \
  "complete-specs: unmet ADR obligation not surfaced without a deliveries file"

out_deliveries="$(bash "$RESOLVE" frontier "$FIX/issues.json" "$FIX/branches.txt" "$FIX/deliveries-met.txt")"
assert_contains "$out_deliveries" "$(printf '#29\tSpec: ADR obligation\ttracker.sh close-spec 29')" \
  "complete-specs: satisfied ADR obligation surfaced given the deliveries file, naming the close command"

out_nobranches="$(bash "$RESOLVE" frontier "$FIX/issues.json")"
assert_contains "$out_nobranches" "$(printf '#10\tAdd the widget')" \
  "frontier: branches file optional"
assert_not_contains "$out_nobranches" "branch feat/10-widget-polish" \
  "frontier: no branch annotations without a branches file"

# --- spec-complete ---
ready="$(bash "$RESOLVE" spec-complete 2 "$FIX/issues.json")"
assert_exit 0 "spec-complete: complete spec exits zero" \
  bash "$RESOLVE" spec-complete 2 "$FIX/issues.json"
assert_eq "complete" "$(head -n 1 <<<"$ready")" \
  "spec-complete: first line verdict"
assert_contains "$ready" "$(printf 'completed\t#3\tAdd the parsers')" \
  "spec-complete: children listed with status"

assert_exit 1 "spec-complete: childless spec is not complete" \
  bash "$RESOLVE" spec-complete 20 "$FIX/issues.json"
childless="$(bash "$RESOLVE" spec-complete 20 "$FIX/issues.json" || true)"
assert_eq "no-children" "$(head -n 1 <<<"$childless")" \
  "spec-complete: childless verdict line"

assert_exit 1 "spec-complete: a spec with a completed and an open child is partial" \
  bash "$RESOLVE" spec-complete 21 "$FIX/issues.json"
open_child="$(bash "$RESOLVE" spec-complete 21 "$FIX/issues.json" || true)"
assert_eq "partial" "$(head -n 1 <<<"$open_child")" \
  "spec-complete: partial verdict line"
assert_contains "$open_child" "$(printf 'open\t#23\tDocument the schema')" \
  "spec-complete: open child named"
assert_contains "$open_child" "$(printf 'completed\t#22\tWire the schema')" \
  "spec-complete: completed sibling still listed"

assert_exit 0 "spec-complete: a not-planned remaining child is still complete" \
  bash "$RESOLVE" spec-complete 24 "$FIX/issues.json"
waived="$(bash "$RESOLVE" spec-complete 24 "$FIX/issues.json")"
assert_eq "complete" "$(head -n 1 <<<"$waived")" \
  "spec-complete: complete verdict line despite a not-planned child"
assert_contains "$waived" "$(printf 'not-planned\t#26\tPolish the importer docs')" \
  "spec-complete: not-planned child still listed with its status"

assert_exit 1 "spec-complete: a spec with only an open child, none delivered, is planned" \
  bash "$RESOLVE" spec-complete 27 "$FIX/issues.json"
planned="$(bash "$RESOLVE" spec-complete 27 "$FIX/issues.json" || true)"
assert_eq "planned" "$(head -n 1 <<<"$planned")" \
  "spec-complete: planned verdict line"
assert_contains "$planned" "$(printf 'open\t#28\tBuild the pending piece')" \
  "spec-complete: planned spec's open child named"

assert_exit 2 "spec-complete: non-spec issue refuses" \
  bash "$RESOLVE" spec-complete 4 "$FIX/issues.json"
assert_exit 2 "spec-complete: unknown number refuses" \
  bash "$RESOLVE" spec-complete 999 "$FIX/issues.json"

# --- spec-complete: ADR obligation folded into the verdict ---
assert_exit 1 "spec-complete: all children closed but an unmet ADR obligation is partial" \
  bash "$RESOLVE" spec-complete 29 "$FIX/issues.json" "$FIX/deliveries-unmet.txt"
unmet="$(bash "$RESOLVE" spec-complete 29 "$FIX/issues.json" "$FIX/deliveries-unmet.txt" || true)"
assert_eq "partial" "$(head -n 1 <<<"$unmet")" \
  "spec-complete: unmet ADR obligation verdict line"
assert_contains "$unmet" "$(printf 'completed\t#30\tDecide the approach')" \
  "spec-complete: unmet-obligation spec's completed child still listed"

assert_exit 0 "spec-complete: a child-delivering commit that touched the ADR directory is complete" \
  bash "$RESOLVE" spec-complete 29 "$FIX/issues.json" "$FIX/deliveries-met.txt"
met="$(bash "$RESOLVE" spec-complete 29 "$FIX/issues.json" "$FIX/deliveries-met.txt")"
assert_eq "complete" "$(head -n 1 <<<"$met")" \
  "spec-complete: satisfied ADR obligation verdict line"

assert_exit 1 "spec-complete: an ADR obligation with no deliveries file at all is unsatisfied, not complete" \
  bash "$RESOLVE" spec-complete 29 "$FIX/issues.json"
no_deliveries="$(bash "$RESOLVE" spec-complete 29 "$FIX/issues.json" || true)"
assert_eq "partial" "$(head -n 1 <<<"$no_deliveries")" \
  "spec-complete: missing deliveries file reads as unsatisfied, not a guessed complete"

assert_exit 0 "spec-complete: a spec with no obligation is unaffected by an unrelated deliveries file" \
  bash "$RESOLVE" spec-complete 2 "$FIX/issues.json" "$FIX/deliveries-met.txt"
no_obligation="$(bash "$RESOLVE" spec-complete 2 "$FIX/issues.json" "$FIX/deliveries-met.txt")"
assert_eq "complete" "$(head -n 1 <<<"$no_obligation")" \
  "spec-complete: no-obligation spec verdict unchanged by a deliveries file"

# --- specs ---
specs_out="$(bash "$RESOLVE" specs "$FIX/issues.json")"
assert_exit 0 "specs: exits zero" bash "$RESOLVE" specs "$FIX/issues.json"
assert_contains "$specs_out" "$(printf '#2\tcomplete\tSpec: sample overlay\ttracker.sh close-spec 2')" \
  "specs: complete spec listed with its verdict, naming the close command"
assert_contains "$specs_out" "$(printf '#20\tno-children\tSpec: childless')" \
  "specs: childless spec listed with its verdict"
assert_not_contains "$specs_out" "$(printf '#20\tno-children\tSpec: childless\ttracker.sh')" \
  "specs: a non-complete verdict never names the close command"
assert_contains "$specs_out" "$(printf '#21\tpartial\tSpec: one open child')" \
  "specs: partial spec listed with its verdict"
assert_contains "$specs_out" "$(printf '#24\tcomplete\tSpec: waived child')" \
  "specs: not-planned-only spec listed as complete"
assert_contains "$specs_out" "$(printf '#27\tplanned\tSpec: planned only')" \
  "specs: planned spec listed with its verdict"
assert_contains "$specs_out" "$(printf '#29\tpartial\tSpec: ADR obligation')" \
  "specs: unmet ADR obligation reads as partial without a deliveries file"
assert_eq "2,20,21,24,27,29" \
  "$(grep -o '^#[0-9]*' <<<"$specs_out" | tr -d '#' | paste -sd,)" \
  "specs: entries ascend by issue number"

specs_met="$(bash "$RESOLVE" specs "$FIX/issues.json" "$FIX/deliveries-met.txt")"
assert_contains "$specs_met" "$(printf '#29\tcomplete\tSpec: ADR obligation\ttracker.sh close-spec 29')" \
  "specs: satisfied ADR obligation reads as complete given the deliveries file, naming the close command"

# --- CLI seam hygiene ---
assert_exit 2 "no arguments refuses loudly" bash "$RESOLVE"
assert_exit 2 "unknown subcommand refuses loudly" bash "$RESOLVE" frobnicate
assert_exit 2 "specs: wrong argument count refuses loudly" bash "$RESOLVE" specs

echo "tracker-resolve: all assertions passed"

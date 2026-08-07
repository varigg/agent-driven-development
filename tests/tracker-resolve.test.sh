#!/usr/bin/env bash
# Contract: skills/lib/tracker/resolve.sh — pure frontier and spec-completion
# resolution over an issue snapshot (the gh --json shape: number, title, state,
# stateReason, labels, assignees, body). No network, no gh. Bodies are parsed
# through parse.sh, so the section encoding contract is inherited, not restated.
#
#   resolve.sh frontier <issues.json> [branches-file]
#   resolve.sh spec-complete <spec-number> <issues.json>
#
# Frontier output: four fixed section headers, always printed, each followed by
# zero or more tab-separated entry lines, ascending by issue number:
#   frontier:            #N<TAB>title[<TAB>[in progress: ...]]
#   needs-rescoping:     #N<TAB>title<TAB>[blocker #M closed as not planned]
#   unknown-blockers:    #N<TAB>title<TAB>[blocker #M not in snapshot]
#   release-ready-specs: #N<TAB>title
#
# Spec-completion output: first line "release-ready" (exit 0) or
# "not-release-ready" (exit 1), then one line per child:
#   <completed|open|not-planned><TAB>#N<TAB>title
# A childless spec prints "no-children" instead of child lines. A number that
# is not a spec-labeled issue in the snapshot exits 2.
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
unknown_sec="$(sed -n '/^unknown-blockers:$/,/^release-ready-specs:$/p' <<<"$out")"
specs_sec="$(sed -n '/^release-ready-specs:$/,$p' <<<"$out")"

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

assert_eq "4,5,10,23" \
  "$(grep -o '^#[0-9]*' <<<"$frontier_sec" | tr -d '#' | paste -sd,)" \
  "frontier: entries ascend by issue number"

assert_contains "$rescope_sec" "$(printf '#7\tRework the exporter\t[blocker #9 closed as not planned]')" \
  "rescoping: dependent of not-planned blocker flagged with the blocker named"
assert_contains "$unknown_sec" "$(printf '#12\tRide the missing blocker\t[blocker #99 not in snapshot]')" \
  "unknown: absent blocker flagged loudly, never treated as satisfied"
assert_contains "$specs_sec" "$(printf '#2\tSpec: sample overlay')" \
  "release-ready: complete open spec surfaced"
assert_not_contains "$specs_sec" "$(printf '#20\t')" \
  "release-ready: childless spec not surfaced"
assert_not_contains "$specs_sec" "$(printf '#21\t')" \
  "release-ready: spec with open child not surfaced"
assert_not_contains "$specs_sec" "$(printf '#24\t')" \
  "release-ready: spec with not-planned child not surfaced"

out_nobranches="$(bash "$RESOLVE" frontier "$FIX/issues.json")"
assert_contains "$out_nobranches" "$(printf '#10\tAdd the widget')" \
  "frontier: branches file optional"
assert_not_contains "$out_nobranches" "branch feat/10-widget-polish" \
  "frontier: no branch annotations without a branches file"

# --- spec-complete ---
ready="$(bash "$RESOLVE" spec-complete 2 "$FIX/issues.json")"
assert_exit 0 "spec-complete: complete spec exits zero" \
  bash "$RESOLVE" spec-complete 2 "$FIX/issues.json"
assert_eq "release-ready" "$(head -n 1 <<<"$ready")" \
  "spec-complete: first line verdict"
assert_contains "$ready" "$(printf 'completed\t#3\tAdd the parsers')" \
  "spec-complete: children listed with status"

assert_exit 1 "spec-complete: childless spec is not release-ready" \
  bash "$RESOLVE" spec-complete 20 "$FIX/issues.json"
childless="$(bash "$RESOLVE" spec-complete 20 "$FIX/issues.json" || true)"
assert_eq "not-release-ready" "$(head -n 1 <<<"$childless")" \
  "spec-complete: childless verdict line"
assert_contains "$childless" "no-children" \
  "spec-complete: childless spec says why"

assert_exit 1 "spec-complete: open child blocks readiness" \
  bash "$RESOLVE" spec-complete 21 "$FIX/issues.json"
open_child="$(bash "$RESOLVE" spec-complete 21 "$FIX/issues.json" || true)"
assert_contains "$open_child" "$(printf 'open\t#23\tDocument the schema')" \
  "spec-complete: open child named"
assert_contains "$open_child" "$(printf 'completed\t#22\tWire the schema')" \
  "spec-complete: completed sibling still listed"

assert_exit 1 "spec-complete: not-planned child blocks readiness" \
  bash "$RESOLVE" spec-complete 24 "$FIX/issues.json"
waived="$(bash "$RESOLVE" spec-complete 24 "$FIX/issues.json" || true)"
assert_contains "$waived" "$(printf 'not-planned\t#26\tPolish the importer docs')" \
  "spec-complete: not-planned child named for the human waiver"

assert_exit 2 "spec-complete: non-spec issue refuses" \
  bash "$RESOLVE" spec-complete 4 "$FIX/issues.json"
assert_exit 2 "spec-complete: unknown number refuses" \
  bash "$RESOLVE" spec-complete 999 "$FIX/issues.json"

# --- CLI seam hygiene ---
assert_exit 2 "no arguments refuses loudly" bash "$RESOLVE"
assert_exit 2 "unknown subcommand refuses loudly" bash "$RESOLVE" frobnicate

echo "tracker-resolve: all assertions passed"

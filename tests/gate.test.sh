#!/usr/bin/env bash
# Contract: skills/lib/gate/gate.sh — the deterministic testing gate.
#
#   gate.sh [test-path...]   (run from the project root)
#
# Reads the recipe ladder from docs/addw.env through the shared config reader
# — there is no path flag, so every case runs from a fixture directory,
# exactly as production runs from a project root — and runs the rungs in
# fixed order via bash -c: lint (ADDW_RECIPE_LINT), typecheck
# (ADDW_RECIPE_TYPECHECK), tests (ADDW_RECIPE_TESTS_AFFECTED). Every rung
# runs even after an earlier one fails; recipe output goes to the gate's
# stderr. Stdout is exactly one summary line:
#
#   gate: lint <status> | typecheck <status> | tests <status>
#
# where <status> is "ok", "FAIL (exit N)", or "skipped (no recipe)" (unset and
# empty keys alike — skips are visible, never silent). In the tests recipe,
# every {paths} occurrence is replaced by the shell-quoted, space-joined test
# paths; a recipe without the placeholder runs as-is. Exit 0 iff no rung
# failed, 1 on any failure, 2 on usage errors (an option-shaped argument —
# the retired --config among them), 78 on a config the grammar rejects, 66 on
# no config at all.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
GATE="$REPO/skills/lib/gate/gate.sh"
FIX="$REPO/tests/fixtures/gate"

run_gate() { # <fixture-dir> [args...] — the gate from that project root
  local dir="$1"
  shift
  (cd "$FIX/$dir" && bash "$GATE" "$@")
}

# --- all rungs pass ---
out="$(run_gate all-pass 2>/dev/null)"
assert_eq "gate: lint ok | typecheck ok | tests ok" "$out" \
  "all-pass: exact summary line on stdout"
status=0
run_gate all-pass >/dev/null 2>&1 || status=$?
assert_eq 0 "$status" "all-pass: exit zero"
err="$(run_gate all-pass 2>&1 >/dev/null)"
assert_contains "$err" "lint-ran" \
  "all-pass: recipe output routed to stderr"
assert_not_contains "$out" "lint-ran" \
  "all-pass: stdout carries only the summary line"

# --- a failing rung ---
status=0
out="$(run_gate fail-typecheck 2>/dev/null)" || status=$?
assert_eq "1" "$status" "fail: gate exits 1 when any rung fails"
assert_eq "gate: lint ok | typecheck FAIL (exit 3) | tests ok" "$out" \
  "fail: summary names the failing rung with its exit code"
err="$(run_gate fail-typecheck 2>&1 >/dev/null)" || true
assert_contains "$err" "tests-ran-after-fail" \
  "fail: rungs after a failure still run"

# --- missing and empty keys are skipped visibly ---
out="$(run_gate no-keys 2>/dev/null)"
assert_eq \
  "gate: lint skipped (no recipe) | typecheck skipped (no recipe) | tests skipped (no recipe)" \
  "$out" "skip: unset and empty keys both report skipped"
status=0
run_gate no-keys >/dev/null 2>&1 || status=$?
assert_eq 0 "$status" "skip: an all-skipped gate exits zero"

# added at codex round 1: recipes come from the config alone — inherited
# environment values must not stand in for keys the config doesn't set
out="$(ADDW_RECIPE_LINT="echo env-leak" ADDW_RECIPE_TESTS_AFFECTED="echo env-leak" \
  run_gate no-keys 2>/dev/null)"
assert_eq \
  "gate: lint skipped (no recipe) | typecheck skipped (no recipe) | tests skipped (no recipe)" \
  "$out" "skip: exported ADDW_RECIPE_* never substitutes for missing keys"

# --- {paths} substitution ---
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
GATE_OUT="$tmp/received" export GATE_OUT
run_gate paths tests/a.test.sh "tests/b c.test.sh" >/dev/null 2>&1
assert_eq "tests/a.test.sh tests/b c.test.sh" "$(cat "$GATE_OUT")" \
  "paths: {paths} receives every selected path, space-safe"

# a recipe without the placeholder runs as-is even when paths are given
out="$(run_gate all-pass tests/a.test.sh 2>/dev/null)"
assert_eq "gate: lint ok | typecheck ok | tests ok" "$out" \
  "paths: placeholder-free recipe ignores selection"

# --- config failures are the reader's statuses, loudly ---

# The retired --config flag must refuse as a usage error rather than be
# swallowed as a test path — a stale caller learns of the removal here.
status=0
run_gate all-pass --config somefile >/dev/null 2>&1 || status=$?
assert_eq 2 "$status" "usage: an option-shaped argument (--config) exits 2"

status=0
err="$(run_gate bad-config 2>&1 >/dev/null)" || status=$?
assert_eq 78 "$status" "config: a grammar-rejected config exits 78 (EX_CONFIG)"
assert_contains "$err" "docs/addw.env:3:" \
  "config: the diagnostic names the offending line"

nowhere="$tmp/no-config-project"
mkdir -p "$nowhere"
status=0
(cd "$nowhere" && bash "$GATE") >/dev/null 2>&1 || status=$?
assert_eq 66 "$status" "config: a missing docs/addw.env exits 66 (EX_NOINPUT)"

echo "gate: all contract assertions passed"

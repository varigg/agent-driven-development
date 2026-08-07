#!/usr/bin/env bash
# Contract: skills/lib/gate/gate.sh — the deterministic testing gate.
#
#   gate.sh [--config <file>] [test-path...]
#
# Sources the project config (default: docs/addw.env) and runs the recipe
# ladder in fixed order — lint (ADDW_RECIPE_LINT), typecheck
# (ADDW_RECIPE_TYPECHECK), tests (ADDW_RECIPE_TESTS_AFFECTED) — via bash -c.
# Every rung runs even after an earlier one fails; recipe output goes to the
# gate's stderr. Stdout is exactly one summary line:
#
#   gate: lint <status> | typecheck <status> | tests <status>
#
# where <status> is "ok", "FAIL (exit N)", or "skipped (no recipe)" (unset and
# empty keys alike — skips are visible, never silent). In the tests recipe,
# every {paths} occurrence is replaced by the shell-quoted, space-joined test
# paths; a recipe without the placeholder runs as-is. Exit 0 iff no rung
# failed, 1 on any failure, 2 on an unreadable config.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

GATE=../skills/lib/gate/gate.sh
FIX=fixtures/gate

# --- all rungs pass ---
out="$(bash "$GATE" --config "$FIX/all-pass.env" 2>/dev/null)"
assert_eq "gate: lint ok | typecheck ok | tests ok" "$out" \
  "all-pass: exact summary line on stdout"
assert_exit 0 "all-pass: exit zero" \
  bash "$GATE" --config "$FIX/all-pass.env"
err="$(bash "$GATE" --config "$FIX/all-pass.env" 2>&1 >/dev/null)"
assert_contains "$err" "lint-ran" \
  "all-pass: recipe output routed to stderr"
assert_not_contains "$out" "lint-ran" \
  "all-pass: stdout carries only the summary line"

# --- a failing rung ---
status=0
out="$(bash "$GATE" --config "$FIX/fail-typecheck.env" 2>/dev/null)" || status=$?
assert_eq "1" "$status" "fail: gate exits 1 when any rung fails"
assert_eq "gate: lint ok | typecheck FAIL (exit 3) | tests ok" "$out" \
  "fail: summary names the failing rung with its exit code"
err="$(bash "$GATE" --config "$FIX/fail-typecheck.env" 2>&1 >/dev/null)" || true
assert_contains "$err" "tests-ran-after-fail" \
  "fail: rungs after a failure still run"

# --- missing and empty keys are skipped visibly ---
out="$(bash "$GATE" --config "$FIX/no-keys.env" 2>/dev/null)"
assert_eq \
  "gate: lint skipped (no recipe) | typecheck skipped (no recipe) | tests skipped (no recipe)" \
  "$out" "skip: unset and empty keys both report skipped"
assert_exit 0 "skip: an all-skipped gate exits zero" \
  bash "$GATE" --config "$FIX/no-keys.env"

# added at codex round 1: recipes come from the config alone — inherited
# environment values must not stand in for keys the config doesn't set
out="$(ADDW_RECIPE_LINT="echo env-leak" ADDW_RECIPE_TESTS_AFFECTED="echo env-leak" \
  bash "$GATE" --config "$FIX/no-keys.env" 2>/dev/null)"
assert_eq \
  "gate: lint skipped (no recipe) | typecheck skipped (no recipe) | tests skipped (no recipe)" \
  "$out" "skip: exported ADDW_RECIPE_* never substitutes for missing keys"

# --- {paths} substitution ---
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
GATE_OUT="$tmp/received" export GATE_OUT
bash "$GATE" --config "$FIX/paths.env" tests/a.test.sh "tests/b c.test.sh" \
  >/dev/null 2>&1
assert_eq "tests/a.test.sh tests/b c.test.sh" "$(cat "$GATE_OUT")" \
  "paths: {paths} receives every selected path, space-safe"

# a recipe without the placeholder runs as-is even when paths are given
out="$(bash "$GATE" --config "$FIX/all-pass.env" tests/a.test.sh 2>/dev/null)"
assert_eq "gate: lint ok | typecheck ok | tests ok" "$out" \
  "paths: placeholder-free recipe ignores selection"

# --- unreadable config refuses loudly ---
assert_exit 2 "config: missing file exits 2" \
  bash "$GATE" --config "$FIX/does-not-exist.env"

echo "gate: all contract assertions passed"

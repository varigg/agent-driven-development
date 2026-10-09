#!/usr/bin/env bash
# Contract: skills/lib/gate/gate.sh — the deterministic testing gate.
#
#   gate.sh [test-path...]   (run from the project root)
#
# Reads the recipe ladder from docs/addw.env through the shared config reader
# — there is no path flag, so every case runs from a fixture directory,
# exactly as production runs from a project root — and runs the rungs in
# fixed order via a recipe shell (bash -o pipefail -c): lint
# (ADDW_RECIPE_LINT), typecheck (ADDW_RECIPE_TYPECHECK), tests
# (ADDW_RECIPE_TESTS_AFFECTED). The recipe shell has pipefail on and neither
# errexit nor nounset, so a failing non-final pipeline component fails its
# rung with that component's status, while a recipe that tolerates one on
# purpose says so with ordinary shell recovery (`cmd | filter || true`).
# Every rung runs even after an earlier one fails; recipe output goes to the
# gate's stderr. Stdout is exactly one summary line:
#
#   gate: lint <status> | typecheck <status> | tests <status>
#
# where <status> is "ok", "FAIL (exit N)", or "skipped (no recipe)". A skip
# is earned only by an explicit empty assignment (KEY=, KEY="", KEY=''): a
# recipe key absent from the config is a configuration error, refused with
# exit 78 before any rung runs, with a stderr diagnostic naming every missing
# key and no summary line (#184). An exported ADDW_RECIPE_* never stands in
# for a missing key. In the tests recipe, every {paths} occurrence is replaced
# by the shell-quoted, space-joined test paths; a recipe without the
# placeholder runs as-is. Exit 0 iff no rung failed, 1 on any failure, 2 on
# usage errors (an option-shaped argument — the retired --config among them),
# 78 on a config the grammar rejects or one missing a recipe key, 66 on no
# config at all.
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

# --- pipelines: the recipe shell runs with pipefail ---
# A failing non-final component is a failing recipe; without pipefail the
# rung would report cat's 0 and hide the linter's failure (#185).
status=0
out="$(run_gate pipe-fail 2>/dev/null)" || status=$?
assert_eq "1" "$status" "pipefail: a failing pipeline component fails the gate"
assert_eq "gate: lint FAIL (exit 1) | typecheck skipped (no recipe) | tests ok" "$out" \
  "pipefail: the rung reports the failing component's exit status"
err="$(run_gate pipe-fail 2>&1 >/dev/null)" || true
assert_contains "$err" "tests-ran-after-pipe-fail" \
  "pipefail: rungs after a pipeline failure still run"
assert_not_contains "$out" "tests-ran-after-pipe-fail" \
  "pipefail: stdout stays exactly the summary line"

out="$(run_gate pipe-pass 2>/dev/null)"
assert_eq "gate: lint ok | typecheck ok | tests ok" "$out" \
  "pipefail: a fully successful pipeline still passes"
err="$(run_gate pipe-pass 2>&1 >/dev/null)"
assert_contains "$err" "lint-ran" \
  "pipefail: pipeline output still reaches stderr"

# Explicit recovery keeps ordinary shell semantics: no errexit is imposed on
# the recipe, so a documented `|| true` handler still yields ok.
status=0
out="$(run_gate pipe-recover 2>/dev/null)" || status=$?
assert_eq 0 "$status" "pipefail: recipe-level recovery exits zero"
assert_eq "gate: lint ok | typecheck ok | tests ok" "$out" \
  "pipefail: recipe-level recovery reports ok"

# --- explicit empty keys are skipped visibly ---
out="$(run_gate all-skips 2>/dev/null)"
assert_eq \
  "gate: lint skipped (no recipe) | typecheck skipped (no recipe) | tests skipped (no recipe)" \
  "$out" "skip: an explicitly empty key, in any quoting, reports skipped"
status=0
run_gate all-skips >/dev/null 2>&1 || status=$?
assert_eq 0 "$status" "skip: an all-skipped gate exits zero"

# --- absent keys are a configuration error, refused before any rung ---
# Empty and absent used to be the same skip; since #184 only KEY= skips, so
# a deleted key cannot quietly weaken the gate. The sentinel recipes in these
# fixtures write $GATE_OUT — its absence afterwards is the proof that refusal
# came before execution.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
GATE_OUT="$tmp/received" export GATE_OUT

for pair in missing-lint:ADDW_RECIPE_LINT missing-typecheck:ADDW_RECIPE_TYPECHECK \
    missing-tests:ADDW_RECIPE_TESTS_AFFECTED; do
  fixture="${pair%%:*}"
  key="${pair#*:}"
  rm -f "$GATE_OUT"
  status=0
  out="$(run_gate "$fixture" 2>"$tmp/err")" || status=$?
  assert_eq 78 "$status" "missing $key: exits 78 (EX_CONFIG)"
  assert_eq "" "$out" "missing $key: no summary line on stdout"
  assert_contains "$(cat "$tmp/err")" "$key" \
    "missing $key: the diagnostic names the missing key"
  [ ! -e "$GATE_OUT" ] || fail "missing $key: a recipe ran before the refusal"
done

# every missing key is named in one refusal, not just the first found
rm -f "$GATE_OUT"
status=0
err="$(run_gate missing-two 2>&1 >/dev/null)" || status=$?
assert_eq 78 "$status" "missing two: exits 78"
assert_contains "$err" "ADDW_RECIPE_LINT" "missing two: names the lint key"
assert_contains "$err" "ADDW_RECIPE_TESTS_AFFECTED" "missing two: names the tests key"
assert_not_contains "$err" "ADDW_RECIPE_TYPECHECK" \
  "missing two: does not name the key that is present"
[ ! -e "$GATE_OUT" ] || fail "missing two: the configured rung ran before the refusal"

# added at codex round 1 (#4), kept under the new contract: recipes come from
# the config alone — an inherited environment value cannot satisfy a key the
# config does not set, so the refusal stands even with the keys exported
rm -f "$GATE_OUT"
status=0
ADDW_RECIPE_LINT="echo env-leak" ADDW_RECIPE_TESTS_AFFECTED="echo env-leak" \
  run_gate missing-two >/dev/null 2>&1 || status=$?
assert_eq 78 "$status" "missing: exported ADDW_RECIPE_* never substitutes for missing keys"
[ ! -e "$GATE_OUT" ] || fail "missing: an exported recipe let a rung run"

# --- {paths} substitution ---
rm -f "$GATE_OUT"
run_gate paths tests/a.test.sh "tests/b c.test.sh" >/dev/null 2>&1
assert_eq "tests/a.test.sh tests/b c.test.sh" "$(cat "$GATE_OUT")" \
  "paths: {paths} receives every selected path, space-safe"

# On bash 5.2 an unquoted replacement turns the escape in `a\&b` into a bare
# `&`, backgrounding part of the recipe (#235).
rm -f "$GATE_OUT"
run_gate paths 'tests/a&b.test.sh' >/dev/null 2>&1
assert_eq 'tests/a&b.test.sh' "$(cat "$GATE_OUT")" \
  "paths: an ampersand in a path reaches the recipe escaped"

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

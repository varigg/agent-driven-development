#!/usr/bin/env bash
# Deterministic testing gate over the project config's recipe ladder. Why the
# ladder is shaped this way, and where its summary line is consumed:
# ../README.md.
#
# Usage: gate.sh [test-path...]   (run from the project root)
#
#   test-path...      affected-test selection; replaces every {paths}
#                     occurrence in the tests recipe, shell-quoted and
#                     space-joined. A recipe without {paths} runs as-is.
#
# Recipes come from docs/addw.env through the shared config reader — the
# reader answers from the file alone, so an exported ADDW_RECIPE_* never
# stands in for a key the config doesn't set. All three recipe keys must be
# present: an explicit empty assignment (KEY=) is the one way to skip a rung,
# and a key absent from the file is a configuration error — refused before
# any rung runs, every missing key named on stderr, exit 78.
# Each non-empty recipe runs in a shell with pipefail enabled, but without
# errexit or nounset. A recipe intentionally tolerating an upstream failure
# must recover explicitly, such as with "cmd | filter || true".
#
# Rung order is fixed: lint (ADDW_RECIPE_LINT), typecheck
# (ADDW_RECIPE_TYPECHECK), tests (ADDW_RECIPE_TESTS_AFFECTED). Every rung runs
# even after an earlier one fails, and an empty key reports "skipped (no
# recipe)". Stdout carries exactly one summary line; recipe output goes to
# stderr. Exit 0 iff no rung failed, 1 on any failure, 2 on usage errors; a
# missing or unreadable config exits 66 or 77, and one the grammar rejects or
# one missing a recipe key exits 78 (EX_CONFIG), each with a diagnostic.
set -euo pipefail

case "${1:-}" in
  -*)
    printf 'gate.sh: unknown option %s — usage: gate.sh [test-path...]\n' "$1" >&2
    exit 2
    ;;
esac

# shellcheck source=../config/config.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/config.sh"
recipe_keys=(ADDW_RECIPE_LINT ADDW_RECIPE_TYPECHECK ADDW_RECIPE_TESTS_AFFECTED)
config_source "${recipe_keys[@]}"

# Presence, not value: config_source leaves an absent key unset and an
# explicit KEY= set-but-empty, and only the latter is a skip. Checked for all
# three before any rung runs, so one refusal names everything to fix.
missing=0
for key in "${recipe_keys[@]}"; do
  if ! declare -p "$key" >/dev/null 2>&1; then
    printf '%s: %s absent — a rung is skipped only by an explicit %s= assignment\n' \
      "$ADDW_CONFIG_FILE" "$key" "$key" >&2
    missing=1
  fi
done
[ "$missing" -eq 0 ] || exit 78

quoted_paths=""
sep=""
for p in "$@"; do
  quoted_paths="$quoted_paths$sep$(printf '%q' "$p")"
  sep=" "
done

failed=0
RUNG_STATUS=""
run_rung() { # recipe — runs it, leaves the status text in RUNG_STATUS
  local recipe="$1" status=0
  if [ -z "$recipe" ]; then
    RUNG_STATUS="skipped (no recipe)"
    return
  fi
  bash -o pipefail -c "$recipe" >&2 || status=$?
  if [ "$status" -eq 0 ]; then
    RUNG_STATUS="ok"
  else
    RUNG_STATUS="FAIL (exit $status)"
    failed=1
  fi
}

run_rung "${ADDW_RECIPE_LINT:-}"
lint_status="$RUNG_STATUS"

run_rung "${ADDW_RECIPE_TYPECHECK:-}"
typecheck_status="$RUNG_STATUS"

tests_recipe="${ADDW_RECIPE_TESTS_AFFECTED:-}"
# Quoted replacement: bash 5.2 patsub_replacement would otherwise read the
# `&` in an escaped path as "the matched text".
tests_recipe="${tests_recipe//\{paths\}/"$quoted_paths"}"
run_rung "$tests_recipe"
tests_status="$RUNG_STATUS"

printf 'gate: lint %s | typecheck %s | tests %s\n' \
  "$lint_status" "$typecheck_status" "$tests_status"
[ "$failed" -eq 0 ]

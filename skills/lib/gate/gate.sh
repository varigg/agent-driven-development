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
# stands in for a key the config doesn't set.
#
# Rung order is fixed: lint (ADDW_RECIPE_LINT), typecheck
# (ADDW_RECIPE_TYPECHECK), tests (ADDW_RECIPE_TESTS_AFFECTED). Every rung runs
# even after an earlier one fails, and a missing or empty key reports
# "skipped (no recipe)". Stdout carries exactly one summary line; recipe output
# goes to stderr. Exit 0 iff no rung failed, 1 on any failure, 2 on usage
# errors; a missing, unreadable, or invalid config exits 66, 77, or 78
# (EX_CONFIG) with the reader's diagnostic.
set -euo pipefail

case "${1:-}" in
  -*)
    printf 'gate.sh: unknown option %s — usage: gate.sh [test-path...]\n' "$1" >&2
    exit 2
    ;;
esac

# shellcheck source=../config/config.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/config.sh"
config_source ADDW_RECIPE_LINT ADDW_RECIPE_TYPECHECK ADDW_RECIPE_TESTS_AFFECTED

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
  bash -c "$recipe" >&2 || status=$?
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
tests_recipe="${tests_recipe//\{paths\}/$quoted_paths}"
run_rung "$tests_recipe"
tests_status="$RUNG_STATUS"

printf 'gate: lint %s | typecheck %s | tests %s\n' \
  "$lint_status" "$typecheck_status" "$tests_status"
[ "$failed" -eq 0 ]

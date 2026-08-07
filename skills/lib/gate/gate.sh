#!/usr/bin/env bash
# Deterministic testing gate. Sources the project config and runs the recipe
# ladder in fixed order — lint (ADDW_RECIPE_LINT), typecheck
# (ADDW_RECIPE_TYPECHECK), tests (ADDW_RECIPE_TESTS_AFFECTED) — reporting
# every rung in one summary line on stdout, the line PR bodies carry
# verbatim. Recipe output goes to stderr; stdout is only the summary.
#
# Usage: gate.sh [--config <file>] [test-path...]
#
#   --config <file>   project config to source (default: docs/addw.env)
#   test-path...      affected-test selection; replaces every {paths}
#                     occurrence in the tests recipe, shell-quoted and
#                     space-joined. A recipe without {paths} runs as-is.
#
# Every rung runs even after an earlier one fails. A missing or empty recipe
# key reports "skipped (no recipe)" — visible, never silent. Exit 0 iff no
# rung failed, 1 on any failure, 2 on usage errors or an unreadable config.
set -euo pipefail

config="docs/addw.env"
if [ "${1:-}" = "--config" ]; then
  if [ "$#" -lt 2 ]; then
    printf 'gate.sh: --config requires a file argument\n' >&2
    exit 2
  fi
  config="$2"
  shift 2
fi

if [ ! -r "$config" ]; then
  printf 'gate.sh: cannot read config: %s\n' "$config" >&2
  exit 2
fi
# shellcheck disable=SC1090
. "$config"

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

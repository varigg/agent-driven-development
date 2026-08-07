#!/usr/bin/env bash
# Contract: tests/run.sh — discovers *.test.sh in a directory (default: tests/),
# runs each, reports per-file results, exits non-zero when any test fails
# or when no tests are found.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

RUN=./run.sh
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir "$tmp/mixed" "$tmp/green" "$tmp/empty"

printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/mixed/pass.test.sh"
printf '#!/usr/bin/env bash\necho boom >&2\nexit 1\n' > "$tmp/mixed/fail.test.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/green/pass.test.sh"
printf 'not a test\n' > "$tmp/mixed/README.md"

# A failing test fails the run and is named in the output.
status=0
out="$(bash "$RUN" "$tmp/mixed" 2>&1)" || status=$?
[ "$status" -ne 0 ] || fail "runner: failing test must produce non-zero exit"
assert_contains "$out" "fail.test.sh" "runner: failing file is named"
assert_contains "$out" "boom" "runner: failing test's output is shown"

# An all-green directory passes.
assert_exit 0 "runner: all-green directory exits zero" bash "$RUN" "$tmp/green"

# Discovering nothing is an error, never a silent green.
assert_exit 1 "runner: empty directory exits non-zero" bash "$RUN" "$tmp/empty"

echo "runner: all assertions passed"

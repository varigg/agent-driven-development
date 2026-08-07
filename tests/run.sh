#!/usr/bin/env bash
# Plain-bash test runner. Discovers *.test.sh in a directory (default: this
# script's own directory), runs each in its own bash process, and exits
# non-zero when any test fails. Finding no tests is an error, never a green.
set -euo pipefail

dir="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

if [ ! -d "$dir" ]; then
  printf 'run.sh: not a directory: %s\n' "$dir" >&2
  exit 1
fi

tests=()
while IFS= read -r f; do
  tests+=("$f")
done < <(find "$dir" -maxdepth 1 -name '*.test.sh' -type f | LC_ALL=C sort)

if [ "${#tests[@]}" -eq 0 ]; then
  printf 'run.sh: no *.test.sh files found in %s\n' "$dir" >&2
  exit 1
fi

passed=0
failed=0
for t in "${tests[@]}"; do
  name="$(basename "$t")"
  status=0
  output="$(bash "$t" 2>&1)" || status=$?
  if [ "$status" -eq 0 ]; then
    printf 'ok   %s\n' "$name"
    passed=$((passed + 1))
  else
    printf 'FAIL %s (exit %d)\n' "$name" "$status"
    printf '%s\n' "$output" | sed 's/^/     /'
    failed=$((failed + 1))
  fi
done

printf '%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]

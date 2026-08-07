#!/usr/bin/env bash
# Contract: every tracker operation routes through skills/lib/tracker — no
# script outside the layer invokes the tracker CLI (gh issue/api/label/search)
# directly. The two codex-spec-review scripts predate the layer and are
# allowlisted until ticket #8 reroutes them; shrinking this list is progress,
# growing it is a contract violation.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
. tests/lib.sh

allowlist=(
  skills/codex-spec-review/scripts/start.sh
  skills/codex-spec-review/scripts/_fetch.sh
)

pattern='(^|[^[:alnum:]_.])gh[[:space:]]+(api|issue|label|search)'

violations=""
while IFS= read -r f; do
  case "$f" in
    skills/lib/tracker/*) continue ;;
  esac
  for allowed in "${allowlist[@]}"; do
    [ "$f" = "$allowed" ] && continue 2
  done
  if grep -qE "$pattern" "$f"; then
    violations="$violations$f"$'\n'
  fi
done < <(git ls-files 'skills/*.sh' 'skills/**/*.sh' 'skills/**/*.tpl' 'tests/*.sh' \
           | grep -v '^tests/tracker-seam.test.sh$')

if [ -n "$violations" ]; then
  fail "tracker CLI invoked outside skills/lib/tracker:"$'\n'"$violations"
fi

echo "tracker-seam: no tracker CLI use outside the layer"

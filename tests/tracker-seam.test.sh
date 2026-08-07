#!/usr/bin/env bash
# Contract: every tracker operation routes through skills/lib/tracker — no
# script outside the layer invokes the tracker CLI (gh issue/api/label/search)
# directly. There is no allowlist: the scan covers the skills' scripts, their
# prompt templates, and their agent-facing instructions, because a SKILL.md
# telling the agent to run `gh issue edit` bypasses the seam exactly as a
# script would.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
. tests/lib.sh

pattern='(^|[^[:alnum:]_.])gh[[:space:]]+(api|issue|label|search)'

violations=""
while IFS= read -r f; do
  case "$f" in
    skills/lib/tracker/*) continue ;;
  esac
  if grep -qE "$pattern" "$f"; then
    violations="$violations$f"$'\n'
  fi
done < <(git ls-files 'skills/*.sh' 'skills/**/*.sh' 'skills/**/*.tpl' \
           'skills/*.md' 'skills/**/*.md' 'tests/*.sh' \
           | grep -v '^tests/tracker-seam.test.sh$')

if [ -n "$violations" ]; then
  fail "tracker CLI invoked outside skills/lib/tracker:"$'\n'"$violations"
fi

echo "tracker-seam: no tracker CLI use outside the layer"

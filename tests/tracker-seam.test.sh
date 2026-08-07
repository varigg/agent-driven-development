#!/usr/bin/env bash
# Contract: every *tracker* operation routes through skills/lib/tracker — no
# script outside the layer performs one with the CLI directly. The scan covers
# the skills' scripts, their prompt templates, and their agent-facing
# instructions, because a SKILL.md telling the agent to run `gh issue edit`
# bypasses the seam exactly as a script would.
#
# Tracker operations are issue operations: body get/edit, labels, comments,
# close-with-reason, assignment, and the frontier/completion queries. Pull
# requests are not tracker work and never were behind this seam — `gh pr` is
# used freely by addw-implement and addw-hotfix — so the scan does not flag it.
#
# The one carve-out is `gh api` against a `/pulls/` endpoint, which reads PR
# review comments that no `gh pr` subcommand exposes (cli/cli#5788). It cannot
# smuggle a tracker operation past the seam: GitHub's REST API routes labels,
# state changes, and body edits exclusively through `/issues/`, which stays
# flagged. Note the asymmetry that makes the carve-out safe — `/issues/<n>`
# also addresses a pull request, but no `/pulls/` path addresses an issue.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
. tests/lib.sh

pattern='(^|[^[:alnum:]_.])gh[[:space:]]+(api|issue|label|search)'
# Lines exempted from the pattern above: `gh api` on a pull-request endpoint.
exempt='(^|[^[:alnum:]_.])gh[[:space:]]+api[^|;&]*/pulls/'

# Self-check the carve-out before scanning with it: a regex that stopped
# catching `/issues/` work would turn this whole test into a no-op, and the
# scan itself cannot notice that.
flags_line() { # line — true when the pair of regexes would report it
  printf '%s\n' "$1" | grep -E "$pattern" | grep -qvE "$exempt"
}
flags_line 'gh api "repos/o/r/pulls/12/comments" --paginate' \
  && fail "carve-out: a /pulls/ endpoint should not be flagged"
for banned in \
  'gh api repos/o/r/issues/12/labels' \
  'gh api repos/o/r/issues/12/comments' \
  'gh api graphql -f query=@close.gql' \
  'gh issue edit 12 --body-file b.md' \
  'gh label create spec'
do
  flags_line "$banned" \
    || fail "carve-out too wide: '$banned' should still be flagged"
done

violations=""
while IFS= read -r f; do
  case "$f" in
    skills/lib/tracker/*) continue ;;
  esac
  if grep -E "$pattern" "$f" | grep -qvE "$exempt"; then
    violations="$violations$f"$'\n'
  fi
done < <(git ls-files 'skills/*.sh' 'skills/**/*.sh' 'skills/**/*.tpl' \
           'skills/*.md' 'skills/**/*.md' 'tests/*.sh' \
           | grep -v '^tests/tracker-seam.test.sh$')

if [ -n "$violations" ]; then
  fail "tracker CLI invoked outside skills/lib/tracker:"$'\n'"$violations"
fi

echo "tracker-seam: no tracker CLI use outside the layer"

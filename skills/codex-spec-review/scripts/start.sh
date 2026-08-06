#!/usr/bin/env bash
# Turn 1: start a fresh Codex spec-review session for GitHub issue <N>
# (adapter entry point). Dumps the issue body into this skill's state as
# the review target / edit buffer, then hands off to the shared runner
# with this skill's prompt and state (same wrapper pattern as
# codex-code-review). Exit 2 from the runner means a thread already
# exists — use resume.sh.
#
# Usage: start.sh [--refresh] <issue-number> [extra prompt text…]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${STATE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)/state}"
export STATE_DIR
# shellcheck source=_fetch.sh
source "$SCRIPT_DIR/_fetch.sh"

REFRESH=""
if [ "${1:-}" = "--refresh" ]; then
    REFRESH="--refresh"; shift
fi
if [ $# -lt 1 ]; then
    echo "usage: start.sh [--refresh] <issue-number> [extra prompt text…]" >&2
    exit 64
fi
ISSUE="$1"; shift
require_issue_number "$ISSUE"

mkdir -p "$STATE_DIR"
BUFFER="$STATE_DIR/issue-$ISSUE.md"
TITLE="$(gh issue view "$ISSUE" --json title -q .title)"
fetch_issue_body "$ISSUE" "$BUFFER" "$REFRESH"

exec bash "$SCRIPT_DIR/../../codex-plan-review/scripts/start.sh" \
    --prompt-file "$SCRIPT_DIR/../prompts/start.tpl" \
    "$BUFFER" "Spec under review: GitHub issue #$ISSUE — $TITLE." "$@"

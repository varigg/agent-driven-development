#!/usr/bin/env bash
# Turn 1: start a fresh code-review session for the branch implementing
# GitHub issue <N> (adapter entry point). Builds this skill's per-issue
# context buffer from the tracker, then hands off to the shared runner with
# this skill's prompt and state (read-only sandbox). The buffer is the
# runner's target, so the thread keys on the issue.
#
# Usage: start.sh <issue-number> [extra prompt text…]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${STATE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)/state}"
export STATE_DIR
# shellcheck source=_fetch.sh
source "$SCRIPT_DIR/_fetch.sh"

if [ $# -lt 1 ]; then
    echo "usage: start.sh <issue-number> [extra prompt text…]" >&2
    exit 64
fi
ISSUE="$1"; shift
require_issue_number "$ISSUE"

BUFFER="$STATE_DIR/issue-$ISSUE.context.md"
TITLE="$(bash "$TRACKER" title "$ISSUE")"
build_context "$ISSUE" "$BUFFER"

exec bash "$SCRIPT_DIR/../../lib/codex/start.sh" \
    --prompt-file "$SCRIPT_DIR/../prompts/start.tpl" \
    "$BUFFER" "Ticket under review: GitHub issue #$ISSUE — $TITLE." "$@"

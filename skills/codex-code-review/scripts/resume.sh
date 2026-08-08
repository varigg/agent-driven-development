#!/usr/bin/env bash
# Turn 2+: resume the code-review session for GitHub issue <N> (adapter
# entry point). Rebuilds the context buffer from the tracker — a ticket
# edited mid-flight should be reviewed as it now reads — then hands off to
# the shared runner with this skill's prompt and state.
#
# Usage: resume.sh [--notes "…"] <issue-number> [extra prompt text…]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${STATE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)/state}"
export STATE_DIR
# shellcheck source=_fetch.sh
source "$SCRIPT_DIR/_fetch.sh"

NOTES_ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --notes)   NOTES_ARGS=(--notes "$2"); shift 2 ;;
        --notes=*) NOTES_ARGS=("$1"); shift ;;
        --) shift; break ;;
        -*) echo "error: unknown flag: $1" >&2; exit 64 ;;
        *)  break ;;
    esac
done
if [ $# -lt 1 ]; then
    echo "usage: resume.sh [--notes \"…\"] <issue-number> [extra prompt text…]" >&2
    exit 64
fi
ISSUE="$1"; shift
require_issue_number "$ISSUE"

BUFFER="$STATE_DIR/issue-$ISSUE.context.md"
build_context "$ISSUE" "$BUFFER"

exec bash "$SCRIPT_DIR/../../lib/codex/resume.sh" \
    --prompt-file "$SCRIPT_DIR/../prompts/resume.tpl" \
    ${NOTES_ARGS[@]+"${NOTES_ARGS[@]}"} \
    "$BUFFER" "$@"

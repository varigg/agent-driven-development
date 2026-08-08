#!/usr/bin/env bash
# Turn 2+: resume the spec-review session for GitHub issue <N> (adapter
# entry point). Re-syncs the body buffer from GitHub — refusing if it
# holds unpushed local edits — then hands off to the shared runner.
#
# Usage: resume.sh [--refresh] [--notes "…"] <issue-number> [extra prompt text…]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${STATE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)/state}"
export STATE_DIR
# shellcheck source=_fetch.sh
source "$SCRIPT_DIR/_fetch.sh"

REFRESH=""
NOTES_ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --refresh) REFRESH="--refresh"; shift ;;
        --notes)   NOTES_ARGS=(--notes "$2"); shift 2 ;;
        --notes=*) NOTES_ARGS=("$1"); shift ;;
        --) shift; break ;;
        -*) echo "error: unknown flag: $1" >&2; exit 64 ;;
        *)  break ;;
    esac
done
if [ $# -lt 1 ]; then
    echo "usage: resume.sh [--refresh] [--notes \"…\"] <issue-number> [extra prompt text…]" >&2
    exit 64
fi
ISSUE="$1"; shift
require_issue_number "$ISSUE"

mkdir -p "$STATE_DIR"
BUFFER="$STATE_DIR/issue-$ISSUE.md"
fetch_issue_body "$ISSUE" "$BUFFER" "$REFRESH"

exec bash "$SCRIPT_DIR/../../lib/codex/resume.sh" \
    --prompt-file "$SCRIPT_DIR/../prompts/resume.tpl" \
    ${NOTES_ARGS[@]+"${NOTES_ARGS[@]}"} \
    "$BUFFER" "$@"

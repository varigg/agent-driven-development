#!/usr/bin/env bash
# Drop the per-issue thread id, review, and event log so the next
# start.sh begins a fresh Codex session. The body buffer is left in
# place — start.sh re-syncs it (and guards unpushed edits) anyway.
#
# Usage: reset.sh <issue-number>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${STATE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)/state}"
export STATE_DIR
# shellcheck source=_fetch.sh
source "$SCRIPT_DIR/_fetch.sh"

if [ $# -ne 1 ]; then
    echo "usage: reset.sh <issue-number>" >&2
    exit 64
fi
require_issue_number "$1"

exec bash "$SCRIPT_DIR/../../lib/codex/reset.sh" \
    "$STATE_DIR/issue-$1.md"

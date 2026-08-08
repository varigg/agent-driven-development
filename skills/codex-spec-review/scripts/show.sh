#!/usr/bin/env bash
# Show the most recent review for GitHub issue <N> without re-running
# Codex. Useful when the conversation has scrolled past the review.
#
# Usage: show.sh <issue-number>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${STATE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)/state}"
export STATE_DIR
# shellcheck source=_fetch.sh
source "$SCRIPT_DIR/_fetch.sh"

if [ $# -ne 1 ]; then
    echo "usage: show.sh <issue-number>" >&2
    exit 64
fi
require_issue_number "$1"

exec bash "$SCRIPT_DIR/../../lib/codex/show.sh" \
    "$STATE_DIR/issue-$1.md"

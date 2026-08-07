#!/usr/bin/env bash
# Shared helper for the codex-spec-review wrappers: locate the tracker
# layer, validate the issue number, and sync the per-issue body buffer.
# Source-only.
#
# The buffer ($STATE_DIR/issue-<N>.md) is both the review target handed
# to the shared runner and the edit buffer for pushing fixes back via
# `tracker.sh edit-body <N>`. Syncing refuses to overwrite a buffer that
# differs from the remote body: that state means either unpushed local
# edits (push them first) or an out-of-band edit on GitHub (re-run with
# --refresh to accept the remote as truth).
#
# Trailing newlines are not a difference. The layer's body read ends its
# output with one that the stored body does not carry, so comparing bytes
# reports a buffer that was just pushed successfully as divergent. Both
# sides are normalized before the comparison; everything else still
# refuses.

set -euo pipefail

# The tracker seam: every tracker operation in this skill goes through it.
TRACKER="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/tracker/tracker.sh"
if [ ! -f "$TRACKER" ]; then
    echo "error: tracker layer not found at $TRACKER" >&2
    echo "       skills/lib must be installed alongside the skills." >&2
    exit 1
fi

require_issue_number() {
    case "${1:-}" in
        ''|*[!0-9]*)
            echo "error: <issue-number> must be numeric, got: ${1:-<empty>}" >&2
            exit 64 ;;
    esac
}

# fetch_issue_body <issue-number> <buffer-file> [--refresh]
fetch_issue_body() {
    local issue="$1" file="$2" refresh="${3:-}"
    local tmp="$file.remote"
    bash "$TRACKER" body "$issue" > "$tmp"
    # Command substitution strips every trailing newline from both sides —
    # that is the normalization, not an accident of the comparison.
    if [ -f "$file" ] && [ "$(cat "$tmp")" != "$(cat "$file")" ]; then
        if [ "$refresh" = "--refresh" ]; then
            mv -- "$tmp" "$file"
            echo "refreshed $file from the issue body on GitHub" >&2
        else
            rm -- "$tmp"
            echo "error: $file differs from the current body of issue #$issue." >&2
            echo "Push local edits first (tracker.sh edit-body $issue $file)," >&2
            echo "or pass --refresh to overwrite the buffer from GitHub." >&2
            exit 3
        fi
    else
        mv -- "$tmp" "$file"
    fi
}

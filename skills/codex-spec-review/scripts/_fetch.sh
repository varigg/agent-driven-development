#!/usr/bin/env bash
# Shared helper for the codex-spec-review wrappers: validate the issue
# number and sync the per-issue body buffer from GitHub. Source-only.
#
# The buffer ($STATE_DIR/issue-<N>.md) is both the review target handed
# to the shared runner and the edit buffer for pushing fixes back via
# `gh issue edit <N> --body-file`. Syncing refuses to overwrite a buffer
# that differs from the remote body: that state means either unpushed
# local edits (push them first) or an out-of-band edit on GitHub
# (re-run with --refresh to accept the remote as truth).

set -euo pipefail

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
    gh issue view "$issue" --json body -q .body > "$tmp"
    if [ -f "$file" ] && ! cmp -s "$tmp" "$file"; then
        if [ "$refresh" = "--refresh" ]; then
            mv -- "$tmp" "$file"
            echo "refreshed $file from the issue body on GitHub" >&2
        else
            rm -- "$tmp"
            echo "error: $file differs from the current body of issue #$issue." >&2
            echo "Push local edits first (gh issue edit $issue --body-file $file)," >&2
            echo "or pass --refresh to overwrite the buffer from GitHub." >&2
            exit 3
        fi
    else
        mv -- "$tmp" "$file"
    fi
}

#!/usr/bin/env bash
# Shared helper for the codex-code-review wrappers: locate the tracker
# layer, validate the issue number, and build the per-issue context
# buffer. Source-only.
#
# The buffer ($STATE_DIR/issue-<N>.context.md) is the review target handed
# to the shared runner, so the thread keys on the issue. It exists because
# the reviewer runs in a read-only sandbox with no network: it cannot fetch
# the ticket itself, and the diff alone does not say what the change was
# supposed to do. Unlike codex-spec-review's buffer this one is read-only
# context — never an edit vehicle — so it is rebuilt from the tracker on
# every start rather than guarded against divergence.
#
# The parent spec is included when the ticket declares one. Spec membership
# is optional by contract: a standalone ticket reviews fine against its own
# acceptance criteria, and the buffer says so rather than going silent.

set -euo pipefail

# The tracker seam: every tracker operation in this skill goes through it.
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib"
TRACKER="$LIB/tracker/tracker.sh"
PARSE="$LIB/tracker/parse.sh"
if [ ! -f "$TRACKER" ] || [ ! -f "$PARSE" ]; then
    echo "error: tracker layer not found at $LIB/tracker" >&2
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

# build_context <issue-number> <buffer-file>
# Writes the ticket and, when declared, its parent spec into the buffer.
build_context() {
    local issue="$1" file="$2" body parent
    mkdir -p "$(dirname "$file")"
    body="$(bash "$TRACKER" body "$issue")"

    {
        printf '# Ticket #%s — %s\n\n' "$issue" "$(bash "$TRACKER" title "$issue")"
        printf '%s\n' "$body"
    } > "$file"

    parent="$(printf '%s\n' "$body" | bash "$PARSE" parent)"
    if [ -n "$parent" ]; then
        {
            printf '\n---\n\n# Parent spec #%s — %s\n\n' \
                "$parent" "$(bash "$TRACKER" title "$parent")"
            bash "$TRACKER" body "$parent"
            printf '\n'
        } >> "$file"
    else
        printf '\n---\n\nNo parent spec: this ticket stands alone. Review it against its own acceptance criteria.\n' \
            >> "$file"
    fi
}

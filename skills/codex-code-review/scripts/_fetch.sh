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
# The buffer also names the configured ADR directory. The reviewer is read-only
# and offline, so configuration needed to interpret checklist references must
# travel with the context; an absent value is stated explicitly rather than
# guessed, and the reviewer is told to report the guardrail item as unperformed
# rather than pass it. Whether a project may lack the key at all is doctor's
# question, not this adapter's — doctor already fails an install missing it,
# and refusing to review would withhold the check that finds problems from the
# install least likely to have none.

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
    local issue="$1" file="$2" body parent adr_dir
    mkdir -p "$(dirname "$file")"
    body="$(bash "$TRACKER" body "$issue")"

    # Command substitution is already a subshell, so the config's other keys
    # never reach the caller. Unsetting first keeps an exported value from
    # making an unconfigured project look configured, and the source's own
    # stdout is discarded so only the key's value is captured.
    #
    # The key is read after the source regardless of its exit status: `.`
    # returns the status of the config's last command, so gating on it would
    # report a correctly-configured project as unconfigured whenever its
    # config happens to end on a conditional. A config that fails to parse
    # says so on stderr and leaves the key unset, which the absent branch
    # below already covers; one that calls `exit` takes the subshell with it,
    # so the assignment itself falls back rather than aborting the review.
    adr_dir="$(
        unset ADDW_ADR_DIR
        if [ -r "docs/addw.env" ]; then
            # shellcheck disable=SC1091
            . "docs/addw.env" >/dev/null || true
        fi
        printf '%s' "${ADDW_ADR_DIR:-}"
    )" || adr_dir=""

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

    if [ -n "$adr_dir" ]; then
        printf '\n---\n\nADR directory for guardrail review: `%s`\n' "$adr_dir" >> "$file"
    else
        printf '\n---\n\nADR directory for guardrail review: none. `ADDW_ADR_DIR` did not resolve from this project'"'"'s config, so the guardrail-ADR checklist item cannot be performed. Do not guess a path, and do not pass the item quietly: report it as **not performed**, naming `ADDW_ADR_DIR` as the reason.\n' \
            >> "$file"
    fi
}

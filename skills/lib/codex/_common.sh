#!/usr/bin/env bash
# Shared paths, key derivation, and prompt-loading helpers for all Codex
# adapters. Source-only.

set -euo pipefail

if [ -z "${STATE_DIR:-}" ]; then
    echo "error: STATE_DIR is required; caller must pin it" >&2
    exit 64
fi
export STATE_DIR
mkdir -p "$STATE_DIR"

# Model/effort per flow, resolved below and the single source of truth for all
# codex skills: the fallbacks in that resolution are the defaults, a project
# overrides them from docs/addw.env, and CODEX_MODEL / CODEX_EFFORT override
# both per run.
# The config is read through the shared reader, whose config_source keys come
# from the file alone (unset-first, so a value inherited from the environment
# cannot make an unconfigured project look configured). A missing config is an
# unconfigured project and the defaults below apply; an invalid one is a
# defect and stays fatal (78, EX_CONFIG), with the parser's line-numbered
# diagnostic relayed because this runs mid-workflow, where the line number is
# the whole remedy.
# shellcheck source=../config/config.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/config.sh"
config_source ADDW_CODEX_MODEL_IMPL ADDW_CODEX_MODEL_REVIEW ADDW_CODEX_EFFORT || {
    config_status=$?
    [ "$config_status" -eq 66 ] || exit "$config_status"
}
# The flow is the adapter's declared CODEX_ROLE (impl|review), default review:
# only codex-implement sets impl. It is never guessed from STATE_DIR's text.
case "${CODEX_ROLE:-review}" in
    impl)   CODEX_MODEL="${CODEX_MODEL:-${ADDW_CODEX_MODEL_IMPL:-gpt-5.6-luna}}" ;;
    review) CODEX_MODEL="${CODEX_MODEL:-${ADDW_CODEX_MODEL_REVIEW:-gpt-5.6-sol}}" ;;
    *)
        echo "error: CODEX_ROLE must be impl or review, got: $CODEX_ROLE" >&2
        exit 64
        ;;
esac
CODEX_EFFORT="${CODEX_EFFORT:-${ADDW_CODEX_EFFORT:-xhigh}}"
export CODEX_MODEL CODEX_EFFORT

# Derive a per-target key from a path-like string. For real paths we
# resolve to absolute; for non-path targets (branch names, commit
# ranges) we sanitize in place. Replace '/' with '__'; force any other
# non-portable characters to '_'.
target_key() {
    local target="$1"
    if [ -e "$target" ]; then
        local abs
        abs="$(realpath -- "$target" 2>/dev/null || readlink -f -- "$target")"
        if [ -z "$abs" ]; then
            echo "error: cannot resolve target path: $target" >&2
            return 1
        fi
        printf '%s' "$abs" | sed 's|^/||; s|/|__|g'
    else
        printf '%s' "$target" | sed 's|^/||; s|/|__|g; s|[^A-Za-z0-9._-]|_|g'
    fi
}

thread_file() {
    printf '%s/%s.thread' "$STATE_DIR" "$(target_key "$1")"
}

review_file() {
    printf '%s/%s.review.txt' "$STATE_DIR" "$(target_key "$1")"
}

events_file() {
    printf '%s/%s.events.ndjson' "$STATE_DIR" "$(target_key "$1")"
}

# Load a prompt template from $1 and substitute {{TARGET}} and
# {{EXTRA_PROMPT}} placeholders with the values of the $TARGET and
# $EXTRA_PROMPT environment variables. Other text passes through
# verbatim — no surprise expansion of unrelated $VAR sequences.
# Writes the substituted prompt to stdout.
load_prompt() {
    local tpl="$1"
    if [ ! -f "$tpl" ]; then
        echo "error: prompt template not found: $tpl" >&2
        return 1
    fi
    # ENVIRON, not awk -v / gsub: -v reprocesses backslash escapes and gsub
    # treats & in the replacement as the matched text, both of which mangle
    # free-text notes. Literal index/substr replacement does neither.
    T="${TARGET-}" X="${EXTRA_PROMPT-}" N="${IMPLEMENTER_NOTES-}" awk '
        function sub_all(line, key, val,    out, i) {
            out = ""
            while ((i = index(line, key)) > 0) {
                out = out substr(line, 1, i - 1) val
                line = substr(line, i + length(key))
            }
            return out line
        }
        {
            $0 = sub_all($0, "{{TARGET}}", ENVIRON["T"])
            $0 = sub_all($0, "{{EXTRA_PROMPT}}", ENVIRON["X"])
            $0 = sub_all($0, "{{IMPLEMENTER_NOTES}}", ENVIRON["N"])
            print
        }
    ' "$tpl"
}

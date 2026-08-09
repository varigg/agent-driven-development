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

# Model/effort per flow (single source of truth for all codex skills):
# implementation runs Luna, reviews (spec + code) run Sol, effort xhigh.
# Per-project overrides come from docs/addw.env (ADDW_CODEX_MODEL_IMPL /
# ADDW_CODEX_MODEL_REVIEW / ADDW_CODEX_EFFORT); CODEX_MODEL / CODEX_EFFORT
# env vars act as per-run overrides on top of both.
# These three come from the config alone. Clearing them first stops a value
# inherited from the environment from making an unconfigured project look
# configured, which is the property the other config readers hold too. The
# subshell below inherits the cleared state, so it needs no unset of its own.
unset ADDW_CODEX_MODEL_IMPL ADDW_CODEX_MODEL_REVIEW ADDW_CODEX_EFFORT
if [ -f "docs/addw.env" ]; then
    # A config that cannot be parsed is a defect and stays fatal; only the
    # sourcing's exit status is forgiven below. The parser's own diagnostic
    # is relayed because this runs mid-workflow, where the line number is
    # the whole remedy.
    if ! config_error="$(bash -n "docs/addw.env" 2>&1)"; then
        echo "error: docs/addw.env is not shell-sourceable" >&2
        [ -z "$config_error" ] || printf '%s\n' "$config_error" >&2
        exit 78
    fi

    # Read only the runner's keys in a subshell. The config's stdout is
    # discarded, and its status or an exit inside it cannot reach this shell.
    config_values=()
    mapfile -t config_values < <(
        # shellcheck disable=SC1091
        . "docs/addw.env" >/dev/null || true
        printf '%s\n' \
            "${ADDW_CODEX_MODEL_IMPL:-}" \
            "${ADDW_CODEX_MODEL_REVIEW:-}" \
            "${ADDW_CODEX_EFFORT:-}"
    )
    ADDW_CODEX_MODEL_IMPL="${config_values[0]:-}"
    ADDW_CODEX_MODEL_REVIEW="${config_values[1]:-}"
    ADDW_CODEX_EFFORT="${config_values[2]:-}"
fi
case "$STATE_DIR" in
    *codex-implement*) CODEX_MODEL="${CODEX_MODEL:-${ADDW_CODEX_MODEL_IMPL:-gpt-5.6-luna}}" ;;
    *)                 CODEX_MODEL="${CODEX_MODEL:-${ADDW_CODEX_MODEL_REVIEW:-gpt-5.6-sol}}" ;;
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
    awk -v target="${TARGET-}" -v extra="${EXTRA_PROMPT-}" -v notes="${IMPLEMENTER_NOTES-}" '
        {
            gsub(/\{\{TARGET\}\}/, target)
            gsub(/\{\{EXTRA_PROMPT\}\}/, extra)
            gsub(/\{\{IMPLEMENTER_NOTES\}\}/, notes)
            print
        }
    ' "$tpl"
}

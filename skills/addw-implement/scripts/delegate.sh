#!/usr/bin/env bash
# Hand a ticket to the configured implementing adapter (ADDW_IMPLEMENT_SKILL,
# default codex-implement) with the ticket's effective contract appended
# verbatim to the caller's scope. The contract is re-read on every call.
#
# Usage: delegate.sh <start|resume> <issue-number> <scope text…>
# Exits 64 on a usage error; a failed contract read or config read exits with
# its own status before the adapter runs; otherwise the adapter's status.

set -euo pipefail

usage() {
    echo "usage: delegate.sh <start|resume> <issue-number> <scope text…>" >&2
    exit 64
}

[ "$#" -ge 3 ] || usage
MODE="$1" ISSUE="$2"
shift 2
case "$MODE" in start|resume) ;; *) usage ;; esac
case "$ISSUE" in ''|*[!0-9]*) usage ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/config/config.sh
. "$SCRIPT_DIR/../../lib/config/config.sh"

contract="$(bash "$SCRIPT_DIR/../../lib/tracker/tracker.sh" contract "$ISSUE")"

# A missing config (66) falls back to the default adapter; any other failure is fatal.
adapter="$(config_get ADDW_IMPLEMENT_SKILL)" || {
    status=$?
    [ "$status" -eq 66 ] || exit "$status"
    adapter=""
}

block="$*

## Effective contract (verbatim)

What follows is the ticket's effective contract exactly as the tracker prints it: the body
plus its amendments. An amendment overrides the body where they conflict, and a later
amendment overrides an earlier one. Presumed-folded amendments are already reflected in the
body. Unmarked comments are context, not contract. If you cannot tell what an amendment
overrides, stop and report that as IMPLEMENTATION_PARTIAL rather than guess.

$contract"

exec bash "$SCRIPT_DIR/../../${adapter:-codex-implement}/scripts/$MODE.sh" "$ISSUE" "$block"

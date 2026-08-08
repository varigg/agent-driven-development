#!/usr/bin/env bash
# Turn 2+: resume the ask session for <topic> (adapter entry point).
# Thin wrapper over the shared runner: pins STATE_DIR to this skill's
# state and the prompt to prompts/followup.tpl.
#
# Usage: resume.sh <topic> [the follow-up question…]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${STATE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)/state}"
export STATE_DIR
exec bash "$SCRIPT_DIR/../../lib/codex/resume.sh" \
    --prompt-file "$SCRIPT_DIR/../prompts/followup.tpl" "$@"

#!/usr/bin/env bash
# Turn 1: start a fresh ask session for <topic> (adapter entry point).
# Thin wrapper over the shared runner: pins STATE_DIR to this skill's
# state and the prompt to prompts/ask.tpl (read-only sandbox).
#
# Usage: start.sh <topic> [the question…]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${STATE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)/state}"
export STATE_DIR
exec bash "$SCRIPT_DIR/../../lib/codex/start.sh" \
    --prompt-file "$SCRIPT_DIR/../prompts/ask.tpl" "$@"

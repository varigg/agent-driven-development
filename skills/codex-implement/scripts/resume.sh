#!/usr/bin/env bash
# Turn 2+: resume the implementation session for <target> (adapter entry
# point). Thin wrapper over the shared runner: pins STATE_DIR to this
# skill's state and the prompt to prompts/continue.tpl. The resumed
# thread inherits the workspace-write sandbox from start.sh.
#
# Usage: resume.sh <target> [custom instructions…]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${STATE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)/state}"
export STATE_DIR
exec bash "$SCRIPT_DIR/../../lib/codex/resume.sh" \
    --prompt-file "$SCRIPT_DIR/../prompts/continue.tpl" "$@"

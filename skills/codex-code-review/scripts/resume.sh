#!/usr/bin/env bash
# Turn 2+: resume the code-review session for <target> (adapter entry
# point). Thin wrapper over the shared runner: pins STATE_DIR to this
# skill's state and the prompt to prompts/resume.tpl.
#
# Usage: resume.sh [--notes "..."] <target> [extra prompt text…]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${STATE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)/state}"
export STATE_DIR
exec bash "$SCRIPT_DIR/../../codex-plan-review/scripts/resume.sh" \
    --prompt-file "$SCRIPT_DIR/../prompts/resume.tpl" "$@"

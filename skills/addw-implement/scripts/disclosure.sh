#!/usr/bin/env bash
# Render a ticket PR body's contract disclosure: the AMENDMENTS, PRESUMED
# FOLDED and UNMARKED sections of `tracker.sh contract <n>` for the ticket and
# its parent, with the bodies left out — or one "none" line when every
# section is empty.
#
# Usage: disclosure.sh <issue-number>
# Exits 64 on a usage error; a failed contract read exits with its own status.

set -euo pipefail

usage() {
    echo "usage: disclosure.sh <issue-number>" >&2
    exit 64
}

[ "$#" -eq 1 ] || usage
case "$1" in ''|*[!0-9]*) usage ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
contract="$(bash "$SCRIPT_DIR/../../lib/tracker/tracker.sh" contract "$1")"

disclosure="$(awk '
    /^== (TICKET|PARENT) #[0-9]+ ==$/ { skip = 1; next }
    /^== (AMENDMENTS|PRESUMED FOLDED|UNMARKED) #[0-9]+ ==$/ { skip = 0 }
    !skip
' <<< "$contract")"

if grep -qv -e '^== ' -e '^(none)$' <<< "$disclosure"; then
    printf '%s\n' "$disclosure"
else
    echo "Contract amendments: none — no amendments, presumed-folded or unmarked comments."
fi

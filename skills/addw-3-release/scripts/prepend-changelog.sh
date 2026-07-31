#!/usr/bin/env bash
# Prepend a release entry to CHANGELOG.md without the caller reading the file.
# The changelog is write-only for the workflow (humans read it, agents get
# history from git) — this script is what keeps that property honest, since
# an agent's Edit tool requires reading a file before modifying it.
#
# Usage: prepend-changelog.sh [changelog-path] <<'EOF'
# ## vX.Y.Z — DD-MM-YYYY
# ...entry body...
# EOF
#
# The entry lands above the previous newest entry (the first "## " line),
# or after the header when no entry exists yet.
# Exit 0 on success, 1 if the changelog is missing, 64 on empty stdin.

set -euo pipefail

FILE="${1:-CHANGELOG.md}"
if [ ! -f "$FILE" ]; then
    echo "error: $FILE not found (run from the repo root)" >&2
    exit 1
fi

ENTRY="$(cat)"
if [ -z "$ENTRY" ]; then
    echo "error: empty entry on stdin" >&2
    exit 64
fi

# ENVIRON, not awk -v: -v would reprocess backslash escapes in the entry.
TMP="$FILE.tmp.$$"
ENTRY="$ENTRY" awk '
    !inserted && /^## / { print ENVIRON["ENTRY"]; print ""; inserted = 1 }
    { print }
    END { if (!inserted) { print ""; print ENVIRON["ENTRY"] } }
' "$FILE" > "$TMP"
mv "$TMP" "$FILE"
echo "prepended entry to $FILE"

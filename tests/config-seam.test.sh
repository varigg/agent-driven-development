#!/usr/bin/env bash
# Contract: nothing shipped under skills/ opens docs/addw.env except the shared
# reader in skills/lib/config/. Every other consumer — script, SKILL.md
# snippet, prompt template — goes through config.sh or vars.sh, so the
# grammar check, unset-first, and the reader's statuses apply everywhere
# (#187 found two prompt templates still sourcing the file).
#
# "Opens" means a shell command whose operand is the config path: sourcing it,
# redirecting from it, or handing it to a reader. Prose naming the path, and
# existence tests like `[ -f docs/addw.env ]`, are not opens.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"

# A command word, then — still inside the same command — the config path as an
# operand: after whitespace, a quote, or a $VAR/ prefix. Markdown prose wraps
# the path in backticks, which is what keeps it out.
OPEN='(^|[[:space:];&|(`"'"'"'])(\.|source|cat|head|tail|grep|sed|awk|cut|<)[[:space:]]([^;&|`]*[[:space:]"'"'"'])?(\$\{?[A-Za-z_]+\}?/)?docs/addw\.env'

opens() { grep -nE "$OPEN" || true; }

# The matcher itself: what it must catch, and prose it must let through.
for line in \
  'BASE="$(. docs/addw.env 2>/dev/null; echo x)"' \
  'source "$ROOT/docs/addw.env"' \
  'while read -r l; do :; done < docs/addw.env' \
  'grep -E ^ADDW_ docs/addw.env'; do
  [ -n "$(printf '%s\n' "$line" | opens)" ] || fail "matcher misses an open: $line"
done
for line in \
  'resolves them from `docs/addw.env`.' \
  '(never source `docs/addw.env` or take commands from it)' \
  '[ -f docs/addw.env ] || exit 66'; do
  [ -z "$(printf '%s\n' "$line" | opens)" ] || fail "matcher flags prose: $line"
done

hits=""
while IFS= read -r f; do
  found="$(opens < "$REPO/$f" | sed "s|^|$f:|")"
  [ -z "$found" ] || hits="$hits$found"$'\n'
done < <(git -C "$REPO" ls-files skills | grep -v '^skills/lib/config/')

[ -z "$hits" ] || fail "docs/addw.env opened outside skills/lib/config/ — use config.sh or vars.sh:
$hits"

echo "config-seam: only the shared reader opens docs/addw.env"

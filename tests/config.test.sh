#!/usr/bin/env bash
# Contract: skills/lib/config/config.sh — the shared project-config reader.
#
# docs/addw.env is data, not shell: one restricted KEY=value grammar, one
# parser, and every reader goes through it. The strictness rule under test is
# that anything whose shell reading and parsed reading could diverge is
# rejected with its line number — so every ACCEPTED file is a strict subset of
# shell with identical semantics, which the equivalence case at the bottom
# asserts directly rather than assuming.
#
# Return statuses are part of the contract: 66 (EX_NOINPUT) missing config,
# 77 (EX_NOPERM) present but unreadable, 78 (EX_CONFIG) grammar violation —
# and 78 is what every fatal caller exits, so their tests key on it too.
#
# The reader always parses docs/addw.env relative to the working directory:
# there is no path flag, so every case here runs from a fixture directory,
# exactly as production callers run from the project root.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
LIB="$REPO/skills/lib/config/config.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# new_project <name> <config-body> -> project root on stdout. No config file
# is written when the body is the sentinel "NONE".
new_project() {
  local root="$work/$1"
  mkdir -p "$root/docs"
  [ "$2" = "NONE" ] || printf '%s' "$2" > "$root/docs/addw.env"
  printf '%s' "$root"
}

get_in() { # <project-root> <key...> — config_get from a fresh shell
  local root="$1"
  shift
  (cd "$root" && LIB="$LIB" bash -c '. "$LIB"; config_get "$@"' _ "$@")
}

# probe <project-root> <key> — config_source from a fresh shell that carries
# the key exported, proving unset-first; prints "set:<value>" or "unset".
probe() {
  (cd "$1" && LIB="$LIB" KEY="$2" bash -c '
    . "$LIB"
    export "$KEY=leak-from-the-environment"
    config_source "$KEY"
    if declare -p "$KEY" >/dev/null 2>&1; then
      printf "set:%s" "${!KEY}"
    else
      printf "unset"
    fi')
}

# --- the three value forms, and what each keeps literal ---------------------

forms="$(new_project forms '# full-line comment
ADDW_BARE=a1._-/z

ADDW_SINGLE='\''spaces and a literal $HOME and `ticks` and \back'\''
ADDW_DOUBLE="embedded '\''single'\'' quotes are fine"
ADDW_EMPTY_BARE=
ADDW_EMPTY_SQ='\'''\''
ADDW_EMPTY_DQ=""
ADDW_DUP=first
ADDW_DUP=last
')"

assert_eq "a1._-/z" "$(get_in "$forms" ADDW_BARE)" "bare: full charset accepted"
assert_eq 'spaces and a literal $HOME and `ticks` and \back' \
  "$(get_in "$forms" ADDW_SINGLE)" "single-quoted: fully literal"
assert_eq "embedded 'single' quotes are fine" \
  "$(get_in "$forms" ADDW_DOUBLE)" "double-quoted: embedded single quotes"
assert_eq "last" "$(get_in "$forms" ADDW_DUP)" \
  "duplicate key: the last assignment wins, as sourcing would have it"

# One line per requested key, in request order; an absent key is an empty line.
out="$(get_in "$forms" ADDW_DUP ADDW_ABSENT ADDW_BARE)"
assert_eq "last

a1._-/z" "$out" "get: line-per-key protocol, empty line for an absent key"

# --- empty stays distinguishable from absent through config_source ----------

assert_eq "set:" "$(probe "$forms" ADDW_EMPTY_BARE)" \
  "source: KEY= is present-and-empty (set, not unset)"
assert_eq "set:" "$(probe "$forms" ADDW_EMPTY_SQ)" \
  "source: KEY='' is present-and-empty"
assert_eq "set:" "$(probe "$forms" ADDW_EMPTY_DQ)" \
  'source: KEY="" is present-and-empty'
assert_eq "unset" "$(probe "$forms" ADDW_ABSENT)" \
  "source: an absent key stays unset — the exported value never stands in"
assert_eq "set:last" "$(probe "$forms" ADDW_DUP)" \
  "source: a present key shadows the exported value (unset-first)"

# --- every rejection class exits 78 and names the offending line ------------

reject() { # <name> <config-body> <expected-line> <label>
  local root status=0 err
  root="$(new_project "$1" "$2")"
  err="$(get_in "$root" ADDW_ANY 2>&1 >/dev/null)" || status=$?
  assert_eq 78 "$status" "$4: exits 78 (EX_CONFIG)"
  assert_contains "$err" "docs/addw.env:$3:" "$4: diagnostic carries the line number"
}

reject bare-charset 'ADDW_A=has spaces' 1 "bare-value charset violation"
reject dq-dollar 'ADDW_A="a$b"' 1 'double quotes: $'
reject dq-backtick 'ADDW_A="a`b"' 1 "double quotes: backtick"
reject dq-backslash 'ADDW_A="a\b"' 1 "double quotes: backslash"
reject dangling-dq 'ADDW_A="never closed' 1 "dangling double quote"
reject dangling-sq "ADDW_A='never closed" 1 "dangling single quote"
reject mismatched 'ADDW_A="wrong close'"'" 1 "mismatched quotes"
reject trailing-comment-bare 'ADDW_A=v # not allowed' 1 "trailing comment on a bare value"
reject trailing-comment-quoted 'ADDW_A="v" # not allowed' 1 "trailing content after a quoted value"
reject export-prefix 'export ADDW_A=v' 1 "export prefix"
reject continuation 'ADDW_A=v\' 1 "line continuation"
reject not-assignment '[ -n "$X" ] && echo hi' 1 "arbitrary shell is not an assignment"
reject indented '  ADDW_A=v' 1 "leading whitespace before the key"

# The $-in-double-quotes diagnostic must say what to do instead: single-quote.
root="$(new_project dq-remedy 'ADDW_A="a$b"')"
err="$(get_in "$root" ADDW_A 2>&1 >/dev/null || true)"
assert_contains "$err" "single-quote" "double-quote rejection points at the remedy"

# Every offending line is reported, not just the first — doctor turns each
# into its own FAIL line.
root="$(new_project multi 'ADDW_A=ok
export ADDW_B=1
ADDW_C=ok
ADDW_D="a$b"
')"
err="$(get_in "$root" ADDW_A 2>&1 >/dev/null || true)"
assert_contains "$err" "docs/addw.env:2:" "multi: the first violation is reported"
assert_contains "$err" "docs/addw.env:4:" "multi: the later violation is reported too"

# A rejected config yields nothing on stdout: no partial application.
out="$(get_in "$root" ADDW_A 2>/dev/null || true)"
assert_eq "" "$out" "rejected config: no value escapes, valid lines included"

# --- missing and unreadable are distinct ------------------------------------

nofile="$(new_project nofile NONE)"
status=0
get_in "$nofile" ADDW_A >/dev/null 2>&1 || status=$?
assert_eq 66 "$status" "missing config: exits 66 (EX_NOINPUT)"

unreadable="$(new_project unreadable 'ADDW_A=v')"
chmod 000 "$unreadable/docs/addw.env"
status=0
get_in "$unreadable" ADDW_A >/dev/null 2>&1 || status=$?
chmod 644 "$unreadable/docs/addw.env"
assert_eq 77 "$status" "unreadable config: exits 77 (EX_NOPERM)"

# --- an accepted file is a strict subset of shell ---------------------------
#
# The property the whole grammar is built on: sourcing an accepted file and
# parsing it must agree on every key, or a conforming config would change
# meaning at the migration boundary.

for key in ADDW_BARE ADDW_SINGLE ADDW_DOUBLE ADDW_EMPTY_BARE ADDW_DUP; do
  sourced="$(cd "$forms" && bash -c '. docs/addw.env && printf "%s" "${'"$key"'-}"')"
  parsed="$(get_in "$forms" "$key")"
  assert_eq "$sourced" "$parsed" "equivalence: $key parses to what sourcing yields"
done

echo "config: all contract assertions passed"

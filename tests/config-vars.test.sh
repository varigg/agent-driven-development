#!/usr/bin/env bash
# Contract: skills/lib/config/vars.sh — the executed entry point SKILL.md
# snippets use to read docs/addw.env, and config.sh's non-bash guard.
#
# A snippet runs in whatever shell drives the session, zsh included, while
# the reader is bash-only. vars.sh runs the reader in bash and prints shell
# assignments for the caller to eval, so every case below evals its output
# under each available POSIX-family shell — the contract is config_source's
# (unset-first, KEY= set-but-empty, absent stays unset, the reader's statuses)
# carried across the process boundary intact.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
VARS="$REPO/skills/lib/config/vars.sh"
LIB="$REPO/skills/lib/config/config.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

new_project() { # <name> <config-body|NONE> -> project root on stdout
  local root="$work/$1"
  mkdir -p "$root/docs"
  [ "$2" = "NONE" ] || printf '%s' "$2" > "$root/docs/addw.env"
  printf '%s' "$root"
}

shells=(bash)
for s in zsh dash; do
  command -v "$s" >/dev/null 2>&1 && shells+=("$s")
done

# run_in <shell> <root> <script> — run a snippet in <shell> from <root>, with
# ADDW_LEAK exported so unset-first is observable. Prints the snippet's stdout;
# its exit status is the snippet's.
run_in() {
  (cd "$2" && VARS="$VARS" ADDW_LEAK=leak-from-the-environment "$1" -c "$3")
}

# report <key> — shell-neutral probe: "set:<value>" or "unset".
report='report() { eval "_isset=\${$1+x}"; if [ -n "$_isset" ]; then eval "printf %s \"set:\$$1\""; else printf unset; fi; printf "\n"; }'

forms="$(new_project forms "ADDW_BARE=a1._-/z
ADDW_SINGLE='a \$HOME and \`ticks\` and \\back'
ADDW_DOUBLE=\"it's quoted\"
ADDW_EMPTY=
ADDW_LEAK=from-the-file
")"

for sh in "${shells[@]}"; do
  out="$(run_in "$sh" "$forms" "$report"'
    eval "$(bash "$VARS" ADDW_BARE ADDW_SINGLE ADDW_DOUBLE ADDW_EMPTY ADDW_ABSENT ADDW_LEAK)"
    report ADDW_BARE; report ADDW_SINGLE; report ADDW_DOUBLE
    report ADDW_EMPTY; report ADDW_ABSENT; report ADDW_LEAK')"
  assert_eq 'set:a1._-/z
set:a $HOME and `ticks` and \back
set:it'"'"'s quoted
set:
unset
set:from-the-file' "$out" "$sh: values round-trip literally; empty is set, absent is unset"

  # Unset-first: an absent key never inherits the environment.
  out="$(run_in "$sh" "$(new_project "absent-$sh" 'ADDW_OTHER=v')" "$report"'
    eval "$(bash "$VARS" ADDW_LEAK)"; report ADDW_LEAK')"
  assert_eq "unset" "$out" "$sh: unset-first — the exported value never stands in"

  # Statuses surface as the eval's status; diagnostics reach stderr; no value
  # escapes a rejected config, and the requested keys are still unset.
  bad="$(new_project "bad-$sh" 'ADDW_A=ok
ADDW_B=has spaces
')"
  status=0
  err="$(run_in "$sh" "$bad" "$report"'
    eval "$(bash "$VARS" ADDW_A ADDW_LEAK)" || { s=$?; report ADDW_A >&2; report ADDW_LEAK >&2; exit $s; }' 2>&1 >/dev/null)" || status=$?
  assert_eq 78 "$status" "$sh: grammar violation surfaces as 78"
  assert_contains "$err" "docs/addw.env:2:" "$sh: the reader's line-numbered diagnostic reaches stderr"
  assert_contains "$err" "unset
unset" "$sh: a rejected config applies nothing and still unsets"

  status=0
  run_in "$sh" "$(new_project "missing-$sh" NONE)" 'eval "$(bash "$VARS" ADDW_A)"' \
    >/dev/null 2>&1 || status=$?
  assert_eq 66 "$status" "$sh: missing config surfaces as 66"

  # A bad key name is refused before anything is emitted — it would otherwise
  # be spliced into code the caller evals.
  status=0
  run_in "$sh" "$forms" 'eval "$(bash "$VARS" "X;touch pwned")"' \
    >/dev/null 2>&1 || status=$?
  assert_eq 64 "$status" "$sh: invalid key name surfaces as 64"
  [ ! -e "$forms/pwned" ] || fail "$sh: an invalid key name was executed"
done

status=0
(cd "$forms" && bash "$VARS") >/dev/null 2>&1 || status=$?
assert_eq 64 "$status" "no keys: usage error 64"

# --- the guard: config.sh refuses a non-bash shell loudly --------------------

for sh in "${shells[@]}"; do
  [ "$sh" = bash ] && continue
  status=0
  # The snippet idiom: `. config.sh && ...` — a returning guard must stop it.
  err="$(cd "$forms" && LIB="$LIB" "$sh" -c '. "$LIB" && echo sourced-and-continued' 2>&1)" \
    || status=$?
  [ "$status" -ne 0 ] || fail "$sh: sourcing config.sh must fail, got status 0"
  assert_contains "$err" "bash" "$sh: the refusal names bash"
  assert_contains "$err" "vars.sh" "$sh: the refusal points at the executed entry point"
  assert_not_contains "$err" "sourced-and-continued" "$sh: the sourcing shell does not carry on"
done

echo "config-vars: all contract assertions passed"

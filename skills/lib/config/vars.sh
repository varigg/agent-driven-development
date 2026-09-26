#!/usr/bin/env bash
# Executed entry point to the config reader for callers not running in bash —
# SKILL.md snippets, which run in whatever shell drives the session. Runs
# config_source here, in bash, and prints shell code the caller evals:
#
#   eval "$(bash .claude/skills/lib/config/vars.sh KEY...)"
#
# Output, valid in bash, zsh, and POSIX sh: `unset KEY...` for every requested
# key, then one KEY='value' line per key the config sets (single-quoted, so
# literal); a key the config does not set stays unset, and KEY= stays set but
# empty. On failure no assignment is printed and the output ends in
# `(exit N)`, so the eval itself returns N.
#
# Exit status (and the eval's): 0 parsed; 64 no keys or an invalid key name,
# refused before anything but `(exit 64)` is printed; 66, 77, 78 as
# config.sh, whose diagnostics pass through to stderr.

# Every name here is prefixed: config_source sets the requested keys in this
# shell, and a bare `key` or `status` would collide with a key of that name.
_vars_fail() { # <status>
    printf '(exit %d)\n' "$1"
    exit "$1"
}

[ "$#" -ge 1 ] || { echo "vars.sh: at least one KEY is required" >&2; _vars_fail 64; }
for _vars_key in "$@"; do
    if ! [[ "$_vars_key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        printf 'vars.sh: not a valid key name: %s\n' "$_vars_key" >&2
        _vars_fail 64
    fi
done

. "$(dirname "${BASH_SOURCE[0]}")/config.sh"

printf 'unset %s\n' "$*"
_vars_status=0
config_source "$@" || _vars_status=$?
[ "$_vars_status" -eq 0 ] || _vars_fail "$_vars_status"

for _vars_key in "$@"; do
    [ -n "${!_vars_key+x}" ] || continue
    _vars_value="${!_vars_key}"
    printf "%s='%s'\n" "$_vars_key" "${_vars_value//\'/\'\\\'\'}"
done

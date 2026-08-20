#!/usr/bin/env bash
# Shared reader for the project config, docs/addw.env. Source-only: source
# this file, then call an entry point. The config is DATA parsed by this one
# reader, never sourced as shell — why the layer exists, and the defect
# history behind it: ../README.md (the config/ section).
#
# Grammar, per line: blank, a full-line # comment, or one KEY=value assignment
# with an identifier key at the start of the line — no `export` prefix, no
# trailing comment, no line continuation. Values take three forms:
#
#   bare           letters, digits, . _ - / only; anything else must be quoted
#   single-quoted  fully literal; no embedded single quote
#   double-quoted  literal; embedded single quotes fine; $, backtick, and
#                  backslash are rejected — single-quote such a value instead
#
# KEY= is legal and distinct from the key being absent. Anything whose shell
# reading and parsed reading could diverge is rejected with its line number,
# so every accepted file is a strict subset of shell with identical semantics.
#
# Entry points (both parse docs/addw.env relative to the working directory):
#
#   config_get KEY...      print one line per requested key: its value, or an
#                          empty line when the key is absent or empty
#   config_source KEY...   set the named keys in the caller's shell, unsetting
#                          them first so only the file can supply values — a
#                          key the file does not set stays unset, and KEY=
#                          sets it empty, so set-but-empty remains
#                          distinguishable from absent
#
# Return status, both entry points: 0 parsed; 66 (EX_NOINPUT) the config is
# missing; 77 (EX_NOPERM) it exists but cannot be read; 78 (EX_CONFIG) it
# violates the grammar, with every offending line reported to stderr by
# number. Whether a missing config is fatal stays the caller's policy; under
# `set -e` an unhandled non-zero return exits the caller with that status.

ADDW_CONFIG_FILE="docs/addw.env"

_CONFIG_KEYS=()
_CONFIG_VALS=()

# _config_accept <key> <value> — record an assignment; a repeated key is
# overwritten so the last assignment wins, exactly as sourcing would have it.
_config_accept() {
    local i
    for i in "${!_CONFIG_KEYS[@]}"; do
        if [ "${_CONFIG_KEYS[$i]}" = "$1" ]; then
            _CONFIG_VALS[$i]="$2"
            return 0
        fi
    done
    _CONFIG_KEYS+=("$1")
    _CONFIG_VALS+=("$2")
}

# Parse $ADDW_CONFIG_FILE into the arrays above. Diagnostics go to stderr as
# "<file>:<line>: <what>"; every offending line is reported, not just the
# first, because the doctor turns each into its own FAIL line.
_config_parse() {
    _CONFIG_KEYS=()
    _CONFIG_VALS=()
    if [ ! -e "$ADDW_CONFIG_FILE" ]; then
        printf '%s: no such file (run from the project root)\n' \
            "$ADDW_CONFIG_FILE" >&2
        return 66
    fi
    if [ ! -f "$ADDW_CONFIG_FILE" ] || [ ! -r "$ADDW_CONFIG_FILE" ]; then
        printf '%s: exists but cannot be read\n' "$ADDW_CONFIG_FILE" >&2
        return 77
    fi

    local line lineno=0 bad=0 key value inner rest
    _config_bad() { # <lineno> <message>
        printf '%s:%d: %s\n' "$ADDW_CONFIG_FILE" "$1" "$2" >&2
        bad=1
    }
    while IFS= read -r line || [ -n "$line" ]; do
        lineno=$((lineno + 1))
        # Blank lines and full-line comments.
        if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        if [[ "$line" =~ ^[[:space:]]*export([[:space:]]|$) ]]; then
            _config_bad "$lineno" \
                "remove the 'export' prefix — the config is parsed as data, never sourced"
            continue
        fi
        if ! [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            _config_bad "$lineno" \
                "not a KEY=value assignment (identifier key at the start of the line)"
            continue
        fi
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"

        # KEY= — present and empty, distinct from absent.
        if [ -z "$value" ]; then
            _config_accept "$key" ""
            continue
        fi

        case "$value" in
        \'*)
            if [[ "$value" =~ ^\'([^\']*)\'(.*)$ ]]; then
                inner="${BASH_REMATCH[1]}"
                rest="${BASH_REMATCH[2]}"
                if [ -n "$rest" ]; then
                    _config_bad "$lineno" \
                        "trailing content after the closing quote (a comment must occupy its own line)"
                else
                    _config_accept "$key" "$inner"
                fi
            else
                _config_bad "$lineno" "unterminated single quote"
            fi
            ;;
        \"*)
            if [[ "$value" =~ ^\"([^\"]*)\"(.*)$ ]]; then
                inner="${BASH_REMATCH[1]}"
                rest="${BASH_REMATCH[2]}"
                if [ -n "$rest" ]; then
                    _config_bad "$lineno" \
                        "trailing content after the closing quote (a comment must occupy its own line)"
                else
                    case "$inner" in
                    *'$'* | *'`'* | *'\'*)
                        _config_bad "$lineno" \
                            "\$, backtick, or backslash inside double quotes — single-quote this value instead (it is literal either way)"
                        ;;
                    *)
                        _config_accept "$key" "$inner"
                        ;;
                    esac
                fi
            else
                _config_bad "$lineno" "unterminated double quote"
            fi
            ;;
        *)
            if [[ "$value" =~ ^[A-Za-z0-9._/-]+$ ]]; then
                _config_accept "$key" "$value"
            elif [[ "$value" == *'\' ]]; then
                _config_bad "$lineno" \
                    "line continuations are not supported — a value is one line"
            elif [[ "$value" == *'#'* ]]; then
                _config_bad "$lineno" \
                    "trailing comment — a comment must occupy its own line"
            else
                _config_bad "$lineno" \
                    "unquoted value may contain only letters, digits, and . _ - / — quote anything else"
            fi
            ;;
        esac
    done < "$ADDW_CONFIG_FILE"
    unset -f _config_bad

    [ "$bad" -eq 0 ] || return 78
}

config_get() {
    if [ "$#" -lt 1 ]; then
        echo "config_get: at least one KEY is required" >&2
        return 64
    fi
    _config_parse || return
    local key i value
    for key in "$@"; do
        value=""
        for i in "${!_CONFIG_KEYS[@]}"; do
            [ "${_CONFIG_KEYS[$i]}" = "$key" ] && value="${_CONFIG_VALS[$i]}"
        done
        printf '%s\n' "$value"
    done
}

config_source() {
    if [ "$#" -lt 1 ]; then
        echo "config_source: at least one KEY is required" >&2
        return 64
    fi
    local key i
    for key in "$@"; do
        if ! [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
            printf 'config_source: not a valid key name: %s\n' "$key" >&2
            return 64
        fi
    done
    # Unset before parsing, not after: only the file may supply values, and
    # that must hold on every path — a caller that treats a missing config as
    # "use the defaults" would otherwise inherit whatever the environment
    # happened to carry.
    for key in "$@"; do
        unset "$key"
    done
    _config_parse || return
    for key in "$@"; do
        for i in "${!_CONFIG_KEYS[@]}"; do
            if [ "${_CONFIG_KEYS[$i]}" = "$key" ]; then
                printf -v "$key" '%s' "${_CONFIG_VALS[$i]}"
            fi
        done
    done
}

#!/usr/bin/env bash
# Contract: skills/lib/docs/next-adr-number.sh — the next ADR number.
#
#   next-adr-number.sh [--config <file>]
#
# Sources the project config (default: docs/addw.env), resolves the ADR
# directory from ADDW_ADR_DIR, and prints the next number as four
# zero-padded digits — max(directory) + 1, never the first gap.
#
# The distinction is the whole point. Before ADR archival the directory had
# no holes, so max and first-gap coincided; archival makes them diverge and
# leaves the intuitive answer — the first unused number in the listing — a
# number already spent. A superseder always outnumbers what it supersedes and
# stays active, so every departed number sits below a present one and the
# directory alone is authoritative: no tracker call, asserted below rather
# than promised.
#
# Files carrying no four-digit prefix are not ADRs and are ignored, the
# template among them. An unset ADDW_ADR_DIR is refused rather than resolved
# to an empty glob, because a silent 0001 in a populated project is exactly
# the silent pass this script exists to prevent.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
SCRIPT="$REPO/skills/lib/docs/next-adr-number.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Build an ADR directory holding the named files, plus a config naming it.
# Returns the config path on stdout.
make_case() { # name file...
  local name=$1
  shift
  local dir="$work/$name"
  mkdir -p "$dir"
  local f
  for f in "$@"; do
    : >"$dir/$f"
  done
  printf 'ADDW_ADR_DIR="%s"\n' "$dir" >"$work/$name.env"
  printf '%s\n' "$work/$name.env"
}

# --- an empty directory starts the sequence --------------------------------

cfg="$(make_case empty)"
out="$(bash "$SCRIPT" --config "$cfg")"
assert_eq "0001" "$out" "empty: first number for an empty ADR directory"

# --- a contiguous directory is max plus one --------------------------------

cfg="$(make_case contiguous 0001-a.md 0002-b.md 0003-c.md)"
out="$(bash "$SCRIPT" --config "$cfg")"
assert_eq "0004" "$out" "contiguous: max plus one"

# --- holes are max plus one, never the first gap ---------------------------
#
# 0002 and 0003 departed under ADR 0003. The first gap is 0002 — a number
# already spent, and the answer a listing-based agent gives.

cfg="$(make_case holes 0001-a.md 0004-d.md)"
out="$(bash "$SCRIPT" --config "$cfg")"
assert_eq "0005" "$out" "holes: max plus one across a hole"
assert_not_contains "$out" "0002" "holes: never the first gap"

# A trailing hole is the same rule: the highest present number wins even when
# every number below it departed.
cfg="$(make_case one-high 0009-only.md)"
out="$(bash "$SCRIPT" --config "$cfg")"
assert_eq "0010" "$out" "one-high: max plus one from a single high number"

# Leading zeros are decimal, not octal: 0008 + 1 is 0009, and a script doing
# arithmetic on "08" without base-10 forcing dies here instead of shipping.
cfg="$(make_case octal 0007-g.md 0008-h.md)"
out="$(bash "$SCRIPT" --config "$cfg")"
assert_eq "0009" "$out" "octal: leading zeros are read as decimal"

# --- files carrying no four-digit prefix are ignored ------------------------

cfg="$(make_case mixed 0001-a.md 0002-b.md template.md README.md notes.txt .gitkeep)"
out="$(bash "$SCRIPT" --config "$cfg")"
assert_eq "0003" "$out" "mixed: non-prefixed files, the template among them, are ignored"

# A directory holding nothing but non-ADRs is an empty directory.
cfg="$(make_case only-template template.md README.md)"
out="$(bash "$SCRIPT" --config "$cfg")"
assert_eq "0001" "$out" "only-template: a directory of non-ADRs starts the sequence"

# A four-digit run inside a name is not a prefix, and neither is a longer run
# of digits at the front — both would inflate the answer if the match were
# loose.
cfg="$(make_case not-a-prefix 0001-a.md adr-0042-b.md 00123-c.md)"
out="$(bash "$SCRIPT" --config "$cfg")"
assert_eq "0002" "$out" "not-a-prefix: only a leading four-digit prefix counts"

# --- the directory comes from configuration, never a hardcoded path ---------
#
# Run from the repo root, where docs/adr/ exists and is populated, against a
# config naming somewhere else. A hardcoded docs/adr/ passes every test above
# and fails only this one.

cfg="$(make_case elsewhere 0031-x.md)"
out="$(cd "$REPO" && bash "$SCRIPT" --config "$cfg")"
assert_eq "0032" "$out" "elsewhere: answers from the configured directory, not docs/adr/"

assert_not_contains "$(cat "$SCRIPT")" "docs/adr" \
  "elsewhere: the script names no ADR directory of its own"

# This repo's own config resolves — the key is present and points somewhere
# real. The value is deliberately not asserted: it moves with every ADR.
out="$(cd "$REPO" && bash "$SCRIPT")"
case "$out" in
  [0-9][0-9][0-9][0-9]) ;;
  *) fail "dogfood: repo config yields four zero-padded digits, got $(printf '%q' "$out")" ;;
esac

# --- an exported value never stands in for an absent key --------------------

cfg="$(make_case absent-key)"
: >"$cfg" # a config setting nothing at all
assert_exit 2 "absent-key: an unset ADDW_ADR_DIR is refused" \
  env ADDW_ADR_DIR="$work/contiguous" bash "$SCRIPT" --config "$cfg"

err="$(env ADDW_ADR_DIR="$work/contiguous" bash "$SCRIPT" --config "$cfg" 2>&1 >/dev/null || true)"
assert_contains "$err" "ADDW_ADR_DIR" "absent-key: the refusal names the key"

# An empty value is the same failure as an absent one — resolving it to an
# empty glob would answer 0001 for a populated project.
printf 'ADDW_ADR_DIR=""\n' >"$cfg"
assert_exit 2 "empty-key: an empty ADDW_ADR_DIR is refused" \
  bash "$SCRIPT" --config "$cfg"

# --- a configured directory that does not exist is loud ---------------------

printf 'ADDW_ADR_DIR="%s"\n' "$work/nowhere" >"$work/missing-dir.env"
assert_exit 2 "missing-dir: a configured directory that is absent is refused" \
  bash "$SCRIPT" --config "$work/missing-dir.env"

err="$(bash "$SCRIPT" --config "$work/missing-dir.env" 2>&1 >/dev/null || true)"
assert_contains "$err" "$work/nowhere" "missing-dir: the refusal names the path"

# --- usage errors -----------------------------------------------------------

assert_exit 2 "config: an unreadable config is refused" \
  bash "$SCRIPT" --config "$work/no-such-file.env"

assert_exit 2 "config: --config with no argument is a usage error" \
  bash "$SCRIPT" --config

# --- no tracker call --------------------------------------------------------
#
# Every departed number sits below a present one, so the directory alone is
# authoritative. A `gh` on PATH that records being called proves it rather
# than asserting it about the source text.

stub="$work/bin"
mkdir -p "$stub"
cat >"$stub/gh" <<EOF
#!/usr/bin/env bash
printf 'called\n' >>"$work/gh-calls"
exit 0
EOF
chmod +x "$stub/gh"

cfg="$work/holes.env"
out="$(PATH="$stub:$PATH" bash "$SCRIPT" --config "$cfg")"
assert_eq "0005" "$out" "no-tracker: the answer is unchanged with gh on PATH"
[ ! -f "$work/gh-calls" ] || fail "no-tracker: the script invoked gh"

# --- output shape -----------------------------------------------------------
#
# One line on stdout and nothing else, so a caller can substitute it into a
# filename directly.

out="$(bash "$SCRIPT" --config "$work/contiguous.env" 2>/dev/null)"
assert_eq "1" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" \
  "output: exactly one line on stdout"

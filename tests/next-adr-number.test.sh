#!/usr/bin/env bash
# Contract: skills/lib/docs/next-adr-number.sh — the next ADR number.
#
#   next-adr-number.sh   (run from the project root; takes no arguments)
#
# Reads ADDW_ADR_DIR from docs/addw.env through the shared config reader —
# there is no path flag, so every case runs from a fixture directory, exactly
# as production runs from a project root — and prints the next number as four
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
# the silent pass this script exists to prevent — it exits 78 (EX_CONFIG),
# the code every fatal caller uses for a config that is present but unusable;
# 2 is reserved for usage errors alone.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
SCRIPT="$REPO/skills/lib/docs/next-adr-number.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Build a project root holding a docs/addw.env that names an ADR directory
# populated with the named files. Returns the project root on stdout.
make_case() { # name file...
  local name=$1
  shift
  local root="$work/$name" dir="$work/$name/decisions"
  mkdir -p "$root/docs" "$dir"
  local f
  for f in "$@"; do
    : >"$dir/$f"
  done
  printf "ADDW_ADR_DIR='%s'\n" "$dir" >"$root/docs/addw.env"
  printf '%s\n' "$root"
}

run_in() { # project-root [args...]
  local root="$1"
  shift
  (cd "$root" && bash "$SCRIPT" "$@")
}

# --- an empty directory starts the sequence --------------------------------

proj="$(make_case empty)"
out="$(run_in "$proj")"
assert_eq "0001" "$out" "empty: first number for an empty ADR directory"

# --- a contiguous directory is max plus one --------------------------------

proj="$(make_case contiguous 0001-a.md 0002-b.md 0003-c.md)"
out="$(run_in "$proj")"
assert_eq "0004" "$out" "contiguous: max plus one"

# --- holes are max plus one, never the first gap ---------------------------
#
# 0002 and 0003 departed under ADR 0003. The first gap is 0002 — a number
# already spent, and the answer a listing-based agent gives.

proj="$(make_case holes 0001-a.md 0004-d.md)"
out="$(run_in "$proj")"
assert_eq "0005" "$out" "holes: max plus one across a hole"
assert_not_contains "$out" "0002" "holes: never the first gap"

# A trailing hole is the same rule: the highest present number wins even when
# every number below it departed.
proj="$(make_case one-high 0009-only.md)"
out="$(run_in "$proj")"
assert_eq "0010" "$out" "one-high: max plus one from a single high number"

# Leading zeros are decimal, not octal: 0008 + 1 is 0009, and a script doing
# arithmetic on "08" without base-10 forcing dies here instead of shipping.
proj="$(make_case octal 0007-g.md 0008-h.md)"
out="$(run_in "$proj")"
assert_eq "0009" "$out" "octal: leading zeros are read as decimal"

# --- files carrying no four-digit prefix are ignored ------------------------

proj="$(make_case mixed 0001-a.md 0002-b.md template.md README.md notes.txt .gitkeep)"
out="$(run_in "$proj")"
assert_eq "0003" "$out" "mixed: non-prefixed files, the template among them, are ignored"

# A directory holding nothing but non-ADRs is an empty directory.
proj="$(make_case only-template template.md README.md)"
out="$(run_in "$proj")"
assert_eq "0001" "$out" "only-template: a directory of non-ADRs starts the sequence"

# A four-digit run inside a name is not a prefix, and neither is a longer run
# of digits at the front — both would inflate the answer if the match were
# loose.
proj="$(make_case not-a-prefix 0001-a.md adr-0042-b.md 00123-c.md)"
out="$(run_in "$proj")"
assert_eq "0002" "$out" "not-a-prefix: only a leading four-digit prefix counts"

# --- the directory comes from configuration, never a hardcoded path ---------
#
# A project whose docs/adr/ is populated with a HIGHER number than the
# configured directory holds: a script hardcoding docs/adr/ passes every test
# above and fails only this one.

proj="$(make_case elsewhere 0031-x.md)"
mkdir -p "$proj/docs/adr"
: >"$proj/docs/adr/0099-decoy.md"
out="$(run_in "$proj")"
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

proj="$(make_case absent-key)"
: >"$proj/docs/addw.env" # a config setting nothing at all
status=0
(cd "$proj" && env ADDW_ADR_DIR="$work/contiguous/decisions" bash "$SCRIPT") \
  >/dev/null 2>&1 || status=$?
assert_eq 78 "$status" "absent-key: an unset ADDW_ADR_DIR is refused with 78"

err="$( (cd "$proj" && env ADDW_ADR_DIR="$work/contiguous/decisions" bash "$SCRIPT") 2>&1 >/dev/null || true)"
assert_contains "$err" "ADDW_ADR_DIR" "absent-key: the refusal names the key"

# An empty value is the same failure as an absent one — resolving it to an
# empty glob would answer 0001 for a populated project.
printf 'ADDW_ADR_DIR=""\n' >"$proj/docs/addw.env"
status=0
run_in "$proj" >/dev/null 2>&1 || status=$?
assert_eq 78 "$status" "empty-key: an empty ADDW_ADR_DIR is refused with 78"

# --- a configured directory that does not exist is loud ---------------------

proj="$work/missing-dir"
mkdir -p "$proj/docs"
printf "ADDW_ADR_DIR='%s'\n" "$work/nowhere" >"$proj/docs/addw.env"
status=0
run_in "$proj" >/dev/null 2>&1 || status=$?
assert_eq 66 "$status" "missing-dir: a configured directory that is absent is refused"

err="$(run_in "$proj" 2>&1 >/dev/null || true)"
assert_contains "$err" "$work/nowhere" "missing-dir: the refusal names the path"

# --- the reader's own refusals pass through --------------------------------

proj="$work/no-config"
mkdir -p "$proj/docs"
status=0
run_in "$proj" >/dev/null 2>&1 || status=$?
assert_eq 66 "$status" "no-config: a missing docs/addw.env exits 66 (EX_NOINPUT)"

proj="$work/bad-config"
mkdir -p "$proj/docs"
printf 'ADDW_ADR_DIR=$(pwd)/adr\n' >"$proj/docs/addw.env"
status=0
err="$(run_in "$proj" 2>&1 >/dev/null)" || status=$?
assert_eq 78 "$status" "bad-config: a grammar-rejected config exits 78"
assert_contains "$err" "docs/addw.env:1:" \
  "bad-config: the diagnostic names the offending line"

# --- usage errors -----------------------------------------------------------
#
# 2 is the usage code and nothing else. The retired --config flag lands here,
# so a stale caller learns of the removal rather than being half-obeyed.

status=0
run_in "$(make_case usage 0001-a.md)" --config somefile >/dev/null 2>&1 || status=$?
assert_eq 2 "$status" "usage: the retired --config flag is a usage error"

status=0
run_in "$work/usage" stray-argument >/dev/null 2>&1 || status=$?
assert_eq 2 "$status" "usage: any argument is a usage error"

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

out="$(cd "$work/holes" && PATH="$stub:$PATH" bash "$SCRIPT")"
assert_eq "0005" "$out" "no-tracker: the answer is unchanged with gh on PATH"
[ ! -f "$work/gh-calls" ] || fail "no-tracker: the script invoked gh"

# --- output shape -----------------------------------------------------------
#
# One line on stdout and nothing else, so a caller can substitute it into a
# filename directly.

out="$(run_in "$work/contiguous" 2>/dev/null)"
assert_eq "1" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" \
  "output: exactly one line on stdout"

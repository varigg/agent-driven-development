#!/usr/bin/env bash
# Contract: skills/lib/tracker/tracker.sh snapshot — the seam's completeness
# guarantee and its archive filter.
#
# Two properties are asserted here, and both are load-bearing for correctness
# rather than for cost.
#
# The filter is the sole enforcement of the write-only archive: no skill and no
# script may read an archived issue back, and locating the drop in the seam
# means no consumer *can*, rather than each consumer promising not to. It is
# logic rather than a thin gh passthrough, so it does not inherit the layer's
# dogfood-verified exemption.
#
# The refusal exists because the filter is client-side. Archived issues occupy
# fetch slots and are discarded only after retrieval, so at the limit they can
# displace live issues *before* the filter runs — an unguarded truncation would
# silently shorten the frontier, which is a wrong answer rather than a slow one.
# Refusing at the seam gives every consumer the refusal for free; a caller-side
# guard would need the raw pre-filter count, which the filtered array cannot
# carry.
#
# The stub records argv and serves a fixture, so assertions are about request
# shape and output content and nothing reaches the network. `git` is stubbed
# too: `frontier` shells out to it after `snapshot`, and an unstubbed failure
# there would make a broken refusal look like a working one.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
TRACKER="$REPO/skills/lib/tracker/tracker.sh"
KEY=ADDW_TRACKER_FETCH_LIMIT

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- stubs ------------------------------------------------------------------

mkdir -p "$work/bin"
cat >"$work/bin/gh" <<'SH'
#!/usr/bin/env bash
: >"$ARGV_LOG"
for a in "$@"; do printf '%s\n' "$a" >>"$ARGV_LOG"; done
cat "$STUB_ISSUES"
SH
# `branches` runs after `snapshot` in the frontier query. Stubbing it to
# succeed leaves the refusal as the only possible source of a non-zero exit.
cat >"$work/bin/git" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$work/bin/gh" "$work/bin/git"
PATH="$work/bin:$PATH"
export PATH

ARGV_LOG="$work/argv.txt"
export ARGV_LOG

argv_after() { # flag — echoes the argument following the flag's first use
  awk -v f="$1" 'prev==f{print;exit}{prev=$0}' "$ARGV_LOG"
}

# --- fixtures ---------------------------------------------------------------

# issue <number> <state> <stateReason> <labels-csv> <title> — one snapshot
# record. Bodies carry a marker so "no archived body reached the output" is an
# assertion about content rather than about a number.
issue() {
  jq -nc --arg n "$1" --arg s "$2" --arg r "$3" --arg l "$4" --arg t "$5" '
    {number: ($n | tonumber), title: $t, state: $s,
     stateReason: (if $r == "" then null else $r end),
     labels: ($l | if . == "" then [] else split(",") end | map({name: .})),
     assignees: [],
     body: ("BODY-OF-" + $n)}'
}

# A mixed snapshot: an open ticket, a closed non-archive issue, two archives
# (one of each kind label), and the spec the ticket hangs off.
mixed="$work/mixed.json"
{
  printf '[\n'
  issue 1 OPEN "" ready-for-agent "feat: a live ticket"
  printf ',\n'
  issue 2 CLOSED COMPLETED ready-for-agent "feat: a finished ticket"
  printf ',\n'
  issue 3 CLOSED COMPLETED archived,proposal "A retired proposal"
  printf ',\n'
  issue 4 CLOSED COMPLETED archived,adr "ADR 0002: a superseded decision"
  printf ',\n'
  issue 5 OPEN "" spec "Spec: the parent"
  printf '\n]\n'
} >"$mixed"

# make_project <name> [limit] — a cwd holding a docs/addw.env, since the seam
# reads its configuration from the project it is run in. Omitting the limit
# writes a config that sets no limit key at all.
make_project() {
  local dir="$work/$1"
  mkdir -p "$dir/docs"
  {
    printf 'ADDW_MAIN_BRANCH="master"\n'
    [ "$#" -lt 2 ] || printf '%s=%s\n' "$KEY" "$2"
  } >"$dir/docs/addw.env"
  printf '%s\n' "$dir"
}

# in_proj <dir> <cmd...> — run a command in a project, so assert_exit can take
# one. `env -C` would do the same but is not on every platform's env(1).
in_proj() {
  local dir=$1
  shift
  (cd "$dir" && "$@")
}

# --- the archive filter -----------------------------------------------------

proj="$(make_project filter 50)"
STUB_ISSUES="$mixed"
export STUB_ISSUES

out="$(cd "$proj" && bash "$TRACKER" snapshot)"

assert_contains "$out" "BODY-OF-1" "filter: an open issue survives the filter"
assert_contains "$out" "BODY-OF-2" \
  "filter: a closed non-archive issue survives — the reference check reads them"
assert_contains "$out" "BODY-OF-5" "filter: a spec issue survives"
assert_not_contains "$out" "BODY-OF-3" \
  "filter: no archived body reaches the output"
assert_not_contains "$out" "BODY-OF-4" \
  "filter: no archived body reaches the output, whatever its kind label"
assert_not_contains "$out" "A retired proposal" \
  "filter: not even an archived title reaches the output"

assert_eq 3 "$(printf '%s' "$out" | jq 'length')" \
  "filter: exactly the three non-archive issues remain"
assert_eq "[1,2,5]" "$(printf '%s' "$out" | jq -c 'map(.number)')" \
  "filter: the surviving records keep their identity and order"

# The output stays the shape resolve.sh contract-asserts — a bare JSON array.
assert_eq "array" "$(printf '%s' "$out" | jq -r 'type')" \
  "filter: the snapshot is still a bare JSON array"

# --- the fetch limit is configuration, with a default -----------------------

proj="$(make_project default-limit)" # no limit key at all
(cd "$proj" && bash "$TRACKER" snapshot >/dev/null)
assert_eq 1000 "$(argv_after --limit)" \
  "default: an absent key fetches at the documented default of 1000"

proj="$(make_project raised 50)"
(cd "$proj" && bash "$TRACKER" snapshot >/dev/null)
assert_eq 50 "$(argv_after --limit)" \
  "configured: the fetch is made at the configured limit"

# An exported value must not make an unconfigured project look configured —
# the property every other config reader in the layer holds.
proj="$(make_project exported)"
(cd "$proj" && env "$KEY=7" bash "$TRACKER" snapshot >/dev/null)
assert_eq 1000 "$(argv_after --limit)" \
  "exported: a value from the environment does not stand in for the key"

# --- the refusal at the limit -----------------------------------------------
#
# Five issues stubbed against a configured limit of five: the fetch reached its
# limit, so what it did not see cannot be shown to be irrelevant.

proj="$(make_project at-limit 5)"
assert_exit 1 "at-limit: a fetch that reached its limit is refused" \
  in_proj "$proj" bash "$TRACKER" snapshot

err="$(cd "$proj" && bash "$TRACKER" snapshot 2>&1 >/dev/null || true)"
assert_contains "$err" "5" "at-limit: the refusal names the current limit"
assert_contains "$err" "$KEY" "at-limit: the refusal names the key that raises it"
assert_contains "$err" "rchiv" \
  "at-limit: the refusal says archives count toward the limit"

# Nothing partial reaches stdout: a consumer redirecting to a file must not be
# handed a truncated array alongside the refusal.
outfile="$work/truncated.json"
(cd "$proj" && bash "$TRACKER" snapshot >"$outfile" 2>/dev/null) || true
assert_eq 0 "$(wc -c <"$outfile" | tr -d ' ')" \
  "at-limit: a refused snapshot writes nothing to stdout"

# Below the limit is the ordinary case and must not refuse.
proj="$(make_project below-limit 6)"
out="$(cd "$proj" && bash "$TRACKER" snapshot)"
assert_eq 3 "$(printf '%s' "$out" | jq 'length')" \
  "below-limit: a fetch short of its limit answers normally"

# Raising the limit past the fetched count is the remedy the refusal
# advertises, exercised here rather than described.
proj="$(make_project remedy 5)"
assert_exit 1 "remedy: the limit is reached before it is raised" \
  in_proj "$proj" bash "$TRACKER" snapshot
printf '%s=500\n' "$KEY" >>"$proj/docs/addw.env"
out="$(cd "$proj" && bash "$TRACKER" snapshot)"
assert_eq 3 "$(printf '%s' "$out" | jq 'length')" \
  "remedy: raising the configured limit makes the same fetch answer"

# --- the refusal propagates to all three queries ----------------------------
#
# A truncated frontier that merely looked shorter is the silent failure this
# exists to prevent, so every live query must exit non-zero rather than
# answer.

proj="$(make_project frontier-at-limit 5)"
assert_exit 1 "frontier: the refusal reaches the frontier query as an exit code" \
  in_proj "$proj" bash "$TRACKER" frontier

out="$(cd "$proj" && bash "$TRACKER" frontier 2>/dev/null || true)"
assert_eq "" "$out" \
  "frontier: a refused query prints no section headers to answer from"

assert_exit 1 "spec-complete: the refusal reaches the completion query" \
  in_proj "$proj" bash "$TRACKER" spec-complete 5

out="$(cd "$proj" && bash "$TRACKER" spec-complete 5 2>/dev/null || true)"
assert_eq "" "$out" "spec-complete: a refused query returns no verdict"

assert_exit 1 "specs: the refusal reaches the specs listing" \
  in_proj "$proj" bash "$TRACKER" specs

out="$(cd "$proj" && bash "$TRACKER" specs 2>/dev/null || true)"
assert_eq "" "$out" "specs: a refused query returns no listing"

# Below the limit every query answers, so the assertions above are about the
# refusal rather than about a query that never worked.
proj="$(make_project frontier-below 6)"
out="$(cd "$proj" && bash "$TRACKER" frontier)"
assert_contains "$out" "frontier:" "frontier: answers normally below the limit"
assert_contains "$out" "#1" "frontier: the live ticket is listed"
assert_not_contains "$out" "A retired proposal" \
  "frontier: no archived issue reaches the listing"

out="$(cd "$proj" && bash "$TRACKER" spec-complete 5 2>/dev/null || true)"
assert_contains "$out" "no-children" \
  "spec-complete: answers normally below the limit"

out="$(cd "$proj" && bash "$TRACKER" specs 2>/dev/null || true)"
assert_contains "$out" "$(printf '#5\tno-children\tSpec: the parent')" \
  "specs: answers normally below the limit"

# --- a malformed limit is refused, never passed to the fetch ----------------
#
# `--limit not-a-number` is a request the tracker CLI would reject with its own
# diagnostic, three layers from the config line that caused it.

proj="$(make_project malformed abc)"
assert_exit 1 "malformed: a non-numeric limit is refused" \
  in_proj "$proj" bash "$TRACKER" snapshot
err="$(cd "$proj" && bash "$TRACKER" snapshot 2>&1 >/dev/null || true)"
assert_contains "$err" "$KEY" "malformed: the refusal names the key"

: >"$ARGV_LOG"
(cd "$proj" && bash "$TRACKER" snapshot >/dev/null 2>&1) || true
assert_eq 0 "$(wc -c <"$ARGV_LOG" | tr -d ' ')" \
  "malformed: the bad limit never reaches the tracker CLI"

proj="$(make_project zero 0)"
assert_exit 1 "zero: a limit of zero is refused" \
  in_proj "$proj" bash "$TRACKER" snapshot

echo "tracker-snapshot: all contract assertions passed"

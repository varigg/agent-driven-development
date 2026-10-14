#!/usr/bin/env bash
# Contract: skills/addw-implement/scripts — the effective contract reaches the
# implementer verbatim, and the PR body discloses it (#252, spec #243).
#
# The implementing adapter runs offline and cannot read the tracker, so the
# contract `tracker.sh contract <n>` prints is the only one it can build from.
# delegate.sh appends that output, byte for byte, after the agent's scope, and
# re-runs the subcommand on every resume so a resumed thread never works from
# a stale contract. disclosure.sh renders the PR body's disclosure from the
# same subcommand: every amendment, presumed-folded and unmarked section of the
# ticket and its parent, or one "none" line when they are all empty.
#
# Exercised against a throwaway install whose tracker layer is a recording
# stand-in serving a canned contract and whose `codex` is a stub that records
# the prompt it was handed, so this runs offline.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- the throwaway install -------------------------------------------------

INSTALL="$work/install"
mkdir -p "$INSTALL/skills/addw-implement" "$INSTALL/skills/codex-implement" \
         "$INSTALL/skills/lib/tracker" "$INSTALL/bin"
cp -R "$REPO/skills/addw-implement/scripts" "$INSTALL/skills/addw-implement/"
cp -R "$REPO/skills/codex-implement/scripts" "$REPO/skills/codex-implement/prompts" \
      "$INSTALL/skills/codex-implement/"
cp -R "$REPO/skills/lib/codex" "$REPO/skills/lib/config" "$INSTALL/skills/lib/"

# Recording stand-in for the tracker layer: logs every call and serves the
# canned contract the test wrote.
cat > "$INSTALL/skills/lib/tracker/tracker.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$TRACKER_LOG"
case "${1:-}" in
  contract) [ -z "${CONTRACT_FAIL:-}" ] || exit 1; cat "$CONTRACT_FILE" ;;
  *) echo "tracker stub: unexpected call: $*" >&2; exit 97 ;;
esac
SH

# Stub Codex CLI: records the prompt (the last argument) and writes a report.
cat > "$INSTALL/bin/codex" <<'SH'
#!/usr/bin/env bash
out=""; prev=""
for a in "$@"; do [ "$prev" = "-o" ] && out=$a; prev=$a; done
printf '%s' "${!#}" > "$PROMPT_LOG"
[ -z "$out" ] || printf 'stub report\nIMPLEMENTATION_COMPLETE\n' > "$out"
printf '{"type":"thread.started","thread_id":"t-stub"}\n'
SH
chmod +x "$INSTALL/skills/lib/tracker/tracker.sh" "$INSTALL/bin/codex"

export TRACKER_LOG="$work/tracker.log" PROMPT_LOG="$work/prompt" \
       CONTRACT_FILE="$work/contract.txt"

project="$work/project"
mkdir -p "$project/docs"
printf 'ADDW_MAIN_BRANCH="master"\n' > "$project/docs/addw.env"

run() { # <script> [args…] — from the project root, as a session would
  local script=$1; shift
  ( cd "$project" && PATH="$INSTALL/bin:$PATH" STATE_DIR="$work/state" \
      bash "$INSTALL/skills/addw-implement/scripts/$script" "$@" )
}

# A contract carrying everything a careless paste or a templating pass would
# mangle: shell metacharacters, backslashes, `&`, and a template placeholder.
cat > "$CONTRACT_FILE" <<'EOF'
== TICKET #7 ==
## What to build

Literal `$HOME`, a backslash \n, an ampersand & and {{TARGET}} survive.
== AMENDMENTS #7 ==
-- 101 2026-10-10T00:00:00Z alice --
Amends-contract: widen the parser to tabs
Tabs count as separators too.
== PRESUMED FOLDED #7 ==
(none)
== UNMARKED #7 ==
-- 102 2026-10-11T00:00:00Z bob --
Should this also cover CRLF?
== PARENT #3 ==
The parent spec body.
== AMENDMENTS #3 ==
(none)
== PRESUMED FOLDED #3 ==
-- 90 2026-10-01T00:00:00Z alice --
Amends-contract: old scope
== UNMARKED #3 ==
(none)
EOF

# --- start: the scope, then the contract verbatim --------------------------

: > "$TRACKER_LOG"
out="$(run delegate.sh start 7 "Build the parser only." 2>&1)" \
  || fail "delegate start: exited non-zero: $out"
prompt="$(cat "$PROMPT_LOG")"

assert_contains "$prompt" "Build the parser only." \
  "start: the agent's scope reaches the implementer"
assert_contains "$prompt" "$(cat "$CONTRACT_FILE")" \
  "start: the contract reaches the implementer verbatim"
assert_contains "$out" "IMPLEMENTATION_COMPLETE" \
  "start: the adapter's report is passed through"
assert_eq "contract 7" "$(cat "$TRACKER_LOG")" \
  "start: the contract is read through the tracker seam"

# --- resume: the contract is captured afresh -------------------------------

printf '\n== AMENDMENTS #7 ==\n-- 103 2026-10-12T00:00:00Z alice --\nAmends-contract: a late change\n' \
  >> "$CONTRACT_FILE"
: > "$TRACKER_LOG"
out="$(run delegate.sh resume 7 "Finish the remainder." 2>&1)" \
  || fail "delegate resume: exited non-zero: $out"
prompt="$(cat "$PROMPT_LOG")"

assert_contains "$prompt" "Finish the remainder." \
  "resume: the new scope reaches the implementer"
assert_contains "$prompt" "$(cat "$CONTRACT_FILE")" \
  "resume: the re-captured contract reaches the implementer verbatim"
assert_eq "contract 7" "$(cat "$TRACKER_LOG")" \
  "resume: the contract is re-read, never reused"

# --- a failed contract read never delegates --------------------------------

rm -f "$PROMPT_LOG"
status=0
CONTRACT_FAIL=1 run delegate.sh resume 7 "Anything." >/dev/null 2>&1 || status=$?
[ "$status" -ne 0 ] || fail "delegate: a failed contract read exited 0"
[ ! -e "$PROMPT_LOG" ] || fail "delegate: codex ran without a contract"

assert_exit 64 "delegate: an unknown mode is refused" run delegate.sh review 7 "x"
assert_exit 64 "delegate: a non-numeric issue is refused" run delegate.sh start abc "x"

# --- disclosure: every list for ticket and parent --------------------------

out="$(run disclosure.sh 7 2>&1)" || fail "disclosure: exited non-zero: $out"

for section in "AMENDMENTS #7" "PRESUMED FOLDED #7" "UNMARKED #7" \
               "AMENDMENTS #3" "PRESUMED FOLDED #3" "UNMARKED #3"; do
  assert_contains "$out" "== $section ==" "disclosure: lists $section"
done
assert_contains "$out" "Amends-contract: widen the parser to tabs" \
  "disclosure: a live amendment is disclosed"
assert_contains "$out" "Amends-contract: old scope" \
  "disclosure: a presumed-folded amendment is disclosed"
assert_contains "$out" "Should this also cover CRLF?" \
  "disclosure: an unmarked comment is disclosed"
assert_not_contains "$out" "The parent spec body." \
  "disclosure: the parent body is not restated"
assert_not_contains "$out" "What to build" \
  "disclosure: the ticket body is not restated"

# --- disclosure: an all-empty contract states none -------------------------

cat > "$CONTRACT_FILE" <<'EOF'
== TICKET #8 ==
A standalone body.
== AMENDMENTS #8 ==
(none)
== PRESUMED FOLDED #8 ==
(none)
== UNMARKED #8 ==
(none)
EOF
out="$(run disclosure.sh 8 2>&1)" || fail "disclosure none: exited non-zero: $out"
assert_eq "Contract amendments: none — no amendments, presumed-folded or unmarked comments." \
  "$out" "disclosure: an all-empty contract states none"

status=0
CONTRACT_FAIL=1 run disclosure.sh 8 >/dev/null 2>&1 || status=$?
[ "$status" -ne 0 ] || fail "disclosure: a failed contract read exited 0"

echo "implement-contract: contract verbatim on start and resume; disclosure lists or states none"

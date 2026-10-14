#!/usr/bin/env bash
# Contract: skills/codex-code-review — the ADR directory reaches the reviewer
# as configuration, never as a literal.
#
# The reviewer runs read-only with no network, so the only thing it knows
# about the project beyond the tree is what the wrapper assembles into
# state/issue-<N>.context.md. The guardrail-ADR checklist item used to name
# `docs/adr/` itself, which in an install that declared another location
# matched nothing and passed silently — a check whose failure mode is that it
# passes. So:
#
#   1. The checklist names no directory.
#   2. The wrapper resolves ADDW_ADR_DIR from the project config and
#      interpolates it into the buffer, on start and on resume alike.
#   3. With no directory configured the buffer says so, rather than falling
#      back to a path that reintroduces the same silent pass.
#
# The fixture declares an ADR directory *other than* `docs/adr/`: an install
# using the default would satisfy a weaker test by accident.
#
# Plus the implementation step's obligation to carry an ADR `Gate` into the
# instruction block, which is the other half of "an in-tree guardrail is only
# worth keeping if something reads it".
#
# Exercised against a throwaway copy of the skills tree whose tracker layer is
# a recording stand-in and whose `codex` is a stub, so this runs offline.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
SKILL="$REPO/skills/codex-code-review"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- the throwaway install -------------------------------------------------

INSTALL="$work/install"
mkdir -p "$INSTALL/skills/codex-code-review" \
         "$INSTALL/skills/lib/tracker" \
         "$INSTALL/bin"
cp -R "$SKILL/scripts" "$SKILL/prompts" "$INSTALL/skills/codex-code-review/"
cp -R "$REPO/skills/lib/codex" "$REPO/skills/lib/config" "$INSTALL/skills/lib/"

# Recording stand-in for the tracker layer: appends every call to $TRACKER_LOG
# and serves the canned contract/title the test wrote.
cat > "$INSTALL/skills/lib/tracker/tracker.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$TRACKER_LOG"
case "${1:-}" in
  contract) cat "$TRACKER_CONTRACT" ;;
  title) printf '%s\n' "${TRACKER_TITLE:-a ticket}" ;;
esac
SH

# Stub Codex CLI: writes a review to the -o file and emits the one event the
# shared runner needs (thread.started) on stdout.
cat > "$INSTALL/bin/codex" <<'SH'
#!/usr/bin/env bash
out=""; prev=""
for a in "$@"; do [ "$prev" = "-o" ] && out=$a; prev=$a; done
[ -z "$out" ] || printf 'stub review\nAPPROVED\n' > "$out"
printf '{"type":"thread.started","thread_id":"t-stub"}\n'
SH
chmod +x "$INSTALL/skills/lib/tracker/tracker.sh" "$INSTALL/bin/codex"

CONTRACT="$work/contract.md"
cat > "$CONTRACT" <<'EOF'
== TICKET #12 ==
## Parent

- #2

## What to build

A ticket body.
== AMENDMENTS #12 ==
(none)
== PRESUMED FOLDED #12 ==
(none)
== UNMARKED #12 ==
(none)
== PARENT #2 ==
A parent spec.
== AMENDMENTS #2 ==
(none)
== PRESUMED FOLDED #2 ==
(none)
== UNMARKED #2 ==
(none)
EOF

export TRACKER_LOG="$work/tracker.log"
export TRACKER_CONTRACT="$CONTRACT"
export TRACKER_TITLE="fix: a ticket under review"

# A project root is where the wrapper reads configuration from, so each case
# gets its own — the adapter is run from it, exactly as a session would.
new_project() { # <name> [config-body] -> project root on stdout
  local root="$work/$1"
  mkdir -p "$root/docs"
  printf '%s' "${2:-}" > "$root/docs/addw.env"
  printf '%s' "$root"
}

run_start() { # <project-root> <state-dir> <issue> [args…]
  local root="$1" state="$2"; shift 2
  ( cd "$root" && PATH="$INSTALL/bin:$PATH" STATE_DIR="$state" \
      bash "$INSTALL/skills/codex-code-review/scripts/start.sh" "$@" )
}

run_resume() { # <project-root> <state-dir> <issue> [args…]
  local root="$1" state="$2"; shift 2
  ( cd "$root" && PATH="$INSTALL/bin:$PATH" STATE_DIR="$state" \
      bash "$INSTALL/skills/codex-code-review/scripts/resume.sh" "$@" )
}

# --- the configured directory reaches the buffer ---------------------------

# An ADR directory other than docs/adr/ — the whole point of the fixture.
CONFIGURED='ADDW_MAIN_BRANCH="master"
ADDW_ADR_DIR="docs/decisions"
ADDW_CONVENTIONS="CLAUDE.md docs/CONVENTIONS.md"
'
project="$(new_project configured "$CONFIGURED")"
state="$work/state-configured"

: > "$TRACKER_LOG"
out="$(run_start "$project" "$state" 12 "gate: green" 2>&1)" \
  || fail "start.sh: exited non-zero: $out"

buffer="$state/issue-12.context.md"
[ -f "$buffer" ] || fail "start.sh: no context buffer at $buffer"
buf="$(cat "$buffer")"

assert_contains "$buf" "docs/decisions" \
  "start: the buffer names the configured ADR directory"
assert_not_contains "$buf" "docs/adr" \
  "start: the buffer names no hardcoded ADR directory"
assert_contains "$buf" "A ticket body." \
  "start: the buffer still carries the ticket body"
assert_contains "$(cat "$TRACKER_LOG")" "contract 12" \
  "start: the effective contract is read through the tracker layer"
# The conventions sources travel the same way (ADR 0016): each listed file by
# name, for the reviewer to read whole.
assert_contains "$buf" '- `CLAUDE.md`' \
  "start: the buffer lists the first conventions source"
assert_contains "$buf" '- `docs/CONVENTIONS.md`' \
  "start: the buffer lists the second conventions source"

# Resume rebuilds the buffer from scratch, so it must interpolate too — a
# reviewer that saw the directory on turn 1 and lost it on turn 2 is the same
# silent pass, one round later.
rm -f "$buffer"
out="$(run_resume "$project" "$state" 12 "gate: green" 2>&1)" \
  || fail "resume.sh: exited non-zero: $out"
buf="$(cat "$buffer")"
assert_contains "$buf" "docs/decisions" \
  "resume: the buffer names the configured ADR directory"
assert_not_contains "$buf" "docs/adr" \
  "resume: the buffer names no hardcoded ADR directory"
assert_contains "$buf" '- `docs/CONVENTIONS.md`' \
  "resume: the buffer lists the conventions sources"

# --- the effective contract is carried verbatim ---------------------------

AMENDMENT_CONTRACT="$work/contract-amendment.md"
cat > "$AMENDMENT_CONTRACT" <<'EOF'
== TICKET #17 ==
## What to build

The body says the old behavior.
== AMENDMENTS #17 ==
-- 901 2026-10-14T22:38:17Z varigg --
Amends-contract: use the new behavior

Literal values: $HOME, backslash \, and & stay unchanged.
== PRESUMED FOLDED #17 ==
(none)
== UNMARKED #17 ==
(none)
== PARENT #243 ==
Parent spec text.
== AMENDMENTS #243 ==
(none)
== PRESUMED FOLDED #243 ==
(none)
== UNMARKED #243 ==
(none)
EOF
export TRACKER_CONTRACT="$AMENDMENT_CONTRACT"
AMENDMENT_CONFIG='ADDW_ADR_DIR="docs/decisions"
ADDW_CONVENTIONS=
'
project="$(new_project amendment "$AMENDMENT_CONFIG")"
state="$work/state-amendment"
out="$(run_start "$project" "$state" 17 2>&1)" \
  || fail "start.sh (amendment contract): exited non-zero: $out"
expected="$work/expected-amendment.context.md"
{
  printf '# Ticket #17 — %s\n\n' "$TRACKER_TITLE"
  cat "$AMENDMENT_CONTRACT"
  printf '\n---\n\nADR directory for guardrail review: `docs/decisions`\n'
  printf '\n---\n\nConventions sources: none — the project declares no rules (`ADDW_CONVENTIONS=`). Skip the convention checklist items and say in the review that it ran without a conventions check.\n'
} > "$expected"
cmp -s "$expected" "$state/issue-17.context.md" \
  || fail "amendment contract: the tracker output was not carried byte-for-byte"

# A standalone contract has all fixed-format sections but no parent block, so
# the adapter supplies the existing standalone-review note.
STANDALONE_CONTRACT="$work/contract-standalone.md"
cat > "$STANDALONE_CONTRACT" <<'EOF'
== TICKET #18 ==
## What to build

A standalone ticket.
== AMENDMENTS #18 ==
(none)
== PRESUMED FOLDED #18 ==
(none)
== UNMARKED #18 ==
(none)
EOF
export TRACKER_CONTRACT="$STANDALONE_CONTRACT"
project="$(new_project standalone "$AMENDMENT_CONFIG")"
state="$work/state-standalone"
out="$(run_start "$project" "$state" 18 2>&1)" \
  || fail "start.sh (standalone contract): exited non-zero: $out"
buf="$(cat "$state/issue-18.context.md")"
assert_contains "$buf" "== AMENDMENTS #18 ==" \
  "standalone contract: amendment section reaches the buffer"
assert_contains "$buf" "== PRESUMED FOLDED #18 ==" \
  "standalone contract: presumed-folded section reaches the buffer"
assert_contains "$buf" "== UNMARKED #18 ==" \
  "standalone contract: unmarked section reaches the buffer"
assert_contains "$buf" "No parent spec: this ticket stands alone. Review it against its own acceptance criteria." \
  "standalone contract: no-parent note is appended"
assert_not_contains "$buf" "== PARENT #" \
  "standalone contract: no parent block is invented"

start_tpl="$(cat "$SKILL/prompts/start.tpl")"
assert_contains "$start_tpl" \
  "An amendment overrides the body where they conflict and a later amendment overrides an earlier one." \
  "start prompt: states amendment precedence"

# --- no directory configured: say so, never guess --------------------------

project="$(new_project unconfigured 'ADDW_MAIN_BRANCH="master"
')"
state="$work/state-unconfigured"

out="$(run_start "$project" "$state" 13 2>&1)" \
  || fail "start.sh (no ADR dir): exited non-zero: $out"
buf="$(cat "$state/issue-13.context.md")"
assert_not_contains "$buf" "docs/adr" \
  "no ADR dir: the buffer falls back to no directory at all"
assert_contains "$buf" "ADDW_ADR_DIR" \
  "no ADR dir: the buffer names the key whose absence disabled the check"
assert_contains "$buf" "not performed" \
  "no ADR dir: the reviewer reports the item unperformed rather than passing it"
# The unconfigured fixture lacks ADDW_CONVENTIONS too: same policy — the
# review runs, and the conventions items are reported as not performed.
assert_contains "$buf" "Conventions sources: none. \`ADDW_CONVENTIONS\` is absent" \
  "no conventions key: the buffer says the key is absent"

# An exported value must not stand in for an absent key: a session that happens
# to carry ADDW_ADR_DIR from elsewhere would otherwise hand the reviewer some
# other project's directory and call it configured. The other ADR consumer
# freezes the same property (tests/next-adr-number.test.sh).
project="$(new_project exported 'ADDW_MAIN_BRANCH="master"
')"
state="$work/state-exported"
out="$( export ADDW_ADR_DIR="docs/from-the-environment"
        run_start "$project" "$state" 14 2>&1 )" \
  || fail "start.sh (exported ADR dir): exited non-zero: $out"
buf="$(cat "$state/issue-14.context.md")"
assert_not_contains "$buf" "docs/from-the-environment" \
  "exported ADR dir: an inherited value never stands in for an absent key"

# A declared-but-empty value is an absent directory, not a directory named "".
project="$(new_project empty 'ADDW_ADR_DIR=""
')"
state="$work/state-empty"
out="$(run_start "$project" "$state" 15 2>&1)" \
  || fail "start.sh (empty ADR dir): exited non-zero: $out"
assert_contains "$(cat "$state/issue-15.context.md")" "ADDW_ADR_DIR" \
  "empty ADR dir: reported as unresolved, not as a configured directory"

# The config is data parsed by the shared reader, never sourced — so a file
# the grammar rejects is a defect the review must not paper over as "no ADR
# directory configured": it exits 78 (EX_CONFIG) with the parser's
# line-numbered diagnostic. Asserted through the adapter entry point, which
# covers this wrapper's read of the same config the shared runner parses.
project="$(new_project rejected 'ADDW_ADR_DIR="docs/decisions"
[ -n "${ADDW_NOT_SET:-}" ]
')"
state="$work/state-rejected"
status=0
out="$(run_start "$project" "$state" 16 2>&1)" || status=$?
assert_eq 78 "$status" \
  "grammar-rejected config: fatal with 78, never read as unconfigured"
assert_contains "$out" "docs/addw.env:2:" \
  "grammar-rejected config: the diagnostic names the offending line"

# --- the checklist names no directory --------------------------------------

checklist="$(cat "$SKILL/checklist.md")"
assert_not_contains "$checklist" "docs/adr" \
  "checklist: no hardcoded ADR directory"
assert_contains "$checklist" "guardrail ADRs" \
  "checklist: the guardrail-ADR item survives the de-hardcoding"

# The prose-against-decisions read (#125) fires only on a diff touching a
# write-once artifact — the same list, not a new surface, and conditioned so
# rounds touching no ADR carry no added instruction.
assert_contains "$checklist" "Only when the diff touches a write-once artifact" \
  "checklist: the prose-against-decisions read is conditioned on a write-once artifact"

# --- the implementation step carries an ADR Gate into the instruction block -

implement_md="$(cat "$REPO/skills/addw-implement/SKILL.md")"
assert_contains "$implement_md" 'ADR `Gate`' \
  "addw-implement: Step 6 obliges the caller to carry an ADR Gate into the instruction block"


# --- conventions sources: absent vs deliberately empty -----------------------
# Same policy as the ADR directory: doctor fails an install missing the key,
# and the review still runs — the conventions items are reported, never passed
# quietly. An absent key is "not performed"; an explicit empty value is the
# project's declared choice to have no rules.

project="$(new_project norules 'ADDW_MAIN_BRANCH="master"
ADDW_ADR_DIR="docs/decisions"
ADDW_CONVENTIONS=
')"
state="$work/state-norules"
out="$(run_start "$project" "$state" 14 2>&1)" \
  || fail "start.sh (empty conventions): exited non-zero: $out"
buf="$(cat "$state/issue-14.context.md")"
assert_contains "$buf" "Conventions sources: none — the project declares no rules" \
  "empty conventions: the buffer states the declared choice"
assert_contains "$buf" "without a conventions check" \
  "empty conventions: the reviewer is told to say the check did not run"

echo "code-review: ADR directory from configuration, on start and resume; Gate in the instruction block"

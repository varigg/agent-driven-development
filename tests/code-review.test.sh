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
cp -R "$REPO/skills/lib/codex" "$INSTALL/skills/lib/"
cp "$REPO/skills/lib/tracker/parse.sh" "$INSTALL/skills/lib/tracker/parse.sh"

# Recording stand-in for the tracker layer: appends every call to $TRACKER_LOG
# and serves the canned body/title the test wrote.
cat > "$INSTALL/skills/lib/tracker/tracker.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$TRACKER_LOG"
case "${1:-}" in
  body)  cat "$TRACKER_BODY" ;;
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

BODY="$work/body.md"
printf '## Parent\n\n- #2\n\n## What to build\n\nA ticket body.\n' > "$BODY"

export TRACKER_LOG="$work/tracker.log"
export TRACKER_BODY="$BODY"
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
assert_contains "$(cat "$TRACKER_LOG")" "body 12" \
  "start: the ticket is read through the tracker layer"

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

# `.` returns the exit status of the config's LAST command, so a shell-clean
# config ending on a false conditional must still yield its ADR directory —
# gating the read on that status would report a configured project as
# unconfigured, which is the silent pass this ticket exists to kill, one layer
# down. Asserted through the adapter entry point, which covers this wrapper's
# read and the shared runner's sourcing of the same config in one pass.
project="$(new_project trailing-false 'ADDW_ADR_DIR="docs/decisions"
[ -n "${ADDW_NOT_SET:-}" ]
')"
state="$work/state-trailing-false"
out="$(run_start "$project" "$state" 16 2>&1)" \
  || fail "start.sh (config ending false): exited non-zero: $out"
assert_contains "$(cat "$state/issue-16.context.md")" "docs/decisions" \
  "config ending on a false conditional: the directory still resolves"

# --- the checklist names no directory --------------------------------------

checklist="$(cat "$SKILL/checklist.md")"
assert_not_contains "$checklist" "docs/adr" \
  "checklist: no hardcoded ADR directory"
assert_contains "$checklist" "guardrail ADRs" \
  "checklist: the guardrail-ADR item survives the de-hardcoding"

# --- the implementation step carries an ADR Gate into the instruction block -

implement_md="$(cat "$REPO/skills/addw-implement/SKILL.md")"
assert_contains "$implement_md" 'ADR `Gate`' \
  "addw-implement: Step 6 obliges the caller to carry an ADR Gate into the instruction block"

echo "code-review: ADR directory from configuration, on start and resume; Gate in the instruction block"

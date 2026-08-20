#!/usr/bin/env bash
# Contract: skills/codex-spec-review — the spec-review adapter's mechanics.
#
# The adapter owns three things this file freezes:
#
#   1. Tracker routing. Every tracker operation goes through the tracker
#      layer (skills/lib/tracker/tracker.sh), resolved relative to the
#      installed skills tree: the body sync reads `body <n>`, the session
#      start reads `title <n>` and applies `label <n> spec`, and the skill's
#      own instructions file retirement tickets with `create`. Nothing here
#      calls the tracker CLI (that half of the contract is static, and lives
#      in tracker-seam.test.sh).
#
#   2. Labelling first. start.sh applies the `spec` label as its first act —
#      before the body is fetched and before Codex is invoked — because the
#      frontier and completion queries key on that label.
#
#   3. The body-sync guard. fetch_issue_body refuses (exit 3) a buffer that
#      differs from the issue body, but trailing newlines are not a
#      difference: the layer's `body` output ends in one, a pushed body may
#      not, and a successful push must never come back as a divergent
#      buffer. On acceptance the buffer is rewritten with the delivered
#      bytes; on refusal it is left untouched with no `.remote` residue.
#
# Plus the prompt's use of the domain-layout contract (docs/agents/domain.md)
# in place of hardcoded glossary and ADR paths.
#
# The adapter is exercised against a throwaway copy of the skills tree whose
# tracker layer is a recording stand-in and whose `codex` is a stub, so the
# tests run offline and assert on the calls the adapter makes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
SKILL="$REPO/skills/codex-spec-review"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- the throwaway install -------------------------------------------------

INSTALL="$work/install"
mkdir -p "$INSTALL/skills/codex-spec-review" \
         "$INSTALL/skills/lib/tracker" \
         "$INSTALL/bin" \
         "$INSTALL/state"
cp -R "$SKILL/scripts" "$SKILL/prompts" "$INSTALL/skills/codex-spec-review/"
cp -R "$REPO/skills/lib/codex" "$REPO/skills/lib/config" "$INSTALL/skills/lib/"

# Recording stand-in for the tracker layer: appends every call to
# $TRACKER_LOG and serves the canned body/title the test wrote.
cat > "$INSTALL/skills/lib/tracker/tracker.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$TRACKER_LOG"
case "${1:-}" in
  body)  cat "$TRACKER_BODY" ;;
  title) printf '%s\n' "${TRACKER_TITLE:-a spec}" ;;
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

# The body as the tracker layer delivers it: the layer's `body` read ends its
# output with a newline the stored body does not carry.
BODY="$work/body.md"
printf '## Parent\n\n- #2\n\n## What to build\n\nA spec body.\n' > "$BODY"

export TRACKER_LOG="$work/tracker.log"
export TRACKER_BODY="$BODY"
export TRACKER_TITLE="process: a spec under review"

reset_log() { : > "$TRACKER_LOG"; }

# --- the body-sync guard ---------------------------------------------------

fetch() { # <issue> <buffer> [--refresh] — sourced call, isolated per run
  ( source "$INSTALL/skills/codex-spec-review/scripts/_fetch.sh"
    fetch_issue_body "$1" "$2" "${3:-}" )
}

# absent buffer: created from the issue body, read through the layer
reset_log
buf="$work/absent.md"
fetch 8 "$buf" >/dev/null 2>&1
assert_eq "$(cat "$BODY")" "$(cat "$buf")" "absent buffer: created from the body"
assert_contains "$(cat "$TRACKER_LOG")" "body 8" \
  "absent buffer: the body is read through the tracker layer"

# identical buffer: accepted
buf="$work/identical.md"
cp "$BODY" "$buf"
assert_exit 0 "identical buffer: accepted" fetch 8 "$buf"

# the live defect: a pushed body comes back with one newline more than the
# buffer that was pushed. Trailing newlines are not a divergence.
buf="$work/short-newline.md"
printf '%s' "$(cat "$BODY")" > "$buf"   # same bytes, no trailing newline
assert_exit 0 "buffer without the trailing newline: accepted" fetch 8 "$buf"
assert_eq "$(cat "$BODY")" "$(cat "$buf")" \
  "buffer without the trailing newline: rewritten with the delivered bytes"

buf="$work/extra-newlines.md"
cat "$BODY" > "$buf"; printf '\n\n\n' >> "$buf"
assert_exit 0 "buffer with extra trailing newlines: accepted" fetch 8 "$buf"

# a genuine divergence still refuses, and leaves nothing behind
buf="$work/divergent.md"
sed 's/A spec body./An edited spec body./' "$BODY" > "$buf"
before="$(cat "$buf")"
assert_exit 3 "divergent buffer: refused" fetch 8 "$buf"
assert_eq "$before" "$(cat "$buf")" "divergent buffer: left untouched"
[ ! -e "$buf.remote" ] || fail "divergent buffer: .remote residue left behind"

# --refresh takes the remote as truth
assert_exit 0 "divergent buffer: --refresh accepted" fetch 8 "$buf" --refresh
assert_eq "$(cat "$BODY")" "$(cat "$buf")" "divergent buffer: --refresh overwrites"

# --- start.sh: label first, everything through the layer -------------------

reset_log
out="$(PATH="$INSTALL/bin:$PATH" STATE_DIR="$INSTALL/state" \
       bash "$INSTALL/skills/codex-spec-review/scripts/start.sh" 8 2>&1)" \
  || fail "start.sh: exited non-zero: $out"

log="$(cat "$TRACKER_LOG")"
assert_eq "label 8 spec" "$(head -1 "$TRACKER_LOG")" \
  "start.sh: labels the issue as a spec first"
assert_contains "$log" "title 8" "start.sh: reads the title through the layer"
assert_contains "$log" "body 8" "start.sh: reads the body through the layer"
assert_eq "$(cat "$BODY")" "$(cat "$INSTALL/state/issue-8.md")" \
  "start.sh: the buffer holds the issue body"

# --- the prompt follows the domain-layout contract -------------------------

tpl="$(cat "$SKILL/prompts/start.tpl")"
assert_contains "$tpl" "docs/agents/domain.md" \
  "start prompt: locates the glossary via the domain-layout contract"
assert_not_contains "$tpl" "docs/CONTEXT.md" \
  "start prompt: no hardcoded glossary path"
assert_not_contains "$tpl" "docs/adr/" \
  "start prompt: no hardcoded ADR path"

# --- the skill's agent-facing instructions route through the layer ---------

skill_md="$(cat "$SKILL/SKILL.md")"
assert_contains "$skill_md" "tracker.sh edit-body" \
  "SKILL.md: body pushes go through the tracker layer"
assert_contains "$skill_md" "tracker.sh comment" \
  "SKILL.md: the verdict comment goes through the tracker layer"
assert_contains "$skill_md" "tracker.sh create" \
  "SKILL.md: retirement tickets go through the tracker layer"

echo "spec-review: tracker routing, spec label, body-sync guard, prompt contract"

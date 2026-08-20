#!/usr/bin/env bash
# Contract: skills/lib/codex — the shared Codex runner, and the skill
# inventory the retirement sweep leaves behind.
#
# The runner used to be hosted inside the codex-plan-review skill, which
# retires. Three things follow, and this file freezes all three:
#
#   1. The runner lives in the shared layer (skills/lib/codex), and every
#      codex adapter resolves it there. A stale `codex-plan-review/scripts`
#      path anywhere under skills/ is a runtime break, not a cosmetic one:
#      the adapters exec the runner by path, so the failure surfaces only
#      when somebody starts a review.
#
#   2. The runner owns no state and no prompts. As a hosted skill it could
#      default STATE_DIR to its own state/ and --prompt-file to its own
#      prompts/; in the shared layer both defaults would resolve to paths
#      that do not exist (skills/lib/state, skills/lib/prompts), silently
#      merging every adapter's threads into one namespace. Both inputs are
#      required, and their absence is a usage error.
#
#   3. The tree carries the post-retirement inventory: the retired skills
#      and the AskUserQuestion shim are gone, and every surviving skill's
#      folder name matches its frontmatter name (skill discovery keys on
#      the latter, the docs contract on the former — a rename that moves
#      only one of them is a live bug).
#
# The adapters are exercised against a throwaway copy of the skills tree
# whose tracker layer is a recording stand-in and whose `codex` is a stub,
# so the tests run offline and assert on what the adapters actually do.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
RUNNER="$REPO/skills/lib/codex"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- 1. the runner lives in the shared layer -------------------------------

for f in _common.sh start.sh resume.sh reset.sh show.sh; do
  [ -f "$RUNNER/$f" ] || fail "shared runner: missing skills/lib/codex/$f"
done

# Nothing under skills/ may still name a retired folder. For the runner a
# stale path breaks at runtime; for the rest, prose sends the next reader to
# a folder that is gone — and a shipped script can print a slash command
# nobody can run. Every retired name is swept, not just the runner's: the one
# name this guard originally covered was the one the sweep got right.
# Tracked files only: what ships is what git carries. Each adapter's state/
# holds gitignored session transcripts, and a Codex thread that discussed the
# retirement quotes every name being retired.
for gone in codex-plan-review addw-1-plan addw-research addw-test \
            addw-4-maintain 'AskUserQuestion/'; do
  stale="$(git -C "$REPO" grep -lF -- "$gone" -- skills 2>/dev/null || true)"
  [ -z "$stale" ] || fail "retired name '$gone' still under skills/: $(printf '%s ' $stale)"
done
# Note the trailing slash on the shim: surviving skills correctly instruct
# agents to "use the AskUserQuestion tool" — that is the native tool, and only
# the folder retired. Sweeping the bare word would flag every one of them.

# --- 2. the retired tree ---------------------------------------------------

for d in skills/codex-plan-review skills/addw-1-plan skills/addw-research \
         skills/addw-test AskUserQuestion; do
  [ ! -e "$REPO/$d" ] || fail "retired, but still present: $d"
done

# The numbered maintain folder rides this sweep to its spec name.
[ -d "$REPO/skills/addw-maintain" ] || fail "inventory: skills/addw-maintain missing"
[ ! -e "$REPO/skills/addw-4-maintain" ] || fail "inventory: addw-4-maintain still present"

# Folder name and frontmatter name are one fact in two places.
for skill in "$REPO"/skills/*/; do
  name="$(basename "$skill")"
  [ "$name" = "lib" ] && continue
  [ -f "$skill/SKILL.md" ] || fail "inventory: $name has no SKILL.md"
  declared="$(sed -n 's/^name: *//p' "$skill/SKILL.md" | head -1)"
  assert_eq "$name" "$declared" "inventory: $name frontmatter name"
done

# --- the throwaway install -------------------------------------------------

INSTALL="$work/install"
mkdir -p "$INSTALL/bin"
cp -R "$REPO/skills" "$INSTALL/skills"
# Live thread state would make start.sh refuse (exit 2); the adapters under
# test each get an empty state dir of their own.
find "$INSTALL/skills" -type d -name state -exec sh -c \
  'rm -rf "$1" && mkdir -p "$1"' _ {} \;

# Recording stand-in for the tracker layer: serves a canned body and title.
cat > "$INSTALL/skills/lib/tracker/tracker.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  body)  printf '## Parent\n\n- #2\n\n## What to build\n\nA ticket body.\n' ;;
  title) printf 'process: a ticket under review\n' ;;
  label) : ;;
esac
SH

# Stub Codex CLI: writes a review to the -o file and emits the one event the
# runner needs (thread.started) on stdout.
cat > "$INSTALL/bin/codex" <<'SH'
#!/usr/bin/env bash
out=""; prev=""
for a in "$@"; do [ "$prev" = "-o" ] && out=$a; prev=$a; done
[ -z "$out" ] || printf 'stub review\nAPPROVED\n' > "$out"
printf '{"type":"thread.started","thread_id":"t-stub"}\n'
SH
chmod +x "$INSTALL/skills/lib/tracker/tracker.sh" "$INSTALL/bin/codex"

# --- 3. the runner requires state and prompt -------------------------------

# No STATE_DIR: a usage error, and emphatically not a state directory
# invented inside the shared layer.
assert_exit 64 "runner: unset STATE_DIR is a usage error" \
  env -u STATE_DIR PATH="$INSTALL/bin:$PATH" \
  bash "$INSTALL/skills/lib/codex/start.sh" \
    --prompt-file "$INSTALL/skills/codex-ask/prompts/ask.tpl" a-topic
[ ! -e "$INSTALL/skills/lib/state" ] || fail "runner: invented skills/lib/state"

# No --prompt-file: a usage error, not a read of a prompts/ dir that the
# shared layer does not have.
assert_exit 64 "runner: missing --prompt-file is a usage error" \
  env STATE_DIR="$work/s1" PATH="$INSTALL/bin:$PATH" \
  bash "$INSTALL/skills/lib/codex/start.sh" a-topic
assert_exit 64 "runner: resume without --prompt-file is a usage error" \
  env STATE_DIR="$work/s1" PATH="$INSTALL/bin:$PATH" \
  bash "$INSTALL/skills/lib/codex/resume.sh" a-topic

# --- 4. every adapter reaches the relocated runner -------------------------

# Each adapter pins STATE_DIR to its own state/ and its own prompt, then
# hands off. A successful start writes the thread and review under that
# adapter's state — never a neighbour's, never the shared layer's.
start_adapter() { # <skill> <target...>
  local skill="$1"; shift
  ( cd "$INSTALL"
    PATH="$INSTALL/bin:$PATH" \
      bash "$INSTALL/skills/$skill/scripts/start.sh" "$@" )
}

for case in "codex-ask a-topic" "codex-implement 42" \
            "codex-code-review 42" "codex-spec-review 42"; do
  # shellcheck disable=SC2086
  set -- $case
  skill="$1"; shift
  out="$(start_adapter "$skill" "$@" 2>&1)" \
    || fail "$skill: start.sh exited non-zero against the relocated runner: $out"
  state="$INSTALL/skills/$skill/state"
  threads="$(find "$state" -name '*.thread' -type f | wc -l)"
  [ "$threads" -ge 1 ] \
    || fail "$skill: no thread file under its own state after start.sh"
  assert_contains "$out" "stub review" "$skill: the runner's review reaches stdout"
done

[ ! -e "$INSTALL/skills/lib/state" ] \
  || fail "adapters: state leaked into the shared layer"

# --- 5. the project config is data, parsed by the shared reader ------------

# The config is never sourced: the shared reader parses it as data, so a
# config has no exit status, no stdout, and no way to stop an adapter — the
# only config failure left is a file the grammar rejects, which is a real
# defect and fatal (78). The runner is on the path of all four adapters, so
# both halves are asserted through each entry point rather than against the
# sourced helper — the helper can be correct while the adapters still die.
#
# Each case gets its own project root, because the config is read from the
# working directory, exactly as a session would.
new_project() { # <name> <config-body> -> project root on stdout
  local root="$work/$1"
  mkdir -p "$root/docs"
  printf '%s' "$2" > "$root/docs/addw.env"
  printf '%s' "$root"
}

start_in() { # <project-root> <state-dir> <skill> <target...>
  local root="$1" state="$2" skill="$3"; shift 3
  ( cd "$root" && env -u CODEX_MODEL -u CODEX_EFFORT \
      PATH="$INSTALL/bin:$PATH" STATE_DIR="$state" \
      bash "$INSTALL/skills/$skill/scripts/start.sh" "$@" )
}

# The two model keys carry distinct values so that each adapter is shown to
# read its OWN key rather than whichever one happens to be set: the impl flow
# runs ADDW_CODEX_MODEL_IMPL, every review flow runs ADDW_CODEX_MODEL_REVIEW.
configured="$(new_project configured 'ADDW_CODEX_MODEL_IMPL="impl-from-config"
ADDW_CODEX_MODEL_REVIEW="review-from-config"
ADDW_CODEX_EFFORT="effort-from-config"
')"

for case in "codex-ask a-topic review" "codex-implement 42 impl" \
            "codex-code-review 42 review" "codex-spec-review 42 review"; do
  # shellcheck disable=SC2086
  set -- $case
  skill="$1" target="$2" flow="$3"
  out="$(start_in "$configured" "$work/cfg-$skill" "$skill" "$target" 2>&1)" \
    || fail "$skill: a conforming config stopped the adapter: $out"
  assert_contains "$out" "$flow-from-config" \
    "$skill: the flow's own model key is read from the config"
  assert_contains "$out" "effort-from-config" \
    "$skill: the effort key is read from the config"
done

# A config that cannot be parsed is the defect the config contract deliberately keeps
# fatal. Whatever makes the case above survivable must not swallow it: it
# fails, it names the config, and it exits 78 (EX_CONFIG) so a caller can tell
# a config defect from a Codex failure (1) or a live thread (2).
unparseable="$(new_project unparseable 'ADDW_CODEX_MODEL_REVIEW="unterminated
')"

for case in "codex-ask a-topic" "codex-implement 42" \
            "codex-code-review 42" "codex-spec-review 42"; do
  # shellcheck disable=SC2086
  set -- $case
  skill="$1" target="$2"
  status=0
  out="$(start_in "$unparseable" "$work/bad-$skill" "$skill" "$target" 2>&1)" || status=$?
  [ "$status" -eq 78 ] \
    || fail "$skill: unparseable config expected exit 78, got $status: $out"
  assert_contains "$out" "docs/addw.env" \
    "$skill: unparseable config — the failure names the config"
  assert_not_contains "$out" "stub review" \
    "$skill: unparseable config — Codex is never invoked"
done

# The three keys come from the config alone. A value inherited from the
# environment must never stand in for one the project did not declare, or a
# session carrying another project's value would silently pick the wrong model
# — the same property the other config readers freeze (tests/code-review.test.sh,
# tests/next-adr-number.test.sh). Both routes to an undeclared key are covered:
# no config file at all, and a config that simply does not mention it.
run_with_env() { # <project-root> <state-dir> -> adapter stdout, ADDW_ key exported
  ( cd "$1" && export ADDW_CODEX_MODEL_REVIEW="model-from-the-environment"
    env -u CODEX_MODEL -u CODEX_EFFORT \
      PATH="$INSTALL/bin:$PATH" STATE_DIR="$2" \
      bash "$INSTALL/skills/codex-ask/scripts/start.sh" a-topic 2>&1 )
}

no_config="$work/no-config"
mkdir -p "$no_config"
out="$(run_with_env "$no_config" "$work/inherited-nofile")" \
  || fail "codex-ask: no config file at all stopped the adapter: $out"
assert_contains "$out" "model/effort:" \
  "no config file: the adapter still runs"
assert_not_contains "$out" "model-from-the-environment" \
  "no config file: an inherited key never stands in for an absent one"

silent="$(new_project silent-on-the-key 'ADDW_CODEX_EFFORT="effort-from-config"
')"
out="$(run_with_env "$silent" "$work/inherited-silent")" \
  || fail "codex-ask: a config silent on the key stopped the adapter: $out"
assert_contains "$out" "effort-from-config" \
  "config silent on the key: the keys it does declare are still read"
assert_not_contains "$out" "model-from-the-environment" \
  "config silent on the key: an inherited key never stands in for it"

echo "codex runner: shared-layer home, required state/prompt, adapter wiring, config parsing, inventory"

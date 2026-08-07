#!/usr/bin/env bash
# Contract: skills/addw-init/scripts/doctor.sh — the install doctor.
#
# Doctor is the deterministic re-verification of everything init produced, and
# the final gate of both init and an upgrade. It is read-only and never fixes
# anything. Run from a project's repo root, it prints one OK/WARN/FAIL line per
# check and one terminal line — "HEALTHY: all checks passed", the same with a
# "(N warnings)" tail, or "UNHEALTHY: fix the FAIL lines above" — exiting 0 iff
# no check failed. Warnings never fail the run.
#
# What it verifies, in the ticket's terms (#9):
#
#   1. Config keys. The required values must be non-empty; the three recipe
#      keys must be *defined*, where an empty value is a deliberate skip and an
#      absent key is a gap. Recipes come from the config alone — an exported
#      ADDW_RECIPE_* must not stand in for a key the config doesn't set.
#   2. Docs contract. The directories and living docs, the ADR template at the
#      location ADDW_ADR_DIR names (never a hardcoded path — that is what the
#      domain-layout contract decides), and the project-instructions line that
#      declares that template authoritative over any skill-bundled ADR format.
#   3. Tracker validation. Matt's setup must have run, its configured tracker
#      must be GitHub, the tracker CLI must be authenticated with issues
#      enabled, and the three labels the frontier keys on must exist. A missing
#      frontier label would otherwise fail silently as a forever-empty frontier.
#   4. Plugin probes, graded. The two programmatic primitives (code-review,
#      tdd) hard-fail when absent because ADDW invokes them; the six
#      happy-path skills only warn, because the flow needs them but ADDW never
#      calls them.
#
# Everything runs offline: the fixture project is a real git repo in a temp
# dir, the tracker CLI is a stub on PATH, and the plugin probe searches a fake
# HOME. No test reaches into doctor's internals.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
DOCTOR="$REPO/skills/addw-init/scripts/doctor.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- the stub tracker CLI --------------------------------------------------
# Answers exactly the three questions the tracker layer asks on doctor's
# behalf. Each is steerable from the environment so a case can break one
# without touching the others.
mkdir -p "$work/bin"
cat > "$work/bin/gh" <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status")
    [ "${STUB_GH_AUTHED:-1}" = 1 ] || { echo "not logged in" >&2; exit 1; }
    ;;
  "repo view")
    printf '%s\n' "${STUB_GH_ISSUES:-true}"
    ;;
  "label list")
    printf '%s\n' ${STUB_GH_LABELS-ready-for-agent spec backlog needs-triage}
    ;;
  *)
    echo "stub gh: unexpected call: $*" >&2
    exit 90
    ;;
esac
SH
chmod +x "$work/bin/gh"

# The stub CLI whose listing drives the plugin probe's first tier. It must
# exist even when a case does not care, because the real binary is on PATH
# here and would otherwise answer with this machine's plugins instead of the
# fixture's. Its default is to FAIL rather than to return an empty listing:
# those two are deliberately different to the probe, and only a case that sets
# STUB_CLAUDE_PLUGINS exercises the first tier at all.
cat > "$work/bin/claude" <<'SH'
#!/usr/bin/env bash
[ "$1 $2" = "plugin list" ] || exit 90
[ -n "${STUB_CLAUDE_PLUGINS:-}" ] || exit 1
printf '%s\n' "$STUB_CLAUDE_PLUGINS"
SH
chmod +x "$work/bin/claude"

PATH="$work/bin:$PATH"
export PATH

# --- the fake plugin install ----------------------------------------------
# Skills live nested under a category directory inside a versioned plugin
# cache, which is where a real plugin install puts them.
plugin_skills() { # home-dir  skill-name...
  local home=$1 root name
  shift
  root="$home/.claude/plugins/cache/vendor/pack/1.0.0/skills/engineering"
  for name in "$@"; do
    mkdir -p "$root/$name"
    printf -- '---\nname: %s\ndescription: stub\n---\n' "$name" \
      > "$root/$name/SKILL.md"
  done
}

ALL_SKILLS=(code-review tdd setup-matt-pocock-skills grill-with-docs grilling
            domain-modeling to-spec to-tickets)

# --- the healthy project ---------------------------------------------------
BASE="$work/base"
mkdir -p "$BASE/project" "$BASE/home"
plugin_skills "$BASE/home" "${ALL_SKILLS[@]}"

(
  cd "$BASE/project"
  mkdir -p docs/agents docs/4-unit-tests docs/6-memo docs/7-maintenance docs/adr

  cat > docs/addw.env <<'ENV'
ADDW_SCHEMA=3
ADDW_PROJECT_NAME="fixture"
ADDW_VERSION_FILE="package.json"
ADDW_MAIN_BRANCH="main"
ADDW_AUDIT_NUDGE_N=5
ADDW_ADR_DIR="docs/adr"
ADDW_RECIPE_LINT="true"
ADDW_RECIPE_TYPECHECK=""
ADDW_RECIPE_TESTS_AFFECTED="true"
ENV

  printf '# Issue tracker: GitHub\n\nIssues live as GitHub issues.\n' \
    > docs/agents/issue-tracker.md
  printf '# Domain Docs\n\nSingle-context: CONTEXT.md and docs/adr/.\n' \
    > docs/agents/domain.md

  printf '# Architecture\n' > docs/ARCHITECTURE.md
  printf '# Architecture Documentation Rules\n' > docs/ARCHITECTURE-rules.md
  printf '# Charter\n' > docs/charter.md
  printf '# Changelog\n' > CHANGELOG.md
  printf '{ "version": "0.1.0" }\n' > package.json
  printf '# Testing Guidelines\n\n## Verification Recipes\n\n## Integration / E2E Impact Rules\n' \
    > docs/4-unit-tests/TESTING.md

  cat > docs/adr/template.md <<'ADR'
# ADR NNNN: <Title>

- **Status**: active | superseded by ADR-NNNN
- **Date**: <YYYY-MM-DD>
- **Origin**: <#spec-issue, #ticket, PR #n, or "design session">

<One paragraph.>

## Gate (required for a guardrail decision)

<What a future reviewer must check.>
ADR

  cat > CLAUDE.md <<'MD'
# Project

## ADR format

`docs/adr/template.md` is the authoritative ADR format for this project.
MD

  git init -q -b main .
  git config user.email fixture@example.com
  git config user.name Fixture
  git add -A
  git commit -qm "chore: fixture"
) >/dev/null

# case <name> — copies the healthy project into a fresh case dir, echoes its
# path. Every mutation starts from the same known-good state.
case_dir() {
  local dst="$work/case-$1"
  rm -rf "$dst"
  cp -R "$BASE" "$dst"
  printf '%s\n' "$dst"
}

# run <case-dir> [env assignments...] — runs doctor at the case's project root
# with the case's fake HOME, capturing stdout+stderr in RUN_OUT and the exit
# code in RUN_STATUS.
RUN_OUT=""
RUN_STATUS=0
run() {
  local dir=$1
  shift
  RUN_STATUS=0
  RUN_OUT="$(cd "$dir/project" && env HOME="$dir/home" "$@" bash "$DOCTOR" 2>&1)" \
    || RUN_STATUS=$?
}

# --- a complete install is healthy ----------------------------------------

d="$(case_dir healthy)"
run "$d"
assert_eq 0 "$RUN_STATUS" "healthy: a complete install exits zero"
assert_contains "$RUN_OUT" "HEALTHY: all checks passed" \
  "healthy: terminal line reports health"
assert_not_contains "$RUN_OUT" "FAIL:" "healthy: no check fails"
assert_not_contains "$RUN_OUT" "WARN:" "healthy: no check warns"

# --- config keys -----------------------------------------------------------

# An empty recipe key is a deliberate skip, not a gap: the healthy fixture
# already carries ADDW_RECIPE_TYPECHECK="" and passed above. An *absent* key
# is the gap.
d="$(case_dir norecipe)"
grep -v '^ADDW_RECIPE_TESTS_AFFECTED=' "$d/project/docs/addw.env" \
  > "$d/project/docs/addw.env.new"
mv "$d/project/docs/addw.env.new" "$d/project/docs/addw.env"
run "$d"
assert_eq 1 "$RUN_STATUS" "recipe: an absent recipe key is unhealthy"
assert_contains "$RUN_OUT" "ADDW_RECIPE_TESTS_AFFECTED" \
  "recipe: the failing line names the absent key"
assert_contains "$RUN_OUT" "UNHEALTHY: fix the FAIL lines above" \
  "recipe: terminal line reports the failure"

# The config is the only source: an exported value must not paper over the gap
# doctor exists to report.
run "$d" ADDW_RECIPE_TESTS_AFFECTED="echo env-leak"
assert_eq 1 "$RUN_STATUS" \
  "recipe: an exported ADDW_RECIPE_* never substitutes for a missing key"

d="$(case_dir nokey)"
grep -v '^ADDW_PROJECT_NAME=' "$d/project/docs/addw.env" \
  > "$d/project/docs/addw.env.new"
mv "$d/project/docs/addw.env.new" "$d/project/docs/addw.env"
run "$d"
assert_eq 1 "$RUN_STATUS" "config: a missing required key is unhealthy"
assert_contains "$RUN_OUT" "ADDW_PROJECT_NAME" \
  "config: the failing line names the missing key"

d="$(case_dir noconfig)"
rm "$d/project/docs/addw.env"
run "$d"
assert_eq 1 "$RUN_STATUS" "config: a missing docs/addw.env is unhealthy"
assert_contains "$RUN_OUT" "docs/addw.env" \
  "config: the failing line names the config file"

# --- docs contract ---------------------------------------------------------

d="$(case_dir noadr)"
rm "$d/project/docs/adr/template.md"
run "$d"
assert_eq 1 "$RUN_STATUS" "adr: a missing ADR template is unhealthy"
assert_contains "$RUN_OUT" "docs/adr/template.md" \
  "adr: the failing line names the template path"

d="$(case_dir badadr)"
grep -v '^- \*\*Origin\*\*' "$d/project/docs/adr/template.md" \
  > "$d/project/docs/adr/template.md.new"
mv "$d/project/docs/adr/template.md.new" "$d/project/docs/adr/template.md"
run "$d"
assert_eq 1 "$RUN_STATUS" \
  "adr: a template without the mandatory Origin field is unhealthy"
assert_contains "$RUN_OUT" "Origin" "adr: the failing line names the field"

# added at codex round 1: the field being present is not the check — a
# skill-bundled template offering proposed/accepted/deprecated has a Status
# line too, and an install still carrying one is exactly what doctor is for.
d="$(case_dir wrongstatus)"
sed -i 's|^- \*\*Status\*\*.*|- **Status**: proposed / accepted / deprecated|' \
  "$d/project/docs/adr/template.md"
run "$d"
assert_eq 1 "$RUN_STATUS" \
  "adr: a template offering the wrong Status states is unhealthy"
assert_contains "$RUN_OUT" "Status" "adr: the failing line names the field"

# added at codex round 2: two states means two, so a third smuggled in beside
# the right pair must not pass on the strength of the pair being there.
d="$(case_dir threestatus)"
sed -i 's|^- \*\*Status\*\*.*|- **Status**: proposed \| active \| superseded by ADR-NNNN|' \
  "$d/project/docs/adr/template.md"
run "$d"
assert_eq 1 "$RUN_STATUS" "adr: a third Status state is unhealthy"

# added at codex round 1: the Gate section is where an author of a guardrail
# ADR learns it is required, so a template without one is a broken surface.
d="$(case_dir nogate)"
grep -v '^## Gate' "$d/project/docs/adr/template.md" \
  > "$d/project/docs/adr/template.md.new"
mv "$d/project/docs/adr/template.md.new" "$d/project/docs/adr/template.md"
run "$d"
assert_eq 1 "$RUN_STATUS" "adr: a template without a Gate section is unhealthy"
assert_contains "$RUN_OUT" "Gate" "adr: the failing line names the section"

# added at codex round 1: the declaration is the path and the word together.
# A file that merely mentions the template is not declaring anything.
d="$(case_dir passingmention)"
printf '# Project\n\nADRs use the template at `docs/adr/template.md`.\n' \
  > "$d/project/CLAUDE.md"
run "$d"
assert_eq 1 "$RUN_STATUS" \
  "override: a passing mention of the template is not a declaration"

d="$(case_dir nooverride)"
printf '# Project\n' > "$d/project/CLAUDE.md"
run "$d"
assert_eq 1 "$RUN_STATUS" \
  "override: project instructions that don't declare the template are unhealthy"
assert_contains "$RUN_OUT" "docs/adr/template.md" \
  "override: the failing line names the template the instructions must declare"

# The ADR location is the domain-layout contract's to choose, so nothing here
# is hardcoded: point the config elsewhere, move the artifacts, stay healthy.
d="$(case_dir altadr)"
(
  cd "$d/project"
  mkdir -p docs/decisions
  git mv docs/adr/template.md docs/decisions/template.md
  rmdir docs/adr
  sed -i 's|^ADDW_ADR_DIR=.*|ADDW_ADR_DIR="docs/decisions"|' docs/addw.env
  sed -i 's|docs/adr/template.md|docs/decisions/template.md|' CLAUDE.md
) >/dev/null
run "$d"
assert_eq 0 "$RUN_STATUS" \
  "adr-dir: an ADR location other than docs/adr/ is healthy when its artifacts are there"
assert_contains "$RUN_OUT" "HEALTHY" "adr-dir: no hardcoded ADR path"

# added at codex round 2: consumers check the value out, pass it to
# `gh pr create --base`, and derive `origin/$ADDW_MAIN_BRANCH` — so a
# remote-qualified value resolves as a ref while being wrong everywhere it is
# used. Checking the ref exists cannot catch that; checking its shape can.
d="$(case_dir remotebranch)"
sed -i 's|^ADDW_MAIN_BRANCH=.*|ADDW_MAIN_BRANCH="origin/main"|' \
  "$d/project/docs/addw.env"
run "$d"
assert_eq 1 "$RUN_STATUS" "branch: a remote-qualified main branch is unhealthy"
assert_contains "$RUN_OUT" "bare branch name" \
  "branch: the failing line says what shape is required"

# added at codex round 1: `inline` is the reserved non-adapter value for the
# implement role — the main agent drives `tdd` itself — so there is no skill
# folder to look for and doctor must not go looking for one.
d="$(case_dir inline)"
printf 'ADDW_IMPLEMENT_SKILL=inline\n' >> "$d/project/docs/addw.env"
run "$d"
assert_eq 0 "$RUN_STATUS" "role: ADDW_IMPLEMENT_SKILL=inline is healthy"
assert_not_contains "$RUN_OUT" "FAIL:" "role: inline needs no adapter scripts"

# --- tracker validation ----------------------------------------------------

d="$(case_dir nosetup)"
rm -r "$d/project/docs/agents"
run "$d"
assert_eq 1 "$RUN_STATUS" "setup: a project without Matt's setup is unhealthy"
assert_contains "$RUN_OUT" "docs/agents/issue-tracker.md" \
  "setup: the failing line names the missing setup artifact"

d="$(case_dir gitlab)"
printf '# Issue tracker: GitLab\n' > "$d/project/docs/agents/issue-tracker.md"
run "$d"
assert_eq 1 "$RUN_STATUS" "tracker: a non-GitHub tracker is unhealthy"
assert_contains "$RUN_OUT" "GitHub" \
  "tracker: the failing line says the overlay is GitHub-only"

d="$(case_dir noauth)"
run "$d" STUB_GH_AUTHED=0
assert_eq 1 "$RUN_STATUS" "auth: an unauthenticated tracker CLI is unhealthy"

d="$(case_dir noissues)"
run "$d" STUB_GH_ISSUES=false
assert_eq 1 "$RUN_STATUS" "issues: a repo with issues disabled is unhealthy"

# A missing frontier label is the silent failure this check exists for: the
# frontier would simply come back empty forever.
d="$(case_dir nolabel)"
run "$d" STUB_GH_LABELS="ready-for-agent backlog"
assert_eq 1 "$RUN_STATUS" "labels: a missing label is unhealthy"
assert_contains "$RUN_OUT" "spec" "labels: the failing line names the label"

# --- graded plugin probes --------------------------------------------------

# The programmatic pair: ADDW invokes these itself, so absence is fatal.
for required in code-review tdd; do
  d="$(case_dir "no-$required")"
  rm -r "$d/home/.claude/plugins/cache/vendor/pack/1.0.0/skills/engineering/$required"
  run "$d"
  assert_eq 1 "$RUN_STATUS" "plugin: a missing $required is unhealthy"
  assert_contains "$RUN_OUT" "$required" \
    "plugin: the failing line names $required"
done

# The happy-path six: the flow needs them, ADDW never calls them, so their
# absence warns and the install stays healthy.
d="$(case_dir no-to-spec)"
rm -r "$d/home/.claude/plugins/cache/vendor/pack/1.0.0/skills/engineering/to-spec"
run "$d"
assert_eq 0 "$RUN_STATUS" "plugin: a missing happy-path skill still exits zero"
assert_contains "$RUN_OUT" "WARN:" "plugin: its absence warns"
assert_contains "$RUN_OUT" "to-spec" "plugin: the warning names the skill"
assert_contains "$RUN_OUT" "HEALTHY: all checks passed (1 warning" \
  "plugin: the terminal line carries the warning count"

# added at codex round 3: an installed-but-disabled plugin is exactly as
# uninvocable as an absent one, and its skills sit in the cache under a live
# installPath — so only the enabled listing answers the question the probe is
# actually asking.
d="$(case_dir disabled-plugin)"
mkdir -p "$d/home/enabled-but-empty"
run "$d" STUB_CLAUDE_PLUGINS="[
  {\"enabled\": true,  \"installPath\": \"$d/home/enabled-but-empty\"},
  {\"enabled\": false, \"installPath\": \"$d/home/.claude/plugins/cache/vendor/pack/1.0.0\"}
]"
assert_eq 1 "$RUN_STATUS" "disabled: a disabled plugin's skills are unhealthy"
assert_contains "$RUN_OUT" "code-review" "disabled: the hard-fail pair is named"
assert_contains "$RUN_OUT" "tdd" "disabled: the hard-fail pair is named"

# added at codex round 4: "every plugin is disabled" is an answer, not a
# failure to answer. Widening the search on an empty-but-valid listing would
# hand back exactly the plugins the enabled filter just excluded.
d="$(case_dir all-disabled)"
run "$d" STUB_CLAUDE_PLUGINS="[
  {\"enabled\": false, \"installPath\": \"$d/home/.claude/plugins/cache/vendor/pack/1.0.0\"}
]"
assert_eq 1 "$RUN_STATUS" \
  "all-disabled: an empty enabled listing does not fall back to the cache"
assert_contains "$RUN_OUT" "tdd" "all-disabled: the hard-fail pair is named"

# added at codex round 2: when the install record is readable it names the
# installed plugins exactly, so a skill sitting in cache residue from a plugin
# that is no longer installed must not read as available.
d="$(case_dir stale-cache)"
plugin_skills "$d/home-residue" to-spec   # a second, unrecorded cache tree
mv "$d/home-residue/.claude/plugins/cache/vendor/pack" \
   "$d/home/.claude/plugins/cache/vendor/removed-pack"
rm -r "$d/home/.claude/plugins/cache/vendor/pack/1.0.0/skills/engineering/to-spec"
cat > "$d/home/.claude/plugins/installed_plugins.json" <<JSON
{ "version": 2, "plugins": { "pack@vendor": [ {
  "installPath": "$d/home/.claude/plugins/cache/vendor/pack/1.0.0" } ] } }
JSON
run "$d"
assert_eq 0 "$RUN_STATUS" "residue: the run still completes"
assert_contains "$RUN_OUT" "WARN:" "residue: an uninstalled plugin's skill warns"
assert_contains "$RUN_OUT" "to-spec" "residue: the warning names the skill"

# An unreadable or reshaped install record must widen the search rather than
# empty it: no paths extracted falls back to scanning the whole cache.
d="$(case_dir unparsable-record)"
printf 'not json at all\n' > "$d/home/.claude/plugins/installed_plugins.json"
run "$d"
assert_eq 0 "$RUN_STATUS" "fallback: an unreadable install record stays healthy"
assert_not_contains "$RUN_OUT" "WARN:" \
  "fallback: the cache scan still finds every installed skill"

# A project-local skills folder is a search root too, so the same skill
# installed there clears the probe.
d="$(case_dir local-skill)"
rm -r "$d/home/.claude/plugins/cache/vendor/pack/1.0.0/skills/engineering/to-spec"
mkdir -p "$d/project/.claude/skills/to-spec"
printf -- '---\nname: to-spec\n---\n' > "$d/project/.claude/skills/to-spec/SKILL.md"
run "$d"
assert_eq 0 "$RUN_STATUS" "plugin: a project-local skill exits zero"
assert_not_contains "$RUN_OUT" "WARN:" \
  "plugin: a project-local skill clears the probe"

echo "doctor: all contract assertions passed"

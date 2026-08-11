#!/usr/bin/env bash
# Contract: skills/addw-init/scripts/doctor.sh — the install doctor.
#
# Doctor is the deterministic re-verification of everything init produced, and
# the final gate of both init and an upgrade. It is read-only and never fixes
# anything. Run from a project's repo root, it prints one OK/FAIL line per
# check and one terminal line — "HEALTHY: all checks passed" or "UNHEALTHY: fix
# the FAIL lines above" — exiting 0 iff no check failed.
#
# What it verifies, in the ticket's terms (#9):
#
#   1. Config keys. The required values must be non-empty; the empty-legal keys
#      — the three recipes and ADDW_VERSION_FILE — must be *defined*, where an
#      empty value is a deliberate skip and an absent key is a gap. Values come
#      from the config alone — an exported ADDW_RECIPE_* must not stand in for a
#      key the config doesn't set.
#   2. Docs contract. The directories and living docs, the ADR template at the
#      location ADDW_ADR_TEMPLATE names — the shipped one under
#      `.claude/skills/lib/templates/` by default, a project's own when it
#      declares one, and never a path derived from ADDW_ADR_DIR or hardcoded
#      here — and the project-instructions line that declares *that same path*
#      authoritative over any skill-bundled ADR format. An absent key and a
#      missing file are different faults and read differently.
#   2b. The migrated state (#13). The generation marker must match the skills,
#      and the retired artifacts must be gone — but only the ones ADDW's
#      migration actually mandates removing. The backlog file is one: its
#      entries move to backlog-labeled issues and then it goes, so a surviving
#      file means either the migration never ran or open ideas are stranded in
#      a file no skill reads. The plans directory is not: it is transient, its
#      deletion is documented as safe and expected but stays the human's call,
#      and ADDW never removes it — so doctor must stay silent about one.
#   3. Tracker validation. Matt's setup must have run, its configured tracker
#      must be GitHub, the tracker CLI must be authenticated with issues
#      enabled, and the three labels the frontier keys on must exist. A missing
#      frontier label would otherwise fail silently as a forever-empty frontier.
# Deliberately absent: any check that Matt's skills are installed. Nothing
# there is load-bearing — the review ADDW cannot proceed without is its
# cross-model loop, whose adapter this file does check, while Matt's
# code-review is a pre-filter addw-implement already permits skipping. init
# takes an inventory of them in prose and reports it, so there is no gate here
# for a script to freeze.
#
# Everything runs offline: the fixture project is a real git repo in a temp dir
# and the tracker CLI is a stub on PATH. No test reaches into doctor's
# internals.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./lib.sh

REPO="$(cd .. && pwd)"
DOCTOR="$REPO/skills/addw-init/scripts/doctor.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Where the wholesale skills copy puts the ADR template in an install, and the
# default addw-init writes into the config. Deliberately outside the fixture's
# ADDW_ADR_DIR, so a doctor that still derived the path from the ADR directory
# fails every case below instead of passing by coincidence.
SHIPPED_TEMPLATE=".claude/skills/lib/templates/adr.md"

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

PATH="$work/bin:$PATH"
export PATH

# --- the healthy project ---------------------------------------------------
BASE="$work/base"
mkdir -p "$BASE/project" "$BASE/home"

(
  cd "$BASE/project"
  mkdir -p docs/agents docs/4-unit-tests docs/7-maintenance docs/adr

  # Quoted heredoc: a config is exactly where a recipe carrying `$` or a
  # backtick belongs, and an expanding one would corrupt it silently. The one
  # interpolated value is appended instead.
  cat > docs/addw.env <<'ENV'
ADDW_SCHEMA=5
ADDW_PROJECT_NAME="fixture"
ADDW_VERSION_FILE="package.json"
ADDW_MAIN_BRANCH="main"
ADDW_AUDIT_NUDGE_N=5
ADDW_ADR_DIR="docs/adr"
ADDW_RECIPE_LINT="true"
ADDW_RECIPE_TYPECHECK=""
ADDW_RECIPE_TESTS_AFFECTED="true"
ENV
  printf 'ADDW_ADR_TEMPLATE="%s"\n' "$SHIPPED_TEMPLATE" >> docs/addw.env

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

  # The real shipped template, not a paraphrase of it. Copying is what makes
  # the healthy case assert that the file this repo actually ships satisfies
  # doctor's four format checks — a second hand-written copy would only ever
  # test itself, and would drift from the shipped one silently.
  mkdir -p "$(dirname "$SHIPPED_TEMPLATE")"
  cp "$REPO/skills/lib/templates/adr.md" "$SHIPPED_TEMPLATE"

  printf '# Project\n\n## ADR format\n\n`%s` is the authoritative ADR format.\n' \
    "$SHIPPED_TEMPLATE" > CLAUDE.md

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
# The template ships with the skills and is found there. A doctor still
# deriving the path from ADDW_ADR_DIR would name docs/adr/template.md — a file
# this fixture deliberately does not have.
assert_contains "$RUN_OUT" "$SHIPPED_TEMPLATE" \
  "healthy: the template checks name the configured shipped path"
assert_not_contains "$RUN_OUT" "docs/adr/template.md" \
  "healthy: no template path is derived from ADDW_ADR_DIR"

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

# ADDW_VERSION_FILE is empty-legal for the same reason a recipe is: a project
# with no native version manifest (Go, C, plain shell) has no file to name, and
# addw-release Step 2 already skips the version write when the value is empty.
# Requiring a value here made those projects invent a file whose only purpose
# was passing this check, and made doctor's own existence check below dead code
# — it could never be reached with an empty value (#74).
d="$(case_dir emptyversion)"
sed -i 's|^ADDW_VERSION_FILE=.*|ADDW_VERSION_FILE=""|' "$d/project/docs/addw.env"
run "$d"
assert_eq 0 "$RUN_STATUS" "version: an empty ADDW_VERSION_FILE is healthy"
assert_contains "$RUN_OUT" "ADDW_VERSION_FILE defined (empty: deliberate skip)" \
  "version: an empty value reads as a considered skip, not a silent pass"
assert_contains "$RUN_OUT" "HEALTHY: all checks passed" \
  "version: no version manifest does not make an install unhealthy"

# Presence is what separates a considered skip from an omission, so the key
# itself still has to be there. Without this the fix above would be indistinguishable
# from dropping the check entirely.
d="$(case_dir noversionkey)"
grep -v '^ADDW_VERSION_FILE=' "$d/project/docs/addw.env" \
  > "$d/project/docs/addw.env.new"
mv "$d/project/docs/addw.env.new" "$d/project/docs/addw.env"
run "$d"
assert_eq 1 "$RUN_STATUS" "version: an absent ADDW_VERSION_FILE is unhealthy"
assert_contains "$RUN_OUT" "ADDW_VERSION_FILE absent from docs/addw.env" \
  "version: the failing line distinguishes an omission from an empty value"

# The existence check the empty case makes reachable. A named file that isn't
# there is still a fault — releases would write a version into nothing.
d="$(case_dir missingversionfile)"
sed -i 's|^ADDW_VERSION_FILE=.*|ADDW_VERSION_FILE="Cargo.toml"|' "$d/project/docs/addw.env"
run "$d"
assert_eq 1 "$RUN_STATUS" "version: a named-but-missing version file is unhealthy"
assert_contains "$RUN_OUT" "version file Cargo.toml missing" \
  "version: the failing line names the file the config points at"

d="$(case_dir noconfig)"
rm "$d/project/docs/addw.env"
run "$d"
assert_eq 1 "$RUN_STATUS" "config: a missing docs/addw.env is unhealthy"
assert_contains "$RUN_OUT" "docs/addw.env" \
  "config: the failing line names the config file"

# --- the generation marker and the migrated state (#13) --------------------

# The marker is the whole point of the schema: an install left at the previous
# generation must be told to apply the upgrade doc, not quietly accepted.
d="$(case_dir oldschema)"
sed -i 's|^ADDW_SCHEMA=.*|ADDW_SCHEMA=4|' "$d/project/docs/addw.env"
run "$d"
assert_eq 1 "$RUN_STATUS" "schema: an install left at the previous generation is unhealthy"
assert_contains "$RUN_OUT" "UPGRADING.md" \
  "schema: the failing line sends the human to the upgrade doc"

# The backlog file's removal is the one deletion the migration mandates, and it
# is ordered: every open entry becomes a backlog-labeled issue first. A
# surviving file therefore means work is stranded somewhere no skill reads.
d="$(case_dir backlogfile)"
printf '# Backlog\n\n- an idea nobody migrated\n' > "$d/project/docs/backlog.md"
run "$d"
assert_eq 1 "$RUN_STATUS" "backlog: a surviving backlog file is unhealthy"
assert_contains "$RUN_OUT" "FAIL: docs/backlog.md" \
  "backlog: the failing line names the retired file"
assert_contains "$RUN_OUT" "backlog-labeled" \
  "backlog: the failing line points at the label the entries migrate to"

# The plan-review role retired with the skill that filled it. Left in a config,
# it names a folder the wholesale skills copy no longer ships, so the generic
# adapter check would report it as a missing adapter — sending the human to
# reinstall a skill that no longer exists instead of to delete a dead key.
d="$(case_dir retiredrole)"
printf 'ADDW_PLAN_REVIEW_SKILL=codex-plan-review\n' >> "$d/project/docs/addw.env"
run "$d"
assert_eq 1 "$RUN_STATUS" "role: a retired role key left in the config is unhealthy"
assert_contains "$RUN_OUT" "FAIL: ADDW_PLAN_REVIEW_SKILL" \
  "role: the failing line names the retired key"
assert_contains "$RUN_OUT" "ADDW_PLAN_REVIEW_SKILL is retired" \
  "role: the failing line says the key is retired, not that an adapter is missing"

# The plans directory is the opposite case: transient, safe to delete, but the
# human's call and never ADDW's. An install that kept it is fully migrated.
d="$(case_dir plansdir)"
mkdir -p "$d/project/docs/1-plans"
printf '# F_1.0.0 old plan\n' > "$d/project/docs/1-plans/F_1.0.0_thing.plan.md"
run "$d"
assert_eq 0 "$RUN_STATUS" "plans: a surviving plans directory is still healthy"
assert_not_contains "$RUN_OUT" "1-plans" \
  "plans: doctor says nothing about a directory whose deletion is the human's call"

# --- docs contract ---------------------------------------------------------

# The key and the file are different faults. An install that never added the
# key on upgrade has nothing to check; one whose template is gone has a path
# that resolved and came up empty. Telling a human to add a config line and
# telling them to restore a file are different instructions, so the two lines
# must not read alike.
d="$(case_dir notemplatekey)"
grep -v '^ADDW_ADR_TEMPLATE=' "$d/project/docs/addw.env" \
  > "$d/project/docs/addw.env.new"
mv "$d/project/docs/addw.env.new" "$d/project/docs/addw.env"
run "$d"
assert_eq 1 "$RUN_STATUS" "adr: an absent ADDW_ADR_TEMPLATE is unhealthy"
assert_contains "$RUN_OUT" "ADDW_ADR_TEMPLATE unset in docs/addw.env" \
  "adr: the failing line names the absent key"
assert_contains "$RUN_OUT" "ADDW_ADR_TEMPLATE is unset" \
  "adr: the template checks say why they could not run"
assert_not_contains "$RUN_OUT" "$SHIPPED_TEMPLATE missing" \
  "adr: an absent key does not masquerade as a missing file"

d="$(case_dir noadr)"
rm "$d/project/$SHIPPED_TEMPLATE"
run "$d"
assert_eq 1 "$RUN_STATUS" "adr: a missing ADR template is unhealthy"
assert_contains "$RUN_OUT" "$SHIPPED_TEMPLATE" \
  "adr: the failing line names the template path"
assert_not_contains "$RUN_OUT" "ADDW_ADR_TEMPLATE is unset" \
  "adr: a missing file does not masquerade as an absent key"

d="$(case_dir badadr)"
grep -v '^- \*\*Origin\*\*' "$d/project/$SHIPPED_TEMPLATE" \
  > "$d/project/$SHIPPED_TEMPLATE.new"
mv "$d/project/$SHIPPED_TEMPLATE.new" "$d/project/$SHIPPED_TEMPLATE"
run "$d"
assert_eq 1 "$RUN_STATUS" \
  "adr: a template without the mandatory Origin field is unhealthy"
assert_contains "$RUN_OUT" "Origin" "adr: the failing line names the field"

# added at codex round 1: the field being present is not the check — a
# skill-bundled template offering proposed/accepted/deprecated has a Status
# line too, and an install still carrying one is exactly what doctor is for.
d="$(case_dir wrongstatus)"
sed -i 's|^- \*\*Status\*\*.*|- **Status**: proposed / accepted / deprecated|' \
  "$d/project/$SHIPPED_TEMPLATE"
run "$d"
assert_eq 1 "$RUN_STATUS" \
  "adr: a template offering the wrong Status states is unhealthy"
assert_contains "$RUN_OUT" "Status" "adr: the failing line names the field"

# added at codex round 2: two states means two, so a third smuggled in beside
# the right pair must not pass on the strength of the pair being there.
d="$(case_dir threestatus)"
sed -i 's|^- \*\*Status\*\*.*|- **Status**: proposed \| active \| superseded by ADR-NNNN|' \
  "$d/project/$SHIPPED_TEMPLATE"
run "$d"
assert_eq 1 "$RUN_STATUS" "adr: a third Status state is unhealthy"

# added at codex round 1: the Gate section is where an author of a guardrail
# ADR learns it is required, so a template without one is a broken surface.
d="$(case_dir nogate)"
grep -v '^## Gate' "$d/project/$SHIPPED_TEMPLATE" \
  > "$d/project/$SHIPPED_TEMPLATE.new"
mv "$d/project/$SHIPPED_TEMPLATE.new" "$d/project/$SHIPPED_TEMPLATE"
run "$d"
assert_eq 1 "$RUN_STATUS" "adr: a template without a Gate section is unhealthy"
assert_contains "$RUN_OUT" "Gate" "adr: the failing line names the section"

# added at codex round 1: the declaration is the path and the word together.
# A file that merely mentions the template is not declaring anything.
d="$(case_dir passingmention)"
printf '# Project\n\nADRs use the template at `%s`.\n' "$SHIPPED_TEMPLATE" \
  > "$d/project/CLAUDE.md"
run "$d"
assert_eq 1 "$RUN_STATUS" \
  "override: a passing mention of the template is not a declaration"

d="$(case_dir nooverride)"
printf '# Project\n' > "$d/project/CLAUDE.md"
run "$d"
assert_eq 1 "$RUN_STATUS" \
  "override: project instructions that don't declare the template are unhealthy"
assert_contains "$RUN_OUT" "$SHIPPED_TEMPLATE" \
  "override: the failing line names the template the instructions must declare"

# The declaration and the key must agree. A declaration naming some other
# template is the install customizing one file and pointing the workflow at
# another — the authoring path and the checked path diverge, silently, which
# is the exact failure the declaration exists to prevent.
d="$(case_dir declmismatch)"
(
  cd "$d/project"
  printf '# Project\n\n`docs/adr/template.md` is the authoritative ADR format.\n' \
    > CLAUDE.md
  printf '# ADR NNNN\n' > docs/adr/template.md
) >/dev/null
run "$d"
assert_eq 1 "$RUN_STATUS" \
  "override: a declaration naming a different template than the key is unhealthy"
assert_contains "$RUN_OUT" "$SHIPPED_TEMPLATE" \
  "override: the failing line names the configured template, not the declared one"

# added at the cold pre-filter: the near-miss the relocation creates. An
# install naming `skills/lib/templates/adr.md` in its config and
# `.claude/skills/lib/templates/adr.md` in its instructions has declared a
# different file, and a substring match would call that agreement.
d="$(case_dir suffixmatch)"
(
  cd "$d/project"
  sed -i "s|^ADDW_ADR_TEMPLATE=.*|ADDW_ADR_TEMPLATE=\"skills/lib/templates/adr.md\"|" \
    docs/addw.env
  mkdir -p skills/lib/templates
  cp "$SHIPPED_TEMPLATE" skills/lib/templates/adr.md
) >/dev/null
run "$d"
assert_eq 1 "$RUN_STATUS" \
  "override: a declaration whose path merely ends in the configured one is unhealthy"

# added at codex round 1: the near-miss runs the other way too. A declaration
# naming `<template>.backup` contains the configured path as a prefix and is
# still a different file, so the match must be flanked on both sides.
d="$(case_dir extendedpath)"
(
  cd "$d/project"
  cp "$SHIPPED_TEMPLATE" "$SHIPPED_TEMPLATE.backup"
  printf '# Project\n\n`%s.backup` is the authoritative ADR format.\n' \
    "$SHIPPED_TEMPLATE" > CLAUDE.md
) >/dev/null
run "$d"
assert_eq 1 "$RUN_STATUS" \
  "override: a declaration naming a longer path starting with the configured one is unhealthy"

# added at codex round 2: `.` is not the only character a filename may continue
# with, so a `+` must extend the path too. Round 3 settled how: the declaration
# names its path in a Markdown code span, which turns the whole question into a
# substring test and needs no theory of which characters a filename may hold.
d="$(case_dir extendedpathplus)"
(
  cd "$d/project"
  cp "$SHIPPED_TEMPLATE" "$SHIPPED_TEMPLATE+old"
  printf '# Project\n\n`%s+old` is the authoritative ADR format.\n' \
    "$SHIPPED_TEMPLATE" > CLAUDE.md
) >/dev/null
run "$d"
assert_eq 1 "$RUN_STATUS" \
  "override: a longer path continuing with a non-dot filename character is unhealthy"

# The code span is required, not merely accepted. A bare path is what makes the
# check approximate, and an install that writes one is told so rather than
# passed on a match that could have been some other file's name.
d="$(case_dir barepath)"
printf '# Project\n\n%s is the authoritative ADR format.\n' "$SHIPPED_TEMPLATE" \
  > "$d/project/CLAUDE.md"
run "$d"
assert_eq 1 "$RUN_STATUS" \
  "override: a declaration that does not put the path in backticks is unhealthy"
assert_contains "$RUN_OUT" "backticks" \
  "override: the failing line says what form the declaration must take"

# The other side of that line: the declaration must be found wherever it sits on
# its line. A check this tight is worthless if it fails the installs that got it
# right.
for decl in '`%s` is the authoritative ADR format.' \
  'The authoritative ADR format is `%s`' \
  '- **ADR format**: `%s` (authoritative)'; do
  d="$(case_dir okdecl)"
  # shellcheck disable=SC2059
  printf "# Project\n\n$decl\n" "$SHIPPED_TEMPLATE" > "$d/project/CLAUDE.md"
  run "$d"
  assert_eq 0 "$RUN_STATUS" \
    "override: a backticked declaration is recognised — $decl"
done

# The key is the customization seam: an install keeping its own template says
# so in the config and stays healthy — and its format is still verified, which
# is what makes the seam an override rather than an escape hatch.
d="$(case_dir owntemplate)"
(
  cd "$d/project"
  git mv "$SHIPPED_TEMPLATE" docs/adr/template.md
  sed -i "s|^ADDW_ADR_TEMPLATE=.*|ADDW_ADR_TEMPLATE=\"docs/adr/template.md\"|" \
    docs/addw.env
  printf '# Project\n\n`docs/adr/template.md` is the authoritative ADR format.\n' \
    > CLAUDE.md
) >/dev/null
run "$d"
assert_eq 0 "$RUN_STATUS" \
  "adr: a project declaring its own template is healthy"
assert_contains "$RUN_OUT" "HEALTHY" "adr: the template path is not hardcoded"

sed -i 's|^- \*\*Status\*\*.*|- **Status**: proposed / accepted / deprecated|' \
  "$d/project/docs/adr/template.md"
run "$d"
assert_eq 1 "$RUN_STATUS" \
  "adr: a project's own template has its format verified too"

# The ADR *directory* is a separate contract — the numbering script's, and the
# living-docs check's. Moving it must not disturb a template that lives with
# the skills.
d="$(case_dir altadr)"
(
  cd "$d/project"
  mkdir -p docs/decisions
  touch docs/decisions/.gitkeep
  rmdir docs/adr
  sed -i 's|^ADDW_ADR_DIR=.*|ADDW_ADR_DIR="docs/decisions"|' docs/addw.env
) >/dev/null
run "$d"
assert_eq 0 "$RUN_STATUS" \
  "adr-dir: an ADR location other than docs/adr/ is healthy"
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

echo "doctor: all contract assertions passed"

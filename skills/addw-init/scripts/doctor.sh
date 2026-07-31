#!/usr/bin/env bash
# Install doctor: deterministically verify an ADDW install's integrity.
# Run it after init, after replacing the skills folder in an upgrade, or
# whenever the workflow misbehaves. Read-only — it never fixes anything.
#
# Usage: doctor.sh               (run from the repo root)
# Prints one OK/FAIL line per check; exit 0 = HEALTHY, 1 = problems found.

# Deliberately no `set -e`: a doctor must keep going past failing checks.
set -uo pipefail

# The schema generation THESE skills expect. Structural upgrade steps in
# UPGRADING.md end by bumping the install's ADDW_SCHEMA to match this.
EXPECTED_SCHEMA=3

fail=0
ok()  { echo "OK:   $1"; }
bad() { echo "FAIL: $1"; fail=1; }

# --- config file ---
if [ ! -f docs/addw.env ]; then
    bad "docs/addw.env missing (generation-2 install? see UPGRADING.md)"
    echo "UNHEALTHY: fix the FAIL lines above"
    exit 1
fi
if bash -n docs/addw.env 2>/dev/null; then
    ok "docs/addw.env parses"
else
    bad "docs/addw.env is not shell-sourceable"
    echo "UNHEALTHY: fix the FAIL lines above"
    exit 1
fi
source docs/addw.env

for key in ADDW_SCHEMA ADDW_PROJECT_NAME ADDW_VERSION_FILE ADDW_MAIN_BRANCH ADDW_AUDIT_NUDGE_N ADDW_TUTORIALS; do
    if [ -n "${!key:-}" ]; then
        ok "$key set"
    else
        bad "$key unset in docs/addw.env"
    fi
done

if [ "${ADDW_SCHEMA:-}" = "$EXPECTED_SCHEMA" ]; then
    ok "ADDW_SCHEMA=$ADDW_SCHEMA matches the installed skills"
else
    bad "ADDW_SCHEMA=${ADDW_SCHEMA:-unset} but the installed skills expect $EXPECTED_SCHEMA — apply UPGRADING.md"
fi

# --- docs contract ---
for d in docs/1-plans docs/4-unit-tests docs/6-memo docs/7-maintenance docs/adr; do
    if [ -d "$d" ]; then ok "$d/ exists"; else bad "$d/ missing"; fi
done
for f in docs/ARCHITECTURE.md docs/ARCHITECTURE-rules.md docs/charter.md docs/adr/template.md docs/4-unit-tests/TESTING.md CHANGELOG.md; do
    if [ -f "$f" ]; then ok "$f exists"; else bad "$f missing"; fi
done

if [ -f docs/4-unit-tests/TESTING.md ]; then
    if grep -q "Verification Recipes" docs/4-unit-tests/TESTING.md; then
        ok "TESTING.md has a Verification Recipes section"
    else
        bad "TESTING.md lacks a Verification Recipes section"
    fi
    if grep -qi "Impact Rules" docs/4-unit-tests/TESTING.md; then
        ok "TESTING.md has Integration/E2E Impact Rules"
    else
        bad "TESTING.md lacks an Integration/E2E Impact Rules section"
    fi
fi

# --- config values point at real things ---
if [ -n "${ADDW_VERSION_FILE:-}" ]; then
    if [ -f "$ADDW_VERSION_FILE" ]; then
        ok "version file $ADDW_VERSION_FILE exists"
    else
        bad "version file $ADDW_VERSION_FILE missing"
    fi
fi
if [ -n "${ADDW_MAIN_BRANCH:-}" ]; then
    if git rev-parse -q --verify "$ADDW_MAIN_BRANCH" >/dev/null 2>&1; then
        ok "main branch '$ADDW_MAIN_BRANCH' exists"
    else
        bad "main branch '$ADDW_MAIN_BRANCH' not found in git"
    fi
fi
if [ "${ADDW_TUTORIALS:-false}" = "true" ]; then
    if [ -d docs/5-tuto ]; then
        ok "docs/5-tuto/ exists (tutorials on)"
    else
        bad "ADDW_TUTORIALS=true but docs/5-tuto/ missing"
    fi
fi

# --- role adapters (checked only when overridden in addw.env) ---
for key in ADDW_PLAN_REVIEW_SKILL ADDW_IMPLEMENT_SKILL ADDW_CODE_REVIEW_SKILL ADDW_ASK_SKILL; do
    val="${!key:-}"
    [ -z "$val" ] && continue
    if [ -f ".claude/skills/$val/scripts/start.sh" ] && [ -f ".claude/skills/$val/scripts/resume.sh" ]; then
        ok "$key=$val adapter scripts present"
    else
        bad "$key=$val but .claude/skills/$val/scripts/{start,resume}.sh missing"
    fi
done

if [ "$fail" -eq 0 ]; then
    echo "HEALTHY: all checks passed"
else
    echo "UNHEALTHY: fix the FAIL lines above"
fi
exit "$fail"

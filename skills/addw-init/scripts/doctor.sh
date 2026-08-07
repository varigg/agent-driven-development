#!/usr/bin/env bash
# Install doctor: deterministically verify an ADDW install's integrity.
# Run it after init, after replacing the skills folder in an upgrade, or
# whenever the workflow misbehaves. Read-only — it never fixes anything.
#
# Deliberately no set -e: a doctor keeps checking after a failure so the
# human gets one actionable line for every part of the contract.
set -uo pipefail

EXPECTED_SCHEMA=3
doctor_fail=0
doctor_warnings=0

ok() { printf 'OK:   %s\n' "$1"; }
bad() {
    printf 'FAIL: %s\n' "$1"
    doctor_fail=1
}
warn() {
    printf 'WARN: %s\n' "$1"
    doctor_warnings=$((doctor_warnings + 1))
}

# Config values come from docs/addw.env alone. In particular, an exported
# recipe must not make an absent recipe key look defined.
unset ADDW_SCHEMA ADDW_PROJECT_NAME ADDW_VERSION_FILE ADDW_MAIN_BRANCH \
    ADDW_AUDIT_NUDGE_N ADDW_ADR_DIR ADDW_RECIPE_LINT \
    ADDW_RECIPE_TYPECHECK ADDW_RECIPE_TESTS_AFFECTED \
    ADDW_PLAN_REVIEW_SKILL ADDW_IMPLEMENT_SKILL ADDW_CODE_REVIEW_SKILL \
    ADDW_ASK_SKILL

# The config decides where half the later checks look, so an unusable one is
# the only failure that stops the run: continuing would bury one actionable
# line under a cascade of consequences.
if [ ! -f docs/addw.env ]; then
    bad "docs/addw.env missing (generation-2 install? see UPGRADING.md)"
    echo "UNHEALTHY: fix the FAIL lines above"
    exit 1
fi
if ! bash -n docs/addw.env 2>/dev/null; then
    bad "docs/addw.env is not shell-sourceable"
    echo "UNHEALTHY: fix the FAIL lines above"
    exit 1
fi
ok "docs/addw.env parses"
# shellcheck disable=SC1091
. docs/addw.env

required_keys=(
    ADDW_SCHEMA
    ADDW_PROJECT_NAME
    ADDW_VERSION_FILE
    ADDW_MAIN_BRANCH
    ADDW_AUDIT_NUDGE_N
    ADDW_ADR_DIR
)
for key in "${required_keys[@]}"; do
    if [ -n "${!key:-}" ]; then
        ok "$key set"
    else
        bad "$key unset in docs/addw.env"
    fi
done

recipe_keys=(ADDW_RECIPE_LINT ADDW_RECIPE_TYPECHECK ADDW_RECIPE_TESTS_AFFECTED)
for key in "${recipe_keys[@]}"; do
    if declare -p "$key" >/dev/null 2>&1; then
        if [ -n "${!key}" ]; then
            ok "$key defined"
        else
            ok "$key defined (empty: deliberate skip)"
        fi
    else
        bad "$key absent from docs/addw.env"
    fi
done

if [ "${ADDW_SCHEMA:-}" = "$EXPECTED_SCHEMA" ]; then
    ok "ADDW_SCHEMA=$ADDW_SCHEMA matches the installed skills"
else
    bad "ADDW_SCHEMA=${ADDW_SCHEMA:-unset} but the installed skills expect $EXPECTED_SCHEMA — apply UPGRADING.md"
fi

# --- docs contract ---------------------------------------------------------
docs_dirs=(docs/4-unit-tests docs/6-memo docs/7-maintenance)
if [ -n "${ADDW_ADR_DIR:-}" ]; then
    docs_dirs+=("$ADDW_ADR_DIR")
fi
for directory in "${docs_dirs[@]}"; do
    if [ -d "$directory" ]; then
        ok "$directory/ exists"
    else
        bad "$directory/ missing"
    fi
done

doc_files=(
    docs/ARCHITECTURE.md
    docs/ARCHITECTURE-rules.md
    docs/charter.md
    docs/4-unit-tests/TESTING.md
    CHANGELOG.md
)
for file in "${doc_files[@]}"; do
    if [ -f "$file" ]; then
        ok "$file exists"
    else
        bad "$file missing"
    fi
done

adr_template=""
if [ -n "${ADDW_ADR_DIR:-}" ]; then
    adr_template="$ADDW_ADR_DIR/template.md"
    if [ -f "$adr_template" ]; then
        ok "$adr_template exists"
        for field in Status Date Origin; do
            if grep -Eq "^[[:space:]-]*\\*\\*$field\\*\\*[[:space:]]*:" "$adr_template"; then
                ok "$adr_template has mandatory $field field"
            else
                bad "$adr_template lacks mandatory $field field"
            fi
        done
    else
        bad "$adr_template missing"
    fi
else
    bad "ADDW_ADR_DIR is unset, so neither the ADR template nor the project-instructions override could be checked"
fi

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

if [ -n "$adr_template" ]; then
    instructions_override=0
    for instructions in CLAUDE.md AGENTS.md; do
        if [ -f "$instructions" ] && grep -Fq -- "$adr_template" "$instructions"; then
            instructions_override=1
        fi
    done
    if [ "$instructions_override" -eq 1 ]; then
        ok "project instructions declare $adr_template authoritative"
    else
        bad "CLAUDE.md or AGENTS.md must declare $adr_template authoritative"
    fi
fi

# --- config values point at real things -----------------------------------
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

# --- role adapters (checked only when overridden in addw.env) -------------
for key in ADDW_PLAN_REVIEW_SKILL ADDW_IMPLEMENT_SKILL ADDW_CODE_REVIEW_SKILL ADDW_ASK_SKILL; do
    value="${!key:-}"
    [ -z "$value" ] && continue
    if [ -f ".claude/skills/$value/scripts/start.sh" ] &&
        [ -f ".claude/skills/$value/scripts/resume.sh" ]; then
        ok "$key=$value adapter scripts present"
    else
        bad "$key=$value but .claude/skills/$value/scripts/{start,resume}.sh missing"
    fi
done

# --- Matt's setup, and the tracker it configured --------------------------
# These files are the setup skill's output, not ADDW's: their absence means
# the setup never ran, which is a different fix from a missing living doc.
setup_ran=1
for f in docs/agents/issue-tracker.md docs/agents/domain.md; do
    if [ -f "$f" ]; then
        ok "$f exists"
    else
        bad "$f missing — run the setup-matt-pocock-skills skill"
        setup_ran=0
    fi
done

if [ "$setup_ran" -eq 1 ]; then
    # The heading Matt's seed template writes. A repo that reworded it reads
    # as unconfirmed rather than as GitHub — the overlay is GitHub-only, and
    # guessing here would strand the tracker layer at the first live call.
    tracker_heading="$(grep -m1 -E '^# Issue tracker:' docs/agents/issue-tracker.md || true)"
    case "$tracker_heading" in
        '# Issue tracker: GitHub'*) ok "the configured tracker is GitHub" ;;
        '')
            bad "docs/agents/issue-tracker.md has no '# Issue tracker: <name>' heading — cannot confirm GitHub, which ADDW's overlay requires" ;;
        *)
            bad "configured tracker is '${tracker_heading#\# Issue tracker: }' — ADDW's overlay is GitHub-only" ;;
    esac
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tracker="$here/../../lib/tracker/tracker.sh"
if [ -f "$tracker" ]; then
    if bash "$tracker" auth >/dev/null 2>&1; then
        ok "tracker CLI is authenticated"
    else
        bad "tracker CLI is not authenticated"
    fi
    if bash "$tracker" issues-enabled >/dev/null 2>&1; then
        ok "repository issues are enabled"
    else
        bad "repository issues are disabled or unavailable"
    fi

    labels=""
    labels_status=0
    labels="$(bash "$tracker" labels 2>/dev/null)" || labels_status=$?
    if [ "$labels_status" -ne 0 ]; then
        bad "tracker labels could not be read"
    else
        for required_label in ready-for-agent spec backlog; do
            if printf '%s\n' "$labels" | grep -Fqx -- "$required_label"; then
                ok "tracker label $required_label exists"
            else
                bad "tracker label $required_label missing"
            fi
        done
    fi
else
    bad "tracker layer missing: $tracker"
fi

# --- graded plugin probes -------------------------------------------------
# A skill is installed when some directory named after it holds a SKILL.md.
# One find pass covers every root — the plugin cache (which nests skills
# several levels down, under a vendor, pack, version, and category), the
# global skills folder, and the project-local one — because the probe asks
# the same question eight times and walking the tree eight times to answer it
# would be the slow way to get the same set.
claude_config_dir="${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}"
find_roots=()
for root in "$claude_config_dir/plugins" "$claude_config_dir/skills" ./.claude/skills; do
    [ -d "$root" ] && find_roots+=("$root")
done

installed_skills=""
if [ "${#find_roots[@]}" -gt 0 ]; then
    installed_skills="$(
        find "${find_roots[@]}" \
            \( -type d \( -name node_modules -o -name .git \) -prune \) \
            -o \( -type f -name SKILL.md -print \) 2>/dev/null |
            sed -e 's|/SKILL\.md$||' -e 's|.*/||' |
            sort -u
    )"
fi

skill_present() {
    printf '%s\n' "$installed_skills" | grep -Fqx -- "$1"
}

# The programmatic pair: ADDW invokes these itself, so absence is fatal.
for required_skill in code-review tdd; do
    if skill_present "$required_skill"; then
        ok "plugin skill '$required_skill' present"
    else
        bad "plugin skill '$required_skill' missing — ADDW invokes it programmatically"
    fi
done
# The happy path: the flow needs these, ADDW never calls them, so the install
# is sound without them and the human decides whether to install them.
for optional_skill in setup-matt-pocock-skills grill-with-docs grilling \
    domain-modeling to-spec to-tickets; do
    if skill_present "$optional_skill"; then
        ok "plugin skill '$optional_skill' present"
    else
        warn "plugin skill '$optional_skill' missing — the flow needs it, though ADDW never invokes it"
    fi
done

if [ "$doctor_fail" -eq 0 ]; then
    if [ "$doctor_warnings" -eq 0 ]; then
        echo "HEALTHY: all checks passed"
    elif [ "$doctor_warnings" -eq 1 ]; then
        echo "HEALTHY: all checks passed (1 warning)"
    else
        echo "HEALTHY: all checks passed ($doctor_warnings warnings)"
    fi
else
    echo "UNHEALTHY: fix the FAIL lines above"
fi
exit "$doctor_fail"

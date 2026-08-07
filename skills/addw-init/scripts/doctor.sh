#!/usr/bin/env bash
# Install doctor: deterministically verify an ADDW install's integrity.
# Run it after init, after replacing the skills folder in an upgrade, or
# whenever the workflow misbehaves. Read-only — it never fixes anything.
#
# Deliberately no set -e: a doctor keeps checking after a failure so the
# human gets one actionable line for every part of the contract.
#
# Deliberately NOT checked here: whether the skills ADDW depends on are
# installed. The authority on that is the agent's own skill roster, which
# carries the plugin qualifier a filesystem scan cannot see — two plugins can
# ship a `code-review`, and only the roster distinguishes them. A scan would
# also have to tell an install from a marketplace clone, from cache residue,
# and from an installed-but-disabled plugin, and would still be answering a
# question one look at the roster answers exactly. So the skills that need a
# dependency check do it in prose, at the point of use: addw-init before it
# writes anything, addw-implement before it invokes one.
set -uo pipefail

# The schema generation THESE skills expect. Structural upgrade steps in
# UPGRADING.md end by bumping the install's ADDW_SCHEMA to match.
#
# The docs contract this file checks has already moved past generation 3 —
# ADDW_ADR_DIR and the recipe keys are required, ADDW_TUTORIALS is gone — but
# the bump and its migration section belong to one ticket, so until that lands
# a generation-3 install reads as schema-matched while failing the newer
# checks. The FAIL lines say what to add; the schema line does not yet.
EXPECTED_SCHEMA=3
doctor_fail=0

ok() { printf 'OK:   %s\n' "$1"; }
bad() {
    printf 'FAIL: %s\n' "$1"
    doctor_fail=1
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
        # Presence is not enough for Status: a skill-bundled template offering
        # proposed/accepted/deprecated also has the field, and telling the two
        # apart is the whole point of checking an install's template.
        if grep -Eq "^[[:space:]-]*\\*\\*Status\\*\\*[[:space:]]*:[[:space:]]*active[[:space:]]*\\|[[:space:]]*superseded by ADR-NNNN[[:space:]]*$" "$adr_template"; then
            ok "$adr_template offers the two Status states"
        else
            bad "$adr_template's Status must read exactly 'active | superseded by ADR-NNNN' — two states, no third"
        fi
        if grep -Eq "^#+[[:space:]]+Gate" "$adr_template"; then
            ok "$adr_template carries the Gate section"
        else
            bad "$adr_template lacks a Gate section — guardrail ADRs require one, and the template is where an author sees it"
        fi
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
    # The path and the word together, on one line: a template mentioned in
    # passing elsewhere in the instructions is not a declaration, and matching
    # the path alone would accept one.
    instructions_override=0
    for instructions in CLAUDE.md AGENTS.md; do
        if [ -f "$instructions" ] &&
            grep -F -- "$adr_template" "$instructions" | grep -qi authoritative; then
            instructions_override=1
        fi
    done
    if [ "$instructions_override" -eq 1 ]; then
        ok "project instructions declare $adr_template authoritative"
    else
        bad "CLAUDE.md or AGENTS.md must carry one line naming $adr_template and calling it authoritative"
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
    # The value must be a *bare* branch name. Consumers check it out, pass it
    # to `gh pr create --base`, and derive `origin/$ADDW_MAIN_BRANCH` — so a
    # remote-qualified "origin/main" resolves perfectly well here while
    # becoming "origin/origin/main" there. Checking that the ref exists would
    # not catch that; checking its shape does. Branch names may legitimately
    # contain slashes (release/2.x), so only a real remote's name disqualifies
    # a first segment.
    remote_prefixed=0
    while IFS= read -r remote; do
        [ -n "$remote" ] || continue
        case "$ADDW_MAIN_BRANCH" in "$remote"/*) remote_prefixed=1 ;; esac
    done < <(
        git remote 2>/dev/null
        printf 'origin\n'
    )
    if [ "$remote_prefixed" -eq 1 ]; then
        bad "ADDW_MAIN_BRANCH='$ADDW_MAIN_BRANCH' is remote-qualified — it must be a bare branch name"
    elif git rev-parse -q --verify "refs/heads/$ADDW_MAIN_BRANCH" >/dev/null 2>&1; then
        ok "main branch '$ADDW_MAIN_BRANCH' exists"
    elif git rev-parse -q --verify "refs/remotes/origin/$ADDW_MAIN_BRANCH" >/dev/null 2>&1; then
        ok "main branch '$ADDW_MAIN_BRANCH' exists on origin (no local branch yet)"
    else
        bad "main branch '$ADDW_MAIN_BRANCH' not found in git"
    fi
fi

# --- role adapters (checked only when overridden in addw.env) -------------
for key in ADDW_PLAN_REVIEW_SKILL ADDW_IMPLEMENT_SKILL ADDW_CODE_REVIEW_SKILL ADDW_ASK_SKILL; do
    value="${!key:-}"
    [ -z "$value" ] && continue
    # `inline` is the reserved non-adapter value: the main agent drives `tdd`
    # itself, so there is no skill folder to find.
    if [ "$key" = ADDW_IMPLEMENT_SKILL ] && [ "$value" = inline ]; then
        ok "$key=inline (no adapter — the main agent implements)"
        continue
    fi
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

if [ "$doctor_fail" -eq 0 ]; then
    echo "HEALTHY: all checks passed"
else
    echo "UNHEALTHY: fix the FAIL lines above"
fi
exit "$doctor_fail"

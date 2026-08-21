#!/usr/bin/env bash
# Install doctor: deterministically verify an ADDW install's integrity.
# Run it after init, after replacing the skills folder in an upgrade, or
# whenever the workflow misbehaves. Read-only — it never fixes anything.
#
# Deliberately no set -e: a doctor keeps checking after a failure so the
# human gets one actionable line for every part of the contract.
#
# Deliberately NOT checked here: which of Matt Pocock's skills are installed.
# Two reasons, and the second is the load-bearing one. A filesystem scan
# cannot answer the question anyway — it would have to tell an install from a
# marketplace clone, from cache residue, and from an installed-but-disabled
# plugin, and even then could not tell two plugins' same-named skills apart,
# which only the agent's own roster does. And there is nothing here to gate
# on: the review ADDW cannot proceed without is its cross-model loop, whose
# adapter IS checked below, while Matt's code-review is a pre-filter that
# addw-implement already permits skipping. A step the flow may skip cannot be
# a dependency that blocks an install. addw-init takes an inventory in prose
# and reports it; nothing about it is a gate.
set -uo pipefail

# The schema generation THESE skills expect. Structural upgrade steps in
# UPGRADING.md end by bumping the install's ADDW_SCHEMA to match.
EXPECTED_SCHEMA=7
doctor_fail=0

ok() { printf 'OK:   %s\n' "$1"; }
bad() {
    printf 'FAIL: %s\n' "$1"
    doctor_fail=1
}

# The config is data read through the shared parser, which answers from the
# file alone — in particular, an exported recipe cannot make an absent recipe
# key look defined, because config_source unsets every requested key first.
# shellcheck source=../../lib/config/config.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)/config/config.sh"

# The config decides where half the later checks look, so an unusable one is
# the only failure that stops the run: continuing would bury one actionable
# line under a cascade of consequences. Grammar violations become one FAIL
# line each, carrying the parser's file:line diagnostic.
config_diag="$(config_get ADDW_SCHEMA 2>&1 >/dev/null)"
config_status=$?
if [ "$config_status" -ne 0 ]; then
    case "$config_status" in
        66) bad "docs/addw.env missing (generation-2 install? see UPGRADING.md)" ;;
        77) bad "docs/addw.env exists but cannot be read" ;;
        *) while IFS= read -r diag_line; do
               [ -n "$diag_line" ] && bad "$diag_line"
           done <<< "$config_diag" ;;
    esac
    echo "UNHEALTHY: fix the FAIL lines above"
    exit 1
fi
ok "docs/addw.env parses"
config_source ADDW_SCHEMA ADDW_PROJECT_NAME ADDW_VERSION_FILE ADDW_MAIN_BRANCH \
    ADDW_AUDIT_NUDGE_N ADDW_ADR_DIR ADDW_ADR_TEMPLATE ADDW_RECIPE_LINT \
    ADDW_RECIPE_TYPECHECK ADDW_RECIPE_TESTS_AFFECTED \
    ADDW_RECIPE_LOCKFILE_SYNC ADDW_LOCKFILE \
    ADDW_PLAN_REVIEW_SKILL ADDW_ASK_SKILL \
    ADDW_IMPLEMENT_SKILL ADDW_CODE_REVIEW_SKILL

required_keys=(
    ADDW_SCHEMA
    ADDW_PROJECT_NAME
    ADDW_MAIN_BRANCH
    ADDW_AUDIT_NUDGE_N
    ADDW_ADR_DIR
    ADDW_ADR_TEMPLATE
)
for key in "${required_keys[@]}"; do
    if [ -n "${!key:-}" ]; then
        ok "$key set"
    else
        bad "$key unset in docs/addw.env"
    fi
done

# Keys that must be *present* but may legitimately be empty, where empty means
# "this project deliberately has no such thing". Checked for presence rather
# than for a value, so an accidental omission stays distinguishable from a
# considered skip — which is why the unset above the source matters: presence
# here means the key was assigned by docs/addw.env and nothing else.
#
# A recipe is empty when the project has no such step (plain bash has no
# typecheck). ADDW_VERSION_FILE is empty when the project has no native version
# manifest — Go, C, plain shell — and `addw-release` Step 2 already skips the
# version write for exactly that case. Its value, when non-empty, is checked
# against the filesystem further down.
empty_ok_keys=(ADDW_VERSION_FILE ADDW_RECIPE_LINT ADDW_RECIPE_TYPECHECK ADDW_RECIPE_TESTS_AFFECTED)
for key in "${empty_ok_keys[@]}"; do
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
docs_dirs=(docs/4-unit-tests)
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

# --- retired artifacts -----------------------------------------------------
# Only the removal the migration actually mandates is checked. The backlog
# file's is ordered — every open entry becomes a `backlog`-labeled issue, then
# the file goes — so a surviving one means either the migration never ran or
# open ideas are stranded where no skill will ever read them again.
#
# `docs/1-plans/` is deliberately NOT checked. Plans are transient, git history
# is their archive, and UPGRADING.md documents deleting the directory as safe
# and expected — but the deletion stays the human's call and ADDW never
# performs it, so a doctor that failed on one would be demanding a change the
# rest of the workflow refuses to make.
if [ -f docs/backlog.md ]; then
    bad "docs/backlog.md is retired — migrate each open entry to a backlog-labeled tracker issue, then delete the file (see UPGRADING.md)"
else
    ok "no retired docs/backlog.md"
fi

# The retired *keys*, checked here beside the retired file rather than in the
# adapter loop below, where they would sit in the list only to be branched out
# of it. ADDW_TUTORIALS retired at the same boundary and is deliberately not
# checked: a dead boolean nothing reads is inert, while a dead key naming a
# skill folder gets read as a live adapter by the loop below.
if [ -n "${ADDW_PLAN_REVIEW_SKILL:-}" ]; then
    bad "ADDW_PLAN_REVIEW_SKILL is retired — the plan-review role no longer exists; delete the key from docs/addw.env (see UPGRADING.md)"
else
    ok "no retired ADDW_PLAN_REVIEW_SKILL"
fi
if [ -n "${ADDW_ASK_SKILL:-}" ]; then
    bad "ADDW_ASK_SKILL is retired — /codex-ask is invoked by name and nothing resolves the ask role; delete the key from docs/addw.env (see UPGRADING.md)"
else
    ok "no retired ADDW_ASK_SKILL"
fi

adr_template="${ADDW_ADR_TEMPLATE:-}"
if [ -n "$adr_template" ]; then
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
    bad "ADDW_ADR_TEMPLATE is unset, so neither the ADR template nor the project-instructions override could be checked"
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
    # A declaration is one line carrying two things: the configured path in
    # backticks, and the word "authoritative". Both, on the same line — a
    # template mentioned in passing elsewhere in the file is not a declaration.
    #
    # The backticks are required, not decoration. Without them this would have
    # to find a bare path in English prose and work out where it ends, and
    # there is no reliable way to do that. Say the config reads
    # ADDW_ADR_TEMPLATE="skills/lib/templates/adr.md". A plain search for that
    # text also matches all of these, and not one of them names that file:
    #
    #     .claude/skills/lib/templates/adr.md    (an install's copy)
    #     skills/lib/templates/adr.md.backup
    #     skills/lib/templates/adr.md old        (a filename with a space?)
    #
    # Ruling those out means deciding which characters a filename may contain —
    # and that decision then starts rejecting honest declarations, such as a
    # sentence ending "...is skills/lib/templates/adr.md." where the full stop
    # looks like part of the name, because it could be.
    #
    # Backticks mark where the path ends, so none of that arises: this is a
    # plain substring search, no escaping and no guessing. The cost is one
    # format rule on a line a human writes once, and addw-init states it.
    instructions_override=0
    for instructions in CLAUDE.md AGENTS.md; do
        if [ -f "$instructions" ] &&
            grep -F -- "\`$adr_template\`" "$instructions" |
            grep -qi authoritative; then
            instructions_override=1
        fi
    done
    if [ "$instructions_override" -eq 1 ]; then
        ok "project instructions declare $adr_template authoritative"
    else
        bad "CLAUDE.md or AGENTS.md must carry one line with \`$adr_template\` in backticks and the word authoritative"
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

# The optional lockfile-sync pair (addw-release Step 3). Both keys absent is
# the common case — most projects have no lockfile embedding their own version
# — and gets no line at all. Once either key appears, the two configure one
# mechanism between them, and that mechanism is by definition a projection of
# the version write: half a pair, a named lockfile that is not there, or a
# pair beside an empty ADDW_VERSION_FILE is a contradiction, not a skip.
if [ -n "${ADDW_RECIPE_LOCKFILE_SYNC:-}" ] || [ -n "${ADDW_LOCKFILE:-}" ]; then
    if [ -z "${ADDW_LOCKFILE:-}" ]; then
        bad "ADDW_RECIPE_LOCKFILE_SYNC set without ADDW_LOCKFILE — the release cannot stage a file the config does not name"
    elif [ -z "${ADDW_RECIPE_LOCKFILE_SYNC:-}" ]; then
        bad "ADDW_LOCKFILE set without ADDW_RECIPE_LOCKFILE_SYNC — nothing would regenerate the file the release stages"
    else
        ok "lockfile-sync pair configured"
    fi
    if [ -n "${ADDW_LOCKFILE:-}" ]; then
        if [ -f "$ADDW_LOCKFILE" ]; then
            ok "lockfile $ADDW_LOCKFILE exists"
        else
            bad "lockfile $ADDW_LOCKFILE missing"
        fi
    fi
    if [ -z "${ADDW_VERSION_FILE:-}" ]; then
        bad "lockfile sync configured but ADDW_VERSION_FILE is empty — the recipe projects a version write this project skips"
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
# Live roles only. Retired role keys are handled above, so a survivor is never
# mistaken here for an adapter whose scripts went missing — or, worse, blessed
# as a live one wherever its skill folder happens to survive.
for key in ADDW_IMPLEMENT_SKILL ADDW_CODE_REVIEW_SKILL; do
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

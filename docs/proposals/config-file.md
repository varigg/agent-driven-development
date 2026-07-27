# Proposal: Replace Skill Placeholders with a Project Config File

**Status**: accepted and implemented (2026-07-27), alongside the v3 simplification set:
week numbers dropped, single-file changelog, CR archive dropped, two-state ADRs,
research Compute Box dropped, addw-review retired (checklist → codex-code-review).
Open questions resolved: `docs/addw.env`; codex overrides folded in; no week-anchor
key (week numbers were dropped).
**Date**: 2026-07-27

## Problem

ADDW skills carry per-project values baked in as placeholders (`[PROJECT_NAME]`,
`[VERSION_FILE]`, `[WEEK_ANCHOR_DATE]`, `[MAIN_BRANCH]`, `[AUDIT_NUDGE_N]`, the
tutorial on/off comment block). Filling them turns every install into a **fork**:
no two projects' skills are byte-identical, so upgrading requires diffing,
extracting, and re-merging — which is why `addw-upgrade` is a 332-line
extraction/merge machine, `addw-init` Phase 6 is a skill-editing procedure, and
both carry placeholder-validation greps to catch what the surgery missed.

v3 already moved design content and commands out of skills into living docs
(ARCHITECTURE.md, TESTING.md). This proposal finishes that move: the last six
process-owned values leave the skills too.

## Proposal

One shell-sourceable config file per project, created by `addw-init`, read by
skills at runtime:

```bash
# docs/addw.env — ADDW project configuration. Created by addw-init.
# Skills read this at runtime; never edit a skill to change these values.
ADDW_SCHEMA=3                     # ADDW install generation (upgrade detection)
ADDW_PROJECT_NAME="MyProject"
ADDW_VERSION_FILE="package.json"
ADDW_MAIN_BRANCH="main"
ADDW_AUDIT_NUDGE_N=5
ADDW_TUTORIALS=false
# Optional codex overrides (otherwise _common.sh defaults apply):
# ADDW_CODEX_MODEL_IMPL="gpt-5.6-luna"
# ADDW_CODEX_MODEL_REVIEW="gpt-5.6-sol"
# ADDW_CODEX_EFFORT="xhigh"
```

Shell-sourceable because its consumers include shell: `addw-3-release` and
`addw-hotfix` `source` it for `$ADDW_VERSION_FILE` / `$ADDW_MAIN_BRANCH`, and
`codex-plan-review/scripts/_common.sh` sources it (if present) for model
overrides — which also deletes addw-upgrade's special-case rule about
preserving a user-tuned `_common.sh` across upgrades.

**The new invariant**: skills are read-only artifacts, identical in every
project. All project state lives in `docs/addw.env` or the living docs.

## Per-skill impact

- **`addw-3-release`** — prerequisites gain "source `docs/addw.env`"; steps
  reference `$ADDW_VERSION_FILE` / `$ADDW_MAIN_BRANCH` / `$ADDW_AUDIT_NUDGE_N`.
  The tutorial comment block becomes a normal conditional step: "If
  `ADDW_TUTORIALS=true`, create `docs/5-tuto/…`". No more uncommenting surgery.
- **`addw-hotfix`** — same treatment for `$ADDW_VERSION_FILE`.
- **`addw-1-plan`, `addw-2-implement`, `addw-review`, `addw-test`,
  `addw-4-maintain`** — their only placeholder is the cosmetic `[PROJECT_NAME]`
  in the mode header. Drop it ("You are now in planning mode for this
  project"). These five skills then need no config at all.
- **`addw-init`** — Phase 6 collapses from a skill-editing procedure to:
  interview → write `docs/addw.env`. (Verifying ARCHITECTURE.md documents per-layer
  conventions, and writing the tutorial audience to CLAUDE.md, both stay.)
- **`addw-upgrade`** — for config-era installs, upgrade = replace `skills/`
  wholesale + carry `docs/addw.env` forward untouched. The extraction/merge
  machinery remains only for pre-config installs (v1/v2/current-v3), whose
  migration is: extract the six values from the installed skills' filled
  placeholders, write `docs/addw.env`, replace all skills from staging.
  `ADDW_SCHEMA` makes the install generation detectable instead of inferred
  from folder names.

## What this buys

- Upgrades become `cp -r` + one env-file check. Most of `addw-upgrade`
  eventually retires (after the pre-config migration window closes).
- `addw-init` no longer edits skills — the "a design change never requires a
  skill edit" rule extends to its natural endpoint: *nothing* requires a skill
  edit except a process change to ADDW itself.
- Placeholder-validation greps, the `_common.sh` diff exception, and the
  tutorial uncomment/renumber procedure all disappear.
- Skills can be tracked as a pristine subtree/submodule if a project wants to.

## Costs

- One extra file read at runtime for `addw-3-release`/`addw-hotfix` (trivial).
- Non-Claude harnesses (OpenCode, Codex CLI, Mistral Vibe) must follow the
  indirection — but they already follow "read ARCHITECTURE.md first", so this is the
  same kind of instruction.
- Mode headers lose the project name (cosmetic).

## Open questions

1. **Filename**: `docs/addw.env` (recommended — env convention, lives with the
   living docs) vs `.claude/addw.env` (nearer the skills, but tool-specific
   path contradicts ADDW's tool-agnostic stance).
2. **Codex model overrides in addw.env**: fold in (recommended) or leave
   solely in `_common.sh`.
3. **`ADDW_WEEK_ANCHOR`**: exists only to serve the project-week numbering.
   If week numbers are dropped (separate decision), this key never exists.

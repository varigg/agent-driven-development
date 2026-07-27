---
name: addw-upgrade
description: Upgrade ADDW workflow skills to a newer version while preserving project customizations
disable-model-invocation: true
argument-hint: "[path to new-addw folder]"
---

# ADDW Upgrade Mode

You are now in **upgrade mode** — merging a newer version of the ADDW workflow into this project's existing, customized ADDW skills.

## The Problem

Installed ADDW skills interleave two layers: the **workflow skeleton** (steps, Codex integration, process flow) and **project customizations** (test commands, checklist sections, version file, guidance sections). A naive copy destroys the second. This skill separates them, applies the new skeleton, and preserves the customizations.

> **v3 destination change**: skills carry NO project values at all — they are identical in every install. Process-owned values (project name, version file, main branch, audit nudge, tutorial flag, optional codex model overrides) live in **`docs/addw.env`**; everything else extracted from an old skill is **relocated into the target repo's living docs** (ARCHITECTURE.md, TESTING.md, CLAUDE.md). Nothing is ever re-injected into a skill, so once a repo is on the config model, upgrading means replacing `skills/` wholesale and carrying `docs/addw.env` forward untouched — most of this skill's machinery exists only for installs that predate the config file.

**Supported sources**: v2 installs (placeholders filled into skills) and config-era v3+ installs. v1 support was dropped once no v1 installs remained; upgrading a v1 repo means going through v2 skills first or re-running `addw-init`.

> **v3 rename (TRIP → ADDW)**: v3 also renames the whole workflow. Installed v2 folders are named `TRIP-*` on disk — this file uses those names for the **installed** side and `addw-*` for the **staging** side. The migration maps `TRIP-<x>` → `addw-<x>` (slash commands change accordingly), `docs/ARCHI.md` → `docs/ARCHITECTURE.md`, `docs/ARCHI-rules.md` → `docs/ARCHITECTURE-rules.md`, and all process values into `ADDW_*` keys in `docs/addw.env`. See §3.0 for the mechanics. Remind the user at the end that their commands changed (`/TRIP-1-plan` → `/addw-1-plan`).

## Prerequisites

The user must have copied the new generic ADDW skills into a staging folder before running this skill. Default location: `.claude/skills/new-addw/`

If `$ARGUMENTS` is provided, treat it as the path to the staging folder. Otherwise use `.claude/skills/new-addw/`.

---

## Phase 1: Inventory

### 1.1 Validate Staging Folder

Confirm the staging folder exists and contains ADDW skills:

```bash
ls -R <staging-path>/
```

If missing or empty, tell the user:
> "No staging folder found at `<path>`. Copy the new ADDW workflow's `skills/` folder there first, then re-run."

### 1.2 Categorize Skills

List all skill folders in both locations:

```bash
# Currently installed
ls -d .claude/skills/*/

# New (staging)
ls -d <staging-path>/*/
```

**Config-era fast path**: if the installed repo already has `docs/addw.env`, the whole upgrade is: replace every staged skill folder wholesale (4.1/4.2), delete retired folders, run Phase 5 validation. Phases 2–3 and the extraction machinery below apply only to **pre-config installs** (placeholders filled into skills).

For pre-config installs, staging skills are all pure workflow (the new skills carry no project values). Categorization applies to the *installed* side:

| Category | Meaning | Action |
|----------|---------|--------|
| **New** | Exists in staging only | Copy directly |
| **Removed** | Exists in installed only, not part of ADDW | Warn user, leave in place |
| **Retired** | Removed from the workflow by a newer version | Extract salvage (below), then delete |
| **Pure** | Installed version holds no project content | Replace directly |
| **Customized** | Installed version holds project content | Extract → relocate → replace |

**Customized (extraction sources)**: `TRIP-1-plan`, `TRIP-2-implement`, `TRIP-3-release`, `TRIP-hotfix`, `TRIP-review`, `TRIP-test` — plus `codex-plan-review/scripts/_common.sh` if the user tuned its model defaults (those move to `addw.env` overrides, not into the new file).

**Retired in v3**: `TRIP-review` (checklist now lives at `codex-code-review/checklist.md`; custom checklist sections are salvage → ARCHITECTURE.md), `cr-template.md`, `synthesize.tpl`.

### 1.3 Present Inventory

Show the user a summary table (skill | status | action) covering every folder in either location, then:

`AskUserQuestion`: "Here's the upgrade plan. Proceed?"
Options: "Yes, start upgrade" (recommended) / "Let me review the new files first" / "Abort"

---

## Phase 2: Extract Project Context

Before touching any installed files, read every customized skill and extract all project-specific values into a context block. This is your safety net — everything here gets re-injected later.

### 2.1 Read All Installed Skills

Read every file in the installed skills directory that will be affected.

### 2.2 Extract Customizations

Build a context block by extracting these values from the installed skills:

**From TRIP-1-plan/SKILL.md:**
- `PROJECT_NAME` — the text that replaced `[PROJECT_NAME]` (in the `**planning mode** for` line)
- `TECHNICAL_CONSIDERATIONS` — the full content of the `## Technical Considerations` section in the plan template, if project-customized
- `GUIDANCE_SECTIONS` — any project-specific per-component guidance sections at the bottom of the file, if present

**From TRIP-3-release/SKILL.md** (and `TRIP-2-implement`/`TRIP-hotfix` where they carry the same values):
- `PROJECT_NAME` — (confirm matches TRIP-1-plan)
- `VERSION_FILE` — the text that replaced `[VERSION_FILE]` in the version-bump step
- `MAIN_BRANCH` / `AUDIT_NUDGE_N` — from the merge and audit-nudge steps
- `WEEK_ANCHOR_DATE` — the date in the date/week step (extracted only to be discarded — see destinations)
- `TUTORIAL_CONFIG` — if tutorials are enabled: the uncommented Tutorial step and its audience context. If disabled: note "tutorials disabled"
- Any lint/typecheck/test commands, if a step carries them inline

**From TRIP-review/ (checklist.md):**
- `REVIEW_CHECKLIST` — the full checklist content, for its project-specific sections
- `CR_TEMPLATE` — `cr-template.md`, if present

**From TRIP-test/SKILL.md:**
- `TEST_COMMANDS` — the Commands section, if project-customized
- `TEST_STRUCTURE` — the test structure description, if project-customized
- `TESTING_PRIORITIES` — the testing priorities section, if project-customized

**Extraction destinations (v3)** — nothing extracted is re-injected into a skill file:
- `PROJECT_NAME`, `VERSION_FILE`, main-branch name, audit-nudge threshold, tutorial on/off, and any tuned `_common.sh` model defaults → **`docs/addw.env`** (per the addw-init Phase 6 template)
- `WEEK_ANCHOR_DATE` → **discarded** — project-week numbering is retired; artifacts are version/date-named
- `TECHNICAL_CONSIDERATIONS`, `GUIDANCE_SECTIONS`, custom `REVIEW_CHECKLIST` sections → the target repo's `docs/ARCHITECTURE.md` (as per-layer conventions), user-reviewed before writing
- `LINT_COMMAND`/`TYPECHECK_COMMAND`/`TEST_COMMAND`, `TEST_COMMANDS`, `TEST_STRUCTURE`, `TESTING_PRIORITIES` → `docs/4-unit-tests/TESTING.md` (Verification Recipes / Test Organization sections)
- `TUTORIAL_CONFIG` audience values (level, focus, style) → the project's CLAUDE.md (`## Tutorial audience` section)
- `CR_TEMPLATE` → **discarded** — the CR archive is retired; the annotated release tag records the review outcome

### 2.3 Present Extracted Context

Show the user a summary of what was extracted:

```
Extracted project context:
- Project name: [name]
- Version file: [path]
- Main branch / audit nudge: [branch] / [N]
- Tutorials: [enabled/disabled]
- Test commands: [lint] / [typecheck] / [test]
- Checklist sections: [count] sections ([list names])
- Guidance sections: [count] sections ([list names])
- Technical considerations: [count] items
```

`AskUserQuestion`: "Extracted project context looks correct?"
Options: "Yes, continue" / "No, let me correct something"

If "No": let the user specify corrections, update the context block.

---

## Phase 3: Handle Structural Migrations

Before merging, handle any structural changes between the old and new workflow versions. Read both old and new files to detect what changed structurally.

### 3.0 Rename Migration (TRIP → ADDW)

Rename the living docs (contents unchanged):

```bash
git mv docs/ARCHI.md docs/ARCHITECTURE.md
git mv docs/ARCHI-rules.md docs/ARCHITECTURE-rules.md
```

The old `TRIP-*` skill folders are not renamed in place — after extraction they are deleted and the staged `addw-*` folders installed (Phase 4). Once everything is applied, sweep the target repo for stale names: `grep -rn 'TRIP-\|ARCHI' docs/ CLAUDE.md README.md .claude/` and update references to the new names. **Dated records are exempt** — old names inside frozen plans, changelog rows, and existing ADRs stay as written.

### 3.1 Checklist Salvage (TRIP-review → codex-code-review)

The review checklist now lives at `codex-code-review/checklist.md` (installed from staging as-is). The v2 install's `TRIP-review/checklist.md` may carry **project-specific sections** — that's the extracted `REVIEW_CHECKLIST` salvage from Phase 2, destined for ARCHITECTURE.md (the v3 checklist derives project conventions from ARCHITECTURE.md at review time). The retired folder is deleted in Phase 4.

### 3.2 Codex Integration & Skills

The Codex review/implement steps in TRIP-1-plan and TRIP-2-implement, and the `codex-*` skills themselves, are pure workflow — copy or replace from staging directly. v2 prompt templates point at the old `TRIP-review/checklist.md` path and must be replaced. The verification commands they rely on live in `docs/4-unit-tests/TESTING.md` (§3.3), not in the skills.

### 3.3 v3 Structural Migration (config, charter, ADRs, maintenance, verification recipes)

When upgrading a repo that lacks them, create:

1. **`docs/addw.env`** — from the values extracted in Phase 2, per the `addw-init` Phase 6 template. Confirm it with the user before writing.
2. **`docs/adr/`** with `docs/adr/template.md` copied verbatim from the template in `addw-init` Phase 7.
   - **If the repo has an existing decision log** (e.g. inside a design doc): move it into `docs/adr/` **verbatim as one frozen legacy file** — it is a dated record; never retro-edit it or split it into per-file ADRs (that would mean reconstructing context from memory). New ADRs **continue its numbering** so existing "decision N" citations stay valid.
   - Existing ADRs with lifecycle statuses (`draft`/`proposed`/`accepted`/`rejected`) are dated records — do not rewrite their status lines. New ADRs use the two-state template (`active` / `superseded by`).
3. **`docs/charter.md`** — interview the user and get approval, exactly as in `addw-init` Phase 7.4. If the repo has a design doc, distill its stable-intent content (purpose, principles, scope, non-goals) into the charter as the interview's starting point.
4. **`docs/7-maintenance/`** — empty folder for addw-4-maintain reports.
5. **Verification Recipes** — add the `## Verification Recipes` and `## Integration / E2E Impact Rules` sections to the existing `docs/4-unit-tests/TESTING.md` (per the `addw-init` Phase 7.2 template), populated from the commands extracted in Phase 2.
6. **Retired artifacts stay put** — existing `docs/3-code-review/` files, per-release changelog files, and `docs/2-changelog/changelog_table.md` are dated records; leave them **frozen exactly as written**. Release history lives in annotated git tags from this upgrade on — do not backfill tags for old changelog rows, and do not add new rows to the frozen file. Add one line at its top: "Frozen at v<current> — release history continues in annotated git tags (`git tag -n99`)."

---

## Phase 4: Merge & Apply

For each skill, apply the appropriate action from the Phase 1 inventory.

### 4.1 New Skills — Copy Directly

```bash
cp -r <staging-path>/<skill>/ .claude/skills/<skill>/
```

For skills with `state/` directories, ensure `.gitignore` is in place.

### 4.2 Pure Workflow Skills — Replace Directly

```bash
rm -rf .claude/skills/<skill>/
cp -r <staging-path>/<skill>/ .claude/skills/<skill>/
```

### 4.3 Customized Skills — Replace, Having Relocated

No merging: every staged skill is installed **as-is** (4.2). The "customization handling" is entirely the relocation already defined by the Phase 2.2 destinations table — addw.env values to `docs/addw.env` (§3.3), design content to ARCHITECTURE.md, commands to TESTING.md, tutorial audience to CLAUDE.md. Verify each relocation landed before replacing the skill folder it came from, and **present anything destined for `docs/ARCHITECTURE.md` to the user for review before writing**.

### 4.4 Retired Skills — Delete

After their salvage is relocated, delete the retired `TRIP-review/` folder, along with every other old `TRIP-*` folder replaced by its `addw-*` successor (4.2).

### 4.5 Write All Files

After building all relocated content in memory, write every file. Do NOT write partial results — complete the full relocation first, then write all at once.

---

## Phase 5: Validate

After writing all files, run a validation pass.

### 5.1 Placeholder Check

Skills carry no placeholders anymore, so any v2 placeholder token is a stale, un-migrated file:

```bash
grep -rn '\[PROJECT_NAME\]\|\[VERSION_FILE\]\|\[WEEK_ANCHOR_DATE\]\|\[MAIN_BRANCH\]\|\[AUDIT_NUDGE_N\]\|\[TUTORIAL_STEP\]' .claude/skills/
```

Any hit means a skill folder escaped replacement — replace it from staging.

### 5.2 Cross-Reference Check

- `docs/addw.env` exists, is shell-sourceable (`bash -n docs/addw.env`), and every `ADDW_*` value is filled
- `codex-code-review/checklist.md` exists; `codex-code-review/prompts/start.tpl` and `resume.tpl` point at it (no template references a `TRIP-review/` path)
- No stale old-name references outside dated records (§3.0 sweep ran clean: no `TRIP-*` folder left, no `ARCHI.md`/`ARCHI-rules.md` reference in living docs)
- `addw-1-plan` and `addw-2-implement` reference `codex-plan-review/scripts/start.sh` and `resume.sh`; `addw-2-implement` also references `codex-implement/scripts/start.sh` — confirm they exist
- v3 structure (§3.3) in place: `docs/charter.md`, `docs/adr/template.md`, and `docs/7-maintenance/` exist; `docs/4-unit-tests/TESTING.md` contains a **Verification Recipes** section (addw-2/addw-3/addw-hotfix/addw-test all point at it)

### 5.3 Present Summary

Show what changed:

```
Upgrade complete:
- New skills added: [list]
- Skills updated: [list]
- Skills unchanged: [list]
- Project customizations preserved: [list key ones]
```

`AskUserQuestion`: "Upgrade applied. Review the changes?"
Options: "Looks good" / "Show me the diffs" / "Revert everything"

If "Show me the diffs": run `git diff .claude/skills/` and present.
If "Revert everything": `git checkout -- .claude/skills/`

---

## Phase 6: Clean Up

After user confirms:

1. Remove the staging folder:
   ```bash
   rm -rf <staging-path>
   ```

2. Report completion:
   > "ADDW workflow upgraded. The staging folder has been removed. You can `git diff .claude/skills/` to review all changes before committing."

---

## Edge Cases

- **Already on the new structure** — most skills categorize as "Unchanged"; the merge is trivial.
- **Extra custom skills not in the new workflow** — categorized "Removed": warn, but never delete a skill that exists only in the install.
- **No extractable test commands anywhere** — if TESTING.md doesn't already carry them, ask: `AskUserQuestion` "The workflow needs lint/typecheck/test commands for TESTING.md's Verification Recipes. What are they?" Options: "Let me provide them" / "Skip for now" (leave TODOs in TESTING.md).

---

## Notes for the Agent

- **Read before writing.** Never write a file from memory alone.
- **Preserve semantics, not bytes.** If the old checklist had 10 custom sections, all 10 must survive the relocation, even if their numbering changes.
- **Atomic application.** Build every merged file in memory before writing any of them, so a mid-merge failure leaves the install intact.
- **When in doubt, ask.** Show the user the section you can't confidently classify.
- **Never delete user-created files** sitting inside a skill directory (fixtures, notes).

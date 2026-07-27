---
name: TRIP-3-release
description: Release a completed implementation - version, code review promotion, changelogs, docs, commit, tag, ff-merge, push
argument-hint: "plan file or feature label"
---

# Release Mode

You are now in **release mode** for **[PROJECT_NAME]**.

Release: $ARGUMENTS

This skill runs after `TRIP-2-implement` has converged (implementation done, testing gate green, Codex code review `APPROVED` or explicitly skipped). It is normally chained from TRIP-2 in the same session, but can be invoked standalone in a fresh session.

---

## Prerequisites

- Implementation complete and user-confirmed.
- Testing gate green: affected unit tests pass.
- Codex code review converged (`APPROVED`), or explicitly skipped by the user.
- Lint and type-check/build green.

### Standalone verification (fresh session, not chained from TRIP-2)

If this skill was NOT chained from a TRIP-2 session in the current conversation, verify before any release step: run the lint, type-check/build, and affected-tests recipes per `docs/4-unit-tests/TESTING.md` (Verification Recipes), scoping tests to the plan's Test Impact section.

All must be green. Also verify the Codex state file exists for the given plan path/label (see Step 3 below); if absent, treat as the skipped-Codex fallback (manual CR) and say so explicitly in the CR.

Any failure blocks the release — fix or return to `TRIP-2-implement` first.

---

## Step 1: Get Current Date/Week

Run this command to get date and project week:

```bash
date '+%d-%m-%Y %H:%M' && echo "Project week: $(( ( $(date +%s) - $(date -d '[WEEK_ANCHOR_DATE]' +%s) ) / 604800 + 1 ))"
```

Use the project week in all subsequent steps.

## Step 2: Version Update

- If not already done in the plan phase, propose new SemVer version (x.y.z)
- Update version in `[VERSION_FILE]`
- Do not modify anything else in this file

## Step 3: Promote Code Review

Now that week (`a`) and version (`x.y.z`) are known:

1. Compute state file path:
   ```bash
   STATE_KEY="$(realpath <plan-path> | sed 's|^/||; s|/|__|g')"
   STATE_FILE=".claude/skills/codex-code-review/state/${STATE_KEY}.review.txt"
   ```

2. Content source:
   - **Multi-round loop**: state file has synthesized review + `PROMOTION_READY`. Strip sentinel.
   - **Turn 1 convergence**: state file has full review already.
   - **Skipped Codex**: write CR from `.claude/skills/TRIP-review/cr-template.md` with body "Code review skipped — trivial change." Verdict: `APPROVED with observations`.

3. Replace `<x.y.z>` with actual version. Fill any remaining `<...>` placeholders.

4. Save to `docs/3-code-review/CR_wa_vx.y.z.md`.

5. Verify: no `<...>` placeholders, no `PROMOTION_READY`, version matches version file.

## Step 4: Commit Message

Propose a one-line commit message for the **release commit** (version bump + docs). The implementation itself was already committed per-phase during `TRIP-2-implement`.

## Step 5: Changelog File

Create `docs/2-changelog/wa_vx.y.z.md` (a=project week, x.y.z=version):

```markdown
# Changelog - Week a, DD-MM-YYYY, V. x.y.z

**Release Date**: Week a, DD-MM-YYYY at HH:MM
**Version**: x.y.z (previously x0.y0.z0)
**Object**: the commit message
**Code review**: `docs/3-code-review/CR_wa_vx.y.z.md` (Codex loop, N rounds -> verdict)

## Changes

[Describe what changed]
```

## Step 6: Changelog Table

Add entry on top of `docs/2-changelog/changelog_table.md`:

```markdown
| `x.y.z` | a | the commit message |
```

Also add a summary entry in the Changelog Summary section.

## Step 7: Design Reconciliation

1. Read fully @docs/ARCHI-rules.md
2. Update @docs/ARCHI.md following the rules
3. Run `bash .claude/skills/TRIP-compact/count-tokens.sh docs/ARCHI.md` to check token count
4. **ADR acceptance** — for each `proposed` ADR in `docs/adr/` this release implements, flip its Status to `accepted` (date + this release's version in its Plan-Release header) and append anything implementation taught, e.g. a gate discharge note. The flip rides in this release's commit. Never retro-edit an ADR's body otherwise; if implementation changed a decision, amend the ADR now or record a superseding one. A `draft` ADR must never reach a release still marked `draft` — that means TRIP-1 skipped adoption; stop and adopt it first, so the record shows a plan validated the decision.
5. **Reconciliation sweep** — mandatory whenever the release changed any documented mechanism:
   - Living docs describe **only the current design**; git history is the archive. Never leave superseded text behind a "historic"/"superseded" label. For each stale passage: **delete it** if it merely describes the old state; **rewrite it as an explicit lesson or warning** if it carries evidence that constrains future work.
   - Sweep **every** living doc — the whole of `docs/` outside the numbered per-release directories, plus CLAUDE.md and README.md — starting from the plan's **Doc Impact** list, then finish with a grep for the retired mechanism's vocabulary to catch what the plan missed. Enumerate the directory rather than working from a remembered list; living documents get added, and the one nobody lists is the one that keeps the retired wording.
   - Dated records (everything under `docs/adr/`, changelogs, code reviews, per-release tutorials, promoted plans) are exempt: their date is part of their meaning. Do not retro-edit them.
   - If the vocabulary grep hits anything under `.claude/skills/`, that is **design content leaked into process files**: do NOT fix it inside the release. Flag it to the user as a separate process-change decision with its own commit (see TRIP-1's Process/Design Separation rule).
6. **Charter check** — re-read `docs/charter.md` and verify it still holds (purpose, principles, scope, non-goals). If this release appears to invalidate any of it, do NOT edit the charter in-release: **FLAG it to the user** as a separate design-commit decision. Charter changes are always their own dedicated commits.

**Warning: If ARCHI.md exceeds ~20,000 tokens**, warn the user:

> "ARCHI.md is at ~X tokens. Consider running `TRIP-compact` to reduce it before committing."

<!-- [TUTORIAL_STEP]
### Step 8: Tutorial

Create `docs/5-tuto/tuto_x.y.z.md` explaining the core principle.

The audience profile (level, learning focus, style) lives in the project's CLAUDE.md — read it there; do not restate it in this skill.
-->

## Step 8: README Update

Update `README.md` with the new version number.
Also update relevant sections whenever needed.

---

After completing all documentation steps, **use the `AskUserQuestion` tool** to ask:

- **Question**: "All documentation steps are complete. Ready to commit?"
- **Options**: "Yes, commit now" (proceed with git commit and tag), "Not yet" (review changes first)

**ONLY after user selects "Yes"**, proceed:

## Step 9: Commit

Review `git status` first. Stage the release artifacts **explicitly** — implementation commits already exist on the branch from TRIP-2's per-phase checkpoints, so this commit contains only version + docs:

```bash
git status
git add [VERSION_FILE] README.md docs/1-plans/<plan-file> docs/2-changelog/ docs/3-code-review/ docs/ARCHI.md docs/adr/
git commit -m "<commit message from Step 4>"
```

Never use `git add -A`. If `git status` shows unexpected files, resolve them (gitignore or discuss) before committing.

**Commit taxonomy**: the release commit carries code artifacts + dated records + ARCHI.md + ADR flips. Charter changes (flagged in Step 7, user-approved) are separate design commits. Skill changes are separate process commits — never part of a release.

**Important**: Only use the commit message. Do NOT add Co-Authored-By or any other trailer.

## Step 10: Tag

```bash
git tag vx.y.z
```

## Step 11: Merge (fast-forward)

Merge the feature branch back into the main branch, keeping a single clean linear history:

```bash
git checkout [MAIN_BRANCH]
git merge --ff-only <feature-branch>
git branch -d <feature-branch>
```

If `--ff-only` fails, the main branch moved during implementation — rebase the feature branch onto it, then retry. **Never create a merge commit.**

## Step 12: Push

**Use the `AskUserQuestion` tool** to ask:

- **Question**: "Release vx.y.z is committed, tagged, and merged. Push to remote?"
- **Options**: "Yes, push now" (push branch and tags), "Not yet" (push manually later)

**If "Yes"**:

```bash
git push && git push --tags
```

## Step 13: Maintenance Audit Nudge

Count releases (changelog entries) since the newest maintenance report in `docs/7-maintenance/` (all releases since init if no report exists yet). If the count is ≥ [AUDIT_NUDGE_N], suggest:

> "N releases since the last maintenance audit. Consider running `TRIP-4-maintain`."

Suggest only — never start the audit automatically.

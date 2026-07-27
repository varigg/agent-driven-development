---
name: addw-3-release
description: Release a completed implementation - version, changelog, docs, commit, tag, ff-merge, push
argument-hint: "plan file or feature label"
---

# Release Mode

You are now in **release mode**.

Release: $ARGUMENTS

This skill runs after `addw-2-implement` has converged (implementation done, testing gate green, Codex code review `APPROVED` or explicitly skipped). It is normally chained from addw-2 in the same session, but can be invoked standalone in a fresh session.

Steps below are **named, not numbered** — the tutorial step is optional, and named steps keep the sequence stable whether or not it runs.

---

## Prerequisites

Source the project config first — subsequent steps use its values:

```bash
source docs/addw.env
```

- Implementation complete and user-confirmed.
- Testing gate green: affected unit tests pass.
- Codex code review converged (`APPROVED`), or explicitly skipped by the user.
- Lint and type-check/build green.

### Standalone verification (fresh session, not chained from addw-2)

If this skill was NOT chained from a addw-2 session in the current conversation, verify before any release step: run the lint, type-check/build, and affected-tests recipes per `docs/4-unit-tests/TESTING.md` (Verification Recipes), scoping tests to the plan's Test Impact section.

All must be green. For the changelog's review line, read the verdict and round count from the Codex state file (`.claude/skills/codex-code-review/state/`, key derived from the plan path); if absent, the review was skipped — record that explicitly.

Any failure blocks the release — fix or return to `addw-2-implement` first.

---

## Date

```bash
date '+%d-%m-%Y %H:%M'
```

## Version Update

- If not already done in the plan phase, propose new SemVer version (x.y.z)
- Update version in `$ADDW_VERSION_FILE`
- Do not modify anything else in this file

## Changelog

`docs/2-changelog/changelog_table.md` is the single release record. Propose a one-line commit message for the **release commit** (version bump + docs) — the table row and the commit itself both use it. The implementation was already committed per-phase during `addw-2-implement`.

Add a row at the top of the Changelog Table section:

```markdown
| `x.y.z` | DD-MM-YYYY | the commit message |
```

And an entry at the top of the Changelog Summary section:

```markdown
- **vx.y.z (DD-MM-YYYY)**: the commit message
  - **Changes**: [what changed and why — 1-3 bullets]
  - **Plan**: `docs/1-plans/F_x.y.z_feature-name.plan.md` (or "unplanned")
  - **Review**: Codex loop, N rounds → verdict [plus any overrides or accepted open findings; or "skipped — trivial change"]
```

## Design Reconciliation

1. Read fully @docs/ARCHITECTURE-rules.md
2. Update @docs/ARCHITECTURE.md following the rules
3. Run `bash .claude/skills/addw-compact/count-tokens.sh docs/ARCHITECTURE.md` to check token count
4. **Reconciliation sweep** — mandatory whenever the release changed any documented mechanism. The plan's **Doc Impact** list is the starting point, not the whole job:
   - Living docs describe **only the current design**; git history is the archive. Never leave superseded text behind a "historic"/"superseded" label. For each stale passage: **delete it** if it merely describes the old state; **rewrite it as an explicit lesson or warning** if it carries evidence that constrains future work.
   - Sweep **every** living doc — the whole of `docs/` outside the numbered per-release directories, plus CLAUDE.md and README.md — starting from the plan's **Doc Impact** list, then finish with a grep for the retired mechanism's vocabulary to catch what the plan missed. Enumerate the directory rather than working from a remembered list; living documents get added, and the one nobody lists is the one that keeps the retired wording.
   - Dated records (everything under `docs/adr/`, changelogs, per-release tutorials, promoted plans) are exempt: their date is part of their meaning. Do not retro-edit them. If this release invalidated a decision an ADR records, write a **superseding ADR** — never edit the old one.
   - If the vocabulary grep hits anything under `.claude/skills/`, that is **design content leaked into process files**: do NOT fix it inside the release. Flag it to the user as a separate process-change decision with its own commit (see addw-1's Process/Design Separation rule).
5. **Charter check** — re-read `docs/charter.md` and verify it still holds (purpose, principles, scope, non-goals). If this release appears to invalidate any of it, do NOT edit the charter in-release: **FLAG it to the user** as a separate design-commit decision. Charter changes are always their own dedicated commits.

**Warning: If ARCHITECTURE.md exceeds ~20,000 tokens**, warn the user:

> "ARCHITECTURE.md is at ~X tokens. Consider running `addw-compact` to reduce it before committing."

## Tutorial (if `ADDW_TUTORIALS=true`)

Skip this step when `$ADDW_TUTORIALS` is not `true`.

Create `docs/5-tuto/tuto_x.y.z.md` explaining the core principle. The audience profile (level, learning focus, style) lives in the project's CLAUDE.md — read it there; do not restate it in this skill.

## README Update

Update `README.md` with the new version number.
Also update relevant sections whenever needed.

---

After completing all documentation steps, **use the `AskUserQuestion` tool** to ask:

- **Question**: "All documentation steps are complete. Ready to commit?"
- **Options**: "Yes, commit now" (proceed with git commit and tag), "Not yet" (review changes first)

**ONLY after user selects "Yes"**, proceed:

## Commit

Review `git status` first. Stage the release artifacts **explicitly** — implementation commits already exist on the branch from addw-2's per-phase checkpoints, so this commit contains only version + docs:

```bash
git status
git add "$ADDW_VERSION_FILE" README.md docs/1-plans/<plan-file> docs/2-changelog/ docs/ARCHITECTURE.md docs/adr/
git commit -m "<the changelog's commit message>"
```

Never use `git add -A`. If `git status` shows unexpected files, resolve them (gitignore or discuss) before committing.

**Commit taxonomy**: the release commit carries code artifacts + dated records + ARCHITECTURE.md. Charter changes (flagged during Design Reconciliation, user-approved) are separate design commits. Skill changes are separate process commits — never part of a release.

**Important**: Only use the commit message. Do NOT add Co-Authored-By or any other trailer.

## Tag

```bash
git tag vx.y.z
```

## Merge (fast-forward)

Merge the feature branch back into the main branch, keeping a single clean linear history:

```bash
git checkout "$ADDW_MAIN_BRANCH"
git merge --ff-only <feature-branch>
git branch -d <feature-branch>
```

If `--ff-only` fails, the main branch moved during implementation — rebase the feature branch onto it, then retry. **Never create a merge commit.**

## Push

**Use the `AskUserQuestion` tool** to ask:

- **Question**: "Release vx.y.z is committed, tagged, and merged. Push to remote?"
- **Options**: "Yes, push now" (push branch and tags), "Not yet" (push manually later)

**If "Yes"**:

```bash
git push && git push --tags
```

## Maintenance Audit Nudge

Count releases (changelog entries) since the newest maintenance report in `docs/7-maintenance/` (all releases since init if no report exists yet). If the count is ≥ `$ADDW_AUDIT_NUDGE_N`, suggest:

> "N releases since the last maintenance audit. Consider running `addw-4-maintain`."

Suggest only — never start the audit automatically.

---
name: addw-hotfix
description: Urgent fix bypassing full ADDW workflow
disable-model-invocation: true
argument-hint: "what is broken in production?"
---

# Hotfix Mode

You are now in **hotfix mode** - a streamlined workflow for urgent production fixes.

> **Warning**: Only use this for genuine emergencies. For regular bugs, use the full ADDW workflow (`addw-1-plan` → `addw-2-implement`).

## Your Task

Hotfix: $ARGUMENTS

---

## Step 1: Assess Urgency

Before proceeding, confirm this is a genuine hotfix:

**Use the `AskUserQuestion` tool** to confirm urgency:

- **Question**: "Is this a production-critical issue that cannot wait for the normal ADDW workflow?"
- **Options**: "Yes — critical issue" (security vulnerability, data corruption, service outage, or critical user-facing bug), "No — regular bug" (redirect to `addw-1-plan` for proper workflow)

**If "No"**: Redirect to `addw-1-plan` for proper workflow.

**If "Yes"**: Proceed with hotfix.

---

## Step 2: Create Hotfix Branch

```bash
source docs/addw.env
git checkout "$ADDW_MAIN_BRANCH" && git pull
git checkout -b hotfix/[short-description]
```

---

## Step 3: Minimal Investigation

First, read `docs/ARCHITECTURE.md`'s Core Architecture Principles section plus the section(s) covering the affected layer — pick them via the change-type table in `docs/ARCHITECTURE-rules.md`. (Scoped read is deliberate: this is the urgent path; the full ARCHI read belongs to planning.) Then explore the codebase and read the files relevant to the issue.

Quickly identify:

1. **Root cause** (1-2 sentences)
2. **Affected files** (list)
3. **Fix approach** (brief)

No formal plan document needed.

---

## Step 4: Implement Fix

- Focus only on the fix - no refactoring, no "while I'm here" improvements
- Minimal changes to resolve the issue
- Follow existing patterns from the codebase

---

## Step 5: Quick Verification

- Manually test the fix
- Run relevant tests only, via the affected-tests recipe in `docs/4-unit-tests/TESTING.md` (Verification Recipes)
- Confirm the issue is resolved

---

## Step 6: Version & Changelog

### Version Bump

Increment **patch** version only (x.y.Z+1) in `$ADDW_VERSION_FILE`.

### Minimal Changelog Entry

Add to top of `docs/2-changelog/changelog_table.md`:

```markdown
| `x.y.z` | DD-MM-YYYY | hotfix: [brief description] |
```

Add to Changelog Summary:

```markdown
- **vX.Y.Z (Hotfix, DD-MM-YYYY)**:
  - **Issue**: [What was broken]
  - **Fix**: [What was done]
  - **Root Cause**: [Brief explanation]
```

---

## Step 7: Commit

Review `git status`, then stage the fix's files **explicitly** (never `git add -A`):

```bash
git status
git add <fixed files> "$ADDW_VERSION_FILE" docs/2-changelog/changelog_table.md
git commit -m "hotfix: [brief description]"
```

---

## Step 8: Merge & Tag

```bash
git checkout "$ADDW_MAIN_BRANCH"
git merge --ff-only hotfix/[short-description]
git tag vx.y.z
git push && git push --tags
git branch -d hotfix/[short-description]
```

If `--ff-only` fails, rebase the hotfix branch onto the main branch and retry. Never create a merge commit.

---

## Step 9: Post-Hotfix

Once the crisis is resolved: write a brief incident report in `docs/6-memo/` if it was significant, and open a proper `addw-1-plan` if the real fix is deeper than the patch.

---

## What This Workflow Skips

No discovery questions, no plan document, no code review checklist, no tutorial, and no ARCHITECTURE.md/README update unless the fix actually changed the architecture. Acceptable trade-offs for a genuine emergency — and only for that.

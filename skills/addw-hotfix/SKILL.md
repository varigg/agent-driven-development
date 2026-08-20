---
name: addw-hotfix
description: Urgent fix bypassing the normal ticket flow - expedited PR merged immediately
disable-model-invocation: true
argument-hint: "what is broken in production?"
---

# Hotfix Mode

You are now in **hotfix mode** - a streamlined workflow for urgent production fixes.

> **Warning**: Only use this for genuine emergencies. For regular bugs, file a tracker issue and work it through `addw-implement`.

## Your Task

Hotfix: $ARGUMENTS

---

## Step 1: Assess Urgency

Before proceeding, confirm this is a genuine hotfix:

**Use the `AskUserQuestion` tool** to confirm urgency:

- **Question**: "Is this a production-critical issue that cannot wait for the normal ticket flow?"
- **Options**: "Yes — critical issue" (security vulnerability, data corruption, service outage, or critical user-facing bug), "No — regular bug" (file a tracker issue and work it as a normal ticket)

**If "No"**: file the tracker issue and stop — the fix arrives through `addw-implement`.

**If "Yes"**: Proceed with hotfix.

---

## Step 2: Create Hotfix Branch

```bash
. .claude/skills/lib/config/config.sh && config_source ADDW_MAIN_BRANCH
git checkout "$ADDW_MAIN_BRANCH" && git pull
git checkout -b hotfix/[short-description]
```

---

## Step 3: Minimal Investigation

First, read `docs/ARCHITECTURE.md`'s Core Architecture Principles section plus the section(s) covering the affected layer — pick them via the change-type table in `docs/ARCHITECTURE-rules.md`. (Scoped read is deliberate: this is the urgent path; the full ARCHI read belongs to the normal ticket flow.) Then explore the codebase and read the files relevant to the issue.

Quickly identify:

1. **Root cause** (1-2 sentences)
2. **Affected files** (list)
3. **Fix approach** (brief)

No ticket needed before the fix — the scrutiny this path skips is ticketed on the way out (Step 6).

---

## Step 4: Implement Fix

- Focus only on the fix - no refactoring, no "while I'm here" improvements
- Minimal changes to resolve the issue
- Follow existing patterns from the codebase

---

## Step 5: Verify Through the Gate

- Manually confirm the issue is resolved
- Run the deterministic testing gate, passing the affected test paths:

```bash
bash .claude/skills/lib/gate/gate.sh [affected-test paths]
```

Keep the summary line it prints — the PR body carries it. The gate must be green: a hotfix that breaks lint or unrelated tests is not expedited, it is a second incident.

---

## Step 6: File the Deferred-Scrutiny Ticket

The expedited path is a **reordering of scrutiny, not a reduction** — deferral, not waiver. Before opening the PR, file one follow-up ticket through the tracker layer — never the tracker CLI directly — naming exactly what this hotfix defers:

```bash
bash .claude/skills/lib/tracker/tracker.sh create "chore: deferred scrutiny for hotfix [short-description]" <body-file> backlog
```

The body names the three deferred checks, with enough context that whoever picks it up rediscovers nothing:

1. **Regression/contract test** for the bug this hotfix fixed — the test the normal flow would have written first.
2. **Codex review** over the landed diff.
3. **Doc-impact check**: whether the fix changed documented design, and the living-doc update if it did.

Filed `backlog` per ADR 0007's gate. The ticket carries **no `## Parent`**, so it gates no spec's completion and no release. The PR body names its number, so the human's merge is the naming act that graduates it — keep the number; the next step and Post-Hotfix both use it.

---

## Step 7: Open the Expedited PR

Review `git status`, stage the fix's files **explicitly** (never `git add -A`), commit, push the branch, and open the PR:

- **Title**: must parse as a conventional-commit subject — normally `fix: [brief description]`. It becomes the squash subject on main, which is all the mechanical changelog projects.
- **Body**: what was broken, the root cause, what the fix does, the gate summary line, and the deferred-scrutiny ticket's number — and say it is a hotfix requesting immediate merge.

The human merges it immediately (squash). Seconds of ceremony, and main's every-commit-is-a-reviewed-PR invariant holds — emergencies included.

---

## Post-Hotfix

- The merge graduated the deferred-scrutiny ticket (ADR 0007's graduation mechanic — a human-merged PR whose body names a filing). Make the graduation mechanical so the frontier picks it up:

```bash
bash .claude/skills/lib/tracker/tracker.sh unlabel [ticket-number] backlog
bash .claude/skills/lib/tracker/tracker.sh label [ticket-number] ready-for-agent
```

- If the fix must ship as a tagged release now, invoke `addw-release` after the merge — a repository release tags what main has accumulated since the last tag.
- The merged PR is the incident record. If the real fix is deeper than the patch, file a follow-up tracker issue.

---

## What This Workflow Defers

No ticket before the fix, no contract tests, no codex review loop, no pre-filter code review — the human's immediate PR review is the only pre-merge gate — and no living-doc update unless the fix obviously changed documented design. None of it is waived: the deferred-scrutiny ticket (Step 6) carries every skipped check, so total scrutiny converges with the normal path. What the emergency buys is time-to-main — and every use costs a visible follow-up ticket, which is why this path cannot quietly become the default.

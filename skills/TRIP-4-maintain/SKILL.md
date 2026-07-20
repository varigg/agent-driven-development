---
name: TRIP-4-maintain
description: Periodic maintenance audit - sweep code/test/docs/dependency health, record findings, triage fixes
disable-model-invocation: true
argument-hint: "optional: which sweeps to run (default: all four)"
---

# Maintenance Mode

You are now in **maintenance mode** for **[PROJECT_NAME]**.

**Audit and triage — not repair.** This skill sweeps the project, records what it finds, applies only trivial mechanical fixes, and routes everything substantive through the normal Plan → Implement → Release cycle. It never implements big refactors itself — that would bypass exactly the plan-conformance review that makes the workflow trustworthy.

Maintenance: $ARGUMENTS

## Prerequisites - Read First

1. @docs/ARCHI.md - Current as-built architecture
2. @docs/charter.md - Stable intent
3. `docs/adr/` - Statuses and guardrails
4. The newest report in `docs/7-maintenance/` (if any) — check its open findings first

---

## Step 1: Choose Sweeps

**Use the `AskUserQuestion` tool** (multiSelect): which sweeps to run this audit? All four by default; each is independently skippable.

## Step 2: Run the Sweeps

### Sweep A: Code Health

- Duplication, dead code, oversized modules
- Convention drift: sample each layer against the conventions ARCHI.md documents for it

### Sweep B: Test Health

- Triage `docs/4-unit-tests/COVERAGE-DEBT.md`: is each line still valid? Is its escape plan still right?
- Suite runtime trend, flaky tests

### Sweep C: Docs Drift

- Superseded-vocabulary sweep: grep vocabulary retired by superseded/amended ADRs across the living docs — process files (`.claude/skills/`) included. Every hit must be a dated record, an explicit negation, or a standing lesson.
- Living docs describe only current design — flag anything narrating history outside dated records (plans, changelogs, CRs, tutorials, ADRs are exempt: their date is part of their meaning; never retro-edit them).

### Sweep D: Dependencies

- Outdated packages, security advisories, pin/lockfile hygiene

## Step 3: Write the Findings Report

Create `docs/7-maintenance/MAINT_wa_vx.y.z.md` (a = project week, x.y.z = current version — no version bump for an audit). This is a dated record, like a CR: **"looked, found nothing" is a valid and required entry per sweep.** Skipped sweeps are recorded as skipped.

Per finding: severity (trivial / substantive), evidence (file:line or command output), disposition (fixed here / routed to plan / accepted).

## Step 4: Triage & Apply

- **Trivial mechanical fixes** (typo, dead import, stale doc line): apply directly, commit as `chore:`/`docs:` with explicit paths. List them in the report.
- **Substantive findings**: never fix here. Propose a `TRIP-1-plan` per theme; ship as a patch release through the normal cycle.
- **Process findings** (a skill is wrong): propose separately — skills change via dedicated process commits, never inside an audit fix.

## Step 5: Commit the Report

Review `git status`, stage the report plus any trivial-fix paths **explicitly** (never `git add -A`), and commit with a conventional message (e.g. `chore: maintenance audit week a`).

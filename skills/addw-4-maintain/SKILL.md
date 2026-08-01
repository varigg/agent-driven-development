---
name: addw-4-maintain
description: Periodic maintenance audit - sweep code/test/docs/dependency health, record findings, triage fixes
disable-model-invocation: true
argument-hint: "optional: which sweeps to run (default: all four)"
---

# Maintenance Mode

You are now in **maintenance mode**.

**Audit and triage — not repair.** This skill sweeps the project, records what it finds, applies only trivial mechanical fixes, and routes everything substantive through the normal Plan → Implement → Release cycle. It never implements big refactors itself — that would bypass exactly the plan-conformance review that makes the workflow trustworthy.

Maintenance: $ARGUMENTS

## Prerequisites - Read First

1. @docs/ARCHITECTURE.md - Current as-built architecture
2. @docs/charter.md - Stable intent
3. `docs/adr/` - Active decisions and guardrails
4. The newest report in `docs/7-maintenance/` (if any) — check its open findings first

---

## Step 1: Choose Sweeps

**Use the `AskUserQuestion` tool** (multiSelect): which sweeps to run this audit? All four by default; each is independently skippable.

## Step 2: Run the Sweeps

### Sweep A: Code Health

- Duplication, dead code, oversized modules
- Convention drift: sample each layer against the conventions ARCHITECTURE.md documents for it

### Sweep B: Test Health

- Triage `docs/4-unit-tests/COVERAGE-DEBT.md`: is each line still valid? Is its escape plan still right?
- Suite runtime trend, flaky tests

### Sweep C: Docs Drift

**Vocabulary**

- Superseded-vocabulary sweep: grep vocabulary retired by superseded/amended ADRs across the living docs — process files (`.claude/skills/`) included. Every hit must be a dated record, an explicit negation, or a standing lesson.
- Living docs describe only current design — flag anything narrating history outside dated records (plans, CHANGELOG.md, CRs, tutorials, ADRs are exempt: their date is part of their meaning; never retro-edit them).
- A rename pass is **prose only**. Identifiers, script names, and paths are
  code changes — file them, don't do them here.
- Verify a rename by listing what survived, never by trusting the edit.
  Multi-word protections fail silently when the phrase wraps a line, and a
  blanket substitution reads plausibly while meaning something new.

**Structure** — drift is not only wording; a correct document in the wrong
place is drift too.

- **Pointer direction: durable must never depend on transient.** Durable =
  charter, `docs/adr/`, ARCHITECTURE.md, glossary, conventions, runbooks. Transient =
  handoffs, worklists, task lists, audit reports. Transient → durable is
  correct; the reverse is a finding, because the durable record's meaning
  then degrades as tasks are checked off and breaks outright if the
  transient file is ever emptied.
- **Filing follows lifetime, not topic.** Check each document's location
  against how long it lives, not what it is about. A durable reference
  sitting in a per-release or working-notes directory is a finding even when
  its content is perfect — and it silently legitimizes bad pointers, since a
  reference aimed into a scratch directory looks unremarkable.
- **Line-scoped pointers** (`file.md:94-95`) drift the moment the target is
  edited, and read as precise while pointing at nothing. Replace with a
  named section or entry.
- **Transient documents are pruned, not appended to.** A worklist or backlog
  that keeps its closed entries becomes a second archive competing with git,
  and the closed majority buries the open minority that is the file's whole
  purpose. Closing an entry means deleting it — after anything durable it
  carried has been moved to a durable home first. Mostly-closed is the
  finding; check the ratio.
- **A document that summarizes its own body will drift out of agreement with
  it.** Header counts, status preambles, and "current state" summaries
  restating what the sections below already say get updated in one place and
  not the other, and the file then contradicts itself while both halves look
  authoritative. Report the duplicated structure — reconciling the two numbers
  and leaving the arrangement in place only resets the clock.

**Claims**

- **Verify every imperative against reality.** Sweep for "must be reversed
  before", "blocked on", "do not X until", "conflicts with". A directive
  recorded in two documents and discharged in one becomes a phantom task
  that survives every handoff and re-enters the backlog forever. Correct the
  document that still asserts it; do not append "satisfied on <date>".
- **A document must not restate a fact it has itself delegated.** Where a doc
  names another as authoritative for some topic, any figure, path, or count it
  then states on that same topic is a second copy nothing keeps in sync — and
  the two diverge silently while both read as current. Check this by following
  the document's own pointers and looking for overlap, not by judging
  importance. The same applies to facts owned by the operator's machine rather
  than the project — addresses, hostnames, local paths, hardware — which no
  repository can keep true.
- **A procedure that has been performed and cannot be performed again is
  spent.** Runbooks accrete one-time migrations, resets, and cutovers that
  keep reading as legitimate reference long after the fact — a description of
  a completed action does not look stale the way a description of a retired
  mechanism does. Delete the steps; keep only what they taught, as a lesson or
  a warning.
- Accretion has a cheap measurement:
  `bash .claude/skills/addw-3-release/scripts/check-doc-accretion.sh <file>...`
  counts a document's version references against its copy at the previous tag.
  A count climbing release over release means the document is narrating its own
  history. Point it at ARCHITECTURE.md and at every runbook — the release step
  runs it on ARCHITECTURE.md only.
- **Design records are not work logs.** When auditing an ADR: an alternative
  earns its place only if a competent reader would independently propose it
  and act on it; evidence earns its place only if the decision would change
  when the evidence changes. Counts, filenames, and dated verifications
  belong in the work log. Options invented to frame a decision are not
  design history.

### Sweep D: Dependencies

- Outdated packages, security advisories, pin/lockfile hygiene

## Step 3: Write the Findings Report

Create `docs/7-maintenance/MAINT_vx.y.z.md` (x.y.z = current version — no version bump for an audit), dated in its header. This is a dated record: **"looked, found nothing" is a valid and required entry per sweep.** Skipped sweeps are recorded as skipped.

Per finding: severity (trivial / substantive), evidence (file:line or command output), disposition (fixed here / routed to plan / accepted).

## Step 4: Triage & Apply

- **Trivial mechanical fixes** (typo, dead import, stale doc line): apply directly, commit as `chore:`/`docs:` with explicit paths. List them in the report.
- **Substantive findings**: never fix here. Propose a `addw-1-plan` per theme; ship as a patch release through the normal cycle.
- **Process findings** (a skill is wrong): propose separately — skills change via dedicated process commits, never inside an audit fix.

## Step 5: Commit the Report

Review `git status`, stage the report plus any trivial-fix paths **explicitly** (never `git add -A`), and commit with a conventional message (e.g. `chore: maintenance audit vx.y.z`).

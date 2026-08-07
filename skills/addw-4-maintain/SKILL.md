---
name: addw-4-maintain
description: Periodic maintenance audit - sweep living-docs drift, coverage debt, and dependency health; record findings, triage fixes
disable-model-invocation: true
argument-hint: "optional: which sweeps to run (default: all three)"
---

# Maintenance Mode

You are now in **maintenance mode**.

**Audit and triage — not repair.** This skill sweeps the project, records what it finds, applies only trivial mechanical fixes, and routes everything substantive to the tracker as issues. It never implements big refactors itself — that would bypass exactly the ticket-scoped review gates (codex loop, human PR review) that make the workflow trustworthy.

This audit covers what the rest of the toolchain doesn't: the living docs, the coverage-debt ledger, and dependencies. Code health belongs to `improve-codebase-architecture` and tracker hygiene to `triage` (Matt Pocock's skills) — don't duplicate them here.

Maintenance: $ARGUMENTS

## Prerequisites - Read First

1. @docs/ARCHITECTURE.md - Current as-built architecture
2. @docs/charter.md - Stable intent
3. The ADRs and the glossary — at the locations the domain-layout contract (`docs/agents/domain.md`) declares
4. The newest report in `docs/7-maintenance/` (if any) — check its open findings first

---

## Step 1: Choose Sweeps

**Use the `AskUserQuestion` tool** (multiSelect): which sweeps to run this audit? All three by default; each is independently skippable.

## Step 2: Run the Sweeps

### Sweep A: Docs Drift

Scope: the living docs — ARCHITECTURE.md, the charter, the ADRs, the glossary — plus the process files (`.claude/skills/`).

**Vocabulary**

- Superseded-vocabulary sweep: grep vocabulary retired by superseded/amended ADRs across the living docs — process files included. Every hit must be a dated record, an explicit negation, or a standing lesson.
- Living docs describe only current design — flag anything narrating history outside dated records (CHANGELOG.md, ADRs, and incident notes are exempt: their date is part of their meaning; never retro-edit them).
- A rename pass is **prose only**. Identifiers, script names, and paths are
  code changes — file them as tracker issues, don't do them here.
- Verify a rename by listing what survived, never by trusting the edit.
  Multi-word protections fail silently when the phrase wraps a line, and a
  blanket substitution reads plausibly while meaning something new.

**Structure & claims**

- **Link liveness.** Follow the living docs' pointers and flag any whose
  target no longer resolves — with one standing exemption: **ADR Origin
  lines are never flagged.** Origin citations are historical provenance,
  dated records expected to outlive their targets; a dead origin link is
  correct history, not drift.
- **Line-scoped pointers** (`file.md:94-95`) drift the moment the target is
  edited, and read as precise while pointing at nothing. Replace with a
  named section or entry.
- **A document that summarizes its own body will drift out of agreement with
  it.** Header counts, status preambles, and "current state" summaries
  restating what the sections below already say get updated in one place and
  not the other, and the file then contradicts itself while both halves look
  authoritative. Report the duplicated structure — reconciling the two numbers
  and leaving the arrangement in place only resets the clock.
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
  `bash .claude/skills/lib/docs/check-doc-accretion.sh <file>...`
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

### Sweep B: Coverage Debt

Triage the coverage-debt ledger (`COVERAGE-DEBT.md`, kept alongside the
testing doc): is each line still valid? Is its escape plan still right?

### Sweep C: Dependencies

- Outdated packages, security advisories, pin/lockfile hygiene

## Step 3: Write the Findings Report

Create `docs/7-maintenance/MAINT_<YYYY-MM-DD>.md`, dated in its header. This is a dated record: **"looked, found nothing" is a valid and required entry per sweep.** Skipped sweeps are recorded as skipped.

Per finding: severity (trivial / substantive), evidence (file:line or command output), disposition (fixed here / routed to tracker / accepted).

## Step 4: Triage & Apply

- **Trivial mechanical fixes** (typo, dead import, stale doc line): apply directly and list them in the report.
- **Substantive findings**: never fix here. File a tracker issue per theme — labeled `backlog` unless the human wants it worked now — and record the issue number in the report as the finding's disposition.
- **Process findings** (a skill is wrong): file separately against the ADDW repo — skills change via dedicated process commits, never inside an audit fix.

## Step 5: Ship the Audit

The audit ships like everything else: as a PR. On a branch off the main branch, review `git status`, stage the report plus any trivial-fix paths **explicitly** (never `git add -A`), and commit. Open a PR whose title parses as a conventional-commit subject (e.g. `chore: maintenance audit 2026-08-07`); the human's merge is the sign-off on the dispositions.

---
name: addw-maintain
description: Periodic maintenance audit - sweep living docs for retirement and dead links, coverage debt, and dependency health; record findings, triage fixes
disable-model-invocation: true
argument-hint: "optional: which sweeps to run (default: all three)"
---

# Maintenance Mode

You are now in **maintenance mode**.

**Audit and triage — not repair.** This skill sweeps the project, records what it finds, applies only trivial mechanical fixes, and routes everything substantive to the tracker as issues. It never implements big refactors itself — that would bypass exactly the ticket-scoped review gates (codex loop, human PR review) that make the workflow trustworthy.

This audit covers what the rest of the toolchain doesn't: documents the tree has moved past, dead pointers, the coverage-debt ledger, and dependencies. Code health belongs to `improve-codebase-architecture` and tracker hygiene to `triage` (Matt Pocock's skills) — don't duplicate them here.

Maintenance: $ARGUMENTS

Run all three sweeps unless the arguments above narrow the scope. The
invocation is the intent — there is no opening ask; a human wanting a narrower
audit says so when invoking.

## Prerequisites - Read First

1. The ADRs, at the location the domain-layout contract (`docs/agents/domain.md`)
   declares, and any proposal documents the project keeps: these are what Sweep A's
   retirement check reads.
2. Prior audits' findings live on the tracker as issues — check the open issues earlier
   audits filed via `bash .claude/skills/lib/tracker/tracker.sh snapshot` (the
   `backlog`-labeled ones and any still-open retirement tickets)

---

## Step 1: Run the Sweeps

### Sweep A: Docs Drift

Two checks, and only two: both find something an install can act on through ADDW's own
tools (ADR 0018). Prose in a project's own docs is the project's to police, and a defect in
`.claude/skills/` is a **process finding** (Step 3), never a Sweep A target.

- **Retirement.** An ADR or proposal untrue *in whole* — a design the tree moved past, a
  proposal whose implementation landed elsewhere, an ADR something has superseded — is
  retired rather than corrected. The test is whether a reader can act on it: a document
  whose reader must diff it against something else to learn which half still holds is one
  of these. Do not delete, edit or archive it here; file it under **Retirement filing** in
  Step 3.
- **Link liveness.** Follow the pointers in the charter, the ADRs, any proposals, the
  glossary and the conventions sources (the files `ADDW_CONVENTIONS` lists), and flag any
  whose target no longer resolves — with one standing exemption: **ADR Origin lines are
  never flagged.** Origin citations are historical provenance, dated records expected to
  outlive their targets; a dead origin link is correct history, not drift. A pointer that
  resolves but names line numbers (`file.md:94-95`) is flagged too: it drifts the moment
  the target is edited and reads as precise while pointing at nothing. Replace it with a
  named section or entry.

### Sweep B: Coverage Debt

Triage the coverage-debt ledger (`COVERAGE-DEBT.md`, kept alongside the
testing doc): is each line still valid? Is its escape plan still right?

### Sweep C: Dependencies

- Outdated packages, security advisories, pin/lockfile hygiene

## Step 2: Keep the Findings List

Keep a findings list as working scratch for this run. It exists because Step 3
files one issue per theme, and a theme across three findings is only visible
with the list in front of you. It is not a committed artifact, and nothing in
`docs/` carries it.

Per finding: severity (trivial / substantive), evidence (file:line or command output), disposition (fixed here / routed to tracker / accepted).

## Step 3: Triage & Apply

- **Trivial mechanical fixes** (typo, dead import, stale doc line): apply directly and list them in the audit commit's message.
- **Substantive findings**: never fix here. File a tracker issue per theme through the tracker layer — never the tracker CLI directly — and record the issue number in the audit commit's message as the finding's disposition:

  ```bash
  bash .claude/skills/lib/tracker/tracker.sh create "<conventional subject>" <body-file> backlog
  ```

  `backlog` unless the human wants it worked now, in which case use `ready-for-agent`. A `backlog` issue is proposed work not yet human-graduated — whether it lacks design, authorization, or both: it carries no `## Parent`, and the frontier skips it until a human act admits it (an explicit re-label, or the merge of a PR naming the filing).
- **Retirement filing**: a document Sweep A found untrue in whole leaves the tree rather than being corrected — and leaves it through a ticket like any other substantive finding, since deleting a file is substantive by any reading. One ticket per document:

  ```bash
  bash .claude/skills/lib/tracker/tracker.sh create "docs: retire <path>" <body-file> backlog
  ```

  The body carries the path, the kind (`adr` or `proposal`), why the document stopped being true, and the command that retires it — `bash .claude/skills/lib/docs/archive-doc.sh <path> <adr|proposal> "<reason>"` — so whoever picks the ticket rediscovers none of the finding. The filing is `backlog` however determined the work: frontier entry is a spending decision that stays human (ADR 0007). The audit record already lists every filing, so the merge of the audit PR is the naming act that graduates these tickets to the frontier — ADR 0007's graduation mechanic. The ticket carries **no `## Parent`**, so it gates no spec's completion and no release. Another detector may file the same document; the duplicate costs one close, which is cheaper than a tracker query to prevent it.
- **Process findings** (a skill is wrong): file separately against the ADDW repo — skills change via dedicated process commits, never inside an audit fix.

## Step 4: Ship the Audit

The audit ships like everything else: as a PR. On a branch off the main branch,
review `git status`, stage any trivial-fix paths **explicitly** (never `git add -A`),
and commit. **The commit message is the audit record.** Its subject is
`chore: maintenance audit <YYYY-MM-DD>` — the exact subject `audit-nudge.sh`
dates the last audit by — and its body carries one line per sweep — run with
findings, run and found nothing, or skipped — plus the issue numbers filed and
the trivial fixes applied.

An audit that applied no trivial fixes has nothing to stage — filing issues
changes the tracker, not the tree — and still commits: `git commit --allow-empty`,
same message contract. The empty commit **is** the audit record, and GitHub
opens a PR on a branch whose only commit is empty, so the sign-off flow is
unchanged.

Open a PR whose title carries the same subject, and **keep the audit on that
single commit** (amend rather than stack): with exactly one commit, the default
squash message is that commit's message, so the record — body included — lands
on the main branch, where `audit-nudge.sh` reads the history. A multi-commit
audit branch risks the merge keeping only the title and discarding the sweep
record. The human's merge is the sign-off on the dispositions.

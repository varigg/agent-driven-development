---
name: addw-maintain
description: Periodic maintenance audit - sweep living-docs drift, coverage debt, and dependency health; record findings, triage fixes
disable-model-invocation: true
argument-hint: "optional: which sweeps to run (default: all three)"
---

# Maintenance Mode

You are now in **maintenance mode**.

**Audit and triage — not repair.** This skill sweeps the project, records what it finds, applies only trivial mechanical fixes, and routes everything substantive to the tracker as issues. It never implements big refactors itself — that would bypass exactly the ticket-scoped review gates (codex loop, human PR review) that make the workflow trustworthy.

This audit covers what the rest of the toolchain doesn't: the living docs, the coverage-debt ledger, and dependencies. Code health belongs to `improve-codebase-architecture` and tracker hygiene to `triage` (Matt Pocock's skills) — don't duplicate them here.

Maintenance: $ARGUMENTS

Run all three sweeps unless the arguments above narrow the scope. The
invocation is the intent — there is no opening ask; a human wanting a narrower
audit says so when invoking.

## Prerequisites - Read First

1. @docs/ARCHITECTURE.md - Current as-built architecture
2. @docs/charter.md - Stable intent
3. The ADRs and the glossary — at the locations the domain-layout contract (`docs/agents/domain.md`) declares
4. Prior audits' findings live on the tracker as issues — check the open issues earlier
   audits filed via `bash .claude/skills/lib/tracker/tracker.sh snapshot` (the
   `backlog`-labeled ones and any still-open retirement tickets)

---

## Step 1: Run the Sweeps

### Sweep A: Docs Drift

Scope: the living docs — ARCHITECTURE.md, the charter, the ADRs, the glossary — plus the process files (`.claude/skills/`).

**Vocabulary**

- **Vocabulary agrees with the active ADRs.** Read the ADRs whose `Status` is
  `active` and check the living docs — process files included — for terms their
  decisions replaced. The superseded ADRs are deliberately *not* the input: they
  have left the tree, and fetching one back would read a document of stale
  present-tense claims into the one session auditing the tree for exactly that.
  Every hit must be a dated record, an explicit negation, or a standing lesson.
- Living docs describe only current design — flag anything narrating history outside dated records (CHANGELOG.md, ADRs, and incident notes are exempt: their date is part of their meaning; never retro-edit a merged one).
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
- **A document untrue *in whole*** — a design the tree moved past, a proposal
  whose implementation landed elsewhere, an ADR something has superseded — is
  retired rather than corrected. The test is whether a reader can act on it: a
  document whose reader must diff it against something else to learn which half
  still holds is one of these. Do not delete, edit or archive it here; file it
  under **Retirement filing** in Step 3.
- Accretion has a cheap measurement:
  `bash .claude/skills/lib/docs/check-doc-accretion.sh <file>...`
  counts a document's version references against its copy at the previous tag.
  A count climbing release over release means the document is narrating its own
  history. Point it at ARCHITECTURE.md and at every runbook — the release step
  runs it on ARCHITECTURE.md only.
- Size has one too:
  `bash .claude/skills/addw-compact/count-tokens.sh docs/ARCHITECTURE.md`
  estimates the document's token count. Over the project's threshold
  (`${ADDW_COMPACT_THRESHOLD:-20000}` tokens, from `docs/addw.env`) it has
  outgrown its budget. Detection ends the sweep's job — compress nothing here; file
  the finding under **Compaction filing** in Step 3. This audit is the
  watchdog, `addw-compact` is the surgeon: the check is mechanical, so a
  script owns it (the ADR 0004 pattern), while the compression is judgment
  and gets its own session.
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

  The body carries the path, the kind (`adr` or `proposal`), why the document stopped being true, and the command that retires it — `bash .claude/skills/lib/docs/archive-doc.sh <path> <adr|proposal> "<reason>"` — so whoever picks the ticket rediscovers none of the finding. The filing is `backlog` however determined the work: frontier entry is a spending decision that stays human (ADR 0007). The audit record already lists every filing, so the merge of the audit PR is the naming act that graduates these tickets to the frontier — the same mechanic the compaction filing below rides. The ticket carries **no `## Parent`**, so it gates no spec's completion and no release. Another detector may file the same document; the duplicate costs one close, which is cheaper than a tracker query to prevent it.
- **Compaction filing**: an oversize ARCHITECTURE.md (Sweep A's size check) files one ticket, carrying its recipe the way retirement tickets carry their `archive-doc.sh` command — the picker rediscovers nothing:

  ```bash
  bash .claude/skills/lib/tracker/tracker.sh create "docs: compact ARCHITECTURE.md" <body-file> backlog
  ```

  The body carries the measured count, the threshold it crossed, and the recipe: run `/addw-compact`. The filing is `backlog`, and its number goes in the audit record like every other filing — which is exactly what graduates it: the merge of the audit PR whose record lists the filing is the human act that admits it to the frontier (ADR 0007's graduation mechanic). Another audit may find the document still oversize and file again; the duplicate costs one close.
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

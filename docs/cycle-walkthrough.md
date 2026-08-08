# A Guided Tour of One ADDW Cycle

This is the human-facing walkthrough of a full **spec → tickets → per-ticket PR → release**
cycle: what happens at each step, what you will be asked, and what lands where. It narrates
the shape of the process — the rules themselves live in the skill files, which remain the
single source of truth. Every pointer below names a skill file and a section heading inside
it; when you want the exact rule, follow the pointer. If a pointer no longer resolves, the
skill changed — fix the pointer here, never copy rule text into this guide.

Paths are given relative to this repo (`skills/...`). In an installed project the same files
live under `.claude/skills/...`.

**Before any cycle**: `addw-init` has run once, on top of Matt Pocock's
`setup-matt-pocock-skills`. His setup configures the tracker (GitHub — the overlay is
GitHub-only) and the domain layout; ADDW's init adds the living docs (ARCHITECTURE.md,
charter.md, TESTING.md), the project config `docs/addw.env`, the `spec` and `backlog` labels,
and the ADR template, then gates on doctor (`addw-init` § *Step 2: Generate — ADDW's
artifacts only*). Skills are never edited per project; everything project-specific lives in
those files.

**Where the work lives**: on the tracker, as GitHub issues — not in this tree. There are no
plan documents and no backlog file. A spec issue carries the `spec` label; its tickets cite
it in a `## Parent` section and list their blocking issues under `## Blocked by`; undesigned
ideas carry `backlog` and no parent.

---

## Phase 1 — Align & Specify (Matt's skills)

ADDW owns none of this phase, and that is the point of the overlay: `grill-with-docs`
interviews you toward a shared understanding — uncapped and incremental, where ADDW's
retired plan skill was capped and batched — and `to-spec` publishes the result as a **spec
issue** on GitHub.

No implementation code is written here, and the phase's own artifact is an issue rather than
a file. Documentation can still land, though: alignment is where `domain-modeling` sharpens
the glossary, and a decision settled before any spec issue exists is recorded as an ADR with
the `design session` origin — origins are never backfilled, so the spec issue published
afterwards references those ADRs in the forward direction rather than the other way round.

---

## Phase 2 — Spec Review (`/codex-spec-review`)

A different model reviews the spec **before** you invest in decomposition, because a design
flaw is cheapest to fix while the spec is still prose (§ *Execution*).

1. **The issue body becomes the working buffer.** The adapter dumps the spec into per-issue
   state that doubles as the edit vehicle, and refuses to start or resume against a buffer
   that has drifted from the remote body — unpushed edits are a real way to review the wrong
   text (§ *Notes*).

2. **Rounds converge on a verdict tag** — `APPROVED` / `REQUEST_CHANGES` / `NEEDS_REWORK`.
   You fix legitimate findings, push back on incorrect ones with notes, and resume
   (§ *Loop Shape*).

3. **Fixes land in the issue body in place; only the final verdict is posted as a comment.**
   The spec stays readable — a reader sees the current spec, not an archaeology of rounds.

The skill also applies the `spec` label, since Matt's `to-spec` applies only the triage
label.

---

## Phase 3 — Ticket (Matt's skills)

`to-tickets` decomposes the reviewed spec into tracer-bullet issues with blocking edges. Its
template's section encoding **is** ADDW's tracker contract, so his skills produce
contract-valid tickets unmodified — nothing is post-processed.

From here on, the question "what can I work on?" has a deterministic answer, the **frontier**:
open issues labeled `ready-for-agent`, not labeled `spec` or `backlog`, whose every blocker is
closed **as completed**.

```bash
bash skills/lib/tracker/tracker.sh frontier
```

Close reasons carry consequences for dependents, which is why the distinction is enforced:
*completed* means what dependents needed now exists — including a ticket made obsolete by an
unrelated change and closed with an explanation — while *not planned* means it never will, so
its dependents never unlock and the listing flags them for you to re-scope.

---

## Phase 4 — Implement, one ticket per session (`/addw-implement`)

Invoked bare, it lists the frontier and stops (§ *Bare Invocation — the Frontier*). Invoked
on a ticket, **mode detection comes first**: an open PR for that ticket means you are
resuming to address review feedback, not rebuilding (§ *Step 1: Mode Detection*). Getting
that backwards restarts finished work.

The fresh-build path (§ *Mode B: Fresh Build*):

1. **Eligibility, read-only.** Open, `ready-for-agent`, not a spec or backlog issue, every
   blocker closed as completed. Nothing is written until the ticket is confirmed workable
   (§ *Step 2: Eligibility — read-only*).

2. **Branch and self-assign, pushed before any build work.** Not a lock — the in-progress
   marker the frontier listing shows, so a second session can see the work exists
   (§ *Step 3: Branch and Self-Assign*).

3. **Frozen contract tests**, if the ticket touches the critical-path floor (auth, deletion,
   persistence, cost, external request shape). Written now, confirmed failing for the right
   reason, committed, and **off-limits to the implementer** (§ *Step 5: Frozen Contract
   Tests*). Work outside that floor is tested in the gate instead.

4. **Implementation via a role key.** `ADDW_IMPLEMENT_SKILL` in `docs/addw.env` names the
   adapter — `codex-implement` by default — or the reserved value `inline`, meaning the main
   agent drives `tdd` itself (§ *Step 6: Implementation*). Either way the main agent reads
   the full diff afterwards and fixes problems directly, never ping-ponging fixes back to the
   adapter.

5. **Cold pre-filter review** — a two-axis `code-review` over the branch diff, run before
   spending codex rounds, to break the ownership bias of reviewing your own work
   (§ *Step 7: Cold Pre-Filter Review*). Skippable by judgment for a trivial diff, but the
   skip is **disclosed in the PR body**.

6. **Doc impact now, not at release.** A ticket that changed documented design updates the
   affected living-doc passages in its own PR, so docs are reviewed alongside the code that
   changed them (§ *Step 8: Doc Impact*).

7. **The deterministic gate**, green before cross-model review starts (§ *Step 9: Testing
   Gate*). `skills/lib/gate/gate.sh` runs the lint / typecheck / affected-tests recipes from
   `docs/addw.env` and emits **one summary line**, carried verbatim into the PR body.
   Choosing which tests are affected stays judgment; running them and reporting the result is
   mechanical. Coverage discipline — the mock-pain tripwire, the coverage-debt ledger, and
   the critical-path floor that debt may never defer — lives in the same section.

8. **The codex code-review loop**, over the full merge-base-to-working-tree diff with the
   ticket and its parent spec as context, capped at five rounds (§ *Step 10: Codex Code
   Review Loop*; adapter mechanics in `skills/codex-code-review/SKILL.md` § *Loop Shape*,
   findings judged against `skills/codex-code-review/checklist.md`). **The final round runs
   against a fully committed HEAD**, and that SHA is what the verdict covers.

9. **Open the PR and stop** (§ *Step 11: Open the PR*). The agent does not merge and does not
   start another ticket. The title must parse as a conventional-commit subject, because it
   becomes the squash subject on `main` and the changelog projects exactly those subjects.

**You review and merge on GitHub.** The PR body carries seven things so you can judge without
archaeology: the `Closes #n` link, the gate summary verbatim, the codex verdict with round
count and covered SHA, any skip disclosures, the doc-impact note, a prose summary, and a merge
recommendation (§ *PR Body Contract*). Squash is the default; rebase-merge is recommended only
when the branch's commits are each individually substantive *and* conventionally titled.

If you leave feedback, invoking the skill on that ticket again resumes into
§ *Mode A: Review-Comments Resume* — which reads both the timeline **and** the inline diff
comments, since no `gh pr` subcommand exposes the latter.

---

## Phase 5 — Release (`/addw-release`)

Readiness is detected when you invoke the skill, never by tracker automation; the frontier
listing also surfaces release-ready specs so you notice at your next session
(§ *Step 1: Mode and Readiness*).

1. **Two modes.** A **spec release** names a release-ready spec — every issue citing it as
   parent closed as completed, and at least one child existing, since a spec with no children
   was never decomposed. Naming an incomplete spec is refused with its open tickets listed. A
   **repository release** tags whatever `main` has accumulated since the last tag and closes
   nothing. A child closed as *not planned* is surfaced by name and you decide whether to
   proceed — your confirmation is the waiver.

2. **Version and changelog, both derived** (§ *Step 2: Derive the Version and the Entry*).
   `skills/lib/release/derive.sh` reads the conventional-commit subjects since the last tag —
   feat → minor, fix → patch, breaking → major — and projects the entry from those same
   subjects. Release commits are excluded; an unclassifiable subject is **warned and listed,
   never silently dropped**. No agent-authored prose, so nothing can drift from history.

3. **A release PR, and your merge is the confirmation** (§ *Step 3: The Release Branch*,
   § *Step 4: Open the Release PR*). This is what keeps "every commit on `main` is a reviewed
   PR" true with zero routine exceptions.

4. **The post-merge tail** — tag, push, GitHub Release carrying the identical changelog text,
   and for a spec release, closing the spec issue (§ *Step 5: The Post-Merge Tail*). It is
   re-runnable: each step skips what is already done.

5. **A verification sweep** over the living docs — vocabulary, accretion, charter fit — as a
   backstop, not a bulk rewrite (§ *Step 6: Verification Sweep*). Reconciliation is small
   here precisely because Phase 4 step 6 already did it per ticket.

---

## Around the cycle

Not part of the cycle, but reachable from it:

- **`addw-maintain`** — the periodic audit, on cadence rather than as a pipeline phase. Three
  skippable sweeps (living-docs drift, coverage debt, dependencies); substantive findings are
  never fixed in place but filed as tracker issues (§ *Step 4: Triage & Apply*), and the
  audit itself ships as a PR (§ *Step 5: Ship the Audit*).
- **`addw-hotfix`** — genuine emergencies only: a gate-verified fix as an expedited PR merged
  immediately (§ *Step 6: Open the Expedited PR*). Direct push to `main` is documented solely
  as the escape hatch for when GitHub itself is the obstacle (§ *Escape Hatch: Direct Push*).
- **`addw-compact`** — shrinks ARCHITECTURE.md when it outgrows its token budget
  (§ *Step 2: Compaction Strategies*).
- **`codex-ask`** — a grounded second opinion on anything. Advisory only: no verdicts,
  nothing gated.

## What lands where

| Artifact | Where it lives | Created by |
|---|---|---|
| Spec | A `spec`-labeled GitHub issue | `to-spec`, reviewed by `codex-spec-review` |
| Tickets | GitHub issues with `## Parent` / `## Blocked by` | `to-tickets` |
| Undesigned ideas | `backlog`-labeled issues, no parent | you, or `addw-maintain` |
| Implementation | One squash-merged PR per ticket | `addw-implement` |
| Decisions | Write-once dated ADRs in `$ADDW_ADR_DIR` | the ticket's own PR, or alignment (origin `design session`) |
| Glossary / domain docs | The layout `docs/agents/domain.md` declares | `domain-modeling`, during alignment |
| Version + changelog | A release PR, then a tag and GitHub Release | `addw-release` |
| Audit reports | `docs/7-maintenance/MAINT_<date>.md`, via a PR | `addw-maintain` |

## Every question you'll be asked

The cycle is autonomous between these checkpoints. Two of them are merges rather than
prompts, which is the design: a merge is a decision with a record.

1. Alignment interview — uncapped and incremental (`grill-with-docs`)
2. Spec-review findings you adjudicate — per round, to convergence (`codex-spec-review`)
3. **Your review and squash-merge of each ticket PR** (`addw-implement` § *Step 11: Open the PR*)
4. Release mode, when readiness is ambiguous (`addw-release` § *Step 1: Mode and Readiness*)
5. Whether to proceed past a child closed as *not planned* (`addw-release` § *Step 1: Mode and Readiness*)
6. **Your merge of the release PR** — the version confirmation (`addw-release` § *Step 4: Open the Release PR*)

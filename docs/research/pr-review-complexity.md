# Diagnose PR review complexity

> **Path note:** there is no existing research-notes convention in this repo
> (confirmed: no `docs/research/` directory prior to this file). This path —
> `docs/research/<topic>.md` — is the sensible default for a wayfinder
> research ticket's findings and is used here for that reason, not because a
> convention pointed at it.

Wayfinder research ticket: [#84](https://github.com/varigg/agent-driven-development/issues/84)
("Diagnose PR review complexity"), tracked under the map issue
[#82](https://github.com/varigg/agent-driven-development/issues/82).

## Question

Why are ADDW (the agent-driven development workflow defined by this repo's
`skills/`) PRs harder to review than they should be?

## Method

1. Pulled all 32 merged PRs on `varigg/agent-driven-development`
   (`gh pr list --state merged --json number,title,additions,deletions,changedFiles,body`)
   and computed diff-size and file-count statistics.
2. Read full bodies and, for several, full diffs (`gh pr view <n> --comments`,
   `gh pr diff <n>`) for the smallest, largest, and several typical/median
   PRs, plus two tickets behind large PRs.
3. Located the two other ADDW installs reachable read-only
   (`/home/varigg/code/adventure-library`, `/home/varigg/code/raytracer_challenge`),
   confirmed their GitHub remotes, and sampled their merged PRs the same way.
4. Read `skills/addw-implement/SKILL.md` (PR Body Contract, step structure,
   Doc Impact step), `skills/codex-implement/SKILL.md`, `skills/addw-maintain/SKILL.md`,
   and `docs/cycle-walkthrough.md`'s decomposition phase, plus the two
   tickets (`#9`, `#11`) behind the two largest PRs, to see how tracer-bullet
   ticket sizing and the implement flow's steps shape what lands in one PR.

## Headline numbers (32 merged PRs, this repo)

| Metric | Mean | Median | Max | Min |
|---|---|---|---|---|
| Total diff (add+del) | 365 | 263 | 1391 (#25) | 11 (#81, #21) |
| Files changed | 7 | 4 | 37 (#26) | 1 (#81, #23) |

The median PR (263 lines / 4 files) is unremarkable to review. The mean is
pulled up by a top quartile — `#22`, `#24`, `#25`, `#26`, `#32` — of
800–1400-line, 9–37-file PRs. **Review difficulty in this repo is concentrated
in a subset of large PRs, not a uniform property of all ADDW PRs.**

## Cross-repo sample (context, not primary evidence)

- `adventure-library` (remote `git@github.com:varigg/adventure-library.git`,
  `.claude/skills/addw-*` installed): only **2** merged PRs exist. One,
  [`adventure-library#12`](https://github.com/varigg/adventure-library/pull/12),
  is a one-off schema-3→5 migration (3894+12230 lines, 138 files) — not
  representative of a typical ticket PR. The other,
  [`adventure-library#23`](https://github.com/varigg/adventure-library/pull/23),
  is a normal-sized docs PR (387+7, 4 files). Sample too small to weigh
  independently; included for completeness.
- `raytracer_challenge` (remote `git@github.com:varigg/raytracer_challenge.git`,
  ADDW skills installed but **not used** for its 4 merged PRs) runs a
  different, non-ADDW workflow (Matt Pocock's "superpowers" plan files under
  `docs/superpowers/plans/`) — no `Closes #`, no Gate line, no Codex verdict
  in any of its PR bodies (checked `raytracer_challenge#1` and `#4`). Its PRs
  are large (up to 1517+141 across 23 files) but are evidence about a
  different workflow, not about ADDW, and are excluded from the ranking
  below.

Given this, the primary evidence base is this repo's own 32 PRs — which is
appropriate, since they were all produced by `addw-implement`/`codex-implement`
against the exact skills under test.

## Evidence per hypothesis

### H1 — missing refactoring step inside the implement flow

**Not supported as stated.** `skills/addw-maintain/SKILL.md:12` is explicit:
*"Audit and triage — not repair… It never implements big refactors itself —
that would bypass exactly the ticket-scoped review gates (codex loop, human
PR review) that make the workflow trustworthy."* Maintenance sweeps route
code-health findings to the tracker as new tickets, which then go through the
same `addw-implement` gates as any other ticket — there is no cadence under
which unreviewed "mess" accumulates and rides a later feature PR unreviewed.

What the evidence *does* show is a related but different mechanism: legitimate
scope decisions discovered **mid-implementation** get folded into the current
PR rather than split into a new ticket, because Step 6 of
`skills/addw-implement/SKILL.md` instructs "read the full diff yourself… and
fix problems directly — never ping-pong fixes back to the adapter," and the
flow is one-ticket-per-session. Two concrete, self-disclosed instances:

- [`#32`](https://github.com/varigg/agent-driven-development/pull/32)'s body:
  *"The tracker seam grew a `create` verb — unasked-for surface, and your
  call… The spec axis flagged it as scope creep, correctly."* This decision,
  its ADR (`0002`), and its new test file all rode PR #32 rather than a
  follow-up ticket.
- [`#25`](https://github.com/varigg/agent-driven-development/pull/25)'s body:
  rounds 6–7 of the codex loop reviewed "two design reversals the human made
  after that verdict" — first replacing a probe with a roster check, then
  "removing the dependency gate entirely," a −211-line change described as
  "the largest thing in this PR to judge."

The flow does have an escape valve for deferring non-blocking findings:
[`#12`](https://github.com/varigg/adventure-library/pull/12)'s body (and
`agent-driven-development` PR bodies generally) shows follow-up issues filed
instead of expanding scope (e.g. `agent-driven-development#76` filed from
PR #25 for a gap that didn't need fixing in-PR). So the mechanism is real but
partial — the flow encourages deferral, and sometimes uses it, but a
substantive design decision discovered mid-ticket is, by design, resolved and
merged inside the current PR rather than always split off.

### H2 — tickets sliced too big at spec-decomposition time

**Best-supported cause.** `docs/cycle-walkthrough.md:67`: `to-tickets`
"decomposes the reviewed spec into **tracer-bullet issues** with blocking
edges" — an explicit design choice to produce vertical, end-to-end slices
rather than narrow, single-concern tickets. The two tickets behind the two
largest PRs bear this out:

- [`#9`](https://github.com/varigg/agent-driven-development/issues/9) ("slim
  addw-init and extend doctor"), behind
  [`#25`](https://github.com/varigg/agent-driven-development/pull/25)
  (1391 lines, 9 files): its acceptance criteria bundle init verifying Matt's
  setup, validating tracker config, generating five separate artifact kinds,
  *and* doctor re-verifying config keys, docs contract, recipe keys, labels,
  tracker validation, and role adapters — six checkable concerns in one
  ticket.
- [`#11`](https://github.com/varigg/agent-driven-development/issues/11)
  ("rewrite addw-release"), behind
  [`#24`](https://github.com/varigg/agent-driven-development/pull/24)
  (1323 lines, 16 files): bundles readiness verification, a release-branch
  version bump, a changelog generator, a release PR, *and* a re-runnable
  post-merge tail script — five deliverables in one ticket.

Every PR over ~800 lines in the top quartile (`#22`, `#24`, `#25`, `#26`,
`#32`) traces to a ticket/spec whose title or acceptance criteria list
multiple deliverables ("modes, release PR, mechanical tail"; "schema
migration and docs reconciliation"). The median ticket, by contrast, produces
a 263-line, 4-file PR — this is not "all tickets are too big," it's that the
tracer-bullet philosophy allows ticket breadth to vary widely, and the wide
ones are disproportionately hard to review.

### H3 — codex-implement produces sprawling diffs

**Not supported.** Inspecting `#25`'s full diff (`gh pr diff 25`) shows 30
commit-level diff hunks touching only **9 distinct files** — the size comes
from one new 335-line test file and a near-total rewrite of one `SKILL.md`
(303+385 lines, described in the PR body as "about 40% shorter than what it
replaces"), not from scatter across unrelated files. No file-level evidence of
codex-implement touching code outside a ticket's stated scope was found in
any sampled PR.

Separately, this repo's `docs/addw.env` sets no `ADDW_IMPLEMENT_SKILL`
override, so `codex-implement` is the default — yet two sampled PRs
(`#32`, `#61`) explicitly disclose implementing **inline** instead, by
deliberate choice, for prose-heavy tickets ("the ticket is mostly narrative
prose… which the adapter's sandbox cannot do"). Diff size in this sample
tracks ticket content (prose rewrites, new test suites) rather than which
implementer produced it.

### H4 — the PR Body Contract buries review signal in boilerplate

**Refuted as literally stated, but a related cost is real.** The seven
sections in `skills/addw-implement/SKILL.md`'s "PR Body Contract" are not
filler: reading the sampled bodies (`#81`, `#21`, `#24`, `#25`, `#32`, `#61`,
`#72`) shows the "Disclosures" and "What changed" sections consistently carry
specific, load-bearing information (scope decisions, git-archaeology on where
a stale claim originated, contract-test edits and why) that a reviewer
genuinely needs — the opposite of boilerplate.

What the data does show is that **body length correlates only weakly with
diff size**, which is itself a review-complexity driver independent of code
volume:

| PR | Diff (add+del) | Body word count |
|---|---|---|
| [`#81`](https://github.com/varigg/agent-driven-development/pull/81) | 11 | 255 |
| [`#61`](https://github.com/varigg/agent-driven-development/pull/61) | 16 | 859 |
| [`#72`](https://github.com/varigg/agent-driven-development/pull/72) | 74 | 917 |
| [`#14`](https://github.com/varigg/agent-driven-development/pull/14) | 308 | 250 |
| [`#25`](https://github.com/varigg/agent-driven-development/pull/25) | 1391 | 1134 |

`#61` is a 16-line, 4-file wording fix whose body is 859 words of genuine
git-archaeology (`git log -S` tracing a stale sentence through `#25` and ADR
0003) needed to justify the change — real signal, but a reviewer must read
nearly a page to approve four lines of prose. `#72` is a release PR whose
length comes from embedding the full multi-version changelog, which is
appropriate to a release PR's job and not comparable to a ticket
implementation PR. The contract's seven mandatory sections impose a **reading
floor that does not shrink with the diff**, so a reviewer's time cost tracks
"how much happened during implementation" more than "how many lines
changed" — a real but different complaint than "boilerplate."

## Ranking

1. **Ticket decomposition breadth (H2)** — the strongest, most direct cause.
   The tracer-bullet decomposition style intentionally produces
   variable-width tickets, and the widest ones (bundling several
   independently-checkable deliverables into one acceptance-criteria list)
   are exactly the PRs that take 800–1400 lines across 9–37 files to close.
   This is a decomposition-time decision, fully within `to-tickets`' control,
   and it is the one lever that would most directly shrink the worst PRs.
2. **Mid-implementation scope decisions resolved in-PR (refines H1)** — real
   and self-disclosed in multiple PRs (`#25`, `#32`), but the flow already has
   a partial escape valve (follow-up tickets) and a stated principle (fix
   directly rather than ping-pong) that make some of this bundling
   deliberate and defensible, not accidental sprawl. Ranks below H2 because
   it explains specific large PRs rather than the general size distribution.
3. **PR Body Contract's fixed reading floor (qualified H4)** — a genuine,
   evidence-backed cost, but secondary: it makes small PRs read longer than
   their diff would suggest, not the reverse. It does not explain why the
   large PRs are large; it explains why even the small ones aren't free.
4. **H1 as literally stated (accumulated mess via missing refactor cadence)**
   — not supported; `addw-maintain` explicitly refuses to repair, routing
   findings to tracker tickets that go through the same review gates as any
   other work.
5. **H3 (codex-implement sprawl)** — not supported; sampled large diffs are
   topically concentrated, and codex-implement is not even always the
   implementer used.

## What evidence would change this ranking

- A larger sample of ADDW-install PRs from a project with many more merged
  tickets than `adventure-library`'s two would test whether this repo's
  meta/self-referential nature (building the workflow, not using it on
  unrelated application code) inflates its own PR sizes unusually. If a
  downstream install with dozens of merged tickets showed the same wide
  variance tied to ticket breadth, H2 would be confirmed further; if it
  instead showed uniformly large PRs regardless of ticket scope, that would
  point back toward the implement flow itself (H1/H3) rather than
  decomposition.
- Evidence that `addw-maintain` sweeps in practice sit unaddressed for many
  cycles before surfacing inside an unrelated ticket's PR (rather than being
  filed and picked up on their own frontier slot) would resurrect H1 as
  stated.
- A sampled PR where `codex-implement`'s diff touched files outside the
  instruction block's stated scope would support H3; none was found in this
  sample.
- If reviewers (the human merging these PRs) reported that the "Disclosures"
  section specifically, rather than sheer body length, was where they lost
  time, that would elevate H4 over its currently qualified/secondary
  position.

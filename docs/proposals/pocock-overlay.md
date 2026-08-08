# Proposal: Rebuild ADDW as an Overlay on Matt Pocock's Skills

**Status**: implemented (2026-08-07) — built out as
[spec issue #2](https://github.com/varigg/agent-driven-development/issues/2),
which is the design's authoritative statement and supersedes this document
wherever the two differ
**Date**: 2026-08-05
**Origin**: comparison of ADDW against
[mattpocock/skills](https://github.com/mattpocock/skills) ("Main Flow":
grill-with-docs → to-spec → to-tickets → implement → code-review). The
comparison found the two systems strong in disjoint places, and found ADDW
spending significant process mass policing failure modes that Matt's
tracker-first design dissolves outright.

## Problem

ADDW currently owns the whole pipeline: alignment interview, plan document,
implementation orchestration, review, release, maintenance. Three of those it
does worse than Matt's freely available skills:

- **Alignment**: addw-1's discovery step caps clarification at 3 batched
  `AskUserQuestion` rounds. Matt's `/grilling` is uncapped, one question at a
  time, with a recommended answer per question — and `/grill-with-docs` builds
  a `CONTEXT.md` glossary and ADRs inline as terms resolve. ADDW has no
  shared-language mechanism at all.
- **Decomposition**: addw plans are sequential phases inside one document.
  Matt's `/to-tickets` produces tracer-bullet tickets (narrow vertical slices,
  each demoable alone, each fitting one context window) with native blocking
  edges on a real tracker, enabling parallel frontier work. `/wayfinder`
  covers foggy long-horizon work ADDW cannot plan at all.
- **Work-item state**: ADDW keeps plans, checkboxes, and backlog in-repo.
  A large fraction of addw-4-maintain's docs-drift sweep exists to police the
  pathologies of exactly that choice (closed entries burying open ones,
  phantom tasks, durable docs citing transient files). GitHub issues dissolve
  the problem class instead of auditing it.

Conversely, Matt's flow has gaps ADDW closes:

- `/code-review` presents findings and stops — no fix-and-re-review loop, no
  severity gate before commit, and both sub-agents are the same model. ADDW's
  codex loops have real convergence semantics
  (`REQUEST_CHANGES → fix → resume → APPROVED`, round caps, implementer
  pushback notes) and a genuinely different model.
- Specs are never reviewed before the user invests in them; ADDW reviews
  plans adversarially pre-presentation.
- No testing gate, no frozen contract tests, no coverage-debt ledger, no
  deterministic verification scripts (his repo explicitly refuses a setup
  verify mode), no release/versioning step, no living-docs upkeep beyond the
  glossary.

## Proposal

Assume Matt's skills are installed globally (Claude Code plugin) and reuse
them. ADDW stops being a parallel pipeline and becomes an **overlay**: Matt's
skills are the head and hands (alignment, decomposition, implementation
discipline); ADDW supplies the **adversary** (cross-model review), the
**gate** (deterministic verification, testing gate), and the **ship
discipline** (living docs, release). Work-item state moves to GitHub issues.

### Division of labor

| Concern | Owner | Skills |
| --- | --- | --- |
| Alignment, shared language | Matt | `grill-with-docs`, `grilling`, `domain-modeling` |
| Specification | Matt + ADDW insert | `to-spec` → spec issue; `codex-spec-review` loop before ticketing |
| Decomposition | Matt | `to-tickets` (tracer-bullet issues, blocking edges), `wayfinder` |
| Implementation | ADDW wrapper over both | `addw-implement`: contract tests → `codex-implement` (or Matt's `implement`+`tdd`) → gate → `codex-code-review` → PR |
| Human review | GitHub | PR per ticket (new — no equivalent in either system today) |
| Release | ADDW | `addw-release`, fully mechanical |
| Periodic upkeep | Split | Matt: `triage`, `improve-codebase-architecture`; ADDW: `addw-maintain` (slimmed), `addw-compact` |
| Second opinions, emergencies | ADDW | `codex-ask`, `addw-hotfix` |

### The flow

1. **Setup** — `/setup-matt-pocock-skills` once (tracker = GitHub, labels,
   domain layout), then slimmed `addw-init`: generate ARCHITECTURE.md, charter
   interview, TESTING.md, write `addw.env`. `doctor.sh` remains the final
   gate. `CONTEXT.md` joins the living-docs set.
2. **Align & specify** — `/grill-with-docs`, then `/to-spec` publishes the
   spec as a GitHub issue. **ADDW insert**: `codex-spec-review` (retargeted
   `codex-plan-review`) runs its convergence loop against the spec before
   ticketing; verdict lands as an issue comment. Specs follow Matt's
   no-file-paths rule, so `check-plan-files.sh` retires — staleness avoided
   rather than verified.
3. **Decompose** — `/to-tickets` → tracer-bullet issues with blocking edges.
   `docs/1-plans/`, `docs/backlog.md`, and plan checkboxes retire; the
   tracker holds work state. `/wayfinder` for foggy work, feeding `to-spec`.
4. **Implement per ticket** — `addw-implement`, the thin wrapper that closes
   the loop Matt leaves open. Per frontier ticket: branch from main; frozen
   contract tests for critical paths (committed first, implementer forbidden
   to modify); implementation via `codex-implement` (default) or Matt's
   `/implement` + `/tdd` inline (role key in `addw.env` chooses);
   self-review with checkpoint commits; testing gate (lint / typecheck /
   affected tests, green before review); `codex-code-review` convergence loop
   as exit gate; open the PR.
5. **Human review & merge** — on GitHub, out-of-band (see below).
6. **Release** — mechanical, triggered by spec completion (see below).
7. **Periodic** — `/triage` (tracker), `/improve-codebase-architecture`
   (code), `addw-maintain` slimmed to what those don't cover: docs-drift over
   the living docs only (ARCHITECTURE.md, charter, ADRs, CONTEXT.md —
   worklist-pathology rules deleted with the worklists), coverage-debt
   triage, dependencies.

### Decided: commit → merge → release → tag (2026-08-05)

- **PR per ticket.** The codex review loop converges **before** the PR opens
  — machine review filters, human review decides on a pre-cleaned diff. The
  PR body carries the ticket link (`Closes #N`), the gate summary, and the
  codex verdict with round count; this replaces the changelog's Review line.
  The agent's flow ends at "PR open"; addressing human review comments is a
  session resume against the branch.
- **Squash merge by default, judgment per PR.** A tracer ticket ≈ an old
  ADDW phase, so one conventional commit per ticket preserves today's
  effective granularity on main; checkpoint commits stay visible in the PR.
  When branch commits are individually substantive, the agent recommends
  rebase-merge instead. Not a hard rule.
- **No stacked PRs.** The frontier requires **merged** blockers. Squash
  merges make stacking painful (rebase --onto after every base squash), and
  the reviewer and the person waiting are the same human — the unblock is
  "go review the pending PR".
- **Release on spec completion** (last ticket merges), on-demand always
  available. Version is decided at release time from conventional-commit
  prefixes since the last tag (`feat:` → minor, `fix:` → patch, breaking →
  major), agent proposes, human confirms. Version-in-plan-filename
  (`F_x.y.z_*`) dies with the plan files.
- **Changelog is a projection of git history, not an authored document.**
  A script derives the entry from squash-commit subjects between tags (the
  PR titles the human already approved at merge), prepends `CHANGELOG.md`,
  and publishes the same text as a GitHub Release on the tag. The agent
  writes no prose — authored entries invite drift. Platform-independent
  (git-only derivation), history in both places.
- **Doc reconciliation is hybrid.** Tickets that change documented design
  update the affected ARCHITECTURE.md / living-doc passages **in their own
  PR** — human-reviewed alongside the code that caused them. The release
  keeps only the verification sweep (vocabulary grep, accretion probe,
  charter check) as backstop for tickets that misjudged their doc impact.
  Staleness window is bounded at one spec.

### Decided: the `addw-implement` contract (2026-08-05)

**Invocation**: `addw-implement <issue-number>`; bare invocation lists the
current frontier (open tickets whose blockers are all closed) and asks. First
act: self-assign the ticket (claim-before-work), read ticket + parent spec.

**Mode detection**: an existing open PR for the ticket means
**review-comments resume** — read the human's PR comments, address them,
re-run the gate, push. Otherwise fresh build:

1. **Branch** from main: `feat/<issue-number>-<slug>`.
2. **Frozen contract tests** — unchanged critical-path-floor rule; seams come
   from the spec's Testing Decisions; committed first, implementer forbidden
   to modify.
3. **Implement** via `ADDW_IMPLEMENT_SKILL`. Default `codex-implement`:
   target = issue number (thread key), context assembled by dumping
   ticket + spec bodies via `gh` to a file. Inline alternative: main agent
   drives Matt's `/tdd` directly — never his `/implement` (his own invocation
   rule: skills may invoke model-invoked primitives, not user-invoked
   orchestrators, and `/implement`'s review-and-commit tail collides with the
   gate).
4. **Self-review = Matt's `/code-review` as pre-filter.** Cold two-axis
   same-model review (Standards + Spec) replaces freeform diff-reading,
   which suffered ownership bias — the orchestrator reviewing the diff it
   just watched land. Main agent fixes findings (supplying the closure
   Matt's flow lacks), checkpoint commits. Codex rounds are then spent only
   on what a different model can see. The codex loop remains the exit gate —
   this changes the pre-filter slot, not the authority.
   **Skippable by judgment + disclosure** (token economy on trivial
   changes): skip when the diff is trivial — small, no critical-path-floor
   contact, no doc impact — and record `pre-filter: skipped — trivial` in
   the PR body's review line, mirroring the plan-review skip rule. Safe
   because two nets remain below every skip: the mandatory codex loop and
   human PR review.
5. **Testing gate** — unchanged; green before any cross-model review.
6. **`codex-code-review` loop** — unchanged convergence semantics, target =
   issue number.
7. **Doc-impact check** — if the slice changed documented design, update the
   affected living-doc passages now so they ride in this PR (hybrid
   reconciliation).
8. **Open the PR** — push branch, `gh pr create`: `Closes #N`, gate summary,
   codex verdict + rounds, doc-impact note, merge recommendation (squash, or
   rebase-merge with a one-line reason). **Stop.** One ticket per session;
   the next frontier ticket gets a fresh window.

### Decided: `codex-spec-review` mechanics (2026-08-05)

Resolved by the same mechanism as implement's step 3: the adapter fetches the
spec issue via `gh issue view --json title,body` into a context file; thread
state keys on the issue number; fixes during the loop edit the issue body in
place (`gh issue edit`), mirroring today's edit-the-plan-file-in-place; only
the **final** verdict + round count is posted as an issue comment —
round-by-round implementer notes stay in adapter state so the issue stays
readable.

### Decided: deterministic testing gate + init scope (2026-08-05)

The gate flagged in [determinism.md](determinism.md) as "not recommended yet"
is adopted by the rewrite — the objections died with it: the schema bump
happens anyway, the gate now runs per ticket build and per review resume,
and its summary lands in PR bodies where the mechanical-over-authored
principle (changelog decision) applies. Init writes `ADDW_RECIPE_LINT` /
`ADDW_RECIPE_TYPECHECK` / `ADDW_RECIPE_TESTS_AFFECTED` (command template
taking test paths) alongside TESTING.md's prose; `gate.sh` runs the ladder
and emits the summary verbatim. Affected-test *selection* stays agent
judgment; execution and reporting become mechanical.

Slimmed `addw-init` is thereby fully specified: run
`/setup-matt-pocock-skills` (tracker, labels, domain layout), then generate
ARCHITECTURE.md, run the charter interview, write TESTING.md + recipe keys,
write `addw.env`; `doctor.sh` — extended to verify recipe keys — remains the
final gate.

### Decided: plugin dependency — probe, don't pin (2026-08-05)

The programmatic dependency surface is two skills: `code-review`
(pre-filter) and `tdd` (inline mode) — Matt's stable model-invoked
primitives. His user-invoked orchestrators are invoked by the human, not by
ADDW skills, and what ADDW consumes downstream of them is tracker artifacts
whose shape lives in `docs/agents/issue-tracker.md`, which no plugin update
touches. `doctor.sh` probes that the required skill names exist; behavioral
drift is accepted, netted by the codex loop and human PR review. No fork, no
vendoring.

### Skill inventory

| Current | Fate |
| --- | --- |
| `addw-1-plan` | **Retired** — replaced by `grill-with-docs` + `to-spec` + `codex-spec-review` + `to-tickets` |
| `addw-2-implement` | **Rewritten** as `addw-implement` (per-ticket wrapper, ends at PR open) |
| `addw-3-release` | **Rewritten** as `addw-release` (mechanical; no merge step, no authored changelog) |
| `addw-4-maintain` | **Slimmed** — worklist-pathology rules deleted; keeps living-docs drift, coverage-debt, deps |
| `addw-init` | **Slimmed** — delegates tracker/labels/domain to `setup-matt-pocock-skills` |
| `addw-test`, `addw-compact`, `addw-hotfix`, `codex-ask`, `codex-implement`, `codex-code-review` | **Kept** (hotfix adapts to PR model) |
| `codex-plan-review` | **Retargeted** as `codex-spec-review` (reviews a spec issue, not a plan file) |
| `addw-research` | **Retired** in favor of Matt's `research` + `wayfinder`; `codex-ask` red-teaming survives as a standalone habit |

Scripts: `check-plan-files.sh` retires (no file paths in specs).
`check-version-sync.sh` mostly retires (no authored entry to drift).
`prepend-changelog.sh` is absorbed into the release generator.
`audit-nudge.sh`, `check-doc-accretion.sh`, `count-tokens.sh`, `doctor.sh`
stay. New: changelog/release-notes generator, version-bump derivation.

Net: ~8 ADDW skills, none duplicating anything Matt ships.

### Decided: ADR origins may cite spec issues (2026-08-05)

Closed spec issues qualify under the durable-citation rule: dated, never
pruned, numbers never reused — functionally the dated records the rule
already admits. The ADR origin line cites `spec issue #N — title`.
Self-containment discipline is unchanged (evidence restated in the ADR's own
words), so a stranded link on platform migration loses provenance only,
never rationale. The remaining migration work is mechanical: `ADDW_SCHEMA`
bump, UPGRADING.md section (retire `docs/1-plans/` and `docs/backlog.md`,
existing plan-linked ADR origins stay as-is — dated records are never
retro-edited).

### Decided: hotfix = expedited PR + escape hatch (2026-08-05)

Hotfixes go through a PR the human merges immediately — seconds of ceremony,
and main's every-commit-is-a-squash-merged-PR invariant holds (uniform
history, one-commit reverts, changelog as pure projection). Direct push to
main remains documented as the escape hatch for when GitHub itself is the
obstacle (platform down, emergency in the PR/CI machinery); the mechanical
changelog tolerates a stray direct commit since it derives from commit
subjects, not PRs.

## Open questions

None — all design questions resolved 2026-08-05. Next step is
implementation planning: rewrite the skills per the decided contracts above.

# A Guided Tour of One ADDW Cycle

This is the human-facing walkthrough of a full **Plan → Implement → Release** cycle: what
happens at each step, what you will be asked, and what gets committed when. It narrates the
shape of the process — the rules themselves live in the skill files, which remain the single
source of truth. Every pointer below names a skill file and a section heading inside it; when
you want the exact rule, follow the pointer. If a pointer no longer resolves, the skill
changed — fix the pointer here, never copy rule text into this guide.

Paths are given relative to this repo (`skills/...`). In an installed project the same files
live under `.claude/skills/...`.

**Before any cycle**: `addw-init` has already run once, generating the living docs
(ARCHITECTURE.md, charter.md, TESTING.md) and the project config `docs/addw.env`. Skills are
never edited per-project; everything project-specific lives in those files.

---

## Phase 1 — Plan (`/addw-1-plan`)

You describe a feature; the agent produces a reviewed, approved plan document. No code is
written in this phase — not even test code (§ *IMPORTANT: No Code Implementation*).

1. **Context load.** The agent reads ARCHITECTURE.md, charter.md, and the relevant ADRs
   before anything else (§ *Prerequisites - Read First*).

2. **Discovery interview.** Instead of planning immediately, the agent asks you structured
   clarifying questions about scope, behavior, constraints, and priority — at most three
   rounds, after which it proceeds and records its assumptions in the plan
   (§ *Step 1: Discovery & Clarification*).

3. **The plan document** lands in `docs/1-plans/F_<version>_<feature>.plan.md`
   (§ *Step 2: Plan Document Creation*). Three of its sections feed later phases, so they
   are worth reading closely when you review it:
   - **Test Impact** — consumed by the implement phase's testing gate; also decides whether
     tests are written *before* implementation (see Phase 2, step 2 below).
   - **Doc Impact** — the list of living docs this change touches; consumed by the release
     phase's reconciliation sweep.
   - **Open Questions & Assumptions** — what the agent decided without you; surfaced again
     at approval time.

4. **Declared-files check.** A script verifies every path the plan claims to create or
   modify against the real working tree, so the plan can't be written against a remembered
   codebase (§ *Declared-Files Check*).

5. **Codex second-opinion review** runs *before you see the plan* (§ *Step 3: Codex
   Second-Opinion Review*). The reviewer returns a verdict tag (`APPROVED` /
   `REQUEST_CHANGES` / `NEEDS_REWORK`); the agent fixes legitimate findings, pushes back on
   incorrect ones with notes, and loops up to five rounds. The loop mechanics live in
   `skills/codex-plan-review/SKILL.md` (§ *Loop Shape*).

6. **Your review.** You get a summary (approach, files affected, complexity, Codex status,
   open assumptions) and a question: **Approved / Request changes / Needs rework**
   (§ *Step 4: User Review & Validation*).

7. **On approval**, two things may happen before implementation starts:
   - If the plan changes documented intent, the decision is recorded as a write-once ADR,
     committed together with the plan (§ *ADR Writing (on approval)*). Routine conforming
     work writes no ADR.
   - You are asked whether to **start implementation now** or later.

---

## Phase 2 — Implement (`/addw-2-implement`)

The main agent orchestrates; Codex writes the code; the main agent reviews, tests, and
fixes. Writer and reviewer are never the same thread.

1. **Branch.** A dedicated `feat/`- or `fix/`-branch is created without asking
   (§ *Step 0: Create a Branch*). Everything up to the release merge happens on it.

2. **Selective test-first.** Only if the plan's Test Impact touches the critical-path floor
   (auth, deletion, persistence, cost, external request shape) are failing behavioral tests
   written *now*, committed, and declared off-limits to Codex — it must make them pass
   without editing them (§ *Step 0.5: Selective Test-First*). Everything else is tested
   after implementation, in the gate.

3. **Delegation.** The agent re-runs the declared-files check (the tree may have drifted
   since planning), then hands the plan — whole, or one phase at a time — to the
   implementing agent, which reports back with `IMPLEMENTATION_COMPLETE` or
   `IMPLEMENTATION_PARTIAL` (§ *Implementation Phase — Delegate to Codex*; adapter
   mechanics in `skills/codex-implement/SKILL.md`).

4. **Self-review and checkpoint commit.** The main agent reads the full diff against the
   plan and ARCHITECTURE.md conventions, fixes problems directly (no back-and-forth with
   Codex over fixes), then commits the phase with explicit paths and a conventional
   message — never `git add -A`, never "wip", because these commits survive into permanent
   history (§ *Self-Review & Fix*). Multi-phase plans repeat delegate → self-review per
   phase.

5. **The testing gate** — after the last phase, before review; any failure blocks the
   review loop from starting (§ *Testing Gate*). Five steps: lint/type-check/build,
   affected unit tests (never the full suite by default), integration impact check, author
   missing tests, and a one-line summary. The test-authoring step carries the interesting
   policy — the mock-pain tripwire, the coverage-debt ledger, and the critical-path floor
   that coverage debt may never defer (§ *Testing Gate* → *4. Author missing tests*). For
   heavy authoring work it points to the deep reference, `skills/addw-test/SKILL.md`
   (§ *Hard-to-Test Code* for the seam ladder).

6. **Codex code review** runs automatically once the gate is green (§ *Codex Code Review*).
   Same verdict-tag loop as the plan review, with two extra rules: the testing gate is
   re-run before every resume, and each round's fixes get their own commit. Findings are
   judged against the shared checklist in `skills/codex-code-review/checklist.md`. Capped
   at five rounds; anything still open is surfaced to you. No review artifact is produced —
   the verdict and round count become one line in the release changelog entry
   (§ *Record the Outcome*).

7. **Handoff.** You are asked: **"Is the implementation complete?"** Yes chains directly
   into the release in the same session; No loops back through gate → review → question
   (§ *Handoff to Release*).

---

## Phase 3 — Release (`addw-3-release`)

Normally chained from Phase 2; if invoked standalone in a fresh session, it first re-runs
lint, build, and affected tests itself (§ *Standalone verification*).

1. **Version bump** in the file `addw.env` names (§ *Version Update*).

2. **Changelog entry** prepended to the root `CHANGELOG.md` by script — the file is
   write-only for the workflow; no skill ever reads it (§ *Changelog*). The entry carries
   the plan path and the review line from Phase 2.

3. **Design reconciliation** — the release's most consequential docs step
   (§ *Design Reconciliation*). Starting from the plan's Doc Impact list, every living doc
   is swept so it describes only the current design; superseded text is deleted or rewritten
   as an explicit lesson, never labeled "historic". Dated records (ADRs, changelog,
   tutorials) are exempt — they are superseded, never retro-edited. Two things deliberately
   escape the release commit: charter changes and skill changes are each flagged as
   separate commits (§ *Design Reconciliation* points 4–5, and addw-1's
   § *Process/Design Separation* under Technical Considerations).

4. **Optional tutorial** if the project opted in at init (§ *Tutorial*), then a README
   version bump (§ *README Update*).

5. **Commit → tag → merge → push.** You are asked **"Ready to commit?"** first. A
   version-sync script must pass, then the release commit stages only version + docs —
   the implementation is already on the branch from Phase 2's checkpoints (§ *Commit*).
   Then the version tag, a fast-forward-only merge into the main branch (never a merge
   commit — § *Merge (fast-forward)*), and a final question: **"Push to remote?"**

6. **Maintenance nudge.** A counter script may suggest running `addw-4-maintain` after N
   releases without an audit — suggest only, never auto-run (§ *Maintenance Audit Nudge*).

---

## What gets committed, in order

All on the feature branch until the final merge; every commit uses explicit paths.

| # | Commit | When | Pointer |
|---|--------|------|---------|
| 1 | Plan + ADR (if intent changed) | Plan approval | addw-1 § *ADR Writing (on approval)* |
| 2 | `test:` failing contract tests | Critical-path work only, before delegation | addw-2 § *Step 0.5* |
| 3 | `feat:`/`fix:` checkpoint, one per phase | After each self-review | addw-2 § *Self-Review & Fix* |
| 4 | `fix:` review-round findings, one per round | Before each review resume | addw-2 § *Codex Code Review*, step 5 |
| 5 | Release commit (version + docs only) | After "Ready to commit?" | addw-3 § *Commit* |
| — | Charter changes, skill changes | Never in a release — separate design/process commits | addw-3 § *Commit* → *Commit taxonomy* |

## Every question you'll be asked

The cycle is autonomous between these checkpoints; these are the only places it stops for you.

1. Plan clarifications — up to 3 rounds (addw-1 § *Step 1*)
2. Plan verdict: Approved / Request changes / Needs rework (addw-1 § *Step 4*)
3. Start implementation now? (addw-1 § *Step 4*, on approval)
4. Is the implementation complete? (addw-2 § *Handoff to Release*)
5. Ready to commit? (addw-3, before § *Commit*)
6. Push to remote? (addw-3 § *Push*)

## Off-ramps

Not part of the cycle, but referenced from inside it: `addw-hotfix` bypasses the full cycle
for genuine emergencies; `addw-test` runs standalone for coverage backfill; the coverage-debt
ledger (`docs/4-unit-tests/COVERAGE-DEBT.md`) parks hard-to-test paths with an escape plan;
`addw-compact` shrinks ARCHITECTURE.md when the release step warns about its token count;
`addw-4-maintain` is the periodic audit the release step nudges you toward.

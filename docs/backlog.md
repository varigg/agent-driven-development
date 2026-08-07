# Backlog — future enhancements

Ideas noted but not yet designed. When one graduates, it gets a full write-up
in `docs/proposals/` (design) and eventually lands as process commits. Entries
here are one-liners with just enough context to pick the thread back up.

- **Native stacked PRs for large tickets** — noted 2026-08-07: GitHub now has
  a first-class stacked-pull-request workflow
  (https://docs.github.com/en/pull-requests/how-tos/stacked-pull-requests).
  Not for starting blocked tickets early — the frontier rule stands — but for
  decomposing one ticket's large change into separately reviewable blocks.
  Before adopting: revisit addw-implement's open-PR mode detection (assumes
  one PR per ticket) and the squash-merge/changelog projection (a squashed
  base rewrites what the rest of the stack sits on).
- **Second agent adapter** — write a non-Codex adapter for one role (implement
  or code-review) and revise the adapter contract against it. The current
  contract (README "Swapping agents") is codex-shaped: resumable thread IDs,
  exit-2-on-existing-session, verdict tags, sandbox modes. An agent without
  durable threads will need the "resume" semantics rethought (likely
  context-replay inside the adapter).
- **Visual identity** — the TRIP-era Smurf/mushroom art (banner, phase-loop
  diagram, multi-LLM illustration) and the parent repo's demo video were
  removed at the rename; the README is currently text-only. Decide whether the
  new identity is whimsical or sober, then produce a banner, a
  **three-phase** loop diagram (Plan → Implement → Release — the old one drew
  the retired four-phase cycle), a multi-agent illustration, and optionally a
  fresh demo recording.
- **Approval-staleness marker** — noted 2026-07-30 while reviewing
  ShopDevX/adeptlydev (whose own red-team flags the same gap in itself):
  nothing detects a plan edited between approval and implementation. The
  same-session happy path makes the window small; it bites multi-session,
  multi-phase work. adeptlydev's mechanic: a truncated sha256 of the plan
  content stored in each derived artifact, compared on read. ADDW analog:
  record the hash at approval, have addw-2-implement warn on drift.
- **Determinism sweep leftovers** — see `docs/proposals/determinism.md`
  (2026-07-30). Deferred script candidates: ADR scaffolder, release tail
  sequence, compact link checker, coverage-debt liveness, `git add -A`
  permission deny rule. Plus the big one: machine-readable Verification
  Recipes + a deterministic `gate.sh` for the addw-2 testing gate — needs a
  schema bump, ride the next boundary (pairs with the addw-4-maintain
  rename below).
- **Rename `addw-4-maintain` → `addw-maintain`** — decided 2026-07-28. The
  "4" implies a pipeline phase, but maintain is a cadence-triggered audit;
  the 1–3 numbers stay (they encode the happy path and sort autocomplete in
  execution order). Skill folder names are docs contract, so ride this into
  the next schema-bump boundary instead of spending one on cosmetics.

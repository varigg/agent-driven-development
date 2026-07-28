# Backlog — future enhancements

Ideas noted but not yet designed. When one graduates, it gets a full write-up
in `docs/proposals/` (design) and eventually lands as process commits. Entries
here are one-liners with just enough context to pick the thread back up.

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
- **Rename `addw-4-maintain` → `addw-maintain`** — decided 2026-07-28. The
  "4" implies a pipeline phase, but maintain is a cadence-triggered audit;
  the 1–3 numbers stay (they encode the happy path and sort autocomplete in
  execution order). Skill folder names are docs contract, so ride this into
  the next schema-bump boundary instead of spending one on cosmetics.

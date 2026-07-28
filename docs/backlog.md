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

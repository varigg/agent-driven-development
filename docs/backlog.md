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
- **Living behavioral spec** — implement `docs/proposals/living-spec.md`
  (decided in principle 2026-07-27; wiring through init/plan/release/maintain
  and the review checklist still to be built).
- **Regenerate branding assets** — the three `assets/trip-workflow-*.png`
  images still carry TRIP branding; replace with agent-driven-development
  versions before or shortly after the public push.
- **Retire `addw-upgrade`** — after the one remaining v2 install
  (adventure-library) is migrated; `UPGRADING.md` is the durable path.

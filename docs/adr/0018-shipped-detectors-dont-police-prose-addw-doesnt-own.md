# ADR 0018: Shipped detectors don't police prose ADDW doesn't own

- **Status**: active
- **Date**: 2026-10-07
- **Origin**: ticket varigg/agent-driven-development#213

`addw-maintain`'s docs-drift sweep audited an install's living docs for prose discipline:
vocabulary agreeing with the active ADRs, history narration, self-summarizing documents,
restated delegated facts and spent procedures. In an install, ADDW can act on none of those
findings. ADRs are write-once. The conventions sources and `CLAUDE.md` belong to the project
and ADDW never edits them. The glossary is `domain-modeling`'s. ADDW's own skills are
byte-identical copies. The only maintenance audit on record agrees: every drift it found
was in ADDW's own product (skills, README, walkthrough, tracker config), none of which
drifts inside an install. The decision is that **a shipped detector runs only checks whose
findings an install can act on through ADDW's own mechanisms**. Those are retiring a
document the archival tool handles, and repairing a dead or line-scoped pointer. Checks on
prose that ADDW does not own, and could only file a ticket about, stay out of shipped
skills. Prose discipline for ADDW's own documents is this repo's convention, enforced at
the PR that would introduce the drift.

## Alternatives Considered

- **A periodic audit that runs only in this repo.** Rejected. Drift in the skills is
  cheapest to catch in the PR that lands the ADR whose vocabulary it replaces. A periodic
  audit finds it later, after the stale term has already shipped.
- **Moving the prose checks into release's verification sweep.** Rejected for the same
  reason as the sweep itself: at release time, in an install, the documents are still
  ones ADDW cannot edit.

## Consequences

- **Shipped `addw-maintain` Sweep A** keeps whole-document retirement (ADRs and
  proposals) and link liveness. Link liveness covers line-scoped pointers and leaves ADR
  `Origin` lines exempt. The sweep reads the charter, ADRs, proposals, glossary and
  conventions sources. `.claude/skills/` is out of scope.
- **Release's verification sweep** keeps retirement and drops its vocabulary check.
- **This repo's conventions** in `CLAUDE.md` take over the four prose checks: vocabulary
  against active ADRs, history narration, self-summary and restated delegated facts.
  Vocabulary is enforced when an ADR lands: the PR that merges an ADR sweeps the whole tree
  for the vocabulary that ADR replaces.
- **Cut:** the spent-procedure check and the accretion probe. The work-log tests for design
  records move into the ADR template's rules.

## Gate

A shipped skill gains no check on prose it can only file a ticket about without
superseding this ADR. In this repo, a PR that lands an ADR sweeps the tree for the
vocabulary the ADR replaces.

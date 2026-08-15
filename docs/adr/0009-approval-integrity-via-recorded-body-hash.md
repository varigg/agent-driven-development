# ADR 0009: Approval integrity is a truncated body hash recorded in the approval artifact

- **Status**: active
- **Date**: 2026-08-15
- **Origin**: ticket #30

An approved tracker artifact can be edited between its approval and the work
derived from it — a spec between `codex-spec-review`'s verdict and `to-tickets`
decomposing it, a ticket between the code-review verdict and the merge — and
nothing structural prevents it, because issue bodies are mutable and the
consumers are partly third-party skills ADDW cannot modify. The decision:
approval writes a truncated SHA-256 of the approved body (`sha256:` plus the
first 12 hex digits, trailing newlines stripped) into the durable approval
artifact itself — the verdict comment for a spec, the PR body for a ticket —
and ADDW's own consumers compare it against the live body and **warn** on
drift. Detection over prevention: the tracker offers no immutability to build
on, so the mechanism is a recorded fact plus a mechanical comparison
(`tracker.sh approval-drift`), which ADR 0004's conditions admit as a script.

## Alternatives Considered

**Locking or re-reviewing on every edit** — the tracker has no lock, and
mandatory re-review would gate human edits on agent availability, inverting
ADR 0005's autonomy direction. **Recording the hash in the tree** — the
approval happens on the tracker before any branch exists (a spec's approval
merges nothing), so there is no reviewed tree to carry it. **A full SHA-256**
— 48 bits already makes accidental collision irrelevant for a drift warning,
and the short form keeps the marker line readable in a comment.

## Consequences

Approvals that predate this decision carry no marker; consumers treat an
absent marker as "unrecorded", never as drift, so the mechanism needs no
migration. A drift warning is advisory — the human decides whether the edit
was cosmetic or the approval is stale — and re-approval simply records a new
marker, which last-wins scanning then honors.

## Gate

The marker grammar — a line of exactly `Approved-body: sha256:<12 hex>` — is
a cross-skill contract between the recorder (`codex-spec-review`) and every
checker. A change to it is coordinated across recorder, `parse.sh`, and the
contract tests in the same PR, never piecemeal.

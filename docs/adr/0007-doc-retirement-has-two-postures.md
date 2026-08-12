# ADR 0007: Doc retirement has two postures

- **Status**: active
- **Date**: 2026-08-12
- **Origin**: ticket varigg/agent-driven-development#87

A document retirement lands one of exactly two ways. When a PR already
carries the change that made the document untrue, the retirement rides that
PR (`addw-implement`'s archive step). A **detached detection** — a sweep or
review that finds a stale document while no such PR exists — files a
`backlog` ticket, which enters the workable frontier only through a human
act that names it: for `addw-maintain`, the merge of the audit PR whose
record lists the filing; for `codex-spec-review`, an explicit label flip,
since nothing in the spec path merges. This replaces the shipped rationale
that a fully-determined retirement — "target, reason and command all fixed
at detection, nothing remains to design" — may file `ready-for-agent`
directly: however determined the work, that argument is queue authorization
by agent judgment, which ADR 0005 rejected — the PR gate catches bad
output, not bad priorities, and frontier entry is a spending decision that
stays human.

## Alternatives Considered

- **A "fully-determined retirement" exception to ADR 0005's gate 3** —
  rejected: the carve-out list is deliberately closed, and reopening it for
  the first inconvenient case would gut the rubric's authority.
- **Dropping detached auto-filing entirely** (let a later sweep rediscover
  the stale document) — rejected: it loses timeliness and makes one
  detector pretend not to have seen what it saw.

## Consequences

Graduation gains one general mechanic: a human-merged PR whose body names a
filed ticket is the naming act, and the merge graduates the filing — the
same rail `addw-hotfix`'s deferred-scrutiny follow-up rides. Detached
filings with no covering merge simply wait; their graduation costs the
human one label flip.

## Gate

Any skill step that files a ticket for fully-determined work — retirements
included — files it `backlog` unless a human-merged PR body names it. No
filing argues its way to `ready-for-agent` from determinedness alone.

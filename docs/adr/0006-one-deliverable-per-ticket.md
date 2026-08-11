# ADR 0006: A ticket carries one Deliverable

- **Status**: active
- **Date**: 2026-08-11
- **Origin**: ticket varigg/agent-driven-development#85

The diagnosis behind this decision found that the workflow's median PR (263
lines, 4 files) reviews fine, but its worst quartile (800–1400 lines, 9–37
files) traces case by case to tickets whose acceptance criteria bundle several
independently-checkable deliverables — `to-tickets` sizes tracer bullets to a
fresh context window, while under ADR 0005 the binding budget is the human
review at the Boundary. The decision: **a ticket carries exactly one
Deliverable** (the CONTEXT.md term — an independently-checkable unit of work).
A bundle of N deliverables decomposes into N tickets with blocking edges;
slices stay vertical, tracer-bullet style, but singular.

## Alternatives Considered

- **A numeric budget** (estimated diff lines or file count) — an objective
  test, but a proxy that is gameable and punishes legitimately wide mechanical
  changes; bundling of checkable deliverables is the diagnosed mechanism,
  size is only its symptom.
- **A soft "one review sitting" framing** — names the right cost but gives a
  decomposition nothing it can be checked against.
- **A decomposition-review step after `to-tickets`** — new machinery for a
  top-quartile problem; the existing granularity quiz plus this ADR's Gate
  reaches decomposition without it.

## Consequences

Specs decompose into more, smaller tickets with more blocking edges. Existing
open tickets are not retro-split; the pickup backstop below catches any
pre-existing bundle when it is picked up. `addw-implement` gains that
backstop as its own ticket (varigg/agent-driven-development#91), which
graduates when this ADR merges.

## Gate

At decomposition — `to-tickets` or a hand-filed ticket: check that each
ticket's acceptance criteria verify a single Deliverable. Criteria that can
pass or fail independently of one another mark a bundle; split it before
publishing. At implement pickup: a ticket found to bundle more than one
Deliverable is not started — report it for rescoping instead.

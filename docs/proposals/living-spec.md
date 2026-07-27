# Proposal: A Living Behavioral Spec (`docs/spec.md`)

**Status**: proposed (decided in principle 2026-07-27 — full living spec over a
charter capabilities list or no spec; wiring below not yet implemented)
**Date**: 2026-07-27

## Problem

The living-doc model covers *intent* (`charter.md` — purpose, scope, non-goals,
deliberately coarse) and *construction* (`ARCHITECTURE.md` — as-built design),
but **current behavior** — what the system actually does, feature by feature,
independent of how it is built — lives nowhere durable. It exists only as the
union of all past plans, which are dated records.

That contradicts the doc model's own core rule: the present must never require
replaying history. For structure the rule holds (ARCHITECTURE.md); for behavior
it doesn't — an agent asked "what does this app do?" must either read the code
or replay plan history. It also weakens two existing mechanisms:

- The selective test-first step (addw-2, Step 0.5) derives "should" from the
  plan being implemented — there is no durable behavioral baseline to test
  *regressions* against.
- Reviews check diffs against the plan and ARCHITECTURE.md conventions, but
  nothing lets a reviewer notice "this silently changes documented behavior."

## Proposal

`docs/spec.md` — the behavioral peer of ARCHITECTURE.md. Describes user-visible
behavior and invariants per feature area: what the system does, what it
guarantees, what it refuses to do. No design, no rationale, no history.

### Wiring (all existing machinery, no new ceremony)

1. **Init**: addw-init generates the initial spec from the as-built behavior
   discovered during codebase exploration, user-reviewed like ARCHITECTURE.md.
2. **Plan**: the plan's Doc Impact section declares its **spec delta** — which
   behaviors are added, changed, or removed. A plan that changes documented
   behavior without a spec delta is incomplete.
3. **Release**: Design Reconciliation updates spec.md alongside ARCHITECTURE.md
   (same rules: current behavior only, delete superseded text, git is the
   archive).
4. **Maintain**: the docs-drift sweep samples spec claims against actual
   behavior, as it already does for ARCHITECTURE.md claims.
5. **Tests**: Step 0.5 contract tests and the testing gate derive expected
   behavior from the spec delta plus the surrounding spec context.
6. **Review**: the code-review checklist gains one line — flag diffs that
   change behavior the spec documents without a matching spec delta.

### Boundary policing (the overlap risks)

| Doc | Answers | Never contains |
|-----|---------|----------------|
| `charter.md` | why the product exists, what's in/out of scope | feature behavior |
| `docs/spec.md` | what the system does (observable behavior, invariants) | how it's built, why it's wanted |
| `ARCHITECTURE.md` | how it's built | behavior guarantees |
| `TESTING.md` | how behavior is verified | behavior definitions |

### Naming

Lowercase `spec.md` per the casing rule: uppercase is reserved for
ecosystem-conventional names (README, LICENSE, ARCHITECTURE, TESTING); "spec"
is workflow vocabulary.

## Costs

- One more living doc in every release's reconciliation sweep — and behavior
  changes more often than architecture, so spec.md will be touched by most
  releases. Mitigation: the spec delta is declared at plan time, so
  reconciliation is applying a known diff, not rediscovering one.
- Per-session token weight for agents that read it. Mitigation: same budget
  discipline as ARCHITECTURE.md (addw-compact applies; behavior described at
  the feature level, not the click level).
- Boundary drift with charter/ARCHITECTURE. Mitigation: the table above plus
  the maintain audit's drift sweep.

## Open Questions

- Single `spec.md` vs a `docs/spec/` tree per feature area — start single-file,
  split only when compaction stops working (mirrors the
  ARCHITECTURE-detailed.md escape hatch).
- Does the upgrade path generate a spec for existing installs (adventure-library)
  at migration time, or lazily at the first release that declares a spec delta?
- Spec format: free prose per feature area vs lightly structured entries
  (behavior / invariants / error cases). Decide at implementation.

## Problem Statement

Users cannot tell why the resolver picked one edge over another when both apply.

## Implementation Decisions

- Root validation follows the `validate_sweep_roots` precedent (ADR-035).
- ADR: records the positive decision, losing alternatives as one-liners.

## Testing Decisions

- Unit tests for `precedence()` covering every documented case.

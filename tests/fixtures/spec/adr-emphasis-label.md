## Problem Statement

Users cannot tell why the resolver picked one edge over another when both apply.

## Implementation Decisions

- **ADR:** one record for the decision.
- The resolver module gains a `precedence()` helper.

## Testing Decisions

- Unit tests for `precedence()` covering every documented case.

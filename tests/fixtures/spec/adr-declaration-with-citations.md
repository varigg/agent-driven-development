## Problem Statement

Users cannot tell why the resolver picked one edge over another when both apply.

## Implementation Decisions

- ADR: supersedes ADR-033's vocabulary split and ADR-035's extract-only ingestion split.
- The resolver module gains a `precedence()` helper.

## Testing Decisions

- Unit tests for `precedence()` covering every documented case.

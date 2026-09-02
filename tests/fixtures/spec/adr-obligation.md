## Problem Statement

Users cannot tell why the resolver picked one edge over another when both apply.

## Solution

Make the precedence explicit and documented.

## Implementation Decisions

- One ADR for the positive decision, losing alternatives as one-liners.
- The resolver module gains a `precedence()` helper.

## Testing Decisions

- Unit tests for `precedence()` covering every documented case.

## Out of Scope

Nothing else changes.

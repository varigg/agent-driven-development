## Problem Statement

Users cannot tell why the resolver picked one edge over another when both apply.

## Solution

Make the precedence explicit and documented.

## Implementation Decisions

- The resolver module gains a `precedence()` helper.
- No new architectural decision here — just a helper extraction.

## Testing Decisions

- Unit tests for `precedence()` covering every documented case.

## Out of Scope

Nothing else changes.

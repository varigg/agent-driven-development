## Problem Statement

A large spec structures its Implementation Decisions into subsections.

## Implementation Decisions

### Roots, settings, and vocabulary

- The resolver module gains a `precedence()` helper.
- Root validation follows the `validate_sweep_roots` precedent (ADR-035).

### Documents

- **ADR** (next number): supersedes ADR-033's vocabulary split and ADR-035's extract-only ingestion split.

## Testing Decisions

- Unit tests for `precedence()` covering every documented case.
- Not an obligation: this bullet lives outside Implementation Decisions.

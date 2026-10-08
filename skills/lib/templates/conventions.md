<!--
Seed for docs/CONVENTIONS.md. addw-init starts its fallback interview from this
file and prunes it rule by rule; the comment goes with the first pass. Every
rule that survives must pass the admission test: a reviewer could cite a diff
as violating it. This template is never itself a conventions source.
-->
# Conventions

The rules review enforces in this project. Constraints, not a checklist: when
two conflict, pick the lowest future cost for this repo and say so in the
commit. Adapted from Tomas Vykruta's AGENTS.md rules.

## Design principles

- **Separation of concerns.** Each file has one concern you can name. Domain
  rules live with their owner, transport and rendering stay thin around it.
  Nothing new goes into a file whose concern is already mixed.
- **Encapsulation.** Read another module's state — its tables, caches, files —
  through its functions, never directly. One rule change touches one module.
- **DRY means one home.** Search before writing a rule, threshold, format
  string or schema fact, and extend its home. Do not abstract coincidental
  similarity.
- **KISS / YAGNI.** Function over class. No speculative flags, hooks or layers.
  Boring technology.
- **Depend on contracts.** Domain code takes and returns plain values; it never
  reaches into the request, the response, or the UI that called it.
- **Fail fast, and fail closed.** Validate at the edges. On any security or
  authorization path an error is a refusal, never a pass.

## Hard invariants

1. **Refactor before you duplicate.** On the second use of a piece of logic:
   move it to its owner, switch the original caller with the tests green and
   no behaviour change, then build the new use — as separate commits. A helper
   beside old copies is one more duplicate.
2. **A refactor never weakens a check.** Refusals, fail-closed paths, signature
   and key checks keep their exact semantics. If a refactor changes what is
   refused, it is not a refactor.
3. **Secrets never enter git.** A secret found in history is rotated, not just
   removed.
4. **Gates, not promises.** A rule that matters is enforced by a test, a lint,
   a scan or a hook, not by a sentence in this file. A check whose tool is
   missing reports SKIPPED, and SKIPPED is never a pass. Never claim a check
   passed that was not run.

## Testing

- **New logic ships with its test.** A diff that adds a branch, a parser, or a
  state change adds a test that fails if that logic breaks. Untested code is
  never hidden behind an ignore comment or a lowered coverage threshold; a gap
  that is genuinely hard to cover goes in the coverage-debt ledger instead.
- **Test behaviour, not wiring.** A test asserts what a caller can observe —
  return values, persisted state, emitted requests — never which internal
  function was called. A test that breaks on a pure refactor is wrong.
- **A bug fix starts with a failing test** that reproduces the bug.
- **The heavier suite runs when its contract moves.** A diff that changes an
  API contract, a schema, a selector the end-to-end suite drives, or a
  cross-process boundary runs the integration/E2E suite before merge, and the
  PR says it did.

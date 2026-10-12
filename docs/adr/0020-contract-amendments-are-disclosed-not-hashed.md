# ADR 0020: Contract amendments are disclosed, not hashed

- **Status**: active
- **Date**: 2026-10-11
- **Origin**: ticket #250 (spec #243)

Design changes keep landing in ticket comments, and editing a spec body to carry them trips `approval-drift` on every ticket cut from it (ADR 0009). The contract an implementer builds from is therefore the reviewed body plus its live amendments: comments by a trusted author that carry one anchored `Amends-contract: <summary>` line. ADR 0009 is amended on one point: the approval hash keeps covering exactly the reviewed body and nothing else. An amendment is a human assertion, not a review, so hashing it would claim a review that never happened; it is disclosed instead, in the PR body, where the merging human judges it at the merge boundary (ADR 0017).

## Alternatives Considered

**Hashing the body together with its amendments** — every new amendment would read as drift on an approval it was never part of, and re-approval would be a cheap click that restates a review nobody did. **Requiring a body edit for every design change** — the status quo, which is exactly the cost on a spec: any byte changed flags every child.

## Consequences

An amendment posted after the final review round trips no mechanical check; the disclosure and the merging human's read of the ticket are what catch it. A drift-style fingerprint of the amendment set is a follow-up if that proves to bite. Who counts as a trusted author, how amendments are ordered and retired, and how the contract is rendered for the skills are later tickets of spec #243, not this decision.

## Gate

The `Amends-contract:` marker grammar — a line of exactly `Amends-contract: <summary>` with a non-space first summary character, anchored at line start, tolerating only a trailing carriage return, the last such line in a comment winning — is a cross-skill contract like ADR 0009's marker. A change to it is coordinated across `parse.sh`, the contract tests and the grammar's documentation in `skills/lib/README.md` in the same PR, never piecemeal. A reviewer must also check that no change makes the approval hash cover anything but the reviewed body.

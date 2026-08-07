# ADR 0001: ADDW does not gate on third-party skill presence

- **Status**: active
- **Date**: 2026-08-07
- **Origin**: PR #25, implementing #9

The overlay design assumed ADDW had a hard dependency on two of Matt Pocock's
skills — `code-review` and `tdd` — and had the install doctor fail when either
was absent. Building that check showed the assumption was wrong in both
directions: no filesystem probe can reliably answer whether a skill is
invocable, and more importantly there was nothing to gate on, since the review
ADDW cannot proceed without is its own cross-model loop and the pre-filter in
front of it is skippable by design. ADDW therefore treats every third-party
skill as replaceable, gates on none of them, and gates instead on the role
adapters named in `docs/addw.env`, which are the dependencies it actually has.

## Alternatives Considered

Probing the filesystem for installed skills was built and refined across four
cross-model review rounds — narrowing from any directory under the plugin
tree, to the plugin cache, to recorded install paths, to only enabled plugins.
Each round found the previous answer too generous, and the last version had
stopped consulting the filesystem and started shelling out to
`claude plugin list --json`, which is the point at which a check has migrated
out of its own mechanism. The accurate authority is the agent's skill roster,
which alone carries the plugin qualifier distinguishing two same-named skills;
but once the dependency itself was recognised as soft, even a roster check had
nothing to enforce.

## Consequences

The flow must stay executable with none of Matt's skills installed: TDD is a
discipline an agent can follow without a skill encoding it, and the cold
pre-filter accepts any competent two-axis review or a plain instruction to
review the diff. Because more than one plugin publishes a `code-review`, a PR
body that says the pre-filter ran must name which review actually ran, so the
claim cannot imply a skill that never executed. Behavioural drift in any
substitute is absorbed by the two nets that remain: the cross-model loop and
human PR review.

## Gate

Before adding any check that a named third-party skill exists, ask what breaks
without it. If the step that consumes it may be skipped by judgment, or if a
substitute would serve, the check is not a gate and belongs in an advisory
inventory. Absence of evidence that one prompt outperforms another is not a
reason to require a particular prompt.

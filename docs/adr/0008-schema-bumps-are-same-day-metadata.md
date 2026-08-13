# ADR 0008: A schema bump is same-day metadata

- **Status**: active
- **Date**: 2026-08-13
- **Origin**: ticket varigg/agent-driven-development#89

The question was whether the schema-version + `UPGRADING.md` machinery is a
testing-era convenience or a permanent part of the product, judged against the
audience it actually serves today: two installs, both the author's, upgraded by
agent sessions with this repo at hand. The evidence split the machinery in two —
`UPGRADING.md`'s numbered sections carried the real 3 → 4 and 4 → 5 upgrades as
an executable script and are where destructive steps are guarded, while doctor's
`EXPECTED_SCHEMA` gate never caught a missed step, and the only cost actually
felt was the discipline that structural changes queue for rare boundaries (the
`addw-4-maintain` → `addw-maintain` rename waited weeks for one). The decision:
**keep the whole mechanism, drop the queueing** — a change that alters the docs
contract lands with its `UPGRADING.md` section and the schema bump in the same
PR, the same day, and a change whose omission fails loudly on a stale install
carries a dated "Within schema N" note instead of a bump — that pattern is now
the rule, not an exception.

## Alternatives Considered

- **Keep as-is** (rare, guarded boundaries) — already public-release-shaped,
  but keeps paying the queueing delay, the one cost the machinery has actually
  imposed, during the era it serves the fewest users.
- **Drop the integer and gate**, keying `UPGRADING.md` sections off observable
  tells per section ("no `docs/addw.env` and `TRIP-*` folders is generation 2")
  — saves one env line and one doctor line while making agent-driven upgrades
  target sections less robustly than "apply every section between your number
  and the current one, oldest first".

## Consequences

Renames and other structural changes ship when they are ready; nothing waits
for a boundary, and bumps become frequent and small. The CLAUDE.md convention
"renames ride a schema boundary" is reworded to "renames ride their own PR's
bump". This judgment was made against the current two-install reality —
a public release of the workflow re-opens it with a foreign-install audience
that cannot be re-baselined by hand.

## Gate

A PR that renames, moves, or retires anything an install references — the docs
contract — must carry, in that same PR, its `UPGRADING.md` section and the
schema bump everywhere the number lives (`docs/addw.env`, doctor's
`EXPECTED_SCHEMA`, the config template in `addw-init`). If the omitted
migration would fail loudly on a stale install, a "Within schema N" note in
`UPGRADING.md` replaces the bump. A structural change parked to "wait for the
next boundary" violates this ADR.

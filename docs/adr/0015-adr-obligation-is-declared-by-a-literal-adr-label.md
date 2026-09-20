# ADR 0015: An ADR obligation is declared by a literal `ADR:` label, not inferred from prose

- **Status**: active
- **Date**: 2026-09-20
- **Origin**: ticket #167 (folding in #168)

`parse.sh adr-obligation` read a spec's `## Implementation Decisions` section for any list
item containing the word "ADR", on the theory that a durable structural signal (a list item,
in that section) beat matching a specific phrase. In practice the signal was too coarse in
both directions: a bullet citing an existing record as precedent ("per the
`validate_sweep_roots` precedent (ADR-035)") read as a promise of a new one, and — because the
section scan reset on every heading depth — a declaration placed under a `###` subsection was
invisible to it. Distinguishing a citation from a declaration by phrase (does the mention
carry a number?) does not compose safely with fixing the subsection blind spot: a spec that
both declares a new ADR and cites existing ones in the same bullet ("**ADR** (next number):
supersedes ADR-033's vocabulary … and ADR-035's …") needs the declaration recognized
independently of how many numbers ride along in the same sentence. The decision: an obligation
is declared by convention, not inferred from prose. A list item under `## Implementation
Decisions` — spanning every `###` subsection beneath it, matching `strip-section`'s existing
level-2 boundary — declares one obligation only when its text, after the list marker and any
emphasis wrapping (`*`, `_`, backtick), begins with the literal label `ADR:` (case-insensitive).
Everything after the colon is free prose and may cite existing records freely; every other
item — a bare citation, or prose that merely mentions the word — is never an obligation, no
matter how it reads. `section_refs` (`parent`, `blockers`) gets the same subsection-spanning
fix, since it carried the identical defect.

## Alternatives Considered

- **Keep phrase-matching, refined** — strip numbered citations before checking for a
  standalone "ADR" mention, so a citation-only bullet doesn't count while a declaration
  survives the strip. Cheaper, and passes the incident's own examples, but is still guessing
  at intent from free prose: any future phrasing that isn't a numbered citation but also isn't
  a promise ("no new architectural decision needed here") is one edge case away from a new
  false positive, and the fix compounds with every future phrasing anyone comes up with.
- **A marker keyword anywhere in the item** ("declares", "new ADR") rather than a leading
  label — rejected because "anywhere in the item" reopens the same problem a leading label
  closes: a citation-heavy bullet can use any of those words in passing without promising
  anything, and a reviewer scanning a spec for its ADR obligations wants them findable at a
  bullet's own start, not buried in its middle.

## Consequences

A spec author who wants the tracker to track an ADR obligation writes `ADR: <what it decides>`
as the bullet's own opening; a citation of an existing record, however phrased, never needs to
avoid the word "ADR" to stay a citation. Existing specs whose Implementation Decisions declared
an obligation in free prose no longer register as obligated — `UPGRADING.md`'s schema 11 → 12
section carries the reword, and because spec bodies are approval-hashed (ADR 0009), that reword
registers as drift needing re-approval. The three section-scanning parsers (`adr-obligation`,
`parent`, `blockers`) and `strip-section` now agree on what a level-2 section spans; nothing
about `strip-section`'s own behavior changes.

## Gate

Any new parser that reads a level-2 section of an issue or spec body must span `###` subsections
the same way `strip-section` does — reset only on the next `##` heading, never on a deeper one —
rather than growing a fourth divergent implementation of the same boundary. A change to the
`ADR:` label grammar itself is coordinated across `parse.sh`, its tests, the parser's header
comment, `skills/lib/README.md`'s `tracker/` entry, `docs/cycle-walkthrough.md`'s release-guard
paragraph, and the spec-review prompt's Implementation Decisions guidance, in the same PR —
never piecemeal, since a spec author who sees only one of those describing the convention will
write the wrong form.

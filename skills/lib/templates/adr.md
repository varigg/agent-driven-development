# ADR NNNN: <Title>

- **Status**: active | superseded by ADR-NNNN
- **Date**: <YYYY-MM-DD>
- **Origin**: <spec issue, ticket, PR, or "design session">

<One paragraph — one to three sentences carrying the context, the decision,
and why. That is the whole ADR by default; the value is in recording that a
decision was made and why, not in filling out sections.>

## Alternatives Considered (only when they earn their place)

<Discarded options and why. This is where discarded ideas live, never the
living docs.>

## Consequences (only when they earn their place)

<What becomes easier, harder, or forbidden.>

## Gate (required for a guardrail decision)

<What a future reviewer must check so later work does not violate this.>

---

## The rules (this section is not copied into an ADR)

- ADRs are **write-once from the merge boundary**, sequence-numbered, and
  self-contained — evidence restated in the ADR's own words, citing only
  living docs and other ADRs. An unmerged ADR can still be corrected; a merged
  one never is.
- The three bold fields are **mandatory and always present**. `Status` has
  exactly two states, `active` and `superseded by ADR-NNNN`. Only the first is
  ever written. Supersession is a **departure**: the superseding PR archives
  the ADR it supersedes, and the archive's provenance block carries the pointer
  — so no ADR in the tree ever reads `superseded by`, and none is edited after
  merge to make it. The second state stays because it names the only exit an
  ADR has, which is what keeps the next number `max + 1`: every departed number
  sits below the active ADR that superseded it.
- `Date` is the date the ADR was **written**, not the date it merged, so the
  field is not a function of review latency.
- `Origin` is historical provenance: the **spec issue** for a decision made
  during alignment or specification, the **ticket or PR** when implementation
  forced it, or the literal `design session` when the decision predates any
  tracker artifact. Origins are never backfilled and are exempt from
  dead-link checking — they are expected to outlive what they cite.

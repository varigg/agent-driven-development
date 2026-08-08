# ADR 0002: The tracker seam owns issue creation

- **Status**: active
- **Date**: 2026-08-07
- **Origin**: #13

The overlay's tracker seam was specified as a read-annotate-close surface —
frontier and eligibility reads, body get/edit, labels, comments,
close-with-reason, completion queries — because in the happy path ADDW never
originates an issue: `to-spec` publishes the spec issue and `to-tickets`
publishes the tickets, and ADDW works on what they authored. The schema-4
backlog migration needed to open issues and found that ADDW already had one
creation path of its own, `addw-maintain` routing a substantive audit finding
to a `backlog` issue, which existed only as prose with no command behind it.
Creation therefore joins the seam as `tracker.sh create`, so the rule that no
script performs a tracker operation outside the layer stays literally true
rather than true-with-an-exception.

## Alternatives Considered

Calling the tracker CLI directly for the one-time migration would have matched
the spec's enumeration and kept the seam narrow, but it left `addw-maintain`'s
instruction unbacked and put an unrouted tracker call in the repo that most
loudly forbids them. Rewriting `addw-maintain` to hand findings to the human
instead of filing them would have removed the second consumer rather than
serving it, at the cost of the audit's own disposition record.

## Consequences

A future non-GitHub tracker adapter must implement an operation the happy path
never calls. That cost is small and was accepted deliberately: the alternative
is an adapter interface that silently omits the one verb two ADDW skills need.
Unlike the layer's other thin wrappers, `create` is unit-tested, because it
shapes an outbound write from variadic arguments rather than passing one
through — a comma-joined label string would be read as a single label name, and
a body-file failure mid-create leaves a titled, bodyless issue that cannot be
un-created.

## Gate

Before adding an operation to the tracker seam, ask which ADDW skill performs
it. An operation Matt's skills perform on ADDW's behalf does not belong here;
one that an ADDW skill instructs an agent to perform does, even when the happy
path rarely reaches it. Prose telling an agent to perform a tracker operation
with no seam command behind it is the defect this ADR exists to catch.

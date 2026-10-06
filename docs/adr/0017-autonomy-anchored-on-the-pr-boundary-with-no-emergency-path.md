# ADR 0017: Autonomy is anchored on the PR boundary, with no emergency path

- **Status**: active
- **Date**: 2026-10-06
- **Origin**: ticket varigg/agent-driven-development#208

ADDW replaces per-stage approval accidents with one generating principle: the
PR merge is the flow's single irreversibility boundary and its only approval
gate. Upstream of it agents own the work outright and may ask the human only
intent forks (options the agent cannot rank from the repo, the spec, or this
rubric — never "proceed?"); at and past it a human gates every landing, with
no direct-push path; and tracker writes, which bypass the boundary, may be
filed freely but enter the workable frontier (`ready-for-agent`) only through
a human act that explicitly names the work — the label follows the act, and
`backlog` means "not yet human-graduated." There is no emergency path that
reduces scrutiny: urgency changes which ticket the human picks first, never
which checks the ticket's PR runs, so every fix rides a ticket through
`addw-implement`.

## Alternatives Considered

- **Stakes-tiered posture table** — a per-action-class table is more
  expressive but is itself a thing to maintain, and local table edits are
  exactly the drift this decision exists to stop.
- **Agent judgment as queue authorization** — rejected because the PR gate
  catches bad output, not bad priorities; what enters the frontier is a
  spending decision that stays human.
- **Open "ask before anything irreversible" principle** — rejected because
  "irreversible" inflates by judgment; the carve-out below is a closed list
  instead.
- **An expedited mode that defers scrutiny past the merge** — rejected: once
  every reader takes the project's conventions whole, deferring the contract
  tests, cross-model review and doc-impact check is the only thing such a mode
  would change, and deferred scrutiny is reduced scrutiny on the commit that
  lands.

## Consequences

Approval-shaped asks upstream of the boundary do not exist. Anticipatory
filings are `backlog` filings, and they graduate mechanically when a merged
PR whose body names them lands — the merge is the human act naming the work.
Two exceptions are codified: a **closed carve-out list** of non-fork asks,
holding one class — destructive or real-money actions outside the repo —
which grows only by superseding this ADR; and a **bootstrap exception** —
before the repo's first commit no PR machinery exists, so addw-init's
approval asks are the gate.

## Gate

For any new or edited skill step, check: (1) no approval-shaped ask for work
that rides a PR — every in-conversation ask must present an intent fork or
match the carve-out entry; (2) no path lands a commit on the main branch
without a human-merged PR, and no path defers a check the ticket flow runs to
after that merge; (3) no agent filing carries `ready-for-agent` unless a
human act explicitly named that work; (4) no addition to the carve-out list
without superseding this ADR.

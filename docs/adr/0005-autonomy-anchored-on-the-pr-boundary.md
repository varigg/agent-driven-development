# ADR 0005: Autonomy is anchored on the PR boundary

- **Status**: active
- **Date**: 2026-08-11
- **Origin**: ticket varigg/agent-driven-development#83

ADDW drifted from a pure-agent workflow into human-in-the-loop one stage at a
time, leaving approval asks where nothing needed guarding and autonomy where
judgment mattered; this decision replaces those per-stage accidents with one
generating principle. The PR merge is the flow's single irreversibility
boundary and its only approval gate: upstream of it agents own the work
outright and may ask the human only intent forks (options the agent cannot
rank from the repo, the spec, or this rubric — never "proceed?"); at and past
it a human gates every landing, with no direct-push path even for emergencies;
and tracker writes, which bypass the boundary, may be filed freely but enter
the workable frontier (`ready-for-agent`) only through a human act that
explicitly names the work — the label follows the act, and `backlog` means
"not yet human-graduated."

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

## Consequences

Approval-shaped asks upstream of the boundary are removed (addw-compact loses
its three checkpoints; its bloat-triage question survives as an intent fork).
Anticipatory `ready-for-agent` filings become `backlog` filings that graduate
mechanically when the authorizing PR merges. Two exceptions are codified:
a **closed carve-out list** of non-fork asks — scrutiny reduction (e.g.
addw-hotfix's emergency question) and destructive or real-money actions
outside the repo — which grows only by revising this ADR; and a **bootstrap
exception** — before the repo's first commit no PR machinery exists, so
addw-init's approval asks are the gate.

## Gate

For any new or edited skill step, check: (1) no approval-shaped ask for work
that rides a PR — every in-conversation ask must present an intent fork or
match a carve-out entry; (2) no path lands a commit on the main branch without
a human-merged PR; (3) no agent filing carries `ready-for-agent` unless a
human act explicitly named that work; (4) no addition to the carve-out list
without revising this ADR.

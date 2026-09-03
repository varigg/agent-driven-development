# ADDW

The agent-driven development workflow this repo ships as skills. Terms here
govern how the workflow's own documents and skills speak about autonomy,
gating, and the ticket lifecycle.

## Language

**The Boundary**:
The PR merge — ADDW's single irreversibility line and its only approval gate. Work is agent-owned upstream of it, human-gated at and past it.
_Avoid_: merge gate, review checkpoint

**Intent Fork**:
The only legitimate shape for an in-conversation question upstream of the Boundary: a genuine choice between options the agent cannot rank from the repo, the spec, or ADR 0005.
_Avoid_: approval ask, confirmation, checkpoint

**Carve-out**:
The closed, ADR-governed list of non-fork questions an agent may still ask: scrutiny reduction, and destructive or real-money actions outside the repo.
_Avoid_: exception (unqualified), special case

**Scrutiny Reduction**:
An action that drops the flow's own checks — skipping reviews, tests, or steps the workflow normally requires. One of the two Carve-out entries.
_Avoid_: fast path, shortcut

**Backlog**:
A ticket not yet human-graduated: an archive of proposed work awaiting the team's curation — whether it lacks design, authorization, or both. Echoes the agile product backlog.
_Avoid_: icebox, undesigned ideas, parking lot

**Graduation**:
The human act that admits proposed work into the Frontier — an explicit re-label, or a mechanical flip when a human merges the artifact that names the work.
_Avoid_: promotion, triage, approval

**Frontier**:
The open, unblocked, `ready-for-agent` tickets — what an agent may pick up right now.
_Avoid_: queue, ready list

**Bootstrap Exception**:
The window before a repo's first commit, when no PR machinery exists and addw-init's approval questions are the only gate that can be.
_Avoid_: init special case

**Deliverable**:
The independently-checkable unit of work a ticket delivers; a ticket carries exactly one. Checkable means a reviewer can verify it passed or failed without reference to the ticket's other criteria.
_Avoid_: feature, work item

**Complete** (of a spec):
A spec with no open child and any ADR it declared present on the main branch, derived at query time from its children and never stored.
_Avoid_: release-ready, done

**Partial** (of a spec):
A spec with at least one child closed as completed and at least one still open — a tag would ship half its intent, so a release refuses it by default.
_Avoid_: in process, in flight, mid-spec

**Closure** (of a spec):
The human act of closing a Complete spec's issue through a tracker-seam command, recording per child the PR that delivered it and the first tag that shipped it, or that it is still unreleased. Independent of any release.
_Avoid_: release, completion

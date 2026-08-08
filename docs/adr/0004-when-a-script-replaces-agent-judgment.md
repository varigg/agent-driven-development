# ADR 0004: A script replaces agent judgment only when three conditions hold

- **Status**: active
- **Date**: 2026-08-08
- **Origin**: design session

ADDW replaces an agent's judgment with a script only when three conditions
hold together: the step is **fully specified** by the project config plus files
on disk, requiring no project knowledge or taste; the **agent failure mode is
real** — arithmetic, date comparison, cross-file consistency, multi-step
command sequences, or work the harness structurally prevents; and the logic is
**project-agnostic**, so the script ships inside the wholesale skills copy and
runs in every install unedited. A step failing any one of them stays judgment,
because a script needing per-project edits breaks the rule that skills are
never edited, and a script guarding a failure that does not occur is process
mass charged to every future cycle. These conditions and the hook analysis
below were worked out in the determinism sweep of 2026-07-30, whose document
leaves the worktree under ADR 0003; this record carries the date it was
written rather than the date it was decided, because a rule followed as
convention has no reliably knowable decision date, and an invented one is
exactly the quietly-wrong claim ADR 0003 exists to prevent.

## Alternatives Considered

Git hooks were the rival mechanism, and they lose on where they attach rather
than on what they do. ADDW's determinism points are not commit-shaped: the
testing gate fires before the review loop starts and again on every round
resume, while checkpoint commits happen before the tests are even authored, so
a hook fires only at premature, redundant, or mis-scoped moments — and
staged-file scoping cannot see a ticket's test impact. No hook sits on the path
that actually matters, either: the gate summary is consumed downstream as the
reviewer's premise, which makes the problem trustworthy *reporting*, not commit
policing. Hooks also cross ADDW's line against installing project
infrastructure. Fast lint and format hooks remain worthwhile defense-in-depth
for commits made outside the workflow — the project's call, not ADDW's; at
most, init may detect an existing hook setup and note it in the testing doc.

## Consequences

A candidate meeting the first and third conditions but lacking evidence for the
second waits rather than being built. The determinism candidates still unbuilt
are held to an audit showing the need, not to principle, which is why they sit
as a backlog entry rather than a queue of accepted work.

Determinism is always attached by a script that a skill invokes. ADDW installs
nothing into a project's git or CI to satisfy a determinism goal, so the same
mechanism works on a clone with no hooks configured and cannot be silently
disabled by a project's local setup.

## Gate

Before building a script to replace an agent step, check all three conditions
and **name the evidence for the second**. A script justified only by the step
feeling error-prone has not met it, and the cost of being wrong is paid in
every cycle thereafter. If the logic would need per-project editing to work, it
fails the third: the variable belongs in the project config as a key, not in a
skill as code. And determinism is attached by a script a skill invokes — a
proposal to enforce it through the project's git hooks or CI has left ADDW's
mechanism entirely, whatever its merits for the project itself.

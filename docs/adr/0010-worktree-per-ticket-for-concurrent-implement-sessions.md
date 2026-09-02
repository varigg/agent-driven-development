# ADR 0010: `addw-implement` isolates each ticket in its own git worktree

- **Status**: active
- **Date**: 2026-09-02
- **Origin**: ticket varigg/agent-driven-development#138

`addw-implement` Step 3 checked out its ticket branch in the single working copy, so two
sessions working different frontier tickets from the same clone could not each hold their
own branch checked out at once — autonomous parallel execution of the frontier was blocked
by shared-checkout collision, not by review capacity. The fix: a config-gated,
default-on worktree-per-ticket mode. When `ADDW_IMPLEMENT_WORKTREE` is unset or `true`, Step
3 runs `git worktree add -b <type>/<issue>-<slug> <path> "$ADDW_MAIN_BRANCH"` and every
later Mode-B step runs from that worktree instead of the original checkout; any other value
keeps the old in-place `git checkout -b`. `<path>` defaults to a sibling directory of the
repo root (`../<repo-basename>-worktrees/<issue>-<slug>`), overridable via
`ADDW_WORKTREE_ROOT`. Plain `git worktree` was chosen over Claude Code's Agent-tool
`isolation: "worktree"` option because `addw-implement` cannot assume it was launched via
that tool — orchestrating how concurrent sessions get started stays out of scope — and a
harness-native mechanism would make the skill non-portable to other invoking agents (e.g.
Codex); `codex-implement`'s `--sandbox workspace-write` is already cwd-scoped and composes
cleanly with a plain `cd` into the worktree, so no isolation-stacking is needed. This repo's
own dogfood setup keeps `.claude/skills` as a gitignored symlink to `skills/`, which `git
worktree add` — checking out tracked files only — would otherwise leave the new worktree
without; Step 3 recreates the same symlink in the new worktree when the main checkout has
one, a no-op in a real install where `.claude/skills` is an ordinary tracked copy.

## Alternatives Considered

- **Claude Code's `isolation: "worktree"` Agent-tool option** — free isolation for a
  subagent, but only when the invoking agent is Claude Code's own Agent tool; the skill must
  stay usable when invoked by a human, a script, or a different agent (e.g. Codex).
- **Orchestrating concurrent sessions from within `addw-implement`** — rejected as a
  separate concern: how N sessions get started (a human, a script, or independent
  Agent-tool forks each choosing a ticket) is not this ticket's problem, only removing the
  filesystem collision that blocks them once started.
- **Making ticket-claiming an atomic lock** — ADR 0004 already settled that a ticket claim
  is not a lock; a claim *race* (two sessions self-assigning the same ticket) is a separate,
  still-rare problem this ADR does not touch. Worktrees remove only the *filesystem*
  collision ADR 0004 never had to consider.

## Consequences

A frontier of independent tickets can now be worked by concurrent `addw-implement` sessions
against one clone without one session's checkout clobbering another's. Worktree and branch
cleanup after merge stays judgment-based — this ADR does not mechanize it. Scope is
`addw-implement` only: `addw-hotfix`, `addw-release`, and `addw-compact` are not
frontier-driven, so isolating them buys nothing and they are unaffected.

## Gate

A change to Step 3's branch-creation sequence must keep both branches — worktree-enabled and
disabled — behaving identically to what they replace in every later Mode-B step; a change
that only updates one path leaves the other silently stale.

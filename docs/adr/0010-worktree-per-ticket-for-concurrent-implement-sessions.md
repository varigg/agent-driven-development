# ADR 0010: `addw-implement` isolates each ticket in its own git worktree

- **Status**: active
- **Date**: 2026-09-02
- **Origin**: ticket varigg/agent-driven-development#138

`addw-implement` Step 3 checked out its ticket branch in the single working copy, so two
sessions working different frontier tickets from the same clone could not each hold their
own branch checked out at once — autonomous parallel execution of the frontier was blocked
by shared-checkout collision, not by review capacity. The fix: a config-gated,
default-on worktree-per-ticket mode. When `ADDW_IMPLEMENT_WORKTREE` is unset or `true`, Step
3 runs `skills/lib/worktree/create.sh "$ADDW_MAIN_BRANCH" <type>/<issue>-<slug> <path>`,
which fetches and branches off the **remote-tracking** ref rather than this checkout's own
branch — a concurrent session's `checkout && pull` right here would recreate the exact
shared-working-tree race this mode exists to remove, and a plain `git fetch` never touches
this checkout's working tree or index — and every later Mode-B step runs from that worktree
instead of the original checkout; any other value keeps the old in-place `git checkout -b`.
`<path>` defaults to a sibling directory of the repo root
(`../<repo-basename>-worktrees/<issue>-<slug>`), overridable via `ADDW_WORKTREE_ROOT`. Mode A
(review-comments resume) gets a matching fix: `skills/lib/worktree/find.sh <branch>` locates
the worktree, if any, already holding a ticket's branch, so a resume enters it instead of
attempting a second checkout of a branch git refuses to check out twice. The mechanism is
scripted rather than left as inline instructions because it meets ADR 0004's bar: fully
specified by the project config and files on disk, project-agnostic, and a real
multi-step-command failure mode — branching off the wrong ref, or a raw symlink copy that
silently escapes the new worktree, are exactly the errors a passing skim of agent-authored
shell would not catch; `tests/worktree.test.sh` exercises both scripts against real local git
repositories. Plain `git worktree` was chosen over Claude Code's Agent-tool
`isolation: "worktree"` option because `addw-implement` cannot assume it was launched via
that tool — orchestrating how concurrent sessions get started stays out of scope — and a
harness-native mechanism would make the skill non-portable to other invoking agents (e.g.
Codex); `codex-implement`'s `--sandbox workspace-write` is already cwd-scoped and composes
cleanly with a plain `cd` into the worktree, so no isolation-stacking is needed. This repo's
own dogfood setup keeps `.claude/skills` as a gitignored symlink to `skills/`, which `git
worktree add` — checking out tracked files only — would otherwise leave the new worktree
without; `create.sh` recreates the symlink, pointed at the new worktree's own tracked
`skills/` copy rather than the original symlink's target verbatim, whenever the main checkout
has one — a no-op in a real install where `.claude/skills` is an ordinary tracked copy.

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

A change to `worktree/create.sh` or `worktree/find.sh` must keep Step 3's two branches
(worktree-enabled and disabled) and Mode A's resume path in agreement — Mode B decides where
a ticket's branch lives, and Mode A must always be able to find it, or fall back cleanly when
worktree mode was off. A change that updates one side and not the other leaves the other
silently stale.

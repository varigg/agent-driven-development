# ADR 0012: Worktree isolation is decided from the clone's state, not a config key

- **Status**: active
- **Date**: 2026-09-19
- **Origin**: ticket varigg/agent-driven-development#172

ADR 0010 gave `addw-implement` a config-gated worktree-per-ticket mode — a toggle, a
default directory convention beside the clone, and a second key to move it — to remove
the shared-checkout collision that blocked two
sessions from working different frontier tickets against one clone. This ADR keeps that
finding and drops the shape around it. Only four outcomes ever mattered: the ticket branch
starts from the remote main, never the clone's own local branch, because `git fetch`
touches no working tree while `checkout && pull` in a shared clone is the collision
itself; the branch is checked out somewhere the rest of the session runs from without
disturbing another session's checkout; every later step, the cwd-scoped implement adapter
included, runs from that checkout; and a review-comments resume works wherever the branch
is already checked out, since git refuses a second checkout of the same branch. None of
those is a directory layout, and the toggle never drove correctness: a clone that sits
clean on main has nobody using it, so checking out in place is safe, and a clone that does
not — another branch checked out, a dirty tree — is a session's work in progress, so the
arriving session isolates itself in a worktree. That rule is decidable from `git status`
alone, so the key that encoded a per-project preference for it is replaced by the
observation, and the cost preference the key also carried (never pay for a worktree on a
single-session project) is met by the same rule: a single session finds its clone clean on
main and works in place. Where a worktree goes is the agent's to choose for its harness,
and the branch name `<type>/<issue>-<slug>` is the only shape contract that remains.
`worktree/create.sh` stays as the portable, tested way to get a worktree that honours the
first outcome and carries this repo's dogfood `.claude/skills` symlink; `worktree/find.sh`
stays as the resume-time locator. The rejection of harness-native worktree creation for
the portable path stands unchanged from ADR 0010: the skill must remain usable when
invoked by a human, a script, or a different agent, and a harness may still be the thing
that *enters* the worktree once it exists — the skill states the outcome and names no
mechanism.

## Alternatives Considered

- **Keep the toggle, drop only the directory keys** — the toggle's remaining job was a
  cost preference the agent can read from the clone as well as a key can, and a key that
  says `false` on a clone another session has left mid-ticket reintroduces the collision
  the mode was created to remove. Isolate-by-state has no such failure.
- **Always isolate, unconditionally** — pays a worktree on every ticket of a
  single-session project, and leaves the release and hotfix skills, which want the clone
  on main, competing with a checkout nothing else is using.

## Consequences

Two config keys leave the install contract with a schema bump (ADR 0008); the reader
ignores stale entries. An install that had opted out of worktrees sees one whenever its
clone is not clean on main — the state a second session must never share. Worktree and
branch cleanup after merge stays judgment-based, as before.

## Gate

Mode B decides where a ticket's branch lives — in place when the clone is clean on main,
a worktree otherwise — and Mode A must always be able to find it: `worktree/find.sh`
locates either, since the clone is itself a listed worktree, and a plain checkout in the
clone is the fallback when it returns nothing. A change to Step 3's
rule, to `create.sh`, or to `find.sh` must keep those two sides in agreement, or the other
is silently stale. No skill reintroduces a config key, a directory convention, or a
harness-specific mechanism for any of the four outcomes.

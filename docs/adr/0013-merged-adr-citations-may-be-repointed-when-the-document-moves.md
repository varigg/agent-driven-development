# ADR 0013: A merged ADR's citation may be repointed when the cited document moves

- **Status**: active
- **Date**: 2026-09-20
- **Origin**: ticket varigg/agent-driven-development#166

Write-once protects the *meaning* a merged ADR records — rewriting what a decision said
would destroy the only value the record has. It says nothing about a citation whose target
document later moves, and taken literally it forbids fixing that too: every merged ADR
citing the old path holds a dead reference forever, and a restructuring that would otherwise
be uniform stays permanently lopsided around the paths two or three frozen ADRs happen to
pin. Repointing a moved file's path does not change what was decided, so it is closer to
fixing a broken link than to revising history. This ADR carves out exactly that: a merged
ADR's citation may be edited when, and only when, the edit is meaning-preserving and
mechanically verifiable — the old and new paths are provably the same document
(`git log --follow`), the edit touches nothing but the reference, and a human approves it.
No agent repoints a citation unprompted. `skills/lib/templates/adr.md`'s rules section
carries the exception in the same words, since that file — not this ADR — is what a
downstream install actually ships and reads.

## Alternatives Considered

- **A stub convention (leave a redirect at the old path, never touch the ADR)** — preserves
  write-once absolutely, with no boundary to police. Rejected because it compounds: unlike
  supersession, which departs rarely and for a reason worth a permanent pointer, a path move
  is a routine, frequent event, and a stub per move accumulates a growing set of pointer
  files plus an extra hop for every future reader who lands on one.
- **No exception; downstream repos strand the citation or edit the ADR anyway** — the status
  quo the ticket was filed against. Leaves the rule's plain text at odds with its own intent:
  it protects meaning, not paths, but reads as protecting both.

## Consequences

A path repoint is now a permitted, narrow edit to a merged ADR rather than a forbidden one —
the boundary is "meaning-preserving and mechanically verifiable," not "small" or "obviously
fine," and the check is a specific command, not a feeling. Everything else about write-once
is unchanged: a decision's prose, its Status, Date, and Origin remain frozen from the merge
boundary. This repo carries no dead citations from a restructuring that predates this ADR;
none exist yet.

## Gate

A PR that edits a merged ADR must touch only a path in a citation, never its prose, Status,
Date, or Origin — a diff that changes anything else is not this exception. The PR body (or
commit message, for a same-repo move) states the old and new paths and that
`git log --follow` on the new path reaches the old one; a reviewer who cannot see that
evidence in the PR should ask for it before approving, not assume it was checked. A human
approves the edit — an agent's own judgment that a path move is meaning-preserving is not
sufficient authorization to make the edit unprompted.

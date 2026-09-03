# ADR 0011: Release and spec lifecycles are independent

- **Status**: active
- **Date**: 2026-09-03
- **Origin**: spec issue varigg/agent-driven-development#144

A release and a spec used to share one lifecycle, inherited from TRIP's
*one spec, one release*: a spec's only exit from `open` was the post-merge
tail of a release, so every judgment about whether a spec was finished lived
inside `addw-release`, and cutting a version could not happen without also
deciding which spec's intent it completed. This splits the two: a **release**
tags whatever the main branch has accumulated since the last tag and closes
nothing; its only guard is that no spec is **Partial** — at least one child
delivered and the spec not yet Complete — since a tag must never ship half an
intent, and that guard may be overridden only by informed human choice,
recorded in the release PR body. A **spec** with children is **Complete**
when none is open and any ADR it declared is present on the main branch,
derived at query time from its children and never stored; a childless spec is
neither Complete nor Partial, since decomposition never happened. Closing a
Complete spec's issue is human housekeeping done through a tracker-seam
command, never a side effect of a tag. *Not planned* reverts to meaning what
the words say — a ticket abandoned, permanently — and is a close only a human
directs; deferring a ticket out of a spec without abandoning it is a distinct
operation, detach, which moves it to the backlog instead. This ADR supersedes
nothing — ADR 0005 is silent on release.

## Gate

No skill closes a ticket as *not planned* on its own judgment — only a
human-directed action does.

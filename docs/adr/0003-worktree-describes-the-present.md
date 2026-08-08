# ADR 0003: The worktree describes the present; superseded documents move to the tracker

- **Status**: active
- **Date**: 2026-08-08
- **Origin**: #36

Living-docs discipline already required that documents describe only current
design, exempting dated records from retro-editing — a rule written for human
readers, who pay a moment's judgment on a stale document and pay it
consciously. Agents read the same tree through grep, which is flat: a match
line carries the stale claim without the `**Status**` header that disclaims it
four screens above, so the cost becomes a wrong premise paid silently, on every
session, by every reader — including the codex adversary this repo deliberately
points at the same tree. A document therefore leaves the worktree when it stops
being true and lands as a closed, labeled tracker issue, following the backlog's
migration in #13. Detection and departure are deliberately separate steps: a
proposal overtaken by a published spec, or an ADR overtaken by a newer one, is
noticed wherever that happens and filed as a retirement ticket, while the
deletion itself happens only at the Doc Impact step of an implementing ticket —
the one place a reviewed diff can carry it. The commit preceding the deletion is
the local archive, so nothing is destroyed — the retrieval cost simply moves from
every read to on demand.

## Alternatives Considered

A `**Status**` line disclaiming the body was tried on the determinism proposal
and is what this ADR reverses: it addresses a reader who arrives at the top of
the file, and grep does not. Correcting stale passages in place fails
differently — it leaves a document in the read path whose only remaining job is
historical, and re-duplicates lists the tracker already owns. An `obsolete/`
directory is the strongest of the three, because it puts status in the path,
which is the one place grep can see it; it was rejected as a *primary*
mechanism because it is a policy requiring enforcement on every tool, in every
install, indefinitely. Ignore files cover ripgrep alone; a `Read` deny rule
neither stops Grep from returning matched lines nor survives the many Bash
readers of the same bytes; and per-project harness configuration rides neither
the wholesale `skills/` copy nor the codex CLI, so it would hide the folder
from the model under our control while leaving it open to the one we invoke
against the tree deliberately. It is retained as the documented fallback where
no tracker is available — issues disabled, a non-GitHub tracker, an air-gapped
clone — because it degrades loudly rather than silently.

## Consequences

`addw-maintain`'s superseded-vocabulary sweep loses its input, since it read the
superseded ADRs as the source list naming the vocabulary it hunts. It does not
follow that the sweep should fetch them back: obtaining them from the tracker
would mean reading a document full of stale present-tense claims into the one
session auditing the tree for exactly that. The sweep is instead reframed as a
positive check — living-doc vocabulary agrees with the **active** ADRs — which
reads only in-tree, present-tense-true sources, needs no network, and finds drift
the original could not, since the original could only ever find terms someone had
thought to write down. Sweeping the retired vocabulary is the superseding
author's job, in the PR that supersedes, while they still hold both documents.

ADR numbering authority stays in the directory, which is worth stating because
the opposite looks true at a glance. A departed ADR leaves a hole, so the
*first free* number stops being safe to propose — that hole is a number already
spent. But an ADR can only leave by being superseded, `Status` offers no third
state, and numbers are sequential and never reused, so a superseder always
carries a higher number than what it supersedes and is `active`, hence in the
tree. For every departed ADR there is therefore a present one numbered above
it, and `max(directory) + 1` remains correct. Derive the next number as max
plus one, never as the first gap. Archival is what makes those two diverge, so
this change is also what makes the intuitive answer wrong; the rule is
therefore encoded in a script the authoring step points at, rather than left
standing as prose in this consequence. The rest of the scaffolder backlogged in
#31 — template copy, date stamp, supersede-pointer flip — stays a convenience,
with nothing yet evidencing it.

Archived bodies would otherwise enter the issue snapshot, since `tracker.sh
snapshot` is `--state all` with bodies included. The seam therefore drops
`archived` issues client-side, immediately after the fetch, so that no consumer
can reason over a retired document's body — not `resolve.sh`, and not the
reference check that archival itself performs. Excluding server-side was
rejected: `gh issue list` has no exclude-label flag, so it would mean `--search`,
which moves a live query onto an eventually-consistent search index and imposes a
hard result cap. That the archive is never read into context is part of this
decision, not an implementation detail, and the filter is what makes it hold by
construction rather than by each caller's good behavior. Single-issue reads
through `view` are unaffected, so an archive stays deliberately fetchable by
number.

Active ADRs are unaffected, and deliberately so. An active ADR is a live
constraint rather than a dated record, and its Gate section exists to be
consulted in-tree while reviewing a diff; moving it to the tracker would remove
a guardrail rather than a poison, and put a network call on the review path.

## Gate

The test is **"is this still true?"** — never "is this about the past?" A
document may narrate history and remain entirely true: rejected alternatives,
incident notes, and an ADR's own reasoning are the highest-value content in a
tree precisely because the code cannot supply them, and evicting them lets
later work confidently re-propose what was already refuted. What leaves is a
document making present-tense claims about a tree that has moved on.

Before any such deletion, confirm two things: that the document's durable
content survives elsewhere — in the spec issue, an ADR, or the superseding
document — and that no living doc still points at the file. A deletion that
strands a reference has moved the defect rather than fixed it.

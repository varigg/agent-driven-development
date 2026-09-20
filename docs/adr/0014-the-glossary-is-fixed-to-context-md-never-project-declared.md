# ADR 0014: The glossary is fixed to `CONTEXT.md`, never project-declared

- **Status**: active
- **Date**: 2026-09-20
- **Origin**: ticket varigg/agent-driven-development#173

`docs/agents/domain.md` is the domain-layout contract ADDW's skills read rather than
hardcode — but only one path in it was ever meant to move. The ADR directory is
genuinely project-declared: `addw-init` resolves it from `domain.md`'s prose and records it
as `ADDW_ADR_DIR`, because a project may keep decisions somewhere other than `docs/adr/`. The
glossary was never that kind of seam. The mattpocock skills this repo overlays — `tdd`,
`diagnosing-bugs`, `improve-codebase-architecture`, `domain-modeling` — read and write
`CONTEXT.md` at the repo root unconditionally; none of them consult `domain.md` first. ADDW's
own skill wording nonetheless described the glossary as living "at the location domain.md
declares," alongside the ADR directory, as if the two were symmetric. They are not: nothing
resolves a declared glossary path into a key the way `ADDW_ADR_DIR` does, so a project whose
`domain.md` names a different glossary location — `docs/glossary.md`, say — gets a split
toolchain. ADDW's skills, reading the declaration, find the vocabulary; the mattpocock skills,
reading nothing, don't, and may seed a second glossary at the root the next time they resolve
a term. This ADR fixes the glossary to `CONTEXT.md` at the repo root (or the per-context files
a root `CONTEXT-MAP.md` points at, matching Matt's own multi-context layout) as a hard
convention, not a per-project declaration. `domain.md` keeps declaring only the ADR directory.

## Alternatives Considered

- **Assert a stub convention via `doctor.sh`** — keep the declared-path indirection for the
  glossary too, and have doctor check that a root `CONTEXT.md` exists and either is the
  glossary or points at it. Preserves per-project glossary placement, but adds a mechanism
  (a stub file, a doctor check to verify it) for a seam that was never load-bearing anywhere
  in the toolchain — nothing consumes a declared glossary path today, so there is nothing a
  stub would be redirecting.
- **Document the split as a known gap, unfixed** — leaves every adopter who customizes
  `domain.md`'s glossary section to rediscover the split independently, which is the state
  the ticket was filed against.

## Consequences

A project's `domain.md` may still describe its file structure however it likes in prose, but
ADDW's own skills (`addw-init`, `addw-implement`, `addw-maintain`, `doctor.sh`,
`docs/cycle-walkthrough.md`) now state the glossary location as fixed rather than resolving
it from the contract. A project that had customized the glossary to a non-root path is now
out of step with the convention this repo documents; migrating it back to `CONTEXT.md` (or a
`CONTEXT-MAP.md`-pointed per-context file) is what restores the mattpocock skills' visibility
into it. `ADDW_ADR_DIR` remains the only glossary/ADR-layout value any skill resolves from
config.

## Gate

No skill or doc introduces a config key, a resolution step, or prose implying the glossary
path is project-declared — only the ADR directory is. A skill that needs the glossary reads
`CONTEXT.md` at the repo root (or the per-context files a root `CONTEXT-MAP.md` points at)
directly, the same way the mattpocock skills already do.

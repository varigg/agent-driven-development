# ADR 0019: ADDW generates no testing doc; intent is read from project-declared charter sources

- **Status**: active
- **Date**: 2026-10-07
- **Origin**: ticket varigg/agent-driven-development#214

ADR 0016 moved rules to sources the project declares. Two documents `addw-init` generates
were left over: `TESTING.md` and `docs/charter.md`. No skill reads `TESTING.md` at runtime.
Init copies its verification recipes into the `ADDW_RECIPE_*` keys, the gate reads only those
keys, and doctor checks only the file's headings. That leaves a write-only copy of the
recipes, an as-built description of the test layout that ADR 0016 forbids, and normative
rules (coverage expectations, test-writing conventions, integration/E2E impact rules) that
no skill reads. The charter is read. Spec review, release's charter-fit check, maintain's
link sweep and implement's doc-impact step all use it, and all hardcode `docs/charter.md`.
Its upkeep is cheap, but most projects already state their intent in a README or a vision
document, and a fixed ADDW copy duplicates that. The decision is that **ADDW generates no
testing doc**. Testing rules are ordinary rules, read from the files `ADDW_CONVENTIONS`
lists, and the conventions seed gains a testing topic that init's fallback interview
covers. **Intent is read from the files a new `ADDW_CHARTER` key lists**, and
`docs/charter.md` is only the fallback init writes when a project declares none. ADR
0014's reason for fixing a path does not apply here: the glossary is fixed because
third-party skills read `CONTEXT.md` unconditionally, and only ADDW reads the charter.

## Alternatives Considered

- **Keep `TESTING.md`, trimmed to its normative part.** Rejected. That makes a second
  ADDW-owned rules file, which ADR 0016 already rejected for `docs/CONVENTIONS.md` as a
  universal home.
- **A separate `ADDW_TESTING` key listing testing-rule files.** Rejected. Testing rules
  are reviewed against a diff the same way every other rule is, so the key would just be
  a second `ADDW_CONVENTIONS`.
- **Keep the charter at its fixed path.** Rejected despite cheap upkeep, because it keeps
  a copy of intent most projects already state elsewhere.
- **Retire the charter outright.** Rejected. It would remove the intent checks in spec
  review and release, which have nothing else to judge against.
- **A doctor WARN for files ADDW used to own but no longer lists.** Rejected. A
  project can keep `TESTING.md` or `docs/ARCHITECTURE.md` for its own reasons, so every
  such WARN risks being a false positive about a file that is no longer ADDW's.

## Consequences

- **`ADDW_CHARTER`** has `ADDW_CONVENTIONS`' semantics. If it is absent, doctor FAILs
  and readers refuse. An explicit `ADDW_CHARTER=` means the project declares no intent
  source, and intent checks say they ran without one. The key lists files only, and a
  listed file that is missing FAILs doctor. Init discovers candidate sources and the
  human confirms them. The charter interview survives only as the fallback for an empty
  confirmed list, and it writes `docs/charter.md`.
- **The intent admission test** decides what a charter source is: could a spec or a
  release be judged as contradicting something the file says? A file need not hold only
  intent. Readers read each listed file whole, so a mixed README costs reading noise.
  That noise is accepted, because carving intent out of a project's own file would mean
  ADDW owning a copy again.
- **Doctor flags no file ADDW no longer owns.** There is no WARN for a leftover
  `TESTING.md`. This also narrows ADR 0016's consequence that doctor WARNs on an
  unlisted `docs/ARCHITECTURE.md`: that WARN is retired, for the same reason. ADR 0016
  itself is not edited.
- **Existing installs migrate at a schema boundary** whose spec cites this ADR. The
  upgrading agent picks out the rules in `TESTING.md` that pass ADR 0016's admission
  test, and the human chooses where each one goes: into a listed rule source (the human
  approves the diff), into `docs/CONVENTIONS.md`, or nowhere. A destination the human
  picks and a diff the human approves is the human's own edit, so this is consistent
  with ADR 0016's rule that ADDW never edits a project's own context files. The step is
  prose guidance with no ADDW script. Afterwards `TESTING.md` belongs to the project.
- **The impact rules are headed for a triggered E2E rung in the gate.** That is a
  direction, not a commitment. It is tracked as its own proposal and is not admitted by
  this ADR.

## Gate

No skill generates or requires a testing doc. No skill reads intent from a hardcoded
path. A skill that needs the project's intent reads the files `ADDW_CHARTER` lists,
whole. Doctor checks only files that ADDW owns or that a key lists.

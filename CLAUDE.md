# CLAUDE.md

This repo *is* the ADDW workflow — the skills under `skills/` are the product,
shipped by copying that directory wholesale into another project's
`.claude/skills/`. There is no application code here. Read `README.md` for what
ADDW is and how the flow runs; this file covers working *on* it.

## Where the work is

Work state lives in GitHub issues, not in this tree. The **frontier** — tickets
whose blockers have all merged — is the answer to "what's next":

```
bash skills/lib/tracker/tracker.sh frontier
```

That script is also the tracker **seam**: every `gh` call for tracker work
routes through it, so reach for it rather than `gh issue` directly.

Issues labeled **`backlog`** are undesigned ideas, not tickets — nothing there
is workable until it graduates into a proposal and a spec, and the frontier
skips them. They carry no `## Parent`.

## Working a ticket

This repo dogfoods its own workflow: one ticket per session, `/addw-implement`,
contract tests frozen before implementation, deterministic gate, `codex-code-review`
loop to `APPROVED`, then a PR that the human reviews and squash-merges. The base
branch is `master` (`ADDW_MAIN_BRANCH` in `docs/addw.env`), and PR titles must
parse as conventional commits — the release version and changelog are derived
from them by `skills/lib/release/derive.sh`.

Verify with the gate, which runs this repo's own recipes:

```
bash skills/lib/gate/gate.sh      # lint (shellcheck) → typecheck (skipped) → tests
bash tests/run.sh                 # tests alone
```

Its one-line summary is what the PR body carries verbatim.

## Conventions that bite

- **Skills are byte-identical across installs.** Nothing project-specific ever
  enters a `SKILL.md`; per-project values live in `docs/addw.env` and the living
  docs a skill points at.
- **`docs/addw.env` must stay shell-clean.** Scripts source it directly
  (`skills/lib/codex/_common.sh` does so whenever it exists), so a syntax error
  there breaks skills far from the edit.
- **Skill folder names are docs contract.** Renames ride a schema boundary and
  get an `UPGRADING.md` entry; they are never free cosmetics. The
  `addw-4-maintain` → `addw-maintain` rename waited for one and rode the schema
  3 → 4 boundary, which is what such a rename is supposed to do.
- **`skills/lib/templates/adr.md` is the authoritative ADR format** here, over
  any format bundled with a skill — `domain-modeling`'s included. It ships with
  the skills rather than being generated per project, and `ADDW_ADR_TEMPLATE` is
  what names it; an install points that key at `.claude/skills/lib/...`, or at
  its own file if it keeps its own format.
- **Shared scripts live in `skills/lib/`**, a non-skill directory that rides the
  wholesale `skills/` copy: `tracker/`, `gate/`, `release/`, `docs/`, `codex/`.
  A script two skills call belongs here, not in whichever skill happened to own
  it first — `skills/lib/README.md` is the layer's contract. That contract is
  also a split: the README owns the layer's *rationale*, and a script header
  owns its usage block, flags, and exit codes. A header explaining why the
  design is what it is has started a second copy of a document it delegated to.

## Pointers

| Where | What |
| --- | --- |
| `README.md` | What ADDW is, the flow, the skills reference |
| `docs/proposals/pocock-overlay.md` | The design ADDW is built on; issue #2 supersedes it where they differ |
| `UPGRADING.md` | Structural steps per schema boundary |
| `docs/cycle-walkthrough.md` | The guided tour of one overlay cycle, pointing into the skills for every rule |

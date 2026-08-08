# CLAUDE.md

This repo *is* the ADDW workflow — the skills under `skills/` are the product,
shipped by copying that directory wholesale into another project's
`.claude/skills/`. There is no application code here. Read `README.md` for what
ADDW is and how the flow runs; this file covers working *on* it.

ADDW is mid-rewrite onto the Pocock-overlay design. `docs/proposals/pocock-overlay.md`
is that design; spec issue #2 is its authoritative statement and the parent of
every open ticket.

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
- **Skill folder names are docs contract.** Renames — `addw-4-maintain` →
  `addw-maintain`, for one — ride a schema boundary and get an `UPGRADING.md`
  entry; they are never free cosmetics.
- **Shared scripts live in `skills/lib/`**, a non-skill directory that rides the
  wholesale `skills/` copy: `tracker/`, `gate/`, `release/`, `docs/`, `codex/`.
  A script two skills call belongs here, not in whichever skill happened to own
  it first — `skills/lib/README.md` is the layer's contract.

## Pointers

| Where | What |
| --- | --- |
| `README.md` | What ADDW is, the flow, the skills reference |
| `docs/proposals/pocock-overlay.md` | The rewrite design; issue #2 supersedes it where they differ |
| `UPGRADING.md` | Structural steps per schema boundary |
| `docs/cycle-walkthrough.md` | Narrates the *previous* generation's cycle; stale until #13 reworks it |

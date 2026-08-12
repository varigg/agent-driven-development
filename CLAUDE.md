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
is workable until it graduates into a spec and the tickets decomposed from it,
and the frontier skips them. They carry no `## Parent`.


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
| `UPGRADING.md` | Structural steps per schema boundary |
| `docs/cycle-walkthrough.md` | The guided tour of one overlay cycle, pointing into the skills for every rule |

## Agent skills

Config for Matt Pocock's engineering skills, which ADDW overlays. These files
are repo config, not product — they sit outside `skills/` and ride no install.

### Issue tracker

GitHub Issues on `varigg/agent-driven-development`, via the `gh` CLI. See
`docs/agents/issue-tracker.md`, whose closing section records how those direct
`gh` calls coexist with ADDW's tracker seam.

### Triage labels

The five canonical roles, each mapping to itself. See
`docs/agents/triage-labels.md`. `ready-for-agent` is shared with ADDW's frontier
query and must not be renamed.

### Domain docs

Single-context — a root `CONTEXT.md` (maintained by `/domain-modeling`) plus
`docs/adr/`. See `docs/agents/domain.md`.

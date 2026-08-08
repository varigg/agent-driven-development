# Upgrading an ADDW install

Skills are byte-identical in every install and carry no project state. The
common upgrade is therefore:

1. Replace the install's `.claude/skills/` contents wholesale with this repo's
   `skills/`.
2. Keep `docs/addw.env` untouched, except: add any newly introduced keys (see
   the config template in `addw-init`'s Generate step) and bump `ADDW_SCHEMA`
   if a structural boundary below was crossed.
3. Run `bash .claude/skills/addw-init/scripts/doctor.sh` from the repo root.
   It compares the install's `ADDW_SCHEMA` against the generation the new
   skills expect and verifies the docs contract — a FAIL means a structural
   step was missed.

## Knowing what you're upgrading from

`ADDW_SCHEMA` in `docs/addw.env` is the install's **generation marker**. It
changes only when a version boundary alters the docs contract (file names,
locations, retired artifacts) — not on every release. Read it with
`grep ADDW_SCHEMA docs/addw.env`. An install with no `docs/addw.env` and
`TRIP-*` skill folders is generation 2.

Apply every section below between your install's schema and the current one,
oldest first. Each section's last step is bumping `ADDW_SCHEMA`. This file is
read only when upgrading; no skill loads it as context.

## Schema 2 → 3

Was automated by the `addw-upgrade` skill — retired 2026-07-28 after the
last generation-2 install (adventure-library) was migrated. Generation-2
installs carried project values inside the skills, which had to be extracted
and relocated first. The structural steps, kept for the record:

- Skill folders `TRIP-<x>` → `addw-<x>`; `TRIP-review` retired (checklist
  lives at `codex-code-review/checklist.md`).
- `docs/ARCHI.md` → `docs/ARCHITECTURE.md`; `docs/ARCHI-rules.md` →
  `docs/ARCHITECTURE-rules.md` (contents unchanged).
- A new `docs/addw.env` is written from the extracted values (generation 2 has
  no config file).
- `docs/2-changelog/changelog_table.md` → root `CHANGELOG.md` verbatim (dated
  record; new entries prepend in the v3 format). `docs/3-code-review/` and
  per-release changelog files stay put, frozen.
- References to old names in living docs, CLAUDE.md, and README updated
  (dated records exempt).
- `ADDW_SCHEMA=3` (included in the freshly written `addw.env`).

## Schema 3 → 4

The Pocock-overlay generation. ADDW stops owning alignment, specification, and
decomposition — [Matt Pocock's skills](https://github.com/mattpocock/skills) do
those now — and work-item state leaves the repo for GitHub issues. Nothing here
is automated: there is no upgrade skill, and both deletions below are yours to
make.

Replacing `.claude/skills/` wholesale handles the skill folders themselves
(`addw-1-plan`, `addw-research`, `addw-test`, and `codex-plan-review` retire;
`addw-2-implement`, `addw-3-release`, and `addw-4-maintain` lose their numbers;
`skills/lib/` arrives as the shared script layer). The steps below are what the
copy cannot do for you.

### 1. Install Matt's skills and run his setup

ADDW no longer works standalone: doctor requires the artifacts his setup skill
writes (`docs/agents/issue-tracker.md`, `docs/agents/domain.md`), and the
configured tracker must be **GitHub** — the overlay is GitHub-only. Run
`setup-matt-pocock-skills` before anything else, then create ADDW's two labels
(`ready-for-agent` is Matt's and is never touched):

```bash
bash .claude/skills/lib/tracker/tracker.sh create-label spec
bash .claude/skills/lib/tracker/tracker.sh create-label backlog
```

A missing frontier label fails silently as a forever-empty frontier, so doctor
checks all three.

### 2. Migrate the backlog, then delete the file

**Order matters — the file is the only copy.** For each *open* entry, open an
issue carrying the `backlog` label and no `## Parent` section, so the frontier
resolver skips it until you graduate it into a spec:

```bash
bash .claude/skills/lib/tracker/tracker.sh create "<title>" <body-file> backlog
```

Entries the intervening work already delivered are not migrated; they are
history, and git has them. An entry whose framing no longer resolves — one
written about plan documents, say — is restated in current terms rather than
copied across verbatim.

Only once every open entry is an issue:

```bash
git rm docs/backlog.md
```

Doctor fails while the file survives, because an un-migrated entry is an idea
stranded where no skill will read it again.

### 3. Delete the plans directory — safe, expected, and yours to do

Plans are **transient**. Everything durable about them already lives in the
ADRs, `ARCHITECTURE.md`, and the tests they produced, and git history is the
archive for the rest, so `docs/1-plans/` can go:

```bash
git rm -r docs/1-plans/
```

Two things this is not. ADDW never deletes the directory itself, and doctor
does not check for it — keeping it costs nothing and no skill reads it. And
existing **ADR `Origin:` lines that cite a plan path are never touched**:
origins are historical provenance, exempt from liveness checking and expected
to outlive their targets. Retro-editing a dated record to point somewhere
tidier is precisely what the ADR rules forbid.

### 4. Take the merged ADR template and declare it authoritative

New installs get both from `addw-init`; an upgrade delivers them by hand.
Replace the installed template at `<ADDW_ADR_DIR>/template.md` with the merged
format in `addw-init`'s § *The ADR contract* — a one-paragraph body, a
mandatory two-state `Status` (`active | superseded by ADR-NNNN`, no third
state), `Date`, `Origin`, and a `Gate` section for guardrail decisions. Then add
one line to `CLAUDE.md` or `AGENTS.md` naming that path and calling it
**authoritative**, which is what overrides the ADR format bundled with Matt's
`domain-modeling`. Doctor verifies both, and checks the `Status` states rather
than the field's mere presence — a skill-bundled `proposed / accepted /
deprecated` template has the field too.

Existing ADRs are not reformatted. The template governs what gets written next.

### 5. Reconcile `docs/addw.env`

Add, filling the values from `TESTING.md`'s Verification Recipes and the ADR
location the domain-layout contract declares:

- `ADDW_ADR_DIR` — no skill hardcodes an ADR path any more.
- `ADDW_RECIPE_LINT`, `ADDW_RECIPE_TYPECHECK`, `ADDW_RECIPE_TESTS_AFFECTED` —
  all three keys must be **present**; an empty value is a step this project
  does not have, and the gate reports it as a visible skip. An absent key is a
  gap, and doctor tells the two apart.

Remove:

- `ADDW_TUTORIALS` — tutorials have no consumer left in the skill set.
- `ADDW_PLAN_REVIEW_SKILL` — the role retired with the plan skill. Doctor fails
  on a survivor by name, so it cannot be mistaken for a missing adapter.

### 6. Update stale references

Sweep the install's own `CLAUDE.md`/`AGENTS.md`, `README.md`, and living docs
for the retired skill names and for `docs/1-plans/` and `docs/backlog.md`.
Dated records — ADRs, the changelog, maintenance reports — are exempt, as
always.

### 7. Bump and verify

```bash
# in docs/addw.env
ADDW_SCHEMA=4
```

```bash
bash .claude/skills/addw-init/scripts/doctor.sh
```

`HEALTHY` means the migration landed.

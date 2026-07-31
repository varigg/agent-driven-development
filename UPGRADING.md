# Upgrading an ADDW install

Skills are byte-identical in every install and carry no project state. The
common upgrade is therefore:

1. Replace the install's `.claude/skills/` contents wholesale with this repo's
   `skills/`.
2. Keep `docs/addw.env` untouched, except: add any newly introduced keys (see
   the template in `addw-init` Phase 6) and bump `ADDW_SCHEMA` if a structural
   boundary below was crossed.
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

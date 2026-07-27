# Upgrading an ADDW install

Skills are byte-identical in every install and carry no project state. The
common upgrade is therefore:

1. Replace the install's `.claude/skills/` contents wholesale with this repo's
   `skills/`.
2. Keep `docs/addw.env` untouched (add any newly introduced keys — see the
   template in `addw-init` Phase 6).

Some version boundaries also change the **docs contract** (file names,
locations, retired artifacts). Those structural steps are listed below, newest
first — apply every section between your install's version and the target.
This file is read only when upgrading; no skill loads it as context.

## v2 → v3

Automated by the `addw-upgrade` skill (available for this boundary only — v2
installs carry project values inside the skills, which must be extracted and
relocated first; see that skill). The structural steps it performs:

- Skill folders `TRIP-<x>` → `addw-<x>`; `TRIP-review` retired (checklist
  lives at `codex-code-review/checklist.md`).
- `docs/ARCHI.md` → `docs/ARCHITECTURE.md`; `docs/ARCHI-rules.md` →
  `docs/ARCHITECTURE-rules.md` (contents unchanged).
- `docs/trip.env` does not exist on v2 — extracted values are written to a new
  `docs/addw.env`.
- `docs/2-changelog/changelog_table.md` → root `CHANGELOG.md` verbatim (dated
  record; new entries prepend in the v3 format). `docs/3-code-review/` and
  per-release changelog files stay put, frozen.
- References to old names in living docs, CLAUDE.md, and README updated
  (dated records exempt).

# skills/lib

Shared script layer used by multiple ADDW skills. Not a skill — there is no
`SKILL.md` here, so skill discovery ignores it — but it must ride along in the
wholesale copy of `skills/` into a project's `.claude/skills/`, which is why it
lives inside `skills/` rather than at the repo root.

- `tracker/` — the tracker layer. `parse.sh` holds the pure text-in/conclusion-out
  parsers for the issue-body section encoding (`## Parent` / `## Blocked by`)
  and close-reason classification. Every tracker operation in ADDW scripts
  routes through this layer; nothing outside it calls `gh` for tracker
  operations. This is the documented seam for any future tracker adapter.

Tested from the repo root via `tests/run.sh` against fixture bodies in
`tests/fixtures/tracker/`.

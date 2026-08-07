# skills/lib

Shared script layer used by multiple ADDW skills. Not a skill — there is no
`SKILL.md` here, so skill discovery ignores it — but it must ride along in the
wholesale copy of `skills/` into a project's `.claude/skills/`, which is why it
lives inside `skills/` rather than at the repo root.

- `tracker/` — the tracker layer, the single seam through which every ADDW
  tracker operation goes; nothing outside it invokes `gh` for tracker work
  (enforced by `tests/tracker-seam.test.sh`), and it is the documented seam
  for any future tracker adapter. Three files, layered by purity:
  - `parse.sh` — pure text-in/conclusion-out parsers for the issue-body
    section encoding (`## Parent` / `## Blocked by`) and close-reason
    classification.
  - `resolve.sh` — pure frontier and spec-completion resolution over an issue
    snapshot (the `gh --json` shape), building on `parse.sh`. Needs `jq` and
    bash ≥ 4 (associative arrays; guarded at startup). No network: fed a
    checked-in fixture in tests, a live snapshot in use.
  - `tracker.sh` — the thin `gh`-calling wrappers (issue reads, body edits,
    labels, comments, close-with-reason, self-assign) plus the live
    `frontier` and `spec-complete` queries, which fetch a snapshot and
    delegate all reasoning to `resolve.sh`. Dogfood-verified, not unit-tested.

Tested from the repo root via `tests/run.sh` against fixtures in
`tests/fixtures/tracker/`.

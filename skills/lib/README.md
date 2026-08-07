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

- `gate/gate.sh` — the deterministic testing gate. Sources the project config
  (default `docs/addw.env`) and runs the recipe ladder in fixed order — lint
  (`ADDW_RECIPE_LINT`), typecheck (`ADDW_RECIPE_TYPECHECK`), tests
  (`ADDW_RECIPE_TESTS_AFFECTED`) — emitting exactly one summary line on
  stdout, the line PR bodies carry verbatim; recipe output goes to stderr.
  Every rung runs even after an earlier one fails; a missing or empty key
  reports `skipped (no recipe)`, never silence. The tests recipe is a command
  template: every `{paths}` occurrence is replaced by the shell-quoted test
  paths passed on the gate's command line (selection stays agent judgment;
  execution and reporting are mechanical), and a recipe without the
  placeholder runs as-is.

Tested from the repo root via `tests/run.sh` against fixtures in
`tests/fixtures/`.

# skills/lib

Shared script layer used by multiple ADDW skills. Not a skill — there is no
`SKILL.md` here, so skill discovery ignores it — but it must ride along in the
wholesale copy of `skills/` into a project's `.claude/skills/`, which is why it
lives inside `skills/` rather than at the repo root.

- `tracker/` — the tracker layer, the single seam through which every ADDW
  tracker operation goes; nothing outside it invokes `gh` for tracker work —
  scripts, prompts, and the SKILL.md instructions agents follow alike
  (enforced by `tests/tracker-seam.test.sh`) — and it is the documented seam
  for any future tracker adapter. Three files, layered by purity:
  - `parse.sh` — pure text-in/conclusion-out parsers for the issue-body
    section encoding (`## Parent` / `## Blocked by`) and close-reason
    classification.
  - `resolve.sh` — pure frontier and spec-completion resolution over an issue
    snapshot (the `gh --json` shape), building on `parse.sh`. Needs `jq` and
    bash ≥ 4 (associative arrays; guarded at startup). No network: fed a
    checked-in fixture in tests, a live snapshot in use.
  - `tracker.sh` — the thin `gh`-calling wrappers (issue reads, body edits,
    labels, comments, close-with-reason, self-assign) plus the live `frontier`
    and `spec-complete` queries, which fetch a snapshot and delegate all
    reasoning to `resolve.sh`. Four wrappers exist for install verification
    rather than for issue work — `auth`, `issues-enabled`, `labels`, and
    `create-label` — because "is the tracker usable, and do the labels the
    frontier keys on exist" is a tracker question, and answering it outside
    the layer would put the one thing a future adapter must reimplement in two
    places. `addw-init` creates the `spec` and `backlog` labels through the
    last of them; doctor re-checks all of it with the first three.
    Dogfood-verified, not unit-tested.
    The branch half of the frontier's in-progress annotation comes from
    `git ls-remote --heads origin` — remote branches, never local ones — so a
    ticket reads as in progress exactly while its branch is visible to
    everybody, and deleting the branch on merge is what retires the
    annotation.

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

- `release/derive.sh` — the mechanical release derivations, run from a
  project's repo root. One commit-collection pass — every commit since the
  last tag reachable from HEAD (whole history when no tag exists) whose
  subject parses as a conventional commit, release commits (`release:` /
  `chore(release):`) excluded, unclassifiable subjects warned and listed on
  stderr — feeds two subcommands, so the changelog and the version can never
  disagree about which commits count. `version` prints the proposed bump
  (`!` → major, else `feat` → minor, else patch) and the next version
  (applied to the last tag, prefix preserved; base v0.0.0 when untagged);
  `changelog` prints the Markdown entry — versioned, dated header, then
  Breaking / Features / Fixes / Other sections of verbatim subjects; `prepend`
  writes that same entry into `CHANGELOG.md` above the newest existing one
  (creating the file with a title when absent) and skips an entry already
  present. The write lives here rather than in skill prose because the
  changelog is write-only for the workflow and an agent's edit tool must read
  a file before modifying it — an instruction not to look is not a mechanism.
  A range with no qualifying commit exits 1: stop and ask the human, never
  release silently.

- `release/tail.sh` — the re-runnable post-merge tail: lay the version tag on
  HEAD, push it, publish the GitHub Release, and for a spec release close the
  spec issue as completed — through `tracker/tracker.sh`, never the tracker
  CLI directly, since closing an issue is a tracker operation while creating a
  GitHub Release is not.
  Each step skips what is already done and prints one `done:`/`skip:` line, so
  running the tail twice is harmless and an interrupted run completes on the
  next invocation — the property that makes a half-finished release
  recoverable by re-running rather than by hand. Everything is validated
  before anything is mutated, since a published tag is awkward to retract, and
  skipping tests for the step's *result*, not its name: a tag that exists but
  points away from the release commit — locally or on the remote — is refused,
  since skipping it would cement a tag laid from a stale checkout. `--commit`
  names the release PR's merge commit and callers should always pass it; HEAD
  is a default that goes wrong the moment another PR merges in between.
  The release notes are the changelog entry's body, read rather than
  re-derived — which is what keeps the published release and the committed
  changelog the same words — and read from the *target commit's* tree rather
  than the working tree, so a release can never be published against code that
  does not contain its own notes. That lookup is also what catches a version
  argument disagreeing with the one the release PR committed.

- `docs/` — living-document probes, shared because the release runs them as its
  backstop sweep and the maintenance audit runs them deliberately.
  - `check-doc-accretion.sh` — counts a document's version references against
    its copy at the previous tag. A count climbing release over release means
    the document is narrating its own history, the failure a size threshold
    cannot see. Advisory, never a gate.
  - `audit-nudge.sh` — counts release tags since the newest maintenance report
    against `ADDW_AUDIT_NUDGE_N` and prints `NUDGE` or `OK`.

Tested from the repo root via `tests/run.sh` against fixtures in
`tests/fixtures/`.

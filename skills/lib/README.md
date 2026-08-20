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
    `create` is the one exception to that last sentence, and the layer's only
    verb that brings a new issue into being. The happy path never reaches it —
    `to-spec` publishes the spec issue and `to-tickets` publishes the tickets,
    so the seam otherwise only reads, annotates, assigns, and closes what
    Matt's skills authored. It is here for the two paths that do originate an
    issue: `addw-maintain` routing a substantive audit finding to a `backlog`
    issue, and the schema-4 backlog migration. It is unit-tested
    (`tests/tracker-create.test.sh`) because it shapes an outbound write from
    variadic arguments rather than passing one through — each label gets its
    own `--label`, since a comma-joined string is read as one label name
    containing commas, and the body file is checked before the call because a
    body-file failure mid-create leaves a titled, bodyless issue that cannot
    be un-created.
    `body-hash` and `approval-drift` are the approval-integrity reads
    (ADR 0009): the first prints the truncated sha256 of an issue's live body —
    the value an approval records — and the second compares that against the
    last `Approved-body:` marker in the issue's comments, exiting 1 on drift.
    The hash computation and the marker scan live in `parse.sh` (`body-hash`,
    `approval-hash`) because both are text-in/conclusion-out; `tracker.sh` only
    wires them to the live body and the comment stream. The comments read pages
    through the whole thread because the scan is last-marker-wins — a
    re-approval records a new marker that must shadow the old one, so a
    truncated read could resurrect a stale approval. An absent marker reports
    itself and exits 0, because approvals predating the mechanism must read as
    unrecorded rather than as drift. Unit-tested (`tests/tracker-drift.test.sh`,
    the parsers in `tests/tracker-parse.test.sh`) because normalization and the
    three-way verdict are logic rather than passthrough.
    The branch half of the frontier's in-progress annotation comes from
    `git ls-remote --heads origin` — remote branches, never local ones — so a
    ticket reads as in progress exactly while its branch is visible to
    everybody, and deleting the branch on merge is what retires the
    annotation.
    `snapshot` is unit-tested (`tests/tracker-snapshot.test.sh`) for the same
    reason `create` is. It drops `archived` issues, which is logic rather than
    a passthrough, and it is the *only* enforcement of the write-only archive:
    dropping them here means no consumer **can** read a retired document back,
    rather than every consumer promising not to. Client-side deliberately —
    the tracker CLI offers no exclude-label flag on a listing, so excluding
    server-side means its search mode, whose hard 1,000-result cap would stop
    the limit below from being a remedy exactly when it is needed.
    That ordering is why reaching `ADDW_TRACKER_FETCH_LIMIT` (default 1000)
    refuses rather than truncating: archives occupy fetch slots and can
    displace live issues *before* anything drops them, so a shortened frontier
    would be a wrong answer rather than a slow one. `frontier` and
    `spec-complete` inherit the refusal as a non-zero exit. The bound is
    configuration because the remedy would otherwise mean editing a skill,
    which must stay byte-identical across installs.

- `config/config.sh` — the shared reader for `docs/addw.env`, and the only
  code that opens it: every consumer — scripts and SKILL.md snippets alike —
  goes through `config_get` (line-per-key stdout) or `config_source`
  (set-in-the-caller, unset-first). The config is **data** in a restricted
  `KEY=value` grammar, never sourced; the grammar itself lives in the
  script's header, and this section owns the why.
  Parse-don't-execute is the design. A config that nothing executes has no
  exit status, no stdout, no way to `exit` the tool, no partial application
  on a mid-file error — and unset-first means an exported environment value
  can never stand in for a key the file does not set. That deletes five
  defect classes at once instead of defending against them at every site.
  The defect history is why the seam exists: #46 and #56 fixed the same
  exit-status conflation twice (`.` returns the status of the config's *last
  command*, which under `set -e` reads a shell-clean config ending on a
  false conditional as a failure), and the per-site defensive idiom —
  `bash -n`, subshell isolation, stdout discard, unset-first, `|| true` —
  kept growing new copies as read sites multiplied, with per-key
  absent-value policies diverging between them (#57, absorbed into #58).
  Centralizing those defenses instead would have treated the symptom: the
  execution threat model survives, one layer deeper. Removing execution
  removes it.
  The strictness rule: anything whose shell reading and parsed reading could
  diverge is rejected with its line number, so every *accepted* file is a
  strict subset of shell with identical semantics — which is what made the
  schema-7 migration a no-op for conforming configs, guarantees single-line
  values (the soundness of the line-per-key protocol), and keeps `KEY=`
  distinguishable from an absent key, the distinction doctor's
  deliberate-skip checks stand on.
  The error contract: 66 (EX_NOINPUT) missing, 77 (EX_NOPERM) unreadable,
  78 (EX_CONFIG) grammar violation. Whether a *missing* config is fatal
  stays per-caller — runtime scripts fall back to their defaults, gate and
  next-adr refuse, doctor FAILs — while a present-but-invalid config is
  fatal in every caller at 78, except doctor, which keeps its
  report-don't-abort style: one FAIL line per violation, then stop before
  the checks that depend on the config. Rejected alternatives: dotenv-style
  loose quoting, which accepts files whose shell and parsed readings
  silently diverge, and a Python reader, a new runtime dependency for a job
  this small.

- `templates/` — shipped, project-agnostic templates that ride along with the
  wholesale skills copy. `adr.md` holds the ADR format and its authoring rules;
  it belongs with the skills because the format is not project state and a
  template change should arrive with the next skills install, rather than
  requiring every project to migrate a generated copy by hand.

- `gate/gate.sh` — the deterministic testing gate, and the reason a PR body's
  verification evidence is a line nobody had to compose: the gate runs the
  project's own lint, typecheck, and test recipes from the config and emits
  that line itself. Every rung runs even after an earlier one fails, because
  what a reviewer needs is the whole picture of what is broken rather than the
  first thing that broke, and an absent recipe reports a visible skip rather
  than silence. Affected-test selection stays agent judgment while execution
  and reporting are mechanical, which is why the tests recipe is a template
  the gate fills in rather than a fixed command.

- `release/derive.sh` — the mechanical release derivations, run from a
  project's repo root. One commit-collection pass feeds every subcommand, so
  the changelog and the version can never disagree about which commits count,
  and both stay projections of history rather than prose an agent composed.
  Release commits are excluded, and a subject the derivation cannot classify is
  warned and listed rather than dropped, because an unreadable subject is a
  defect at the commit and not something for the changelog to swallow. The
  changelog *write* lives here rather than in skill prose because the changelog
  is write-only for the workflow and an agent's edit tool must read a file
  before modifying it — an instruction not to look is not a mechanism. A range
  with no qualifying commit stops and asks the human, never releasing silently.

- `release/tail.sh` — the re-runnable post-merge tail: the version tag, its
  push, the GitHub Release, and for a spec release the spec issue's closure —
  the last of those through `tracker/tracker.sh`, never the tracker CLI
  directly, since closing an issue is a tracker operation while creating a
  GitHub Release is not.
  Each step skips what is already done, so running the tail twice is harmless
  and an interrupted run completes on the next invocation — the property that
  makes a half-finished release recoverable by re-running rather than by hand.
  Everything is validated before anything is mutated, since a published tag is
  awkward to retract, and a skip therefore tests for the step's *result* rather
  than its name: a tag pointing away from the release commit would otherwise
  cement one laid from a stale checkout.
  The release notes are the changelog entry's body, read rather than
  re-derived — which is what keeps the published release and the committed
  changelog the same words — and read from the *target commit's* tree rather
  than the working tree, so a release can never be published against code that
  does not contain its own notes. That lookup is also what catches a version
  argument disagreeing with the one the release PR committed.

- `docs/` — living-document probes and the one operation performed on a living
  document, shared because the release runs the probes as its backstop sweep
  and the maintenance audit runs them deliberately.
  - `check-doc-accretion.sh` — version density is the signal a living design
    document is narrating its own history: it describes the system as it is, so
    a release rewrites the passages it affects rather than appending to them,
    and appending is invisible to a size threshold — a document stays well
    under budget while its overview turns into a changelog — which is why the
    comparison is against the previous release rather than against a limit. A
    handful of references are legitimate (the as-built statement, a dependency
    pin, a hazard predating its fix), so the probe names what it counted and is
    advisory, never a gate.
  - `audit-nudge.sh` — the maintenance-audit cadence check, so that a stack of
    releases with no audit behind it is something the flow says out loud rather
    than something the human has to remember.
  - `next-adr-number.sh` — the next ADR number: max plus one, never the first
    gap.
    Archival is what makes those two diverge, so the intuitive answer — the
    first unused number in the listing — is one already spent, which is why
    the rule is a script rather than prose the Doc Impact step points at. A
    superseding ADR is always numbered above the document it retires, so every
    departed number sits below a present one and the directory alone is
    authoritative — no tracker call is needed. It does not solve concurrent authorship: two branches each computing
    max plus one land on the same number, which only merge order or a reviewer
    catches.
  - `archive-doc.sh` — retires a document to a closed, labeled issue and stages
    the deletion. A script rather than an agent step because the harness
    forbids writing a file's contents anywhere without reading them first, so
    an agent performing the archival guarantees exactly the context
    contamination the rule exists to prevent — the same reasoning that made the
    changelog prepender a script. The reference check spans two surfaces with
    two verdicts: a live pointer in the tree or in an open issue refuses, since
    a deletion that strands one has moved the defect rather than fixed it,
    while a closed issue's mention is reported and does not block, since
    history must not deadlock the tool permanently. ADR `Origin:` lines are
    exempt on both. One PR is a review unit rather than a transaction, so what
    the ordering guarantees is that the irreversible step comes last: every
    failure before the issue exists leaves the tree untouched, and after that
    point the residue is made loud — the number is printed the moment it
    exists — rather than resumable, since recognising an existing archive for a
    path would mean reading archives back.

- `codex/` — the shared Codex runner every `codex-*` adapter sits on. It owns
  the mechanics of a resumable non-interactive Codex session — invoking
  `codex exec`, capturing the `thread.started` id, writing the thread, review,
  and event files under a per-target key — and, with one exception below,
  nothing about *what* is being reviewed or implemented. `start.sh` opens a
  thread (refusing one that already
  exists, exit 2), `resume.sh` continues it, `reset.sh` drops its state, and
  `show.sh` replays the last output without spending a call; `_common.sh` holds
  the key derivation, the prompt-template substitution, and the model/effort
  resolution (`ADDW_CODEX_MODEL_IMPL` / `ADDW_CODEX_MODEL_REVIEW` /
  `ADDW_CODEX_EFFORT` from the project config, `CODEX_MODEL` / `CODEX_EFFORT`
  as per-run overrides). Those three come through `config/config.sh` like
  every other config read: a missing config just means the defaults, and a
  config that fails to parse exits 78 with the reader's line-numbered
  diagnostic.
  The exception: model *class* is chosen by matching the caller's `STATE_DIR`
  against `*codex-implement*`, so implementation gets the implementation-class
  model and everything else the review-class one. That is the layer knowing one
  thing about its callers, and it is a wart — the honest shape is a variable the
  adapter sets.
  Two inputs are **required**, not defaulted: the caller pins `STATE_DIR` to
  its own skill's `state/`, and passes `--prompt-file`. A shared layer must
  default neither, because a default here would merge every adapter's threads
  into one namespace under `skills/lib/`. Absent either, the runner exits 64
  rather than guessing. The adapters are the thin half: pin state, pin prompt,
  hand off.

Tested from the repo root via `tests/run.sh` against fixtures in
`tests/fixtures/`.

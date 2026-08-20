---
name: addw-init
description: Initialize the ADDW overlay in a project after Matt Pocock's setup has run
disable-model-invocation: true
argument-hint: "name of the project to initialize"
---

# Initialization Mode

You are setting up the **ADDW half** of a project's configuration. The other
half is not yours: Matt Pocock's `setup-matt-pocock-skills` skill owns the
tracker choice, the triage labels, and the domain-document layout. It is
user-invoked, and this skill **never invokes it** — init probes for the
artifacts it leaves behind, and stops with instructions when they are absent.

Work from the repository root. If no project name was supplied, ask for one.

**No skill file is ever edited.** Everything project-specific lands in
`docs/addw.env` or in the living docs the skills point at.

---

## Step 1: Verify — read-only

Nothing is written until the ground is confirmed. Every check here has a
failure mode that is silent later, which is why it is a check and not an
assumption.

1. **Matt's setup ran.** `docs/agents/issue-tracker.md` and
   `docs/agents/domain.md` must both exist. If either is missing, stop and
   tell the human to run `setup-matt-pocock-skills` first — do not invoke it
   yourself, and do not write the files on its behalf.

2. **The tracker is GitHub.** Read the `# Issue tracker: <name>` heading in
   `docs/agents/issue-tracker.md`. ADDW's overlay is GitHub-only, so anything
   else means stopping and saying so: the human either switches the repo's
   tracker or does not use ADDW here.

3. **The tracker is reachable.** Through the tracker layer at
   `.claude/skills/lib/tracker/tracker.sh` — never the tracker CLI directly:

   ```bash
   bash .claude/skills/lib/tracker/tracker.sh auth            # authenticated?
   bash .claude/skills/lib/tracker/tracker.sh issues-enabled  # issues on?
   bash .claude/skills/lib/tracker/tracker.sh labels          # label inventory
   ```

   Stop if authentication fails or issues are disabled. In the label list,
   `ready-for-agent` must already be there — it is Matt's, and the frontier
   query keys on it, so a missing one fails silently as a forever-empty
   frontier rather than as an error. `spec` and `backlog` are ADDW's own and
   are created in Step 2.

4. **Take stock of the skills the flow uses.** Read your own skill roster and
   note which of Matt's are there: `code-review` and `tdd`, which ADDW's own
   steps reach for, and `setup-matt-pocock-skills`, `grill-with-docs`,
   `grilling`, `domain-modeling`, `to-spec`, and `to-tickets`, which the human
   invokes around them.

   **This is an inventory, not a gate.** Nothing here stops init, because
   nothing here is load-bearing. The review ADDW cannot do without is its own
   cross-model loop, named by `ADDW_CODE_REVIEW_SKILL` and checked by doctor;
   Matt's `code-review` is the cold *pre-filter* in front of it, which
   `addw-implement` already permits skipping by judgment — a step the flow may
   skip is not a dependency that can block an install. `tdd` encodes a
   discipline, and the discipline survives the skill's absence. There is no
   evidence that any of these outperforms another cold-review skill, or a
   plain instruction to review the diff; what matters is that a review step
   happens, not whose prompt runs it.

   So report rather than refuse: say which are present, which are missing, and
   what the human loses in each case. Where a name is ambiguous — other
   plugins publish a `code-review` too — say which entry you would actually
   invoke, so that the PR disclosure can name what ran rather than implying
   Matt's did.

5. **Resolve the ADR location.** `docs/agents/domain.md` is a prose contract;
   read it and resolve the directory it declares for ADRs. Do not hardcode a
   path and do not infer one from the layout Matt's seed template happens to
   ship — a project may have declared otherwise, and this indirection is the
   reason ADDW skills carry no glossary or ADR paths of their own. The
   resolved path is recorded as `ADDW_ADR_DIR` in Step 2, which is what lets
   doctor re-check the same decision mechanically. If the contract is
   genuinely ambiguous, ask the human to settle it before writing anything.

---

## Step 2: Generate — ADDW's artifacts only

Anything Matt's setup already produced is left alone. Init creates the two
ADDW labels, the living docs, the project config, and the ADR contract, and
nothing else — no plans directory, no tutorial machinery.

### 2.1 The docs contract

Create the directories the skills expect to find, so the contract holds
before anything writes into it:

```
docs/4-unit-tests/     # the testing guide and the coverage-debt ledger
<ADDW_ADR_DIR>/        # the ADR directory resolved in Step 1.5
```

There is no plans directory and no tutorial directory: work items live on the
tracker, and tutorials have no consumer in the skill set. Directories this
contract no longer names may survive in historical installs. Leave them alone
and leave the numbering gaps; never recreate one, and treat a surviving one as
frozen history, never as a live input. Deleting them is the human's call, and
`UPGRADING.md` owns their disposition.

### 2.2 The ADDW labels

For each of `spec` and `backlog` that Step 1's label listing did not show:

```bash
bash .claude/skills/lib/tracker/tracker.sh create-label <label>
```

`ready-for-agent` is Matt's and is never recreated or modified.

### 2.3 Explore and classify the codebase

The living docs are written from evidence, not from the project's name. Read
the root and the source tree: the build/package manifest identifies language
and toolchain, framework config files (`next.config.*`, `tauri.conf.*`,
`platformio.ini`, `serverless.yml`, a linker script) identify the runtime
shape, and the source layout identifies the architecture — `src/components/`,
`src/hal/`, and `cmd/` are three different kinds of project. Also gather
dependencies and their purposes, entry points, the configuration approach,
and the test framework and conventions.

Record the current version and its format (SemVer, CalVer, custom) from
`package.json`, `Cargo.toml`, `pyproject.toml`, `version.h`, `__version__`,
or git tags. Languages with no native version manifest — Go, C, plain shell —
often have no such file, and inventing one solely to name it here is not the
goal: `ADDW_VERSION_FILE` may be left empty, and releases then carry the
version in the tag and the changelog alone.

Then classify:

| Type | Typical signals | Concerns to capture |
| --- | --- | --- |
| Web frontend | React, Vue, Angular, Svelte, components, routing | components, state, styling, routing, API calls |
| Web backend | Express, FastAPI, Gin, Spring, routes, middleware | endpoints, database, auth, middleware, errors |
| Full-stack web | frontend and backend in one tree | both sides, plus the API contracts between them |
| Desktop app | Electron, Tauri, Qt, GTK, WinForms | windows, native APIs, IPC, cross-platform behavior |
| Mobile app | React Native, Flutter, Swift, Kotlin | screens, navigation, platform APIs, offline behavior |
| CLI tool | entry point and argument parsing, no GUI | commands, configuration, I/O, exit codes |
| Library/SDK | public exports, no application entry point | API surface, compatibility, versioning |
| Embedded/firmware | HAL, interrupts, memory-mapped I/O | hardware, memory, real-time behavior, boot, peripherals |
| Game | game loop, rendering, entities | loop, rendering, physics, input, assets |
| Data/ML pipeline | notebooks, processing, models | data flow, training, inference, pipelines |

Note the primary type, any secondary aspects (a CLI that is also a library),
and domain-specific concerns such as real-time or compliance constraints.
These decide which architecture sections earn a place.

### 2.4 `docs/ARCHITECTURE.md`

Write it as an **as-built** description of the system as it currently is.
Every project gets the universal sections: how to read the document,
overview, technology stack, project structure, core architecture principles,
build system and toolchain, and configuration. It closes with the applicable
ones: data-flow diagrams, error-handling strategy, testing strategy,
performance, security, deployment, and a short conclusion.

Between them go the sections **this** project needs, from the classification
and from what exploration actually found. A frontend earns component
organization, state, routing, and API integration; a backend earns API
design, request lifecycle, database layer, and auth; firmware earns the HAL,
memory map, interrupts, and boot sequence. Add a section whenever the
codebase holds an aspect a newcomer would otherwise reverse-engineer — a
caching strategy, a plugin system, multi-tenancy, offline sync, migrations,
feature flags. Omit any section the project has no real answer for: an empty
heading is worse than no heading.

Use the domain's own vocabulary — firmware has *peripherals*, a CLI has
*commands*, neither has "components". Document **per-layer conventions**:
patterns, quality expectations, and common pitfalls per component type. These
are what implementation and review derive from later, so a layer with no
written conventions is a gap, not a blank.

Then **present it and ask the user to approve it** with `AskUserQuestion` —
approve, request changes, or add sections. Revise and re-present until they
approve explicitly; nothing further is written before that.

### 2.5 `docs/charter.md`

The charter holds intent that outlasts any single feature. Interview the user
with `AskUserQuestion`, **one topic at a time** — purpose, product
principles, scope, non-goals, success criteria — offering options drawn from
the exploration. Draft from their answers:

```markdown
# <Project Name> Charter

Stable intent only — this document changes rarely, via dedicated design
commits. If a release appears to invalidate it, addw-release flags it; the
charter is never silently edited.

## Purpose

<Why this project exists — one paragraph.>

## Product Principles

<Three to six principles that outlast any single feature.>

## Scope

<What this project does.>

## Non-Goals

<What it deliberately does not do — pair lasting ones with guardrail ADRs.>

## Success Criteria

<How we know it is working.>
```

**Get explicit approval before writing the file.**

### 2.6 `docs/4-unit-tests/TESTING.md`

Adapted from what exploration found, never generic: the real framework and
version, how tests are run and organized, the project's own writing
conventions, coverage expectations, and **Integration / E2E Impact Rules**
(when the heavier suite must run — a changed selector, a changed API
contract; docs-only changes skip it).

Its **Verification Recipes** section is the single source of truth for
verification commands — the skills point here and carry none themselves:
lint, type-check/build, all tests, affected tests, single test, coverage.
Prefer task-runner targets (`make lint`, `npm run lint`) over raw commands,
so there is one place to change them.

### 2.7 `docs/addw.env`

The project config, and the reason skills stay byte-identical across
installs. It is **data, not shell**: a restricted `KEY=value` grammar parsed
by the shared reader in `.claude/skills/lib/config/`, never sourced. Write
the file with the header below verbatim — it teaches the grammar to whoever
edits the file next, and the parser rejects a violating line by number.

```bash
# docs/addw.env — ADDW project configuration. Created by addw-init.
# Skills read this at runtime; never edit a skill to change these values.
#
# This file is DATA, not shell: one KEY=value per line, parsed by the shared
# reader in .claude/skills/lib/config/ — never sourced. Blank lines and
# full-line # comments are fine; trailing comments, `export`, and line
# continuations are not. Values are bare (letters, digits, . _ - / only),
# 'single-quoted' (fully literal, no embedded single quote), or
# "double-quoted" (literal; embedded single quotes fine; $, backtick, and
# backslash are rejected — single-quote those instead). KEY= means
# deliberately empty, which is distinct from deleting the key.
#
# Install generation — bumped only by structural upgrades (see UPGRADING.md):
ADDW_SCHEMA=7
ADDW_PROJECT_NAME="<project name>"
# The file a release writes the version into. Empty is valid and means the
# project has no version manifest to write — the release then carries the
# version in its tag and CHANGELOG.md alone. The key itself must be present
# either way, so a considered skip cannot be mistaken for an omission.
ADDW_VERSION_FILE="<package.json, Cargo.toml, pyproject.toml, version.h, or empty>"
# A bare branch name — never remote-qualified: a consumer derives
# `origin/$ADDW_MAIN_BRANCH` from it, so an "origin/main" here becomes
# "origin/origin/main" there. Resolve it with:
#   git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||'
# falling back to `git branch --show-current` in a repo with no remote.
ADDW_MAIN_BRANCH="<bare branch name>"
ADDW_AUDIT_NUDGE_N=5
# The ADR directory the domain-layout contract declares (Step 1.5):
ADDW_ADR_DIR="<resolved ADR directory>"
# The shipped ADR template, or a project-owned replacement:
ADDW_ADR_TEMPLATE=".claude/skills/lib/templates/adr.md"
# Testing-gate recipes, from TESTING.md's Verification Recipes. All three keys
# are always present: an empty value is a step this project does not have, and
# the gate reports it as a visible skip.
ADDW_RECIPE_LINT="<command or empty>"
ADDW_RECIPE_TYPECHECK="<command or empty>"
# {paths} is replaced by the affected test paths; a recipe without it runs as-is:
ADDW_RECIPE_TESTS_AFFECTED="<command template or empty>"
# Optional lockfile sync, for ecosystems whose lockfile embeds the project's
# own version (uv, Cargo, npm): addw-release Step 3 runs the recipe right
# after the version write and stages the named file in the release commit.
# Set both keys or neither, and only beside a non-empty ADDW_VERSION_FILE —
# doctor checks the pair exactly when it is set:
# ADDW_RECIPE_LOCKFILE_SYNC="uv lock"
# ADDW_LOCKFILE="uv.lock"
# Optional codex model/effort overrides — unset, the shared codex runner's own
# defaults apply:
# ADDW_CODEX_MODEL_IMPL="..."
# ADDW_CODEX_MODEL_REVIEW="..."
# ADDW_CODEX_EFFORT="..."
# Optional agent role adapters — each names a skill folder under
# .claude/skills/ providing scripts/start.sh and scripts/resume.sh. The
# reserved value `inline` on the implement key means no adapter: the main
# agent drives `tdd` itself.
# ADDW_IMPLEMENT_SKILL=codex-implement
# ADDW_CODE_REVIEW_SKILL=codex-code-review
# Optional addw-compact token budgets — unset, the defaults below apply. The
# threshold triggers compaction (addw-maintain's size check watches it too);
# the target range is where a compaction aims, and its upper bound doubles as
# the split trigger. Rule of thumb for choosing a threshold: ARCHITECTURE.md
# should stay around ~10% of the context window.
# ADDW_COMPACT_THRESHOLD=20000
# ADDW_COMPACT_TARGET_MIN=10000
# ADDW_COMPACT_TARGET_MAX=15000
```

Fill every value (audit nudge 5 unless the user chooses otherwise). Do not
invent a tutorial flag, and do not change `ADDW_SCHEMA` — the generation
marker moves only at a structural boundary, which `UPGRADING.md` documents.

### 2.8 The ADR contract

The ADR format is shipped at `.claude/skills/lib/templates/adr.md` with the
wholesale skills copy. Init does not write a template file. It writes only one
line to the `CLAUDE.md` or `AGENTS.md` that Matt's setup already edited,
**never the other one**, declaring `<ADDW_ADR_TEMPLATE>` authoritative over any
ADR format bundled with a skill, including `domain-modeling`'s. A project that
keeps its own ADR format points `ADDW_ADR_TEMPLATE` at its own file rather than
overwriting a generated one. That declaration is the documented customization
seam and the path is the same one doctor checks.

Put the resolved value of `ADDW_ADR_TEMPLATE` **in backticks** and the word
**authoritative** on the same line:

```markdown
`<ADDW_ADR_TEMPLATE>` is the authoritative ADR format for this project.
```

Doctor looks for both together, so that a passing mention of the template
somewhere else in the file cannot be mistaken for the declaration. The
backticks are what make that check exact rather than approximate: a bare path
in prose cannot be told apart from a longer path containing it — an install
naming `.claude/skills/lib/templates/adr.md` has not declared
`skills/lib/templates/adr.md`, and it is the near-miss, not the obvious
mismatch, that this check exists to catch.

### 2.9 `docs/ARCHITECTURE-rules.md` and `CHANGELOG.md`

`docs/ARCHITECTURE-rules.md` records how ARCHITECTURE.md is maintained,
naming that document's actual sections: update after any change to project
structure, technology stack, data flow, component interactions, or build and
deployment; **rewrite, never append** — restate the affected passage as the
system now stands and delete descriptions of machinery that no longer
exists; be factual and concise; update diagrams when data flow changes;
reference real paths. Version history belongs in `CHANGELOG.md`, not here — a
version number earns a place only when it is a live fact a reader must act
on, such as a dependency pin.

The root `CHANGELOG.md` is write-only for the workflow: the release skills
prepend entries and no skill reads it as context. Create it with the header
and the initialization entry, patch-incrementing the version exploration
found (`1.2.3` → `1.2.4`; `0.1.0` when there is none):

```markdown
# Changelog

Release history, newest first. Maintained by the ADDW release skills; humans
read it, agents don't.

## v<next version> — <DD-MM-YYYY>

chore: initialize the ADDW workflow

- Initialized ADDW — architecture, charter, testing guide, ADR declaration, and
  project config.
```

Author no release history beyond that entry.

---

## Step 3: The Final Gate

Doctor is the deterministic re-verification of everything above, and it is
what init is judged by:

```bash
bash .claude/skills/addw-init/scripts/doctor.sh
```

It must report **HEALTHY**. A `FAIL` line is fixed in the artifact or config
init owns, never by editing a skill or lowering a check, and doctor is re-run.
Doctor does not check skill availability — that was Step 1.4, and the roster
is the only place it can be answered.

Then offer — do not perform unasked — the initial commit and tag, at the
version the `CHANGELOG.md` entry carries. Stage by **explicit paths**, and
stage the paths this run actually wrote and no others: the
project-instructions file is whichever of `CLAUDE.md` or `AGENTS.md` Matt's
setup chose, and the ADR directory now holds nothing init produced — the
template ships with the skills. Naming a path this run did not write aborts
the whole `git add` on a pathspec error, taking the commit with it.

```bash
git commit -m "chore: initialize the ADDW workflow"
git tag vX.Y.Z
```

If the user declines the tag, tell them the first `addw-release` will assume
a tag baseline exists.

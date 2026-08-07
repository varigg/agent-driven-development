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

4. **The skills ADDW depends on are installed.** Read your own skill roster —
   it is the authority here, and no filesystem check is a substitute for it,
   since only the roster carries the plugin qualifier that tells two skills of
   the same name apart.

   The question is never "does a skill by this name exist" but "**is Matt's
   here**". Name collision is not hypothetical — other plugins publish a
   `code-review` — and a lone namesake is the more dangerous case than a
   duplicated one, because nothing prompts you to look twice. So identify each
   dependency as **his** every time, by its plugin qualifier when his skills
   are installed as a plugin, otherwise by what the entry actually is. A
   same-named skill from any other source does not satisfy the dependency. If
   you cannot tell whose an entry is, stop and ask rather than assume.

   `code-review` and `tdd` are the two ADDW **invokes programmatically**. If
   either is absent — or present only as somebody else's — stop: the flow
   breaks at the point of use, and finding out then costs a ticket's work.
   Record the qualified names; that is what the flow must invoke.

   `setup-matt-pocock-skills`, `grill-with-docs`, `grilling`,
   `domain-modeling`, `to-spec`, and `to-tickets` are ones the **human**
   invokes. ADDW never calls them, so their absence is not a stop — but judge
   them the same way, and say which of *his* are missing rather than which
   names are unclaimed.

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
docs/6-memo/           # research memos
docs/7-maintenance/    # dated maintenance reports (addw-maintain)
<ADDW_ADR_DIR>/        # the ADR directory resolved in Step 1.5
```

There is no plans directory and no tutorial directory: work items live on the
tracker now, and tutorials have no consumer left in the skill set. Historical
installs may still carry `docs/1-plans/`, `docs/2-changelog/`,
`docs/3-code-review/`, or `docs/5-tuto/` — leave them alone, and leave the
numbering gaps; deleting them is the human's call, documented in
`UPGRADING.md`.

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
or git tags. A project with no version mechanism gets the smallest
appropriate one before `ADDW_VERSION_FILE` can name a file.

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
installs. It must be shell-sourceable — scripts `source` it directly, so a
syntax error here breaks skills far from the edit.

```bash
# docs/addw.env — ADDW project configuration. Created by addw-init.
# Skills read this at runtime; never edit a skill to change these values.
# Install generation — bumped only by structural upgrades (see UPGRADING.md):
ADDW_SCHEMA=3
ADDW_PROJECT_NAME="<project name>"
ADDW_VERSION_FILE="<package.json, Cargo.toml, pyproject.toml, version.h, ...>"
# A bare branch name — never remote-qualified. Consumers check it out and pass
# it to `gh pr create --base`, and one derives `origin/$ADDW_MAIN_BRANCH`, so
# an "origin/main" here becomes "origin/origin/main" there:
#   git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||'
# falling back to `git branch --show-current` in a repo with no remote.
ADDW_MAIN_BRANCH="<bare branch name>"
ADDW_AUDIT_NUDGE_N=5
# The ADR directory the domain-layout contract declares (Step 1.5):
ADDW_ADR_DIR="<resolved ADR directory>"
# Testing-gate recipes, from TESTING.md's Verification Recipes. All three keys
# are always present: an empty value is a step this project does not have, and
# the gate reports it as a visible skip.
ADDW_RECIPE_LINT="<command or empty>"
ADDW_RECIPE_TYPECHECK="<command or empty>"
# {paths} is replaced by the affected test paths; a recipe without it runs as-is:
ADDW_RECIPE_TESTS_AFFECTED="<command template or empty>"
# Optional codex model overrides (defaults live in the shared codex runner):
# ADDW_CODEX_MODEL_IMPL="..."
# ADDW_CODEX_MODEL_REVIEW="..."
# ADDW_CODEX_EFFORT="..."
# Optional agent role adapters — each names a skill folder under
# .claude/skills/ providing scripts/start.sh and scripts/resume.sh. The
# reserved value `inline` on the implement key means no adapter: the main
# agent drives `tdd` itself.
# ADDW_IMPLEMENT_SKILL=codex-implement
# ADDW_CODE_REVIEW_SKILL=codex-code-review
# ADDW_ASK_SKILL=codex-ask
```

Fill every value (audit nudge 5 unless the user chooses otherwise). Do not
invent a tutorial flag, and do not change `ADDW_SCHEMA` — the generation
marker moves only at a structural boundary, which `UPGRADING.md` documents.

### 2.8 The ADR contract

Write the template to `<ADDW_ADR_DIR>/template.md` — the directory resolved
in Step 1.5, never a literal path from this skill. It merges Matt's minimal
format with ADDW's decision-record rules:

```markdown
# ADR NNNN: <Title>

- **Status**: active | superseded by ADR-NNNN
- **Date**: <YYYY-MM-DD>
- **Origin**: <spec issue, ticket, PR, or "design session">

<One paragraph — one to three sentences carrying the context, the decision,
and why. That is the whole ADR by default; the value is in recording that a
decision was made and why, not in filling out sections.>

## Alternatives Considered (only when they earn their place)

<Discarded options and why. This is where discarded ideas live, never the
living docs.>

## Consequences (only when they earn their place)

<What becomes easier, harder, or forbidden.>

## Gate (required for a guardrail decision)

<What a future reviewer must check so later work does not violate this.>
```

Carry these rules into the template's own prose:

- ADRs are **write-once**, sequence-numbered, and self-contained — evidence
  restated in the ADR's own words, citing only living docs and other ADRs.
  The `Status` pointer is the only edit ever made to an existing ADR.
- The three bold fields are **mandatory and always present**. `Status` has
  exactly two states, `active` and `superseded by ADR-NNNN`.
- `Origin` is historical provenance: the **spec issue** for a decision made
  during alignment or specification, the **ticket or PR** when implementation
  forced it, or the literal `design session` when the decision predates any
  tracker artifact. Origins are never backfilled and are exempt from
  dead-link checking — they are expected to outlive what they cite.

Then add one line to the project instructions — the `CLAUDE.md` or
`AGENTS.md` that Matt's setup already edited, **never the other one** —
declaring that `<ADDW_ADR_DIR>/template.md` is authoritative over any
ADR format bundled with a skill, including `domain-modeling`'s. That
override is what makes the template the enforcing surface for every
authoring path. Put the resolved path and the word **authoritative** on the
same line: doctor looks for both together, so that a passing mention of the
template somewhere else in the file cannot be mistaken for the declaration.

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

- Initialized ADDW — architecture, charter, testing guide, ADR template, and
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
stage the paths this run actually wrote: the ADR directory may sit outside
`docs/`, and the project-instructions file is whichever of `CLAUDE.md` or
`AGENTS.md` Matt's setup chose — naming the other one aborts the whole `git
add` on a pathspec error.

```bash
git commit -m "chore: initialize the ADDW workflow"
git tag vX.Y.Z
```

If the user declines the tag, tell them the first `addw-release` will assume
a tag baseline exists.

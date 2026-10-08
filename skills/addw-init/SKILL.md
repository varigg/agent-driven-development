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
   reason ADDW skills carry no ADR path of their own. The resolved path is
   recorded as `ADDW_ADR_DIR` in Step 2, which is what lets doctor re-check
   the same decision mechanically. If the contract is genuinely ambiguous, ask
   the human to settle it before writing anything. The glossary carries no
   equivalent indirection: it is always `CONTEXT.md` at the repo root (or the
   per-context files a root `CONTEXT-MAP.md` points at), matching Matt's own
   setup and the mattpocock skills' hardcoded reads — never project-declared,
   so init resolves no path and records no key for it (ADR 0014).

---

## Step 2: Generate — ADDW's artifacts only

Anything Matt's setup already produced is left alone. Init creates the two
ADDW labels, the living docs, the project config, and the ADR contract, and
nothing else — no plans directory, no tutorial machinery.

### 2.1 The docs contract

Create the directories the skills expect to find, so the contract holds
before anything writes into it:

```
docs/testing/          # the coverage-debt ledger, written on its first entry
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

### 2.3 Explore the codebase

What init writes — the config, its recipes, and the candidate answers for the
conventions and charter steps — comes from evidence, not from the project's
name. Read the root and the source tree: the build/package manifest
identifies language and toolchain, framework config files (`next.config.*`,
`tauri.conf.*`, `platformio.ini`, `serverless.yml`, a linker script) identify
the runtime shape, and the source layout shows how the code divides —
`src/components/`, `src/hal/`, and `cmd/` are three different kinds of
project. Also gather entry points, the configuration approach, the test
framework and its conventions, and the commands that lint, type-check, and
run the tests — the recipes in 2.6 come from these directly. Prefer
task-runner targets (`make lint`, `npm run lint`) over raw commands, so there
is one place to change them.

Use the domain's own vocabulary — firmware has *peripherals*, a CLI has
*commands*, neither has "components". A **layer** is a component type, not a
directory: the names you find here are what the conventions interview in 2.4
asks about, should it run.

Record the current version and its format (SemVer, CalVer, custom) from
`package.json`, `Cargo.toml`, `pyproject.toml`, `version.h`, `__version__`,
or git tags. Languages with no native version manifest — Go, C, plain shell —
often have no such file, and inventing one solely to name it here is not the
goal: `ADDW_VERSION_FILE` may be left empty, and releases then carry the
version in the tag and the changelog alone.

Nothing here is written down as a description of the code. ADDW keeps none —
sessions explore for themselves (ADR 0016).

### 2.4 Rule-source discovery

Reviewers enforce the project's rules, and most projects already keep them
somewhere. Find those files rather than starting a second home for rules.
Probe:

- `CLAUDE.md` and `AGENTS.md`, nested copies included
- `CONTRIBUTING.md`
- `.github/copilot-instructions.md`
- `.cursor/rules/`
- `docs/*conventions*` and `docs/*style*`

and add anything else exploration turned up that plainly holds rules. Filter
every candidate through the **admission test**: could a reviewer cite a diff
as violating something it says? A file of build commands or orientation notes
fails; a file stating "domain code never reads the request" passes. A file
need not be *only* rules to qualify.

Present the survivors with `AskUserQuestion` as a **multi-select** and let
the human confirm the list. A confirmed directory expands to the files it
holds — `ADDW_CONVENTIONS` lists files only — and the expanded list is what
goes into the key (2.6), single-quoted and space-separated. A path containing
a space cannot be listed; say so if one is confirmed.

**When the confirmed list is empty**, offer to write `docs/CONVENTIONS.md`:

- **Accepted** — interview the human **per layer, one topic at a time**,
  starting from the shipped seed `.claude/skills/lib/templates/conventions.md`
  and pruning it rule by rule. Exploration supplies the layer names and may
  offer observed patterns as candidate answers, never as rules: a pattern the
  code happens to follow becomes a rule only when the human says so. The
  admission test governs every entry, seed rules included. The result is
  `ADDW_CONVENTIONS='docs/CONVENTIONS.md'`.
- **Declined** — write `ADDW_CONVENTIONS=`, the explicit no-rules value. The
  report says review runs without a conventions check.

Never list the seed template itself: it ships with the skills and changes
under the project on every upgrade. When the confirmed sources look thin for
what exploration found, note it in the report — do not interview a project
that already has rule files.

### 2.5 Charter-source discovery

The charter is the project's stable intent: purpose, principles, scope,
non-goals, success criteria. Spec review and release judge work against it.
Most projects already state it somewhere, so find those files rather than
writing a copy. Probe:

- `README.md`
- a PRD, `VISION.md`, or similar product documents
- anything else exploration turned up that plainly states intent

Filter every candidate through the **intent admission test**: could a spec or
a release be judged as contradicting something the file says? A file of setup
instructions fails; a README stating what the project deliberately does not
do passes. A file need not be *only* intent to qualify: readers read each
listed file whole, and the noise of a mixed file is accepted.

Present the survivors with `AskUserQuestion` as a **multi-select** and let the
human confirm the list. It goes into `ADDW_CHARTER` (2.6) with
`ADDW_CONVENTIONS`' form: files only, single-quoted, space-separated, and no
paths with spaces. When the confirmed sources look thin against the five
topics, note it in the report and do not interview.

**When the confirmed list is empty**, offer to write `docs/charter.md`:

- **Accepted** — interview the human with `AskUserQuestion`, **one topic at a
  time** — purpose, product principles, scope, non-goals, success criteria —
  offering options drawn from the exploration. Draft from their answers:

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

  **Get explicit approval before writing the file.** The result is
  `ADDW_CHARTER='docs/charter.md'`.
- **Declined** — write `ADDW_CHARTER=`, the explicit no-charter value. The
  report says intent checks run without a charter.

### 2.6 `docs/addw.env`

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
ADDW_SCHEMA=14
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
# The project's rule files (Step 2.4), read whole by implementation and review:
# single-quoted, space-separated, files only. Empty means the project declares
# no rules, and review says it ran without a conventions check:
ADDW_CONVENTIONS='<confirmed rule files, or empty>'
# The project's intent files (Step 2.5), read whole by every intent reader:
# same form. Empty means the project declares no charter, and the
# intent checks say they ran without one:
ADDW_CHARTER='<confirmed intent files, or empty>'
# Testing-gate recipes, from the commands exploration found. All three keys
# must be present: an empty value is a step this project does not have, and
# the gate reports it as a visible skip — deleting a key instead makes the
# gate refuse to run.
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
# .claude/skills/ providing scripts/start.sh and scripts/resume.sh. Unset or
# empty, the defaults below apply, and doctor checks whichever adapter is in
# effect — the default included — so an omitted key is never an unchecked
# one. The reserved value `inline` on the implement key means no adapter: the
# main agent drives `tdd` itself. It is not valid on the review key.
# ADDW_IMPLEMENT_SKILL=codex-implement
# ADDW_CODE_REVIEW_SKILL=codex-code-review
```

Fill every value (audit nudge 5 unless the user chooses otherwise). Do not
invent a tutorial flag, and do not change `ADDW_SCHEMA` — the generation
marker moves only at a structural boundary, which `UPGRADING.md` documents.

### 2.7 The ADR contract

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

### 2.8 `CHANGELOG.md`

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

- Initialized ADDW — conventions and charter sources, ADR declaration, and
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
template ships with the skills. `docs/CONVENTIONS.md` is staged only when the
2.4 interview wrote it, and `docs/charter.md` only when the 2.5 interview
did. Naming a path this run did not write aborts the whole `git add` on a
pathspec error, taking the commit with it.

```bash
git commit -m "chore: initialize the ADDW workflow"
git tag vX.Y.Z
```

If the user declines the tag, tell them the first `addw-release` will assume
a tag baseline exists.

Close with a report: the skill inventory from Step 1.4, the conventions
sources `ADDW_CONVENTIONS` now lists — or that review runs without a
conventions check, when the human declined — the charter sources
`ADDW_CHARTER` lists — or that intent checks run without a charter — and any
thin-coverage note from 2.4 or 2.5. When the project already had rule sources, name
`.claude/skills/lib/templates/conventions.md` as optional reading: a base set
of language-agnostic rules worth comparing against.

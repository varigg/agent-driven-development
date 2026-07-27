---
name: TRIP-init
description: Initialize TRIP workflow in a new project (creates docs structure and generates ARCHI.md)
disable-model-invocation: true
argument-hint: "name of the project to initialize"
---

# TRIP Initialization Mode

You are now in **initialization mode** for setting up the TRIP workflow — Plan → Implement → Release, with review and testing gates living inside Implement.

---

## Your Task

Initialize the TRIP workflow for the project: **$ARGUMENTS**

If no project name provided, ask the user for the project name before proceeding.

---

## Phase 1: Create Documentation Folder Structure

Create the following folder structure if it doesn't exist:

```
docs/
├── 1-plans/              # Feature planning documents
├── 2-changelog/          # changelog_table.md — the single release record
├── 4-unit-tests/         # Unit testing documentation
├── 6-memo/               # Miscellaneous notes and memos
├── 7-maintenance/        # Maintenance audit reports (TRIP-4-maintain)
└── adr/                  # Architecture Decision Records
```

Note: `5-tuto/` folder is created conditionally in Phase 6 only if the user wants tutorial generation. (Historical installs may also have a `3-code-review/` directory — retired; its numbering gap is deliberate.)

Files (`trip.env`, `ARCHI.md`, `ARCHI-rules.md`, `charter.md`, `adr/template.md`, `changelog_table.md`, `TESTING.md`) will be created in later phases after codebase analysis.

---

## Phase 2: Codebase Exploration

Perform a **thorough exploration** of the codebase to gather information:

### 2.1 Project Indicators to Identify

Read the repository root and the source tree for the usual signals: the build/package manifest identifies the language and toolchain, framework config files (`next.config.*`, `tauri.conf.*`, `platformio.ini`, `serverless.yml`, a linker script) identify the runtime shape, and the source layout identifies the architecture (`src/components/` vs `src/hal/` vs `cmd/` are three different kinds of project). Trust what the tree actually contains over what its name suggests.

### 2.2 Information to Gather

- **Current version** - Check `package.json`, `Cargo.toml`, `version.h`, `__version__`, git tags, or any versioning mechanism. Note the format (SemVer, CalVer, custom). If no version exists, start at `0.1.0`.
- **Languages used** and their versions
- **Build system** and toolchain
- **Dependencies** and their purposes
- **Directory structure** and organization patterns
- **Entry points** (main files, boot sequences)
- **Configuration** approach (env vars, config files, compile-time)
- **Testing** framework and conventions

---

## Phase 3: Project Type Classification

Based on Phase 2 findings, classify the project into one of these categories:

### Project Type Profiles

| Type                  | Indicators                                         | Key Concerns                                          |
| --------------------- | -------------------------------------------------- | ----------------------------------------------------- |
| **Web Frontend**      | React/Vue/Angular/Svelte, components, routing, CSS | Components, State, Styling, Routing, API calls        |
| **Web Backend**       | Express/FastAPI/Gin/Spring, routes, middleware     | Endpoints, Database, Auth, Middleware, Error handling |
| **Full-Stack Web**    | Both frontend and backend in monorepo              | All of above, plus API contracts                      |
| **Desktop App**       | Electron/Tauri/Qt/GTK/WinForms                     | Windows, Native APIs, IPC, Cross-platform             |
| **Mobile App**        | React Native/Flutter/Swift/Kotlin                  | Screens, Navigation, Platform APIs, Offline           |
| **CLI Tool**          | Main entry, arg parsing, no GUI                    | Commands, Config, I/O, Exit codes                     |
| **Library/SDK**       | Public API, no main entry, exports                 | API surface, Versioning, Docs, Compatibility          |
| **Embedded/Firmware** | HAL, interrupts, memory-mapped I/O                 | Hardware, Memory, Real-time, Peripherals, Boot        |
| **Game**              | Game loop, rendering, entities                     | Loop, Rendering, Physics, Input, Assets               |
| **Data/ML Pipeline**  | Notebooks, data processing, models                 | Data flow, Training, Inference, Pipelines             |

### Classification Output

After classification, note:

1. **Primary type** (the main category)
2. **Secondary aspects** (e.g., a CLI tool that's also a library)
3. **Domain-specific concerns** (e.g., real-time constraints, security requirements)

---

## Phase 4: Generate ARCHI.md

Based on the project type, generate `docs/ARCHI.md` using the appropriate sections.

### Universal Sections (ALL projects)

```markdown
# [Project Name] Architecture Documentation

## 1. How to Read This Document

[Document structure and intended audience]

## 2. Overview

[Project purpose, main functionality, high-level architecture]

## 3. Technology Stack

[Languages, frameworks, tools with versions]

## 4. Project Structure

[Directory tree with explanations]

## 5. Core Architecture Principles

[Design principles guiding the codebase]

## 6. Build System & Toolchain

[How to build, compile flags, build targets]

## 7. Configuration

[Environment variables, config files, compile-time options]
```

### Type-Specific Sections

Between the universal opening and closing sections, add the sections this project type actually needs — derived from the Phase 3 classification and what Phase 2 found in the codebase, not from a fixed menu. A web frontend earns component organization, state management, routing, styling, and API integration; a backend earns API design, request lifecycle, database layer, and auth; embedded firmware earns HAL, memory map, interrupts, boot sequence, power, and real-time constraints; a library earns its public API surface and versioning policy. Use the domain's own vocabulary — firmware has *peripherals*, a CLI has *commands*, neither has "components".

Add a section whenever the codebase holds an architectural aspect a newcomer would otherwise have to reverse-engineer — a caching strategy, a plugin system, multi-tenancy, offline sync, a migration mechanism, feature flags. Omit any section the project has no real answer for: an empty heading is worse than no heading.

### Closing Universal Sections (ALL projects)

```markdown
## Data Flow Diagrams

[Mermaid diagrams showing key interactions]

## Error Handling Strategy

[How errors are handled, logged, and reported]

## Testing Strategy

[Test types, frameworks, coverage expectations]

## Performance Considerations

[Optimization strategies, profiling, benchmarks]

## Security Considerations

[If applicable - threat model, mitigations]

## Deployment

[How the project is deployed/distributed/flashed]

## Conclusion

[Summary and key architectural decisions]
```

---

## Phase 5: User Review & Validation

After generating ARCHI.md, **stop and request user review**.

### Present to User

Summarize what was generated:

1. **Project classification** - What type was detected and why
2. **Sections included** - List the sections added to ARCHI.md
3. **Custom sections** - Highlight any sections added beyond the standard templates
4. **Key architectural decisions** documented

### Ask for Feedback

**Use the `AskUserQuestion` tool** to present the user with a structured choice:

- **Question**: "Please review the generated ARCHI.md. How would you like to proceed?"
- **Options**:
  1. **"Approved"** — ARCHI.md looks good, proceed to Phase 6
  2. **"Request changes"** — I have corrections or modifications
  3. **"Add sections"** — I'd like additional sections added

### Handle Feedback

- **If "Approved"**: Proceed to Phase 6
- **If "Request changes"**: Make the requested modifications, then re-present for validation using `AskUserQuestion` again
- **If "Add sections"**: Add them, then re-present for validation using `AskUserQuestion` again
- **If "Other" (custom input)**: Handle accordingly

**Do NOT proceed to Phase 6 until the user explicitly approves the ARCHI.md.**

---

## Phase 6: Write the Project Config

**Skills are never edited** — they are identical in every project. All project state lives in `docs/trip.env` (written here) or the living docs (Phase 7). Everything discovered about the codebase — commands, conventions, priorities, review concerns — lands in ARCHI.md and TESTING.md, which the skills point at. Commands specifically go into TESTING.md's **Verification Recipes** (Phase 7.2), preferring single-source task-runner targets (`make lint`, `npm run lint`) over raw commands.

### 6.1 Tutorial Preference

**Use the `AskUserQuestion` tool** to ask:

- **Question**: "Do you want the release step to generate tutorials after each implementation (learn by doing)?"
- **Options**: **"Yes"** / **"No"**

**If "Yes"**: create the `docs/5-tuto/` folder, then **use the `AskUserQuestion` tool** with multiple questions to capture the audience:

- **Question 1** (header: "Level"): "What is your current programming level?" — "Beginner" / "Intermediate" / "Advanced"
- **Question 2** (header: "Focus", multiSelect: true): "What do you want to learn from these tutorials?" — "Language fundamentals" / "Framework specifics" / "Architecture & patterns" / "Performance & optimization"
- **Question 3** (header: "Style"): "What tutorial style do you prefer?" — "Concise" / "Balanced" / "Verbose"

Write the answers into the **project's CLAUDE.md** — create or append a `## Tutorial audience` section (level, learning focus, style). The release skill's tutorial step reads it from there; the on/off flag goes into `trip.env` below.

### 6.2 Write `docs/trip.env`

```bash
# docs/trip.env — TRIP project configuration. Created by TRIP-init.
# Skills read this at runtime; never edit a skill to change these values.
TRIP_SCHEMA=3
TRIP_PROJECT_NAME="<project name>"
TRIP_VERSION_FILE="<from Phase 2: package.json, Cargo.toml, pyproject.toml, version.h, ...>"
TRIP_MAIN_BRANCH="<git symbolic-ref --short refs/remotes/origin/HEAD, or git branch --show-current for local-only repos>"
TRIP_AUDIT_NUDGE_N=5
TRIP_TUTORIALS=<true|false>
# Optional codex model overrides (defaults live in codex-plan-review/scripts/_common.sh):
# TRIP_CODEX_MODEL_IMPL="..."
# TRIP_CODEX_MODEL_REVIEW="..."
# TRIP_CODEX_EFFORT="..."
```

Fill every value (audit nudge 5 unless the user chooses otherwise). The file must be shell-sourceable — the release skill and the codex scripts `source` it.

### 6.3 Verify Layer Conventions

The planning skill's Technical Considerations pull per-layer conventions from ARCHI.md at planning time. Verify ARCHI.md (Phase 4) documents them — patterns, quality expectations, common pitfalls per component type. If a layer's conventions aren't written down, add them to ARCHI.md now.

---

## Phase 7: Create Supporting Files

Now that ARCHI.md is validated, create the supporting documentation files adapted to the project.

### 1. `docs/2-changelog/changelog_table.md` - Version Tracking

**Version for first entry**: Take the current version identified in Phase 2 and increment the patch number. For example:

- Current `1.2.3` → First entry `1.2.4`
- Current `0.5.0` → First entry `0.5.1`
- No version found → First entry `0.1.0`

This file has two sections:

**Section 1: Quick Reference Table**

```markdown
# Changelog Table

| Version   | Date       | Commit Message                  |
| --------- | ---------- | ------------------------------- |
| `X.Y.Z+1` | DD-MM-YYYY | chore: initialize TRIP workflow |
```

**Section 2: Detailed Changelog Summary**

```markdown
# Changelog Summary

- **vX.Y.Z+1 (DD-MM-YYYY)**: chore: initialize TRIP workflow
  - **Changes**: Initialized TRIP workflow — docs structure, ARCHI.md ([project type] architecture)
  - **Files Added**: docs/trip.env, docs/ARCHI.md, docs/ARCHI-rules.md, docs/charter.md, docs/adr/template.md, docs/2-changelog/changelog_table.md, docs/4-unit-tests/TESTING.md
```

The summary provides context that the table cannot capture: rationale, impact, decisions, review outcome. New entries are added at the **top** of each section. This file is the **single release record** — there are no per-release changelog files.

---

### 2. `docs/4-unit-tests/TESTING.md` - Testing Guidelines

**Adapt based on the validated ARCHI.md** - use the actual test framework, commands, and conventions discovered during codebase exploration:

```markdown
# Testing Guidelines

## Test Framework

[From ARCHI: actual framework name and version]

## Running Tests

\`\`\`bash
[From ARCHI: actual test commands]
\`\`\`

## Test Organization

[From ARCHI: actual test file locations and patterns]

## Writing Tests

[Project-specific conventions observed in the codebase]

## Verification Recipes

Single source of truth for verification commands — the TRIP skills point here and never carry commands themselves. Prefer single-source task-runner targets (make lint, npm run lint) when the project has them.

\`\`\`bash
# Lint:              [actual command, or "none"]
# Type-check/build:  [actual command, or "none"]
# All tests:         [actual command]
# Affected tests:    [actual command] <pattern>
# Single test:       [actual command]
# Coverage:          [actual command]
\`\`\`

## Integration / E2E Impact Rules

[When must the integration/E2E suite run — e.g. "if selectors changed, run the E2E suite" or "if an API contract changed, exercise it against the local server/emulator". Docs-only changes skip this.]

## Coverage Requirements

[From ARCHI: actual coverage thresholds if defined, or "Not defined" if none]
```

---

### 3. `docs/ARCHI-rules.md` - Architecture Maintenance Rules

**Adapt based on the validated ARCHI.md** - reference the actual sections and terminology used:

```markdown
# Architecture Documentation Rules

[ARCHI.md](ARCHI.md) documents the [Project Name] architecture. After each
task (new feature, refactor, bug fix), determine if ARCHI.md needs updating.

## When to Update

Update after ANY change that alters:

- Project structure (new directories, moved files)
- Technology stack (new dependencies, version changes)
- [List actual section names from ARCHI.md that might need updates]
- Data flow or component interactions
- Build or deployment processes

## How to Update by Change Type

### Major Feature / Refactor

Review: [List actual relevant section names from ARCHI.md]

### Minor Feature / Enhancement

Update: [List actual relevant section names from ARCHI.md]

### Bug Fix

Usually no update needed, unless it reveals/fixes an architectural flaw

### Dependency Changes

Update: Technology Stack, and any affected architectural sections

## Guidelines

- Be precise and factual - reflect the actual codebase
- Be concise - enough detail to understand, not implementation specifics
- Update diagrams when data flow changes
- Reference actual file paths
```

---

### 4. `docs/charter.md` - Stable Intent

The charter holds intent that outlasts any single feature. It changes rarely and only via user-approved **design commits**; `TRIP-3-release` flags apparent violations to the user and never edits it silently.

**Use the `AskUserQuestion` tool** to interview the user (purpose, product principles, scope, non-goals, success criteria — one question per topic, offering options derived from the codebase exploration). Draft the charter from the answers, present it, and **get explicit user approval before writing the file**:

```markdown
# [Project Name] Charter

Stable intent only — this document changes rarely, via dedicated design commits.
If a release appears to invalidate it, TRIP-3-release flags the user; the
charter is never silently edited.

## Purpose

[Why this project exists — one paragraph]

## Product Principles

[3-6 principles that outlast any single feature]

## Scope

[What this project does]

## Non-Goals

[What this project deliberately does not do — pair lasting ones with guardrail ADRs]

## Success Criteria

[How we know it's working]
```

---

### 5. `docs/adr/template.md` - ADR Template

Create verbatim (no adaptation needed — it is process, not design):

```markdown
# ADR NNNN: <Title>

- **Status**: active | superseded by ADR-NNNN
- **Date**: <YYYY-MM-DD>
- **Origin**: <plan path under docs/1-plans/, or "design session">
- **Relations**: supersedes <ADR links, or "none">

ADRs are write-once: dated, immutable. A later decision supersedes this one
via a new ADR; the status pointer above is the only edit ever made here.

## Context

[Forces at play — technical, product, process. Written so a reader with no
session memory understands why a decision was needed.]

## Decision

[The decision, stated in full sentences, active voice. For guardrails: what we
deliberately do NOT build, and why.]

## Alternatives Considered (optional)

[Discarded options and why — this is where discarded ideas live, not in living docs]

## Consequences

[What becomes easier, harder, or forbidden]

## Gate

[What a planner or reviewer must check so future work doesn't violate this decision]
```

---

## Post-Initialization Checklist

Verify before reporting completion:

- [ ] ARCHI.md documents **per-layer conventions** — plans and reviews derive from these, so a layer without written conventions is a gap
- [ ] `docs/trip.env` written with every value filled and shell-sourceable (`bash -n docs/trip.env`)
- [ ] **No skill file was edited** — all project state is in trip.env or the living docs
- [ ] TESTING.md has **Verification Recipes** and **Integration/E2E Impact Rules** filled with the project's real commands
- [ ] charter.md **user-approved** before writing; ARCHI.md **user-approved** at Phase 5
- [ ] `docs/adr/template.md`, `ARCHI-rules.md`, and `changelog_table.md` created
- [ ] Tutorial preference resolved: `TRIP_TUTORIALS` set; if true, `docs/5-tuto/` exists and the audience is in the project's CLAUDE.md

---
name: TRIP-init
description: Initialize TRIP workflow in a new project (creates docs structure and generates ARCHI.md)
disable-model-invocation: true
argument-hint: "name of the project to initialize"
---

# TRIP Initialization Mode

You are now in **initialization mode** for setting up the TRIP workflow.

## What is TRIP?

TRIP is a structured development workflow with four phases:

- **P**lan - Design features before implementation
- **I**mplement - Build with proper documentation
- **R**eview - Systematic code review
- **T**est - Comprehensive testing

Why call it TRIP instead of PIRT? Because why not

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
├── 2-changelog/          # Version changelog files
├── 3-code-review/        # Code review documentation
├── 4-unit-tests/         # Unit testing documentation
├── 6-memo/               # Miscellaneous notes and memos
├── 7-maintenance/        # Maintenance audit reports (TRIP-4-maintain)
└── adr/                  # Architecture Decision Records
```

Note: `5-tuto/` folder is created conditionally in Phase 6 only if the user wants tutorial generation.

Files (`ARCHI.md`, `ARCHI-rules.md`, `charter.md`, `adr/template.md`, `changelog_table.md`, `TESTING.md`) will be created in later phases after codebase analysis.

---

## Phase 2: Codebase Exploration

Perform a **thorough exploration** of the codebase to gather information:

### 2.1 Project Indicators to Identify

Look for these signals to understand the project:

**Build/Package Files:**

- `package.json` → Node.js/JavaScript/TypeScript
- `Cargo.toml` → Rust
- `CMakeLists.txt`, `Makefile` → C/C++
- `pom.xml`, `build.gradle` → Java
- `pyproject.toml`, `setup.py`, `requirements.txt` → Python
- `go.mod` → Go
- `*.csproj`, `*.sln` → C#/.NET
- `platformio.ini`, `*.ino` → Embedded/Arduino

**Framework Indicators:**

- `next.config.*`, `nuxt.config.*` → Web frontend frameworks
- `electron.*`, `tauri.conf.*` → Desktop apps
- `Dockerfile`, `docker-compose.*` → Containerized services
- `serverless.yml`, `firebase.json` → Cloud functions
- `startup.s`, `linker.ld`, `*.hal` → Embedded/firmware

**Source Structure:**

- `src/components/` → Component-based UI
- `src/routes/`, `src/pages/` → Web routing
- `src/hal/`, `src/drivers/` → Hardware abstraction
- `src/cmd/`, `cmd/` → CLI tools
- `lib/`, `crates/` → Libraries

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

Select sections based on project type classification.

**Important**: The sections below are starting points, not exhaustive lists. If during codebase exploration you identify architectural aspects that deserve their own section but aren't listed here, **add them**. Examples of custom sections you might add:

- **Caching Layer** - for projects with complex caching strategies
- **Plugin/Extension System** - for extensible architectures
- **Multi-tenancy** - for SaaS applications
- **Offline Support** - for apps with offline-first patterns
- **WebSocket/Real-time** - for real-time communication
- **File Processing Pipeline** - for media/document processing
- **Logging & Observability** - for complex monitoring setups
- **Feature Flags** - for projects with feature flag systems
- **Migration System** - for projects with data migration patterns
- _...or any other architectural aspect significant to the project_

---

#### For Web Frontend

```markdown
## Components & UI Architecture

[Component organization, patterns (atomic, feature-based), reusability]

## State Management

[Local state, global state, server state caching]

## Routing

[Route structure, navigation patterns, guards]

## Styling Architecture

[CSS approach, theming, responsive design]

## API Integration

[Service layer, data fetching, error handling]

## Internationalization (i18n)

[If applicable - translation system, locale handling]
```

---

#### For Web Backend / API

```markdown
## API Design

[Endpoints, REST/GraphQL conventions, versioning]

## Request Lifecycle

[Middleware chain, validation, response formatting]

## Database Layer

[ORM/query patterns, migrations, connections]

## Authentication & Authorization

[Auth flow, session/token management, RBAC]

## Error Handling

[Error types, logging, client responses]

## Background Jobs

[If applicable - queues, scheduled tasks, workers]
```

---

#### For Desktop Application

```markdown
## Window Management

[Main window, dialogs, multi-window architecture]

## Native Platform Integration

[System APIs, file system, notifications, tray]

## IPC Architecture

[If applicable - main/renderer communication, message protocols]

## Cross-Platform Considerations

[Platform-specific code, abstractions, conditional compilation]

## Packaging & Distribution

[Installers, updates, code signing]
```

---

#### For CLI Tool

```markdown
## Command Structure

[Commands, subcommands, argument parsing]

## Input/Output Handling

[stdin/stdout/stderr, interactive mode, piping]

## Configuration Management

[Config files, environment variables, precedence]

## Error Handling & Exit Codes

[Error types, user-friendly messages, exit code conventions]
```

---

#### For Library/SDK

```markdown
## Public API Surface

[Exported modules, main entry points, API stability]

## Internal Architecture

[Private modules, helper utilities]

## Versioning Strategy

[SemVer policy, breaking changes, deprecation]

## Integration Patterns

[How consumers use the library, common patterns]

## Documentation

[API docs generation, examples, guides]
```

---

#### For Embedded/Firmware

```markdown
## Hardware Abstraction Layer (HAL)

[Peripheral abstractions, board support packages]

## Memory Architecture

[Memory map, stack/heap, static allocation, DMA]

## Interrupt Handling

[ISR design, priorities, critical sections]

## Peripheral Drivers

[UART, SPI, I2C, GPIO, ADC, timers, etc.]

## Boot Process

[Startup sequence, initialization order, watchdog]

## Power Management

[Sleep modes, wake sources, power budgeting]

## Real-Time Constraints

[Timing requirements, latency budgets, determinism]

## Communication Protocols

[Protocol stacks, message formats, error recovery]
```

---

#### For Game Development

```markdown
## Game Loop Architecture

[Update/render cycle, fixed timestep, frame timing]

## Entity/Component System

[Entity management, component patterns, systems]

## Rendering Pipeline

[Graphics API, shaders, scene graph, culling]

## Input Handling

[Input abstraction, rebinding, multiple devices]

## Asset Pipeline

[Asset loading, formats, streaming, caching]

## Audio System

[Sound engine, music, spatial audio]

## Physics & Collision

[Physics engine, collision detection, response]
```

---

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

## Phase 6: Update TRIP Skills

After user validation, fill the process-owned placeholders in the skill files.

> **Rule**: skills receive ONLY process-owned values (`[PROJECT_NAME]`, `[VERSION_FILE]`, `[WEEK_ANCHOR_DATE]`, `[MAIN_BRANCH]`, `[AUDIT_NUDGE_N]`, tutorial on/off). Everything discovered about the codebase — commands, conventions, priorities, review concerns — lands in the living docs (ARCHI.md, TESTING.md), which the skills point at. Never inject repo facts into a skill: a design change must never require a skill edit.

### Skills to Update:

1. **`TRIP-1-plan`** - Custom plan sections (optional)
2. **`TRIP-3-release`** - Version file, week anchor, tutorials, audit nudge
3. **`TRIP-hotfix`** - Version file

---

### 6.1 Universal Updates (ALL skills)

**Project Name**: Replace the `[PROJECT_NAME]` placeholder with the actual project name in all skill files.

---

### 6.2 Update `TRIP-1-plan`

**A. Technical Considerations & Layer Guidance** — no edits. These sections are process-only and pull from ARCHI.md/ADRs at planning time. Instead, verify ARCHI.md (Phase 4) documents the per-layer conventions plans will derive from — patterns, quality expectations, and common pitfalls per component type. If a layer's conventions aren't written down, add them to ARCHI.md now.

**B. Custom Plan Sections**

**Use the `AskUserQuestion` tool** to ask:

- **Question**: "Are there any project-specific sections you want included in every plan?"
- **Options**:
  1. **"No custom sections"** — Standard plan sections are sufficient
  2. **"Yes, add custom sections"** — I want to specify additional sections (provide details via "Other")

If the user selects "Yes" or provides custom input, add the specified sections to the plan template.

---

### 6.3 Update `TRIP-3-release` (and `TRIP-hotfix`)

The release ceremony customizations (version, week, tutorials, audit nudge) live in `TRIP-3-release`. No skill receives commands — the testing gate and all verification steps point at TESTING.md (see E below):

**A. Version File Location**

Update TRIP-3-release Step 2 (and the `[VERSION_FILE]` occurrences in TRIP-hotfix) to reference the actual version file:

- `package.json` for Node.js
- `Cargo.toml` for Rust
- `setup.py` / `pyproject.toml` for Python
- `CMakeLists.txt` or `version.h` for C/C++
- Or other location identified in Phase 2

**B. Week Anchor**

The week Init is run becomes **Week 1** of the project. Capture the anchor date (Monday of the current week) and update the week formula in `TRIP-2-implement`.

Run this to get the anchor date:

```bash
date -d "last monday" '+%Y-%m-%d'  # If today is Monday, use: date '+%Y-%m-%d'
```

Then replace the `[WEEK_ANCHOR_DATE]` placeholder in `TRIP-3-release` Step 1 with the actual date. The formula counts elapsed weeks from that fixed date, so it works across year boundaries indefinitely.

**C. Tutorial Generation**

**Use the `AskUserQuestion` tool** to ask:

- **Question**: "Do you want the Implement command to generate tutorials after each implementation (learn by doing)?"
- **Options**:
  1. **"Yes"** — Generate tutorials after each implementation
  2. **"No"** — Skip tutorial generation

**If "No"**:

- Remove the `[TUTORIAL_STEP]` block entirely from `TRIP-3-release`
- Do NOT create the `docs/5-tuto/` folder
- No renumbering needed — the existing step numbers are already correct for this case

**If "Yes"**:

- Create the `docs/5-tuto/` folder
- **Use the `AskUserQuestion` tool** with multiple questions to customize tutorial generation:

  **Question 1** (header: "Level"): "What is your current programming level?"
  - **Options**: "Beginner" (learning fundamentals), "Intermediate" (comfortable with basics, learning advanced), "Advanced" (experienced, deep dives and edge cases)

  **Question 2** (header: "Focus", multiSelect: true): "What do you want to learn from these tutorials?"
  - **Options**: "Language fundamentals" (syntax, idioms, patterns), "Framework specifics" (React, Rust, etc.), "Architecture & patterns" (design patterns, system design), "Performance & optimization" (profiling, caching, efficiency)

  **Question 3** (header: "Style"): "What tutorial style do you prefer?"
  - **Options**: "Concise" (key points, minimal explanation), "Balanced" (explanations with examples), "Verbose" (detailed explanations, multiple examples, diagrams)

Then in `TRIP-3-release`:

1. Uncomment the `[TUTORIAL_STEP]` block **as-is** — it is pure process; do NOT write the user's answers into the skill.
2. Write the audience answers into the **project's CLAUDE.md** instead — create or append a `## Tutorial audience` section (level, learning focus, style). The tutorial step reads it from there.

**IMPORTANT — Renumber subsequent steps**: After uncommenting the Tutorial as Step 8, renumber the steps that follow:

- Step 8: README Update → **Step 9**: README Update
- Step 9: Commit → **Step 10**: Commit
- Step 10: Tag → **Step 11**: Tag
- Step 11: Merge → **Step 12**: Merge
- Step 12: Push → **Step 13**: Push
- Step 13: Maintenance Audit Nudge → **Step 14**: Maintenance Audit Nudge

**D. Audit Nudge Threshold**

Replace `[AUDIT_NUDGE_N]` in the `TRIP-3-release` Maintenance Audit Nudge step with **5** (or a user-chosen value).

**E. Verification Recipes**

Do NOT put commands in any skill. The actual lint / type-check / test / coverage / integration commands discovered in Phase 2 go into the **Verification Recipes** section of `docs/4-unit-tests/TESTING.md` (Phase 7.2). **Prefer single-source task-runner targets** (`make lint`, `npm run lint`) over raw commands when the project has them — the runner config then stays the single source of truth.

---

### 6.4 `TRIP-review` and `TRIP-test` — no project edits

Beyond `[PROJECT_NAME]`, do NOT edit `TRIP-review/SKILL.md`, `checklist.md`, `cr-template.md`, or `TRIP-test/SKILL.md`. They are fully generic: review criteria derive project conventions from ARCHI.md and the guardrail ADRs at review time, and test commands/structure/priorities live in `docs/4-unit-tests/TESTING.md`. Any review- or test-relevant project concern discovered at init belongs in ARCHI.md or TESTING.md, never in these files.

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

| Version   | Week | Commit Message                  |
| --------- | ---- | ------------------------------- |
| `X.Y.Z+1` | 1    | chore: initialize TRIP workflow |
```

- **Version**: SemVer format in backticks (e.g., `1.0.0`, `0.2.1`)
- **Week**: Project week number. Week 1 = the week when TRIP Init was run.
- **Commit Message**: One-line description of the change

**Section 2: Detailed Changelog Summary**

```markdown
# Changelog Summary

- **vX.Y.Z+1 (TRIP Initialization - Week 1, DD-MM-YYYY)**:
  - **Setup**: Initialized TRIP workflow with docs structure
  - **Documentation**: Generated ARCHI.md with [project type] architecture
  - **Files Added**: docs/ARCHI.md, docs/ARCHI-rules.md, docs/charter.md, docs/adr/template.md, docs/2-changelog/changelog_table.md, docs/4-unit-tests/TESTING.md
```

The summary provides context that the table cannot capture: rationale, impact, technical decisions, and file-level details. New entries are added at the **top** of each section.

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

- **Status**: proposed | accepted | rejected | superseded by ADR-NNNN
- **Relations**: supersedes / amends <ADR links, or "none">
- **Plan-Release**: <plan path under docs/1-plans/> → <release version, filled at release>

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

- [ ] Core `docs/` folders created (Phase 1): 1-plans, 2-changelog, 3-code-review, 4-unit-tests, 6-memo, 7-maintenance, adr
- [ ] Codebase thoroughly explored (Phase 2)
- [ ] Current version identified (Phase 2)
- [ ] Project type correctly classified (Phase 3)
- [ ] ARCHI.md generated with appropriate sections, **including per-layer conventions plans and reviews will derive from** (Phase 4)
- [ ] Custom sections added where relevant (Phase 4)
- [ ] **User reviewed and approved ARCHI.md** (Phase 5)
- [ ] **TRIP skills updated — process-owned values only, no repo facts injected** (Phase 6):
  - [ ] `[PROJECT_NAME]` placeholder replaced in all skills
  - [ ] `TRIP-1-plan`: Custom plan sections added (if user requested)
  - [ ] `TRIP-3-release`: `[VERSION_FILE]` placeholder replaced
  - [ ] `TRIP-3-release`: `[WEEK_ANCHOR_DATE]` placeholder replaced
  - [ ] `TRIP-3-release`: `[AUDIT_NUDGE_N]` set (default 5)
  - [ ] `TRIP-3-release`: Tutorial preference configured (if enabled: 5-tuto/ folder created, steps renumbered, audience recorded in the project's CLAUDE.md; if disabled: `[TUTORIAL_STEP]` block removed)
  - [ ] `TRIP-hotfix`: `[VERSION_FILE]` placeholder replaced
  - [ ] `TRIP-review` and `TRIP-test`: NOT edited beyond `[PROJECT_NAME]`
- [ ] changelog_table.md initialized with version+1 (Phase 7)
- [ ] TESTING.md created with **Verification Recipes** and **Integration/E2E Impact Rules** filled with the actual commands/rules (Phase 7)
- [ ] ARCHI-rules.md created, referencing actual ARCHI sections (Phase 7)
- [ ] charter.md interviewed, drafted, **user-approved**, and written (Phase 7)
- [ ] `docs/adr/template.md` created verbatim (Phase 7)

---

## Notes for the Agent

- **Explore thoroughly**: Read key files to understand the project before classifying
- **Be adaptive**: The section list is a guide, not a rigid template. Add custom sections when the codebase has architectural patterns not covered by the templates
- **Use correct terminology**: Embedded projects have "peripherals", not "components". CLI tools have "commands", not "routes"
- **Ask if uncertain**: If the project type is ambiguous, ask the user
- **Focus on what exists**: Document the actual architecture, not an idealized version
- **Diagrams matter**: Mermaid diagrams help visualize complex flows regardless of project type
- **User review is mandatory**: Never skip Phase 5. The user must validate the ARCHI.md before proceeding
- **Iterate if needed**: If the user requests changes, make them and re-present for approval

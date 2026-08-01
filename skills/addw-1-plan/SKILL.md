---
name: addw-1-plan
description: Plan a new feature following project standards
argument-hint: "describe the feature you want to build"
---

# Planning Mode

You are now in **planning mode**.

## Prerequisites - Read First

Before creating any plan, you MUST read ALL THE LINES of:

1. @docs/ARCHITECTURE.md - Understand current system architecture
2. @docs/charter.md - Stable intent: purpose, principles, scope, non-goals
3. `docs/adr/` - Skim titles and statuses; fully read every ADR touching the feature's area (guardrail ADRs especially)

## Your Task

Plan the following feature: $ARGUMENTS

---

## Step 1: Discovery & Clarification (Interactive)

**Do NOT start writing a plan immediately.** First, engage in a discovery conversation to fully understand the user's intent.

### 1.1 Initial Understanding

After reading the feature request, summarize your understanding in 2-3 sentences, then **use the `AskUserQuestion` tool** to present clarifying questions with structured options.

Frame questions around:

- **Scope**: What's included vs excluded?
- **Behavior**: How should it work from the user's perspective?
- **Constraints**: Any technical limitations, deadlines, or dependencies?
- **Priority**: What's most important if trade-offs are needed?

For each question, provide 2-4 concrete options based on your analysis of the codebase and the feature request. Always let the user provide custom input via the built-in "Other" option.

After the user answers, proceed **directly to writing the plan** (Step 2) — no approach-confirmation question. Ask a follow-up round with `AskUserQuestion` only if a blocking ambiguity remains (**maximum 3 rounds total**; if still unclear, summarize what you know and proceed, recording the assumptions in the plan's **Open Questions & Assumptions** section).

---

## Step 2: Plan Document Creation

Once understanding is confirmed, create the plan document.

### File Naming

Depending on the feature (major, minor, patch), propose a new version using SemVer (x.y.z) and create:
`docs/1-plans/F_[version]_[feature-name].plan.md`

### Required Sections

```markdown
# [Feature Name] Implementation Plan

## Overview

[2-4 sentences describing the feature and its purpose]

## Problem Statement (if applicable)

[Current limitations/issues this feature addresses]

## Solution Architecture

[High-level design approach]

## Implementation Details

### 1. [Component/Module/File Name]

**File**: `path/to/file`

[Detailed description of changes needed]

**Current state** (if modifying existing):
[Describe what currently exists]

**Modifications**:

- Specific change 1 (around line X)
- Specific change 2 (around line Y)

### 2. [Next Component/Module/File]

[Continue with same pattern]

## Technical Considerations

- **Architecture Alignment**: How this plan conforms to the constraints in ARCHITECTURE.md (as-built) and reintroduces nothing the ADRs in `docs/adr/` have superseded or ruled out. Derive this from those documents at planning time — never from memory.
- **Doc Impact**: If this plan changes or supersedes anything the living docs state — everything in `docs/` outside the numbered per-release directories, plus CLAUDE.md and README.md — name the affected documents here. Enumerate that scope at planning time rather than working from a remembered list. `addw-3-release` consumes this list. An empty list is a claim ("this plan contradicts nothing documented"), not a default.
- **Process/Design Separation**: `.claude/skills/` files are never modified as part of a feature. If this plan appears to need a skill edit, that is a process change — propose it separately, commit it separately.
- **Layer Conventions**: For each layer/artifact type this plan adds to, state how the addition satisfies the conventions ARCHITECTURE.md documents for that layer — pulled at planning time. No per-layer checklist is ever cached in this skill; caches rot, ARCHITECTURE.md does not.
- **Edge Cases**: [Relevant edge cases for this feature]

## Files to Modify/Create

[Comprehensive numbered list with purposes]

1. `path/to/file1` (modify) - Purpose description
2. `path/to/file2` (new) - Purpose description

## Type Definitions (if applicable)

[New types, interfaces, structs, or modifications to existing ones]

## Performance & Cost Impact (if applicable)

[Expected performance implications]

## Backward Compatibility (if applicable)

[Migration strategy if needed]

## Test Impact

[2-5 bullets: which existing tests the change affects, what new logic will need tests, whether an integration/E2E check applies. No test code — the addw-2 testing gate consumes this section.]

## Open Questions & Assumptions (if applicable)

[Assumptions this plan proceeds on without explicit user confirmation, and questions the approver must answer before implementation starts. Omit when there are none.]

## To-dos

### Phase 1: [Phase Name] (if multiple phases are needed) or simply skip title if only one phase is needed

- [ ] Task description
- [ ] Another task

### Phase 2: [Phase Name] (if applicable)

- [ ] Task description
- [ ] Another task

**Note**: For simple plans, a single phase is sufficient. Split into multiple phases only for complex features requiring sequential implementation.

**Note**: Do NOT write test code during planning — the Test Impact section above only names what the addw-2 testing gate will run and author.
```

Every step must be unambiguous and actionable, name exact files and functions, and call out where it could fail.

### Declared-Files Check

After writing the plan, verify the Files to Modify/Create section against the working tree — deterministically, not from memory:

```bash
bash .claude/skills/addw-1-plan/scripts/check-plan-files.sh <plan-path>
```

Every `(new)` path must not exist yet; every `(modify)` or `(delete)` path must exist. Fix each MISMATCH before the Codex review — it means the plan was written against a remembered tree, not the real one (wrong path, stale assumption, or wrong verb). Re-run until it reports OK.

---

## Step 3: Codex Second-Opinion Review

Before the user sees the plan, run the second-opinion plan review loop — no confirmation needed. Skip it only for genuinely trivial plans (single-file, low-risk); say so in the Step 4 summary when you do.

The reviewing agent is the skill named by `ADDW_PLAN_REVIEW_SKILL` in `docs/addw.env` (default `codex-plan-review`) — source the config first so the role key resolves.

### Loop

1. **Start**:
   ```bash
   source docs/addw.env
   bash ".claude/skills/${ADDW_PLAN_REVIEW_SKILL:-codex-plan-review}/scripts/start.sh" <plan-path>
   ```
2. **Parse trailing tag**: `APPROVED` -> Step 4. `NEEDS_REWORK` -> surface to user. `REQUEST_CHANGES` -> continue.
3. **Address findings critically** — quote each P1/P2, push back on incorrect ones, fix legitimate ones by editing the plan in place.
4. **Write implementer notes** (1-3 sentences): which findings you fixed, which you pushed back on and why, any user decisions that override existing docs or environment limitations that can't be resolved in the plan.
5. **Resume** with notes:
   ```bash
   bash ".claude/skills/${ADDW_PLAN_REVIEW_SKILL:-codex-plan-review}/scripts/resume.sh" \
       --notes "Fixed X. Pushed back on Y because Z. User decided W." \
       <plan-path>
   ```
   -> back to step 2.
6. **Cap at 5 rounds** (or user-specified). Surface remaining findings and let user decide.

Surface Codex reviews verbatim. Keep edits scoped to findings. Reset thread (`reset.sh <plan-path>`) only if context is genuinely confused.

---

## Step 4: User Review & Validation

After Codex review converges (or is skipped), present a summary to the user including:

- **Feature**: [name]
- **Approach**: [1-2 sentences]
- **Files affected**: [count] files ([list key ones])
- **Estimated complexity**: [simple/moderate/complex]
- **Codex status**: [APPROVED / skipped / capped at N rounds with open findings]
- **Open assumptions**: [from the plan's Open Questions & Assumptions section, or "none"]

Then **use the `AskUserQuestion` tool** to collect feedback:

- **Question**: "Please review the plan at `docs/1-plans/F_x.y.z_feature-name.plan.md`. How would you like to proceed?"
- **Options**: "Approved" (ready for implementation), "Request changes" (I have modifications), "Needs rework" (significant issues to address)

Handle feedback:

- **If "Request changes"**: Update the plan and re-present. Run another Codex pass if changes are substantive.
- **If "Needs rework"**: Discuss issues, rework the plan, and re-present.
- **If "Other" (custom input)**: Handle accordingly.
- **If "Approved"**: first complete **ADR Writing** (below) if the plan changes documented intent, then **use the `AskUserQuestion` tool** to ask:
  - **Question**: "Plan approved. Would you like to start implementation now?"
  - **Options**: "Yes, implement now" (proceed with `addw-2-implement` using this plan), "Not yet" (I'll implement later)

### ADR Writing (on approval)

If the plan's Doc Impact section says it changes documented intent — it contradicts or supersedes anything ARCHITECTURE.md, charter.md, or a prior ADR states — record the decision now, while the discussion that made it is fresh:

1. Copy `docs/adr/template.md` to `docs/adr/NNNN-<slug>.md` (next free sequence number), dated today, status `active`. Name this plan's path as the origin, and in Relations name any ADR it supersedes (flip that one's status to `superseded by ADR-NNNN` — the pointer is the only edit ever made to an existing ADR). Draw Alternatives from what the planning discussion actually rejected.
2. Guardrail decisions — things deliberately NOT built — are first-class ADRs; record them the same way.
3. **Write it self-contained.** An ADR outlives the working documents around it, so it may cite only things that live as long: other ADRs, the charter, ARCHITECTURE.md, and dated records that are never pruned — including its own origin plan. Never point it at a worklist, backlog, handoff, or audit report. Those are pruned as their tasks close, so the citation rots into a dead reference while still reading as precise. Where such a document holds the evidence, restate the evidence here in the ADR's own words.
4. Commit the ADR on the feature branch together with the plan. ADRs are **write-once**: if a later decision changes this one, a new ADR supersedes it — including the case where this work is abandoned.

An ADR in the plan's scope may be superseded with reasons, but never silently ignored. Routine feature work that changes no documented intent writes no ADR — do not create ceremony for conforming plans.

---

## IMPORTANT: No Code Implementation

**DO NOT write code snippets or implement anything during planning** — not feature code, not test code, not algorithm sketches. The plan states WHAT changes, WHERE, and WHY; code comes in `addw-2-implement`.

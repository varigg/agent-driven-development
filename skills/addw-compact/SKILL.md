---
name: addw-compact
description: Compact ARCHITECTURE.md when it exceeds recommended size - smart compression without losing relevance
disable-model-invocation: true
---

# ARCHITECTURE.md Compaction Mode

You are now in **compaction mode** - intelligently reducing ARCHITECTURE.md size while preserving its value.

## Why Compact?

ARCHITECTURE.md should not exceed _~20k tokens_. A bloated ARCHITECTURE.md:

- Consumes tokens that could be used for actual work
- Slows down every command that reads it
- May contain redundant or outdated information
- Defeats the purpose of "balanced detail vs token usage"

## Your Task

Compact: @docs/ARCHITECTURE.md

---

## Step 1: Assess Current State

First, measure the actual token count using the bundled script:

```bash
bash .claude/skills/addw-compact/count-tokens.sh docs/ARCHITECTURE.md
```

Then read the full ARCHITECTURE.md and evaluate:

1. **Identify bloat sources**:
   - Verbose explanations where concise would suffice
   - Redundant information repeated across sections
   - Implementation details that belong in code comments, not architecture docs
   - Overly detailed file listings
   - Excessive examples

**If token count > 20,000**, report the assessment to the user, then **use the `AskUserQuestion` tool**:

- **Question**: "ARCHITECTURE.md is at ~[X] tokens (target: ~10,000-15,000). Main bloat sources: [list top 3-5]. Proceed with compaction?"
- **Options**: "Yes, compact" (proceed with compaction strategies), "No, leave as-is" (stop here)

**If token count <= 20,000**, report to the user, then **use the `AskUserQuestion` tool**:

- **Question**: "ARCHITECTURE.md is at ~[X] tokens — within acceptable range. Would you still like to compact it further?"
- **Options**: "Yes, compact anyway" (proceed with compaction), "No, it's fine" (stop here)

If "No" in either case, stop here.

---

## Step 2: Compaction Strategies

Apply these strategies **in order of priority**:

### 2.1 Remove Redundancy (First Pass)

- Eliminate repeated information across sections
- Consolidate overlapping descriptions
- Remove "see above" or "as mentioned" patterns - restructure instead

### 2.2 Increase Information Density

Replace narrative paragraphs with labelled facts. A paragraph explaining that auth goes through Supabase, creates a session, returns a token, and distinguishes two roles becomes four labelled lines — same information, a fifth of the tokens.

### 2.3 Convert Prose to Structured Formats

Tables for comparisons, bullets for enumerations, `code` for paths/commands/types, mermaid for flows that prose describes at length.

### 2.4 Collapse Implementation Details

Keep **what** and **why**; drop **how**. A hook's internal `useState`/`useEffect`/`useCallback` wiring is implementation — one line naming its responsibility is architecture.

### 2.5 Summarize File Listings

Collapse a directory's file-by-file enumeration into one line naming the directory and what lives in it.

### 2.6 Use References Instead of Duplication

Link to the section that explains a pattern rather than re-explaining it.

---

## Step 3: Preserve Critical Information

**NEVER compress or remove:**

- Project overview and purpose
- Technology stack with versions
- Directory structure (can be summarized but not removed)
- Core architectural principles
- Key patterns and their locations
- Data flow diagrams
- API contracts/interfaces
- Configuration requirements
- Build/deployment commands

**These are the backbone** - compress everything else first.

---

## Step 4: Validate Compression

The test is whether a new developer could still onboard from the compacted document. Concretely: every major section survives, the tech stack is complete, the directory structure is followable, key patterns are still located, internal links resolve, and mermaid diagrams still parse.

---

## Step 5: Measure & Present Changes

Run the script again on the compacted file:

```bash
bash .claude/skills/addw-compact/count-tokens.sh docs/ARCHITECTURE.md
```

Present the compaction results to the user, then **use the `AskUserQuestion` tool**:

- **Question**: "Compaction complete: ~[X] → ~[Y] tokens ([Z]% reduction). Changes: [brief summary]. How does the compacted ARCHITECTURE.md look?"
- **Options**: "Looks good" (compaction is complete), "Restore some detail" (specific sections need more detail), "Too aggressive" (undo and try lighter compaction)

---

## Step 6: Iterate if Needed

If the user wants detail restored somewhere, restore it there and compensate by compressing a less critical section further.

If the file is still over 15k tokens after honest compression, propose splitting it: `ARCHITECTURE.md` (core, read by default) + `ARCHITECTURE-detailed.md` (deep dives, read on demand).

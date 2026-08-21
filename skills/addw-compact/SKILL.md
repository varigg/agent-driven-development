---
name: addw-compact
description: Compact ARCHITECTURE.md when it exceeds recommended size - smart compression without losing relevance
disable-model-invocation: true
---

# ARCHITECTURE.md Compaction Mode

You are now in **compaction mode** - intelligently reducing ARCHITECTURE.md size while
preserving its value. The rewrite lands the same way every other change does: on a branch,
as a pull request reviewed at the Boundary. The human's merge is the approval — nothing
here asks permission to proceed, and nothing here lands a commit on the main branch.

## Why Compact?

ARCHITECTURE.md should not exceed its token budget —
`${ADDW_COMPACT_THRESHOLD:-20000}` tokens, a per-project value from
`docs/addw.env` (rule of thumb for choosing one: ~10% of the context window).
A bloated ARCHITECTURE.md:

- Consumes tokens that could be used for actual work
- Slows down every command that reads it
- May contain redundant or outdated information
- Defeats the purpose of "balanced detail vs token usage"

## Your Task

Compact: @docs/ARCHITECTURE.md

---

## Step 1: Assess & Triage

First, load the project's budgets and measure the actual token count using the
bundled script:

```bash
. .claude/skills/lib/config/config.sh && config_source ADDW_COMPACT_THRESHOLD ADDW_COMPACT_TARGET_MIN ADDW_COMPACT_TARGET_MAX
bash .claude/skills/addw-compact/count-tokens.sh docs/ARCHITECTURE.md
```

**If the count is at or below `${ADDW_COMPACT_THRESHOLD:-20000}`**, the document is
within range: report the count and **stop**. There is nothing to land, so no branch and
no PR. Compacting a within-range document is work nobody asked for.

**If the count exceeds `${ADDW_COMPACT_THRESHOLD:-20000}`**, read the full
ARCHITECTURE.md and identify the bloat sources:

- Verbose explanations where concise would suffice
- Redundant information repeated across sections
- Implementation details that belong in code comments, not architecture docs
- Overly detailed file listings
- Excessive examples

Report the assessment — the count, the target range
(`${ADDW_COMPACT_TARGET_MIN:-10000}`–`${ADDW_COMPACT_TARGET_MAX:-15000}`), and the top bloat sources —
then **use the `AskUserQuestion` tool** for the one thing only the human knows: the
**bloat-triage intent fork**. Which sections are load-bearing (their detail must survive)
and which are compressible? Build the options from the sections you identified, with
multi-select. An intent fork is not permission — compaction proceeds either way; the
answer decides where the compression lands.

---

## Step 2: Branch

The rewrite rides its own PR, so branch before editing:

```bash
. .claude/skills/lib/config/config.sh && config_source ADDW_MAIN_BRANCH
git checkout "$ADDW_MAIN_BRANCH" && git pull
git checkout -b docs/compact-architecture
```

If that branch already exists, locally or on the remote, an earlier compaction is in
flight — surface that to the human before proceeding. And confirm the checkout actually
succeeded before editing: a failed `checkout -b` leaves HEAD on `$ADDW_MAIN_BRANCH`, and
committing there is exactly what this skill promises never to do.

---

## Step 3: Compaction Strategies

Apply these strategies **in order of priority**, honoring the triage answer — a section the
human marked load-bearing keeps its detail, and the compression concentrates elsewhere:

### 3.1 Remove Redundancy (First Pass)

- Eliminate repeated information across sections
- Consolidate overlapping descriptions
- Remove "see above" or "as mentioned" patterns - restructure instead

### 3.2 Increase Information Density

Replace narrative paragraphs with labelled facts. A paragraph explaining that auth goes through Supabase, creates a session, returns a token, and distinguishes two roles becomes four labelled lines — same information, a fifth of the tokens.

### 3.3 Convert Prose to Structured Formats

Tables for comparisons, bullets for enumerations, `code` for paths/commands/types, mermaid for flows that prose describes at length.

### 3.4 Collapse Implementation Details

Keep **what** and **why**; drop **how**. A hook's internal `useState`/`useEffect`/`useCallback` wiring is implementation — one line naming its responsibility is architecture.

### 3.5 Summarize File Listings

Collapse a directory's file-by-file enumeration into one line naming the directory and what lives in it.

### 3.6 Use References Instead of Duplication

Link to the section that explains a pattern rather than re-explaining it.

---

## Step 4: Preserve Critical Information

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

**These are the backbone** - compress everything else first. Sections the triage marked
load-bearing join this list for the run.

---

## Step 5: Validate Compression

The test is whether a new developer could still onboard from the compacted document. Concretely: every major section survives, the tech stack is complete, the directory structure is followable, key patterns are still located, internal links resolve, and mermaid diagrams still parse.

---

## Step 6: Measure & Open the PR

Run the script again on the compacted file:

```bash
bash .claude/skills/addw-compact/count-tokens.sh docs/ARCHITECTURE.md
```

**If the result is still over `${ADDW_COMPACT_TARGET_MAX:-15000}` tokens after honest
compression** — the target's upper bound is also the split trigger — one intent fork
remains before the PR: propose splitting the document — `ARCHITECTURE.md` (core, read by
default) + `ARCHITECTURE-detailed.md` (deep dives, read on demand) — and **use the
`AskUserQuestion` tool** to let the human choose between the split and accepting the
over-target size. You cannot rank these from the repo: the split trades every reader's
default context for depth on demand, and whether that trade is worth it is knowledge only
the human has. If the split is chosen, perform it on this same branch so one PR carries the
whole change — then repeat Step 5's validation and the token measurement on both resulting
files, so what the PR reports is the final state, not the pre-split one.

The diff is documentation-only, so no testing gate runs here; Step 5's validation — links
resolve, diagrams parse, onboarding survives — is the pre-PR check. Commit with explicit
paths (never `git add -A`) and a conventional subject, push, and open the PR:

```bash
git push -u origin docs/compact-architecture
gh pr create --base "$ADDW_MAIN_BRANCH" \
    --title "docs: compact ARCHITECTURE.md" --body-file <file>
```

The PR body carries what the in-conversation summary used to: the before/after token counts
from the script, which strategies did the heavy lifting and in which sections, the triage
answer it honored, and anything the reviewer should double-check — detail you judged
droppable but a reader might miss.

Then **stop**. Do not merge. "Restore some detail" and "too aggressive" are review
comments now: they arrive on the PR, and addressing them — restoring detail in one section,
compensating by compressing a less critical one — happens on this branch like any other
review round at the Boundary.

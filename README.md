![ADDW Workflow Banner](assets/trip-workflow-banner2.png)

![Version](https://img.shields.io/badge/version-3.0.0-blue) [![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE) ![Works with](https://img.shields.io/badge/Works_with-grey) [![Claude Code](https://img.shields.io/badge/Claude_Code-E5582B)](https://docs.anthropic.com/en/docs/claude-code) [![Codex CLI](https://img.shields.io/badge/Codex_CLI-10A37F)](https://developers.openai.com/codex/cli/) [![OpenCode](https://img.shields.io/badge/OpenCode-1a3a5c)](https://github.com/sst/opencode) [![Mistral Vibe](https://img.shields.io/badge/Mistral_Vibe-F7D046)](https://github.com/mistralai/mistral-vibe)

## What is Agent-Driven Development?

A structured development workflow for AI coding agents that brings **memory**, **consistency**, and **reduced hallucination** (only humans should) to AI-assisted development.
**ADDW** — the **a**gent-**d**riven **d**evelopment **w**orkflow — is the prefix every skill shares. The flow is **Plan → Implement → Release**, with review and testing living *inside* Implement as a testing gate and an automatic Codex review loop.

ADDW was initially designed for Claude Code using the [Agent Skills](https://agentskills.io/home) open standard (`SKILL.md`). Also compatible with OpenCode, Codex CLI, Mistral Vibe and more.

## Why ADDW?

There are tons of AI coding workflows out there like [Superpowers](https://github.com/obra/superpowers), [BMAD](https://github.com/bmad-code-org/BMAD-METHOD), [Gastown](https://github.com/steveyegge/gastown) and countless others. They might be powerful, but overwhelming for many of us dumb asses.

Even the "simple" ones come with:

- 47 different commands & skills to memorize
- Sub-agents swarm for God-knows-what
- Mutlti-chapters courses (sometimes paid lol)

**ADDW is different.** It's deliberately minimal:

| That's it           | Just these                                             |
| ------------------- | ------------------------------------------------------ |
| `/addw-1-plan`      | Think before you code (Codex reviews the plan)         |
| `/addw-2-implement` | Codex writes, you review, tests gate, Codex re-reviews |
| `/addw-3-release`   | Version, changelog, docs, commit, tag, merge, push     |

![ADDW Workflow loop](assets/trip-workflow-loop2.png)

Three numbered skills. One architecture file. Zero PhD required.

The onboarding is: copy the folder, run init, start coding. If you can count to 3, you can run it.

It was kept stupid simple because **the goal is to ship features, not to master a workflow**. The workflow should disappear into the background, not become a project of its own.

## Getting Started

1. Copy the `skills/` folder contents to your repo's `.claude/skills/` or whatever
2. Run `/addw-init [YourProjectName]`
3. Follow the interactive prompts
4. Review and approve the generated ARCHITECTURE.md

### Additional For Mistral users (if they exist)

Also copy `AskUserQuestion/` to your agent `/skills/` — it emulates the `AskUserQuestion` tool the ADDW skills rely on. It deliberately lives outside `skills/`: agents with a native `AskUserQuestion` tool (like Claude Code) don't need the shim, so it isn't part of the wholesale copy.  

Et voila ! Start using the skills like `/addw-1-plan auth for this webapp`, `/addw-2-implement @auth-plan.md`, etc.

https://github.com/user-attachments/assets/d37bbc60-1868-4fa8-9be6-083b60d6a53d

## The Heart of ADDW: ARCHITECTURE.md

The `ARCHITECTURE.md` file is the **central nervous system** of this workflow. It serves as the AI agent's **long-term memory** of your codebase.

It is flanked by two companions: `docs/charter.md` holds the stable intent (purpose, scope, non-goals) that outlasts any feature, and `docs/adr/` holds dated, write-once Architecture Decision Records — written whenever a plan or design session changes documented intent, `active` until a later ADR supersedes them, with guardrail ADRs recording what you deliberately do *not* build so no future plan reintroduces it.

### Why ARCHITECTURE.md Matters

**1. Persistent Context Across Sessions**

AI agents have no memory between sessions. Every new conversation starts from zero. ARCHITECTURE.md solves this by providing a comprehensive, always-up-to-date snapshot of your architecture that the agent reads at the start of each task. Unlike tool-specific files like `CLAUDE.md` or `AGENTS.md`, ARCHITECTURE.md is purely about architecture. It's tool-agnostic, so it works with any agent. You can still reference it from your `CLAUDE.md` to include it in all conversations.

**2. Token Savings & Reduced Hallucination**

Without ARCHITECTURE.md, your agent must glob, grep, and read multiple files to piece together the architecture from scratch for every single session. This wastes tokens and leads to guessing: _"There's probably a utils folder..."_, _"This project likely uses Redux..."_. ARCHITECTURE.md eliminates both problems. The agent gets the full picture in one read for minimal exploration & hallucination.

**3. Balanced Detail vs Token Usage**

ARCHITECTURE.md is designed to be:

- **Detailed enough** to provide meaningful context, **concise enough** to not waste tokens
- **Structured** for quick navigation
- **Updated** after every architectural change

It's not a dump of your entire codebase, rather a curated architectural guide.

## The Init Process

The `addw-init` skill is a **script written in human language** that programmatically bootstraps the ADDW workflow in any repository.

### What Init Does

1. **Creates the docs structure** - Folders for plans, tests, memos, maintenance reports, and ADRs, plus a root `CHANGELOG.md` (written at release time, never read by skills — human-consumable history only)
2. **Explores your codebase** - Identifies languages, frameworks, patterns, conventions
3. **Classifies your project** - Web frontend? CLI tool? Embedded firmware? Library?
4. **Generates the living docs** - ARCHITECTURE.md (as-built, tailored to your project type), charter.md (stable intent, from a short interview), TESTING.md (with your actual verification commands), and the ADR template
5. **Writes `docs/addw.env`** - Process-owned values only

### The Config File

Skills are **never edited** — they are byte-identical in every project. The handful of process-owned values (project name, version file location, main branch, audit cadence, tutorial flag, optional Codex model overrides) live in `docs/addw.env`, which init writes and the skills read at runtime. Everything else init discovers about your codebase — commands, conventions, review concerns — lands in the living docs (ARCHITECTURE.md, TESTING.md), which the skills point at. Skills stay pure process: neither a design change nor a config change ever requires a skill edit, and upgrading ADDW means replacing the skills folder wholesale.

## More Skills

### `/codex-implement`

Implementation delegated to Codex CLI in a **workspace-write sandbox**: it reads the approved plan, edits the working tree, runs your lint/build, and reports back with a completion tag. Your main agent then self-reviews the diff and fixes issues directly. Persistent thread per plan, so multi-phase plans resume with full context. Integrated into addw-2-implement as the default implementation path.

### `/codex-plan-review` & `/codex-code-review`

Iterative review loops powered by Codex CLI. Plans get a second-opinion review before the user sees them. Code gets reviewed against the plan and a shared checklist (`codex-code-review/checklist.md` — also the criteria for any manual review) after implementation. Both use persistent thread state for multi-round convergence (`start → REQUEST_CHANGES → fix → resume → APPROVED`). Integrated directly into addw-1-plan and addw-2-implement (after the testing gate). The review outcome lands as one line in the release's changelog entry — no separate review archive.

Per-flow model defaults (implementation vs reviews) live in `codex-plan-review/scripts/_common.sh`, overridable per project via `docs/addw.env` or per run via `CODEX_MODEL` / `CODEX_EFFORT` env vars.

### `/addw-test`

The former step 4, reborn as an on-demand support skill: the deep test-authoring reference with a seam ladder and a coverage-debt ledger for hard-to-test code.

### `/addw-4-maintain`

Periodic maintenance audit with four independently skippable sweeps: code health, test health, docs drift, and dependencies. Writes a dated findings report to `docs/7-maintenance/`, applies only trivial mechanical fixes, and routes anything substantive through the normal plan → implement → release cycle. `addw-3-release` nudges you to run it after N releases without an audit.

### `/addw-upgrade`

Upgrades an existing project's ADDW install. On config-era installs (`docs/addw.env` present) that's just a wholesale skills replacement — see `UPGRADING.md`, which also lists the structural docs-contract steps per version boundary. On older (v2) installs this skill extracts your project-specific content (test commands, checklist sections, technical considerations, version file paths), writes `docs/addw.env`, relocates the rest into your living docs (ARCHITECTURE.md, TESTING.md), and creates the charter/ADR structure. Copy the new skills to `new-addw/`, run the skill, done. The skill exists for the v2 boundary only; once no v2 installs remain, `UPGRADING.md` is the upgrade path.

### `/codex-ask`

A grounded second opinion on **anything** — architecture calls, debugging hypotheses, research conclusions. Codex answers from inside the repo (read-only), threaded per topic for multi-round discussion. Advisory only: no verdict tags, nothing gated. addw-research uses it to red-team decision-grade findings before presenting them.

### `/addw-hotfix`

Streamlined workflow for production emergencies. Bypasses the full cycle for genuine crises (or lazy debugging).

### `/addw-research`

Exploratory investigation with defined compute level. For feasibility studies and technology evaluation. Produces documented findings, not production code.

### `/addw-compact`

Run this skill to compact ARCHITECTURE.md size while preserving relevance, accuracy, and coverage through summarization and restructuring. Token calculator script included.
As a rule of thumb, ARCHITECTURE.md should not exceed ~10% of context window.

## Multi-Agent: Using Different LLMs at Different Steps

![ADDW Workflow multiLLM](assets/trip-workflow-multiLLM4.png)

Just like you wouldn't smell your own fart, an LLM is unlikely to catch bugs in its own implementation. Some people conduct adversarial review with a different session but still the same model, which is..._meh_. The best approach is to introduce a different model in the same reasoning ballpark as the first one, that will most likely catch what the other missed.

As of v2.0.0, this multi-agent approach is **the default workflow**.  
Considering Claude as your main and Codex as the copilot:  
Fable writes the plan, 5.6 Sol reviews it, Luna implements, back to Fable who reviews and fixes the diff, runs the testing gate, then a new Sol thread reviews again the code. All in one claude code session. Writer and reviewer are never the same thread.  
As of mid july 2026, this Fable + GPT5.6 harness combo is absolute peak.

### Swapping agents

The process skills don't hard-code Codex — they call **roles**, resolved from `docs/addw.env`: `ADDW_PLAN_REVIEW_SKILL`, `ADDW_IMPLEMENT_SKILL`, `ADDW_CODE_REVIEW_SKILL`, and `ADDW_ASK_SKILL` (defaulting to the four `codex-*` skills). To plug in a different agent CLI, write one adapter skill per role you want to replace and point the role key at it. The adapter contract is small:

- `scripts/start.sh <target> [instructions…]` — start a fresh session for the target; prompts and state are the adapter's own business.
- `scripts/resume.sh [--notes "…"] <target> [instructions…]` — continue the same session with context retained (exit code 2 when no session exists).
- Review roles end their output with a trailing verdict tag (`APPROVED` / `REQUEST_CHANGES` / `NEEDS_REWORK`); the implement role ends with `IMPLEMENTATION_COMPLETE` / `IMPLEMENTATION_PARTIAL`.
- Reviews run read-only; implementation may write to the working tree but never commits.

## MCP Servers: Less Is More

Last piece of advise before your new coding quest: Every MCP server you add is extra context, extra latency, and extra confusion. Keep it minimal. The one use case where MCP genuinely shines is **up-to-date documentation**, so your agent stops hallucinating deprecated APIs/whatever. Two servers cover it: [Context7](https://github.com/upstash/context7) for current library & framework docs, and [Exa](https://github.com/exa-labs/exa-mcp-server) for web search when the answer isn't in any doc. No bloat beyond that.

## Contributing

PRs & forks are welcome

Happy shipping ! 🚀

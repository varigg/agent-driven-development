# Prior art: architecture docs for coding agents

Research for [#205](https://github.com/varigg/agent-driven-development/issues/205)
(parent map #203). Question: what does prior art say about keeping a
structural/architecture overview for coding agents versus letting the agent
explore the code each session, and what does it recommend documenting instead?
Facts only; the decision belongs to #203/#206. Gathered 2026-10-04.

## Bottom line

Every source consulted converges on the same split. **Derivable, as-built
description** (file-by-file layout, "what's in this directory", stack listings)
is either explicitly discouraged or measured as unhelpful. **Non-derivable,
normative content** (commands the agent can't guess, project-specific
conventions, architectural *decisions*, gotchas, invariants) is recommended
everywhere and is the content agents measurably follow. The one counter-current
is that a *short, accurate map* of where subsystems live can help agents
localize — but the evidence for that comes from tuned, failure-derived
guidance, not from a maintained narrative overview, and staleness is named as
the primary failure mode wherever large docs are kept.

## 1. Anthropic: Claude Code memory and best-practices docs

**Best practices** ([code.claude.com/docs/en/best-practices](https://code.claude.com/docs/en/best-practices),
"Write an effective CLAUDE.md") gives an explicit include/exclude table:

| Include | Exclude |
| --- | --- |
| Bash commands Claude can't guess | **Anything Claude can figure out by reading code** |
| Code style rules that differ from defaults | Standard language conventions Claude already knows |
| Testing instructions and preferred test runners | Detailed API documentation (link to docs instead) |
| Repository etiquette (branch naming, PR conventions) | **Information that changes frequently** |
| **Architectural decisions specific to your project** | Long explanations or tutorials |
| Developer environment quirks (required env vars) | **File-by-file descriptions of the codebase** |
| Common gotchas or non-obvious behaviors | Self-evident practices like "write clean code" |

Stated reasons: "This gives Claude persistent context it can't infer from code
alone." "For each line, ask: *'Would removing this cause Claude to make
mistakes?'* If not, cut it. Bloated CLAUDE.md files cause Claude to ignore your
actual instructions!" It also notes `/doctor` "proposes cuts for content it can
derive from the codebase."

**Memory page** ([code.claude.com/docs/en/memory](https://code.claude.com/docs/en/memory))
is slightly softer: it lists "project layout" among facts to keep and "Project
architecture" as a use for project CLAUDE.md, but adds a size target ("under
200 lines per CLAUDE.md file. Longer files consume more context and reduce
adherence") and a consistency rule ("if two instructions contradict each other,
Claude may pick one arbitrarily … remove outdated or conflicting
instructions"). It describes auto memory as holding "project context Claude
can't derive from the code". Instructions are "context, not enforced
configuration" — to block an action deterministically, use a hook.

**Context engineering** ([anthropic.com/engineering/effective-context-engineering-for-ai-agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents))
gives the architectural rationale: "CLAUDE.md files are naively dropped into
context up front, while primitives like glob and grep allow it to navigate its
environment and retrieve files just-in-time, effectively bypassing the issues
of stale indexing." The stated trade-off: "runtime exploration is slower than
retrieving pre-computed data."

Takeaway: Anthropic recommends against the as-built half (file-by-file
descriptions, frequently-changing info) and for the normative half
(architectural decisions, gotchas, conventions). "Architecture" in its usage
means decisions, not a structural tour.

## 2. AGENTS.md convention

**agents.md** ([agents.md](https://agents.md/)) frames the file as "a README for
agents" holding "the extra, sometimes detailed context coding agents need" that
the README doesn't. It lists "Project overview" among popular sections
alongside build/test commands, code style, testing, security, PR guidelines —
but gives no guidance on overview depth. Claims use by "over 60k open-source
projects."

**OpenAI Codex docs** ([learn.chatgpt.com/docs/agent-configuration/agents-md](https://learn.chatgpt.com/docs/agent-configuration/agents-md))
suggest working agreements, repository expectations, review rules, and
service-specific overrides; files are concatenated up to `project_doc_max_bytes`
(32 KiB default). No architecture-overview guidance.

**OpenAI "Harness engineering"** ([openai.com/index/harness-engineering](https://openai.com/index/harness-engineering/);
the page returned 403 to the fetcher, quotes verified via a verbatim mirror at
[celesteanders/harness](https://github.com/celesteanders/harness/blob/main/docs/research/260211_openai_harness_engineering_codex.md))
reports trying and abandoning "one big AGENTS.md": "A giant instruction file
crowds out the task, the code, and the relevant docs"; "Too much guidance
becomes non-guidance"; "It rots instantly. A monolithic manual turns into a
graveyard of stale rules"; "It's hard to verify. A single blob doesn't lend
itself to mechanical checks." Their replacement: a ~100-line AGENTS.md "map",
a `docs/` directory "treated as the system of record" where "Architecture
documentation provides a top-level map of domains and package layering", a
recurring "doc-gardening" agent that "scans for stale or obsolete
documentation that does not reflect the real code behavior", and architecture
rules enforced by "custom linters and structural tests" whose error messages
"inject remediation instructions into agent context." Note: OpenAI *does* keep
a domain/layering map — but short, and backed by mechanical enforcement and an
automated staleness sweep.

**How real projects use it** — Chatlatanagulchai et al., *Agent READMEs*
([arXiv:2511.12884](https://arxiv.org/abs/2511.12884)), 2,303 context files from
1,925 repos: content is dominated by testing (75.9%), implementation details
(70.8%), architecture (68.1%), development process (65.1%), build/run (63.0%);
security (14.8%) and performance (14.5%) are rare. Files are actively
maintained (67.0% of Claude Code files modified in multiple commits, median
~1 day between edits) and grow by addition: median deletions under 15 words
per commit vs. a median 57 words added for Claude Code files. So in practice
most projects *do* write architecture sections, and those sections accrete.

## 3. deslop-rules AGENTS.md (local)

`/home/varigg/code/deslop-rules/AGENTS.md` (public at
[minitru/deslop-rules](https://github.com/minitru/deslop-rules); adapted from
Tomas Vykruta's Sep 2026 AGENTS.md rules — the original thread was not
located) is 70 lines with **no as-built description at all**: no overview, no
stack, no tree. It contains only:

- **Design principles** — separation of concerns, one-rule-one-module, DRY as
  "one home", fail closed, etc.
- **Hard invariants** — including "One owning module per domain" with a
  domain → owner file table that is filled in only "when you confirm an
  owner".
- **How to work** — measure first, refactor then change, verbatim moves, and
  "**Gates, not promises.** A rule that matters is enforced by a test, a lint,
  a scan or a hook, not by a sentence in this file."

Its opening line states the stance: "Constraints, not a checklist." The only
structural content is the domain→owner table, which is normative (it names
*the* owner and forbids a second one) rather than descriptive.

## 4. TRIP (ADDW's ancestor)

[PiLastDigit/TRIP-workflow](https://github.com/PiLastDigit/TRIP-workflow)
calls `docs/ARCHI.md` "the **central nervous system** of this workflow" and
"the AI agent's **long-term memory** of your codebase." Stated rationale:
avoid re-deriving architecture each session ("glob, grep, and read multiple
files"), avoid guessing ("_There's probably a utils folder_"), and give "the
full picture in one read" while staying "concise enough to not waste tokens."

`skills/TRIP-init/SKILL.md` Phase 4 generates universal sections: How to Read,
Overview, Technology Stack, Project Structure ("Directory tree with
explanations"), Core Architecture Principles, Build System & Toolchain,
Configuration — plus project-type sections (UI, IPC, memory map, game loop…),
and requires user approval. `skills/TRIP-3-release/SKILL.md` Step 7 updates it
every release against `docs/ARCHI-rules.md`, then token-counts it and warns
past ~20,000 tokens, pointing at a dedicated `TRIP-compact` skill.

So TRIP is the one source that argues *for* the as-built half, on token-cost
grounds. It presents no measurement; and the fact that it needs a token
budget, a compaction skill, and a per-release update step is itself the
maintenance cost the other sources warn about. ADDW inherited all three
(`addw-compact`, the ~10%-of-context rule of thumb, update-in-same-PR).

## 5. Evidence: stale docs vs. re-exploration

- **Gloaguen et al., ETH Zurich** ([arXiv:2602.11988](https://arxiv.org/abs/2602.11988)) —
  the most direct test. SWE-bench Lite plus a new benchmark of repos with
  developer-committed context files; Claude Code/Sonnet-4.5, Codex/GPT-5.2 and
  5.1-mini, Qwen Code. LLM-generated context files: slightly *lower* success
  (−0.5% / −2%, not significant) at **+20–23% cost** and +2.5–3.9 steps.
  Developer-written files: +2.4% (not significant vs. no file). On overviews
  specifically: "Context files do not provide effective overviews" — they did
  not meaningfully reduce steps before the agent first touched a relevant
  file. On instructions: "Instructions in context files are well followed"
  (e.g. `uv` usage jumps when mentioned). Recommendation: human-written files
  "should only include instructions required for coding agents that are not
  already present in the README."
- **Lulla et al.** ([arXiv:2601.20404](https://arxiv.org/abs/2601.20404), ICSE
  JAWs 2026) — 10 repos, 124 PRs: a curated AGENTS.md associated with 28.6%
  lower median runtime and 16.6% fewer output tokens, comparable completion.
  Measures efficiency, not correctness; does not isolate which content helped.
- **Shepard & Albrecht, probe-and-refine** ([arXiv:2606.20512](https://arxiv.org/abs/2606.20512)) —
  reconciles the two: "how the guidance is produced is the decisive variable."
  Guidance tuned against synthetic failures (≤3000 chars, covering "which files
  house which subsystems, how to run the test suite, which workflows have
  historically led to wrong fixes") lifted SWE-bench Verified resolve rate to
  33.0% vs. 28.3% for a static generated knowledge base and 25.5% unguided.
  The gain was **localization** — reaching the right file — not patch quality
  (per-patch precision flat at ~59%). Guidance tuned for one model
  destabilized another. This is the best evidence *for* a compact
  "where things live" map — but a small, failure-derived one.
- **Codified Context** ([arXiv:2602.20478](https://arxiv.org/abs/2602.20478)) —
  single-developer case study, 108k-line C# system, 26k lines of agent context
  (24% of code size). Names staleness "the primary failure mode": "On at least
  two occasions, outdated context documents caused agents to generate code that
  conflicted with recent refactors." Built a session-start drift detector over
  recent commits. Anecdotal, but first-hand.
- **Gao & Chen, agent documentation behaviour** ([arXiv:2608.20195](https://arxiv.org/abs/2608.20195)) —
  557 real agent sessions + 33k agentic PRs. 60.5% of agents' documentation
  interactions target agent-facing files (instruction files 35.4%, working
  notes 25.1%); classical technical docs 10.6%, API refs 1.3%. Documentation
  "trails code rather than leading it": code is touched first 4.7× more often
  than docs in multi-commit PRs that change both — i.e. docs are updated after
  the fact, which is the mechanism by which they go stale.

## What the sources recommend documenting instead

Consistently across Anthropic, ETH, OpenAI and deslop-rules:

- commands and environment facts the agent can't guess;
- project-specific conventions and architectural *decisions* (the "why");
- gotchas, non-obvious behaviours, historically-wrong fixes;
- invariants and ownership (e.g. domain → owner), ideally backed by a
  mechanical gate rather than prose;
- at most a short map/pointer layer, kept accurate by automation (OpenAI's
  doc-gardening, Codified Context's drift detector) or derived from observed
  failures (probe-and-refine).

## Caveats

- Benchmarks are mostly Python bug-fix tasks (SWE-bench family); feature work
  in large or unusual codebases is less covered. Codified Context is the only
  large-codebase source and is a single-author case study.
- No source measures a *maintained, human-reviewed* as-built ARCHITECTURE.md
  of the TRIP/ADDW kind head-to-head against no doc.
- The Gao & Chen and probe-and-refine figures were read from the PDFs
  directly; an automated summarizer gave materially wrong paraphrases of both,
  so quote from the papers, not from secondary summaries.

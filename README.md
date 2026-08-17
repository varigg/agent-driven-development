# Agent-Driven Development

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE) ![Works with](https://img.shields.io/badge/Works_with-grey) [![Claude Code](https://img.shields.io/badge/Claude_Code-E5582B)](https://docs.anthropic.com/en/docs/claude-code) [![Codex CLI](https://img.shields.io/badge/Codex_CLI-10A37F)](https://developers.openai.com/codex/cli/)

**ADDW** — the **a**gent-**d**riven **d**evelopment **w**orkflow — is a shipping discipline for AI coding agents, built as an overlay on [Matt Pocock's skills](https://github.com/mattpocock/skills). His skills handle the front of the flow: alignment, specification, and decomposition into tickets. ADDW adds what gets a change safely onto `main`: cross-model review loops, a deterministic testing gate, a pull request per ticket with human review, and a fully mechanical release.

End to end: **spec → tickets → per-ticket PR → release** — with a second model reviewing every spec and every diff before you see it, and small scripts (not agent judgment) verifying everything that can be verified mechanically.

> [docs/cycle-walkthrough.md](docs/cycle-walkthrough.md) walks through one full cycle step by step — start there if you want the guided tour rather than the summary below.

## Origins & inspirations

- ADDW began as a fork of [TRIP](https://github.com/PiLastDigit/TRIP-workflow), the deliberately minimal three-step workflow this repo grew out of. The plan → implement → release core, the living `ARCHITECTURE.md`, and the init interview all trace back there.
- [mattpocock/skills](https://github.com/mattpocock/skills) supplies the overlay's foundation: `grill-with-docs` for alignment, `to-spec` for specification, `to-tickets` for decomposition into tracer-bullet GitHub issues with blocking edges, and `tdd` / `code-review` for implementation discipline. ADDW builds on these rather than competing with them.
- [ShopDevX/adeptlydev](https://github.com/ShopDevX/adeptlydev) inspired the determinism posture: wherever a check can be a small verifiable script instead of an agent's judgment, it is one.

## What ADDW adds

**The adversary.** Cross-model review loops with real convergence semantics. A fresh Codex thread reviews the spec (`codex-spec-review`) before ticketing and the code (`codex-code-review`) before each PR opens, ending every round with a verdict tag: `REQUEST_CHANGES → fix → resume → APPROVED`. The writing model and the reviewing model are never the same — a model is unlikely to catch the flaws in its own reasoning, and a fresh thread of the same model is only marginally better.

**The gate.** Contract tests are written and frozen before implementation starts, and a deterministic gate (`skills/lib/gate/gate.sh`) runs the project's lint, typecheck, and test recipes from `docs/addw.env`, emitting exactly one summary line — the line every PR body carries. Choosing which tests are affected stays a judgment call; running them and reporting the result is mechanical.

**The ship discipline.** Every commit on `main` is a reviewed, squash-merged PR whose title parses as a conventional commit. The version bump and changelog are derived from those commit subjects and published identically as a GitHub Release — no agent-authored release prose to drift from history. Living docs are updated in the same PR as the change that touches them, so docs are reviewed alongside code.

## The flow

1. **Align & specify** — `grill-with-docs` interviews you toward a shared understanding; `to-spec` publishes the result as a spec issue on GitHub.
2. **Spec review** — `codex-spec-review` runs its review loop over the spec issue; fixes land in the issue body, and only the final verdict is posted as a comment.
3. **Ticket** — `to-tickets` decomposes the spec into tracer-bullet issues with blocking edges. The *frontier* — tickets whose blockers are all merged — is queryable at any time; work on a ticket starts only after its blockers have merged.
4. **Implement, one ticket per session** — `addw-implement` wraps the loop: frozen contract tests → implementation (delegated to `codex-implement`, or driven inline with `tdd`) → deterministic gate → `codex-code-review` convergence → open the PR and stop. You review and merge on GitHub.
5. **Release** — when a spec's last ticket merges (or on demand), `addw-release` opens a release PR carrying the derived version bump and the mechanical changelog. Your merge is the confirmation; the tag and GitHub Release follow automatically.

Around the cycle sit `addw-maintain` (periodic audit), `addw-hotfix` (emergencies), `codex-ask` (second opinions), and `addw-compact` (doc size control) — see the reference below.

## The living docs

`ARCHITECTURE.md` is the agent's long-term memory of your codebase: an always-current, as-built snapshot read at the start of each task, so the agent doesn't re-derive your structure from scratch every session — or worse, guess it. It is flanked by `docs/charter.md`, which holds the stable intent (purpose, scope, non-goals) that outlasts any feature, and a set of dated ADRs that are write-once from the moment they merge — `active` until superseded, including guardrail ADRs that record what you deliberately do *not* build so no future change reintroduces it.

## One config file, zero skill edits

Skills are byte-identical in every project — pure process, never edited per install. Everything project-specific lives in `docs/addw.env` (main branch, agent role keys, testing-gate recipes, the ADR directory) and in the living docs the skills point at. Upgrading ADDW means replacing your `.claude/skills/` contents wholesale with this repo's `skills/`; `UPGRADING.md` lists any structural steps for the schema boundary you're crossing.

## Getting started

You'll need Claude Code, Codex CLI (for the default review/implement roles), an authenticated `gh`, and a GitHub repo with issues enabled — the overlay's tracker is GitHub, by design. Skills use the `SKILL.md` format ([Agent Skills](https://agentskills.io/home)).

1. Install [Matt Pocock's skills](https://github.com/mattpocock/skills) and run his setup skill (it configures the tracker, labels, and domain layout).
2. Copy this repo's `skills/` contents into your project's `.claude/skills/`.
3. Run `/addw-init` — it verifies the setup (GitHub tracker, authenticated `gh`, the `ready-for-agent` label), interviews you for the charter, generates `ARCHITECTURE.md`, `TESTING.md`, and `docs/addw.env`, declares the shipped ADR template authoritative, and finishes with a doctor check of the whole install.
4. Bring a feature: `grill-with-docs` → `to-spec` → `/codex-spec-review` → `to-tickets` → `/addw-implement` per ticket → merge PRs → `/addw-release`.

## Skills reference

| Skill | What it does |
| --- | --- |
| `/addw-init` | Bootstraps a project: verifies Matt's setup ran and configured GitHub, generates the living docs and the config, declares the shipped ADR template authoritative, gates on doctor. |
| `/codex-spec-review` | Cross-model review loop over a spec issue, before ticketing. |
| `/addw-implement` | The per-ticket wrapper: contract tests → implement → gate → review loop → PR. Bare invocation lists the frontier. |
| `/addw-release` | Mechanical release: derived version, generated changelog, release PR, tag + GitHub Release. Refuses a spec whose tickets are not all closed as completed. |
| `/addw-maintain` | Periodic audit with three skippable sweeps: living-docs drift, coverage-debt triage, dependencies. Substantive findings become tracker issues; the audit itself ships as a PR. |
| `/addw-hotfix` | Emergencies only: a gate-verified fix as an expedited PR merged immediately. Even an emergency rides a PR a human merges — no direct-push path to main. |
| `/addw-compact` | Shrinks `ARCHITECTURE.md` through summarization and restructuring when it outgrows its token budget (rule of thumb: ~10% of the context window). |
| `/codex-implement` | Implementation delegated to Codex CLI in a workspace-write sandbox, with a persistent thread per target for resumable context. |
| `/codex-code-review` | The code-review loop adapter: reviews a ticket's whole branch diff against the ticket and its spec — read-only sandbox, checklist-driven, multi-round with verdict tags. |
| `/codex-ask` | A grounded second opinion on anything — architecture calls, debugging hypotheses. Advisory only: no verdicts, nothing gated. |
| `skills/lib/` | Not a skill: the shared script layer — the tracker seam (every `gh` tracker call routes through it), the deterministic gate, the release derivations, and the Codex runner every `codex-*` adapter sits on. |

Retired: planning and research moved to Matt's skills (`grill-with-docs` + `to-spec` for planning; `research` + `wayfinder` for research), and the standalone test skill's role now lives in the deterministic gate and `tdd`. In-repo plan documents and the backlog file went with them — work state lives on the tracker, where not-yet-graduated proposals are `backlog`-labeled issues the frontier skips. [`UPGRADING.md`](UPGRADING.md) has the full list and the migration steps.

## Swapping agents

The process skills don't hard-code Codex — they call **roles**, resolved from `docs/addw.env` (`ADDW_IMPLEMENT_SKILL`, `ADDW_CODE_REVIEW_SKILL`). To plug in a different agent CLI, write one adapter skill per role and point the key at it. The contract is small:

- `scripts/start.sh <target> [instructions…]` — start a fresh session for the target; prompts and state are the adapter's own business.
- `scripts/resume.sh [--notes "…"] <target> [instructions…]` — continue the same session with context retained (exit code 2 when no session exists).
- Review roles end their output with a trailing verdict tag (`APPROVED` / `REQUEST_CHANGES` / `NEEDS_REWORK`); the implement role ends with `IMPLEMENTATION_COMPLETE` / `IMPLEMENTATION_PARTIAL`.
- Reviews run read-only; implementation may write to the working tree but never commits.

**Caveat**: this contract currently has exactly one implementation and inherits Codex CLI's semantics (resumable threads, exit codes, sandbox modes). Expect it to be revised the first time a real second adapter is written.

## Contributing

PRs, forks, and issues are welcome.

Happy shipping! 🚀

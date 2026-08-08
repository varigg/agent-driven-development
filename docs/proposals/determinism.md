# Determinism sweep — replacing agent judgment with scripts

**Status**: partly implemented (2026-08-07) — the deterministic testing gate and
the release tail shipped during the overlay rewrite; the candidates still unbuilt
are tracked in
[issue #31](https://github.com/varigg/agent-driven-development/issues/31).
The tables below record the sweep as it stood on 2026-07-30; some script paths
they name have since moved or been superseded.
**Date**: 2026-07-30
**Origin**: review of [ShopDevX/adeptlydev](https://github.com/ShopDevX/adeptlydev),
whose plan checker (`lib/plans.ts` `detectDeclaredChanges`) validates declared
file changes mechanically. That prompted a full sweep of the ADDW skills for
steps where agent judgment does work a script could do reliably.

## The qualification test

A step qualifies for a script when all three hold:

1. **Fully specified** by config (`docs/addw.env`) plus files on disk — no
   project knowledge or taste required.
2. **The agent failure mode is real** — arithmetic, date comparison,
   cross-file consistency, multi-step command sequences, or anything the
   harness structurally prevents (see prepend-changelog).
3. **Project-agnostic** — the script ships inside a skill folder and works in
   every install unchanged, preserving "skills are never edited".

Scripts inside skill folders are established precedent (`codex-*` adapters,
`addw-compact/count-tokens.sh`); none of this bends the config-file design.

## Implemented (2026-07-30)

| Script | Home | Replaces |
| --- | --- | --- |
| `check-plan-files.sh` | `addw-1-plan/scripts/` | Eyeballing the plan's Files to Modify/Create section against the tree. `(new)` must not exist, `(modify)`/`(delete)` must. Run after plan writing and again by addw-2 before the first delegation (first only — later phases create the `(new)` files). Adopted from adeptlydev. |
| `audit-nudge.sh` | `addw-3-release/scripts/` | Counting v* tags newer than the newest `docs/7-maintenance/` report and comparing to `$ADDW_AUDIT_NUDGE_N` — date arithmetic agents fumble. Assumes release tags sit on fresh commits (lightweight tags carry the commit's date). |
| `prepend-changelog.sh` | `addw-3-release/scripts/` | The unenforceable "prepend without reading the file" instruction. The Edit tool *requires* reading before modifying, so the changelog's write-only contract was structurally violated on every release; piping the entry through a script is the only honest implementation. Also used by addw-hotfix. |
| `check-version-sync.sh` | `addw-3-release/scripts/` | Attention-based consistency of the version across `$ADDW_VERSION_FILE`, the CHANGELOG heading, and the tag namespace (README is WARN-only — not every project's README carries a version). Runs at the top of the release Commit step. |
| `doctor.sh` | `addw-init/scripts/` | The eyeballed Post-Initialization Checklist. Verifies env keys, docs-contract dirs/files, TESTING.md sections, branch and version-file existence, adapter overrides — and carries `EXPECTED_SCHEMA`, making the skills side of the `ADDW_SCHEMA` generation marker checkable. Final gate of init and step 3 of UPGRADING.md. |

## Deferred (backlogged, build when an audit shows the need)

- **ADR scaffolder** — next free NNNN, template copy, date stamp, and the
  superseded-pointer flip. Real but rare failure mode; sequence numbers and
  dates are classic agent slips.
- **Release tail sequence** — tag → ff-merge → branch delete → push as one
  script with the ff-failure → rebase branch. Four verbatim commands rarely
  fail today.
- **Compact validation** — internal-link and mermaid-fence checker for
  `addw-compact` Step 4 ("links resolve, diagrams parse" is checkable).
- **Coverage-debt liveness** — flag `COVERAGE-DEBT.md` ledger paths that no
  longer exist, turning half of maintain Sweep B's triage into input.
- **`git add -A` deny rule** — the thrice-repeated prose rule is enforceable
  for free as a project permission deny rule; harness config, not a script.

## Flagged, not recommended yet: deterministic testing gate

The addw-2 testing gate is the highest-stakes judgment point: the agent picks
commands out of TESTING.md prose, runs them, interprets output, and assembles
the `$GATE_SUMMARY` line that downstream review consumes. Making Verification
Recipes machine-readable (e.g. `docs/4-unit-tests/recipes.env` with
`ADDW_RECIPE_LINT`, `ADDW_RECIPE_TYPECHECK`, `ADDW_RECIPE_TESTS_AFFECTED`)
would let a `gate.sh` run the ladder and emit the summary deterministically —
affected-test *selection* stays judgment; execution and reporting stop being
judgment.

Costs: a docs-contract change (schema bump + UPGRADING section), a second
source of truth beside TESTING.md prose (drift risk — exactly what the
maintain skill hunts), and env-var recipes can't express conditional or
multi-step verification. Mitigation sketch: TESTING.md's Verification Recipes
section becomes prose rationale plus a pointer, `recipes.env` becomes the
single executable source, doctor.sh checks its keys. Decision: worth doing,
but ride the next schema boundary (alongside the addw-4-maintain rename)
rather than spending one on it alone.

**Why not pre-commit hooks instead** (raised 2026-07-30): the gate's runs are
not attached to commits — it fires before the review loop starts and before
every round resume, while checkpoint commits happen *before* tests are even
authored. A hook therefore fires only at premature, redundant, or mis-scoped
moments (staged-file scoping can't see the plan's Test Impact), and no hook
sits on the path that matters: `$GATE_SUMMARY` is consumed downstream as the
reviewer's premise, so the problem is trustworthy *reporting*, not commit
policing. Hooks also cross ADDW's no-project-infrastructure line. Fast
lint/format hooks remain worthwhile defense-in-depth for commits made outside
the workflow — the project's call, not ADDW's; at most, init may detect an
existing hook setup and note it in TESTING.md.

# Changelog

## v0.2.0 — 2026-08-18

### Features
- feat(addw-release): add a project-supplied lockfile-sync recipe (#132)
- feat(addw-compact): promote token budgets to ADDW_* config keys (#130)
- feat(tracker): detect approved specs and tickets edited after approval (#124)
- feat(tracker): add edit-title, let create take its title from a file (#123)
- feat(addw-implement): scope Step 6 — discovered work files as backlog (#117)
- feat(codex-spec-review): file retirement tickets as backlog per ADR 0007 (#116)
- feat(addw-maintain): backlog retirement filings per ADR 0007, drop the sweep-selection ask (#115)
- feat(addw-hotfix): file a deferred-scrutiny follow-up ticket on every expedited merge (#114)
- feat(addw-hotfix): remove the direct-push escape hatch (#113)
- feat(addw-maintain): size-check ARCHITECTURE.md and file a compact ticket (#112)
- feat(addw-compact): end compaction on a branch with a PR, drop the approval asks (#111)
- feat: move the maintenance-audit record into the audit commit's message (#97)
- feat: judge ticket breadth at pickup, route bundles to rescoping (#93)

### Fixes
- fix(addw-release): file retirement tickets as backlog per ADR 0007 (#129)
- fix(addw-init): retire ADDW_ASK_SKILL role key (schema 6) (#127)
- fix: ADDW_VERSION_FILE may be empty, as addw-release already assumes (#75)

### Other
- docs(addw-maintain): describe backlog in the glossary's terms (#131)
- process: trim retired-directory history from addw-init's docs-contract note (#128)
- chore: maintenance audit 2026-08-13 (#121)
- docs(addw-implement): state that test code gets no pre-Boundary approval (#118)
- docs: record the two-posture retirement rule as ADR 0007 (#99)
- docs: record same-day schema bumps as ADR 0008 (#109)
- docs: commit the agent-skills layout config (#95)
- docs: record the one-Deliverable decomposition rule as ADR 0006 (#92)
- docs: record the autonomy rubric as ADR 0005, seed CONTEXT.md (#90)
- chore: drop the 6-memo doctor case, a migration artifact in a permanent suite (#81)
- docs: retire docs/6-memo/, orphaned when addw-research was deleted (#79)

## v0.1.0 — 2026-08-10

### Features
- feat: three detectors file stale-document tickets under one contract (#69)
- feat: archive-doc.sh retires a document to the tracker (#64)
- feat: filter archives and refuse truncated snapshots at the tracker seam (#63)
- feat: relocate the ADR template into the shipped skills tree (#60)
- feat: derive the next ADR number from the configured directory (#54)
- feat(TRIP-upgrade): relocate extracted content into living docs; v3 structural migration
- feat(TRIP-init): emit process + pointers only; generate charter, ADR template, verification recipes
- feat(TRIP-4-maintain): new audit-and-triage skill
- feat(verification): replace command placeholders with TESTING.md verification-recipe pointers
- feat(TRIP-review): pointerize design-convention checks to ARCHI.md and guardrail ADRs
- feat(TRIP-3-release): design reconciliation, vocab sweep, audit nudge, pure-process tutorial
- feat(TRIP-1-plan): process-only technical considerations, ADR step, collapse layer guidance
- feat: harden workflow from agent-guidelines review
- feat: codex-ask skill — grounded second opinions from Codex on any matter, TRIP-research cross-check step
- feat: TRIP v2.0.0 — plan→implement→release flow, codex-implement delegation, testing gate + hard-to-cover policy, TRIP-review/TRIP-test support skills, per-flow Codex model defaults

### Fixes
- fix: sourcing docs/addw.env under set -e no longer kills every codex adapter (#59)
- fix: resolve the ADR directory from configuration in both consumers (#55)

### Other
- chore: migrate this repo's proposals to the tracker archive (#70)
- docs: make Doc Impact the one step that archives a retired document (#65)
- docs: de-duplicate the lib contract between script headers and README (#62)
- docs: scope ADR write-once to the merge boundary (#61)
- docs: stage ADRs 0003 and 0004 (#52)
- docs: retire the mid-rewrite status claims (#35)
- process: schema migration and docs reconciliation (#32)
- process: retire replaced skills and relocate the shared codex runner (#26)
- process: slim addw-init and extend doctor (#25)
- process: rewrite addw-release (modes, release PR, mechanical tail) (#24)
- docs: add CLAUDE.md for working on this repo (#23)
- process: rewrite addw-implement as the per-ticket PR wrapper (#22)
- docs(tracker): record that the in-progress annotation reads remote heads (#21)
- process: bring codex-spec-review up to the spec contracts (#20)
- process: add changelog generator and version-bump derivation (#19)
- docs: rewrite README around the pocock-overlay workflow (#18)
- process: slim addw-maintain and adapt addw-hotfix to the PR model (#17)
- docs: add a guided tour of one ADDW cycle
- process: add deterministic testing gate (recipe keys + gate runner) (#16)
- process: add tracker layer with frontier and completion queries (#15)
- process: add test runner and tracker parsers (#14)
- docs: add pocock-overlay proposal (design complete)
- process: add codex-spec-review (tracker-first retarget of codex-plan-review)
- process: give the docs-drift sweep the failures it kept missing
- process: bind the durable-never-cites-transient rule to ADR authoring
- process: measure ARCHITECTURE accretion instead of restating the rule
- process: deterministic scripts for release checks, changelog, and install health
- process: adopt declared-files check and approval assumptions (adeptlydev review)
- docs: backlog the addw-4-maintain → addw-maintain rename
- process: retire addw-upgrade — the last v2 install is migrated
- docs: remove TRIP-era artwork and the parent repo's demo video link
- docs: ADDW_SCHEMA becomes the install's generation marker
- docs: drop the living-spec proposal
- docs: mark the adapter contract provisional; add a backlog
- docs: UPGRADING.md becomes the durable upgrade path
- process: release record moves to a write-only root CHANGELOG.md
- docs: propose a living behavioral spec (docs/spec.md)
- process: agent roles resolve via addw.env instead of hard-coding Codex
- process: release history goes git-native (annotated tags replace the changelog)
- process: rename TRIP -> ADDW, ARCHI.md -> ARCHITECTURE.md
- process: land the v3 config-era restructure; decouple from parent repo
- docs(README): reflect the draft ADR status in the lifecycle summary
- process: finish absorbing the TRIP-1/TRIP-3 charter/ADR restructure
- chore: self-ignoring state dirs for the codex-ask and codex-implement skills
- process: TRIP-4's docs-drift sweep gains structure and claim checks
- process: the doc sweep enumerates docs/ instead of a remembered list
- process: add a draft ADR status for design-session decisions
- docs(README): reflect charter/ADR/maintain additions

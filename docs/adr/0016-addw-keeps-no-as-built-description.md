# ADR 0016: ADDW keeps no as-built description; rules are read from project-declared sources

- **Status**: active
- **Date**: 2026-10-06
- **Origin**: wayfinder map varigg/agent-driven-development#203

`addw-init` generated `docs/ARCHITECTURE.md` for every install. It was meant to be the
agent's long-term memory: an as-built snapshot (overview, stack, structure, build, config,
data flow) read at the start of each task, plus core principles and per-layer conventions.
The two halves age differently. An agent can re-derive the as-built half from the code in
any session, and keeping it in sync was the doc's whole upkeep cost: `addw-compact`, a token
threshold, `ARCHITECTURE-rules.md`, and maintain's size sweep all existed to manage that
half's growth. Of the ten skills that read the doc, six read it only for orientation.
Published guidance on agent context files agrees that overview-style content does not help
and that conventions, decisions and known pitfalls do. The normative half is different,
because code shows what *is*, not what is *required*. The decision is that ADDW keeps no
structural description of an install's code. Sessions explore. The normative half is read
from **rule sources** the project declares in `ADDW_CONVENTIONS`, a list of files in
`docs/addw.env`, because most projects already keep rules in `CLAUDE.md` / `AGENTS.md` and
ADDW should read them there rather than own a second copy. `docs/CONVENTIONS.md` is the
fallback home ADDW writes only when the project has no rule source at all.

## Alternatives Considered

- **Keep `ARCHITECTURE.md` and tighten its upkeep.** Rejected. The upkeep cost comes from
  ADDW owning a description of the code, and no rule set removes that cost.
- **A short ADDW-owned orientation pointer** (entry points, owning modules). Rejected
  because it brings back the upkeep in a smaller size. The only form with evidence behind it
  is a short, *failure-derived* note, and an install can add one to its own `CLAUDE.md` /
  `AGENTS.md` without any ADDW machinery.
- **On-demand regeneration** of an uncommitted snapshot. Rejected. It is exploration done
  eagerly, at a moment when nothing has asked for it.
- **Make `docs/CONVENTIONS.md` the normative home for every install.** Rejected because it
  duplicates rules most projects already keep elsewhere, and Codex-side readers would still
  never see `CLAUDE.md`. Reading the declared list closes that gap.
- **ADRs or the charter as the normative home.** Rejected. Those record decisions and
  intent, not standing rules a reviewer can cite against a diff.

## Consequences

- **The admission test** decides what may enter a file ADDW writes as a rule source: an
  entry belongs only if a reviewer could cite a diff as violating it. A description of what
  the code is, including "layer X lives in directory Y", stays out. The test lives in
  `addw-init`'s fallback generation as policy shared by every install, not as a per-install
  rules file.
- **`ADDW_CONVENTIONS` semantics** follow the recipe keys' absent/empty rule. If the key is
  absent, doctor FAILs and readers refuse. An explicit `ADDW_CONVENTIONS=` means the project
  deliberately has no rules: readers skip the conventions check and review says so. If a
  listed file is missing, doctor FAILs. The key lists files only, single-quoted and
  space-separated, and normative readers read each listed file whole.
- **ADDW never edits a project's own context files.** Duplicates or conflicts across listed
  files are the human's to resolve. The same goes for a domain → owner table: a project that
  wants one keeps it in a file it lists.
- **Retired:** `docs/ARCHITECTURE.md` as a generated doc, `docs/ARCHITECTURE-rules.md`, the
  `addw-compact` skill and its `ADDW_COMPACT_*` keys, and hotfix's change-type scoping table.
  `check-doc-accretion.sh` survives as a generic tool with no default target.
- **Doctor gains a WARN level**, which prints but leaves the exit code alone. Its first use
  is a `docs/ARCHITECTURE.md` that exists but is not listed. That may be stranded rules from
  a half-finished migration or a deliberate project-owned doc, so it is worth a nudge but not
  a failure.
- Existing installs migrate at schema 12 → 13. The itemized change list is the spec that
  cites this ADR.

## Gate

No skill generates, reads, or asks an agent to maintain a structural description of an
install's code: overview, stack, directory layout, build, or data flow. A skill that needs
the project's rules reads the files `ADDW_CONVENTIONS` lists, whole, and never reaches past
the list to a hardcoded rules path. Anything ADDW itself writes into a rule source passes
the admission test.

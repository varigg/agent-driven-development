---
name: codex-implement
description: Delegate implementation of a ticket (or a scoped part of it) to Codex CLI
argument-hint: "<target> [instructions] | reset <target> | show <target>"
---

# Codex Implement

Non-interactive implementation via Codex CLI in a **workspace-write** sandbox: Codex works from the instruction block it is handed, edits the working tree directly, runs the project's lint/build on its own work, and reports back. One persistent thread per target, so a large ticket can be delegated in scoped parts with full context retained.

State persisted under `.claude/skills/codex-implement/state/<sanitized-target>.{thread,review.txt,events.ndjson}` (the `.review.txt` file holds Codex's implementation **report** — the naming comes from the shared helpers). This skill's `scripts/start.sh` and `scripts/resume.sh` are the adapter entry points; for `reset`/`show` (shared scripts in `.claude/skills/lib/codex/`, no adapter wrapper) export first:

```bash
export STATE_DIR=".claude/skills/codex-implement/state"
```

## Arguments

- `<target>` — auto: start if no thread, resume if one exists. Usually the ticket's issue number, so the thread keys per ticket; any free-form label works for unticketed work.
- Optional trailing instructions — **this is where the scope lives.** Codex cannot read the tracker, so the caller states what to build in its own words, e.g. `"Implement only the parser; leave the CLI wiring to a later ticket"`.
- `reset <target>` — drop state, next call starts fresh.
- `show <target>` — display the latest report without calling Codex.

## Execution

1. **Parse `$ARGUMENTS`**: extract action (`reset`/`show`/auto) and target.

2. **Auto** — try `start.sh` first (exit code 2 = thread exists → use `resume.sh`):
   - **Start**: `bash .claude/skills/codex-implement/scripts/start.sh <target> [instructions]`
   - **Resume** (next phase / additional scope): `bash .claude/skills/codex-implement/scripts/resume.sh <target> [instructions]`

3. **Reset**: `bash .claude/skills/lib/codex/reset.sh <target>`

4. **Show**: `bash .claude/skills/lib/codex/show.sh <target>`

5. **Parse trailing tag** of the report:
   - `IMPLEMENTATION_COMPLETE` — hand control back to the requester's own read of the diff.
   - `IMPLEMENTATION_PARTIAL` — read the report; resume with instructions for the remainder, or let the requester finish small leftovers directly.

## Notes

- `--sandbox workspace-write` on start; `codex exec resume` inherits it. Codex edits files and runs repo commands (lint/build); no network, no commits.
- **Fixes are the requester's job.** After Codex reports, the requester (`addw-implement`, reading the diff) fixes problems directly in the tree — do NOT ping-pong fixes back to Codex. Resume only for genuinely new scope (a large remainder).
- Separate `STATE_DIR` from the review skills — the same target can hold an implementation thread and a review thread without collision.
- Codex is instructed not to write tests (testing gate owns that) and not to touch release ceremony.
- Network is blocked in the sandbox: if the work requires installing a new dependency, Codex will report it as a leftover — install it yourself while reading the diff.
- **Never point Codex at a file it must edit while that file is executing.** Rewriting a running script mid-flight corrupts it — bash reads scripts incrementally — and the failure looks like a syntax error at an unrelated line.
- Model/effort defaults live in `.claude/skills/lib/codex/_common.sh`, keyed off `STATE_DIR` (this skill's key selects the implementation-class model). Override per run with `CODEX_MODEL` / `CODEX_EFFORT`.

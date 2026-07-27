---
name: codex-code-review
description: Iterative Codex CLI code review against an implementation plan
argument-hint: "<plan-path> [extra context] | reset <plan-path> | show <plan-path>"
---

# Codex Code Review

Iterative code review via Codex CLI on uncommitted changes. Codex reads the plan and runs `git status -s` / `git diff HEAD` to inspect the change set. Criteria come from `checklist.md` in this skill's directory — the single source of truth for review sections, severity, and the approval gate.

Review output stays in `state/<key>.review.txt`; no separate review artifact is produced. What survives the loop is the Review line of the release's CHANGELOG.md entry: rounds, verdict, and any overrides or accepted open findings.

State persisted under `.claude/skills/codex-code-review/state/<sanitized-target>.{thread,review.txt,events.ndjson}`. This skill's `scripts/start.sh` and `scripts/resume.sh` are thin adapters over the shared `codex-plan-review` runner; for `reset`/`show` (shared scripts, no adapter wrapper) export first:

```bash
export STATE_DIR=".claude/skills/codex-code-review/state"
```

## Arguments

- `<target>` — auto: start if no thread, resume if exists. Usually a plan path (`docs/1-plans/F_*.plan.md`) or a free-form label for unplanned work.
- `reset <target>` — drop state, next call starts fresh.
- `show <target>` — display latest review without calling Codex.

## Execution

1. **Parse `$ARGUMENTS`**: extract action (`reset`/`show`/auto) and target.

2. **Auto** — try `start.sh` first (exit code 2 = thread exists -> use `resume.sh`):
   - **Start**: `bash .claude/skills/codex-code-review/scripts/start.sh <target> [extra]`
   - **Resume**: `bash .claude/skills/codex-code-review/scripts/resume.sh <target> [extra]`

3. **Reset**: `bash .claude/skills/codex-plan-review/scripts/reset.sh <target>`

4. **Show**: `bash .claude/skills/codex-plan-review/scripts/show.sh <target>`

5. **Parse trailing tag**:
   - `APPROVED` — propose post-convergence steps.
   - `REQUEST_CHANGES` — surface review verbatim, engage critically (read actual code at `file:line`, fix legitimate ones, push back on incorrect ones), then resume.
   - `NEEDS_REWORK` — surface to user before mass-editing.

6. **Resume** after addressing findings for incremental re-review.

## Diff Visibility

Codex uses `git status -s` / `git diff HEAD` in read-only sandbox. If those fail, pass diff inline: `DIFF="$(git diff --stat HEAD; echo '---'; git diff HEAD)"` as extra context.

## After Convergence

Note the round count, verdict, and any overrides or accepted open findings — `addw-3-release` records them in the changelog entry. Then continue with `addw-3-release`.

## Notes

- Model/effort defaults live in `codex-plan-review/scripts/_common.sh`, keyed off `STATE_DIR`. Override per run with `CODEX_MODEL` / `CODEX_EFFORT`.
- `--sandbox read-only`. Safe to invoke autonomously.
- Thread IDs persisted per-target (no `--last`). Concurrent reviews don't collide.
- Separate `STATE_DIR` from `codex-plan-review` — same key is fine.
- Extra context -> `{{EXTRA_PROMPT}}`. Keep short.

## Loop Shape

```
turn 1: start.sh -> REQUEST_CHANGES (Critical: A, Major: B C)
         address A B C
turn 2: resume.sh -> REQUEST_CHANGES (A B addressed, Minor: C partial, Suggestion: D)
         address C, optionally D
turn 3: resume.sh -> APPROVED -> continue with addw-3-release
```

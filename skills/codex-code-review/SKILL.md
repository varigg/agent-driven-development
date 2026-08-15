---
name: codex-code-review
description: Iterative Codex CLI code review of a ticket's branch, against the ticket and its spec
argument-hint: "<issue-number> [extra context] | reset <issue-number> | show <issue-number>"
---

# Codex Code Review

Iterative cross-model review of the branch implementing a tracker ticket, via Codex CLI. The
reviewed change is the **full merge-base-to-working-tree diff** — everything the pull request
will deliver, not the last commit — judged against the ticket's acceptance criteria and the
decisions in its parent spec. It runs after the `addw-implement` testing gate is green and
before the PR opens. Criteria come from `checklist.md` in this skill's directory — the single
source of truth for review sections, severity, and the approval gate.

State (thread ID, review text, event log) persists under
`.claude/skills/codex-code-review/state/`, keyed on the issue number. The scripts wrap the
shared runner in `.claude/skills/lib/codex/` with this skill's prompts and state — the same
pattern as `codex-spec-review`. The per-issue file `state/issue-<N>.context.md` holds the
ticket body, the parent spec's, and the project's configured ADR directory, and is the
target handed to the runner.

That buffer exists because the reviewer runs in a read-only sandbox with **no network**: it
cannot fetch the ticket itself, and a diff without the intent behind it is unreviewable for
conformance. The buffer is read-only context — never an edit vehicle — so it is rebuilt from
the tracker on every start and resume rather than guarded against divergence.

Every tracker operation — the ticket read, the parent lookup, the spec read — goes through the
tracker layer at `.claude/skills/lib/tracker/tracker.sh`. Never call the tracker CLI for
tracker work here.

No review artifact is produced. What survives the loop is the PR body's verdict line — the
tag, the round count, the commit SHA the verdict covers, and the ticket-body hash it was
judged against — plus the `Approved-body:` marker comment `addw-implement` posts on the
ticket at the final round, which is what `tracker.sh approval-drift <n>` checks (ADR 0009).

## Arguments

- `<issue-number>` — auto: start if no thread, resume if one exists. Trailing free text is
  extra context for the reviewer, normally the gate summary line.
- `reset <issue-number>` — drop state, next call starts fresh.
- `show <issue-number>` — display the latest review without calling Codex.

## Execution

1. **Parse `$ARGUMENTS`**: extract action (`reset`/`show`/auto) and issue number.

2. **Auto** — try `start.sh` first (exit code 2 = thread exists -> use `resume.sh`):
   - **Start**: `bash .claude/skills/codex-code-review/scripts/start.sh <issue-number> "$GATE_SUMMARY"`
   - **Resume**: `bash .claude/skills/codex-code-review/scripts/resume.sh --notes "…" <issue-number> "$GATE_SUMMARY"`

3. **Reset**: `bash .claude/skills/lib/codex/reset.sh <buffer-path>`

4. **Show**: `bash .claude/skills/lib/codex/show.sh <buffer-path>`

   `reset`/`show` are shared scripts with no adapter wrapper, so they take the buffer path
   (`.claude/skills/codex-code-review/state/issue-<N>.context.md`) and need `STATE_DIR`
   exported first:

   ```bash
   export STATE_DIR=".claude/skills/codex-code-review/state"
   ```

5. **Parse trailing tag**:
   - `APPROVED` — record the verdict, round count, the commit it covers, and the
     ticket-body hash captured before the round; continue with the PR, which posts that
     hash as the ticket's `Approved-body:` marker (`addw-implement` § Step 10).
   - `REQUEST_CHANGES` — surface the review verbatim, engage critically (read the actual code
     at `file:line`, fix the legitimate findings, push back on the incorrect ones in the next
     resume's `--notes`), then resume.
   - `NEEDS_REWORK` — surface to the user before mass-editing.

6. **Resume** after addressing findings, having re-run the gate and committed the round's
   fixes, for incremental re-review.

## After Convergence

The final round must run against a **fully committed HEAD** — commit everything before the
round you expect to be the last. Record `git rev-parse HEAD` and
`tracker.sh body-hash <n>` at that moment: the SHA is the diff the verdict covers, the hash
is the ticket it was judged against, and `addw-implement` writes both into the PR body and
posts the hash as the ticket's `Approved-body:` marker. A change made after the verdict
either earns another round or is disclosed in the PR body as uncovered.

## Notes

- Model/effort defaults live in the shared `_common.sh`, keyed off `STATE_DIR` (reviews run
  the review model). Override per run with `CODEX_MODEL` / `CODEX_EFFORT`.
- `--sandbox read-only`. Safe to invoke autonomously.
- On network failure, check `*.events.ndjson.stderr`. Run `reset.sh` and retry.
- Thread IDs persist per issue; concurrent reviews of different tickets don't collide.
- Extra context -> `{{EXTRA_PROMPT}}`. Keep short — the gate summary line is the usual payload.
- A ticket with no parent spec reviews fine; the buffer says so and the reviewer falls back to
  the ticket's own acceptance criteria.
- The guardrail-ADR checklist item names no directory. `ADDW_ADR_DIR` supplies it through the
  buffer; a project that declares no such key gets a stated absence there, never a guessed path.

## Loop Shape

```
turn 1: start.sh 10 "$GATE_SUMMARY" -> REQUEST_CHANGES (Critical: A, Major: B C)
         fix A B, push back on C
turn 2: re-run gate, commit, resume.sh --notes "Fixed A B. Pushed back on C because …" 10
        -> REQUEST_CHANGES (Minor: D)
         fix D, commit everything
turn 3: resume.sh --notes "…" 10 -> APPROVED
         record `git rev-parse HEAD` as the covered commit -> open the PR
```

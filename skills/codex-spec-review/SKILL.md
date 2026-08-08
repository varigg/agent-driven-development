---
name: codex-spec-review
description: Iterative Codex CLI review of a spec issue on the project tracker
argument-hint: "<issue-number> [extra context] | reset <issue-number> | show <issue-number>"
---

# Codex Spec Review

Iterative review of a feature spec published as a GitHub issue, via Codex CLI. The reviewed
artifact lives on the tracker rather than in the repo, which is why the buffer below exists
at all. It runs after `/to-spec` publishes the spec and before `/to-tickets` decomposes it.

State (thread ID, review text, event log) persists under
`.claude/skills/codex-spec-review/state/`, keyed on the issue number. The scripts wrap the
shared runner in `.claude/skills/lib/codex/` with this skill's prompts and state — the same
pattern as `codex-code-review`. The per-issue file `state/issue-<N>.md` mirrors the issue
body and doubles as the **edit buffer**: fixes are made there and pushed back with
`tracker.sh edit-body`.

Every tracker operation — issue reads, body edits, the `spec` label, the verdict comment —
goes through the tracker layer at `.claude/skills/lib/tracker/tracker.sh`. Never call `gh`
for tracker work here.

## Arguments

- `<issue-number>` — auto: start if no thread, resume if one exists. Trailing free text is
  extra context for the reviewer.
- `reset <issue-number>` — drop state, next call starts fresh.
- `show <issue-number>` — display the latest review without calling Codex.

## Execution

1. **Parse `$ARGUMENTS`**: extract action (`reset`/`show`/auto) and issue number.

2. **Auto** — try `start.sh` first (exit code 2 = thread exists -> use `resume.sh`).
   Starting labels the issue `spec` before anything else — reviewing an issue is what
   makes it one, and the frontier and completion queries key on that label:
   - **Start**: `bash .claude/skills/codex-spec-review/scripts/start.sh <issue-number> [extra]`
   - **Resume**: `bash .claude/skills/codex-spec-review/scripts/resume.sh --notes "..." <issue-number> [extra]`

3. **Reset**: `bash .claude/skills/codex-spec-review/scripts/reset.sh <issue-number>`

4. **Show**: `bash .claude/skills/codex-spec-review/scripts/show.sh <issue-number>`

5. **Parse trailing tag**:
   - `APPROVED` — post the verdict comment (below), tell the user, done.
   - `REQUEST_CHANGES` — engage critically: fix legitimate findings by editing
     `state/issue-<N>.md` and pushing with
     `bash .claude/skills/lib/tracker/tracker.sh edit-body <N> .claude/skills/codex-spec-review/state/issue-<N>.md`;
     push back on incorrect ones in the `--notes` of the next resume. Surface the review
     verbatim.
   - `NEEDS_REWORK` — surface to the user before mass-editing.

6. **Verdict comment** — when the loop converges (or is capped), post **only the final
   verdict** to the issue; round-by-round findings and implementer notes stay in adapter
   state so the issue remains readable:

   ```bash
   S=.claude/skills/codex-spec-review/state
   printf 'Codex spec review: APPROVED after <R> round(s).\n' > "$S/issue-<N>.verdict.md"
   bash .claude/skills/lib/tracker/tracker.sh comment <N> "$S/issue-<N>.verdict.md"
   ```

## Notes

- **Unpushed-edit guard**: start/resume re-sync the buffer from GitHub and **refuse (exit 3)**
  if it differs from the remote body — that means unpushed local edits (push them first) or
  an out-of-band edit on GitHub (pass `--refresh` to accept the remote as truth). Trailing
  newlines are not a difference, so pushing the buffer and resuming immediately is always
  clean. Never bypass the guard by deleting the buffer.
- Model/effort defaults live in the shared `_common.sh`, keyed off `STATE_DIR` (reviews run
  the review model). Override per run with `CODEX_MODEL` / `CODEX_EFFORT`.
- `--sandbox read-only`. Safe to invoke autonomously.
- On network failure, check `*.events.ndjson.stderr`. Run `reset.sh` and retry.
- Thread IDs persist per issue; concurrent reviews of different specs don't collide.
- Extra context -> `{{EXTRA_PROMPT}}`. Keep short.

## Loop Shape

```
turn 1: start.sh 42 (labels #42 spec) -> REQUEST_CHANGES (A B C)
         edit state/issue-42.md, tracker.sh edit-body 42 state/issue-42.md
turn 2: resume.sh --notes "Fixed A B. Pushed back on C because …" 42
        -> REQUEST_CHANGES (C stale, new D)
         edit + push
turn 3: resume.sh --notes "…" 42 -> APPROVED
         tracker.sh comment 42 state/issue-42.verdict.md
```

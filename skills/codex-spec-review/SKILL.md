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

Every tracker operation — issue reads, body edits, the `spec` label, the verdict comment,
the retirement tickets of Step 7 — goes through the tracker layer at
`.claude/skills/lib/tracker/tracker.sh`. Never call `gh` for tracker work here.

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
   - `APPROVED` — post the verdict comment (below), file any retirement the spec earned
     (Step 7), tell the user, done.
   - `REQUEST_CHANGES` — engage critically: fix legitimate findings by editing
     `state/issue-<N>.md` and pushing with
     `bash .claude/skills/lib/tracker/tracker.sh edit-body <N> .claude/skills/codex-spec-review/state/issue-<N>.md`;
     push back on incorrect ones in the `--notes` of the next resume. Surface the review
     verbatim.
   - `NEEDS_REWORK` — surface to the user before mass-editing.

6. **Verdict comment** — when the loop converges (or is capped), post **only the final
   verdict** to the issue; round-by-round findings and implementer notes stay in adapter
   state so the issue remains readable. Hash the state buffer — the reviewed bytes — with
   `parse.sh`, not the remote body. The empty-hash guard is not optional: a failed
   substitution would otherwise post an empty marker, which reads as never-recorded and
   silently disables the drift check.

   ```bash
   S=.claude/skills/codex-spec-review/state
   hash="$(bash .claude/skills/lib/tracker/parse.sh body-hash "$S/issue-<N>.md")"
   [ -n "$hash" ] || exit 1
   printf 'Codex spec review: APPROVED after <R> round(s).\nApproved-body: %s\n' \
     "$hash" > "$S/issue-<N>.verdict.md"
   bash .claude/skills/lib/tracker/tracker.sh comment <N> "$S/issue-<N>.verdict.md"
   ```

   Consumers compare this against the live body via `tracker.sh approval-drift` to detect
   a spec edited after its approval.

7. **Retirement filing** — an approved spec supersedes what it replaces. For each
   in-tree document the spec has left untrue *in whole* — a proposal it replaces, an ADR
   whose decision it overturns — file one ticket. Filing is all this step does: no branch,
   no commit, no PR, no gate, and never a deletion or an edit of the document itself.

   The ticket body carries the path, the kind (`adr` or `proposal`), why the document
   stopped being true, and the command that retires it —

   ```
   bash .claude/skills/lib/docs/archive-doc.sh <path> <adr|proposal> "<reason>"
   ```

   — so whoever picks the ticket rediscovers none of it. Write it into adapter state and
   file:

   ```bash
   S=.claude/skills/codex-spec-review/state
   bash .claude/skills/lib/tracker/tracker.sh create \
     "docs: retire <path>" "$S/issue-<N>.retire-<k>.md" backlog
   ```

   `backlog` per ADR 0007: this is a detached detection — approving a spec endorses its
   design, not the side-detection that some old document is stale — and nothing in the
   spec path merges, so no PR exists whose body could name the filing. Graduation is an
   explicit human label flip; report "filed as backlog" on the way out. **No `## Parent`** — the ticket belongs to no spec, so it gates no spec's
   completion and no release. Another detector may later file the same document; the
   duplicate costs one close, which is cheaper than a tracker query to prevent it.

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
         tracker.sh create "docs: retire …" … backlog   (one per superseded doc)
```

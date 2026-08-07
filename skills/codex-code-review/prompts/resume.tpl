The branch implementing the ticket in `{{TARGET}}` has been updated since your previous review.
Re-derive the same whole-branch view from turn 1 — merge base to working tree, not just the last
commit — and produce an incremental review:

  BASE="$(. docs/addw.env 2>/dev/null; echo "${ADDW_MAIN_BRANCH:-main}")"
  MERGE_BASE="$(git merge-base "origin/$BASE" HEAD 2>/dev/null || git merge-base "$BASE" HEAD)"
  git diff --stat "$MERGE_BASE"
  git diff "$MERGE_BASE"
  git log --oneline "$MERGE_BASE"..HEAD

Re-read `{{TARGET}}` if the ticket matters to a finding — it is rebuilt from the tracker on every
resume, so an edited ticket reads as it now stands.

  1. Confirm whether each of your prior findings is now addressed. Quote the prior finding
     briefly, then state addressed / not addressed / partially addressed with the `file:line`
     references that resolved (or didn't).
  2. Flag any **new** issues introduced by the edits — re-checking against every section of
     `.claude/skills/codex-code-review/checklist.md` (the same single-source checklist used in
     turn 1).

## Implementer notes

The implementer has provided context on what changed and why. Findings that
are explicitly marked as intentional decisions, environment limitations, or
with a doc-update to-do should NOT be re-flagged.

{{IMPLEMENTER_NOTES}}

Apply the same severity tags and the same approval gate from `checklist.md` as the initial review — it is the only file you need for the criteria.

End with the same tag on its own line:

  APPROVED
  REQUEST_CHANGES
  NEEDS_REWORK

{{EXTRA_PROMPT}}

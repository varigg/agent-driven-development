---
name: addw-implement
description: Implement one tracker ticket end to end, from contract tests to an open PR
argument-hint: "<issue-number> — omit to list the frontier"
---

# Implement Mode

You are implementing **one ticket** — a single GitHub issue — and you stop when its pull
request is open. The human reviews and merges it; nothing here touches the main branch.

Every tracker operation goes through the tracker layer at
`.claude/skills/lib/tracker/tracker.sh`. Never call the tracker CLI directly for issue reads,
labels, comments, assignment, or closure. Pull-request operations are not tracker operations
and use `gh pr` directly.

---

## Bare Invocation — the Frontier

Invoked with no issue number, list what can be started and stop:

```bash
bash .claude/skills/lib/tracker/tracker.sh frontier
```

The four sections are fixed. **frontier** is what is workable now — tickets annotated
`[in progress: …]` already have a branch or an assignee, so pick an unannotated one unless
you are resuming your own work. **needs-rescoping** and **unknown-blockers** are for the
human, not for you: report them and do not start those tickets. **release-ready-specs** means
a spec's tickets are all closed as completed — surface it so the human can invoke
`addw-release`.

---

## Step 1: Mode Detection

**Before anything else**, check whether the ticket already has an open PR:

```bash
gh pr list --state open --search "<issue-number>" --json number,headRefName,url
```

Confirm the match is real (the PR closes this ticket) rather than a coincidental number.

- **Open PR exists** → **Mode A: Review-Comments Resume**.
- **No open PR** → **Mode B: Fresh Build**.

Getting this backwards restarts finished work, so resolve it before reading anything else.

---

## Mode A: Review-Comments Resume

The human has reviewed and left feedback. Same skill, not a separate procedure.

1. **Check out the PR's branch** and read **all** the feedback. Two reads, not one — the
   conversation timeline and the comments anchored to diff lines are different endpoints, and
   inline comments are where most review feedback actually lands:

   ```bash
   gh pr view <n> --comments                                  # timeline + review summaries
   gh api "repos/{owner}/{repo}/pulls/<n>/comments" --paginate \
       --jq '.[] | "\(.path):\(.line // .original_line)\t\(.user.login): \(.body)"'
   ```

   No `gh pr` subcommand exposes inline comments (cli/cli#5788), so the API read is not
   optional. Skipping it produces the worst failure this mode has: reporting feedback
   addressed while never having seen it.

   Also run `bash .claude/skills/lib/tracker/tracker.sh approval-drift <issue-number>` —
   the final review round posted the ticket's approval marker, so drift from the body the
   verdict judged is one command. Surface drift before addressing anything: the feedback
   may be responding to a ticket the verdict never saw.

2. **Address the feedback.** Push back in a PR reply where a comment is mistaken — agreement
   is not the goal, resolution is. Commit with explicit paths and a conventional subject.

3. **Re-run the gate** (Step 9) and **refresh the PR body's gate summary** — a stale summary
   is worse than none, because it reads as current evidence.

4. **Re-enter the codex loop by judgment.** Substantive changes — new logic, changed control
   flow, a different approach — earn another round. Comment-only or rename-only changes do
   not. If you skip the loop, the PR body must say which commit the recorded verdict covers,
   so the gap between the verdict and HEAD is visible rather than implied.

5. **Push, then update the PR body**, and stop. Do not merge. Push before touching the body:
   a body advertising a gate summary and a verdict SHA for commits that exist only on your
   machine is evidence for a PR the reviewer cannot see.

---

## Mode B: Fresh Build

### Step 2: Eligibility — read-only

Nothing is written until the ticket is confirmed workable:

```bash
bash .claude/skills/lib/tracker/tracker.sh view <issue-number>
```

The ticket must be **open**, labeled **`ready-for-agent`**, and labeled neither `spec` nor
`backlog` — a spec is decomposed by `to-tickets`, not implemented. Every issue in its
`## Blocked by` section must be **closed as completed**: a blocker closed as *not planned*
never unlocks it, and the ticket needs human re-scoping instead. Its `## Parent` section is
read when present but never required — standalone tickets are workable.

Those checks are mechanical; one judgment call remains. **A ticket carries exactly one
Deliverable** — an independently-checkable unit of work, one a reviewer can verify passed or
failed without reference to the ticket's other criteria. Read the acceptance criteria and
judge their breadth: criteria that can pass or fail independently of one another mark a
bundle of Deliverables. A bundled ticket is **not started** — report it for rescoping, the
same human-facing disposition the frontier's **needs-rescoping** section gets (that section
itself stays mechanical and will never list the bundle; the report is yours). Decomposition
should have split it, so this is a backstop, not a routine gate; but breadth is not
mechanically computable, so no script runs the check for you.

Stop and report if any of that fails. Derive the branch slug from the ticket title: a few
lowercase, hyphenated words, no issue number in the slug itself.

### Step 3: Branch and Self-Assign

The branch and the assignment are the **in-progress marker** the frontier listing shows —
not a lock. Push before building, so a second session sees the work exists.

```bash
. .claude/skills/lib/config/config.sh && config_source ADDW_MAIN_BRANCH
git checkout "$ADDW_MAIN_BRANCH" && git pull
git checkout -b <type>/<issue-number>-<slug>       # feat/ fix/ docs/ — the type the work will carry
git push -u origin <type>/<issue-number>-<slug>
bash .claude/skills/lib/tracker/tracker.sh assign <issue-number>
```

If the branch already exists on the remote, **surface that to the human before proceeding** —
somebody, possibly you in an earlier session, has already started.

### Step 4: Read the Ticket and Its Spec

Read the ticket body in full, then the parent spec when the ticket names one
(`tracker.sh body <parent>`) — the spec carries the decisions the ticket assumes. After
reading the parent spec, run
`bash .claude/skills/lib/tracker/tracker.sh approval-drift <parent>`. If it reports drift,
surface it to the human before building — the tickets may descend from content the spec
reviewer never saw. `no approval hash recorded` needs no action; it identifies a pre-feature
approval. Then read `docs/ARCHITECTURE.md`, and the glossary and ADRs at the locations the
domain-layout contract (`docs/agents/domain.md`) declares. Never hardcode those paths.

### Step 5: Frozen Contract Tests

If the ticket touches the critical-path floor — auth, deletion, persistence, cost, or
external request shape — write those tests **now**, before any implementation:

1. Author behavioral tests from the ticket's acceptance criteria, following the project's
   testing guide.
2. Confirm they fail for the right reason.
3. Commit them with explicit paths: `test: add contract tests for <ticket>`.

They are **off-limits to the implementer** — say so in its instructions. If an interface
mismatch surfaces later, you fix the test yourself and say why in the PR body. Work outside
the critical-path floor skips this step; its tests are authored in Step 9. Freezing is an
agent discipline against implementer drift, not a human gate: test code receives **no
pre-Boundary approval** — PR review is where tests are judged, like every other part of the
diff (ADR 0005).

### Step 6: Implementation

The implementing agent is the **role key** `ADDW_IMPLEMENT_SKILL` in `docs/addw.env`:

- The reserved value **`inline`** means no adapter — you drive the `tdd` skill yourself in
  this session. Never invoke Matt's `implement` skill; `tdd` is the programmatic primitive.
  If no `tdd` is installed, drive the discipline directly — failing test first, then the code
  that passes it. The skill encodes the loop; it does not own it.
- **Any other value** names an adapter skill, invoked through the adapter contract. The issue
  number is the target, so the thread keys per ticket; the **instruction block carries the
  scope**, because the adapter cannot read the tracker:

  ```bash
  . .claude/skills/lib/config/config.sh && config_source ADDW_IMPLEMENT_SKILL
  bash ".claude/skills/${ADDW_IMPLEMENT_SKILL:-codex-implement}/scripts/start.sh" \
      <issue-number> "<what to build, from the ticket and the spec's decisions>. \
  Make the tests in <paths> pass. Do NOT modify any test file."
  ```

  You have read the ticket and its spec; the adapter has not. State the scope in your own
  words — what to build, what to leave to a later ticket, which conventions bind — rather than
  pasting the ticket wholesale. The instruction block must also name any ADR `Gate` bearing on
  the ticket's work: the adapter cannot read the tracker and is never told to read the ADR
  directory, so a constraint reaches it only if you carry it. Parse the
  trailing tag: `IMPLEMENTATION_COMPLETE` → proceed.
  `IMPLEMENTATION_PARTIAL` → read the report, then `resume.sh` for the remainder or finish
  small leftovers yourself.

Either way, **read the full diff yourself** afterwards against the ticket, ARCHITECTURE.md
patterns, and project conventions. What happens to a problem depends on whether the ticket
covers it:

- **In scope** — a finding against the ticket's own Deliverable: fix it in-branch yourself,
  never ping-pong fixes back to the adapter.
- **Discovered work** — work outside the ticket's acceptance criteria, however small it
  feels mid-flight: it does not ride the PR. File it and move on:

  ```bash
  bash .claude/skills/lib/tracker/tracker.sh create "<conventional subject>" <body-file> backlog
  ```

  `backlog` because frontier entry is a spending decision that stays human (ADR 0005
  gate 3) and the PR ships one Deliverable (ADR 0006). Deliberately no merge-graduation
  via the PR body naming the filing: a mid-implementation discovery has no prior
  authorizing act, unlike the hotfix follow-up — graduation is an explicit human label
  flip.
- **Mechanical drive-bys** — formatting on a line the diff already touches — are not
  "work"; just do them.

Commit with explicit paths (never `git add -A`, never "wip") and a conventional subject.

### Step 7: Cold Pre-Filter Review

Run a cold `code-review` over the branch diff before spending codex rounds. It breaks
ownership bias: you are reviewing your own work, and a cold read catches what a warm one
cannot. Matt's is the one this step was written around, but nothing turns on whose prompt
runs — any competent two-axis review earns the same thing, and a plain instruction to review
the diff against the ticket is a fair substitute where no skill is installed. Name in the PR
body which one ran, since more than one plugin publishes a `code-review` and "the pre-filter
ran" should not imply a skill that did not.

**Skippable by judgment** for a genuinely trivial diff — two nets remain (the codex loop and
human review). A skip is not free: it is **disclosed in the PR body**, with the reason.

### Step 8: Doc Impact

If this ticket changed documented design, update the affected living-doc passages **now** —
ARCHITECTURE.md, the charter, an ADR — so the reviewed diff carries them and the docs are
reviewed alongside the code that changed them. A new decision gets an ADR from the project's
template, with the ticket or PR as its Origin; use `.claude/skills/lib/docs/next-adr-number.sh`
to get its number.

**A document this ticket made untrue leaves the tree here.** This is the only step in the
workflow that archives one — everywhere else a stale document is noticed, it is filed as a
ticket that arrives back here:

```bash
bash .claude/skills/lib/docs/archive-doc.sh <path> <adr|proposal> "<why it stopped being true>"
```

The test is **"is this still true?"** — never "is this about the past?" A document may narrate
history and remain entirely true: rejected alternatives, incident notes, and an ADR's own
reasoning are the highest-value content in a tree precisely because the code cannot supply
them. What leaves is a document making present-tense claims about a tree that has moved on.
Before running the command, confirm two things — that the document's durable content survives
elsewhere, in the spec issue, an ADR, or the superseding document, and that no living doc still
points at the file. Re-aim the pointers first; a deletion that strands one has moved the defect
rather than fixed it. The script refuses on a surviving reference, but the judgment is yours,
and it prints no document content, which is why it exists at all. It leaves the deletion
staged — commit it with the rest of the ticket's changes.

**An ADR that supersedes another archives the superseded one in the same PR**, since this is
where both documents are in hand and nowhere later are they. The departing ADR is not edited on
its way out: a merged ADR is never edited, and the reason you pass the script — which names the
superseding ADR — is what records the supersession. Then **sweep the vocabulary the superseded
decision introduced** out of the living docs, in this same PR, and list the swept terms in the
PR body so a reviewer can tell a thorough sweep from a cursory one. That list lives in the PR
body and nowhere else: it is needed once, while you hold both documents, and an in-tree list of
retired terms would serve a transient purpose forever.

If nothing documented changed, say so; the PR body carries the note either way.

### Step 9: Testing Gate

Author any missing tests for new logic first, then run the gate with the affected test paths —
selecting them is your judgment, running and reporting them is mechanical:

```bash
bash .claude/skills/lib/gate/gate.sh <affected test paths>
```

Keep its single summary line **verbatim**; the PR body carries it and the review loop is
handed it as context. The gate must be green before cross-model review starts — a red gate
wastes codex rounds on findings the ladder already found.

Coverage discipline: test observable behavior, never internal wiring. If mock setup outgrows
the test's assertions, record the gap in the coverage-debt ledger rather than fighting it —
but the critical-path floor keeps at least one behavioral test regardless. Never hide
untested code behind ignore comments or lowered gates.

### Step 10: Codex Code Review Loop

The reviewing agent is the role key `ADDW_CODE_REVIEW_SKILL`. It reviews the **full
merge-base-to-working-tree diff** — everything the PR will deliver, not the last commit — with
the ticket and parent spec as context, which the adapter fetches for itself.

```bash
. .claude/skills/lib/config/config.sh && config_source ADDW_CODE_REVIEW_SKILL
bash ".claude/skills/${ADDW_CODE_REVIEW_SKILL:-codex-code-review}/scripts/start.sh" \
    <issue-number> "$GATE_SUMMARY"
```

1. **Parse the trailing tag**: `APPROVED` → converged. `REQUEST_CHANGES` → continue.
   `NEEDS_REWORK` → surface to the human before mass-editing.
2. **Address findings** — quote each with `file:line`, read the actual code, fix the
   legitimate ones, push back on the incorrect ones. Critical and Major block approval;
   Minor and Suggestion are case-by-case.
3. **Re-run the gate**, commit the round's fixes, and resume with implementer notes so the
   reviewer stops re-flagging what you settled:

   ```bash
   bash ".claude/skills/${ADDW_CODE_REVIEW_SKILL:-codex-code-review}/scripts/resume.sh" \
       --notes "Fixed X. Pushed back on Y because Z." <issue-number> "$GATE_SUMMARY"
   ```

4. **Cap at 5 rounds** unless the human says otherwise; surface whatever remains open.

**The final round must run against a fully committed HEAD.** Commit everything before the
round you expect to be the last, and record `git rev-parse HEAD` plus
`hash="$(bash .claude/skills/lib/tracker/tracker.sh body-hash <issue-number>)"` at that
moment — before invoking the round, when the ticket the reviewer is handed is the ticket
the hash pins. The verdict SHA pins the diff, the body hash pins the ticket it was judged
against, and the PR body states both. After the verdict, post that **recorded** hash as the
ticket's approval marker — never recompute it here, which would hash bytes the reviewer may
never have seen — so anyone, the merging human included, can re-check the ticket with one
command (`tracker.sh approval-drift <issue-number>`) for as long as the PR sits unmerged.
The empty-hash guard is what keeps a failed capture from posting an empty marker, which
would read as never-recorded and silently disable the check:

```bash
[ -n "$hash" ] || exit 1     # the hash recorded before the final round
f="$(mktemp)"
printf 'Codex code review: <TAG> after <R> round(s).\nApproved-body: %s\n' "$hash" > "$f"
bash .claude/skills/lib/tracker/tracker.sh comment <issue-number> "$f"
```

Any change made after that verdict either earns another round or is disclosed as
uncovered.

### Step 11: Open the PR

Push the branch and open the PR against `$ADDW_MAIN_BRANCH`:

```bash
. .claude/skills/lib/config/config.sh && config_source ADDW_MAIN_BRANCH
git push
gh pr create --base "$ADDW_MAIN_BRANCH" --title "<conventional subject>" --body-file <file>
```

The **title must parse as a conventional-commit subject** — it becomes the squash subject on
main, and the mechanical changelog projects exactly those subjects. A title the changelog
cannot classify is a defect at the source.

Then **stop**. You do not merge, and you do not start another ticket — one ticket per
session. Report the PR URL and what the human is being asked to judge.

---

## PR Body Contract

Every ticket PR body carries all seven, in this order. A missing element is a review the
human has to do by archaeology:

1. **Closure link** — `Closes #<issue-number>`, so the merge closes the ticket as completed.
2. **Gate summary** — the gate's line, verbatim.
3. **Codex verdict** — the tag, the round count, the commit SHA it covers, and the ticket-body
   hash the verdict covers.
4. **Disclosures** — a skipped pre-filter, a skipped review round, an edited contract test,
   an accepted open finding. If there are none, say none.
5. **Doc-impact note** — which living docs this changed, or that none needed changing. A
   document archived here is named with its archive issue number; a supersession also lists the
   vocabulary it swept, since that list exists nowhere else.
6. **What changed** — a short prose summary of the change and anything the reviewer should
   look at first.
7. **Merge recommendation** — **squash by default**. Recommend **rebase-merge** only when the
   branch's commits are each individually substantive *and* each conventionally titled, since
   the changelog projects every subject that lands on main.

---

## Operating Notes

- **One ticket per session.** Context from a finished ticket contaminates the next one's
  judgment, and the frontier may have moved.
- **The gate before the loop, always.** Cross-model review is expensive; the ladder is not.
- **Surface reviews verbatim.** Do not paraphrase a finding you are about to argue with.
- If the reviewer repeats a finding you addressed, re-read it carefully — you likely fixed an
  adjacent concern rather than the one raised.
- If the ticket turns out to be obsolete or wrong, stop and say so. Closing it as *completed*
  with an explanatory comment (its dependents' need is met some other way) or as *not planned*
  (it never will be) is the human's call, and the two mean opposite things to the frontier.

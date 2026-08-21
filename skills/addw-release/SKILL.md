---
name: addw-release
description: Mechanical release - derived version, generated changelog, release PR, tag and GitHub Release
disable-model-invocation: true
argument-hint: "<spec-issue-number> — omit for the sole release-ready spec, or the repository"
---

# Release Mode

The release is **mechanical**. You author nothing about what shipped: the version
comes from the derivation script and the changelog from the generator, both
projecting the conventional-commit subjects that merged PRs put on the main
branch. Prose written here could drift from history; derived text cannot.

Your judgment enters at exactly two points — **which spec is being released**
(Step 1) and, for the human, **whether to merge the release PR** (Step 5).
Everything between them is transcription.

Every tracker operation goes through `.claude/skills/lib/tracker/tracker.sh`.
Pull requests and GitHub Releases are not tracker operations and use `gh pr` and
`gh release` directly.

---

## Step 0: Preconditions

```bash
. .claude/skills/lib/config/config.sh && config_source ADDW_MAIN_BRANCH ADDW_VERSION_FILE ADDW_RECIPE_LOCKFILE_SYNC ADDW_LOCKFILE
git checkout "$ADDW_MAIN_BRANCH" && git fetch origin && git pull
git status --short
git rev-parse HEAD "origin/$ADDW_MAIN_BRANCH"
```

The version and changelog are derived from what is *merged*, so the branch must
be **exactly** the remote's, not merely up to date with it. Those last two
lines are the check: a clean tree, and the two SHAs identical. A local commit
sitting ahead of the remote — a stray fix, an experiment, anything that never
went through a PR — would otherwise be projected into the changelog and shipped
under a version number, which is the one thing this flow exists to prevent.
Stop if they differ.

---

## Step 1: Mode and Readiness

Readiness is verified **here, at invocation** — never by tracker automation, so
nothing about a spec's state can go stale between sessions. Two modes:

```bash
bash .claude/skills/lib/tracker/tracker.sh frontier
```

Its `release-ready-specs` section is the same query, surfaced for the human at
the end of an implement session; this step re-runs it rather than trusting it.

**The invocation names a spec** — verify it:

```bash
bash .claude/skills/lib/tracker/tracker.sh state <n>
bash .claude/skills/lib/tracker/tracker.sh spec-complete <n>
```

A **closed** spec has already been released — its closure is what the last
release's tail did — so releasing it again would cut a second version for the
same intent. Refuse unless it is open; the completion query answers only
whether the children are done, not whether the spec is still in flight.

It prints `release-ready` or `not-release-ready`, then one
`<completed|open|not-planned>` line per child. Read the child lines before
reacting to the verdict, because the two ways to be not-ready mean opposite
things:

- **Any child still open** → **refuse**. List those tickets and stop. The
  release does not get to decide that unfinished work is finished.
- **No open child, but one or more closed as *not planned*** → name each one
  and ask the human, with `AskUserQuestion`, whether to release without it. A
  ticket closed as not planned is work deliberately abandoned, so only the human
  can say the spec is complete anyway; their confirmation **is** the waiver, and
  the release proceeds on it.
- **`no-children`** → refuse: decomposition never happened, so there is no
  completed intent to release.

**The invocation names nothing** — decide from the `release-ready-specs`
section:

- Exactly one → release it as a spec release, saying which.
- More than one → ask which; never pick for the human.
- None → before concluding, check for a spec that is complete **but for a
  not-planned child**. Such a spec never appears in `release-ready-specs`, so
  defaulting straight to a repository release would silently withhold the very
  waiver the human is owed:

  ```bash
  bash .claude/skills/lib/tracker/tracker.sh snapshot \
    | jq -r '.[] | select(.state == "OPEN")
             | select(any(.labels[]; .name == "spec")) | .number'
  ```

  Run `spec-complete` on each. Any spec whose children are all closed, with at
  least one not planned, is a release candidate: name it and its abandoned
  tickets, and offer it. If none qualifies, it is a **repository release** —
  it tags whatever the main branch has accumulated since the last tag and
  **closes nothing**. Say that explicitly, since it is the mode that silently
  does less.

Carry two things out of this step: the **mode**, and for a spec release the
**spec issue number**.

---

## Step 2: Derive the Version and the Entry

```bash
bash .claude/skills/lib/release/derive.sh version
bash .claude/skills/lib/release/derive.sh changelog
```

Both read the same commit range — everything since the last tag — so the version
and the entry can never disagree about which commits count.

- **Exit 1** means no commit in the range qualifies. **Stop and ask the human.**
  Never invent a version for a range that earned none.
- **Unclassifiable subjects** are warned and listed on stderr. Surface that list
  verbatim: each one is a PR title that landed unclassifiable, a defect at its
  source, and the commit is not in the entry. Releasing anyway is the human's
  call to make knowingly.

Both subcommands only read: this step decides the version and shows the entry
the PR body will carry. Step 3 writes it. Take both **exactly as printed** —
editing either is the drift this whole design exists to prevent.

---

## Step 3: The Release Branch

```bash
git checkout -b "release/<version>"
```

Two mechanical edits — three when the project configures a lockfile sync —
and nothing else:

1. **Write the changelog entry** with the generator — never by hand:

   ```bash
   bash .claude/skills/lib/release/derive.sh prepend
   ```

   It places the entry above the newest existing one, creating `CHANGELOG.md`
   with a title when absent, and skips an entry already present. Do not open
   the changelog to do this yourself: your edit tool must read a file before
   modifying it, and the changelog is **write-only for the workflow** — humans
   read it, agents get history from git. A step you perform by hand is a step
   that can drift from the commits it claims to describe.

2. **Write the version** to `$ADDW_VERSION_FILE` if that key is set, changing
   nothing else in that file. Projects without a version file skip this.

3. **Regenerate the lockfile**, if `ADDW_RECIPE_LOCKFILE_SYNC` is set: run
   that command now, immediately after the version write. The pair exists for
   ecosystems whose lockfile embeds the project's own version — uv, Cargo,
   npm — where skipping it would ship a lockfile still recording the
   *previous* version at every tag. A non-zero exit **aborts the release**
   before anything is committed, the same posture as a gate failure; there is
   no skip-and-warn. Projects without the key skip this edit entirely.

   Then read the diff of `$ADDW_LOCKFILE` before committing. The recipe is a
   mechanical projection of the version write, so the hunk is the project's
   own version line and nothing more. Anything beyond that is pre-existing
   drift this release did not create: stop and file it as its own ticket
   rather than folding it into the release — a lockfile hunk the human cannot
   approve at a glance defeats the point of the mode being mechanical.

Commit them with a subject the changelog generator excludes from future ranges,
so releases never narrate themselves:

```bash
git add CHANGELOG.md ${ADDW_VERSION_FILE:+"$ADDW_VERSION_FILE"} \
    ${ADDW_LOCKFILE:+"$ADDW_LOCKFILE"}
git commit -m "chore(release): <version>"
```

Never `git add -A`. If `git status` shows anything else — a doc fix, a stray
build artifact, a "while I'm here" change — it does not belong in a release PR
and goes to its own ticket. A release PR the human can approve at a glance is
the point of the mode being mechanical.

---

## Step 4: Open the Release PR

```bash
git push -u origin "release/<version>"
gh pr create --base "$ADDW_MAIN_BRANCH" --title "chore(release): <version>" --body-file <file>
```

The body states the mode (spec release naming its issue, or repository release),
the range the derivation covered, the changelog entry verbatim, and any
unclassifiable subjects from Step 2. Say plainly that **merging is the version
confirmation** and that the tag and GitHub Release follow it.

Then **wait**. The merge is the human's, and it is the only approval gate the
release has — which is exactly why the invariant that every commit on the main
branch arrives through a reviewed PR needs no exception for releases.

---

## Step 5: The Post-Merge Tail

After the human merges, **the release PR's merge commit** is what gets tagged —
not whatever the main branch has drifted to since:

```bash
git checkout "$ADDW_MAIN_BRANCH" && git pull
merge_sha="$(gh pr view <pr-number> --json mergeCommit --jq .mergeCommit.oid)"
bash .claude/skills/lib/release/tail.sh --commit "$merge_sha" [--spec <n>] <version>
```

Always pass `--commit`. If another PR merged in the minutes between the release
merge and this step — routine on any repo with more than one person — then
tagging the branch tip would ship a version covering commits its changelog
entry never mentions, and the tail cannot detect that on its own.

Four steps — tag, push, publish the GitHub Release from the changelog entry, and
for a spec release close the spec issue as completed. Each **skips what is
already done** and prints one `done:` or `skip:` line, so running the tail twice
is harmless and an interrupted run completes on the next invocation. If it exits
non-zero, fix the cause and **run it again**; do not perform the remaining steps
by hand, or the next run will disagree with the tree about what happened.

Pass `--spec <n>` only for a spec release. A repository release closes nothing,
so the open spec issues remain exactly the in-flight work.

---

## Step 6: Verification Sweep

A **backstop, not a rewrite**. Tickets update the living docs in their own PRs,
so this step expects to find nothing; what it does find becomes a ticket, never
an edit riding the release that already shipped.

```bash
bash .claude/skills/lib/docs/check-doc-accretion.sh docs/ARCHITECTURE.md
```

- **Vocabulary** — grep the living docs for the vocabulary of anything this
  release retired. A living doc describes only the current design; git history
  is the archive. Dated records (ADRs, `CHANGELOG.md` entries) are exempt —
  their date is part of their meaning, and once merged they are never
  retro-edited.
- **Accretion** — on `ACCRETION`, the document is narrating its own history one
  appended sentence at a time, a failure no size threshold can see. File it.
- **Retirement** — a document this release left untrue *in whole*, rather than in
  a passage, is retired rather than corrected. File one ticket per document:

  ```bash
  bash .claude/skills/lib/tracker/tracker.sh create \
    "docs: retire <path>" <body-file> backlog
  ```

  `backlog` per ADR 0007: this sweep is a detached detection — the release PR
  has already merged, so no PR body can name the filing. Graduation is an
  explicit human label flip; report "filed as backlog" on the way out. The body
  carries the path, the kind (`adr` or `proposal`), why the document
  stopped being true, and the command that retires it —
  `bash .claude/skills/lib/docs/archive-doc.sh <path> <adr|proposal> "<reason>"` —
  so the ticket is workable without rediscovering the finding. It carries **no
  `## Parent`**: an unparented ticket belongs to no spec, so it can make no spec
  incomplete and no release unready, and a document found here cannot block the
  release that found it. Being filed and reported is what makes it loud;
  withholding a release over a documentation deletion would be disproportionate.
  Never archive or delete the document here — that is the retirement ticket's own
  PR, reviewed like any other.
- **Charter fit** — re-read the charter and verify the release did not
  invalidate its purpose, principles, scope, or non-goals. If it did, flag it to
  the human: the charter changes only by their explicit decision, never as a
  side effect of shipping.

Finally, the maintenance nudge:

```bash
bash .claude/skills/lib/docs/audit-nudge.sh
```

On `NUDGE`, suggest `addw-maintain` — suggest only, never start it.

---

## Operating Notes

- **Derived, never authored.** If you find yourself writing a sentence about
  what this release contains, the mechanism has already failed.
- **Refusal is cheap; a wrong release is not.** Tags and GitHub Releases are
  public and awkward to retract, which is why Step 1 refuses rather than
  interprets.
- The release **never merges its own PR** and never pushes to the main branch
  directly. No skill has a direct-push path to main — emergencies included.

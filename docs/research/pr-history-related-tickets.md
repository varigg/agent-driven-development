# What does this repo's PR history show about small related tickets?

Research for issue #281 (map #278). Evidence only; no policy conclusions.

**Source and method.** All 110 merged PRs of `varigg/agent-driven-development` (PR #1 on 2026-08-06 through #274 on 2026-10-23), pulled with `gh api graphql` (PR size, files, commits per commit size, review/comment counts, closing-issue references) and `gh issue list` (issue bodies, for the `## Parent` and `## Blocked by` sections). "Lines" is additions plus deletions. "Open to merge" is `createdAt` to `mergedAt`. There is no `docs/research/` convention in the repo; this file creates that directory.

**Data caveats that bound everything below.**

- 91 of 110 PRs close an issue via a GitHub closing reference; only 35 close an issue whose body has a resolvable `## Parent`. The 19 PRs with no closing issue are mostly release, ADR-only and early process PRs.
- The 110-PR sample is not the sample ADR 0006 measured: this set has median 116 lines / 4 files and a third quartile of 308 lines, versus the ADR's cited median of 263 lines / 4 files. The ADR's "worst quartile 800-1400 lines, 9-37 files" matches PRs #22, #24, #25, #26 and #32 (below), all from 2026-08-07 and 2026-08-08.
- GitHub review data is almost empty (see section b), so "how review went" can only be read from commit history.

## (a) Sibling and blocking-chain tickets as separate small PRs

### Sibling PRs under one `## Parent`

Four parent specs have two or more merged PRs. Together they cover 34 of the 110 PRs.

| Parent spec | PRs | Merge span | Total lines | Pairs sharing at least one file |
| --- | --- | --- | --- | --- |
| #2 rebuild ADDW as an overlay | 13: #14 #15 #16 #17 #19 #20 #22 #24 #25 #26 #32 #35 #62 | 65.3 h (08-07 01:21 to 08-09 18:38); 11 of the 13 merged within 08-07 to 08-08 02:13 | 7771 | 65 of 78 |
| #37 worktree describes the present | 10: #52 #54 #55 #60 #61 #63 #64 #69 #65 #70 | 40.1 h (08-08 21:58 to 08-10 14:06) | 2703 | 14 of 45 |
| #144 release and spec lifecycles independent | 7: #153 #155 #156 #157 #158 #159 #161 | 70.2 h (09-03 00:58 to 09-05 23:10) | 2276 | 15 of 21 |
| #243 contract amendments | 4: #254 #257 #259 #260 | 51.7 h (10-12 19:07 to 10-14 22:48) | 943 | 2 of 6 |

Gaps between consecutively merged PRs within these groups (30 gaps): 10 are at most 1 hour, 18 are between 1 and 24 hours, 2 are over 24 hours.

Concrete short-window examples:

- #260 (178 lines, 7 files) merged 2026-10-14 22:48, 12 minutes after #259 (334 lines, 6 files, 22:36); both depend on #257, which merged 10-13.
- #64 (599 lines, 3 files) merged 2026-08-10 00:18; #65, #69 and #70 (50, 82 and 460 lines) all merged 14:05 to 14:06 the same day, after a night gap.
- #158 (601 lines, 12 files) and #159 (332 lines, 5 files) merged 30 minutes apart on 2026-09-04 (16:47 and 17:18), sharing 4 files.
- #229 (54 lines, 1 file) then #230 (253 lines, 10 files) merged 18 minutes apart on 2026-10-07, sharing no files.
- #26 (1083 lines, 37 files) then #32 (823 lines, 14 files) merged 42 minutes apart on 2026-08-08, sharing 4 files.

35 PRs link to a resolvable parent, with median 328 lines (versus 116 across all 110).

### Blocking chains

Edges where PR B closes an issue whose `## Blocked by` names an issue closed by PR A: 33 distinct PR-to-PR edges, of which 5 have a merge gap of 1 hour or less and 24 have a gap of 24 hours or less. Edges with a gap of 1 hour or less:

| Edge | Sizes | Gap | Shared files |
| --- | --- | --- | --- |
| #14 to #15 | 308 L/11 f to 712 L/8 f | 0.9 h | 2 |
| #26 to #32 | 1083 L/37 f to 823 L/14 f | 0.7 h | 4 |
| #52 to #54 | 160 L/2 f to 265 L/5 f | 0.6 h | 0 |
| #158 to #159 | 601 L/12 f to 332 L/5 f | 0.5 h | 4 |
| #229 to #230 | 54 L/1 f to 253 L/10 f | 0.3 h | 0 |

Other chains: #63 to #64 (328 to 599 lines, 1.1 h gap, 1 shared file); #60 to #61 (482 to 16 lines, 1.2 h, 2 shared files); #54 to #55 (265 to 261 lines, 2.3 h, 1 shared file). In the early overlay build, #26 depended on #20, #22 and #24 and shared 4 to 5 files with each of #20, #22 and #24.

### PRs that bundled several related tickets anyway

Three PRs close more than one issue: #115 (42 lines, 1 commit, issues #104 and #108), #248 (100 lines/13 files, 4 commits, issues #236 and #237) and #222 (902 lines/26 files, 6 commits, issues #217-#221; the commit headlines carry #221 and #219 only).

## (b) PRs that already carry several commits, and how review went

**Commit counts.** 63 of 110 PRs have more than one commit; the distribution of commits per PR is 1:47, 2:27, 3:17, 4:11, 5:3, 6:2, 8:1, 9:1, 12:1. Single-commit PRs: median 43 lines, 2 files, 0.08 h open to merge (max 48.5 h). Multi-commit PRs: median 253 lines, 6 files, 0.82 h (max 210.3 h). PRs with 4 or more commits (19): median 334 lines, 9 files, 0.84 h (max 18.1 h).

**GitHub-recorded review.** Across all 110 PRs: 0 formal reviews, 0 review threads, 1 issue comment (on #18). There are no review rounds, comments or approvals to count on GitHub; merge times are therefore dominated by when the PR was opened relative to the human boundary decision, not review traffic.

**Review rounds visible in commit history.** 15 PRs (all multi-commit) carry at least one commit headlined as addressing review ("address codex round N", "address pre-filter review", "address code review round 1 findings"), 21 such commits in total. The heaviest: #25 (1391 lines, 12 commits, 5 review-fix commits including codex rounds 1 to 4), #24 (1323 lines, 5 commits, 2 fix commits), #261 (80 lines, 3 commits, 2 fix commits), and one fix commit each in #15, #22, #26, #32 and #35.

**Multi-commit PRs where commits map to separate pieces of work:**

- #222 (5 tickets, 6 commits; 131, 125, 203, 343, 98 and 6 lines; 3 to 10 files each): opened to merged 1.1 h, no review rounds recorded, no fix commits.
- #248 (2 tickets, 4 commits of 47, 14, 22 and 19 lines): 1.3 h open to merge.
- #32 (9 commits: test, schema bump, tracker issue creation, backlog migration, migration doc, walkthrough rewrite, pre-filter fix, ADR 0002, small docs fix): 0.1 h open to merge; largest commit 339 lines.
- #25 (12 commits): 0.8 h open to merge, with the codex rounds visible as separate commits.

## (c) ADR 0006's worst quartile: would one commit per Deliverable have kept it reviewable?

ADR 0006 gives 800-1400 lines and 9-37 files. PRs in this repo at or above 800 lines (7):

| PR | Lines/files | Commits | Largest commit | Tickets closed | Open to merge | Commit structure |
| --- | --- | --- | --- | --- | --- | --- |
| #25 (08-08) | 1391/9 | 12 | 937 L, 4 f | #9 | 0.8 h | test commit 321 L; implementation 937 L; 5 review-fix commits (36 to 99 L, one 313 L plugin-probe rewrite); ADR 0001 47 L |
| #24 (08-07) | 1323/16 | 5 | 673 L, 12 f | #11 | 0.1 h | tests 300 L; implementation 673 L; three fix commits (395, 307, 70 L) |
| #135 (08-21) | 1090/31 | 1 | 1090 L, 31 f | #58 | 1.6 h | single commit |
| #26 (08-08) | 1083/37 | 3 | 907 L, 35 f | #12 | 0.3 h | tests 151 L; one retire-and-relocate commit 907 L over 35 files; review fix 37 L |
| #222 (10-06) | 902/26 | 6 | 343 L, 9 f | #217-#221 | 1.1 h | five ticket-aligned commits plus one 6-line follow-up |
| #22 (08-07) | 827/13 | 2 | 760 L, 11 f | #10 | 0.8 h | implementation 760 L; review fix 73 L |
| #32 (08-08) | 823/14 | 9 | 339 L, 2 f | #13 | 0.1 h | nine commits, none above 339 L, each single-topic |

Observations on the commit structure of these seven, without a verdict:

- In #32 and #222 every commit is 343 lines or fewer, so each commit is already a unit smaller than the 800-line PRs; #222 is already one commit per ticket.
- In #25, #24, #26 and #22 the bulk sits in one implementation commit (937, 673, 907 and 760 lines). Those commits are tests-first plus one implementation plus review-fix commits, not one commit per deliverable. In #26 the one big commit touches 35 of the PR's 37 files (a retirement/relocation sweep).
- #135 is a single 1090-line, 31-file commit with no internal commit structure.
- The test-first commits in #25, #24 and #26 (321, 300 and 151 lines) and #15 are separable from the implementation in git terms; the review-fix commits are small except #25's 313-line plugin-probe commit and #24's 395 and 307-line fix commits.
- In the overlay-build set, each of #22, #24, #25 and #26 closed exactly one ticket, so a commit-per-Deliverable split inside those PRs would have needed the single ticket itself to be decomposed; the commits there reflect build order (tests, implementation, fixes), not deliverables.
- PRs between 500 and 799 lines (4 more, so 11 at 500 lines or above in total) include #15 (712 lines, 3 commits, largest 357) and #158 (601 lines, 4 commits).

## Reproduction

`gh api graphql --paginate` over `pullRequests(states: MERGED)` with `commits`, `files`, `reviews`, `comments`, `reviewThreads` and `closingIssuesReferences`; `gh issue list --state all --limit 600 --json number,title,body`; parent and blocker numbers taken from the first `#N` under `## Parent` and all `#N` under `## Blocked by`. Gaps use `mergedAt`. Review-fix commits are matched by headline keywords (address, round N, pre-filter, review finding), so the count may under- or over-count by a few.

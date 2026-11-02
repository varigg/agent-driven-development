# What review research says about reviewer cognitive load

Research for issue #294, a child of map #278 (one PR delivering several related
tickets, one commit per ticket). It feeds #283, which designs the review-budget
guard that #280 split off from the cohesion judgment on eligibility.

The question: what limits a reviewer's effectiveness, are the claims leaned on
in #280 accurate, which metric could serve as a *checkable* guard, and what does
splitting a change into per-unit pieces buy?

## Short answer

The one finding that every source agrees on is that **review effectiveness
falls as the change grows**, and only diff size (lines changed, secondarily
files touched) has both evidence behind it and a mechanical check. The
"200–400 LOC, about an hour" figure is real but comes from a vendor case study,
not peer-reviewed work, and should be cited as a practitioner heuristic.
Splitting a change by concern has weaker evidence than #280 assumed: the one
controlled experiment found it cut false alarms but did **not** help reviewers
find more defects, and no study tests per-commit splitting inside a single PR.
Per-ticket commits are therefore a navigation aid, not a substitute for a size
cap.

## The claims from #280, checked

### Herzig & Zeller — tangled changes (partly misapplied)

Kim Herzig and Andreas Zeller, "The Impact of Tangled Code Changes," *Proc. 10th
Working Conference on Mining Software Repositories (MSR 2013)*, pp. 121–130. It
received the MSR most-influential-paper award ten years later.

What it measured: five open-source Java projects, with 3,047 bug-fixing commits.
The authors could classify only 549 of them by hand; 298 of those were tangled.
Because most commits were unclassifiable, they report a bound rather than a
rate: up to (or, as later work reads it, at least) **15% of bug fixes are
tangled**, ranging 6–15% across projects. Their untangling experiment found that
**at least 16.6% of source files are wrongly associated with bug reports** when
tangled commits are taken at face value.

Correction: this is a **repository-mining study about polluted defect data**,
not a code-review study. It establishes that tangled changes are common and
corrupt bug-prediction datasets; it says nothing about how tangling affects a
human reviewer. It supports "mixed concerns are common," not "mixed concerns
hurt review."

Source note: the Saarland server refused connections during this research, so
the figures above come from the paper's indexed abstract and from the precise
restatement in Herbold et al., "A Fine-grained Data Set and Analysis of Tangling
in Bug Fixing Commits," *Empirical Software Engineering* (2022),
[arXiv:2011.06244](https://arxiv.org/abs/2011.06244), §2. Herbold et al.'s own
line-level labelling of bug fixes found tangling in about 17% of commits once
formatting-only noise is set aside, broadly replicating the 15% bound.

### Barnett et al. — decomposing review changesets (accurate, but perception only)

Mike Barnett, Christian Bird, João Brunet, Shuvendu Lahiri, "Helping Developers
Help Themselves: Automatic Decomposition of Code Review Changesets," *ICSE 2015*
([Microsoft Research page](https://www.microsoft.com/en-us/research/publication/helping-developers-help-themselves-automatic-decomposition-of-code-review-changesets/),
[PDF](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/barnett2015hdh.pdf)).

Their tool, ClusterChanges, grouped diff regions by def-use relationships. On
1,000 randomly chosen changesets from Office 2013 review, **nearly 42% contained
more than one non-trivial partition** (the abstract rounds to "over 40%"); 45%
had exactly one. Authors annotating their changes to guide reviewers, the
manual alternative, happened in **under 5% of reviews**. In interviews with 20
developers from 13 projects, **16 said the partitions were correct and
complete**, and all were positive about the idea.

Caveat: the evidence is developer agreement and perceived usefulness. The paper
did not measure whether decomposition led reviewers to find more defects.

### SmartBear / Cisco — the 200–400 LOC, 60-minute figures (real, vendor-sourced)

Jason Cohen, *Best Kept Secrets of Peer Code Review* (SmartBear, 2006), chapter
5. The study covered **2,500 reviews of 3.2 million lines** of Cisco's
MeetingPlace product, by 50 developers on three continents over 10 months,
using SmartBear's Code Collaborator.

SmartBear's own summary
([best practices page](https://smartbear.com/learn/code-review/best-practices-for-peer-code-review/))
states the findings as:

- "developers should review no more than 200 to 400 lines of code (LOC) at a
  time";
- "a significant drop in defect density at rates faster than 500 LOC per hour";
- "Do not review for more than 60 minutes at a time", with the projection that
  "a review of 200-400 LOC over 60 to 90 minutes should yield 70-90% defect
  discovery."

Cohen's own write-up (StickyMinds, "The Largest Case Study of Code
Reviews—Ever") frames it as 200 LOC as a good limit and 400 as the absolute
maximum, at 400–500 LOC/hour, for no more than 60–90 minutes.

Corrections: the #280 summary ("~200–400 LOC, ~60 min") is faithful to the
source, but the source is a **vendor case study, not peer-reviewed**, from one
team and one product, and published to sell a review tool. The 70–90% defect
yield is a projection on SmartBear's marketing page, not a measured result. The
book itself sits behind a SmartBear sign-up form and the StickyMinds article
returned 403, so the study figures above are verified only against SmartBear's
page and indexed copies of Cohen's article.

### Baum et al. — working memory and change ordering (ordering overstated)

Tobias Baum, Kurt Schneider, Alberto Bacchelli, "Associating Working Memory
Capacity and Code Change Ordering with Code Review Performance," *Empirical
Software Engineering* 24(4):1762–1798, 2019, doi
[10.1007/s10664-018-9676-8](https://doi.org/10.1007/s10664-018-9676-8)
([author manuscript](https://www.ifi.uzh.ch/dam/jcr:c47671a8-3fa4-4f76-bbd1-bb352a9ac6d0/emse2019a.pdf)).

A confirmatory experiment with **50 participants**, mostly professional
developers (working memory measured for 45). Each reviewed one small change
(2 files, 31 presented lines) and two large ones (7 files, 233 and 490 presented
lines) from jEdit, seeded with defects. Findings:

- **Working memory capacity correlates with finding delocalized defects only**
  — defects that need two or more change parts held in mind together — with
  Kendall τB = 0.24 (p = 0.019). For all defects τB = 0.05 (not significant);
  for localized defects it is essentially zero.
- **Review effectiveness was significantly higher for the small change**,
  confirming earlier observational results.
- **Change-part ordering:** "We observe a tendency that the order of presenting
  the code changes influences the efficiency of code review, but cannot conclude
  this reliably." The study did not reach the sample size its power analysis
  called for.

Correction: Baum et al. support "working memory limits review" and "small
changes review better." They do **not** establish that ordering change parts
improves review; citing them for that claim overstates the paper.

## Further evidence worth carrying into #283

**di Biase et al. — the one controlled test of decomposition.** Marco di Biase,
Magiel Bruntink, Arie van Deursen, Alberto Bacchelli, "The effects of change
decomposition on code review — a controlled experiment," *PeerJ Computer
Science* 5:e193, 2019, doi
[10.7717/peerj-cs.193](https://doi.org/10.7717/peerj-cs.193)
([full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC7924728/)). 28 developers
reviewed a change of about 100 lines across seven files that mixed a refactoring
with a feature. The control group got one PR with one commit; the treatment
group got **two separate PRs**, one per concern. Result: decomposition "leads to
fewer wrongly reported issues" (6 false positives vs 1, p = 0.03) "yet impacts
neither understanding the change rationale nor the number of found defects"
(20 vs 17, p = 0.6). The authors flag that larger changes could behave
differently.

**Google's engineering practices.**
["Small CLs"](https://google.github.io/eng-practices/review/developer/small-cls.html):
"100 lines is usually a reasonable size for a CL, and 1000 lines is usually too
large," with the explicit qualification that "A 200-line change in one file
might be okay, but spread across 50 files it would usually be too large." It
also advises refactorings "in a separate CL from feature changes or bug fixes."
This is guidance, not a study.

**Sadowski et al. — Google's actual distribution.** Caitlin Sadowski et al.,
"Modern Code Review: A Case Study at Google," *ICSE-SEIP 2018*, doi
10.1145/3183519.3183525
([PDF](https://storage.googleapis.com/gweb-research2023-media/pubtools/4476.pdf)),
across 9 million reviewed changes: the **median change modifies 24 lines**, over
35% touch a single file, about 90% touch fewer than 10 files, and the median
reviewer count is one. Small changes are the norm where review works well, which
is consistent with, but does not prove, a size threshold.

## Which metrics could serve as a checkable guard

| Metric | Checkable before review? | Evidence that it predicts review quality |
| --- | --- | --- |
| Lines changed | Yes, from the diff | Strongest: Baum et al. (controlled), Cisco (observational, vendor), Google guidance. Thresholds cluster at 200–400 (Cisco) and 100 reasonable / 1000 too large (Google). |
| Files touched | Yes, from the diff | Moderate: Google treats spread across files as an aggravating factor; Baum's small/large contrast varies files and lines together, so it cannot separate them. |
| Concerns / tickets in the PR | Yes, by count | Weak as a *size* proxy: tangling is common (Herzig, Barnett), but splitting concerns did not raise defect detection (di Biase). A count says nothing about how big each unit is. |
| Review time / inspection rate | No; it is observed only after or during review | Cisco's 60–90 minutes and under 500 LOC/hour are review-conduct advice, not a property of the PR. This is the "one sitting" framing that ADR 0006 already rejected as uncheckable; its practical stand-in is a line count. |

## What commit-per-unit splitting changes

No study found here tests per-commit splitting *within* one PR. The nearest
evidence points one way. Splitting a tangled change into separate review units
reduces false alarms and is liked by developers (di Biase, Barnett), but it did
not help reviewers find more defects in the one controlled test, and ordering
the parts for the reviewer is unproven (Baum). Per-ticket commits also leave the
total a reviewer must work through unchanged if the PR is reviewed in one
sitting, and it is the total size that the evidence ties to effectiveness.

Where per-unit commits plausibly do help is the working-memory mechanism Baum
identified: when units are genuinely independent, fewer defects span units, so
the reviewer has fewer cross-part interactions to hold in mind. That benefit
depends on the cohesion judgment #280 already makes, not on the commit
boundaries themselves.

## Implication for the review-budget guard

The evidence supports guarding on **total diff size of the PR** — changed lines
as the primary measure, with file count as a secondary signal — rather than on
the number of tickets. A ceiling in the low hundreds of changed lines matches
both the Cisco heuristic and Google's practice, but no source justifies a
precise number, so whatever value #283 picks is a policy choice to be tuned
against this repo's own PR history, not a research-backed constant. Commit per
ticket should be required for navigation and to support the PR body's
ticket-by-ticket walk, without being counted as relief from the size cap.

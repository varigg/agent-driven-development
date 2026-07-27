---
name: addw-research
description: Exploratory research or spike - investigation without production code
disable-model-invocation: true
argument-hint: "what do you want to investigate?"
---

# Research Mode

You are now in **research mode** - for exploratory investigations that don't directly produce production code.

Use this for:

- Technology evaluation
- Feasibility studies
- Architecture exploration
- Performance investigation
- Bug root cause analysis
- Proof of concept

## Your Task

Research: $ARGUMENTS

---

## Step 0: Read fully @docs/ARCHITECTURE.md

## Step 1: Define Scope

Document the research question(s) clearly:

- What do we need to find out?
- What would a successful outcome look like?
- What decisions will this research inform?

Choose the investigation depth yourself — a quick lookup, a comparison, or a deep multi-tradeoff evaluation — and state it in the plan; the user adjusts it at the Step 3 confirmation if they disagree.

---

## Step 2: Research Plan

Create a lightweight research plan (not a full ADDW plan):

```markdown
# Research: [Topic]

## Question(s)

- [Primary question]
- [Secondary questions if any]

## Approach

1. [First thing to investigate]
2. [Second thing to investigate]
3. [...]

## Success Criteria

- [ ] [What we need to determine]
- [ ] [What we need to determine]

## Depth

[One line: how deep this investigation goes and why]
```

---

## Step 3: Confirm & Start

Present the research plan summary, then **use the `AskUserQuestion` tool**:

- **Question**: "Research plan ready — Question: [primary question], Approach: [brief summary], Depth: [one line]. Ready to start?"
- **Options**: "Yes, start research" (proceed with investigation), "Adjust the plan" (I have changes to the research scope or approach)

**If "Adjust"**: Modify the plan, then re-present using `AskUserQuestion`. Delivery format (chat vs memo) is decided at Step 5, once there are findings to judge.

---

## Step 4: Investigation

Conduct the research at the confirmed depth. Throwaway prototype code is fine here — it never ships.

---

## Step 4b: Codex Cross-Check

For **decision-grade findings** — architecture recommendations, technology choices, anything the user will build on — red-team the draft conclusion with the ask agent before presenting: the skill named by `ADDW_ASK_SKILL` in `docs/addw.env` (default `codex-ask`). Skip for quick lookups.

```bash
source docs/addw.env
bash ".claude/skills/${ADDW_ASK_SKILL:-codex-ask}/scripts/start.sh" \
    <topic-label> "Here is my draft recommendation: <summary + key rationale>. Red-team it: what am I missing, what would you choose instead, and why?"
```

Follow up in the same thread (the adapter's `scripts/resume.sh`) if the answer raises points worth probing. Then:

- **Incorporate** legitimate points into the findings (adjust the recommendation or add caveats).
- **Record real disagreements** in the memo's Open Questions section with both positions — the user decides.
- This is advisory, not gating: you own the final recommendation.

---

## Step 5: Present Findings

Present the findings in the conversation, structured as:

1. **Summary** (2-3 sentences)
2. **Key Findings** (numbered list)
3. **Recommendations** (what to do, rationale, alternatives)
4. **Open Questions** (if any)

Then **use the `AskUserQuestion` tool**:

- **Question**: "Research complete. What would you like to do next?"
- **Options**: "Write a memo" (persist findings to `docs/6-memo/`), "Elaborate on findings" (dive deeper into specific results), "Plan implementation" (hand these findings to `addw-1-plan`), "Done" (no further action needed)

**If "Write a memo"**, create `docs/6-memo/research_[date]_[topic].md` from this template, then confirm the file location:

```markdown
# Research: [Topic]

**Date**: DD-MM-YYYY
**Author**: [Name]

## Summary

[2-3 sentence executive summary]

## Questions Investigated

### Q1: [Question]

**Finding**: [Answer]
**Confidence**: [High/Medium/Low]
**Evidence**: [What supports this conclusion]

### Q2: [Question]

[...]

## Key Findings

1. **[Finding 1]**: [Details]
2. **[Finding 2]**: [Details]
3. **[Finding 3]**: [Details]

## Recommendations

- **Recommended**: [What we should do]
- **Rationale**: [Why]
- **Alternatives Considered**: [What else was evaluated]

## Open Questions

- [Questions that remain unanswered]
- [Areas needing further investigation]

## Next Steps

- [ ] [Action item 1]
- [ ] [Action item 2]

## Appendix (optional)

### Code Snippets / Prototypes

[Any throwaway code created during research]

### References

- [Links to documentation, articles, etc.]
```

---

## Boundaries

This workflow produces recommendations and — optionally — a memo in `docs/6-memo/`. It produces **no production code, no version bump, no changelog entry, and no commits to the main branch**. If it concludes that implementation should proceed, that happens through `addw-1-plan`.

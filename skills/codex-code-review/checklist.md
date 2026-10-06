# Code Review Checklist

This file is the **single source of truth** for code-review criteria. The Codex review loop (`codex-code-review`) applies it every round, and any manual review — auditing a past version, reviewing unplanned work, or standing in when Codex is unavailable — walks the same sections by hand and reports findings in chat. Referenced, never copied, so review surfaces cannot drift.

## Systematic Review Checklist

The **conventions sources** are the files `ADDW_CONVENTIONS` lists (ADR 0016). The ticket-context file names them for the Codex loop, and a manual review resolves them from `docs/addw.env`. When the key is empty, the project declares no rules: skip the convention items and say the review ran without a conventions check. When it is absent, report those items as **not performed**, never as passed.

### 1. Functional Requirements

- [ ] Implementation logic matches requirements correctly
- [ ] Interface/API matches documented specifications
- [ ] Error scenarios handled with proper feedback
- [ ] Edge cases and boundary conditions validated

### 2. Code Quality

Formatting, import hygiene, unused imports, and naming casing are enforced deterministically by the project's linter/formatter/type-checker in the testing gate — do not re-review them.

- [ ] DRY principle - no duplicated logic
- [ ] KISS principle - not unnecessarily complex for the problem
- [ ] Convention conformance - verify typing, naming, commenting, and module-size expectations against the project's conventions sources, each read whole (derived at review time, not cached here)

### 3. Architectural Compliance

- [ ] Code conforms to the rules the project's conventions sources state for what the diff touches (derived at review time)
- [ ] Nothing reintroduces what the project's guardrail ADRs rule out — the ticket-context file names the directory they live in, and a manual review resolves it from `ADDW_ADR_DIR`
- [ ] Only when the diff touches a write-once artifact (an ADR or other decision record frozen from the moment it merges): its delivered prose contradicts nothing the guardrail ADRs or the parent spec decided, even in a sentence no acceptance criterion points at — a standalone ticket is read against the guardrail ADRs alone. A diff touching no such artifact skips this item.

### 4. Error Handling

- [ ] Errors are properly caught and handled
- [ ] Error messages are clear and actionable
- [ ] Failure modes are graceful
- [ ] Logging is appropriate (not too verbose, not silent)

### 5. Security (if applicable)

- [ ] Input validation implemented
- [ ] No sensitive data exposed
- [ ] Authentication/authorization respected
- [ ] No obvious vulnerabilities

### 6. Performance

- [ ] No obvious performance issues (unnecessary work in hot paths, missing resource cleanup)
- [ ] Performance expectations the conventions sources state for what the diff touches are met (derived at review time)

---

## Issue Severity Classification

**Critical (Block Deployment)**:

- Security vulnerabilities
- Data corruption risks
- Breaking API/interface changes
- Authentication bypasses

**Major (Require Immediate Fix)**:

- Incorrect business logic
- Significant performance degradation
- Missing error handling
- Compilation/build errors

**Minor (Should Fix)**:

- Missing documentation
- Code duplication
- Missing edge case handling

**Suggestions (Nice to Have)**:

- Performance optimizations
- Readability improvements
- Additional test coverage

---

## Review Completion Criteria (Approval Gate)

Minimum for approval:

- [ ] All functional requirements implemented
- [ ] No critical or major issues remaining
- [ ] Build/compilation successful
- [ ] Affected unit tests pass (per the `addw-implement` testing gate)
- [ ] New logic has test coverage (or a coverage-debt ledger entry per the hard-to-cover policy)
- [ ] Documentation updated per project standards

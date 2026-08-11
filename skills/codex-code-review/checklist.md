# Code Review Checklist

This file is the **single source of truth** for code-review criteria. The Codex review loop (`codex-code-review`) applies it every round, and any manual review — auditing a past version, reviewing unplanned work, or standing in when Codex is unavailable — walks the same sections by hand and reports findings in chat. Referenced, never copied, so review surfaces cannot drift.

## Systematic Review Checklist

### 1. Functional Requirements

- [ ] Implementation logic matches requirements correctly
- [ ] Interface/API matches documented specifications
- [ ] Error scenarios handled with proper feedback
- [ ] Edge cases and boundary conditions validated

### 2. Code Quality

Formatting, import hygiene, unused imports, and naming casing are enforced deterministically by the project's linter/formatter/type-checker in the testing gate — do not re-review them.

- [ ] DRY principle - no duplicated logic
- [ ] KISS principle - not unnecessarily complex for the problem
- [ ] Convention conformance - for each layer the diff touches, verify typing, naming, commenting, and module-size expectations against what ARCHITECTURE.md documents for that layer (derived at review time, not cached here)

### 3. Architectural Compliance

- [ ] For each layer the diff touches, code conforms to the conventions ARCHITECTURE.md documents for it (derived at review time)
- [ ] Nothing reintroduces what the project's guardrail ADRs rule out — the ticket-context file names the directory they live in, and a manual review resolves it from `ADDW_ADR_DIR`

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
- [ ] Performance expectations ARCHITECTURE.md documents for the touched layers are met (derived at review time)

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

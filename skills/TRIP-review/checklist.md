# Code Review Checklist

This file is the **single source of truth** for code-review criteria. Both human-driven reviews via `.claude/skills/TRIP-review` and Codex-driven reviews via `.claude/skills/codex-code-review` apply the criteria below — referenced, not copied — so the two review surfaces cannot drift.

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
- [ ] Convention conformance - for each layer the diff touches, verify typing, naming, commenting, and module-size expectations against what ARCHI.md documents for that layer (derived at review time, not cached here)

### 3. Architectural Compliance

- [ ] For each layer the diff touches, code conforms to the conventions ARCHI.md documents for it (derived at review time)
- [ ] Nothing reintroduces what the guardrail ADRs in `docs/adr/` rule out

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
- [ ] Performance expectations ARCHI.md documents for the touched layers are met (derived at review time)

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
- [ ] Affected unit tests pass (per the TRIP-2 testing gate)
- [ ] New logic has test coverage (or a coverage-debt ledger entry per the hard-to-cover policy)
- [ ] Documentation updated per project standards

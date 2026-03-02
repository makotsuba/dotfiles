---
name: review-pr
description: Review a pull request using the reviewer subagent for an unbiased second opinion. Reports findings grouped by severity.
disable-model-invocation: true
---

Review the pull request: $ARGUMENTS

Follow these steps:

## 1. Get PR Details
- Run `gh pr view $ARGUMENTS` to read the title, description, and linked issue
- Run `gh pr diff $ARGUMENTS` to see all changes

## 2. Delegate to Reviewer Subagent
- Use the reviewer subagent to analyze the diff
- Provide it with the PR description and changed files as context
- The reviewer should read the surrounding code for consistency checks

## 3. Report Findings
Present results grouped by severity:

- **Critical**: Must fix before merging (correctness, security, data loss)
- **Major**: Should fix (significant impact on maintainability or behavior)
- **Minor**: Suggestions (style, naming, small improvements)
- **Positive**: Good patterns worth noting

Each finding must include: file path, line reference, and a concrete suggestion.

## 4. Summary
End with a one-line verdict:
- "Approve" — ready to merge
- "Approve with minor comments" — can merge after small fixes
- "Request changes" — needs fixes before merging

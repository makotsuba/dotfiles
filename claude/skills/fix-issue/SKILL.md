---
name: fix-issue
description: Fix a GitHub issue end-to-end following the project workflow. Investigates the codebase, writes a plan, implements the fix, verifies it works, and opens a PR.
disable-model-invocation: true
---

Fix the GitHub issue: $ARGUMENTS

Follow these steps exactly:

## 1. Understand the Issue
- Run `gh issue view "$ARGUMENTS"` to read the full issue
- Identify the problem, expected behavior, and any reproduction steps

## 2. Investigate the Codebase
- Use the researcher subagent to explore relevant code
- Find the root cause — do not guess or patch symptoms

## 3. Plan
- Write a checklist plan to `tasks/todo.md`
- Include: files to change, approach, test strategy
- Check in with the user before proceeding to implementation

## 4. Implement
- Make the minimal change that fixes the root cause
- Follow existing patterns in the codebase
- Do not refactor unrelated code

## 5. Verify
- Write tests that cover the fix and the reported edge case
- Run the test suite and confirm it passes
- Run the linter/type checker if available

## 6. Commit and PR
- Stage and commit with a descriptive message referencing the issue
- Open a PR: `gh pr create` with a summary of what was changed and why

## 7. Document
- Mark the task complete in `tasks/todo.md`
- If any mistakes were made during this session, update `tasks/lessons.md`

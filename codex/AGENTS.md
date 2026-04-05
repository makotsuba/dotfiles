# Coding Agent Instructions

## Workflow

### 1. Plan First

- Plan non-trivial tasks (3+ steps or architectural decisions) before starting
- Write detailed specs upfront to reduce ambiguity
- If something goes sideways, STOP and re-plan — don't keep pushing

### 2. Subagent Strategy

- Use the researcher subagent for codebase exploration before implementation
- Use the reviewer subagent after implementation for an unbiased second opinion
- One focused task per subagent

### 3. Self-Improvement Loop

- After ANY correction: update `tasks/lessons.md` with the pattern
- Write rules that prevent the same mistake from recurring
- Review `tasks/lessons.md` at session start when relevant

### 4. Verification Before Done

- Never mark a task complete without proving it works
- Run tests, check logs, demonstrate correctness
- Ask yourself: "Would a staff engineer approve this?"

### 5. Autonomous Bug Fixing

- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests — then resolve them

### 6. Demand Elegance (Balanced)

- For non-trivial changes: pause and ask "is there a more elegant way?"
- Skip this for simple, obvious fixes — don't over-engineer

## Task Management

1. **Plan First**: Write plan to `tasks/todo.md` with checkable items
2. **Verify Plan**: Check in with the user before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to `tasks/todo.md`
6. **Capture Lessons**: Update `tasks/lessons.md` after corrections

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Only touch what's necessary. Avoid introducing bugs.
- **No Speculation**: Don't add features, refactor, or make improvements beyond what was asked.

## Security

- Never read, write, or modify `.env`, `.envrc`, or `.env.*` files
- Never run `rm -rf` or destructive delete commands
- Never run `git push --force` or `git reset --hard` without explicit user confirmation
- Never run `sudo` or `su`

## Language

Always respond in Japanese. Use Japanese for all explanations, comments, and communications.
Technical terms and code identifiers remain in their original form.

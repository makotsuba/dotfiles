# Coding Agent Instructions

## Workflow

### 1. Plan First

- Plan non-trivial tasks (3+ steps or architectural decisions) before starting
- Write detailed specs upfront to reduce ambiguity
- If something goes sideways, STOP and re-plan — don't keep pushing

### 2. Subagent Strategy

- Use the researcher subagent for codebase exploration before implementation
- Use the `review-agent` skill after implementation for an unbiased second opinion
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
- When using existing API credentials, review how the command uses them, verify the effective destination, and limit access to the operation that needs them. Do not display, log, or save credentials in plaintext. If the expected credential is unavailable, report the cause. Create or substitute a credential only if explicitly authorized for the task.
- For a requested local OpenAI API call, use the existing 1Password reference if the project does not specify its own credentials. Read the single-line reference from `openai-key-ref` in `CODEX_HOME` (default: `~/.codex`). Keep the reference file local and outside Git.
- When using this reference, pass `OPENAI_API_KEY` only to the target process with `op run`. Use this key only for requests to `https://api.openai.com`. If the reference or 1Password authentication is unavailable, stop the call.
- Never run `rm -rf` or destructive delete commands
- Never run `git push --force` or `git reset --hard` without explicit user confirmation
- Never run `sudo` or `su`

## Language

Respond to the user in Japanese by default. Use Japanese for explanations, code comments, docstrings, and communications unless the user requests another language. Commit messages and pull requests follow the repository conventions below.
Technical terms and code identifiers remain in their original form.

## Migrated Shared Conventions

- Write commit subjects and bodies, and pull request titles and descriptions, in the language established by the repository. Check its contribution guidelines and relevant recent history. Follow each artifact's convention if they differ, and use English when the convention is unclear.
- Use Conventional Commits and keep the entire subject line under 72 characters, including the type and any scope.
- When modifying AWS CDK or CloudFormation, write any `description` passed to AWS APIs in English and never include sensitive information.
- Keep routine completion reports concise; add detail only when necessary.

# Skill Building Reference Guide

Based on "The Complete Guide to Building Skills for Claude" (Anthropic, January 2026).

## Progressive Disclosure (3 levels)

1. **YAML frontmatter**: Always in system prompt. Minimal — just enough for Claude to know WHEN to use the skill.
2. **SKILL.md body**: Loaded when skill is relevant. Full instructions.
3. **Linked files** (`references/`, `scripts/`, `assets/`): Loaded on demand. Detailed docs, templates, executable code, fonts, icons.

## Folder Structure

```text
your-skill-name/
├── SKILL.md              # Required - main skill file
├── scripts/              # Optional - executable code (Python, Bash, etc.)
├── references/           # Optional - documentation loaded as needed
└── assets/               # Optional - templates, fonts, icons used in output
```

## YAML Frontmatter Specification

### Required fields

```yaml
---
name: kebab-case-name        # Must match folder name
description: What + When      # Under 1024 chars, no XML tags
---
```

### Optional fields

```yaml
license: MIT
allowed-tools: "Bash(python:*) Bash(npm:*) WebFetch"  # Space-separated string (per official guide, Jan 2026)
compatibility: "Requires Node.js 18+"  # 1-500 characters
metadata:
  author: Company Name
  version: 1.0.0
  mcp-server: server-name
  category: productivity
  tags: [project-management, automation]
  documentation: https://example.com/docs
  support: support@example.com
```

### Security restrictions

- No XML angle brackets in frontmatter
- No "claude" or "anthropic" in skill name (reserved)

## Description Field Best Practices

Structure: `[What it does] + [When to use it] + [Key capabilities]`

Good:

```yaml
description: Analyzes Figma design files and generates developer handoff documentation. Use when user uploads .fig files, asks for "design specs", "component documentation", or "design-to-code handoff".
```

Bad:

```yaml
description: Helps with projects.         # Too vague
description: Processes documents.          # Missing triggers
```

## Workflow Patterns

### Pattern 1: Sequential Workflow Orchestration

Steps in a specific order with dependencies and validation at each stage.

```markdown
## 1. Create Account
Call MCP tool: `create_customer`

## 2. Setup Payment
Wait for: payment method verification

## 3. Create Subscription
Parameters: plan_id, customer_id (from Step 1)
```

### Pattern 2: Multi-MCP Coordination

Phases spanning multiple services with clear data passing.

```markdown
## Phase 1: Export (Figma MCP)
## Phase 2: Storage (Drive MCP)
## Phase 3: Task Creation (Linear MCP)
```

### Pattern 3: Iterative Refinement

Draft → Quality Check → Refinement Loop → Finalization.

### Pattern 4: Context-Aware Tool Selection

Decision tree to choose the right tool based on context.

### Pattern 5: Domain-Specific Intelligence

Embed specialized knowledge (compliance rules, best practices) before action.

## Instruction Writing Best Practices

- Be specific: `Run python scripts/validate.py --input {filename}` not "Validate the data"
- Include error handling with cause and solution
- Use `## Important` or `## Critical` headers for must-follow rules
- Keep SKILL.md under 5,000 words; move details to `references/`
- Put critical instructions at the top — don't bury them
- Provide examples of common scenarios

## Testing Checklist

### Triggering

- Triggers on obvious tasks
- Triggers on paraphrased requests
- Does NOT trigger on unrelated topics

### Functional

- Valid outputs generated
- Tool/API calls succeed
- Error handling works
- Edge cases covered

### Debugging

- Ask Claude: "When would you use the [skill-name] skill?" to verify trigger behavior
- If undertriggering: add more keywords and trigger phrases to description
- If overtriggering: add negative triggers ("Do NOT use for...")

## Troubleshooting

| Problem | Cause | Fix |
| ------- | ----- | --- |
| Skill won't load | SKILL.md not found | Must be exactly `SKILL.md` (case-sensitive) |
| Invalid frontmatter | YAML syntax error | Check `---` delimiters, quote strings with special chars |
| Doesn't trigger | Description too vague | Add specific trigger phrases and task types |
| Triggers too much | Description too broad | Add "Do NOT use for..." negative triggers |
| Instructions ignored | Too verbose or buried | Put critical rules at top, use numbered headers |
| Slow responses | SKILL.md too large | Move docs to `references/`, keep under 5K words |

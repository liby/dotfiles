# Agent Skills Best Practices

Summary of best practices for creating effective Claude Code Skills.

## SKILL.md Structure

### Required Fields

```yaml
---
name: your-skill-name        # lowercase, hyphens only, max 64 chars
description: What it does and when to use it  # max 1024 chars
---
```

### Optional Fields

| Field | Purpose |
|-------|---------|
| `version` | Skill version |
| `allowed-tools` | Restrict tools Claude can use |
| `model` | Specify model (e.g., `claude-sonnet-4-20250514`) |
| `context` | Set to `fork` for isolated sub-agent |
| `agent` | Agent type when `context: fork` (e.g., `Explore`, `Plan`) |
| `hooks` | Define PreToolUse, PostToolUse, Stop handlers |
| `user-invocable` | Hide from slash menu if `false` |

## Progressive Disclosure

**Core principle**: Load only what's needed, when it's needed.

### File Structure

```
my-skill/
├── SKILL.md              # Required - overview and navigation (~100 lines)
├── reference.md          # Detailed docs - loaded when needed
├── examples.md           # Usage examples - loaded when needed
└── scripts/
    └── helper.py         # Utility scripts - executed, not loaded
```

### Naming Conventions

Two valid approaches:

| Style | Examples | When to use |
|-------|----------|-------------|
| By document type | `reference.md`, `examples.md` | Generic, standard |
| By content | `commands.md`, `patterns.md`, `SECURITY.md` | Descriptive, self-explanatory |

### SKILL.md Guidelines

- Keep under **500 lines** for optimal performance
- Include **Quick Reference** with most common operations
- Link to detailed files in **Additional Resources** section
- Keep references **one level deep** (SKILL.md → reference files)

### What Goes Where

| Content | Location |
|---------|----------|
| Core principles, rules | SKILL.md |
| Quick reference (80% use cases) | SKILL.md |
| Complete command/API reference | Separate file |
| Advanced patterns, edge cases | Separate file |
| Utility scripts | `scripts/` directory |

## Description Best Practices

The description determines when Claude uses the Skill.

### Must Answer

1. **What does this Skill do?** - List specific capabilities
2. **When should Claude use it?** - Include trigger terms

### Good Example

```yaml
description: Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
```

### Bad Example

```yaml
description: Helps with documents
```

## Tool Restrictions

Use `allowed-tools` for security and scope control:

```yaml
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(python:*)  # Pattern matching
```

Use cases:
- Read-only Skills that shouldn't modify files
- Limited scope (analysis only, no file writing)
- Security-sensitive workflows

## Context Management

### When to Use `context: fork`

- Complex multi-step operations
- Tasks that would clutter main conversation
- Operations needing isolation

```yaml
context: fork
agent: gha  # or Explore, Plan, general-purpose
```

### Subagent Access to Skills

Built-in agents (Explore, Plan, general-purpose) do NOT access your Skills.

For custom subagents in `.claude/agents/`:

```yaml
# .claude/agents/code-reviewer.md
---
name: code-reviewer
skills: pr-review, security-check
---
```

## Scripts for Zero-Context Execution

Scripts execute without loading content into context - only output consumes tokens.

Good for:
- Complex validation logic
- Data processing requiring consistency
- Operations that are verbose to describe in prose

```markdown
## Validation

Run the validation script to check input:
python scripts/validate.py input.pdf
```

## Hooks

Scope hooks to Skill lifecycle:

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/security-check.sh $TOOL_INPUT"
          once: true  # Run only once per session
```

## Visibility Control

| Setting | Slash Menu | Skill Tool | Auto-discovery |
|---------|------------|------------|----------------|
| `user-invocable: true` (default) | Visible | Allowed | Yes |
| `user-invocable: false` | Hidden | Allowed | Yes |
| `disable-model-invocation: true` | Visible | Blocked | Yes |

## Skill Locations

| Location | Path | Scope |
|----------|------|-------|
| Personal | `~/.claude/skills/` | All your projects |
| Project | `.claude/skills/` | Repository only |
| Plugin | Bundled with plugins | Plugin users |
| Enterprise | Managed settings | Organization-wide |

Priority: Enterprise > Personal > Project > Plugin

## Troubleshooting

### Skill Not Triggering

- Description too vague
- Missing trigger terms users would naturally say
- Similar descriptions causing conflicts

### Skill Not Loading

- Check path: `~/.claude/skills/my-skill/SKILL.md`
- Check YAML syntax (no tabs, `---` on line 1)
- Run `claude --debug` to see errors

### No Diagnostics / Tools Not Working

- IDE not connected
- Language server not initialized
- File not opened in IDE

## References

- [Agent Skills Documentation](https://docs.anthropic.com/en/docs/agents-and-tools/agent-skills)
- [Best Practices Guide](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices)

# Frontmatter Matrix

> **Source of truth**: [`references/schema.yaml`](schema.yaml) — field names, types, constraints, and allowed values are defined there. This document provides human-readable explanations and examples.

Complete reference for all YAML frontmatter fields, their interactions, common patterns, and edge cases.

## Quick Reference

Minimum viable frontmatter:

```yaml
---
name: my-skill
description: What it does. Use when ...
---
```

## Field Reference

### name

| Attribute | Value |
|---|---|
| Type | string |
| Required | Strongly recommended (required in strict mode) |
| Max Length | 64 characters |
| Format | kebab-case: `[a-z0-9]+(-[a-z0-9]+)*` |
| Reserved Prefixes | `claude`, `anthropic` |

Must match the folder name. Examples:

```yaml
name: code-reviewer       # good
name: CodeReviewer        # bad — not kebab-case
name: claude-helper       # bad — reserved prefix
name: my_skill            # bad — underscores not allowed
```

### description

| Attribute | Value |
|---|---|
| Type | string |
| Required | Recommended (primary trigger mechanism) |
| Max Length | 1024 characters |
| Recommended Length | 100-200 words |
| Forbidden | Angle brackets (`<`, `>`) |

This is the most important field. Claude uses it to decide when to load the skill.

**Must include**:

1. What the skill does (specific capabilities).
2. When to use it ("Use when ...", "Use whenever ...").
3. Boundary language to reduce over-triggering.

**Good example**:

```yaml
description: Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
```

**Bad examples**:

```yaml
description: Helps with documents              # too vague
description: A tool for PDF processing         # no trigger language
description: Use this <skill> for PDFs         # angle brackets
```

**Tips for trigger accuracy**:

- Lean slightly aggressive — under-triggering is harder to fix than over-triggering.
- Include natural phrasings users would type, not just technical terms.
- Add negative boundaries: "Do NOT trigger for general file reading or text editing."
- If the description exceeds 1024 chars, use `improve_description.py` to compress it.

### argument-hint

| Attribute | Value |
|---|---|
| Type | string |
| Required | No |
| Purpose | Shown during `/` autocomplete |

Examples:

```yaml
argument-hint: "[issue-number]"
argument-hint: "[filename] [format]"
argument-hint: "[component] [from-framework] [to-framework]"
```

### disable-model-invocation

| Attribute | Value |
|---|---|
| Type | boolean |
| Default | false |
| Effect | Prevents Claude from auto-triggering; removes description from context |

Use for skills with side effects that should only run on explicit user command:

```yaml
disable-model-invocation: true    # only /deploy triggers this
```

### user-invocable

| Attribute | Value |
|---|---|
| Type | boolean |
| Default | true |
| Effect | Hides from `/` slash menu when false |

Use for background knowledge skills Claude should apply but users should not invoke directly:

```yaml
user-invocable: false    # Claude loads when relevant, no /slash-command
```

### allowed-tools

| Attribute | Value |
|---|---|
| Type | string (comma-separated) or list |
| Default | All tools available |
| Effect | Restricts Claude's tool access when skill is active |

Both formats are valid:

```yaml
# String format
allowed-tools: Read, Grep, Glob

# List format
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(python:*)
  - Bash(npm test*)
```

Pattern matching with `Bash(pattern)`:

| Pattern | Matches |
|---|---|
| `Bash(python:*)` | Any python command |
| `Bash(npm test*)` | npm test, npm test:unit, etc. |
| `Bash(git *)` | Any git command |
| `Bash(gh *)` | Any GitHub CLI command |

### model

| Attribute | Value |
|---|---|
| Type | string |
| Default | Session's current model |
| Purpose | Pin a specific model for this skill |

```yaml
model: claude-sonnet-4-20250514    # use a faster model for simple tasks
```

### context

| Attribute | Value |
|---|---|
| Type | string |
| Values | `fork` |
| Effect | Runs skill in an isolated subagent |

Always pair with `agent` when using `context: fork`:

```yaml
context: fork
agent: Explore
```

### agent

| Attribute | Value |
|---|---|
| Type | string |
| Values | `Explore`, `Plan`, `general-purpose`, or custom agent name |
| Effect | Determines subagent type when `context: fork` is set |

Setting `agent` without `context: fork` is usually unintended and triggers a validator warning.

### hooks

| Attribute | Value |
|---|---|
| Type | mapping |
| Keys | `PreToolUse`, `PostToolUse`, `Stop` |
| Effect | Lifecycle automation scoped to skill |

See [advanced_patterns.md](advanced_patterns.md) for full hook documentation.

### compatibility

| Attribute | Value |
|---|---|
| Type | string |
| Max Length | 500 characters |
| Purpose | Document runtime requirements |

```yaml
compatibility: Requires Python 3.9+ and pyyaml. Unix/macOS only.
```

### metadata

| Attribute | Value |
|---|---|
| Type | mapping |
| Purpose | Author, version, category, and custom annotations |

```yaml
metadata:
  author: "Your Name"
  version: "1.0.0"
  category: "developer-tooling"
```

### license and version

Both are optional string fields for distributed/open-source skills:

```yaml
license: MIT
version: "1.0.0"
```

## Common Field Combinations

### Read-Only Analysis Skill

```yaml
name: code-analyzer
description: Analyze code patterns. Use when asking about code quality or architecture.
allowed-tools: Read, Grep, Glob
```

### Side-Effect Workflow (User-Only)

```yaml
name: deploy-prod
description: Deploy to production
disable-model-invocation: true
context: fork
agent: general-purpose
allowed-tools: Bash(npm *), Bash(git *), Read
```

### Background Knowledge Skill

```yaml
name: api-conventions
description: API design patterns for this codebase
user-invocable: false
```

### Research Skill with Isolation

```yaml
name: deep-research
description: Research a topic in the codebase thoroughly
context: fork
agent: Explore
```

## Validation Rules

The validator (`validate_skill.py`) checks:

| Check | Level | Condition |
|---|---|---|
| `name` format | error | Must be kebab-case |
| `name` length | error | Must be ≤ 64 chars |
| `name` reserved prefix | error | Must not start with `claude` or `anthropic` |
| `name` folder match | warning | Should match folder name |
| `description` present | warning/error (strict) | Strongly recommended |
| `description` length | error | Must be ≤ 1024 chars |
| `description` angle brackets | error | Must not contain `<` or `>` |
| `description` trigger language | warning | Should include "Use when..." |
| `compatibility` length | error | Must be ≤ 500 chars |
| `allowed-tools` type | error | Must be string or list of strings |
| `model` type | error | Must be string |
| `hooks` type | error | Must be mapping |
| `context`/`agent` pairing | warning | `fork` without `agent` or `agent` without `fork` |
| Unknown keys | warning/error (strict) | Only known keys allowed |
| SKILL.md line count | warning | Recommended ≤ 500 lines |
| README.md present | warning/error (strict) | Should not exist in skill folder |

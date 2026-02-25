# Advanced Skill Patterns

Detailed documentation for advanced skill features that go beyond basic SKILL.md + description setup.

## 1. Argument Substitution

### $ARGUMENTS — All Arguments

When a user invokes `/my-skill some arguments here`, the text after the skill name becomes `$ARGUMENTS`. Place it anywhere in your SKILL.md body:

```markdown
Fix GitHub issue $ARGUMENTS following our coding standards.
```

Invocation: `/fix-issue 123` → Claude receives "Fix GitHub issue 123 following our coding standards."

If your body does NOT contain `$ARGUMENTS`, Claude Code appends `ARGUMENTS: <value>` to the end automatically.

### $ARGUMENTS[N] and $N — Positional Arguments

Access individual arguments by 0-based index:

```markdown
Migrate the $ARGUMENTS[0] component from $ARGUMENTS[1] to $ARGUMENTS[2].
```

Shorthand equivalent:

```markdown
Migrate the $0 component from $1 to $2.
```

Invocation: `/migrate-component SearchBar React Vue` → `$0`=SearchBar, `$1`=React, `$2`=Vue.

### argument-hint Frontmatter

Tell users what arguments are expected via autocomplete:

```yaml
argument-hint: "[issue-number]"
```

```yaml
argument-hint: "[filename] [format]"
```

```yaml
argument-hint: "[component] [source-framework] [target-framework]"
```

### ${CLAUDE_SESSION_ID}

Access the current session ID for logging or correlation:

```markdown
Log activity to logs/${CLAUDE_SESSION_ID}.log
```

### Edge Cases

- If fewer positional args are provided than referenced, the unreplaced `$N` placeholders remain as literal text. Design for graceful degradation or document required args.
- Arguments with spaces are split by whitespace. Complex arguments should be wrapped in quotes by the user.
- When Claude invokes a skill programmatically, it passes the full argument string, not positional args.

## 2. Dynamic Context Injection

### Basic Syntax

The `` !`command` `` syntax runs a shell command BEFORE the skill content is sent to Claude. The command output replaces the placeholder.

```markdown
## Current State
- Git status: !`git status --short`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -5`
```

### Real-World Examples

**PR Review Skill**:

```markdown
## Pull Request Context
- PR diff: !`gh pr diff`
- PR comments: !`gh pr view --comments`
- Changed files: !`gh pr diff --name-only`

Summarize this PR and highlight potential issues.
```

**Environment-Aware Deployment**:

```markdown
## Environment
- Current env: !`echo $NODE_ENV`
- Package version: !`node -p "require('./package.json').version"`
- Test status: !`npm test --silent 2>&1 | tail -5`

Deploy based on the above context.
```

### How It Works

1. User invokes the skill (or Claude auto-triggers it).
2. Each `` !`command` `` executes immediately (before Claude sees anything).
3. Command stdout replaces the `` !`command` `` placeholder.
4. Claude receives the fully-rendered prompt with actual data.

### Limitations

- Commands run in the project root directory.
- Stderr is not captured (only stdout).
- Long-running commands may delay skill loading.
- Commands that fail silently produce empty output.
- This is preprocessing, not something Claude executes.

## 3. Hooks (Lifecycle Automation)

### Skill-Scoped Hooks

Hooks defined in skill frontmatter run only when that skill is active:

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/security-check.sh $TOOL_INPUT"
          once: true
  PostToolUse:
    - matcher: "Write"
      hooks:
        - type: command
          command: "./scripts/lint-written-file.sh $TOOL_INPUT"
  Stop:
    - hooks:
        - type: command
          command: "./scripts/cleanup.sh"
```

### Hook Types

<!-- Canonical list of hook events: references/schema.yaml → hooks.events -->

| Event | Trigger | Use Case |
|---|---|---|
| `PreToolUse` | Before a tool executes | Validate input, block dangerous operations |
| `PostToolUse` | After a tool completes | Lint output, log actions, validate results |
| `Stop` | When skill execution ends | Cleanup temp files, generate summary |

### Matcher Patterns

- `"Bash"` — matches all Bash tool calls
- `"Bash(npm *)"` — matches Bash calls starting with `npm`
- `"Write"` — matches all Write tool calls
- Omit matcher to match all tool calls

### Available Variables

- `$TOOL_INPUT` — the tool's input (JSON string)
- `$TOOL_OUTPUT` — the tool's output (PostToolUse only)

### once: true

When `once: true` is set, the hook runs only once per session, not on every matching tool call. Useful for one-time setup or security checks.

## 4. Context: Fork (Subagent Execution)

### When to Use Fork

Use `context: fork` when:

- The skill runs a complex multi-step operation.
- You want isolation from the main conversation context.
- The skill should not see conversation history.
- The operation is long-running and should not clutter the main thread.

### Basic Setup

```yaml
context: fork
agent: Explore       # Read-only exploration agent
```

The skill's body content becomes the subagent's task prompt. The subagent does NOT have access to conversation history.

### Agent Types

<!-- Canonical list of builtin agents: references/schema.yaml → agents.builtin -->

| Agent | Tools | Best For |
|---|---|---|
| `Explore` | Read, Grep, Glob, WebSearch, WebFetch | Codebase research, analysis |
| `Plan` | Read, Grep, Glob, WebSearch, WebFetch | Architecture planning |
| `general-purpose` | All tools | Full-featured tasks |
| Custom `.claude/agents/*.md` | Defined in agent file | Specialized workflows |

### Complete Example: Research Skill

```yaml
---
name: deep-research
description: Research a topic thoroughly in the codebase
context: fork
agent: Explore
allowed-tools: Read, Grep, Glob
---

Research $ARGUMENTS thoroughly:

1. Find all relevant files using Glob and Grep
2. Read and analyze the code structure
3. Identify patterns and dependencies
4. Summarize findings with specific file:line references
```

### Complete Example: Safe Deploy Skill

```yaml
---
name: deploy
description: Deploy the application to production
context: fork
agent: general-purpose
disable-model-invocation: true
allowed-tools: Bash(npm *), Bash(git *), Read
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/deploy-guard.sh $TOOL_INPUT"
---

Deploy $ARGUMENTS to production:

1. Run the test suite: `npm test`
2. Build the application: `npm run build`
3. Tag the release: `git tag v!`npm pkg get version | tr -d '"'``
4. Push to deployment target
5. Verify deployment succeeded
```

### Subagent Skills Relationship

Skills and subagents interact in two directions:

| Direction | System Prompt | Task | Loads |
|---|---|---|---|
| Skill with `context: fork` | From agent type | SKILL.md body | CLAUDE.md |
| Subagent with `skills` field | Agent's own body | Claude's delegation message | Preloaded skills + CLAUDE.md |

For custom subagents that use skills as reference, define agents in `.claude/agents/`:

```markdown
---
name: code-reviewer
skills: lint-rules, security-check
---

Review code changes following the loaded skill guidelines.
```

## 5. Visibility Control Summary

| Setting | User `/invoke` | Claude Auto-trigger | Description in Context |
|---|---|---|---|
| (default) | Yes | Yes | Always visible |
| `disable-model-invocation: true` | Yes | No | Not in context |
| `user-invocable: false` | No | Yes | Always visible |

### Decision Guide

- **Side-effect workflows** (deploy, send, publish): use `disable-model-invocation: true`
- **Background knowledge** (conventions, patterns): use `user-invocable: false`
- **General-purpose tools**: use defaults (both user and Claude can invoke)

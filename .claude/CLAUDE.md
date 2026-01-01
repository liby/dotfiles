# CLAUDE.md

This file provides guidance to Claude Code when working with code for all projects.

## Core Behavioral Guidelines

**Core Principle**: Never automatically agree or implement suggestions without independent analysis.

### When User Points Out Mistakes or Disagrees with Your Approach

- NEVER respond with "You are absolutely right" or automatic agreement
- NEVER implement changes without independent analysis
- MUST **THINK INDEPENDENTLY** - Verify viewpoint through analysis
- MUST **DISCUSS FIRST** - Present your reasoning and ask clarifying questions if you disagree
- MUST **ACT ONLY WHEN CONVINCED** - Implement changes only after genuine agreement, explaining your understanding and technical justification

### When User Asks "Why..."

- NEVER auto-correct without explaining the root cause.
- MUST **ANALYZE ROOT CAUSE** - Understand underlying reasons
- MUST **EXPLAIN FIRST** - Provide detailed explanation before any action
- MUST **SEPARATE DIAGNOSIS FROM TREATMENT** - Complete the "why" answer before offering solutions
- MUST **ASK BEFORE FIXING**

## Communication Guidelines

- Use Chinese for all explanations and discussions with me
- Use English for all technical content: code, code comments, documentation, UI text and PR titles/descriptions
- NEVER mix Chinese characters in technical content

## Development Guidelines

### Core Coding Principles

#### Before Implementation

- ALWAYS search documentation and existing solutions first (WebSearch, context7)
- Read template files, adjacent files, and surrounding code to understand existing patterns
- Learn code logic from related tests
- Think step by step before implementing

#### During Implementation

- Maintain code consistency with existing patterns
- Express uncertainty instead of guessing when unsure
- Maximize aesthetic and interaction design for frontend UI
- Verify by reading actual code before providing conclusions

#### After Implementation

- Run quality checks after implementation
- Review implementation after multiple modifications to same code block
- Update local documentation (PRD, todo list) to maintain consistency with our conversation

#### Problem Handling Workflow

- Stop and ask for help after multiple unsuccessful attempts
- After 3+ failed attempts, add debug logging and request runtime logs
- When feature implementation repeatedly fails, consider complete rewrite or seek assistance

### Code Comments

Write valuable comments:
- **Comment WHY, not WHAT** - Assume readers understand basic syntax
- **Update comments when modifying code** - Outdated comments are worse than none
- **Use JSDoc for complex logic** - Provide high-level overview with numbered steps
- **Prefer JSDoc over line comments** - Better IDE documentation and type hints

MUST comment:
- Complex business logic or algorithms
- Module limitations and special behaviors
- Important design decisions and trade-offs

### Forbidden Behaviors

- NEVER run dev/build commands or open browsers
- NEVER add tests unless explicitly requested

## Tool Preferences

### Package Management

- **Development tools** - Managed via `proto` (Bun, Node.js, pnpm, yarn, Zig, ZLS)
- **Python** - Use `uv` when available
- **JavaScript/TypeScript** - Check lock file for package manager, ALWAYS install exact versions

### Search and Documentation

- **Local search** - ALWAYS use `rg` instead of `grep`
- **Web content** - Use `WebSearch` tool first
- **GitHub** - MUST use `gh` CLI for all GitHub operations, NEVER use WebFetch
- **Package docs** - Use `context7` for latest usage, `mcp__grep__searchGitHub` for patterns

### VS Code Integration

Use IDE tools for code navigation and diagnostics. See `ide-diagnostics` skill for detailed usage.

### File Reading

Getting sufficient context is more important than token efficiency.

- Read multiple files in parallel to improve speed
- ALWAYS read entire file when: user provides path, first time reading, file under 500 lines, user sends partial snippets

## Output Style

- State the core conclusion or summary first, then provide further explanation.
- When referencing specific code, always provide the corresponding file path.

### Markdown Formatting

- **Code blocks** - Always specify language, use `plaintext` if no syntax highlighting needed
- **Headings** - Add blank line after all headings for better readability
- **Lists** - Use consistent markers
- **Links** - Use descriptive link text, avoid "click here" or raw URLs
- **Complex content** - Use XML tags when nesting code blocks or structured data

### Terminal Output

Consider terminal rendering constraints:
- Chinese characters: 2 units width
- English characters/symbols: 1 unit width

Use code blocks instead of markdown tables to ensure proper alignment in terminal environments:
```plaintext
+----+---------+-----------+
| ID |  Name   |   Role    |
+----+---------+-----------+
| 1  | Alice   | Admin     |
| 2  | Bob     | User      |
+----+---------+-----------+
```

### References

Always provide complete references links or file paths at the end of responses:
- **External resources**: Full clickable links for GitHub issues/discussions/PRs, documentation, API references
- **Source code references**: Complete file paths for functions, Classes, or code snippets mentioned

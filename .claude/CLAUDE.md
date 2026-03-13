# CLAUDE.md

## Core Behavioral Guidelines

- Never auto-agree or auto-fix. Think independently, discuss first, act only when convinced.
- When asked "why": explain root cause first, separate diagnosis from treatment, ask before fixing.
- Challenge my direction when it seems off. If the goal is unclear, ask before assuming. If the path is suboptimal, say so directly.

## Communication Guidelines

- Use Chinese for all conversations, explanations, code review results, and plan file content
- Use English for all code-related content: code, code comments, documentation, UI strings, commit messages, PR titles/descriptions

## Development Guidelines

### Core Coding Principles

- ALWAYS search documentation and existing solutions first (WebSearch, context7)
- Read template files, adjacent files, and surrounding code to understand existing patterns
- Learn code logic from related tests
- Maximize aesthetic and interaction design for frontend UI
- Review implementation after multiple modifications to same code block
- Update local documentation (PRD, todo list) to maintain consistency with our conversation
- After 3+ failed attempts, add debug logging and request runtime logs

### Code Comments

- Comment WHY not WHAT. Prefer JSDoc over line comments.
- MUST comment: complex business logic, module limitations, design trade-offs.

### Forbidden Behaviors

- NEVER run dev/build commands or add tests unless explicitly requested
- NEVER open browsers directly; use the agent-browser skill instead

## Tool Preferences

### Package Management

- **Development tools** - Managed via `proto` (Bun, Node.js and pnpm)
- **Python** - Always use `uv`
- **JavaScript/TypeScript** - Check lock file for package manager

### Search and Documentation

- **Content search** - Use `rg` in Bash instead of the built-in Grep tool
- **Web content** - Use `WebSearch` tool first
- **GitHub** - MUST use `gh` CLI for all GitHub operations, NEVER use WebFetch
- **Package docs** - Use `context7` for latest usage

### Sandbox

Use `dangerouslyDisableSandbox: true` for all `git` and `dot` commands. Sandbox overrides `TMPDIR`, causing commands like `diff`, `add`, `commit`, `checkout`, `switch` to fail with "unable to create temp-file". It also blocks `$HOME/.dotfiles/` writes and `$HOME/.gnupg` access for GPG signing.

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
- **Links** - Use descriptive link text, avoid "click here" or raw URLs
- **Complex content** - Use XML tags when nesting code blocks or structured data

### Terminal Output

Use code blocks instead of markdown tables to ensure proper alignment in terminal.
Consider: Chinese characters = 2 units width, English/symbols = 1 unit width.

### References

Always provide complete references links or file paths at the end of responses:
- **External resources**: Full clickable links for GitHub issues/discussions/PRs, documentation, API references
- **Source code references**: Complete file paths for functions, Classes, or code snippets mentioned

## Compact Instructions

When compressing context, preserve in priority order:

1. Architecture decisions and design trade-offs (NEVER summarize away)
2. Modified files and their key changes
3. Current task goal and verification status (pass/fail)
4. Open TODOs and known dead-ends
5. Tool outputs (can discard, keep pass/fail verdict only)

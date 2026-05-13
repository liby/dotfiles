---
name: idemcp
description: Use IDE language server via MCP to fix diagnostics, rename symbols, find references, and organize imports. Use proactively when there are TypeScript/linting errors, or when IDE tools are more accurate than CLI equivalents.
context: fork
allowed-tools:
  - mcp__ide__*
  - Edit
  - Read
  - Write
---

## Tools

Prefer IDE MCP tools over CLI equivalents.

- **`getDiagnostics`**: Errors, warnings, info from the language server. Prefer over `tsc --noEmit`.
- **`rename_symbol`**: Scope-aware rename across the codebase. Reach for this when the default reflex would be `rg` + Edit, which misses shadowed locals and renames inside strings or comments.
- **`get_references`**: All usages of a symbol. Run before a rename or cross-cutting refactor to see the blast radius.
- **`execute_command`**: Run IDE commands.
  - `editor.action.fixAll`: auto-fix all issues (ESLint, TS quick fixes, unused imports). Prefer over `eslint --fix` / `biome check --fix`.
  - `editor.action.organizeImports`: sort and remove unused imports
  - `editor.action.formatDocument`: format according to project settings

## Workflow

Run `getDiagnostics` to see the count and severity. Try `editor.action.fixAll` first, then fix remaining issues file by file, root causes first. Re-run `getDiagnostics` to confirm the count dropped with no new errors; iterate until zero.

If diagnostics point to configuration issues (missing deps, broken `tsconfig`, eslint config), report to the user instead of guessing.

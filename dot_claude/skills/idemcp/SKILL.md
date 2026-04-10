---
name: idemcp
description: Use IDE language server via MCP to fix diagnostics, rename symbols, find references, and organize imports. Use proactively when there are TypeScript/linting errors, or when IDE tools are more accurate than CLI equivalents.
context: fork
allowed-tools:
  - mcp__ide__*
  - Edit
  - Glob
  - Grep
  - Read
  - Write
---

## Tool Selection

Prefer IDE MCP tools over CLI equivalents:
- `getDiagnostics` instead of `tsc --noEmit`
- `execute_command` with `editor.action.fixAll` instead of `eslint --fix` / `biome check --fix`
- `rename_symbol` instead of find-and-replace

## Available Tools

**getDiagnostics** — Retrieve errors, warnings, and info from the language server. Use before fixing, after editing, and before committing.

**rename_symbol** — Rename across the entire codebase with scope awareness. Always prefer this over manual Edit-based renaming.

**get_references** — Find all usages of a symbol. Use before renaming or to understand impact of changes.

**execute_command** — Run IDE commands:
- `editor.action.fixAll` — auto-fix all issues (ESLint, TS quick fixes, unused imports)
- `editor.action.organizeImports` — sort and remove unused imports
- `editor.action.formatDocument` — format according to project settings

## Workflow

1. **Assess** — get all diagnostics, report count and severity breakdown
2. **Fix** — try `editor.action.fixAll` first, then manually fix remaining issues file by file, root causes first
3. **Verify** — re-run getDiagnostics, confirm count decreased with no new errors
4. **Iterate** — repeat until zero diagnostics

Report when done: what was fixed, which files were modified.

If diagnostics point to configuration issues (missing deps, broken tsconfig, eslint config), report to the user instead of guessing.

## Troubleshooting

If no diagnostics are returned: the IDE may not be running, the file may not be open, or the language server may still be initializing. If diagnostics don't update after fixes, save the file and re-run getDiagnostics.

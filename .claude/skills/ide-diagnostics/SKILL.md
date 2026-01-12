---
name: ide-diagnostics
description: Fix TypeScript errors, get diagnostics, rename symbols, find references, organize imports. Use when user needs IDE/LSP tools for code navigation, diagnostics, and refactoring.
version: 0.1.0
allowed-tools:
  - mcp__ide__execute_command
  - mcp__ide__get_references
  - mcp__ide__getDiagnostics
  - mcp__ide__rename_symbol
  - Glob
  - Grep
  - Read
user-invocable: false
---

# IDE Diagnostics and Navigation Expert

Master IDE integration tools for diagnostics, code navigation, and automated fixes.

## Available IDE Tools

### Get Diagnostics (`mcp__ide__getDiagnostics`)

Retrieve errors, warnings, and info messages from the IDE's language server.

**When to use**: Before fixing errors, checking linting, validating changes

### Find References (`mcp__ide__get_references`)

Find all usages of a symbol (variable, function, class, etc.)

**When to use**: Before renaming, understanding impact, finding callers

### Rename Symbol (`mcp__ide__rename_symbol`)

Safely rename across the entire codebase.

**ALWAYS use this instead of manual find-replace** - handles scope correctly.

### Execute IDE Command (`mcp__ide__execute_command`)

Execute IDE commands like auto-fix, organize imports, format document.

Common commands:
- `editor.action.fixAll` - Auto-fix all issues
- `editor.action.organizeImports` - Remove/sort imports
- `editor.action.formatDocument` - Format document

## Best Practices

### DO:
- Use `mcp__ide__getDiagnostics` instead of `tsc --noEmit`
- Use `mcp__ide__rename_symbol` instead of manual find-replace
- Use `editor.action.fixAll` instead of `eslint --fix` or `biome check --fix`
- Check diagnostics before committing changes
- Fix errors before warnings
- Read file context before fixing (use Read tool)

### DON'T:
- Run `tsc --noEmit` via Bash when you have `getDiagnostics`
- Use Edit tool for renaming (use `rename_symbol`)
- Ignore warnings - they often indicate real issues
- Fix diagnostics without understanding the context

## Additional Resources

- For diagnostic error codes and patterns, see [diagnostics.md](diagnostics.md)
- For complete fix workflows, see [workflows.md](workflows.md)

## Troubleshooting

### No Diagnostics Returned

Possible causes:
- IDE not running or not connected
- File not opened in IDE
- Language server not initialized

### Diagnostics Not Updating

After fixes, diagnostics may take a moment to refresh. If needed:
- Use `editor.action.fixAll`
- Save the file
- Re-run `getDiagnostics`

## References

- VS Code Commands: Use `/ide` for interactive IDE features
- TypeScript Error Codes: https://typescript.tv/errors/
- ESLint Rules: https://eslint.org/docs/rules/
- Biome Linter: https://biomejs.dev/linter/

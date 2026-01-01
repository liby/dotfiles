---
name: ide-diagnostics
description: Expert knowledge of IDE/LSP tools for code navigation, diagnostics, and refactoring. Use when working with TypeScript errors, linting issues, code navigation, or IDE operations.
allowed-tools: mcp__ide__getDiagnostics, mcp__ide__get_references, mcp__ide__rename_symbol, mcp__ide__execute_command, Read, Glob
---

# IDE Diagnostics and Navigation Expert

Master IDE integration tools for diagnostics, code navigation, and automated fixes.

## Available IDE Tools

### 1. Get Diagnostics (`mcp__ide__getDiagnostics`)

**Purpose**: Retrieve errors, warnings, and info messages from the IDE's language server.

**When to use**:
- Before fixing TypeScript/JavaScript errors
- Checking for linting violations
- Validating code changes
- Identifying compilation issues

**Usage**:
```
Use mcp__ide__getDiagnostics to get all diagnostics
```

**Output**: List of diagnostics with:
- File path
- Line and column numbers
- Severity (error/warning/info)
- Error message
- Error code (e.g., `TS2304`, `@typescript-eslint/no-unused-vars`)

**Best practices**:
- Always check diagnostics before claiming code is error-free
- Use this instead of running `tsc --noEmit` or manual compilation
- Filter by severity if only interested in errors
- Group diagnostics by file for systematic fixing

### 2. Find References (`mcp__ide__get_references`)

**Purpose**: Find all usages of a symbol (variable, function, class, etc.)

**When to use**:
- Before renaming or refactoring
- Understanding code impact
- Finding all callers of a function
- Checking if code is unused

**Usage**:
```
Use mcp__ide__get_references for symbol at file:line:column
```

**Best practices**:
- Use before making changes to understand impact
- Verify all references when refactoring
- Check for unused code (0 references)

### 3. Rename Symbol (`mcp__ide__rename_symbol`)

**Purpose**: Safely rename variables, functions, classes across the entire codebase

**When to use**:
- Renaming variables, functions, classes
- Ensuring all references are updated
- Avoiding manual find-replace errors

**Usage**:
```
Use mcp__ide__rename_symbol at file:line:column to newName
```

**Best practices**:
- **ALWAYS use this instead of manual find-replace**
- Safer than Edit tool for renaming (handles scope correctly)
- Automatically updates all references
- Works across files

### 4. Execute IDE Command (`mcp__ide__execute_command`)

**Purpose**: Execute IDE commands like auto-fix, organize imports, format document

**Common commands**:

#### Auto-fix All Issues
```
Use mcp__ide__execute_command with command: "editor.action.fixAll"
```

**Use cases**:
- Auto-fix ESLint violations
- Auto-fix TypeScript quick fixes
- Apply all available code actions

#### Organize Imports
```
Use mcp__ide__execute_command with command: "editor.action.organizeImports"
```

**Use cases**:
- Remove unused imports
- Sort imports
- Clean up import statements

#### Format Document
```
Use mcp__ide__execute_command with command: "editor.action.formatDocument"
```

**Best practices**:
- **Use `editor.action.fixAll` instead of running `eslint --fix` via Bash**
- More efficient than manual fixes
- Respects IDE configuration
- Works with all language servers

## Diagnostic Severity Levels

1. **Error** (must fix):
   - TypeScript type errors
   - Syntax errors
   - Missing imports
   - Breaking compilation

2. **Warning** (should fix):
   - Unused variables
   - Deprecated API usage
   - Potential bugs
   - Style violations (if configured as warnings)

3. **Info** (consider fixing):
   - Suggestions
   - Code improvements
   - Style preferences

## Common Diagnostic Patterns

### TypeScript Errors

**Missing imports**:
```
Error: Cannot find name 'foo'
Code: TS2304
Fix: Add import statement
```

**Type mismatches**:
```
Error: Type 'string' is not assignable to type 'number'
Code: TS2322
Fix: Convert type or adjust declaration
```

**Property errors**:
```
Error: Property 'bar' does not exist on type 'Foo'
Code: TS2339
Fix: Add property or check type definition
```

### ESLint Errors

**Unused variables**:
```
Error: 'foo' is defined but never used
Rule: @typescript-eslint/no-unused-vars
Fix: Remove variable or use it
```

**Missing return types**:
```
Error: Missing return type on function
Rule: @typescript-eslint/explicit-function-return-type
Fix: Add explicit return type annotation
```

## Workflow: Fix All Diagnostics

### Step 1: Get Current Diagnostics
```
Use mcp__ide__getDiagnostics
```

### Step 2: Prioritize Fixes
1. Fix errors first (severity: error)
2. Then warnings
3. Then info-level suggestions

### Step 3: Fix Systematically
- Group by file
- Fix one file at a time
- Use `editor.action.fixAll` for auto-fixable issues
- Manually fix remaining issues with Edit tool

### Step 4: Verify
```
Use mcp__ide__getDiagnostics again to confirm all fixed
```

### Step 5: Iterate
Repeat until no diagnostics remain

## Best Practices

### DO:
- ✅ Use `mcp__ide__getDiagnostics` instead of `tsc --noEmit`
- ✅ Use `mcp__ide__rename_symbol` instead of manual find-replace
- ✅ Use `editor.action.fixAll` instead of `eslint --fix`
- ✅ Check diagnostics before committing changes
- ✅ Fix errors before warnings
- ✅ Read file context before fixing (use Read tool)

### DON'T:
- ❌ Don't run `tsc --noEmit` via Bash when you have `getDiagnostics`
- ❌ Don't use Edit tool for renaming (use `rename_symbol`)
- ❌ Don't ignore warnings - they often indicate real issues
- ❌ Don't fix diagnostics without understanding the context

## Integration with Other Tools

### With Read Tool
Always read the file before fixing diagnostics to understand context:
```
1. Use Read to view the file
2. Understand the code
3. Fix diagnostics appropriately
```

### With Edit Tool
After understanding diagnostics, use Edit to make targeted fixes:
```
1. Get diagnostics
2. Read file
3. Plan fixes
4. Apply edits
5. Verify with getDiagnostics
```

### With Glob Tool
For project-wide issues, find affected files first:
```
1. Use Glob to find TypeScript files: **/*.ts
2. Get diagnostics
3. Fix systematically
```

## Troubleshooting

### No Diagnostics Returned

Possible causes:
- IDE not running or not connected
- File not opened in IDE
- Language server not initialized

### Diagnostics Not Updating

After fixes, diagnostics may take a moment to refresh. If needed, trigger a refresh by:
- Using `editor.action.fixAll`
- Saving the file
- Re-running `getDiagnostics`

## References

- VS Code Commands: Use `/ide` for interactive IDE features
- TypeScript Error Codes: https://typescript.tv/errors/
- ESLint Rules: https://eslint.org/docs/rules/

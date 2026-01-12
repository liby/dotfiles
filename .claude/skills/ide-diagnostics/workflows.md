# IDE Diagnostics Workflows

Complete workflows for fixing diagnostics and using IDE tools effectively.

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

Repeat until no diagnostics remain.

## Workflow: Safe Refactoring

### Renaming a Symbol

1. **Find all references first**:
   ```
   Use mcp__ide__get_references for symbol at file:line:column
   ```

2. **Review the impact**: Understand which files will be affected

3. **Perform the rename**:
   ```
   Use mcp__ide__rename_symbol at file:line:column to newName
   ```

4. **Verify**: Run `getDiagnostics` to ensure no new errors

### Moving Code Between Files

1. Get references to understand dependencies
2. Make the move
3. Update imports using `editor.action.organizeImports`
4. Verify with diagnostics

## Workflow: Clean Up Imports

### Single File

```
Use mcp__ide__execute_command with command: "editor.action.organizeImports"
```

### Project-Wide

1. Use Glob to find all TypeScript files: `**/*.ts`
2. For each file, run organize imports
3. Verify with diagnostics

## Workflow: Auto-Fix Common Issues

### Fix All Auto-Fixable Issues

```
Use mcp__ide__execute_command with command: "editor.action.fixAll"
```

This handles:
- ESLint auto-fixes
- TypeScript quick fixes
- Unused import removal
- Formatting issues

### When to Use Manual Fixes

Auto-fix won't help with:
- Type mismatches requiring logic changes
- Missing function implementations
- Architectural issues
- Complex refactoring

## Workflow: Before Committing

1. **Get all diagnostics**: `getDiagnostics`
2. **Fix any errors**: Don't commit with errors
3. **Review warnings**: Fix if relevant to your changes
4. **Organize imports**: Clean up any import mess
5. **Final check**: Run diagnostics one more time

## Tool Usage Patterns

### getDiagnostics Output

Returns list of diagnostics with:
- File path
- Line and column numbers
- Severity (error/warning/info)
- Error message
- Error code (e.g., `TS2304`, `@typescript-eslint/no-unused-vars`)

### get_references Output

Returns list of locations where symbol is used:
- File paths
- Line and column numbers
- Context (how symbol is used)

### rename_symbol Behavior

- Automatically updates all references
- Works across files
- Handles scope correctly (won't rename unrelated symbols with same name)
- Respects language semantics

### execute_command Common Commands

| Command | Effect |
|---------|--------|
| `editor.action.fixAll` | Apply all available auto-fixes |
| `editor.action.organizeImports` | Sort and remove unused imports |
| `editor.action.formatDocument` | Format according to settings |
| `editor.action.quickFix` | Show available quick fixes |

---
allowed-tools: mcp__ide__getDiagnostics, Read, Edit, MultiEdit, LS, Glob, TodoWrite
description: Automatically fix all IDE diagnostics/errors until none remain
argument-hint: "[file path or pattern]"
---

## Your Task

Automatically fix all IDE diagnostics (errors, warnings) for: $ARGUMENTS

Iteratively fix ALL diagnostics until none remain.

## Process:

1. **Get diagnostics** for the specified scope (file/pattern/all)

2. **Fix errors** by:
   - Reading files to understand context
   - Analyzing and fixing all errors in each file
   - Common fixes: missing imports, type errors, undefined variables, syntax issues, etc.

3. **Repeat** until no diagnostics remain

4. **Report** summary of fixes applied
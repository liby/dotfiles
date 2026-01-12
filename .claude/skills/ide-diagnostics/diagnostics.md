# Diagnostic Error Codes and Patterns

Reference for common diagnostic patterns from TypeScript, ESLint, and Biome.

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

## Common TypeScript Errors

### Missing imports

```
Error: Cannot find name 'foo'
Code: TS2304
Fix: Add import statement
```

### Type mismatches

```
Error: Type 'string' is not assignable to type 'number'
Code: TS2322
Fix: Convert type or adjust declaration
```

### Property errors

```
Error: Property 'bar' does not exist on type 'Foo'
Code: TS2339
Fix: Add property or check type definition
```

### Implicit any

```
Error: Parameter 'x' implicitly has an 'any' type
Code: TS7006
Fix: Add type annotation
```

### Missing return type

```
Error: Function lacks ending return statement
Code: TS2366
Fix: Add return statement or adjust return type
```

### Null/undefined errors

```
Error: Object is possibly 'null'
Code: TS2531
Fix: Add null check or use optional chaining
```

## Common ESLint Errors

### Unused variables

```
Error: 'foo' is defined but never used
Rule: @typescript-eslint/no-unused-vars
Fix: Remove variable or use it
```

### Missing return types

```
Error: Missing return type on function
Rule: @typescript-eslint/explicit-function-return-type
Fix: Add explicit return type annotation
```

### Prefer const

```
Error: 'foo' is never reassigned
Rule: prefer-const
Fix: Change 'let' to 'const'
```

### No explicit any

```
Error: Unexpected any. Specify a different type
Rule: @typescript-eslint/no-explicit-any
Fix: Use specific type instead of any
```

### Require await

```
Error: Async function has no 'await' expression
Rule: require-await
Fix: Add await or remove async keyword
```

## Common Biome Errors

Biome rules are organized by category: `suspicious`, `correctness`, `style`, `complexity`, `a11y`, `security`, `performance`.

### Suspicious patterns

```
Error: noExplicitAny - Disallow the any type usage
Category: lint/suspicious
Fix: Use specific type instead of any
```

```
Error: noArrayIndexKey - Avoid using array index as key
Category: lint/suspicious
Fix: Use a unique identifier from the data
```

### Correctness issues

```
Error: noUnusedVariables - Disallow unused variables
Category: lint/correctness
Fix: Remove variable or use it
```

```
Error: useExhaustiveDependencies - Missing dependencies in useEffect
Category: lint/correctness
Fix: Add missing dependencies to the array
```

### Style rules

```
Error: useConst - Variable is never reassigned
Category: lint/style
Fix: Change 'let' to 'const'
```

```
Error: noNonNullAssertion - Avoid non-null assertions
Category: lint/style
Fix: Use optional chaining or proper null check
```

### Complexity rules

```
Error: noForEach - Prefer for...of instead of forEach
Category: lint/complexity
Fix: Convert to for...of loop
```

## Integration with Other Tools

### With Read Tool

Always read the file before fixing diagnostics to understand context:
1. Use Read to view the file
2. Understand the code
3. Fix diagnostics appropriately

### With Edit Tool

After understanding diagnostics, use Edit to make targeted fixes:
1. Get diagnostics
2. Read file
3. Plan fixes
4. Apply edits
5. Verify with getDiagnostics

### With Glob Tool

For project-wide issues, find affected files first:
1. Use Glob to find TypeScript files: `**/*.ts`
2. Get diagnostics
3. Fix systematically

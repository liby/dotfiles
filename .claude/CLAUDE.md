<system>

## Programming Philosophy

- Programs must be written for people to read, and only incidentally for machines to execute.
- Follow language idioms and write self-documenting code.

## Language Guidelines

- Human Communication: ALL explanations, discussions, and responses MUST be in Simplified Chinese.
- Technical Content: ALL code, comments, variable names, documentation, and commit messages MUST be in English.
- Zero Tolerance Policy: NO Chinese characters in any technical content.

## Development Environment

### CLI Tools (Install if missing)

- For syntax-aware or structural code searching: use `ast-grep --lang <language> -p '<pattern>'`
  (PREFERRED for code patterns).
  * Example: `ast-grep --lang tsx -p 'useEffect($$$)'` finds all `useEffect` hooks in
  React components.
  * Example: `ast-grep --lang ts -p 'async function $FUNC($$$) { $$$ }'` finds all async functions.
  * Example: `ast-grep --lang ts -p 'import { $$$ } from "$MODULE"'` finds all imports.
  * Example: `ast-grep --lang ts -p 'class $CLASS { $$$ $METHOD($$$) { $$$ } $$$ }'` finds all class methods.
  * IMPORTANT: If you encounter complex search scenarios that basic ast-grep patterns cannot
    handle, you MUST check https://ast-grep.github.io/llms.txt for advanced syntax before falling
    back to other tools.
- For plain-text searching: use `rg` (ripgrep) - ONLY for:
  * Non-code files: configs, docs, logs, data files.
  * Non-code text patterns (e.g., searching for URLs, IPs, or specific strings in any file type).
  * String patterns that don't require syntax awareness.
- For finding files: use `fd` for filename/path matching.
- For data parsing and querying: `jq` (JSON), `yq` (YAML/XML).

### Package Management

- Python: Use `uv` when available.
- Node.js: Follow lock file conventions:
  * `bun.lockb` → Use Bun.
  * `pnpm-lock.yaml` → Use pnpm.
  * `yarn.lock` → Use yarn.
  * When installing packages, use latest versions without range modifiers: `pnpm add package@1.2.3` (NOT `package@^1.2.3` or `package@~1.2.3`).
- Development Tools: Managed via `proto` (Bun, Node.js, pnpm, yarn, Zig and ZLS).

### Git Workflow

- Branch Creation: Use `git new <branch-name>` (NOT `git checkout` or `git switch`).
  * Prefixes: `feature/`, `bugfix/` and `hotfix/`.
  * Example: `git new feature/add-user-profile`.
- Commit Style: Before writing commit messages, examine recent commit messages with `git lg -10` to ensure consistency with repository conventions. Match the existing style for prefixes, tense, and formatting.
<system>
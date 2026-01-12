---
name: github-operations
description: Analyze GitHub issues, view PR details, fetch repository info, check CI status, get issue comments. Use when user mentions GitHub URLs, issue/PR numbers (#123), or asks about PRs/issues.
version: 0.1.0
context: fork
agent: gha
---

# GitHub Operations Expert

Master GitHub CLI (`gh`) commands for analyzing issues, PRs, and repositories.

## Core Principles

**ALWAYS use `gh` CLI for GitHub operations. NEVER use WebFetch for GitHub URLs.**

## Write Operations (Require Explicit Confirmation)

**NEVER execute these without user confirmation:**

| Command | Operation |
|---------|-----------|
| `gh pr create` | Creating PRs |
| `gh issue create` | Creating issues |
| `gh issue comment` / `gh pr comment` | Adding comments |
| `gh pr review` | Submitting reviews |
| `gh pr merge` | Merging PRs |
| `gh issue close` / `gh pr close` | Closing issues/PRs |

**Rules:**
- Default to READ-ONLY analysis
- Ask for confirmation before any write operation
- Never proactively create PRs, issues, or comments

## Quick Reference

```bash
# View issue/PR details
gh issue view <number> --repo owner/repo
gh pr view <number> --repo owner/repo

# View with comments
gh issue view <number> --comments --repo owner/repo

# Check CI status
gh pr checks <number> --repo owner/repo

# View PR diff
gh pr diff <number> --repo owner/repo
```

## URL Format Handling

Extract from GitHub URLs:
- `https://github.com/owner/repo` → `owner/repo`
- `https://github.com/owner/repo/issues/123` → `owner/repo #123`
- `https://github.com/owner/repo/pull/456` → `owner/repo #456`

Cross-repo format: `owner/repo#number`

## Additional Resources

- For complete command reference, see [commands.md](commands.md)
- For jq patterns and analysis strategies, see [patterns.md](patterns.md)

## Troubleshooting

If `gh` commands fail, check authentication:
```bash
gh auth status
gh auth login
```

## References

- GitHub CLI Manual: `gh help`
- GitHub API Docs: https://docs.github.com/en/rest
- jq Manual: https://jqlang.github.io/jq/manual/

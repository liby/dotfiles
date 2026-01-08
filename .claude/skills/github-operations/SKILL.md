---
name: github-operations
description: Expert knowledge of GitHub CLI (gh) usage and best practices. Use when analyzing GitHub issues, PRs, repositories, or when user mentions GitHub URLs, issue/PR numbers.
allowed-tools:
  - Bash(gh *)
  - Bash(jq *)
---

# GitHub Operations Expert

Master GitHub CLI (`gh`) commands and advanced techniques for analyzing issues, PRs, and repositories.

## Core Principles

**ALWAYS use `gh` CLI for GitHub operations. NEVER use WebFetch for GitHub URLs.**

## ⚠️ Write Operations (Require Explicit Confirmation)

**NEVER execute these without user confirmation:**

| Command | Operation |
|---------|-----------|
| `gh pr create` | Creating PRs |
| `gh issue create` | Creating issues |
| `gh issue comment` / `gh pr comment` | Adding comments |
| `gh pr review` | Submitting reviews |
| `gh pr merge` | Merging PRs |
| `gh issue close` / `gh pr close` | Closing issues/PRs |
| `gh issue reopen` / `gh pr reopen` | Reopening issues/PRs |

**Rules:**
- Default to READ-ONLY analysis
- Ask for confirmation before any write operation
- Never proactively create PRs, issues, or comments

## Basic Commands

### View Issues and PRs

```bash
# View issue details
gh issue view <number> --repo owner/repo

# View issue with comments
gh issue view <number> --comments --repo owner/repo

# View PR details
gh pr view <number> --repo owner/repo

# View PR with comments and reviews
gh pr view <number> --comments --repo owner/repo
```

### Repository Information

```bash
# View repository overview
gh repo view owner/repo

# Get detailed repository data (JSON format)
gh repo view owner/repo --json name,description,stargazersCount,forksCount

# Explore repository structure
gh api repos/owner/repo/contents
```

### PR-Specific Commands

```bash
# View PR diff/code changes
gh pr diff <number> --repo owner/repo

# Check CI/CD status
gh pr checks <number> --repo owner/repo

# Get PR review comments
gh api repos/owner/repo/pulls/<number>/reviews
```

## Advanced Techniques with `gh api` and `jq`

### Fetch and Filter Comments

#### Most Helpful Comments (by reactions)

Get the top 5 most-reacted comments to identify community consensus:

```bash
gh api repos/owner/repo/issues/<number>/comments --paginate \
  | jq 'sort_by(-.reactions.total_count) | .[0:5]'
```

**Use case**: Find the most valuable insights in long discussions

#### Timeline View (Recent + Early Comments)

Get context by viewing the first 3 and last 3 comments:

```bash
gh api repos/owner/repo/issues/<number>/comments --paginate \
  | jq 'sort_by(.created_at) | (.[0:3] + .[-3:])'
```

**Use case**: Understand how the discussion evolved without reading everything

#### All Comments (Paginated)

Fetch complete comment history:

```bash
gh api repos/owner/repo/issues/<number>/comments --paginate
```

### Filter Comments by Criteria

#### Filter by Author

```bash
gh api repos/owner/repo/issues/<number>/comments \
  | jq '.[] | select(.user.login == "username")'
```

#### Filter by Date Range

```bash
gh api repos/owner/repo/issues/<number>/comments \
  | jq '.[] | select(.created_at > "2024-01-01")'
```

#### Filter by Specific Reaction Count

Find comments with 10+ thumbs up:

```bash
gh api repos/owner/repo/issues/<number>/comments \
  | jq '.[] | select(.reactions."+1" > 10)'
```

## Search Operations

### Search Issues

```bash
# Search issues with filters
gh issue list --repo owner/repo --search "your query"

# Search with labels
gh issue list --repo owner/repo --label bug,priority-high

# Search by state
gh issue list --repo owner/repo --state open
```

### Search Code and Repositories

```bash
# Search across GitHub
gh search repos "your query"
gh search code "your query"
```

## Timeline and Event Analysis

### Get Issue Timeline Events

Track all activities on an issue (labels, assignments, references):

```bash
gh api repos/owner/repo/issues/<number>/timeline
```

### Get PR Review Comments

```bash
gh api repos/owner/repo/pulls/<number>/reviews
```

## URL Format Handling

When given GitHub URLs, extract the appropriate format:

- `https://github.com/owner/repo` → `owner/repo`
- `https://github.com/owner/repo/issues/123` → `owner/repo #123`
- `https://github.com/owner/repo/pull/456` → `owner/repo #456`

## Cross-Repository References

Use format `owner/repo#number` for cross-repo references:

```bash
gh issue view owner/repo#123
gh pr view owner/repo#456
```

## JSON Output for Structured Data

Add `--json` flag when you need structured data:

```bash
gh issue view <number> --json title,body,state,createdAt,comments
gh pr view <number> --json title,state,reviews,mergeable
```

## Common Analysis Patterns

### Pattern 1: Analyze Long Discussion (100+ comments)

**Strategy: Don't read everything - focus on high-value content**

1. Get issue/PR body: `gh issue view <number>`
2. Fetch most helpful comments (by reactions):
   ```bash
   gh api repos/owner/repo/issues/<number>/comments --paginate \
     | jq 'sort_by(-.reactions.total_count) | .[0:5]'
   ```
3. Get timeline view (first 3 + last 3 for evolution):
   ```bash
   gh api repos/owner/repo/issues/<number>/comments --paginate \
     | jq 'sort_by(.created_at) | (.[0:3] + .[-3:])'
   ```
4. Check timeline events for context
5. Summarize key points and community consensus

### Pattern 2: PR Code Review

1. View PR description: `gh pr view <number>`
2. Check CI status: `gh pr checks <number>`
3. Review code changes: `gh pr diff <number>`
4. Read review comments: `gh api repos/owner/repo/pulls/<number>/reviews`

### Pattern 3: Repository Overview

1. Get repo info: `gh repo view owner/repo`
2. List recent issues: `gh issue list --repo owner/repo --limit 10`
3. List recent PRs: `gh pr list --repo owner/repo --limit 10`
4. Check repository structure: `gh api repos/owner/repo/contents`

## Best Practices

1. **Always paginate** for complete data: Use `--paginate` with `gh api`
2. **Use jq for filtering**: Don't rely on manual parsing
3. **Respect rate limits**: Cache results when analyzing multiple items
4. **Extract structured data**: Use `--json` for programmatic access
5. **Context matters**: Combine issue body + comments + timeline for full picture

## Troubleshooting

### Authentication

If `gh` commands fail, check authentication:

```bash
gh auth status
gh auth login
```

### Repository Context

When no repo is specified, `gh` uses the current directory's git remote:

```bash
# Explicit repo specification
gh issue view 123 --repo owner/repo

# Uses current git repo
cd /path/to/repo && gh issue view 123
```

## References

- GitHub CLI Manual: `gh help`
- GitHub API Docs: https://docs.github.com/en/rest
- jq Manual: https://jqlang.github.io/jq/manual/

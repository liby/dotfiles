# jq Patterns and Analysis Strategies

Advanced techniques for analyzing GitHub issues and PRs using `gh api` and `jq`.

## Fetch and Filter Comments

### Most Helpful Comments (by reactions)

Get the top 5 most-reacted comments to identify community consensus:

```bash
gh api repos/owner/repo/issues/<number>/comments --paginate \
  | jq 'sort_by(-.reactions.total_count) | .[0:5]'
```

**Use case**: Find the most valuable insights in long discussions

### Timeline View (Recent + Early Comments)

Get context by viewing the first 3 and last 3 comments:

```bash
gh api repos/owner/repo/issues/<number>/comments --paginate \
  | jq 'sort_by(.created_at) | (.[0:3] + .[-3:])'
```

**Use case**: Understand how the discussion evolved without reading everything

### All Comments (Paginated)

Fetch complete comment history:

```bash
gh api repos/owner/repo/issues/<number>/comments --paginate
```

## Filter Comments by Criteria

### Filter by Author

```bash
gh api repos/owner/repo/issues/<number>/comments \
  | jq '.[] | select(.user.login == "username")'
```

### Filter by Date Range

```bash
gh api repos/owner/repo/issues/<number>/comments \
  | jq '.[] | select(.created_at > "2024-01-01")'
```

### Filter by Specific Reaction Count

Find comments with 10+ thumbs up:

```bash
gh api repos/owner/repo/issues/<number>/comments \
  | jq '.[] | select(.reactions."+1" > 10)'
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

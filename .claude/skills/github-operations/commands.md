# GitHub CLI Command Reference

Complete reference for `gh` commands used in GitHub operations.

## View Issues and PRs

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

## Repository Information

```bash
# View repository overview
gh repo view owner/repo

# Get detailed repository data (JSON format)
gh repo view owner/repo --json name,description,stargazersCount,forksCount

# Explore repository structure
gh api repos/owner/repo/contents
```

## PR-Specific Commands

```bash
# View PR diff/code changes
gh pr diff <number> --repo owner/repo

# Check CI/CD status
gh pr checks <number> --repo owner/repo

# Get PR review comments
gh api repos/owner/repo/pulls/<number>/reviews
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

```bash
# Get issue timeline events (labels, assignments, references)
gh api repos/owner/repo/issues/<number>/timeline

# Get PR review comments
gh api repos/owner/repo/pulls/<number>/reviews
```

## JSON Output for Structured Data

Add `--json` flag when you need structured data:

```bash
gh issue view <number> --json title,body,state,createdAt,comments
gh pr view <number> --json title,state,reviews,mergeable
```

## Repository Context

When no repo is specified, `gh` uses the current directory's git remote:

```bash
# Explicit repo specification
gh issue view 123 --repo owner/repo

# Uses current git repo
cd /path/to/repo && gh issue view 123
```

---
allowed-tools: Bash(gh api:*), Bash(gh issue:*), Bash(gh repo:*), Bash(gh search:*), Bash(gh pr:*)
description: Analyze GitHub issues, PRs, and discussions to provide insights or implementation guidance
---

Please analyze the GitHub content: $ARGUMENTS.

Steps to follow:

1. Identify the content type from the URL or reference provided
   - Repository: `https://github.com/owner/repo` or `owner/repo`
   - Issue: `owner/repo/issues/123` or `#123` (in current repo)
   - Pull Request: `owner/repo/pull/456` or `#456` (in current repo)
   - Other GitHub references (discussions, releases, etc.)

2. Gather comprehensive information:
   - For Repositories:
     - Use `gh repo view owner/repo` for basic info
     - Use `gh repo view owner/repo --json` for detailed data
     - Use `gh api repos/owner/repo/contents` to explore structure
   - For Issues: 
     - Use `gh issue view <number>` to get details
     - Use `gh issue view <number> --comments` to include comments
   - For PRs: 
     - Use `gh pr view <number>` for description and status
     - Use `gh pr view <number> --comments` to include all comments and reviews
     - Use `gh pr diff <number>` to see code changes
     - Use `gh pr checks <number>` to see CI/CD status
   - For any URL: Extract the appropriate format and use corresponding gh commands

3. Analyze and provide insights:
   - Understand the context and purpose
   - Summarize key points and discussions
   - Identify concerns or feedback if present
   - Suggest solutions or next steps based on the analysis

4. Take action only if explicitly requested:
   - Default to analysis and recommendations
   - Implement changes only when specifically asked
   - Ask for clarification if the intent is unclear

Notes:
- IMPORTANT: ALWAYS use GitHub CLI (`gh`) commands for all GitHub-related tasks, NOT WebFetch or other tools
- When given a full GitHub URL, extract owner/repo format (e.g., `liby/dotfiles` from `https://github.com/liby/dotfiles`)
- Commands automatically use the current repository context when no repo is specified
- For cross-repo references, use format: `owner/repo#number`
- Add `--json` flag for structured data when needed

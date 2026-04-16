---
name: gh
description: Analyze GitHub issues, PRs, and repos via `gh` CLI. Use when user mentions GitHub URLs, issue/PR numbers (#123), or asks about GitHub content.
context: fork
allowed-tools:
  - Bash(gh:*)
  - Bash(jq:*)
  - Read
---

Use `gh` CLI for all GitHub operations. Use your training knowledge — run `gh <command> --help` when unsure.

## URL Parsing

Extract owner/repo and number from GitHub URLs:
- `https://github.com/owner/repo/issues/123` → `gh issue view 123 --repo owner/repo`
- `https://github.com/owner/repo/pull/456` → `gh pr view 456 --repo owner/repo`
- Cross-repo shorthand: `owner/repo#123`

## Structured Output

Use `--json` + `jq` for structured data. Prefer `@tsv` for tabular output:

```bash
gh issue list --repo owner/repo --json number,title,state,updatedAt --jq '
  (["#","title","state","updated"],
  (.[] | [.number, .title, .state, .updatedAt[:10]])) | @tsv'
```

For large API responses, redirect to temp file first:

```bash
gh api repos/OWNER/REPO/issues/N/comments --paginate >/tmp/gh_comments.json \
  && jq -r '(["author","date","reactions","body"],
  (.[] | [.user.login, .created_at[:10], .reactions.total_count, .body[:80]])) | @tsv' /tmp/gh_comments.json
```

## Long Discussions (100+ comments)

Don't read everything — focus on high-value content:

1. Get the issue/PR body first
2. Fetch most-reacted comments: `jq 'sort_by(-.reactions.total_count) | .[0:5]'`
3. Get timeline view (first 3 + last 3) for how the discussion evolved
4. Check timeline events for labels, assignments, cross-references

## Agent Skills

`gh skill` installs Agent Skills from GitHub repos. State lives in each `SKILL.md`'s frontmatter (`metadata.github-*`) — there is no central manifest.

User mainly uses Claude Code and Codex. Pass `--agent` explicitly; default would be `github-copilot`.

Skills are unverified third-party content. Preview and skim `SKILL.md` (and any scripts) before installing anything the user hasn't vetted.

```bash
gh skill preview <owner/repo> <skill>

gh skill install <owner/repo> <skill> --agent <claude-code|codex> --scope <user|project>

gh skill update --dry-run     # check what's outdated
gh skill update --all         # update everything non-interactively
```

Scope paths:

- Claude Code: user → `~/.claude/skills`, project → `$PWD/.claude/skills`
- Codex: user → `~/.codex/skills`, project → `$PWD/.agents/skills` (shared with Copilot/Cursor/Gemini)

`gh skill update` only finds project-scope skills when run from that project root — it does not walk up parent dirs.

No `uninstall` command exists. To remove a skill, delete its directory directly (e.g. `rm -rf ~/.claude/skills/<name>`).

## Write Operations

Only perform write operations (create issues, comment, label, close, merge) when the user **explicitly** asks. Default to read-only analysis.

When creating issues or PRs, **always mask personal information** — replace hostnames, directory paths, email addresses, repo URLs, and other identifiable details with generic placeholders (e.g. `<hostname>`, `/path/to/project`, `example/example-repo.git`). Debug logs and error output should also be sanitized before including in public issues.

## Troubleshooting

If `gh` commands fail, check: `gh auth status`

---
name: gh
description: GitHub operations via `gh` CLI. Analyze issues/PRs/repos, and install/update/preview Agent Skills from GitHub repos (`gh skill install`). Use when user mentions GitHub URLs, issue/PR numbers (#123), GitHub content, or asks to install/update/preview a skill from a GitHub repo (e.g. a `SKILL.md` path, `owner/repo` skill reference).
context: fork
allowed-tools:
  - Bash(gh:*)
  - Bash(jq:*)
  - Read
---

Use `gh` CLI for all GitHub operations. Lean on your training knowledge; run `gh <command> --help` when unsure.

## URL Parsing

Extract owner/repo and number from GitHub URLs:
- `https://github.com/owner/repo/issues/123` -> `gh issue view 123 --repo owner/repo`
- `https://github.com/owner/repo/pull/456` -> `gh pr view 456 --repo owner/repo`
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

Don't read everything; focus on high-value content:

1. Get the issue/PR body first
2. Fetch most-reacted comments: `jq 'sort_by(-.reactions.total_count) | .[0:5]'`
3. Get timeline view (first 3 + last 3) for how the discussion evolved
4. Check timeline events for labels, assignments, cross-references

## Agent Skills

`gh skill` installs Agent Skills from GitHub repos or local directories. Use it instead of manually fetching `SKILL.md`. For a local source, add `--from-local`.

Preview third-party skills before installing. Read `SKILL.md` and bundled scripts because installed skills become agent instructions.

For this setup, install shared personal skills into `~/.agents/skills`; `~/.claude/skills` is a symlink to that root for Claude Code. Use `--agent` and `--scope` only when the user asks for a native host path or project install.

```bash
gh skill preview <owner/repo> <skill>

gh skill install <owner/repo> <skill> --dir ~/.agents/skills

gh skill update --dry-run --dir ~/.agents/skills
gh skill update --all --dir ~/.agents/skills
```

If `gh skill update --dry-run` reports duplicate skill names, verify overlapping host paths and rerun against the canonical root:

```bash
ls -ld ~/.claude/skills ~/.agents/skills 2>/dev/null
gh skill update --dry-run --dir ~/.agents/skills
```

If `gh skill update` prompts for missing source metadata, answer only when the original repo is known. Otherwise reinstall from a known source instead of guessing provenance.

To remove a skill, delete its directory directly (e.g. `rm -rf ~/.agents/skills/<name>`).

## Write Operations

Only perform write operations (create issues, comment, label, close, merge) when the user **explicitly** asks. Default to read-only analysis.

When creating issues or PRs, **always mask personal information**: replace hostnames, directory paths, email addresses, repo URLs, and other identifiable details with generic placeholders (e.g. `<hostname>`, `/path/to/project`, `example/example-repo.git`). Debug logs and error output should also be sanitized before including in public issues.

## Troubleshooting

If `gh` commands fail, check: `gh auth status`.

---
name: gh
description: Operate GitHub through the `gh` CLI for GitHub issues, pull requests, repos, workflow data, comments, and GitHub-hosted Agent Skills. Use when the user gives a GitHub URL, `owner/repo#123`, asks about a GitHub issue/PR/workflow, or asks to preview/install/update a skill from GitHub. Not for GitLab URLs or local skill editing without a GitHub source.
allowed-tools:
  - Bash(gh:*)
  - Bash(git:*)
  - Bash(jq:*)
  - Bash(ls:*)
  - Read
---

Use `gh` for GitHub operations. Verify command syntax with `gh <command> --help` before relying on flags that affect writes, pagination, or Agent Skills.

## Mode Picker

| User intent | Default action | Write allowed? |
|---|---|---|
| View issue, PR, repo, comments, workflow data | Read with `gh ... --json` and `jq` | No |
| Long discussion analysis | Fetch body, timeline, and high-signal comments | No |
| Draft PR title or body | Resolve the base and inspect the complete branch change; return text in chat | No |
| Create or update a PR | Draft from the verified branch change, then write only after an explicit request | Yes |
| Preview GitHub skill | `gh skill preview` and inspect bundled files | No |
| Install or update a skill; create an issue; comment, label, close, or merge; any other write | Explain target and run only after explicit user request | Yes |

Do not run `gh auth status` unless a `gh` command fails with an auth or host error. On a git auth failure, diagnose with `gh auth status` first; do not run `gh auth setup-git` to "ensure" auth, which unconditionally rewrites the global git credential helper to gh's absolute path and clobbers dotfile-managed git config.

## URL And Reference Parsing

- `https://github.com/owner/repo/issues/123` -> `gh issue view 123 --repo owner/repo`
- `https://github.com/owner/repo/pull/456` -> `gh pr view 456 --repo owner/repo`
- `owner/repo#123` -> ask whether it is issue or PR when the host command cannot infer it

Treat bare `#123` as ambiguous unless the current repo is known to be GitHub and the user context points to GitHub.

## Structured Reads

Use `--json` plus `--jq` or `jq`. Prefer tabular extraction for chat output.

```bash
gh issue list --repo owner/repo --json number,title,state,updatedAt --jq '
  (["#","title","state","updated"],
  (.[] | [.number, .title, .state, .updatedAt[:10]])) | @tsv'
```

`gh search issues`/`gh search prs` accept only `--state open|closed` (no `all`, unlike `gh issue list --state all`); omit `--state` to get both.

For large paginated responses, stream directly into `jq` and extract only needed fields:

```bash
gh api repos/OWNER/REPO/issues/N/comments --paginate | jq -sr '
  add | (["author","date","reactions","body"],
  (.[] | [.user.login, .created_at[:10], .reactions.total_count, .body[:80]])) | @tsv'
```

## Long Discussions

For issues or PRs with many comments:

1. Read the issue or PR body first.
2. Fetch comments and sort by reaction count for the top five high-signal comments.
3. Read the first three and last three comments to understand timeline.
4. Check timeline events for labels, assignments, review states, and cross-references when they affect the answer.

## Pull Requests

When asked to draft, create, or update a PR title or body:

1. For an existing PR, resolve the base, head, and URL with `gh pr view <number-or-url> --json baseRefName,headRefName,url`.
2. For a new PR, resolve the base from the user's request, the branch's `gh-merge-base` configuration, or the repository default branch. Do not hardcode `main` or `master`.
3. For an existing PR, inspect its complete patch with `gh pr diff <number-or-url>` and use the resolved PR metadata for commits and files. For a new PR, inspect `git log <base>..HEAD`, the stat, and the complete `git diff <base>...HEAD`. Read the repository PR template when one exists.
4. Draft from the actual branch changes and follow the user's requested structure. Do not invent release, rollback, impact, or testing claims.
5. Run `gh pr create` or `gh pr edit` only when the user explicitly asked for that write this turn. Otherwise keep the draft in chat.
6. Return the final title and body. After a write, also return the PR URL.

## Agent Skills From GitHub

Use `gh skill` instead of manually downloading a GitHub-hosted `SKILL.md`.

Read-only path:

```bash
gh skill preview <owner/repo> <skill>
gh skill update --dry-run --dir ~/.agents/skills
```

Write path, only after explicit request:

```bash
gh skill install <owner/repo> <skill> --dir ~/.agents/skills
gh skill install <owner/repo> <skill> --agent codex --scope user
gh skill update --all --dir ~/.agents/skills
```

Applying `gh skill update` requires `--all` (or interactive confirmation) even when skill names are given.

Use `--from-local` only when the user asks to install from a local directory. Use `--allow-hidden-dirs` only when the source repo stores skills under hidden directories.

For this setup, shared personal skills live under `~/.agents/skills`; `~/.claude/skills` is expected to point at the same root. Verify with:

```bash
ls -ld ~/.agents/skills ~/.claude/skills 2>/dev/null
```

If `gh skill update --dry-run` reports duplicate names, verify host paths and rerun against the canonical root.

If `gh skill update` prompts for missing source metadata, answer only when the original repo is known. Otherwise reinstall from a known source instead of guessing provenance.

Local skill removal is a filesystem workflow, not a `gh skill` operation in the verified help. Do not remove local skill directories from this skill unless a current `gh skill remove --help` command exists and documents the removal mode.

## Write Operations

GitHub writes include issue creation, comments, labels, closes, merges, releases, workflow dispatches, skill installs, and skill updates. Run them only after explicit user request.

When creating public issues, PRs, or comments, mask personal information: hostnames, local directory paths, email addresses, repo URLs that should not be public, tokens, and raw debug output.

## Troubleshooting

- Unknown flag: run `gh <command> --help` and adjust to the installed version.
- Auth or host error: run `gh auth status` and report the failing account or host without printing tokens.
- Large JSON: stream to `jq` with bounded output before responding.

---
name: gh
description: Operate GitHub through the `gh` CLI for GitHub issues, pull requests, repos, workflow data, comments, and GitHub-hosted Agent Skills. Use when the user gives a GitHub URL, `owner/repo#123`, asks about a GitHub issue/PR/workflow, or asks to preview/install/update a skill from GitHub. Not for GitLab URLs or local skill editing without a GitHub source.
allowed-tools:
  - Bash(gh:*)
  - Bash(git:*)
  - Bash(jq:*)
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

Do not run `gh auth status` unless a `gh` command fails with an auth or host error. Report the failing account or host without printing tokens. On a git auth failure, diagnose with `gh auth status` first; do not run `gh auth setup-git` to "ensure" auth, because it rewrites Git's global credential-helper configuration.

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

At the first inspection of an existing PR, record its `url` and `headRefOid` with
the evidence. A review or inspection from another workflow can serve as a later
merge baseline only when it carries that exact URL and OID.

When asked to draft, create, or update a PR title or body:

1. For an existing PR, resolve the base, head, head OID, and URL with `gh pr view <number-or-url> --json baseRefName,headRefName,headRefOid,url`.
2. For a new PR, resolve the base from the user's request, the branch's `gh-merge-base` configuration, or the repository default branch. Do not hardcode `main` or `master`.
3. For an existing PR, inspect its complete patch with `gh pr diff <number-or-url>` and use the resolved PR metadata for commits and files. For a new PR, inspect `git log <base>..HEAD`, the stat, and the complete `git diff <base>...HEAD`. Read the repository PR template when one exists.
4. Draft from the actual branch changes and follow the user's requested structure. Do not invent release, rollback, impact, or testing claims.
5. Run `gh pr create` or `gh pr edit` only when the user explicitly asked for that write this turn. Otherwise keep the draft in chat.
6. Return the final title and body. After a write, also return the PR URL.

## Agent Skills From GitHub

Before the first `gh skill` command for preview, install, or update, load and
follow the [GitHub-hosted Agent Skills workflow](references/agent-skills.md).

## Write Operations

GitHub writes include issue creation, comments, labels, closes, merges, releases, workflow dispatches, skill installs, and skill updates. Run them only after explicit user request.

For `gh pr merge`:

1. If the merge relies on a review or earlier inspection, require its recorded PR URL and `headRefOid`; stop if either is absent.
2. Immediately before the write, refresh the PR and resolve its current `url` and `headRefOid`.
3. Stop when the refreshed URL or OID differs from the recorded review/inspection baseline.
4. Pass the refreshed, successfully compared OID with `--match-head-commit`.
5. Refetch the PR after the command and verify the same head OID and resulting merge state.

When creating public issues, PRs, or comments, mask personal information: hostnames, local directory paths, email addresses, repo URLs that should not be public, tokens, and raw debug output.

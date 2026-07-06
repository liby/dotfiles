---
name: glab
description: Operate GitLab through the `glab` CLI for GitLab merge requests, issues, pipelines, discussions, repos, and MR descriptions. Use when the user gives a GitLab URL, asks about a GitLab MR/issue/pipeline, mentions `glab`, or asks to draft/update an MR description. Not for GitHub URLs or purely local git tasks that do not need GitLab issue, MR, pipeline, discussion, or repo data.
context: fork
allowed-tools:
  - Bash(glab:*)
  - Bash(git:*)
  - Bash(jq:*)
  - Read
---

Use `glab` for GitLab operations. Verify command syntax with `glab <command> --help` before relying on flags that affect writes, JSON output, or pipelines.

Do not run `glab auth status` unless a `glab` command fails with an auth or host error.

## Mode Picker

| User intent | Default action | Write allowed? |
|---|---|---|
| View MR, issue, discussions, repo, pipeline list | Read with `glab ... -F json` or `glab api` | No |
| Draft MR title or description | Produce text in chat | No |
| Update MR, create issue, comment, approve, merge, retry or cancel CI | Run only after explicit user request | Yes |

## URL Parsing

- `https://<host>/group/project/-/merge_requests/123` -> `glab mr view 123 -R group/project`
- `https://<host>/group/project/-/issues/456` -> `glab issue view 456 -R group/project`

Treat bare `!123`, `#123`, or `MR 123` as ambiguous unless the current repo or user text identifies GitLab.

## Structured Reads

Use `-F json` only for commands whose help lists `-F --output`. Use `jq` for extraction.

```bash
glab mr list -R group/project -F json | jq -r '
  (["!","title","author","updated"],
  (.[] | [.iid, .title, .author.username, .updated_at[:10]])) | @tsv'
```

For API endpoints, use placeholders that `glab api --help` supports. Use `:fullpath` for the current project and literal IID values from the user URL or `glab mr view`. For raw `glab api` paths, percent-encode the project path and any ref containing `/` (`group%2Fproject`, `feature%2Fbranch`), or use `:fullpath`/`-R` instead.

```bash
glab api projects/:fullpath/merge_requests/<iid>/notes | jq -r '
  (["author","date","body"],
  (.[] | select(.system == false) | [.author.username, .created_at[:10], .body[:80]])) | @tsv'
```

## Pipelines

Use `glab ci list -F json` for machine-readable pipeline data. Do not assume `glab ci view` supports JSON; check `glab ci view --help` before using flags.

```bash
glab ci list -F json | jq -r '
  (["id","status","ref","created"],
  (.[] | [.id, .status, .ref, .created_at[:10]])) | @tsv'
```

To inspect failed jobs without opening the interactive view, resolve a pipeline ID from `glab ci list -F json`, then use the GitLab API path for that project:

```bash
glab api projects/:fullpath/pipelines/<pipeline_id>/jobs | jq -r '
  (.[] | select(.status == "failed") | [.name, .stage, .failure_reason]) | @tsv'
```

## Merge Requests

When asked to draft or update an MR title and description:

1. Resolve the MR and target branch from `glab mr view <id> -F json` or the user's URL.
2. If there is no MR yet, resolve the base from the target branch, repo default branch, or user-provided base. Do not hardcode `master`.
3. Analyze all branch changes against the base:

   ```bash
   git log <base>...HEAD --oneline
   git diff <base>...HEAD --stat
   ```

4. Draft a title and description from actual branch changes. Use the user's requested structure. Do not invent release, rollback, or testing claims.
5. If the user explicitly asked to update the MR, run:

   ```bash
   glab mr update <iid> --title "<title>" --description "<description>"
   ```

6. Return the MR URL or the draft text.

## Write Operations

GitLab writes include creating or updating issues/MRs, comments, approvals, labels, merges, pipeline retries, pipeline cancels, and MR metadata updates. Run them only after explicit user request.

## Troubleshooting

- Unknown flag: run `glab <command> --help` and adjust to the installed version.
- Auth or host error: run `glab auth status` and report the failing host without printing tokens.
- API endpoint mismatch: run `glab api --help` and use documented placeholders such as `:fullpath`.

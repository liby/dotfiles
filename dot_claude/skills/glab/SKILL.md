---
name: glab
description: Analyze GitLab merge requests, issues, pipelines, and repos via `glab` CLI. Use when user mentions GitLab URLs, MR/issue numbers, or asks about GitLab content.
context: fork
allowed-tools:
  - Bash(glab:*)
  - Bash(jq:*)
  - Read
---

Use `glab` CLI for all GitLab operations. Use your training knowledge — run `glab <command> --help` when unsure.

The GitLab host is already configured via `glab auth login` — run `glab auth status` to discover it.

## URL Parsing

Extract group/project and number from GitLab URLs:
- `https://<host>/group/project/-/merge_requests/123` → `glab mr view 123 -R group/project`
- `https://<host>/group/project/-/issues/456` → `glab issue view 456 -R group/project`

## Structured Output

Use `-F json` + `jq` for structured data. Prefer `@tsv` for tabular output:

```bash
glab mr list -R group/project -F json | jq -r '
  (["!","title","author","updated"],
  (.[] | [.iid, .title, .author.username, .updated_at[:10]])) | @tsv'
```

For large API responses, redirect to temp file first:

```bash
glab api projects/:id/merge_requests/:iid/notes >/tmp/gl_notes.json \
  && jq -r '(["author","date","body"],
  (.[] | select(.system == false) | [.author.username, .created_at[:10], .body[:80]])) | @tsv' /tmp/gl_notes.json
```

## Pipelines

```bash
# View pipeline status for current branch
glab ci view

# List recent pipelines
glab ci list -F json | jq -r '
  (["id","status","ref","created"],
  (.[] | [.id, .status, .ref, .created_at[:10]])) | @tsv'

# View failed jobs
glab ci view -F json | jq -r '.jobs[] | select(.status == "failed") | [.name, .stage, .failure_reason] | @tsv'
```

## Merge Requests

MRs are auto-created when branches are pushed. Use `glab mr list` to find them, then `glab mr update` to set the title and description.

1. Analyze all changes in the branch (ALL commits vs base branch, not just the latest):
  ```bash
  git log master...HEAD --oneline
  git diff master...HEAD --stat
  ```
2. Find the auto-created MR:
  ```bash
  glab mr list --source-branch=$(git branch --show-current) -F json | jq '.[0] | {iid, title, web_url}'
  ```
3. Update the MR title and description. Title uses ticket number as prefix if present in branch name (e.g., `PLAT-123 Add email status check`), not conventional commit format. Description follows the structure the user requests, no speculative statements:
  ```bash
  glab mr update <iid> --title "<title>" --description "<description>"
  ```
4. Return the MR URL to the user.

## Write Operations

Only perform write operations (create MRs, comment, approve, merge) when the user **explicitly** asks. Default to read-only analysis.

## Troubleshooting

If `glab` commands fail, check: `glab auth status`
If API returns 401, the token may need refresh: `glab auth login`

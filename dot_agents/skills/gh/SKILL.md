---
name: gh
description: Operate GitHub through the `gh` CLI for GitHub issues, pull requests, repos, workflow data, comments, and GitHub-hosted Agent Skills. Use when the user gives a GitHub URL, `owner/repo#123`, asks about a GitHub issue/PR/workflow, or asks to preview/install/update a skill from GitHub. Not for GitLab URLs or local skill editing without a GitHub source.
allowed-tools:
  - Bash(gh:*)
  - Bash(git:*)
  - Bash(jq:*)
  - Read
---

Use `gh` for GitHub reads and writes. The rules below cover what `gh` does that its help does not make obvious.

## Before a call

Do not run `gh auth status` unless a `gh` command fails with an auth or host error. Report the failing account or host without printing tokens. On a git auth failure, diagnose with `gh auth status` first; do not run `gh auth setup-git` to "ensure" auth, because it rewrites Git's global credential-helper configuration.

Check an unfamiliar flag in that subcommand's help filtered to the flag, such as `gh pr merge --help | rg -- --match-head-commit`; whole help pages are large. `gh <command> --json` with no field list prints the fields that command accepts, so use it instead of guessing a field name.

These calls fail in ways that recur:

- `gh search issues` and `gh search prs` accept only `--state open|closed`; omit `--state` for both. Scope a search with `--repo owner/name` and pass each other qualifier as its own word. `gh` quotes a qualifier's value through the end of its argument and escapes quotes inside it: `'repo:cli/cli GH_HOST'` and `'repo:"cli/cli"'` become invalid queries, and `'GH_HOST in:title repo:cli/cli'` silently searches all of GitHub as `in:"title repo:cli/cli"`.
- `gh issue view` and `gh pr view` reject `--comments` together with `--json`.
- Quote every `gh api` path that contains `?`, `[`, or `*`; zsh otherwise aborts with `no matches found`.
- `gh api` prints an error body to stdout and exits non-zero. Filter with `--jq` so the call's exit status carries the HTTP error; without `set -o pipefail`, a pipeline takes its last command's exit status, so a pipe into `jq -r .content` prints `null` and exits 0.
- In `gh api graphql`, pass string variables with `-f`: `-F` converts a numeric value, such as a repository named `2048`, to an integer and the query fails.

## Read

Answer from the complete relevant set. Save context by selecting fields and filtering noise, not by sampling: raw `gh api` objects carry users, URLs, and metadata the question rarely needs, while TSV, JSON lines, and plain text of the same selected fields differ little in size. Use `@tsv` for short single-line fields and JSON lines or plain text for long bodies; if a body still goes through `@tsv`, strip its `\r` first, because `@tsv` escapes each one.

- **Facts and lists:** one call with `--json <fields> --jq`.
- **A file in a repository:** `gh api -H 'Accept: application/vnd.github.raw' 'repos/OWNER/REPO/contents/PATH?ref=REF'`. That response is the file itself, not JSON, so do not add `--jq`. The `.content` field is base64, larger, and needs a decoder in the pipe.
- **Conversation:** `gh issue view --json comments` and `gh pr view --json comments` return every comment. The default text view silently omits minimized comments, so request `author,authorAssociation,createdAt,isMinimized,minimizedReason,body`, skip only those minimized as spam or off-topic (compare `minimizedReason` case-insensitively; values include `SPAM`, `spam`, and `off-topic`), count what you skipped, and read every remaining body. Check the comment count before printing bodies: a thread of more than a few dozen comments usually exceeds what one tool result shows, so save the selected JSON once in the task's temporary directory and read it in order in chunks, then report how many comments were read and skipped.
- **Pull request review:** `gh pr view --comments` and `--json comments` omit inline review comments. Read review verdicts with `--json reviews,latestReviews` and inline threads with one GraphQL query, the only source of thread resolution; resolved threads carry earlier decisions, so keep the final `select` only when the question is about open feedback alone:

  ```bash
  gh api graphql --paginate -f owner=OWNER -f name=REPO -F n=NUMBER -f query='
    query($owner:String!,$name:String!,$n:Int!,$endCursor:String){repository(owner:$owner,name:$name){pullRequest(number:$n){
      reviewThreads(first:100,after:$endCursor){pageInfo{hasNextPage endCursor} nodes{id isResolved isOutdated path line
        comments(first:100){totalCount nodes{author{login} body}}}}}}}' \
    --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)'
  ```

  `--paginate` follows only the thread cursor, so a thread whose `comments.totalCount` exceeds 100 needs its remaining comments read through that thread's `id` with its own `comments` cursor.

- **Diff:** list changed paths with `gh api 'repos/OWNER/REPO/pulls/N/files' --paginate --jq '.[].filename'`, then read the patch with `gh pr diff --exclude` for lockfiles, generated, and vendored paths. Past 300 changed files `gh pr diff` fails with HTTP 406, even with `--name-only`; read each file's `.patch` from that API instead. The API lists at most 3000 files and omits `patch` for large file diffs, so compare its count with `gh pr view N --json changedFiles` and read any file it lacks from a local diff of the PR's base and head commits.
- **CI:** `gh run view <run-id> --json jobs` for job and step states, then `--log-failed` for the failed steps' logs. That log holds every failed step's complete output, hundreds of KB when a matrix fails together, so save it in the task's temporary directory and search it for `##[error]`, the lines Actions annotated as failures, before broader markers such as `FAIL` that can match every package in a failed build; read the lines around each hit, and treat a full `--log` the same way. Both refuse while any job in the run is still running, even for a job that already failed; read that job's log with `gh api --allow-escape-sequences 'repos/OWNER/REPO/actions/jobs/JOB/logs'`. For a PR, `gh pr checks N --json name,bucket,link` lists every check; a `link` outside `/actions/runs/` belongs to an external CI whose logs `gh` cannot read.
- **Repeated questions over the same data:** fetch once into the task's temporary directory and query that file instead of calling the API again.

## Pull Requests

At the first inspection of an existing PR, record its `url` and `headRefOid` with the evidence. A review or inspection from another workflow can serve as a later merge baseline only when it carries that exact URL and OID. `mergeable` reads `UNKNOWN` while GitHub is still computing it, which is not a conflict.

GitHub pending-review comments remain visible only to their author until the review is submitted. When that unpublished form satisfies the authorized outcome, create it with `gh api -X POST 'repos/OWNER/REPO/pulls/N/reviews' --input FILE`, omitting `event`, setting `commit_id` to the recorded `headRefOid`, and giving each `comments[]` entry `path`, `line`, `side`, and `body`; `gh pr review` always submits. Submitting the review is a separate publishing action. Do not treat a draft PR as an invisible saved draft.

A PR title and body describe the complete change against the resolved base. Resolve that base from the user's request, the branch's `branch.<name>.gh-merge-base` setting, or the repository default branch, never an assumed `main` or `master`. Read an existing PR's full patch with `gh pr diff` and its metadata with `gh pr view --json baseRefName,headRefName,headRefOid,url`; for a new PR read `git log <base>..HEAD` and `git diff <base>...HEAD`. Follow the repository PR template when one exists. Run `gh pr create` or `gh pr edit` only when Authority authorizes that write for that target, otherwise keep the text in chat, and return the final title and body, plus the PR URL after a write.

## Agent Skills From GitHub

Before the first `gh skill` command for preview, install, or update, load and follow the [GitHub-hosted Agent Skills workflow](references/agent-skills.md).

## Write Operations

GitHub writes include issue creation, comments, labels, closes, merges, releases, workflow dispatches, skill installs, and skill updates. Run them when Authority authorizes them; in a context without the shared rules, run a write only when the request plainly covers it and its effects are still undoable and no one else can see its result, or when the user's own direction or supplied text clears the effect it would otherwise stop for.

For `gh pr merge`, a merge that relies on a review or earlier inspection needs that inspection's recorded URL and `headRefOid`; stop if either is missing. Immediately before the write, refresh the PR, stop if its URL or `headRefOid` differs from the record, and pass the compared OID with `--match-head-commit`. Refetch afterwards and verify the same head OID and the resulting merge state.

GitHub renders every single newline in issue, PR, and comment bodies as a line break, so keep each paragraph on one line, and put an `@name` that should not notify anyone in backticks.

When creating public issues, PRs, or comments, mask personal information: hostnames, local directory paths, email addresses, repo URLs that should not be public, tokens, and raw debug output.

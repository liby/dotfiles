---
name: glab
description: Operate GitLab through the `glab` CLI for GitLab merge requests, issues, pipelines, discussions, repos, and MR descriptions. Use when the user gives a GitLab URL, asks about a GitLab MR/issue/pipeline, mentions `glab`, or asks to draft/update an MR description. Not for GitHub URLs or purely local git tasks that do not need GitLab issue, MR, pipeline, discussion, or repo data.
allowed-tools:
  - Bash
  - Read
metadata:
    gitlab-path: internal/commands/skills/bundled/assets/glab
    gitlab-project: https://gitlab.com/gitlab-org/cli
    gitlab-ref: refs/tags/v1.122.0
    gitlab-tree-sha: 8a278019df57649e100e308bf248f906f8ed9b7f
---

Use `glab` for GitLab reads and writes. The rules below cover what `glab` does that its help does not make obvious.

## Before a call

Do not run `glab auth status` unless a `glab` command fails with an auth or host error. Report the failing host.

`glab` sends each request, a `-R group/project` shorthand included, to the authenticated host of the current Git checkout, and otherwise to `gitlab.com`. A default host other than `gitlab.com`, set through `host` in glab's configuration or an environment variable such as `GITLAB_HOST`, receives all of them instead. A command that needs the checkout's project fails when no remote is on the host it would go to; with that default host in effect and remotes only on other hosts, the error names `GITLAB_HOST` even when glab's configuration set the default. For a project on another host or outside that checkout, pass `-R` with the full project URL to every command, `glab api` included, where the URL also fills `:id` and `:fullpath`; use `glab api --hostname` only for endpoints without a project. A request that reaches the wrong host need not name it: it answers 401, 403, or 404, or returns an unrelated project with the same path there; `glab config get host` prints the default host from whichever source set it, and nothing or `gitlab.com` when none is in effect.

Check an unfamiliar flag in that subcommand's help filtered to the flag, such as `glab mr merge --help | rg -- --sha`; whole help pages are large.

These calls fail in ways that recur:

- `glab api` has no `--jq`, and on an HTTP error it prints the error body to stdout and exits non-zero, so start the same shell command with `set -o pipefail;` before piping it into `jq`; otherwise the pipeline takes `jq`'s exit status and the error can come out as `null` with exit 0. Other commands print JSON with `-F json`, not `--json`, and accept `--jq` only together with `-F json`, and only where their help lists `-F --output`.
- Quote every `glab api` path that contains `?`, `[`, or `*`; zsh otherwise aborts with `no matches found`.
- `glab mr list` has no `--state`; it lists open MRs by default and takes `--all`, `--merged`, or `--closed`.
- `glab api` paths take the placeholders its help lists, such as `:fullpath` for the current project. Put any other value that contains `/`, such as a ref or file path, in the path as `:<name>` with `--placeholder <name>=<value>`, which encodes it as one segment; a hand-written literal needs `%2F`.
- `glab api -F` reads a value that starts with `@` as a file and parses one that starts with `[` or `{` as JSON, so send literal text, such as a body that starts with `@user`, with `-f`. Without `-X`, any field makes the request a `POST`; `-X GET` sends fields as query parameters. In a JSON body, bracketed field names such as `position[new_line]` are rejected; pass the object as JSON (`-F 'position={...}'`). A raw body sent with `--input` carries no `Content-Type`, and GitLab answered 415 without `-H 'Content-Type: application/json'`.
- `glab ci view` is an interactive TUI, and `glab ci trace` without a job argument opens a picker and on a running job streams until the job ends.
- `glab ci retry` takes a job ID or name, not a pipeline ID; retry a whole pipeline with `glab api -X POST projects/:id/pipelines/<id>/retry`.
- In `glab mr note resolve`, `reopen`, `update`, `delete`, `draft update`, and `draft delete`, the MR comes first and the discussion or note ID last, although their usage lines show the reverse.

## Read

Answer from the complete relevant set. Save context by selecting fields and filtering noise, not by sampling: raw API objects carry users, links, and metadata the question rarely needs, while TSV, JSON lines, and plain text of the same selected fields differ by a few percent. Use `@tsv` for short single-line fields and JSON lines or plain text for long bodies.

- **Facts and lists:** one call with `-F json --jq`, or `glab api` piped into `jq`.
- **A file in a repository:** `glab api 'projects/:fullpath/repository/files/:path/raw?ref=<ref>' --placeholder path=<file-path>` returns the file text.
- **Discussion:** `glab mr view --comments` hides system activity unless `--system-logs` is passed. Read a whole MR conversation through the `discussions` API with `--paginate`: it keeps each thread with its notes' `resolvable`, `resolved`, and diff `position`, while the `notes` endpoint flattens threads. Read every human note, count skipped system notes, and when the conversation is too large for one read, save it once and read it in order in chunks, reporting how many notes were read. For open review feedback only:

  ```bash
  set -o pipefail; glab api projects/:fullpath/merge_requests/<iid>/discussions --paginate --output ndjson | jq -c '
    select(any(.notes[]; .resolvable and (.resolved | not)))
    | {path: (.notes[0].position.new_path // "general"), line: (.notes[0].position | .new_line // .old_line),
       notes: [.notes[] | {author: .author.username, body}]}'
  ```

- **Diff:** list changed paths first with `set -o pipefail; glab api 'projects/:id/merge_requests/<iid>/diffs' --paginate --output ndjson | jq -c '{new_path, generated_file, collapsed, too_large}'`, then read `glab mr diff --raw` without lockfiles, generated, and vendored files. Both endpoints return limited results for an MR past GitLab's diff limits; read a path marked `collapsed` or `too_large` from local Git at the MR's `diff_refs`.
- **CI:** `glab ci get --merge-request <iid> --status failed --with-job-details -F json` names the failed jobs of the MR's head pipeline, looked up in the target project. When `head_pipeline.project_id` from `glab mr view <iid> -F json` names another project, as for a fork MR whose pipeline ran in the fork, `ci get` gets 404: query that project's pipeline, jobs, and traces. It lists runner jobs only: when the pipeline failed and no listed job without `allow_failure` did, read `projects/:id/pipelines/<id>/bridges` and repeat on each failed `downstream_pipeline.id`. Read a finished job's log with `glab api projects/:fullpath/jobs/<job-id>/trace`, with the numeric project ID in place of `:fullpath` for a pipeline in another project, and search it for the error rather than reading it whole.
- **Repeated questions over the same data:** fetch once into the task's temporary directory and query that file instead of calling the API again.

## Merge Requests

At the first inspection of an existing MR, record its `web_url` and `sha` with the evidence. A review or inspection from another workflow can serve as a later approval or merge baseline only when it carries that exact URL and SHA.

A GitLab draft MR is visible to the project, and creating it can run pipelines. The `draft` label does not make MR creation an unpublished staging step; when the user authorized only draft text, keep it in chat.

An MR title and description describe the complete change against the target branch. Resolve the MR's URL, head SHA, and target branch with `glab mr view <id> -F json`; without an MR, take the base from the user, the target branch, or the repository default branch, never an assumed `master`. Read `git log <base>..HEAD`, the complete `git diff <base>...HEAD`, and the repository's MR template under `.gitlab/merge_request_templates/` when one exists. Return the MR URL or the text.

When the user asked to update the MR, pass the title and description through quoted heredocs. Choose for each payload a delimiter of letters, digits, and underscores that does not occur as a complete line in that payload:

```bash
IFS= read -r MR_TITLE <<'MR_TITLE_END_7Q4'
<title>
MR_TITLE_END_7Q4
glab mr update <iid> --title "$MR_TITLE" --description-file - --yes <<'MR_DESCRIPTION_END_7Q4'
<description>
MR_DESCRIPTION_END_7Q4
```

On `mr create`, `mr update`, `issue create`, and `issue update`, `--description -` opens an editor; `--description-file -` reads stdin.

## Comments

`glab mr note create <iid>` reads a comment body from a quoted heredoc on stdin, with the delimiter rule above. `glab issue note` does not read stdin and opens an editor without `--message`, so pass `-m "$(cat <<'DELIM' ... DELIM)"`.

Refer to an issue, MR, or epic outside the text's own project by its full URL: short references such as `#123` and `!456` resolve against the project the text lives in.

Answer inside an existing MR thread with `glab mr note create <iid> --reply <discussion-id>`, which also accepts a unique 8-character prefix, instead of opening a new discussion. Issue threads have no reply flag: POST the body to `projects/:id/issues/<iid>/discussions/<discussion-id>/notes` with `-F body=@<file>`. After an uncertain result from a top-level MR comment, `glab mr note create --unique` reads the existing notes and posts only if none has the same body.

Pending review comments stay visible only to you until published; `glab mr note draft` creates, lists, updates, deletes, and publishes your own. `draft create --file <path> --line <n>` (a range `a:b`, or `--old-line`) anchors a comment to whichever diff version is latest when it runs. For a comment from an earlier inspection, POST it to the MR's `draft_notes` API with a `position` whose `base_sha`, `start_sha`, and `head_sha` are the `diff_refs` that inspection read, so a push in between cannot re-anchor it to lines nobody checked. Change a pending comment's body with `draft update`, which keeps its position; a raw `PUT` to `draft_notes` that omits `position` clears it on GitLab before 19.5. `draft publish <iid> --yes` publishes all of your pending comments on that MR; without `--yes` it prompts and fails when not run interactively.

## Write Operations

GitLab writes include creating or updating issues/MRs, comments, approvals, labels, merges, pipeline retries, pipeline cancels, and MR metadata updates. Run them when Authority authorizes them; in a context without the shared rules, run a write only when the request plainly covers it and its effects are still undoable and no one else can see its result, or when the user's own direction or supplied text clears the effect it would otherwise stop for.

For `mr approve` or `mr merge`, an action that relies on a review or earlier inspection needs that inspection's recorded URL and `sha`; stop if either is missing. Immediately before the write, refresh the MR, stop if its `web_url` or `sha` differs from the record, and pass the compared SHA with `--sha`; for merge, add `--auto-merge=false` unless the user explicitly requested auto-merge. Refetch afterwards and verify the same head SHA and the resulting approval or merge state.

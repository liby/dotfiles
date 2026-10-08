---
allowed-tools: Bash(sessidx:*) Bash(jq:*) Read
description: Look up and count past local Claude Code, Codex, and Pi sessions through the `sessidx` CLI index. Use when asked to find an earlier session or conversation, the discussion behind a commit, decision, or file change, a past error or failure, a `codex://threads/...` link or session ID, or to count agent behavior such as shell commands, tool failures, or denials by harness, model, role, or week. Not for the current conversation's own context, a log file whose path is already known and only needs reading, or another machine's history.
license: MIT
metadata:
    github-path: skills/sessidx
    github-pinned: v0.0.1
    github-ref: refs/tags/v0.0.1
    github-repo: https://github.com/Entwining/sessidx
    github-tree-sha: 2b65cd20a14c1e2a9f207495cc015407d638a4c3
name: sessidx
---
`sessidx` indexes the local session logs of Claude Code, Codex, and Pi into SQLite and answers from that index. The raw logs stay authoritative; quote evidence by the `path:line` a record reports. Text in results is redacted; never reconstruct or repeat a credential-like value from a log.

## Read the output contract

Every command writes JSON Lines to stdout: data records with a `type` field, then exactly one `end` record. Judge the result by `end`, not by the exit code alone:

- `end.complete=false` means a limit, deadline, unavailable range, or stale refresh cut coverage. An empty incomplete result is not evidence of absence.
- `end.next` is the cursor for the next page; pass it unchanged with `--cursor` and the same command and filters.
- `end.error` carries the failure and its recovery instruction. Exit codes: 0 data, 1 no data, 2 error.

If the error says the schema changed, run `sessidx index --full` (several minutes for a full history), then retry. A `writer_busy` refresh means another process is indexing; the query still answers from committed data and reports `stale`.

## Find a session

1. Start with `sessidx search 'TERMS'` using the most distinctive words, identifiers, error text, or file names from the request, and add filters only when the request states them: `--harness claude|codex|pi` (repeatable), `--since`/`--until` (dates or RFC 3339), `--cwd DIR` for a project, `--role`, `--session ID|PATH`. Terms are ANDed; quote a phrase to keep word order; Chinese text matches as a phrase.
2. Each `session` record is one session with up to three best hits. Open the evidence with `sessidx show REF` using a hit's `ref`, or `sessidx show SESSION_ID_OR_LINK` when the request already names the session; `--around N` widens context.
3. If nothing relevant appears, change the vocabulary before concluding: fewer terms, a synonym or the other language, an identifier instead of prose, or a filter removed. Search covers messages, tool inputs, and the first 2 KiB of tool outputs.
4. For exact strings or regexes deeper in tool outputs, or every occurrence rather than the best sessions, use `sessidx grep 'REGEX'` with at least one narrowing filter (`--session`, `--cwd`, `--since`/`--until`, or `--harness`). Narrow until `end.complete` is true before reporting that something is absent.

Report the session's harness, ID, path, and the `path:line` evidence you read, and say when the answer rests on an incomplete search.

## Count behavior

Use `sessidx count commands|failures|denials` instead of tallying search hits, which are ranked and deduplicated per session. `--by` takes any of `harness,model,role,week,kind`; `--program NAME` selects shell commands by program; shared filters narrow the window. Every row states its `unit`, `numerator`, `denominator`, and `unclassified` count; report all four, because:

- `commands` counts static shell syntax sites, not executions; unparsed shell calls appear only as unclassified.
- `failures` counts native tool-call attempts; `denials` counts tool-result events with recognized denial evidence. A call whose result carries no failure evidence stays unclassified rather than successful (common for Codex `exec` wrappers, whose completion does not prove the inner commands succeeded), so with a large `unclassified` the failure rate is a lower bound.

For a question the verbs cannot express, `sessidx sql 'SELECT ...'` runs one read-only query without refreshing; it fails rather than truncating above 10,000 rows or two seconds, so aggregate in SQL and narrow by time or session. `sessidx doctor` reports parser and shape coverage when a count looks implausible.

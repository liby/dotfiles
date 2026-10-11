---
allowed-tools: Bash(sessidx:*) Bash(jq:*) Read
description: Look up and count past local Claude Code, Codex, and Pi sessions through the `sessidx` CLI index. Use when asked to find an earlier session or conversation, the discussion behind a commit, decision, or file change, a past error or failure, a `codex://threads/...` link or session ID, or to count agent behavior such as shell commands, tool failures, or denials by agent, model, role, or week. Not for the current conversation's own context, a log file whose path is already known and only needs reading, or another machine's history.
license: MIT
metadata:
    github-path: skills/sessidx
    github-pinned: v0.0.4
    github-ref: refs/tags/v0.0.4
    github-repo: https://github.com/Entwining/sessidx
    github-tree-sha: e81e270c0a456fbdef005803d92ab224e4b788a1
name: sessidx
---
`sessidx` indexes the local session logs of Claude Code, Codex, and Pi into SQLite and answers from that index. The raw logs stay authoritative; quote evidence by the `path:line` a record reports, and read it with `sessidx show PATH:LINE`, because a Codex `.jsonl` path may exist on disk only as a compressed `.jsonl.zst`. Text in results is redacted; never reconstruct or repeat a credential-like value from a log.

## Read the output contract

Every command writes JSON Lines to stdout: data records with a `type` field, then exactly one `end` record. Judge the result by `end`, not by the exit code alone:

- `end.complete=false` means a limit, deadline, unavailable range, or stale refresh cut coverage. An empty incomplete result is not evidence of absence.
- `end.refresh.missing_roots` lists each absent session directory as the `AGENT=PATH` that `--root` accepts. One that never held indexed sessions, such as an agent the user does not run or `~/.codex/archived_sessions` before any thread is archived, leaves the result complete; one that disappeared after indexing makes the refresh stale.
- `end.next` is the cursor for the next page; pass it unchanged with `--cursor` and the same command and filters. `search` pages cover the first 100 ranked sessions; past them `next` is null with `complete=false`, so narrow the query to reach the rest.
- `end.error` carries the failure and its recovery instruction. Exit codes: 0 data, 1 no data, 2 error.

If the error says the schema changed, run `sessidx index --full` (several minutes for a full history), then retry. A `writer_busy` refresh means another process is indexing; the query still answers from committed data and reports `stale`. A `continuation` in `end.refresh` means the two-second refresh stopped before indexing everything, as on first use; run `sessidx index` once (several minutes for a full history), then retry.

## Find a session

1. Start with `sessidx search 'TERMS'` using the most distinctive words, identifiers, error text, or file names from the request, and add filters only when the request states them: `--agent claude|codex|pi` (repeatable), `--since`/`--until` (dates or RFC 3339), `--cwd DIR` for a project, `--role`, `--session-kind main|subagent` for sessions started on their own or spawned by another session (`unknown` when the log carries no evidence either way), `--session ID|PATH`. Terms are ANDed; quote a phrase to keep word order; Chinese text matches as a phrase.
2. Each `session` record is one session (one transcript file, with its `session_kind`, `parent_id`, `cwd`, and `started_at`) and up to three best hits. Open the evidence with `sessidx show REF` using a hit's `ref` (it includes 3 source lines on each side; `--around N` changes that), or read the whole session, a page at a time, with `sessidx show SESSION_ID_OR_LINK`. Each `record` is one source line as a redacted JSON object in `record`, shown once per role on that line; a hit is only the best match, so read around it before quoting. A Claude subagent is its own session, keyed by its agent ID, and its ID can repeat under another parent: when an ID names more than one transcript, `show` and `--session` fail and list their paths, so pass the path.
3. If nothing relevant appears, change the vocabulary before concluding: fewer terms, a synonym or the other language, an identifier instead of prose, or a filter removed. Search covers messages, tool inputs, and the first 2 KiB of tool outputs.
4. For exact strings or regexes deeper in tool outputs, or every occurrence rather than the best sessions, use `sessidx grep 'REGEX'` with at least one narrowing filter (`--session`, `--cwd`, `--since`/`--until`, or `--agent`). Narrow until `end.complete` is true before reporting that something is absent.

The current conversation can be indexed too. Exclude it only by a session ID or path you know is yours; recency, directory, and matching text do not identify it, because an older session or a subagent can repeat the request. Report the session's agent, ID, path, and the `path:line` evidence you read, and say when the answer rests on an incomplete search.

## Count behavior

Use `sessidx count commands|failures|denials` instead of tallying search hits, which are ranked and deduplicated per session. `--by` takes any of `agent,model,role,week,session_kind`, or no value for one total row; `--program NAME` selects shell commands by program; shared filters narrow the window. Each row's counts are named for what they count and add up to their population; report the population and its unknown part with any rate:

- `commands`: `sites` that parsed, of which `sites_without_program` have no literal program, and with `--program` `matching_sites`. Sites are static syntax, not executions. `unparsed_calls` are shell calls outside `sites` because their syntax did not parse.
- `failures`: `calls` = `failed` + `succeeded` + `outcome_unknown`. A call whose result carries no failure evidence has an unknown outcome rather than a successful one (common for Codex `exec` wrappers, whose completion does not prove the inner commands succeeded), so with a large `outcome_unknown` the failure rate `failed / calls` is a lower bound.
- `denials`: `results`, of which `denied` carry denial evidence, of which `denied_reason_unknown` have no known reason.
- With `--program`, `calls` or `results` hold only those that name the program, and `calls_with_unresolved_program` or `results_with_unresolved_program` count the others whose program is unknown and might be it.

For a question the verbs cannot express, `sessidx sql 'SELECT ...'` runs one read-only query without refreshing, so its `end.refresh` holds only `stale` and `writer_busy`; it fails rather than truncating above 10,000 rows or two seconds, so aggregate in SQL and narrow by time or session. Query `sessions`, `events`, `canonical_events` (events without copied history, which counts use), `call_outcomes`, `commands`, and `denials`; the other tables are index storage. `sessions` has one row per session with its `agent`, `session_id`, `parent_id`, `session_kind`, `path`, `cwd`, and `started_at`, so list sessions there rather than by ranking them. `events` carries each event's `agent`, `session_id`, and `path`, and reads `text` only when a query names it. List a relation's columns with `sessidx sql "SELECT name FROM pragma_table_info('events')"`. `sessidx doctor` reports parser and shape coverage when a count looks implausible.

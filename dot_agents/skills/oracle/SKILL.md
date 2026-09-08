---
description: 'Use Oracle only when the user explicitly requests Oracle, ChatGPT Pro, ChatGPT Deep Research, a ChatGPT Project consultation, continuation of an Oracle session, or Oracle API mode. Not for requests limited to other consultants, ordinary review or research, or inspection of existing ChatGPT content.'
allowed-tools:
    - Bash(oracle:*)
    - Read
    - Write
    - WebFetch
    - WebSearch
    - mcp__chrome-devtools__*
metadata:
    github-path: skills/oracle
    github-ref: refs/tags/v0.20.0
    github-repo: https://github.com/steipete/oracle
    github-tree-sha: c6ede997dad62e888ac9aeb7c83d4eba8abc596f
name: oracle
---
# Oracle

Use the installed `oracle` binary. Treat its answer as advisory and verify material claims against the code and primary sources.

## Default: keep the browser's model and effort

For an ordinary consultation, open a dedicated tab in the signed-in browser and retain its model and effort:

```bash
oracle --engine browser --browser-attach-running \
  --browser-model-strategy current --slug "<3-5 words>" \
  -p "<task>" --file "<path-or-glob>"
```

Omit model and thinking-time flags unless requested. The explicit `current` flag skips model selection, implicit Pro effort, and inherited `browser.thinkingTime` configuration. It inherits the new tab's selection, which need not be the newest available model. A preview's `requested` alias is not evidence of the active model. Report a visible label as an observation, not verified model selection.

Before an explicit model, latest-model, or effort request, load the Model and effort section of the [non-default modes contract](references/non-default-modes.md). Do not silently replace that request with browser defaults.

For a supplied ChatGPT Project, add `--chatgpt-url "<project-url>"`. Verify that the saved conversation retains that Project ID/path or visibly belongs to the requested Project; a generic `/c/<id>` URL alone does not prove membership.

If attach-running fails, ask the user to enable or approve Chrome remote debugging, or use the manual path below. Never copy a personal browser profile or target an existing unrelated tab.

## Authorization and context

An explicit browser consultation authorizes submitting its prompt and files to the requested ChatGPT target, including a same-task manual fallback. Ask again only if the recipient, material content, paid route, or another external effect changes. API mode requires separate, explicit billing consent. Ask the user to complete login, CAPTCHA, SSO, workspace selection, or another human check.

Never attach secrets, credential files, private keys, shell history, browser storage, real environment files, or a broad home-directory tree. Make a fresh prompt self-contained: exact question, relevant facts and attempts, constraints, desired output, and the smallest files containing the evidence. Use a follow-up when continuity matters.

## Submit and complete

For non-secret inputs whose expansion or contents need checking, add `--dry-run json` to the intended command and inspect the full `composerText` and attachments. This output contains the selected file contents; a browser summary reports only a count for inline files, and `--files-report` does not list them. A dry run proves parsing and bundle construction, not browser selection or completion. Confirm every required file is selected and every included file is intentional; bracketed paths can be glob patterns even when shell-quoted. If expansion selects the wrong set, stage byte-identical non-secret inputs under unambiguous temporary names and preview again. Correct the inputs before submitting, rather than requesting an abstract substitute. Narrow oversized bundles; use explicit dotfile paths and `!` exclusions.

Keep the process or session ID and follow the same run through finite waits. After detachment, compaction, a timeout, stale status, or ambiguous submission, inspect `oracle status` and `oracle session <id>` before doing anything that could resend. A `prompt-commit-timeout` may already have submitted. Use `oracle session <id> --live` to follow the bound page and `--harvest` to recover its current answer; use `--render` for a saved completed answer.

Accept completion only when the answer is non-empty and complete, belongs to this request's actual submitted turn, includes the required material, and satisfies the requested Project and any explicit model/effort requirements. Normal automated completion also requires terminal `completed` status. After recovery, verify the actual user turn and its corresponding answer: matched conversation identity alone does not bind the turn. If only the visible page establishes completion, report a manual UI observation with the saved conversation URL instead of claiming the automated controller completed.

- If the exact page remains unchanged at `Finalizing answer` across a finite observation, or appears finished after controller loss while harvest is unexpectedly empty, reload that same conversation at most once and recheck its user turn and answer. Account for any reload already performed by Oracle. Changing Thinking text or other progress means keep waiting.
- If harvest reports an identity mismatch, stop using that capture and resolve the exact saved conversation. Non-empty `--live`/`--harvest` output or stale `running` metadata alone does not prove completion or failure.
- If upload or send readiness times out, establish whether submission occurred first. Only an unsubmitted attempt may be retried with `--browser-bundle-files --browser-bundle-format auto`.

Use `--force` only after establishing that the worker, controller, and bound target are dead and the original conversation or answer cannot be recovered. While the requested consultation is pending, keep following it; do not substitute your own analysis for its result.

If automation cannot submit, run the original prompt and text-file arguments with `oracle --render-markdown`, inspect the rendered text, and submit it in the visible signed-in browser. Attach each original non-text file or a byte-preserving archive and verify readiness before sending. Preserve browser defaults unless selection was requested; verify any requested model/effort and Project, then require a completed answer to that turn and saved URL. A preceding failed session supplies no selection or completion evidence for this manual answer.

## Non-default modes

Before a browser follow-up, Deep Research run, explicitly billed API run, or upgrade/option/picker recovery, load the corresponding section of the [non-default modes contract](references/non-default-modes.md).

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
    github-ref: refs/tags/v0.21.1
    github-repo: https://github.com/steipete/oracle
    github-tree-sha: c6ede997dad62e888ac9aeb7c83d4eba8abc596f
name: oracle
---

Use the installed `oracle` binary. Treat the answer as advisory and verify material claims against the code and primary sources.

Before an explicit model, latest-model, or effort request, or an upgrade, option-rejection, or picker-routing recovery, load the Model and effort section of the [non-default modes contract](references/non-default-modes.md). Before a browser follow-up, a Deep Research run, or an explicitly billed API run, load its corresponding section. Do not silently replace such a request with browser defaults.

## Build the input

Authorization for a consultation, its recipient, and any paid route follows Authority; this skill adds no authorization of its own. Ask the user to complete login, CAPTCHA, SSO, workspace selection, or another human check.

Never attach secrets, credential files, private keys, shell history, browser storage, real environment files, or a broad home-directory tree. Make a fresh prompt self-contained: exact question, relevant facts and attempts, constraints, desired output, and the smallest files containing the evidence. Use a follow-up when continuity matters.

For non-secret inputs whose expansion or contents need checking, add `--dry-run json` to the intended command and inspect the full `composerText` and attachments. This output contains the selected file contents; a browser summary reports only a count for inline files, and `--files-report` does not list them. A dry run proves parsing and bundle construction, not browser selection or completion. Confirm every required file is selected and every included file is intentional; bracketed paths can be glob patterns even when shell-quoted. If expansion selects the wrong set, stage byte-identical non-secret inputs under unambiguous temporary names and preview again. Correct the inputs before submitting, rather than requesting an abstract substitute. Narrow oversized bundles; use explicit dotfile paths and `!` exclusions.

## Run

For an ordinary consultation, open a dedicated tab in the signed-in browser and retain its model and effort:

```bash
oracle --engine browser --browser-attach-running --browser-approval-wait 30m \
  --browser-model-strategy current --browser-capture-provider-native \
  --slug "<3-5 words>" -p "<task>" --file "<path-or-glob>"
```

`current` keeps the tab's model and effort. Omit model and thinking-time flags unless requested; asking to leave them unchanged is that default, not a selection request. With both omitted, `current` resolves the active model without opening the model picker or clicking a selection. It inherits the tab's selection, which need not be the newest model or the intended tier, and it neither warns about nor repairs a stale Instant or older selection. Report the inherited label as an observation, and when it is stale against the user's intent, say so and offer the explicit latest + Pro path instead of presenting the run as made at the intended tier.

`--browser-capture-provider-native` saves ChatGPT's verbatim conversation record and independent text digests as private session artifacts, including prior turns, without changing the returned answer. It supplies the fidelity evidence checked under Accept: the session metadata's `browser.providerNativeCapture.answerFidelity`, also printed in the run log as `[capture] ... answer fidelity: <value>`.

For a supplied ChatGPT Project, add `--chatgpt-url "<project-url>"`. Verify that the saved conversation retains that Project ID/path or visibly belongs to the requested Project; a generic `/c/<id>` URL alone does not prove membership.

Attaching raises Chrome's remote-debugging prompt, which only the user can allow, and every new attach raises it again. `--browser-approval-wait` keeps the run waiting for that click instead of failing after the short default wait; pass it on every browser attach, including the commands in the non-default modes contract. If attaching still fails, ask the user to enable remote debugging, or use the manual fallback below. Never copy a personal browser profile or submit into an existing unrelated tab.

A build that predates the upstream DOM fix cannot detect a submitted turn under ChatGPT's Chat/Work layout: the page no longer exposes `data-message-author-role`, so a run submits, then times out at `prompt-commit-timeout`, `--harvest` reports no submitted turn, and the answer can only be read from the saved conversation (upstream issue #517, fix PR #516). No release includes that fix yet (PR #516 is open); until one does, run an authorized consultation as usual but read the answer from the conversation URL instead of relying on the automated capture.

## Follow the run

Keep the process or session ID and follow the same run through finite waits. After detachment, compaction, a timeout, stale status, or ambiguous submission, inspect `oracle status` and `oracle session <id>` before doing anything that could resend. A `prompt-commit-timeout` may already have submitted. Use `oracle session <id> --live` to follow the bound page and `--harvest` to recover its current answer; use `--render` for a saved completed answer.

- If the exact page remains unchanged at `Finalizing answer` across a finite observation, or appears finished after controller loss while harvest is unexpectedly empty, reload that same conversation at most once and recheck its user turn and answer. Account for any reload already performed by Oracle. Changing Thinking text or other progress means keep waiting.
- If harvest reports an identity mismatch, stop using that capture and resolve the exact saved conversation. Non-empty `--live`/`--harvest` output or stale `running` metadata alone does not prove completion or failure.
- If upload or send readiness times out, establish whether submission occurred first. Only an attempt that did not submit and can no longer submit, because its process has exited or been stopped, may be retried with `--browser-bundle-files --browser-bundle-format auto`.

Use `--force` only after establishing that the worker, controller, and bound target are dead and the original conversation or answer cannot be recovered. While the requested consultation is pending, keep following it; do not substitute your own analysis for its result.

## Accept and report

Accept the result only when all of these hold:

- a normal automated run has terminal `completed` status;
- the answer is non-empty and complete, includes the required material, and satisfies the requested Project and any explicit model/effort requirements;
- the answer belongs to this request's actual submitted turn; matched conversation identity alone does not bind it, including for a saved or recovered session;
- when capture is enabled, `browser.providerNativeCapture.answerFidelity` is one of: `matched` on the active branch's assistant message; `divergent` reconciled against that message's text in `~/.oracle/sessions/<session-id>/artifacts/conversation-<id>-raw.json`, where a difference limited to the page's rendering (padded table columns, heading markers, file-citation chips) is the same answer, any other difference makes the provider record the answer, and a missing record or message leaves the result unresolved; or `unknown` for a Deep Research report without an assistant message ID. Any other `unknown` is unresolved.

Report the inherited model/effort label as an observation, never as verified selection. Report a reconciled `divergent` result as such rather than as `matched`, and do not claim provider-native fidelity when it is `unknown` or missing. If only the visible page establishes completion, report a manual UI observation with the saved conversation URL instead of claiming the automated controller completed.

## Manual fallback

If automation did not submit and can no longer submit, established as under Follow the run, run the original prompt and text-file arguments with `oracle --render-markdown`, inspect the rendered text, and submit it in a new tab of the signed-in browser opened at the requested target, such as the supplied Project URL. Attach each original non-text file or a byte-preserving archive and verify readiness before sending. Preserve browser defaults unless selection was requested; verify any requested model/effort and Project, then require a completed answer to that turn and a saved URL. A preceding failed session supplies no selection or completion evidence for this manual answer. Apply the acceptance checklist except the automated-completion and provider-native fidelity items, which do not apply to a manual turn.

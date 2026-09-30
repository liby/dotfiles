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
    github-ref: refs/tags/v0.21.3
    github-repo: https://github.com/steipete/oracle
    github-tree-sha: c6ede997dad62e888ac9aeb7c83d4eba8abc596f
name: oracle
---

Use the installed `oracle` binary. Preserve the ordinary browser route; explicit choices and recovery are separate branches.

Before an explicit model, latest-model, or effort request, or an upgrade, option-rejection, or picker-routing recovery, load the Model and effort section of the [non-default modes contract](references/non-default-modes.md). Before a browser follow-up, Deep Research run, or explicitly billed API run, load its corresponding section.

Before recovering a submission, connection, upload, or capture failure, or accepting a provider capture whose fidelity is not `matched`, read the [recovery contract](references/recovery.md). This includes resumed or stale sessions and manual fallback; load it before harvest, reload, retry, force, or another submission. An uncertain submission never authorizes a resend.

## Build the input

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

`--browser-capture-provider-native` saves ChatGPT's verbatim conversation record and independent text digests as private session artifacts, including prior turns, without changing the returned answer. It supplies the fidelity evidence required to accept the result: the session metadata's `browser.providerNativeCapture.answerFidelity`, also printed in the run log as `[capture] ... answer fidelity: <value>`.

For a supplied ChatGPT Project, add `--chatgpt-url "<project-url>"`. Verify that the saved conversation retains that Project ID/path or visibly belongs to the requested Project; a generic `/c/<id>` URL alone does not prove membership.

Attaching raises Chrome's remote-debugging prompt, which only the user can allow, and every new attach raises it again. `--browser-approval-wait` keeps the run waiting for that click instead of failing after the short default wait; pass it on every browser attach, including the commands in the non-default modes contract. When the page shows a login, CAPTCHA, SSO, workspace selection, or another human check, ask the user to complete it. If attaching still fails, ask the user to enable remote debugging, or use the [manual fallback](references/recovery.md#manual-fallback). Never copy a personal browser profile or submit into an existing unrelated tab.

## Follow and accept the result

Keep the process or session ID and follow that same run through finite waits. If status, submission, or capture becomes uncertain, load the recovery contract and establish what happened to the bound conversation before acting. Wait for the requested consultation; do not replace a pending result with your own answer.

Accept a normal automated result only when its status is terminal `completed`, its answer is non-empty and complete, and it belongs to this request's actual submitted user turn. Verify any requested Project, model, or effort separately. A conversation URL, elapsed wait, non-empty output, or parent linkage alone does not prove those constraints.

With provider capture enabled, require `matched` fidelity on the active branch's assistant message, or follow the recovery contract's reconciliation before accepting another fidelity value. Report the inherited model/effort label as an observation. Report a reconciled `divergent` result as divergent. If only the saved conversation's visible answer establishes completion, report manual UI evidence and its URL; do not claim the automated controller completed or provider-native fidelity was verified.

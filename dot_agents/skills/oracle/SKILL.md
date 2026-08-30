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
    github-ref: refs/tags/v0.18.0
    github-repo: https://github.com/steipete/oracle
    github-tree-sha: 26cca2ea90a18f55ea56bddd7e5fb318a67f466c
name: oracle
---
# Oracle

Use the reviewed globally installed `oracle` binary, not an unpinned `npx -y`
download. Treat its answer as advisory and verify material claims against
authoritative sources, repository behavior, and tests.

## Default: latest reviewed ChatGPT model with Pro effort

For the reviewed Oracle release, use the explicit GPT-5.6 Sol browser target
with the independent `Pro` effort:

```bash
oracle --engine browser --browser-attach-running \
  --browser-model-strategy select --model gpt-5.6-sol \
  --browser-thinking-time pro --slug "<3-5 words>" \
  -p "<task>" --file "<path-or-glob>"
```

The model slug pins the latest ChatGPT model verified for this CLI release;
`Pro` is a separate effort selection. In v0.18.0 the generic current-Pro aliases
also resolve to GPT-5.6 Sol, but they intentionally float with ChatGPT. Keep the
model and effort flags explicit, let Oracle open a dedicated tab, and run any
other consultant separately through its native route.

For a supplied ChatGPT Project, add `--chatgpt-url "<project-url>"`. Completion
must retain that Project ID/path in the conversation URL or visibly confirm
membership in the target Project. A generic `/c/<id>` URL or fallback to the
ChatGPT home page leaves Project placement unverified.

If attach-running fails, ask the user to enable or approve Chrome remote
debugging, or use the manual path below. Never copy a personal browser profile
or target an existing tab.

## Authorization and context

An explicit request for Oracle's default browser consultation, ChatGPT Pro, Deep
Research, or a ChatGPT Project consultation authorizes the requested
subscription-backed browser run, model selection, and supplied Project target.
That authorization carries through a same-task manual fallback which sends the
same reviewed prompt and attachments to the same target; do not ask again unless
the recipient, material content, paid route, or another external effect changes.
API mode requires separate, explicit billing consent.

Never attach secrets, credential files, private keys, shell history, browser
storage, real environment files, or a broad home-directory tree. Ask the user
to complete login, CAPTCHA, SSO, workspace selection, or another human check in
the visible browser.

A fresh root has no reliable task context beyond what you provide; account and
Project memory may add context. Make the prompt self-contained with the exact
question, verified facts, attempts and verbatim errors, constraints, desired
output, and the smallest files containing the evidence. Use a follow-up when
continuity matters.

## Run and prove

Preview directories, globs, generated or unfamiliar paths, and inputs of
uncertain expansion or size by adding `--dry-run summary --files-report` to the
exact root command above. The preview must parse every selected flag and report
`target=GPT-5.6 Sol; requested=gpt-5.6-sol` without calling a model.

Every included file must be intentional. Narrow an oversized bundle rather than
raising its limit; use explicit dotfile paths and `!` exclusions. If attachment
upload or send-button readiness times out, retry once with
`--browser-bundle-files --browser-bundle-format auto`.

Before submitting a review request, confirm that every material requested file
or attachment will be present in the submitted turn. If one is absent, do not
start an abstract substitute; attach it in the same conversation, then request
the artifact-specific review.

Wait on the running process without fixed sleeps or repeated polling. Treat a
`prompt-commit-timeout` as possibly submitted. After it, detachment, resumption,
compaction, a stale or finalizing controller, or a duplicate-running guard,
inspect the exact existing session and saved conversation before resending or
starting another: use `oracle status`, then `oracle session <id>` to follow its
worker or saved log. Use `--live` only to tail the bound browser tab,
`--harvest` to snapshot or recover its answer, and `--render` after completion.

Accept a fresh automated Pro result only when:

- the session is terminal `completed` with a non-empty answer or artifact;
- model-selection evidence records `requestedKey=gpt-5.6-sol`,
  `target=GPT-5.6 Sol`, `resolvedLabel=GPT-5.6 Sol`, `strategy=select`, and
  `verified=yes`;
- the browser log separately confirms `Thinking time: Pro`; this selection is
  fail-closed; and
- any supplied Project passes the Project-placement check above; and
- the submitted turn contains every material requested file or attachment.

If the exact bound page remains unchanged at `Finalizing answer` across one
finite observation, or after controller loss looks completed while harvest
remains unexpectedly empty, reload it at most once and recheck the same session;
any other Thinking state or observed progress means keep waiting. A UI-visible
answer after reload may be surfaced as a manual UI observation, but does not
establish automated completion. In reviewed Oracle v0.18.0, missing-tab recovery
does not bind the recovered user turn to this session and cannot override stale
automated status; a separately verified visible answer remains a manual UI
observation.
Ordinary `--live` or `--harvest` output from a still-bound tab, Thinking UI,
command launch, detachment, timeout, or stale `running` metadata do not establish
completion. Use `--force` only when the worker, controller, and bound browser
target are dead and the exact conversation or its output remains unrecoverable.
While a run is pending or unrecovered, report that state; do not substitute the
current agent's analysis for the requested second opinion.

If automation cannot submit, rerun the original prompt and text-file arguments
with `oracle --render-markdown`, inspect the rendered text, and submit it in the
visible signed-in browser. Separately attach each original non-text file or a
byte-preserving archive, and verify attachment readiness before sending. Verify
the visible model version, `Pro` effort, and the Project; then require a visible
completed answer and saved conversation URL. Report these as manual UI
observations only.
A preceding failed Oracle session supplies no picker, model, or completion
evidence for the manually submitted answer.

## Non-default modes

Before a browser follow-up, Deep Research run, explicitly billed API run, or
version/picker recovery, load the corresponding section of the
[non-default modes contract](references/non-default-modes.md). Keep the API
billing gate in Authorization and context in force before loading that contract.

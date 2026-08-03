---
description: 'Use Oracle only when the user explicitly requests Oracle, ChatGPT Pro, ChatGPT Deep Research, a ChatGPT Project consultation, continuation of an Oracle session, or Oracle API mode. Not for requests limited to other consultants, ordinary review or research, or inspection of existing ChatGPT content.'
allowed-tools:
    - Bash(oracle:*)
metadata:
    github-path: skills/oracle
    github-ref: refs/tags/v0.16.1
    github-repo: https://github.com/steipete/oracle
    github-tree-sha: 0bc3e9fcbffa218ccf8745a3ce8af0e50c9aec4f
name: oracle
---
# Oracle

Use the reviewed globally installed `oracle` binary, not an unpinned `npx -y`
download. Treat its answer as advisory and verify material claims against
authoritative sources, repository behavior, and tests.

## Default: current ChatGPT Pro

Use the semantic `gpt-5-pro` route with the current Pro `extended` effort:

```bash
oracle --engine browser --browser-attach-running \
  --browser-model-strategy select --model gpt-5-pro \
  --browser-thinking-time extended --slug "<3-5 words>" \
  -p "<task>" --file "<path-or-glob>"
```

The alias selects ChatGPT's current `Pro` picker, not a fixed version. Do not
inherit or substitute another model or effort here; run any other consultant
separately through its native route. Let Oracle open a dedicated tab.

For a supplied ChatGPT Project, add `--chatgpt-url "<project-url>"`. Completion
must retain that Project ID/path in the conversation URL or visibly confirm
membership in the target Project. A generic `/c/<id>` URL or fallback to the
ChatGPT home page leaves Project placement unverified.

If attach-running fails, ask the user to enable or approve Chrome remote
debugging, or use the manual path below. Never copy a personal browser profile
or target an existing tab.

## Authorization and context

An explicit request to consult ChatGPT Pro or Deep Research authorizes the
requested subscription-backed browser run, model selection, and Project target.
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
uncertain expansion or size:

```bash
oracle --dry-run summary --files-report \
  -p "<task>" --file "<path-or-glob>"
```

Every included file must be intentional. Narrow an oversized bundle rather than
raising its limit; use explicit dotfile paths and `!` exclusions. If attachment
upload or send-button readiness times out, retry once with
`--browser-bundle-files --browser-bundle-format auto`.

Wait on the running process without fixed sleeps or repeated polling. After
detachment, resumption, compaction, or a stale controller, inspect the existing
session before starting another: use `oracle status`; while it runs, use
`oracle session <id> --live`; use `--harvest` when the page has an unsaved
answer, or `--render` after completion.

Accept a fresh automated Pro result only when:

- the session is terminal `completed` with a non-empty answer or artifact;
- the CLI records a Pro picker resolution, currently `resolved=Pro`
  (`resolvedLabel=Pro` in metadata), with `strategy=select` and `verified=yes`;
- the CLI's fail-closed Pro Extended selection passes; and
- any supplied Project passes the Project-placement check above.

After controller loss, non-empty recovered output plus
`browser.harvest.state=completed` from `--live` or `--harvest` satisfies the
first condition for the same verified session even if its top-level status is
stale. Stale status alone remains insufficient.

Thinking UI, a detached command, a timeout, or stale `running` metadata is not
completion. While a run is pending or unrecovered, report that state; do not
substitute the current agent's analysis for the requested second opinion.

If automation cannot submit, rerun the original prompt and text-file arguments
with `oracle --render-markdown`, inspect the rendered text, and submit it in the
visible signed-in browser. Separately attach each original non-text file or a
byte-preserving archive, and verify attachment readiness before sending. Verify
visible `Pro`, extended effort, and the Project; then require a visible completed
answer and saved conversation URL. Report these as manual UI observations only.
A preceding failed Oracle session supplies no picker, model, or completion
evidence for the manually submitted answer.

## Browser follow-up

Use repeated `--browser-follow-up "<message>"` options for planned turns in the
root run. To continue later:

```bash
oracle --followup "<root-session-id>" -p "<message>"
```

Add `--browser-archive never` when continuity is expected. A browser follow-up
is valid when the verified Pro root completed, the child references that parent
and its exact saved conversation URL, and the child completes with a non-empty
answer. Its model selection is normally skipped and unverified; do not apply
the fresh-root picker gate.

Never guess a conversation from open tabs. If continuity is essential and
Oracle cannot recover the URL, stop and report the gap; otherwise start a fresh,
self-contained root in the requested Project.

## Deep Research

Use `--browser-research deep` only when explicitly requested. Keep the browser,
attach-running, semantic Pro, and Project route, but omit
`--browser-thinking-time` and do not combine it with `--browser-follow-up`.
Require terminal completion, a non-empty report, and usable citations.

## Explicit API mode

After explicit API-billing consent, inspect current verbose help and preflight
only the requested model. Verify that `--route` matches the provider covered by
the consent and pin that provider with current CLI flags when billing or data
boundaries differ. Run with explicit `--engine api` and `--model`. Pro API runs
detach by default: add `--wait`, or inspect an already detached run with
`oracle session <id>`; a returned session ID is still pending.

API `--followup` applies to supported OpenAI or Azure Responses runs. Verify
response/session lineage, the requested model, and terminal output; browser
picker and conversation-URL gates do not apply. Avoid printing credentials,
hardcoded provider catalogs, or arbitrary timeouts.

## Version boundary

Inspect version and verbose help after install or upgrade, option rejection, or
picker-routing failure. If the installed version differs from the reviewed
upstream ref, verify the release and relevant source before changing this skill;
do not add a compatibility branch without an observed caller.

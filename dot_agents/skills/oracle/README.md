# Oracle skill: local patches on upstream

`SKILL.md` tracks the upstream ref in its frontmatter. `gh skill update` replaces
the upstream file and can delete this ledger, so recover the ledger from git,
compare the new upstream behavior, and reapply only the patches that still have
an observed purpose.

## Keep after upstream updates

- **ChatGPT Pro in running Chrome**: default to `--browser-attach-running` plus
  the floating `--model gpt-5-pro` alias, which selects ChatGPT's current Pro
  picker instead of pinning a generation or inheriting the tab's current model.
- **Attach preflight and fallback**: check port 9222, let attach-running open a
  dedicated tab, and use `--copy-profile` only when nothing listens.
- **Local authorization**: browser subscription runs are pre-authorized for an
  explicit second-model request; API billing still needs explicit consent.
- **Existing-tab boundary**: `--browser-tab` still depends on HTTP `/json/list`;
  omit it when that endpoint returns 404 even if the browser WebSocket works.
- **Preview boundary**: inspect every file bundle before sending it, and strip
  banner lines before piping `--dry-run json` output to `jq`.
- **Follow-up boundary**: reopen only a real conversation URL from the session;
  recover or ask when it is missing, never guess from open tabs.
- **Completion gate**: wait for an answer, terminal error, or user stop instead
  of replacing a pending second opinion with the current agent's inference.
- **Local CLI and style**: prefer the reviewed global `oracle` binary, canonical
  flags, `--perf-trace-path "$(mktemp)"`, and ASCII punctuation.

## Reworked for v0.16.0

- Use only the floating `gpt-5-pro` alias with no thinking-time flag for the
  current ChatGPT Pro target, now GPT-5.6 Sol Pro. Stop instead of substituting
  another model when Pro is unavailable.
- Remove the npm 0.15.2 compatibility section after current help and browser
  runs resolve `gpt-5-pro` correctly.
- Keep the canonical `--render-markdown --copy-markdown` flags.

The old 1Password fallback and personal checkout debugging remain retired
upstream and need no local patch.

# Oracle skill: local patches on top of upstream

`SKILL.md` comes from [steipete/oracle](https://github.com/steipete/oracle) (ref pinned in frontmatter); an upstream update overwrites the whole file and deletes every local patch. After updating: diff against the last pre-update commit, re-apply everything below, update this list. Each patch guards a failure that actually happened; don't drop one because upstream's wording looks cleaner.

## Re-apply after every upstream update

- **Attach to running Chrome** (`--browser-attach-running`; upstream launches a fresh Chrome): a fresh automation Chrome has no ChatGPT login. Preflight `lsof -nP -iTCP:9222 -sTCP:LISTEN`; `--copy-profile` only when nothing listens.
- **Pin model + effort per run** (`--model gpt-5.5-pro --browser-thinking-time extended`): relying on the tab's standing ChatGPT default (`--browser-model-strategy current`) breaks when that default drifts. `--browser-thinking-time` is hidden from `--help --verbose` but registered in `bin/oracle-cli.js`; Pro + `extended` fails closed if the effort control is missing.
- **Known Pitfalls section**: `--browser-tab current` resolves tabs via `CDP.List` (HTTP `/json/list`), which newer approved remote-debugging Chrome 404s while the browser WebSocket still works; the symptom is a generic `browser-automation` error. Omit `--browser-tab`.
- **Local authorization section**: pre-authorizes browser mode on this machine so agents stop re-asking per run; API runs still need explicit consent (API billing, not the ChatGPT subscription).
- **`--dry-run json` jq trap**: banner lines precede the JSON body; piping to `jq` fails. Extract from the first `{`.
- **`--followup` needs a real conversation URL**: the CLI only navigates to the URL stored in session metadata and fails clean when it is missing (`followup.js` sets `browserTabRef: null`, never picks a tab). The incident was an agent then guessing a URL from open tabs and posting into an unrelated conversation: recover the URL from session artifacts or the user, never guess. v0.15.2 ([#284](https://github.com/steipete/oracle/issues/284)) improves URL persistence; project-scoped chats can still miss it.
- **Completion gate**: a timeout or quiet terminal is not evidence Oracle has no result (GPT Pro runs 7-10+ min); keep reattaching (`oracle status`, `oracle session <id> --render`) instead of answering from the agent's own inference.
- **Style**: "GPT Pro" in prose, concrete model id only in commands; `--perf-trace-path "$(mktemp)"` (validator rejects fixed `/tmp` paths); ASCII punctuation.

## Do not reintroduce

- 1Password `op item get` API-key fallback and `~/Projects/oracle` checkout debugging: upstream author's personal content, removed upstream in v0.15.2 ([#292](https://github.com/steipete/oracle/issues/292)).

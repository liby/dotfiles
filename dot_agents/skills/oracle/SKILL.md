---
description: 'Oracle second-model review: bundle prompts/files, debug, refactor, design-check.'
metadata:
    github-path: skills/oracle
    github-ref: refs/tags/v0.15.0
    github-repo: https://github.com/steipete/oracle
    github-tree-sha: c89f61005e0156cc0c106de1e2f0bbdd309c9a5c
name: oracle
---
# Oracle (CLI) — best use

Oracle bundles your prompt + selected files into one “one-shot” request so another model can answer with real repo context (API or browser automation). Treat outputs as advisory: verify against the codebase + tests.

## Main use case (browser, GPT Pro)

Default workflow here: `--engine browser` with GPT Pro in ChatGPT. This is the “human in the loop” path: it can take ~10 minutes to ~1 hour; expect a stored session you can reattach to.

Recommended defaults:

- Engine + browser: `--engine browser --browser-attach-running --browser-tab current`
- Model: `--browser-model-strategy current` leaves the picker alone, so the run uses whatever the ChatGPT tab already shows. Pick GPT Pro + Pro extended in the tab before running; the `--model` flag is inert here (only the default `select` strategy reads it).
- ChatGPT target: reuses the active tab; pass `--chatgpt-url "<project-url>"` only to force a specific Project.
- Fallback: `--copy-profile` when no running Chrome is attachable (see Engines).
- Attachments: directories/globs + excludes; avoid secrets.

## Local authorization

The user has explicitly authorized this skill to use Oracle browser mode against the running Chrome (`--browser-attach-running`, `--browser-tab`, `--browser-model-strategy current`, `--chatgpt-url`) and `--copy-profile "$HOME/Library/Application Support/Google/Chrome"` as fallback, when the requested task is to consult ChatGPT Web, GPT Pro, or Deep Research from Codex or Claude Code.

- Do not ask for separate permission just to use `--engine browser`, `--browser-attach-running`, `--browser-tab current`, or `--copy-profile` on this machine.
- Still preview attached file sets with `--dry-run` and `--files-report` when files or globs are involved.
- Still avoid secrets, private key files, credential files, shell history, browser storage dumps, and broad home-directory uploads.
- If ChatGPT requires login, captcha, SSO, workspace selection, or manual verification, stop and ask the user to complete that step in the visible browser.
- API runs still require explicit user consent because they use API billing rather than the ChatGPT Web subscription.

## Golden path (fast + reliable)

1. Pick a tight file set (fewest files that still contain the truth).
2. Preview what you’re about to send (`--dry-run` + `--files-report` when needed).
3. Run in browser mode (attach to the running Chrome; preflight first) for the usual GPT Pro ChatGPT workflow; use API only when you explicitly want it.
4. If the run detaches/timeouts: reattach to the stored session (don’t re-run).

## Commands (preferred)

- Show help (once/session):
  - `npx -y @steipete/oracle --help`

- Preview (no tokens):
  - `npx -y @steipete/oracle --dry-run summary -p "<task>" --file "src/**" --file "!**/*.test.*"`
  - `npx -y @steipete/oracle --dry-run full -p "<task>" --file "src/**"`

- Token/cost sanity:
  - `npx -y @steipete/oracle --dry-run summary --files-report -p "<task>" --file "src/**"`

- Startup/perf trace:
  - `npx -y @steipete/oracle --perf-trace --perf-trace-path /tmp/oracle-perf.json --dry-run summary -p "<task>" --file "src/**"`
  - Use when CLI startup or time-to-first-output feels slow; inspect `first-output` and `exit`.

- Preflight the attach target (Chrome DevTools port up?):
  - `lsof -nP -iTCP:9222 -sTCP:LISTEN` (empty output means use the `--copy-profile` fallback instead).
- Browser run (main path; long-running is normal):
  - `npx -y @steipete/oracle --engine browser --browser-attach-running --browser-tab current --browser-model-strategy current -p "<task>" --file "src/**"`
  - Fallback when nothing is listening (launches a throwaway signed-in Chrome and switches the picker via `--model`; pass the current Pro model id, e.g. `gpt-5.5-pro`):
    - `npx -y @steipete/oracle --engine browser --model gpt-5.5-pro --copy-profile "$HOME/Library/Application Support/Google/Chrome" -p "<task>" --file "src/**"`

- Manual paste fallback (assemble bundle, copy to clipboard):
  - `npx -y @steipete/oracle --render --copy -p "<task>" --file "src/**"`
  - Note: `--copy` is a hidden alias for `--copy-markdown`.

## Attaching files (`--file`)

`--file` accepts files, directories, and globs. You can pass it multiple times; entries can be comma-separated.

- Include:
  - `--file "src/**"` (directory glob)
  - `--file src/index.ts` (literal file)
  - `--file docs --file README.md` (literal directory + file)

- Exclude (prefix with `!`):
  - `--file "src/**" --file "!src/**/*.test.ts" --file "!**/*.snap"`

- Defaults (important behavior from the implementation):
  - Default-ignored dirs: `node_modules`, `dist`, `coverage`, `.git`, `.turbo`, `.next`, `build`, `tmp` (skipped unless you explicitly pass them as literal dirs/files).
  - Honors `.gitignore` when expanding globs.
  - Does not follow symlinks (glob expansion uses `followSymbolicLinks: false`).
  - Dotfiles are filtered unless you explicitly opt in with a pattern that includes a dot-segment (e.g. `--file ".github/**"`).
  - Default cap: files > 1 MB are rejected unless you raise `ORACLE_MAX_FILE_SIZE_BYTES` or `maxFileSizeBytes` in `~/.oracle/config.json`.

## Budget + observability

- Target: keep total input under ~196k tokens.
- Use `--files-report` (and/or `--dry-run json`) to spot the token hogs before spending.
- Use `--perf-trace` / `ORACLE_PERF_TRACE=1` for startup and first-output timing. Traces redact prompts, tokens, keys, cookies, and inline cookie payloads; detached API children write a session-suffixed sidecar trace.
- If you need hidden/advanced knobs: `npx -y @steipete/oracle --help --verbose`.

## Engines (API vs browser)

- Auto-pick: uses `api` when `OPENAI_API_KEY` is set, otherwise `browser`.
- Browser engine supports GPT + Gemini only; use `--engine api` for Claude/Grok/Codex or multi-model runs.
- `--browser-attach-running` (default browser path here): attaches to an already-running Chrome instead of launching one (defaults to `127.0.0.1:9222`; `--remote-chrome <host:port>` hints a different host). Pair with `--browser-tab current` to drive the live ChatGPT tab (a ref can also be a target id, full URL, or title substring). Preflight the port (see Commands); if nothing listens, fall back to `--copy-profile`.
- `--browser-model-strategy select|current|ignore`: `select` (Oracle's default) switches the picker to `--model`; `current` keeps whatever model the tab has selected, which is how a hand-set GPT Pro + Pro extended survives (`--model` is then ignored); `ignore` skips the picker entirely.
- `--copy-profile <chrome-user-data-dir>` (fallback): reuse your **already signed-in** Chrome session with no manual login — copies the profile to a throwaway dir, launches with the real Keychain so its cookies decrypt, runs, then always deletes the copy. Failed/incomplete runs are deleted too, so they cannot be kept, reattached, or sent to an existing/remote browser. e.g. `oracle --engine browser --copy-profile "$HOME/Library/Application Support/Google/Chrome" -p "<task>"`. macOS/Linux; needs `rsync`.
- **API runs require explicit user consent** before starting because they incur usage costs.
- Browser attachments:
  - `--browser-attachments auto|never|always` (auto pastes inline up to ~60k chars then uploads).
  - Add `--browser-bundle-files --browser-bundle-format auto|zip` to upload many files as one bundle; ZIP bundles preserve original file bytes.
- Remote browser host (signed-in machine runs automation):
  - Host: `oracle serve --host 0.0.0.0 --port 9473 --token <secret>`
  - Client: `oracle --engine browser --remote-host <host:port> --remote-token <secret> -p "<task>" --file "src/**"`

## API preflight

- API runs require explicit user consent and cost money.
- Before API runs, check provider readiness without printing secrets:
  - `oracle doctor --providers --models gpt-5.4,claude-4.6-sonnet,gemini-3-pro`
  - `oracle --preflight --models gpt-5.4,gemini-3-pro`
  - `oracle --route --model gpt-5.4`
- If the user wants first-party OpenAI, pass `--provider openai` or `--no-azure`. This prevents exported Azure env/config from hijacking the route:
  - `oracle --provider openai --engine api --model gpt-5.5-pro ...`
- For advisory multi-model panels where partial success is useful, use `--allow-partial --write-output <path>` so successful model files and the `<stem>.oracle.json` manifest are easy to recover:
  - `oracle --models gpt-5.4,claude-4.6-sonnet,gemini-3-pro --allow-partial --write-output /tmp/panel.md -p "<task>"`
- `--timeout 10m` is the normal user-facing API deadline; Oracle derives the HTTP transport timeout unless `--http-timeout` is explicitly set.
- If the exported `OPENAI_API_KEY` is invalid and the user wants their personal OpenAI key, use `$one-password` in one persistent tmux session. Known item: `API Key - OpenAI - Personal`, field `api_key`. Inject only into the single Oracle command; never print the key:
  - `OPENAI_API_KEY="$(op item get 'API Key - OpenAI - Personal' --account my.1password.com --fields label=api_key --reveal)" oracle --provider openai --engine api --model gpt-5.5-pro ...`
- For debugging Oracle itself, prefer the local checkout after pulling `~/Projects/oracle`:
  - `pnpm -C ~/Projects/oracle run build`
  - `node ~/Projects/oracle/dist/scripts/run-cli.js ...`

## Sessions + slugs (don’t lose work)

- Stored under `~/.oracle/sessions` (override with `ORACLE_HOME_DIR`).
- Browser runs save durable files under `~/.oracle/sessions/<id>/artifacts/`, including `transcript.md`, Deep Research reports, and downloaded ChatGPT-generated images when available.
- Runs may detach or take a long time (browser/API + GPT Pro often does). If the CLI times out: don’t re-run; reattach.
  - List: `oracle status --hours 72`
  - Attach: `oracle session <id> --render`
- Use `--slug "<3-5 words>"` to keep session IDs readable.
- Duplicate prompt guard exists; use `--force` only when you truly want a fresh run.
- CLI guardrails: root runs without a prompt exit nonzero; `--dry-run` conflicts with `--render` / `--render-markdown`; Ctrl-C exits foreground API runs with code 130 while browser cleanup/reattach still runs.

## Prompt template (high signal)

Oracle starts with **zero** project knowledge. Assume the model cannot infer your stack, build tooling, conventions, or “obvious” paths. Include:

- Project briefing (stack + build/test commands + platform constraints).
- “Where things live” (key directories, entrypoints, config files, dependency boundaries).
- Exact question + what you tried + the error text (verbatim).
- Constraints (“don’t change X”, “must keep public API”, “perf budget”, etc).
- Desired output (“return patch plan + tests”, “list risky assumptions”, “give 3 options with tradeoffs”).

### “Exhaustive prompt” pattern (for later restoration)

When you know this will be a long investigation, write a prompt that can stand alone later:

- Top: 6–30 sentence project briefing + current goal.
- Middle: concrete repro steps + exact errors + what you already tried.
- Bottom: attach _all_ context files needed so a fresh model can fully understand (entrypoints, configs, key modules, docs).

If you need to reproduce the same context later, re-run with the same prompt + `--file …` set (Oracle runs are one-shot; the model doesn’t remember prior runs).

## Safety

- Don’t attach secrets by default (`.env`, key files, auth tokens). Redact aggressively; share only what’s required.
- Prefer “just enough context”: fewer files + better prompt beats whole-repo dumps.

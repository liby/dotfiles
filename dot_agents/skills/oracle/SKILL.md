---
description: 'Send a bounded prompt and file bundle to an independent ChatGPT Pro, Deep Research, or API model for second-opinion review. Use when the user says /oracle, asks to consult ChatGPT Pro or another model, or explicitly requires an external model check. Not for ordinary review or research that the current agent can complete directly.'
allowed-tools:
    - Bash(curl:*)
    - Bash(lsof:*)
    - Bash(mktemp:*)
    - Bash(oracle:*)
metadata:
    github-path: skills/oracle
    github-ref: refs/tags/v0.16.0
    github-repo: https://github.com/steipete/oracle
    github-tree-sha: 0bc3e9fcbffa218ccf8745a3ce8af0e50c9aec4f
name: oracle
---
# Oracle (CLI): best use

Oracle sends a prompt and selected files to another model through the API or a
browser. Attach only the context needed for the question, treat the result as
advisory, and verify it against the codebase and tests.

## Default path: ChatGPT Pro in running Chrome

Use ChatGPT Pro for an independent second opinion.

Recommended defaults:

- Use `--engine browser --browser-attach-running`.
- Pin every new browser run with `--model gpt-5-pro`; never rely on Oracle's
  CLI default. Do not add a thinking-time flag.
- Let Oracle open a dedicated tab. Do not pass `--browser-tab` by default.
- Pass `--chatgpt-url "<project-url>"` when the review belongs in a ChatGPT
  Project.
- Use `--copy-profile "$HOME/Library/Application Support/Google/Chrome"` only
  when no attachable Chrome is listening.
- Preview every attached file set before sending it.

Preflight the normal browser path:

```bash
lsof -nP -iTCP:9222 -sTCP:LISTEN
```

When it is listening, run:

```bash
oracle --engine browser --browser-attach-running --model gpt-5-pro \
  -p "<task>" --file "src/**"
```

When it is not listening, use the copied-profile fallback:

```bash
oracle --engine browser --model gpt-5-pro \
  --copy-profile "$HOME/Library/Application Support/Google/Chrome" \
  -p "<task>" --file "src/**"
```

`gpt-5-pro` selects ChatGPT's current `Pro` picker, currently GPT-5.6 Sol Pro,
and follows future Pro upgrades. If Pro is unavailable for the account, stop
and report it. Do not substitute another model.

## Local authorization

The user has authorized this skill to use browser mode against the running
Chrome, select the requested model, target a ChatGPT Project, and use the
copied-profile fallback when the task is to consult ChatGPT Pro, Deep Research,
or another model from Codex or Claude Code.

- Do not ask again before using `--engine browser`, `--browser-attach-running`,
  `--model`, `--chatgpt-url`, or the copied-profile fallback for that task.
- Use `--browser-tab current` only when the user explicitly requests existing-tab
  reuse and the check in Known pitfalls passes.
- Do not attach secrets, credential files, private keys, shell history, browser
  storage, or a broad home-directory tree.
- If ChatGPT requires login, CAPTCHA, SSO, workspace selection, or manual
  verification, stop and ask the user to complete it in the visible browser.
- API runs require explicit user consent because they use API billing rather
  than the ChatGPT subscription.

## Golden path

1. Run `oracle --version` and confirm `oracle --help --verbose` exposes the
   intended model and browser flags.
2. Select the smallest file set that contains the truth, then preview it with
   `--dry-run` and `--files-report` until every included file is intentional.
3. Preflight port 9222 and choose attach-running or copied-profile mode from the
   observed result.
4. Run with an explicit model and preserve the session identifier plus model
   selection evidence.
5. Keep checking or reattaching until Oracle returns an answer, a terminal
   error, or the user stops the run. Do not substitute the current agent's
   answer while the requested second opinion is still pending.

## Commands

- Help: `oracle --help --verbose`
- Preview: `oracle --dry-run summary -p "<task>" --file "src/**" --file "!**/*.test.*"`
- Full bundle preview: `oracle --dry-run full -p "<task>" --file "src/**"`
- Token report: `oracle --dry-run summary --files-report -p "<task>" --file "src/**"`
- Manual paste: `oracle --render-markdown --copy-markdown -p "<task>" --file "src/**"`
- Performance trace: `oracle --perf-trace --perf-trace-path "$(mktemp)" --dry-run summary -p "<task>" --file "src/**"`

Use the globally installed `oracle` binary so the reviewed CLI version and the
skill stay aligned. Do not replace these commands with an unpinned `npx -y`
download during a normal run.

## Attaching files

`--file` accepts files, directories, and globs. Pass it multiple times or use
comma-separated entries.

- Include: `--file "src/**"`, `--file src/index.ts`, `--file docs --file README.md`
- Exclude: prefix a pattern with `!`, for example `--file "!src/**/*.test.ts"`
- Default ignored directories: `node_modules`, `dist`, `coverage`, `.git`,
  `.turbo`, `.next`, `build`, and `tmp`
- Globs honor `.gitignore` and do not follow symlinks.
- Dotfiles require an explicit dot-segment, such as `--file ".github/**"`.
- Files over 1 MB are rejected by default; configure
  `ORACLE_MAX_FILE_SIZE_BYTES` or `maxFileSizeBytes` only when required.

Keep total input under roughly 196k tokens. Use `--files-report` or
`--dry-run json` to find oversized inputs. JSON previews print banner lines
before the JSON object, so extract from the first `{` before passing output to
`jq`, or use the summary preview instead.

## Engines and browser controls

- Always pass `--engine browser` for the subscription-backed path. Otherwise an
  exported API key can make Oracle select the billable API engine.
- Browser mode supports GPT through ChatGPT and Gemini through Gemini web. Read
  current help before selecting other model families or providers.
- `--browser-attach-running` attaches to an existing Chrome and opens a
  dedicated tab. `--browser-model-strategy select` is the default and applies
  the explicit `--model`; `current` ignores that model and inherits tab state.
- The copied-profile fallback creates a throwaway copy, launches Chrome, and
  removes the copy after the run. It cannot be retained or reattached.
- Browser attachments use `--browser-attachments auto|never|always`; add
  `--browser-bundle-files --browser-bundle-format auto|zip` for many files.
- Use `--browser-research deep` only when Deep Research is explicitly requested.

## API preflight

Before an explicitly authorized API run, check provider readiness without
printing secrets:

```bash
oracle doctor --providers --models gpt-5.6,claude-4.6-sonnet,gemini-3-pro
oracle --preflight --models gpt-5.6,gemini-3-pro
oracle --route --model gpt-5.6
```

Use `--provider openai` or `--no-azure` when first-party OpenAI routing is
required. For a multi-model panel where partial success is useful, use
`--allow-partial --write-output <path>` so successful outputs and the manifest
remain recoverable. Set an explicit automation deadline such as `--timeout 10m`.

## Sessions and recovery

- Sessions live under `~/.oracle/sessions`; override with `ORACLE_HOME_DIR`.
- Browser artifacts include `transcript.md` and, when available, research
  reports and generated images.
- List recent sessions with `oracle status --hours 72`.
- Reattach with `oracle session <id> --render`.
- Use `--slug "<3-5 words>"` for readable session identifiers.
- Use `--force` only when a genuinely new identical run is intended.
- Successful non-project browser one-shots archive automatically by default;
  override with `--browser-archive never|always`.
- Before browser `--followup`, use the real ChatGPT conversation URL preserved
  by the original session. If it is missing, recover it from session artifacts
  or ask the user. Never guess from open tabs.

## Known pitfalls

Oracle resolves explicit existing-tab references through `CDP.List`, which
uses the HTTP `/json/list` endpoint. Some approved remote-debugging Chrome
flows expose a working browser WebSocket while `/json/list` returns 404. In
that case, omit `--browser-tab` and let attach-running open a dedicated tab.

Check the endpoint only when existing-tab reuse is explicitly requested:

```bash
/usr/bin/curl -sS -o /dev/null -w '%{http_code}\n' \
  http://127.0.0.1:9222/json/list
```

## Prompt template

Oracle starts with zero project knowledge. Include:

- Project briefing: stack, services, build/test commands, and platform constraints
- Where things live: entrypoints, configs, key modules, and dependency boundaries
- Exact question, prior attempts, and verbatim error text
- Constraints such as API compatibility, performance budgets, and files not to change
- Desired output such as a patch plan, tests, risk list, or tradeoff comparison

For a long investigation, make the prompt restorable: put a 6 to 30 sentence
briefing at the top, concrete reproduction and errors in the middle, and attach
all context files required by a fresh model at the bottom. Oracle runs are
one-shot; the model does not remember prior runs.

<h4 align="right"><strong>English</strong> | <a href="README_CN.md">简体中文</a></h4>

# dotfiles

My macOS setup, built around coding agents. Claude Code, Codex and Pi share most of their instructions and skills. [chezmoi](https://www.chezmoi.io/) keeps it in sync across my Macs.

It is a personal setup, meant to be borrowed from. Every skill in [`dot_agents/skills/`](../dot_agents/skills/) works on its own, outside this repository.

## What's inside

### Shared instructions

The [global instructions](CONCEPTS.md#shared-agent-instructions) are short Markdown sections in [`.chezmoitemplates/agents/`](../.chezmoitemplates/agents/). chezmoi builds `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md` and `~/.pi/agent/AGENTS.md` from them. Claude Code's copy adds rules for its own tools, such as LSP, WebFetch and its sandbox. Change a shared rule once and every agent gets it.

### Shared skills

The skills cover commits, code review, cleanup, PR descriptions and review comments, and writing skills. Every agent loads them from `~/.agents/skills`. Before a change to when a skill runs or what it produces ships, it is [compared with the old version](../dot_agents/skills/write-skill/references/evaluation.md).

### agent-guard and sandboxes

[agent-guard](https://github.com/Entwining/agent-guard) checks agents' shell and file calls before they run. It blocks home-directory scans and credential reads, and tells the agent what to run instead. This repository [wires it into](CONCEPTS.md#agent-guard) every agent. The Claude Code and Codex sandboxes share one [allowlist](../.chezmoitemplates/sandbox/) of domains and Unix sockets.

### Credentials stay out of the repository

API keys live in [Maskey](https://github.com/Entwining/maskey), which keeps them in iCloud Keychain. A command receives its key as an environment variable when it runs. Files such as the SSH config are committed [encrypted](CONCEPTS.md#identity-and-encrypted-data), and only my YubiKey can decrypt them.

### Agent orchestration in Rex

Agents run in [Rex](https://www.superlogical.com/rex) panes. An orchestrator can hand review, research, or implementation to other agents as workers, such as Codex reviewing a Claude Code change. Each worker is a full CLI session in its own pane that you can step into. The orchestrator does not have to wait on its workers: [Rexume](https://github.com/Entwining/rexume) saves each result and notifies it when a worker finishes. When the Rex server restarts, Rexume reopens the conversation in every pane: an interrupted turn continues, and the model, effort, and permission mode stay as they were. [`setup-rex`](../dot_local/bin/executable_setup-rex) installs the skills for Rex and Rexume, and this repository [manages Rex's settings and hooks](CONCEPTS.md#rex-integration).

### A new Mac in one command

One chezmoi command installs Homebrew packages, App Store apps and everything above. It asks for sign-ins and `sudo`, and for the YubiKey's PIN to decrypt files. [SETUP.md](SETUP.md) walks through it.

## Use it

Copy what you need. To build your own setup from it, read [SETUP.md](SETUP.md) first. It covers forking, keys and credentials.

## What it does not do

Setup scripts run once or when they change, so a tool you remove by hand stays removed until you [rerun that script](CONCEPTS.md#bootstrap). Old Macs keep retired configuration until you [review and remove it](SETUP.md#update-an-existing-mac). [Apps keep their own runtime state and sign-ins](CONCEPTS.md#configuration-ownership). Tools follow [their own update channels](CONCEPTS.md#package-and-tool-ownership) instead of one pinned snapshot.

## Contributing

Read [`AGENTS.md`](../AGENTS.md) before changing anything. Open an [issue](https://github.com/liby/dotfiles/issues/new) or a [pull request](https://github.com/liby/dotfiles/pulls).

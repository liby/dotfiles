<h4 align="right"><a href="README.md">English</a> | <strong>简体中文</strong></h4>

# dotfiles

我的 macOS 配置，日常工作主要交给 Claude Code、Codex 和 Pi。它们共用大部分 instructions 和 skills，多台 Mac 之间由 [chezmoi](https://www.chezmoi.io/) 保持同步。

这是个人配置，欢迎参考。[`dot_agents/skills/`](../dot_agents/skills/) 里的每个 skill 都能脱离这个仓库单独使用。

## 主要内容

### 共享的 instructions

[全局 instructions](CONCEPTS.md#shared-agent-instructions) 按主题拆成几段 Markdown，放在 [`.chezmoitemplates/agents/`](../.chezmoitemplates/agents/)。chezmoi 用它们生成 `~/.claude/CLAUDE.md`、`~/.codex/AGENTS.md` 和 `~/.pi/agent/AGENTS.md`，其中针对 Claude Code 还加了几条有关它自身工具的规则，比如 LSP、WebFetch 和 sandbox。一处修改，所有 agent 同时生效。

### 共享的 skills

skill 覆盖 commit、code review、code cleanup、PR 描述、review comment 和 skill 编写等场景，所有 agent 都从 `~/.agents/skills` 加载。修改 skill 的触发条件或输出之前，会先和旧版本做 [A/B 对比](../dot_agents/skills/write-skill/references/evaluation.md)。

### agent-guard 与 sandbox

[agent-guard](https://github.com/Entwining/agent-guard) 会在 agent 的 shell 和文件操作执行前先检查一遍。扫描整个 home 目录、读取 credentials 这类操作会被拦下，同时告诉 agent 应该换成什么命令。这个仓库负责把它[接入](CONCEPTS.md#agent-guard)每个 agent。Claude Code 和 Codex 的 sandbox 共用同一份 [allowlist](../.chezmoitemplates/sandbox/)，包括允许访问的域名和 Unix socket。

### Credentials 不进仓库

API key 存在 [Maskey](https://github.com/Entwining/maskey) 里，底层是 iCloud Keychain。命令运行时才通过环境变量拿到 key。SSH config 这类文件[加密](CONCEPTS.md#identity-and-encrypted-data)后提交，只有我的 YubiKey 能解密。

### 在 Rex 里做 agent orchestration

agent 都跑在 [Rex](https://www.superlogical.com/rex) 的 pane 里。orchestrator 可以把 review、调研或实现交给其他 agent 当 worker，比如让 Codex review Claude Code 的改动。每个 worker 都是独立 pane 里完整的 CLI 会话，需要时可以直接接手。orchestrator 不必守着 worker：任务完成后，[Rexume](https://github.com/Entwining/rexume) 会保存结果并通知它。Rex server 重启后，Rexume 会把每个 pane 里的对话重新打开：被打断的 turn 继续执行，模型、effort 和权限模式保持不变。[`setup-rex`](../dot_local/bin/executable_setup-rex) 负责安装 Rex 和 Rexume 的 skill，Rex 的设置和 hook 由这个仓库[统一管理](CONCEPTS.md#rex-integration)。

### 一条命令配置好新设备

只需一条命令就可以装好 Homebrew 包、App Store 里的 App，以及上面提到的所有配置。但不是无人值守：中途需要登录账号、输入 `sudo` 密码，解密文件时还要插上 YubiKey 输入 PIN。完整步骤见 [SETUP.md](SETUP.md)（英文）。

## 如何使用

需要哪些内容，请随意取用。想基于它搭一套属于自己的配置，先看 [SETUP.md](SETUP.md)，里面讲了怎么 fork、怎么换成自己的 key 和 credentials。

## 注意事项

安装脚本只在第一次运行或内容变化时执行，所以手动删掉的工具不会被自动装回来，要让对应脚本[重新执行](CONCEPTS.md#bootstrap)才行。旧 Mac 上不再使用的配置不会自动删除，需要[自己检查后清理](SETUP.md#update-an-existing-mac)。App 的运行状态和登录信息由 [App 自己管理](CONCEPTS.md#configuration-ownership)。各个工具按[各自的渠道](CONCEPTS.md#package-and-tool-ownership)更新，不统一锁定版本。

## 参与贡献

修改前请先阅读 [`AGENTS.md`](../AGENTS.md)。欢迎提 [issue](https://github.com/liby/dotfiles/issues/new) 或 [pull request](https://github.com/liby/dotfiles/pulls)。

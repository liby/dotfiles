<h4 align="right"><a href="README.md">English</a> | <strong>简体中文</strong></h4>

# My Dotfiles

这套 dotfiles 用于配置我的 macOS 开发环境，并通过 [chezmoi](https://www.chezmoi.io/) 在多台 Mac 之间同步。仓库还包含新 Mac 的初始化脚本。

这套配置仅支持 Apple Silicon Mac，不支持 Intel Mac。

部分配置依赖我的账户、GPG 密钥和文件系统布局。如果使用环境不同，需要相应调整。

## 项目概览

| 内容 | 入口 |
| --- | --- |
| Coding Agent 工具与配置 | [`dot_agents`](../dot_agents/)、[`dot_claude`](../dot_claude/)、[`dot_codex`](../dot_codex/) |
| Git 配置 | [`dot_config/git`](../dot_config/git/)、[`.chezmoitemplates/git`](../.chezmoitemplates/git/) |
| 设计思路 | [`CONCEPTS.md`](CONCEPTS.md) |
| 软件包和初始化脚本 | [`Brewfile`](../Brewfile)、[`.chezmoiscripts`](../.chezmoiscripts/) |
| Shell 和应用配置 | [`dot_zshrc`](../dot_zshrc)、[`dot_zsh`](../dot_zsh/)、[`dot_config`](../dot_config/) |
| chezmoi 配置和模板 | [`.chezmoi.toml.tmpl`](../.chezmoi.toml.tmpl)、[`.chezmoitemplates`](../.chezmoitemplates/) |

## 初始化新 Mac

在新 Mac 上打开 Terminal.app，运行以下命令：

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply liby
```

这不是无人值守安装。请保持 Terminal.app 打开，以便输入模板所需的私有参数、响应 Xcode 或 `sudo` 提示，并在需要时使用 YubiKey。

这条命令会安装 chezmoi，将本仓库克隆到 `~/.local/share/chezmoi`，运行初始化脚本，并将受 chezmoi 管理的文件同步到 `$HOME`。

如果这台 Mac 上已经安装了 chezmoi，只需运行：

```sh
chezmoi init --apply liby
```

## 常用操作

```sh
chezmoi status                     # 查看配置状态
chezmoi diff <target>              # 查看单个配置文件的差异
chezmoi apply                      # 将配置应用到 $HOME
chezmoi edit <target>              # 编辑由 chezmoi 管理的加密文件
chezmoi edit-encrypted <filename>  # 编辑未由 chezmoi 管理的加密文件
```

编辑加密文件时需要使用 YubiKey，不应该交由 Agent 处理。

其他命令参见 [chezmoi 日常操作指南](https://www.chezmoi.io/user-guide/daily-operations/)。

## 取用

可以 Fork 本仓库并根据自己的环境调整，也可以只取用需要的部分。若要应用整套配置，请先检查并调整 `.chezmoi.toml.tmpl`、`Brewfile` 和 `.chezmoiscripts/`。

## 参与贡献

修改本仓库前，请先阅读 [`AGENTS.md`](../AGENTS.md)，其中记录了仓库的工作流程、安全边界和验证要求。发现问题时，可以创建 [Issue](https://github.com/liby/dotfiles/issues/new)；如需提交修改，可以创建 [Pull Request](https://github.com/liby/dotfiles/pulls)。

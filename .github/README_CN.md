<h4 align="right">
  <a href="https://github.com/liby/dotfiles/blob/main/.github/README.md">English</a> | <strong>简体中文</strong>
</h4>

<div>
  <h1 align="center">My Dotfiles</h1>
</div>

> **Note**
>
> 这是我的 dotfiles 仓库，主要用于配置和管理个人的开发环境。借助 [chezmoi](https://www.chezmoi.io/)，我能在多台 Mac 设备间轻松实现无缝同步。

## 项目简介

本仓库包含了一系列配置文件和脚本，用于设置和管理我的开发环境，包括但不限于：

  - Agentic coding 配置：[`dot_claude`](https://github.com/liby/dotfiles/tree/main/dot_claude) / [`dot_codex`](https://github.com/liby/dotfiles/tree/main/dot_codex)

  - Shared Agent Skills：[`dot_agents/skills`](https://github.com/liby/dotfiles/tree/main/dot_agents/skills)

  - Git 配置：[`dot_config/git`](https://github.com/liby/dotfiles/tree/main/dot_config/git)

  - Homebrew 依赖：[`Brewfile`](https://github.com/liby/dotfiles/blob/main/Brewfile)

  - Shell 配置：[`dot_zshrc`](https://github.com/liby/dotfiles/blob/main/dot_zshrc)

  - 终端提示符：[`dot_config/starship`](https://github.com/liby/dotfiles/tree/main/dot_config/starship)

这些文件通过 [chezmoi](https://www.chezmoi.io/) 管理，支持模板、加密和跨设备差异化配置。

## 安装说明

### 新设备初始化

在新 Mac 上打开 Terminal.app，运行：

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply liby
```

这条命令会：
1. 安装 chezmoi
2. 克隆本仓库到 `~/.local/share/chezmoi`
3. 执行所有 Bootstrap 脚本（安装 Xcode CLI Tools、Homebrew、brew packages 等）
4. 将配置文件同步到 `$HOME`

### 已安装 chezmoi 的设备

```sh
chezmoi init liby
chezmoi apply
```

## 使用方法

```sh
chezmoi add <file>          # 将文件加入 chezmoi 管理
chezmoi edit <file>         # 编辑源文件
chezmoi status --exclude=encrypted  # 安全查看变更概览
chezmoi diff <dest-path>    # 检查单个非敏感目标文件
chezmoi apply               # 应用所有变更到 $HOME
chezmoi cd                  # 进入源目录
chezmoi git status          # 在任意目录下操作源目录的 Git
```

### 加密文件

敏感文件使用 GPG 加密存储：

```sh
chezmoi add --encrypt <file>   # 加密添加
```

### Bootstrap 脚本

Bootstrap 脚本位于 `.chezmoiscripts/` 目录下，按以下顺序执行：

| 阶段 | 脚本 | 备注 |
|------|------|------|
| before | [Xcode CLI Tools](../.chezmoiscripts/run_once_before_100-install-xcode-cli-tools.sh) | Git 和编译依赖 |
| before | [Homebrew](../.chezmoiscripts/run_once_before_200-install-homebrew.sh) | |
| before | [Brewfile packages](../.chezmoiscripts/run_onchange_before_300-install-brew-packages.sh.tmpl) | |
| before | [Case-sensitive volume](../.chezmoiscripts/run_once_before_400-setup-case-sensitive-volume.sh) | 供 `~/Code` 使用 |
| before | [Node.js](../.chezmoiscripts/run_once_before_500-install-nodejs.sh) | 包含 proto 和 pnpm |
| before | [uv tools](../.chezmoiscripts/run_onchange_before_600-install-uv-tools.sh) | |
| before | [Rust](../.chezmoiscripts/run_once_before_700-install-rust.sh) | |
| before | [Claude Code](../.chezmoiscripts/run_once_before_800-install-claude-code.sh) | |
| after | [GPG agent](../.chezmoiscripts/run_once_after_100-setup-gpg-agent.sh) | 含 YubiKey 配置 |
| after | [Git config](../.chezmoiscripts/run_once_after_200-setup-gitconfig.sh) | 从模板生成 |
| after | [macOS defaults](../.chezmoiscripts/run_onchange_after_300-setup-macos-defaults.sh) | Dock、Finder 等 |
| after | [zsh completions](../.chezmoiscripts/run_once_after_400-reload-zsh-completions.sh) | |
| after | [Developer tools](../.chezmoiscripts/run_onchange_after_600-update-dev-tools.sh.tmpl) | 定期更新 CLI 工具 |

`before` 脚本在文件同步前执行，`after` 脚本在文件同步后执行。

Zsh 插件通过 [`.chezmoiexternal.toml`](../.chezmoiexternal.toml) 固定到明确的上游 commit，由 chezmoi 声明式同步，不再在首次初始化时克隆当时的分支最新状态。

## 贡献指南

如果你有任何改进建议或问题，欢迎提交 [Issue](https://github.com/liby/dotfiles/issues/new) 或 [Pull Request](https://github.com/liby/dotfiles/pulls)。

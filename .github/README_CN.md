<h4 align="right">
  <a href="https://github.com/liby/dotfiles/blob/main/.github/README.md">English</a> | <strong>简体中文</strong>
</h4>

<div>
  <h1 align="center">My Dotfiles</h1>
</div>

> **Note**
>
> 这是我的 dotfiles 仓库，用于配置和管理我的开发环境。通过 [chezmoi](https://www.chezmoi.io/) 我可以在多台 Mac 间轻松同步开发环境。

## 项目简介

本仓库包含了一系列配置文件和脚本，用于设置和管理我的开发环境，包括但不限于：

  - 开发环境初始化脚本：[_.chezmoiscripts_](https://github.com/liby/dotfiles/tree/main/.chezmoiscripts)

  - Homebrew 依赖：[_Brewfile_](https://github.com/liby/dotfiles/blob/main/Brewfile)

  - Shell 配置：[_dot_zshrc_](https://github.com/liby/dotfiles/blob/main/dot_zshrc)

  - 终端提示符：[_dot_config/starship_](https://github.com/liby/dotfiles/tree/main/dot_config/starship)

  - Git 配置：[_dot_config/git_](https://github.com/liby/dotfiles/tree/main/dot_config/git)

  - SSH 配置：[_dot_ssh/config_](https://github.com/liby/dotfiles/blob/main/dot_ssh/config)

  - Claude Code 配置：[_dot_claude_](https://github.com/liby/dotfiles/tree/main/dot_claude)

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
3. 执行所有初始化脚本（安装 Xcode CLI Tools、Homebrew、brew packages 等）
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
chezmoi diff                # 查看源目录与目标的差异
chezmoi apply               # 应用所有变更到 $HOME
chezmoi cd                  # 进入源目录
chezmoi git status          # 在任意目录下操作源目录的 git
```

### 加密文件

敏感文件使用 GPG 加密存储：

```sh
chezmoi add --encrypt <file>   # 加密添加
```

### 初始化脚本

初始化脚本位于 `.chezmoiscripts/` 目录下，按编号顺序执行：

| 阶段 | 脚本 | 说明 |
|------|------|------|
| before | [01-install-xcode-cli-tools](../.chezmoiscripts/run_once_before_01-install-xcode-cli-tools.sh) | 安装 Xcode 命令行工具 |
| before | [02-install-homebrew](../.chezmoiscripts/run_once_before_02-install-homebrew.sh) | 安装 Homebrew |
| before | [03-install-brew-packages](../.chezmoiscripts/run_onchange_before_03-install-brew-packages.sh.tmpl) | 安装 Brewfile 中的所有包 |
| before | [04-setup-case-sensitive-volume](../.chezmoiscripts/run_once_before_04-setup-case-sensitive-volume.sh) | 创建大小写敏感的 Code volume |
| before | [05-install-nodejs](../.chezmoiscripts/run_once_before_05-install-nodejs.sh) | 安装 proto、Node.js、pnpm |
| before | [06-install-rust](../.chezmoiscripts/run_once_before_06-install-rust.sh) | 安装 Rust |
| before | [07-install-claude-code](../.chezmoiscripts/run_once_before_07-install-claude-code.sh) | 安装 Claude Code |
| before | [08-setup-zsh-plugins](../.chezmoiscripts/run_once_before_08-setup-zsh-plugins.sh) | 安装 zsh 插件 |
| after | [01-setup-gpg-agent](../.chezmoiscripts/run_once_after_01-setup-gpg-agent.sh) | 配置 GPG agent 和 Yubikey |
| after | [02-setup-gitconfig](../.chezmoiscripts/run_once_after_02-setup-gitconfig.sh) | 从模板生成 git 配置 |
| after | [03-setup-macos-defaults](../.chezmoiscripts/run_once_after_03-setup-macos-defaults.sh) | 设置 macOS 系统偏好 |
| after | [04-reload-zsh-completions](../.chezmoiscripts/run_once_after_04-reload-zsh-completions.sh) | 重建 zsh 补全缓存 |

`before` 脚本在文件同步前执行，`after` 脚本在文件同步后执行。

## 贡献指南

如果你有任何改进建议或问题，欢迎提交 Issue 或 Pull Request。

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

  - Git 配置：[`dot_config/git`](https://github.com/liby/dotfiles/tree/main/dot_config/git) 和 [`.chezmoitemplates/git`](https://github.com/liby/dotfiles/tree/main/.chezmoitemplates/git)

  - Homebrew 依赖：[`Brewfile`](https://github.com/liby/dotfiles/blob/main/Brewfile)

  - Shell 配置：[`dot_zshrc`](https://github.com/liby/dotfiles/blob/main/dot_zshrc)

  - 终端提示符：[`dot_config/starship`](https://github.com/liby/dotfiles/tree/main/dot_config/starship)

这些文件通过 [chezmoi](https://www.chezmoi.io/) 管理，支持模板、加密和跨设备差异化配置。

## 安装说明

### 新设备初始化

在新的 Apple Silicon Mac 上打开 Terminal.app，运行：

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply liby
```

这是一条统一入口命令，并不是无人值守安装。请保持 Terminal.app 打开，以便
填写私有模板值、完成 Xcode 或 `sudo` 交互，以及使用 YubiKey。

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
| before | [Xcode CLI Tools](../.chezmoiscripts/run_once_before_01-install-xcode-cli-tools.sh) | Git 和编译依赖 |
| before | [Homebrew](../.chezmoiscripts/run_once_before_02-install-homebrew.sh) | |
| before | [Brewfile packages](../.chezmoiscripts/run_onchange_before_03-install-brew-packages.sh.tmpl) | 重建每日执行 Homebrew update、upgrade 和 cleanup 的 LaunchAgent |
| before | [GPG agent](../.chezmoiscripts/run_once_before_04-setup-gpg-agent.sh) | 在同步加密目标前获取 YubiKey 公钥 |
| before | [Case-sensitive volume](../.chezmoiscripts/run_once_before_05-setup-case-sensitive-volume.py) | 创建并持久挂载 `~/Code` APFS volume |
| before | [Node.js](../.chezmoiscripts/run_once_before_06-install-nodejs.sh) | 通过 proto 安装，包含 pnpm |
| before | [全局开发工具](../.chezmoiscripts/run_onchange_before_07-reconcile-dev-tools.sh.tmpl) | 全局 npm 工具和 Pyright 的版本声明见 [`package.json`](dev-tools/package.json) 与 [`requirements.txt`](dev-tools/requirements.txt) |
| before | [Rust](../.chezmoiscripts/run_once_before_08-install-rust.sh) | |
| before | [Claude Code](../.chezmoiscripts/run_once_before_09-install-claude-code.sh) | |
| after | [Git config](../.chezmoiscripts/run_onchange_after_01-setup-gitconfig.sh.tmpl) | 渲染输入变化时重新生成 provider 配置，并在运行时从 GPG/YubiKey 解析签名密钥 |
| after | [macOS defaults](../.chezmoiscripts/run_onchange_after_02-setup-macos-defaults.sh.tmpl) | Dock、Finder 等 |
| after | [zsh completions](../.chezmoiscripts/run_once_after_03-reload-zsh-completions.sh) | |
| after | [Envchain seed](../.chezmoiscripts/run_onchange_after_04-seed-envchain.sh.tmpl) | 将用户管理的加密值写入 Keychain namespace |

`before` 脚本在文件同步前执行，`after` 脚本在文件同步后执行。

Homebrew autoupdate 是周期 LaunchAgent，两次运行之间无需持续存在活跃进程。
`brew autoupdate status` 检查调用方所在的 bootstrap namespace，因此从其他
app 运行时，即使 Terminal 安装的 agent 已加载，也可能显示 `stopped`。请用
GUI domain 中的持久状态验收：

```sh
launchctl print "gui/$(id -u)/com.github.domt4.homebrew-autoupdate"
```

大小写敏感 volume 脚本使用 Python plist parser 定位 `$HOME` 所属 APFS
container，通过 `vifs` 安装基于 UUID 的持久挂载；如果 `~/Code` 非空或该
volume 已挂载到别处，脚本会停止而不会自动卸载。失败后处理冲突并重新运行
`chezmoi apply`；失败的 `run_once` 会重试，但成功后不会持续修复后续漂移。
无需磁盘操作的检查可这样运行：

```sh
/usr/bin/python3 .github/tests/setup_case_sensitive_volume_test.py
```

Docker 无法验证 macOS APFS 或 Disk Arbitration。新机最终仍需完成一次
`apply`、重启后确认同一 volume 挂载在 `~/Code`，再验证第二次 `apply` 无操作。

[Renovate](renovate.json) 按 `Asia/Singapore` 时区每日检查依赖，并将所有 manager 的常规更新合入一个 `All dependencies` PR，major update 也不单独拆分。按路径触发的 CI 会验证该 PR 涉及的依赖面。下一次 `chezmoi apply` 只安装缺失或版本不符的全局 npm 工具与 Pyright。

Zsh 插件通过 [`.chezmoiexternal.toml`](../.chezmoiexternal.toml) 固定到上游 commit。[CI](workflows/validate-zsh-plugins.yml) 验证每个 archive 可应用且入口可加载。

## 贡献指南

如果你有任何改进建议或问题，欢迎提交 [Issue](https://github.com/liby/dotfiles/issues/new) 或 [Pull Request](https://github.com/liby/dotfiles/pulls)。

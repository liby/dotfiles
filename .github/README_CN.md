<h4 align="right"><a href="README.md">English</a> | <strong>简体中文</strong></h4>

# My Dotfiles

这套 dotfiles 用于配置我的 macOS 开发环境，并通过 [chezmoi](https://www.chezmoi.io/) 在多台 Mac 之间同步。仓库还包含新 Mac 的初始化脚本。

这套配置仅支持 Apple Silicon Mac，不支持 Intel Mac。

部分配置依赖我的账户、GPG 密钥和文件系统布局。如果使用环境不同，需要相应调整。

## 范围

这个仓库负责让我的多台 Mac 保持同步、初始化新 Mac，并配置我使用的 Coding Agent：它们共用的指令、skill、沙箱和防护。以下内容刻意不做：

- 无人值守安装，见[初始化新 Mac](#初始化新-mac)。
- 修复漂移：初始化脚本只在渲染后的内容变化时重新运行，所以手动删掉的工具、换成另一把密钥的 YubiKey，都会保持原样，直到那个脚本再次运行；重跑单个脚本的方法见 [Bootstrap](CONCEPTS.md#bootstrap)。
- 清理早先应用过的机器上已退役的配置，见[更新已有配置的机器](#更新已有配置的机器)。
- 把所有工具钉在同一个快照：Coding Agent、Homebrew 软件包和会自动更新的应用都走各自的更新渠道，只有后台开发工具固定版本，见 [Package and tool ownership](CONCEPTS.md#package-and-tool-ownership)。
- 应用的运行时状态和登录会话，它们归写入它们的应用管理，见 [Configuration ownership](CONCEPTS.md#configuration-ownership)。

## 项目概览

| 内容 | 入口 |
| --- | --- |
| Coding Agent 工具与配置 | [`dot_agents`](../dot_agents/)、[`dot_claude`](../dot_claude/)、[`dot_codex`](../dot_codex/)、[`private_dot_pi`](../private_dot_pi/)、[`.chezmoitemplates/agents`](../.chezmoitemplates/agents/) |
| Git 配置 | [`dot_config/git`](../dot_config/git/)、[`.chezmoitemplates/git`](../.chezmoitemplates/git/) |
| 设计思路 | [`CONCEPTS.md`](CONCEPTS.md) |
| 软件包和初始化脚本 | [`Brewfile`](../Brewfile)、[`.chezmoiscripts`](../.chezmoiscripts/) |
| Shell 和应用配置 | [`dot_zshrc`](../dot_zshrc)、[`dot_zsh`](../dot_zsh/)、[`dot_config`](../dot_config/) |
| chezmoi 配置和模板 | [`.chezmoi.toml.tmpl`](../.chezmoi.toml.tmpl)、[`.chezmoitemplates`](../.chezmoitemplates/) |

## 初始化新 Mac

全新安装的 macOS 上，`git` 只是一个占位程序，调用它只会弹出命令行开发者工具的安装对话框并返回错误，`chezmoi init` 因此无法克隆本仓库。在新 Mac 上打开 Terminal.app，先安装命令行工具：

```sh
xcode-select --install
```

等安装窗口结束，确认 `xcode-select -p` 和 `git --version` 都有输出，再运行：

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$(mktemp -d)" init --apply liby
```

这不是无人值守安装。请先登录 App Store：`Brewfile` 通过 `mas` 安装 App Store 应用，而 `mas` 需要已登录的账户。请保持 Terminal.app 打开，以便输入模板所需的私有参数、响应 `sudo` 提示、在需要时使用 YubiKey，并在浏览器中完成 GitLab 登录。完成后运行 `gh auth login`：后台升级任务只有在登录 GitHub 后才能更新 gh 扩展。

这条命令会安装 chezmoi，将本仓库克隆到 `~/.local/share/chezmoi`，运行初始化脚本，并将受 chezmoi 管理的文件同步到 `$HOME`。`-b` 把这个临时用的二进制放进临时目录，而不是安装脚本默认在当前目录下创建的 `bin`，在 Terminal.app 里就是 `~/bin`：之后所有命令都应该用 `Brewfile` 安装的那个 chezmoi，而 `.zshrc` 把 `~/bin` 排在 Homebrew 之前，留在那里的副本会挡住它，并且不会再更新。

初始化脚本失败会中断整个 apply。重新运行上面那条一键命令即可继续，它会把 chezmoi 装进一个新的临时目录，从失败的地方接着往下走。

如果这台 Mac 上已经安装了 chezmoi，运行：

```sh
chezmoi init --apply liby
```

## 常用操作

```sh
chezmoi status                     # 查看配置状态
chezmoi diff <target>              # 查看单个配置文件的差异
chezmoi apply                      # 将配置应用到 $HOME
chezmoi edit <target>              # 编辑受管理文件（传递 target 路径）
chezmoi edit-encrypted <filename>  # 编辑加密文件（传递 source 路径）
```

编辑加密文件时需要使用 YubiKey，不应该交由 Agent 处理。

其他命令参见 [chezmoi 日常操作指南](https://www.chezmoi.io/user-guide/daily-operations/)。

## 更新已有配置的机器

更新已有的 Mac 或向 fork 合并上游变更时，请检查这台机器上次应用版本之后的提交，确认哪些路径和字段需要清理。删除前先核对当前内容，保留仍然需要的本地修改。应用新版本[不会清理所有已退役的配置](CONCEPTS.md#configuration-ownership)，即使 `chezmoi status` 没有输出。

## 取用

可以 Fork 本仓库并根据自己的环境调整，也可以只取用需要的部分。若要应用整套配置，请先检查并调整 `.chezmoi.toml.tmpl`、`Brewfile` 和 `.chezmoiscripts/`。加密的 `*.asc` 文件只能用我的 YubiKey 解密，请把它们和 `.chezmoi.toml.tmpl` 中的 GPG 接收者换成你自己的，或者连同用到它们的部分一起删除，详见[身份与加密数据](CONCEPTS.md#identity-and-encrypted-data)。

## 参与贡献

修改本仓库前，请先阅读 [`AGENTS.md`](../AGENTS.md)，其中记录了仓库的工作流程、安全边界和验证要求。发现问题时，可以创建 [Issue](https://github.com/liby/dotfiles/issues/new)；如需提交修改，可以创建 [Pull Request](https://github.com/liby/dotfiles/pulls)。

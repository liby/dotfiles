<h4 align="right"><a href="README.md">English</a> | <strong>简体中文</strong></h4>

# My Dotfiles

这套 dotfiles 用于配置我的 macOS 开发环境，并通过 [chezmoi](https://www.chezmoi.io/) 在多台 Mac 之间同步。仓库还包含新 Mac 的初始化脚本。

整套配置面向 Apple Silicon Mac。安装前，请将 macOS 主版本号与[通知脚本的 `main()` 开头检查的版本集合](../.chezmoiscripts/run_after_setup-macos-notifications.py)比较。

部分配置依赖我的账户、GPG 密钥和文件系统布局。如果使用环境不同，需要相应调整。

## 范围

这个仓库负责让我的多台 Mac 保持同步、初始化新 Mac，并配置我使用的 coding agent：它们共用的指令、skill、沙箱和防护。以下内容刻意不做：

- 无人值守安装：[安装过程](#初始化新-mac)需要登录账户、响应交互提示并使用硬件密钥。
- 持续检查已安装工具的健康状态：一次性或变更触发的安装需要[显式重新调度](CONCEPTS.md#bootstrap)来修复漂移。
- 自动清理已退役的配置：[已有机器需要显式检查和删除](#更新已有配置的机器)。
- 把整个环境锁定在同一个快照：工具遵循[各自的声明和更新渠道](CONCEPTS.md#package-and-tool-ownership)。
- 应用的运行时状态和登录会话，它们[归写入它们的应用管理](CONCEPTS.md#configuration-ownership)。

## 项目概览

| 内容 | 入口 |
| --- | --- |
| coding agent 工具与配置 | [`dot_agents`](../dot_agents/)、[`dot_claude`](../dot_claude/)、[`dot_codex`](../dot_codex/)、[`private_dot_pi`](../private_dot_pi/)、[`.chezmoitemplates/agents`](../.chezmoitemplates/agents/) |
| Git 配置 | [`dot_config/git`](../dot_config/git/)、[`.chezmoitemplates/git`](../.chezmoitemplates/git/) |
| 设计思路 | [`CONCEPTS.md`](CONCEPTS.md) |
| 软件包和初始化脚本 | [`Brewfile`](../Brewfile)、[`.chezmoiscripts`](../.chezmoiscripts/) |
| Shell 和应用配置 | [`dot_zshenv`](../dot_zshenv)、[`dot_zprofile`](../dot_zprofile)、[`dot_zshrc`](../dot_zshrc)、[`dot_zsh`](../dot_zsh/)、[`dot_config`](../dot_config/) |
| chezmoi 配置和模板 | [`.chezmoi.toml.tmpl`](../.chezmoi.toml.tmpl)、[`.chezmoitemplates`](../.chezmoitemplates/) |

## 取用

可以只复制需要的部分，也可以 fork 本仓库来调整整套配置。应用 fork 前，请先检查并调整 `.chezmoi.toml.tmpl`、`Brewfile` 和 `.chezmoiscripts/`。加密的 `*.asc` 文件只能用我的 YubiKey 解密，请把[密文和 GPG 接收者](CONCEPTS.md#identity-and-encrypted-data)换成你自己的，接收者在 `.chezmoi.toml.tmpl` 中声明；也可以连同用到它们的部分一起删除。下面的命令会应用我的整套配置；安装调整后的版本时，请换成你自己的 fork 仓库名。

## 初始化新 Mac

在新 Mac 上打开 Terminal.app，先安装 Apple 的[命令行开发者工具](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools/)，再克隆本仓库：

```sh
xcode-select --install
```

等安装窗口结束，确认 `xcode-select -p` 和 `git --version` 都有输出。

继续前请先登录 App Store，满足 [mas 的账户要求](https://github.com/mas-cli/mas#app-store-apple-account-requirements)，以便安装 `Brewfile` 中的应用。请保持 Terminal.app 打开，以便输入模板所需的私有参数、响应 `sudo` 提示、在需要时使用 YubiKey，并在浏览器中完成 GitLab 登录。

运行下面的安装命令前，先在系统设置 > 隐私与安全性 > 完全磁盘访问权限中授权 Terminal.app，以便[自动同步通知偏好](CONCEPTS.md#configuration-ownership)。后续 apply 也需要运行它的终端获得同样授权；缺少授权时，apply 会在通知步骤停下，并指出要开启哪个应用。之后才注册通知的应用会在下次 apply 时配置。

使用 [chezmoi 的引导命令](https://www.chezmoi.io/user-guide/daily-operations/#install-chezmoi-and-your-dotfiles-on-a-new-machine-with-a-single-command)安装整套配置：

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$(mktemp -d)" init --apply liby
```

`-b` 把引导安装用的二进制放进临时目录；之后使用和更新的 chezmoi 由 `Brewfile` 管理。

如果安装失败，请先解决报错，再重新运行同一条命令，按 [chezmoi 的脚本生命周期](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/)继续安装。

如果这台 Mac 上已经安装了 chezmoi，运行：

```sh
chezmoi init --apply liby
```

安装完成后运行 `gh auth login`：Git 通过 HTTPS 推送到 GitHub、拉取私有仓库时使用这个登录，后台升级任务也只有在登录 GitHub 后才能更新 gh 扩展。

如果使用 Rex，请手动安装并打开它，再从普通 Rex pane 运行一次 `setup-rex`。`chezmoi apply` 写入的 Rex 设置在重新打开应用后生效。

## 常用操作

通过 [chezmoi 的日常工作流程](https://www.chezmoi.io/user-guide/daily-operations/)编辑和应用受管理的文件。排查本仓库的初始化问题时，运行 `chezmoi apply -v`，实时显示脚本每一步的完整输出。

[编辑加密文件](https://www.chezmoi.io/reference/commands/edit-encrypted/)时需要使用 YubiKey，不应该交由 agent 处理。

## 更新已有配置的机器

更新已有的 Mac 或向 fork 合并上游变更时，请检查这台机器上次应用版本之后的提交，确认哪些路径和字段需要清理。删除前先核对当前内容，保留仍然需要的本地修改。应用新版本[不会清理所有已退役的配置](CONCEPTS.md#configuration-ownership)，即使 `chezmoi status` 没有输出。

如果 `.chezmoi.toml.tmpl` 有变动，先运行 [`chezmoi init`](https://www.chezmoi.io/reference/commands/init/)重新生成本机配置，再应用。

## 参与贡献

修改本仓库前，请先阅读 [`AGENTS.md`](../AGENTS.md)，其中记录了仓库的工作流程、安全边界和验证要求。发现问题时，可以创建 [issue](https://github.com/liby/dotfiles/issues/new)；如需提交修改，可以创建 [pull request](https://github.com/liby/dotfiles/pulls)。

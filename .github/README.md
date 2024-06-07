<h4 align="right">
  <strong>简体中文</strong> | <a href="https://github.com/liby/dotfiles/blob/main/.github/README_EN.md">English</a>
</h4>

<div>
  <h1 align="center">My Dotfiles</h1>
</div>

> **Note**
>
> 这是我个人的 dotfiles 仓库，用于配置和管理我的开发环境。通过这个仓库，我可以在不同的 Mac 上轻松地保持一致的开发环境。

## 项目简介

本仓库包含了一系列配置文件和脚本，用于设置和管理我的开发环境，包括但不限于：
- Git 配置，如： [_.config/git_](https://github.com/liby/dotfiles/tree/main/.config/git)
- Homebrew 备份文件：[_Brewfile_](https://github.com/liby/dotfiles/blob/main/Brewfile)
- Shell 配置，如：[_.zshrc_](https://github.com/liby/dotfiles/blob/main/.zshrc)
- SSH 配置，如：[_.ssh/config_](https://github.com/liby/dotfiles/blob/main/.ssh/config)
- 开发环境的初始化脚本：[_.config/scripts/macos-bootstrap.zsh_](https://github.com/liby/dotfiles/blob/main/.config/scripts/macos-bootstrap.zsh)
- 终端配置，如：[_.config/starship_](https://github.com/liby/dotfiles/tree/main/.config/starship)

## 安装说明

### 1. 克隆仓库

首先，克隆本仓库到本地：
```sh
git clone --bare <git_url> $HOME/.dotfiles
```

### 2. 定义别名

为了更方便地管理 dotfiles，你可以添加以下别名到你的 shell 配置文件（如 _.zshrc_ 或 _.bashrc_）：
```sh
alias dot='$(command -v git) --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
```

然后，重新加载你的 shell 配置：
```sh
source ~/.zshrc  # 如果你使用的是 Zsh
# 或者
source ~/.bashrc  # 如果你使用的是 Bash
```

### 3. 隐藏未跟踪文件

为了避免在使用 `dot` 命令时看到未跟踪的文件列表，可以使用以下命令：
```sh
dot config --local status.showUntrackedFiles no
```

如果不设置的话，运行 `dot status` 你会发现列出来一大堆 untracked files，因为 `$HOME` 下所有文件都还没加入 Git 跟踪，但我们本意也不是要跟踪所有文件，这样全部列出来看着比较乱。

### 4. 检出文件

使用以下命令将仓库中的文件检出到你的 `$HOME` 目录：
```sh
dot checkout
```

如果遇到文件冲突，比如下面这种报错：
```
error: The following untracked working tree files would be overwritten by checkout:
  .zshrc
Please move or remove them before you can switch branches.
Aborting
```

可以先备份已有的配置文件：
```sh
mkdir -p .dotfiles-backup
dot checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} .dotfiles-backupp/{}
```

然后再次尝试检出文件：

```sh
dot checkout
```

## 使用方法

你可以使用以下命令来管理你的 dotfiles：
```sh
dot add <file>：添加文件到仓库
dot commit -m "message"：提交更改
dot remote add origin <git_url>：配置远程仓库
dot push -u origin <branch>：推送 commit 到远程仓库，同时将远程仓库与本地的 branch 分支关联
dot push：推送更改到远程仓库
dot pull：从远程仓库拉取更新
```

## 快捷方式（可选）

对于上面这些步骤，操作起来还是比较繁琐的；有一些并不是经常使用的命令，所以也不容易记得。

因此，我们可以写一个脚本来达到一劳永逸的效果，就像 [The best way to store your dotfiles: A bare Git repository](https://www.atlassian.com/git/tutorials/dotfiles#:~:text=you%20can%20create%20a%20simple%20script) 中提到的那样：
  1. 创建一个脚本
  2. 存储为代码片段，可以使用 https://paste.gg/ 之类的网站
  3. 为其创建一个短链接

我自己也有一个用于配置开发环境的[初始化脚本](https://github.com/liby/dotfiles/blob/main/.config/scripts/macos-bootstrap.zsh)，当我拿到一台新的 Mac 时，只需要打开 Terminal.app，运行下面的命令即可完成开发环境的设置：
```sh
curl -o /tmp/macos-bootstrap.zsh https://raw.githubusercontent.com/liby/dotfiles/main/.config/scripts/macos-bootstrap.zsh && chmod +x /tmp/macos-bootstrap.zsh && /tmp/macos-bootstrap.zsh
```
非常方便。

## 贡献指南

如果你有任何改进建议或发现了问题，欢迎提交 Issue 或 Pull Request。
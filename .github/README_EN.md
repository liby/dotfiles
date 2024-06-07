<h4 align="right">
   <a href="https://github.com/liby/dotfiles/blob/main/.github/README_EN.md">简体中文</a> | <strong>English</strong>
</h4>

<div>
  <h1 align="center">My Dotfiles</h1>
</div>

> **Note**
>
> This is my personal dotfiles repository used to configure and manage my development environment. With this repository, I can easily maintain a consistent development environment across different Mac.

## Project Overview

This repository contains a series of configuration files and scripts used to set up and manage my development environment, including but not limited to:
- Git configuration, such as: [_.config/git_](https://github.com/liby/dotfiles/tree/main/.config/git)
- Homebrew Bundle Backup: [_Brewfile_](https://github.com/liby/dotfiles/blob/main/Brewfile)
- Initialization script: [_.config/scripts/macos-bootstrap.zsh_](https://github.com/liby/dotfiles/blob/main/.config/scripts/macos-bootstrap.zsh)
- Shell configuration, such as: [_.zshrc_](https://github.com/liby/dotfiles/blob/main/.zshrc)
- SSH configuration, such as: [_.ssh/config_](https://github.com/liby/dotfiles/blob/main/.ssh/config)
- Terminal configuration, such as: [_.config/starship_](https://github.com/liby/dotfiles/tree/main/.config/starship)

These files are managed using a Git Bare Repo. This method allows me to keep my $HOME directory clean while using Git to manage my configuration files. If you’re interested in the rationale behind this and want to learn more about managing dotfiles with a Git Bare Repo, feel free to read [a document](https://note.itswhat.me/#/page/%E4%BD%BF%E7%94%A8%20git%20bare%20repo%20%E6%9D%A5%E7%AE%A1%E7%90%86%20dotfiles) (only Chinese) I previously wrote on this topic.

## Installation Instructions

### 1. Clone the repository

First, clone this repository to your local machine:
```sh
git clone --bare <git_url> $HOME/.dotfiles
```

### 2. Define alias

To manage dotfiles more conveniently, you can add the following alias to your shell configuration file (such as _.zshrc_ or _.bashrc_):
```sh
alias dot='$(command -v git) --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
```

Then, reload your shell configuration:
```sh
source ~/.zshrc  # If you are using Zsh
# or
source ~/.bashrc  # If you are using Bash
```

### 3. Hide untracked files

To avoid seeing a large list of untracked files when using the `dot` command, you can use the following command:
```sh
dot config --local status.showUntrackedFiles no
```

If this is not set, running `dot status` will list a large number of untracked files because not all files in `$HOME` are tracked by Git, and we don't intend to track all of them, which can make the output cluttered.

### 4. Checkout files

Use the following command to check out the files from the repository to your `$HOME` directory:
```sh
dot checkout
```

If you encounter file conflicts, such as the following error:
```
error: The following untracked working tree files would be overwritten by checkout:
  .zshrc
Please move or remove them before you can switch branches.
Aborting
```

You can back up your existing configuration files first:
```sh
mkdir -p .dotfiles-backup
dot checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} .dotfiles-backup/{}
```

Then try checking out the files again:
```sh
dot checkout
```

## Usage

You can use the following commands to manage your dotfiles:

```sh
dot add <file>: Add file to the repository
dot commit -m "message": Commit changes
dot remote add origin <git_url>: Set up the remote repository
dot push -u origin <branch>: Push commits to the remote repository and link the remote branch to the local branch
dot push: Push changes to the remote repository
dot pull: Pull updates from the remote repository
```

### Shortcuts (Optional)

The steps above can be cumbersome; some of the commands are not used frequently, so they can be hard to remember.

Therefore, we can create a script to simplify these operations, as mentioned in The best way to store your dotfiles: A bare Git repository:
  1. Create a script.
  2. Save it as a code snippet using a site like https://paste.gg.
  3. Create a short link for it.

I also have an [initialization script](https://github.com/liby/dotfiles/blob/main/.config/scripts/macos-bootstrap.zsh) for setting up my development environment. When I get a new Mac, I just need to open Terminal.app and run the following command to complete the setup:
```sh
curl -o /tmp/macos-bootstrap.zsh https://raw.githubusercontent.com/liby/dotfiles/main/.config/scripts/macos-bootstrap.zsh && chmod +x /tmp/macos-bootstrap.zsh && /tmp/macos-bootstrap.zsh
```
It's very convenient.

## Contribution Guidelines

If you have any suggestions for improvement or find any issues, please feel free to submit an Issue or a Pull Request.
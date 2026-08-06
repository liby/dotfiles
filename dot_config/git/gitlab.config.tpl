[user]
  email = @GITLAB_EMAIL@
  name = @GITLAB_NAME@
  signingkey = @SIGNINGKEY@

[commit]
  gpgsign = true

[core]
  sshCommand = ~/.config/git/git-ssh-gpg-agent --transport

[gpg]
  format = ssh

[gpg "ssh"]
  allowedSignersFile = ~/.ssh/allowed_signers
  program = ~/.config/git/git-ssh-gpg-agent

[ssh]
  variant = ssh

[tag]
  gpgsign = true

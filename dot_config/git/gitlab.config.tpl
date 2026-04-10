[user]
  email = @GITLAB_EMAIL@
  name = @GITLAB_NAME@
  signingkey = @SIGNINGKEY@

[commit]
  gpgsign = true

[gpg]
  format = ssh

[gpg "ssh"]
  allowedSignersFile = ~/.ssh/allowed_signers

[tag]
  gpgsign = true

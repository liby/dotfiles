## Execution Host

Create new Git worktrees outside every project checkout; Git ignore rules do not keep recursive build, lint, and test tools from scanning nested sources. Use a stable external directory when the worktree must survive the task.

Run headless browser jobs only with a dedicated binary such as puppeteer's Chrome for Testing or chrome-headless-shell, under a finite deadline, and kill the process when the job ends. Never use `/Applications/Google Chrome.app`: a hung headless job captures the GUI app identity.

Never start gpg-agent or keyboxd from a sandboxed shell: inherited sandboxing prevents YubiKey access, and launchd owns startup. Recover these errors as the login user, never sudo, and from a shell outside the sandbox that raised them, since the sandbox can block the launchd kickstart or the agent socket regardless of the daemon's state. The two `running in this session` errors below also appear while the daemon is running but its socket is unreachable, so rule out a sandbox socket denial before restarting anything:

- `no gpg-agent running in this session` or `No pinentry`: `gpgconf --kill gpg-agent && launchctl kickstart gui/$UID/org.gnupg.gpg-agent`.
- `no keyboxd running in this session`: `gpgconf --kill keyboxd && launchctl kickstart gui/$UID/org.gnupg.keyboxd`.

## Execution Host

Create new Git worktrees outside every project checkout; Git ignore rules do not keep recursive build, lint, and test tools from scanning nested sources. Use a stable external directory when the worktree must survive the task.

Run headless browser jobs only with a dedicated binary such as puppeteer's Chrome for Testing or chrome-headless-shell, under a finite deadline, and kill the process when the job ends. Never use `/Applications/Google Chrome.app`: a hung headless job captures the GUI app identity.

Scope filesystem searches to the checkout or an explicit target. A recursive scan that walks from `$HOME`, `/`, or `~/Library` reads other apps' data containers, and macOS records each one as a Files & Folders App Data entry under this process's responsible app, so keep `~/Library` (including its `Containers`, `Group Containers`, `Mobile Documents`, and `CloudStorage` subtrees) out of traversals and name the one path a task needs instead.

Never start gpg-agent or keyboxd from a sandboxed shell: inherited sandboxing prevents YubiKey access, and launchd owns startup. Recover these errors as the login user, never sudo, and from a shell outside the sandbox that raised them, since the sandbox can block the launchd kickstart or the agent socket regardless of the daemon's state. The two `running in this session` errors below also appear while the daemon is running but its socket is unreachable, so rule out a sandbox socket denial before restarting anything:

- `no gpg-agent running in this session` or `No pinentry`: `gpgconf --kill gpg-agent && launchctl kickstart gui/$UID/org.gnupg.gpg-agent`.
- `no keyboxd running in this session`: `gpgconf --kill keyboxd && launchctl kickstart gui/$UID/org.gnupg.keyboxd`.

In a sandbox that denies writes to `~/.gnupg`, signing works but verifying an OpenPGP signature hangs: gpg cannot open its trust database, and GnuPG 2.5.24 deadlocks on that fatal error instead of exiting. Git picks the verifier from each signature, not from `gpg.format`, so any `%G` format placeholder (`%G?`, `%GS`, `%GK`, and the rest), `verify-commit`, `verify-tag` or `tag -v`, `--verify-signatures`, or `--show-signature` hangs as soon as one commit or tag it checks carries an OpenPGP signature (`-----BEGIN PGP SIGNATURE-----` in `git cat-file`), and a plain `gpg --verify` hangs the same way; SSH signatures go to `ssh-keygen` and are unaffected. Verify OpenPGP signatures outside the sandbox; where no such path exists, run `gpg --trust-model always --verify` on the signature and payload split out of `git cat-file`, which skips the trust database, or report the check as not run. Remove this once gpg exits on that error.

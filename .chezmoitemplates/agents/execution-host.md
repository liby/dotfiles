## Execution Host

Create scratch files and directories in runtime-provided temporary space under unique names, such as those `mktemp` returns, keep each path, and remove exactly those paths once the task no longer needs them. Other sessions and agents share that space and the machine's temporary roots such as `/tmp`, so never delete in shared temporary space by a wildcard or by any path other than one you created and kept.

Create new Git worktrees outside every project checkout, since Git ignore rules do not keep recursive build, lint, and test tools from scanning nested sources. Put a worktree that must survive the task in `~/Code/worktrees`. Any other worktree is scratch, and the directory `mktemp -d` returns is the worktree itself, as in `wt=$(mktemp -d "$TMPDIR/<repo>-wt.XXXXXX") && git worktree add "$wt" <ref>`: Git names the worktree's metadata after that directory's name, and a sandbox can keep denying a name registered earlier in the session.

For headless browser jobs you launch, use a dedicated automation binary such as Chrome for Testing or chrome-headless-shell. Set a finite execution deadline and ensure the job's browser processes terminate when the job ends or times out. Never launch these jobs with `/Applications/Google Chrome.app`: a hung headless instance can hold the Chrome app identity and prevent normal GUI launches. When connected to the user's existing browser, release automation control when finished instead of terminating the browser or closing the user's tabs.

Scope filesystem searches to the checkout or an explicit target. A recursive scan that walks from `$HOME`, `/`, or `~/Library` reads other apps' data containers, and macOS records each one as a Files & Folders App Data entry under this process's responsible app, so keep `~/Library` (including its `Containers`, `Group Containers`, `Mobile Documents`, and `CloudStorage` subtrees) out of traversals and name the one path a task needs instead.

Never start gpg-agent or keyboxd from a sandboxed shell: inherited sandboxing prevents YubiKey access, and launchd owns startup. Recover these errors as the login user, never sudo, and from a shell outside the sandbox that raised them, since the sandbox can block the launchd kickstart or the agent socket regardless of the daemon's state. The two `running in this session` errors below also appear while the daemon is running but its socket is unreachable, so rule out a sandbox socket denial before restarting anything:

- `no gpg-agent running in this session` or `No pinentry`: `gpgconf --kill gpg-agent && launchctl kickstart gui/$UID/org.gnupg.gpg-agent`.
- `no keyboxd running in this session`: `gpgconf --kill keyboxd && launchctl kickstart gui/$UID/org.gnupg.keyboxd`.

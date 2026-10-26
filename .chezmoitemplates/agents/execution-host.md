## Execution Host

Create scratch files and directories in runtime-provided temporary space under unique names, such as those `mktemp` returns, keep each path, and remove exactly those paths once the task no longer needs them. Other sessions and agents share that space and the machine's temporary roots such as `/tmp`, so never delete in shared temporary space by a wildcard or by any path other than one you created and kept.

Create new Git worktrees outside every project checkout, since Git ignore rules do not keep recursive build, lint, and test tools from scanning nested sources. Put a worktree that must survive the task in `~/Code/worktrees`. Any other worktree is scratch, and the directory `mktemp -d` returns is the worktree itself, as in `wt=$(mktemp -d "$TMPDIR/<repo>-wt.XXXXXX") && git worktree add "$wt" <ref>`: Git names the worktree's metadata after that directory's name, and a sandbox can keep denying a name registered earlier in the session.

For headless browser jobs you launch, use a dedicated automation binary such as Chrome for Testing or chrome-headless-shell. Set a finite execution deadline and ensure the job's browser processes terminate when the job ends or times out. Never launch these jobs with `/Applications/Google Chrome.app`: a hung headless instance can hold the Chrome app identity and prevent normal GUI launches. When connected to the user's existing browser, release automation control when finished instead of terminating the browser or closing the user's tabs.

Scope filesystem searches to the checkout or an explicit target. A recursive scan that walks from `$HOME`, `/`, or `~/Library` reads other apps' data containers, and macOS records each one as a Files & Folders App Data entry under this process's responsible app, so keep `~/Library` (including its `Containers`, `Group Containers`, `Mobile Documents`, and `CloudStorage` subtrees) out of traversals and name the one path a task needs instead.

gpg-agent and keyboxd run as launchd jobs, and `no-autostart` keeps every client, `gpgconf --launch` included, from starting them. Act on the error a signing or decryption failure prints:

- `signing failed: Operation cancelled` after pinentry launched, `Bad PIN`, or a card error such as `selecting card failed`: the YubiKey is waiting for the user to enter the PIN, touch it, or plug it in, and `gpg --card-status` shows whether it is plugged in. gpg-agent launches pinentry outside any agent sandbox, so leaving the sandbox or restarting the daemon does not help; tell the user what the key needs and retry once after they reply.
- `no gpg-agent running in this session` or `No pinentry`: `gpgconf --kill gpg-agent && launchctl kickstart gui/$UID/org.gnupg.gpg-agent`.
- `no keyboxd running in this session`: `gpgconf --kill keyboxd && launchctl kickstart gui/$UID/org.gnupg.keyboxd`.

Run these as the login user, never with sudo; they work inside the sandbox, because launchd starts the daemon outside it. Never start a daemon directly: one started from a sandboxed shell keeps that sandbox and cannot reach the YubiKey.

# GnuPG recovery

## YubiKey errors

gpg-agent starts pinentry outside the sandbox. Restarting a daemon or leaving the sandbox cannot resolve a card error, a bad PIN, or a cancellation after pinentry opens.

- If an authorized commit fails with a card error (such as `selecting card failed`) or `signing failed: Operation cancelled` after pinentry opens, retry the commit with `--no-gpg-sign`. Carry out any authorized push and report that the commit is unsigned.
- For `Bad PIN` on any operation, tell the user the YubiKey needs the correct PIN.
- For a card error or cancellation on any other operation, use `gpg --card-status` to check whether the YubiKey is plugged in and tell the user whether to insert it, enter its PIN, or touch it.

## Daemon errors

gpg-agent and keyboxd run as launchd jobs. With `no-autostart`, clients including `gpgconf --launch` cannot start them. Run the matching command as the login user, without sudo:

- `no gpg-agent running in this session` or `No pinentry`: `gpgconf --kill gpg-agent && launchctl kickstart gui/$UID/org.gnupg.gpg-agent`.
- `no keyboxd running in this session`: `gpgconf --kill keyboxd && launchctl kickstart gui/$UID/org.gnupg.keyboxd`.

These commands work from inside the sandbox because launchd starts the daemon outside it. Never start the daemon directly from a sandboxed shell: it would inherit the sandbox and lose access to the YubiKey.

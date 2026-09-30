# Herdr saved machines

A saved machine is a connection profile, not a pane inventory. IDs and agent names belong to one server; two machines can both have `w1:p1` or `reviewer`. Switching the TUI's selected machine does not retarget your pane's CLI calls.

Discover profiles with `herdr machine list --json`. Use the same enabled profile ID or unique case-sensitive label for discovery and every subsequent control command:

```bash
herdr --machine <label-or-id> agent list
herdr --machine <label-or-id> pane list
herdr --machine <label-or-id> agent prompt <remote-agent-name> '<task>' --wait --timeout <milliseconds>
```

Do not combine `--machine` with `--session` or `--remote`. Discover targets on that machine; local caller IDs and `--current` do not identify remote panes. Forwarding requires API-compatible installations and an already-running remote server. It neither installs nor starts a server and never falls back to Local. Local configuration, session management, installation, and interactive attachment are not forwarded. Remote worktree paths must be absolute, `~`, or start with `~/`; plugin link paths must be absolute. After a connection failure, query the remote result before retrying a mutation.

Use `herdr machine status [<label-or-id>] --json` to diagnose a failing saved connection. Reconnect requires SSH authentication in the user's terminal; hand the exact `herdr machine reconnect <label-or-id>` command to the user. Do not restart a server to repair that connection.

Profile add/remove/enable/disable change which remote installation later commands reach, so perform them only for the requested target. Interactive `machine add` discovers running remote sessions and may ask the user to choose; non-interactive setup uses the remote default unless `--remote-session` is supplied. Add can install or start Herdr remotely; incompatible replacement requires approval for that effect. Removing or disabling a profile leaves its remote sessions running. Experimental handoff is separate from machine add.

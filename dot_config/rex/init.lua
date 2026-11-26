require("actions.confirm_close")

-- Ctrl+_ (decimal 31) is the undo key of zsh's line editor and of agent prompts such as Claude Code's and Pi's.
rex.bind("cmd+z", "com.superlogical.terminal.write", { data = "\031" })
rex.bind("cmd+w", "confirm_close")
rex.bind("alt+cmd+w", "confirm_close_tab")

-- Rexume reopens these agents' conversations. Rex's Claude Code hook reports a resume command that
-- the built-in rule would run in the same pane, racing Rexume, and that command reruns the launch
-- flags, where Rexume restores the model, effort, and permission mode last used and continues a
-- cut-off turn once. Codex and OpenCode have rules but no reporter yet; these keep the race away
-- once one reports.
rex.set("resume.trust.claude", false)
rex.set("resume.trust.codex", false)
rex.set("resume.trust.opencode", false)

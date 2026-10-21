require("actions.confirm_close")

-- Ctrl+_ (decimal 31) is the undo key of zsh's line editor and of agent prompts such as Claude Code's and Pi's.
rex.bind("cmd+z", "com.superlogical.terminal.write", { data = "\031" })
rex.bind("cmd+w", "confirm_close")

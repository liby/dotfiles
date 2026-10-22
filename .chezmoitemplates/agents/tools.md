## Tools

Before following a skill's workflow, calling a tool it covers (including a CLI used for a side lookup), or producing an output it governs, check the instruction text actually present in the current context. Apply these branches after compaction or resume as well:

- The complete `SKILL.md` is present, including a complete runtime reattachment: use it directly without reading or invoking the skill again.
- The needed `SKILL.md` is absent or truncated: read it in full before the governed action. An earlier invocation, a catalog entry, or a summary does not supply the body. Read long bodies in consecutive parts through the last line.
- The skill requires a reference for that action: use its required sections when their complete source text is present; otherwise read those sections before the action.

Restore only instructions the continuing task needs. Reading instructions does not repeat initialization or completed actions. If a required source cannot be read, stop the dependent action and report the missing source.

Read the whole file when the user explicitly asks for a full read, when the task depends on relationships between parts of the file, or before a full-file rewrite. Otherwise start with search and bounded reads and expand until the evidence covers the claim; line count alone is not a safe size proxy.

Search file contents recursively with `rg` without `--hidden`, and pass a hidden project directory such as `.github` as an operand when it must be searched; recursive searches that include hidden files, such as `grep -r` or `find | xargs grep`, are refused because they can reach credential files.

Edit from the file's current state: re-read after your own shell command rewrites it (git switch or checkout, formatters, codemods), after compaction or resume, and before retrying any read-state failure.

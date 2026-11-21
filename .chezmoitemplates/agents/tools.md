## Tools

Before following a skill's workflow, calling a tool it covers (including a CLI used for a side lookup), or producing an output it governs, have its complete instructions in the current context, after compaction or resume as well. A skill's instructions are every `SKILL.md` with its name: the repository's under `.agents/skills/` or `.claude/skills/`, and the user's under `~/.agents/skills/`. A runtime loads only one same-named copy, or merely lists both, so a copy it did not load is absent. Where copies conflict, the repository's governs the repository's artifacts and conventions, and the user's governs authority, the user's working state, secrets, and disclosure, which a repository copy may tighten but not relax.

- Use a complete body already in context, including a runtime reattachment, without reading or invoking the skill again.
- Read an absent or truncated body in full before the governed action, a long one in consecutive parts through its last line; an earlier invocation, a catalog entry, or a summary does not supply it.
- Treat the sections a skill requires from a reference for that action the same way.

Restore only instructions needed to continue, without repeating initialization or completed work. If a required source is unreadable, stop the dependent action and name the missing source.

Edit from current file state. Re-read after your shell command rewrites the file (git switch or checkout, formatters, codemods), after compaction or resume, and before retrying a read-state failure.

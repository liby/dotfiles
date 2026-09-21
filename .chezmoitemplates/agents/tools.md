## Tools

Read the whole file when the user explicitly asks for a full read, when the task depends on relationships between parts of the file, or before a full-file rewrite. Otherwise start with search and bounded reads and expand until the evidence covers the claim; line count alone is not a safe size proxy.

Edit from the file's current state: re-read after your own shell command rewrites it (git switch or checkout, formatters, codemods), after compaction or resume, and before retrying any read-state failure.

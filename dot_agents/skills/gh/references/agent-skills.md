# GitHub-Hosted Agent Skills

Use `gh skill` instead of manually downloading a GitHub-hosted `SKILL.md`.

For install or update, use the destination resolved from the request and governing instructions as `--dir <skill-directory>`; do not substitute the CLI's default install path. In `gh` 2.98, a non-interactive install defaults to project-scoped GitHub Copilot, and `--agent codex --scope user` selects `~/.codex/skills`. An explicit `--dir` overrides both agent and scope.

Read-only path:

```bash
gh skill preview <owner/repo> <skill>
gh skill update <skill> --all --dry-run --dir <skill-directory>
```

Write path, only after explicit request:

```bash
gh skill install <owner/repo> <skill> --dir <skill-directory>
gh skill update <skill> --all --dir <skill-directory>
```

Use the exact requested skill names for preview and update. On `gh` 2.98, `--all` suppresses the confirmation after that name filter; never run it without explicit skill names. When current and candidate metadata expose comparable release refs, stop on a version regression unless the user explicitly requested the downgrade. Review the whole directory replacement before applying an update: the current implementation can remove extra local files despite its help text.

Use `--from-local` only when the user asks to install from a local directory. Use `--allow-hidden-dirs` only when the source repo stores skills under hidden directories.

If `gh skill update` prompts for missing source metadata, answer only when the original repo is known. Otherwise reinstall from a known source instead of guessing provenance.

Local skill removal is a filesystem workflow, not a `gh skill` operation in the verified help. Do not remove local skill directories from this skill unless a current `gh skill remove --help` command exists and documents the removal mode.

# Agent Skills

`dot_agents/skills` is the canonical skill tree. Chezmoi deploys it to `~/.agents/skills`.

`dot_claude/symlink_skills` deploys `~/.claude/skills -> ../.agents/skills`. Claude Code discovers personal skills from `~/.claude/skills`, so the symlink makes the shared `~/.agents/skills` tree visible to Claude Code without duplicating files.

Installing a local skill directly into `~/.agents/skills/<name>` is visible through `~/.claude/skills/<name>`. Chezmoi will not know about that skill unless it is later added to `dot_agents/skills`.

Do not manage `~/.agents/.skill-lock.json` in chezmoi. It is mutable `gh skill` install state. Updates are driven by GitHub metadata embedded in each installed `SKILL.md`.

`gh skill update` defaults to scanning every known agent host directory. In `gh 2.92.0`, Cline/Warp use `~/.agents/skills` as a user directory, and Claude Code uses `~/.claude/skills`; the updater deduplicates literal paths, not resolved symlink targets. Because those two paths point to the same directory here, default scanning reports local skills twice. Use a single canonical root when checking updates:

```sh
gh skill update --dry-run --dir ~/.agents/skills
```

Avoid project-scope installs in company repositories. `gh skill install --scope project` can write `$PWD/.agents/skills`, and the global gitignore does not ignore `.agents/`.

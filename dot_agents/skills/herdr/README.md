# Herdr local policy

This directory is a chezmoi-managed customization of Herdr's official agent
skill. It is a shared transport skill for Codex TUI and Claude Code, not a
Codex-review wrapper or a Claude-only agent definition.

## Upstream provenance

- Repository: `https://github.com/herdrdev/herdr`
- License: Apache-2.0
- Release: `v0.8.0`
- Release commit: `346411fa21afd297f5ed3b3fa56f9e3fbf7654b7`
- Release root tree: `a0997075215a7ffda63399049e0292e75dc14962`
- Skill directory tree: `4821f1d39ccae24b9b274b03184edaaf198a3994`
- Upstream `SKILL.md` blob: `fafea549c0c46b87bac6c7ae4ad22ef7ac635a5e`

`SKILL.md` retains the source metadata injected by `gh skill install`. The
installed Herdr `0.8.0` binary and the pinned upstream skill were the reviewed
baseline. The upstream skill was also unchanged on `master` when this local
version was created.

## Initial scope

The skill intentionally supports only the common path:

- refuse control outside a Herdr-managed process;
- inspect panes and recognized agents using explicit IDs or names;
- split a sibling pane without changing focus or working directory;
- start, label, prompt, wait for, and read an agent;
- run and observe one ordinary shell command in another pane; and
- recover from blocked state, ambiguous submission, or truncated TUI output.

It does not contain review policy. A spawned Codex or Claude instance can use
whatever skills that client normally loads, including a separate review skill,
without Herdr knowing about that workflow.

Herdr integrations for Claude and Codex are optional session-restore helpers,
managed separately and only when explicitly requested; they are not
prerequisites for this skill.

## Local deltas

The local skill keeps the official execution boundary and adds a small set of
observed rules:

- Reuse a named, settled agent only when continuity is useful; never prompt a
  working agent whose current turn could satisfy the new wait.
- Give agents role-based names and matching pane labels. Add a short mnemonic
  suffix when several agents have the same role instead of referring to opaque
  pane IDs in conversation.
- Use `herdr --skill` as the binary-matched reference after an upgrade or
  command mismatch. Do not reload it on every task: this installed skill already
  carries the local policy that the upstream text does not know about.
- Use finite lifecycle waits, retain the default `idle`/`done`/`blocked`
  settlement, and always read the state afterward.
- After starting an agent, inspect its visible screen before sending work. This
  fails closed around the Codex first-run readiness race in Herdr `0.8.0`.
- Treat `pane wait-output` as a search over existing output: match fresh,
  task-specific evidence rather than a generic completion word.
- Keep concurrent helpers read-only in one checkout. Isolated writer worktrees
  remain an explicit topology choice, not an automatic side effect.
- Use a temporary Markdown artifact only when alternate-screen output cannot be
  recovered through `recent-unwrapped` reads.

These rules were cross-checked against the installed CLI, Herdr's official
automation documentation, the open `v0.8.0` readiness/submission issues, and
current community reports about readable pane labels and `herdr --skill`.

## Updating

An overwrite-style skill update would erase local policy. Review upstream
manually instead:

```bash
gh skill preview herdrdev/herdr herdr@<new-release>
herdr --version
herdr --skill
```

Compare the new upstream behavior with the installed CLI, reconcile only the
still-relevant local deltas, update the provenance metadata, run the shared
skills validator, then apply the source to `~/.agents/skills/herdr`. Add future
workflows only after a real use case exposes a missing decision; do not grow the
skill into a general scheduler in advance.

import { expect, test } from "bun:test";

test("managed requirements keep the sole mode and hook", async () => {
  const requirements = Bun.TOML.parse(
    await Bun.file(
      new URL("../../.chezmoitemplates/codex/requirements.toml", import.meta.url),
    ).text(),
  ) as {
    default_permissions: string;
    allowed_approval_policies: string[];
    allowed_approvals_reviewers: string[];
    allowed_permission_profiles: Record<string, boolean>;
    hooks: { managed_dir: string } & Record<string, Array<{ matcher?: string; hooks: Array<{ command: string }> }>>;
  };

  expect({
    default_permissions: requirements.default_permissions,
    allowed_approval_policies: requirements.allowed_approval_policies,
    allowed_approvals_reviewers: requirements.allowed_approvals_reviewers,
    allowed_permission_profiles: requirements.allowed_permission_profiles,
  }).toEqual({
    default_permissions: "development",
    allowed_approval_policies: ["on-request"],
    allowed_approvals_reviewers: ["auto_review"],
    allowed_permission_profiles: { development: true },
  });

  // Codex documents that managed hook commands use absolute script paths under
  // managed_dir; chezmoi deploys this directory there.
  const { managed_dir: managedDir, ...events } = requirements.hooks;
  expect(managedDir).toBe("{{ .chezmoi.homeDir }}/.codex/managed-hooks");
  for (const command of Object.values(events).flat().flatMap((entry) => entry.hooks.map((h) => h.command))) {
    expect({ command, underManagedDir: command.startsWith(`${managedDir}/`) }).toEqual({ command, underManagedDir: true });
  }

  const registered = requirements.hooks.PreToolUse;
  expect(registered).toHaveLength(1);
  const { hooks, ...entry } = registered[0];
  expect(entry).toEqual({ matcher: "^Bash$" });
  expect(hooks).toHaveLength(1);
  const { timeout, ...hook } = hooks[0] as Record<string, string | number>;
  expect(hook).toEqual({
    type: "command",
    command: "{{ .chezmoi.homeDir }}/.codex/managed-hooks/guard-bash",
  });
  // A finite deadline is the invariant; no document owns the value.
  expect(Number(timeout)).toBeGreaterThan(0);
});

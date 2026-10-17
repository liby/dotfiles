import { expect, test } from "bun:test";
import { readdirSync } from "node:fs";

type Hook = { type: string; command: string; timeout: number };
const parse = async <T>(path: string) => Bun.TOML.parse(await Bun.file(new URL(path, import.meta.url)).text()) as T;

test("managed requirements keep the sole mode and run every managed hook", async () => {
  const requirements = await parse<{
    default_permissions: string;
    allowed_approval_policies: string[];
    allowed_approvals_reviewers: string[];
    allowed_permission_profiles: Record<string, boolean>;
    hooks: { managed_dir: string } & Record<string, Array<{ matcher?: string; hooks: Hook[] }>>;
  }>("../../.chezmoitemplates/codex/requirements.toml");

  // The requirements admit exactly the tuple config.toml selects, so Desktop's
  // saved agent mode cannot substitute another approval policy or reviewer.
  const config = await parse<{ approval_policy: string; approvals_reviewer: string; default_permissions: string }>(
    "../../.chezmoitemplates/codex/config.toml",
  );
  expect({
    default_permissions: requirements.default_permissions,
    allowed_approval_policies: requirements.allowed_approval_policies,
    allowed_approvals_reviewers: requirements.allowed_approvals_reviewers,
    allowed_permission_profiles: requirements.allowed_permission_profiles,
  }).toEqual({
    default_permissions: config.default_permissions,
    allowed_approval_policies: [config.approval_policy],
    allowed_approvals_reviewers: [config.approvals_reviewer],
    allowed_permission_profiles: { [config.default_permissions]: true },
  });

  // Codex runs managed hooks only from absolute paths under managed_dir, where
  // chezmoi deploys this directory; each registered script must be one of its
  // executable sources and each source must be registered.
  const { managed_dir: managedDir, ...events } = requirements.hooks;
  expect(managedDir).toBe("{{ .chezmoi.homeDir }}/.codex/managed-hooks");
  const hooks = Object.values(events).flat().flatMap((entry) => entry.hooks);
  for (const { type, command, timeout } of hooks) {
    expect({ command, type, underManagedDir: command.startsWith(`${managedDir}/`), timeout: timeout > 0 })
      .toEqual({ command, type: "command", underManagedDir: true, timeout: true });
  }
  const sources = readdirSync(import.meta.dir).flatMap((name) => name.match(/^executable_(.+)$/)?.[1] ?? []);
  expect([...new Set(hooks.map(({ command }) => command.slice(managedDir.length + 1)))].sort()).toEqual(sources.sort());

  // The guard is the one Bash check; see CONCEPTS.md#agent-guard.
  expect(events.PreToolUse.filter((entry) => entry.matcher === "^Bash$").flatMap((entry) => entry.hooks.map((h) => h.command)))
    .toEqual([`${managedDir}/guard-bash`]);
});

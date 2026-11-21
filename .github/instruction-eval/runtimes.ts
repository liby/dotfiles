// What a trial needs to know about each CLI: how to start it, which paths outside the workspace
// it must reach, where it loads the arm from, and which output event carries its reply. A CLI
// upgrade that breaks `selftest` is fixed here.
//
// Each arm goes above the project directory, where the trial's shell cannot read it and the CLI
// loads it ahead of the fixture's own instructions, as it loads the global file in a real session.

import { existsSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const HOME = homedir();
const claude = Bun.which("claude") ?? "claude";

export const RUNTIMES = {
  claude: {
    launcher: claude,
    // The launcher is a script; it reads its saved mode before the route flag overrides it and
    // reports a denied read on stderr.
    reads: [claude, join(HOME, ".config/claude-code/mode"), join(HOME, "Library/Keychains")],
    writes: [] as string[],
    // Without the route the launcher falls back to its saved mode, which can read other credentials.
    version: ["--subscription", "--version"],
    writeArm(root: string, cwd: string, arm: Buffer) {
      // A CLAUDE.md above the project keeps Claude Code from loading the project's AGENTS.md by
      // itself, so the arm imports it when the project has no CLAUDE.md of its own.
      const own = ["CLAUDE.md", ".claude/CLAUDE.md", "CLAUDE.local.md"].some((file) => existsSync(join(cwd, file)));
      const project = !own && existsSync(join(cwd, "AGENTS.md")) ? "\n@project/AGENTS.md\n" : "";
      writeFileSync(join(root, "CLAUDE.md"), arm + project);
    },
    command: (model: string, effort: string, _cwd: string, mcpUrl: string, maxTurns: number) => [
      "--subscription", "--print", "--no-session-persistence", "--output-format", "stream-json", "--verbose",
      "--model", model, "--effort", effort, "--max-turns", String(maxTurns),
      "--setting-sources", "project,local",
      "--settings", JSON.stringify({
        autoMemoryEnabled: false,
        disableAllHooks: true,
        outputStyle: "default",
        claudeMdExcludes: [join(HOME, ".claude/CLAUDE.md"), join(HOME, ".claude/rules/**")],
      }),
      "--disable-slash-commands", "--strict-mcp-config",
      "--mcp-config", JSON.stringify({ mcpServers: { terminal: { type: "http", url: mcpUrl } } }),
      "--tools", "", "--allowedTools", "mcp__terminal__run",
    ],
    reply: (event: any): string | undefined => (event.type === "result" ? event.result : undefined),
  },
  codex: {
    launcher: Bun.which("codex") ?? "codex",
    reads: [join(HOME, "Library/Keychains")],
    // Codex opens this for writing at startup and exits before any model turn without it;
    // its sign-in is keyed to the real home, so a separate CODEX_HOME cannot stand in.
    writes: [join(HOME, ".codex/installation_id")],
    version: ["--version"],
    // The real home's global file cannot be swapped, so the trial root becomes the project root.
    writeArm(root: string, _cwd: string, arm: Buffer) {
      writeFileSync(join(root, "AGENTS.md"), arm);
      writeFileSync(join(root, ".trial-root"), "");
    },
    command: (model: string, effort: string, cwd: string, mcpUrl: string, _maxTurns: number) => [
      "exec", "--ephemeral", "--json", "--ignore-user-config", "--ignore-rules", "--skip-git-repo-check",
      "-m", model,
      ...["shell_tool", "unified_exec", "apps", "view_image", "hooks", "memories", "multi_agent"]
        .flatMap((feature) => ["--disable", feature]),
      // --ignore-user-config also drops the credential store setting the sign-in needs.
      "-c", 'cli_auth_credentials_store="keyring"',
      "-c", `model_reasoning_effort=${JSON.stringify(effort)}`,
      "-c", 'web_search="disabled"',
      "-c", 'project_root_markers=[".trial-root"]',
      // The default limit is smaller than the shared instructions, and the model then never sees their end.
      "-c", "project_doc_max_bytes=262144",
      "-c", 'default_permissions="development"',
      "-c", `permissions.development.filesystem={":root"="read",${JSON.stringify(cwd)}="write"}`,
      "-c", `mcp_servers.terminal.url=${JSON.stringify(mcpUrl)}`,
      "-",
    ],
    reply: (event: any): string | undefined => (event.type === "item.completed" ? event.item?.text : undefined),
  },
};

export type RuntimeName = keyof typeof RUNTIMES;

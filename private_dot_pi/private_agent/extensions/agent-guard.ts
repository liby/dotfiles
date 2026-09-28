import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { spawnSync } from "node:child_process";

// The decisions belong to the shared guard; this adapter only translates each
// tool call into the Claude-shaped event the guard reads. find and ls list
// names without reading contents, so find is checked as a search root and ls
// as a read of its directory.
function guardEvent(toolName: string, input: Record<string, unknown>) {
  switch (toolName) {
    case "bash":
      return { tool_name: "Bash", tool_input: { command: input.command } };
    case "read":
    case "edit":
    case "write":
      return { tool_name: toolName, tool_input: { file_path: input.path } };
    case "grep":
      return { tool_name: "Grep", tool_input: { path: input.path, glob: input.glob } };
    case "find":
      return { tool_name: "Grep", tool_input: { path: input.path } };
    case "ls":
      return { tool_name: "Read", tool_input: { file_path: input.path ?? "." } };
  }
}

export default function (pi: ExtensionAPI) {
  const guard = "/opt/homebrew/bin/agent-guard";
  pi.on("tool_call", (event, ctx) => {
    const guardInput = guardEvent(event.toolName, event.input as Record<string, unknown>);
    if (!guardInput) return;
    const result = spawnSync(guard, ["--runtime", "pi"], {
      input: JSON.stringify({ ...guardInput, cwd: ctx.cwd }),
      encoding: "utf8",
      timeout: 5000,
    });
    if (result.status === 0) return;
    // Anything but a clean pass blocks, including a guard that could not run.
    const reason = result.status === 2 && result.stderr.trim();
    return { block: true, reason: reason || "The agent guard could not complete its check, so this call is blocked. Inspect the guard installation, repair the failure, then retry the call." };
  });
}

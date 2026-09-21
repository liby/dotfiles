import { expect, test } from "bun:test";

const hook = new URL(
  "./executable_contextual-markdown-links",
  import.meta.url,
).pathname;
test("injects link-placement context even when the prompt has no URLs", () => {
  const result = Bun.spawnSync(["/bin/zsh", "-f", hook], {
    stdin: new Blob([JSON.stringify({ prompt: "Draft a concise note." })]),
    stdout: "pipe",
    stderr: "pipe",
  });

  expect(result.exitCode).toBe(0);
  expect(result.stderr.toString()).toBe("");
  // Assert the payload contract, not the prose: a wording change must not fail here.
  const payload = JSON.parse(result.stdout.toString());
  expect(payload.hookSpecificOutput.hookEventName).toBe("UserPromptSubmit");
  const context = payload.hookSpecificOutput.additionalContext;
  expect(typeof context).toBe("string");
  expect(context.length).toBeGreaterThan(0);
});

test("managed requirements register the prompt hook", async () => {
  const requirements = Bun.TOML.parse(
    await Bun.file(
      new URL("../../.chezmoitemplates/codex/requirements.toml", import.meta.url),
    ).text(),
  ) as {
    hooks: {
      UserPromptSubmit: Array<{
        hooks: Array<Record<string, string | number>>;
      }>;
    };
  };

  const registered = requirements.hooks.UserPromptSubmit;
  expect(registered).toHaveLength(1);
  const { hooks, ...entry } = registered[0];
  expect(entry).toEqual({});
  expect(hooks).toHaveLength(1);
  const { timeout, ...hook } = hooks[0];
  expect(hook).toEqual({
    type: "command",
    command:
      "{{ .chezmoi.homeDir }}/.codex/managed-hooks/contextual-markdown-links",
  });
  // A finite deadline is the invariant; no document owns the value.
  expect(Number(timeout)).toBeGreaterThan(0);
});

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

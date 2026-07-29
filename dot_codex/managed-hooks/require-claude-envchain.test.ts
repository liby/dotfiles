import { expect, test } from "bun:test";

const hook = new URL(
  "./executable_require-claude-envchain.ts",
  import.meta.url,
).pathname;

const cases: Array<[string, number]> = [
  ["claude -p x", 2],
  ['"claude" -p x', 2],
  ["/path/to/claude -p x", 2],
  ['envchain wrong "/path with space/claude" -p x', 2],
  ["envchain 'claude-gateway' claude -p x", 0],
  ['envchain context7,"claude-gateway" claude -p x', 0],
  ["envchain claude-gateway2 claude -p x", 2],
  ["/path/to/envchain wrong /path/to/claude -p x", 2],
  ["envchain", 0],
  ["echo claude", 0],
];

for (const [command, exitCode] of cases) {
  test(command, () => {
    const result = Bun.spawnSync([process.execPath, hook], {
      stdin: new Blob([JSON.stringify({ tool_input: { command } })]),
      stdout: "pipe",
      stderr: "pipe",
    });

    expect(result.exitCode).toBe(exitCode);
    expect(result.stdout.toString()).toBe("");
    expect(result.stderr.toString()).toBe(
      exitCode === 2
        ? "Run Claude as `envchain claude-gateway claude ...`.\n"
        : "",
    );
  });
}

test("managed requirements register the hook", async () => {
  const requirements = await Bun.file(
    new URL("../../.chezmoitemplates/codex-requirements.toml", import.meta.url),
  ).text();

  expect(requirements).toContain(
    'command = "{{ .chezmoi.homeDir }}/.codex/managed-hooks/require-claude-envchain.ts"',
  );
});

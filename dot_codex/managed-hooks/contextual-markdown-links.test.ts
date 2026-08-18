import { expect, test } from "bun:test";

const hook = new URL(
  "./executable_contextual-markdown-links",
  import.meta.url,
).pathname;
const hookInput = {
  cwd: "/synthetic/workspace",
  hook_event_name: "UserPromptSubmit",
  model: "synthetic-model",
  permission_mode: "default",
  session_id: "synthetic-session",
  transcript_path: "/synthetic/transcript.jsonl",
  turn_id: "synthetic-turn",
};
const additionalContext =
  "When producing Markdown, do not preserve or create a links block. Every link-bearing sentence must state requested substantive content beyond the link relationship. Put each useful URL on descriptive link text in the existing sentence about the fact or action it supports; never add a separate see, tracking, related, or reference sentence, paragraph, list, or section merely to retain it. Preserve literal or separate URLs only when the requested format or artifact purpose requires them.";

function runHook(prompt: string) {
  return Bun.spawnSync(["/bin/zsh", "-f", hook], {
    stdin: new Blob([JSON.stringify({ ...hookInput, prompt })]),
    stdout: "pipe",
    stderr: "pipe",
  });
}

for (const [name, prompt] of [
  ["no URLs", "Draft a concise note."],
  ["one URL", "Summarize https://example.test/one."],
  ["grouped URLs", "Use https://example.test/one and https://example.test/two."],
]) {
  test(`injects link-placement context for ${name}`, () => {
    const result = runHook(prompt);

    expect(result.exitCode).toBe(0);
    expect(result.stderr.toString()).toBe("");
    expect(JSON.parse(result.stdout.toString())).toEqual({
      hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext,
      },
    });
  });
}

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

  expect(requirements.hooks.UserPromptSubmit).toEqual([
    {
      hooks: [
        {
          type: "command",
          command:
            "{{ .chezmoi.homeDir }}/.codex/managed-hooks/contextual-markdown-links",
          timeout: 5,
        },
      ],
    },
  ]);
});

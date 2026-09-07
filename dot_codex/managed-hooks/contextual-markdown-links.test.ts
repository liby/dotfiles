import { expect, test } from "bun:test";

const hook = new URL(
  "./executable_contextual-markdown-links",
  import.meta.url,
).pathname;
const additionalContext =
  "When producing Markdown, do not preserve or create a links block. Every link-bearing sentence must state requested substantive content beyond the link relationship. Put each useful URL on descriptive link text in the existing sentence about the fact or action it supports; never add a separate see, tracking, related, or reference sentence, paragraph, list, or section merely to retain it. Preserve literal or separate URLs only when the requested format or artifact purpose requires them.";

test("injects link-placement context even when the prompt has no URLs", () => {
  const result = Bun.spawnSync(["/bin/zsh", "-f", hook], {
    stdin: new Blob([JSON.stringify({ prompt: "Draft a concise note." })]),
    stdout: "pipe",
    stderr: "pipe",
  });

  expect(result.exitCode).toBe(0);
  expect(result.stderr.toString()).toBe("");
  expect(JSON.parse(result.stdout.toString())).toEqual({
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext,
    },
  });
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

import { expect, test } from "bun:test";

const hook = new URL("./executable_guard-bash", import.meta.url).pathname;
const hookInput = {
  cwd: "/synthetic/workspace",
  hook_event_name: "PreToolUse",
  model: "synthetic-model",
  permission_mode: "default",
  session_id: "synthetic-session",
  tool_name: "Bash",
  tool_use_id: "synthetic-tool-use",
  transcript_path: "/synthetic/transcript.jsonl",
  turn_id: "synthetic-turn",
};

const cases: Array<[string, number, string?]> = [
  ["cat .env", 2],
  ["cat .env.local", 2],
  ["cat .env{,.local}", 2],
  ["cat ~/.npmrc", 2],
  ["cat ~/.zprofile", 2],
  ["tail ~/.zsh_history.backup", 2],
  ['jq . "$HOME/.claude/.credentials.json"', 2],
  ['jq . "$HOME/.codex/auth.json"', 2],
  ["head ~/.ssh/id_ed25519", 2],
  ["head ~/.ssh/polylab-deploy", 2],
  ["head ~/.ssh/polylab-host-ed25519", 2],
  ["cat ~/.gnupg/private-keys-v1.d/example.key", 2],
  ["cat ~/.ssh/config", 0],
  ["cat ~/.ssh/id_ed25519.pub", 0],
  ["printenv", 2],
  ["printenv OPENAI_API_KEY", 2],
  ["printenv HOME", 0],
  ["env -u HOME", 2],
  ["env -i -- SYNTHETIC=value", 2],
  ["env FOO=bar printenv HOME", 0],
  ["env -u HOME printenv PATH", 0],
  ["env SYNTHETIC=1 claude -p x", 2, "claude"],
  ["env -C /private/tmp claude -p x", 2, "claude"],
  ["export -p", 2],
  ["export -px", 2],
  ["typeset", 2],
  ["declare -x", 2],
  ["typeset -p OPENAI_API_KEY", 2],
  ["set", 2],
  ["gh auth token", 2],
  ['gh auth status "--show-token"', 2],
  ["gh auth status --show-token=true", 2],
  ["gh auth status -t", 2],
  ["glab auth status --show-token", 2],
  ["security find-generic-password -w -s example", 2],
  ['curl -v -H "authorization: Bearer $API_TOKEN" https://example.test', 2],
  ["curl -sv -usynthetic:credential https://example.test", 2],
  ["curl -v https://example.test", 0],
  ["dotenvx run -f .env -- bun test", 0],
  ["node --env-file=.env.local app.js", 0],
  ["npm --userconfig ~/.npmrc install", 0],
  ["ssh -i ~/.ssh/id_ed25519 example.test", 0],
  ["cat .env.example", 0],
  ["rg .env README.md", 0],
  ["FOO=1 cat .env", 2],
  ["claude -p x", 2, "claude"],
  ['"claude" -p x', 2, "claude"],
  ["/path/to/claude -p x", 2, "claude"],
  ["envchain wrong claude -p x", 2, "claude"],
  ['envchain wrong "/path with space/claude" -p x', 2, "claude"],
  ["envchain claude-gateway2 claude -p x", 2, "claude"],
  ["envchain example printenv", 2],
  ["envchain claude-gateway claude -p x", 0],
  ['envchain context7,"claude-gateway" claude -p x', 0],
];

for (const [command, exitCode, policy = "client"] of cases) {
  test(command, () => {
    const result = Bun.spawnSync(["/bin/zsh", "-f", hook], {
      stdin: new Blob([
        JSON.stringify({
          ...hookInput,
          tool_input: { command },
        }),
      ]),
      stdout: "pipe",
      stderr: "pipe",
    });

    expect(result.exitCode).toBe(exitCode);
    expect(result.stdout.toString()).toBe("");
    if (exitCode === 0) {
      expect(result.stderr.toString()).toBe("");
    } else if (policy === "claude") {
      expect(result.stderr.toString()).toBe(
        "Run Claude as `envchain claude-gateway claude ...`.\n",
      );
    } else {
      expect(result.stderr.toString()).not.toBe("");
    }
  });
}

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
    hooks: { PreToolUse: Array<{ matcher: string; hooks: unknown[] }> };
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

  expect(requirements.hooks.PreToolUse).toEqual([
    {
      matcher: "^Bash$",
      hooks: [
        {
          type: "command",
          command: "{{ .chezmoi.homeDir }}/.codex/managed-hooks/guard-bash",
          timeout: 5,
        },
      ],
    },
  ]);
});

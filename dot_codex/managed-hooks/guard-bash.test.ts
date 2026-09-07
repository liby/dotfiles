import { expect, test } from "bun:test";

const hook = new URL("./executable_guard-bash", import.meta.url).pathname;
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
  ["head ~/.ssh/deploy-key", 2],
  ["cat ~/.gnupg/private-keys-v1.d/example.key", 2],
  ["cat ~/.ssh/config", 0],
  ["cat ~/.ssh/config.work", 0],
  ["cat ~/.ssh/id_ed25519.pub", 0],
  ["cat ~/.ssh/allowed_signers", 0],
  ["grep github ~/.ssh/known_hosts", 0],
  ["printenv", 2],
  ["printenv > synthetic-output", 2],
  ["printenv OPENAI_API_KEY", 2],
  ["printenv HOME", 0],
  ["env -u HOME", 2],
  ["env -0", 2],
  ["env -i 2>/dev/null", 2],
  ["env 2>/dev/null printf synthetic", 0],
  ["env 2>/dev/null cat < .env", 2],
  ["env -i -- SYNTHETIC=value", 2],
  ["env FOO=bar printenv HOME", 0],
  ["env -u HOME printenv PATH", 0],
  ["env SYNTHETIC=1 claude -p x", 2, "claude"],
  ["env -C /private/tmp claude -p x", 2, "claude"],
  ["./scripts/export", 0],
  ["env ./scripts/set", 0],
  ["export -p", 2],
  ["export -px", 2],
  ["typeset", 2],
  ["declare -x", 2],
  ["declare -p 2>/dev/null", 2],
  ["typeset -p HOME 2>/dev/null", 0],
  ["typeset -p OPENAI_API_KEY", 2],
  ["set", 2],
  ["set 2>/dev/null", 2],
  ["set '2>' /dev/null", 0],
  ["builtin set", 2],
  ["builtin - export", 2],
  ["'noglob' printenv", 2],
  ["nocorrect FOO=1 set", 2],
  ["'nocorrect' set", 0],
  ["noglob nocorrect set", 0],
  ["builtin noglob printenv", 2],
  ["builtin noglob builtin printenv", 0],
  ["env builtin set", 0],
  ["builtin command claude --version", 2, "claude"],
  ["builtin printf '%s\\n' \"$API_KEY\"", 2],
  ["gh auth token", 2],
  ['gh auth status "--show-token"', 2],
  ["gh auth status -t", 2],
  ["gh 2>/dev/null auth status -t", 2],
  ["gh auth status -at", 2],
  ["gh auth status -th example.test", 2],
  ["gh auth status --show-token=false", 2],
  ["gh auth status -t --show-token=false", 2],
  ["gh auth status -t --help", 2],
  ["gh auth status -hgithub.test", 0],
  ["gh auth status --hostname -t", 0],
  ["gh auth status --template '-t' --json hosts", 0],
  ["gh auth status -- -t", 0],
  ["printf '%s' '|' gh auth status -t", 0],
  ["gh auth status -t > --show-token=false", 2],
  ["gh auth status > -t", 0],
  ["glab auth status --show-token", 2],
  ["security find-generic-password -w -s example", 2],
  ['curl -v -H "authorization: Bearer $API_TOKEN" https://example.test', 2],
  ["curl -sv -usynthetic:credential https://example.test", 2],
  ['curl --trace=- -H "Authorization: synthetic" https://example.test', 2],
  ["curl -v -n https://example.test", 2],
  ["curl -vn https://example.test", 2],
  ["curl -v --oauth2-bearer SYNTHETIC https://example.test", 2],
  ["curl --trace - --oauth2-bearer=SYNTHETIC https://example.test", 2],
  ["curl -v -o/tmp/name https://example.test", 0],
  ["curl --trace=- https://example.test", 0],
  ["curl -v https://example.test", 0],
  ["dotenvx run -f .env -- bun test", 0],
  ["node --env-file=.env.local app.js", 0],
  ["npm --userconfig ~/.npmrc install", 0],
  ["ssh -i ~/.ssh/id_ed25519 example.test", 0],
  ["cat .env.example", 0],
  ["cat < .env", 2],
  ["rg .env README.md", 0],
  ["rg TOKEN .env", 2],
  ["grep TOKEN .env", 2],
  ["rg -nFi --hidden TOKEN .env", 2],
  ["rg -g .env TOKEN README.md", 0],
  ["rg -e .env README.md", 0],
  ["rg -e TOKEN .env", 2],
  ["rg -e TOKEN < .env", 2],
  ["rg --no-messages TOKEN < .env", 2],
  ["rg --trim TOKEN .env", 2],
  ["rg .env -e TOKEN", 2],
  ["grep -f .env README.md", 2],
  ["rg --regexp=TOKEN -- .env", 2],
  ["rg --help .env", 0],
  ["rg --files .env", 0],
  ["rg --encoding utf-8 .env README.md", 0],
  ["grep -E TOKEN .env", 2],
  ["grep -E .env README.md", 0],
  ["grep --color TOKEN .env", 2],
  ["rg -E utf-8 .env README.md", 0],
  ["rg -E utf-8 TOKEN .env", 2],
  ["rg -o 'TOKEN=.*' .env", 2],
  ["rg --json .env README.md", 0],
  ["printf '%s\\n' \"$API_KEY\"", 2],
  ["printf '%s\\n' \"${API_KEY}\"", 2],
  ["echo $API_KEY", 2],
  ["printf '%s\\n' '$API_KEY'", 0],
  ["printf '%s\\n' \"\\$API_KEY\"", 0],
  ["printf '%s\\n' \"$HOME\"", 0],
  ["printf -v copy '%s' \"$API_KEY\"", 0],
  ["printf '%s\\n' \"$(printf '%s' '$API_KEY')\"", 0],
  ["cd project && cat .env", 2],
  ["printf synthetic | cat .env", 2],
  ["cat README.md; printf '%s\\n' .env", 0],
  ["printf fixture > .env; rg pattern README.md", 0],
  ["printf '%s\\n' ';' ; cat .env", 2],
  ["printf '%s\\n' \\; cat .env", 0],
  ["printf '%s\\n' 'cat .env'", 0],
  ["cat README.md # cat .env", 0],
  ["cat README.md # comment\ncat .env", 2],
  ["cat \\\n  .env", 2],
  ["tee README.md <<'EOF'\ncat .env\nEOF", 0],
  ["tee README.md 0<<'EOF'\ncat .env\nEOF", 0],
  ["tee README.md 0<<-'EOF'\n\tcat .env\nEOF", 0],
  ["cat <<'EOF' \\\n.env\nx\nEOF", 2],
  ["cat 0<<'EOF' ';' .env\nx\nEOF", 2],
  ["cat <<'EOF' <<'NEXT' .env\nx\nEOF\ny\nNEXT", 2],
  ["cat <<'EOF' README.md; cat .env\nx\nEOF", 0],
  ["cat <<'EOF' | cat .env\npublic\nEOF", 2],
  ["cat <<'EOF' && cat .env\npublic\nEOF", 2],
  ["sample() {\ncat .env\n}\nprintf okay", 0],
  ["if false; then\ncat .env\nfi", 0],
  ["cat .env; tee README.md <<'EOF'\npublic text\nEOF", 2],
  ["cat .env <<'EOF'\npublic text\nEOF", 2],
  ["cat .env; sample() { printf okay; }", 2],
  ["tee README.md <<'EOF'\npublic text\nEOF\ncat .env", 0],
  ["printf '%s' '<<'; cat .env", 2],
  ["printf '%s' '('; cat .env", 2],
  ["printf '%s' {; cat .env", 2],
  ["printf '%s' if; cat .env", 2],
  ["echo synthetic; FOO=1 cat .env", 2],
  ["claude -p synthetic; cat .env", 2],
  ["envchain example client; cat .env", 2],
  ["env -S 'client arguments'; cat .env", 2],
  ["FOO=1 cat .env", 2],
  ["claude -p x", 0],
  ["FOO=1 claude --version", 0],
  ["/path/to/claude -p x", 2, "claude"],
  ["command claude --version", 2, "claude"],
  ["command -- claude --version", 2, "claude"],
  ["command -v claude", 0],
  ["envchain example printenv", 2],
  ["envchain claude-gateway claude -p x", 2, "claude"],
];

for (const [command, exitCode, policy = "client"] of cases) {
  test(command, () => {
    const result = Bun.spawnSync(["/bin/zsh", "-f", hook], {
      stdin: new Blob([
        JSON.stringify({
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
        "Run Claude as `claude ...`; the provider-aware launcher selects the persisted mode.\n",
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

import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

const ROOT = resolve(import.meta.dir, "../..");
const read = (path: string) => readFileSync(join(ROOT, path), "utf8");
const AGENTS = "AGENTS.md";
const CONCEPTS = ".github/CONCEPTS.md";
const SETTINGS_RULE = ".claude/rules/claude-code-settings.md";
const CLAUDE_SETTINGS = ".chezmoitemplates/claude/settings.json";
const FRAGMENTS = ".chezmoitemplates/agents";

const EXPECTED_FRAGMENTS = [
  "authority.md",
  "protected-inputs.md",
  "evidence.md",
  "tools.md",
  "coding-principles.md",
  "execution-host.md",
  "completion.md",
  "deliverables.md",
];
const CODEX_ROOT = "dot_codex/AGENTS.md.tmpl";
const PI_ROOT = "private_dot_pi/private_agent/private_AGENTS.md.tmpl";
const AGENT_ROOTS = ["dot_claude/CLAUDE.md.tmpl", CODEX_ROOT, PI_ROOT];
const SHARED_ONLY_ROOTS = [CODEX_ROOT, PI_ROOT];

const ROUTE_EXPECTATIONS: Record<string, string[]> = {
  "Repository validation": ["`.github/workflows/**`", "`.github/tests/**`", "(.github/CONCEPTS.md#repository-validation)"],
  "Bootstrap and packages": [
    "`Brewfile`",
    "`.chezmoiexternal.toml`",
    "`.chezmoiscripts/**`",
    "`.chezmoitemplates/input-source-pro/**`",
    "(.github/CONCEPTS.md#bootstrap)",
    "(.github/CONCEPTS.md#package-and-tool-ownership)",
  ],
  "Git signing": [
    "`dot_config/git/config`",
    "`dot_config/git/executable_git-ssh-gpg-agent`",
    "`.chezmoitemplates/git/**`",
    "`private_dot_ssh/private_config`",
    "(.github/CONCEPTS.md#git-identity-and-signing)",
  ],
  "GitLab CLI": [
    "`.chezmoiscripts/run_onchange_after_setup-glab.sh.tmpl`",
    "`dot_config/private_glab-cli/**`",
    "glab's live configuration",
    "(.github/CONCEPTS.md#gitlab-cli-configuration)",
  ],
  Codex: [
    "`.chezmoitemplates/codex/**`",
    "`dot_codex/**`",
    "`~/.codex/config.toml`",
    "bundled Browser cache",
    "(.github/CONCEPTS.md#codex-configuration)",
  ],
  "Claude Code": ["`.chezmoitemplates/claude/**`", "`dot_claude/**`", "`~/.claude/settings.json`", "(.claude/rules/claude-code-settings.md)"],
  "Shared agent instructions": [
    "`.chezmoitemplates/agents/**`",
    "`dot_claude/CLAUDE.md.tmpl`",
    "`dot_codex/AGENTS.md.tmpl`",
    "`private_dot_pi/private_agent/private_AGENTS.md.tmpl`",
    "(.github/CONCEPTS.md#shared-agent-instructions)",
  ],
  Pi: ["`.chezmoitemplates/pi/**`", "`private_dot_pi/**`", "`~/.pi/agent/**`", "(.github/CONCEPTS.md#pi-configuration)"],
  Oracle: ["`private_dot_oracle/**`", "`~/.oracle/config.json`", "(.github/CONCEPTS.md#oracle-configuration)"],
  "Herdr integrations": [
    "`.chezmoiscripts/run_onchange_after_install-herdr-integrations.sh.tmpl`",
    "(.github/CONCEPTS.md#herdr-integrations)",
  ],
  "Agent guard": [
    "`dot_codex/managed-hooks/executable_guard-bash`",
    "`private_dot_pi/private_agent/extensions/agent-guard.ts`",
    "`dot_ignore`",
    "`Brewfile`",
    "`.chezmoitemplates/claude/settings.json`",
    "`.chezmoitemplates/codex/requirements.toml`",
    "(.github/CONCEPTS.md#agent-guard)",
  ],
  "Managed skills": ["`dot_agents/skills/**`", "`~/.agents/skills/**`", "`write-skill`", "(.github/CONCEPTS.md#managed-skill-registry)"],
  "Snowflake CLI": ["`dot_local/bin/executable_snow`", "`dot_agents/skills/snow/**`", "(.github/CONCEPTS.md#shared-agent-execution)"],
  Credentials: [
    "`.secrets/**`",
    "any source that invokes `envchain`",
    "(.github/CONCEPTS.md#identity-and-encrypted-data)",
    "(.github/CONCEPTS.md#credential-backed-features)",
    "(#encrypted-files)",
  ],
};

const CREDENTIAL_KEYS: Record<string, string[]> = {
  "claude-gateway": [
    "ANTHROPIC_AUTH_TOKEN",
    "ANTHROPIC_VERTEX_BASE_URL",
    "ANTHROPIC_VERTEX_PROJECT_ID",
    "CLAUDE_CODE_SKIP_VERTEX_AUTH",
    "CLAUDE_CODE_USE_VERTEX",
  ],
  context7: ["CONTEXT7_API_KEY"],
  glab: ["GITLAB_CLIENT_ID"],
  pi: ["ANTHROPIC_API_KEY", "RC_GATEWAY_API_KEY"],
  typesafe: ["TYPESAFE_API_KEY"],
};

// Each consumer file and the tokens that wire it to its namespace.
const CREDENTIAL_CONSUMERS: Record<string, Record<string, string[]>> = {
  "claude-gateway": {
    // Subscription mode unsets every contract key by name.
    "dot_local/share/claude-launcher/bin/executable_claude": [
      "gateway_namespace=claude-gateway",
      'envchain "$gateway_namespace" "$native" "$@"',
      ...CREDENTIAL_KEYS["claude-gateway"],
    ],
  },
  context7: {
    "dot_agents/skills/context7/SKILL.md": ["envchain context7 sh -c 'CTX7_TELEMETRY_DISABLED=1 exec ctx7 --base-url", "CONTEXT7_API_KEY"],
  },
  glab: { ".chezmoiscripts/run_onchange_after_setup-glab.sh.tmpl": ["envchain glab /bin/sh -c", "GITLAB_CLIENT_ID"] },
  pi: { "private_dot_pi/private_agent/private_models.json.tmpl": ["!envchain pi printenv", "ANTHROPIC_API_KEY", "RC_GATEWAY_API_KEY"] },
  typesafe: {
    "private_dot_pi/private_agent/private_models.json.tmpl": ["!envchain typesafe printenv", "TYPESAFE_API_KEY"],
  },
};

// GitHub's heading anchors: lowercase, drop punctuation, spaces to hyphens,
// and a numeric suffix for repeats.
function headingAnchors(markdown: string): Set<string> {
  const anchors = new Set<string>();
  const counts = new Map<string, number>();
  let inFence = false;
  for (const line of markdown.split("\n")) {
    if (line.startsWith("```")) inFence = !inFence;
    const match = !inFence && line.match(/^#{1,6}\s+(.+?)\s*#*$/);
    if (!match) continue;
    const text = match[1].replace(/<[^>]+>/g, "").toLowerCase().replace(/[^\p{L}\p{N}_\- ]/gu, "");
    const base = text.trim().replace(/\s+/g, "-");
    const count = counts.get(base) ?? 0;
    counts.set(base, count + 1);
    anchors.add(count ? `${base}-${count}` : base);
  }
  return anchors;
}

// Rejects a relative link or anchor in the instruction files that no longer
// resolves, which would route an agent to a missing owner.
test("local links and anchors resolve", () => {
  let checked = 0;
  const skillSources = ["*/SKILL.md", "*/references/**/*.md"].flatMap((pattern) =>
    [...new Bun.Glob(pattern).scanSync(join(ROOT, "dot_agents/skills"))].map((name) => `dot_agents/skills/${name}`),
  );
  for (const source of [AGENTS, CONCEPTS, SETTINGS_RULE, ...skillSources]) {
    const targets: string[] = [];
    Bun.markdown.render(read(source), {
      link: (children, { href }) => {
        targets.push(href);
        return children;
      },
    });
    for (const target of targets) {
      if (/^[a-z][a-z0-9+.-]*:/.test(target)) continue;
      const [pathText, fragment] = target.split("#", 2);
      const path = pathText ? resolve(dirname(join(ROOT, source)), decodeURIComponent(pathText)) : join(ROOT, source);
      expect({ source, target, exists: existsSync(path) }).toEqual({ source, target, exists: true });
      if (fragment) {
        expect(statSync(path).isFile()).toBe(true);
        expect({ source, target, anchor: headingAnchors(readFileSync(path, "utf8")).has(fragment) }).toEqual({ source, target, anchor: true });
      }
      checked++;
    }
  }
  expect(checked).toBeGreaterThan(0);
});

describe("maintenance routes", () => {
  // Rejects a Claude config template the settings rule's paths frontmatter
  // does not load for.
  test("Claude config templates load the settings rule", () => {
    const frontmatter = read(SETTINGS_RULE).split("---", 3)[1];
    const patterns = [...frontmatter.matchAll(/^ {2}- "(.+)"$/gm)].map((m) => new Bun.Glob(m[1]));
    for (const name of new Bun.Glob("*.json").scanSync(join(ROOT, ".chezmoitemplates/claude"))) {
      const template = `.chezmoitemplates/claude/${name}`;
      expect({ template, loaded: patterns.some((p) => p.match(template)) }).toEqual({ template, loaded: true });
    }
  });

  // Rejects a missing, duplicated, or rerouted row in AGENTS.md's pre-action
  // table.
  test("safety owners have pre-action routes", () => {
    const markdown = read(AGENTS);
    expect(markdown).toContain("Before inspecting, changing, or running a matching surface");
    const rows = [...markdown.matchAll(/^\| ([^|]+?) \| ([^|]+?) \| ([^|]+?) \|$/gm)]
      .map((m) => m.slice(1, 4).map((cell) => cell.trim()))
      .filter(([area]) => !area.startsWith("---") && area !== "Area");
    for (const [label, snippets] of Object.entries(ROUTE_EXPECTATIONS)) {
      const matching = rows.filter(([area]) => area === label);
      expect({ label, rows: matching.length }).toEqual({ label, rows: 1 });
      const route = `${matching[0][1]} ${matching[0][2]}`;
      for (const snippet of snippets) expect({ label, snippet, routed: route.includes(snippet) }).toEqual({ label, snippet, routed: true });
    }
  });
});

// Rejects drift between the documented seed contract, its key list, and the
// files that consume each namespace, without reading the encrypted seed.
test("documented credential contract matches consumers", () => {
  const markdown = read(CONCEPTS);
  const match = markdown.match(/### Credential-backed features\n[\s\S]*?```toml\n([\s\S]*?)\n```/);
  expect(match).not.toBeNull();
  const contract = Bun.TOML.parse(match![1]) as Record<string, Record<string, string>>;
  expect(Object.fromEntries(Object.entries(contract).map(([ns, values]) => [ns, Object.keys(values).sort()]))).toEqual(CREDENTIAL_KEYS);
  const section = markdown.slice(match!.index);
  for (const [namespace, consumers] of Object.entries(CREDENTIAL_CONSUMERS)) {
    for (const [path, tokens] of Object.entries(consumers)) {
      expect({ namespace, path, file: existsSync(join(ROOT, path)), linked: section.includes(`(../${path})`) })
        .toEqual({ namespace, path, file: true, linked: true });
      const content = read(path);
      for (const token of tokens) expect({ path, token, present: content.includes(token) }).toEqual({ path, token, present: true });
    }
  }
});

describe("shared agent instructions", () => {
  const INCLUDE = /\{\{ includeTemplate "agents\/([^"]+)" \. (-?)\}\}(\n?)/g;
  const fragment = (name: string) => read(`${FRAGMENTS}/${name}`);
  const render = (root: string) => read(root).replace(INCLUDE, (_, name: string, trim: string, newline: string) => fragment(name) + (trim ? "" : newline));
  const headings = (text: string) => [...text.matchAll(/^## (.+)$/gm)].map((m) => m[1]);
  const localLines = (root: string) => read(root).replace(INCLUDE, "").split("\n").filter((line) => line.trim());

  // Rejects a fragment added, removed, or holding other than one section, and
  // a second Coding Principles section.
  test("fragments define the shared sections", () => {
    expect([...new Bun.Glob("*.md").scanSync(join(ROOT, FRAGMENTS))].sort()).toEqual([...EXPECTED_FRAGMENTS].sort());
    const perFragment = EXPECTED_FRAGMENTS.map((name) => headings(fragment(name)));
    expect(perFragment.every((h) => h.length === 1)).toBe(true);
    expect(perFragment.flat().filter((h) => h === "Coding Principles").length).toBe(1);
  });

  // Rejects a scope-predicate phrase changed in the policy but not in the
  // auto-mode classifier text, or the reverse.
  test("scope predicate matches between policy and classifier", () => {
    const policy = fragment("authority.md");
    const classifier = read(CLAUDE_SETTINGS);
    for (const phrase of ["the user's own tools", "for the task or as a standing choice", "without the user choosing it is an outside reader"]) {
      expect({ phrase, policy: policy.includes(phrase), classifier: classifier.includes(phrase) }).toEqual({ phrase, policy: true, classifier: true });
    }
  });

  // Rejects a root that skips, repeats, or reorders a fragment, or adds a
  // section of its own.
  test("roots assemble each fragment once in order", () => {
    const expected = EXPECTED_FRAGMENTS.flatMap((name) => headings(fragment(name)));
    for (const root of AGENT_ROOTS) {
      const source = read(root);
      expect({ root, includes: [...source.matchAll(INCLUDE)].map((m) => m[1]) }).toEqual({ root, includes: EXPECTED_FRAGMENTS });
      expect(source).not.toMatch(/^## /m);
      const rendered = render(root);
      expect(rendered).not.toMatch(INCLUDE);
      expect({ root, headings: headings(rendered) }).toEqual({ root, headings: expected });
      const [section = "", ...more] = rendered.match(/^## Coding Principles\n[\s\S]*?(?=^## )/gm) ?? [];
      expect({ root, section: section !== "", more: more.length }).toEqual({ root, section: true, more: 0 });
      expect(rendered.replace(section, "")).not.toContain("## Coding Principles");
    }
  });

  // Rejects a root-local line that duplicates shared text or appears in more
  // than one rendered root, and any local line in the shared-only roots.
  test("root-local lines stay local", () => {
    const shared = EXPECTED_FRAGMENTS.map(fragment).join("\n");
    const rendered = AGENT_ROOTS.map(render);
    for (const root of SHARED_ONLY_ROOTS) expect({ root, local: localLines(root) }).toEqual({ root, local: [] });
    for (const root of AGENT_ROOTS) {
      for (const line of localLines(root)) {
        const occurrences = rendered.reduce((sum, doc) => sum + doc.split(line).length - 1, 0);
        expect({ root, line, shared: shared.includes(line), occurrences }).toEqual({
          root,
          line,
          shared: false,
          occurrences: 1,
        });
      }
    }
  });
});

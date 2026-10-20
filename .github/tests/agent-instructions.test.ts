import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const ROOT = resolve(import.meta.dir, "../..");
const read = (path: string) => readFileSync(join(ROOT, path), "utf8");
const AGENTS = "AGENTS.md";
const CONCEPTS = ".github/CONCEPTS.md";
const FRAGMENTS = ".chezmoitemplates/agents";

const CODEX_ROOT = "dot_codex/AGENTS.md.tmpl";
const PI_ROOT = "private_dot_pi/private_agent/private_AGENTS.md.tmpl";
const AGENT_ROOTS = ["dot_claude/CLAUDE.md.tmpl", CODEX_ROOT, PI_ROOT];
const SHARED_ONLY_ROOTS = [CODEX_ROOT, PI_ROOT];
const WORKFLOWS = ".github/workflows";

const exists = (path: string) =>
  path.includes("*")
    ? new Bun.Glob(path).scanSync({ cwd: ROOT, dot: true }).next().done === false
    : existsSync(join(ROOT, path));

// Rejects a pre-action route whose trigger names a repository path that a
// rename or deletion left behind, so edits to the moved file are no longer
// routed to their owner.
test("pre-action route triggers name existing paths", () => {
  const rows = [...read(AGENTS).matchAll(/^\| ([^|]+?) \| ([^|]+?) \| ([^|]+?) \|$/gm)];
  // Only list items that are wholly one code span name a repository path.
  const triggers = rows.flatMap((row) =>
    row[2].split(/,\s*/).flatMap((item) => item.replace(/^and\s+/, "").match(/^`([^`~/][^`]*)`$/)?.[1] ?? []),
  );
  expect(triggers.length).toBeGreaterThan(0);
  for (const trigger of triggers) {
    expect({ trigger, exists: exists(trigger) }).toEqual({ trigger, exists: true });
  }
});

// Rejects a workflow path filter that a rename or deletion left behind, so
// changes to the moved file no longer run the checks that cover it.
test("workflow path filters name existing paths", () => {
  const filters = [...new Bun.Glob("*.yml").scanSync(join(ROOT, WORKFLOWS))].flatMap((file) => {
    const { on } = Bun.YAML.parse(read(`${WORKFLOWS}/${file}`)) as { on: Record<string, { paths?: string[] } | null> };
    return Object.values(on).flatMap((event) => (event?.paths ?? []).map((path) => ({ file, path })));
  });
  expect(filters.length).toBeGreaterThan(0);
  for (const { file, path } of filters) {
    expect({ file, path, exists: exists(path) }).toEqual({ file, path, exists: true });
  }
});

// Rejects a documented seed key that no consumer its entry links names any
// more, such as a gateway variable the Claude launcher does not unset, without
// reading the encrypted seed. A name match is reference integrity: whether the
// consumer reads the key from that namespace is its own behavior test's job.
test("documented credential keys are named by their consumers", () => {
  const markdown = read(CONCEPTS);
  const section = markdown.slice(markdown.indexOf("### Credential-backed features"));
  const contract = Bun.TOML.parse(section.match(/```toml\n([\s\S]*?)\n```/)![1]) as Record<string, Record<string, string>>;
  const entries = [...section.matchAll(/^- (.+?): (.*)$/gm)].map(([, head, body]) => {
    const namespaces = [...head.matchAll(/`([^`]+)`/g)].map((m) => m[1]).filter((name) => name in contract);
    return {
      namespaces,
      keys: namespaces.flatMap((name) => Object.keys(contract[name])),
      consumers: [...body.matchAll(/\]\(\.\.\/([^)#]+)\)/g)].map((m) => read(m[1])),
    };
  });
  expect(entries.flatMap((entry) => entry.namespaces).sort()).toEqual(Object.keys(contract).sort());
  for (const { namespaces, keys, consumers } of entries) {
    // Every key is named by a consumer, and every linked consumer still names one
    // of the entry's keys, so a consumer that lost its local wiring is not hidden by
    // a sibling that names the same key.
    expect({ namespaces, unread: keys.filter((key) => !consumers.some((text) => text.includes(key))) }).toEqual({ namespaces, unread: [] });
    expect({ namespaces, idle: consumers.filter((text) => !keys.some((key) => text.includes(key))).length }).toEqual({ namespaces, idle: 0 });
  }
});

describe("shared agent instructions", () => {
  const INCLUDE = /\{\{ includeTemplate "agents\/([^"]+)" \. (-?)\}\}(\n?)/g;
  const fragment = (name: string) => read(`${FRAGMENTS}/${name}`);
  const includes = (root: string) => [...read(root).matchAll(INCLUDE)].map((m) => m[1]);
  const render = (root: string) => read(root).replace(INCLUDE, (_, name: string, trim: string, newline: string) => fragment(name) + (trim ? "" : newline));
  const headings = (text: string) => [...text.matchAll(/^## (.+)$/gm)].map((m) => m[1]);
  const localLines = (root: string) => read(root).replace(INCLUDE, "").split("\n").filter((line) => line.trim());
  const order = includes(CODEX_ROOT);

  // Rejects a fragment that a root skips, repeats, or reorders, and a root or
  // fragment that adds a second section, so each rendered section stays one
  // removable fragment.
  test("roots assemble every fragment once in the same order", () => {
    expect([...new Bun.Glob("*.md").scanSync(join(ROOT, FRAGMENTS))].sort()).toEqual([...order].sort());
    expect(order.map((name) => ({ name, sections: headings(fragment(name)).length }))).toEqual(order.map((name) => ({ name, sections: 1 })));
    expect(new Set(order.flatMap((name) => headings(fragment(name)))).size).toBe(order.length);
    for (const root of AGENT_ROOTS) {
      expect({ root, includes: includes(root), headings: headings(read(root).replace(INCLUDE, "")) }).toEqual({ root, includes: order, headings: [] });
    }
  });

  // Rejects a root-local line that duplicates shared text or appears in more
  // than one rendered root, and any local line in the shared-only roots.
  test("root-local lines stay local", () => {
    const shared = order.map(fragment).join("\n");
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

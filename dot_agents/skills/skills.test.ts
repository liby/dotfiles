import { expect, test } from "bun:test";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

// Claude Code's documented SKILL.md fields
// (https://code.claude.com/docs/en/skills#frontmatter-reference). It ignores any
// other key without an error, so a misspelled field silently loses its effect.
const FIELDS = new Set([
  "name",
  "description",
  "when_to_use",
  "argument-hint",
  "arguments",
  "disable-model-invocation",
  "user-invocable",
  "allowed-tools",
  "disallowed-tools",
  "model",
  "effort",
  "context",
  "agent",
  "background",
  "hooks",
  "paths",
  "shell",
  "metadata",
  "license",
  "compatibility",
]);

const skills = readdirSync(import.meta.dir, { withFileTypes: true }).filter((entry) => entry.isDirectory()).map((entry) => entry.name);

// Rejects a skill that a runtime drops or cripples: unparseable frontmatter
// loads in Claude Code with no description to route on, Codex rejects a missing
// description, and a description over 1,024 characters makes Pi warn and Codex
// truncate the boundary sentences at its end.
test.each(skills)("%s frontmatter meets the runtimes' load rules", (dir) => {
  const block = readFileSync(join(import.meta.dir, dir, "SKILL.md"), "utf8").match(/^---\n([\s\S]*?)\n---\n/)?.[1];
  expect(block).toBeString();
  const frontmatter = Bun.YAML.parse(block!) as Record<string, unknown>;
  const description = typeof frontmatter.description === "string" ? frontmatter.description.trim() : "";
  expect({ name: frontmatter.name, described: description.length > 0, unknown: Object.keys(frontmatter).filter((key) => !FIELDS.has(key)) })
    .toEqual({ name: dir, described: true, unknown: [] });
  expect(description.length).toBeLessThanOrEqual(1024);
});

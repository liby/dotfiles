#!/usr/bin/env bun

import { basename } from "node:path";

const input = (await Bun.stdin.json()) as {
  tool_input: { command: string };
};
const [executable = "", namespace = "", child = ""] = (
  input.tool_input.command.match(/(?:[^\s'"]+|'[^']*'|"[^"]*")+/g) ?? []
).map((word) => word.replace(/'([^']*)'|"([^"]*)"/g, "$1$2"));
const program = basename(executable);

if (
  program === "claude" ||
  (program === "envchain" &&
    !namespace.split(",").includes("claude-gateway") &&
    basename(child) === "claude")
) {
  console.error("Run Claude as `envchain claude-gateway claude ...`.");
  process.exit(2);
}

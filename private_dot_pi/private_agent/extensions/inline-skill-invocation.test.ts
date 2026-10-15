import { describe, expect, mock, test } from "bun:test";

mock.module("@earendil-works/pi-coding-agent", () => ({ CustomEditor: class {} }));
const { default: inlineSkillInvocation } = await import("./inline-skill-invocation");

type InputHandler = (event: { text: string; source: string }, ctx: { mode: string }) => unknown;
const handlers = new Map<string, InputHandler>();
inlineSkillInvocation({
  on: (event: string, handler: InputHandler) => handlers.set(event, handler),
  getCommands: () => ["commit", "review"].map((name) => ({ name: `skill:${name}`, source: "skill" })),
} as Parameters<typeof inlineSkillInvocation>[0]);
const input = handlers.get("input")!;

describe("inline skill invocation", () => {
  test.each([
    ["different fence character", "```", "~~~", "```"],
    ["shorter fence", "````", "```", "````"],
    ["fence with trailing text", "```", "```text", "```"],
  ])("keeps code literal after a %s", (_name, open, interior, close) => {
    const text = `Explain:\n${open}\n${interior}\nPlease /commit later\n${close}\nThen /review the patch`;
    expect(input({ text, source: "interactive" }, { mode: "tui" })).toEqual({ action: "transform", text: `/skill:review ${text}` });
  });

  test.each([
    ["```", "```"],
    ["~~~", "~~~"],
    ["```", "````"],
  ])("resumes invocation after %s closed by %s", (open, close) => {
    const text = `Explain:\n${open}\nPlease /commit later\n${close}\nThen /review the patch`;
    expect(input({ text, source: "interactive" }, { mode: "tui" })).toEqual({ action: "transform", text: `/skill:review ${text}` });
  });

  test("leaves an unclosed code fence literal", () => {
    expect(input({ text: "Explain:\n```sh\nPlease /commit later", source: "interactive" }, { mode: "tui" })).toEqual({ action: "continue" });
  });

  test("preserves CRLF prompts", () => {
    const text = "Explain:\r\n```sh\r\nPlease /commit later\r\n```\r\nThen /review the patch";
    expect(input({ text, source: "interactive" }, { mode: "tui" })).toEqual({ action: "transform", text: `/skill:review ${text}` });
  });

  test("keeps the first skill mention outside code", () => {
    const text = "Please /commit then /review the patch";
    expect(input({ text, source: "interactive" }, { mode: "tui" })).toEqual({ action: "transform", text: `/skill:commit ${text}` });
  });
});

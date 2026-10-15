import { describe, expect, test } from "bun:test";
import inlineSkillInvocation from "./inline-skill-invocation";

type Handler = (event: any, ctx: any) => any;
const handlers = new Map<string, Handler>();
inlineSkillInvocation({
  on: (event: string, handler: Handler) => handlers.set(event, handler),
  getCommands: () =>
    ["commit", "deslop", "herdr", "review"].map((name) => ({ name: `skill:${name}`, source: "skill", sourceInfo: { path: `/skills/${name}/SKILL.md` } })),
} as any);

let editorText = "";
let expandedText = "";
let editorFactory: any;
let provider: any;
const piSuggestions = { prefix: "pi", items: [] };
handlers.get("session_start")!({}, {
  mode: "tui",
  ui: {
    getEditorComponent: () => () => ({
      getText: () => editorText,
      getExpandedText: () => expandedText,
      getLines: () => [editorText],
      getCursor: () => ({ line: 0, col: 0 }),
      tryTriggerAutocomplete() {},
      render: () => [editorText],
      handleInput() {},
    }),
    setEditorComponent: (factory: any) => (editorFactory = factory),
    addAutocompleteProvider: (wrap: any) => (provider = wrap({ getSuggestions: async () => piSuggestions, applyCompletion: () => undefined })),
  },
});
const editor = editorFactory({}, { selectList: { selectedText: (text: string) => `<${text}>` } }, {});

function submit(text: string) {
  return handlers.get("input")!({ text, source: "interactive" }, { mode: "tui" });
}

describe("inline skill invocation", () => {
  test("expands the first mention natively", () => {
    const text = "改完，/deslop 跑一下，没问题就 /commit";
    expect(submit(text)).toEqual({ action: "transform", text: `/skill:deslop ${text}` });
  });

  test("expands a mention at the start of the message", () => {
    const text = "/herdr 驱动 codex review";
    expect(submit(text)).toEqual({ action: "transform", text: `/skill:herdr ${text}` });
  });

  test("leaves a leading Pi command in place", () => {
    expect(submit("/skill:review the patch, then /commit")).toEqual({ action: "continue" });
  });

  test.each([
    ["inline code inside a list", "Quote:\n- `没问题就 /commit`"],
    ["a fenced block inside a list", "Explain:\n- log:\n\n  ```text\n  GET /commit 200\n  ```"],
  ])("keeps a mention in %s literal", (_name, text) => {
    expect(submit(text)).toEqual({ action: "continue" });
  });

  test("ignores a slash right after inline markup, as the editor does", () => {
    expect(submit("**注意**/commit 然后 /review")).toEqual({ action: "transform", text: "/skill:review **注意**/commit 然后 /review" });
  });

  test("skips a mention hidden in a collapsed paste", () => {
    const text = "Log: GET /commit 200\nThen /review it";
    editorText = "Log: [paste #1 +12 lines]\nThen /review it";
    expandedText = text;
    editor.handleInput("\r");
    expect(submit(text)).toEqual({ action: "transform", text: `/skill:review ${text}` });
  });

  test("ignores an editor submit that produced another message", () => {
    editorText = expandedText = "/model";
    editor.handleInput("\r");
    expect(submit("then /commit")).toEqual({ action: "transform", text: "/skill:commit then /commit" });
  });

  test("names the other mentions beside each request message", () => {
    const invoked = '<skill name="deslop" location="/skills/deslop/SKILL.md">\n# Deslop\n\nRun /review first.\n</skill>\n\n改完 /deslop，然后 /commit';
    const messages = [
      { role: "user", content: [{ type: "text", text: invoked }] },
      { role: "assistant", content: [{ type: "text", text: "Use /review next." }] },
      { role: "user", content: [{ type: "text", text: "see /herdr" }] },
    ];
    expect(handlers.get("context")!({ type: "context", messages }, {})).toBeUndefined();
    const hintedPaths = messages.map(({ content }) => content.slice(1).flatMap(({ text }) => text.match(/\/skills\/\S+\.md/g)));
    expect(hintedPaths).toEqual([["/skills/commit/SKILL.md"], [], ["/skills/herdr/SKILL.md"]]);
  });

  test.each([
    ["a partial name", "see /de", { prefix: "de", items: [{ value: "deslop", label: "deslop" }] }],
    ["a partial name after a leading command", "/herdr 驱动 /de", { prefix: "de", items: [{ value: "deslop", label: "deslop" }] }],
    ["a complete name", "see /deslop", null],
    ["a bare slash", "see /", null],
    ["a finished mention", "see /deslop/", null],
    ["a leading command", "/de", piSuggestions],
    ["a leading command's arguments", "/model ", piSuggestions],
  ])("completes %s", async (_name, line, expected) => {
    expect(await provider.getSuggestions([line], 0, line.length, { force: false })).toEqual(expected);
  });

  test("highlights known skills only", () => {
    editorText = "see /commit, not /usr";
    expect(editor.render(80)).toEqual(["see </commit>, not /usr"]);
  });

  test.each([
    ["inside a token", "see /comit now", 7, "co", "commit", "see /commit now", 11],
    ["before punctuation", "改完 /de，然后", 6, "de", "deslop", "改完 /deslop，然后", 10],
  ])("accepting %s completes the token", (_name, line, col, prefix, value, completed, cursorCol) => {
    expect(provider.applyCompletion([line], 0, col, { value }, prefix)).toEqual({ lines: [completed], cursorLine: 0, cursorCol });
  });
});

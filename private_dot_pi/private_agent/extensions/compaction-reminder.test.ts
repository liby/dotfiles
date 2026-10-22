import { expect, test } from "bun:test";

type Message = { role: string; timestamp: number; content?: string };
type Context = (event: { messages: Message[] }) => { messages: Message[] } | undefined;

const reminder = (await Bun.file(new URL("../../../.chezmoitemplates/agents/compaction-reminder.md", import.meta.url)).text()).trim();
const template = await Bun.file(new URL("./compaction-reminder.ts.tmpl", import.meta.url)).text();
const source = template.replace('{{ includeTemplate "agents/compaction-reminder.md" . | trim | toJson }}', JSON.stringify(reminder));
const script = new Bun.Transpiler({ loader: "ts" }).transformSync(source);
const { default: register } = await import(`data:text/javascript;base64,${Buffer.from(script).toString("base64")}`);
let context: Context;
register({ on: (event: string, handler: Context) => {
  expect(event).toBe("context");
  context = handler;
} });

test("leaves uncompacted context unchanged", () => {
  const messages = [{ role: "user", timestamp: 1 }];
  expect(context({ messages })).toBeUndefined();
  expect(messages).toEqual([{ role: "user", timestamp: 1 }]);
});

test("places the reminder after retained history and before new messages", () => {
  const summary = { role: "compactionSummary", timestamp: 10 };
  const kept = { role: "assistant", timestamp: 2 };
  const current = { role: "user", timestamp: 11 };
  const messages = [summary, kept, current];
  const expected = [summary, kept, expect.objectContaining({ content: reminder, display: false }), current];
  expect(context({ messages })?.messages).toEqual(expected);
  expect(context({ messages })?.messages).toEqual(expected);
  expect(messages).toEqual([summary, kept, current]);
});

test("covers in-turn compaction before any new message exists", () => {
  const summary = { role: "compactionSummary", timestamp: 10 };
  const kept = { role: "toolResult", timestamp: 2 };
  expect(context({ messages: [summary, kept] })?.messages)
    .toEqual([summary, kept, expect.objectContaining({ content: reminder, display: false })]);
});

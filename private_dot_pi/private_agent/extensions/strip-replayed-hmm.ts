import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Long DeepSeek V4.1 Flash sessions accumulate "Hmm." filler in their thinking, and
// filler left in the reasoning Pi replays makes the next turn write more of it.
// DeepSeek's API docs require replaying reasoning on tool requests, so only the
// filler is removed, and only from the copy sent to the model. Remove this once the
// model no longer repeats the filler it is shown.
const HMM_FILLER = /\bhmm+\b[.!?,…—-]*\s*/gi;

export default function (pi: ExtensionAPI) {
  pi.on("context", (event, ctx) => {
    const model = ctx.model;
    if (model?.id !== "deepseek/deepseek-v4.1-flash") return;
    const messages = event.messages.map((message) => {
      // Pi replays a thinking signature only to the model that wrote it and sends other
      // models' thinking as plain text.
      const isOwnMessage =
        message.role === "assistant" &&
        message.provider === model.provider &&
        message.api === model.api &&
        message.model === model.id;
      if (!isOwnMessage) return message;
      const content = message.content.map((block) => {
        if (block.type !== "thinking") return block;
        // Pi replays the reasoning_details stored in thinkingSignature, not block.thinking.
        const reasoningDetails = JSON.parse(block.thinkingSignature!) as { text: string }[];
        const withoutFiller = reasoningDetails.map((detail) => ({ ...detail, text: detail.text.replace(HMM_FILLER, "") }));
        return { ...block, thinkingSignature: JSON.stringify(withoutFiller) };
      });
      return { ...message, content };
    });
    return { messages };
  });
}

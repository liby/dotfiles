import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// DeepSeek V4.1 Flash pads the thinking of long sessions with interjections ("Hmm",
// "嗯") and short lines repeated verbatim ("好。", "执行。", "Let me run."). Pi
// replays earlier thinking with every request, and the model continues the filler it
// is shown, up to a loop that runs until the output limit. This removes the filler
// from the copy sent to the model; the session keeps the original, and the rest of the
// reasoning stays because DeepSeek's API requires it on tool requests.
//
// Short filler lines are found by repetition, not by a word list, because suppressing
// one wording only moves the loop to the next. The first copy of each stays in case it
// carries meaning, so a short verdict repeated after different steps also keeps only
// its first copy. Deduplicating within each message instead would leave one copy of
// every filler line per message for the model to continue.
//
// The filter relies on how Pi replays reasoning (see the comments in the handler); if
// Pi changes that, the filter stops taking effect without raising an error. Remove it
// once the model no longer continues filler it is shown.
const INTERJECTION = /嗯+[。，,.!！?？…—-]*\s*|\bhmm+\b[.!?,？…—-]*\s*/gi;
const MAX_FILLER_LINE_LENGTH = 12;
const MIN_FILLER_REPEATS = 3;

function isShortStatement(line: string) {
  return line.length <= MAX_FILLER_LINE_LENGTH && /\p{L}/u.test(line) && /[。.！!）)]$/u.test(line);
}

function indentColumns(whitespace: string) {
  let columns = 0;
  for (const char of whitespace) columns = char === "\t" ? columns + 4 - (columns % 4) : columns + 1;
  return columns;
}

// Lines inside fenced code are content, not narration, and are never changed. Fences
// opened after a list or blockquote marker ("- ~~~", "> ```") are not recognized, so
// their lines count as prose; DeepSeek's reasoning has not used them.
function splitLines(text: string) {
  let open: { marker: string; indent: number } | undefined;
  return text.split("\n").map((line) => {
    const trimmed = line.trim();
    const fence = /^([ \t]*)(`{3,}|~{3,})/.exec(line);
    if (open === undefined && fence) {
      open = { marker: fence[2], indent: indentColumns(fence[1]) };
      return { line, trimmed, prose: false };
    }
    if (open !== undefined) {
      // A closer uses the opener's character, is at least as long, and has only spaces
      // or tabs after it. CommonMark measures its three columns of allowed indentation
      // from the enclosing list item, which is not tracked here, so a closer indented
      // past both three columns and its opener is kept as code: that can leave filler
      // in place but cannot remove code.
      const closes =
        fence &&
        fence[2][0] === open.marker[0] &&
        fence[2].length >= open.marker.length &&
        indentColumns(fence[1]) <= Math.max(3, open.indent) &&
        /^[ \t\r]*$/.test(line.slice(fence[0].length));
      if (closes) open = undefined;
      return { line, trimmed, prose: false };
    }
    return { line, trimmed, prose: true };
  });
}

export default function (pi: ExtensionAPI) {
  pi.on("context", (event, ctx) => {
    const model = ctx.model;
    if (model?.id !== "deepseek/deepseek-v4.1-flash") return;
    // Pi replays a thinking signature only to the model that wrote it and sends other
    // models' thinking as plain text. It also drops errored and aborted assistant
    // messages before sending (pi-ai transform-messages.js), so they neither count
    // toward repeats nor hold the kept first copy, which the model would never see.
    type Message = (typeof event.messages)[number];
    const isReplayedOwnMessage = (message: Message): message is Extract<Message, { role: "assistant" }> =>
      message.role === "assistant" &&
      message.provider === model.provider &&
      message.api === model.api &&
      message.model === model.id &&
      message.stopReason !== "error" &&
      message.stopReason !== "aborted";
    // Pi replays the reasoning_details stored in thinkingSignature, not block.thinking.
    const reasoningDetails = (signature: string) => JSON.parse(signature) as { text: string }[];

    const repeats = new Map<string, number>();
    for (const message of event.messages) {
      if (!isReplayedOwnMessage(message)) continue;
      for (const block of message.content) {
        if (block.type !== "thinking") continue;
        for (const detail of reasoningDetails(block.thinkingSignature!)) {
          for (const { trimmed, prose } of splitLines(detail.text)) {
            if (prose && isShortStatement(trimmed)) repeats.set(trimmed, (repeats.get(trimmed) ?? 0) + 1);
          }
        }
      }
    }

    const keptRepeats = new Set<string>();
    const withoutFiller = (text: string) => {
      const lines = splitLines(text).flatMap(({ line, trimmed, prose }) => {
        if (!prose) return [line];
        if ((repeats.get(trimmed) ?? 0) >= MIN_FILLER_REPEATS) {
          if (keptRepeats.has(trimmed)) return [];
          keptRepeats.add(trimmed);
        }
        const cleaned = line.replace(INTERJECTION, "");
        return trimmed !== "" && cleaned.trim() === "" ? [] : [cleaned];
      });
      return lines.join("\n");
    };

    const messages = event.messages.map((message) => {
      if (!isReplayedOwnMessage(message)) return message;
      const content = message.content.map((block) => {
        if (block.type !== "thinking") return block;
        const details = reasoningDetails(block.thinkingSignature!).map((detail) => ({ ...detail, text: withoutFiller(detail.text) }));
        return { ...block, thinkingSignature: JSON.stringify(details) };
      });
      return { ...message, content };
    });
    return { messages };
  });
}

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// DeepSeek V4.1 Flash pads long sessions' thinking with interjections ("Hmm", "嗯")
// and repeated lines ("好。", "Let me do it."). Pi replays earlier thinking with every
// request and the model continues the filler it is shown, until one response loops to
// the output limit. This strips the filler from the request copy only; the rest of the
// reasoning stays because DeepSeek requires it on tool requests.
//
// Filler is found by repetition, not by a word list (suppressing one wording moves the
// loop to the next) and not by length (it runs from "好。" to "Let me write the final
// report."). It stands alone as a paragraph, while repeated plan and status items sit
// in consecutive lines and must keep every copy. Copies are counted across the whole
// request, since per-message deduplication would leave one copy per message to
// continue, and the first copy stays in case it carries meaning.
//
// If Pi changes how it replays reasoning, this stops taking effect without an error.
// Remove it once the model no longer continues filler it is shown.
const MODEL_ID = "deepseek/deepseek-v4.1-flash";
// Quoted, code and path uses ("`hmm`", "/tmp/hmm.txt", "hmm-model") are content.
const INTERJECTION = /(?<![`"'/])(?:嗯+|\b[Hh]mm+\b)(?![`"'/]|[.-]\w)[。，,.!！?？…—:：;；-]*\s*/g;
// A fence may open after list or quote markers ("- ```", "> ~~~").
const FENCE = /^((?:[ \t]*(?:[-*+]|\d+[.)])[ \t]+|[ \t]*>[ \t]?)*[ \t]*)(`{3,}|~{3,})/;
const MIN_FILLER_REPEATS = 3;

// No ASCII ")": it would admit standalone code such as "run(x)", and no filler has
// ended with it. List items, headings and quotes stay even when blank lines separate them.
function isStatement(line: string) {
  return /\p{L}/u.test(line) && /[。.！!）]$/u.test(line) && !/^([-*+]\s|\d+[.)、．）]|#{1,6}\s|>)/.test(line);
}

function indentColumns(prefix: string) {
  let columns = 0;
  for (const char of prefix) columns = char === "\t" ? columns + 4 - (columns % 4) : columns + 1;
  return columns;
}

// Paragraphs are judged on the lines the model will see, after interjection-only lines
// are dropped.
function visibleLines(text: string) {
  let open: { marker: string; indent: number } | undefined;
  const lines = text.split("\n").flatMap((line) => {
    const fence = FENCE.exec(line);
    if (open !== undefined) {
      // CommonMark measures closer indentation from the enclosing container, which is not
      // tracked here; a closer that does not match keeps the fence open, which can keep
      // filler but never removes code.
      const closes =
        fence !== null &&
        fence[2][0] === open.marker[0] &&
        fence[2].length >= open.marker.length &&
        indentColumns(fence[1]) <= Math.max(3, open.indent) &&
        /^[ \t\r]*$/.test(line.slice(fence[0].length));
      if (closes) open = undefined;
      return [{ line, prose: false, closesFence: closes }];
    }
    if (fence !== null) {
      open = { marker: fence[2], indent: indentColumns(fence[1]) };
      return [{ line, prose: false, closesFence: false }];
    }
    const cleaned = line.replace(INTERJECTION, "");
    if (line.trim() !== "" && cleaned.trim() === "") return [];
    return [{ line: cleaned, prose: true, closesFence: false }];
  });
  // A closed fence starts a paragraph, but an opening one does not end it: quoted text
  // often runs straight into a code block.
  const isBlank = (index: number) => index < 0 || index >= lines.length || (lines[index].prose && lines[index].line.trim() === "");
  return lines.map(({ line, prose }, index) => {
    const statement = line.trim();
    const standalone =
      prose && isStatement(statement) && (isBlank(index - 1) || lines[index - 1].closesFence) && isBlank(index + 1);
    return { line, filler: standalone ? statement : undefined };
  });
}

const isRecord = (value: unknown): value is Record<string, unknown> => typeof value === "object" && value !== null;
const hasText = (detail: unknown): detail is { text: string } => isRecord(detail) && typeof detail.text === "string";
const reasoningDetails = (message: unknown): unknown[] =>
  isRecord(message) && Array.isArray(message.reasoning_details) ? message.reasoning_details : [];

export default function stripReplayedFiller(pi: ExtensionAPI) {
  // The request Pi has built already applies its replay rules: only the same model's
  // reasoning, without errored or aborted turns, one signed thinking block per message.
  pi.on("before_provider_request", (event, ctx) => {
    if (ctx.model?.id !== MODEL_ID) return;
    const payload = event.payload;
    if (!isRecord(payload) || !Array.isArray(payload.messages)) return;
    const messages: unknown[] = payload.messages;

    const repeats = new Map<string, number>();
    const replayedLines = messages
      .flatMap(reasoningDetails)
      .filter(hasText)
      .flatMap((detail) => visibleLines(detail.text));
    for (const { filler } of replayedLines) if (filler !== undefined) repeats.set(filler, (repeats.get(filler) ?? 0) + 1);

    const keptRepeats = new Set<string>();
    const isLaterCopy = (filler: string | undefined) => {
      if (filler === undefined || (repeats.get(filler) ?? 0) < MIN_FILLER_REPEATS) return false;
      if (keptRepeats.has(filler)) return true;
      keptRepeats.add(filler);
      return false;
    };
    const withoutFiller = (text: string) => {
      const lines = visibleLines(text);
      const kept: string[] = [];
      for (let index = 0; index < lines.length; index++) {
        // A standalone line is followed by a blank line or the end; drop that blank too,
        // or a long run of copies leaves as many empty lines behind.
        if (isLaterCopy(lines[index].filler)) index++;
        else kept.push(lines[index].line);
      }
      return kept.join("\n");
    };

    return {
      ...payload,
      messages: messages.map((message) => {
        if (!isRecord(message) || !Array.isArray(message.reasoning_details)) return message;
        const details: unknown[] = message.reasoning_details;
        return {
          ...message,
          reasoning_details: details.map((detail) => (hasText(detail) ? { ...detail, text: withoutFiller(detail.text) } : detail)),
        };
      }),
    };
  });
}

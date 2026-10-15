import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Invoke a skill from anywhere in a prompt by mentioning it as `/name`. Pi opens
// slash completion only on the first line when the line starts with "/", and it
// drops "/" from autocomplete trigger characters, so the editor wrapper below
// requests completion itself.
//
// On submit the first mention is rewritten to the leading `/skill:name` form, so Pi
// expands, renders, compacts, and exports the skill natively; a second mention
// stays literal, as it would after a leading `/skill:name` command. The rewrite is
// limited to the interactive editor, where the person can see the result; a script
// uses the explicit `/skill:name` form. Wrapping a mention in backticks keeps it literal.
//
// A mention starts after whitespace or CJK punctuation, as Pi's @ and # completion
// does. pi-tui keeps that boundary regex out of its package root, and the extension
// loader aliases only the root, so a deep import does not resolve.
const BOUNDARY = String.raw`(?:^|\s|(?=\p{Punctuation})[\p{Script_Extensions=Han}\p{Script_Extensions=Hiragana}\p{Script_Extensions=Katakana}\p{Script_Extensions=Hangul}\p{Script_Extensions=Bopomofo}]|[，．：；！？（）［］｛｝“”‘’…—])`;
const MENTION = new RegExp(String.raw`${BOUNDARY}\/([a-z0-9][a-z0-9-]*)(?![A-Za-z0-9_/-])(?!\.[A-Za-z0-9_])`, "gu");
const TRAILING_FRAGMENT = new RegExp(String.raw`${BOUNDARY}\/([a-z0-9-]+)$`, "u");
const ENDED_MENTION = new RegExp(String.raw`${BOUNDARY}\/[a-z0-9-]+[^a-z0-9-]$`, "u");
const TOKEN_SUFFIX = /^[a-z0-9-]*/;
const FENCE = /^\s*(?:```|~~~)/;

// getLines, getCursor, and tryTriggerAutocomplete sit on the Editor rather than the
// EditorComponent interface the factory returns.
type CompletionEditor = {
  getLines?(): string[];
  getCursor?(): { line: number; col: number };
  isShowingAutocomplete?(): boolean;
  tryTriggerAutocomplete?(): void;
};

function availableSkills(pi: ExtensionAPI) {
  return pi
    .getCommands()
    .filter((command) => command.source === "skill")
    .map((command) => ({ name: command.name.slice("skill:".length), description: command.description }));
}

function textBeforeCursor(lines: readonly string[], line: number, col: number) {
  return [...lines.slice(0, line), (lines[line] ?? "").slice(0, col)].join("\n");
}

// The fragment after an inline "/", or undefined when the cursor is not in one. A
// fragment at the start of the message is Pi's own command completion, not ours.
function inlineFragment(before: string) {
  if (before.trimStart().startsWith("/")) return undefined;
  return TRAILING_FRAGMENT.exec(before)?.[1];
}

// A mention inside a fenced code block is code, not an invocation.
function firstInlineSkill(text: string, names: ReadonlySet<string>) {
  let offset = 0;
  let fenced = false;
  for (const line of text.split("\n")) {
    if (FENCE.test(line)) {
      fenced = !fenced;
    } else if (!fenced) {
      for (const match of line.matchAll(MENTION)) {
        const slash = offset + (match.index ?? 0) + match[0].indexOf("/");
        if (text.slice(0, slash).trim() === "") continue;
        if (names.has(match[1])) return match[1];
      }
    }
    offset += line.length + 1;
  }
  return undefined;
}

export default function inlineSkillInvocation(pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    // Pi does not carry embedWorkingStatus over from its default editor to a replacement.
    const base =
      ctx.ui.getEditorComponent() ??
      ((tui, theme, keybindings) => new CustomEditor(tui, theme, keybindings, { embedWorkingStatus: true }));
    ctx.ui.setEditorComponent((tui, theme, keybindings) => {
      const editor = base(tui, theme, keybindings);
      const completion = editor as CompletionEditor;
      if (!completion.getLines || !completion.getCursor || !completion.tryTriggerAutocomplete) return editor;
      const getLines = completion.getLines.bind(editor);
      const getCursor = completion.getCursor.bind(editor);
      const tryTriggerAutocomplete = completion.tryTriggerAutocomplete.bind(editor);
      const isShowingAutocomplete = completion.isShowingAutocomplete?.bind(editor);

      const handleInput = editor.handleInput.bind(editor);
      editor.handleInput = (data) => {
        const text = editor.getText();
        handleInput(data);
        // A cursor move leaves the text unchanged and must not reopen the menu, while
        // Backspace that shrinks a fragment back into range must.
        if (editor.getText() === text || isShowingAutocomplete?.()) return;
        const { line, col } = getCursor();
        if (inlineFragment(textBeforeCursor(getLines(), line, col)) !== undefined) tryTriggerAutocomplete();
      };
      return editor;
    });

    ctx.ui.addAutocompleteProvider((current) => ({
      async getSuggestions(lines, line, col, options) {
        const before = textBeforeCursor(lines, line, col);
        const fragment = inlineFragment(before);
        if (fragment !== undefined) {
          const items = availableSkills(pi)
            .filter((skill) => skill.name.startsWith(fragment))
            .map((skill) => ({
              value: skill.name,
              label: `/${skill.name}`,
              ...(skill.description && { description: skill.description }),
            }));
          // A mention offers skills only. Without one, Tab still reaches Pi's own path
          // completion, which is what an inline "/usr" was before this extension.
          if (items.length > 0) return { prefix: fragment, items };
          return options.force ? current.getSuggestions(lines, line, col, options) : null;
        }
        // A finished mention leaves a path-shaped tail; handing it to Pi's provider
        // turns the menu into a file list that Enter then inserts into the prompt.
        if (!options.force && ENDED_MENTION.test(before)) return null;
        return current.getSuggestions(lines, line, col, options);
      },
      applyCompletion(lines, line, col, item, prefix) {
        const fragment = inlineFragment(textBeforeCursor(lines, line, col));
        if (fragment === undefined || fragment !== prefix) return current.applyCompletion(lines, line, col, item, prefix);
        // Accepting mid-token must consume the rest of the token, or `/co|de-review`
        // becomes `/code-review de-review`.
        const currentLine = lines[line] ?? "";
        const tokenStart = col - prefix.length - 1;
        const suffix = TOKEN_SUFFIX.exec(currentLine.slice(col))?.[0] ?? "";
        const rest = currentLine.slice(col + suffix.length);
        const inserted = `/${item.value}${/^\s/.test(rest) ? "" : " "}`;
        const next = [...lines];
        next[line] = currentLine.slice(0, tokenStart) + inserted + rest;
        return { lines: next, cursorLine: line, cursorCol: tokenStart + inserted.length };
      },
      shouldTriggerFileCompletion(lines, line, col) {
        return inlineFragment(textBeforeCursor(lines, line, col)) !== undefined || (current.shouldTriggerFileCompletion?.(lines, line, col) ?? true);
      },
    }));
  });

  pi.on("input", (event, ctx) => {
    if (ctx.mode !== "tui" || event.source === "extension" || event.text.startsWith("/")) return { action: "continue" };
    const name = firstInlineSkill(event.text, new Set(availableSkills(pi).map((skill) => skill.name)));
    return name ? { action: "transform", text: `/skill:${name} ${event.text}` } : { action: "continue" };
  });
}

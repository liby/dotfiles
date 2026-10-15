import { CustomEditor, type ExtensionAPI, parseSkillBlock } from "@earendil-works/pi-coding-agent";
import { Marked } from "@earendil-works/pi-tui";

// Lets `/name` invoke a skill anywhere in an interactive prompt; scripts use `/skill:name`.
// Pi expands only one leading `/skill:name` per message, so on submit the first mention
// visible in the editor gets that prefix and Pi renders, compacts, and exports the skill
// natively. Other mentions, including any in a collapsed paste, are named to the model,
// which decides whether they were requests.
//
// Pi offers slash completion only at the start of the first line and does not trigger it
// on "/", so the editor wrapper requests completion itself.
//
// Mentions use Pi's @ and # boundary, whitespace or CJK punctuation; after a Han
// character or ASCII punctuation, "/" usually means "or" or a path (`代码/review`,
// `~/commit`). pi-tui keeps that regex out of its root export, and extensions can import
// only package roots.
const CJK_PUNCTUATION = String.raw`(?=\p{Punctuation})[\p{Script_Extensions=Han}\p{Script_Extensions=Hiragana}\p{Script_Extensions=Katakana}\p{Script_Extensions=Hangul}\p{Script_Extensions=Bopomofo}]|[，．：；！？（）［］｛｝“”‘’…—]`;
// Completion leaves a "/" that starts the message, and that command's arguments, to Pi's
// own command menu.
const INLINE_BOUNDARY = String.raw`(?:\s|${CJK_PUNCTUATION})`;
const MENTION = new RegExp(String.raw`(?:^|${INLINE_BOUNDARY})\/([a-z0-9][a-z0-9-]*)(?![A-Za-z0-9_/-])(?!\.[A-Za-z0-9_])`, "gu");
const TRAILING_FRAGMENT = new RegExp(String.raw`${INLINE_BOUNDARY}\/([a-z0-9-]+)$`, "u");
const ENDED_MENTION = new RegExp(String.raw`${INLINE_BOUNDARY}\/(?:[a-z0-9-]+[^a-z0-9-])?$`, "u");
const TOKEN_SUFFIX = /^[a-z0-9-]*/;
const markdown = new Marked();

// getLines, getCursor, and tryTriggerAutocomplete sit on the Editor rather than the
// EditorComponent interface the factory returns.
type CompletionEditor = {
  getLines?(): string[];
  getCursor?(): { line: number; col: number };
  isShowingAutocomplete?(): boolean;
  tryTriggerAutocomplete?(): void;
};

type Skill = { name: string; description?: string; path: string };

function textBeforeCursor(lines: readonly string[], line: number, col: number) {
  return [...lines.slice(0, line), (lines[line] ?? "").slice(0, col)].join("\n");
}

function inlineFragment(before: string) {
  return TRAILING_FRAGMENT.exec(before)?.[1];
}

// Skills mentioned outside Markdown code, in order and each once. Marked keeps prose in
// text tokens and code out of them. A text token can start right after inline markup, as
// in `**note**/commit`, so a name must also be a mention in the full text, which is what
// the editor highlights.
function mentionedSkills(text: string, skills: ReadonlyMap<string, Skill>) {
  const mentions = (source: string) => Array.from(source.matchAll(MENTION), (match) => match[1]).filter((name) => skills.has(name));
  const candidates = mentions(text);
  // Lexing costs far more than the scan, and most text mentions no skill.
  if (candidates.length === 0) return [];
  const found: string[] = [];
  markdown.walkTokens(markdown.lexer(text), (token) => {
    if (token.type === "text" && !token.tokens?.length) found.push(...mentions(token.raw));
  });
  return [...new Set(found)].filter((name) => candidates.includes(name));
}

function highlightMentions(lines: readonly string[], names: ReadonlySet<string>, style: (text: string) => string) {
  return lines.map((line) =>
    line.replace(MENTION, (match, name: string) => {
      if (!names.has(name)) return match;
      const slash = match.indexOf("/");
      return match.slice(0, slash) + style(match.slice(slash));
    }),
  );
}

export default function inlineSkillInvocation(pi: ExtensionAPI) {
  // Commands change only on reload, which emits session_start again.
  let skills = new Map<string, Skill>();
  let commands = new Set<string>();
  // The editor text before the last key and the message Pi would expand it to. The input
  // handler uses it only when the expansion matches what was submitted.
  let submitted: { shown: string; expanded: string } | undefined;

  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    const all = pi.getCommands();
    commands = new Set(all.map((command) => command.name));
    skills = new Map(
      all
        .filter((command) => command.source === "skill")
        .map((command) => {
          const name = command.name.slice("skill:".length);
          return [name, { name, description: command.description, path: command.sourceInfo.path }];
        }),
    );

    // Pi does not carry embedWorkingStatus over from its default editor to a replacement.
    const base =
      ctx.ui.getEditorComponent() ??
      ((tui, theme, keybindings) => new CustomEditor(tui, theme, keybindings, { embedWorkingStatus: true }));
    ctx.ui.setEditorComponent((tui, theme, keybindings) => {
      const editor = base(tui, theme, keybindings);
      const render = editor.render.bind(editor);
      editor.render = (width) =>
        highlightMentions(render(width), new Set(mentionedSkills(editor.getText(), skills)), theme.selectList.selectedText);

      const completion = editor as CompletionEditor;
      if (!completion.getLines || !completion.getCursor || !completion.tryTriggerAutocomplete) return editor;
      const getLines = completion.getLines.bind(editor);
      const getCursor = completion.getCursor.bind(editor);
      const tryTriggerAutocomplete = completion.tryTriggerAutocomplete.bind(editor);
      const isShowingAutocomplete = completion.isShowingAutocomplete?.bind(editor);

      const handleInput = editor.handleInput.bind(editor);
      editor.handleInput = (data) => {
        const text = editor.getText();
        // Enter, Alt+Enter, and accepting a command completion each submit along their own
        // path, expanding collapsed pastes on the way, so record the editor before any key.
        submitted = { shown: text, expanded: (editor.getExpandedText?.() ?? text).trim() };
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
          if (skills.has(fragment)) return null;
          const items = [...skills.values()]
            .filter((skill) => skill.name.startsWith(fragment))
            .map((skill) => ({
              value: skill.name,
              label: skill.name,
              ...(skill.description && { description: skill.description }),
            }));
          if (items.length > 0) return { prefix: fragment, items };
          return options.force ? current.getSuggestions(lines, line, col, options) : null;
        }
        // A bare inline "/" or a finished mention looks like a path to Pi's provider, which
        // turns the menu into a file list that Enter then inserts into the prompt.
        if (!options.force && ENDED_MENTION.test(before)) return null;
        return current.getSuggestions(lines, line, col, options);
      },
      applyCompletion(lines, line, col, item, prefix) {
        const fragment = inlineFragment(textBeforeCursor(lines, line, col));
        if (fragment !== prefix) return current.applyCompletion(lines, line, col, item, prefix);
        const currentLine = lines[line] ?? "";
        const tokenStart = col - prefix.length - 1;
        const rest = currentLine.slice(col).replace(TOKEN_SUFFIX, "");
        const inserted = `/${item.value}${/^[\s\p{P}]/u.test(rest) ? "" : " "}`;
        const next = [...lines];
        next[line] = currentLine.slice(0, tokenStart) + inserted + rest;
        return { lines: next, cursorLine: line, cursorCol: tokenStart + inserted.length };
      },
      shouldTriggerFileCompletion(lines, line, col) {
        return inlineFragment(textBeforeCursor(lines, line, col)) !== undefined || (current.shouldTriggerFileCompletion?.(lines, line, col) ?? true);
      },
    }));
  });

  pi.on("input", (event) => {
    if (event.source !== "interactive") return { action: "continue" };
    const leadingCommand = /^\/(\S+)/.exec(event.text)?.[1];
    if (leadingCommand !== undefined && commands.has(leadingCommand)) return { action: "continue" };
    const shown = submitted?.expanded === event.text ? submitted.shown : event.text;
    const invoked = mentionedSkills(shown, skills)[0];
    return invoked ? { action: "transform", text: `/skill:${invoked} ${event.text}` } : { action: "continue" };
  });

  // The hint joins the user message because a separate message would take its own turn
  // when steering. It is edited in place, since a returned list makes Pi drop its
  // mid-conversation system messages, and the same message always gets the same hint, so
  // the cached prompt prefix holds.
  pi.on("context", (event) => {
    for (const message of event.messages) {
      if (message.role !== "user" || typeof message.content === "string") continue;
      const text = message.content.find((part) => part.type === "text")?.text;
      if (text === undefined) continue;
      const block = parseSkillBlock(text);
      const hinted = mentionedSkills(block ? (block.userMessage ?? "") : text, skills).filter((name) => name !== block?.name);
      if (hinted.length === 0) continue;
      message.content.push({
        type: "text",
        text: hinted
          .map((name) => `The user's message contains /${name}, which is the name of the skill at ${skills.get(name)?.path}. If they are asking you to use it, read that file first and follow it. If they only mention it, do not run it.`)
          .join("\n"),
      });
    }
  });
}

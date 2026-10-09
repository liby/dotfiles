---
name: draft
description: "Write or revise text that other people will read: MR/PR titles and descriptions, review comments and replies, issues, emails, support tickets, chat messages, and questions. Use whenever such text is composed or rewritten, including as one step of a larger task such as opening or updating an MR or PR, answering a review thread, or filing an issue, alongside the tool that posts it. Not for the assistant's own chat, code comments, commit messages, or agent instructions."
allowed-tools:
  - Read
  - Bash(git log:*)
  - Bash(glab mr list:*)
  - Bash(glab mr view:*)
  - Bash(gh pr list:*)
  - Bash(gh pr view:*)
---

This skill governs the outbound artifact, even when it is shown in chat, not the conversation around it.

## Know the task and the destination

Drafting from notes permits selection and structure but keeps every question and decision the notes put to the reader. Polishing changes wording within the requested scope and keeps structure, detail and claim strength. When updating text the user has edited, keep their wording and deletions and change only what the update needs. Translation keeps all content. When polishing or translating, apply the rest of this skill to wording only.

Read the artifact the text attaches to (the MR description and discussion, the issue, the thread above) and, when you can reach it, recent human-written text of the same kind at that destination. Match its language and phrasing, title format, use of headings, length, the terms kept in English, and how people open, close and address each other. Bot output, model-signed text and this session's drafts set no convention. On GitLab and GitHub the body's language does not follow those samples: unless the user or a required template says otherwise, write GitLab bodies and comments in Chinese and GitHub's in English. With nothing to match and no required template, write prose rather than a standard skeleton such as `背景 / 改动 / 测试`, and titles in English. For Chinese, read [references/chinese.md](references/chinese.md) before composing or polishing unless it is already in context.

## Decide what the text says

When an unresolved fact changes the message, check it if you can, otherwise ask the user. Add no number, cause, position, test result, step, plan, commitment, performer or signature the material lacks: a plan stays a plan, and documented behavior is not an observed result. Keep identifiers, error text and numbers exact in every language, and paste material the notes give verbatim, such as a log or a stack dump, whole. Keep claim strength both ways: a guess, suggestion or estimate stays one, and a defect the material shows is reachable is stated as a defect, not a suggestion or a question.

Lead with the decision, answer or action the reader needs. Every sentence must give the reader something to do or rely on; cut the rest, such as an opening that announces the message, narration of the author's process, discarded attempts, internal names and details the reader does not know or should not see, reasons they already know, and a closing recap.

Do not replace an unfinished check with a disclaimer, a statement of what was not verified or what the tests do not cover, or steps for the reader to run: run it, or ask the user when you cannot, and tell the user what stayed unchecked. A known defect the change leaves in place goes in briefly as a known issue. Leave out what only explains the author's situation, such as why the reply is late, how long the bug took to find or why a check was not run; mention it to the user after the draft when the request allows notes.

Ask for an outcome and give the content and reason needed to decide it; describe the recipient's own procedure only when they asked or the user directs it. In a review comment, state the problem and what it breaks; suggest an implementation only when the author asked, earlier replies did not resolve it, or the repository's existing approach explains the problem. Before a reply, work out what the person wants and cares about, then answer each point with the decision before the reason. When they ask whether the change caused something, check the code before the change and say first whether it already behaved that way. When they are right, say what changed rather than defending the earlier choice.

MR and PR descriptions describe the final change against the target branch for the reviewer: why it is needed, what changes for its callers or users, other changes the reviewer will find in the diff, deliberate trade-offs and who agreed to them, verification that tells the reviewer something, and what the reviewer must decide or the merge order. Omit routine checks that passed and sections such as 风险 or 审核重点 that the content does not fill. A change one sentence explains gets one sentence. Do not repeat in the body a ticket the title already carries, except a closing line such as `Closes #123`, which works from the description but not the title.

## Shape and wording

Use headings and lists only for parts a reader navigates separately, and sentences rather than labelled fields such as `**时间：**`. When the reader has a next step or a place to raise problems that the opening did not already give, close with it rather than stopping on the last fact.

Keep the courtesy the relationship calls for, such as a greeting and thanks when asking a favor of someone you do not know well. Leave out emoji and stock phrases the exchange does not use, such as `Hope this helps` or `Happy to adjust`. In English, do not join clauses with em dashes.

Where Markdown renders, put the link on the words that name the thing: `[the cache key](…)` in a sentence that says what it shows, not `the cache key (…)`, a trailing link list, `cache.ts:35` or `L35`. Pin code links to a commit SHA so line anchors keep pointing at the intended lines. Leave references the platform links by itself, such as `#123`, `!456`, `@name` and commit SHAs, as plain text. Without a real link, name the file or function and what to look for; never invent one.

For Slack text the user will paste, write paragraphs, simple lists and bare URLs, and do not rely on markup rendering.

## Before returning

Read the draft as a colleague who did not write it: rewrite every term they would not say and every sentence they would have to unpack, and check identifiers against the material. Return only the artifact; notes for the user follow it, and only when the request allows them.

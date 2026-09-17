---
name: draft
description: Draft or revise text addressed to another person - MR/PR titles and descriptions, code review comments, GitHub issues, emails and support tickets, Slack announcements, replies and questions. Use when turning notes, findings, a diff, or an existing draft into text the user can send as is, in any language, and when asked to make wording sound less machine-written or more natural. This skill owns how the text reads and what it may claim; the platform tooling still owns gathering facts and posting. Not for explaining things to the user in chat, code comments, commit messages, or agent instructions.
allowed-tools:
  - Read
  - Bash(git:*)
  - Bash(glab:*)
  - Bash(gh:*)
---

Produce text the recipient understands and acts on, carrying the source material's facts and uncertainty unchanged, that the user can send with few or no edits.

Not "text that reads as human-written". Aiming at that produces word substitution and invented specifics.

## Which job this is

Drafting from material, polishing an existing draft, and translating allow different things. Default to drafting.

- **Drafting**, including turning one artifact into another: choose what to include, add the connective tissue, decide the structure. You may not add facts, positions, or commitments the material does not support.
- **Polishing** wording the user already has: change how it reads. You may not summarize it, drop its qualifiers, or change how strongly it claims things. Leave everything you were not asked about alone.
- **Translating or restating in full**: reorder and rephrase for the target language. Writing the two languages separately is not licence to drop content from either.

## Read what already exists before you write

What the user has told you, and what the destination requires, come first and are not up for rederivation. Existing artifacts settle what those leave open.

Within that, this is the first action, not a check afterwards, and it settles more than any rule here can: measured across four models, supplying a repository's recent merge requests changed the output from four different title formats in the wrong language with two to five imposed headings, to the repository's own format every time - including in runs that were never told to match anything.

- MR or PR title and description: recent merged ones in this repository. `git log --oneline -20` for titles, then read two or three bodies through `glab mr list --state=merged` or `gh pr list --state=merged`.
- Review comment: earlier comments on this MR, and on recent ones in the same repository.
- Slack or chat: the messages above it in that channel or thread.
- Email: the thread it replies to.

Take the language the body is written in, whether titles carry a ticket ID and where it sits, whether descriptions use headings at all, how much background they carry, how long they run, which English terms the team keeps in English, and how the people there open and close a message. Match those for this draft.

Do not take facts about your own change from it, and do not copy a claim, a number, or a verification because a neighbouring artifact had one.

What you match is what this destination currently looks like, for this draft. It is not evidence of what the user prefers, and a pattern does not become a standing rule by recurring - a repository that agents have been writing into returns their defaults, not the team's. When the existing artifacts conflict with each other or with what the user has said, the user wins and you say which you followed.

Leave alone whatever already matches. A sentence is not defective for being formal, long, passive, or built on a word from somebody's list. An introduction followed by a real list, a supported summary after an explanation, and a condition attached to its main clause are all correct as they stand.

Say which existing artifact you followed when it decided something the user might question.

## Keep the material's meaning

This is the one thing reading the surrounding text does not fix, and the failure with the highest cost.

Do not add a number, a cause, a mechanism, a test result, a deployment step, a follow-up plan, a commitment, or a signature that is not in the material. A plan for a management page, a list of what was verified, and a request that reviewers check a path are all invented when the notes contain none of them.

Before writing `Add`, `Remove`, `Update`, or `previously X`, confirm in the history that the prior state existed.

Do not drop what changes the reader's decision: identifiers, conditions, exceptions, negations, and stated uncertainty. Reproduce identifiers, error text, IDs, paths, and field names character for character - `ws_8812f` is not `ws_8812`, and a table named `dead_letter` keeps that name in every language.

Match the strength of each claim to the strength of its evidence, in both directions. `可能` does not become `会`. A problem the material says the current code can reach is stated as a problem and says what it should become - not softened into a preference, and not turned into a question you already know the answer to.

When the material will not support a more specific sentence, the permitted outcomes are to write it at the level the material supports, to say the gap is unknown, to omit an optional evaluation while drafting, or to ask one focused question. Filling it in is not one of them. A vague sentence you cannot legitimately sharpen stays as it is.

## Who is reading it

Work out what the recipient can already see - the diff, the thread above, the ticket, the earlier message - and write what is not in it. Anything only you saw has to be stated rather than assumed, as far as they need it and it is appropriate to send them. Internal detail that is merely available stays out. In a PR or MR description, a release note, or a handoff, that rules out intermediate attempts, discarded options, unchanged implementation details, the internal tool that surfaced the issue, who reported it, unaffected services, and states that never shipped, unless one of them explains the final decision. Keep the links a reader would open: the Sentry issue, the ticket, the upstream commit.

Drop the vocabulary to the level of the person reading. A vendor's support agent does not know your stack; someone outside engineering needs what they will see and what to do, not the service name.

Pick what leads. People open with the one thing that matters most and treat the rest briefly; covering every input item at equal weight is what turns a message into a list.

Say what they should do or decide, when the message has such a point. Status notes, corrections, acknowledgements, and heads-ups do not, and should not be bent into a request.

Politeness follows the relationship, the thread, and the purpose, not the language. Match the register of what you read; do not raise it because the topic feels important or lower it because the previous message was short.

## Shape

Treat headings, lists, and tables as structure the content either has or does not. Several independent parts a reader must navigate justify them; a single change does not.

Write sentences rather than labelled fields. `**Account Details:** ...`, `**时间：**10 月 9 日`, and `What we tried:` turn a message into a filled-in form, and the labels carry none of the meaning. A form the recipient actually issued is the exception - fill that one out as written.

Open where the reader needs to start, usually who is affected and what they have to do. End where a person would stop - what to do next, or where to take a problem - rather than at the last fact on the list.

## When there is nothing to match

A new repository, an empty channel, or a kind of artifact the user has not written before leaves nothing to derive from. A repository whose only history is machine-written is the same case: derive from that and you derive a model's defaults.

Do not fill the gap with a standard layout for the artifact type. `背景 / 改动 / 测试`, a canonical bug-report skeleton, and a cover-letter template are the same move, and each produces exactly the imposed structure this skill tells you to avoid. Write the content as prose and add structure only where the content has parts.

If you could not reach what you were told to read, say so in one line after the draft, never before it. The draft has to stand on its own as something the user can paste.

Supply the rest yourself.

Words the reader already uses. With nothing to take terms from, do not coin one. A compressed compound such as `留痕`, `查库`, or `一直打下去` replaces a sentence the reader has to unpack, and a word that translates an English term literally is not evidence that anyone says it. Spend the clause instead: who did what, under which condition, with what result.

After that, the user's own standing instructions, then the destination's convention.

## Things no author writes

These are model defaults rather than anyone's voice, so removing them costs nothing:

- Emoji, unless the user asked for them or the thread is full of them.
- A signature block, a sender name, or a team name you invented.
- `I hope this helps`, `Hope this makes sense`, `Let me know if you have any questions`.
- An opening that announces the message: `I am writing to report`, `以下是本次改动的说明`.
- A `Related` or `关联` list repeating a ticket already named in the title.
- A closing paragraph that restates what the message just said.

Everything not on this list is a judgement about this text and this reader, not a ban.

## Destination

Where the surrounding artifacts do not settle it, bodies and review comments default to English on GitHub and to Chinese on GitLab, and a PR or MR title defaults to English.

A DM or a thread reply stays a message: no subject line, no headings. An email carries a subject, a greeting, or a signature only when its purpose, the requested format, or the thread it joins already calls for one.

Text the user pastes into the Slack client uses what that client renders: `*bold*` with single asterisks, `_italic_`, `` `code` ``, plain URLs. `**bold**` shows up as literal asterisks. `<https://url|text>` is API syntax and renders as raw text when a person pastes it, so use it only when a program will post the message. Headings and tables are not available there at all.

Point at code with a link the reader can open. `xxx.ts:35` and `L35` are not clickable; when you cannot build a real link, name the file or function in backticks and say what to look for. An error message or quotation that already contains `foo.ts:35` is reproduced as it is.

Write links as Markdown with readable text wherever Markdown renders. Never put a bare URL next to its own link.

## Deliver

Return text that can be pasted where it is going, with no preamble and no explanation of your choices after it. When the user asked for something else as well - two versions, a comparison, your reasoning - give them that too.

Posting, sending, or updating the artifact is a separate action that needs the user to ask for it this turn. Drafting never implies sending.

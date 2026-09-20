---
name: draft
description: Draft or revise text addressed to another person - MR/PR titles and descriptions, code review comments, GitHub issues, emails and support tickets, Slack announcements, replies and questions. Use when turning notes, findings, a diff, or an existing draft into text the user can send as is, in any language, and when asked to make wording sound less machine-written or more natural. This skill owns how the text reads and what it may claim; the platform tooling still owns gathering facts and posting. Not for explaining things to the user in chat, code comments, commit messages, or agent instructions.
allowed-tools:
  - Read
  - Bash(git log:*)
  - Bash(glab mr list:*)
  - Bash(glab mr view:*)
  - Bash(gh pr list:*)
  - Bash(gh pr view:*)
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

Within that, this is the first action, not a check afterwards, and what you find there settles more than any rule here can.

Two reads, both before you write. Neighbouring artifacts of the same kind show you the form:

- MR or PR title and description: recent merged ones in this repository. `git log --oneline -20` for titles, then read two or three bodies through `glab mr list --state=merged` or `gh pr list --state=merged`.
- Review comment: earlier comments on this MR, and on recent ones in the same repository.
- Slack or chat: the messages above it in that channel or thread.
- Email: the thread it replies to.
- Issue or issue comment: the repository's issue template when it has one, otherwise several recent issues there; before a follow-up, the issue thread itself.

The artifact this text attaches to shows you what the reader already knows. Read that one in full: the MR or PR description before a comment on that MR, the issue body before a reply, the thread above a message, your own side's last email. Whatever it already settles, you do not raise again.

From the neighbours, take the language the body is written in, whether titles carry a ticket ID and where it sits, whether descriptions use headings at all, how much background they carry, how long they run, which English terms the team keeps in English, and how the people there open and close a message. Match those for this draft.

Do not take facts about your own change from it, and do not copy a claim, a number, or a verification because a neighbouring artifact had one.

What you match is what this destination currently looks like, for this draft. It is not evidence of what the user prefers, and a pattern does not become a standing rule by recurring - a repository that agents have been writing into returns their defaults, not the team's. When the existing artifacts conflict with each other or with what the user has said, the user wins and you say which you followed.

Leave alone whatever already matches. A sentence is not defective for being formal, long, passive, or built on a word from somebody's list. An introduction followed by a real list, a supported summary after an explanation, and a condition attached to its main clause are all correct as they stand.

## Keep the material's meaning

This is the one thing reading the surrounding text does not fix, and the failure with the highest cost.

Do not add a number, a cause, a mechanism, a test result, a deployment step, a follow-up plan, a commitment, or a signature that is not in the material. A plan for a management page, a list of what was verified, and a request that reviewers check a path are all invented when the notes contain none of them.

Before writing `Add`, `Remove`, `Update`, or `previously X`, confirm in the history that the prior state existed.

Do not drop what changes the reader's decision: identifiers, conditions, exceptions, negations, and stated uncertainty. Reproduce identifiers, error text, IDs, paths, and field names character for character - `ws_8812f` is not `ws_8812`, and a table named `dead_letter` keeps that name in every language.

Match the strength of each claim to the strength of its evidence, in both directions. `可能` does not become `会`. A problem the material says the current code can reach is stated as a problem and says what it should become - not softened into a preference, and not turned into a question you already know the answer to.

When the material will not support a more specific sentence, the permitted outcomes are to write it at the level the material supports, to say the gap is unknown, to omit an optional evaluation while drafting, or to ask one focused question. Filling it in is not one of them. A vague sentence you cannot legitimately sharpen stays as it is.

## Who is reading it

The notes are the user's account, written in a hurry: they can leave out what the recipient needs and assert things the user has not checked. Supply what the goal implies from what you can read. Ask one question before drafting only when a gap is still open after reading and it would change a fact, a commitment, or what you deliver; a message you can complete as asked is completed, including a short factual one. When something in the notes is contradicted by what you read, do not carry it over as fact: ask, or write it as the user's understanding and say so in the line after the draft.

Work out what the recipient can already see - the diff, the thread above, the ticket, the earlier message - and write what is not in it. Anything only you saw has to be stated rather than assumed, as far as they need it and it is appropriate to send them. Internal detail that is merely available stays out. In a PR or MR description, a release note, or a handoff, that rules out intermediate attempts, discarded options, unchanged implementation details, the internal tool that surfaced the issue, who reported it, unaffected services, and states that never shipped, unless one of them explains the final decision. Keep the links a reader would open: the Sentry issue, the ticket, the upstream commit.

When the destination is public - an open-source issue or PR, a vendor's tracker, a status page - hostnames, local paths, internal URLs, email addresses, and raw debug output come out unless the reader needs that exact string to act.

Drop the vocabulary to the level of the person reading. A vendor's support agent does not know your stack; someone outside engineering needs what they will see and what to do, not the service name.

Pick what leads from what the user wants this message to achieve and what would make this recipient act, not from the wording of the request. People open with the one thing that matters most and treat the rest briefly; covering every input item at equal weight is what turns a message into a list.

Every sentence gives this reader something to know or to do. What was not tested stays in, stated as what to watch; framed as a disclaimer, it protects the writer and tells the reader nothing. A reason clause that restates the obvious, a section such as 风险 or 审核重点 that nobody asked for and the content does not fill, and a detail with no consequence for the reader all come out.

Say what they should do or decide, when the message has such a point. Status notes, corrections, acknowledgements, and heads-ups do not, and should not be bent into a request.

Politeness follows the relationship, the thread, and the purpose, not the language. Match the register of what you read; do not raise it because the topic feels important or lower it because the previous message was short.

## Shape

Treat headings, lists, and tables as structure the content either has or does not. Several independent parts a reader must navigate justify them; a single change does not.

Write sentences rather than labelled fields. `**Account Details:** ...`, `**时间：**10 月 9 日`, and `What we tried:` turn a message into a filled-in form, and the labels carry none of the meaning. A form the recipient actually issued is the exception - fill that one out as written.

Open where the reader needs to start, usually who is affected and what they have to do. End where a person would stop - what to do next when there is such a step, or where to take a problem - rather than at the last fact on the list.

Do not coin a term. A compressed compound such as `留痕`, `查库`, or `一直打下去` replaces a sentence the reader has to unpack, and a word that translates an English term literally is not evidence that anyone says it. Spend the clause instead: who did what, under which condition, with what result.

Concise is not clipped. Judge the register against the venue's current messages and the user's own examples, not against a word list: keep the connectives and function words those messages keep, and the lead-in and close they use. Where they say 仍然, 不需要, 如果遇到, 这个, writing 仍为, 无需, 如遇, 该 reads as half-classical. For an announcement, use the venue's form of advance notice when it has one: a heads-up such as `FYI`, then a one-line subject; introduce the points with a cue such as `需要注意的事项` or its local equivalent rather than dropping straight into bullets; and close by inviting a usable response path, such as replying in the current thread or contacting the owning channel, instead of ending with a clipped destination. These are venue cues, not a fixed template: use only the parts the message and surrounding examples call for. Address people the way the sender does in that venue.

## When there is nothing to match

A new repository, an empty channel, or a kind of artifact the user has not written before leaves nothing to derive from. A repository whose only history is machine-written is the same case: derive from that and you derive a model's defaults.

Do not fill the gap with a standard layout for the artifact type. `背景 / 改动 / 测试`, a canonical bug-report skeleton, and a cover-letter template are the same move, and each produces exactly the imposed structure this skill tells you to avoid. Write the content as prose and add structure only where the content has parts.

The draft has to stand on its own as something the user can paste.

Supply the rest yourself, in this order: words the reader already uses, then the user's own standing instructions, then the destination's convention.

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

Point at code with a link the reader can open, and put the link on the words that name the thing: `only the [plan job](https://...) reads it`, not `only the plan job reads it ([data-platform.yml:209](https://...))`. A path in a trailing parenthesis tells the reader nothing until they click it, and the sentence still has to carry the meaning without it. `xxx.ts:35` and `L35` are not clickable; when you cannot build a real link, name the file or function in backticks and say what to look for. An error message or quotation that already contains `foo.ts:35` is reproduced as it is.

Write links as Markdown with readable text wherever Markdown renders. Never put a bare URL next to its own link.

## Deliver

Return text that can be pasted where it is going, with no preamble. Anything you owe the user about the draft - which existing artifact decided something they might question, what you were told to read and could not reach - goes in one line after it, never before, and never as an explanation of choices they did not ask about. When the user asked for something else as well - two versions, a comparison, your reasoning - give them that too.

Drafting never implies sending. Posting, sending, or updating the artifact is a separate action under its own authorization.

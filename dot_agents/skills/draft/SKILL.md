---
name: draft
description: "Draft or revise text addressed to another person: MR/PR titles and descriptions, review comments, issues, emails, support tickets, Slack messages, replies and questions. Use when turning notes, findings, a diff, or an existing draft into sendable text, or improving its wording in any language. Not for the assistant's own chat, code comments, commit messages, or agent instructions."
allowed-tools:
  - Read
  - Bash(git log:*)
  - Bash(glab mr list:*)
  - Bash(glab mr view:*)
  - Bash(gh pr list:*)
  - Bash(gh pr view:*)
---

This skill governs outbound artifacts, even in chat, not the surrounding conversation.

## Establish the writing task

Identify the recipient, the situation the message responds to, the result the user wants, and how the text will reach the recipient. Use the request and available exchange as evidence.

Select the permitted transformation from the request. When its extent is unspecified, preserve the supplied draft's substantive content and structure while resolving the wording request.

- Drafting from notes, including adapting one artifact into another, permits selection and organization. It does not permit new facts, positions or commitments.
- Polishing permits changes to wording within the requested scope. Preserve headings, examples, detail, claim strength and qualifications unless the user authorizes changing them.
- Translation or complete restatement permits reordering for the target language while retaining all substantive content. Separate language versions carry the same facts and conditions.

Follow explicit instructions and destination requirements. Read the attached MR description/discussion, issue or preceding exchange; distinguish recipient knowledge, sender-only knowledge and permitted disclosure. Assign the recipient's internal procedure only with sender authority or the recipient's request.

For unsettled style choices, sample comparable human-authored artifacts from this recipient or destination. Bots, this session's output and structurally different changes establish no convention. Do not invent authorship; stop when the open choices are settled.

Existing-file language and explicit instructions prevail. Otherwise PR/MR titles and GitHub bodies/comments use English; GitLab bodies/comments use Chinese. Match the exchange's register and established form of address.

## Settle the facts before composing

Separate established facts, the user's stated understanding, requested hypotheses, and unresolved information. When the source does not identify an action's performer, describe the event or result without assigning it to the sender. Treat a next step as a sender commitment only when the source establishes that commitment. Do not convert a documented mechanism into a runtime observation, a proposed action into a completed one, or an unknown into a fact.

When an unresolved fact changes the message's purpose, a material claim or a sender commitment, perform the available evidence work within the task's authority before drafting. If the answer requires the user or unavailable access, ask the focused question that resolves it. Do not replace an unfinished authorized check with a disclaimer or an assignment to the recipient.

Optional detail may be omitted when the selected transformation permits it and the omission does not change the reader's decision. A genuine limitation belongs in the artifact when the recipient needs it to judge or act; it belongs in operational reporting when only the user needs to know it.

Preserve retained identifiers, error text, numbers, conditions, exceptions, negations and causal or temporal relations exactly. Check the previous state before claiming something was added, removed or changed. Do not invent a test result, deployment step, recipient action, follow-up plan, signature or sender identity.

## Compose for the reader

Before composing or polishing Chinese, read [references/chinese.md](references/chinese.md) unless that exact file is already in context.

Use ISO 24495-1:2023's reader outcomes within the permitted transformation:

- Relevant: include what this recipient needs.
- Findable: make the point and qualifications easy to locate.
- Understandable: use established terms and explain unfamiliar identifiers and relationships.
- Usable: make the conclusion or request actionable without inventing actions or commitments.

For English, use transferable ASD-STE100 principles: clear words, consistent technical terms, short sentences, one topic per sentence and conditions before instructional actions. Use active voice when the source names the actor; preserve uncertainty and obligation. Keep natural syntax and the exchange's register. STE's controlled vocabulary and English syntax do not govern Chinese. This summary is self-contained and claims no conformity, certification or percentage; full conformity requires the applicable rules and dictionary.

PR/MR descriptions explain final behavior and reasons or trade-offs absent from the diff. Omit routine check commands and passes unless a template requires them; include informative validation and material gaps.

Review replies answer the author's concern first. State the verified problem and consequence or unresolved question; prescribe implementation only when requested, earlier replies failed to resolve the issue, or the repository approach is needed to explain it.

## Deliver

Put useful URLs on descriptive words in sentences that state the supported fact or action without requiring a click; do not add a links block or a sentence merely to retain a link. Preserve literal URLs when required by the format or protected source text. For references to repository code in rendered Markdown, establish the actual code permalink before composing; if unavailable, name the file/function and what to inspect, and never invent a permalink. Slack uses pasteable plain text, paragraphs, simple lists and ordinary URLs.

Return only the artifact, honor exact output constraints and keep operational notes out; provide requested reasoning, variants or comparisons separately.

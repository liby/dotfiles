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

Produce the message the user needs this recipient to understand. Establish what may change and what the message must accomplish before choosing its wording. This skill governs the artifact even when it is displayed in chat; it does not govern the surrounding conversation.

## Establish the writing task

Identify the recipient, the situation the message responds to, the result the user wants, and how the text will reach the recipient. Use the request and available exchange as evidence. Do not turn the user's narration into a list of equally important points or invent a motive to make it coherent.

Select the permitted transformation from the request. When its extent is unspecified, preserve the supplied draft's substantive content and structure while resolving the wording request.

- Drafting from notes, including adapting one artifact into another, permits selection and organization. It does not permit new facts, positions or commitments.
- Polishing permits changes to wording within the requested scope. Preserve headings, examples, detail, claim strength and qualifications unless the user authorizes changing them.
- Translation or complete restatement permits reordering for the target language while retaining all substantive content. Separate language versions carry the same facts and conditions.

These limits apply throughout: a neighbouring artifact's format does not authorize restructuring a wording-only edit, and a preference for brevity does not authorize summarizing a full restatement.

## Resolve the recipient's context

Follow explicit user instructions and destination requirements first. Read the material the message attaches to: the description and discussion before an MR comment, the issue before its reply, or the preceding exchange before an email or chat response. Establish what the recipient already knows, what only the sender knows, and what can appropriately be disclosed. For public drafts, omit internal hostnames, local paths, internal URLs, personal contact details and raw debug output unless the recipient needs those exact details to act.

Use neighbouring artifacts only for choices still open. For an MR/PR, inspect authorship alongside titles and choose bodies with a comparable kind of change. For an issue, read its template and comparable reports; for messages, use the actual exchange. A bot's title convention, this session's own output, and a recent but structurally different change do not establish the convention for this task. Unknown authorship limits what the sample proves; it does not justify inventing an author or discarding an explicit template.

Stop sampling when the open choices are settled. Record a genuine conflict or inaccessible required source for the user; do not manufacture a house style when evidence is missing. With no applicable convention, organize the content according to the recipient's needs. A template the recipient requires remains binding.

Resolve language before formatting. Existing-file language and explicit instructions prevail. Otherwise PR/MR titles default to English; GitHub bodies and comments to English, GitLab's to Chinese. Match the relationship and the exchange's register, including how the sender addresses the recipient.

## Settle the facts before composing

Separate established facts, the user's stated understanding, requested hypotheses, and unresolved information. A report from another model is a lead until checked against its primary evidence. Do not convert a documented mechanism into a runtime observation, a proposed action into a completed one, or an unknown into a fact.

When an unresolved fact changes the message's purpose, a material claim or a sender commitment, perform the available evidence work within the task's authority before drafting. If the answer requires the user or unavailable access, ask the focused question that resolves it. A plausible sentence does not resolve a missing fact. Do not replace an unfinished authorized check with a disclaimer or an assignment to the recipient.

Optional detail may be omitted when the selected transformation permits it and the omission does not change the reader's decision. A genuine limitation belongs in the artifact when the recipient needs it to judge or act; it belongs in operational reporting when only the user needs to know it. Explicitly requested hypotheses remain qualified hypotheses. Never conceal a material uncertainty to make a draft appear complete.

Preserve retained identifiers, error text, numbers, conditions, exceptions, negations and causal or temporal relations exactly. Check the previous state before claiming something was added, removed or changed. Do not invent a test result, deployment step, recipient action, follow-up plan, signature or sender identity.

## Compose around the message's purpose

For a Chinese artifact, read [references/chinese.md](references/chinese.md) before composing or polishing unless that exact file is already present in the current context. These rules apply to the artifact, not its surrounding conversation. For English, use natural English syntax and the exchange's register.

Lead with the point that lets this recipient understand why the message matters. Develop the necessary explanation in the order they need it, giving each point the weight its consequence deserves. Supply background they cannot otherwise see without repeating what the attached diff, ticket or exchange already establishes.

A request states the desired outcome and enough context for the recipient to consider it. It does not assign the recipient's internal procedure unless the sender has that authority or the recipient requested it. A status note, correction or acknowledgement need not end with a request. Stop when the communicative purpose is fulfilled; do not add a closing recap by habit.

Use paragraphs for connected reasoning and lists or headings for independent parts the reader must navigate. Preserve a required form or requested structure. Do not turn an ordinary message into labelled fields merely because several facts are available, or strip useful structure merely to make it shorter.

PR/MR descriptions explain final behavior and material rationale or trade-offs the diff does not make apparent. Omit routine test, lint, typecheck and build commands and pass results unless a required template calls for them. Include informative manual or risk-specific results and material gaps affecting review. Intermediate attempts, discarded options, unaffected services and internal review mechanics stay out unless they explain the final decision.

For review comments, address one issue per comment. State the verified problem and its consequence or the genuinely unresolved question. Answer the author's concern first in a reply. Specify the required outcome; prescribe implementation only when requested, when earlier replies have not resolved the issue, or when the established repository approach is necessary to explain it. Wording does not reopen the finding's evidence or severity decision.

Use the recipient's established terms. Explain an unfamiliar identifier on first use when needed, rather than substituting a vague label for it. Keep connective words that make sentences natural; compression is useful only while the reader can still follow the relationship between the facts.

## Render and deliver

Keep a DM or thread reply in message form. Add an email subject, greeting or signature only when its purpose, requested format or exchange calls for it. Do not add formulaic courtesy, an announcement of what the message will say, an invented signature, emoji the user or exchange did not call for, or a recap that adds nothing.

Where the destination renders Markdown, resolve the commit, the file path and the line, and build the permalink form that destination uses, before composing the sentence. Place the link on the words naming the fact, code or action it supports, in a sentence that carries the substance without a click. Do not create a links section, retain a bare location as a substitute for explanation, or print a URL alongside its own link. Preserve literal URLs when the destination requires them or they are protected source text. If no real code link can be built, name the file or function and explain what to inspect; do not invent a permalink.

For Slack, return plain text the user can paste into the message composer, using paragraphs, simple lists and ordinary URLs.

Before returning the artifact, read it from the recipient's position: can they identify the point, understand each necessary fact and qualification, and distinguish a request from a sender commitment? Confirm the requested transformation and protected spans survived. Remove only material the permitted scope allows removing.

Return the requested artifact without a preamble or unrequested explanation. Honor exact output constraints. A material question that prevents a trustworthy draft must be resolved before this step; an operational note does not belong inside the artifact. If the user also requested reasoning, variants or a comparison, provide those separately in the requested format.

Drafting does not authorize sending or publishing.

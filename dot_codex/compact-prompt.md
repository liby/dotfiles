You are performing a CONTEXT CHECKPOINT COMPACTION. Create a handoff summary for another LLM that will resume the task.

Include:
- Current progress and key decisions made
- Important context, constraints, or user preferences
- What remains to be done, with clear next steps
- Any critical data, examples, or references needed to continue

Write the compact summary so a fresh agent can continue without re-deriving context. The post-compact session inherits only this summary.

Preserve identifiers exactly: UUIDs, commit hashes, IPs, ports, URLs, file paths, branch names, and PR numbers. One altered character can break downstream tool calls silently.

Identifier preservation does not extend to credentials. Never copy secrets into the summary: no tokens, API keys, cookies, passwords, or .env values, even when earlier tool output displayed them. Name where the credential lives (file path, env var name) instead; the summary becomes the next agent's prompt.

Reference durable artifacts instead of duplicating them. When work has been committed, pushed, or written to a durable artifact, cite the artifact and name which user request it resolved. Do not re-prose the diff or file body. The next agent can run `git show <hash>` or open the file when needed. For external references such as PRDs, ADRs, or third-party issues, cite the reference and add one line with the working fact: decision, status, or conclusion.

Preserve in priority order:

1. Architecture decisions and design trade-offs: keep the decision, rationale, and alternatives rejected. These outlast any single task.
2. Resolved user requests: cite the resolving artifact per the rule above, one line each. The artifact carries the detail.
3. In-flight work: uncommitted edits and ongoing investigation. Quote file paths and the substantive nature of pending changes so the next agent can continue without re-deriving.
4. Known dead ends: approaches tried this session that did not work, with one line on why each failed.
5. Current working directory, active git branch, and environment variables in play: HTTP_PROXY, NODE_ENV, PYTHONPATH, model or effort overrides. Without these the next tool call may run in the wrong place or with the wrong config.
6. Tool outputs: keep the pass or fail verdict, discard raw logs unless they are needed evidence.

Keep the verified/unverified boundary: a claim that was never checked this session carries an explicit `unverified` marker into the summary, so it cannot harden into fact after the handoff.

When two items at the same priority compete for space, prefer the one tied to the user's most recent instruction. Topically distant items at higher priority still win.

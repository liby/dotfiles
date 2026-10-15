#!/usr/bin/env bash
# PreCompact hook.
# Injects compaction priorities as additional instructions to the summarizer.

cat <<'EOF'
<compaction-instructions>

Identifier preservation: copy identifiers character for character (UUIDs, commit hashes, IPs, ports, URLs, file paths, branch names, PR numbers). A single altered character breaks downstream tool calls silently.

Identifier preservation does not extend to credentials. Never copy secrets into the summary: no tokens, API keys, cookies, passwords, or .env values, even when earlier tool output displayed them. Name where the credential lives (file path, env var name) instead; the summary becomes the next agent's prompt.

Don't duplicate artifacts; reference them. When work has been committed, pushed, or written to a durable artifact, cite the artifact (commit hash, PR URL, file path) and state whether the user request is still open or resolved; the artifact alone does not establish completion. Do not re-prose the diff or the file body; the next agent runs `git show <hash>` or opens the file when they need detail. Re-prosing completed work scatters the completion signal across the summary, and the post-compact agent treats already-resolved requests as still pending and re-launches them. For external references (PRDs, ADRs, third-party issues), cite plus one inline line on the working fact (decision, status, conclusion).

Preserve in priority order:

1. Architecture decisions and design trade-offs: keep the decision, the rationale, and alternatives rejected. These outlast any single task.
2. Resolved user requests: cite the resolving artifact per the rule above, one line each. The artifact carries the detail.
3. In-flight work: uncommitted edits, ongoing investigation. Quote file paths and the substantive nature of pending changes so the next agent can pick up without re-deriving. Report each step's state from the latest result in the input: a check, write, commit, or background run that already finished carries its result instead of being listed as pending, and later completion or failure evidence supersedes earlier `running` reports. For background work needed by the current request, retain its exact recovery handle; if its result is still uncollected, include a next step to inspect that run or its saved output before sleeping or launching a replacement.
4. Known dead-ends: approaches tried this session that did not work, with one line on why each failed, so the next agent does not re-try. Include environment limits discovered this session, such as a missing command or a blocked command form, with the working alternative.
5. Last observed working directory, active git branch, and environment variables in play (HTTP_PROXY, NODE_ENV, PYTHONPATH, model or effort overrides), labeled as a snapshot rather than verified current state. Include a continuation prerequisite to verify the working directory and branch against the current request before the first repository mutation after compaction or resume, for example with `git branch --show-current`.
6. Tool outputs: keep the pass/fail verdict; raw output may be discarded.

Keep the verified/unverified boundary: a claim that was never checked this session carries an explicit `unverified` marker into the summary, so it cannot harden into fact after the handoff.

Tie-breaker: when two items at the same priority compete for space, prefer the one tied to the user's most recent instruction. Topically distant items at higher priority still win.

</compaction-instructions>
EOF
exit 0

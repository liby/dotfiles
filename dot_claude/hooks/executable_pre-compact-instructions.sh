#!/usr/bin/env bash
# PreCompact hook.
# Injects compaction priorities as additional instructions to the summarizer.

cat <<'EOF'
<compaction-instructions>

Goal: summarize so a fresh agent can continue the current work without re-deriving context. The post-compact session inherits only this summary.

Identifier preservation: copy identifiers character for character (UUIDs, commit hashes, IPs, ports, URLs, file paths, branch names, PR numbers). A single altered character breaks downstream tool calls silently.

Don't duplicate artifacts; reference them. When work has been committed, pushed, or written to a durable artifact, cite the artifact (commit hash, PR URL, file path) and name which user request it resolved. Do not re-prose the diff or the file body; the next agent runs `git show <hash>` or opens the file when they need detail. Re-prosing committed work scatters the completion signal across the summary, and the post-compact agent treats already-resolved requests as still pending and re-launches them. For external references (PRDs, ADRs, third-party issues), cite plus one inline line on the working fact (decision, status, conclusion).

Preserve in priority order:

1. Architecture decisions and design trade-offs: keep the decision, the rationale, and alternatives rejected. These outlast any single task.
2. Resolved user requests: cite the resolving artifact per the rule above, one line each. The artifact carries the detail.
3. In-flight work: uncommitted edits, ongoing investigation. Quote file paths and the substantive nature of pending changes so the next agent can pick up without re-deriving.
4. Known dead-ends: approaches tried this session that did not work, with one line on why each failed, so the next agent does not re-try.
5. Current working directory, active git branch, and environment variables in play (HTTP_PROXY, NODE_ENV, PYTHONPATH, model or effort overrides). Without these the next tool call may run in the wrong place or with the wrong config.
6. Tool outputs: keep the pass/fail verdict; raw output may be discarded.

Tie-breaker: when two items at the same priority compete for space, prefer the one tied to the user's most recent instruction. Topically distant items at higher priority still win.

</compaction-instructions>
EOF
exit 0

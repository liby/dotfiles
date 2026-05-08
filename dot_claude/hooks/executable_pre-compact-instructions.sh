#!/usr/bin/env bash
# PreCompact hook.
# Injects compaction priorities as additional instructions to the summarizer.

cat <<'EOF'
<compaction-instructions>

<goal>
Produce a summary that lets a fresh agent continue the current work without re-deriving context. The post-compact session inherits only this summary; anything you drop is forgotten until the user re-supplies it.
</goal>

<identifier-preservation>
Copy identifiers character for character: UUIDs, commit hashes, IPs, ports, URLs, file paths, branch names, PR numbers. A single altered character breaks downstream tool calls silently, with no error.
</identifier-preservation>

<preserve-in-priority-order>
1. Architecture decisions and design trade-offs: keep the decision, the rationale, and alternatives rejected.
2. Modified files and the substantive nature of each change; quote file paths.
3. Current task goal and verification status (pass or fail).
4. Open TODOs, known dead-ends, and unresolved side threads (paused threads typically resume).
5. Current working directory, active git branch, and any environment variables set or referenced this session (for example HTTP_PROXY, NODE_ENV, PYTHONPATH, model or effort overrides). Without these the next tool call may run in the wrong place or with the wrong config.
6. Tool outputs: keep the pass/fail verdict; raw output may be discarded.
</preserve-in-priority-order>

<weighting-when-trimming>
When two items at the same priority compete for space, prefer the one related to the user's most recent instruction. The most recent instruction is a tie-breaker, not an exclusive filter; topically distant items at higher priority still win.
</weighting-when-trimming>

<external-artifacts>
Cite external artifacts (PRDs, plans, ADRs, issues, commits, diffs) by path or URL and keep the working fact (decision, status, conclusion) inline. Locators alone are insufficient because the post-compact session may be unable to refetch the artifact. Architecture decisions and trade-offs stay fully inline regardless of whether an ADR documents them.
</external-artifacts>

</compaction-instructions>
EOF
exit 0

#!/usr/bin/env bash
# PreCompact hook.
# Injects compaction priorities as additional instructions to the summarizer.

cat <<'EOF'
Preserve in priority order:
1. Architecture decisions and design trade-offs (NEVER summarize away)
2. Modified files and their key changes
3. Current task goal and verification status (pass/fail)
4. Open TODOs and known dead-ends
5. Tool outputs (can discard, keep pass/fail verdict only)

CRITICAL: Never alter identifiers — UUIDs, commit hashes, IPs, ports, URLs, file paths, branch names, and PR numbers must be preserved verbatim. A single changed character breaks downstream tool calls.
EOF
exit 0

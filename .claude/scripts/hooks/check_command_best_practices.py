#!/usr/bin/env python3
import json
import re
import signal
import sys

# Define validation rules as a list of (regex pattern, message) tuples
VALIDATION_RULES = [
    (
        r"\b(grep|rg)\b.*\.json\b",
        "Use 'jq [options] <jq filter> [file...]' instead of 'grep | rg' for JSON files"
    ),
    (
        r"\bgrep\b(?!.*\|)",
        """Use `ast-grep --lang <language> -p '<pattern>'` instead of 'grep' for syntax-aware or structural code searching:
<ul>
  <li>Documentation: https://ast-grep.github.io/llms.txt</li>
  <li>Example: `ast-grep --lang tsx -p 'useEffect($$$)'` finds all useEffect hooks</li>
  <li>Example: `ast-grep --lang ts -p 'async function $FUNC($$$) { $$$ }'` finds all async functions</li>
  </li>
</ul>

Use `rg` (ripgrep) ONLY for:
<ul>
  <li>Non-code files: configs, docs, logs, data files</li>
  <li>Non-code text patterns (e.g., searching for URLs, IPs)</li>
  <li>String patterns that don't require syntax awareness</li>
  <li>Languages not yet supported by ast-grep</li>
</ul>"""
    ),
    (
        r"\bfind\s+\S+\s+-name\b",
        "Use 'fd [OPTIONS] [pattern] [path]...' for finding files instead of 'find -name' for better performance"
    ),
]

def validate_command(command: str) -> list[str]:
    issues = []
    for pattern, message in VALIDATION_RULES:
        if re.search(pattern, command):
            issues.append(message)
    return issues


try:
    input_data = json.load(sys.stdin)
except json.JSONDecodeError as e:
    print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
    sys.exit(1)

tool_name = input_data.get("tool_name", "")
tool_input = input_data.get("tool_input", {})
command = tool_input.get("command", "")

if tool_name != "Bash" or not command:
    sys.exit(1)

# Validate the command
issues = validate_command(command)

if issues:
    for message in issues:
        print(f"• {message}", file=sys.stderr)
    # Exit code 2 blocks tool call and shows stderr to Claude
    sys.exit(2)
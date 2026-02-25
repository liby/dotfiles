#!/usr/bin/env python3
"""Improve a skill description based on eval failures using claude CLI.

Reads trigger eval results (from eval_description.py), identifies failure
patterns, and asks Claude to generate an improved description that fixes
the failures without overfitting.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    import yaml  # type: ignore
except Exception:
    yaml = None


def load_eval_results(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_skill_content(skill_path: Path) -> str:
    skill_md = skill_path / "SKILL.md"
    if not skill_md.exists():
        raise FileNotFoundError(f"Missing SKILL.md in {skill_path}")
    return skill_md.read_text(encoding="utf-8")


def extract_failures(results: dict[str, Any]) -> tuple[list[dict], list[dict]]:
    """Split failures into under-triggers and over-triggers."""
    under_triggers: list[dict] = []
    over_triggers: list[dict] = []
    for r in results.get("results", []):
        if r.get("pass"):
            continue
        if r["should_trigger"]:
            under_triggers.append(r)
        else:
            over_triggers.append(r)
    return under_triggers, over_triggers


def build_improvement_prompt(
    current_description: str,
    under_triggers: list[dict],
    over_triggers: list[dict],
    skill_content: str,
    history: list[dict] | None,
) -> str:
    parts = [
        "You are optimizing a Claude Code skill description for trigger accuracy.",
        "The description determines when Claude automatically loads this skill.",
        "",
        "## Current Description",
        f"```\n{current_description}\n```",
        "",
    ]

    if under_triggers:
        parts.append("## Under-Triggering Failures (skill should trigger but didn't)")
        for f in under_triggers:
            parts.append(f"- Query: \"{f['query']}\" (trigger_rate: {f['trigger_rate']})")
        parts.append("")

    if over_triggers:
        parts.append("## Over-Triggering Failures (skill triggered but shouldn't)")
        for f in over_triggers:
            parts.append(f"- Query: \"{f['query']}\" (trigger_rate: {f['trigger_rate']})")
        parts.append("")

    if history:
        parts.append("## Previous Attempts (do NOT repeat these approaches)")
        for h in history[-3:]:  # only last 3 to save context
            parts.append(f"- Round {h.get('round', '?')}: \"{h.get('description', '')[:200]}...\"")
            parts.append(f"  Result: {h.get('pass_rate', 'unknown')}")
        parts.append("")

    parts.extend([
        "## Skill Content (for context only)",
        f"```markdown\n{skill_content[:3000]}\n```",
        "",
        "## Rules",
        "1. Output ONLY the new description text, nothing else.",
        "2. Stay under 1024 characters.",
        "3. Use 100-200 words. Be specific about capabilities and trigger contexts.",
        "4. Include natural trigger phrases users would actually type.",
        "5. Include boundary language to prevent over-triggering.",
        "6. Do NOT list specific eval queries verbatim (that's overfitting).",
        "7. Generalize from failure patterns: what intent is being missed or falsely matched?",
        "8. Always include 'Use when' or 'Use whenever' phrasing.",
        "9. No angle brackets (< or >).",
        "",
        "Write the improved description now:",
    ])
    return "\n".join(parts)


def call_claude(prompt: str, model: str | None = None) -> str:
    cmd = ["claude", "-p", prompt, "--output-format", "text"]
    if model:
        cmd.extend(["--model", model])

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
        )
    except FileNotFoundError as exc:
        raise RuntimeError("`claude` CLI not found on PATH") from exc
    except subprocess.TimeoutExpired:
        raise RuntimeError("claude CLI timed out after 120 seconds")

    if result.returncode != 0:
        raise RuntimeError(f"claude CLI failed: {result.stderr.strip()}")

    return result.stdout.strip()


def load_history(path: Path) -> list[dict]:
    if not path.exists():
        return []
    return json.loads(path.read_text(encoding="utf-8"))


def save_history(path: Path, history: list[dict]) -> None:
    path.write_text(
        json.dumps(history, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def improve_description(
    eval_results_path: Path,
    skill_path: Path,
    history_path: Path | None,
    model: str | None,
) -> dict[str, Any]:
    results = load_eval_results(eval_results_path)
    skill_content = load_skill_content(skill_path)
    current_description = results.get("description", "")
    under_triggers, over_triggers = extract_failures(results)

    if not under_triggers and not over_triggers:
        return {
            "status": "no_failures",
            "message": "All eval cases passed. No improvement needed.",
            "current_description": current_description,
        }

    history = load_history(history_path) if history_path else []
    prompt = build_improvement_prompt(
        current_description, under_triggers, over_triggers, skill_content, history,
    )
    new_description = call_claude(prompt, model)

    # Validate length
    if len(new_description) > 1024:
        trim_prompt = (
            f"The following skill description is {len(new_description)} characters. "
            f"Shorten it to under 1024 characters while preserving trigger accuracy. "
            f"Output ONLY the shortened description:\n\n{new_description}"
        )
        new_description = call_claude(trim_prompt, model)

    # Strip any wrapping quotes or code fences
    new_description = new_description.strip("`\"'")
    if new_description.startswith("description:"):
        new_description = new_description[len("description:"):].strip()

    summary = results.get("summary", {})
    round_entry = {
        "round": len(history) + 1,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "description": new_description,
        "pass_rate": f"{summary.get('passed', 0)}/{summary.get('total', 0)}",
        "under_triggers": len(under_triggers),
        "over_triggers": len(over_triggers),
    }

    if history_path:
        history.append(round_entry)
        save_history(history_path, history)

    return {
        "status": "improved",
        "previous_description": current_description,
        "new_description": new_description,
        "improvements": {
            "under_triggers_addressed": len(under_triggers),
            "over_triggers_addressed": len(over_triggers),
        },
        "round": round_entry["round"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Improve skill description based on eval failures"
    )
    parser.add_argument(
        "--eval-results",
        required=True,
        help="Path to eval results JSON (from eval_description.py)",
    )
    parser.add_argument(
        "--skill-path",
        required=True,
        help="Path to skill directory containing SKILL.md",
    )
    parser.add_argument(
        "--history",
        default=None,
        help="Path to history JSON for tracking iterations",
    )
    parser.add_argument(
        "--model",
        default=None,
        help="Optional model for claude CLI",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write improved description back to SKILL.md",
    )
    parser.add_argument(
        "--json-out",
        default=None,
        help="Save result to JSON file",
    )
    args = parser.parse_args()

    try:
        result = improve_description(
            eval_results_path=Path(args.eval_results).expanduser().resolve(),
            skill_path=Path(args.skill_path).expanduser().resolve(),
            history_path=Path(args.history).expanduser().resolve() if args.history else None,
            model=args.model,
        )
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    output = json.dumps(result, indent=2, ensure_ascii=False)
    print(output)

    if args.json_out:
        Path(args.json_out).expanduser().resolve().write_text(
            output + "\n", encoding="utf-8"
        )

    if args.apply and result.get("status") == "improved":
        skill_md = Path(args.skill_path).expanduser().resolve() / "SKILL.md"
        content = skill_md.read_text(encoding="utf-8")
        old_desc = result["previous_description"]
        new_desc = result["new_description"]
        if old_desc in content:
            content = content.replace(old_desc, new_desc, 1)
            skill_md.write_text(content, encoding="utf-8")
            print(f"\nApplied new description to {skill_md}", file=sys.stderr)
        else:
            print(
                "\nWarning: could not locate previous description in SKILL.md for replacement.",
                file=sys.stderr,
            )

    return 0


if __name__ == "__main__":
    sys.exit(main())

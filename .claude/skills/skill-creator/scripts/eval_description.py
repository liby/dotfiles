#!/usr/bin/env python3
"""Evaluate skill trigger quality by replaying queries with `claude -p`.

Input eval set formats:
1) Array of objects:
   [{"query": "...", "should_trigger": true}, ...]
2) Object with `evals`:
   {"evals": [{"prompt": "...", "should_trigger": true}, ...]}
"""

from __future__ import annotations

import argparse
import concurrent.futures
import contextlib
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path
from typing import Any

if platform.system() != "Windows":
    import select
else:
    select = None  # type: ignore[assignment]

try:
    import yaml  # type: ignore
except Exception:
    yaml = None


def _split_frontmatter(content: str) -> tuple[str, str]:
    lines = content.splitlines()
    if not lines or lines[0].strip() != "---":
        raise ValueError("SKILL.md must start with frontmatter")
    closing = None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            closing = idx
            break
    if closing is None:
        raise ValueError("SKILL.md frontmatter closing delimiter not found")
    return "\n".join(lines[1:closing]), "\n".join(lines[closing + 1 :])


def _parse_frontmatter(frontmatter: str) -> dict[str, Any]:
    if yaml is not None:
        parsed = yaml.safe_load(frontmatter)
        if isinstance(parsed, dict):
            return parsed
    data: dict[str, Any] = {}
    for line in frontmatter.splitlines():
        if not line.strip() or line.startswith((" ", "\t", "-")):
            continue
        match = re.match(r"^([A-Za-z0-9_-]+)\s*:\s*(.*)$", line)
        if match:
            data[match.group(1)] = match.group(2).strip().strip('"').strip("'")
    return data


def load_skill_metadata(skill_path: Path) -> tuple[str, str]:
    skill_md = skill_path / "SKILL.md"
    if not skill_md.exists():
        raise FileNotFoundError(f"Missing SKILL.md in {skill_path}")
    content = skill_md.read_text(encoding="utf-8", errors="replace")
    frontmatter, _ = _split_frontmatter(content)
    data = _parse_frontmatter(frontmatter)
    name = str(data.get("name") or skill_path.name).strip()
    description = str(data.get("description") or "").strip()
    if not description:
        raise ValueError("Skill frontmatter must contain description for trigger evaluation")
    return name, description


def infer_project_root(skill_path: Path, explicit: str | None) -> Path:
    if explicit:
        return Path(explicit).expanduser().resolve()
    cwd = Path.cwd().resolve()
    for candidate in [cwd, *cwd.parents]:
        if (candidate / ".claude").is_dir():
            return candidate
    fallback = skill_path.parent.parent
    if (fallback / ".claude").is_dir():
        return fallback
    return cwd


def load_eval_set(path: Path) -> list[dict[str, Any]]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(raw, list):
        source = raw
    elif isinstance(raw, dict) and isinstance(raw.get("evals"), list):
        source = raw["evals"]
    else:
        raise ValueError("Eval set must be a JSON array or an object with an `evals` array")

    normalized: list[dict[str, Any]] = []
    for idx, item in enumerate(source):
        if not isinstance(item, dict):
            raise ValueError(f"Eval item #{idx} is not an object")
        query = item.get("query", item.get("prompt"))
        if not isinstance(query, str) or not query.strip():
            raise ValueError(f"Eval item #{idx} is missing non-empty query/prompt")
        should_trigger = item.get("should_trigger")
        if not isinstance(should_trigger, bool):
            raise ValueError(f"Eval item #{idx} is missing boolean should_trigger")
        normalized.append({"query": query.strip(), "should_trigger": should_trigger})
    return normalized


@contextlib.contextmanager
def temp_command_context(
    command_name: str,
    skill_name: str,
    description: str,
):
    """Context manager that creates a temp command file and cleans up on exit.

    Uses a temporary directory to avoid polluting the user's .claude/commands/.
    The temp dir contains a .claude/commands/ structure so it can be passed
    via --add-dir to claude CLI.
    """
    tmp_root = Path(tempfile.mkdtemp(prefix="skill-eval-"))
    commands_dir = tmp_root / ".claude" / "commands"
    commands_dir.mkdir(parents=True, exist_ok=True)
    command_file = commands_dir / f"{command_name}.md"
    indented_desc = "\n  ".join(description.splitlines())
    command_file.write_text(
        "\n".join(
            [
                "---",
                f"name: {command_name}",
                "description: |",
                f"  {indented_desc}",
                "---",
                "",
                f"# Trigger Eval Harness for {skill_name}",
                "",
                "This file is generated temporarily for trigger evaluation.",
                "",
            ]
        ),
        encoding="utf-8",
    )
    try:
        yield tmp_root, command_file
    finally:
        shutil.rmtree(tmp_root, ignore_errors=True)


def _read_stdout_chunk(process: subprocess.Popen, timeout_sec: float) -> bytes:
    """Read a chunk from process stdout, using select on Unix or polling on Windows."""
    if not process.stdout:
        return b""
    if select is not None:
        ready, _, _ = select.select([process.stdout], [], [], timeout_sec)
        if not ready:
            return b""
    else:
        # Windows fallback: brief poll-based read
        time.sleep(min(timeout_sec, 0.2))
    return os.read(process.stdout.fileno(), 8192)


def run_single_query(
    query: str,
    skill_name: str,
    description: str,
    project_root: Path,
    timeout: int,
    model: str | None,
) -> bool:
    unique = uuid.uuid4().hex[:10]
    safe_skill = re.sub(r"[^a-zA-Z0-9-]+", "-", skill_name).strip("-") or "skill"
    command_name = f"{safe_skill}-trigger-eval-{unique}".lower()

    with temp_command_context(command_name, skill_name, description) as (tmp_root, _command_file):
        cmd = [
            "claude",
            "-p",
            query,
            "--output-format",
            "stream-json",
            "--include-partial-messages",
            "--verbose",
            "--add-dir",
            str(tmp_root),
        ]
        if model:
            cmd.extend(["--model", model])

        env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
        process = None
        triggered = False
        active_tool = None
        tool_json = ""

        try:
            process = subprocess.Popen(
                cmd,
                cwd=project_root,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                env=env,
            )
        except FileNotFoundError as exc:
            raise RuntimeError("`claude` CLI not found on PATH") from exc

        start = time.monotonic()
        buffer = ""

        try:
            while time.monotonic() - start < timeout:
                if process.poll() is not None:
                    tail = process.stdout.read() if process.stdout else b""
                    if tail:
                        buffer += tail.decode("utf-8", errors="replace")
                    break

                if not process.stdout:
                    break
                chunk = _read_stdout_chunk(process, 1.0)
                if not chunk:
                    continue
                buffer += chunk.decode("utf-8", errors="replace")

                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()
                    if not line:
                        continue

                    try:
                        event = json.loads(line)
                    except json.JSONDecodeError:
                        continue

                    etype = event.get("type")
                    if etype == "stream_event":
                        stream_event = event.get("event", {})
                        se_type = stream_event.get("type")
                        if se_type == "content_block_start":
                            block = stream_event.get("content_block", {})
                            if block.get("type") == "tool_use":
                                active_tool = block.get("name")
                                tool_json = ""
                        # These tool names are Claude Code internals, not part of the
                        # Agent Skills spec. Update if Claude Code renames them.
                        elif se_type == "content_block_delta" and active_tool in {"Skill", "Read"}:
                            delta = stream_event.get("delta", {})
                            if delta.get("type") == "input_json_delta":
                                tool_json += delta.get("partial_json", "")
                                if command_name in tool_json:
                                    triggered = True
                        elif se_type == "content_block_stop":
                            active_tool = None
                            tool_json = ""
                    elif etype == "assistant":
                        message = event.get("message", {})
                        for content in message.get("content", []):
                            if content.get("type") != "tool_use":
                                continue
                            tool_name = content.get("name")
                            # Claude Code internals — see comment above.
                            if tool_name not in {"Skill", "Read"}:
                                continue
                            tool_input = json.dumps(content.get("input", {}), ensure_ascii=False)
                            if command_name in tool_input:
                                triggered = True
                    elif etype == "result":
                        break

            return triggered
        finally:
            if process and process.poll() is None:
                process.kill()
                process.wait()


def evaluate(
    eval_set: list[dict[str, Any]],
    skill_name: str,
    description: str,
    project_root: Path,
    runs_per_query: int,
    threshold: float,
    workers: int,
    timeout: int,
    model: str | None,
) -> dict[str, Any]:
    results_map: dict[str, dict[str, Any]] = {}
    order: list[str] = []

    for item in eval_set:
        query = item["query"]
        if query not in results_map:
            results_map[query] = {
                "query": query,
                "should_trigger": item["should_trigger"],
                "runs": 0,
                "triggers": 0,
                "errors": 0,
            }
            order.append(query)

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
        futures = []
        for item in eval_set:
            for _ in range(runs_per_query):
                futures.append(
                    executor.submit(
                        run_single_query,
                        query=item["query"],
                        skill_name=skill_name,
                        description=description,
                        project_root=project_root,
                        timeout=timeout,
                        model=model,
                    )
                )

        idx = 0
        for item in eval_set:
            record = results_map[item["query"]]
            for _ in range(runs_per_query):
                future = futures[idx]
                idx += 1
                record["runs"] += 1
                try:
                    if future.result():
                        record["triggers"] += 1
                except Exception:
                    record["errors"] += 1

    results: list[dict[str, Any]] = []
    for query in order:
        record = results_map[query]
        trigger_rate = (record["triggers"] / record["runs"]) if record["runs"] else 0.0
        should_trigger = record["should_trigger"]
        passed = trigger_rate >= threshold if should_trigger else trigger_rate < threshold
        results.append(
            {
                "query": query,
                "should_trigger": should_trigger,
                "triggers": record["triggers"],
                "runs": record["runs"],
                "errors": record["errors"],
                "trigger_rate": round(trigger_rate, 4),
                "pass": passed,
            }
        )

    passed = sum(1 for result in results if result["pass"])
    total = len(results)

    return {
        "skill_name": skill_name,
        "description": description,
        "summary": {
            "passed": passed,
            "failed": total - passed,
            "total": total,
            "threshold": threshold,
        },
        "results": results,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate trigger quality for a skill description")
    parser.add_argument("--skill-path", required=True, help="Path to skill directory containing SKILL.md")
    parser.add_argument("--eval-set", required=True, help="Path to eval JSON")
    parser.add_argument("--project-root", default=None, help="Project root containing .claude/")
    parser.add_argument("--runs-per-query", type=int, default=3, help="Number of runs per query")
    parser.add_argument("--threshold", type=float, default=0.5, help="Trigger-rate threshold")
    parser.add_argument("--workers", type=int, default=6, help="Parallel workers")
    parser.add_argument("--timeout", type=int, default=45, help="Timeout per run (seconds)")
    parser.add_argument("--model", default=None, help="Optional model for `claude -p`")
    parser.add_argument("--json-out", default=None, help="Optional path to save JSON output")
    args = parser.parse_args()

    if shutil.which("claude") is None:
        print("Error: `claude` CLI is not available on PATH.", file=sys.stderr)
        return 2

    skill_path = Path(args.skill_path).expanduser().resolve()
    eval_path = Path(args.eval_set).expanduser().resolve()
    if not eval_path.exists():
        print(f"Error: eval set not found: {eval_path}", file=sys.stderr)
        return 2

    try:
        skill_name, description = load_skill_metadata(skill_path)
        eval_set = load_eval_set(eval_path)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2

    project_root = infer_project_root(skill_path, args.project_root)
    if not (project_root / ".claude").is_dir():
        print(
            f"Error: could not find .claude/ under project root: {project_root}",
            file=sys.stderr,
        )
        return 2

    report = evaluate(
        eval_set=eval_set,
        skill_name=skill_name,
        description=description,
        project_root=project_root,
        runs_per_query=args.runs_per_query,
        threshold=args.threshold,
        workers=args.workers,
        timeout=args.timeout,
        model=args.model,
    )

    output = json.dumps(report, indent=2, ensure_ascii=False)
    print(output)
    if args.json_out:
        out_path = Path(args.json_out).expanduser().resolve()
        out_path.write_text(output + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())


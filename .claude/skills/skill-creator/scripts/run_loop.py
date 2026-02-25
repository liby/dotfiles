#!/usr/bin/env python3
"""Run eval → improve → re-eval loop until target pass rate or max iterations.

Orchestrates eval_description.py and improve_description.py in a cycle,
tracking each iteration's description and score. Optionally splits eval set
into train/test to detect overfitting.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from eval_description import evaluate, load_eval_set, load_skill_metadata  # noqa: E402
from improve_description import improve_description  # noqa: E402

try:
    import yaml  # type: ignore
except Exception:
    yaml = None


def split_eval_set(
    eval_set: list[dict[str, Any]],
    holdout: float,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Split eval set into train/test with stratification by should_trigger."""
    positives = [e for e in eval_set if e["should_trigger"]]
    negatives = [e for e in eval_set if not e["should_trigger"]]

    def split_list(items: list) -> tuple[list, list]:
        n_test = max(1, int(len(items) * holdout)) if len(items) > 1 else 0
        return items[n_test:], items[:n_test]

    train_pos, test_pos = split_list(positives)
    train_neg, test_neg = split_list(negatives)
    return train_pos + train_neg, test_pos + test_neg


def compute_pass_rate(report: dict[str, Any]) -> float:
    summary = report.get("summary", {})
    total = summary.get("total", 0)
    if total == 0:
        return 0.0
    return summary.get("passed", 0) / total


def update_skill_description(skill_path: Path, old_desc: str, new_desc: str) -> bool:
    """Replace description in SKILL.md frontmatter."""
    skill_md = skill_path / "SKILL.md"
    content = skill_md.read_text(encoding="utf-8")
    if old_desc in content:
        content = content.replace(old_desc, new_desc, 1)
        skill_md.write_text(content, encoding="utf-8")
        return True
    return False


def run_loop(
    skill_path: Path,
    eval_set_path: Path,
    project_root: Path,
    max_iterations: int,
    target_pass_rate: float,
    runs_per_query: int,
    threshold: float,
    workers: int,
    timeout: int,
    holdout: float,
    model: str | None,
    history_path: Path | None,
    output_dir: Path | None,
) -> dict[str, Any]:
    eval_set = load_eval_set(eval_set_path)
    skill_name, description = load_skill_metadata(skill_path)

    if holdout > 0 and len(eval_set) >= 4:
        train_set, test_set = split_eval_set(eval_set, holdout)
    else:
        train_set, test_set = eval_set, []

    iterations: list[dict[str, Any]] = []
    best_iteration: dict[str, Any] | None = None
    best_test_rate = -1.0
    original_description = description

    for i in range(max_iterations):
        round_num = i + 1
        print(f"\n{'='*60}", file=sys.stderr)
        print(f"  Iteration {round_num}/{max_iterations}", file=sys.stderr)
        print(f"  Description: {description[:80]}...", file=sys.stderr)
        print(f"{'='*60}", file=sys.stderr)

        # Evaluate on full set (train + test)
        full_report = evaluate(
            eval_set=eval_set,
            skill_name=skill_name,
            description=description,
            project_root=project_root,
            runs_per_query=runs_per_query,
            threshold=threshold,
            workers=workers,
            timeout=timeout,
            model=model,
        )
        full_pass_rate = compute_pass_rate(full_report)

        # Separate train/test results if we have a holdout
        train_queries = {e["query"] for e in train_set}
        train_results = [r for r in full_report["results"] if r["query"] in train_queries]
        test_results = [r for r in full_report["results"] if r["query"] not in train_queries]
        train_passed = sum(1 for r in train_results if r["pass"])
        test_passed = sum(1 for r in test_results if r["pass"])
        train_rate = train_passed / len(train_results) if train_results else 0.0
        test_rate = test_passed / len(test_results) if test_results else full_pass_rate

        iteration_data = {
            "round": round_num,
            "description": description,
            "full_pass_rate": round(full_pass_rate, 4),
            "train_pass_rate": round(train_rate, 4),
            "test_pass_rate": round(test_rate, 4),
            "train_passed": train_passed,
            "train_total": len(train_results),
            "test_passed": test_passed,
            "test_total": len(test_results),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        iterations.append(iteration_data)

        print(f"  Full: {full_pass_rate:.1%} | Train: {train_rate:.1%} | Test: {test_rate:.1%}", file=sys.stderr)

        # Track best by test score (or full if no holdout)
        score = test_rate if test_set else full_pass_rate
        if score > best_test_rate:
            best_test_rate = score
            best_iteration = iteration_data

        # Check if target reached
        if full_pass_rate >= target_pass_rate:
            print(f"\n  Target pass rate {target_pass_rate:.0%} reached!", file=sys.stderr)
            break

        # Check if all train passed (no improvement possible from train failures)
        if train_rate >= 1.0 and round_num < max_iterations:
            print(f"\n  All train cases pass. Stopping.", file=sys.stderr)
            break

        # Save eval results for improve_description to read
        eval_results_file = (output_dir or Path(".")) / f"eval_round_{round_num}.json"
        # Build a report scoped to train set for improvement
        train_report = {
            "skill_name": skill_name,
            "description": description,
            "summary": {
                "passed": train_passed,
                "failed": len(train_results) - train_passed,
                "total": len(train_results),
                "threshold": threshold,
            },
            "results": train_results,
        }
        eval_results_file.write_text(
            json.dumps(train_report, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

        if round_num >= max_iterations:
            break

        # Improve description
        print(f"  Improving description...", file=sys.stderr)
        try:
            improve_result = improve_description(
                eval_results_path=eval_results_file,
                skill_path=skill_path,
                history_path=history_path,
                model=model,
            )
        except Exception as exc:
            print(f"  Improvement failed: {exc}", file=sys.stderr)
            break

        if improve_result.get("status") != "improved":
            print(f"  No improvement generated: {improve_result.get('message', '')}", file=sys.stderr)
            break

        new_description = improve_result["new_description"]
        if new_description == description:
            print(f"  Description unchanged. Stopping.", file=sys.stderr)
            break

        # Update SKILL.md
        if not update_skill_description(skill_path, description, new_description):
            print(f"  Warning: could not update SKILL.md automatically.", file=sys.stderr)

        description = new_description

    result = {
        "skill_name": skill_name,
        "original_description": original_description,
        "iterations": iterations,
        "best_iteration": best_iteration,
        "final_description": description,
        "total_rounds": len(iterations),
    }

    if output_dir:
        output_dir.mkdir(parents=True, exist_ok=True)
        summary_file = output_dir / "loop_summary.json"
        summary_file.write_text(
            json.dumps(result, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        print(f"\n  Summary saved to {summary_file}", file=sys.stderr)

    return result


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run eval → improve → re-eval optimization loop"
    )
    parser.add_argument("--skill-path", required=True, help="Path to skill directory")
    parser.add_argument("--eval-set", required=True, help="Path to eval set JSON")
    parser.add_argument("--project-root", default=None, help="Project root with .claude/")
    parser.add_argument("--max-iterations", type=int, default=5, help="Maximum improvement rounds")
    parser.add_argument("--target-pass-rate", type=float, default=1.0, help="Stop when this rate is reached (0.0-1.0)")
    parser.add_argument("--runs-per-query", type=int, default=3, help="Runs per query per eval")
    parser.add_argument("--threshold", type=float, default=0.5, help="Trigger rate threshold")
    parser.add_argument("--workers", type=int, default=6, help="Parallel eval workers")
    parser.add_argument("--timeout", type=int, default=45, help="Timeout per eval run (seconds)")
    parser.add_argument("--holdout", type=float, default=0.4, help="Fraction of eval set to hold out as test (0 to disable)")
    parser.add_argument("--model", default=None, help="Model for claude CLI")
    parser.add_argument("--history", default=None, help="Path to history JSON")
    parser.add_argument("--output-dir", default=None, help="Directory for iteration artifacts")
    args = parser.parse_args()

    if shutil.which("claude") is None:
        print("Error: `claude` CLI not found on PATH.", file=sys.stderr)
        return 2

    skill_path = Path(args.skill_path).expanduser().resolve()
    eval_set_path = Path(args.eval_set).expanduser().resolve()

    # Infer project root
    project_root = Path(args.project_root).expanduser().resolve() if args.project_root else None
    if project_root is None:
        for candidate in [Path.cwd(), *Path.cwd().parents]:
            if (candidate / ".claude").is_dir():
                project_root = candidate
                break
        if project_root is None:
            project_root = skill_path.parent.parent

    output_dir = Path(args.output_dir).expanduser().resolve() if args.output_dir else None
    history_path = Path(args.history).expanduser().resolve() if args.history else None

    try:
        result = run_loop(
            skill_path=skill_path,
            eval_set_path=eval_set_path,
            project_root=project_root,
            max_iterations=args.max_iterations,
            target_pass_rate=args.target_pass_rate,
            runs_per_query=args.runs_per_query,
            threshold=args.threshold,
            workers=args.workers,
            timeout=args.timeout,
            holdout=args.holdout,
            model=args.model,
            history_path=history_path,
            output_dir=output_dir,
        )
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Generate an HTML report from eval or loop results.

Converts JSON output from eval_description.py or run_loop.py into a
browsable HTML report.
"""

from __future__ import annotations

import argparse
import json
import sys
import webbrowser
from pathlib import Path
from typing import Any


def _escape(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


def generate_eval_html(data: dict[str, Any]) -> str:
    """Generate HTML for a single eval report."""
    skill_name = _escape(str(data.get("skill_name", "Unknown")))
    description = _escape(str(data.get("description", "")))
    summary = data.get("summary", {})
    results = data.get("results", [])

    rows = []
    for r in results:
        status = "pass" if r.get("pass") else "fail"
        color = "#22c55e" if r.get("pass") else "#ef4444"
        icon = "&#10003;" if r.get("pass") else "&#10007;"
        query = _escape(r.get("query", ""))
        should = "yes" if r.get("should_trigger") else "no"
        rate = f"{r.get('trigger_rate', 0):.0%}"
        runs = r.get("runs", 0)
        triggers = r.get("triggers", 0)
        rows.append(
            f'<tr class="{status}">'
            f'<td style="color:{color};font-weight:bold;text-align:center">{icon}</td>'
            f"<td>{query}</td>"
            f"<td>{should}</td>"
            f"<td>{triggers}/{runs}</td>"
            f"<td>{rate}</td>"
            f"</tr>"
        )

    passed = summary.get("passed", 0)
    total = summary.get("total", 0)
    rate_pct = f"{passed/total:.0%}" if total else "N/A"

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Eval Report: {skill_name}</title>
<style>
  body {{ font-family: system-ui, -apple-system, sans-serif; margin: 0; background: #0f172a; color: #e2e8f0; }}
  .container {{ max-width: 960px; margin: 0 auto; padding: 24px; }}
  h1 {{ font-size: 24px; margin-bottom: 8px; }}
  .meta {{ color: #94a3b8; margin-bottom: 24px; font-size: 14px; }}
  .summary {{ display: flex; gap: 16px; margin-bottom: 24px; }}
  .card {{ background: #1e293b; border-radius: 8px; padding: 16px 20px; flex: 1; }}
  .card-label {{ font-size: 12px; color: #64748b; text-transform: uppercase; letter-spacing: 0.05em; }}
  .card-value {{ font-size: 28px; font-weight: bold; margin-top: 4px; }}
  .card-value.good {{ color: #22c55e; }}
  .card-value.warn {{ color: #f59e0b; }}
  .card-value.bad {{ color: #ef4444; }}
  .desc {{ background: #1e293b; border-radius: 8px; padding: 16px; margin-bottom: 24px; font-size: 14px; line-height: 1.6; white-space: pre-wrap; word-break: break-word; }}
  table {{ width: 100%; border-collapse: collapse; background: #1e293b; border-radius: 8px; overflow: hidden; }}
  th {{ background: #334155; text-align: left; padding: 10px 12px; font-size: 12px; text-transform: uppercase; letter-spacing: 0.05em; color: #94a3b8; }}
  td {{ padding: 10px 12px; border-top: 1px solid #334155; font-size: 14px; }}
  tr.fail td {{ background: rgba(239,68,68,0.05); }}
</style>
</head>
<body>
<div class="container">
  <h1>Trigger Eval Report</h1>
  <div class="meta">Skill: <strong>{skill_name}</strong> &middot; Threshold: {summary.get('threshold', 0.5)}</div>
  <div class="summary">
    <div class="card"><div class="card-label">Passed</div><div class="card-value good">{passed}</div></div>
    <div class="card"><div class="card-label">Failed</div><div class="card-value {"bad" if summary.get("failed",0) else "good"}">{summary.get('failed', 0)}</div></div>
    <div class="card"><div class="card-label">Total</div><div class="card-value">{total}</div></div>
    <div class="card"><div class="card-label">Pass Rate</div><div class="card-value {"good" if passed==total else "warn"}">{rate_pct}</div></div>
  </div>
  <h2 style="font-size:14px;color:#94a3b8;margin-bottom:8px">DESCRIPTION</h2>
  <div class="desc">{description}</div>
  <table>
    <thead><tr><th style="width:40px"></th><th>Query</th><th>Should Trigger</th><th>Triggers/Runs</th><th>Rate</th></tr></thead>
    <tbody>{"".join(rows)}</tbody>
  </table>
</div>
</body>
</html>"""


def generate_loop_html(data: dict[str, Any]) -> str:
    """Generate HTML for a run_loop summary."""
    skill_name = _escape(str(data.get("skill_name", "Unknown")))
    iterations = data.get("iterations", [])
    best = data.get("best_iteration", {})

    iter_rows = []
    for it in iterations:
        desc_preview = _escape(it.get("description", "")[:120])
        full_rate = f"{it.get('full_pass_rate', 0):.0%}"
        train_rate = f"{it.get('train_pass_rate', 0):.0%}"
        test_rate = f"{it.get('test_pass_rate', 0):.0%}"
        is_best = it.get("round") == best.get("round")
        highlight = ' style="background:rgba(34,197,94,0.1)"' if is_best else ""
        badge = ' <span style="color:#22c55e;font-size:11px">&#9733; BEST</span>' if is_best else ""
        iter_rows.append(
            f"<tr{highlight}>"
            f'<td style="text-align:center">{it["round"]}{badge}</td>'
            f"<td>{desc_preview}...</td>"
            f"<td>{full_rate}</td>"
            f"<td>{train_rate}</td>"
            f"<td>{test_rate}</td>"
            f"</tr>"
        )

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Optimization Loop: {skill_name}</title>
<style>
  body {{ font-family: system-ui, -apple-system, sans-serif; margin: 0; background: #0f172a; color: #e2e8f0; }}
  .container {{ max-width: 960px; margin: 0 auto; padding: 24px; }}
  h1 {{ font-size: 24px; margin-bottom: 8px; }}
  .meta {{ color: #94a3b8; margin-bottom: 24px; font-size: 14px; }}
  table {{ width: 100%; border-collapse: collapse; background: #1e293b; border-radius: 8px; overflow: hidden; }}
  th {{ background: #334155; text-align: left; padding: 10px 12px; font-size: 12px; text-transform: uppercase; letter-spacing: 0.05em; color: #94a3b8; }}
  td {{ padding: 10px 12px; border-top: 1px solid #334155; font-size: 14px; }}
  .best-desc {{ background: #1e293b; border-radius: 8px; padding: 16px; margin: 24px 0; font-size: 14px; line-height: 1.6; white-space: pre-wrap; word-break: break-word; border-left: 3px solid #22c55e; }}
</style>
</head>
<body>
<div class="container">
  <h1>Description Optimization Loop</h1>
  <div class="meta">Skill: <strong>{skill_name}</strong> &middot; {len(iterations)} iterations</div>
  <table>
    <thead><tr><th style="width:80px">Round</th><th>Description</th><th>Full</th><th>Train</th><th>Test</th></tr></thead>
    <tbody>{"".join(iter_rows)}</tbody>
  </table>
  <h2 style="font-size:14px;color:#94a3b8;margin:24px 0 8px">BEST DESCRIPTION (Round {best.get("round", "?")})</h2>
  <div class="best-desc">{_escape(str(best.get("description", data.get("final_description", ""))))}</div>
</div>
</body>
</html>"""


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate HTML report from eval/loop JSON")
    parser.add_argument("input", help="Path to JSON file (eval or loop output)")
    parser.add_argument("--output", default=None, help="Output HTML path (default: <input>.html)")
    parser.add_argument("--open", action="store_true", help="Open in browser after generating")
    args = parser.parse_args()

    input_path = Path(args.input).expanduser().resolve()
    if not input_path.exists():
        print(f"Error: input file not found: {input_path}", file=sys.stderr)
        return 1

    data = json.loads(input_path.read_text(encoding="utf-8"))

    # Detect format: loop output has "iterations", eval output has "results"
    if "iterations" in data:
        html = generate_loop_html(data)
    elif "results" in data:
        html = generate_eval_html(data)
    else:
        print("Error: unrecognized JSON format (expected eval or loop output)", file=sys.stderr)
        return 1

    output_path = Path(args.output) if args.output else input_path.with_suffix(".html")
    output_path.write_text(html, encoding="utf-8")
    print(f"Generated: {output_path}")

    if args.open:
        webbrowser.open(f"file://{output_path.resolve()}")

    return 0


if __name__ == "__main__":
    sys.exit(main())

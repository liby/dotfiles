#!/usr/bin/env python3
"""Validate Claude/Codex skill folders.

This validator is intentionally compatible with both:
1) conservative local rules (name+description required),
2) newer docs where some frontmatter fields are optional.

Default mode is practical and forward-compatible.
Use --strict to enforce stronger release rules.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

try:
    import yaml  # type: ignore
except Exception:
    yaml = None


# ---------------------------------------------------------------------------
# Schema loading — single source of truth is references/schema.yaml
# ---------------------------------------------------------------------------

# Hardcoded fallback values used when schema.yaml is unavailable.
_FALLBACK_ALLOWED_KEYS = {
    "name",
    "description",
    "argument-hint",
    "disable-model-invocation",
    "user-invocable",
    "allowed-tools",
    "model",
    "context",
    "agent",
    "hooks",
    "compatibility",
    "metadata",
    "license",
    "version",
}
_FALLBACK_CONSTRAINTS = {
    "max_name_length": 64,
    "max_description_length": 1024,
    "max_compatibility_length": 500,
    "max_skill_md_lines": 500,
    "reserved_prefixes": ["claude", "anthropic"],
}


def _load_schema() -> tuple[set[str], dict[str, int | list[str]]]:
    """Load field names and constraints from references/schema.yaml.

    Returns (allowed_keys, constraints). Falls back to hardcoded defaults
    if the schema file is missing or unparseable.
    """
    schema_path = Path(__file__).resolve().parent.parent / "references" / "schema.yaml"
    if not schema_path.exists() or yaml is None:
        return _FALLBACK_ALLOWED_KEYS, _FALLBACK_CONSTRAINTS

    try:
        data = yaml.safe_load(schema_path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            return _FALLBACK_ALLOWED_KEYS, _FALLBACK_CONSTRAINTS

        fields = data.get("fields")
        if isinstance(fields, dict):
            allowed = set(fields.keys())
        else:
            allowed = _FALLBACK_ALLOWED_KEYS

        raw_constraints = data.get("constraints")
        if isinstance(raw_constraints, dict):
            constraints = {**_FALLBACK_CONSTRAINTS, **raw_constraints}
        else:
            constraints = _FALLBACK_CONSTRAINTS

        return allowed, constraints
    except Exception:
        return _FALLBACK_ALLOWED_KEYS, _FALLBACK_CONSTRAINTS


_ALLOWED_KEYS, _CONSTRAINTS = _load_schema()

MAX_NAME_LEN: int = _CONSTRAINTS["max_name_length"]  # type: ignore[assignment]
MAX_DESCRIPTION_LEN: int = _CONSTRAINTS["max_description_length"]  # type: ignore[assignment]
MAX_COMPATIBILITY_LEN: int = _CONSTRAINTS["max_compatibility_length"]  # type: ignore[assignment]
RECOMMENDED_MAX_LINES: int = _CONSTRAINTS["max_skill_md_lines"]  # type: ignore[assignment]
ALLOWED_KEYS: set[str] = _ALLOWED_KEYS
RECOMMENDED_KEYS = {"name", "description"}
RESERVED_PREFIXES: tuple[str, ...] = tuple(_CONSTRAINTS.get("reserved_prefixes", ["claude", "anthropic"]))  # type: ignore[arg-type]


@dataclass
class Finding:
    level: str
    code: str
    message: str


def _split_frontmatter(content: str) -> tuple[str, str]:
    lines = content.splitlines()
    if not lines or lines[0].strip() != "---":
        raise ValueError("SKILL.md must begin with YAML frontmatter delimited by ---")

    closing = None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            closing = idx
            break
    if closing is None:
        raise ValueError("Missing closing --- delimiter for frontmatter")

    frontmatter = "\n".join(lines[1:closing])
    body = "\n".join(lines[closing + 1 :])
    return frontmatter, body


def _coerce_scalar(value: str) -> Any:
    text = value.strip()
    if text == "":
        return None
    if (text.startswith('"') and text.endswith('"')) or (text.startswith("'") and text.endswith("'")):
        return text[1:-1]
    low = text.lower()
    if low == "true":
        return True
    if low == "false":
        return False
    if low in {"null", "none", "~"}:
        return None
    if text.startswith("[") and text.endswith("]"):
        inner = text[1:-1].strip()
        if not inner:
            return []
        return [part.strip().strip('"').strip("'") for part in inner.split(",")]
    return text


def _fallback_parse_frontmatter(frontmatter: str) -> dict[str, Any]:
    data: dict[str, Any] = {}
    for line in frontmatter.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.startswith((" ", "\t", "-")):
            continue
        match = re.match(r"^([A-Za-z0-9_-]+)\s*:\s*(.*)$", line)
        if not match:
            continue
        key = match.group(1)
        value = _coerce_scalar(match.group(2))
        data[key] = value
    return data


def _parse_frontmatter(frontmatter: str) -> dict[str, Any]:
    if yaml is None:
        return _fallback_parse_frontmatter(frontmatter)

    parsed = yaml.safe_load(frontmatter)
    if parsed is None:
        return {}
    if not isinstance(parsed, dict):
        raise ValueError("Frontmatter must parse to a YAML mapping/object")
    return parsed


def _add_find(findings: list[Finding], level: str, code: str, message: str) -> None:
    findings.append(Finding(level=level, code=code, message=message))


def validate_skill(skill_path: str | Path, strict: bool = False) -> dict[str, Any]:
    skill_dir = Path(skill_path).expanduser().resolve()
    findings: list[Finding] = []

    if not skill_dir.exists():
        _add_find(findings, "error", "SKILL_DIR_MISSING", f"Skill path does not exist: {skill_dir}")
        return _result(skill_dir, findings)
    if not skill_dir.is_dir():
        _add_find(findings, "error", "SKILL_PATH_NOT_DIR", f"Skill path is not a directory: {skill_dir}")
        return _result(skill_dir, findings)

    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        _add_find(findings, "error", "SKILL_MD_MISSING", f"Missing SKILL.md at: {skill_md}")
        return _result(skill_dir, findings)

    readmes = list(skill_dir.rglob("README.md"))
    if readmes:
        level = "error" if strict else "warning"
        _add_find(
            findings,
            level,
            "README_PRESENT",
            "README.md found inside skill folder. Prefer SKILL.md + references/ instead.",
        )

    content = skill_md.read_text(encoding="utf-8", errors="replace")
    try:
        frontmatter_text, body = _split_frontmatter(content)
    except ValueError as exc:
        _add_find(findings, "error", "FRONTMATTER_PARSE", str(exc))
        return _result(skill_dir, findings)

    try:
        fm = _parse_frontmatter(frontmatter_text)
    except Exception as exc:
        _add_find(findings, "error", "FRONTMATTER_INVALID", f"Failed to parse frontmatter: {exc}")
        return _result(skill_dir, findings)

    keys = set(fm.keys())
    unknown = sorted(keys - ALLOWED_KEYS)
    if unknown:
        level = "error" if strict else "warning"
        _add_find(
            findings,
            level,
            "UNKNOWN_KEYS",
            f"Unknown frontmatter keys: {', '.join(unknown)}",
        )

    for key in sorted(RECOMMENDED_KEYS):
        if key not in fm:
            level = "error" if strict else "warning"
            _add_find(
                findings,
                level,
                "MISSING_RECOMMENDED_KEY",
                f"Frontmatter is missing recommended key: {key}",
            )

    if "name" in fm:
        name = fm["name"]
        if not isinstance(name, str):
            _add_find(findings, "error", "NAME_TYPE", "name must be a string")
        else:
            name = name.strip()
            if not name:
                _add_find(findings, "error", "NAME_EMPTY", "name cannot be empty")
            elif len(name) > MAX_NAME_LEN:
                _add_find(findings, "error", "NAME_TOO_LONG", f"name exceeds {MAX_NAME_LEN} characters")
            elif not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name):
                _add_find(findings, "error", "NAME_FORMAT", "name must be kebab-case: lowercase letters, digits, hyphens")
            for prefix in RESERVED_PREFIXES:
                if name.startswith(prefix):
                    _add_find(findings, "error", "NAME_RESERVED_PREFIX", f"name must not start with reserved prefix: {prefix}")
            if name != skill_dir.name:
                _add_find(
                    findings,
                    "warning",
                    "NAME_FOLDER_MISMATCH",
                    f"name '{name}' does not match folder name '{skill_dir.name}'",
                )

    if "description" in fm:
        desc = fm["description"]
        if not isinstance(desc, str):
            _add_find(findings, "error", "DESCRIPTION_TYPE", "description must be a string")
        else:
            desc = desc.strip()
            if not desc:
                _add_find(findings, "error", "DESCRIPTION_EMPTY", "description cannot be empty")
            if len(desc) > MAX_DESCRIPTION_LEN:
                _add_find(findings, "error", "DESCRIPTION_TOO_LONG", f"description exceeds {MAX_DESCRIPTION_LEN} characters")
            if "<" in desc or ">" in desc:
                _add_find(findings, "error", "DESCRIPTION_ANGLE_BRACKETS", "description must not contain angle brackets")
            if not re.search(r"\buse when\b|\buse whenever\b|\buse for\b", desc.lower()):
                _add_find(
                    findings,
                    "warning",
                    "DESCRIPTION_TRIGGER_HINT",
                    "description should usually include explicit trigger language like 'Use when ...'",
                )

    if "compatibility" in fm:
        compatibility = fm["compatibility"]
        if not isinstance(compatibility, str):
            _add_find(findings, "error", "COMPATIBILITY_TYPE", "compatibility must be a string")
        elif len(compatibility) > MAX_COMPATIBILITY_LEN:
            _add_find(
                findings,
                "error",
                "COMPATIBILITY_TOO_LONG",
                f"compatibility exceeds {MAX_COMPATIBILITY_LEN} characters",
            )

    if "allowed-tools" in fm:
        at = fm["allowed-tools"]
        if isinstance(at, str):
            pass  # comma-separated string is valid
        elif isinstance(at, list):
            for idx, item in enumerate(at):
                if not isinstance(item, str):
                    _add_find(
                        findings,
                        "error",
                        "ALLOWED_TOOLS_ITEM_TYPE",
                        f"allowed-tools item #{idx} must be a string, got {type(item).__name__}",
                    )
        else:
            _add_find(
                findings,
                "error",
                "ALLOWED_TOOLS_TYPE",
                f"allowed-tools must be a string or list of strings, got {type(at).__name__}",
            )

    if "model" in fm:
        model_val = fm["model"]
        if not isinstance(model_val, str):
            _add_find(findings, "error", "MODEL_TYPE", "model must be a string")

    if "hooks" in fm:
        hooks_val = fm["hooks"]
        if not isinstance(hooks_val, dict):
            _add_find(findings, "error", "HOOKS_TYPE", "hooks must be a mapping/object")

    context = fm.get("context")
    agent = fm.get("agent")
    if context == "fork" and "agent" not in fm:
        _add_find(
            findings,
            "warning",
            "CONTEXT_FORK_NO_AGENT",
            "context is 'fork' but agent is not set (defaults may still work)",
        )
    if context != "fork" and "agent" in fm:
        _add_find(
            findings,
            "warning",
            "AGENT_WITHOUT_FORK",
            "agent is set but context is not 'fork'; this is often unintended",
        )

    total_lines = len(content.splitlines())
    if total_lines > RECOMMENDED_MAX_LINES:
        _add_find(
            findings,
            "warning",
            "SKILL_MD_TOO_LONG",
            f"SKILL.md has {total_lines} lines (recommended <= {RECOMMENDED_MAX_LINES})",
        )

    if re.search(r"^\s{0,3}#{1,6}\s*when to use\b", body, flags=re.IGNORECASE | re.MULTILINE):
        _add_find(
            findings,
            "warning",
            "WHEN_TO_USE_IN_BODY",
            "Move 'When to use' trigger guidance into frontmatter description when possible",
        )

    for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", body):
        if target.startswith(("http://", "https://", "#", "mailto:")):
            continue
        if target.startswith("../") or "/../" in target:
            _add_find(
                findings,
                "warning",
                "DEEP_LINK_TARGET",
                f"Link target '{target}' escapes current folder; prefer one-level references from SKILL.md",
            )

    return _result(skill_dir, findings)


def _result(skill_dir: Path, findings: list[Finding]) -> dict[str, Any]:
    errors = [asdict(f) for f in findings if f.level == "error"]
    warnings = [asdict(f) for f in findings if f.level == "warning"]
    return {
        "skill_path": str(skill_dir),
        "valid": len(errors) == 0,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "error_count": len(errors),
            "warning_count": len(warnings),
        },
    }


def render_report(report: dict[str, Any]) -> str:
    lines = [
        f"Skill: {report['skill_path']}",
        f"Valid: {'yes' if report['valid'] else 'no'}",
        "",
    ]
    if report["errors"]:
        lines.append("Errors:")
        for item in report["errors"]:
            lines.append(f"- [{item['code']}] {item['message']}")
        lines.append("")
    if report["warnings"]:
        lines.append("Warnings:")
        for item in report["warnings"]:
            lines.append(f"- [{item['code']}] {item['message']}")
        lines.append("")
    if not report["errors"] and not report["warnings"]:
        lines.append("No issues found.")
    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a Claude/Codex skill folder")
    parser.add_argument("skill_path", help="Path to skill directory")
    parser.add_argument("--strict", action="store_true", help="Treat warnings about missing recommended fields and unknown keys as errors")
    parser.add_argument("--json", action="store_true", help="Output JSON report")
    args = parser.parse_args()

    report = validate_skill(args.skill_path, strict=args.strict)
    if args.json:
        print(json.dumps(report, indent=2, ensure_ascii=False))
    else:
        print(render_report(report), end="")
    return 0 if report["valid"] else 1


if __name__ == "__main__":
    sys.exit(main())

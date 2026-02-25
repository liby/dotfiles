#!/usr/bin/env python3
"""Initialize a new skill scaffold."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


VALID_NAME = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
DEFAULT_RESOURCES = ()


SKILL_TEMPLATE = """---
name: {name}
description: {description}
compatibility: {compatibility}
---

# {title}

## Quick Start

1. Invoke with `/{name}` or let Claude trigger automatically via description match.
2. For common tasks, follow the workflow below.

## Workflow

1. Define the task inputs and expected outputs.
2. Execute the core steps in order.
3. Validate results match quality criteria.

## Error Handling

- If inputs are missing or malformed, report clearly and stop.
- If an external tool fails, retry once, then surface the error to the user.

## Additional References

- Link `references/*.md` files here as the skill grows.
"""


def to_title(name: str) -> str:
    return " ".join(part.capitalize() for part in name.split("-"))


def quote_yaml_scalar(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def normalize_resources(raw: str | None) -> tuple[str, ...]:
    if not raw:
        return DEFAULT_RESOURCES
    parts = [part.strip() for part in raw.split(",") if part.strip()]
    all_valid = ("scripts", "references", "assets")
    invalid = [part for part in parts if part not in all_valid]
    if invalid:
        raise ValueError(f"Invalid resources: {', '.join(invalid)}")
    seen: list[str] = []
    for part in parts:
        if part not in seen:
            seen.append(part)
    return tuple(seen)


def initialize_skill(
    skill_name: str,
    root_path: Path,
    description: str,
    resources: tuple[str, ...],
    force: bool,
    compatibility: str,
) -> Path:
    if not VALID_NAME.fullmatch(skill_name):
        raise ValueError(
            "skill name must be kebab-case (lowercase letters, digits, hyphens)"
        )

    skill_dir = root_path.expanduser().resolve() / skill_name
    if skill_dir.exists() and any(skill_dir.iterdir()) and not force:
        raise ValueError(f"Target already exists and is not empty: {skill_dir}")

    skill_dir.mkdir(parents=True, exist_ok=True)
    for resource in resources:
        (skill_dir / resource).mkdir(parents=True, exist_ok=True)

    title = to_title(skill_name)
    desc_value = description or (
        f"Describe what this skill does and when to use it. Use when ..."
    )
    compat_value = compatibility or "No special requirements."
    skill_md = skill_dir / "SKILL.md"
    skill_md.write_text(
        SKILL_TEMPLATE.format(
            name=skill_name,
            description=quote_yaml_scalar(desc_value),
            compatibility=quote_yaml_scalar(compat_value),
            title=title,
        ),
        encoding="utf-8",
    )

    return skill_dir


def main() -> int:
    parser = argparse.ArgumentParser(description="Initialize a new skill scaffold")
    parser.add_argument("skill_name", help="Skill folder and frontmatter name")
    parser.add_argument(
        "--path",
        default=".",
        help="Directory where the new skill folder will be created",
    )
    parser.add_argument(
        "--description",
        default="",
        help="Initial frontmatter description",
    )
    parser.add_argument(
        "--compatibility",
        default="",
        help="Runtime requirements (e.g., 'Python 3.9+, claude CLI on PATH')",
    )
    parser.add_argument(
        "--resources",
        default="",
        help="Comma-separated subset of: scripts,references,assets (default: none)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Allow writing into an existing non-empty target directory",
    )
    args = parser.parse_args()

    try:
        resources = normalize_resources(args.resources)
        skill_dir = initialize_skill(
            skill_name=args.skill_name,
            root_path=Path(args.path),
            description=args.description,
            resources=resources,
            force=args.force,
            compatibility=args.compatibility,
        )
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    print(f"Initialized skill scaffold: {skill_dir}")
    print(f"Next: edit {skill_dir / 'SKILL.md'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())


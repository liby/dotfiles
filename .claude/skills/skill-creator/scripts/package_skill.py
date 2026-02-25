#!/usr/bin/env python3
"""Package a skill folder into a .skill archive."""

from __future__ import annotations

import argparse
import fnmatch
import sys
import zipfile
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from validate_skill import render_report, validate_skill  # noqa: E402


EXCLUDE_DIRS = {
    "__pycache__",
    "node_modules",
    ".git",
    ".pytest_cache",
    ".mypy_cache",
}
ROOT_EXCLUDE_DIRS = {
    "evals",
    "benchmarks",
    "tmp",
}
EXCLUDE_FILE_NAMES = {
    ".DS_Store",
    "Thumbs.db",
}
EXCLUDE_GLOBS = {
    "*.pyc",
    "*.pyo",
    "*.swp",
    "*.swo",
}


def should_exclude(rel_path: Path) -> bool:
    parts = rel_path.parts
    if any(part in EXCLUDE_DIRS for part in parts):
        return True
    if len(parts) > 1 and parts[1] in ROOT_EXCLUDE_DIRS:
        return True
    if rel_path.name in EXCLUDE_FILE_NAMES:
        return True
    return any(fnmatch.fnmatch(rel_path.name, pattern) for pattern in EXCLUDE_GLOBS)


def package_skill(skill_path: Path, output_dir: Path, strict: bool, validate: bool) -> Path:
    skill_path = skill_path.expanduser().resolve()
    output_dir = output_dir.expanduser().resolve()

    if not skill_path.exists() or not skill_path.is_dir():
        raise ValueError(f"Skill folder does not exist or is not a directory: {skill_path}")

    if validate:
        report = validate_skill(skill_path, strict=strict)
        print(render_report(report), end="")
        if not report["valid"]:
            raise ValueError("Validation failed; aborting packaging")

    output_dir.mkdir(parents=True, exist_ok=True)
    artifact = output_dir / f"{skill_path.name}.skill"

    with zipfile.ZipFile(artifact, "w", zipfile.ZIP_DEFLATED) as archive:
        for file_path in sorted(skill_path.rglob("*")):
            if not file_path.is_file():
                continue
            rel = file_path.relative_to(skill_path.parent)
            if should_exclude(rel):
                continue
            archive.write(file_path, arcname=rel)

    return artifact


def main() -> int:
    parser = argparse.ArgumentParser(description="Package a skill into a .skill archive")
    parser.add_argument("skill_path", help="Path to skill directory")
    parser.add_argument(
        "--output-dir",
        default=".",
        help="Directory for generated .skill file (default: current directory)",
    )
    parser.add_argument("--strict", action="store_true", help="Run validator in strict mode")
    parser.add_argument("--no-validate", action="store_true", help="Skip validation before packaging")
    args = parser.parse_args()

    try:
        artifact = package_skill(
            skill_path=Path(args.skill_path),
            output_dir=Path(args.output_dir),
            strict=args.strict,
            validate=not args.no_validate,
        )
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    print(f"Packaged: {artifact}")
    return 0


if __name__ == "__main__":
    sys.exit(main())


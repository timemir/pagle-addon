"""scripts/generate-data.py's command line (DATA-R60): with no flag it rewrites every generated file; --check
writes nothing and fails if any generated file would change. Each other mode arrives with the rule it serves.
"""

import argparse
import os
import sys
from collections.abc import Sequence
from pathlib import Path

from pagle_data.generate import generate
from pagle_data.toml_reader import DataError

PROG = "generate-data"


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="scripts/generate-data.py",
        description="Generate Pagle's content data files from data/ (docs/spec/content-data.md).",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="write nothing; fail if any generated file differs from what data/ gives (DATA-R61)",
    )
    return parser


def _current(path: Path) -> bytes | None:
    try:
        return path.read_bytes()
    except FileNotFoundError:
        return None


def _write(path: Path, content: bytes) -> None:
    # Through a temporary file, so an interrupted run never leaves half a file.
    path.parent.mkdir(parents=True, exist_ok=True)
    partial = path.with_name(path.name + ".partial")
    partial.write_bytes(content)
    os.replace(partial, path)


def main(argv: Sequence[str], root: Path) -> int:
    """Runs the command line on the repo at root; returns the exit code."""
    args = _parser().parse_args(argv)
    try:
        outputs = generate(root)
    except DataError as error:
        for problem in error.problems:
            print(f"{PROG}: {problem}", file=sys.stderr)
        print(f"{PROG}: {len(error.problems)} problem(s) in data/; wrote nothing", file=sys.stderr)
        return 1

    contents = {path: text.encode("utf-8") for path, text in sorted(outputs.items())}
    stale = [path for path, content in contents.items() if _current(root / path) != content]

    if args.check:
        for path in stale:
            message = f"{path} is out of date with data/; run scripts/generate-data.py and commit it"
            print(f"{PROG}: {message}", file=sys.stderr)
        if stale:
            return 1
        print(f"{PROG}: {len(contents)} generated file(s) up to date")
        return 0

    for path in stale:
        _write(root / path, contents[path])
        print(f"{PROG}: wrote {path}")
    print(f"{PROG}: {len(contents)} generated file(s) up to date")
    return 0

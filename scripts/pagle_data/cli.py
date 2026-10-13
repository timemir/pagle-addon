"""scripts/generate-data.py's command line (DATA-R60): with no flag it rewrites every generated file; --check
writes nothing and fails if any generated file would change; --propose-aliases writes nothing and prints the alias
candidates not yet committed (DATA-R32). Each other mode arrives with the rule it serves.
"""

import argparse
import os
import sys
from collections.abc import Sequence
from pathlib import Path

from pagle_data.aliases import proposal_line, proposal_toml
from pagle_data.db2 import AREAS
from pagle_data.forever import ALIASES
from pagle_data.generate import Layers, outputs, read_layers
from pagle_data.observed import OBSERVED
from pagle_data.toml_reader import DataError

PROG = "generate-data"


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="scripts/generate-data.py",
        description="Generate Pagle's content data files from data/ (docs/spec/content-data.md).",
    )
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument(
        "--check",
        action="store_true",
        help="write nothing; fail if any generated file differs from what data/ gives (DATA-R61)",
    )
    modes.add_argument(
        "--propose-aliases",
        action="store_true",
        help=f"write nothing; print the alias candidates not yet in {ALIASES}, in its shape (DATA-R32)",
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


def _print_proposals(layers: Layers) -> None:
    proposals = layers.proposals()
    print(
        f"# {len(proposals)} alias candidate(s) not in {ALIASES} (DATA-R32). Commit each one you can back with a"
        " why (DATA-R10); the rest stay proposals."
    )
    for proposal in proposals:
        print()
        print(proposal_toml(layers.db2, proposal), end="")


def _warn(layers: Layers) -> None:
    """DATA-R64's warnings, printed and not failing: so far, observed areas missing from the slice (DATA-R33) and
    the alias proposals not yet committed."""
    for area, seen in layers.missing_areas().items():
        where = ", ".join(str(at) for at in seen)
        message = f"area {area} seen in {OBSERVED} is not in {AREAS}; update the DB2 slice ({where})"
        print(f"{PROG}: warning: {message}", file=sys.stderr)
    proposals = layers.proposals()
    for proposal in proposals:
        line = proposal_line(layers.db2, proposal)
        print(f"{PROG}: warning: alias proposal not in {ALIASES}: {line}", file=sys.stderr)
    if proposals:
        message = f"{len(proposals)} alias proposal(s) not committed; --propose-aliases prints them as entries"
        print(f"{PROG}: warning: {message}", file=sys.stderr)


def main(argv: Sequence[str], root: Path) -> int:
    """Runs the command line on the repo at root; returns the exit code."""
    args = _parser().parse_args(argv)
    try:
        layers = read_layers(root)
    except DataError as error:
        for problem in error.problems:
            print(f"{PROG}: {problem}", file=sys.stderr)
        print(f"{PROG}: {len(error.problems)} problem(s) in data/; wrote nothing", file=sys.stderr)
        return 1

    if args.propose_aliases:
        _print_proposals(layers)
        return 0
    _warn(layers)

    contents = {path: text.encode("utf-8") for path, text in sorted(outputs(layers).items())}
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

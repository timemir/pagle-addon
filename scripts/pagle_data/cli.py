"""scripts/generate-data.py's command line (DATA-R60): with no flag it rewrites every generated file, and
removes a Lore.lua whose lore file is gone; --check writes nothing and fails if any generated file would change. The
read-only modes write nothing and print no warning: --propose-aliases prints the alias candidates not yet committed
(DATA-R32), --min-build <n> the facts that would lose confirmation if only builds >= n counted (DATA-R57), and
--explain <id> every layer's value for an item or an area and which won. --lock rewrites data/hunts/released.lock
from the Hunt list and data/forever/varieties.lock from varieties.toml, and writes nothing else (DATA-R95,
DATA-R133); it is run when a release is tagged, from 1.0 on, and never
before (DATA-R73).
"""

import argparse
import sys
from collections.abc import Sequence
from pathlib import Path

from pagle_data.aliases import proposal_toml
from pagle_data.baseline import AREA_LOOT
from pagle_data.db2 import AREAS
from pagle_data.errors import DataError
from pagle_data.explain import explain
from pagle_data.files import write_atomic
from pagle_data.forever import ALIASES
from pagle_data.generate import Layers, event_list_of, hunt_list_of, outputs, read_layers
from pagle_data.lock import LOCK, lock_toml
from pagle_data.lore import retired_lore
from pagle_data.min_build import lost
from pagle_data.observed import OBSERVED
from pagle_data.pools import POOLS_TOML
from pagle_data.varieties import VARIETIES_LOCK, varieties_lock_toml

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
    modes.add_argument(
        "--min-build",
        type=int,
        metavar="N",
        help="write nothing; print the facts that would lose confirmation if only builds >= N counted (DATA-R57)",
    )
    modes.add_argument(
        "--explain",
        type=int,
        metavar="ID",
        help="write nothing; print every layer's value for an item or an area (or both) and which won (DATA-R60)",
    )
    modes.add_argument(
        "--lock",
        action="store_true",
        help=f"rewrite {LOCK} from the Hunt list and the event pool, every Hunt counting as released, and"
        f" {VARIETIES_LOCK} from the varieties, and write nothing else (DATA-R95, DATA-R98, DATA-R133); run it"
        " only when a release is tagged, from 1.0 on, and never before (DATA-R73)",
    )
    return parser


def _current(path: Path) -> bytes | None:
    try:
        return path.read_bytes()
    except FileNotFoundError:
        return None


def _print_proposals(layers: Layers) -> None:
    proposals = layers.proposals()
    print(
        f"# {len(proposals)} alias candidate(s) not in {ALIASES} (DATA-R32). Commit each one you can back with a"
        " why (DATA-R10); the rest stay proposals."
    )
    for proposal in proposals:
        print()
        print(proposal_toml(layers.db2, proposal), end="")


def _print_min_build(root: Path, layers: Layers, build: int) -> int:
    try:
        then = read_layers(root, build)
    except DataError as error:  # the same data read cleanly with the minimum confirming build
        return _failed(error)
    losses = lost(layers, then)
    if not losses:
        print(f"{PROG}: no fact would lose confirmation if only builds >= {build} counted (DATA-R57)")
        return 0
    print(f"{PROG}: {len(losses)} fact(s) would lose confirmation if only builds >= {build} counted (DATA-R57):")
    for line in losses:
        print(line)
    return 0


def _print_explain(layers: Layers, target: int) -> int:
    lines = explain(layers, target)
    if not lines:
        message = f"{target} is neither an item of the universe (DATA-R15) nor an area of {AREAS} (DATA-R25)"
        print(f"{PROG}: {message}", file=sys.stderr)
        return 1
    for line in lines:
        print(line)
    return 0


def _failed(error: DataError) -> int:
    for problem in error.problems:
        print(f"{PROG}: {problem}", file=sys.stderr)
    print(f"{PROG}: {len(error.problems)} problem(s) in data/; wrote nothing", file=sys.stderr)
    return 1


def _warn(layers: Layers) -> None:
    """DATA-R64's warnings, printed and not failing: so far, the baseline loot rows with a condition that isn't a
    single event (DATA-R9), baseline pool templates in no pool type (DATA-R43), observed areas missing from the slice
    (DATA-R33), observed pairs without a consistent gate (DATA-R47) and how many alias proposals aren't committed yet
    (one line; --propose-aliases lists them)."""
    for row in layers.conditional_rows():
        loot = f"item {row.item}" if row.item is not None else f"ref {row.ref}"
        message = f"area {row.area} {loot} has the condition {row.condition}, not a single event"
        print(f"{PROG}: warning: {AREA_LOOT}: {message}; it is treated as ungated", file=sys.stderr)
    for pool in layers.ungrouped_pools():
        message = f"pool template {pool.entry} ({pool.name}) in pools.csv is in no pool type in {POOLS_TOML}"
        print(f"{PROG}: warning: {message}; add it to one (DATA-R43)", file=sys.stderr)
    for area, seen in layers.missing_areas().items():
        where = ", ".join(str(at) for at in seen)
        message = f"area {area} seen in {OBSERVED} is not in {AREAS}; update the DB2 slice ({where})"
        print(f"{PROG}: warning: {message}", file=sys.stderr)
    for pair in layers.ungated_pairs():
        gated = ", ".join(f"area {area} by {window}" for area, window in pair.gated)
        message = (
            f"the observed pair item {pair.item} in area {pair.area} joins ungated, but the item is gated elsewhere"
            f" ({gated}); set its gate with an areas.toml add if it has one (DATA-R47)"
        )
        print(f"{PROG}: warning: {message}", file=sys.stderr)
    proposals = layers.proposals()
    if proposals:
        listing = "run scripts/generate-data.py --propose-aliases to list them"
        print(f"{PROG}: warning: {len(proposals)} uncommitted alias proposals; {listing}", file=sys.stderr)


def main(argv: Sequence[str], root: Path) -> int:
    """Runs the command line on the repo at root; returns the exit code."""
    args = _parser().parse_args(argv)
    try:
        layers = read_layers(root)
    except DataError as error:
        return _failed(error)

    if args.propose_aliases:
        _print_proposals(layers)
        return 0
    if args.min_build is not None:
        return _print_min_build(root, layers, args.min_build)
    if args.explain is not None:
        return _print_explain(layers, args.explain)
    if args.lock:
        write_atomic(root / LOCK, lock_toml(hunt_list_of(layers), event_list_of(layers)).encode("utf-8"))
        print(f"{PROG}: wrote {LOCK}")
        write_atomic(root / VARIETIES_LOCK, varieties_lock_toml(layers.varieties).encode("utf-8"))
        print(f"{PROG}: wrote {VARIETIES_LOCK}")
        return 0
    _warn(layers)

    contents = {path: text.encode("utf-8") for path, text in sorted(outputs(layers).items())}
    stale = [path for path, content in contents.items() if _current(root / path) != content]
    retired = retired_lore(lambda path: (root / path).is_file(), contents)

    if args.check:
        for path in stale:
            message = f"{path} is out of date with data/; run scripts/generate-data.py and commit it"
            print(f"{PROG}: {message}", file=sys.stderr)
        for path, source in retired.items():
            message = f"{path} is out of date with data/: {source} is gone; run scripts/generate-data.py to remove it"
            print(f"{PROG}: {message}", file=sys.stderr)
        if stale or retired:
            return 1
        print(f"{PROG}: {len(contents)} generated file(s) up to date")
        return 0

    for path in stale:
        write_atomic(root / path, contents[path])
        print(f"{PROG}: wrote {path}")
    for path in retired:
        (root / path).unlink()
        print(f"{PROG}: removed {path}, as {retired[path]} is gone")
    print(f"{PROG}: {len(contents)} generated file(s) up to date")
    return 0

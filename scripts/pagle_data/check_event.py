"""scripts/check-event.py's command line (DATA-R99): every DATA-R97 and DATA-R99 check the generator runs on an event,
run on one <event-id>.toml or one pushed huntEvent item given as JSON (hunts.md › Contracts), against the committed
catalogue, Hunt list and event pool, so a curator can check a draft and pagle-backend a p_ definition before it
pushes it. The checks are pagle_data.events' and pagle_data.lore's, the generator's own, so the two never disagree.

A file outside data/hunts/events/ and a pushed item are checked as one more event beside the committed pool: its ID
and its Hunts' IDs new to the pool and hunts.toml, its tags from tags.toml, its zones, Hunts and conditions as the
generator checks a pool event's, and its lore by DATA-R107's glyph check and, when data/checks.toml has the hunts
lore check on, the Hunts lore check. A pushed item always gets the Hunts lore check: it ships without the dev's
review. A file in data/hunts/events/ is already in the pool, so the generator's own run checks it, and only its
problems are named. Each failure is printed on its own line, in the generator's words; the exit code is 0 when the
event passes, 1 when it doesn't, and 2 when the committed data itself has problems to fix first. It writes nothing.
"""

import argparse
import json
import sys
from collections.abc import Iterable, Sequence
from pathlib import Path

from pagle_data.checks import read_checks
from pagle_data.errors import At, DataError, Problems
from pagle_data.events import (
    EventLayer,
    HuntEvent,
    check_event_hunts,
    check_events,
    read_event_file,
    read_pushed_event,
)
from pagle_data.generate import Layers, read_layers
from pagle_data.hunts import hunt_classes
from pagle_data.lore import HUNTS_OWNER, LoreLayer, check_glyphs, check_hunts_texts
from pagle_data.universe import EVENTS_DIR

PROG = "check-event"
# The exit codes: the event passes, it fails a check, the committed data fails the generator.
PASSED, FAILED, COMMITTED_FAILS = 0, 1, 2


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="scripts/check-event.py",
        description="Check one Hunt Event file or one pushed huntEvent item against the committed data (DATA-R99).",
    )
    parser.add_argument(
        "file",
        type=Path,
        help="an <event-id>.toml (DATA-R97) or a pushed huntEvent item as JSON (.json, hunts.md › Contracts)",
    )
    return parser


def check_new_event(event: HuntEvent, layers: Layers, hunts_lore: bool, problems: Problems) -> None:
    """DATA-R97's and DATA-R99's checks on an event that isn't in the pool, against layers as read: its event ID and
    each Hunt's new to the pool and hunts.toml, its Hunts' classes, everything check_events checks but the pool
    minimum, the glyph check on its lore and, with hunts_lore, the Hunts lore check (DATA-R107)."""
    pool = layers.events
    if event.id in {entry.id for entry in pool.events}:
        problems.add(event.at / "id", f"the event ID '{event.id}' is already in {EVENTS_DIR}/ (DATA-R97)")
    # Listed after the pool, so a Hunt ID the pool or hunts.toml already has is named at this event (DATA-R92).
    check_event_hunts(EventLayer(pool.tags, [*pool.events, event]), layers.hunts, problems)
    classes = hunt_classes(layers.hunts, layers.items, layers.lock.classes)
    one = EventLayer(pool.tags, [event])
    forever = layers.forever
    check_events(
        one, classes, layers.items, layers.catch_lists, layers.db2.areas, forever.auras, forever.events, False, problems
    )
    texts = {text.key: text for text in event.texts}
    check_glyphs(LoreLayer(events={event.file: texts}), problems)
    if hunts_lore:
        check_hunts_texts(event.file, texts, problems)


def _read_json(path: Path, problems: Problems) -> object:
    at = At(str(path))
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        problems.add(at, "missing")
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        problems.add(at, f"not valid JSON: {error}")
    return None


def _about(problem: str, file: str) -> bool:
    return problem == file or problem.startswith(f"{file}: ")


def _passed(file: str) -> int:
    print(f"{PROG}: {file} passes DATA-R97's and DATA-R99's checks")
    return PASSED


def _failed(file: str, problems: Iterable[str]) -> int:
    found = list(problems)
    for problem in found:
        print(f"{PROG}: {problem}")
    print(f"{PROG}: {len(found)} problem(s) in {file}", file=sys.stderr)
    return FAILED


def _committed(file: str, problems: Sequence[str]) -> int:
    for problem in problems:
        print(f"{PROG}: {problem}", file=sys.stderr)
    message = f"the committed data has {len(problems)} problem(s); fix them and run scripts/generate-data.py"
    print(f"{PROG}: {message} before checking {file} against it", file=sys.stderr)
    return COMMITTED_FAILS


def _check_in_place(root: Path, file: str) -> int:
    """A file in data/hunts/events/: the generator's run on the data, naming only the file's problems."""
    try:
        read_layers(root)
    except DataError as error:
        own = [problem for problem in error.problems if _about(problem, file)]
        others = [problem for problem in error.problems if not _about(problem, file)]
        if others:
            return _committed(file, others)
        return _failed(file, own)
    return _passed(file)


def main(argv: Sequence[str], root: Path) -> int:
    """Runs the command line on the repo at root; returns the exit code."""
    path: Path = _parser().parse_args(argv).file
    if path.suffix == ".toml" and path.resolve().parent == (root / EVENTS_DIR).resolve():
        return _check_in_place(root, f"{EVENTS_DIR}/{path.name}")
    file = str(path)
    try:
        layers = read_layers(root)
    except DataError as error:
        return _committed(file, error.problems)
    problems = Problems()
    tags = layers.events.tags
    event: HuntEvent | None = None
    pushed = path.suffix == ".json"
    if path.suffix == ".toml":
        event = read_event_file(path, tags, problems)
    elif pushed:
        item = _read_json(path, problems)
        event = None if problems else read_pushed_event(item, file, tags, problems)
    else:
        problems.add(At(file), "expected an event file (.toml) or a pushed huntEvent item (.json)")
    if event is not None:
        hunts_lore = pushed or HUNTS_OWNER in read_checks(root, Problems()).lore
        check_new_event(event, layers, hunts_lore, problems)
    if problems:
        return _failed(file, problems)
    return _passed(file)

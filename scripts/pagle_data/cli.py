"""scripts/generate-data.py's command line (DATA-R60): with no flag it rewrites every generated file, and
removes a Lore.lua whose lore file is gone; --check writes nothing and fails if any generated file would change. The
read-only modes write nothing and print no warning: --propose-aliases prints the alias candidates not yet committed
(DATA-R32), --min-build <n> the facts that would lose confirmation if only builds >= n counted (DATA-R57), and
--explain <id> every layer's value for an item or an area and which won, --translators the CHANGELOG's TRANSLATORS block
from the Locales' headers (with --since <tag>, only the languages whose translations changed since that tag) and
--check-changelog <version> whether that release's entry credits just the languages whose translations changed since
the previous release tag (DATA-R114, docs/translations.md › Credits). --stale lists the translations whose EN snapshot
is not today's English, --stale-issue <code> prints the body of a Locale's "translations stale" issue, and --drop-stale removes the stale
translations whose {fields} changed from the Locales' TOML and then runs as with no flag (DATA-R114,
docs/translations.md › Drift and the stale issue). --lock rewrites data/hunts/released.lock
from the Hunt list and data/forever/varieties.lock from varieties.toml, and writes nothing else (DATA-R95,
DATA-R133); it is run when a release is tagged, from 1.0 on, and never
before (DATA-R73).
"""

import argparse
import os
import subprocess
import sys
from collections.abc import Sequence
from pathlib import Path

from pagle_data.aliases import proposal_toml
from pagle_data.baseline import AREA_LOOT
from pagle_data.credits import CHANGELOG, changed_locales, check_changelog, previous_tag, translators_block
from pagle_data.db2 import AREAS
from pagle_data.drift import (
    FIELDS_CHANGED,
    SAME_FIELDS,
    Sources,
    Stale,
    drop_stale,
    find_gaps,
    find_stale,
    issue_body,
    issue_json,
    read_sources,
    stale_json,
    stale_text,
)
from pagle_data.errors import DataError, Problems
from pagle_data.explain import explain
from pagle_data.files import write_atomic
from pagle_data.forever import ALIASES
from pagle_data.generate import Layers, event_list_of, hunt_list_of, outputs, read_layers
from pagle_data.glyphs import ENGLISH
from pagle_data.lock import LOCK, lock_toml
from pagle_data.locale import listed_at_base, retired_locale
from pagle_data.lore import retired_lore, retired_translations
from pagle_data.min_build import lost
from pagle_data.observed import OBSERVED
from pagle_data.pools import POOLS_TOML
from pagle_data.toml_edit import EditError
from pagle_data.varieties import VARIETIES_LOCK, varieties_lock_toml

PROG = "generate-data"


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="scripts/generate-data.py",
        description="Generate Pagle's content data files from data/ (docs/spec/content-data.md).",
    )
    parser.add_argument(
        "--base",
        metavar="REF",
        help="the branch a pull request merges into (default: origin/$GITHUB_BASE_REF, if set): a Locale newly marked"
        " `listed` against its merge base with REF must cover 100% of the interface (DATA-R114); with no base, a"
        " coverage gap only warns",
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
        "--translators",
        action="store_true",
        help="write nothing; print the TRANSLATORS block for a release's CHANGELOG entry: one line for each listed"
        " Locale with translators, from the headers in data/locale/; with --since TAG, only for those whose"
        " translations changed since TAG (DATA-R114)",
    )
    modes.add_argument(
        "--check-changelog",
        metavar="VERSION",
        help=f"write nothing; fail if {CHANGELOG}'s entry for VERSION lacks the TRANSLATORS block, or a line of it, for"
        " a listed Locale with translators whose translations changed since the previous release tag, or credits one"
        " whose translations did not (DATA-R114); with no tag before VERSION, every such Locale is wanted. Run it"
        " before the tag",
    )
    parser.add_argument(
        "--since",
        metavar="TAG",
        help="with --translators or --check-changelog: the release to compare data/locale/<code>/ and"
        " data/lore/<code>/ with (--check-changelog's default: the greatest release tag below VERSION) (DATA-R114)",
    )
    modes.add_argument(
        "--stale",
        action="store_true",
        help="write nothing; list, for each Locale, every translated string (interface and Lore) whose EN snapshot is no"
        " longer today's English: `same fields` (keeps showing) or `fields changed` (dropped by --drop-stale)"
        " (DATA-R114). Exits 0 whatever it finds; --json prints it as JSON",
    )
    modes.add_argument(
        "--drop-stale",
        action="store_true",
        help="remove from each Locale's TOML the `value` and `en` of every stale string whose {fields} changed, so"
        " English shows for it, then regenerate like a plain run (DATA-R114). Run it in the pull request that changes"
        " English; comments in the TOML stay, and a second run changes nothing",
    )
    modes.add_argument(
        "--stale-issue",
        metavar="CODE",
        help="write nothing; print the body of the Locale's \"translations stale\" issue: the counts, the stale keys by"
        " kind and the keys with no translation, as checklists (DATA-R114); --json prints title, body and counts",
    )
    parser.add_argument("--json", action="store_true", help="with --stale or --stale-issue: print JSON, not text")
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


def _failed(error: DataError, hint: str = "") -> int:
    for problem in error.problems:
        print(f"{PROG}: {problem}", file=sys.stderr)
    if hint:
        print(f"{PROG}: {hint}", file=sys.stderr)
    print(f"{PROG}: {len(error.problems)} problem(s) in data/; wrote nothing", file=sys.stderr)
    return 1


def _drop_hint(root: Path) -> str:
    """What to say after a failed run when a translation's English changed under it (DATA-R114): the fields-changed
    strings fail the placeholder check, and the maintainer's pull request drops them. Empty when there are none, or when
    the Locale sources do not read (the problems above say why)."""
    sources = read_sources(root)
    if sources.problems:
        return ""
    count = sum(1 for item in find_stale(sources) if item.kind == FIELDS_CHANGED)
    if not count:
        return ""
    return (
        f"{count} translation(s) are stale with changed {{fields}} (--stale lists them) and fail the checks above; in"
        " the pull request that changes English, run scripts/generate-data.py --drop-stale, and English shows for them"
        " until a translator updates them (DATA-R114)"
    )


def _print_stale(sources: Sources, stale: list[Stale], as_json: bool) -> int:
    headers = sources.locale.headers
    print(stale_json(stale, headers) if as_json else stale_text(stale, headers), end="")
    return 0


def _print_stale_issue(sources: Sources, stale: list[Stale], code: str, as_json: bool) -> int:
    header = sources.locale.headers.get(code)
    if header is None or code == ENGLISH:
        print(f"{PROG}: no Locale {code} in data/locale/ with a translation to track (DATA-R114)", file=sys.stderr)
        return 1
    gaps = find_gaps(sources, code)
    print(issue_json(code, header, stale, gaps) if as_json else issue_body(code, header, stale, gaps), end="")
    return 0


def _dropped(root: Path, stale: list[Stale]) -> int:
    """--drop-stale's first half: the fields-changed strings out of the TOML (DATA-R114); the generator then runs as
    it does with no flag."""
    try:
        dropped = drop_stale(root, stale)
    except EditError as error:
        print(f"{PROG}: {error}; wrote nothing", file=sys.stderr)
        return 1
    for item in dropped:
        print(f"{PROG}: dropped {item.key} from {item.file}, so English shows")
    kept = sum(1 for item in stale if item.kind == SAME_FIELDS)
    left = f"; {kept} stale string(s) with the same {{fields}} keep showing (--stale lists them)" if kept else ""
    print(f"{PROG}: dropped {len(dropped)} translation(s) whose {{fields}} changed{left}")
    return 0


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
    # DATA-R114: drift, and the gaps of a Locale already listed
    for warning in (*layers.locale.warnings, *layers.lore.warnings):
        print(f"{PROG}: warning: {warning}", file=sys.stderr)


def _in_git(root: Path) -> bool:
    done = subprocess.run(["git", "-C", str(root), "rev-parse", "--git-dir"], capture_output=True, check=False)
    return done.returncode == 0


def _listed_before(root: Path, base: str | None) -> dict[str, bool] | None:
    """Each Locale's `listed` at the merge base with the pull request's base branch (DATA-R114's coverage rule), or None
    where there is no base to ask: neither --base nor GITHUB_BASE_REF, or a tree that is not a git checkout (a copy of
    it). A base that is named, by --base or by GITHUB_BASE_REF in a checkout, and that git cannot find or merge with is
    an error, so a broken CI fetch cannot quietly turn a failure into a warning."""
    ref = base
    if ref is None and os.environ.get("GITHUB_BASE_REF"):
        if not _in_git(root):
            return None
        ref = f"origin/{os.environ['GITHUB_BASE_REF']}"
    if ref is None:
        return None
    try:
        return listed_at_base(root, ref)
    except LookupError as error:
        raise DataError([f"the base for the coverage rule, {ref}: {error}"]) from error


def _check_changelog(root: Path, layers: Layers, version: str, since: str | None) -> int:
    """--check-changelog: judges the entry against the languages changed since `since`, or since the release tag before
    `version`; with neither, against every listed Locale with translators (DATA-R114)."""
    since = since if since is not None else previous_tag(root, version)
    changed = None
    if since is None:
        print(
            f"{PROG}: no release tag before {version}, so every listed language with translators is credited",
            file=sys.stderr,
        )
    else:
        try:
            changed = changed_locales(root, since)
        except LookupError as error:
            print(f"{PROG}: --check-changelog against {since}: {error}", file=sys.stderr)
            return 1
    problems = Problems()
    check_changelog(root, layers.locale.headers, version, problems, changed, since)
    if problems.found:
        for problem in problems.found:
            print(f"{PROG}: {problem}", file=sys.stderr)
        return 1
    against = "every listed language" if since is None else f"the languages whose translations changed since {since}"
    print(f"{PROG}: {CHANGELOG}'s entry for {version} credits the translators of {against} (DATA-R114)")
    return 0


def main(argv: Sequence[str], root: Path) -> int:
    """Runs the command line on the repo at root; returns the exit code."""
    parser = _parser()
    args = parser.parse_args(argv)
    if args.json and not (args.stale or args.stale_issue is not None):
        parser.error("--json goes with --stale or --stale-issue")
    if args.since is not None and not (args.translators or args.check_changelog is not None):
        parser.error("--since goes with --translators or --check-changelog")
    if args.stale or args.stale_issue is not None or args.drop_stale:
        # DATA-R114: a tree with a stale string fails the generator's checks, which is what these modes are for, so
        # they read the TOML themselves and run before the checks.
        sources = read_sources(root)
        if sources.problems:
            return _failed(DataError(sources.problems.found))
        drifted = find_stale(sources)
        if args.stale:
            return _print_stale(sources, drifted, args.json)
        if args.stale_issue is not None:
            return _print_stale_issue(sources, drifted, args.stale_issue, args.json)
        if _dropped(root, drifted):
            return 1
    try:
        layers = read_layers(root, listed_before=_listed_before(root, args.base))
    except DataError as error:
        return _failed(error, _drop_hint(root))

    if args.propose_aliases:
        _print_proposals(layers)
        return 0
    if args.min_build is not None:
        return _print_min_build(root, layers, args.min_build)
    if args.explain is not None:
        return _print_explain(layers, args.explain)
    if args.translators:
        changed = None
        if args.since is not None:
            try:
                changed = changed_locales(root, args.since)
            except LookupError as error:
                print(f"{PROG}: --since {args.since}: {error}", file=sys.stderr)
                return 1
        block = translators_block(layers.locale.headers, changed)
        if not block and changed is not None:
            print(
                f"{PROG}: no listed language's translations changed since {args.since}; the entry needs no TRANSLATORS"
                " block",
                file=sys.stderr,
            )
        elif not block:
            print(f"{PROG}: no listed Locale has translators; the entry needs no TRANSLATORS block", file=sys.stderr)
        print(block, end="")
        return 0
    if args.check_changelog is not None:
        return _check_changelog(root, layers, args.check_changelog, args.since)
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
    retired |= retired_locale(root, contents, layers.locale)
    retired |= retired_translations(root, contents)

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

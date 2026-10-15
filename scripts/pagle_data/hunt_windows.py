"""Admission and the rarity cap (DATA-R92): the two Hunt checks that read what a Hunt's window means. A natural Hunt
must be catchable, its window gating its Species somewhere, and no Hunt may be open so rarely that it's a chore.
A retired Hunt is held to neither."""

import json
from collections.abc import Collection, Mapping

from pagle_data.areas import CatchLists
from pagle_data.errors import Problems
from pagle_data.hunts import IMPOSED, NATURAL, Hunt, HuntLayer
from pagle_data.items import Record
from pagle_data.realm_time import (
    LONGEST_CLOSED_STEPS,
    OPEN_SHARE_DENOMINATOR,
    STEP_MINUTES,
    STEPS,
    Openness,
    Rules,
    openness,
)

# The fields the rarity cap reads (DATA-R92); every other field is ignored.
_TIME_FIELDS = ("time", "season", "events")


def _current(hunts: HuntLayer) -> list[Hunt]:
    """The Hunts that aren't retired: only they are held to admission and the cap (DATA-R92)."""
    return [hunt for hunt in hunts.hunts if "retired" not in hunt.record]


def check_admission(
    hunts: HuntLayer,
    items: Mapping[int, Record],
    catch_lists: CatchLists,
    windows: Collection[str],
    problems: Problems,
) -> None:
    """DATA-R92's admission: a natural Hunt that isn't retired fails when no catch entry of any item of its target
    Species (an item whose species is the target, DATA-R19), in any area, carries its window as gate. Contradicted
    gates are still gates (DATA-R52), so they count. A target that isn't a Species, or a window that isn't one, is
    check_hunts' problem alone."""
    gated: set[tuple[int, str]] = set()
    for catches in catch_lists.lists.values():
        for catch in catches:
            species = items[catch.item].get("species") if catch.item in items else None
            if isinstance(species, int) and catch.window is not None:
                gated.add((species, catch.window))
    for hunt in _current(hunts):
        species, window = hunt.get("species"), hunt.get("window")
        if hunt.get("kind") != NATURAL or not isinstance(species, int) or window not in windows:
            continue
        target = items.get(species)
        if target is None or target.get("species") != species:
            continue
        if (species, window) not in gated:
            message = f"no catch entry of Species {species}'s items, in any area, has the gate '{window}'"
            problems.add(hunt.at, f"admission: {message}; gate one, or retire the Hunt (DATA-R92)")


def _duration(steps: int) -> str:
    """A run of steps as days, hours and minutes, the parts that aren't 0."""
    days, minutes = divmod(steps * STEP_MINUTES, 24 * 60)
    hours, minutes = divmod(minutes, 60)
    parts = [(days, "day"), (hours, "hour"), (minutes, "minute")]
    return " ".join(f"{count} {unit}{'' if count == 1 else 's'}" for count, unit in parts if count) or "0 minutes"


def _cap_message(found: Openness) -> str:
    """The rarity cap's failure, with the numbers that failed it: the open share and the longest closed run."""
    share = 100 * found.open_steps / STEPS
    needed = 100 / OPEN_SHARE_DENOMINATOR
    return (
        f"rarity cap: open at {found.open_steps} of {STEPS} steps ({share:.2f}%; needs 1/{OPEN_SHARE_DENOMINATOR},"
        f" {needed:.2f}%), and closed {_duration(found.longest_closed)} running"
        f" (needs at most {_duration(LONGEST_CLOSED_STEPS)}) (DATA-R92)"
    )


def check_rarity_cap(
    hunts: HuntLayer, windows: Mapping[str, Mapping[str, object]], rules: Rules, problems: Problems
) -> None:
    """DATA-R92's rarity cap: a Hunt that isn't retired passes if its spec (the window's for a natural Hunt, its
    conditions for an imposed one) has auras; otherwise its time, season and events, events forecast from their
    weekly rules (DATA-R38), must be open at 1/7 or more of the rarity-cap span's steps or never closed more than 7
    days running (Tunables). Each spec's time is computed once per run. A Hunt whose window isn't one, whose
    conditions are invalid or whose events aren't all on the list has check_hunts' problem alone."""
    computed: dict[str, Openness] = {}
    for hunt in _current(hunts):
        spec: object = None
        if hunt.get("kind") == NATURAL and isinstance(hunt.get("window"), str):
            spec = windows.get(str(hunt.get("window")))
        elif hunt.get("kind") == IMPOSED:
            spec = hunt.get("conditions")
        if not isinstance(spec, Mapping) or "auras" in spec:
            continue
        events = spec.get("events")
        if isinstance(events, list) and any(event not in rules for event in events):
            continue
        time = {field: spec[field] for field in _TIME_FIELDS if field in spec}
        key = json.dumps(time, sort_keys=True)
        if key not in computed:
            computed[key] = openness(time, rules)
        if not computed[key].passes:
            problems.add(hunt.at, _cap_message(computed[key]))


def check_hunt_windows(
    hunts: HuntLayer,
    items: Mapping[int, Record],
    catch_lists: CatchLists,
    windows: Mapping[str, Mapping[str, object]],
    rules: Rules,
    problems: Problems,
) -> None:
    """Admission, then the rarity cap, for every Hunt that isn't retired (DATA-R92)."""
    check_admission(hunts, items, catch_lists, windows.keys(), problems)
    check_rarity_cap(hunts, windows, rules, problems)

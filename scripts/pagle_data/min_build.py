"""--min-build <n> (DATA-R57): the facts that would lose confirmation if only observations on builds >= n counted.

Launch re-verification (M8) uses it to see which facts rest on beta builds only. It compares the layers read with
the minimum confirming build (DATA-R46) against the same layers read with n, so every rule that reads observations
(observed pairs joining a list, DATA-R47; every confirmed flag, DATA-R48–R55) is applied the same way both times.
"""

from pagle_data.generate import Layers


def lost(now: Layers, then: Layers) -> list[str]:
    """One line per fact confirmed in now but not in then: pairs, gates, windows, weekly rules and skill bases, in
    that order, each ascending."""
    before, after = now.confirmation, then.confirmation
    lists_now, lists_then = now.catch_lists.windows(), then.catch_lists.windows()
    lines: list[str] = []
    for area, item in sorted(before.entries - after.entries):
        leaves = " (an observed pair: it would leave the list)" if item not in lists_then.get(area, {}) else ""
        lines.append(f"pair: item {item} in area {area}{leaves}")
    for area, item in sorted(before.gates - after.gates):
        lines.append(f"gate: item {item} in area {area} by {lists_now[area][item]}")
    lines += [f"window: {window}" for window in sorted(before.windows - after.windows)]
    lines += [f"weekly rule: event {event}" for event in sorted(before.weekly - after.weekly)]
    lines += [f"skill base: area {area}" for area in sorted(before.skill_bases - after.skill_bases)]
    return lines

"""data/forever/windows.toml for the generator's tests (DATA-R10, DATA-R36): spring and autumn, the two windows no
baseline event seeds, at their Tunables dates. With baseline_fixture's seed events and the Extravaganza's weekly
rule they give the windows below."""

from pathlib import Path

WINDOWS = """\
[window.spring]
season = [{ from = [3, 20], to = [6, 20] }]
why = "Tunables: spring window"

[window.autumn]
season = [{ from = [9, 23], to = [12, 20] }]
why = "Tunables: autumn window"
"""

# The windows those give, as the canonical JSON writes them (DATA-R70: each spec in full), for a fingerprint worked
# out by hand. The seeds are test_windows.py's (DATA-R36); event.301 is { events = { 301 } } (DATA-R37).
WINDOWS_JSON = (
    '"windows":{"autumn":{"confirmed":false,"spec":{"season":[{"from":[9,23],"to":[12,20]}]}},'
    '"day":{"confirmed":false,"spec":{"time":[[360,0]]}},"event.301":{"confirmed":false,"spec":{"events":[301]}},'
    '"night":{"confirmed":false,"spec":{"time":[[1080,720]]}},'
    '"spring":{"confirmed":false,"spec":{"season":[{"from":[3,20],"to":[6,20]}]}},'
    '"summer":{"confirmed":false,"spec":{"season":[{"from":[3,20],"to":[9,18]}]}},'
    '"winter":{"confirmed":false,"spec":{"season":[{"from":[9,23],"to":[3,24]}]}}}'
)

# The same windows in Catalogue.lua, written by hand from the Contracts section and DATA-R62: the local W of specs,
# emitted once before ns.catalogue, then the catalogue's windows field pointing at W's entries.
W_LUA = """\
local W = {
\tautumn = {
\t\tseason = {
\t\t\t{
\t\t\t\tfrom = { 9, 23 },
\t\t\t\tto = { 12, 20 },
\t\t\t},
\t\t},
\t},
\tday = {
\t\ttime = {
\t\t\t{ 360, 0 },
\t\t},
\t},
\t["event.301"] = {
\t\tevents = { 301 },
\t},
\tnight = {
\t\ttime = {
\t\t\t{ 1080, 720 },
\t\t},
\t},
\tspring = {
\t\tseason = {
\t\t\t{
\t\t\t\tfrom = { 3, 20 },
\t\t\t\tto = { 6, 20 },
\t\t\t},
\t\t},
\t},
\tsummer = {
\t\tseason = {
\t\t\t{
\t\t\t\tfrom = { 3, 20 },
\t\t\t\tto = { 9, 18 },
\t\t\t},
\t\t},
\t},
\twinter = {
\t\tseason = {
\t\t\t{
\t\t\t\tfrom = { 9, 23 },
\t\t\t\tto = { 3, 24 },
\t\t\t},
\t\t},
\t},
}
"""
WINDOWS_LUA = """\
\twindows = {
\t\tautumn = { confirmed = false, spec = W.autumn },
\t\tday = { confirmed = false, spec = W.day },
\t\t["event.301"] = { confirmed = false, spec = W["event.301"] },
\t\tnight = { confirmed = false, spec = W.night },
\t\tspring = { confirmed = false, spec = W.spring },
\t\tsummer = { confirmed = false, spec = W.summer },
\t\twinter = { confirmed = false, spec = W.winter },
\t},
"""


def write_windows(root: Path, text: str = WINDOWS) -> None:
    forever = root / "data" / "forever"
    forever.mkdir(parents=True, exist_ok=True)
    (forever / "windows.toml").write_text(text, encoding="utf-8")

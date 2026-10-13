"""data/forever/windows.toml for the generator's tests (DATA-R10, DATA-R36): spring and autumn, the two windows no
baseline event seeds, at their Tunables dates."""

from pathlib import Path

WINDOWS = """\
[window.spring]
season = [{ from = [3, 20], to = [6, 20] }]
why = "Tunables: spring window"

[window.autumn]
season = [{ from = [9, 23], to = [12, 20] }]
why = "Tunables: autumn window"
"""


def write_windows(root: Path, text: str = WINDOWS) -> None:
    forever = root / "data" / "forever"
    forever.mkdir(parents=True, exist_ok=True)
    (forever / "windows.toml").write_text(text, encoding="utf-8")

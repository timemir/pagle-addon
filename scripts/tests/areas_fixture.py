"""data/forever/areas.toml for the generator's tests (DATA-R10, DATA-R26–R30): a tree whose test isn't about catch
lists writes an empty one; test_catch_lists.py covers the file."""

from pathlib import Path


def write_areas(root: Path, text: str = "") -> None:
    forever = root / "data" / "forever"
    forever.mkdir(parents=True, exist_ok=True)
    (forever / "areas.toml").write_text(text, encoding="utf-8")

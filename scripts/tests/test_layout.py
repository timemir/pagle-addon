"""The real-font layout harness's Python half (scripts/measure-layout.py, pagle_data/layout.py): the committed advance
widths are what the bundled faces give, the allowlist loads and each entry carries a reason, and a finding is allowed
only where an entry covers every stop it's on."""

from pathlib import Path
from typing import Any

import pytest

from pagle_data import layout

REPO = Path(__file__).resolve().parents[2]


def finding(text: str, stop: str, kind: str = "cut", other: str | None = None) -> dict[str, Any]:
    return {"kind": kind, "text": text, "other": other, "stop": stop, "detail": "wider than its box: 9 wide in 8",
            "file": f"01-{stop}.jsonl"}


def test_advances_lua_is_what_the_bundled_faces_give() -> None:
    expected = layout.advances_lua(REPO / layout.FONTS_DIR)
    assert (REPO / layout.ADVANCES_LUA).read_text(encoding="utf-8") == expected, \
        "run .tools/bin/python scripts/measure-layout.py advances"


def test_a_face_without_cyrillic_measures_it_by_latin_look_alikes_marked_estimated() -> None:
    advances, estimated, line = layout.face_advances(REPO / layout.FONTS_DIR / "IMFeENrm28P.ttf")
    assert advances[ord("Ж")] == advances[ord("W")] and ord("Ж") in estimated
    assert ord("a") in advances and ord("a") not in estimated
    assert 1.0 < line < 1.5


def test_the_shipped_allowlist_loads_and_every_entry_has_a_reason() -> None:
    entries = layout.load_allowlist(REPO / "scripts/measure-layout/allowlist.toml")
    assert entries
    assert all(entry.reason and entry.kind in layout.KINDS for entry in entries)


def test_an_entry_without_a_reason_is_refused(tmp_path: Path) -> None:
    path = tmp_path / "allowlist.toml"
    path.write_text('[[allow]]\nkind = "cut"\ntext = "x"\n', encoding="utf-8")
    with pytest.raises(ValueError, match="needs a reason"):
        layout.load_allowlist(path)


def test_a_finding_is_allowed_only_where_an_entry_covers_every_stop_and_language() -> None:
    allow = [layout.Allow("cut", "Forelle*", "accepted", stop="hunts.trackerframe.*", languages=("deDE",))]
    covered = [finding("Forelle im Morgengrauen", "hunts.trackerframe.inkwash")]
    assert layout.group(covered, allow, "deDE")[0].allow is not None
    assert layout.group(covered, allow, "esES")[0].allow is None
    spread = covered + [finding("Forelle im Morgengrauen", "hunts.board.home")]
    groups = layout.group(spread, allow, "deDE")
    assert len(groups) == 1 and groups[0].allow is None
    assert groups[0].stops == ["hunts.trackerframe.inkwash", "hunts.board.home"]
    assert layout.report(groups, "deDE")[-1] == "deDE: 1 new finding, 0 allowed"

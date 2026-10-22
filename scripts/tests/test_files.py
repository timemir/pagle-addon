"""The file helpers every script writes through (DATA-R9, DATA-R11, DATA-R60, DATA-R12)."""

from pathlib import Path

import pytest

from pagle_data.files import csv_text, write_atomic


def test_csv_text_is_a_header_row_then_one_row_per_line() -> None:
    # DATA-R9 and DATA-R11: CSV files with a header row, one row per line; a cell with a comma is quoted.
    text = csv_text(("area", "name"), [(1, "Dun Morogh"), (453, "The Long Wash, north")])
    assert text == 'area,name\n1,Dun Morogh\n453,"The Long Wash, north"\n'


def test_write_atomic_replaces_the_file_whole_and_leaves_nothing_beside_it(tmp_path: Path) -> None:
    # DATA-R60 and DATA-R12 rewrite generated and data/db2/ files: an interrupted run never leaves half a file, so
    # the new content is written beside the file and moved over it.
    path = tmp_path / "data" / "db2" / "areas.csv"
    write_atomic(path, b"old\n")
    write_atomic(path, b"new\n")
    assert path.read_bytes() == b"new\n"
    assert sorted(p.name for p in path.parent.iterdir()) == ["areas.csv"]


@pytest.mark.parametrize("existing", [False, True])
def test_interrupted_write_preserves_the_destination(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, existing: bool,
) -> None:
    path = tmp_path / "areas.csv"
    if existing:
        path.write_bytes(b"original\n")
    write_bytes = Path.write_bytes

    def interrupted_write(target: Path, content: bytes) -> int:
        write_bytes(target, content[:2])
        raise OSError("interrupted write")

    monkeypatch.setattr(Path, "write_bytes", interrupted_write)
    with pytest.raises(OSError, match="interrupted write"):
        write_atomic(path, b"replacement\n")
    if existing:
        assert path.read_bytes() == b"original\n"
    else:
        assert not path.exists()

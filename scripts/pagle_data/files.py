"""The file helpers the scripts share: CSV text in data/'s shape, and writing a file whole."""

import csv
import io
import os
from collections.abc import Iterable, Sequence
from pathlib import Path

Cell = int | float | str | None


def csv_text(header: Sequence[str], rows: Iterable[Sequence[Cell]]) -> str:
    """A CSV file as data/ keeps them (DATA-R9, DATA-R11): the header row, then one row per line, "\\n"-ended."""
    out = io.StringIO()
    writer = csv.writer(out, lineterminator="\n")
    writer.writerow(header)
    writer.writerows(rows)
    return out.getvalue()


def write_atomic(path: Path, content: bytes) -> None:
    """Writes path whole: through a temporary file beside it, so an interrupted run never leaves half a file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    partial = path.with_name(path.name + ".partial")
    partial.write_bytes(content)
    os.replace(partial, path)

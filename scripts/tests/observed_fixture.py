"""A data/observed/ layer for the generator's tests (DATA-R8 order 4): dev.toml and reports/<reporterKey>.toml,
hand-made in the shapes of the Data section's data/observed/ table (DATA-R121, DATA-R122). Fixture rows live
only here, never in the committed data/observed/ (#94)."""

from pathlib import Path

# dev.toml with no keys and no facts: what a tree needs when its test isn't about this layer.
NO_FACTS = "keys = []\n"


def write_observed(root: Path, dev: str = NO_FACTS, reports: dict[str, str] | None = None) -> None:
    """Writes root/data/observed/dev.toml and, for each reporter key in reports, reports/<key>.toml."""
    observed = root / "data" / "observed"
    observed.mkdir(parents=True, exist_ok=True)
    (observed / "dev.toml").write_text(dev, encoding="utf-8")
    if reports:
        (observed / "reports").mkdir(exist_ok=True)
        for key, text in reports.items():
            (observed / "reports" / f"{key}.toml").write_text(text, encoding="utf-8")


def report(*rows: str, header: str = 'addon = "0.9.0"\ndata = "3f9a2c1e"\nlocale = "enUS"\n') -> str:
    """A reports/<key>.toml: issues, header, then the rows as given (each a [[i]], [[k]] or [[p]] table)."""
    return "issues = [101]\n\n[header]\n" + header + "".join(f"\n{row}" for row in rows)


def i_row(item: int, area: int, build: int = 70338, count: int = 1, extra: str = "") -> str:
    """An [[i]] row (REP-R20) with its required fields, plus extra lines."""
    return f"[[i]]\nitem = {item}\narea = {area}\nbuild = {build}\ncount = {count}\n{extra}"

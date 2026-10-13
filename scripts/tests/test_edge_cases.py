"""The generator's part in content-data.md's edge cases (DATA-R190–R197): an Uncharted item in a report (R196), an
item removed after release (R197) and a lore-only release (R191). Their runtime halves are LOG-R72's and the
Modules'. Over test_catch_lists.py's fixture tree, with hand-made data/observed/ rows (#94's fixture layer)."""

from pathlib import Path

import pytest

from observed_fixture import i_row, report
from pools_fixture import POOLS
from test_catch_lists import CATALOGUE, ITEMS, area_record, run, write_tree
from test_confirmed import ALICE

# 30002 is in no layer but a report: an item the client saw that Pagle doesn't know.
UNCHARTED = 30002
ROWS = {ALICE: report(i_row(UNCHARTED, 368))}


def items_part(text: str) -> str:
    return text[text.index("\titems = {") : text.index("\n\t},", text.index("\titems = {"))]


def test_an_uncharted_item_in_a_report_fails_until_it_is_categorised_or_deferred(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R196: a Field report brings an Uncharted item into the universe (DATA-R15), and the generator fails until
    # it is categorised (DATA-R17) or deferred (DATA-R18).
    code, output = run(write_tree(tmp_path / "new", reports=ROWS), capsys)
    assert code == 1
    assert f"data/forever/items.toml: item.{UNCHARTED}: no category" in output
    assert not (tmp_path / "new" / CATALOGUE).exists()

    deferred = ITEMS + f'\n[item.{UNCHARTED}]\ncategory = "uncharted"\nwhy = "can\'t classify it yet"\n'
    code, output = run(write_tree(tmp_path / "deferred", items=deferred, reports=ROWS), capsys)
    assert code == 0, output
    assert f"{UNCHARTED}" not in (tmp_path / "deferred" / CATALOGUE).read_text(encoding="utf-8")

    # Classified, it ships; one reporter is enough for an ordinary pair, so it joins Echo Isles' list (DATA-R47).
    classified = ITEMS + f'\n[item.{UNCHARTED}]\ncategory = "junk"\n'
    code, output = run(write_tree(tmp_path / "classified", items=classified, reports=ROWS), capsys)
    assert code == 0, output
    text = (tmp_path / "classified" / CATALOGUE).read_text(encoding="utf-8")
    assert f"[{UNCHARTED}] = {{ category = \"junk\"" in items_part(text)
    assert f"{{ confirmed = true, itemID = {UNCHARTED} }}" in area_record(text, 368)


def test_a_removed_item_leaves_every_list_but_keeps_its_record(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R197 (DATA-R23): 6303 is listed in Stranglethorn Vale (33, through reference table 500) and Jaguero Isle
    # (297), and a pool type adds it. Removed, it leaves both lists and the pool type, and keeps its record.
    pools = POOLS + "add = [6303]\n"
    root = write_tree(tmp_path / "listed")
    (root / "data" / "forever" / "pools.toml").write_text(pools, encoding="utf-8")
    code, output = run(root, capsys)
    assert code == 0, output
    text = (root / CATALOGUE).read_text(encoding="utf-8")
    assert "itemID = 6303" in area_record(text, 33)
    assert "itemID = 6303" in area_record(text, 297)
    assert "extravaganza = { 6303, 19807 }" in text

    removed = ITEMS.replace(
        '[item.6303]\ncategory = "fish"\n',
        '[item.6303]\ncategory = "fish"\nremoved = true\nremovedFrom = 70338\nwhy = "proven gone"\n',
    )
    root = write_tree(tmp_path / "removed", items=removed)
    (root / "data" / "forever" / "pools.toml").write_text(pools, encoding="utf-8")
    code, output = run(root, capsys)
    assert code == 0, output
    text = (root / CATALOGUE).read_text(encoding="utf-8")
    assert "itemID = 6303" not in text
    assert "extravaganza = { 19807 }" in text
    assert '[6303] = { category = "fish", legend = false, noise = false, pool = false, removed = true' in (
        items_part(text)
    )


def test_a_lore_only_change_leaves_the_catalogue_and_its_fingerprint_alone(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # DATA-R191: a lore-only release rebuilds nothing, so nothing under data/lore/ (DATA-R100) is part of the
    # catalogue or its fingerprint (DATA-R70).
    root = write_tree(tmp_path)
    run(root, capsys)
    before = (root / CATALOGUE).read_bytes()
    lore = root / "data" / "lore"
    lore.mkdir(parents=True)
    (lore / "core.toml").write_text('[enUS]\n"family.1.name" = "Groupers"\n', encoding="utf-8")
    code, output = run(root, capsys, "--check")
    assert code == 0, output
    (lore / "core.toml").write_text('[enUS]\n"family.1.name" = "Big groupers"\n', encoding="utf-8")
    code, output = run(root, capsys)
    assert code == 0, output
    assert (root / CATALOGUE).read_bytes() == before

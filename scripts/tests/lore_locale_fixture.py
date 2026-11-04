"""Fixture trees for a Locale's Lore (DATA-R104, DATA-R114): data/lore/<code>/<lore ID>.toml over test_lore.py's English
ledger, with the data/locale/ files that register the code. Nothing here ships: the repository holds no translation."""

from collections.abc import Mapping
from dataclasses import replace
from pathlib import Path

from locale_fixture import SPANISH_HEADER, english, spanish, write_locales
from pagle_data.errors import Problems
from pagle_data.lore import LoreLayer, Text, check_glyphs, check_translations, read_lore
from test_lore import LEDGER, OFF, write_lore_tree

LORE_ES_LUA = "addons/Pagle_Ledger/data/Lore.esES.lua"
LEDGER_LORE = "data/lore/esES/ledger.toml"

# A part of the English ledger translated into Spanish, each field with the snapshot of the English beside it
# (test_lore.LEDGER): the keys it lacks (the other riddle, the blurbs, the sub, the family and the rest) show English.
ES_LEDGER = """\
# Fixture: a Spanish translation of some of the ledger's Lore.
[species.13759.riddle]
value = "Pica donde el agua corre perezosa."
en = "Bites where the water runs lazy."

[legend.19807.title]
value = "El Sabrosón"
en = "The Tasty One"

[title.level1.text]
value = "Novato"
en = "Greenhorn"

[title.zonemaster.text]
value = "Maestro de {zone}"
en = "Master of {zone}"
"""


def field(value: str, en: str) -> str:
    """One translated field's table (DATA-R114)."""
    return f'value = "{value}"\nen = "{en}"\n'


def entry(key: str, value: str, en: str) -> str:
    """A translated field under its key, `species.13759.riddle`: the TOML table [species.13759.riddle]; an ID with dots
    is written quoted by the caller, as in `good."core.a".name`."""
    return f"[{key}]\n{field(value, en)}\n"


def registering_locales(*codes: str, addons: tuple[str, ...] = ("ledger",)) -> dict[str, dict[str, str]]:
    """The data/locale/ trees that register each code for the addons (the ledger by default): English, and a Spanish
    (esES) or Mexican (esMX, falling back to esES) header with an empty interface file per addon, which is all a Lore
    file needs of them."""
    trees: dict[str, dict[str, str]] = {"enUS": english()}
    for code in codes:
        files = spanish(hunts=None)
        if code == "esMX":
            files["locale.toml"] = 'name = "Español (México)"\nlisted = false\nfallback = "esES"\ndecimal = "."\n'
        else:
            files["locale.toml"] = SPANISH_HEADER
        for addon in addons:
            files[f"{addon}.toml"] = ""
        trees[code] = files
    return trees


def write_translations(root: Path, translations: Mapping[str, Mapping[str, str]]) -> Path:
    """data/lore/<code>/<lore ID>.toml for each code's files."""
    for code, files in translations.items():
        directory = root / "data" / "lore" / code
        directory.mkdir(parents=True, exist_ok=True)
        for lore_id, text in files.items():
            (directory / f"{lore_id}.toml").write_text(text, encoding="utf-8")
    return root


def write_tree(
    root: Path,
    translations: Mapping[str, Mapping[str, str]] | None = None,
    ledger: str = LEDGER,
    checks: str = OFF,
    registering: tuple[str, ...] | None = None,
    addons: tuple[str, ...] = ("ledger",),
    **lore: str,
) -> Path:
    """test_lore's English tree, the Locales that register each code translated (or the `registering` codes) for the
    `addons`, and the translations by code and lore ID."""
    translations = {"esES": {"ledger": ES_LEDGER}} if translations is None else translations
    write_lore_tree(root, ledger, checks=checks, **lore)
    codes = tuple(translations) if registering is None else registering
    write_locales(root, registering_locales(*codes, addons=addons))
    return write_translations(root, translations)


def read(
    root: Path,
    translations: Mapping[str, Mapping[str, str]],
    english_files: Mapping[str, str] | None = None,
    hunts: Mapping[str, str] | None = None,
    events: Mapping[str, Mapping[str, str]] | None = None,
) -> tuple[LoreLayer, Problems]:
    """The lore layer at root with english_files (by lore ID; the English ledger by default) and translations written,
    read and checked as the generator does (shape, glyphs, then the translations). hunts and events are the
    Hunt-and-set text and each event file's text, by key and value, as the Hunt and event layers give them."""
    english_files = {"ledger": LEDGER} if english_files is None else english_files
    directory = root / "data" / "lore"
    directory.mkdir(parents=True, exist_ok=True)
    for lore_id, text in english_files.items():
        (directory / f"{lore_id}.toml").write_text(text, encoding="utf-8")
    write_translations(root, translations)
    problems = Problems()
    layer = read_lore(root, problems)

    def texts(values: Mapping[str, str]) -> dict[str, Text]:
        found = {}
        for key, value in values.items():
            kind, rest = key.split(".", 1)
            id_, name = rest.rsplit(".", 1)
            found[key] = Text(kind, id_, name, value)
        return found

    layer = replace(
        layer,
        hunts=texts(hunts or {}),
        events={file: texts(values) for file, values in (events or {}).items()},
    )
    check_glyphs(layer, problems)
    check_translations(layer, problems)
    return layer, problems


def judged(root: Path, es_ledger: str) -> list[str]:
    """The problems found in a Spanish ledger translation over the English ledger."""
    return read(root, {"esES": {"ledger": es_ledger}})[1].found

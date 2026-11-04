"""Fixture data/locale/ trees (DATA-R114): a small English, a Spanish and a Russian Locale that are never shipped, and a
helper that reads and checks a tree the way the generator does."""

from collections.abc import Mapping
from pathlib import Path

from pagle_data.errors import Problems
from pagle_data.locale import LocaleLayer, check_locale, read_locale

ENGLISH_HEADER = 'name = "English"\nplural = "one_other"\ndecimal = "."\nthousands = ","\n'

# English: a plain string, a counted string, an array, a table with whole-number keys, a string with a line break and
# a string with fields. Every addon has a file; only Core's and Hunts' hold keys.
CORE = """\
# Core's text.
TITLE = "Pagle"
GREETING = "Hello, {name}"
FISH_COUNT.one = "{count} fish"
FISH_COUNT.other = "{count} fishes"
BANDS = ["Small", "Big"]
CONTINENTS.0 = "Eastern Kingdoms"
CONTINENTS.1 = "Kalimdor"
SEAL = "%s\\nof %s"
WEIGHT = "{weight:1} kg, {{literal}}"
"""
HUNTS = 'HUNTS_ONLY = "Hunts"\n'
OTHER = ""


def english(core: str = CORE, hunts: str = HUNTS) -> dict[str, str]:
    """data/locale/enUS/'s files by name."""
    return {
        "locale.toml": ENGLISH_HEADER,
        "core.toml": core,
        "hunts.toml": hunts,
        "ledger.toml": OTHER,
        "qol.toml": OTHER,
        "stats.toml": OTHER,
        "tackleboard.toml": OTHER,
    }


SPANISH_HEADER = (
    'name = "Español"\ntranslators = ["Ana", "Luis"]\nlisted = false\nplural = "one_many_other"\ndecimal = ","\n'
    'thousands = "."\n'
)

# A whole Spanish core.toml: every key of CORE, each with its EN snapshot.
SPANISH_CORE = """\
[TITLE]
value = "Pagle"
en = "Pagle"

[GREETING]
value = "Hola, {name}"
en = "Hello, {name}"

[FISH_COUNT]
value.one = "{count} pez"
value.many = "{count} de peces"
value.other = "{count} peces"
en.one = "{count} fish"
en.other = "{count} fishes"

[BANDS]
value = ["Pequeño", "Grande"]
en = ["Small", "Big"]

[CONTINENTS]
value.0 = "Reinos del Este"
value.1 = "Kalimdor"
en.0 = "Eastern Kingdoms"
en.1 = "Kalimdor"

[SEAL]
value = "%s\\nde %s"
en = "%s\\nof %s"

[WEIGHT]
value = "{weight:1} kg, {{literal}}"
en = "{weight:1} kg, {{literal}}"
"""
SPANISH_HUNTS = '[HUNTS_ONLY]\nvalue = "Cacerías"\nen = "Hunts"\n'


def spanish(core: str = SPANISH_CORE, header: str = SPANISH_HEADER, hunts: str | None = SPANISH_HUNTS) -> dict[str, str]:
    """data/locale/esES/'s files by name; Spanish translates only Core and Hunts here, so it is complete only where a
    test says so."""
    files = {"locale.toml": header, "core.toml": core}
    if hunts is not None:
        files["hunts.toml"] = hunts
    return files


RUSSIAN_HEADER = (
    'name = "Русский"\nlisted = false\nplural = "one_few_many_other"\ndecimal = ","\nthousands = " "\n'
)
RUSSIAN_CORE = """\
[FISH_COUNT]
value.one = "{count} рыба"
value.few = "{count} рыбы"
value.many = "{count} рыб"
value.other = "{count} рыбы"
en.one = "{count} fish"
en.other = "{count} fishes"
"""


def write_locales(root: Path, trees: Mapping[str, Mapping[str, str]]) -> Path:
    """data/locale/<code>/<name> for each code's files."""
    for code, files in trees.items():
        directory = root / "data" / "locale" / code
        directory.mkdir(parents=True, exist_ok=True)
        for name, text in files.items():
            (directory / name).write_text(text, encoding="utf-8")
    return root


def checked(
    root: Path,
    trees: Mapping[str, Mapping[str, str]],
    listed_before: Mapping[str, bool] | None = None,
) -> tuple[list[str], list[str], LocaleLayer]:
    """Writes the trees, reads and checks them: the problems found, the warnings, and the layer."""
    write_locales(root, trees)
    problems = Problems()
    layer = read_locale(root, problems)
    check_locale(layer, problems, listed_before)
    return problems.found, layer.warnings, layer


def with_spanish(
    root: Path, core: str = SPANISH_CORE, header: str = SPANISH_HEADER, hunts: str | None = SPANISH_HUNTS
) -> tuple[list[str], list[str], LocaleLayer]:
    return checked(root, {"enUS": english(), "esES": spanish(core, header, hunts)})

"""The repository's own translations against today's English (DATA-R114, docs/translations.md › Drift): a warning for
each stale string, and never a failure. English may change at any time; a translator catches up later, and a change to
English never waits for one. `generate-data.py --stale` lists the same strings, and `--drop-stale` drops those whose
{fields} changed in the pull request that changes English."""

import warnings
from pathlib import Path

from pagle_data.drift import find_stale, read_sources, stale_warning

ROOT = Path(__file__).resolve().parents[2]


class StaleTranslation(UserWarning):
    """A translated string whose EN snapshot is not today's English."""


def test_every_stale_translation_warns_and_none_fails() -> None:
    sources = read_sources(ROOT)
    assert not sources.problems, sources.problems.found  # the sources read; what they say is the generator's checks'
    with warnings.catch_warnings():
        warnings.simplefilter("always")  # a warning here is never turned into an error by -W error
        for item in find_stale(sources):
            warnings.warn(stale_warning(item), StaleTranslation, stacklevel=1)

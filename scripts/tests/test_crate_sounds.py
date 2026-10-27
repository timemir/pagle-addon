"""The Curio crate's sounds (scripts/render-crate-sounds.py, pagle_data/crate_sounds.py): one file for each beat, mono 44.1 kHz
Ogg Vorbis, short, small in all, named by data/CrateSounds.lua, and each the render's output to the encoder's noise (Vorbis isn't
byte-stable, so a file is held, as tests/test_repo_sounds.py holds the sets', to within 0.5 dB of the error this machine's own
encode of the render has)."""

import io
import re
from pathlib import Path

import numpy as np
import pytest
import soundfile as sf
from sounds_fixture import read_sound

from pagle_data.crate_sounds import BEATS, SOUNDS_DIR, SOUNDS_LUA, render_all
from pagle_data.sounds import PEAK_DB, PEAK_MARGIN_DB, SAMPLE_RATE, Signal

REPO = Path(__file__).resolve().parents[2]
FOLDER = REPO / SOUNDS_DIR
BUDGET_BYTES = 1_500_000  # all of them (the brief's ~1.5 MB; they come to a fifth of it)
FILE_BYTES = 64_000
LONGEST_SECONDS = 4.0  # the Curio sting, which is the longest beat (its bell rings 2.6 s) and its room
SHORTEST_SECONDS = 0.1
EXPECTED = sorted(f"{name}.ogg" for name in BEATS)


def _snr_db(reference: Signal, x: Signal) -> float:
    return float(10 * np.log10((reference**2).sum() / max(((reference - x) ** 2).sum(), 1e-30)))


def test_the_committed_sounds_are_exactly_the_beats() -> None:
    assert sorted(p.name for p in FOLDER.iterdir()) == EXPECTED
    for name in (
        "crate_land", "crate_knock_1", "crate_knock_2", "crate_knock_3", "seal_crack", "straps_snap", "lid_whoosh", "reel_open",
        "card_tick_1", "card_land", "card_turn", "sting_1", "sting_2", "sting_3", "sting_4", "sting_5", "sting_6", "sting_curio",
        "payback",
    ):  # fmt: skip
        assert name in BEATS, name


@pytest.mark.parametrize("name", EXPECTED)
def test_each_sound_is_mono_44_1_khz_ogg_vorbis_short_quiet_enough_and_not_silent(name: str) -> None:
    path = FOLDER / name
    info = sf.info(path)
    assert (info.format, info.subtype, info.channels, info.samplerate) == ("OGG", "VORBIS", 1, SAMPLE_RATE)
    assert SHORTEST_SECONDS <= info.duration <= LONGEST_SECONDS, f"{info.duration:.2f} s"
    assert path.stat().st_size <= FILE_BYTES
    samples = read_sound(path)
    peak = 20 * np.log10(np.abs(samples).max())
    assert -40 < peak < PEAK_DB, f"{name}: peak {peak:.2f} dBFS"  # the loudest sits at -1.3: Vorbis may not take it over -1


def test_all_the_sounds_together_are_within_budget() -> None:
    assert sum(p.stat().st_size for p in FOLDER.iterdir()) <= BUDGET_BYTES


def test_the_lua_table_names_each_file_once_under_media_crate_sounds() -> None:
    text = (REPO / SOUNDS_LUA).read_text(encoding="utf-8")
    assert 'local DIR = "Interface\\\\AddOns\\\\Pagle\\\\media\\\\crate\\\\sounds\\\\"' in text
    named = re.findall(r'DIR \.\. "([\w]+\.ogg)"', text)
    assert sorted(named) == sorted(set(named)), "a file is named twice"
    assert sorted(named) == EXPECTED


@pytest.fixture(scope="module")
def renders() -> dict[str, Signal]:
    return render_all()


def test_a_render_is_the_same_every_time(renders: dict[str, Signal]) -> None:
    again = render_all()
    assert all(np.array_equal(renders[name], again[name]) for name in renders)


@pytest.mark.parametrize("name", sorted(BEATS))
def test_each_committed_sound_is_what_the_render_renders(name: str, renders: dict[str, Signal]) -> None:
    signal = renders[name].astype(np.float32).astype(np.float64)
    encoded = io.BytesIO()
    sf.write(encoded, signal.astype(np.float32), SAMPLE_RATE, format="OGG", subtype="VORBIS")
    encoded.seek(0)
    ours = read_sound(encoded)
    committed = read_sound(FOLDER / f"{name}.ogg")
    assert len(committed) == len(signal)
    assert _snr_db(signal, committed) >= _snr_db(signal, ours) - 0.5


def test_the_levels_between_the_sounds_are_the_prototype_s(renders: dict[str, Signal]) -> None:
    # One gain for all: the loudest is at the peak limit less Vorbis's margin, and a tick (noise .22 through a narrow band)
    # is well under the thud (tone .7, noise .5), as in the prototype.
    peak = {name: float(np.abs(x).max()) for name, x in renders.items()}
    assert max(peak.values()) == pytest.approx(10 ** ((PEAK_DB - PEAK_MARGIN_DB) / 20), rel=1e-4)
    assert peak["card_tick_1"] < peak["crate_land"] / 5
    assert peak["crate_knock_1"] < peak["crate_knock_2"] < peak["crate_knock_3"]  # each rattle harder
    assert [round(peak[f"sting_{n}"], 2) for n in (1, 2)] == sorted(round(peak[f"sting_{n}"], 2) for n in (1, 2))

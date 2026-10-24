"""Pagle's Announcement sounds, rendered by scripts/render-sounds.py (ANN-R72, ANN-R74)."""

from pathlib import Path

import numpy as np
import pytest
from sounds_fixture import EXPANSION_SETS, LEGEND_ITEMS, RENDERED_FILES, check_sound, read_sound

from pagle_data.sounds import NOTES, SOUND_FILES, Signal, hz, loudness, render


@pytest.fixture(scope="module")
def rendered(tmp_path_factory: pytest.TempPathFactory) -> Path:
    out = tmp_path_factory.mktemp("sounds")
    render(out)
    return out


def _files(folder: Path) -> list[str]:
    return sorted(path.relative_to(folder).as_posix() for path in folder.rglob("*") if path.is_file())


def _all_differ(sounds: list[Signal]) -> bool:
    for i, a in enumerate(sounds):
        for b in sounds[i + 1 :]:
            n = min(len(a), len(b))
            if np.allclose(a[:n], b[:n], atol=0.01):
                return False
    return True


def test_the_render_writes_exactly_the_files_ann_r74_lists(rendered: Path) -> None:
    # ANN-R74: "It renders every sound set but the generated ones, and every Legend sting", as "<set>/toast_<n>.ogg and banner.ogg" and
    # "legend/<itemID>.ogg".
    assert _files(rendered) == RENDERED_FILES
    assert sorted(SOUND_FILES) == RENDERED_FILES


def test_loudness_is_the_rms_of_the_audible_part_and_the_peak_in_dbfs() -> None:
    # ANN-R74's loudness target is measured this way. A sine of amplitude 0.5 has an RMS of 0.5 / sqrt(2), -9.03 dBFS,
    # and a peak of -6.02 dBFS; the silence after it isn't audible, so it doesn't lower the RMS.
    t = np.arange(44100) / 44100
    sine = np.concatenate([0.5 * np.sin(2 * np.pi * 440 * t), np.zeros(44100)])
    rms, peak = loudness(sine)
    assert rms == pytest.approx(-9.03, abs=0.01)
    assert peak == pytest.approx(-6.02, abs=0.01)


def test_the_expansion_s_notes_are_equal_tempered_from_a4() -> None:
    # ANN-R74's sets play in tune with each other: A4 is 440 Hz, an octave doubles it, and the expansion's D major
    # notes land on Driftwood's.
    assert hz("A4") == 440.0
    assert hz("A5") == 880.0
    assert hz("A3") == 220.0
    for note, frequency in NOTES.items():
        assert hz(note) == pytest.approx(frequency, abs=0.01)


@pytest.mark.parametrize("name", RENDERED_FILES)
def test_each_file_is_mono_44_1_khz_ogg_vorbis_at_the_loudness_target(rendered: Path, name: str) -> None:
    # ANN-R74: mono, 44.1 kHz, .ogg, loudness-matched; Tunables: -20 dBFS RMS, -1 dBFS peak.
    check_sound(rendered / name)


def test_driftwood_s_three_toast_variants_differ(rendered: Path) -> None:
    # ANN-R72: Driftwood's toast rotates through 3 variants "so back-to-back toasts never sound the same".
    assert _all_differ([read_sound(rendered / f"driftwood/toast_{n}.ogg") for n in (1, 2, 3)])


@pytest.mark.parametrize("folder", EXPANSION_SETS)
def test_each_expansion_set_s_three_toast_variants_differ(rendered: Path, folder: str) -> None:
    # ANN-R72: each of the expansion's sets has "three toast variants, rotated", as Driftwood's are.
    assert _all_differ([read_sound(rendered / f"{folder}/toast_{n}.ogg") for n in (1, 2, 3)])


@pytest.mark.parametrize("item", LEGEND_ITEMS)
def test_each_legend_sting_lasts_about_3_seconds(rendered: Path, item: int) -> None:
    # ANN-R72, Tunables: each Legend's sting is about 3 s (the ticket's bound: 2.5-3.5 s).
    assert 2.5 <= len(read_sound(rendered / f"legend/{item}.ogg")) / 44100 <= 3.5


def test_each_legend_has_a_sting_of_its_own(rendered: Path) -> None:
    # ANN-R72: "Each Legend has its own sting".
    assert _all_differ([read_sound(rendered / f"legend/{item}.ogg") for item in LEGEND_ITEMS])

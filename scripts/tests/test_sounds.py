"""Pagle's Announcement sounds, rendered by scripts/render-sounds.py (ANN-R72, ANN-R74)."""

from pathlib import Path

import numpy as np
import pytest
from sounds_fixture import ANN_R74_FILES, check_sound, read_sound

from pagle_data.sounds import SOUND_FILES, loudness, render


@pytest.fixture(scope="module")
def rendered(tmp_path_factory: pytest.TempPathFactory) -> Path:
    out = tmp_path_factory.mktemp("sounds")
    render(out)
    return out


def _files(folder: Path) -> list[str]:
    return sorted(path.relative_to(folder).as_posix() for path in folder.rglob("*") if path.is_file())


def test_the_render_writes_exactly_the_files_ann_r74_lists(rendered: Path) -> None:
    # ANN-R74: "<set>/toast_<n>.ogg and banner.ogg (<set> is driftwood or gilded), plus the shared legend.ogg".
    assert _files(rendered) == ANN_R74_FILES
    assert sorted(SOUND_FILES) == ANN_R74_FILES


def test_loudness_is_the_rms_of_the_audible_part_and_the_peak_in_dbfs() -> None:
    # ANN-R74's loudness target is measured this way. A sine of amplitude 0.5 has an RMS of 0.5 / sqrt(2), -9.03 dBFS,
    # and a peak of -6.02 dBFS; the silence after it isn't audible, so it doesn't lower the RMS.
    t = np.arange(44100) / 44100
    sine = np.concatenate([0.5 * np.sin(2 * np.pi * 440 * t), np.zeros(44100)])
    rms, peak = loudness(sine)
    assert rms == pytest.approx(-9.03, abs=0.01)
    assert peak == pytest.approx(-6.02, abs=0.01)


@pytest.mark.parametrize("name", ANN_R74_FILES)
def test_each_file_is_mono_44_1_khz_ogg_vorbis_at_the_loudness_target(rendered: Path, name: str) -> None:
    # ANN-R74: mono, 44.1 kHz, .ogg, loudness-matched; Tunables: -20 dBFS RMS, -1 dBFS peak.
    check_sound(rendered / name)


def test_driftwood_s_three_toast_variants_differ(rendered: Path) -> None:
    # ANN-R72: Driftwood's toast rotates through 3 variants "so back-to-back toasts never sound the same".
    toasts = [read_sound(rendered / f"driftwood/toast_{n}.ogg") for n in (1, 2, 3)]
    for i, a in enumerate(toasts):
        for b in toasts[i + 1 :]:
            n = min(len(a), len(b))
            assert not np.allclose(a[:n], b[:n], atol=0.01)


def test_the_legend_sting_lasts_about_3_seconds(rendered: Path) -> None:
    # ANN-R72, Tunables: the Legend sting is about 3 s (the ticket's bound: 2.5-3.5 s).
    assert 2.5 <= len(read_sound(rendered / "legend.ogg")) / 44100 <= 3.5

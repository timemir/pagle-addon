"""The committed sounds in addons/Pagle/media/sounds/ (ANN-R74). check.sh doesn't re-render them, since Vorbis output
isn't byte-stable; it checks what ships instead: the file list, the format and the loudness."""

from pathlib import Path

import pytest
from sounds_fixture import ANN_R74_FILES, check_sound

SOUNDS = Path(__file__).resolve().parents[2] / "addons/Pagle/media/sounds"


def test_the_committed_sounds_are_exactly_the_files_ann_r74_lists() -> None:
    # ANN-R74: the render's output is committed under addons/Pagle/media/sounds/, and nothing else is there.
    assert sorted(path.relative_to(SOUNDS).as_posix() for path in SOUNDS.rglob("*") if path.is_file()) == ANN_R74_FILES


@pytest.mark.parametrize("name", ANN_R74_FILES)
def test_each_committed_sound_is_mono_44_1_khz_ogg_vorbis_at_the_loudness_target(name: str) -> None:
    # ANN-R74: mono, 44.1 kHz, .ogg, loudness-matched; Tunables: -20 dBFS RMS, -1 dBFS peak.
    check_sound(SOUNDS / name)

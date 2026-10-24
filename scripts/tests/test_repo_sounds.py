"""The committed sounds in addons/Pagle/media/sounds/ (ANN-R74). check.sh doesn't re-render them into the tree, since
Vorbis output isn't byte-stable; it checks what ships instead: the file list, the format and the loudness, and that
each file is the render's output, to the encoder's noise."""

import io
import tomllib
from pathlib import Path

import numpy as np
import pytest
import soundfile as sf
from sounds_fixture import ANN_R74_FILES, GENERATED_SETS, SOURCED_SETS, check_sound, read_sound

from pagle_data.sounds import SAMPLE_RATE, SOUND_FILES, Signal, loudness

REPO = Path(__file__).resolve().parents[2]
SOUNDS = REPO / "addons/Pagle/media/sounds"


def _snr_db(reference: Signal, x: Signal) -> float:
    return float(10 * np.log10((reference**2).sum() / max(((reference - x) ** 2).sum(), 1e-30)))


def test_the_committed_sounds_are_exactly_the_files_ann_r74_lists() -> None:
    # ANN-R74: the render's output is committed under addons/Pagle/media/sounds/, and nothing else is there.
    assert sorted(path.relative_to(SOUNDS).as_posix() for path in SOUNDS.rglob("*") if path.is_file()) == ANN_R74_FILES


@pytest.mark.parametrize("name", ANN_R74_FILES)
def test_each_committed_sound_is_mono_44_1_khz_ogg_vorbis_at_the_loudness_target(name: str) -> None:
    # ANN-R74: mono, 44.1 kHz, .ogg, loudness-matched; Tunables: -20 dBFS RMS, -1 dBFS peak.
    check_sound(SOUNDS / name)


@pytest.mark.parametrize("name", sorted(SOUND_FILES))
def test_each_committed_sound_is_what_render_sounds_renders(name: str) -> None:
    # ANN-R74: every sound file is rendered by scripts/render-sounds.py, "nothing is rendered by hand or elsewhere".
    # The committed file has the render's length and loudness, and is as far from the render as the encoder allows:
    # Vorbis on another machine rounds a little differently, so the file is held to within 0.5 dB of the error this
    # machine's own encode of the render has.
    signal = SOUND_FILES[name]().astype(np.float32).astype(np.float64)
    encoded = io.BytesIO()
    sf.write(encoded, signal.astype(np.float32), SAMPLE_RATE, format="OGG", subtype="VORBIS")
    encoded.seek(0)
    ours = read_sound(encoded)
    committed = read_sound(SOUNDS / name)
    assert len(committed) == len(signal)
    assert loudness(committed)[0] == pytest.approx(loudness(ours)[0], abs=0.05)
    assert _snr_db(signal, committed) >= _snr_db(signal, ours) - 0.5


def test_every_sound_is_rendered_or_one_of_the_generated_sets() -> None:
    # ANN-R74: the files the render doesn't make are the generated sets', each folder named in GENERATED_SETS.
    rendered = {name.split("/")[0] for name in SOUND_FILES}
    committed = {name.split("/")[0] for name in ANN_R74_FILES}
    assert committed - rendered == set(GENERATED_SETS)


@pytest.mark.parametrize("folder", SOURCED_SETS)
def test_each_generated_set_has_its_sources_committed(folder: str) -> None:
    # ANN-R74: a generated set's prompts and raw takes are committed, since a generation can't be repeated. A file is
    # a whole take, or a mix of parts (each with a prompt and its picked take) and the game's own clips.
    source = REPO / "data/sounds/generated" / folder
    spec = tomllib.loads((source / "set.toml").read_text(encoding="utf-8"))
    files, parts = spec["file"], spec.get("part", {})
    assert sorted(files) == ["banner", "toast_1", "toast_2", "toast_3"]
    for name, file in files.items():
        if "mix" not in file:
            assert file["prompt"], name
            assert (source / "raw" / name / f"take_{file['pick']}.mp3").is_file(), name
            continue
        assert file["mix"], name
        for entry in file["mix"]:
            if "part" in entry:
                take = source / "raw" / entry["part"] / f"take_{entry.get('pick', 'a')}.mp3"
                assert take.is_file(), f"{name}: {take}"
                assert parts.get(entry["part"], {}).get("prompt") or entry["part"] in files, f"{name}: {entry['part']}"
            else:
                assert entry["clip"].startswith("creature/") or entry["clip"].startswith("character/"), name

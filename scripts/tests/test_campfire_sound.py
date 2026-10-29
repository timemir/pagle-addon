"""The Campfire card's opening sound (scripts/render-campfire-sound.py, pagle_data/campfire_sound.py): one mono 44.1 kHz Ogg
Vorbis file of about 1.9 s, quiet enough and not silent, a soft whoosh and then crackle fading out, and the render's output
to the encoder's noise (Vorbis isn't byte-stable, so it is held, as tests/test_crate_sounds.py holds the crate's, to within
0.5 dB of the error this machine's own encode of the render has)."""

import io
from pathlib import Path

import numpy as np
import soundfile as sf
from sounds_fixture import read_sound

from pagle_data.campfire_sound import SOUND, render
from pagle_data.sounds import PEAK_DB, PEAK_MARGIN_DB, SAMPLE_RATE, Signal

REPO = Path(__file__).resolve().parents[2]
FILE_BYTES = 64_000


def _rms_db(x: Signal) -> float:
    return float(20 * np.log10(np.sqrt((x**2).mean()) + 1e-12))


def _snr_db(reference: Signal, x: Signal) -> float:
    return float(10 * np.log10((reference**2).sum() / max(((reference - x) ** 2).sum(), 1e-30)))


def test_the_sound_is_mono_44_1_khz_ogg_vorbis_about_two_seconds_small_and_under_the_peak_limit() -> None:
    path = REPO / SOUND
    info = sf.info(path)
    assert (info.format, info.subtype, info.channels, info.samplerate) == ("OGG", "VORBIS", 1, SAMPLE_RATE)
    assert 1.7 <= info.duration <= 2.1, f"{info.duration:.2f} s"
    assert path.stat().st_size <= FILE_BYTES
    peak = 20 * np.log10(np.abs(read_sound(path)).max())
    assert -12 < peak < PEAK_DB - PEAK_MARGIN_DB + 0.3, f"peak {peak:.2f} dBFS"


def test_it_is_a_whoosh_then_crackle_fading_out() -> None:
    samples = read_sound(REPO / SOUND)
    second = SAMPLE_RATE // 10
    blocks = [samples[i : i + second] for i in range(0, len(samples) - second + 1, second)]
    # The catch is a steady body of sound (its blocks are never near-silent), the crackle is pops (quiet between them, the
    # peaks standing well over the body), and the last block has faded away.
    assert all(_rms_db(b) > -40 for b in blocks[:3])
    crackle = blocks[4:14]
    assert sum(1 for b in crackle if np.abs(b).max() > 10 ** (-24 / 20)) >= 6, "the crackle has gone quiet"
    assert _rms_db(blocks[-1]) < _rms_db(blocks[3]) - 20
    assert _rms_db(blocks[-1]) < -60


def test_a_render_is_the_same_every_time() -> None:
    assert np.array_equal(render(), render())


def test_the_committed_sound_is_what_the_render_renders() -> None:
    signal = render().astype(np.float32).astype(np.float64)
    encoded = io.BytesIO()
    sf.write(encoded, signal.astype(np.float32), SAMPLE_RATE, format="OGG", subtype="VORBIS")
    encoded.seek(0)
    ours = read_sound(encoded)
    committed = read_sound(REPO / SOUND)
    assert len(committed) == len(signal)
    assert _snr_db(signal, committed) >= _snr_db(signal, ours) - 0.5

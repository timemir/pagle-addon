"""Checks one sound file against ANN-R74, for the render's tests and the committed files' tests alike."""

from pathlib import Path

import numpy as np
import soundfile as sf

from pagle_data.sounds import Signal, loudness

# ANN-R74's layout, written out here as the spec gives it: Driftwood's three toast variants (Tunables: Driftwood
# toast variants = 3) and its banner, Gilded's one toast and banner (ANN-R72), and the shared Legend sting.
ANN_R74_FILES = [
    "driftwood/banner.ogg",
    "driftwood/toast_1.ogg",
    "driftwood/toast_2.ogg",
    "driftwood/toast_3.ogg",
    "gilded/banner.ogg",
    "gilded/toast_1.ogg",
    "legend.ogg",
]


def read_sound(path: Path) -> Signal:
    samples, _ = sf.read(path, dtype="float64")
    return np.asarray(samples, dtype=np.float64)


def check_sound(path: Path) -> None:
    # ANN-R74: mono, 44.1 kHz, .ogg (Vorbis), loudness-matched; Tunables: -20 dBFS RMS, -1 dBFS peak. The ticket
    # allows 0.5 dB either side of the RMS target, measured on the decoded file.
    info = sf.info(path)
    assert (info.format, info.subtype, info.channels, info.samplerate) == ("OGG", "VORBIS", 1, 44100)
    rms, peak = loudness(read_sound(path))
    assert abs(rms - -20.0) <= 0.5, f"{path.name}: RMS {rms:.2f} dBFS"
    assert peak < -1.0, f"{path.name}: peak {peak:.2f} dBFS"

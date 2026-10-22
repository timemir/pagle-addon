"""Checks one sound file against ANN-R74, for the render's tests and the committed files' tests alike."""

from pathlib import Path
from typing import BinaryIO

import numpy as np
import soundfile as sf

from pagle_data.sounds import Signal, loudness

# ANN-R74's layout, written out here as the spec gives it: "<set>/toast_<n>.ogg and banner.ogg, <set> being the sound
# set good's last ID segment", and "legend/<itemID>.ogg". Driftwood has three toast variants (Tunables: Driftwood toast
# variants = 3), Gilded one, and each of the expansion's fifteen sets three (ANN-R72); each Legend has its own sting.
EXPANSION_SETS = [
    "rain",
    "marimba",
    "shipbell",
    "kalimba",
    "musicbox",
    "glass",
    "steelpan",
    "dulcimer",
    "frost",
    "harp",
    "gizmo",
    "wardrums",
    "concertina",
    "choir",
    "nightwatch",
]
LEGEND_ITEMS = [19803, 19805, 19806]
ANN_R74_FILES = sorted(
    [
        "driftwood/banner.ogg",
        "driftwood/toast_1.ogg",
        "driftwood/toast_2.ogg",
        "driftwood/toast_3.ogg",
        "gilded/banner.ogg",
        "gilded/toast_1.ogg",
        *(f"{folder}/{name}.ogg" for folder in EXPANSION_SETS for name in ("banner", "toast_1", "toast_2", "toast_3")),
        *(f"legend/{item}.ogg" for item in LEGEND_ITEMS),
    ]
)


def read_sound(path: Path | BinaryIO) -> Signal:
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

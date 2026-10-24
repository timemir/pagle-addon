"""Builds the Mrglglgl sound set (ANN-R74) from three of the game's own murloc clips.

The clips are Blizzard's and are not in the repo: point WOW_MURLOC_DIR at a folder holding mmurlocaggrob.ogg,
mmurlocaggroold.ogg and mmurlocwoundcriticala.ogg (wow.export's sound/creature/murloc). Each file is those clips pitched,
layered and given a small room, then finished with the synthesised sets' own trim, fade and loudness match.
"""

import os
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

from pagle_data.sounds import PEAK_DB, SAMPLE_RATE, SOUNDS_DIR, Signal, _finish_limited, loudness

FOLDER = "mrglglgl"
CLIPS = ("mmurlocaggrob", "mmurlocaggroold", "mmurlocwoundcriticala")
TOAST_SECONDS = 2.0
BANNER_SECONDS = 4.0


def pitched(x: Signal, rate: int, semitones: float = 0.0) -> Signal:
    """A signal at `rate` as 44.1 kHz, pitched (and so sped up or slowed down) by `semitones`."""
    ratio = 2 ** (semitones / 12)
    resampled: Signal = resample_poly(x, SAMPLE_RATE, round(rate * ratio))
    return resampled


def clip(source: Path, name: str, semitones: float = 0.0) -> Signal:
    """A clip at 44.1 kHz, pitched (and so sped up or slowed down) by `semitones`."""
    samples, rate = sf.read(source / f"{name}.ogg", dtype="float64", always_2d=True)
    return pitched(np.asarray(samples.mean(axis=1), dtype=np.float64), rate, semitones)


def write_ogg(path: Path, signal: Signal) -> None:
    """Writes `signal` as the set's .ogg. Vorbis can overshoot a spiky sound's peak, so the file is decoded again and
    the gain backed off in 0.2 dB steps until the decoded peak is under ANN-R74's -1 dBFS."""
    for _ in range(8):
        sf.write(path, signal.astype(np.float32), SAMPLE_RATE, format="OGG", subtype="VORBIS")
        samples, _rate = sf.read(path, dtype="float64")
        if loudness(np.asarray(samples, dtype=np.float64))[1] < PEAK_DB - 0.05:
            return
        signal = signal * 10 ** (-0.2 / 20)
    raise ValueError(f"{path}: the peak stays over {PEAK_DB} dBFS")


def place(layers: list[tuple[float, Signal, float]]) -> Signal:
    """Layers of (start in seconds, signal, gain), summed."""
    length = max(int(start * SAMPLE_RATE) + len(x) for start, x, _ in layers)
    out = np.zeros(length)
    for start, x, gain in layers:
        i = int(start * SAMPLE_RATE)
        out[i : i + len(x)] += x * gain
    return out


def _room(x: Signal, seconds: float = 0.5, wet: float = 0.22) -> Signal:
    """A small wet room: decaying noise, the same on every render."""
    rng = np.random.default_rng(7)
    n = int(seconds * SAMPLE_RATE)
    impulse = rng.standard_normal(n) * np.exp(-np.arange(n) / (SAMPLE_RATE * seconds / 5))
    tail = np.convolve(x, impulse / np.abs(impulse).sum() * 8)[: len(x) + n]
    out = np.zeros(len(tail))
    out[: len(x)] += x
    return out + tail * wet


def _voices(source: Path) -> dict[str, tuple[Signal, float]]:

    def short(semitones: float) -> Signal:
        return clip(source, CLIPS[0], semitones)

    def long(semitones: float) -> Signal:
        return clip(source, CLIPS[1], semitones)

    def wound(semitones: float) -> Signal:
        return clip(source, CLIPS[2], semitones)

    return {
        # One bright "mrgl!" a fourth up.
        "toast_1": (_room(short(5)), TOAST_SECONDS),
        # The wound cry, squeaky and rising, as a questioning "mrgl?".
        "toast_2": (_room(wound(6)), TOAST_SECONDS),
        # Two in a row: a low one, then a high one on its heels.
        "toast_3": (_room(place([(0, short(-2), 1.0), (0.42, short(4), 0.9)])), TOAST_SECONDS),
        # A chorus: the long cry at four pitches, staggered, with a wound cry for the squeal at the end.
        "banner": (
            _room(
                place(
                    [
                        (0.00, long(-5), 0.8),
                        (0.12, long(0), 1.0),
                        (0.25, long(3), 0.8),
                        (0.40, long(7), 0.6),
                        (1.10, short(-3), 0.7),
                        (1.45, wound(4), 0.8),
                    ]
                ),
                seconds=0.9,
                wet=0.3,
            ),
            BANNER_SECONDS,
        ),
    }


def build(root: Path, source: Path | None = None) -> list[Path]:
    """Writes the set's four .ogg files under addons/Pagle/media/sounds/mrglglgl/ and returns them."""
    source = source or Path(os.environ["WOW_MURLOC_DIR"])
    written = []
    for name, (signal, longest) in _voices(source).items():
        path = root / SOUNDS_DIR / FOLDER / f"{name}.ogg"
        path.parent.mkdir(parents=True, exist_ok=True)
        write_ogg(path, _finish_limited(signal, longest))
        written.append(path)
    return written

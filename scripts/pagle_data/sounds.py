"""Pagle's own Announcement sounds (ANN-R72, ANN-R74), rendered from scratch: modal wood and bell synthesis plus a
small room, in D major pentatonic, mono, 44.1 kHz Ogg Vorbis, loudness-matched to the Tunables' target.

The command line is scripts/render-sounds.py, which writes into addons/Pagle/media/sounds/. The files are committed;
scripts/check.sh doesn't re-render them, since Vorbis output isn't byte-stable. Moved from the sounds prototype
(prototype/sounds:prototypes/sounds/render.py, its "own" set). QoL's recast cue is QoL's (ANN-R75), not rendered here.
"""

from collections.abc import Callable
from pathlib import Path

import numpy as np
import numpy.typing as npt
import soundfile as sf

Signal = npt.NDArray[np.float64]

# Where the sounds go, from the repo root (ANN-R74).
SOUNDS_DIR = Path("addons/Pagle/media/sounds")
SAMPLE_RATE = 44100
# Tunables, Loudness target (ANN-R74), measured by loudness().
TARGET_RMS_DB = -20.0
PEAK_DB = -1.0
AUDIBLE_DB = -40.0
BLOCK = SAMPLE_RATE // 100
# Tunables, Legend sting length (ANN-R72).
LEGEND_SECONDS = 3.0
# Vorbis moves samples a little, so the render aims this far under the peak limit to stay under it once encoded.
PEAK_MARGIN_DB = 0.3

# D major pentatonic: nothing in it can clash, whatever order the notes land in.
NOTES = {
    "D4": 293.66,
    "E4": 329.63,
    "F#4": 369.99,
    "A4": 440.00,
    "B4": 493.88,
    "D5": 587.33,
    "E5": 659.26,
    "F#5": 739.99,
    "A5": 880.00,
    "B5": 987.77,
    "D6": 1174.66,
    "E6": 1318.51,
    "F#6": 1479.98,
    "A6": 1760.00,
}

# An event places a signal at a start time (seconds) with a gain.
Event = tuple[float, Signal, float]


class _Synth:
    """The instruments. Each sound gets its own, seeded, so a sound renders the same whatever else is rendered."""

    def __init__(self, seed: int) -> None:
        self.rng = np.random.default_rng(seed)

    def partials(
        self, f: float, dur: float, ratios: list[float], amps: list[float], decays: list[float], attack: float = 0.003
    ) -> Signal:
        t = np.arange(int(dur * SAMPLE_RATE)) / SAMPLE_RATE
        out = np.zeros_like(t)
        for r, a, d in zip(ratios, amps, decays, strict=True):
            if f * r > SAMPLE_RATE / 2.2:
                continue
            out += a * np.sin(2 * np.pi * f * r * t + self.rng.uniform(0, 6.28)) * np.exp(-t / d)
        envelope: Signal = np.minimum(t / attack, 1.0)
        return out * envelope

    def lowpassed_noise(self, n: int, cutoff: float) -> Signal:
        x = self.rng.standard_normal(n)
        a = float(np.exp(-2 * np.pi * cutoff / SAMPLE_RATE))
        y = np.zeros(n)
        acc = 0.0
        for i in range(n):
            acc = (1 - a) * float(x[i]) + a * acc
            y[i] = acc
        normalized: Signal = y / (np.abs(y).max() + 1e-9)
        return normalized

    def marimba(self, f: float, dur: float = 0.9) -> Signal:
        # Bar modes of a tuned wooden bar: 1, ~3.9, ~9.2.
        tone = self.partials(f, dur, [1, 3.93, 9.2], [1, 0.22, 0.05], [dur * 0.32, dur * 0.09, dur * 0.03])
        n = int(0.012 * SAMPLE_RATE)
        click = self.lowpassed_noise(n, 2500) * np.exp(-np.arange(n) / (0.003 * SAMPLE_RATE)) * 0.15
        tone[:n] += click
        return tone

    def bell(self, f: float, dur: float = 1.6) -> Signal:
        # A small inharmonic hand bell.
        return self.partials(
            f,
            dur,
            [1, 2.0, 2.76, 5.4, 8.93],
            [1, 0.45, 0.35, 0.12, 0.05],
            [dur * 0.45, dur * 0.35, dur * 0.25, dur * 0.1, dur * 0.05],
            attack=0.002,
        )

    def room(self, x: Signal, seconds: float = 0.9, wet: float = 0.16) -> Signal:
        n = int(seconds * SAMPLE_RATE)
        ir = self.lowpassed_noise(n, 3500) * np.exp(-np.arange(n) / (0.22 * SAMPLE_RATE))
        ir /= np.sqrt((ir**2).sum())
        # The convolution x * ir, through the FFT: direct convolution of a sting with a 1.6 s room takes seconds.
        size = len(x) + n - 1
        w = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
        dry = np.concatenate([x, np.zeros(len(w) - len(x))])
        mixed: Signal = (1 - wet) * dry + wet * w
        return mixed


def _place(events: list[Event], tail: float = 0.6) -> Signal:
    end = max(start + len(signal) / SAMPLE_RATE for start, signal, _ in events) + tail
    out = np.zeros(int(end * SAMPLE_RATE))
    for start, signal, gain in events:
        i = int(start * SAMPLE_RATE)
        out[i : i + len(signal)] += gain * signal
    return out


def _db(x: float) -> float:
    return float(20 * np.log10(x))


def loudness(x: Signal) -> tuple[float, float]:
    """A sound's (RMS, peak) in dBFS (ANN-R74's loudness target). The RMS is over its audible part: the 10 ms blocks
    whose own RMS is within AUDIBLE_DB of the loudest block's, so silence and a long quiet tail don't lower it."""
    blocks = np.zeros(-(-len(x) // BLOCK) * BLOCK)
    blocks[: len(x)] = x
    power = (blocks.reshape(-1, BLOCK) ** 2).mean(axis=1)
    audible = power[power >= power.max() * 10 ** (AUDIBLE_DB / 10)]
    return _db(float(np.sqrt(audible.mean()))), _db(float(np.abs(x).max()))


def _finish(x: Signal) -> Signal:
    """Trims the trailing near-silence, fades out, then matches the loudness target."""
    last = int(np.nonzero(np.abs(x) > np.abs(x).max() * 10 ** (-60 / 20))[0][-1])
    x = x[: last + 1].copy()
    fade = min(len(x), int(0.05 * SAMPLE_RATE))
    x[-fade:] *= np.linspace(1, 0, fade)
    rms, peak = loudness(x)
    gain = TARGET_RMS_DB - rms
    if peak + gain > PEAK_DB - PEAK_MARGIN_DB:
        raise ValueError(f"the peak would be {peak + gain:.2f} dBFS at the RMS target; voice the sound less spiky")
    scaled: Signal = x * 10 ** (gain / 20)
    return scaled


def _driftwood_toast(a: str, b: str) -> Callable[[_Synth], Signal]:
    # ANN-R72: two rising wooden notes.
    def voice(s: _Synth) -> Signal:
        return s.room(_place([(0, s.marimba(NOTES[a]), 0.8), (0.085, s.marimba(NOTES[b]), 1.0)]))

    return voice


def _driftwood_banner(s: _Synth) -> Signal:
    # ANN-R72: a wooden run up the scale with a bell on top.
    run: list[Event] = [(i * 0.09, s.marimba(NOTES[n]), 0.8) for i, n in enumerate(["D4", "F#4", "A4", "D5"])]
    return s.room(_place([*run, (0.36, s.bell(NOTES["D6"], 1.8), 0.55)]), wet=0.2)


def _gilded_toast(s: _Synth) -> Signal:
    # ANN-R72: two bell notes.
    return s.room(_place([(0, s.bell(NOTES["D6"], 1.2), 0.6), (0.07, s.bell(NOTES["A6"], 1.0), 0.35)]))


def _gilded_banner(s: _Synth) -> Signal:
    # ANN-R72: three rising bells.
    return s.room(_place([(i * 0.11, s.bell(NOTES[n], 1.6), 0.5) for i, n in enumerate(["A5", "D6", "F#6"])]), wet=0.22)


def _legend(s: _Synth) -> Signal:
    # ANN-R72: a slow bell chord, a fast wooden run and a ringing top note, about 3 s.
    events: list[Event] = [(0, s.bell(NOTES["D4"], 3.0), 0.5), (0.02, s.bell(NOTES["A4"], 3.0), 0.4)]
    events += [(0.04, s.bell(NOTES["D5"], 3.0), 0.35)]
    run = ["D5", "E5", "F#5", "A5", "B5", "D6"]
    events += [(0.55 + i * 0.06, s.marimba(NOTES[n], 0.7), 0.6) for i, n in enumerate(run)]
    events += [(0.95, s.bell(NOTES["D6"], 3.0), 0.5), (0.97, s.bell(NOTES["A6"], 2.4), 0.2)]
    sting = s.room(_place(events, tail=1.0), seconds=1.6, wet=0.28)
    # The bells ring on well past 3 s (Tunables: Legend sting length ~3 s), so the sting fades out over its last 0.8 s.
    end, fade = int(LEGEND_SECONDS * SAMPLE_RATE), int(0.8 * SAMPLE_RATE)
    sting = sting[:end].copy()
    sting[-fade:] *= np.linspace(1, 0, fade)
    return sting


# Every file ANN-R74 lays out, under addons/Pagle/media/sounds/, with its voicing. Driftwood rotates through its three
# toast variants (Tunables: Driftwood toast variants = 3).
SOUND_FILES: dict[str, Callable[[_Synth], Signal]] = {
    "driftwood/toast_1.ogg": _driftwood_toast("A4", "D5"),
    "driftwood/toast_2.ogg": _driftwood_toast("B4", "E5"),
    "driftwood/toast_3.ogg": _driftwood_toast("D5", "F#5"),
    "driftwood/banner.ogg": _driftwood_banner,
    "gilded/toast_1.ogg": _gilded_toast,
    "gilded/banner.ogg": _gilded_banner,
    "legend.ogg": _legend,
}


def render(out: Path) -> list[Path]:
    """Renders every sound into out/ (addons/Pagle/media/sounds/ in the repo) and returns the files written."""
    written = []
    for seed, (name, voice) in enumerate(SOUND_FILES.items(), 1):
        path = out / name
        path.parent.mkdir(parents=True, exist_ok=True)
        sf.write(path, _finish(voice(_Synth(seed))).astype(np.float32), SAMPLE_RATE, format="OGG", subtype="VORBIS")
        written.append(path)
    return written

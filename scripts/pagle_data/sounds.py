"""Pagle's own Announcement sounds (ANN-R72, ANN-R74), rendered from scratch, nothing sampled: every sound set and
every Legend sting, mono, 44.1 kHz Ogg Vorbis, loudness-matched to the Tunables' target.

Driftwood and Gilded are modal wood and bell synthesis plus a small room, in D major pentatonic (_Synth). The shop
expansion's fifteen sets and the three Legend stings play a wider palette (_Palette): plucked and hammered strings,
tines, pans, glass, membranes, reeds, brass, voices, and filtered noise for water and wind, through SciPy's filters.

The command line is scripts/render-sounds.py, which writes into addons/Pagle/media/sounds/. The files are committed;
scripts/check.sh doesn't rewrite them, since Vorbis output isn't byte-stable, but holds each to the render, to the
encoder's noise (tests/test_repo_sounds.py). Driftwood and Gilded moved from the sounds prototype
(prototype/sounds:prototypes/sounds/render.py, its "own" set), the rest from the shop expansion kit's source/sounds.py.
QoL's recast cue is QoL's (ANN-R75), not rendered here.
"""

from collections.abc import Callable
from pathlib import Path

import numpy as np
import numpy.typing as npt
import soundfile as sf
from scipy.signal import butter, lfilter, sosfilt

Signal = npt.NDArray[np.float64]

# Where the sounds go, from the repo root (ANN-R74).
SOUNDS_DIR = Path("addons/Pagle/media/sounds")
SAMPLE_RATE = 44100
# Tunables, Loudness target (ANN-R74), measured by loudness().
TARGET_RMS_DB = -20.0
PEAK_DB = -1.0
AUDIBLE_DB = -40.0
BLOCK = SAMPLE_RATE // 100
# Tunables, Legend sting length (ANN-R72): the stings, and the expansion's banners, are cut to it.
LEGEND_SECONDS = 3.0
# The longest an expansion toast runs before it's cut and faded.
TOAST_SECONDS = 1.6
# Vorbis moves samples a little, so the render aims this far under the peak limit to stay under it once encoded.
PEAK_MARGIN_DB = 0.3
# The expansion's limiter aims a little further under it, since soft-limited peaks sit right at its ceiling.
LIMITER_MARGIN_DB = 0.4

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

# The expansion's sets play in other keys too, so their notes are equal-tempered from A4 by name ("F#5", "C#7").
_SEMITONES = {
    "C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2
}


def hz(note: str) -> float:
    """A note's frequency, equal-tempered with A4 at 440 Hz: hz("A4") is 440.0, hz("A5") 880.0."""
    name, octave = note[:-1], int(note[-1])
    return float(440.0 * 2 ** ((_SEMITONES[name] + 12 * (octave - 4)) / 12))


# An event places a signal at a start time (seconds) with a gain.
Event = tuple[float, Signal, float]


class _Synth:
    """Driftwood's and Gilded's instruments. Each sound gets its own, seeded, so a sound renders the same whatever
    else is rendered."""

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
        return _convolve(x, ir, wet)


def _convolve(x: Signal, ir: Signal, wet: float) -> Signal:
    # The convolution x * ir, through the FFT: direct convolution of a sting with a 1.6 s room takes seconds.
    size = len(x) + len(ir) - 1
    w = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
    dry = np.concatenate([x, np.zeros(len(w) - len(x))])
    mixed: Signal = (1 - wet) * dry + wet * w
    return mixed


class _Palette:
    """The shop expansion's instruments (ANN-R74's wider palette). Seeded per sound, like _Synth. Its marimba, bell and
    room aren't _Synth's: the marimba's click and the room are Butterworth-filtered noise, the bell has a hum partial an
    octave down, and each partial draws a detune (zero unless asked for), so these render as the kit's files do and
    Driftwood's and Gilded's don't change."""

    def __init__(self, seed: int) -> None:
        self.rng = np.random.default_rng(seed)

    @staticmethod
    def t(dur: float) -> Signal:
        times: Signal = np.arange(int(dur * SAMPLE_RATE)) / SAMPLE_RATE
        return times

    def partials(
        self,
        f: float,
        dur: float,
        ratios: list[float],
        amps: list[float],
        decays: list[float],
        attack: float = 0.003,
        detune: float = 0.0,
    ) -> Signal:
        t = self.t(dur)
        out = np.zeros_like(t)
        for r, a, d in zip(ratios, amps, decays, strict=True):
            fr = f * r * (1 + self.rng.uniform(-detune, detune))
            if fr > SAMPLE_RATE / 2.3:
                continue
            out += a * np.sin(2 * np.pi * fr * t + self.rng.uniform(0, 6.28)) * np.exp(-t / d)
        envelope: Signal = np.minimum(t / attack, 1)
        return out * envelope

    def noise(self, dur: float) -> Signal:
        return self.rng.standard_normal(int(dur * SAMPLE_RATE))

    @staticmethod
    def band(x: Signal, lo: float, hi: float, order: int = 2) -> Signal:
        y: Signal = sosfilt(butter(order, [lo, hi], btype="band", fs=SAMPLE_RATE, output="sos"), x)
        return y

    @staticmethod
    def low(x: Signal, fc: float, order: int = 2) -> Signal:
        y: Signal = sosfilt(butter(order, fc, fs=SAMPLE_RATE, output="sos"), x)
        return y

    @staticmethod
    def high(x: Signal, fc: float, order: int = 2) -> Signal:
        y: Signal = sosfilt(butter(order, fc, btype="high", fs=SAMPLE_RATE, output="sos"), x)
        return y

    # Strings.

    def ks(self, f: float, dur: float, bright: float = 0.5, decay: float = 0.996, pick: float = 0.0) -> Signal:
        # Karplus-Strong: a noise burst in a damped delay loop, as one IIR filter, y[n] = x[n] + decay/2 (y[n-N] +
        # y[n-N-1]). The loop's two-tap average adds half a sample, hence the - 0.5.
        loop = max(2, int(round(SAMPLE_RATE / f - 0.5)))
        burst = self.rng.uniform(-1, 1, loop)
        burst = self.low(np.concatenate([burst, np.zeros(64)]), 1500 + bright * 9000)[:loop]
        if pick:
            burst = burst - np.roll(burst, int(loop * pick))
        x = np.zeros(int(dur * SAMPLE_RATE))
        x[:loop] = burst
        a = np.zeros(loop + 2)
        a[0] = 1
        a[loop] = a[loop + 1] = -decay * 0.5
        y: Signal = lfilter([1], a, x)
        normalized: Signal = y / (np.abs(y[: loop * 4]).max() + 1e-9)
        return normalized

    def harp(self, f: float, dur: float = 1.6) -> Signal:
        if f > 1100:  # Too short a loop to stay in tune: the same pluck, additive.
            decays = [dur * 0.3, dur * 0.15, dur * 0.08, dur * 0.05]
            return self.partials(f, dur, [1, 2, 3, 4], [1, 0.35, 0.12, 0.05], decays, attack=0.002)
        y = self.ks(f, dur, bright=0.35, decay=0.9985, pick=0.3)
        body = self.band(y, 180, 2400) * 0.35
        return (y + body) * np.minimum(self.t(dur) / 0.002, 1)

    def dulcimer(self, f: float, dur: float = 1.6) -> Signal:
        if f > 1100:
            return self.partials(
                f, dur, [1, 2, 3], [1, 0.4, 0.15], [dur * 0.3, dur * 0.15, dur * 0.08], attack=0.002, detune=0.002
            )
        # Three strings a course, a little out of tune with each other.
        out = np.zeros(int(dur * SAMPLE_RATE))
        for d in (-0.0018, 0, 0.0021):
            out += self.ks(f * (1 + d), dur, bright=0.8, decay=0.9975)
        out /= 3
        n = int(0.01 * SAMPLE_RATE)
        hammer = self.band(self.noise(0.01), 800, 5000) * np.exp(-np.arange(n) / (0.002 * SAMPLE_RATE)) * 0.3
        out[:n] += hammer
        return out

    # Struck.

    def marimba(self, f: float, dur: float = 0.9) -> Signal:
        y = self.partials(f, dur, [1, 3.93, 9.2], [1, 0.22, 0.05], [dur * 0.32, dur * 0.09, dur * 0.03])
        n = int(0.012 * SAMPLE_RATE)
        y[:n] += self.low(self.noise(0.012), 2500) * np.exp(-np.arange(n) / (0.003 * SAMPLE_RATE)) * 0.15
        return y

    def bell(self, f: float, dur: float = 1.6, bright: float = 1.0) -> Signal:
        return self.partials(
            f,
            dur,
            [0.5, 1, 2.0, 2.76, 5.4, 8.93],
            [0.25, 1, 0.45, 0.35 * bright, 0.12 * bright, 0.05 * bright],
            [dur * 0.7, dur * 0.45, dur * 0.35, dur * 0.25, dur * 0.1, dur * 0.05],
            attack=0.002,
        )

    def shipbell(self, f: float, dur: float = 3.0) -> Signal:
        y = self.partials(
            f,
            dur,
            [0.5, 1, 1.19, 1.5, 2.0, 2.52, 3.0],
            [0.5, 1, 0.6, 0.25, 0.4, 0.2, 0.15],
            [dur * 0.8, dur * 0.5, dur * 0.4, dur * 0.3, dur * 0.3, dur * 0.15, dur * 0.1],
            attack=0.001,
            detune=0.0015,
        )
        n = int(0.02 * SAMPLE_RATE)
        y[:n] += self.band(self.noise(0.02), 1500, 7000) * np.exp(-np.arange(n) / (0.003 * SAMPLE_RATE)) * 0.4
        return y

    def glass(self, f: float, dur: float = 2.2) -> Signal:
        return self.partials(
            f,
            dur,
            [1, 2.32, 4.25, 6.63],
            [1, 0.5, 0.25, 0.12],
            [dur * 0.5, dur * 0.3, dur * 0.18, dur * 0.1],
            attack=0.001,
            detune=0.002,
        )

    def kalimba(self, f: float, dur: float = 1.4) -> Signal:
        y = self.partials(f, dur, [1, 5.9, 13.1], [1, 0.3, 0.08], [dur * 0.35, dur * 0.05, dur * 0.02], attack=0.0015)
        t = self.t(dur)
        y *= 1 + 0.06 * np.sin(2 * np.pi * 5.5 * t)  # The tine's slight wobble.
        return y

    def pan(self, f: float, dur: float = 1.3) -> Signal:
        t = self.t(dur)
        y = self.partials(
            f,
            dur,
            [1, 2.0, 3.0, 4.02],
            [1, 0.55, 0.28, 0.12],
            [dur * 0.4, dur * 0.3, dur * 0.2, dur * 0.1],
            attack=0.004,
            detune=0.003,
        )
        bloom: Signal = np.sin(2 * np.pi * f * 2 * t) * 0.3 * (1 - np.exp(-t / 0.03)) * np.exp(-t / (dur * 0.25))
        return y + bloom

    def musicbox(self, f: float, dur: float = 1.2) -> Signal:
        y = self.partials(f, dur, [1, 4.07, 10.4], [1, 0.25, 0.06], [dur * 0.4, dur * 0.08, dur * 0.03], attack=0.0008)
        n = int(0.006 * SAMPLE_RATE)
        y[:n] += self.high(self.noise(0.006), 4000) * 0.2 * np.exp(-np.arange(n) / (0.001 * SAMPLE_RATE))
        return y

    def drum(self, f: float, dur: float = 1.0, snap: float = 0.25) -> Signal:
        t = self.t(dur)
        freq = f * (1 + 0.7 * np.exp(-t / 0.03))
        phase = 2 * np.pi * np.cumsum(freq) / SAMPLE_RATE
        body = np.sin(phase) * np.exp(-t / (dur * 0.28)) + 0.35 * np.sin(phase * 1.6) * np.exp(-t / (dur * 0.12))
        hit = self.low(self.noise(dur), 1800) * np.exp(-t / 0.02) * snap
        return (body + hit) * np.minimum(t / 0.001, 1)

    def tick(self, dur: float = 0.05, fc: float = 3200) -> Signal:
        t = self.t(dur)
        click = self.band(self.noise(dur), fc, fc * 2.2) * np.exp(-t / 0.004)
        return click + 0.5 * np.sin(2 * np.pi * fc * 1.3 * t) * np.exp(-t / 0.01)

    # Sustained.

    def brass(self, f: float, dur: float = 1.2, att: float = 0.06, bright: float = 1.0) -> Signal:
        t = self.t(dur)
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.minimum(t / 0.3, 1)
        ph = 2 * np.pi * f * np.cumsum(vib) / SAMPLE_RATE
        env = np.minimum(t / att, 1) * np.exp(-np.maximum(t - dur * 0.6, 0) / (dur * 0.15))
        y = np.zeros_like(t)
        for k in range(1, 12):
            if f * k < SAMPLE_RATE / 2.3:
                y += (1 / k ** (1.35 / bright)) * np.sin(k * ph) * (1 - np.exp(-t / (att * (1 + k * 0.15))))
        return self.low(y * env, 2600 * bright)

    def reed(self, f: float, dur: float = 1.0) -> Signal:
        t = self.t(dur)
        env = (
            np.minimum(t / 0.05, 1)
            * np.exp(-np.maximum(t - dur * 0.55, 0) / (dur * 0.18))
            * (1 + 0.15 * np.sin(2 * np.pi * 3 * t))
        )
        # Two reeds a little apart, odd harmonics each.
        y = np.zeros_like(t)
        for d in (-0.004, 0.004):
            reed = np.zeros_like(t)
            for k in range(1, 14, 2):
                if f * k < SAMPLE_RATE / 2.3:
                    reed += (1 / k) * np.sin(2 * np.pi * f * (1 + d) * k * t)
            y += reed
        return self.low(y * env, 3200)

    def voice(self, f: float, dur: float = 2.5, vowel: str = "ah") -> Signal:
        # Three voices, each a harmonic series shaped by its vowel's formants (centre, gain, width).
        formants = {
            "ah": ((700, 1.0, 110), (1220, 0.5, 120), (2600, 0.25, 160)),
            "oo": ((300, 1.0, 80), (870, 0.3, 100), (2240, 0.1, 140)),
        }[vowel]
        t = self.t(dur)
        out = np.zeros_like(t)
        for d in (-0.006, 0, 0.007):
            vib = 1 + 0.005 * np.sin(2 * np.pi * (5 + d * 100) * t + self.rng.uniform(0, 6))
            ph = 2 * np.pi * f * (1 + d) * np.cumsum(vib) / SAMPLE_RATE
            for k in range(1, 40):
                fk = f * k
                if fk > SAMPLE_RATE / 2.3:
                    break
                w = sum(a / (1 + ((fk - fc) / bw) ** 2) for fc, a, bw in formants)
                out += w * np.sin(k * ph) / k**0.3
        env: Signal = np.minimum(t / (dur * 0.3), 1) * np.minimum((dur - t) / (dur * 0.35), 1)
        return out * env

    def whale(self, f0: float, f1: float, dur: float = 2.0) -> Signal:
        t = self.t(dur)
        f = f0 + (f1 - f0) * (1 - np.cos(np.pi * t / dur)) / 2
        f = f * (1 + 0.01 * np.sin(2 * np.pi * 4 * t))
        ph = 2 * np.pi * np.cumsum(f) / SAMPLE_RATE
        y = np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.1 * np.sin(3 * ph)
        return y * np.sin(np.pi * t / dur) ** 1.5

    def hoot(self, f: float = 380, dur: float = 0.42) -> Signal:
        t = self.t(dur)
        fr = f * (1 + 0.08 * np.sin(np.pi * t / dur))
        ph = 2 * np.pi * np.cumsum(fr) / SAMPLE_RATE
        y = np.sin(ph) + 0.15 * np.sin(2 * ph)
        env = np.sin(np.pi * np.minimum(t / dur, 1)) ** 2
        return self.low(y * env + 0.04 * self.low(self.noise(dur), 1200) * env, 1500)

    # Water and wind.

    def drip(self, f: float, dur: float = 0.35) -> Signal:
        t = self.t(dur)
        fr = f * (1 + 0.9 * (1 - np.exp(-t / 0.025)))
        ph = 2 * np.pi * np.cumsum(fr) / SAMPLE_RATE
        return np.sin(ph) * np.exp(-t / 0.06) * np.minimum(t / 0.001, 1)

    def bubbles(self, n: int = 6, dur: float = 0.6) -> Signal:
        out = np.zeros(int(dur * SAMPLE_RATE))
        for _ in range(n):
            b = self.drip(self.rng.uniform(500, 1400), 0.12) * self.rng.uniform(0.3, 0.7)
            start = int(self.rng.uniform(0, dur - 0.13) * SAMPLE_RATE)
            out[start : start + len(b)] += b
        return out

    def surf(self, dur: float = 1.6, lo: float = 200, hi: float = 2400, swell: float = 0.5) -> Signal:
        t = self.t(dur)
        env = np.exp(-(((t - dur * swell) / (dur * 0.3)) ** 2))
        return self.band(self.noise(dur), lo, hi) * env

    def wind(self, dur: float = 1.5, f0: float = 500, f1: float = 1400) -> Signal:
        # Noise through a band that sweeps up and back, refiltered every 1024 samples.
        t = self.t(dur)
        x = self.noise(dur)
        out = np.zeros_like(x)
        seg = 1024
        for i in range(0, len(x), seg):
            fc = f0 + (f1 - f0) * np.sin(np.pi * i / len(x))
            out[i : i + seg] = self.band(x[i : i + seg], fc * 0.8, fc * 1.25)
        swell: Signal = np.sin(np.pi * t / dur) ** 2
        return out * swell

    # Things.

    def creak(self, dur: float = 0.5, f0: float = 180, f1: float = 260) -> Signal:
        # A rope or timber: a slowing-down train of clicks through a 900 Hz resonance.
        t = self.t(dur)
        pulses = np.zeros_like(t)
        rate = np.linspace(f0, f1, len(t)) / 6
        ph = np.cumsum(rate) / SAMPLE_RATE
        idx = np.nonzero(np.diff(np.floor(ph)) > 0)[0]
        pulses[idx] = self.rng.uniform(0.5, 1, len(idx))
        y: Signal = lfilter([1], [1, -1.6 * np.cos(2 * np.pi * 900 / SAMPLE_RATE), 0.81], pulses)
        return y * np.sin(np.pi * t / dur)

    def square(self, f0: float, f1: float, dur: float = 0.12) -> Signal:
        # A bleep: a band-limited square wave gliding from f0 to f1.
        t = self.t(dur)
        ph = 2 * np.pi * np.cumsum(np.geomspace(f0, f1, len(t))) / SAMPLE_RATE
        y = np.zeros_like(t)
        for k in range(1, 16, 2):
            y += np.sin(k * ph) / k
        return y * np.minimum(t / 0.003, 1) * np.minimum((dur - t) / 0.01, 1)

    def hum(self, f: float = 110, dur: float = 1.6) -> Signal:
        # A lantern's hum, flickering.
        t = self.t(dur)
        flick = 1 + 0.25 * self.low(self.noise(dur), 8) / 3
        y = np.sin(2 * np.pi * f * t) + 0.4 * np.sin(4 * np.pi * f * t) + 0.15 * np.sin(6 * np.pi * f * t)
        return y * flick * np.sin(np.pi * t / dur)

    def room(
        self, x: Signal, seconds: float = 1.0, wet: float = 0.18, bright: float = 3500, decay: float = 0.22
    ) -> Signal:
        n = int(seconds * SAMPLE_RATE)
        ir = self.low(self.noise(seconds), bright) * np.exp(-np.arange(n) / (decay * SAMPLE_RATE))
        ir /= np.sqrt((ir**2).sum())
        return _convolve(x, ir, wet)


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


def _trim(x: Signal) -> Signal:
    """Cuts the trailing near-silence, 60 dB under the peak."""
    last = int(np.nonzero(np.abs(x) > np.abs(x).max() * 10 ** (-60 / 20))[0][-1])
    return x[: last + 1].copy()


def _fade_out(x: Signal, seconds: float) -> None:
    fade = min(len(x), int(seconds * SAMPLE_RATE))
    x[-fade:] *= np.linspace(1, 0, fade)


def _finish(x: Signal) -> Signal:
    """Driftwood's and Gilded's finish: trims the trailing near-silence, fades out, then matches the loudness target."""
    x = _trim(x)
    _fade_out(x, 0.05)
    rms, peak = loudness(x)
    gain = TARGET_RMS_DB - rms
    if peak + gain > PEAK_DB - PEAK_MARGIN_DB:
        raise ValueError(f"the peak would be {peak + gain:.2f} dBFS at the RMS target; voice the sound less spiky")
    scaled: Signal = x * 10 ** (gain / 20)
    return scaled


def _finish_limited(x: Signal, longest: float) -> Signal:
    """The expansion's finish: trims the trailing near-silence, cuts the sound at `longest` seconds with a 0.8 s fade
    if it rings on past it, fades out, then matches the loudness target, soft-limiting the peaks (a tanh knee) until
    the RMS target fits under the ceiling. The drums and drips are too spiky to fit otherwise."""
    x = _trim(x)
    if len(x) > longest * SAMPLE_RATE:
        x = x[: int(longest * SAMPLE_RATE)]
        _fade_out(x, 0.8)
    _fade_out(x, 0.05)
    ceiling = 10 ** ((PEAK_DB - LIMITER_MARGIN_DB) / 20)
    for _ in range(8):
        rms, _peak = loudness(x)
        x = x * 10 ** ((TARGET_RMS_DB - rms) / 20)
        if np.abs(x).max() <= ceiling:
            break
        x = np.tanh(x / ceiling * 0.95) * ceiling
    return x


# Driftwood and Gilded (_Synth).

Voice = Callable[[_Synth], Signal]


def _driftwood_toast(a: str, b: str) -> Voice:
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


# The shop expansion's sets (_Palette), in ANN-R72's order, each three toast variants and a banner.

PaletteVoice = Callable[[_Palette], Signal]


def _rain_toast(a: str, b: str) -> PaletteVoice:
    # ANN-R72, Rain on the Lake: drops landing on still water, and the faint hush of rain behind them.
    def voice(s: _Palette) -> Signal:
        hush = s.low(s.noise(0.4), 2500) * np.exp(-s.t(0.4) / 0.08) * 0.04
        drops: list[Event] = [(0, s.drip(hz(a)), 0.8), (0.11, s.drip(hz(b)), 0.9)]
        return s.room(_place([*drops, (0.05, hush, 1)]), wet=0.3, decay=0.35)

    return voice


def _rain_banner(s: _Palette) -> Signal:
    # ANN-R72: drops one after another, a little uneven, over the rain.
    notes = ["D5", "F#5", "A5", "B5", "D6", "F#6"]
    events: list[Event] = [(i * 0.085 + s.rng.uniform(0, 0.02), s.drip(hz(n)), 0.7) for i, n in enumerate(notes)]
    events += [(0, s.surf(1.4, 1500, 6000, 0.3) * 0.08, 1)]
    return s.room(_place(events), wet=0.32, decay=0.4)


def _marimba_toast(notes: list[str]) -> PaletteVoice:
    # ANN-R72, Marimba Shore: warm wooden bars, rolled quickly up the scale.
    def voice(s: _Palette) -> Signal:
        return s.room(_place([(i * 0.07, s.marimba(hz(n)), 0.8 + 0.1 * i) for i, n in enumerate(notes)]))

    return voice


def _marimba_banner(s: _Palette) -> Signal:
    # ANN-R72: a roll up the scale like a wave coming in, landing on a fifth, with the surf under it.
    notes = ["G4", "B4", "D5", "G5", "B5", "D6"]
    events: list[Event] = [(i * 0.06, s.marimba(hz(n), 1.1), 0.75) for i, n in enumerate(notes)]
    events += [(0.42, s.marimba(hz("G5"), 1.4), 0.6), (0.42, s.marimba(hz("D6"), 1.4), 0.5)]
    events += [(0.1, s.surf(1.6, 300, 1800, 0.45) * 0.06, 1)]
    return s.room(_place(events), wet=0.2)


def _shipbell_toast_1(s: _Palette) -> Signal:
    # ANN-R72, Ship's Bell: the brass bell on the mast, with the rope creaking under it.
    return s.room(_place([(0, s.shipbell(hz("A4"), 1.6), 0.7), (0.02, s.creak(0.35) * 0.25, 1)]))


def _shipbell_toast_2(s: _Palette) -> Signal:
    # ANN-R72: the bell rung twice.
    return s.room(_place([(0, s.shipbell(hz("A4"), 1.4), 0.55), (0.22, s.shipbell(hz("A4"), 1.4), 0.7)]))


def _shipbell_toast_3(s: _Palette) -> Signal:
    # ANN-R72: the bell a third up, and the timbers.
    return s.room(_place([(0, s.shipbell(hz("C#5"), 1.6), 0.7), (0.05, s.creak(0.4, 150, 220) * 0.22, 1)]))


def _shipbell_banner(s: _Palette) -> Signal:
    # ANN-R72: two strokes and a low one, the rope and timbers creaking, the sea under it.
    events: list[Event] = [
        (0, s.shipbell(hz("A4"), 2.4), 0.6),
        (0.32, s.shipbell(hz("A4"), 2.4), 0.6),
        (0.9, s.shipbell(hz("E4"), 3.0), 0.75),
        (0.2, s.creak(0.7, 140, 240) * 0.25, 1),
        (0.4, s.surf(1.8, 200, 1500, 0.5) * 0.07, 1),
    ]
    return s.room(_place(events), wet=0.25, decay=0.3)


def _kalimba_toast(a: str, b: str) -> PaletteVoice:
    # ANN-R72, Kalimba Creek: a thumb piano by running water, two notes and a little buzz.
    def voice(s: _Palette) -> Signal:
        events: list[Event] = [(0, s.kalimba(hz(a)), 0.8), (0.09, s.kalimba(hz(b)), 0.9)]
        events += [(0, s.surf(0.8, 1500, 5000, 0.4) * 0.03, 1)]
        return s.room(_place(events), wet=0.22)

    return voice


def _kalimba_banner(s: _Palette) -> Signal:
    # ANN-R72: a run of tines up the scale, two left ringing, and the creek.
    notes = ["E5", "G5", "B5", "D6", "E6"]
    events: list[Event] = [(i * 0.085, s.kalimba(hz(n)), 0.75) for i, n in enumerate(notes)]
    events += [(0.43, s.kalimba(hz("B5"), 1.8), 0.55), (0.43, s.kalimba(hz("G6"), 1.8), 0.35)]
    events += [(0, s.surf(1.8, 1800, 6000, 0.5) * 0.05, 1)]
    return s.room(_place(events), wet=0.24)


def _musicbox_toast(notes: list[str]) -> PaletteVoice:
    # ANN-R72, Music Box: a tiny wind-up tune, two notes.
    def voice(s: _Palette) -> Signal:
        return s.room(_place([(i * 0.12, s.musicbox(hz(n)), 0.8) for i, n in enumerate(notes)]), wet=0.25)

    return voice


def _musicbox_banner(s: _Palette) -> Signal:
    # ANN-R72: the tune, a little uneven as the comb's teeth are, and two turns of the key.
    notes = ["G5", "B5", "D6", "G6", "F#6", "D6", "G6"]
    events: list[Event] = [
        (i * 0.13 + (0.004 if i % 2 else 0), s.musicbox(hz(n), 1.4), 0.75) for i, n in enumerate(notes)
    ]
    events += [(1.0, s.musicbox(hz("B6"), 1.6), 0.5)]
    events += [(0, s.tick(0.04, 4000) * 0.1, 1), (0.5, s.tick(0.04, 4000) * 0.08, 1)]
    return s.room(_place(events), wet=0.25)


def _glass_toast(a: str, b: str) -> PaletteVoice:
    # ANN-R72, Glass Floats: green glass floats knocking together, with bubbles rising past them.
    def voice(s: _Palette) -> Signal:
        events: list[Event] = [(0, s.glass(hz(a), 1.6), 0.6), (0.08, s.glass(hz(b), 1.4), 0.45)]
        events += [(0.03, s.bubbles(3, 0.4) * 0.3, 1)]
        return s.room(_place(events), wet=0.28, decay=0.35)

    return voice


def _glass_banner(s: _Palette) -> Signal:
    # ANN-R72: the floats knocking up a chord, one high, and a stream of bubbles.
    events: list[Event] = [(i * 0.09, s.glass(hz(n), 2.0), 0.5) for i, n in enumerate(["A5", "C#6", "E6", "A6"])]
    events += [(0.4, s.glass(hz("E7"), 2.2), 0.3), (0.0, s.bubbles(9, 1.2) * 0.35, 1)]
    return s.room(_place(events), wet=0.3, decay=0.4)


def _steelpan_toast(a: str, b: str) -> PaletteVoice:
    # ANN-R72, Steel Pan Lagoon: bright steel drums, two notes.
    def voice(s: _Palette) -> Signal:
        return s.room(_place([(0, s.pan(hz(a)), 0.8), (0.1, s.pan(hz(b)), 0.9)]), wet=0.18)

    return voice


def _steelpan_banner(s: _Palette) -> Signal:
    # ANN-R72: a chord up the pans, two left ringing, the lagoon's surf.
    events: list[Event] = [(i * 0.1, s.pan(hz(n)), 0.7) for i, n in enumerate(["C5", "E5", "G5", "C6"])]
    events += [(0.42, s.pan(hz("E6"), 1.6), 0.5), (0.47, s.pan(hz("G5"), 1.6), 0.45)]
    events += [(0, s.surf(1.8, 250, 1600, 0.55) * 0.06, 1)]
    return s.room(_place(events), wet=0.2)


def _dulcimer_toast(notes: list[str]) -> PaletteVoice:
    # ANN-R72, Tavern Dulcimer: a hammered dulcimer, struck quick and bright.
    def voice(s: _Palette) -> Signal:
        return s.room(_place([(i * 0.06, s.dulcimer(hz(n), 1.2), 0.8) for i, n in enumerate(notes)]))

    return voice


def _dulcimer_banner(s: _Palette) -> Signal:
    # ANN-R72: a quick run up the scale, ending on a struck chord.
    notes = ["D5", "E5", "F#5", "A5", "B5", "D6", "F#6"]
    events: list[Event] = [(i * 0.055, s.dulcimer(hz(n), 1.6), 0.7) for i, n in enumerate(notes)]
    events += [(0.45, s.dulcimer(hz("D5"), 2.0), 0.55), (0.46, s.dulcimer(hz("A5"), 2.0), 0.5)]
    events += [(0.47, s.dulcimer(hz("D6"), 2.0), 0.45)]
    return s.room(_place(events), wet=0.22)


def _frost_toast(a: str, b: str) -> PaletteVoice:
    # ANN-R72, Frost Chimes: icicles chiming, ringing long after they stop moving.
    def voice(s: _Palette) -> Signal:
        events: list[Event] = [(0, s.glass(hz(a), 2.4), 0.5), (0.06, s.glass(hz(b), 2.2), 0.4)]
        events += [(0.12, s.glass(hz(a) * 2, 1.8), 0.2)]
        return s.room(_place(events), seconds=1.8, wet=0.38, bright=6000, decay=0.5)

    return voice


def _frost_banner(s: _Palette) -> Signal:
    # ANN-R72: a cascade of icicles in a cold wind.
    notes = ["B5", "D6", "E6", "G6", "B6", "D7", "E7"]
    events: list[Event] = [(i * 0.07, s.glass(hz(n), 2.6), 0.45) for i, n in enumerate(notes)]
    events += [(0, s.wind(2.2, 900, 2600) * 0.05, 1)]
    return s.room(_place(events), seconds=2.0, wet=0.4, bright=6500, decay=0.55)


def _harp_toast(notes: list[str]) -> PaletteVoice:
    # ANN-R72, Harp of the Glade: a short sweep of strings.
    def voice(s: _Palette) -> Signal:
        return s.room(_place([(i * 0.045, s.harp(hz(n), 1.8), 0.7) for i, n in enumerate(notes)]), wet=0.28, decay=0.32)

    return voice


def _harp_banner(s: _Palette) -> Signal:
    # ANN-R72: a long sweep up two octaves, a chord left ringing, and the leaves answering.
    notes = ["D4", "F#4", "A4", "D5", "E5", "F#5", "A5", "B5", "D6", "F#6", "A6"]
    events: list[Event] = [(i * 0.035, s.harp(hz(n), 2.2), 0.6) for i, n in enumerate(notes)]
    events += [(0.45, s.harp(hz("D6"), 2.4), 0.5), (0.46, s.harp(hz("A5"), 2.4), 0.45)]
    events += [(0, s.wind(2.0, 600, 1500) * 0.035, 1)]
    return s.room(_place(events), seconds=1.6, wet=0.32, decay=0.4)


def _gizmo_toast(f0: float, f1: float) -> PaletteVoice:
    # ANN-R72, Gnomish Gizmo: clockwork ticking and two cheerful bleeps.
    def voice(s: _Palette) -> Signal:
        events: list[Event] = [(0, s.tick(), 0.5), (0.06, s.tick(0.04, 2600), 0.4)]
        events += [(0.12, s.square(f0, f1, 0.1) * 0.25, 1), (0.24, s.square(f1, f1 * 1.5, 0.08) * 0.22, 1)]
        return s.room(_place(events), wet=0.12)

    return voice


def _gizmo_banner(s: _Palette) -> Signal:
    # ANN-R72: ticking, a spring letting go, three bleeps up and a little bell: it almost certainly works.
    events: list[Event] = [(i * 0.07, s.tick(0.04, 3000 + 400 * (i % 2)), 0.45) for i in range(6)]
    events += [
        (0.45, s.square(400, 1600, 0.3) * 0.2, 1),
        (0.8, s.square(1200, 1200, 0.08) * 0.2, 1),
        (0.9, s.square(1600, 1600, 0.08) * 0.2, 1),
        (1.0, s.square(2000, 2000, 0.14) * 0.22, 1),
        (1.0, s.bell(hz("E6"), 1.2), 0.25),
    ]
    return s.room(_place(events), wet=0.14)


def _wardrums_toast(f: float, hits: int) -> PaletteVoice:
    # ANN-R72, War Drums: deep drums from the hills, high and low by turns.
    def voice(s: _Palette) -> Signal:
        events: list[Event] = [(i * 0.12, s.drum(f * (1 if i % 2 == 0 else 1.18), 0.7), 0.8) for i in range(hits)]
        return s.room(_place(events), wet=0.2, bright=2000, decay=0.3)

    return voice


def _wardrums_banner(s: _Palette) -> Signal:
    # ANN-R72: a march of drums, then a low horn in fifths over a big drum, like the start of a march.
    events: list[Event] = [(i * 0.14, s.drum(85 if i % 2 == 0 else 100, 0.9, 0.3), 0.8) for i in range(5)]
    events += [(0.7, s.brass(hz("D3"), 1.4, 0.09, 0.8), 0.55), (0.7, s.brass(hz("A3"), 1.4, 0.09, 0.8), 0.35)]
    events += [(0.7, s.drum(70, 1.6, 0.4), 1.0)]
    return s.room(_place(events), wet=0.24, bright=2200, decay=0.38)


def _concertina_toast(notes: list[str]) -> PaletteVoice:
    # ANN-R72, Old Salt's Concertina: a squeezebox phrase, the last note held.
    def voice(s: _Palette) -> Signal:
        last = len(notes) - 1
        return s.room(_place([(i * 0.12, s.reed(hz(n), 0.32 if i < last else 0.55), 0.7) for i, n in enumerate(notes)]))

    return voice


def _concertina_banner(s: _Palette) -> Signal:
    # ANN-R72: a phrase from a sea song everyone half-knows, closing on a held chord.
    notes = ["A4", "D5", "D5", "E5", "F#5", "E5", "D5"]
    events: list[Event] = [(i * 0.14, s.reed(hz(n), 0.3 if i < 6 else 0.9), 0.65) for i, n in enumerate(notes)]
    events += [(0.84, s.reed(hz("F#4"), 0.9), 0.4), (0.84, s.reed(hz("A4"), 0.9), 0.35)]
    return s.room(_place(events), wet=0.2)


def _choir_toast(a: str, b: str) -> PaletteVoice:
    # ANN-R72, Choir of the Deep: low voices swelling up from deep water, something very large under them.
    def voice(s: _Palette) -> Signal:
        events: list[Event] = [(0, s.voice(hz(a), 1.2), 0.5), (0, s.voice(hz(b), 1.2), 0.4)]
        events += [(0.1, s.whale(hz(a) / 2, hz(a) / 2 * 1.25, 1.0) * 0.15, 1)]
        return s.room(_place(events), seconds=1.6, wet=0.35, decay=0.45)

    return voice


def _choir_banner(s: _Palette) -> Signal:
    # ANN-R72: a chord of voices, the top one on "oo", and the whale singing along underneath.
    events: list[Event] = [
        (0, s.voice(hz("D3"), 2.6), 0.45),
        (0.05, s.voice(hz("A3"), 2.6), 0.4),
        (0.1, s.voice(hz("F#4"), 2.4), 0.35),
        (0.2, s.voice(hz("D5"), 2.2, "oo"), 0.25),
        (0, s.whale(hz("D3"), hz("A3"), 2.4) * 0.2, 1),
    ]
    return s.room(_place(events), seconds=2.0, wet=0.4, decay=0.55)


def _nightwatch_toast(variant: int) -> PaletteVoice:
    # ANN-R72, Night Watch: a low bell for the night watch and a lantern humming, then the owl: two hoots, one, or a
    # creak of the lantern and one.
    def voice(s: _Palette) -> Signal:
        events: list[Event] = [(0, s.shipbell(hz("D4"), 1.4), 0.45), (0.05, s.hum(98, 1.0) * 0.12, 1)]
        if variant == 1:
            events += [(0.35, s.hoot(390, 0.32) * 0.5, 1), (0.75, s.hoot(350, 0.45) * 0.55, 1)]
        elif variant == 2:
            events += [(0.3, s.hoot(420, 0.3) * 0.5, 1)]
        else:
            events += [(0.25, s.tick(0.05, 1800) * 0.2, 1), (0.5, s.hoot(370, 0.4) * 0.5, 1)]
        return s.room(_place(events), wet=0.3, decay=0.45, bright=2400)

    return voice


def _nightwatch_banner(s: _Palette) -> Signal:
    # ANN-R72: two low bells, the lantern, and the owl who has seen every catch you ever made.
    events: list[Event] = [
        (0, s.shipbell(hz("D4"), 2.4), 0.45),
        (0.6, s.shipbell(hz("A3"), 2.6), 0.5),
        (0.1, s.hum(98, 2.4) * 0.14, 1),
        (0.9, s.hoot(390, 0.32) * 0.5, 1),
        (1.35, s.hoot(350, 0.5) * 0.55, 1),
    ]
    return s.room(_place(events), wet=0.32, decay=0.5, bright=2400)


# Each expansion set's folder (ANN-R74: the sound set good's last ID segment), its three toast variants and its banner.
EXPANSION_SETS: dict[str, tuple[list[PaletteVoice], PaletteVoice]] = {
    "rain": ([_rain_toast("D5", "A5"), _rain_toast("E5", "B5"), _rain_toast("F#5", "D6")], _rain_banner),
    "marimba": (
        [_marimba_toast(["G4", "B4", "D5"]), _marimba_toast(["A4", "C#5", "E5"]), _marimba_toast(["B4", "D5", "G5"])],
        _marimba_banner,
    ),
    "shipbell": ([_shipbell_toast_1, _shipbell_toast_2, _shipbell_toast_3], _shipbell_banner),
    "kalimba": ([_kalimba_toast("E5", "B5"), _kalimba_toast("G5", "D6"), _kalimba_toast("A5", "E6")], _kalimba_banner),
    "musicbox": (
        [_musicbox_toast(["G5", "D6"]), _musicbox_toast(["B5", "G6"]), _musicbox_toast(["A5", "F#6"])],
        _musicbox_banner,
    ),
    "glass": ([_glass_toast("E6", "B6"), _glass_toast("D6", "A6"), _glass_toast("F#6", "C#7")], _glass_banner),
    "steelpan": (
        [_steelpan_toast("C5", "G5"), _steelpan_toast("D5", "A5"), _steelpan_toast("E5", "C6")],
        _steelpan_banner,
    ),
    "dulcimer": (
        [
            _dulcimer_toast(["D5", "F#5", "A5"]),
            _dulcimer_toast(["E5", "G5", "B5"]),
            _dulcimer_toast(["F#5", "A5", "D6"]),
        ],
        _dulcimer_banner,
    ),
    "frost": ([_frost_toast("E6", "B6"), _frost_toast("G6", "D7"), _frost_toast("B5", "F#6")], _frost_banner),
    "harp": (
        [
            _harp_toast(["D5", "F#5", "A5", "D6"]),
            _harp_toast(["E5", "G5", "B5", "E6"]),
            _harp_toast(["A4", "D5", "F#5", "A5"]),
        ],
        _harp_banner,
    ),
    "gizmo": ([_gizmo_toast(600, 900), _gizmo_toast(700, 1050), _gizmo_toast(500, 800)], _gizmo_banner),
    "wardrums": ([_wardrums_toast(90, 2), _wardrums_toast(100, 3), _wardrums_toast(80, 2)], _wardrums_banner),
    "concertina": (
        [
            _concertina_toast(["D5", "F#5", "A5"]),
            _concertina_toast(["A4", "D5", "E5"]),
            _concertina_toast(["F#5", "E5", "D5"]),
        ],
        _concertina_banner,
    ),
    "choir": ([_choir_toast("D4", "A4"), _choir_toast("E4", "B4"), _choir_toast("F#4", "D5")], _choir_banner),
    "nightwatch": ([_nightwatch_toast(1), _nightwatch_toast(2), _nightwatch_toast(3)], _nightwatch_banner),
}


# The Legend stings (ANN-R72), one per Legend, the same in every set.


def _racer(s: _Palette) -> Signal:
    # ANN-R72, Brownell's Blue Striped Racer (19803): an accelerating run that never lets up, a roll of drums under
    # it, and a bright finish.
    notes = ["D4", "E4", "F#4", "A4", "B4", "D5", "E5", "F#5", "A5", "B5", "D6", "E6", "F#6", "A6"]
    t, gap = 0.0, 0.16
    events: list[Event] = []
    for n in notes:
        events.append((t, s.marimba(hz(n), 0.8), 0.7))
        events.append((t + 0.01, s.harp(hz(n) * 2, 0.9), 0.25))
        t += gap
        gap *= 0.84
    roll = 0.0
    while roll < t:
        events.append((roll, s.drum(170, 0.25, 0.6) * 0.25, 1))
        roll += 0.06
    events += [
        (t + 0.05, s.bell(hz("D6"), 2.4), 0.55),
        (t + 0.05, s.bell(hz("A6"), 2.2), 0.3),
        (t + 0.05, s.drum(90, 1.2, 0.5), 0.9),
        (t - 0.4, s.wind(0.8, 800, 4000) * 0.15, 1),
    ]
    return s.room(_place(events, tail=1.4), seconds=1.6, wet=0.26)


def _angelfish(s: _Palette) -> Signal:
    # ANN-R72, Keefer's Angelfish (19805): a harp sweep that shimmers up and drifts back, with glass and soft voices on
    # top.
    up = ["D5", "E5", "F#5", "A5", "B5", "D6", "E6", "F#6", "A6", "B6", "D7"]
    events: list[Event] = [(i * 0.05, s.harp(hz(n), 2.2), 0.5) for i, n in enumerate(up)]
    events += [(0.6 + i * 0.05, s.harp(hz(n), 2.0), 0.35) for i, n in enumerate(reversed(up[3:]))]
    events += [(0.55, s.glass(hz("F#6"), 2.6), 0.35), (0.7, s.glass(hz("D7"), 2.4), 0.25)]
    events += [(1.1, s.glass(hz("A6"), 2.4), 0.3)]
    events += [(0, s.voice(hz("D4"), 3.0), 0.3), (0, s.voice(hz("A4"), 3.0), 0.22)]
    events += [(0.4, s.voice(hz("F#5"), 2.6, "oo"), 0.15)]
    return s.room(_place(events, tail=1.2), seconds=2.0, wet=0.36, decay=0.5, bright=6000)


def _queenfish(s: _Palette) -> Signal:
    # ANN-R72, Dezian Queenfish (19806): a fanfare in fifths over timpani, ending on a full chord and a ringing bell.
    events: list[Event] = [(i * 0.045, s.drum(65, 0.5, 0.35) * 0.5, 1) for i in range(8)]
    fanfare = [(0.35, "D4", 0.22), (0.6, "D4", 0.12), (0.75, "A4", 0.22), (1.0, "F#4", 0.2), (1.22, "D5", 0.9)]
    for start, n, held in fanfare:
        # Each horn call doubled an octave down.
        events += [(start, s.brass(hz(n), held + 0.25, 0.04), 0.5)]
        events += [(start, s.brass(hz(n) / 2, held + 0.25, 0.05, 0.8), 0.3)]
    events += [
        (1.22, s.brass(hz("A4"), 1.4, 0.06), 0.35),
        (1.22, s.brass(hz("F#4"), 1.4, 0.06), 0.3),
        (1.22, s.drum(60, 1.6, 0.5), 1.0),
        (1.24, s.bell(hz("D6"), 2.0), 0.35),
        (1.24, s.shipbell(hz("D5"), 2.0), 0.25),
    ]
    return s.room(_place(events, tail=1.2), seconds=1.8, wet=0.3, decay=0.42, bright=3000)


# Each Legend's item ID and its sting. The first is the one played for a Legend without its own (ANN-R72).
LEGEND_STINGS: dict[int, PaletteVoice] = {19803: _racer, 19805: _angelfish, 19806: _queenfish}

Render = Callable[[], Signal]


def _own(seed: int, voice: Voice) -> Render:
    return lambda: _finish(voice(_Synth(seed)))


def _expansion(seed: int, voice: PaletteVoice, longest: float) -> Render:
    return lambda: _finish_limited(voice(_Palette(seed)), longest)


def _expansion_files() -> dict[str, Render]:
    # Seeded 101 on, one per file in this order, as the kit rendered them.
    files: dict[str, Render] = {}
    seed = 100
    for folder, (toasts, banner) in EXPANSION_SETS.items():
        for n, toast in enumerate(toasts, 1):
            seed += 1
            files[f"{folder}/toast_{n}.ogg"] = _expansion(seed, toast, TOAST_SECONDS)
        seed += 1
        files[f"{folder}/banner.ogg"] = _expansion(seed, banner, LEGEND_SECONDS)
    for item, sting in LEGEND_STINGS.items():
        seed += 1
        files[f"legend/{item}.ogg"] = _expansion(seed, sting, LEGEND_SECONDS)
    return files


# Every file ANN-R74 lays out, under addons/Pagle/media/sounds/, with how it's rendered. Driftwood rotates through its
# three toast variants (Tunables: Driftwood toast variants = 3), as every expansion set does through its three.
SOUND_FILES: dict[str, Render] = {
    "driftwood/toast_1.ogg": _own(1, _driftwood_toast("A4", "D5")),
    "driftwood/toast_2.ogg": _own(2, _driftwood_toast("B4", "E5")),
    "driftwood/toast_3.ogg": _own(3, _driftwood_toast("D5", "F#5")),
    "driftwood/banner.ogg": _own(4, _driftwood_banner),
    "gilded/toast_1.ogg": _own(5, _gilded_toast),
    "gilded/banner.ogg": _own(6, _gilded_banner),
    **_expansion_files(),
}


def render(out: Path) -> list[Path]:
    """Renders every sound into out/ (addons/Pagle/media/sounds/ in the repo) and returns the files written."""
    written = []
    for name, sound in SOUND_FILES.items():
        path = out / name
        path.parent.mkdir(parents=True, exist_ok=True)
        sf.write(path, sound().astype(np.float32), SAMPLE_RATE, format="OGG", subtype="VORBIS")
        written.append(path)
    return written

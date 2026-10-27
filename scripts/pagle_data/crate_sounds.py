"""The Curio crate's sounds (wallet-and-shop.md › Motion, "A crate opens"), rendered offline from the prototype's WebAudio
synthesis (prototypes/curio-crate/crate.js: audio(), noise(), tone(), sfx): one Ogg Vorbis file for each beat, mono, 44.1 kHz,
in addons/Pagle/media/crate/sounds/.

The prototype's graph is rebuilt as it is: a noise voice is a 2-second white-noise buffer through a biquad filter (WebAudio's
own coefficients: bandpass with Q linear, lowpass and highpass with Q in dB, a filter's frequency ramped exponentially where
the prototype does) and an exponential gain envelope (0.0001 up to the volume in the attack, then down to 0.0001 by the end);
a tone is an oscillator (sine, triangle, square or sawtooth, band-limited as WebAudio's are) with an exponential frequency ramp
and the same envelope. Each voice goes dry to the master (gain 0.55) and, by its wet amount, through the prototype's room
(gain 0.22 into two feedback delays of 43 and 71 ms, feedback 0.42, each through a 2600 Hz lowpass). Every frequency, volume,
attack, duration and wet amount is the prototype's, as is each beat's timing inside it; the places the prototype draws a random
number (the noise's start, a tick's pitch, the glitter's and the coins' pitch and timing) are drawn from a seeded generator, so
a sound renders the same each time.

The prototype's own levels are kept between the sounds (a tick is quieter than a thud as it is there) by one gain for all of them,
which puts the loudest of them at -1 dBFS (the shop's PEAK_DB, pagle_data/sounds.py) less the margin Vorbis needs. Three beats
are new, in the same voices: the coin sounds of a crate that pays Coins back (payback), and the stamp of "YOURS" (the
prototype has it, the spec's list of beats doesn't), and the card tick comes in three pitches (the prototype draws it from
3800 to 4400 Hz), so a run of them doesn't repeat itself.

The command line is scripts/render-crate-sounds.py. The files are committed; Vorbis output isn't byte-stable, so
tests/test_crate_sounds.py holds each to a fresh render to the encoder's noise, as tests/test_repo_sounds.py does the sets'.
"""

import math
from collections.abc import Callable
from pathlib import Path

import numpy as np
import numpy.typing as npt
import soundfile as sf
from scipy.signal import lfilter

from pagle_data.sounds import PEAK_DB, PEAK_MARGIN_DB, SAMPLE_RATE

Signal = npt.NDArray[np.float64]

SOUNDS_DIR = Path("addons/Pagle/media/crate/sounds")
SOUNDS_LUA = Path("addons/Pagle/data/CrateSounds.lua")
MASTER = 0.55
ROOM = 0.22
FLOOR = 0.0001  # the prototype's envelope floor
TAIL_DB = -60.0  # the render is cut where what is left is quieter than this (below the loudest sound's peak)
FADE_SECONDS = 0.02
BLOCK = 32  # samples between a swept filter's coefficients


# ---------- the voices ----------


def _envelope(n: int, volume: float, attack: float, duration: float) -> Signal:
    """setValueAtTime(0.0001, t); exponentialRampToValueAtTime(volume, t + attack); exponentialRampToValueAtTime(0.0001,
    t + duration), held after, for `n` samples."""
    t = np.arange(n) / SAMPLE_RATE
    attack = min(attack, duration)
    rise = FLOOR * (volume / FLOOR) ** (np.minimum(t, attack) / attack)
    fall = volume * (FLOOR / volume) ** (np.clip((t - attack) / max(duration - attack, 1e-9), 0, 1))
    return np.where(t < attack, rise, fall)


def _sweep(start: float, end: float | None, duration: float, n: int) -> Signal:
    """A frequency by sample: `start`, ramping exponentially to `end` over `duration` and holding there, if there is one."""
    if not end:
        return np.full(n, start, dtype=np.float64)
    t = np.arange(n) / SAMPLE_RATE
    return start * (end / start) ** (np.minimum(t, duration) / duration)


def _biquad(kind: str, f: float, q: float) -> tuple[Signal, Signal]:
    """WebAudio's biquad coefficients (b, a, normalised by a0); lowpass and highpass take Q in dB, bandpass linear."""
    w0 = 2 * math.pi * min(f, SAMPLE_RATE / 2 - 1) / SAMPLE_RATE
    cos, sin = math.cos(w0), math.sin(w0)
    if kind == "bandpass":
        alpha = sin / (2 * q)
        b = [alpha, 0.0, -alpha]
    else:
        alpha = sin / (2 * 10 ** (q / 20))
        b = [(1 - cos) / 2, 1 - cos, (1 - cos) / 2] if kind == "lowpass" else [(1 + cos) / 2, -(1 + cos), (1 + cos) / 2]
    a = [1 + alpha, -2 * cos, 1 - alpha]
    return np.array(b) / a[0], np.array(a) / a[0]


def _filter(x: Signal, kind: str, f: float, q: float, f2: float | None, duration: float) -> Signal:
    """`x` through the biquad, its frequency ramped to `f2` over `duration` where there is one (the coefficients are
    set every BLOCK samples, the state carried over)."""
    if not f2:
        b, a = _biquad(kind, f, q)
        return np.asarray(lfilter(b, a, x), dtype=np.float64)
    freq = _sweep(f, f2, duration, len(x))
    out = np.empty_like(x)
    zi = np.zeros(2)
    for start in range(0, len(x), BLOCK):
        b, a = _biquad(kind, float(freq[start]), q)
        out[start : start + BLOCK], zi = lfilter(b, a, x[start : start + BLOCK], zi=zi)
    return out


def _wave(kind: str, freq: Signal) -> Signal:
    """An oscillator of the instantaneous frequency `freq`, from phase 0, band-limited: a sum of harmonics to the Nyquist at its
    highest frequency, as WebAudio's periodic waves are."""
    phase = 2 * math.pi * np.cumsum(freq) / SAMPLE_RATE
    phase = np.concatenate([[0.0], phase[:-1]])
    if kind == "sine":
        return np.sin(phase)
    top = max(1, min(int(SAMPLE_RATE / 2 / float(freq.max())), 120))
    out = np.zeros_like(phase)
    for k in range(1, top + 1):
        if kind == "sawtooth":
            out += (-1) ** (k + 1) * np.sin(k * phase) / k
        elif k % 2:
            out += np.sin(k * phase) / k if kind == "square" else (-1) ** ((k - 1) // 2) * np.sin(k * phase) / k**2
    scale = {"sawtooth": 2 / math.pi, "square": 4 / math.pi, "triangle": 8 / math.pi**2}[kind]
    return out * scale


class Scene:
    """What the prototype's sfx functions do to one AudioContext, for one sound: voices add to a dry mix and to a send to the
    room, and `render` runs the room and the master over them."""

    def __init__(self, seed: int, seconds: float) -> None:
        self.rng = np.random.default_rng(seed)
        self.n = round(seconds * SAMPLE_RATE)
        self.dry = np.zeros(self.n)
        self.send = np.zeros(self.n)

    def random(self) -> float:
        return float(self.rng.random())

    def _add(self, t0: float, voice: Signal, wet: float) -> None:
        start = round(t0 * SAMPLE_RATE)
        end = min(start + len(voice), self.n)
        if end > start:
            self.dry[start:end] += voice[: end - start]
            self.send[start:end] += voice[: end - start] * wet

    def noise(self, dur: float, kind: str, f: float, q: float, vol: float, t0: float = 0.0, f2: float | None = None) -> None:
        n = round((dur + 0.05) * SAMPLE_RATE)
        source = self.rng.uniform(-1.0, 1.0, n)
        shaped = _filter(source, kind, f, q, f2, dur)
        self._add(t0, shaped * _envelope(n, vol, min(0.01, dur / 4), dur), 0.3)

    def tone(self, f: float, dur: float, kind: str = "sine", vol: float = 0.2, t0: float = 0.0, f2: float | None = None,
             wet: float = 0.5, atk: float = 0.005) -> None:
        n = round((dur + 0.05) * SAMPLE_RATE)
        self._add(t0, _wave(kind, _sweep(f, f2, dur, n)) * _envelope(n, vol, atk, dur), wet)

    def render(self) -> Signal:
        room = np.zeros(self.n)
        for delay in (0.043, 0.071):
            room += _delay_line(self.send * ROOM, round(delay * SAMPLE_RATE))
        return (self.dry + room) * MASTER


def _delay_line(x: Signal, delay: int) -> Signal:
    """One of the room's two feedback delays: the delay's input is the send plus 0.42 of its own output, which has been through a
    2600 Hz lowpass (WebAudio's default Q of 1 dB); what comes out of the lowpass goes to the master. A block of `delay`
    samples at a time: the delay's output at a sample is its input a block earlier."""
    b, a = _biquad("lowpass", 2600.0, 1.0)
    out = np.zeros_like(x)
    zi = np.zeros(2)
    previous = np.zeros(delay)
    for start in range(0, len(x), delay):
        block = x[start : start + delay]
        filtered, zi = lfilter(b, a, previous[: len(block)], zi=zi)
        out[start : start + len(block)] = filtered
        previous = np.zeros(delay)
        previous[: len(block)] = block + 0.42 * filtered
    return out


# ---------- the sfx, from crate.js ----------


def coin(s: Scene, t0: float = 0.0, pitch: float = 1.0) -> None:
    s.tone(2350 * pitch, 0.12, "triangle", 0.08, t0, 0, 0.3)
    s.tone(3520 * pitch, 0.18, "sine", 0.05, t0 + 0.03)


def thud(s: Scene) -> None:
    s.tone(90, 0.35, "sine", 0.7, 0, 38, 0.2)
    s.noise(0.25, "lowpass", 500, 0.7, 0.5)
    s.noise(0.08, "bandpass", 1400, 2, 0.15)


def knock(s: Scene, n: int) -> None:
    v = 0.3 + n * 0.12
    s.tone(170 + n * 14, 0.12, "triangle", v, 0, 120, 0.2)
    s.noise(0.07, "bandpass", 900, 3, v * 0.8)
    s.tone(175 + n * 14, 0.1, "triangle", v * 0.7, 0.09, 130, 0.2)
    s.noise(0.06, "bandpass", 1000, 3, v * 0.6, 0.09)


def crack(s: Scene) -> None:
    s.noise(0.18, "highpass", 2500, 0.8, 0.5)
    s.noise(0.06, "bandpass", 5000, 1, 0.4, 0.03)
    s.tone(300, 0.08, "square", 0.06, 0, 120, 0.1)


def snap(s: Scene, t0: float) -> None:
    s.noise(0.05, "bandpass", 3200, 4, 0.35, t0)
    s.tone(900, 0.05, "triangle", 0.08, t0, 300, 0.1)


def straps(s: Scene) -> None:
    snap(s, 0.05)
    snap(s, 0.11)


def whoosh(s: Scene) -> None:
    s.noise(0.55, "bandpass", 350, 1.2, 0.45, 0, 2600)
    s.tone(220, 0.9, "sine", 0.12, 0.05, 660, 0.8, 0.2)
    s.tone(330, 0.9, "sine", 0.08, 0.1, 990, 0.8, 0.25)


def tick(s: Scene, hz: float = 4100.0, v: float = 1.0) -> None:
    s.noise(0.025, "bandpass", hz, 6, 0.22 * v)
    s.tone(1900, 0.03, "triangle", 0.05 * v, 0, 0, 0.05)


def unfurl(s: Scene) -> None:
    s.noise(0.35, "bandpass", 600, 1, 0.25, 0, 1800)
    s.tone(523, 0.3, "triangle", 0.06, 0.15)


def stamp(s: Scene) -> None:
    s.tone(110, 0.2, "sine", 0.5, 0, 50, 0.1)
    s.noise(0.1, "lowpass", 900, 0.8, 0.4)


def land(s: Scene) -> None:
    s.tone(1320, 0.4, "sine", 0.08, 0)
    s.tone(1760, 0.5, "sine", 0.05, 0.05)


def flip(s: Scene, t0: float = 0.0) -> None:
    s.noise(0.12, "bandpass", 1800, 2, 0.15, t0, 900)


REVEAL_NOTES = [
    [523, 659],
    [523, 659, 784],
    [440, 554, 659, 880],
    [392, 494, 587, 784, 988],
    [349, 440, 523, 698, 880, 1047],
    [392, 494, 587, 784, 988, 1175, 1568],
    [523, 659, 784, 1047, 1319, 1568, 2093],
]


def reveal(s: Scene, ti: int) -> None:
    """The sting as the good's face comes round: `ti` 0 to 5 are the crate's tiers 1 to 6, 6 is Curio."""
    notes = REVEAL_NOTES[ti]
    step = 0.075 if ti >= 4 else 0.1
    for i, f in enumerate(notes):
        s.tone(f, 1.6 + ti * 0.25, "triangle", 0.09, i * step, 0, 0.7, 0.01)
        s.tone(f * 2, 1.2, "sine", 0.025, i * step, 0, 0.8)
    if ti >= 3:
        s.tone(notes[0] / 2, 2.2, "sawtooth", 0.035, 0, 0, 0.6, 0.15)
    if ti >= 4:
        s.noise(1.4, "highpass", 6000, 0.5, 0.06, 0.1)
        s.tone(notes[0] / 4, 1.6, "sine", 0.35, 0, notes[0] / 6, 0.2)
    if ti >= 5:
        for i in range(10):
            s.tone(2000 + s.random() * 2400, 0.4, "sine", 0.03, 0.4 + i * 0.07)
    if ti == 6:
        for i, m in enumerate((1, 2.76, 5.4, 8.9)):
            s.tone(660 * m, 2.6 / (i + 1), "sine", 0.12 / (i + 1), 0)
        for i in range(14):
            coin(s, 0.3 + i * 0.06 + s.random() * 0.04)


def payback(s: Scene) -> None:
    """New: what a crate that pays Coins back plays as its card turns over: the purse dropping, a quick run of coins rising a
    little as they stack, and the card's own chime (land) on the last."""
    s.tone(160, 0.18, "sine", 0.25, 0, 90, 0.2)
    s.noise(0.1, "lowpass", 700, 0.8, 0.2)
    for i in range(10):
        coin(s, 0.06 + i * 0.055 + s.random() * 0.02, 1 + i * 0.012 + (s.random() - 0.5) * 0.03)
    land_at = 0.06 + 10 * 0.055 + 0.08
    s.tone(1320, 0.4, "sine", 0.08, land_at)
    s.tone(1760, 0.5, "sine", 0.05, land_at + 0.05)


# What each file is: the seconds of render it needs (its longest voice and the room's tail) and how it is made.
Beat = Callable[[Scene], None]
BEATS: dict[str, tuple[float, Beat, str]] = {
    "crate_land": (1.2, thud, "the crate lands (0.7 s)"),
    "crate_knock_1": (1.0, lambda s: knock(s, 0), "the first rattle (1.25 s), tipping 3 degrees"),
    "crate_knock_2": (1.0, lambda s: knock(s, 1), "the second rattle (1.6 s), 5 degrees"),
    "crate_knock_3": (1.0, lambda s: knock(s, 2), "the third rattle (1.9 s), 8 degrees"),
    "seal_crack": (1.0, crack, "the wax seal cracks (2.2 s)"),
    "straps_snap": (1.0, straps, "the straps snap (2.2 s)"),
    "lid_whoosh": (2.5, whoosh, "the lid flies off (2.38 s)"),
    "reel_open": (1.6, unfurl, "the reel opens out of the light (2.9 s)"),
    "card_tick_1": (0.6, lambda s: tick(s, 3800), "a card crosses the line, low pitch"),
    "card_tick_2": (0.6, lambda s: tick(s, 4100), "a card crosses the line, middle pitch"),
    "card_tick_3": (0.6, lambda s: tick(s, 4400), "a card crosses the line, high pitch"),
    "card_land": (1.8, land, "the reel stops on the card (9.7 s)"),
    "card_turn": (0.6, flip, "each half turn of the card's turning over"),
    "stamp": (1.0, stamp, "the YOURS stamp lands"),
    "sting_1": (3.0, lambda s: reveal(s, 0), "the face of a tier 1 good comes round"),
    "sting_2": (3.0, lambda s: reveal(s, 1), "tier 2"),
    "sting_3": (3.4, lambda s: reveal(s, 2), "tier 3"),
    "sting_4": (4.0, lambda s: reveal(s, 3), "tier 4"),
    "sting_5": (4.5, lambda s: reveal(s, 4), "tier 5"),
    "sting_6": (5.0, lambda s: reveal(s, 5), "tier 6"),
    "sting_curio": (5.8, lambda s: reveal(s, 6), "a Curio's face comes round: a bell and a shower of coins"),
    "payback": (2.4, payback, "a crate that pays Coins back: the purse, a run of coins, a chime"),
}


def _trim(signal: Signal, floor: float) -> Signal:
    """`signal` cut where nothing after is above `floor`, plus a short fade."""
    loud = np.where(np.abs(signal) > floor)[0]
    end = int(loud[-1]) + 1 if len(loud) else len(signal)
    end = min(end + round(0.05 * SAMPLE_RATE), len(signal))
    out = signal[:end].copy()
    fade = min(round(FADE_SECONDS * SAMPLE_RATE), end)
    out[end - fade :] *= np.linspace(1.0, 0.0, fade)
    return out


def render_all() -> dict[str, Signal]:
    """Every beat rendered, by file stem, at the one gain that puts the loudest at the peak limit."""
    raw: dict[str, Signal] = {}
    for seed, (name, (seconds, beat, _)) in enumerate(BEATS.items(), start=700):
        scene = Scene(seed, seconds)
        beat(scene)
        raw[name] = scene.render()
    peak = max(float(np.abs(x).max()) for x in raw.values())
    gain = 10 ** ((PEAK_DB - PEAK_MARGIN_DB) / 20) / peak
    floor = 10 ** (TAIL_DB / 20) * peak * gain
    return {name: _trim(x * gain, floor) for name, x in raw.items()}


def write(root: Path) -> list[Path]:
    out = root / SOUNDS_DIR
    out.mkdir(parents=True, exist_ok=True)
    written = []
    for name, signal in render_all().items():
        path = out / f"{name}.ogg"
        sf.write(path, signal.astype(np.float32), SAMPLE_RATE, format="OGG", subtype="VORBIS")
        written.append(path)
    lua = root / SOUNDS_LUA
    lua.write_text(sounds_lua(), encoding="utf-8", newline="\n")
    return [*written, lua]


def sounds_lua() -> str:
    lines = [
        "---@class PagleNS",
        "local ns = select(2, ...)",
        "",
        "-- The Curio crate's sounds (wallet-and-shop.md › Motion, \"A crate opens\"): one Ogg Vorbis file for each beat, by name,",
        "-- under media/crate/sounds/, rendered from the prototype's WebAudio synthesis by scripts/render-crate-sounds.py",
        "-- (pagle_data/crate_sounds.py); don't edit by hand. Played with PlaySoundFile(path, \"SFX\"). Each is mono, 44.1 kHz, and",
        "-- at the one gain they share, so the levels between them are the prototype's. `ticks` are the three pitches of the card",
        "-- tick, `stings` the six crate tiers' and Curio's, by tier. `knocks` are the three rattles, in order.",
        "",
        'local DIR = "Interface\\\\AddOns\\\\Pagle\\\\media\\\\crate\\\\sounds\\\\"',
        "",
        "---@type table<string, string|string[]>",
        "ns.CRATE_SOUNDS = {",
    ]
    singles = ["crate_land", "seal_crack", "straps_snap", "lid_whoosh", "reel_open", "card_land", "card_turn", "stamp", "payback"]
    for name in singles:
        lines.append(f'\t{_field(name)} = DIR .. "{name}.ogg",')
    lines.append("\tknocks = { " + ", ".join(f'DIR .. "crate_knock_{i}.ogg"' for i in (1, 2, 3)) + " },")
    lines.append("\tticks = { " + ", ".join(f'DIR .. "card_tick_{i}.ogg"' for i in (1, 2, 3)) + " },")
    lines.append("\tstings = { " + ", ".join(f'DIR .. "sting_{i}.ogg"' for i in (1, 2, 3, 4, 5, 6)) + ' },')
    lines.append('\tcurio = DIR .. "sting_curio.ogg",')
    lines.append("}")
    return "\n".join(lines) + "\n"


def _field(name: str) -> str:
    words = name.split("_")
    return words[0] + "".join(w.capitalize() for w in words[1:])

"""The sound of the Campfire card opening (#473; tackle-board.md › UI, TKB-R106), rendered offline: a soft whoosh as the fire
catches, then about a second and a half of crackle fading out. One Ogg Vorbis file, mono, 44.1 kHz, in
addons/Pagle_TackleBoard/media/sounds/Campfire.ogg, played once each time the card opens (adapter/Ledge.lua) and never on
its closing.

All of it is synthesised, as the shop's and the sets' sounds are (pagle_data/sounds.py, crate_sounds.py), from one seeded
generator, so it renders the same each time:

- the catch, 0 to 0.6 s: two bands of white noise, a low one (200 to 700 Hz) that swells first and a higher one (900 to
  2800 Hz) that swells just after, so the whoosh seems to rise, and a soft thump under it, a sine falling from 120 to 55 Hz,
  as the air takes the flame;
- the crackle, from 0.25 s: pops at random times, their rate falling from about 60 a second to 8 as the fire settles
  (a Poisson process thinned to that rate), each a few milliseconds of high-passed noise with a quick decay and a pitch
  drawn from a band, one in twelve a louder snap, over a faint low hiss of the flames that fades with them;
- the whole faded to nothing over its last 0.3 s, the file about 1.9 s long.

One gain sets the loudest sample (a snap) a little below the shop's peak limit, less the margin Vorbis needs (PEAK_DB,
PEAK_MARGIN_DB), and a further QUIET_DB under it: the whoosh is the quietest part and the crackle's pops the loudest. The
command line is scripts/render-campfire-sound.py; the file is committed, and Vorbis output isn't byte-stable, so
tests/test_campfire_sound.py holds it to a fresh render to the encoder's noise, as tests/test_crate_sounds.py does the crate's.
"""

from pathlib import Path

import numpy as np
import numpy.typing as npt
import soundfile as sf
from scipy.signal import butter, sosfilt

from pagle_data.sounds import PEAK_DB, PEAK_MARGIN_DB, SAMPLE_RATE

Signal = npt.NDArray[np.float64]

SOUND = Path("addons/Pagle_TackleBoard/media/sounds/Campfire.ogg")
SEED = 473
SECONDS = 1.9
CATCH_SECONDS = 0.6
CRACKLE_FROM = 0.25
CRACKLE_TO = 1.75
FADE_SECONDS = 0.3
QUIET_DB = 3.0  # under the shop's peak limit and its Vorbis margin: a UI sound that sits under the game's own


def _band(x: Signal, lo: float, hi: float) -> Signal:
    return np.asarray(sosfilt(butter(2, [lo, hi], btype="band", fs=SAMPLE_RATE, output="sos"), x), dtype=np.float64)


def _swell(t: Signal, peak: float, rise: float, fall: float) -> Signal:
    """A gain that is 0 at t = 0, 1 at `peak`, and gone by `peak` + `fall` (a raised cosine up over `rise`, a decaying
    exponential down)."""
    up = 0.5 - 0.5 * np.cos(np.pi * np.clip((t - (peak - rise)) / rise, 0, 1))
    down = np.exp(-np.clip(t - peak, 0, None) / (fall / 4))
    return np.asarray(up * down, dtype=np.float64)


def whoosh(rng: np.random.Generator, n: int) -> Signal:
    """The catch: two bands of noise swelling one after the other, and the thump under them."""
    t = np.arange(n) / SAMPLE_RATE
    low = _band(rng.standard_normal(n), 200, 700) * _swell(t, 0.14, 0.14, 0.4)
    high = _band(rng.standard_normal(n), 900, 2800) * _swell(t, 0.26, 0.2, 0.34) * 0.45
    freq = 55 + 65 * np.exp(-t / 0.08)
    phase = 2 * np.pi * np.cumsum(freq) / SAMPLE_RATE
    thump = np.sin(phase) * _swell(t, 0.05, 0.05, 0.22) * 0.5
    return (low + high) * 0.55 + thump * 0.6


def _pop(rng: np.random.Generator, snap: bool) -> Signal:
    """One crackle: a few milliseconds of high-passed noise with a quick decay, at a pitch drawn from a band."""
    length = int(rng.uniform(0.004, 0.012 if snap else 0.008) * SAMPLE_RATE)
    centre = rng.uniform(1500, 5200)
    noise = _band(rng.standard_normal(length + 64), centre * 0.6, min(centre * 1.5, SAMPLE_RATE / 2 - 100))[64:]
    decay = np.exp(-np.arange(length) / (rng.uniform(0.0008, 0.0025) * SAMPLE_RATE))
    return np.asarray(noise * decay, dtype=np.float64)


def crackle(rng: np.random.Generator, n: int) -> Signal:
    """The pops at random times, thinned to a rate falling from 60 a second to 8, over the faint hiss of the flames."""
    out = np.zeros(n)
    t = CRACKLE_FROM
    top = 60.0
    while t < CRACKLE_TO:
        t += rng.exponential(1 / top)
        at = int(t * SAMPLE_RATE)
        rate = 8 + 52 * np.exp(-(t - CRACKLE_FROM) / 0.7)
        if at >= n or rng.uniform() > rate / top:
            continue
        snap = rng.uniform() < 1 / 12
        gain = rng.lognormal(-0.2, 0.55) * (1.8 if snap else 1.0)
        pop = _pop(rng, snap) * gain
        pop = pop[: n - at]
        out[at : at + len(pop)] += pop
    times = np.arange(n) / SAMPLE_RATE
    fade = np.exp(-np.clip(times - CRACKLE_FROM, 0, None) / 1.1)
    hiss = _band(rng.standard_normal(n), 120, 900) * 0.035 * _swell(times, 0.45, 0.25, 1.1)
    return out * fade + hiss


def render() -> Signal:
    """The whole sound: the catch and the crackle mixed, faded out, at its level."""
    rng = np.random.default_rng(SEED)
    n = int(SECONDS * SAMPLE_RATE)
    catch = whoosh(rng, int(CATCH_SECONDS * SAMPLE_RATE))
    mix = crackle(rng, n)
    mix[: len(catch)] += catch
    times = np.arange(n) / SAMPLE_RATE
    mix *= np.clip((SECONDS - times) / FADE_SECONDS, 0, 1)
    mix *= 10 ** ((PEAK_DB - PEAK_MARGIN_DB - QUIET_DB) / 20) / np.abs(mix).max()
    return mix


def write(root: Path) -> list[Path]:
    """Writes addons/Pagle_TackleBoard/media/sounds/Campfire.ogg, returning it."""
    path = root / SOUND
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(path, render().astype(np.float32), SAMPLE_RATE, format="OGG", subtype="VORBIS")
    return [path]

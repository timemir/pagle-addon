"""PROTOTYPE, throwaway. Renders the sound board's shipped sets as .ogg files.

Question (wow-fish "Prototype Pagle's sounds"): what do Pagle's Announcements
sound like? This script builds two of the three candidate sets the in-game
board compares:

  cc0/  cut from Kenney CC0 packs (interface-sounds, rpg-audio, music-jingles),
        loudness-matched, plus one Legend sting chained from two jingles.
  own/  rendered here from scratch (modal wood and bell synthesis + a small
        room), so the files are wholly Pagle's under GPL-3.0-or-later.

Every file is mono, 44.1 kHz, matched to the same loudness so the board compares
sound, not volume.

Run: python render.py <kenney-dir> <addon-sounds-dir>
Needs: numpy, soundfile (pip install numpy soundfile).
"""

import sys
from pathlib import Path

import numpy as np
import soundfile as sf

SR = 44100
TARGET_RMS_DB = -20.0  # over the audible part of the sound
PEAK_DB = -1.0
rng = np.random.default_rng(7)

# D major pentatonic: nothing in it can clash, whatever order the notes land in.
N = {
    "D4": 293.66, "E4": 329.63, "F#4": 369.99, "A4": 440.00, "B4": 493.88,
    "D5": 587.33, "E5": 659.26, "F#5": 739.99, "A5": 880.00, "B5": 987.77,
    "D6": 1174.66, "E6": 1318.51, "F#6": 1479.98, "A6": 1760.00,
}


def silence(sec):
    return np.zeros(int(sec * SR))


def partials(f, dur, ratios, amps, decays, attack=0.003):
    t = np.arange(int(dur * SR)) / SR
    out = np.zeros_like(t)
    for r, a, d in zip(ratios, amps, decays):
        if f * r > SR / 2.2:
            continue
        out += a * np.sin(2 * np.pi * f * r * t + rng.uniform(0, 6.28)) * np.exp(-t / d)
    env = np.minimum(t / attack, 1.0)
    return out * env


def lowpassed_noise(n, cutoff):
    x = rng.standard_normal(n)
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros(n)
    acc = 0.0
    for i in range(n):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y / (np.abs(y).max() + 1e-9)


def marimba(f, dur=0.9):
    # Bar modes of a tuned wooden bar: 1, ~3.9, ~9.2.
    tone = partials(f, dur, [1, 3.93, 9.2], [1, 0.22, 0.05], [dur * 0.32, dur * 0.09, dur * 0.03])
    click = lowpassed_noise(int(0.012 * SR), 2500) * np.exp(-np.arange(int(0.012 * SR)) / (0.003 * SR)) * 0.15
    tone[: len(click)] += click
    return tone


def bell(f, dur=1.6):
    # Small inharmonic hand bell.
    return partials(f, dur, [1, 2.0, 2.76, 5.4, 8.93], [1, 0.45, 0.35, 0.12, 0.05],
                    [dur * 0.45, dur * 0.35, dur * 0.25, dur * 0.1, dur * 0.05], attack=0.002)


def woodblock(f, dur=0.12):
    tone = partials(f, dur, [1, 2.57], [1, 0.3], [0.03, 0.012], attack=0.001)
    click = lowpassed_noise(int(0.006 * SR), 4000) * 0.2
    tone[: len(click)] += click
    return tone


def place(events, tail=0.6):
    """events: list of (start_sec, signal, gain)."""
    end = max(s + len(sig) / SR for s, sig, _ in events) + tail
    out = np.zeros(int(end * SR))
    for s, sig, g in events:
        i = int(s * SR)
        out[i : i + len(sig)] += g * sig
    return out


def room(x, seconds=0.9, wet=0.16):
    n = int(seconds * SR)
    ir = lowpassed_noise(n, 3500) * np.exp(-np.arange(n) / (0.22 * SR))
    ir /= np.sqrt((ir ** 2).sum())
    w = np.convolve(x, ir)
    dry = np.concatenate([x, np.zeros(len(w) - len(x))])
    return (1 - wet) * dry + wet * w


def finish(x):
    # Trim trailing near-silence, fade, then loudness-match.
    thresh = np.abs(x).max() * 10 ** (-60 / 20)
    last = np.nonzero(np.abs(x) > thresh)[0][-1]
    x = x[: last + 1]
    fade = min(len(x), int(0.05 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    return match(x)


def match(x):
    active = x[np.abs(x) > np.abs(x).max() * 10 ** (-40 / 20)]
    rms = np.sqrt((active ** 2).mean())
    x = x * (10 ** (TARGET_RMS_DB / 20) / rms)
    peak = np.abs(x).max()
    limit = 10 ** (PEAK_DB / 20)
    if peak > limit:
        x = x * (limit / peak)  # peak wins over loudness for very spiky sounds
    return x


def write(path, x):
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(str(path), x.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print(f"{path.name:28} {len(x) / SR:5.2f}s")


def own(out):
    # Toasts: two rising wooden notes. Three variants rotate so a run of toasts never repeats.
    for i, (a, b) in enumerate([("A4", "D5"), ("B4", "E5"), ("D5", "F#5")], 1):
        write(out / f"toast_wood_{i}.ogg", finish(room(place([(0, marimba(N[a]), 0.8), (0.085, marimba(N[b]), 1.0)]))))
    write(out / "toast_bell.ogg", finish(room(place([(0, bell(N["D6"], 1.2), 0.6), (0.07, bell(N["A6"], 1.0), 0.35)]))))

    # Banner: a wooden run up the scale with a bell on top.
    run = [(i * 0.09, marimba(N[n]), 0.8) for i, n in enumerate(["D4", "F#4", "A4", "D5"])]
    write(out / "banner_wood.ogg", finish(room(place(run + [(0.36, bell(N["D6"], 1.8), 0.55)]), wet=0.2)))
    gild = [(i * 0.11, bell(N[n], 1.6), 0.5) for i, n in enumerate(["A5", "D6", "F#6"])]
    write(out / "banner_bell.ogg", finish(room(place(gild), wet=0.22)))

    # Legend: a slow bell chord, a fast run, a ringing top note. Shared by every Legend.
    def sting():
        ev = [(0, bell(N["D4"], 3.0), 0.5), (0.02, bell(N["A4"], 3.0), 0.4), (0.04, bell(N["D5"], 3.0), 0.35)]
        ev += [(0.55 + i * 0.06, marimba(N[n], 0.7), 0.6) for i, n in enumerate(["D5", "E5", "F#5", "A5", "B5", "D6"])]
        ev += [(0.95, bell(N["D6"], 3.0), 0.5), (0.97, bell(N["A6"], 2.4), 0.2)]
        return ev

    write(out / "legend_sting.ogg", finish(room(place(sting(), tail=1.0), seconds=1.6, wet=0.28)))
    # Each Legend could add its own short motif after the sting. Two examples.
    for name, motif in [("a", ["A5", "F#5", "D6"]), ("b", ["E5", "B5", "A5"])]:
        ev = sting() + [(2.1 + i * 0.16, bell(N[n], 1.4), 0.45) for i, n in enumerate(motif)]
        write(out / f"legend_signature_{name}.ogg", finish(room(place(ev, tail=1.0), seconds=1.6, wet=0.28)))

    # Recast cue: practical, not musical. A quiet wooden knock.
    write(out / "recast_double.ogg", finish(place([(0, woodblock(820), 1.0), (0.13, woodblock(820), 0.8)], tail=0.05)))
    write(out / "recast_single.ogg", finish(place([(0, woodblock(640, 0.15), 1.0)], tail=0.05)))


def load(path):
    x, sr = sf.read(str(path), always_2d=True)
    x = x.mean(axis=1)
    assert sr in (44100, 48000)
    if sr != SR:  # naive resample is fine for a prototype
        x = np.interp(np.arange(int(len(x) * SR / sr)) * sr / SR, np.arange(len(x)), x)
    return x


def cc0(kenney, out):
    pick = {
        "toast_confirmation.ogg": "kenney_interface-sounds/Audio/confirmation_002.ogg",
        "toast_glass.ogg": "kenney_interface-sounds/Audio/glass_001.ogg",
        "toast_pizzi.ogg": "kenney_music-jingles/Audio/Pizzicato jingles/jingles_PIZZI04.ogg",
        "toast_steel.ogg": "kenney_music-jingles/Audio/Steel jingles/jingles_STEEL09.ogg",
        "banner_pizzi.ogg": "kenney_music-jingles/Audio/Pizzicato jingles/jingles_PIZZI03.ogg",
        "banner_steel.ogg": "kenney_music-jingles/Audio/Steel jingles/jingles_STEEL01.ogg",
        "banner_hit.ogg": "kenney_music-jingles/Audio/Hit jingles/jingles_HIT11.ogg",
        "legend_steel.ogg": "kenney_music-jingles/Audio/Steel jingles/jingles_STEEL07.ogg",
        "legend_pizzi.ogg": "kenney_music-jingles/Audio/Pizzicato jingles/jingles_PIZZI07.ogg",
        "recast_tick.ogg": "kenney_interface-sounds/Audio/tick_004.ogg",
        "recast_drop.ogg": "kenney_interface-sounds/Audio/drop_002.ogg",
        "recast_latch.ogg": "kenney_rpg-audio/Audio/metalLatch.ogg",
    }
    for name, rel in pick.items():
        matches = list(kenney.glob("**/" + Path(rel).name))
        assert matches, rel
        write(out / name, match(load(matches[0])))
    # A longer Legend sting chained from two steel-drum jingles.
    a = load(next(kenney.glob("**/jingles_STEEL03.ogg")))
    b = load(next(kenney.glob("**/jingles_STEEL12.ogg")))
    gap = silence(0.05)
    write(out / "legend_chained.ogg", finish(np.concatenate([a, gap, b, silence(0.5)])))


if __name__ == "__main__":
    kenney, sounds = Path(sys.argv[1]), Path(sys.argv[2])
    own(sounds / "own")
    cc0(kenney, sounds / "cc0")

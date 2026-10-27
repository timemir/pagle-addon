"""Builds Pagle's generated Announcement sounds (ANN-R74) from raw ElevenLabs takes and the game's own clips.

Each generated sound set has data/sounds/generated/<set>/set.toml. A file in it is one of:

- a **pick**: `pick = "a"` takes the file's own raw take, data/sounds/generated/<set>/raw/<file>/take_<x>.mp3, whole;
- a **mix**: `mix = [{ part = "pop", start = 0.0, ... }, { clip = "creature/parrot/parrotaggro", ... }]` lays parts
  and clips on a timeline. A part is a single generated sound in raw/<part>/take_<x>.mp3 (`pick`, default "a"); a clip
  is the game's own, named under WOW_SOUND_DIR (wow.export's sound/ folder) and Blizzard's, so not in the repo. Each
  entry has `start` seconds, `semitones` (default 0), `gain` (default 1; every part and clip is peak-matched first) and
  `length` seconds (default whole; a cut ends in a short fade). Every part and clip is faded in and out over a few
  milliseconds, so a take that starts mid-wave doesn't click.

[part.<name>] tables hold the prompts of the parts. build() finishes each file with the synthesised sets' own trim,
fade and loudness match, and writes the shipped .ogg. The takes are committed because a generation can't be repeated.
"""

import os
import tomllib
from pathlib import Path
from typing import Any

import numpy as np
import soundfile as sf

from pagle_data.murloc_sounds import clip, pitched, place, write_ogg
from pagle_data.sounds import SAMPLE_RATE, SOUNDS_DIR, Signal, _finish_limited

# Where the sets' sources are, from the repo root.
GENERATED_DIR = Path("data/sounds/generated")
FILES = ["toast_1", "toast_2", "toast_3", "banner"]
# Tunables, generated sound length: the longest a generated toast and banner run before they're cut and faded.
# Looser than the synthesised sets' (1.6 s, 3 s): a take that rings a little longer is fine.
TOAST_SECONDS = 2.0
BANNER_SECONDS = 4.0
# The fade at the end of a cut part or clip.
CUT_FADE = 0.03
# The fades at the start and end of every part and clip: a take that starts mid-wave clicks without one.
EDGE_FADE_IN = 0.004
EDGE_FADE_OUT = 0.008


def generated_sets(root: Path) -> list[str]:
    """The folder names of the generated sets, in alphabetical order."""
    return sorted(path.parent.name for path in (root / GENERATED_DIR).glob("*/set.toml"))


def read_take(path: Path) -> tuple[Signal, int]:
    samples, rate = sf.read(path, dtype="float64", always_2d=True)
    mono: Signal = np.asarray(samples.mean(axis=1), dtype=np.float64)
    return mono, int(rate)


def _layer(root: Path, folder: str, entry: dict[str, Any]) -> tuple[float, Signal, float]:
    """One mix entry as (start, signal, gain): peak-matched, pitched and cut."""
    semitones = float(entry.get("semitones", 0))
    if "part" in entry:
        take, rate = read_take(root / GENERATED_DIR / folder / "raw" / entry["part"] / f"take_{entry.get('pick', 'a')}.mp3")
        x = pitched(take, rate, semitones)
    else:
        source = Path(os.environ["WOW_SOUND_DIR"]) / Path(entry["clip"]).parent
        x = clip(source, Path(entry["clip"]).name, semitones)
    if "length" in entry:
        x = x[: int(entry["length"] * SAMPLE_RATE)].copy()
        fade = min(len(x), int(CUT_FADE * SAMPLE_RATE))
        x[-fade:] *= np.linspace(1, 0, fade)
    x = x / max(float(np.abs(x).max()), 1e-9)
    fade_in, fade_out = min(len(x), int(EDGE_FADE_IN * SAMPLE_RATE)), min(len(x), int(EDGE_FADE_OUT * SAMPLE_RATE))
    x[:fade_in] *= np.linspace(0, 1, fade_in)
    x[-fade_out:] *= np.linspace(1, 0, fade_out)
    return float(entry.get("start", 0)), x, float(entry.get("gain", 1))


def build_sound(root: Path, folder: str, name: str, spec: dict[str, Any]) -> Signal:
    if "mix" in spec:
        signal = place([_layer(root, folder, entry) for entry in spec["mix"]])
    else:
        signal, rate = read_take(root / GENERATED_DIR / folder / "raw" / name / f"take_{spec['pick']}.mp3")
        assert rate == SAMPLE_RATE, f"{folder}/{name}: {rate} Hz"
    return _finish_limited(signal, BANNER_SECONDS if name == "banner" else TOAST_SECONDS)


def build(root: Path) -> list[Path]:
    """Writes every generated set's four .ogg files under addons/Pagle/media/sounds/ and returns them."""
    written = []
    for folder in generated_sets(root):
        files = tomllib.loads((root / GENERATED_DIR / folder / "set.toml").read_text(encoding="utf-8"))["file"]
        for name in FILES:
            path = root / SOUNDS_DIR / folder / f"{name}.ogg"
            path.parent.mkdir(parents=True, exist_ok=True)
            write_ogg(path, build_sound(root, folder, name, files[name]))
            written.append(path)
    return written

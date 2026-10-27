"""Renders the Curio crate's sounds (wallet-and-shop.md › Motion, "A crate opens") from the prototype's WebAudio synthesis
(prototypes/curio-crate/crate.js) into addons/Pagle/media/crate/sounds/, with the table that names them.

    .tools/bin/python scripts/render-crate-sounds.py

Runs on the pinned Python in .tools/ (scripts/setup.sh installs numpy, soundfile and SciPy), like render-sounds.py. Writes one
Ogg Vorbis file for each beat (mono, 44.1 kHz) and addons/Pagle/data/CrateSounds.lua (then StyLua it). Commit what it
writes: the files ship as they are. The art is scripts/crate-art.py's. tests/test_crate_sounds.py checks the files'
format, lengths and sizes, and renders each in memory to hold the committed file to it, to the encoder's noise; it never writes
them. pagle_data/crate_sounds.py has the details.
"""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("render-crate-sounds: needs Python 3.12; run it as .tools/bin/python scripts/render-crate-sounds.py")

from pagle_data.crate_sounds import write  # noqa: E402 (after the version check, which must run first)

if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    for path in write(root):
        print(path.relative_to(root).as_posix())

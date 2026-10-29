"""Renders the sound of the Campfire card opening (#473): a soft whoosh as the fire catches, then about a second and a half of
crackle fading out, into addons/Pagle_TackleBoard/media/sounds/Campfire.ogg.

    .tools/bin/python scripts/render-campfire-sound.py

Runs on the pinned Python in .tools/ (scripts/setup.sh installs numpy, soundfile and SciPy), like render-sounds.py and
render-crate-sounds.py. Writes one Ogg Vorbis file (mono, 44.1 kHz); commit it: it ships as it is. tests/test_campfire_sound.py
checks its format, length and level, and renders it in memory to hold the committed file to it; it never writes it.
pagle_data/campfire_sound.py has the details.
"""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("render-campfire-sound: needs Python 3.12; run it as .tools/bin/python scripts/render-campfire-sound.py")

from pagle_data.campfire_sound import write  # noqa: E402 (after the version check, which must run first)

if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    for path in write(root):
        print(path.relative_to(root).as_posix())

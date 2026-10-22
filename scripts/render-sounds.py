"""Renders Pagle's own Announcement sounds (ANN-R72, ANN-R74) into addons/Pagle/media/sounds/.

    .tools/bin/python scripts/render-sounds.py

Runs on the pinned Python in .tools/ (scripts/setup.sh installs numpy, soundfile and SciPy). Commit what it writes:
the files ship as they are. scripts/check.sh checks their format and loudness, and renders each in memory to hold the
committed file to it, to the encoder's noise; it never writes them.
"""

import sys
from pathlib import Path

if sys.version_info < (3, 12):
    sys.exit("render-sounds: needs Python 3.12; run it as .tools/bin/python scripts/render-sounds.py")

from pagle_data.sounds import SOUNDS_DIR, render  # noqa: E402 (after the version check, which must run first)

if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    for path in render(root / SOUNDS_DIR):
        print(path.relative_to(root).as_posix())
